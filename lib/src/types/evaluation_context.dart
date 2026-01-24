import 'flag_value.dart';

const _privateAttributePrefix = '_';

/// Context for flag evaluation containing user and custom attributes.
///
/// This context is used when evaluating flags to provide user-specific
/// information for targeting rules.
class EvaluationContext {
  /// Unique user identifier.
  final String? userId;

  /// Alternative user key (e.g., email).
  final String? userKey;

  /// User's email address.
  final String? email;

  /// User's display name.
  final String? name;

  /// Whether this is an anonymous user.
  final bool anonymous;

  /// ISO country code (e.g., "US", "GB").
  final String? country;

  /// User's IP address.
  final String? ip;

  /// User's browser/device info.
  final String? userAgent;

  /// Custom attributes for targeting.
  final Map<String, FlagValue> custom;

  /// Attribute names that should not be sent to the server.
  final List<String> privateAttributes;

  /// Additional generic attributes.
  final Map<String, FlagValue> attributes;

  EvaluationContext({
    this.userId,
    this.userKey,
    this.email,
    this.name,
    this.anonymous = false,
    this.country,
    this.ip,
    this.userAgent,
    Map<String, FlagValue>? custom,
    List<String>? privateAttributes,
    Map<String, FlagValue>? attributes,
  })  : custom = custom ?? {},
        privateAttributes = privateAttributes ?? [],
        attributes = attributes ?? {};

  /// Creates a context with just a user ID.
  factory EvaluationContext.withUserId(String userId) {
    return EvaluationContext(userId: userId);
  }

  /// Creates an anonymous context.
  factory EvaluationContext.anonymous() {
    return EvaluationContext(anonymous: true);
  }

  /// Creates a copy with the given fields replaced.
  EvaluationContext copyWith({
    String? userId,
    String? userKey,
    String? email,
    String? name,
    bool? anonymous,
    String? country,
    String? ip,
    String? userAgent,
    Map<String, FlagValue>? custom,
    List<String>? privateAttributes,
    Map<String, FlagValue>? attributes,
  }) {
    return EvaluationContext(
      userId: userId ?? this.userId,
      userKey: userKey ?? this.userKey,
      email: email ?? this.email,
      name: name ?? this.name,
      anonymous: anonymous ?? this.anonymous,
      country: country ?? this.country,
      ip: ip ?? this.ip,
      userAgent: userAgent ?? this.userAgent,
      custom: custom ?? Map.from(this.custom),
      privateAttributes: privateAttributes ?? List.from(this.privateAttributes),
      attributes: attributes ?? Map.from(this.attributes),
    );
  }

  /// Returns a new context with the given user ID.
  EvaluationContext withUserId(String userId) {
    return copyWith(userId: userId, anonymous: false);
  }

  /// Returns a new context with the given email.
  EvaluationContext withEmail(String email) {
    return copyWith(email: email);
  }

  /// Returns a new context with the given country.
  EvaluationContext withCountry(String country) {
    return copyWith(country: country);
  }

  /// Returns a new context with an additional attribute.
  EvaluationContext withAttribute(String key, dynamic value) {
    final newAttributes = Map<String, FlagValue>.from(attributes);
    newAttributes[key] = FlagValue.from(value);
    return copyWith(attributes: newAttributes);
  }

  /// Returns a new context with additional attributes merged in.
  EvaluationContext withAttributes(Map<String, dynamic> attrs) {
    final newAttributes = Map<String, FlagValue>.from(attributes);
    attrs.forEach((key, value) {
      newAttributes[key] = FlagValue.from(value);
    });
    return copyWith(attributes: newAttributes);
  }

  /// Returns a new context with a custom attribute.
  EvaluationContext withCustom(String key, dynamic value) {
    final newCustom = Map<String, FlagValue>.from(custom);
    newCustom[key] = FlagValue.from(value);
    return copyWith(custom: newCustom);
  }

  /// Returns a new context with additional custom attributes merged in.
  EvaluationContext withCustomAttributes(Map<String, dynamic> attrs) {
    final newCustom = Map<String, FlagValue>.from(custom);
    attrs.forEach((key, value) {
      newCustom[key] = FlagValue.from(value);
    });
    return copyWith(custom: newCustom);
  }

  /// Returns a new context with a private attribute added.
  EvaluationContext withPrivateAttribute(String attributeName) {
    final newPrivate = List<String>.from(privateAttributes);
    if (!newPrivate.contains(attributeName)) {
      newPrivate.add(attributeName);
    }
    return copyWith(privateAttributes: newPrivate);
  }

  /// Merges another context into this one.
  ///
  /// The [other] context's values take precedence.
  EvaluationContext merge(EvaluationContext? other) {
    if (other == null) return this;

    final mergedAttributes = Map<String, FlagValue>.from(attributes);
    mergedAttributes.addAll(other.attributes);

    final mergedCustom = Map<String, FlagValue>.from(custom);
    mergedCustom.addAll(other.custom);

    final mergedPrivate = List<String>.from(privateAttributes);
    for (final attr in other.privateAttributes) {
      if (!mergedPrivate.contains(attr)) {
        mergedPrivate.add(attr);
      }
    }

    return EvaluationContext(
      userId: other.userId ?? userId,
      userKey: other.userKey ?? userKey,
      email: other.email ?? email,
      name: other.name ?? name,
      anonymous: other.anonymous,
      country: other.country ?? country,
      ip: other.ip ?? ip,
      userAgent: other.userAgent ?? userAgent,
      custom: mergedCustom,
      privateAttributes: mergedPrivate,
      attributes: mergedAttributes,
    );
  }

  /// Strips private attributes from the context.
  ///
  /// Removes attributes that:
  /// - Start with underscore prefix
  /// - Are listed in [privateAttributes]
  EvaluationContext stripPrivateAttributes() {
    final filteredAttributes = Map<String, FlagValue>.fromEntries(
      attributes.entries.where((e) =>
          !e.key.startsWith(_privateAttributePrefix) &&
          !privateAttributes.contains(e.key)),
    );

    final filteredCustom = Map<String, FlagValue>.fromEntries(
      custom.entries.where((e) =>
          !e.key.startsWith(_privateAttributePrefix) &&
          !privateAttributes.contains('custom.$e.key')),
    );

    return EvaluationContext(
      userId: userId,
      userKey: userKey,
      email: privateAttributes.contains('email') ? null : email,
      name: privateAttributes.contains('name') ? null : name,
      anonymous: anonymous,
      country: privateAttributes.contains('country') ? null : country,
      ip: privateAttributes.contains('ip') ? null : ip,
      userAgent: privateAttributes.contains('userAgent') ? null : userAgent,
      custom: filteredCustom,
      privateAttributes: [],
      attributes: filteredAttributes,
    );
  }

  /// Returns true if this context has no identifying information.
  bool get isEmpty =>
      userId == null &&
      userKey == null &&
      email == null &&
      name == null &&
      country == null &&
      ip == null &&
      userAgent == null &&
      custom.isEmpty &&
      attributes.isEmpty;

  /// Gets an attribute value by key.
  FlagValue? operator [](String key) {
    // Check direct attributes first
    if (attributes.containsKey(key)) {
      return attributes[key];
    }
    // Then check custom attributes
    if (custom.containsKey(key)) {
      return custom[key];
    }
    return null;
  }

  /// Converts this context to a JSON map for API communication.
  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};

    if (userId != null) result['userId'] = userId;
    if (userKey != null) result['userKey'] = userKey;
    if (email != null) result['email'] = email;
    if (name != null) result['name'] = name;
    if (anonymous) result['anonymous'] = anonymous;
    if (country != null) result['country'] = country;
    if (ip != null) result['ip'] = ip;
    if (userAgent != null) result['userAgent'] = userAgent;

    if (custom.isNotEmpty) {
      result['custom'] = custom.map((k, v) => MapEntry(k, v.raw));
    }

    if (privateAttributes.isNotEmpty) {
      result['privateAttributes'] = privateAttributes;
    }

    // Merge generic attributes at top level
    if (attributes.isNotEmpty) {
      for (final entry in attributes.entries) {
        if (!result.containsKey(entry.key)) {
          result[entry.key] = entry.value.raw;
        }
      }
    }

    return result;
  }

  /// Creates a context from a JSON map.
  factory EvaluationContext.fromJson(Map<String, dynamic> json) {
    Map<String, FlagValue>? custom;
    if (json['custom'] != null) {
      custom = (json['custom'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, FlagValue.from(v)));
    }

    return EvaluationContext(
      userId: json['userId'] as String?,
      userKey: json['userKey'] as String?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      anonymous: json['anonymous'] as bool? ?? false,
      country: json['country'] as String?,
      ip: json['ip'] as String?,
      userAgent: json['userAgent'] as String?,
      custom: custom,
      privateAttributes: json['privateAttributes'] != null
          ? List<String>.from(json['privateAttributes'] as List)
          : null,
    );
  }

  /// Creates a builder for constructing an EvaluationContext.
  static EvaluationContextBuilder builder() => EvaluationContextBuilder();

  @override
  String toString() {
    return 'EvaluationContext(userId: $userId, anonymous: $anonymous)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaluationContext &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          userKey == other.userKey &&
          email == other.email &&
          name == other.name &&
          anonymous == other.anonymous &&
          country == other.country;

  @override
  int get hashCode =>
      userId.hashCode ^
      userKey.hashCode ^
      email.hashCode ^
      name.hashCode ^
      anonymous.hashCode ^
      country.hashCode;
}

/// Builder for EvaluationContext.
class EvaluationContextBuilder {
  String? _userId;
  String? _userKey;
  String? _email;
  String? _name;
  bool _anonymous = false;
  String? _country;
  String? _ip;
  String? _userAgent;
  final Map<String, FlagValue> _custom = {};
  final List<String> _privateAttributes = [];
  final Map<String, FlagValue> _attributes = {};

  /// Sets the user ID.
  EvaluationContextBuilder userId(String userId) {
    _userId = userId;
    _anonymous = false;
    return this;
  }

  /// Sets the user key.
  EvaluationContextBuilder userKey(String userKey) {
    _userKey = userKey;
    return this;
  }

  /// Sets the email.
  EvaluationContextBuilder email(String email) {
    _email = email;
    return this;
  }

  /// Sets the name.
  EvaluationContextBuilder name(String name) {
    _name = name;
    return this;
  }

  /// Sets anonymous status.
  EvaluationContextBuilder anonymous(bool anonymous) {
    _anonymous = anonymous;
    return this;
  }

  /// Sets the country.
  EvaluationContextBuilder country(String country) {
    _country = country;
    return this;
  }

  /// Sets the IP address.
  EvaluationContextBuilder ip(String ip) {
    _ip = ip;
    return this;
  }

  /// Sets the user agent.
  EvaluationContextBuilder userAgent(String userAgent) {
    _userAgent = userAgent;
    return this;
  }

  /// Adds a custom attribute.
  EvaluationContextBuilder custom(String key, dynamic value) {
    _custom[key] = FlagValue.from(value);
    return this;
  }

  /// Adds a private attribute.
  EvaluationContextBuilder privateAttribute(String attributeName) {
    if (!_privateAttributes.contains(attributeName)) {
      _privateAttributes.add(attributeName);
    }
    return this;
  }

  /// Adds a generic attribute.
  EvaluationContextBuilder attribute(String key, dynamic value) {
    _attributes[key] = FlagValue.from(value);
    return this;
  }

  /// Builds the EvaluationContext.
  EvaluationContext build() {
    return EvaluationContext(
      userId: _userId,
      userKey: _userKey,
      email: _email,
      name: _name,
      anonymous: _anonymous,
      country: _country,
      ip: _ip,
      userAgent: _userAgent,
      custom: Map.from(_custom),
      privateAttributes: List.from(_privateAttributes),
      attributes: Map.from(_attributes),
    );
  }
}
