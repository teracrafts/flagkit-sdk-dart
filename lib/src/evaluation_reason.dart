/// Reasons for flag evaluation results.
enum EvaluationReason {
  cached,
  defaultValue,
  flagNotFound,
  bootstrap,
  server,
  staleCache,
  error,
  disabled,
  typeMismatch,
  offline;

  static EvaluationReason fromString(String? value) {
    if (value == null) return EvaluationReason.defaultValue;
    return EvaluationReason.values.firstWhere(
      (e) => e.name == value || _aliases[value] == e,
      orElse: () => EvaluationReason.defaultValue,
    );
  }

  static const _aliases = {
    'flag_not_found': EvaluationReason.flagNotFound,
    'stale_cache': EvaluationReason.staleCache,
    'type_mismatch': EvaluationReason.typeMismatch,
    'default': EvaluationReason.defaultValue,
  };
}
