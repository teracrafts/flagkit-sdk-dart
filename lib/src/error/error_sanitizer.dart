/// Error message sanitization to prevent information leakage.
///
/// This module provides functionality to remove sensitive information
/// from error messages before they are logged or displayed.

/// Configuration for error message sanitization.
///
/// Controls how error messages are processed to remove sensitive data.
class ErrorSanitizationConfig {
  /// Whether sanitization is enabled.
  ///
  /// When false, error messages are passed through unchanged.
  final bool enabled;

  /// Whether to preserve the original unsanitized message.
  ///
  /// When true, the original message is stored separately for debugging.
  /// This should only be enabled in development environments.
  final bool preserveOriginal;

  /// Creates a new error sanitization configuration.
  ///
  /// [enabled] defaults to true.
  /// [preserveOriginal] defaults to false for security.
  const ErrorSanitizationConfig({
    this.enabled = true,
    this.preserveOriginal = false,
  });

  /// Default configuration with sanitization enabled.
  static const defaultConfig = ErrorSanitizationConfig();

  /// Configuration with sanitization disabled (use only in development).
  static const disabled = ErrorSanitizationConfig(enabled: false);

  /// Development configuration that preserves original messages.
  static const development = ErrorSanitizationConfig(
    enabled: true,
    preserveOriginal: true,
  );
}

/// Result of sanitizing an error message.
class SanitizedError {
  /// The sanitized error message.
  final String message;

  /// The original unsanitized message (only populated if preserveOriginal is true).
  final String? originalMessage;

  /// Whether any sanitization was applied.
  final bool wasSanitized;

  /// List of patterns that were matched and replaced.
  final List<String> sanitizedPatterns;

  const SanitizedError({
    required this.message,
    this.originalMessage,
    required this.wasSanitized,
    this.sanitizedPatterns = const [],
  });
}

/// Sanitizes error messages to remove sensitive information.
///
/// Removes:
/// - File paths (Unix and Windows)
/// - IP addresses
/// - API keys (sdk_, srv_, cli_ prefixes)
/// - Email addresses
/// - Connection strings (database URLs)
class ErrorSanitizer {
  /// Patterns to match and their replacements.
  static final _patterns = <(RegExp, String)>[
    // Unix file paths (must have at least one directory)
    (RegExp(r'/(?:[\w.-]+/)+[\w.-]+'), '[PATH]'),
    // Windows file paths
    (RegExp(r'[A-Za-z]:\\(?:[\w.-]+\\)+[\w.-]*'), '[PATH]'),
    // IPv4 addresses
    (RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'), '[IP]'),
    // SDK API keys
    (RegExp(r'sdk_[a-zA-Z0-9_-]{8,}'), 'sdk_[REDACTED]'),
    // Server API keys
    (RegExp(r'srv_[a-zA-Z0-9_-]{8,}'), 'srv_[REDACTED]'),
    // CLI API keys
    (RegExp(r'cli_[a-zA-Z0-9_-]{8,}'), 'cli_[REDACTED]'),
    // Email addresses
    (RegExp(r'[\w.-]+@[\w.-]+\.\w+'), '[EMAIL]'),
    // Database connection strings
    (
      RegExp(r'(?:postgres|mysql|mongodb|redis)://[^\s]+', caseSensitive: false),
      '[CONNECTION_STRING]'
    ),
  ];

  final ErrorSanitizationConfig _config;

  /// Creates a new error sanitizer with the given configuration.
  ErrorSanitizer([ErrorSanitizationConfig? config])
      : _config = config ?? const ErrorSanitizationConfig();

  /// Sanitizes the given error message.
  ///
  /// Returns a [SanitizedError] containing the sanitized message and metadata.
  SanitizedError sanitize(String message) {
    if (!_config.enabled) {
      return SanitizedError(
        message: message,
        wasSanitized: false,
      );
    }

    var sanitizedMessage = message;
    final matchedPatterns = <String>[];

    for (final (pattern, replacement) in _patterns) {
      if (pattern.hasMatch(sanitizedMessage)) {
        matchedPatterns.add(replacement);
        sanitizedMessage = sanitizedMessage.replaceAll(pattern, replacement);
      }
    }

    return SanitizedError(
      message: sanitizedMessage,
      originalMessage: _config.preserveOriginal ? message : null,
      wasSanitized: matchedPatterns.isNotEmpty,
      sanitizedPatterns: matchedPatterns,
    );
  }

  /// Sanitizes the message from an exception.
  ///
  /// Returns the sanitized message string.
  String sanitizeException(Object exception) {
    final message = exception.toString();
    return sanitize(message).message;
  }

  /// Creates a sanitized copy of an error message.
  ///
  /// This is a convenience method that returns just the sanitized string.
  String sanitizeMessage(String message) {
    return sanitize(message).message;
  }
}

/// Global error sanitizer instance.
///
/// Use this for convenience when you don't need custom configuration.
final defaultErrorSanitizer = ErrorSanitizer();

/// Sanitizes an error message using the default sanitizer.
///
/// This is a convenience function for quick sanitization.
String sanitizeErrorMessage(String message) {
  return defaultErrorSanitizer.sanitizeMessage(message);
}

/// Sanitizes an exception message using the default sanitizer.
///
/// This is a convenience function for quick sanitization.
String sanitizeExceptionMessage(Object exception) {
  return defaultErrorSanitizer.sanitizeException(exception);
}
