import 'error_code.dart';

/// Exception for FlagKit SDK errors.
class FlagKitException implements Exception {
  final ErrorCode code;
  final String message;
  final Object? cause;

  FlagKitException(this.code, this.message, [this.cause]);

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
}
