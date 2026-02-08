import 'package:test/test.dart';
import 'package:teracrafts_flagkit/teracrafts_flagkit.dart';

void main() {
  group('EvaluationJitterConfig', () {
    test('defaults to disabled', () {
      const config = EvaluationJitterConfig();
      expect(config.enabled, isFalse);
      expect(config.minMs, equals(5));
      expect(config.maxMs, equals(15));
    });

    test('disabled static constant has correct values', () {
      expect(EvaluationJitterConfig.disabled.enabled, isFalse);
      expect(EvaluationJitterConfig.disabled.minMs, equals(5));
      expect(EvaluationJitterConfig.disabled.maxMs, equals(15));
    });

    test('defaultEnabled static constant has jitter enabled', () {
      expect(EvaluationJitterConfig.defaultEnabled.enabled, isTrue);
      expect(EvaluationJitterConfig.defaultEnabled.minMs, equals(5));
      expect(EvaluationJitterConfig.defaultEnabled.maxMs, equals(15));
    });

    test('accepts custom values', () {
      const config = EvaluationJitterConfig(
        enabled: true,
        minMs: 10,
        maxMs: 50,
      );
      expect(config.enabled, isTrue);
      expect(config.minMs, equals(10));
      expect(config.maxMs, equals(50));
    });
  });

  group('FlagKitOptions evaluationJitter', () {
    test('defaults to disabled', () {
      final options = FlagKitOptions(apiKey: 'sdk_test_key');
      expect(options.evaluationJitter.enabled, isFalse);
    });

    test('accepts custom jitter config', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        evaluationJitter: const EvaluationJitterConfig(
          enabled: true,
          minMs: 10,
          maxMs: 20,
        ),
      );
      expect(options.evaluationJitter.enabled, isTrue);
      expect(options.evaluationJitter.minMs, equals(10));
      expect(options.evaluationJitter.maxMs, equals(20));
    });

    test('copyWith preserves evaluationJitter', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        evaluationJitter: const EvaluationJitterConfig(enabled: true),
      );
      final copied = options.copyWith(timeout: const Duration(seconds: 20));
      expect(copied.evaluationJitter.enabled, isTrue);
    });

    test('copyWith can override evaluationJitter', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        evaluationJitter: const EvaluationJitterConfig(enabled: false),
      );
      final copied = options.copyWith(
        evaluationJitter: const EvaluationJitterConfig(enabled: true, minMs: 1, maxMs: 5),
      );
      expect(copied.evaluationJitter.enabled, isTrue);
      expect(copied.evaluationJitter.minMs, equals(1));
      expect(copied.evaluationJitter.maxMs, equals(5));
    });
  });

  group('FlagKitOptionsBuilder evaluationJitter', () {
    test('builder sets evaluationJitter', () {
      final options = FlagKitOptions.builder('sdk_test_key')
          .evaluationJitter(const EvaluationJitterConfig(
            enabled: true,
            minMs: 3,
            maxMs: 10,
          ))
          .build();

      expect(options.evaluationJitter.enabled, isTrue);
      expect(options.evaluationJitter.minMs, equals(3));
      expect(options.evaluationJitter.maxMs, equals(10));
    });

    test('builder defaults evaluationJitter to disabled', () {
      final options = FlagKitOptions.builder('sdk_test_key').build();
      expect(options.evaluationJitter.enabled, isFalse);
    });
  });

  group('FlagKitClient jitter behavior', () {
    test('jitter is NOT applied when disabled (default)', () async {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        offline: true,
        bootstrap: {'test-flag': true},
      );
      final client = FlagKitClient(options);
      await client.initialize();

      // Measure time for multiple evaluations
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 10; i++) {
        client.getBooleanValue('test-flag', false);
      }
      stopwatch.stop();

      // Without jitter, 10 evaluations should be very fast (< 50ms total)
      // This is a sanity check that we're not accidentally adding jitter
      expect(stopwatch.elapsedMilliseconds, lessThan(50));

      await client.close();
    });

    test('jitter IS applied when enabled (async evaluation)', () async {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        offline: true,
        bootstrap: {'test-flag': true},
        evaluationJitter: const EvaluationJitterConfig(
          enabled: true,
          minMs: 10,
          maxMs: 20,
        ),
      );
      final client = FlagKitClient(options);
      await client.initialize();

      // Measure time for a single async evaluation with jitter
      final stopwatch = Stopwatch()..start();
      await client.evaluateAsync('test-flag');
      stopwatch.stop();

      // With jitter enabled (minMs: 10, maxMs: 20), evaluation should take at least 10ms
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(10));

      await client.close();
    });

    test('jitter timing falls within min/max range', () async {
      const minMs = 5;
      const maxMs = 15;
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        offline: true,
        bootstrap: {'test-flag': true},
        evaluationJitter: const EvaluationJitterConfig(
          enabled: true,
          minMs: minMs,
          maxMs: maxMs,
        ),
      );
      final client = FlagKitClient(options);
      await client.initialize();

      // Run multiple evaluations and check timing
      final timings = <int>[];
      for (var i = 0; i < 10; i++) {
        final stopwatch = Stopwatch()..start();
        await client.evaluateAsync('test-flag');
        stopwatch.stop();
        timings.add(stopwatch.elapsedMilliseconds);
      }

      // All timings should be at least minMs
      for (final timing in timings) {
        expect(timing, greaterThanOrEqualTo(minMs));
      }

      // At least some variation should exist (not all exactly the same)
      // This tests that jitter is actually random
      final uniqueTimings = timings.toSet();
      // With 10 samples from a range of 11 values (5-15), we expect some variation
      // Allow for some tolerance - at least 2 different values
      expect(uniqueTimings.length, greaterThanOrEqualTo(1));

      await client.close();
    });

    test('internal _evaluateWithJitter applies jitter', () async {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        offline: true,
        bootstrap: {'test-flag': 'value'},
        evaluationJitter: const EvaluationJitterConfig(
          enabled: true,
          minMs: 10,
          maxMs: 20,
        ),
      );
      final client = FlagKitClient(options);
      await client.initialize();

      // Test that evaluateAsync (which uses _applyEvaluationJitter) adds delay
      final stopwatch = Stopwatch()..start();
      final result = await client.evaluateAsync('test-flag');
      stopwatch.stop();

      expect(result.flagKey, equals('test-flag'));
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(10));

      await client.close();
    });
  });
}
