/// Security utilities for FlagKit SDK.

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

  final piiFields = detectPotentialPII(data);

  if (piiFields.isNotEmpty) {
    final fieldsStr = piiFields.join(', ');
    final advice = dataType == 'context'
        ? 'Consider adding these to privateAttributes.'
        : 'Consider removing sensitive data from events.';

    logger.warn(
      '[FlagKit Security] Potential PII detected in $dataType data: $fieldsStr. $advice',
    );
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

  /// Creates a security configuration.
  const SecurityConfig({
    this.warnOnPotentialPII = true,
    this.warnOnServerKeyInBrowser = true,
    this.additionalPIIPatterns = const [],
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
    );
  }

  /// Creates a copy with the given fields replaced.
  SecurityConfig copyWith({
    bool? warnOnPotentialPII,
    bool? warnOnServerKeyInBrowser,
    List<String>? additionalPIIPatterns,
  }) {
    return SecurityConfig(
      warnOnPotentialPII: warnOnPotentialPII ?? this.warnOnPotentialPII,
      warnOnServerKeyInBrowser:
          warnOnServerKeyInBrowser ?? this.warnOnServerKeyInBrowser,
      additionalPIIPatterns:
          additionalPIIPatterns ?? this.additionalPIIPatterns,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityConfig &&
          runtimeType == other.runtimeType &&
          warnOnPotentialPII == other.warnOnPotentialPII &&
          warnOnServerKeyInBrowser == other.warnOnServerKeyInBrowser &&
          _listEquals(additionalPIIPatterns, other.additionalPIIPatterns);

  @override
  int get hashCode =>
      warnOnPotentialPII.hashCode ^
      warnOnServerKeyInBrowser.hashCode ^
      additionalPIIPatterns.hashCode;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
