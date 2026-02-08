import 'dart:convert';

import 'package:test/test.dart';
import 'package:teracrafts_flagkit/teracrafts_flagkit.dart';

/// Mock logger for testing.
class MockLogger implements Logger {
  final List<String> debugMessages = [];
  final List<String> infoMessages = [];
  final List<String> warnMessages = [];
  final List<String> errorMessages = [];

  @override
  void debug(String message) => debugMessages.add(message);

  @override
  void info(String message) => infoMessages.add(message);

  @override
  void warn(String message) => warnMessages.add(message);

  @override
  void error(String message) => errorMessages.add(message);

  void clear() {
    debugMessages.clear();
    infoMessages.clear();
    warnMessages.clear();
    errorMessages.clear();
  }
}

void main() {
  group('isPotentialPIIField', () {
    test('should detect email fields', () {
      expect(isPotentialPIIField('email'), isTrue);
      expect(isPotentialPIIField('userEmail'), isTrue);
      expect(isPotentialPIIField('EMAIL'), isTrue);
      expect(isPotentialPIIField('primary_email'), isTrue);
    });

    test('should detect phone fields', () {
      expect(isPotentialPIIField('phone'), isTrue);
      expect(isPotentialPIIField('phoneNumber'), isTrue);
      expect(isPotentialPIIField('mobile'), isTrue);
      expect(isPotentialPIIField('telephone'), isTrue);
      expect(isPotentialPIIField('PHONE_NUMBER'), isTrue);
    });

    test('should detect SSN fields', () {
      expect(isPotentialPIIField('ssn'), isTrue);
      expect(isPotentialPIIField('socialSecurity'), isTrue);
      expect(isPotentialPIIField('social_security'), isTrue);
      expect(isPotentialPIIField('SSN'), isTrue);
    });

    test('should detect credit card fields', () {
      expect(isPotentialPIIField('creditCard'), isTrue);
      expect(isPotentialPIIField('credit_card'), isTrue);
      expect(isPotentialPIIField('cardNumber'), isTrue);
      expect(isPotentialPIIField('card_number'), isTrue);
      expect(isPotentialPIIField('cvv'), isTrue);
    });

    test('should detect authentication fields', () {
      expect(isPotentialPIIField('password'), isTrue);
      expect(isPotentialPIIField('passwd'), isTrue);
      expect(isPotentialPIIField('secret'), isTrue);
      expect(isPotentialPIIField('apiKey'), isTrue);
      expect(isPotentialPIIField('api_key'), isTrue);
      expect(isPotentialPIIField('accessToken'), isTrue);
      expect(isPotentialPIIField('access_token'), isTrue);
      expect(isPotentialPIIField('refreshToken'), isTrue);
      expect(isPotentialPIIField('refresh_token'), isTrue);
      expect(isPotentialPIIField('authToken'), isTrue);
      expect(isPotentialPIIField('auth_token'), isTrue);
      expect(isPotentialPIIField('token'), isTrue);
      expect(isPotentialPIIField('privateKey'), isTrue);
      expect(isPotentialPIIField('private_key'), isTrue);
    });

    test('should detect address fields', () {
      expect(isPotentialPIIField('address'), isTrue);
      expect(isPotentialPIIField('street'), isTrue);
      expect(isPotentialPIIField('zipCode'), isTrue);
      expect(isPotentialPIIField('zip_code'), isTrue);
      expect(isPotentialPIIField('postalCode'), isTrue);
      expect(isPotentialPIIField('postal_code'), isTrue);
    });

    test('should detect date of birth fields', () {
      expect(isPotentialPIIField('dateOfBirth'), isTrue);
      expect(isPotentialPIIField('date_of_birth'), isTrue);
      expect(isPotentialPIIField('dob'), isTrue);
      expect(isPotentialPIIField('birthDate'), isTrue);
      expect(isPotentialPIIField('birth_date'), isTrue);
    });

    test('should detect identification fields', () {
      expect(isPotentialPIIField('passport'), isTrue);
      expect(isPotentialPIIField('driverLicense'), isTrue);
      expect(isPotentialPIIField('driver_license'), isTrue);
      expect(isPotentialPIIField('nationalId'), isTrue);
      expect(isPotentialPIIField('national_id'), isTrue);
    });

    test('should detect financial fields', () {
      expect(isPotentialPIIField('bankAccount'), isTrue);
      expect(isPotentialPIIField('bank_account'), isTrue);
      expect(isPotentialPIIField('routingNumber'), isTrue);
      expect(isPotentialPIIField('routing_number'), isTrue);
      expect(isPotentialPIIField('iban'), isTrue);
      expect(isPotentialPIIField('swift'), isTrue);
    });

    test('should not flag safe fields', () {
      expect(isPotentialPIIField('userId'), isFalse);
      expect(isPotentialPIIField('plan'), isFalse);
      expect(isPotentialPIIField('country'), isFalse);
      expect(isPotentialPIIField('featureEnabled'), isFalse);
      expect(isPotentialPIIField('theme'), isFalse);
      expect(isPotentialPIIField('language'), isFalse);
      expect(isPotentialPIIField('version'), isFalse);
    });
  });

  group('detectPotentialPII', () {
    test('should detect PII in flat objects', () {
      final data = {
        'userId': 'user-123',
        'email': 'user@example.com',
        'plan': 'premium',
      };

      final piiFields = detectPotentialPII(data);
      expect(piiFields, contains('email'));
      expect(piiFields, isNot(contains('userId')));
      expect(piiFields, isNot(contains('plan')));
    });

    test('should detect PII in nested objects', () {
      final data = {
        'user': {
          'email': 'user@example.com',
          'phone': '123-456-7890',
        },
        'settings': {
          'darkMode': true,
        },
      };

      final piiFields = detectPotentialPII(data);
      expect(piiFields, contains('user.email'));
      expect(piiFields, contains('user.phone'));
      expect(piiFields, isNot(contains('settings.darkMode')));
    });

    test('should handle deeply nested objects', () {
      final data = {
        'profile': {
          'contact': {
            'primaryEmail': 'user@example.com',
          },
        },
      };

      final piiFields = detectPotentialPII(data);
      expect(piiFields, contains('profile.contact.primaryEmail'));
    });

    test('should return empty list for safe data', () {
      final data = {
        'userId': 'user-123',
        'plan': 'premium',
        'features': ['dark-mode', 'beta'],
      };

      final piiFields = detectPotentialPII(data);
      expect(piiFields, isEmpty);
    });

    test('should handle empty objects', () {
      final data = <String, dynamic>{};
      final piiFields = detectPotentialPII(data);
      expect(piiFields, isEmpty);
    });

    test('should handle multiple PII fields', () {
      final data = {
        'email': 'test@example.com',
        'phone': '555-1234',
        'ssn': '123-45-6789',
        'creditCard': '4111111111111111',
      };

      final piiFields = detectPotentialPII(data);
      expect(piiFields.length, equals(4));
      expect(piiFields, contains('email'));
      expect(piiFields, contains('phone'));
      expect(piiFields, contains('ssn'));
      expect(piiFields, contains('creditCard'));
    });

    test('should work with custom prefix', () {
      final data = {
        'email': 'test@example.com',
      };

      final piiFields = detectPotentialPII(data, 'root');
      expect(piiFields, contains('root.email'));
    });
  });

  group('warnIfPotentialPII', () {
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
    });

    test('should log warning when PII is detected', () {
      final data = {
        'email': 'user@example.com',
        'phone': '123-456-7890',
      };

      warnIfPotentialPII(data, 'context', mockLogger);

      expect(mockLogger.warnMessages, hasLength(1));
      expect(
        mockLogger.warnMessages.first,
        contains('Potential PII detected'),
      );
      expect(mockLogger.warnMessages.first, contains('email'));
      expect(mockLogger.warnMessages.first, contains('phone'));
    });

    test('should include context-specific advice for context data', () {
      final data = {'email': 'user@example.com'};

      warnIfPotentialPII(data, 'context', mockLogger);

      expect(
        mockLogger.warnMessages.first,
        contains('privateAttributes'),
      );
    });

    test('should include event-specific advice for event data', () {
      final data = {'email': 'user@example.com'};

      warnIfPotentialPII(data, 'event', mockLogger);

      expect(
        mockLogger.warnMessages.first,
        contains('removing sensitive data'),
      );
    });

    test('should not log when no PII is detected', () {
      final data = {
        'userId': 'user-123',
        'plan': 'premium',
      };

      warnIfPotentialPII(data, 'context', mockLogger);

      expect(mockLogger.warnMessages, isEmpty);
    });

    test('should handle null data', () {
      warnIfPotentialPII(null, 'event', mockLogger);
      expect(mockLogger.warnMessages, isEmpty);
    });

    test('should handle null logger', () {
      final data = {'email': 'test@example.com'};
      // Should not throw
      expect(
        () => warnIfPotentialPII(data, 'event', null),
        returnsNormally,
      );
    });

    test('should handle empty data', () {
      warnIfPotentialPII(<String, dynamic>{}, 'context', mockLogger);
      expect(mockLogger.warnMessages, isEmpty);
    });
  });

  group('enforceStrictPII', () {
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
    });

    test('should throw SecurityException when PII is detected', () {
      final data = {'email': 'user@example.com'};

      expect(
        () => enforceStrictPII(data, 'context', null, mockLogger),
        throwsA(isA<SecurityException>()),
      );
    });

    test('should not throw when PII field is in privateAttributes', () {
      final data = {'email': 'user@example.com'};

      expect(
        () => enforceStrictPII(data, 'context', ['email'], mockLogger),
        returnsNormally,
      );
    });

    test('should not throw when nested PII field parent is in privateAttributes', () {
      final data = {
        'user': {
          'email': 'user@example.com',
        },
      };

      expect(
        () => enforceStrictPII(data, 'context', ['user'], mockLogger),
        returnsNormally,
      );
    });

    test('should throw for PII not in privateAttributes', () {
      final data = {
        'email': 'user@example.com',
        'phone': '123-456-7890',
      };

      expect(
        () => enforceStrictPII(data, 'context', ['email'], mockLogger),
        throwsA(isA<SecurityException>()),
      );
    });

    test('should not throw for null data', () {
      expect(
        () => enforceStrictPII(null, 'context', null, mockLogger),
        returnsNormally,
      );
    });

    test('should not throw for safe data', () {
      final data = {'userId': 'user-123', 'plan': 'premium'};

      expect(
        () => enforceStrictPII(data, 'context', null, mockLogger),
        returnsNormally,
      );
    });
  });

  group('isServerKey', () {
    test('should return true for server keys', () {
      expect(isServerKey('srv_abc123'), isTrue);
      expect(isServerKey('srv_'), isTrue);
      expect(isServerKey('srv_longkeyvalue12345'), isTrue);
    });

    test('should return false for SDK keys', () {
      expect(isServerKey('sdk_abc123'), isFalse);
    });

    test('should return false for CLI keys', () {
      expect(isServerKey('cli_abc123'), isFalse);
    });

    test('should return false for invalid keys', () {
      expect(isServerKey('invalid_key'), isFalse);
      expect(isServerKey('srv'), isFalse);
      expect(isServerKey(''), isFalse);
    });
  });

  group('isClientKey', () {
    test('should return true for SDK keys', () {
      expect(isClientKey('sdk_abc123'), isTrue);
      expect(isClientKey('sdk_'), isTrue);
      expect(isClientKey('sdk_longkeyvalue12345'), isTrue);
    });

    test('should return true for CLI keys', () {
      expect(isClientKey('cli_abc123'), isTrue);
      expect(isClientKey('cli_'), isTrue);
    });

    test('should return false for server keys', () {
      expect(isClientKey('srv_abc123'), isFalse);
    });

    test('should return false for invalid keys', () {
      expect(isClientKey('invalid_key'), isFalse);
      expect(isClientKey('sdk'), isFalse);
      expect(isClientKey('cli'), isFalse);
      expect(isClientKey(''), isFalse);
    });
  });

  group('warnIfServerKeyInBrowser', () {
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
    });

    test('should not warn for SDK keys', () {
      warnIfServerKeyInBrowser('sdk_abc123', mockLogger);
      expect(mockLogger.warnMessages, isEmpty);
    });

    test('should not warn for CLI keys', () {
      warnIfServerKeyInBrowser('cli_abc123', mockLogger);
      expect(mockLogger.warnMessages, isEmpty);
    });

    test('should handle null logger', () {
      // Should not throw
      expect(
        () => warnIfServerKeyInBrowser('srv_abc123', null),
        returnsNormally,
      );
    });

    // Note: Testing browser environment detection is difficult in unit tests
    // as kIsWeb is a compile-time constant. The browser warning behavior
    // would need to be tested in integration tests or with a different
    // approach that allows mocking the platform detection.
  });

  group('Request Signing (HMAC-SHA256)', () {
    const testApiKey = 'sdk_test_key_12345678';
    const testBody = '{"flagKey":"test-flag","context":{}}';

    test('should generate consistent HMAC-SHA256 signatures', () {
      const message = 'test message';

      final sig1 = generateHMACSHA256(message, testApiKey);
      final sig2 = generateHMACSHA256(message, testApiKey);

      expect(sig1, equals(sig2));
      expect(sig1, isNotEmpty);
      expect(sig1.length, equals(64)); // SHA256 produces 64 hex chars
    });

    test('should generate different signatures for different messages', () {
      final sig1 = generateHMACSHA256('message1', testApiKey);
      final sig2 = generateHMACSHA256('message2', testApiKey);

      expect(sig1, isNot(equals(sig2)));
    });

    test('should generate different signatures for different keys', () {
      final sig1 = generateHMACSHA256('message', 'key1');
      final sig2 = generateHMACSHA256('message', 'key2');

      expect(sig1, isNot(equals(sig2)));
    });

    test('getKeyId should return first 8 characters', () {
      expect(getKeyId('sdk_test_key_12345678'), equals('sdk_test'));
      expect(getKeyId('short'), equals('short'));
      expect(getKeyId(''), equals(''));
    });

    test('createRequestSignature should return valid signature', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sig = createRequestSignature(testBody, testApiKey, timestamp);

      expect(sig.signature, isNotEmpty);
      expect(sig.timestamp, equals(timestamp));
      expect(sig.keyId, equals('sdk_test'));
    });

    test('getSignatureHeaders should return all required headers', () {
      final headers = getSignatureHeaders(testBody, testApiKey);

      expect(headers, containsPair('X-Signature', isNotEmpty));
      expect(headers, containsPair('X-Timestamp', isNotEmpty));
      expect(headers, containsPair('X-Key-Id', 'sdk_test'));
    });

    test('verifyRequestSignature should verify valid signatures', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sig = createRequestSignature(testBody, testApiKey, timestamp);

      final isValid = verifyRequestSignature(
        testBody,
        sig.signature,
        sig.timestamp,
        sig.keyId,
        testApiKey,
      );

      expect(isValid, isTrue);
    });

    test('verifyRequestSignature should reject invalid signatures', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final isValid = verifyRequestSignature(
        testBody,
        'invalid_signature',
        timestamp,
        'sdk_test',
        testApiKey,
      );

      expect(isValid, isFalse);
    });

    test('verifyRequestSignature should reject expired timestamps', () {
      final oldTimestamp =
          DateTime.now().millisecondsSinceEpoch - 400000; // 6+ minutes ago
      final sig = createRequestSignature(testBody, testApiKey, oldTimestamp);

      final isValid = verifyRequestSignature(
        testBody,
        sig.signature,
        sig.timestamp,
        sig.keyId,
        testApiKey,
        maxAgeMs: 300000, // 5 minutes
      );

      expect(isValid, isFalse);
    });

    test('verifyRequestSignature should reject wrong keyId', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sig = createRequestSignature(testBody, testApiKey, timestamp);

      final isValid = verifyRequestSignature(
        testBody,
        sig.signature,
        sig.timestamp,
        'wrong_id',
        testApiKey,
      );

      expect(isValid, isFalse);
    });
  });

  group('SignedPayload', () {
    const testApiKey = 'sdk_test_key_12345678';

    test('signPayload should create valid signed payload', () {
      final data = {'test': 'data'};
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final signed = signPayload(
        data,
        testApiKey,
        (d) => jsonEncode(d),
        timestamp,
      );

      expect(signed.data, equals(data));
      expect(signed.signature, isNotEmpty);
      expect(signed.timestamp, equals(timestamp));
      expect(signed.keyId, equals('sdk_test'));
    });

    test('verifySignedPayload should verify valid payloads', () {
      final data = {'test': 'data'};
      final signed = signPayload(data, testApiKey, (d) => jsonEncode(d));

      final isValid = verifySignedPayload(
        signed,
        testApiKey,
        (d) => jsonEncode(d),
      );

      expect(isValid, isTrue);
    });

    test('verifySignedPayload should reject tampered data', () {
      final data = {'test': 'data'};
      final signed = signPayload(data, testApiKey, (d) => jsonEncode(d));

      // Create a new payload with tampered data but same signature
      final tampered = SignedPayload(
        data: {'test': 'tampered'},
        signature: signed.signature,
        timestamp: signed.timestamp,
        keyId: signed.keyId,
      );

      final isValid = verifySignedPayload(
        tampered,
        testApiKey,
        (d) => jsonEncode(d),
      );

      expect(isValid, isFalse);
    });
  });

  group('Cache Encryption (AES-GCM)', () {
    const testApiKey = 'sdk_test_key_12345678';

    test('EncryptedStorage should encrypt and decrypt strings', () {
      final storage = EncryptedStorage.fromApiKey(testApiKey, iterations: 1000);

      const plaintext = 'Hello, World!';
      final encrypted = storage.encryptString(plaintext);
      final decrypted = storage.decryptString(encrypted);

      expect(encrypted, isNot(equals(plaintext)));
      expect(decrypted, equals(plaintext));
    });

    test('EncryptedStorage should produce different ciphertext each time', () {
      final storage = EncryptedStorage.fromApiKey(testApiKey, iterations: 1000);

      const plaintext = 'Hello, World!';
      final encrypted1 = storage.encryptString(plaintext);
      final encrypted2 = storage.encryptString(plaintext);

      // Different IVs should produce different ciphertext
      expect(encrypted1, isNot(equals(encrypted2)));

      // But both should decrypt to the same plaintext
      expect(storage.decryptString(encrypted1), equals(plaintext));
      expect(storage.decryptString(encrypted2), equals(plaintext));
    });

    test('EncryptedStorage should encrypt and decrypt JSON', () {
      final storage = EncryptedStorage.fromApiKey(testApiKey, iterations: 1000);

      final data = {
        'key': 'test-flag',
        'value': true,
        'version': 1,
      };

      final encrypted = storage.encryptJson(data);
      final decrypted = storage.decryptJson(encrypted);

      expect(decrypted, equals(data));
    });

    test('EncryptedStorage with different keys should fail decryption', () {
      final storage1 = EncryptedStorage.fromApiKey('key1', iterations: 1000);
      final storage2 = EncryptedStorage.fromApiKey('key2', iterations: 1000);

      const plaintext = 'Secret data';
      final encrypted = storage1.encryptString(plaintext);

      expect(
        () => storage2.decryptString(encrypted),
        throwsA(isA<SecurityException>()),
      );
    });

    test('deriveEncryptionKey should produce consistent keys', () {
      final key1 = deriveEncryptionKey(testApiKey, iterations: 1000);
      final key2 = deriveEncryptionKey(testApiKey, iterations: 1000);

      expect(key1, equals(key2));
      expect(key1.length, equals(32)); // 256 bits
    });

    test('deriveEncryptionKey should produce different keys for different API keys', () {
      final key1 = deriveEncryptionKey('api_key_1', iterations: 1000);
      final key2 = deriveEncryptionKey('api_key_2', iterations: 1000);

      expect(key1, isNot(equals(key2)));
    });
  });

  group('EncryptedFlagCache', () {
    const testApiKey = 'sdk_test_key_12345678';

    test('should store and retrieve flags', () {
      final cache = EncryptedFlagCache(
        apiKey: testApiKey,
        pbkdf2Iterations: 1000,
      );

      final flag = FlagState(
        key: 'test-flag',
        value: FlagValue(true),
        enabled: true,
        version: 1,
      );

      cache.set('test-flag', flag);
      final retrieved = cache.get('test-flag');

      expect(retrieved, isNotNull);
      expect(retrieved!.key, equals('test-flag'));
      expect(retrieved.value.boolValue, isTrue);
    });

    test('should export and import encrypted data', () {
      final cache1 = EncryptedFlagCache(
        apiKey: testApiKey,
        pbkdf2Iterations: 1000,
      );

      cache1.set(
        'flag1',
        FlagState(key: 'flag1', value: FlagValue(true), version: 1),
      );
      cache1.set(
        'flag2',
        FlagState(key: 'flag2', value: FlagValue('test'), version: 2),
      );

      final exported = cache1.exportEncrypted();

      final cache2 = EncryptedFlagCache(
        apiKey: testApiKey,
        pbkdf2Iterations: 1000,
      );
      cache2.importEncrypted(exported);

      expect(cache2.get('flag1')?.value.boolValue, isTrue);
      expect(cache2.get('flag2')?.value.stringValue, equals('test'));
    });

    test('should serialize and deserialize entire cache', () {
      final cache1 = EncryptedFlagCache(
        apiKey: testApiKey,
        pbkdf2Iterations: 1000,
      );

      cache1.set(
        'flag1',
        FlagState(key: 'flag1', value: FlagValue(42), version: 1),
      );

      final serialized = cache1.serializeEncrypted();

      final cache2 = EncryptedFlagCache(
        apiKey: testApiKey,
        pbkdf2Iterations: 1000,
      );
      cache2.deserializeEncrypted(serialized);

      expect(cache2.get('flag1')?.value.numberValue, equals(42));
    });

    test('should fail to deserialize with different API key', () {
      final cache1 = EncryptedFlagCache(
        apiKey: 'sdk_key_1',
        pbkdf2Iterations: 1000,
      );

      cache1.set(
        'flag1',
        FlagState(key: 'flag1', value: FlagValue(true), version: 1),
      );

      final serialized = cache1.serializeEncrypted();

      final cache2 = EncryptedFlagCache(
        apiKey: 'sdk_key_2',
        pbkdf2Iterations: 1000,
      );

      expect(
        () => cache2.deserializeEncrypted(serialized),
        throwsA(isA<SecurityException>()),
      );
    });

    test('should clear encrypted data on clear()', () {
      final cache = EncryptedFlagCache(
        apiKey: testApiKey,
        pbkdf2Iterations: 1000,
      );

      cache.set(
        'flag1',
        FlagState(key: 'flag1', value: FlagValue(true), version: 1),
      );

      cache.clear();

      expect(cache.get('flag1'), isNull);
      expect(cache.exportEncrypted(), isEmpty);
    });
  });

  group('Key Rotation', () {
    test('KeyRotationManager should start with primary key', () {
      final manager = KeyRotationManager(
        primaryApiKey: 'sdk_primary',
        secondaryApiKey: 'sdk_secondary',
      );

      expect(manager.activeKey, equals('sdk_primary'));
      expect(manager.isPrimaryActive, isTrue);
      expect(manager.hasSecondaryKey, isTrue);
    });

    test('KeyRotationManager should rotate to secondary on request', () {
      final manager = KeyRotationManager(
        primaryApiKey: 'sdk_primary',
        secondaryApiKey: 'sdk_secondary',
      );

      final result = manager.rotateToSecondary();

      expect(result.success, isTrue);
      expect(result.activeKey, equals('sdk_secondary'));
      expect(result.isPrimaryActive, isFalse);
      expect(manager.activeKey, equals('sdk_secondary'));
    });

    test('KeyRotationManager should fail rotation without secondary key', () {
      final manager = KeyRotationManager(
        primaryApiKey: 'sdk_primary',
      );

      final result = manager.rotateToSecondary();

      expect(result.success, isFalse);
      expect(result.error, contains('No secondary API key'));
      expect(manager.activeKey, equals('sdk_primary'));
    });

    test('KeyRotationManager should fail double rotation', () {
      final manager = KeyRotationManager(
        primaryApiKey: 'sdk_primary',
        secondaryApiKey: 'sdk_secondary',
      );

      manager.rotateToSecondary();
      final result = manager.rotateToSecondary();

      expect(result.success, isFalse);
      expect(result.error, contains('Already using secondary key'));
    });

    test('KeyRotationManager should reset to primary', () {
      final manager = KeyRotationManager(
        primaryApiKey: 'sdk_primary',
        secondaryApiKey: 'sdk_secondary',
      );

      manager.rotateToSecondary();
      expect(manager.isPrimaryActive, isFalse);

      manager.resetToPrimary();
      expect(manager.activeKey, equals('sdk_primary'));
      expect(manager.isPrimaryActive, isTrue);
    });

    test('shouldRotateOnError should rotate on 401', () {
      final manager = KeyRotationManager(
        primaryApiKey: 'sdk_primary',
        secondaryApiKey: 'sdk_secondary',
      );

      final shouldRetry = manager.shouldRotateOnError(401);

      expect(shouldRetry, isTrue);
      expect(manager.activeKey, equals('sdk_secondary'));
    });

    test('shouldRotateOnError should not rotate on other errors', () {
      final manager = KeyRotationManager(
        primaryApiKey: 'sdk_primary',
        secondaryApiKey: 'sdk_secondary',
      );

      expect(manager.shouldRotateOnError(500), isFalse);
      expect(manager.shouldRotateOnError(404), isFalse);
      expect(manager.shouldRotateOnError(403), isFalse);
      expect(manager.activeKey, equals('sdk_primary'));
    });

    test('shouldRotateOnError should not rotate twice', () {
      final manager = KeyRotationManager(
        primaryApiKey: 'sdk_primary',
        secondaryApiKey: 'sdk_secondary',
      );

      manager.shouldRotateOnError(401);
      final secondRotate = manager.shouldRotateOnError(401);

      expect(secondRotate, isFalse);
    });
  });

  group('SecurityConfig', () {
    test('should create with default values', () {
      const config = SecurityConfig();

      expect(config.warnOnPotentialPII, isTrue);
      expect(config.warnOnServerKeyInBrowser, isTrue);
      expect(config.additionalPIIPatterns, isEmpty);
      expect(config.strictPIIMode, isFalse);
      expect(config.enableRequestSigning, isFalse);
      expect(config.enableCacheEncryption, isFalse);
    });

    test('should create with custom values', () {
      const config = SecurityConfig(
        warnOnPotentialPII: false,
        warnOnServerKeyInBrowser: false,
        additionalPIIPatterns: ['customField', 'sensitiveData'],
        strictPIIMode: true,
        enableRequestSigning: true,
        enableCacheEncryption: true,
      );

      expect(config.warnOnPotentialPII, isFalse);
      expect(config.warnOnServerKeyInBrowser, isFalse);
      expect(config.additionalPIIPatterns, hasLength(2));
      expect(config.additionalPIIPatterns, contains('customField'));
      expect(config.strictPIIMode, isTrue);
      expect(config.enableRequestSigning, isTrue);
      expect(config.enableCacheEncryption, isTrue);
    });

    test('should create defaults from factory', () {
      final config = SecurityConfig.defaults();

      expect(config.warnOnPotentialPII, isTrue);
      expect(config.warnOnServerKeyInBrowser, isTrue);
      expect(config.additionalPIIPatterns, isEmpty);
      expect(config.strictPIIMode, isFalse);
      expect(config.enableRequestSigning, isFalse);
      expect(config.enableCacheEncryption, isFalse);
    });

    test('should support copyWith', () {
      const original = SecurityConfig(
        warnOnPotentialPII: true,
        warnOnServerKeyInBrowser: true,
        strictPIIMode: false,
      );

      final modified = original.copyWith(
        warnOnPotentialPII: false,
        strictPIIMode: true,
      );

      expect(modified.warnOnPotentialPII, isFalse);
      expect(modified.warnOnServerKeyInBrowser, isTrue);
      expect(modified.strictPIIMode, isTrue);
    });

    test('should implement equality', () {
      const config1 = SecurityConfig(
        warnOnPotentialPII: true,
        warnOnServerKeyInBrowser: true,
        additionalPIIPatterns: ['test'],
        strictPIIMode: false,
        enableRequestSigning: true,
        enableCacheEncryption: false,
      );
      const config2 = SecurityConfig(
        warnOnPotentialPII: true,
        warnOnServerKeyInBrowser: true,
        additionalPIIPatterns: ['test'],
        strictPIIMode: false,
        enableRequestSigning: true,
        enableCacheEncryption: false,
      );
      const config3 = SecurityConfig(
        warnOnPotentialPII: false,
        warnOnServerKeyInBrowser: true,
        additionalPIIPatterns: ['test'],
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    test('should have consistent hashCode', () {
      const config1 = SecurityConfig(
        warnOnPotentialPII: true,
        warnOnServerKeyInBrowser: true,
        additionalPIIPatterns: ['test'],
      );
      const config2 = SecurityConfig(
        warnOnPotentialPII: true,
        warnOnServerKeyInBrowser: true,
        additionalPIIPatterns: ['test'],
      );

      expect(config1.hashCode, equals(config2.hashCode));
    });
  });

  group('SecurityException', () {
    test('should create local port in production exception', () {
      final exception = SecurityException.localPortInProduction();

      expect(exception.code, equals(ErrorCode.securityLocalPortInProduction));
      expect(exception.message, contains('localPort'));
      expect(exception.message, contains('production'));
      expect(exception.isSecurityError, isTrue);
    });

    test('should create PII detected exception', () {
      final exception = SecurityException.piiDetected(['email', 'phone']);

      expect(exception.code, equals(ErrorCode.securityPIIDetected));
      expect(exception.message, contains('email'));
      expect(exception.message, contains('phone'));
      expect(exception.isSecurityError, isTrue);
    });

    test('should create encryption failed exception', () {
      final exception = SecurityException.encryptionFailed('Bad key');

      expect(exception.code, equals(ErrorCode.securityEncryptionFailed));
      expect(exception.message, contains('Encryption failed'));
      expect(exception.message, contains('Bad key'));
      expect(exception.isSecurityError, isTrue);
    });

    test('should create decryption failed exception', () {
      final exception = SecurityException.decryptionFailed('Invalid data');

      expect(exception.code, equals(ErrorCode.securityDecryptionFailed));
      expect(exception.message, contains('Decryption failed'));
      expect(exception.message, contains('Invalid data'));
      expect(exception.isSecurityError, isTrue);
    });
  });

  group('PIIDetectionResult', () {
    test('should create result with PII', () {
      final result = checkForPotentialPII({'email': 'test@test.com'}, 'context');

      expect(result.hasPII, isTrue);
      expect(result.fields, contains('email'));
      expect(result.message, contains('Potential PII detected'));
    });

    test('should create result without PII', () {
      final result = checkForPotentialPII({'userId': '123'}, 'context');

      expect(result.hasPII, isFalse);
      expect(result.fields, isEmpty);
      expect(result.message, isEmpty);
    });

    test('should handle null data', () {
      final result = checkForPotentialPII(null, 'context');

      expect(result.hasPII, isFalse);
      expect(result.fields, isEmpty);
      expect(result.message, isEmpty);
    });
  });

  group('Logger interface', () {
    test('MockLogger should implement Logger', () {
      final logger = MockLogger();
      expect(logger, isA<Logger>());
    });

    test('MockLogger should capture all message types', () {
      final logger = MockLogger();

      logger.debug('debug message');
      logger.info('info message');
      logger.warn('warn message');
      logger.error('error message');

      expect(logger.debugMessages, contains('debug message'));
      expect(logger.infoMessages, contains('info message'));
      expect(logger.warnMessages, contains('warn message'));
      expect(logger.errorMessages, contains('error message'));
    });

    test('MockLogger should support clear', () {
      final logger = MockLogger();

      logger.debug('debug');
      logger.info('info');
      logger.warn('warn');
      logger.error('error');

      logger.clear();

      expect(logger.debugMessages, isEmpty);
      expect(logger.infoMessages, isEmpty);
      expect(logger.warnMessages, isEmpty);
      expect(logger.errorMessages, isEmpty);
    });
  });
}
