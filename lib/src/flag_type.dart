/// Types of feature flags.
enum FlagType {
  boolean,
  string,
  number,
  json;

  static FlagType? fromString(String? value) {
    if (value == null) return null;
    return FlagType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => FlagType.json,
    );
  }
}
