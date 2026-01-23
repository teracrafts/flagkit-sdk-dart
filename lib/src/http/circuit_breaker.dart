import '../error/error_code.dart';
import '../error/flagkit_exception.dart';

/// Circuit breaker states.
enum CircuitState {
  closed,
  open,
  halfOpen,
}

/// Thread-safe circuit breaker for fault tolerance.
class CircuitBreaker {
  final int threshold;
  final Duration resetTimeout;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _openedAt;

  CircuitBreaker({
    this.threshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
  });

  CircuitState get state {
    if (_state == CircuitState.open && _openedAt != null) {
      if (DateTime.now().difference(_openedAt!) >= resetTimeout) {
        _state = CircuitState.halfOpen;
      }
    }
    return _state;
  }

  bool get isOpen => state == CircuitState.open;
  bool get isClosed => state == CircuitState.closed;
  bool get isHalfOpen => state == CircuitState.halfOpen;

  int get failureCount => _failureCount;

  bool get canExecute {
    final currentState = state;
    return currentState == CircuitState.closed ||
        currentState == CircuitState.halfOpen;
  }

  void recordSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
    _openedAt = null;
  }

  void recordFailure() {
    _failureCount++;

    if (_state == CircuitState.halfOpen || _failureCount >= threshold) {
      _state = CircuitState.open;
      _openedAt = DateTime.now();
    }
  }

  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _openedAt = null;
  }

  Future<T> execute<T>(Future<T> Function() action,
      [T Function()? fallback]) async {
    if (!canExecute) {
      if (fallback != null) {
        return fallback();
      }

      throw FlagKitException.networkError(
        ErrorCode.httpCircuitOpen,
        'Circuit breaker is open',
      );
    }

    try {
      final result = await action();
      recordSuccess();
      return result;
    } catch (e) {
      if (e is FlagKitException && e.code == ErrorCode.httpCircuitOpen) {
        rethrow;
      }
      recordFailure();
      rethrow;
    }
  }

  T executeSync<T>(T Function() action, [T Function()? fallback]) {
    if (!canExecute) {
      if (fallback != null) {
        return fallback();
      }

      throw FlagKitException.networkError(
        ErrorCode.httpCircuitOpen,
        'Circuit breaker is open',
      );
    }

    try {
      final result = action();
      recordSuccess();
      return result;
    } catch (e) {
      if (e is FlagKitException && e.code == ErrorCode.httpCircuitOpen) {
        rethrow;
      }
      recordFailure();
      rethrow;
    }
  }
}
