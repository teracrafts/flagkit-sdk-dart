import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

void main() {
  group('canonicalizeObject', () {
    test('should produce consistent output for same data', () {
      final data = {'b': 2, 'a': 1, 'c': 3};

      final result1 = canonicalizeObject(data);
      final result2 = canonicalizeObject(data);

      expect(result1, equals(result2));
    });

    test('should sort keys alphabetically', () {
      final data = {'z': 1, 'a': 2, 'm': 3};

      final result = canonicalizeObject(data);

      expect(result, equals('{"a":2,"m":3,"z":1}'));
    });

    test('should handle nested objects', () {
      final data = {
        'outer': {'b': 2, 'a': 1},
        'simple': 'value',
      };

      final result = canonicalizeObject(data);

      expect(result, equals('{"outer":{"a":1,"b":2},"simple":"value"}'));
    });

    test('should handle arrays', () {
      final data = {'arr': [3, 1, 2], 'key': 'val'};

      final result = canonicalizeObject(data);

      expect(result, equals('{"arr":[3,1,2],"key":"val"}'));
    });

    test('should handle null values', () {
      final data = {'key': null, 'other': 'value'};

      final result = canonicalizeObject(data);

      expect(result, equals('{"key":null,"other":"value"}'));
    });

    test('should handle boolean values', () {
      final data = {'enabled': true, 'disabled': false};

      final result = canonicalizeObject(data);

      expect(result, equals('{"disabled":false,"enabled":true}'));
    });

    test('should handle string escaping', () {
      final data = {'key': 'value with "quotes"'};

      final result = canonicalizeObject(data);

      // JSON encoding escapes quotes as \"
      expect(result, contains('\\"quotes\\"'));
    });

    test('should handle empty objects', () {
      final data = <String, dynamic>{};

      final result = canonicalizeObject(data);

      expect(result, equals('{}'));
    });

    test('should handle numeric values', () {
      final data = {'int': 42, 'double': 3.14};

      final result = canonicalizeObject(data);

      expect(result, contains('"int":42'));
      expect(result, contains('"double":3.14'));
    });
  });

  group('createSignedBootstrap', () {
    const testApiKey = 'sdk_test_key_12345678';

    test('should create bootstrap with signature and timestamp', () {
      final flags = {'feature-flag': true, 'other-flag': 'value'};

      final bootstrap = createSignedBootstrap(flags, testApiKey);

      expect(bootstrap.flags, equals(flags));
      expect(bootstrap.signature, isNotNull);
      expect(bootstrap.signature, isNotEmpty);
      expect(bootstrap.timestamp, isNotNull);
      expect(bootstrap.timestamp, greaterThan(0));
    });

    test('should create bootstrap with custom timestamp', () {
      final flags = {'feature-flag': true};
      final customTimestamp = 1700000000000;

      final bootstrap = createSignedBootstrap(flags, testApiKey, customTimestamp);

      expect(bootstrap.timestamp, equals(customTimestamp));
    });

    test('should produce consistent signatures for same data', () {
      final flags = {'feature-flag': true};
      final timestamp = 1700000000000;

      final bootstrap1 = createSignedBootstrap(flags, testApiKey, timestamp);
      final bootstrap2 = createSignedBootstrap(flags, testApiKey, timestamp);

      expect(bootstrap1.signature, equals(bootstrap2.signature));
    });

    test('should produce different signatures for different data', () {
      final timestamp = 1700000000000;

      final bootstrap1 = createSignedBootstrap({'flag': true}, testApiKey, timestamp);
      final bootstrap2 = createSignedBootstrap({'flag': false}, testApiKey, timestamp);

      expect(bootstrap1.signature, isNot(equals(bootstrap2.signature)));
    });

    test('should produce different signatures for different timestamps', () {
      final flags = {'feature-flag': true};

      final bootstrap1 = createSignedBootstrap(flags, testApiKey, 1700000000000);
      final bootstrap2 = createSignedBootstrap(flags, testApiKey, 1700000000001);

      expect(bootstrap1.signature, isNot(equals(bootstrap2.signature)));
    });
  });

  group('verifyBootstrapSignature', () {
    const testApiKey = 'sdk_test_key_12345678';
    const defaultConfig = BootstrapVerificationConfig();

    test('should accept valid signature', () {
      final bootstrap = createSignedBootstrap(
        {'feature-flag': true},
        testApiKey,
      );

      final result = verifyBootstrapSignature(bootstrap, testApiKey, defaultConfig);

      expect(result.valid, isTrue);
      expect(result.error, isNull);
    });

    test('should reject invalid signature', () {
      final bootstrap = BootstrapConfig(
        flags: {'feature-flag': true},
        signature: 'invalid_signature_12345678901234567890123456789012',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final result = verifyBootstrapSignature(bootstrap, testApiKey, defaultConfig);

      expect(result.valid, isFalse);
      expect(result.error, contains('signature mismatch'));
    });

    test('should reject missing signature when verification enabled', () {
      final bootstrap = BootstrapConfig(
        flags: {'feature-flag': true},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final result = verifyBootstrapSignature(bootstrap, testApiKey, defaultConfig);

      expect(result.valid, isFalse);
      expect(result.error, contains('missing'));
    });

    test('should reject expired timestamp', () {
      final oldTimestamp = DateTime.now().millisecondsSinceEpoch - 100000000; // ~27 hours ago
      final bootstrap = createSignedBootstrap(
        {'feature-flag': true},
        testApiKey,
        oldTimestamp,
      );

      final config = const BootstrapVerificationConfig(maxAge: 86400000); // 24 hours

      final result = verifyBootstrapSignature(bootstrap, testApiKey, config);

      expect(result.valid, isFalse);
      expect(result.error, contains('expired'));
    });

    test('should reject future timestamp', () {
      final futureTimestamp = DateTime.now().millisecondsSinceEpoch + 3600000; // 1 hour in future
      final bootstrap = createSignedBootstrap(
        {'feature-flag': true},
        testApiKey,
        futureTimestamp,
      );

      final result = verifyBootstrapSignature(bootstrap, testApiKey, defaultConfig);

      expect(result.valid, isFalse);
      expect(result.error, contains('future'));
    });

    test('should accept bootstrap when verification is disabled', () {
      final bootstrap = BootstrapConfig(
        flags: {'feature-flag': true},
        signature: 'invalid_signature',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      final config = const BootstrapVerificationConfig(enabled: false);

      final result = verifyBootstrapSignature(bootstrap, testApiKey, config);

      expect(result.valid, isTrue);
    });

    test('should reject tampered data', () {
      // Create valid bootstrap
      final bootstrap = createSignedBootstrap(
        {'feature-flag': true},
        testApiKey,
      );

      // Tamper with the data
      final tamperedBootstrap = BootstrapConfig(
        flags: {'feature-flag': false}, // Changed from true to false
        signature: bootstrap.signature,
        timestamp: bootstrap.timestamp,
      );

      final result = verifyBootstrapSignature(tamperedBootstrap, testApiKey, defaultConfig);

      expect(result.valid, isFalse);
      expect(result.error, contains('mismatch'));
    });

    test('should reject signature made with different API key', () {
      final bootstrap = createSignedBootstrap(
        {'feature-flag': true},
        'sdk_different_key_123',
      );

      final result = verifyBootstrapSignature(bootstrap, testApiKey, defaultConfig);

      expect(result.valid, isFalse);
    });
  });

  group('handleBootstrapVerificationFailure', () {
    test('should throw SecurityException when onFailure is error', () {
      const result = BootstrapVerificationResult.failure('Test error');
      const config = BootstrapVerificationConfig(onFailure: 'error');

      expect(
        () => handleBootstrapVerificationFailure(result, config),
        throwsA(isA<SecurityException>()),
      );
    });

    test('should call onWarn callback when onFailure is warn', () {
      const result = BootstrapVerificationResult.failure('Test error');
      const config = BootstrapVerificationConfig(onFailure: 'warn');

      String? warningMessage;
      handleBootstrapVerificationFailure(
        result,
        config,
        onWarn: (msg) => warningMessage = msg,
      );

      expect(warningMessage, isNotNull);
      expect(warningMessage, contains('Test error'));
    });

    test('should do nothing when onFailure is ignore', () {
      const result = BootstrapVerificationResult.failure('Test error');
      const config = BootstrapVerificationConfig(onFailure: 'ignore');

      String? warningMessage;
      // Should not throw
      handleBootstrapVerificationFailure(
        result,
        config,
        onWarn: (msg) => warningMessage = msg,
      );

      expect(warningMessage, isNull);
    });

    test('should do nothing for valid results', () {
      const result = BootstrapVerificationResult.success();
      const config = BootstrapVerificationConfig(onFailure: 'error');

      // Should not throw even with error config
      expect(
        () => handleBootstrapVerificationFailure(result, config),
        returnsNormally,
      );
    });
  });

  group('BootstrapConfig', () {
    test('should create from JSON', () {
      final json = {
        'flags': {'feature': true},
        'signature': 'abc123',
        'timestamp': 1700000000000,
      };

      final config = BootstrapConfig.fromJson(json);

      expect(config.flags, equals({'feature': true}));
      expect(config.signature, equals('abc123'));
      expect(config.timestamp, equals(1700000000000));
    });

    test('should convert to JSON', () {
      const config = BootstrapConfig(
        flags: {'feature': true},
        signature: 'abc123',
        timestamp: 1700000000000,
      );

      final json = config.toJson();

      expect(json['flags'], equals({'feature': true}));
      expect(json['signature'], equals('abc123'));
      expect(json['timestamp'], equals(1700000000000));
    });

    test('should handle missing optional fields', () {
      final json = {
        'flags': {'feature': true},
      };

      final config = BootstrapConfig.fromJson(json);

      expect(config.flags, equals({'feature': true}));
      expect(config.signature, isNull);
      expect(config.timestamp, isNull);
    });
  });

  group('BootstrapVerificationConfig', () {
    test('should have correct defaults', () {
      const config = BootstrapVerificationConfig();

      expect(config.enabled, isTrue);
      expect(config.maxAge, equals(86400000));
      expect(config.onFailure, equals('warn'));
    });

    test('disabled config should have enabled false', () {
      const config = BootstrapVerificationConfig.disabled;

      expect(config.enabled, isFalse);
    });

    test('strict config should have error onFailure', () {
      const config = BootstrapVerificationConfig.strict;

      expect(config.onFailure, equals('error'));
    });
  });

  group('FlagKitClient with bootstrap verification', () {
    const testApiKey = 'sdk_test_key_12345678';

    test('should load bootstrap with valid signature', () {
      final bootstrap = createSignedBootstrap(
        {'test-flag': true, 'string-flag': 'hello'},
        testApiKey,
      );

      final client = FlagKitClient(FlagKitOptions(
        apiKey: testApiKey,
        bootstrapConfig: bootstrap,
        enablePolling: false,
        eventsEnabled: false,
      ));

      expect(client.getBooleanValue('test-flag', false), isTrue);
      expect(client.getStringValue('string-flag', 'default'), equals('hello'));
    });

    test('should load legacy bootstrap format', () {
      final client = FlagKitClient(FlagKitOptions(
        apiKey: testApiKey,
        bootstrap: {'legacy-flag': 42},
        enablePolling: false,
        eventsEnabled: false,
      ));

      expect(client.getIntValue('legacy-flag', 0), equals(42));
    });

    test('should prefer bootstrapConfig over bootstrap', () {
      final signedBootstrap = createSignedBootstrap(
        {'flag': 'from-config'},
        testApiKey,
      );

      final client = FlagKitClient(FlagKitOptions(
        apiKey: testApiKey,
        bootstrap: {'flag': 'from-legacy'},
        bootstrapConfig: signedBootstrap,
        enablePolling: false,
        eventsEnabled: false,
      ));

      expect(client.getStringValue('flag', 'default'), equals('from-config'));
    });

    test('should throw on invalid signature with error config', () {
      final invalidBootstrap = BootstrapConfig(
        flags: {'test-flag': true},
        signature: 'invalid_signature_00000000000000000000000000000000',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      expect(
        () => FlagKitClient(FlagKitOptions(
          apiKey: testApiKey,
          bootstrapConfig: invalidBootstrap,
          bootstrapVerification: const BootstrapVerificationConfig(onFailure: 'error'),
          enablePolling: false,
          eventsEnabled: false,
        )),
        throwsA(isA<SecurityException>()),
      );
    });

    test('should warn but load on invalid signature with warn config', () {
      final invalidBootstrap = BootstrapConfig(
        flags: {'test-flag': true},
        signature: 'invalid_signature_00000000000000000000000000000000',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      Object? errorReceived;
      final client = FlagKitClient(FlagKitOptions(
        apiKey: testApiKey,
        bootstrapConfig: invalidBootstrap,
        bootstrapVerification: const BootstrapVerificationConfig(onFailure: 'warn'),
        enablePolling: false,
        eventsEnabled: false,
        onError: (error) => errorReceived = error,
      ));

      // Data should still be loaded
      expect(client.getBooleanValue('test-flag', false), isTrue);
      // Error callback should have been called
      expect(errorReceived, isA<SecurityException>());
    });

    test('should silently load on invalid signature with ignore config', () {
      final invalidBootstrap = BootstrapConfig(
        flags: {'test-flag': true},
        signature: 'invalid_signature_00000000000000000000000000000000',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      Object? errorReceived;
      final client = FlagKitClient(FlagKitOptions(
        apiKey: testApiKey,
        bootstrapConfig: invalidBootstrap,
        bootstrapVerification: const BootstrapVerificationConfig(onFailure: 'ignore'),
        enablePolling: false,
        eventsEnabled: false,
        onError: (error) => errorReceived = error,
      ));

      // Data should be loaded
      expect(client.getBooleanValue('test-flag', false), isTrue);
      // No error callback for ignore mode
      expect(errorReceived, isNull);
    });

    test('should accept unsigned bootstrap with verification disabled', () {
      final unsignedBootstrap = BootstrapConfig(
        flags: {'test-flag': true},
        // No signature
      );

      final client = FlagKitClient(FlagKitOptions(
        apiKey: testApiKey,
        bootstrapConfig: unsignedBootstrap,
        bootstrapVerification: const BootstrapVerificationConfig(enabled: false),
        enablePolling: false,
        eventsEnabled: false,
      ));

      expect(client.getBooleanValue('test-flag', false), isTrue);
    });
  });

  group('SecurityException for bootstrap', () {
    test('should create bootstrap verification failed exception', () {
      final exception = SecurityException.bootstrapVerificationFailed('Test error');

      expect(exception.code, equals(ErrorCode.securityBootstrapVerificationFailed));
      expect(exception.message, contains('Bootstrap verification failed'));
      expect(exception.message, contains('Test error'));
      expect(exception.isSecurityError, isTrue);
    });
  });

  group('BootstrapVerificationResult', () {
    test('should create success result', () {
      const result = BootstrapVerificationResult.success();

      expect(result.valid, isTrue);
      expect(result.error, isNull);
    });

    test('should create failure result with message', () {
      const result = BootstrapVerificationResult.failure('Custom error');

      expect(result.valid, isFalse);
      expect(result.error, equals('Custom error'));
    });
  });
}
