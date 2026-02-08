import 'package:test/test.dart';
import 'package:teracrafts_flagkit/teracrafts_flagkit.dart';

void main() {
  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(
        threshold: 3,
        resetTimeout: const Duration(milliseconds: 100),
      );
    });

    test('starts in closed state', () {
      expect(breaker.isClosed, isTrue);
      expect(breaker.isOpen, isFalse);
      expect(breaker.isHalfOpen, isFalse);
    });

    test('canExecute is true when closed', () {
      expect(breaker.canExecute, isTrue);
    });

    test('records successful executions', () {
      breaker.recordSuccess();
      expect(breaker.failureCount, equals(0));
      expect(breaker.isClosed, isTrue);
    });

    test('opens after threshold failures', () {
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isClosed, isTrue);

      breaker.recordFailure();
      expect(breaker.isOpen, isTrue);
      expect(breaker.canExecute, isFalse);
    });

    test('transitions to half-open after reset timeout', () async {
      // Open the circuit
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isOpen, isTrue);

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 150));
      expect(breaker.isHalfOpen, isTrue);
      expect(breaker.canExecute, isTrue);
    });

    test('closes on success after half-open', () async {
      // Open the circuit
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();

      // Wait for half-open
      await Future.delayed(const Duration(milliseconds: 150));
      expect(breaker.isHalfOpen, isTrue);

      // Record success
      breaker.recordSuccess();
      expect(breaker.isClosed, isTrue);
      expect(breaker.failureCount, equals(0));
    });

    test('opens on failure when half-open', () async {
      // Open the circuit
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();

      // Wait for half-open
      await Future.delayed(const Duration(milliseconds: 150));
      expect(breaker.isHalfOpen, isTrue);

      // Record failure
      breaker.recordFailure();
      expect(breaker.isOpen, isTrue);
    });

    test('reset() restores to closed state', () {
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isOpen, isTrue);

      breaker.reset();
      expect(breaker.isClosed, isTrue);
      expect(breaker.failureCount, equals(0));
    });

    test('execute() runs action when closed', () async {
      var called = false;
      await breaker.execute(() async {
        called = true;
        return 'result';
      });
      expect(called, isTrue);
    });

    test('execute() throws when circuit is open', () async {
      // Open the circuit
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();

      expect(
        () => breaker.execute(() async => 'result'),
        throwsA(isA<FlagKitException>()),
      );
    });

    test('execute() uses fallback when circuit is open', () async {
      // Open the circuit
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();

      final result = await breaker.execute(
        () async => 'primary',
        () => 'fallback',
      );
      expect(result, equals('fallback'));
    });

    test('execute() records success on successful action', () async {
      breaker.recordFailure();
      expect(breaker.failureCount, equals(1));

      await breaker.execute(() async => 'result');
      expect(breaker.failureCount, equals(0));
    });

    test('execute() records failure on failed action', () async {
      try {
        await breaker.execute(() async => throw Exception('error'));
      } catch (_) {}

      expect(breaker.failureCount, equals(1));
    });

    test('executeSync() runs action when closed', () {
      var called = false;
      breaker.executeSync(() {
        called = true;
        return 'result';
      });
      expect(called, isTrue);
    });

    test('executeSync() throws when circuit is open', () {
      // Open the circuit
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordFailure();

      expect(
        () => breaker.executeSync(() => 'result'),
        throwsA(isA<FlagKitException>()),
      );
    });
  });
}
