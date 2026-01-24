import 'core/cache.dart';
import 'types/evaluation_context.dart';
import 'types/evaluation_reason.dart';
import 'types/evaluation_result.dart';
import 'types/flag_state.dart';
import 'types/flag_value.dart';
import 'flagkit_options.dart';
import 'http/http_client.dart';

/// Main FlagKit client for feature flag evaluation.
class FlagKitClient {
  final FlagKitOptions options;
  final FlagKitHttpClient _httpClient;
  final FlagCache _cache;

  EvaluationContext _globalContext = EvaluationContext();
  bool _initialized = false;

  FlagKitClient(this.options)
      : _httpClient = FlagKitHttpClient(options, localPort: options.localPort),
        _cache = FlagCache(
          maxSize: options.maxCacheSize,
          ttl: options.cacheTtl,
        ) {
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

  bool get isInitialized => _initialized;

  EvaluationContext get globalContext => _globalContext;

  Future<void> initialize() async {
    final response = await _httpClient.get(
      '/sdk/init',
      (json) => _InitResponse.fromJson(json),
    );

    for (final flag in response.flags) {
      _cache.set(flag.key, flag);
    }

    _initialized = true;
  }

  void identify(String userId, [Map<String, dynamic>? attributes]) {
    _globalContext = _globalContext.withUserId(userId);

    if (attributes != null) {
      _globalContext = _globalContext.withAttributes(attributes);
    }
  }

  void setContext(EvaluationContext context) {
    _globalContext = context;
  }

  void clearContext() {
    _globalContext = EvaluationContext();
  }

  EvaluationResult evaluate(String flagKey, [EvaluationContext? context]) {
    final mergedContext = _mergeContext(context);
    final flag = _cache.get(flagKey);

    if (flag == null) {
      return EvaluationResult.defaultResult(
        flagKey,
        FlagValue(null),
        EvaluationReason.flagNotFound,
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

  Future<EvaluationResult> evaluateAsync(String flagKey,
      [EvaluationContext? context]) async {
    final mergedContext = _mergeContext(context);

    try {
      final response = await _httpClient.post(
        '/sdk/evaluate',
        {
          'flagKey': flagKey,
          'context': mergedContext.stripPrivateAttributes().toJson(),
        },
        (json) => _EvaluateResponse.fromJson(json),
      );

      return EvaluationResult(
        flagKey: response.flagKey,
        value: response.value,
        enabled: response.enabled,
        reason: response.reason,
        version: response.version,
      );
    } catch (_) {
      // Fall back to cache
      return evaluate(flagKey, context);
    }
  }

  bool getBooleanValue(String flagKey, bool defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    return result.reason == EvaluationReason.flagNotFound
        ? defaultValue
        : result.boolValue;
  }

  String getStringValue(String flagKey, String defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    return result.reason == EvaluationReason.flagNotFound
        ? defaultValue
        : result.stringValue ?? defaultValue;
  }

  double getNumberValue(String flagKey, double defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    return result.reason == EvaluationReason.flagNotFound
        ? defaultValue
        : result.numberValue;
  }

  int getIntValue(String flagKey, int defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    return result.reason == EvaluationReason.flagNotFound
        ? defaultValue
        : result.intValue;
  }

  Map<String, dynamic>? getJsonValue(
      String flagKey, Map<String, dynamic>? defaultValue,
      [EvaluationContext? context]) {
    final result = evaluate(flagKey, context);
    return result.reason == EvaluationReason.flagNotFound
        ? defaultValue
        : result.jsonValue ?? defaultValue;
  }

  Map<String, FlagState> getAllFlags() {
    return _cache.getAll();
  }

  Future<void> pollForUpdates([String? since]) async {
    final path = since != null ? '/sdk/updates?since=$since' : '/sdk/updates';

    final response = await _httpClient.get(
      path,
      (json) => _UpdatesResponse.fromJson(json),
    );

    if (response.hasUpdates && response.flags != null) {
      for (final flag in response.flags!) {
        _cache.set(flag.key, flag);
      }
    }
  }

  void close() {
    _httpClient.close();
  }

  EvaluationContext _mergeContext(EvaluationContext? context) {
    return _globalContext.merge(context);
  }
}

class _InitResponse {
  final List<FlagState> flags;
  final String? timestamp;

  _InitResponse({required this.flags, this.timestamp});

  factory _InitResponse.fromJson(Map<String, dynamic> json) {
    return _InitResponse(
      flags: (json['flags'] as List)
          .map((e) => FlagState.fromJson(e as Map<String, dynamic>))
          .toList(),
      timestamp: json['timestamp'] as String?,
    );
  }
}

class _UpdatesResponse {
  final List<FlagState>? flags;
  final bool hasUpdates;

  _UpdatesResponse({this.flags, required this.hasUpdates});

  factory _UpdatesResponse.fromJson(Map<String, dynamic> json) {
    return _UpdatesResponse(
      flags: json['flags'] != null
          ? (json['flags'] as List)
              .map((e) => FlagState.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      hasUpdates: json['hasUpdates'] as bool? ?? false,
    );
  }
}

class _EvaluateResponse {
  final String flagKey;
  final FlagValue value;
  final bool enabled;
  final EvaluationReason reason;
  final int version;

  _EvaluateResponse({
    required this.flagKey,
    required this.value,
    required this.enabled,
    required this.reason,
    required this.version,
  });

  factory _EvaluateResponse.fromJson(Map<String, dynamic> json) {
    return _EvaluateResponse(
      flagKey: json['flagKey'] as String,
      value: FlagValue.from(json['value']),
      enabled: json['enabled'] as bool? ?? false,
      reason: EvaluationReason.fromString(json['reason'] as String?),
      version: json['version'] as int? ?? 0,
    );
  }
}
