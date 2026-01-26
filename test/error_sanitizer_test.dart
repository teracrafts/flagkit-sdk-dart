import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

void main() {
  group('ErrorSanitizationConfig', () {
    test('should create with default values', () {
      const config = ErrorSanitizationConfig();

      expect(config.enabled, isTrue);
      expect(config.preserveOriginal, isFalse);
    });

    test('should create with custom values', () {
      const config = ErrorSanitizationConfig(
        enabled: false,
        preserveOriginal: true,
      );

      expect(config.enabled, isFalse);
      expect(config.preserveOriginal, isTrue);
    });

    test('defaultConfig should have sanitization enabled', () {
      expect(ErrorSanitizationConfig.defaultConfig.enabled, isTrue);
      expect(ErrorSanitizationConfig.defaultConfig.preserveOriginal, isFalse);
    });

    test('disabled should have sanitization disabled', () {
      expect(ErrorSanitizationConfig.disabled.enabled, isFalse);
    });

    test('development should preserve original messages', () {
      expect(ErrorSanitizationConfig.development.enabled, isTrue);
      expect(ErrorSanitizationConfig.development.preserveOriginal, isTrue);
    });
  });

  group('ErrorSanitizer', () {
    late ErrorSanitizer sanitizer;

    setUp(() {
      sanitizer = ErrorSanitizer();
    });

    group('Unix file paths', () {
      test('should sanitize Unix file paths', () {
        const message = 'Failed to read /home/user/config/settings.json';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Failed to read [PATH]'));
        expect(result.wasSanitized, isTrue);
        expect(result.sanitizedPatterns, contains('[PATH]'));
      });

      test('should sanitize multiple Unix paths', () {
        const message = 'Copy /var/log/app.log to /tmp/backup/app.log';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Copy [PATH] to [PATH]'));
        expect(result.wasSanitized, isTrue);
      });

      test('should sanitize deep nested paths', () {
        const message = 'Error at /usr/local/share/flagkit/data/cache.db';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Error at [PATH]'));
        expect(result.wasSanitized, isTrue);
      });
    });

    group('Windows file paths', () {
      test('should sanitize Windows file paths', () {
        const message = r'Failed to read C:\Users\admin\config.json';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Failed to read [PATH]'));
        expect(result.wasSanitized, isTrue);
      });

      test('should sanitize Windows paths with spaces in component names', () {
        const message = r'Error in D:\Program\FlagKit\data\cache.db';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Error in [PATH]'));
        expect(result.wasSanitized, isTrue);
      });
    });

    group('IP addresses', () {
      test('should sanitize IPv4 addresses', () {
        const message = 'Connection failed to 192.168.1.100:8080';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Connection failed to [IP]:8080'));
        expect(result.wasSanitized, isTrue);
        expect(result.sanitizedPatterns, contains('[IP]'));
      });

      test('should sanitize multiple IP addresses', () {
        const message = 'Route from 10.0.0.1 to 172.16.0.1 failed';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Route from [IP] to [IP] failed'));
        expect(result.wasSanitized, isTrue);
      });

      test('should sanitize localhost IP', () {
        const message = 'Listening on 127.0.0.1:3000';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Listening on [IP]:3000'));
        expect(result.wasSanitized, isTrue);
      });
    });

    group('API keys', () {
      test('should sanitize SDK API keys', () {
        const message = 'Invalid API key: sdk_abc123def456ghi789';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Invalid API key: sdk_[REDACTED]'));
        expect(result.wasSanitized, isTrue);
        expect(result.sanitizedPatterns, contains('sdk_[REDACTED]'));
      });

      test('should sanitize server API keys', () {
        const message = 'Auth failed for srv_production_key_12345';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Auth failed for srv_[REDACTED]'));
        expect(result.wasSanitized, isTrue);
        expect(result.sanitizedPatterns, contains('srv_[REDACTED]'));
      });

      test('should sanitize CLI API keys', () {
        const message = 'CLI key cli_testing_abcdefgh expired';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('CLI key cli_[REDACTED] expired'));
        expect(result.wasSanitized, isTrue);
        expect(result.sanitizedPatterns, contains('cli_[REDACTED]'));
      });

      test('should not sanitize short API key fragments', () {
        const message = 'Key prefix sdk_abc is valid';
        final result = sanitizer.sanitize(message);

        // sdk_abc is only 7 chars after prefix, below threshold of 8
        expect(result.message, equals('Key prefix sdk_abc is valid'));
        expect(result.wasSanitized, isFalse);
      });
    });

    group('Email addresses', () {
      test('should sanitize email addresses', () {
        const message = 'User user@example.com not found';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('User [EMAIL] not found'));
        expect(result.wasSanitized, isTrue);
        expect(result.sanitizedPatterns, contains('[EMAIL]'));
      });

      test('should sanitize multiple email addresses', () {
        const message = 'Send from admin@company.io to support@company.io';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Send from [EMAIL] to [EMAIL]'));
        expect(result.wasSanitized, isTrue);
      });

      test('should sanitize email with subdomain', () {
        const message = 'Contact dev.team@mail.example.org';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Contact [EMAIL]'));
        expect(result.wasSanitized, isTrue);
      });
    });

    group('Connection strings', () {
      test('should sanitize PostgreSQL connection strings', () {
        const message =
            'Failed to connect: postgres://user:pass@db.example.com:5432/mydb';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Failed to connect: [CONNECTION_STRING]'));
        expect(result.wasSanitized, isTrue);
        expect(result.sanitizedPatterns, contains('[CONNECTION_STRING]'));
      });

      test('should sanitize MySQL connection strings', () {
        const message = 'MySQL error: mysql://root:secret@localhost/app';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('MySQL error: [CONNECTION_STRING]'));
        expect(result.wasSanitized, isTrue);
      });

      test('should sanitize MongoDB connection strings', () {
        const message =
            'Timeout: mongodb://admin:password@cluster.mongodb.net/db';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Timeout: [CONNECTION_STRING]'));
        expect(result.wasSanitized, isTrue);
      });

      test('should sanitize Redis connection strings', () {
        const message = 'Redis failed: redis://default:token@redis.io:6379';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Redis failed: [CONNECTION_STRING]'));
        expect(result.wasSanitized, isTrue);
      });

      test('should be case insensitive for connection strings', () {
        const message = 'Error: POSTGRES://user:pass@host/db';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals('Error: [CONNECTION_STRING]'));
        expect(result.wasSanitized, isTrue);
      });
    });

    group('Multiple patterns', () {
      test('should sanitize multiple different sensitive data types', () {
        const message =
            'User admin@company.com at 192.168.1.50 used key sdk_secretkey123456';
        final result = sanitizer.sanitize(message);

        expect(result.message,
            equals('User [EMAIL] at [IP] used key sdk_[REDACTED]'));
        expect(result.wasSanitized, isTrue);
        expect(result.sanitizedPatterns, contains('[EMAIL]'));
        expect(result.sanitizedPatterns, contains('[IP]'));
        expect(result.sanitizedPatterns, contains('sdk_[REDACTED]'));
      });

      test('should sanitize path with connection string', () {
        const message =
            'Config at /etc/app/db.conf contains postgres://user:pass@host/db';
        final result = sanitizer.sanitize(message);

        expect(result.message,
            equals('Config at [PATH] contains [CONNECTION_STRING]'));
        expect(result.wasSanitized, isTrue);
      });
    });

    group('No sensitive data', () {
      test('should not modify messages without sensitive data', () {
        const message = 'Flag evaluation failed for key: my-feature-flag';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals(message));
        expect(result.wasSanitized, isFalse);
        expect(result.sanitizedPatterns, isEmpty);
      });

      test('should not modify empty messages', () {
        const message = '';
        final result = sanitizer.sanitize(message);

        expect(result.message, equals(''));
        expect(result.wasSanitized, isFalse);
      });
    });

    group('Disabled sanitization', () {
      test('should not sanitize when disabled', () {
        final disabledSanitizer =
            ErrorSanitizer(const ErrorSanitizationConfig(enabled: false));

        const message = 'Error with sdk_myapikey123456 at 192.168.1.1';
        final result = disabledSanitizer.sanitize(message);

        expect(result.message, equals(message));
        expect(result.wasSanitized, isFalse);
      });
    });

    group('Preserve original', () {
      test('should preserve original message when configured', () {
        final preservingSanitizer = ErrorSanitizer(
            const ErrorSanitizationConfig(preserveOriginal: true));

        const message = 'Error at user@test.com';
        final result = preservingSanitizer.sanitize(message);

        expect(result.message, equals('Error at [EMAIL]'));
        expect(result.originalMessage, equals(message));
        expect(result.wasSanitized, isTrue);
      });

      test('should not preserve original when not configured', () {
        const message = 'Error at user@test.com';
        final result = sanitizer.sanitize(message);

        expect(result.originalMessage, isNull);
      });
    });
  });

  group('Convenience functions', () {
    test('sanitizeErrorMessage should sanitize strings', () {
      const message = 'Failed at 192.168.1.1';
      final sanitized = sanitizeErrorMessage(message);

      expect(sanitized, equals('Failed at [IP]'));
    });

    test('sanitizeExceptionMessage should sanitize exception messages', () {
      final exception = Exception('Error with sdk_key123456789');
      final sanitized = sanitizeExceptionMessage(exception);

      expect(sanitized, contains('sdk_[REDACTED]'));
    });
  });

  group('FlagKitException integration', () {
    setUp(() {
      // Reset to default config
      setGlobalErrorSanitizationConfig(const ErrorSanitizationConfig());
    });

    tearDown(() {
      // Reset to default config after tests
      setGlobalErrorSanitizationConfig(const ErrorSanitizationConfig());
    });

    test('should sanitize error messages in FlagKitException', () {
      final exception = FlagKitException(
        ErrorCode.networkError,
        'Connection failed to 192.168.1.100',
      );

      expect(exception.message, equals('Connection failed to [IP]'));
      expect(exception.toString(), contains('[IP]'));
    });

    test('should sanitize API keys in exception messages', () {
      final exception = FlagKitException(
        ErrorCode.authInvalidKey,
        'Invalid key: sdk_mysecretapikey123',
      );

      expect(exception.message, equals('Invalid key: sdk_[REDACTED]'));
    });

    test('should preserve original when configured', () {
      setGlobalErrorSanitizationConfig(
          const ErrorSanitizationConfig(preserveOriginal: true));

      final exception = FlagKitException(
        ErrorCode.networkError,
        'Error at user@example.com',
      );

      expect(exception.message, equals('Error at [EMAIL]'));
      expect(exception.originalMessage, equals('Error at user@example.com'));
    });

    test('should not sanitize when disabled', () {
      setGlobalErrorSanitizationConfig(
          const ErrorSanitizationConfig(enabled: false));

      const originalMessage = 'Error at 192.168.1.1 with sdk_key123456789';
      final exception = FlagKitException(
        ErrorCode.networkError,
        originalMessage,
      );

      expect(exception.message, equals(originalMessage));
    });

    test('should sanitize connection strings in exceptions', () {
      final exception = FlagKitException(
        ErrorCode.networkError,
        'DB error: postgres://admin:secret@db.example.com:5432/app',
      );

      expect(exception.message, equals('DB error: [CONNECTION_STRING]'));
    });
  });

  group('SecurityException integration', () {
    setUp(() {
      setGlobalErrorSanitizationConfig(const ErrorSanitizationConfig());
    });

    tearDown(() {
      setGlobalErrorSanitizationConfig(const ErrorSanitizationConfig());
    });

    test('should sanitize paths in SecurityException', () {
      final exception = SecurityException(
        ErrorCode.securityEncryptionFailed,
        'Failed to encrypt /home/user/secrets/key.pem',
      );

      expect(exception.message, equals('Failed to encrypt [PATH]'));
    });
  });

  group('FlagKitOptions integration', () {
    test('should include errorSanitization in options', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_testkey123456789',
        errorSanitization: const ErrorSanitizationConfig(
          enabled: true,
          preserveOriginal: true,
        ),
      );

      expect(options.errorSanitization.enabled, isTrue);
      expect(options.errorSanitization.preserveOriginal, isTrue);
    });

    test('should use default errorSanitization', () {
      final options = FlagKitOptions(apiKey: 'sdk_testkey123456789');

      expect(options.errorSanitization.enabled, isTrue);
      expect(options.errorSanitization.preserveOriginal, isFalse);
    });

    test('should support copyWith for errorSanitization', () {
      final options = FlagKitOptions(apiKey: 'sdk_testkey123456789');
      final modified = options.copyWith(
        errorSanitization: const ErrorSanitizationConfig(enabled: false),
      );

      expect(modified.errorSanitization.enabled, isFalse);
    });

    test('should support builder for errorSanitization', () {
      final options = FlagKitOptions.builder('sdk_testkey123456789')
          .errorSanitization(const ErrorSanitizationConfig(
            enabled: true,
            preserveOriginal: true,
          ))
          .build();

      expect(options.errorSanitization.enabled, isTrue);
      expect(options.errorSanitization.preserveOriginal, isTrue);
    });
  });
}
