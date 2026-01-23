import 'flag_type.dart';
import 'flag_value.dart';

/// Represents the state of a feature flag.
class FlagState {
  final String key;
  final FlagValue value;
  final bool enabled;
  final int version;
  final FlagType? flagType;
  final String? lastModified;
  final Map<String, String>? metadata;

  FlagState({
    required this.key,
    required this.value,
    this.enabled = true,
    this.version = 0,
    this.flagType,
    this.lastModified,
    this.metadata,
  });

  factory FlagState.fromJson(Map<String, dynamic> json) {
    return FlagState(
      key: json['key'] as String,
      value: FlagValue.from(json['value']),
      enabled: json['enabled'] as bool? ?? true,
      version: json['version'] as int? ?? 0,
      flagType: FlagType.fromString(json['flagType'] as String?),
      lastModified: json['lastModified'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, String>.from(json['metadata'] as Map)
          : null,
    );
  }

  FlagType get effectiveFlagType => flagType ?? value.inferredType;

  bool get boolValue => value.boolValue ?? false;

  String? get stringValue => value.stringValue;

  double get numberValue => value.numberValue ?? 0.0;

  int get intValue => value.intValue ?? 0;

  Map<String, dynamic>? get jsonValue => value.jsonValue;

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value.raw,
      'enabled': enabled,
      'version': version,
      if (flagType != null) 'flagType': flagType!.name,
      if (lastModified != null) 'lastModified': lastModified,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
