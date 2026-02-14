/// Error codes for FlagKit SDK errors.
enum ErrorCode {
  // Initialization errors
  initFailed('INIT_FAILED'),
  initTimeout('INIT_TIMEOUT'),
  initAlreadyInitialized('INIT_ALREADY_INITIALIZED'),
  initNotInitialized('INIT_NOT_INITIALIZED'),

  // Authentication errors
  authInvalidKey('AUTH_INVALID_KEY'),
  authExpiredKey('AUTH_EXPIRED_KEY'),
  authMissingKey('AUTH_MISSING_KEY'),
  authUnauthorized('AUTH_UNAUTHORIZED'),
  authPermissionDenied('AUTH_PERMISSION_DENIED'),
  authIpRestricted('AUTH_IP_RESTRICTED'),
  authOrganizationRequired('AUTH_ORGANIZATION_REQUIRED'),
  authSubscriptionSuspended('AUTH_SUBSCRIPTION_SUSPENDED'),

  // Network errors
  networkError('NETWORK_ERROR'),
  networkTimeout('NETWORK_TIMEOUT'),
  networkRetryLimit('NETWORK_RETRY_LIMIT'),
  networkServiceUnavailable('NETWORK_SERVICE_UNAVAILABLE'),

  // HTTP errors
  httpBadRequest('HTTP_BAD_REQUEST'),
  httpUnauthorized('HTTP_UNAUTHORIZED'),
  httpForbidden('HTTP_FORBIDDEN'),
  httpNotFound('HTTP_NOT_FOUND'),
  httpRateLimited('HTTP_RATE_LIMITED'),
  httpServerError('HTTP_SERVER_ERROR'),
  httpTimeout('HTTP_TIMEOUT'),
  httpNetworkError('HTTP_NETWORK_ERROR'),
  httpInvalidResponse('HTTP_INVALID_RESPONSE'),
  httpCircuitOpen('HTTP_CIRCUIT_OPEN'),

  // Evaluation errors
  evalFlagNotFound('EVAL_FLAG_NOT_FOUND'),
  evalTypeMismatch('EVAL_TYPE_MISMATCH'),
  evalInvalidKey('EVAL_INVALID_KEY'),
  evalInvalidValue('EVAL_INVALID_VALUE'),
  evalDisabled('EVAL_DISABLED'),
  evalError('EVAL_ERROR'),
  evaluationFailed('EVALUATION_FAILED'),
  evalContextError('EVAL_CONTEXT_ERROR'),
  evalDefaultUsed('EVAL_DEFAULT_USED'),
  evalStaleValue('EVAL_STALE_VALUE'),
  evalCacheMiss('EVAL_CACHE_MISS'),
  evalNetworkError('EVAL_NETWORK_ERROR'),
  evalParseError('EVAL_PARSE_ERROR'),
  evalTimeoutError('EVAL_TIMEOUT_ERROR'),

  // Cache errors
  cacheReadError('CACHE_READ_ERROR'),
  cacheWriteError('CACHE_WRITE_ERROR'),
  cacheInvalidData('CACHE_INVALID_DATA'),
  cacheExpired('CACHE_EXPIRED'),
  cacheStorageError('CACHE_STORAGE_ERROR'),

  // Event errors
  eventQueueFull('EVENT_QUEUE_FULL'),
  eventInvalidType('EVENT_INVALID_TYPE'),
  eventInvalidData('EVENT_INVALID_DATA'),
  eventSendFailed('EVENT_SEND_FAILED'),
  eventFlushFailed('EVENT_FLUSH_FAILED'),
  eventFlushTimeout('EVENT_FLUSH_TIMEOUT'),

  // Circuit breaker errors
  circuitOpen('CIRCUIT_OPEN'),

  // SDK lifecycle errors
  sdkNotInitialized('SDK_NOT_INITIALIZED'),
  sdkAlreadyInitialized('SDK_ALREADY_INITIALIZED'),
  sdkNotReady('SDK_NOT_READY'),

  // Configuration errors
  configInvalidUrl('CONFIG_INVALID_URL'),
  configInvalidInterval('CONFIG_INVALID_INTERVAL'),
  configMissingRequired('CONFIG_MISSING_REQUIRED'),
  configInvalidApiKey('CONFIG_INVALID_API_KEY'),
  configInvalidBaseUrl('CONFIG_INVALID_BASE_URL'),
  configInvalidPollingInterval('CONFIG_INVALID_POLLING_INTERVAL'),
  configInvalidCacheTtl('CONFIG_INVALID_CACHE_TTL'),

  // Streaming errors (1800-1899)
  streamingTokenInvalid('STREAMING_TOKEN_INVALID'),
  streamingTokenExpired('STREAMING_TOKEN_EXPIRED'),
  streamingSubscriptionSuspended('STREAMING_SUBSCRIPTION_SUSPENDED'),
  streamingConnectionLimit('STREAMING_CONNECTION_LIMIT'),
  streamingUnavailable('STREAMING_UNAVAILABLE'),

  // Security errors
  securityPIIDetected('SECURITY_PII_DETECTED'),
  securityEncryptionFailed('SECURITY_ENCRYPTION_FAILED'),
  securityDecryptionFailed('SECURITY_DECRYPTION_FAILED'),
  securityKeyRotationFailed('SECURITY_KEY_ROTATION_FAILED'),
  securityBootstrapVerificationFailed('SECURITY_BOOTSTRAP_VERIFICATION_FAILED');

  const ErrorCode(this.code);

  final String code;

  bool get isRecoverable => _recoverableCodes.contains(this);

  static const _recoverableCodes = {
    ErrorCode.networkError,
    ErrorCode.networkTimeout,
    ErrorCode.networkRetryLimit,
    ErrorCode.networkServiceUnavailable,
    ErrorCode.circuitOpen,
    ErrorCode.httpCircuitOpen,
    ErrorCode.httpTimeout,
    ErrorCode.httpNetworkError,
    ErrorCode.httpServerError,
    ErrorCode.httpRateLimited,
    ErrorCode.cacheExpired,
    ErrorCode.evalStaleValue,
    ErrorCode.evalCacheMiss,
    ErrorCode.evalNetworkError,
    ErrorCode.eventSendFailed,
    ErrorCode.streamingTokenInvalid,
    ErrorCode.streamingTokenExpired,
    ErrorCode.streamingConnectionLimit,
    ErrorCode.streamingUnavailable,
  };
}
