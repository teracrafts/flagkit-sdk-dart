import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

void main() {
  group('EvaluationContext', () {
    test('creates empty context', () {
      final context = EvaluationContext();
      expect(context.userId, isNull);
      expect(context.attributes, isEmpty);
    });

    test('creates context with userId', () {
      final context = EvaluationContext(userId: 'user-123');
      expect(context.userId, equals('user-123'));
    });

    test('creates context with attributes', () {
      final context = EvaluationContext(attributes: {
        'plan': FlagValue('premium'),
      });
      expect(context.attributes['plan']?.stringValue, equals('premium'));
    });

    test('withUserId creates new context', () {
      final context1 = EvaluationContext(attributes: {
        'plan': FlagValue('free'),
      });
      final context2 = context1.withUserId('user-456');

      expect(context1.userId, isNull);
      expect(context2.userId, equals('user-456'));
      expect(context2.attributes['plan']?.stringValue, equals('free'));
    });

    test('withAttribute creates new context', () {
      final context1 = EvaluationContext(userId: 'user-123');
      final context2 = context1.withAttribute('plan', 'premium');

      expect(context1.attributes, isEmpty);
      expect(context2.attributes['plan']?.stringValue, equals('premium'));
      expect(context2.userId, equals('user-123'));
    });

    test('withAttributes creates new context', () {
      final context1 = EvaluationContext(userId: 'user-123');
      final context2 = context1.withAttributes({
        'plan': 'pro',
        'team': 'engineering',
      });

      expect(context1.attributes, isEmpty);
      expect(context2.attributes['plan']?.stringValue, equals('pro'));
      expect(context2.attributes['team']?.stringValue, equals('engineering'));
    });

    test('merge combines contexts', () {
      final context1 = EvaluationContext(
        userId: 'user-123',
        attributes: {'plan': FlagValue('free')},
      );
      final context2 = EvaluationContext(
        attributes: {
          'plan': FlagValue('premium'),
          'team': FlagValue('eng'),
        },
      );

      final merged = context1.merge(context2);

      expect(merged.userId, equals('user-123'));
      expect(merged.attributes['plan']?.stringValue, equals('premium'));
      expect(merged.attributes['team']?.stringValue, equals('eng'));
    });

    test('merge with null returns same context', () {
      final context = EvaluationContext(userId: 'user-123');
      final merged = context.merge(null);

      expect(merged.userId, equals('user-123'));
    });

    test('merge prefers other userId when set', () {
      final context1 = EvaluationContext(userId: 'user-123');
      final context2 = EvaluationContext(userId: 'user-456');

      final merged = context1.merge(context2);
      expect(merged.userId, equals('user-456'));
    });

    test('stripPrivateAttributes removes attributes starting with underscore', () {
      final context = EvaluationContext(
        userId: 'user-123',
        attributes: {
          'plan': FlagValue('premium'),
          '_email': FlagValue('test@example.com'),
          '_ssn': FlagValue('123-45-6789'),
        },
      );

      final stripped = context.stripPrivateAttributes();

      expect(stripped.userId, equals('user-123'));
      expect(stripped.attributes['plan']?.stringValue, equals('premium'));
      expect(stripped.attributes.containsKey('_email'), isFalse);
      expect(stripped.attributes.containsKey('_ssn'), isFalse);
    });

    test('isEmpty returns true for empty context', () {
      final context = EvaluationContext();
      expect(context.isEmpty, isTrue);
    });

    test('isEmpty returns false when userId is set', () {
      final context = EvaluationContext(userId: 'user-123');
      expect(context.isEmpty, isFalse);
    });

    test('isEmpty returns false when attributes exist', () {
      final context = EvaluationContext(attributes: {
        'key': FlagValue('value'),
      });
      expect(context.isEmpty, isFalse);
    });

    test('subscript operator accesses attributes', () {
      final context = EvaluationContext(attributes: {
        'plan': FlagValue('premium'),
      });
      expect(context['plan']?.stringValue, equals('premium'));
      expect(context['missing'], isNull);
    });

    test('toJson serializes context', () {
      final context = EvaluationContext(
        userId: 'user-123',
        attributes: {'plan': FlagValue('premium')},
      );

      final json = context.toJson();

      expect(json['userId'], equals('user-123'));
      expect(json['attributes']['plan'], equals('premium'));
    });

    test('copyWith creates modified copy', () {
      final context1 = EvaluationContext(
        userId: 'user-123',
        attributes: {'plan': FlagValue('free')},
      );
      final context2 = context1.copyWith(userId: 'user-456');

      expect(context1.userId, equals('user-123'));
      expect(context2.userId, equals('user-456'));
      expect(context2.attributes['plan']?.stringValue, equals('free'));
    });
  });

  group('EvaluationContextBuilder', () {
    test('builds context with all properties', () {
      final context = EvaluationContext.builder()
          .userId('user-123')
          .attribute('plan', 'premium')
          .attribute('team', 'engineering')
          .build();

      expect(context.userId, equals('user-123'));
      expect(context.attributes['plan']?.stringValue, equals('premium'));
      expect(context.attributes['team']?.stringValue, equals('engineering'));
    });

    test('builder methods are chainable', () {
      final builder = EvaluationContextBuilder();

      expect(builder.userId('user-123'), same(builder));
      expect(builder.attribute('key', 'value'), same(builder));
    });
  });

  group('EvaluationContext.withUserId factory', () {
    test('creates context with just userId', () {
      final context = EvaluationContext.withUserId('user-123');
      expect(context.userId, equals('user-123'));
      expect(context.attributes, isEmpty);
    });
  });
}
