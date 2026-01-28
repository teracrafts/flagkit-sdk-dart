/// FlagKit Dart SDK Lab
///
/// Internal verification script for SDK functionality.
/// Run with: dart run sdk-lab/run.dart

import 'dart:io';
import '../lib/flagkit.dart';

const pass = '\x1b[32m[PASS]\x1b[0m';
const fail = '\x1b[31m[FAIL]\x1b[0m';

void main() async {
  print('=== FlagKit Dart SDK Lab ===\n');

  var passed = 0;
  var failed = 0;

  void passTest(String test) {
    print('$pass $test');
    passed++;
  }

  void failTest(String test) {
    print('$fail $test');
    failed++;
  }

  try {
    // Test 1: Initialization with offline mode + bootstrap
    print('Testing initialization...');
    final options = FlagKitOptions(
      apiKey: 'sdk_lab_test_key',
      offline: true,
      bootstrap: {
        'lab-bool': true,
        'lab-string': 'Hello Lab',
        'lab-number': 42.0,
        'lab-json': {'nested': true, 'count': 100.0},
      },
    );

    final client = await FlagKit.initialize(options);
    await client.waitForReady();

    if (client.isReady) {
      passTest('Initialization');
    } else {
      failTest('Initialization - client not ready');
    }

    // Test 2: Boolean flag evaluation
    print('\nTesting flag evaluation...');
    final boolValue = await client.getBooleanValue('lab-bool', false);
    if (boolValue == true) {
      passTest('Boolean flag evaluation');
    } else {
      failTest('Boolean flag - expected true, got $boolValue');
    }

    // Test 3: String flag evaluation
    final stringValue = await client.getStringValue('lab-string', '');
    if (stringValue == 'Hello Lab') {
      passTest('String flag evaluation');
    } else {
      failTest("String flag - expected 'Hello Lab', got '$stringValue'");
    }

    // Test 4: Number flag evaluation
    final numberValue = await client.getNumberValue('lab-number', 0);
    if (numberValue == 42.0) {
      passTest('Number flag evaluation');
    } else {
      failTest('Number flag - expected 42, got $numberValue');
    }

    // Test 5: JSON flag evaluation
    final jsonValue = await client.getJsonValue('lab-json', {'nested': false, 'count': 0});
    if (jsonValue != null && jsonValue['nested'] == true && jsonValue['count'] == 100.0) {
      passTest('JSON flag evaluation');
    } else {
      failTest('JSON flag - unexpected value: $jsonValue');
    }

    // Test 6: Default value for missing flag
    final missingValue = await client.getBooleanValue('non-existent', true);
    if (missingValue == true) {
      passTest('Default value for missing flag');
    } else {
      failTest('Missing flag - expected default true, got $missingValue');
    }

    // Test 7: Context management - identify
    print('\nTesting context management...');
    client.identify('lab-user-123', {'custom': {'plan': 'premium', 'country': 'US'}});
    final context = client.getContext();
    if (context?.userId == 'lab-user-123') {
      passTest('identify()');
    } else {
      failTest('identify() - context not set correctly');
    }

    // Test 8: Context management - getContext
    // Note: Dart SDK stores custom values as FlagValue objects
    final planValue = context?.custom['plan'];
    if (planValue != null && planValue.stringValue == 'premium') {
      passTest('getContext()');
    } else {
      failTest('getContext() - custom attributes missing (plan=$planValue)');
    }

    // Test 9: Context management - reset
    client.reset();
    final resetContext = client.getContext();
    if (resetContext == null || resetContext.userId == null) {
      passTest('reset()');
    } else {
      failTest('reset() - context not cleared');
    }

    // Test 10: Event tracking
    print('\nTesting event tracking...');
    try {
      client.track('lab_verification', {'sdk': 'dart', 'version': '1.0.0'});
      passTest('track()');
    } catch (e) {
      failTest('track() - $e');
    }

    // Test 11: Flush (offline mode - no-op but should not throw)
    try {
      await client.flush();
      passTest('flush()');
    } catch (e) {
      failTest('flush() - $e');
    }

    // Test 12: Cleanup
    print('\nTesting cleanup...');
    try {
      await client.close();
      passTest('close()');
    } catch (e) {
      failTest('close() - $e');
    }
  } catch (e, stackTrace) {
    failTest('Unexpected error: $e');
    print(stackTrace);
  }

  // Summary
  print('\n${'=' * 40}');
  print('Results: $passed passed, $failed failed');
  print('=' * 40);

  if (failed > 0) {
    print('\n\x1b[31mSome verifications failed!\x1b[0m');
    exit(1);
  } else {
    print('\n\x1b[32mAll verifications passed!\x1b[0m');
    exit(0);
  }
}
