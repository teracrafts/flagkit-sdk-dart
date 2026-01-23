import 'error_code.dart';
import 'flagkit_exception.dart';

/// Configuration options for the FlagKit SDK.
class FlagKitOptions {
  static const defaultBaseUrl = 'https://api.flagkit.dev/api/v1';
  static const defaultPollingInterval = Duration(seconds: 30);
  static const defaultCacheTtl = Duration(seconds: 300);
  static const defaultMaxCacheSize = 1000;
  static const defaultEventBatchSize = 10;
  static const defaultEventFlushInterval = Duration(seconds: 30);
  static const defaultTimeout = Duration(seconds: 10);
  static const defaultRetryAttempts = 3;
  static const defaultCircuitBreakerThreshold = 5;
  static const defaultCircuitBreakerResetTimeout = Duration(seconds: 30);

  final String apiKey;
  final String baseUrl;
  final Duration pollingInterval;
  final Duration cacheTtl;
  final int maxCacheSize;
  final bool cacheEnabled;
  final int eventBatchSize;
  final Duration eventFlushInterval;
  final bool eventsEnabled;
  final Duration timeout;
  final int retryAttempts;
  final int circuitBreakerThreshold;
  final Duration circuitBreakerResetTimeout;
  final Map<String, dynamic>? bootstrap;

  FlagKitOptions({
    required this.apiKey,
    this.baseUrl = defaultBaseUrl,
    this.pollingInterval = defaultPollingInterval,
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
  });

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
        'Invalid API key format',
      );
    }

    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw FlagKitException.configError(
        ErrorCode.configInvalidBaseUrl,
        'Invalid base URL',
      );
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
  }

  static FlagKitOptionsBuilder builder(String apiKey) =>
      FlagKitOptionsBuilder(apiKey);
}

/// Builder for FlagKitOptions.
class FlagKitOptionsBuilder {
  final String _apiKey;
  String _baseUrl = FlagKitOptions.defaultBaseUrl;
  Duration _pollingInterval = FlagKitOptions.defaultPollingInterval;
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

  FlagKitOptionsBuilder(this._apiKey);

  FlagKitOptionsBuilder baseUrl(String url) {
    _baseUrl = url;
    return this;
  }

  FlagKitOptionsBuilder pollingInterval(Duration interval) {
    _pollingInterval = interval;
    return this;
  }

  FlagKitOptionsBuilder cacheTtl(Duration ttl) {
    _cacheTtl = ttl;
    return this;
  }

  FlagKitOptionsBuilder maxCacheSize(int size) {
    _maxCacheSize = size;
    return this;
  }

  FlagKitOptionsBuilder cacheEnabled(bool enabled) {
    _cacheEnabled = enabled;
    return this;
  }

  FlagKitOptionsBuilder eventBatchSize(int size) {
    _eventBatchSize = size;
    return this;
  }

  FlagKitOptionsBuilder eventFlushInterval(Duration interval) {
    _eventFlushInterval = interval;
    return this;
  }

  FlagKitOptionsBuilder eventsEnabled(bool enabled) {
    _eventsEnabled = enabled;
    return this;
  }

  FlagKitOptionsBuilder timeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  FlagKitOptionsBuilder retryAttempts(int attempts) {
    _retryAttempts = attempts;
    return this;
  }

  FlagKitOptionsBuilder circuitBreakerThreshold(int threshold) {
    _circuitBreakerThreshold = threshold;
    return this;
  }

  FlagKitOptionsBuilder circuitBreakerResetTimeout(Duration timeout) {
    _circuitBreakerResetTimeout = timeout;
    return this;
  }

  FlagKitOptionsBuilder bootstrap(Map<String, dynamic> data) {
    _bootstrap = data;
    return this;
  }

  FlagKitOptions build() {
    return FlagKitOptions(
      apiKey: _apiKey,
      baseUrl: _baseUrl,
      pollingInterval: _pollingInterval,
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
    );
  }
}
