import 'flag_value.dart';

const _privateAttributePrefix = '_';

/// Context for flag evaluation containing user and custom attributes.
class EvaluationContext {
  final String? userId;
  final Map<String, FlagValue> attributes;

  EvaluationContext({
    this.userId,
    Map<String, FlagValue>? attributes,
  }) : attributes = attributes ?? {};

  factory EvaluationContext.withUserId(String userId) {
    return EvaluationContext(userId: userId);
  }

  EvaluationContext copyWith({
    String? userId,
    Map<String, FlagValue>? attributes,
  }) {
    return EvaluationContext(
      userId: userId ?? this.userId,
      attributes: attributes ?? Map.from(this.attributes),
    );
  }

  EvaluationContext withUserId(String userId) {
    return copyWith(userId: userId);
  }

  EvaluationContext withAttribute(String key, dynamic value) {
    final newAttributes = Map<String, FlagValue>.from(attributes);
    newAttributes[key] = FlagValue.from(value);
    return copyWith(attributes: newAttributes);
  }

  EvaluationContext withAttributes(Map<String, dynamic> attrs) {
    final newAttributes = Map<String, FlagValue>.from(attributes);
    attrs.forEach((key, value) {
      newAttributes[key] = FlagValue.from(value);
    });
    return copyWith(attributes: newAttributes);
  }

  EvaluationContext merge(EvaluationContext? other) {
    if (other == null) return this;

    final mergedAttributes = Map<String, FlagValue>.from(attributes);
    mergedAttributes.addAll(other.attributes);

    return EvaluationContext(
      userId: other.userId ?? userId,
      attributes: mergedAttributes,
    );
  }

  EvaluationContext stripPrivateAttributes() {
    final filteredAttributes = Map<String, FlagValue>.fromEntries(
      attributes.entries
          .where((e) => !e.key.startsWith(_privateAttributePrefix)),
    );

    return EvaluationContext(
      userId: userId,
      attributes: filteredAttributes,
    );
  }

  bool get isEmpty => userId == null && attributes.isEmpty;

  FlagValue? operator [](String key) => attributes[key];

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (userId != null) {
      result['userId'] = userId;
    }
    if (attributes.isNotEmpty) {
      result['attributes'] = attributes.map((k, v) => MapEntry(k, v.raw));
    }
    return result;
  }

  static EvaluationContextBuilder builder() => EvaluationContextBuilder();
}

/// Builder for EvaluationContext.
class EvaluationContextBuilder {
  String? _userId;
  final Map<String, FlagValue> _attributes = {};

  EvaluationContextBuilder userId(String userId) {
    _userId = userId;
    return this;
  }

  EvaluationContextBuilder attribute(String key, dynamic value) {
    _attributes[key] = FlagValue.from(value);
    return this;
  }

  EvaluationContext build() {
    return EvaluationContext(
      userId: _userId,
      attributes: Map.from(_attributes),
    );
  }
}
