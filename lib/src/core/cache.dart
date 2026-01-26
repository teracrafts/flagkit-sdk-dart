import '../types/flag_state.dart';
import '../utils/security.dart';

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  DateTime lastAccessed;

  _CacheEntry({
    required this.value,
    required this.expiresAt,
    required this.lastAccessed,
  });
}

/// Generic cache with TTL and LRU eviction.
class Cache<K, V> {
  final Map<K, _CacheEntry<V>> _cache = {};
  final int maxSize;
  final Duration ttl;

  Cache({
    this.maxSize = 1000,
    this.ttl = const Duration(minutes: 5),
  });

  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }

    entry.lastAccessed = DateTime.now();
    return entry.value;
  }

  void set(K key, V value, [Duration? customTtl]) {
    final effectiveTtl = customTtl ?? ttl;
    final now = DateTime.now();

    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: now.add(effectiveTtl),
      lastAccessed: now,
    );

    _evictIfNeeded();
  }

  bool has(K key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return false;
    }

    return true;
  }

  bool remove(K key) {
    return _cache.remove(key) != null;
  }

  void clear() {
    _cache.clear();
  }

  int get length => _cache.length;

  bool get isEmpty => _cache.isEmpty;

  Iterable<K> get keys => _cache.keys;

  void _evictIfNeeded() {
    if (_cache.length <= maxSize) return;

    final now = DateTime.now();

    // Remove expired entries first
    _cache.removeWhere((_, entry) => now.isAfter(entry.expiresAt));

    // If still over capacity, remove least recently used
    while (_cache.length > maxSize) {
      K? lruKey;
      DateTime? lruTime;

      for (final entry in _cache.entries) {
        if (lruTime == null || entry.value.lastAccessed.isBefore(lruTime)) {
          lruKey = entry.key;
          lruTime = entry.value.lastAccessed;
        }
      }

      if (lruKey != null) {
        _cache.remove(lruKey);
      } else {
        break;
      }
    }
  }
}

/// Specialized cache for flag states.
class FlagCache extends Cache<String, FlagState> {
  FlagCache({
    super.maxSize = 1000,
    super.ttl = const Duration(minutes: 5),
  });

  void setAll(List<FlagState> flags) {
    for (final flag in flags) {
      set(flag.key, flag);
    }
  }

  Map<String, FlagState> getAll() {
    final result = <String, FlagState>{};
    for (final key in keys) {
      final value = get(key);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }
}

/// Encrypted flag cache that stores data with AES-GCM encryption.
///
/// This cache encrypts flag data at rest using a key derived from the API key.
/// It provides the same interface as [FlagCache] but with added security.
class EncryptedFlagCache extends FlagCache {
  final EncryptedStorage _storage;

  // Internal storage for encrypted data
  final Map<String, String> _encryptedData = {};

  EncryptedFlagCache({
    required String apiKey,
    super.maxSize = 1000,
    super.ttl = const Duration(minutes: 5),
    int pbkdf2Iterations = 100000,
  }) : _storage = EncryptedStorage.fromApiKey(apiKey, iterations: pbkdf2Iterations);

  @override
  void set(String key, FlagState value, [Duration? customTtl]) {
    // Store in parent cache for fast access
    super.set(key, value, customTtl);

    // Also store encrypted version
    try {
      final json = value.toJson();
      final encrypted = _storage.encryptJson(json);
      _encryptedData[key] = encrypted;
    } catch (e) {
      // If encryption fails, continue with unencrypted cache
      // The data is still in memory cache
    }
  }

  @override
  bool remove(String key) {
    _encryptedData.remove(key);
    return super.remove(key);
  }

  @override
  void clear() {
    _encryptedData.clear();
    super.clear();
  }

  /// Exports all encrypted data for persistence.
  ///
  /// Returns a map of key to encrypted JSON string.
  Map<String, String> exportEncrypted() {
    return Map.from(_encryptedData);
  }

  /// Imports encrypted data from persistence.
  ///
  /// [data] is a map of key to encrypted JSON string.
  void importEncrypted(Map<String, String> data) {
    for (final entry in data.entries) {
      try {
        final json = _storage.decryptJson(entry.value);
        final flag = FlagState.fromJson(json);
        super.set(entry.key, flag);
        _encryptedData[entry.key] = entry.value;
      } catch (e) {
        // Skip invalid entries
        continue;
      }
    }
  }

  /// Serializes the entire cache to an encrypted string.
  ///
  /// This can be used to persist the cache to disk or shared preferences.
  String serializeEncrypted() {
    final allFlags = getAll();
    final flagsJson = <String, dynamic>{};

    for (final entry in allFlags.entries) {
      flagsJson[entry.key] = entry.value.toJson();
    }

    return _storage.encryptJson(flagsJson);
  }

  /// Deserializes and loads cache from an encrypted string.
  ///
  /// [encrypted] is the encrypted string from [serializeEncrypted].
  void deserializeEncrypted(String encrypted) {
    try {
      final flagsJson = _storage.decryptJson(encrypted);

      for (final entry in flagsJson.entries) {
        final flagData = entry.value as Map<String, dynamic>;
        final flag = FlagState.fromJson(flagData);
        set(entry.key, flag);
      }
    } catch (e) {
      // If decryption fails, clear the cache
      clear();
      rethrow;
    }
  }
}
