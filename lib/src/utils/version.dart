/// Semantic version comparison utilities for SDK version metadata handling.
///
/// These utilities are used to compare the current SDK version against
/// server-provided version requirements (min, recommended, latest).

/// Maximum allowed value for version components (defensive limit).
const int _maxVersionComponent = 999999999;

/// Represents a parsed semantic version.
class SemanticVersion {
  final int major;
  final int minor;
  final int patch;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  @override
  String toString() => '$major.$minor.$patch';
}

/// Parse a semantic version string into numeric components.
/// Returns null if the version is not a valid semver.
SemanticVersion? parseVersion(String? version) {
  if (version == null || version.isEmpty) {
    return null;
  }

  // Trim whitespace
  final trimmed = version.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  // Strip leading 'v' or 'V' if present
  final normalized = (trimmed.startsWith('v') || trimmed.startsWith('V'))
      ? trimmed.substring(1)
      : trimmed;

  // Match semver pattern (allows pre-release suffix but ignores it for comparison)
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(normalized);
  if (match == null) {
    return null;
  }

  try {
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);

    // Validate components are within reasonable bounds
    if (major < 0 || major > _maxVersionComponent ||
        minor < 0 || minor > _maxVersionComponent ||
        patch < 0 || patch > _maxVersionComponent) {
      return null;
    }

    return SemanticVersion(major: major, minor: minor, patch: patch);
  } catch (e) {
    return null;
  }
}

/// Compare two semantic versions.
/// Returns:
///  - negative number if a < b
///  - 0 if a == b
///  - positive number if a > b
///
/// Returns 0 if either version is invalid.
int compareVersions(String? a, String? b) {
  final parsedA = parseVersion(a);
  final parsedB = parseVersion(b);

  if (parsedA == null || parsedB == null) {
    return 0;
  }

  // Compare major
  if (parsedA.major != parsedB.major) {
    return parsedA.major - parsedB.major;
  }

  // Compare minor
  if (parsedA.minor != parsedB.minor) {
    return parsedA.minor - parsedB.minor;
  }

  // Compare patch
  return parsedA.patch - parsedB.patch;
}

/// Check if version a is less than version b.
bool isVersionLessThan(String? a, String? b) {
  return compareVersions(a, b) < 0;
}

/// Check if version a is greater than or equal to version b.
bool isVersionAtLeast(String? a, String? b) {
  return compareVersions(a, b) >= 0;
}
