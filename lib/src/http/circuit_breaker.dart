import '../error/error_code.dart';
import '../error/flagkit_exception.dart';

/// Circuit breaker states.
///
/// State transitions:
/// - CLOSED -> OPEN: When failures >= failureThreshold
/// - OPEN -> HALF_OPEN: After resetTimeout
/// - HALF_OPEN -> CLOSED: After successThreshold successes
/// - HALF_OPEN -> OPEN: On any failure
enum CircuitState {
  /// Normal operation - requests are allowed.
  closed,

  /// Circuit is open - requests are rejected.
  open,

  /// Testing recovery - limited requests allowed.
  halfOpen,
}

/// Configuration for the circuit breaker.
class CircuitBreakerConfig {
  /// Number of failures before opening circuit. Default: 5
  final int failureThreshold;

  /// Time before attempting recovery. Default: 30 seconds
  final Duration resetTimeout;

  /// Number of successes in half-open to close circuit. Default: 1
  final int successThreshold;

  const CircuitBreakerConfig({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
    this.successThreshold = 1,
  });

  /// Default circuit breaker configuration per spec.
  static const defaultConfig = CircuitBreakerConfig();
}

/// Statistics about the circuit breaker state.
class CircuitBreakerStats {
  final CircuitState state;
  final int failures;
  final int successes;
  final DateTime? lastFailureTime;
  final int timeUntilResetMs;

  const CircuitBreakerStats({
    required this.state,
    required this.failures,
    required this.successes,
    this.lastFailureTime,
    required this.timeUntilResetMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'state': state.name,
      'failures': failures,
      'successes': successes,
      'lastFailureTime': lastFailureTime?.toIso8601String(),
      'timeUntilResetMs': timeUntilResetMs,
    };
  }
}

/// Error thrown when the circuit breaker is open.
class CircuitOpenException extends FlagKitException {
  /// Time in milliseconds until the circuit may reset.
  final int timeUntilResetMs;

  CircuitOpenException(this.timeUntilResetMs)
      : super(
          ErrorCode.httpCircuitOpen,
          'Circuit breaker is open. Reset in ${timeUntilResetMs}ms',
        );
}

/// Circuit breaker for protecting against cascading failures.
///
/// Implements the circuit breaker pattern per the SDK spec:
/// - Opens after [failureThreshold] consecutive failures
/// - Stays open for [resetTimeout] duration
/// - Transitions to half-open state to test recovery
/// - Closes after [successThreshold] successful requests in half-open state
class CircuitBreaker {
  final CircuitBreakerConfig _config;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _successCount = 0;
  DateTime? _lastFailureTime;

  /// Creates a circuit breaker with the given configuration.
  CircuitBreaker({
    int threshold = 5,
    Duration resetTimeout = const Duration(seconds: 30),
    int successThreshold = 1,
  }) : _config = CircuitBreakerConfig(
          failureThreshold: threshold,
          resetTimeout: resetTimeout,
          successThreshold: successThreshold,
        );

  /// Creates a circuit breaker from a config object.
  CircuitBreaker.fromConfig(this._config);

  /// Gets the failure threshold.
  int get threshold => _config.failureThreshold;

  /// Gets the reset timeout.
  Duration get resetTimeout => _config.resetTimeout;

  /// Gets the current state, checking for automatic transitions.
  CircuitState get state {
    _checkStateTransition();
    return _state;
  }

  /// Returns true if the circuit is open.
  bool get isOpen => state == CircuitState.open;

  /// Returns true if the circuit is closed.
  bool get isClosed => state == CircuitState.closed;

  /// Returns true if the circuit is half-open.
  bool get isHalfOpen => state == CircuitState.halfOpen;

  /// Gets the current failure count.
  int get failureCount => _failureCount;

  /// Gets the current success count (relevant in half-open state).
  int get successCount => _successCount;

  /// Returns true if requests can be executed.
  bool get canExecute {
    final currentState = state;
    return currentState == CircuitState.closed ||
        currentState == CircuitState.halfOpen;
  }

  /// Gets the time until the circuit may reset, in milliseconds.
  int get timeUntilResetMs {
    if (_state != CircuitState.open || _lastFailureTime == null) {
      return 0;
    }
    final elapsed = DateTime.now().difference(_lastFailureTime!);
    final remaining = _config.resetTimeout - elapsed;
    return remaining.isNegative ? 0 : remaining.inMilliseconds;
  }

  /// Records a successful operation.
  void recordSuccess() {
    if (_state == CircuitState.halfOpen) {
      _successCount++;

      if (_successCount >= _config.successThreshold) {
        _transitionTo(CircuitState.closed);
        _reset();
      }
    } else if (_state == CircuitState.closed) {
      // Reset failure count on success in closed state
      _failureCount = 0;
    }
  }

  /// Records a failed operation.
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      // Any failure in half-open state opens the circuit
      _transitionTo(CircuitState.open);
      _successCount = 0;
    } else if (_state == CircuitState.closed &&
        _failureCount >= _config.failureThreshold) {
      _transitionTo(CircuitState.open);
    }
  }

  /// Manually resets the circuit breaker to closed state.
  void reset() {
    _transitionTo(CircuitState.closed);
    _reset();
  }

  /// Gets statistics about the circuit breaker.
  CircuitBreakerStats getStats() {
    return CircuitBreakerStats(
      state: state,
      failures: _failureCount,
      successes: _successCount,
      lastFailureTime: _lastFailureTime,
      timeUntilResetMs: timeUntilResetMs,
    );
  }

  /// Executes an async operation through the circuit breaker.
  ///
  /// If the circuit is open and a [fallback] is provided, it will be called
  /// instead of throwing an exception.
  Future<T> execute<T>(Future<T> Function() action,
      [T Function()? fallback]) async {
    _checkStateTransition();

    if (_state == CircuitState.open) {
      if (fallback != null) {
        return fallback();
      }
      throw CircuitOpenException(timeUntilResetMs);
    }

    try {
      final result = await action();
      recordSuccess();
      return result;
    } catch (e) {
      if (e is CircuitOpenException) {
        rethrow;
      }
      recordFailure();
      rethrow;
    }
  }

  /// Executes a synchronous operation through the circuit breaker.
  ///
  /// If the circuit is open and a [fallback] is provided, it will be called
  /// instead of throwing an exception.
  T executeSync<T>(T Function() action, [T Function()? fallback]) {
    _checkStateTransition();

    if (_state == CircuitState.open) {
      if (fallback != null) {
        return fallback();
      }
      throw CircuitOpenException(timeUntilResetMs);
    }

    try {
      final result = action();
      recordSuccess();
      return result;
    } catch (e) {
      if (e is CircuitOpenException) {
        rethrow;
      }
      recordFailure();
      rethrow;
    }
  }

  void _checkStateTransition() {
    if (_state == CircuitState.open && _lastFailureTime != null) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed >= _config.resetTimeout) {
        _transitionTo(CircuitState.halfOpen);
        _successCount = 0;
      }
    }
  }

  void _transitionTo(CircuitState newState) {
    _state = newState;
  }

  void _reset() {
    _failureCount = 0;
    _successCount = 0;
    _lastFailureTime = null;
  }
}
