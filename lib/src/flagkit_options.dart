import 'error/error_code.dart';
import 'error/flagkit_exception.dart';
import 'utils/security.dart';

/// Configuration for evaluation timing jitter to protect against cache timing attacks.
///
/// When enabled, adds a random delay before each flag evaluation to make
/// timing-based attacks more difficult.
class EvaluationJitterConfig {
  /// Whether jitter is enabled.
  final bool enabled;

  /// Minimum jitter delay in milliseconds.
  final int minMs;

  /// Maximum jitter delay in milliseconds.
  final int maxMs;

  /// Creates a new evaluation jitter configuration.
  ///
  /// [enabled] defaults to false for backward compatibility.
  /// [minMs] defaults to 5 milliseconds.
  /// [maxMs] defaults to 15 milliseconds.
  const EvaluationJitterConfig({
    this.enabled = false,
    this.minMs = 5,
    this.maxMs = 15,
  });

  /// Default configuration with jitter disabled.
  static const disabled = EvaluationJitterConfig();

  /// Default configuration with jitter enabled.
  static const defaultEnabled = EvaluationJitterConfig(enabled: true);
}

/// Configuration options for the FlagKit SDK.
///
/// Use [FlagKitOptions.builder] for a fluent construction API.
class FlagKitOptions {
  /// Default base URL for the FlagKit API.
  static const defaultBaseUrl = 'https://api.flagkit.dev/api/v1';

  /// Default polling interval (30 seconds).
  static const defaultPollingInterval = Duration(seconds: 30);

  /// Default cache TTL (5 minutes).
  static const defaultCacheTtl = Duration(seconds: 300);

  /// Default maximum cache size.
  static const defaultMaxCacheSize = 1000;

  /// Default event batch size.
  static const defaultEventBatchSize = 10;

  /// Default event flush interval (30 seconds).
  static const defaultEventFlushInterval = Duration(seconds: 30);

  /// Default request timeout (10 seconds per spec: 5s is common, 10s is safe).
  static const defaultTimeout = Duration(seconds: 10);

  /// Default retry attempts (3 per spec).
  static const defaultRetryAttempts = 3;

  /// Default circuit breaker threshold (5 failures per spec).
  static const defaultCircuitBreakerThreshold = 5;

  /// Default circuit breaker reset timeout (30 seconds per spec).
  static const defaultCircuitBreakerResetTimeout = Duration(seconds: 30);

  /// Default maximum persisted events.
  static const defaultMaxPersistedEvents = 10000;

  /// Default persistence flush interval (1 second).
  static const defaultPersistenceFlushInterval = Duration(milliseconds: 1000);

  /// The API key for authentication.
  final String apiKey;

  /// Base URL for the FlagKit API.
  final String baseUrl;

  /// Polling interval for flag updates.
  final Duration pollingInterval;

  /// Whether polling is enabled.
  final bool enablePolling;

  /// Cache time-to-live.
  final Duration cacheTtl;

  /// Maximum number of flags to cache.
  final int maxCacheSize;

  /// Whether caching is enabled.
  final bool cacheEnabled;

  /// Number of events to batch before sending.
  final int eventBatchSize;

  /// Interval between event flushes.
  final Duration eventFlushInterval;

  /// Whether event tracking is enabled.
  final bool eventsEnabled;

  /// Request timeout duration.
  final Duration timeout;

  /// Maximum retry attempts for failed requests.
  final int retryAttempts;

  /// Number of failures before circuit breaker opens.
  final int circuitBreakerThreshold;

  /// Duration before circuit breaker attempts recovery.
  final Duration circuitBreakerResetTimeout;

  /// Bootstrap data for offline initialization.
  final Map<String, dynamic>? bootstrap;

  /// Local development port (overrides baseUrl to localhost).
  final int? localPort;

  /// Whether to operate in offline mode.
  final bool offline;

  /// Secondary API key for automatic failover on 401 errors.
  final String? secondaryApiKey;

  /// Whether to throw SecurityException on PII detection instead of warning.
  ///
  /// When enabled, PII detected in context data that is not marked as
  /// a privateAttribute will throw a SecurityException.
  final bool strictPIIMode;

  /// Whether to enable request signing for POST requests.
  ///
  /// When enabled, all POST requests will include HMAC-SHA256 signatures
  /// in the X-Signature, X-Timestamp, and X-Key-Id headers.
  final bool enableRequestSigning;

  /// Whether to enable cache encryption.
  ///
  /// When enabled, cached flag data is encrypted using AES-GCM with
  /// a key derived from the API key via PBKDF2.
  final bool enableCacheEncryption;

  /// Whether to enable crash-resilient event persistence.
  ///
  /// When enabled, events are persisted to disk before being queued for sending,
  /// ensuring events are not lost in case of crashes or unexpected termination.
  final bool persistEvents;

  /// Directory path for event storage files.
  ///
  /// If not specified, uses the OS temp directory.
  final String? eventStoragePath;

  /// Maximum number of events to persist.
  ///
  /// When this limit is reached, oldest pending events will be dropped.
  final int maxPersistedEvents;

  /// Interval between disk flushes for persisted events.
  ///
  /// Events are buffered and flushed to disk at this interval.
  final Duration persistenceFlushInterval;

  /// Configuration for evaluation timing jitter.
  ///
  /// When enabled, adds random delay to flag evaluations to protect
  /// against cache timing attacks.
  final EvaluationJitterConfig evaluationJitter;

  /// Callback when SDK is ready.
  final void Function()? onReady;

  /// Callback when an error occurs.
  final void Function(Object error)? onError;

  /// Callback when flags are updated.
  final void Function(List<dynamic> flags)? onUpdate;

  /// Whether the SDK is configured for local development.
  bool get isLocal => localPort != null;

  /// Gets the effective base URL (accounting for local port).
  String get effectiveBaseUrl =>
      localPort != null ? 'http://localhost:$localPort/api/v1' : baseUrl;

  FlagKitOptions({
    required this.apiKey,
    this.baseUrl = defaultBaseUrl,
    this.pollingInterval = defaultPollingInterval,
    this.enablePolling = true,
    this.cacheTtl = defaultCacheTtl,
    this.maxCacheSize = defaultMaxCacheSize,
    this.cacheEnabled = true,
    this.eventBatchSize = defaultEventBatchSize,
    this.eventFlushInterval = defaultEventFlushInterval,
    this.eventsEnabled = true,
    this.timeout = defaultTimeout,
    this.retryAttempts = defaultRetryAttempts,
    this.circuitBreakerThreshold = defaultCircuitBreakerThreshold,
    this.circuitBreakerResetTimeout = defaultCircuitBreakerResetTimeout,
    this.bootstrap,
    this.localPort,
    this.offline = false,
    this.secondaryApiKey,
    this.strictPIIMode = false,
    this.enableRequestSigning = false,
    this.enableCacheEncryption = false,
    this.persistEvents = false,
    this.eventStoragePath,
    this.maxPersistedEvents = defaultMaxPersistedEvents,
    this.persistenceFlushInterval = defaultPersistenceFlushInterval,
    this.evaluationJitter = const EvaluationJitterConfig(),
    this.onReady,
    this.onError,
    this.onUpdate,
  });

  /// Validates the configuration options.
  ///
  /// Throws [FlagKitException] if configuration is invalid.
  /// Throws [SecurityException] if security constraints are violated.
  void validate() {
    if (apiKey.isEmpty) {
      throw FlagKitException.configError(
        ErrorCode.configInvalidApiKey,
        'API key is required',
      );
    }

    final validPrefixes = ['sdk_', 'srv_', 'cli_'];
    if (!validPrefixes.any((p) => apiKey.startsWith(p))) {
      throw FlagKitException.configError(
        ErrorCode.configInvalidApiKey,
        'Invalid API key format. Must start with sdk_, srv_, or cli_',
      );
    }

    // Validate secondary API key format if provided
    if (secondaryApiKey != null && secondaryApiKey!.isNotEmpty) {
      if (!validPrefixes.any((p) => secondaryApiKey!.startsWith(p))) {
        throw FlagKitException.configError(
          ErrorCode.configInvalidApiKey,
          'Invalid secondary API key format. Must start with sdk_, srv_, or cli_',
        );
      }
    }

    if (pollingInterval.inMilliseconds <= 0) {
      throw FlagKitException.configError(
        ErrorCode.configInvalidPollingInterval,
        'Polling interval must be positive',
      );
    }

    if (cacheTtl.inMilliseconds <= 0) {
      throw FlagKitException.configError(
        ErrorCode.configInvalidCacheTtl,
        'Cache TTL must be positive',
      );
    }

    if (baseUrl.isEmpty) {
      throw FlagKitException.configError(
        ErrorCode.configInvalidBaseUrl,
        'Base URL cannot be empty',
      );
    }

    if (retryAttempts < 0) {
      throw FlagKitException.configError(
        ErrorCode.configInvalidInterval,
        'Retry attempts cannot be negative',
      );
    }

    if (circuitBreakerThreshold <= 0) {
      throw FlagKitException.configError(
        ErrorCode.configInvalidInterval,
        'Circuit breaker threshold must be positive',
      );
    }

    // Security validation: localPort in production
    validateLocalPortSecurity(localPort);
  }

  /// Creates a copy of this options with the given fields replaced.
  FlagKitOptions copyWith({
    String? apiKey,
    String? baseUrl,
    Duration? pollingInterval,
    bool? enablePolling,
    Duration? cacheTtl,
    int? maxCacheSize,
    bool? cacheEnabled,
    int? eventBatchSize,
    Duration? eventFlushInterval,
    bool? eventsEnabled,
    Duration? timeout,
    int? retryAttempts,
    int? circuitBreakerThreshold,
    Duration? circuitBreakerResetTimeout,
    Map<String, dynamic>? bootstrap,
    int? localPort,
    bool? offline,
    String? secondaryApiKey,
    bool? strictPIIMode,
    bool? enableRequestSigning,
    bool? enableCacheEncryption,
    bool? persistEvents,
    String? eventStoragePath,
    int? maxPersistedEvents,
    Duration? persistenceFlushInterval,
    EvaluationJitterConfig? evaluationJitter,
    void Function()? onReady,
    void Function(Object error)? onError,
    void Function(List<dynamic> flags)? onUpdate,
  }) {
    return FlagKitOptions(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      pollingInterval: pollingInterval ?? this.pollingInterval,
      enablePolling: enablePolling ?? this.enablePolling,
      cacheTtl: cacheTtl ?? this.cacheTtl,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      cacheEnabled: cacheEnabled ?? this.cacheEnabled,
      eventBatchSize: eventBatchSize ?? this.eventBatchSize,
      eventFlushInterval: eventFlushInterval ?? this.eventFlushInterval,
      eventsEnabled: eventsEnabled ?? this.eventsEnabled,
      timeout: timeout ?? this.timeout,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      circuitBreakerThreshold:
          circuitBreakerThreshold ?? this.circuitBreakerThreshold,
      circuitBreakerResetTimeout:
          circuitBreakerResetTimeout ?? this.circuitBreakerResetTimeout,
      bootstrap: bootstrap ?? this.bootstrap,
      localPort: localPort ?? this.localPort,
      offline: offline ?? this.offline,
      secondaryApiKey: secondaryApiKey ?? this.secondaryApiKey,
      strictPIIMode: strictPIIMode ?? this.strictPIIMode,
      enableRequestSigning: enableRequestSigning ?? this.enableRequestSigning,
      enableCacheEncryption:
          enableCacheEncryption ?? this.enableCacheEncryption,
      persistEvents: persistEvents ?? this.persistEvents,
      eventStoragePath: eventStoragePath ?? this.eventStoragePath,
      maxPersistedEvents: maxPersistedEvents ?? this.maxPersistedEvents,
      persistenceFlushInterval:
          persistenceFlushInterval ?? this.persistenceFlushInterval,
      evaluationJitter: evaluationJitter ?? this.evaluationJitter,
      onReady: onReady ?? this.onReady,
      onError: onError ?? this.onError,
      onUpdate: onUpdate ?? this.onUpdate,
    );
  }

  /// Creates a builder for constructing FlagKitOptions.
  static FlagKitOptionsBuilder builder(String apiKey) =>
      FlagKitOptionsBuilder(apiKey);
}

/// Builder for FlagKitOptions.
///
/// Provides a fluent API for constructing FlagKitOptions.
class FlagKitOptionsBuilder {
  final String _apiKey;
  String _baseUrl = FlagKitOptions.defaultBaseUrl;
  Duration _pollingInterval = FlagKitOptions.defaultPollingInterval;
  bool _enablePolling = true;
  Duration _cacheTtl = FlagKitOptions.defaultCacheTtl;
  int _maxCacheSize = FlagKitOptions.defaultMaxCacheSize;
  bool _cacheEnabled = true;
  int _eventBatchSize = FlagKitOptions.defaultEventBatchSize;
  Duration _eventFlushInterval = FlagKitOptions.defaultEventFlushInterval;
  bool _eventsEnabled = true;
  Duration _timeout = FlagKitOptions.defaultTimeout;
  int _retryAttempts = FlagKitOptions.defaultRetryAttempts;
  int _circuitBreakerThreshold = FlagKitOptions.defaultCircuitBreakerThreshold;
  Duration _circuitBreakerResetTimeout =
      FlagKitOptions.defaultCircuitBreakerResetTimeout;
  Map<String, dynamic>? _bootstrap;
  int? _localPort;
  bool _offline = false;
  String? _secondaryApiKey;
  bool _strictPIIMode = false;
  bool _enableRequestSigning = false;
  bool _enableCacheEncryption = false;
  bool _persistEvents = false;
  String? _eventStoragePath;
  int _maxPersistedEvents = FlagKitOptions.defaultMaxPersistedEvents;
  Duration _persistenceFlushInterval = FlagKitOptions.defaultPersistenceFlushInterval;
  EvaluationJitterConfig _evaluationJitter = const EvaluationJitterConfig();
  void Function()? _onReady;
  void Function(Object error)? _onError;
  void Function(List<dynamic> flags)? _onUpdate;

  /// Creates a builder with the required API key.
  FlagKitOptionsBuilder(this._apiKey);

  /// Sets the base URL for the FlagKit API.
  FlagKitOptionsBuilder baseUrl(String url) {
    _baseUrl = url;
    return this;
  }

  /// Sets the polling interval for flag updates.
  FlagKitOptionsBuilder pollingInterval(Duration interval) {
    _pollingInterval = interval;
    return this;
  }

  /// Sets whether polling is enabled.
  FlagKitOptionsBuilder enablePolling(bool enabled) {
    _enablePolling = enabled;
    return this;
  }

  /// Sets the cache time-to-live.
  FlagKitOptionsBuilder cacheTtl(Duration ttl) {
    _cacheTtl = ttl;
    return this;
  }

  /// Sets the maximum cache size.
  FlagKitOptionsBuilder maxCacheSize(int size) {
    _maxCacheSize = size;
    return this;
  }

  /// Sets whether caching is enabled.
  FlagKitOptionsBuilder cacheEnabled(bool enabled) {
    _cacheEnabled = enabled;
    return this;
  }

  /// Sets the event batch size.
  FlagKitOptionsBuilder eventBatchSize(int size) {
    _eventBatchSize = size;
    return this;
  }

  /// Sets the event flush interval.
  FlagKitOptionsBuilder eventFlushInterval(Duration interval) {
    _eventFlushInterval = interval;
    return this;
  }

  /// Sets whether events are enabled.
  FlagKitOptionsBuilder eventsEnabled(bool enabled) {
    _eventsEnabled = enabled;
    return this;
  }

  /// Sets the request timeout.
  FlagKitOptionsBuilder timeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  /// Sets the maximum retry attempts.
  FlagKitOptionsBuilder retryAttempts(int attempts) {
    _retryAttempts = attempts;
    return this;
  }

  /// Sets the circuit breaker failure threshold.
  FlagKitOptionsBuilder circuitBreakerThreshold(int threshold) {
    _circuitBreakerThreshold = threshold;
    return this;
  }

  /// Sets the circuit breaker reset timeout.
  FlagKitOptionsBuilder circuitBreakerResetTimeout(Duration timeout) {
    _circuitBreakerResetTimeout = timeout;
    return this;
  }

  /// Sets bootstrap data for offline initialization.
  FlagKitOptionsBuilder bootstrap(Map<String, dynamic> data) {
    _bootstrap = data;
    return this;
  }

  /// Sets the local development port.
  FlagKitOptionsBuilder localPort(int port) {
    _localPort = port;
    return this;
  }

  /// Sets offline mode.
  FlagKitOptionsBuilder offline(bool offline) {
    _offline = offline;
    return this;
  }

  /// Sets the secondary API key for automatic failover.
  FlagKitOptionsBuilder secondaryApiKey(String key) {
    _secondaryApiKey = key;
    return this;
  }

  /// Sets strict PII mode.
  ///
  /// When enabled, throws SecurityException on PII detection
  /// instead of logging a warning.
  FlagKitOptionsBuilder strictPIIMode(bool enabled) {
    _strictPIIMode = enabled;
    return this;
  }

  /// Enables request signing for POST requests.
  FlagKitOptionsBuilder enableRequestSigning(bool enabled) {
    _enableRequestSigning = enabled;
    return this;
  }

  /// Enables cache encryption.
  FlagKitOptionsBuilder enableCacheEncryption(bool enabled) {
    _enableCacheEncryption = enabled;
    return this;
  }

  /// Enables crash-resilient event persistence.
  FlagKitOptionsBuilder persistEvents(bool enabled) {
    _persistEvents = enabled;
    return this;
  }

  /// Sets the event storage path.
  FlagKitOptionsBuilder eventStoragePath(String path) {
    _eventStoragePath = path;
    return this;
  }

  /// Sets the maximum number of persisted events.
  FlagKitOptionsBuilder maxPersistedEvents(int max) {
    _maxPersistedEvents = max;
    return this;
  }

  /// Sets the persistence flush interval.
  FlagKitOptionsBuilder persistenceFlushInterval(Duration interval) {
    _persistenceFlushInterval = interval;
    return this;
  }

  /// Sets the evaluation jitter configuration.
  ///
  /// Use this to protect against cache timing attacks by adding
  /// random delay to flag evaluations.
  FlagKitOptionsBuilder evaluationJitter(EvaluationJitterConfig config) {
    _evaluationJitter = config;
    return this;
  }

  /// Sets the callback for when SDK is ready.
  FlagKitOptionsBuilder onReady(void Function() callback) {
    _onReady = callback;
    return this;
  }

  /// Sets the callback for errors.
  FlagKitOptionsBuilder onError(void Function(Object error) callback) {
    _onError = callback;
    return this;
  }

  /// Sets the callback for flag updates.
  FlagKitOptionsBuilder onUpdate(void Function(List<dynamic> flags) callback) {
    _onUpdate = callback;
    return this;
  }

  /// Builds the FlagKitOptions.
  FlagKitOptions build() {
    return FlagKitOptions(
      apiKey: _apiKey,
      baseUrl: _baseUrl,
      pollingInterval: _pollingInterval,
      enablePolling: _enablePolling,
      cacheTtl: _cacheTtl,
      maxCacheSize: _maxCacheSize,
      cacheEnabled: _cacheEnabled,
      eventBatchSize: _eventBatchSize,
      eventFlushInterval: _eventFlushInterval,
      eventsEnabled: _eventsEnabled,
      timeout: _timeout,
      retryAttempts: _retryAttempts,
      circuitBreakerThreshold: _circuitBreakerThreshold,
      circuitBreakerResetTimeout: _circuitBreakerResetTimeout,
      bootstrap: _bootstrap,
      localPort: _localPort,
      offline: _offline,
      secondaryApiKey: _secondaryApiKey,
      strictPIIMode: _strictPIIMode,
      enableRequestSigning: _enableRequestSigning,
      enableCacheEncryption: _enableCacheEncryption,
      persistEvents: _persistEvents,
      eventStoragePath: _eventStoragePath,
      maxPersistedEvents: _maxPersistedEvents,
      persistenceFlushInterval: _persistenceFlushInterval,
      evaluationJitter: _evaluationJitter,
      onReady: _onReady,
      onError: _onError,
      onUpdate: _onUpdate,
    );
  }
}
