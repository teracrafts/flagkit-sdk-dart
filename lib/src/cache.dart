import 'flag_state.dart';

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
