import 'error_code.dart';
import 'error_sanitizer.dart';

/// Global error sanitizer configuration.
///
/// This can be set by the SDK to apply error sanitization globally.
ErrorSanitizationConfig _globalErrorSanitizationConfig =
    const ErrorSanitizationConfig();

/// Sets the global error sanitization configuration.
///
/// This is typically called during SDK initialization.
void setGlobalErrorSanitizationConfig(ErrorSanitizationConfig config) {
  _globalErrorSanitizationConfig = config;
}

/// Gets the current global error sanitization configuration.
ErrorSanitizationConfig getGlobalErrorSanitizationConfig() {
  return _globalErrorSanitizationConfig;
}

/// Exception for FlagKit SDK errors.
class FlagKitException implements Exception {
  final ErrorCode code;
  final String _rawMessage;
  final Object? cause;

  /// The original unsanitized message (only available if preserveOriginal is enabled).
  final String? originalMessage;

  FlagKitException(this.code, String message, [this.cause])
      : _rawMessage = message,
        originalMessage = _globalErrorSanitizationConfig.preserveOriginal
            ? message
            : null;

  /// Gets the sanitized error message.
  String get message {
    if (!_globalErrorSanitizationConfig.enabled) {
      return _rawMessage;
    }
    return ErrorSanitizer(_globalErrorSanitizationConfig)
        .sanitizeMessage(_rawMessage);
  }

  @override
  String toString() => '[${code.code}] $message';

  bool get isRecoverable => code.isRecoverable;

  bool get isConfigError => const {
        ErrorCode.configInvalidUrl,
        ErrorCode.configInvalidInterval,
        ErrorCode.configMissingRequired,
        ErrorCode.configInvalidApiKey,
        ErrorCode.configInvalidBaseUrl,
        ErrorCode.configInvalidPollingInterval,
        ErrorCode.configInvalidCacheTtl,
      }.contains(code);

  bool get isNetworkError => const {
        ErrorCode.networkError,
        ErrorCode.networkTimeout,
        ErrorCode.networkRetryLimit,
        ErrorCode.httpBadRequest,
        ErrorCode.httpUnauthorized,
        ErrorCode.httpForbidden,
        ErrorCode.httpNotFound,
        ErrorCode.httpRateLimited,
        ErrorCode.httpServerError,
        ErrorCode.httpTimeout,
        ErrorCode.httpNetworkError,
        ErrorCode.httpInvalidResponse,
        ErrorCode.httpCircuitOpen,
      }.contains(code);

  bool get isEvaluationError => const {
        ErrorCode.evalFlagNotFound,
        ErrorCode.evalTypeMismatch,
        ErrorCode.evalInvalidKey,
        ErrorCode.evalInvalidValue,
        ErrorCode.evalDisabled,
        ErrorCode.evalError,
        ErrorCode.evaluationFailed,
        ErrorCode.evalContextError,
        ErrorCode.evalDefaultUsed,
        ErrorCode.evalStaleValue,
        ErrorCode.evalCacheMiss,
        ErrorCode.evalNetworkError,
        ErrorCode.evalParseError,
        ErrorCode.evalTimeoutError,
      }.contains(code);

  bool get isSdkError => const {
        ErrorCode.sdkNotInitialized,
        ErrorCode.sdkAlreadyInitialized,
        ErrorCode.sdkNotReady,
        ErrorCode.initFailed,
        ErrorCode.initTimeout,
        ErrorCode.initAlreadyInitialized,
        ErrorCode.initNotInitialized,
      }.contains(code);

  bool get isSecurityError => const {
        ErrorCode.securityLocalPortInProduction,
        ErrorCode.securityPIIDetected,
        ErrorCode.securityEncryptionFailed,
        ErrorCode.securityDecryptionFailed,
        ErrorCode.securityKeyRotationFailed,
        ErrorCode.securityBootstrapVerificationFailed,
      }.contains(code);

  static FlagKitException configError(ErrorCode code, String message) {
    return FlagKitException(code, message);
  }

  static FlagKitException networkError(ErrorCode code, String message,
      [Object? cause]) {
    return FlagKitException(code, message, cause);
  }

  static FlagKitException evaluationError(ErrorCode code, String message) {
    return FlagKitException(code, message);
  }

  static FlagKitException sdkError(ErrorCode code, String message) {
    return FlagKitException(code, message);
  }

  static FlagKitException notInitialized() {
    return FlagKitException(ErrorCode.sdkNotInitialized,
        'SDK not initialized. Call FlagKit.initialize() first.');
  }

  static FlagKitException alreadyInitialized() {
    return FlagKitException(
        ErrorCode.sdkAlreadyInitialized, 'SDK already initialized.');
  }

  static FlagKitException securityError(ErrorCode code, String message,
      [Object? cause]) {
    return FlagKitException(code, message, cause);
  }
}

/// Exception thrown for security-related violations.
///
/// This is a specialized exception for security issues like:
/// - Using localPort in production environment
/// - PII detected in strict mode
/// - Encryption/decryption failures
class SecurityException extends FlagKitException {
  SecurityException(super.code, super.message, [super.cause]);

  /// Creates a security exception for local port usage in production.
  factory SecurityException.localPortInProduction() {
    return SecurityException(
      ErrorCode.securityLocalPortInProduction,
      'localPort cannot be used in production environment. '
          'Set DART_ENV to a value other than "production" for local development.',
    );
  }

  /// Creates a security exception for PII detection in strict mode.
  factory SecurityException.piiDetected(List<String> fields) {
    return SecurityException(
      ErrorCode.securityPIIDetected,
      'Potential PII detected in strict mode: ${fields.join(', ')}. '
          'Add these fields to privateAttributes or disable strictPIIMode.',
    );
  }

  /// Creates a security exception for encryption failures.
  factory SecurityException.encryptionFailed(String message, [Object? cause]) {
    return SecurityException(
      ErrorCode.securityEncryptionFailed,
      'Encryption failed: $message',
      cause,
    );
  }

  /// Creates a security exception for decryption failures.
  factory SecurityException.decryptionFailed(String message, [Object? cause]) {
    return SecurityException(
      ErrorCode.securityDecryptionFailed,
      'Decryption failed: $message',
      cause,
    );
  }

  /// Creates a security exception for bootstrap verification failures.
  factory SecurityException.bootstrapVerificationFailed(String message) {
    return SecurityException(
      ErrorCode.securityBootstrapVerificationFailed,
      'Bootstrap verification failed: $message',
    );
  }
}
