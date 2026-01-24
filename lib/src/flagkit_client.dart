import 'dart:async';
import 'dart:math';

import 'core/cache.dart';
import 'core/context_manager.dart';
import 'core/event_queue.dart';
import 'core/polling_manager.dart';
import 'error/error_code.dart';
import 'error/flagkit_exception.dart';
import 'http/circuit_breaker.dart';
import 'types/evaluation_context.dart';
import 'types/evaluation_reason.dart';
import 'types/evaluation_result.dart';
import 'types/flag_state.dart';
import 'types/flag_value.dart';
import 'flagkit_options.dart';
import 'http/http_client.dart';

/// Main FlagKit client for feature flag evaluation.
///
/// Provides methods for evaluating feature flags, managing user context,
/// tracking events, and handling background polling for flag updates.
///
/// Example usage:
/// ```dart
/// final client = FlagKitClient(FlagKitOptions(apiKey: 'sdk_xxx'));
/// await client.initialize();
///
/// final darkMode = client.getBooleanValue('dark-mode', false);
/// ```
class FlagKitClient {
  /// The configuration options for this client.
  final FlagKitOptions options;

  final FlagKitHttpClient _httpClient;
  final FlagCache _cache;
  final ContextManager _contextManager;
  EventQueue? _eventQueue;
  PollingManager? _pollingManager;

  final Completer<void> _readyCompleter = Completer<void>();
  bool _initialized = false;
  bool _closed = false;
  String? _environmentId;
  String? _lastUpdatedAt;
  String? _projectId;
  String? _organizationId;

  /// Callback invoked when flags are updated.
  final void Function(List<FlagState>)? onFlagsUpdated;

  /// Callback invoked when an error occurs.
  final void Function(FlagKitException)? onError;

  /// Callback invoked when the SDK is ready.
  final void Function()? onReady;

  /// Creates a new FlagKit client with the given options.
  ///
  /// The client must be initialized before use by calling [initialize].
  /// Alternatively, use [FlagKit.initialize] for automatic initialization.
  FlagKitClient(
    this.options, {
    this.onFlagsUpdated,
    this.onError,
    this.onReady,
  })  : _httpClient = FlagKitHttpClient(options, localPort: options.localPort),
        _cache = FlagCache(
          maxSize: options.maxCacheSize,
          ttl: options.cacheTtl,
        ),
        _contextManager = ContextManager() {
    options.validate();

    // Load bootstrap data
    if (options.bootstrap != null) {
      for (final entry in options.bootstrap!.entries) {
        final flag = FlagState(
          key: entry.key,
          value: FlagValue.from(entry.value),
          enabled: true,
          version: 0,
        );
        _cache.set(entry.key, flag);
      }
    }
  }

  /// Returns true if the SDK has been initialized.
  bool get isInitialized => _initialized;

  /// Returns true if the SDK is ready for flag evaluation.
  bool get isReady => _initialized && !_closed;

  /// Returns true if the SDK has been closed.
  bool get isClosed => _closed;

  /// Returns true if the SDK is in offline mode.
  bool get isOffline => options.offline;

  /// Gets the current global context.
  EvaluationContext? get globalContext => _contextManager.context;

  /// Gets the environment ID, if available.
  String? get environmentId => _environmentId;

  /// Gets the project ID, if available.
  String? get projectId => _projectId;

  /// Gets the organization ID, if available.
  String? get organizationId => _organizationId;

  /// Gets the last update timestamp, if available.
  String? get lastUpdatedAt => _lastUpdatedAt;

  /// Gets the number of cached flags.
  int get flagCount => _cache.length;

  /// Gets the circuit breaker for monitoring.
  CircuitBreaker get circuitBreaker => _httpClient.circuitBreaker;

  /// Gets the session ID.
  String get sessionId => _generateSessionId();

  // Lazy session ID generation
  String? _sessionId;
  String _generateSessionId() {
    _sessionId ??= '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999).toString().padLeft(6, '0')}';
    return _sessionId!;
  }

  /// Initializes the SDK by fetching flag configurations from the server.
  ///
  /// This must be called before evaluating flags unless bootstrap data is provided.
  /// If [options.offline] is true, initialization will use bootstrap data only.
  Future<void> initialize() async {
    if (_closed) {
      throw FlagKitException.sdkError(
        ErrorCode.sdkNotInitialized,
        'SDK has been closed',
      );
    }

    if (_initialized) {
      return;
    }

    // Handle offline mode
    if (options.offline) {
      _initialized = true;

      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }

      onReady?.call();
      options.onReady?.call();
      return;
    }

    try {
      final response = await _httpClient.get(
        '/sdk/init',
        (json) => _InitResponse.fromJson(json),
      );

      for (final flag in response.flags) {
        _cache.set(flag.key, flag);
      }

      _environmentId = response.environmentId;
      _projectId = response.projectId;
      _organizationId = response.organizationId;
      _lastUpdatedAt = response.serverTime;

      // Initialize event queue if events are enabled
      if (options.eventsEnabled) {
        _initializeEventQueue();
      }

      // Initialize polling manager if enabled
      if (options.enablePolling) {
        _initializePollingManager();
      }

      _initialized = true;

      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }

      onReady?.call();
      options.onReady?.call();
    } catch (error) {
      final exception = error is FlagKitException
          ? error
          : FlagKitException.sdkError(
              ErrorCode.initFailed,
              'Failed to initialize SDK: $error',
            );

      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(exception);
      }

      onError?.call(exception);
      options.onError?.call(exception);
      rethrow;
    }
  }

  /// Waits for the SDK to be ready.
  ///
  /// Returns immediately if already initialized.
  /// Throws if initialization failed.
  Future<void> waitForReady() {
    if (_initialized) {
      return Future.value();
    }
    return _readyCompleter.future;
  }

  /// Identifies a user with optional attributes.
  ///
  /// Sets the global context with the user's information.
  void identify(String userId, [Map<String, dynamic>? attributes]) {
    _contextManager.identify(userId, attributes);
    _eventQueue?.setUserId(userId);
    _eventQueue?.trackIdentify(userId, attributes);
  }

  /// Sets the global evaluation context.
  void setContext(EvaluationContext context) {
    _contextManager.setContext(context);
    _eventQueue?.setUserId(context.userId);
  }

  /// Gets the current global context.
  EvaluationContext? getContext() {
    return _contextManager.getContext();
  }

  /// Clears the global evaluation context.
  void clearContext() {
    _contextManager.clearContext();
    _eventQueue?.setUserId(null);
  }

  /// Resets to anonymous state.
  void reset() {
    _contextManager.reset();
    _eventQueue?.setUserId(null);
  }

  /// Evaluates a flag synchronously using cached values.
  ///
  /// Returns the cached flag value or a default result if not found.
  EvaluationResult evaluate(String flagKey, [EvaluationContext? context]) {
    _ensureNotClosed();

    final flag = _cache.get(flagKey);

    if (flag == null) {
      return EvaluationResult.defaultResult(
        flagKey,
        FlagValue(null),
        EvaluationReason.flagNotFound,
      );
    }

    if (!flag.enabled) {
      return EvaluationResult(
        flagKey: flagKey,
        value: flag.value,
        enabled: false,
        reason: EvaluationReason.disabled,
        version: flag.version,
      );
    }

    return EvaluationResult(
      flagKey: flagKey,
      value: flag.value,
      enabled: flag.enabled,
      reason: EvaluationReason.cached,
      version: flag.version,
    );
  }

  /// Evaluates a flag asynchronously, fetching from server if needed.
  ///
  /// Falls back to cached value on network errors.
  Future<EvaluationResult> evaluateAsync(String flagKey,
      [EvaluationContext? context]) async {
    _ensureNotClosed();

    final resolvedContext = _contextManager.resolveContextForServer(context);

    try {
      final response = await _httpClient.post(
        '/sdk/evaluate',
        {
          'flagKey': flagKey,
          if (resolvedContext != null) 'context': resolvedContext.toJson(),
        },
        (json) => _EvaluateResponse.fromJson(json),
      );

      final result = EvaluationResult(
        flagKey: response.flagKey,
        value: response.value,
        enabled: response.enabled,
        reason: response.reason,
        version: response.version,
        variationId: response.variationId,
        ruleId: response.ruleId,
        segmentId: response.segmentId,
      );

      // Update cache with server response
      _cache.set(
        flagKey,
        FlagState(
          key: flagKey,
          value: response.value,
          enabled: response.enabled,
          version: response.version,
        ),
      );

      return result;
    } catch (error) {
      // Fall back to cache
      final cachedResult = evaluate(flagKey, context);

      // If we have a cached value, return it with stale indicator
      if (cachedResult.reason != EvaluationReason.flagNotFound) {
        return cachedResult.copyWith(reason: EvaluationReason.staleCache);
      }

      return cachedResult;
    }
  }

  /// Evaluates all flags and returns a map of results.
  Future<Map<String, EvaluationResult>> evaluateAll([EvaluationContext? context]) async {
    _ensureNotClosed();

    final resolvedContext = _contextManager.resolveContextForServer(context);

    try {
      final response = await _httpClient.post(
        '/sdk/evaluate/all',
        {
          if (resolvedContext != null) 'context': resolvedContext.toJson(),
        },
        (json) => _BatchEvaluateResponse.fromJson(json),
      );

      final results = <String, EvaluationResult>{};

      for (final entry in response.flags.entries) {
        results[entry.key] = EvaluationResult(
          flagKey: entry.key,
          value: entry.value.value,
          enabled: entry.value.enabled,
          reason: entry.value.reason,
          version: entry.value.version,
          variationId: entry.value.variationId,
          ruleId: entry.value.ruleId,
          segmentId: entry.value.segmentId,
        );

        // Update cache
        _cache.set(
          entry.key,
          FlagState(
            key: entry.key,
            value: entry.value.value,
            enabled: entry.value.enabled,
            version: entry.value.version,
          ),
        );
      }

      return results;
    } catch (error) {
      // Fall back to cached values
      final cachedFlags = getAllFlags();
      final results = <String, EvaluationResult>{};

      for (final entry in cachedFlags.entries) {
        results[entry.key] = EvaluationResult(
          flagKey: entry.key,
          value: entry.value.value,
          enabled: entry.value.enabled,
          reason: EvaluationReason.staleCache,
          version: entry.value.version,
        );
      }

      return results;
    }
  }

  /// Evaluates multiple flags in a single request.
  ///
  /// More efficient than calling evaluateAsync for each flag individually.
  Future<Map<String, EvaluationResult>> evaluateBatch(
    List<String> flagKeys, [
    EvaluationContext? context,
  ]) async {
    _ensureNotClosed();

    if (flagKeys.isEmpty) {
      return {};
    }

    final resolvedContext = _contextManager.resolveContextForServer(context);

    try {
      final response = await _httpClient.post(
        '/sdk/evaluate/batch',
        {
          'flagKeys': flagKeys,
          if (resolvedContext != null) 'context': resolvedContext.toJson(),
        },
        (json) => _BatchEvaluateResponse.fromJson(json),
      );

      final results = <String, EvaluationResult>{};

      for (final entry in response.flags.entries) {
        results[entry.key] = EvaluationResult(
          flagKey: entry.key,
          value: entry.value.value,
          enabled: entry.value.enabled,
          reason: entry.value.reason,
          version: entry.value.version,
          variationId: entry.value.variationId,
          ruleId: entry.value.ruleId,
          segmentId: entry.value.segmentId,
        );

        // Update cache
        _cache.set(
          entry.key,
          FlagState(
            key: entry.key,
            value: entry.value.value,
            enabled: entry.value.enabled,
            version: entry.value.version,
          ),
        );
      }

      return results;
    } catch (error) {
      // Fall back to cached values for requested keys
      final results = <String, EvaluationResult>{};

      for (final key in flagKeys) {
        final cached = _cache.get(key);
        if (cached != null) {
          results[key] = EvaluationResult(
            flagKey: key,
            value: cached.value,
            enabled: cached.enabled,
            reason: EvaluationReason.staleCache,
            version: cached.version,
          );
        } else {
          results[key] = EvaluationResult.defaultResult(
            key,
            FlagValue(null),
            EvaluationReason.flagNotFound,
          );
        }
      }

      return results;
    }
  }

  /// Gets a boolean flag value with a default.
  bool getBooleanValue(String flagKey, bool defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    if (result.reason == EvaluationReason.flagNotFound ||
        result.reason == EvaluationReason.disabled) {
      return defaultValue;
    }
    return result.boolValue;
  }

  /// Gets a string flag value with a default.
  String getStringValue(String flagKey, String defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    if (result.reason == EvaluationReason.flagNotFound ||
        result.reason == EvaluationReason.disabled) {
      return defaultValue;
    }
    return result.stringValue ?? defaultValue;
  }

  /// Gets a number flag value with a default.
  double getNumberValue(String flagKey, double defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    if (result.reason == EvaluationReason.flagNotFound ||
        result.reason == EvaluationReason.disabled) {
      return defaultValue;
    }
    return result.numberValue;
  }

  /// Gets an integer flag value with a default.
  int getIntValue(String flagKey, int defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    if (result.reason == EvaluationReason.flagNotFound ||
        result.reason == EvaluationReason.disabled) {
      return defaultValue;
    }
    return result.intValue;
  }

  /// Gets a JSON flag value with a default.
  Map<String, dynamic>? getJsonValue(
      String flagKey, Map<String, dynamic>? defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    if (result.reason == EvaluationReason.flagNotFound ||
        result.reason == EvaluationReason.disabled) {
      return defaultValue;
    }
    return result.jsonValue ?? defaultValue;
  }

  /// Returns true if the flag exists in the cache.
  bool hasFlag(String flagKey) {
    return _cache.has(flagKey);
  }

  /// Gets all flag keys from the cache.
  List<String> getAllFlagKeys() {
    return _cache.keys.toList();
  }

  /// Gets all cached flags.
  Map<String, FlagState> getAllFlags() {
    return _cache.getAll();
  }

  /// Tracks a custom event.
  void track(String eventType, [Map<String, dynamic>? eventData]) {
    _eventQueue?.track(eventType, eventData);
  }

  /// Flushes pending events immediately.
  Future<void> flush() async {
    await _eventQueue?.flush();
  }

  /// Forces a refresh of flag configurations from the server.
  Future<void> refresh() async {
    _ensureNotClosed();

    try {
      final response = await _httpClient.get(
        '/sdk/init',
        (json) => _InitResponse.fromJson(json),
      );

      final updatedFlags = <FlagState>[];

      for (final flag in response.flags) {
        _cache.set(flag.key, flag);
        updatedFlags.add(flag);
      }

      _lastUpdatedAt = response.serverTime;

      if (updatedFlags.isNotEmpty) {
        onFlagsUpdated?.call(updatedFlags);
      }
    } catch (error) {
      final exception = error is FlagKitException
          ? error
          : FlagKitException.networkError(
              ErrorCode.networkError,
              'Failed to refresh flags: $error',
              error,
            );
      onError?.call(exception);
      rethrow;
    }
  }

  /// Polls for flag updates since the last update.
  Future<void> pollForUpdates([String? since]) async {
    _ensureNotClosed();

    final sinceTimestamp = since ?? _lastUpdatedAt;
    final path = sinceTimestamp != null
        ? '/sdk/updates?since=$sinceTimestamp'
        : '/sdk/updates';

    try {
      final response = await _httpClient.get(
        path,
        (json) => _UpdatesResponse.fromJson(json),
      );

      if (response.flags != null && response.flags!.isNotEmpty) {
        final updatedFlags = <FlagState>[];

        for (final flag in response.flags!) {
          _cache.set(flag.key, flag);
          updatedFlags.add(flag);
        }

        _lastUpdatedAt = response.checkedAt;

        if (updatedFlags.isNotEmpty) {
          onFlagsUpdated?.call(updatedFlags);
          options.onUpdate?.call(updatedFlags);
        }
      } else {
        _lastUpdatedAt = response.checkedAt;
      }
    } catch (error) {
      final exception = error is FlagKitException
          ? error
          : FlagKitException.networkError(
              ErrorCode.networkError,
              'Failed to poll for updates: $error',
              error,
            );
      onError?.call(exception);
      options.onError?.call(exception);
      rethrow;
    }
  }

  /// Starts background polling for flag updates.
  void startPolling() {
    _pollingManager?.start();
  }

  /// Stops background polling.
  void stopPolling() {
    _pollingManager?.stop();
  }

  /// Returns true if polling is active.
  bool get isPolling => _pollingManager?.isRunning ?? false;

  /// Closes the SDK and releases resources.
  ///
  /// The client cannot be used after calling this method.
  Future<void> close() async {
    if (_closed) {
      return;
    }

    _closed = true;

    // Stop polling
    _pollingManager?.stop();

    // Flush and close event queue
    await _eventQueue?.close(flushBeforeClose: true);

    // Close HTTP client
    _httpClient.close();
  }

  void _ensureNotClosed() {
    if (_closed) {
      throw FlagKitException.sdkError(
        ErrorCode.sdkNotInitialized,
        'SDK has been closed',
      );
    }
  }

  void _initializeEventQueue() {
    _eventQueue = EventQueue(
      EventQueueOptions(
        httpClient: _httpClient,
        sessionId: sessionId,
        environmentId: _environmentId ?? '',
        sdkVersion: '1.0.0',
        config: EventQueueConfig(
          batchSize: options.eventBatchSize,
          flushIntervalMs: options.eventFlushInterval.inMilliseconds,
        ),
      ),
    );

    if (_contextManager.userId != null) {
      _eventQueue!.setUserId(_contextManager.userId);
    }
  }

  void _initializePollingManager() {
    _pollingManager = PollingManager(
      onPoll: () => pollForUpdates(),
      config: PollingConfig(
        intervalMs: options.pollingInterval.inMilliseconds,
      ),
      onError: (error) {
        final exception = error is FlagKitException
            ? error
            : FlagKitException.networkError(
                ErrorCode.networkError,
                'Polling error: $error',
                error,
              );
        onError?.call(exception);
      },
    );

    // Start polling automatically
    _pollingManager!.start();
  }
}

// Response models

class _InitResponse {
  final List<FlagState> flags;
  final String? serverTime;
  final String? environmentId;
  final String? environment;
  final String? projectId;
  final String? organizationId;
  final int? pollingIntervalSeconds;
  final String? streamingUrl;
  final _InitMetadata? metadata;

  _InitResponse({
    required this.flags,
    this.serverTime,
    this.environmentId,
    this.environment,
    this.projectId,
    this.organizationId,
    this.pollingIntervalSeconds,
    this.streamingUrl,
    this.metadata,
  });

  factory _InitResponse.fromJson(Map<String, dynamic> json) {
    return _InitResponse(
      flags: (json['flags'] as List?)
              ?.map((e) => FlagState.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      serverTime: json['serverTime'] as String?,
      environmentId: json['environmentId'] as String?,
      environment: json['environment'] as String?,
      projectId: json['projectId'] as String?,
      organizationId: json['organizationId'] as String?,
      pollingIntervalSeconds: json['pollingIntervalSeconds'] as int?,
      streamingUrl: json['streamingUrl'] as String?,
      metadata: json['metadata'] != null
          ? _InitMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }
}

class _InitMetadata {
  final String? sdkVersionMin;
  final String? sdkVersionRecommended;
  final Map<String, bool>? features;

  _InitMetadata({
    this.sdkVersionMin,
    this.sdkVersionRecommended,
    this.features,
  });

  factory _InitMetadata.fromJson(Map<String, dynamic> json) {
    return _InitMetadata(
      sdkVersionMin: json['sdkVersionMin'] as String?,
      sdkVersionRecommended: json['sdkVersionRecommended'] as String?,
      features: json['features'] != null
          ? Map<String, bool>.from(json['features'] as Map)
          : null,
    );
  }
}

class _UpdatesResponse {
  final List<FlagState>? flags;
  final String? checkedAt;
  final String? since;

  _UpdatesResponse({
    this.flags,
    this.checkedAt,
    this.since,
  });

  factory _UpdatesResponse.fromJson(Map<String, dynamic> json) {
    return _UpdatesResponse(
      flags: json['flags'] != null
          ? (json['flags'] as List)
              .map((e) => FlagState.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      checkedAt: json['checkedAt'] as String?,
      since: json['since'] as String?,
    );
  }
}

class _EvaluateResponse {
  final String flagKey;
  final FlagValue value;
  final bool enabled;
  final EvaluationReason reason;
  final int version;
  final String? variationId;
  final String? ruleId;
  final String? segmentId;

  _EvaluateResponse({
    required this.flagKey,
    required this.value,
    required this.enabled,
    required this.reason,
    required this.version,
    this.variationId,
    this.ruleId,
    this.segmentId,
  });

  factory _EvaluateResponse.fromJson(Map<String, dynamic> json) {
    return _EvaluateResponse(
      flagKey: json['flagKey'] as String,
      value: FlagValue.from(json['value']),
      enabled: json['enabled'] as bool? ?? false,
      reason: EvaluationReason.fromString(json['reason'] as String?),
      version: json['version'] as int? ?? 0,
      variationId: json['variationId'] as String?,
      ruleId: json['ruleId'] as String?,
      segmentId: json['segmentId'] as String?,
    );
  }
}

class _BatchEvaluateResponse {
  final Map<String, _EvaluateResponse> flags;
  final String? evaluatedAt;

  _BatchEvaluateResponse({
    required this.flags,
    this.evaluatedAt,
  });

  factory _BatchEvaluateResponse.fromJson(Map<String, dynamic> json) {
    final flagsJson = json['flags'] as Map<String, dynamic>? ?? {};
    final flags = <String, _EvaluateResponse>{};

    for (final entry in flagsJson.entries) {
      final flagData = entry.value as Map<String, dynamic>;
      // Ensure flagKey is set
      flagData['flagKey'] ??= entry.key;
      flags[entry.key] = _EvaluateResponse.fromJson(flagData);
    }

    return _BatchEvaluateResponse(
      flags: flags,
      evaluatedAt: json['evaluatedAt'] as String?,
    );
  }
}

/// Extension methods for List<EvaluationResult>.
extension EvaluationResultListExtensions on List<EvaluationResult> {
  /// Converts a list of results to a map keyed by flag key.
  Map<String, EvaluationResult> toMap() {
    return {for (final result in this) result.flagKey: result};
  }
}
