import 'package:test/test.dart';
import 'package:teracrafts_flagkit/src/utils/version.dart';

void main() {
  group('parseVersion', () {
    test('parses valid semver string', () {
      final result = parseVersion('1.2.3');
      expect(result, isNotNull);
      expect(result!.major, equals(1));
      expect(result.minor, equals(2));
      expect(result.patch, equals(3));
    });

    test('parses zero version', () {
      final result = parseVersion('0.0.0');
      expect(result, isNotNull);
      expect(result!.major, equals(0));
      expect(result.minor, equals(0));
      expect(result.patch, equals(0));
    });

    test('handles lowercase v prefix', () {
      final result = parseVersion('v1.2.3');
      expect(result, isNotNull);
      expect(result!.major, equals(1));
    });

    test('handles uppercase V prefix', () {
      final result = parseVersion('V1.2.3');
      expect(result, isNotNull);
      expect(result!.major, equals(1));
    });

    test('handles prerelease suffix', () {
      final result = parseVersion('1.2.3-beta.1');
      expect(result, isNotNull);
      expect(result!.major, equals(1));
      expect(result.minor, equals(2));
      expect(result.patch, equals(3));
    });

    test('handles build metadata', () {
      final result = parseVersion('1.2.3+build.123');
      expect(result, isNotNull);
      expect(result!.patch, equals(3));
    });

    test('handles leading whitespace', () {
      final result = parseVersion('  1.2.3');
      expect(result, isNotNull);
      expect(result!.major, equals(1));
    });

    test('handles trailing whitespace', () {
      final result = parseVersion('1.2.3  ');
      expect(result, isNotNull);
      expect(result!.major, equals(1));
    });

    test('handles surrounding whitespace', () {
      final result = parseVersion('  1.2.3  ');
      expect(result, isNotNull);
      expect(result!.major, equals(1));
    });

    test('handles v prefix with whitespace', () {
      final result = parseVersion('  v1.0.0  ');
      expect(result, isNotNull);
      expect(result!.major, equals(1));
    });

    test('returns null for null input', () {
      expect(parseVersion(null), isNull);
    });

    test('returns null for empty string', () {
      expect(parseVersion(''), isNull);
    });

    test('returns null for whitespace only', () {
      expect(parseVersion('   '), isNull);
    });

    test('returns null for invalid version', () {
      expect(parseVersion('invalid'), isNull);
    });

    test('returns null for partial version', () {
      expect(parseVersion('1.2'), isNull);
    });

    test('returns null for non-numeric components', () {
      expect(parseVersion('a.b.c'), isNull);
    });

    test('returns null for version exceeding max', () {
      expect(parseVersion('1000000000.0.0'), isNull);
    });

    test('parses version at max boundary', () {
      final result = parseVersion('999999999.999999999.999999999');
      expect(result, isNotNull);
      expect(result!.major, equals(999999999));
    });
  });

  group('compareVersions', () {
    test('returns 0 for equal versions', () {
      expect(compareVersions('1.0.0', '1.0.0'), equals(0));
    });

    test('returns 0 for equal versions with v prefix', () {
      expect(compareVersions('v1.0.0', '1.0.0'), equals(0));
    });

    test('returns negative for a < b (major)', () {
      expect(compareVersions('1.0.0', '2.0.0'), lessThan(0));
    });

    test('returns negative for a < b (minor)', () {
      expect(compareVersions('1.0.0', '1.1.0'), lessThan(0));
    });

    test('returns negative for a < b (patch)', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    });

    test('returns positive for a > b', () {
      expect(compareVersions('2.0.0', '1.0.0'), greaterThan(0));
    });

    test('returns 0 for invalid versions', () {
      expect(compareVersions('invalid', '1.0.0'), equals(0));
      expect(compareVersions('1.0.0', 'invalid'), equals(0));
    });
  });

  group('isVersionLessThan', () {
    test('returns true when a < b', () {
      expect(isVersionLessThan('1.0.0', '1.0.1'), isTrue);
      expect(isVersionLessThan('1.0.0', '1.1.0'), isTrue);
      expect(isVersionLessThan('1.0.0', '2.0.0'), isTrue);
    });

    test('returns false when a >= b', () {
      expect(isVersionLessThan('1.0.0', '1.0.0'), isFalse);
      expect(isVersionLessThan('1.1.0', '1.0.0'), isFalse);
    });

    test('returns false for invalid versions', () {
      expect(isVersionLessThan('invalid', '1.0.0'), isFalse);
    });
  });

  group('isVersionAtLeast', () {
    test('returns true when a >= b', () {
      expect(isVersionAtLeast('1.0.0', '1.0.0'), isTrue);
      expect(isVersionAtLeast('1.1.0', '1.0.0'), isTrue);
      expect(isVersionAtLeast('2.0.0', '1.0.0'), isTrue);
    });

    test('returns false when a < b', () {
      expect(isVersionAtLeast('1.0.0', '1.0.1'), isFalse);
    });
  });

  group('SDK scenarios', () {
    test('detects SDK below minimum', () {
      const sdkVersion = '1.0.0';
      const minVersion = '1.1.0';
      expect(isVersionLessThan(sdkVersion, minVersion), isTrue);
    });

    test('allows SDK at minimum', () {
      const sdkVersion = '1.1.0';
      const minVersion = '1.1.0';
      expect(isVersionLessThan(sdkVersion, minVersion), isFalse);
    });

    test('handles server v-prefixed response', () {
      const sdkVersion = '1.0.0';
      const serverMin = 'v1.1.0';
      expect(isVersionLessThan(sdkVersion, serverMin), isTrue);
    });
  });
}
