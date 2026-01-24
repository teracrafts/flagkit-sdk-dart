import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

void main() {
  group('FlagKit', () {
    tearDown(() {
      FlagKit.reset();
    });

    test('isInitialized returns false before initialization', () {
      expect(FlagKit.isInitialized, isFalse);
    });

    test('instance returns null before initialization', () {
      expect(FlagKit.instance, isNull);
    });

    test('getClient throws when not initialized', () {
      expect(
        () => FlagKit.getClient(),
        throwsA(isA<FlagKitException>().having(
          (e) => e.code,
          'code',
          equals(ErrorCode.sdkNotInitialized),
        )),
      );
    });

    test('createClient creates client without initialization', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {'dark-mode': true},
      );

      final client = FlagKit.createClient(options);

      expect(client, isNotNull);
      expect(FlagKit.isInitialized, isTrue);
      expect(FlagKit.instance, same(client));
    });

    test('createClient throws when already initialized', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {'feature': true},
      );

      FlagKit.createClient(options);

      expect(
        () => FlagKit.createClient(options),
        throwsA(isA<FlagKitException>().having(
          (e) => e.code,
          'code',
          equals(ErrorCode.sdkAlreadyInitialized),
        )),
      );
    });

    test('static methods delegate to client', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {
          'bool-flag': true,
          'string-flag': 'hello',
          'number-flag': 42,
        },
      );

      FlagKit.createClient(options);

      // Test getBooleanValue
      expect(FlagKit.getBooleanValue('bool-flag', false), isTrue);
      expect(FlagKit.getBooleanValue('missing', true), isTrue);

      // Test getStringValue
      expect(FlagKit.getStringValue('string-flag', 'default'), equals('hello'));
      expect(FlagKit.getStringValue('missing', 'default'), equals('default'));

      // Test getNumberValue
      expect(FlagKit.getNumberValue('number-flag', 0), equals(42.0));
      expect(FlagKit.getNumberValue('missing', 99.0), equals(99.0));

      // Test getIntValue
      expect(FlagKit.getIntValue('number-flag', 0), equals(42));
      expect(FlagKit.getIntValue('missing', 99), equals(99));
    });

    test('evaluate returns result for cached flag', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {'feature': true},
      );

      FlagKit.createClient(options);
      final result = FlagKit.evaluate('feature');

      expect(result.flagKey, equals('feature'));
      expect(result.boolValue, isTrue);
      expect(result.reason, equals(EvaluationReason.cached));
    });

    test('evaluate returns flag not found for missing flag', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {},
      );

      FlagKit.createClient(options);
      final result = FlagKit.evaluate('missing');

      expect(result.flagKey, equals('missing'));
      expect(result.reason, equals(EvaluationReason.flagNotFound));
    });

    test('getAllFlags returns cached flags', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {
          'flag1': true,
          'flag2': 'value',
        },
      );

      FlagKit.createClient(options);
      final flags = FlagKit.getAllFlags();

      expect(flags.length, equals(2));
      expect(flags.containsKey('flag1'), isTrue);
      expect(flags.containsKey('flag2'), isTrue);
    });

    test('identify sets user context', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {},
      );

      FlagKit.createClient(options);
      FlagKit.identify('user-123', {'plan': 'premium'});

      final context = FlagKit.getClient().globalContext;
      expect(context?.userId, equals('user-123'));
      expect(context?.attributes['plan']?.stringValue, equals('premium'));
    });

    test('setContext updates global context', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {},
      );

      FlagKit.createClient(options);

      final newContext = EvaluationContext(
        userId: 'user-456',
      ).withAttribute('role', 'admin');
      FlagKit.setContext(newContext);

      final context = FlagKit.getClient().globalContext;
      expect(context?.userId, equals('user-456'));
      expect(context?.attributes['role']?.stringValue, equals('admin'));
    });

    test('clearContext resets global context', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {},
      );

      FlagKit.createClient(options);
      FlagKit.identify('user-123');
      FlagKit.clearContext();

      final context = FlagKit.getClient().globalContext;
      expect(context?.userId, isNull);
      expect(context?.attributes ?? {}, isEmpty);
    });

    test('close cleans up resources', () async {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {},
      );

      FlagKit.createClient(options);
      expect(FlagKit.isInitialized, isTrue);

      await FlagKit.close();
      expect(FlagKit.isInitialized, isFalse);
      expect(FlagKit.instance, isNull);
    });

    test('reset cleans up resources', () async {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {},
      );

      FlagKit.createClient(options);
      await FlagKit.reset();

      expect(FlagKit.isInitialized, isFalse);
      expect(FlagKit.instance, isNull);
    });

    test('evaluate with context merges with global context', () {
      final options = FlagKitOptions(
        apiKey: 'sdk_test_key',
        bootstrap: {'feature': true},
      );

      FlagKit.createClient(options);
      FlagKit.identify('user-123', {'plan': 'free'});

      final localContext = EvaluationContext(attributes: {
        'experiment': FlagValue('test'),
      });
      final result = FlagKit.evaluate('feature', localContext);

      expect(result, isNotNull);
    });
  });

  group('FlagKitException', () {
    test('creates config error', () {
      final error = FlagKitException.configError(
        ErrorCode.configInvalidApiKey,
        'Invalid API key',
      );

      expect(error.code, equals(ErrorCode.configInvalidApiKey));
      expect(error.message, contains('Invalid API key'));
      expect(error.isConfigError, isTrue);
    });

    test('creates network error', () {
      final error = FlagKitException.networkError(
        ErrorCode.httpTimeout,
        'Request timed out',
      );

      expect(error.code, equals(ErrorCode.httpTimeout));
      expect(error.message, contains('Request timed out'));
      expect(error.isNetworkError, isTrue);
    });

    test('creates evaluation error', () {
      final error = FlagKitException.evaluationError(
        ErrorCode.evalError,
        'Evaluation failed',
      );

      expect(error.code, equals(ErrorCode.evalError));
      expect(error.message, contains('Evaluation failed'));
      expect(error.isEvaluationError, isTrue);
    });

    test('creates sdk error', () {
      final error = FlagKitException.sdkError(
        ErrorCode.sdkNotInitialized,
        'SDK not initialized',
      );

      expect(error.code, equals(ErrorCode.sdkNotInitialized));
      expect(error.message, contains('SDK not initialized'));
      expect(error.isSdkError, isTrue);
    });

    test('toString includes code and message', () {
      final error = FlagKitException.configError(
        ErrorCode.configInvalidApiKey,
        'Test message',
      );

      final str = error.toString();
      expect(str, contains('CONFIG_INVALID_API_KEY'));
      expect(str, contains('Test message'));
    });
  });
}
