import '../types/evaluation_context.dart';
import '../types/flag_value.dart';

/// Manages global and per-evaluation context.
///
/// Provides methods for setting, getting, and merging evaluation contexts,
/// as well as user identification and private attribute handling.
class ContextManager {
  EvaluationContext? _globalContext;
  final void Function(EvaluationContext?)? _onContextChanged;

  ContextManager({
    void Function(EvaluationContext?)? onContextChanged,
  }) : _onContextChanged = onContextChanged;

  /// Gets the current global context.
  EvaluationContext? get context => _globalContext;

  /// Sets the global context.
  ///
  /// Replaces the entire global context with the provided context.
  void setContext(EvaluationContext context) {
    _globalContext = context;
    _onContextChanged?.call(_globalContext);
  }

  /// Gets the current global context.
  ///
  /// Returns null if no context has been set.
  EvaluationContext? getContext() {
    return _globalContext;
  }

  /// Clears the global context.
  void clearContext() {
    _globalContext = null;
    _onContextChanged?.call(null);
  }

  /// Identifies a user by setting userId and optional attributes.
  ///
  /// This sets the global context with the user's information.
  /// If additional attributes are provided, they are merged into the context.
  void identify(String userId, [Map<String, dynamic>? attributes]) {
    EvaluationContext newContext = EvaluationContext(
      userId: userId,
      anonymous: false,
    );

    if (attributes != null) {
      // Extract known fields from attributes
      newContext = newContext.copyWith(
        email: attributes['email'] as String?,
        name: attributes['name'] as String?,
        country: attributes['country'] as String?,
        ip: attributes['ip'] as String?,
        userAgent: attributes['userAgent'] as String?,
      );

      // Handle custom attributes
      final custom = attributes['custom'] as Map<String, dynamic>?;
      if (custom != null) {
        newContext = newContext.withCustomAttributes(custom);
      }

      // Handle remaining attributes
      final remainingAttrs = Map<String, dynamic>.from(attributes);
      remainingAttrs.removeWhere((key, _) =>
          const {'email', 'name', 'country', 'ip', 'userAgent', 'custom'}
              .contains(key));

      if (remainingAttrs.isNotEmpty) {
        newContext = newContext.withAttributes(remainingAttrs);
      }
    }

    _globalContext = newContext;
    _onContextChanged?.call(_globalContext);
  }

  /// Resets to an anonymous state.
  ///
  /// Clears the userId but preserves other attributes if [keepAttributes] is true.
  void reset({bool keepAttributes = false}) {
    if (keepAttributes && _globalContext != null) {
      _globalContext = _globalContext!.copyWith(
        userId: null,
        anonymous: true,
      );
    } else {
      _globalContext = EvaluationContext.anonymous();
    }

    _onContextChanged?.call(_globalContext);
  }

  /// Returns true if a user has been identified (has a userId and is not anonymous).
  bool get isIdentified =>
      _globalContext?.userId != null && !(_globalContext?.anonymous ?? true);

  /// Returns true if the context is anonymous (no userId or anonymous flag set).
  bool get isAnonymous =>
      _globalContext == null ||
      _globalContext?.userId == null ||
      (_globalContext?.anonymous ?? false);

  /// Gets the current user ID, if set.
  String? get userId => _globalContext?.userId;

  /// Gets the current email, if set.
  String? get email => _globalContext?.email;

  /// Gets the current name, if set.
  String? get name => _globalContext?.name;

  /// Resolves the final context by merging global and evaluation-specific contexts.
  ///
  /// The evaluation context takes precedence over the global context.
  /// Returns null if both contexts are null.
  EvaluationContext? resolveContext([EvaluationContext? evaluationContext]) {
    return mergeContexts(_globalContext, evaluationContext);
  }

  /// Resolves and strips private attributes from the context.
  ///
  /// This is used when sending context to the server to protect sensitive data.
  EvaluationContext? resolveContextForServer(
      [EvaluationContext? evaluationContext]) {
    final merged = resolveContext(evaluationContext);
    return merged?.stripPrivateAttributes();
  }

  /// Updates the global context with additional attributes.
  ///
  /// Preserves existing attributes and userId.
  void updateContext(Map<String, dynamic> attributes) {
    if (_globalContext == null) {
      _globalContext = EvaluationContext().withAttributes(attributes);
    } else {
      _globalContext = _globalContext!.withAttributes(attributes);
    }

    _onContextChanged?.call(_globalContext);
  }

  /// Sets a single attribute on the global context.
  void setAttribute(String key, dynamic value) {
    if (_globalContext == null) {
      _globalContext = EvaluationContext().withAttribute(key, value);
    } else {
      _globalContext = _globalContext!.withAttribute(key, value);
    }

    _onContextChanged?.call(_globalContext);
  }

  /// Sets a custom attribute on the global context.
  void setCustomAttribute(String key, dynamic value) {
    if (_globalContext == null) {
      _globalContext = EvaluationContext().withCustom(key, value);
    } else {
      _globalContext = _globalContext!.withCustom(key, value);
    }

    _onContextChanged?.call(_globalContext);
  }

  /// Gets a single attribute from the global context.
  FlagValue? getAttribute(String key) {
    return _globalContext?[key];
  }

  /// Removes a single attribute from the global context.
  void removeAttribute(String key) {
    if (_globalContext == null) {
      return;
    }

    final newAttributes =
        Map<String, FlagValue>.from(_globalContext!.attributes);
    newAttributes.remove(key);

    _globalContext = _globalContext!.copyWith(attributes: newAttributes);

    _onContextChanged?.call(_globalContext);
  }

  /// Adds a private attribute name.
  ///
  /// Private attributes are stripped before sending to the server.
  void addPrivateAttribute(String attributeName) {
    if (_globalContext == null) {
      _globalContext = EvaluationContext(privateAttributes: [attributeName]);
    } else {
      _globalContext = _globalContext!.withPrivateAttribute(attributeName);
    }

    _onContextChanged?.call(_globalContext);
  }

  /// Sets the user's email.
  void setEmail(String email) {
    if (_globalContext == null) {
      _globalContext = EvaluationContext(email: email);
    } else {
      _globalContext = _globalContext!.copyWith(email: email);
    }

    _onContextChanged?.call(_globalContext);
  }

  /// Sets the user's country.
  void setCountry(String country) {
    if (_globalContext == null) {
      _globalContext = EvaluationContext(country: country);
    } else {
      _globalContext = _globalContext!.copyWith(country: country);
    }

    _onContextChanged?.call(_globalContext);
  }
}

/// Merges two evaluation contexts.
///
/// The [evaluationContext] takes precedence over [globalContext].
/// If both are null, returns null.
/// If one is null, returns the other.
EvaluationContext? mergeContexts(
  EvaluationContext? globalContext,
  EvaluationContext? evaluationContext,
) {
  if (globalContext == null && evaluationContext == null) {
    return null;
  }

  if (globalContext == null) {
    return evaluationContext;
  }

  if (evaluationContext == null) {
    return globalContext;
  }

  return globalContext.merge(evaluationContext);
}

/// Strips private attributes from a context.
///
/// Private attributes are those with keys starting with '_' or
/// listed in the privateAttributes list.
EvaluationContext stripPrivateAttributes(EvaluationContext context) {
  return context.stripPrivateAttributes();
}
