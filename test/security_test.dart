import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

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

  group('SecurityConfig', () {
    test('should create with default values', () {
      const config = SecurityConfig();

      expect(config.warnOnPotentialPII, isTrue);
      expect(config.warnOnServerKeyInBrowser, isTrue);
      expect(config.additionalPIIPatterns, isEmpty);
    });

    test('should create with custom values', () {
      const config = SecurityConfig(
        warnOnPotentialPII: false,
        warnOnServerKeyInBrowser: false,
        additionalPIIPatterns: ['customField', 'sensitiveData'],
      );

      expect(config.warnOnPotentialPII, isFalse);
      expect(config.warnOnServerKeyInBrowser, isFalse);
      expect(config.additionalPIIPatterns, hasLength(2));
      expect(config.additionalPIIPatterns, contains('customField'));
    });

    test('should create defaults from factory', () {
      final config = SecurityConfig.defaults();

      expect(config.warnOnPotentialPII, isTrue);
      expect(config.warnOnServerKeyInBrowser, isTrue);
      expect(config.additionalPIIPatterns, isEmpty);
    });

    test('should support copyWith', () {
      const original = SecurityConfig(
        warnOnPotentialPII: true,
        warnOnServerKeyInBrowser: true,
      );

      final modified = original.copyWith(warnOnPotentialPII: false);

      expect(modified.warnOnPotentialPII, isFalse);
      expect(modified.warnOnServerKeyInBrowser, isTrue);
    });

    test('should support copyWith with all fields', () {
      const original = SecurityConfig();

      final modified = original.copyWith(
        warnOnPotentialPII: false,
        warnOnServerKeyInBrowser: false,
        additionalPIIPatterns: ['custom'],
      );

      expect(modified.warnOnPotentialPII, isFalse);
      expect(modified.warnOnServerKeyInBrowser, isFalse);
      expect(modified.additionalPIIPatterns, contains('custom'));
    });

    test('should implement equality', () {
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
