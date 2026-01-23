import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

void main() {
  group('Cache', () {
    late Cache<String, String> cache;

    setUp(() {
      cache = Cache<String, String>(
        maxSize: 3,
        ttl: const Duration(milliseconds: 100),
      );
    });

    test('stores and retrieves values', () {
      cache.set('key1', 'value1');
      expect(cache.get('key1'), equals('value1'));
    });

    test('returns null for missing keys', () {
      expect(cache.get('nonexistent'), isNull);
    });

    test('has() returns true for existing keys', () {
      cache.set('key1', 'value1');
      expect(cache.has('key1'), isTrue);
    });

    test('has() returns false for missing keys', () {
      expect(cache.has('nonexistent'), isFalse);
    });

    test('remove() removes keys', () {
      cache.set('key1', 'value1');
      expect(cache.remove('key1'), isTrue);
      expect(cache.get('key1'), isNull);
    });

    test('remove() returns false for missing keys', () {
      expect(cache.remove('nonexistent'), isFalse);
    });

    test('clear() removes all entries', () {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      cache.clear();
      expect(cache.isEmpty, isTrue);
    });

    test('length returns number of entries', () {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      expect(cache.length, equals(2));
    });

    test('evicts expired entries on get', () async {
      cache.set('key1', 'value1');
      await Future.delayed(const Duration(milliseconds: 150));
      expect(cache.get('key1'), isNull);
    });

    test('evicts expired entries on has', () async {
      cache.set('key1', 'value1');
      await Future.delayed(const Duration(milliseconds: 150));
      expect(cache.has('key1'), isFalse);
    });

    test('evicts LRU entries when over capacity', () {
      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      cache.set('key3', 'value3');

      // Access key1 to make it recently used
      cache.get('key1');

      // Add key4, should evict key2 (least recently used)
      cache.set('key4', 'value4');

      expect(cache.has('key1'), isTrue);
      expect(cache.has('key2'), isFalse);
      expect(cache.has('key3'), isTrue);
      expect(cache.has('key4'), isTrue);
    });

    test('supports custom TTL per entry', () async {
      cache.set('key1', 'value1', const Duration(milliseconds: 200));
      await Future.delayed(const Duration(milliseconds: 120));
      expect(cache.get('key1'), equals('value1'));
    });
  });

  group('FlagCache', () {
    late FlagCache flagCache;

    setUp(() {
      flagCache = FlagCache(maxSize: 10);
    });

    test('stores and retrieves FlagState', () {
      final flag = FlagState(
        key: 'test-flag',
        value: FlagValue.from(true),
        enabled: true,
        version: 1,
      );

      flagCache.set('test-flag', flag);
      final result = flagCache.get('test-flag');

      expect(result, isNotNull);
      expect(result!.key, equals('test-flag'));
      expect(result.enabled, isTrue);
    });

    test('setAll stores multiple flags', () {
      final flags = [
        FlagState(
            key: 'flag1', value: FlagValue.from(true), enabled: true, version: 1),
        FlagState(
            key: 'flag2', value: FlagValue.from('hello'), enabled: true, version: 1),
        FlagState(
            key: 'flag3', value: FlagValue.from(42), enabled: false, version: 2),
      ];

      flagCache.setAll(flags);

      expect(flagCache.length, equals(3));
      expect(flagCache.get('flag1')?.enabled, isTrue);
      expect(flagCache.get('flag2')?.value.stringValue, equals('hello'));
      expect(flagCache.get('flag3')?.enabled, isFalse);
    });

    test('getAll returns all valid flags', () {
      final flags = [
        FlagState(
            key: 'flag1', value: FlagValue.from(true), enabled: true, version: 1),
        FlagState(
            key: 'flag2', value: FlagValue.from('hello'), enabled: true, version: 1),
      ];

      flagCache.setAll(flags);
      final result = flagCache.getAll();

      expect(result.length, equals(2));
      expect(result.containsKey('flag1'), isTrue);
      expect(result.containsKey('flag2'), isTrue);
    });
  });
}
