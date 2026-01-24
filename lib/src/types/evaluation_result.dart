import 'evaluation_reason.dart';
import 'flag_value.dart';

/// Result of evaluating a feature flag.
///
/// Contains all information about a flag evaluation including the value,
/// reason for the evaluation result, and optional targeting metadata.
class EvaluationResult {
  /// The key of the evaluated flag.
  final String flagKey;

  /// The evaluated value wrapped in a FlagValue.
  final FlagValue value;

  /// Whether the flag is enabled.
  final bool enabled;

  /// The reason for this evaluation result.
  final EvaluationReason reason;

  /// The version of the flag configuration.
  final int version;

  /// When the evaluation occurred.
  final DateTime timestamp;

  /// The ID of the variation that was returned, if applicable.
  final String? variationId;

  /// The ID of the targeting rule that matched, if applicable.
  final String? ruleId;

  /// The ID of the segment that matched, if applicable.
  final String? segmentId;

  /// The rollout percentage if this was a percentage-based evaluation.
  final double? rolloutPercentage;

  EvaluationResult({
    required this.flagKey,
    required this.value,
    this.enabled = false,
    this.reason = EvaluationReason.defaultValue,
    this.version = 0,
    DateTime? timestamp,
    this.variationId,
    this.ruleId,
    this.segmentId,
    this.rolloutPercentage,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Gets the value as a boolean, defaulting to false.
  bool get boolValue => value.boolValue ?? false;

  /// Gets the value as a string, or null if not a string.
  String? get stringValue => value.stringValue;

  /// Gets the value as a double, defaulting to 0.0.
  double get numberValue => value.numberValue ?? 0.0;

  /// Gets the value as an integer, defaulting to 0.
  int get intValue => value.intValue ?? 0;

  /// Gets the value as a JSON map, or null if not a map.
  Map<String, dynamic>? get jsonValue => value.jsonValue;

  /// Returns true if this evaluation result represents a successful evaluation.
  bool get isSuccessful => reason != EvaluationReason.flagNotFound &&
      reason != EvaluationReason.error &&
      reason != EvaluationReason.evaluationError;

  /// Returns true if this result came from cache (including stale cache).
  bool get isFromCache => reason == EvaluationReason.cached ||
      reason == EvaluationReason.staleCache;

  /// Creates a default result for when a flag is not found.
  static EvaluationResult defaultResult(
    String key,
    FlagValue defaultValue,
    EvaluationReason reason,
  ) {
    return EvaluationResult(
      flagKey: key,
      value: defaultValue,
      enabled: false,
      reason: reason,
    );
  }

  /// Creates a result from a server response.
  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      flagKey: json['flagKey'] as String,
      value: FlagValue.from(json['value']),
      enabled: json['enabled'] as bool? ?? false,
      reason: EvaluationReason.fromString(json['reason'] as String?),
      version: json['version'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      variationId: json['variationId'] as String?,
      ruleId: json['ruleId'] as String?,
      segmentId: json['segmentId'] as String?,
      rolloutPercentage: json['rolloutPercentage'] != null
          ? (json['rolloutPercentage'] as num).toDouble()
          : null,
    );
  }

  /// Converts this result to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'flagKey': flagKey,
      'value': value.raw,
      'enabled': enabled,
      'reason': reason.toApiString(),
      'version': version,
      'timestamp': timestamp.toIso8601String(),
      if (variationId != null) 'variationId': variationId,
      if (ruleId != null) 'ruleId': ruleId,
      if (segmentId != null) 'segmentId': segmentId,
      if (rolloutPercentage != null) 'rolloutPercentage': rolloutPercentage,
    };
  }

  /// Creates a copy of this result with the given fields replaced.
  EvaluationResult copyWith({
    String? flagKey,
    FlagValue? value,
    bool? enabled,
    EvaluationReason? reason,
    int? version,
    DateTime? timestamp,
    String? variationId,
    String? ruleId,
    String? segmentId,
    double? rolloutPercentage,
  }) {
    return EvaluationResult(
      flagKey: flagKey ?? this.flagKey,
      value: value ?? this.value,
      enabled: enabled ?? this.enabled,
      reason: reason ?? this.reason,
      version: version ?? this.version,
      timestamp: timestamp ?? this.timestamp,
      variationId: variationId ?? this.variationId,
      ruleId: ruleId ?? this.ruleId,
      segmentId: segmentId ?? this.segmentId,
      rolloutPercentage: rolloutPercentage ?? this.rolloutPercentage,
    );
  }

  @override
  String toString() {
    return 'EvaluationResult(flagKey: $flagKey, value: ${value.raw}, enabled: $enabled, reason: $reason)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaluationResult &&
          runtimeType == other.runtimeType &&
          flagKey == other.flagKey &&
          value == other.value &&
          enabled == other.enabled &&
          reason == other.reason &&
          version == other.version;

  @override
  int get hashCode =>
      flagKey.hashCode ^
      value.hashCode ^
      enabled.hashCode ^
      reason.hashCode ^
      version.hashCode;
}
