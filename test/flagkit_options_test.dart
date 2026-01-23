import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

void main() {
  group('FlagKitOptions', () {
    test('creates options with required apiKey', () {
      final options = FlagKitOptions(apiKey: 'sdk_test_key');
      expect(options.apiKey, equals('sdk_test_key'));
    });

    test('uses default values', () {
      final options = FlagKitOptions(apiKey: 'sdk_test_key');

      expect(options.pollingInterval, equals(FlagKitOptions.defaultPollingInterval));
      expect(options.cacheTtl, equals(FlagKitOptions.defaultCacheTtl));
      expect(options.maxCacheSize, equals(FlagKitOptions.defaultMaxCacheSize));
      expect(options.cacheEnabled, isTrue);
      expect(options.eventsEnabled, isTrue);
      expect(options.timeout, equals(FlagKitOptions.defaultTimeout));
      expect(options.retryAttempts, equals(FlagKitOptions.defaultRetryAttempts));
    });

    test('validates empty apiKey', () {
      final options = FlagKitOptions(apiKey: '');

      expect(
        () => options.validate(),
        throwsA(isA<FlagKitException>().having(
          (e) => e.code,
          'code',
          equals(ErrorCode.configInvalidApiKey),
        )),
      );
    });

    test('validates apiKey format - sdk_ prefix', () {
      final options = FlagKitOptions(apiKey: 'sdk_valid_key');
      expect(() => options.validate(), returnsNormally);
    });

    test('validates apiKey format - srv_ prefix', () {
      final options = FlagKitOptions(apiKey: 'srv_server_key');
      expect(() => options.validate(), returnsNormally);
    });

    test('validates apiKey format - cli_ prefix', () {
      final options = FlagKitOptions(apiKey: 'cli_client_key');
      expect(() => options.validate(), returnsNormally);
    });

    test('rejects invalid apiKey prefix', () {
      final options = FlagKitOptions(apiKey: 'invalid_key');

      expect(
        () => options.validate(),
        throwsA(isA<FlagKitException>().having(
          (e) => e.code,
          'code',
          equals(ErrorCode.configInvalidApiKey),
        )),
      );
    });

    test('validates negative pollingInterval', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        pollingInterval: const Duration(seconds: -1),
      );

      expect(
        () => options.validate(),
        throwsA(isA<FlagKitException>().having(
          (e) => e.code,
          'code',
          equals(ErrorCode.configInvalidPollingInterval),
        )),
      );
    });

    test('validates zero pollingInterval', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        pollingInterval: Duration.zero,
      );

      expect(
        () => options.validate(),
        throwsA(isA<FlagKitException>()),
      );
    });

    test('validates negative cacheTtl', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        cacheTtl: const Duration(seconds: -1),
      );

      expect(
        () => options.validate(),
        throwsA(isA<FlagKitException>().having(
          (e) => e.code,
          'code',
          equals(ErrorCode.configInvalidCacheTtl),
        )),
      );
    });

    test('accepts custom values', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        pollingInterval: const Duration(seconds: 60),
        cacheTtl: const Duration(minutes: 10),
        maxCacheSize: 500,
        cacheEnabled: false,
        eventsEnabled: false,
        timeout: const Duration(seconds: 30),
        retryAttempts: 5,
      );

      expect(options.pollingInterval, equals(const Duration(seconds: 60)));
      expect(options.cacheTtl, equals(const Duration(minutes: 10)));
      expect(options.maxCacheSize, equals(500));
      expect(options.cacheEnabled, isFalse);
      expect(options.eventsEnabled, isFalse);
      expect(options.timeout, equals(const Duration(seconds: 30)));
      expect(options.retryAttempts, equals(5));
    });

    test('accepts bootstrap data', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {
          'dark-mode': true,
          'max-items': 100,
        },
      );

      expect(options.bootstrap, isNotNull);
      expect(options.bootstrap!['dark-mode'], isTrue);
      expect(options.bootstrap!['max-items'], equals(100));
    });
  });

  group('FlagKitOptionsBuilder', () {
    test('builds options with all properties', () {
      final options = FlagKitOptions.builder('sdk_test_key')
          .pollingInterval(const Duration(seconds: 45))
          .cacheTtl(const Duration(minutes: 3))
          .maxCacheSize(200)
          .cacheEnabled(false)
          .eventBatchSize(20)
          .eventFlushInterval(const Duration(seconds: 15))
          .eventsEnabled(false)
          .timeout(const Duration(seconds: 15))
          .retryAttempts(2)
          .circuitBreakerThreshold(3)
          .circuitBreakerResetTimeout(const Duration(seconds: 60))
          .bootstrap({'feature': true})
          .build();

      expect(options.apiKey, equals('sdk_test_key'));
      expect(options.pollingInterval, equals(const Duration(seconds: 45)));
      expect(options.cacheTtl, equals(const Duration(minutes: 3)));
      expect(options.maxCacheSize, equals(200));
      expect(options.cacheEnabled, isFalse);
      expect(options.eventBatchSize, equals(20));
      expect(options.eventFlushInterval, equals(const Duration(seconds: 15)));
      expect(options.eventsEnabled, isFalse);
      expect(options.timeout, equals(const Duration(seconds: 15)));
      expect(options.retryAttempts, equals(2));
      expect(options.circuitBreakerThreshold, equals(3));
      expect(options.circuitBreakerResetTimeout, equals(const Duration(seconds: 60)));
      expect(options.bootstrap!['feature'], isTrue);
    });

    test('builder returns self for chaining', () {
      final builder = FlagKitOptions.builder('sdk_test_key');

      expect(builder.pollingInterval(const Duration(seconds: 30)), same(builder));
      expect(builder.cacheTtl(const Duration(minutes: 5)), same(builder));
    });
  });
}
