import 'dart:math';

import '../error/error_code.dart';
import '../error/flagkit_exception.dart';

/// Configuration for retry logic.
class RetryConfig {
  /// Maximum number of retry attempts. Default: 3
  final int maxAttempts;

  /// Base delay in milliseconds. Default: 1000
  final int baseDelayMs;

  /// Maximum delay in milliseconds. Default: 30000
  final int maxDelayMs;

  /// Backoff multiplier. Default: 2.0
  final double backoffMultiplier;

  /// Maximum jitter in milliseconds. Default: 100
  final int jitterMs;

  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.backoffMultiplier = 2.0,
    this.jitterMs = 100,
  });

  /// Default retry configuration.
  static const defaultConfig = RetryConfig();
}

/// Result of a retry operation.
class RetryResult<T> {
  /// Whether the operation was successful.
  final bool success;

  /// The value returned by the operation, if successful.
  final T? value;

  /// The error that occurred, if any.
  final Object? error;

  /// The number of attempts made.
  final int attempts;

  const RetryResult({
    required this.success,
    this.value,
    this.error,
    required this.attempts,
  });

  /// Creates a successful result.
  factory RetryResult.successful(T value, int attempts) {
    return RetryResult(
      success: true,
      value: value,
      attempts: attempts,
    );
  }

  /// Creates a failed result.
  factory RetryResult.failed(Object error, int attempts) {
    return RetryResult(
      success: false,
      error: error,
      attempts: attempts,
    );
  }
}

/// Calculates backoff delay with exponential backoff and jitter.
Duration calculateBackoff(int attempt, RetryConfig config, [Random? random]) {
  final rng = random ?? Random();

  // Exponential backoff: baseDelay * (multiplier ^ attempt)
  final exponentialDelay =
      config.baseDelayMs * pow(config.backoffMultiplier, attempt - 1);

  // Cap at maxDelay
  final cappedDelay = min(exponentialDelay.toDouble(), config.maxDelayMs.toDouble());

  // Add jitter to prevent thundering herd
  final jitter = rng.nextDouble() * config.jitterMs;

  return Duration(milliseconds: (cappedDelay + jitter).toInt());
}

/// Checks if an error is retryable.
bool isRetryableError(Object error) {
  if (error is FlagKitException) {
    return const {
      ErrorCode.httpTimeout,
      ErrorCode.httpNetworkError,
      ErrorCode.httpServerError,
      ErrorCode.networkError,
      ErrorCode.networkTimeout,
      ErrorCode.httpRateLimited,
    }.contains(error.code);
  }
  return false;
}

/// Options for retry operations.
class RetryOptions {
  /// Name of the operation for logging.
  final String? operationName;

  /// Custom function to determine if an error should be retried.
  final bool Function(Object error)? shouldRetry;

  /// Callback invoked on each retry attempt.
  final void Function(int attempt, Object error, Duration delay)? onRetry;

  const RetryOptions({
    this.operationName,
    this.shouldRetry,
    this.onRetry,
  });
}

/// Executes an operation with retry logic.
///
/// Retries the operation using exponential backoff with jitter on failure.
/// Only retries errors that are considered retryable (network errors, timeouts, etc).
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  RetryConfig config = RetryConfig.defaultConfig,
  RetryOptions? options,
}) async {
  Object? lastError;

  for (var attempt = 1; attempt <= config.maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      // Check if we should retry
      final shouldRetry = options?.shouldRetry ?? isRetryableError;
      final canRetry = shouldRetry(error);

      if (!canRetry) {
        rethrow;
      }

      // Check if we've exhausted retries
      if (attempt >= config.maxAttempts) {
        rethrow;
      }

      // Calculate and apply backoff
      final delay = calculateBackoff(attempt, config);

      // Call onRetry callback if provided
      options?.onRetry?.call(attempt, error, delay);

      // Wait before retrying
      await Future.delayed(delay);
    }
  }

  // This should never be reached, but Dart needs it for type safety
  throw lastError ?? FlagKitException.networkError(
    ErrorCode.networkError,
    'Retry failed',
  );
}

/// Executes an operation with retry logic and returns a result object.
///
/// Unlike [withRetry], this never throws and always returns a [RetryResult].
Future<RetryResult<T>> withRetryResult<T>(
  Future<T> Function() operation, {
  RetryConfig config = RetryConfig.defaultConfig,
  RetryOptions? options,
}) async {
  Object? lastError;

  for (var attempt = 1; attempt <= config.maxAttempts; attempt++) {
    try {
      final result = await operation();
      return RetryResult.successful(result, attempt);
    } catch (error) {
      lastError = error;

      // Check if we should retry
      final shouldRetry = options?.shouldRetry ?? isRetryableError;
      final canRetry = shouldRetry(error);

      if (!canRetry || attempt >= config.maxAttempts) {
        return RetryResult.failed(error, attempt);
      }

      // Calculate and apply backoff
      final delay = calculateBackoff(attempt, config);

      // Call onRetry callback if provided
      options?.onRetry?.call(attempt, error, delay);

      // Wait before retrying
      await Future.delayed(delay);
    }
  }

  return RetryResult.failed(
    lastError ?? FlagKitException.networkError(
      ErrorCode.networkError,
      'Retry failed',
    ),
    config.maxAttempts,
  );
}

/// Parses a Retry-After header value.
///
/// Can be either a number of seconds or an HTTP date.
/// Returns null if the value cannot be parsed.
Duration? parseRetryAfter(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  // Try parsing as number of seconds
  final seconds = int.tryParse(value);
  if (seconds != null && seconds > 0) {
    return Duration(seconds: seconds);
  }

  // Try parsing as HTTP date
  try {
    final date = DateTime.parse(value);
    final now = DateTime.now();
    if (date.isAfter(now)) {
      return date.difference(now);
    }
  } catch (_) {
    // Ignore parse errors
  }

  return null;
}
