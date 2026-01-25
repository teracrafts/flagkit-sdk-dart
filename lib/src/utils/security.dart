/// Security utilities for FlagKit SDK.
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/pointycastle.dart' as pc;

import '../error/error_code.dart';
import '../error/flagkit_exception.dart';

/// Logger interface for security warnings.
abstract class Logger {
  void debug(String message);
  void info(String message);
  void warn(String message);
  void error(String message);
}

/// Whether the app is running in a web browser.
///
/// Uses conditional import to determine the platform.
const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

/// Common PII field patterns (case-insensitive).
const List<String> _piiPatterns = [
  'email',
  'phone',
  'telephone',
  'mobile',
  'ssn',
  'social_security',
  'socialSecurity',
  'credit_card',
  'creditCard',
  'card_number',
  'cardNumber',
  'cvv',
  'password',
  'passwd',
  'secret',
  'token',
  'api_key',
  'apiKey',
  'private_key',
  'privateKey',
  'access_token',
  'accessToken',
  'refresh_token',
  'refreshToken',
  'auth_token',
  'authToken',
  'address',
  'street',
  'zip_code',
  'zipCode',
  'postal_code',
  'postalCode',
  'date_of_birth',
  'dateOfBirth',
  'dob',
  'birth_date',
  'birthDate',
  'passport',
  'driver_license',
  'driverLicense',
  'national_id',
  'nationalId',
  'bank_account',
  'bankAccount',
  'routing_number',
  'routingNumber',
  'iban',
  'swift',
];

/// Check if a field name potentially contains PII.
///
/// Returns `true` if the [fieldName] contains any known PII patterns
/// (case-insensitive).
bool isPotentialPIIField(String fieldName) {
  final lowerName = fieldName.toLowerCase();
  return _piiPatterns
      .any((pattern) => lowerName.contains(pattern.toLowerCase()));
}

/// Detect potential PII in a data map and return the field paths.
///
/// Recursively searches through [data] and returns a list of dot-notation
/// paths for fields that match PII patterns.
///
/// The optional [prefix] parameter is used for nested objects to build
/// the full path.
List<String> detectPotentialPII(
  Map<String, dynamic> data, [
  String prefix = '',
]) {
  final piiFields = <String>[];

  for (final entry in data.entries) {
    final key = entry.key;
    final value = entry.value;
    final fullPath = prefix.isEmpty ? key : '$prefix.$key';

    if (isPotentialPIIField(key)) {
      piiFields.add(fullPath);
    }

    // Recursively check nested objects
    if (value != null && value is Map<String, dynamic>) {
      final nestedPII = detectPotentialPII(value, fullPath);
      piiFields.addAll(nestedPII);
    }
  }

  return piiFields;
}

/// PII detection result.
class PIIDetectionResult {
  /// Whether PII was detected.
  final bool hasPII;

  /// List of field paths containing potential PII.
  final List<String> fields;

  /// Human-readable message about the detection.
  final String message;

  const PIIDetectionResult({
    required this.hasPII,
    required this.fields,
    required this.message,
  });
}

/// Check for potential PII in data and return detailed result.
PIIDetectionResult checkForPotentialPII(
  Map<String, dynamic>? data,
  String dataType,
) {
  if (data == null) {
    return const PIIDetectionResult(hasPII: false, fields: [], message: '');
  }

  final piiFields = detectPotentialPII(data);

  if (piiFields.isEmpty) {
    return const PIIDetectionResult(hasPII: false, fields: [], message: '');
  }

  final advice = dataType == 'context'
      ? 'Consider adding these to privateAttributes.'
      : 'Consider removing sensitive data from events.';

  final message =
      '[FlagKit Security] Potential PII detected in $dataType data: ${piiFields.join(', ')}. $advice';

  return PIIDetectionResult(hasPII: true, fields: piiFields, message: message);
}

/// Warn about potential PII in data.
///
/// Logs a warning if [data] contains fields matching PII patterns.
/// The [dataType] describes the type of data being checked (e.g., 'context', 'event').
void warnIfPotentialPII(
  Map<String, dynamic>? data,
  String dataType,
  Logger? logger,
) {
  if (data == null || logger == null) {
    return;
  }

  final result = checkForPotentialPII(data, dataType);

  if (result.hasPII) {
    logger.warn(result.message);
  }
}

/// Check and throw if PII detected in strict mode.
///
/// In strict PII mode, this throws a [SecurityException] instead of just
/// logging a warning when potential PII is detected.
///
/// [privateAttributes] contains the list of fields that are expected to
/// contain sensitive data and should be excluded from PII detection.
void enforceStrictPII(
  Map<String, dynamic>? data,
  String dataType,
  List<String>? privateAttributes,
  Logger? logger,
) {
  if (data == null) {
    return;
  }

  final piiFields = detectPotentialPII(data);

  if (piiFields.isEmpty) {
    return;
  }

  // Filter out fields that are already in privateAttributes
  final privateSet = privateAttributes?.toSet() ?? <String>{};
  final exposedPII = piiFields.where((field) {
    // Check if the field or any of its parents are in privateAttributes
    final parts = field.split('.');
    for (var i = 0; i < parts.length; i++) {
      final partialPath = parts.sublist(0, i + 1).join('.');
      if (privateSet.contains(partialPath)) {
        return false;
      }
    }
    return true;
  }).toList();

  if (exposedPII.isNotEmpty) {
    throw SecurityException.piiDetected(exposedPII);
  }
}

/// Check if an API key is a server key.
///
/// Server keys start with 'srv_' prefix.
bool isServerKey(String apiKey) {
  return apiKey.startsWith('srv_');
}

/// Check if an API key is a client/SDK key.
///
/// Client keys start with 'sdk_' or 'cli_' prefix.
bool isClientKey(String apiKey) {
  return apiKey.startsWith('sdk_') || apiKey.startsWith('cli_');
}

/// Warn if server key is used in browser environment.
///
/// Server keys should not be exposed in client-side code.
/// This function logs a warning when a server key is detected
/// in a web browser environment.
void warnIfServerKeyInBrowser(String apiKey, Logger? logger) {
  if (kIsWeb && isServerKey(apiKey)) {
    const message =
        '[FlagKit Security] WARNING: Server keys (srv_) should not be used in browser environments. '
        'This exposes your server key in client-side code, which is a security risk. '
        'Use SDK keys (sdk_) for client-side applications instead. '
        'See: https://docs.flagkit.dev/sdk/security#api-keys';

    // Always log to console for visibility
    // ignore: avoid_print
    print(message);

    // Also log through the SDK logger if available
    logger?.warn(message);
  }
}

/// Check if the current environment is production.
bool isProductionEnvironment() {
  if (kIsWeb) {
    return false; // Cannot determine in web
  }
  try {
    final dartEnv = Platform.environment['DART_ENV'];
    return dartEnv == 'production';
  } catch (e) {
    return false;
  }
}

/// Validate local port usage in production.
///
/// Throws [SecurityException] if [localPort] is set while running
/// in production environment (DART_ENV=production).
void validateLocalPortSecurity(int? localPort) {
  if (localPort == null) {
    return;
  }

  if (isProductionEnvironment()) {
    throw SecurityException.localPortInProduction();
  }
}

/// Security configuration options.
class SecurityConfig {
  /// Warn about potential PII in context/events.
  ///
  /// Defaults to `true` in non-release builds.
  final bool warnOnPotentialPII;

  /// Warn when server keys are used in browser.
  ///
  /// Defaults to `true`.
  final bool warnOnServerKeyInBrowser;

  /// Custom PII patterns to detect in addition to built-in patterns.
  final List<String> additionalPIIPatterns;

  /// Whether to throw exception on PII detection instead of warning.
  ///
  /// When enabled, detecting PII in data that is not marked as private
  /// will throw a [SecurityException] instead of logging a warning.
  final bool strictPIIMode;

  /// Whether to enable request signing for POST requests.
  final bool enableRequestSigning;

  /// Whether to enable cache encryption.
  final bool enableCacheEncryption;

  /// Creates a security configuration.
  const SecurityConfig({
    this.warnOnPotentialPII = true,
    this.warnOnServerKeyInBrowser = true,
    this.additionalPIIPatterns = const [],
    this.strictPIIMode = false,
    this.enableRequestSigning = false,
    this.enableCacheEncryption = false,
  });

  /// Creates the default security configuration.
  ///
  /// PII warnings are enabled in non-release builds.
  /// Server key browser warnings are always enabled.
  factory SecurityConfig.defaults() {
    return const SecurityConfig(
      warnOnPotentialPII: true,
      warnOnServerKeyInBrowser: true,
      additionalPIIPatterns: [],
      strictPIIMode: false,
      enableRequestSigning: false,
      enableCacheEncryption: false,
    );
  }

  /// Creates a copy with the given fields replaced.
  SecurityConfig copyWith({
    bool? warnOnPotentialPII,
    bool? warnOnServerKeyInBrowser,
    List<String>? additionalPIIPatterns,
    bool? strictPIIMode,
    bool? enableRequestSigning,
    bool? enableCacheEncryption,
  }) {
    return SecurityConfig(
      warnOnPotentialPII: warnOnPotentialPII ?? this.warnOnPotentialPII,
      warnOnServerKeyInBrowser:
          warnOnServerKeyInBrowser ?? this.warnOnServerKeyInBrowser,
      additionalPIIPatterns:
          additionalPIIPatterns ?? this.additionalPIIPatterns,
      strictPIIMode: strictPIIMode ?? this.strictPIIMode,
      enableRequestSigning: enableRequestSigning ?? this.enableRequestSigning,
      enableCacheEncryption:
          enableCacheEncryption ?? this.enableCacheEncryption,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityConfig &&
          runtimeType == other.runtimeType &&
          warnOnPotentialPII == other.warnOnPotentialPII &&
          warnOnServerKeyInBrowser == other.warnOnServerKeyInBrowser &&
          _listEquals(additionalPIIPatterns, other.additionalPIIPatterns) &&
          strictPIIMode == other.strictPIIMode &&
          enableRequestSigning == other.enableRequestSigning &&
          enableCacheEncryption == other.enableCacheEncryption;

  @override
  int get hashCode =>
      warnOnPotentialPII.hashCode ^
      warnOnServerKeyInBrowser.hashCode ^
      additionalPIIPatterns.hashCode ^
      strictPIIMode.hashCode ^
      enableRequestSigning.hashCode ^
      enableCacheEncryption.hashCode;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ============================================================================
// Request Signing (HMAC-SHA256)
// ============================================================================

/// Get the first 8 characters of an API key for identification.
/// This is safe to expose as it doesn't reveal the full key.
String getKeyId(String apiKey) {
  if (apiKey.length < 8) {
    return apiKey;
  }
  return apiKey.substring(0, 8);
}

/// Generate HMAC-SHA256 signature.
String generateHMACSHA256(String message, String key) {
  final keyBytes = utf8.encode(key);
  final messageBytes = utf8.encode(message);

  final hmacSha256 = Hmac(sha256, keyBytes);
  final digest = hmacSha256.convert(messageBytes);

  return digest.toString();
}

/// Request signature result.
class RequestSignature {
  /// The HMAC-SHA256 signature.
  final String signature;

  /// The timestamp when the signature was created.
  final int timestamp;

  /// The key ID (first 8 chars of API key).
  final String keyId;

  const RequestSignature({
    required this.signature,
    required this.timestamp,
    required this.keyId,
  });
}

/// Create signature for a request body.
///
/// Returns headers that should be added to the request:
/// - X-Signature: The HMAC-SHA256 signature
/// - X-Timestamp: The Unix timestamp in milliseconds
/// - X-Key-Id: The first 8 characters of the API key
RequestSignature createRequestSignature(
  String body,
  String apiKey, [
  int? timestamp,
]) {
  final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
  final message = '$ts.$body';
  final signature = generateHMACSHA256(message, apiKey);

  return RequestSignature(
    signature: signature,
    timestamp: ts,
    keyId: getKeyId(apiKey),
  );
}

/// Get signature headers for a POST request.
Map<String, String> getSignatureHeaders(String body, String apiKey) {
  final sig = createRequestSignature(body, apiKey);
  return {
    'X-Signature': sig.signature,
    'X-Timestamp': sig.timestamp.toString(),
    'X-Key-Id': sig.keyId,
  };
}

/// Verify a request signature (for testing/debugging).
bool verifyRequestSignature(
  String body,
  String signature,
  int timestamp,
  String keyId,
  String apiKey, {
  int maxAgeMs = 300000, // 5 minutes default
}) {
  // Check timestamp age
  final now = DateTime.now().millisecondsSinceEpoch;
  final age = now - timestamp;
  if (age > maxAgeMs || age < 0) {
    return false;
  }

  // Verify key ID matches
  if (keyId != getKeyId(apiKey)) {
    return false;
  }

  // Verify signature
  final message = '$timestamp.$body';
  final expectedSignature = generateHMACSHA256(message, apiKey);

  return signature == expectedSignature;
}

/// Signed payload structure for beacon requests.
class SignedPayload<T> {
  final T data;
  final String signature;
  final int timestamp;
  final String keyId;

  const SignedPayload({
    required this.data,
    required this.signature,
    required this.timestamp,
    required this.keyId,
  });

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) dataToJson) {
    return {
      'data': dataToJson(data),
      'signature': signature,
      'timestamp': timestamp,
      'keyId': keyId,
    };
  }
}

/// Sign a payload with HMAC-SHA256.
SignedPayload<T> signPayload<T>(
  T data,
  String apiKey,
  String Function(T) dataToString, [
  int? timestamp,
]) {
  final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
  final payload = dataToString(data);
  final message = '$ts.$payload';
  final signature = generateHMACSHA256(message, apiKey);

  return SignedPayload(
    data: data,
    signature: signature,
    timestamp: ts,
    keyId: getKeyId(apiKey),
  );
}

/// Verify a signed payload (for testing/debugging).
bool verifySignedPayload<T>(
  SignedPayload<T> signedPayload,
  String apiKey,
  String Function(T) dataToString, {
  int maxAgeMs = 300000, // 5 minutes default
}) {
  // Check timestamp age
  final now = DateTime.now().millisecondsSinceEpoch;
  final age = now - signedPayload.timestamp;
  if (age > maxAgeMs || age < 0) {
    return false;
  }

  // Verify key ID matches
  if (signedPayload.keyId != getKeyId(apiKey)) {
    return false;
  }

  // Verify signature
  final payload = dataToString(signedPayload.data);
  final message = '${signedPayload.timestamp}.$payload';
  final expectedSignature = generateHMACSHA256(message, apiKey);

  return signedPayload.signature == expectedSignature;
}

// ============================================================================
// Cache Encryption (AES-GCM with PBKDF2 key derivation)
// ============================================================================

/// Derive an encryption key from API key using PBKDF2.
Uint8List deriveEncryptionKey(String apiKey, {int iterations = 100000}) {
  final salt = utf8.encode('flagkit-cache-v1');
  final keyDerivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2');

  final params = pc.Pbkdf2Parameters(
    Uint8List.fromList(salt),
    iterations,
    32, // 256 bits for AES-256
  );

  keyDerivator.init(params);
  return keyDerivator.process(Uint8List.fromList(utf8.encode(apiKey)));
}

/// Encrypted storage for cache data.
///
/// Uses AES-GCM encryption with a key derived from the API key via PBKDF2.
class EncryptedStorage {
  /// The encryption key (kept for potential future key rotation).
  // ignore: unused_field
  final encrypt.Key _key;

  final encrypt.Encrypter _encrypter;

  EncryptedStorage._internal(this._key, this._encrypter);

  /// Creates an encrypted storage instance.
  ///
  /// Derives the encryption key from [apiKey] using PBKDF2.
  factory EncryptedStorage.fromApiKey(String apiKey, {int iterations = 100000}) {
    final keyBytes = deriveEncryptionKey(apiKey, iterations: iterations);
    final key = encrypt.Key(keyBytes);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
    return EncryptedStorage._internal(key, encrypter);
  }

  /// Encrypts a string value.
  ///
  /// Returns the encrypted value as a base64 string.
  /// The IV is prepended to the encrypted data.
  String encryptString(String plaintext) {
    try {
      final iv = encrypt.IV.fromSecureRandom(12); // 96-bit IV for GCM
      final encrypted = _encrypter.encrypt(plaintext, iv: iv);

      // Combine IV and encrypted data
      final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
      combined.setRange(0, iv.bytes.length, iv.bytes);
      combined.setRange(iv.bytes.length, combined.length, encrypted.bytes);

      return base64Encode(combined);
    } catch (e) {
      throw SecurityException.encryptionFailed(e.toString(), e);
    }
  }

  /// Decrypts an encrypted string value.
  ///
  /// Expects the input to be a base64 string with IV prepended.
  String decryptString(String ciphertext) {
    try {
      final combined = base64Decode(ciphertext);

      // Extract IV and encrypted data
      final ivBytes = combined.sublist(0, 12);
      final encryptedBytes = combined.sublist(12);

      final iv = encrypt.IV(ivBytes);
      final encrypted = encrypt.Encrypted(encryptedBytes);

      return _encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw SecurityException.decryptionFailed(e.toString(), e);
    }
  }

  /// Encrypts a JSON-serializable object.
  String encryptJson(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    return encryptString(jsonString);
  }

  /// Decrypts a JSON object.
  Map<String, dynamic> decryptJson(String ciphertext) {
    final jsonString = decryptString(ciphertext);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }
}

// ============================================================================
// Key Rotation
// ============================================================================

/// Result of an API key rotation attempt.
class KeyRotationResult {
  /// Whether the rotation was successful.
  final bool success;

  /// The active API key after rotation.
  final String activeKey;

  /// Whether the primary key is active.
  final bool isPrimaryActive;

  /// Error message if rotation failed.
  final String? error;

  const KeyRotationResult({
    required this.success,
    required this.activeKey,
    required this.isPrimaryActive,
    this.error,
  });
}

/// Manages API key rotation with primary and secondary keys.
class KeyRotationManager {
  final String primaryApiKey;
  final String? secondaryApiKey;

  String _activeKey;
  bool _isPrimaryActive = true;

  KeyRotationManager({
    required this.primaryApiKey,
    this.secondaryApiKey,
  }) : _activeKey = primaryApiKey;

  /// Gets the currently active API key.
  String get activeKey => _activeKey;

  /// Returns true if the primary key is currently active.
  bool get isPrimaryActive => _isPrimaryActive;

  /// Returns true if a secondary key is configured.
  bool get hasSecondaryKey => secondaryApiKey != null;

  /// Attempts to rotate to the secondary key.
  ///
  /// Returns a [KeyRotationResult] indicating success or failure.
  /// This should be called when a 401 Unauthorized error is received.
  KeyRotationResult rotateToSecondary() {
    if (secondaryApiKey == null) {
      return KeyRotationResult(
        success: false,
        activeKey: _activeKey,
        isPrimaryActive: _isPrimaryActive,
        error: 'No secondary API key configured',
      );
    }

    if (!_isPrimaryActive) {
      return KeyRotationResult(
        success: false,
        activeKey: _activeKey,
        isPrimaryActive: _isPrimaryActive,
        error: 'Already using secondary key',
      );
    }

    _activeKey = secondaryApiKey!;
    _isPrimaryActive = false;

    return KeyRotationResult(
      success: true,
      activeKey: _activeKey,
      isPrimaryActive: false,
    );
  }

  /// Resets to the primary key.
  void resetToPrimary() {
    _activeKey = primaryApiKey;
    _isPrimaryActive = true;
  }

  /// Attempts to use a key, rotating on failure.
  ///
  /// If [statusCode] is 401 and a secondary key is available,
  /// rotates to the secondary key and returns true to indicate
  /// the request should be retried.
  bool shouldRotateOnError(int statusCode) {
    if (statusCode == 401 && _isPrimaryActive && secondaryApiKey != null) {
      rotateToSecondary();
      return true;
    }
    return false;
  }
}
