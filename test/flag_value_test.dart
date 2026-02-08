import 'package:test/test.dart';
import 'package:teracrafts_flagkit/teracrafts_flagkit.dart';

void main() {
  group('FlagValue', () {
    test('creates null value', () {
      final value = FlagValue(null);
      expect(value.isNull, isTrue);
      expect(value.raw, isNull);
    });

    test('creates boolean value', () {
      final value = FlagValue(true);
      expect(value.boolValue, isTrue);
      expect(value.inferredType, equals(FlagType.boolean));
    });

    test('creates string value', () {
      final value = FlagValue('hello');
      expect(value.stringValue, equals('hello'));
      expect(value.inferredType, equals(FlagType.string));
    });

    test('creates int value', () {
      final value = FlagValue(42);
      expect(value.intValue, equals(42));
      expect(value.inferredType, equals(FlagType.number));
    });

    test('creates double value', () {
      final value = FlagValue(3.14);
      expect(value.numberValue, closeTo(3.14, 0.001));
      expect(value.inferredType, equals(FlagType.number));
    });

    test('creates json value', () {
      final json = {'key': 'value', 'count': 42};
      final value = FlagValue(json);
      expect(value.jsonValue, equals(json));
      expect(value.inferredType, equals(FlagType.json));
    });

    test('creates list value as json type', () {
      final list = [1, 2, 3];
      final value = FlagValue(list);
      expect(value.inferredType, equals(FlagType.json));
      expect(value.arrayValue, equals(list));
    });

    group('FlagValue.from factory', () {
      test('handles null', () {
        final value = FlagValue.from(null);
        expect(value.isNull, isTrue);
      });

      test('handles bool', () {
        final value = FlagValue.from(false);
        expect(value.boolValue, isFalse);
      });

      test('handles String', () {
        final value = FlagValue.from('test');
        expect(value.stringValue, equals('test'));
      });

      test('handles int', () {
        final value = FlagValue.from(100);
        expect(value.intValue, equals(100));
      });

      test('handles double', () {
        final value = FlagValue.from(2.5);
        expect(value.numberValue, equals(2.5));
      });

      test('handles Map', () {
        final value = FlagValue.from({'a': 1});
        expect(value.jsonValue, equals({'a': 1}));
      });

      test('handles List', () {
        final value = FlagValue.from([1, 2, 3]);
        expect(value.arrayValue, equals([1, 2, 3]));
      });
    });

    group('type conversions', () {
      test('boolValue returns null for non-bool', () {
        expect(FlagValue('true').boolValue, isNull);
        expect(FlagValue(1).boolValue, isNull);
        expect(FlagValue(null).boolValue, isNull);
      });

      test('stringValue returns string representation for primitives', () {
        expect(FlagValue(true).stringValue, equals('true'));
        expect(FlagValue(42).stringValue, equals('42'));
        expect(FlagValue(null).stringValue, isNull);
      });

      test('intValue returns null for non-number', () {
        expect(FlagValue(true).intValue, isNull);
        expect(FlagValue('42').intValue, isNull);
        expect(FlagValue(null).intValue, isNull);
      });

      test('numberValue returns null for non-number', () {
        expect(FlagValue(true).numberValue, isNull);
        expect(FlagValue('3.14').numberValue, isNull);
        expect(FlagValue(null).numberValue, isNull);
      });

      test('intValue truncates double', () {
        expect(FlagValue(3.9).intValue, equals(3));
      });

      test('jsonValue returns null for non-map', () {
        expect(FlagValue(true).jsonValue, isNull);
        expect(FlagValue('test').jsonValue, isNull);
        expect(FlagValue(42).jsonValue, isNull);
      });
    });

    group('equality', () {
      test('equal values are equal', () {
        expect(FlagValue(true), equals(FlagValue(true)));
        expect(FlagValue('test'), equals(FlagValue('test')));
        expect(FlagValue(42), equals(FlagValue(42)));
      });

      test('different values are not equal', () {
        expect(FlagValue(true), isNot(equals(FlagValue(false))));
        expect(FlagValue('a'), isNot(equals(FlagValue('b'))));
      });

      test('null values are equal', () {
        expect(FlagValue(null), equals(FlagValue(null)));
      });
    });

    group('toString', () {
      test('returns string representation', () {
        expect(FlagValue(true).toString(), equals('true'));
        expect(FlagValue('test').toString(), equals('test'));
        expect(FlagValue(42).toString(), equals('42'));
        expect(FlagValue(null).toString(), equals('null'));
      });
    });

    group('toJson', () {
      test('returns raw value', () {
        expect(FlagValue(true).toJson(), equals(true));
        expect(FlagValue('test').toJson(), equals('test'));
        expect(FlagValue(42).toJson(), equals(42));
        expect(FlagValue(null).toJson(), isNull);
      });
    });
  });
}
