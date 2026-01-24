/// Reasons for flag evaluation results.
///
/// These correspond to the spec-defined evaluation reasons.
enum EvaluationReason {
  /// Flag was evaluated from cache.
  cached,

  /// Default value was returned.
  defaultValue,

  /// Flag does not exist.
  flagNotFound,

  /// Flag was evaluated from bootstrap data.
  bootstrap,

  /// Flag was evaluated from server response.
  server,

  /// Cached value was stale but returned due to network error.
  staleCache,

  /// An error occurred during evaluation.
  error,

  /// Flag is disabled in this environment.
  disabled,

  /// The flag type didn't match the requested type.
  typeMismatch,

  /// Evaluation occurred while offline.
  offline,

  /// Default targeting rule matched (fallthrough).
  fallthrough,

  /// A targeting rule matched.
  ruleMatch,

  /// User is in a matched segment.
  segmentMatch,

  /// Environment is not configured.
  environmentNotConfigured,

  /// Evaluation error occurred.
  evaluationError;

  /// Converts a string to an EvaluationReason.
  ///
  /// Supports both camelCase and snake_case formats.
  static EvaluationReason fromString(String? value) {
    if (value == null) return EvaluationReason.defaultValue;

    // Check aliases first
    final aliased = _aliases[value.toUpperCase()];
    if (aliased != null) return aliased;

    // Try direct match
    return EvaluationReason.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => EvaluationReason.defaultValue,
    );
  }

  /// Converts this reason to its string representation for API communication.
  ///
  /// Uses uppercase for spec-defined reasons and lowercase for internal reasons.
  String toApiString() {
    return _reverseAliases[this] ?? name;
  }

  static const _aliases = {
    'FLAG_NOT_FOUND': EvaluationReason.flagNotFound,
    'FLAG_DISABLED': EvaluationReason.disabled,
    'ENVIRONMENT_NOT_CONFIGURED': EvaluationReason.environmentNotConfigured,
    'FALLTHROUGH': EvaluationReason.fallthrough,
    'RULE_MATCH': EvaluationReason.ruleMatch,
    'SEGMENT_MATCH': EvaluationReason.segmentMatch,
    'DEFAULT': EvaluationReason.defaultValue,
    'EVALUATION_ERROR': EvaluationReason.evaluationError,
    'STALE_CACHE': EvaluationReason.staleCache,
    'TYPE_MISMATCH': EvaluationReason.typeMismatch,
    'CACHED': EvaluationReason.cached,
    'SERVER': EvaluationReason.server,
    'BOOTSTRAP': EvaluationReason.bootstrap,
    'OFFLINE': EvaluationReason.offline,
    'ERROR': EvaluationReason.error,
  };

  static const _reverseAliases = {
    EvaluationReason.flagNotFound: 'FLAG_NOT_FOUND',
    EvaluationReason.disabled: 'FLAG_DISABLED',
    EvaluationReason.environmentNotConfigured: 'ENVIRONMENT_NOT_CONFIGURED',
    EvaluationReason.fallthrough: 'FALLTHROUGH',
    EvaluationReason.ruleMatch: 'RULE_MATCH',
    EvaluationReason.segmentMatch: 'SEGMENT_MATCH',
    EvaluationReason.defaultValue: 'DEFAULT',
    EvaluationReason.evaluationError: 'EVALUATION_ERROR',
  };
}
