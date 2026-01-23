import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

void main() {
  group('EvaluationResult', () {
    test('creates result with all properties', () {
      final result = EvaluationResult(
        flagKey: 'test-flag',
        value: FlagValue(true),
        enabled: true,
        reason: EvaluationReason.cached,
        version: 5,
      );

      expect(result.flagKey, equals('test-flag'));
      expect(result.value.boolValue, isTrue);
      expect(result.enabled, isTrue);
      expect(result.reason, equals(EvaluationReason.cached));
      expect(result.version, equals(5));
    });

    test('defaultResult creates result with given reason', () {
      final result = EvaluationResult.defaultResult(
        'missing-flag',
        FlagValue(false),
        EvaluationReason.flagNotFound,
      );

      expect(result.flagKey, equals('missing-flag'));
      expect(result.value.boolValue, isFalse);
      expect(result.enabled, isFalse);
      expect(result.reason, equals(EvaluationReason.flagNotFound));
    });

    group('typed value getters', () {
      test('boolValue returns boolean', () {
        final result = EvaluationResult(
          flagKey: 'bool-flag',
          value: FlagValue(true),
          enabled: true,
          reason: EvaluationReason.server,
          version: 1,
        );
        expect(result.boolValue, isTrue);
      });

      test('stringValue returns string', () {
        final result = EvaluationResult(
          flagKey: 'string-flag',
          value: FlagValue('hello'),
          enabled: true,
          reason: EvaluationReason.defaultValue,
          version: 1,
        );
        expect(result.stringValue, equals('hello'));
      });

      test('numberValue returns double', () {
        final result = EvaluationResult(
          flagKey: 'number-flag',
          value: FlagValue(3.14),
          enabled: true,
          reason: EvaluationReason.bootstrap,
          version: 1,
        );
        expect(result.numberValue, closeTo(3.14, 0.001));
      });

      test('intValue returns int', () {
        final result = EvaluationResult(
          flagKey: 'int-flag',
          value: FlagValue(42),
          enabled: true,
          reason: EvaluationReason.cached,
          version: 1,
        );
        expect(result.intValue, equals(42));
      });

      test('jsonValue returns map', () {
        final json = {'key': 'value', 'count': 10};
        final result = EvaluationResult(
          flagKey: 'json-flag',
          value: FlagValue(json),
          enabled: true,
          reason: EvaluationReason.server,
          version: 1,
        );
        expect(result.jsonValue, equals(json));
      });
    });

    test('toJson serializes result', () {
      final result = EvaluationResult(
        flagKey: 'my-flag',
        value: FlagValue(true),
        enabled: true,
        reason: EvaluationReason.server,
        version: 3,
      );

      final json = result.toJson();

      expect(json['flagKey'], equals('my-flag'));
      expect(json['value'], equals(true));
      expect(json['enabled'], isTrue);
      expect(json['reason'], equals('server'));
      expect(json['version'], equals(3));
    });
  });

  group('FlagState', () {
    test('creates flag state with all properties', () {
      final state = FlagState(
        key: 'test-flag',
        value: FlagValue('variant-a'),
        enabled: true,
        version: 10,
      );

      expect(state.key, equals('test-flag'));
      expect(state.value.stringValue, equals('variant-a'));
      expect(state.enabled, isTrue);
      expect(state.version, equals(10));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'key': 'feature-flag',
        'value': true,
        'enabled': true,
        'version': 5,
      };

      final state = FlagState.fromJson(json);

      expect(state.key, equals('feature-flag'));
      expect(state.value.boolValue, isTrue);
      expect(state.enabled, isTrue);
      expect(state.version, equals(5));
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'key': 'minimal-flag',
        'value': 'test',
      };

      final state = FlagState.fromJson(json);

      expect(state.key, equals('minimal-flag'));
      expect(state.value.stringValue, equals('test'));
      expect(state.enabled, isTrue);
      expect(state.version, equals(0));
    });

    test('toJson serializes correctly', () {
      final state = FlagState(
        key: 'test-flag',
        value: FlagValue(42),
        enabled: true,
        version: 3,
      );

      final json = state.toJson();

      expect(json['key'], equals('test-flag'));
      expect(json['value'], equals(42));
      expect(json['enabled'], isTrue);
      expect(json['version'], equals(3));
    });
  });

  group('EvaluationReason', () {
    test('fromString parses known reasons', () {
      expect(EvaluationReason.fromString('cached'), equals(EvaluationReason.cached));
      expect(EvaluationReason.fromString('defaultValue'), equals(EvaluationReason.defaultValue));
      expect(EvaluationReason.fromString('flagNotFound'), equals(EvaluationReason.flagNotFound));
      expect(EvaluationReason.fromString('bootstrap'), equals(EvaluationReason.bootstrap));
      expect(EvaluationReason.fromString('server'), equals(EvaluationReason.server));
      expect(EvaluationReason.fromString('staleCache'), equals(EvaluationReason.staleCache));
      expect(EvaluationReason.fromString('error'), equals(EvaluationReason.error));
      expect(EvaluationReason.fromString('disabled'), equals(EvaluationReason.disabled));
      expect(EvaluationReason.fromString('typeMismatch'), equals(EvaluationReason.typeMismatch));
      expect(EvaluationReason.fromString('offline'), equals(EvaluationReason.offline));
    });

    test('fromString handles aliases', () {
      expect(EvaluationReason.fromString('flag_not_found'), equals(EvaluationReason.flagNotFound));
      expect(EvaluationReason.fromString('stale_cache'), equals(EvaluationReason.staleCache));
      expect(EvaluationReason.fromString('type_mismatch'), equals(EvaluationReason.typeMismatch));
      expect(EvaluationReason.fromString('default'), equals(EvaluationReason.defaultValue));
    });

    test('fromString returns defaultValue for unknown reason', () {
      expect(EvaluationReason.fromString('invalid'), equals(EvaluationReason.defaultValue));
    });

    test('fromString returns defaultValue for null', () {
      expect(EvaluationReason.fromString(null), equals(EvaluationReason.defaultValue));
    });
  });
}
