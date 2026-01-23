import 'flag_type.dart';

/// A wrapper for flag values.
class FlagValue {
  final dynamic _value;

  FlagValue(this._value);

  factory FlagValue.from(dynamic value) => FlagValue(value);

  dynamic get raw => _value;

  bool? get boolValue => _value is bool ? _value : null;

  String? get stringValue {
    if (_value is String) return _value;
    if (_value is bool) return _value.toString();
    if (_value is num) return _value.toString();
    return null;
  }

  double? get numberValue {
    if (_value is num) return _value.toDouble();
    return null;
  }

  int? get intValue {
    if (_value is num) return _value.toInt();
    return null;
  }

  Map<String, dynamic>? get jsonValue {
    if (_value is Map<String, dynamic>) return _value;
    if (_value is Map) {
      return Map<String, dynamic>.from(_value);
    }
    return null;
  }

  List<dynamic>? get arrayValue {
    if (_value is List) return _value;
    return null;
  }

  bool get isNull => _value == null;

  FlagType get inferredType {
    if (_value is bool) return FlagType.boolean;
    if (_value is String) return FlagType.string;
    if (_value is num) return FlagType.number;
    return FlagType.json;
  }

  @override
  String toString() => _value?.toString() ?? 'null';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlagValue &&
          runtimeType == other.runtimeType &&
          _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  dynamic toJson() => _value;
}
