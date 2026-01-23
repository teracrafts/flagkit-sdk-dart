import 'evaluation_reason.dart';
import 'flag_value.dart';

/// Result of evaluating a feature flag.
class EvaluationResult {
  final String flagKey;
  final FlagValue value;
  final bool enabled;
  final EvaluationReason reason;
  final int version;
  final DateTime timestamp;

  EvaluationResult({
    required this.flagKey,
    required this.value,
    this.enabled = false,
    this.reason = EvaluationReason.defaultValue,
    this.version = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get boolValue => value.boolValue ?? false;

  String? get stringValue => value.stringValue;

  double get numberValue => value.numberValue ?? 0.0;

  int get intValue => value.intValue ?? 0;

  Map<String, dynamic>? get jsonValue => value.jsonValue;

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

  Map<String, dynamic> toJson() {
    return {
      'flagKey': flagKey,
      'value': value.raw,
      'enabled': enabled,
      'reason': reason.name,
      'version': version,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
