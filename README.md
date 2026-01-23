# FlagKit Dart/Flutter SDK

Official Dart/Flutter SDK for [FlagKit](https://flagkit.dev) feature flag management.

## Installation

Add FlagKit to your `pubspec.yaml`:

```yaml
dependencies:
  flagkit: ^1.0.0
```

Then run:

```bash
flutter pub get
# or for Dart-only projects
dart pub get
```

## Quick Start

```dart
import 'package:flagkit/flagkit.dart';

void main() async {
  // Initialize the SDK
  final client = await FlagKit.initialize(
    FlagKitOptions(apiKey: 'sdk_your_api_key'),
  );

  // Identify a user
  FlagKit.identify('user-123', {'plan': 'premium'});

  // Evaluate flags
  final darkMode = FlagKit.getBooleanValue('dark-mode', false);
  final maxItems = FlagKit.getIntValue('max-items', 10);

  // Clean up when done
  FlagKit.close();
}
```

## Configuration

Use `FlagKitOptions` to configure the SDK:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_your_api_key',
  pollingInterval: Duration(seconds: 30),      // Flag update polling
  cacheTtl: Duration(minutes: 5),              // Cache duration
  maxCacheSize: 1000,                          // Max cached flags
  timeout: Duration(seconds: 10),              // HTTP timeout
  retryAttempts: 3,                            // Retry count
  isLocal: false,                              // Use local server (localhost:8200)
);
```

Or use the builder pattern:

```dart
final options = FlagKitOptions.builder('sdk_your_api_key')
    .pollingInterval(Duration(seconds: 60))
    .cacheTtl(Duration(minutes: 10))
    .maxCacheSize(500)
    .isLocal(true)  // Use local server for development
    .build();
```

### Local Development

For local development with a FlagKit server running on localhost:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_your_api_key',
  isLocal: true,  // Uses http://localhost:8200/api/v1
);
```

### Bootstrap Data

For offline-first scenarios or faster startup:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_your_api_key',
  bootstrap: {
    'dark-mode': true,
    'max-items': 100,
    'feature-config': {'variant': 'a'},
  },
);

// Create client without network call
final client = FlagKit.createClient(options);
```

## Flag Evaluation

### Typed Value Methods

```dart
// Boolean flags
final enabled = FlagKit.getBooleanValue('feature-enabled', false);

// String flags
final variant = FlagKit.getStringValue('experiment-variant', 'control');

// Number flags
final limit = FlagKit.getNumberValue('rate-limit', 100.0);
final count = FlagKit.getIntValue('max-count', 10);

// JSON flags
final config = FlagKit.getJsonValue('feature-config', {'default': true});
```

### Full Evaluation Result

```dart
final result = FlagKit.evaluate('feature-flag');

print(result.flagKey);     // 'feature-flag'
print(result.boolValue);   // true
print(result.enabled);     // true
print(result.reason);      // EvaluationReason.cached
print(result.version);     // 5
print(result.isDefault);   // false
```

### Async Evaluation

For real-time evaluation from the server:

```dart
final result = await FlagKit.evaluateAsync('feature-flag');
```

## User Context

### Identify Users

```dart
// Simple identification
FlagKit.identify('user-123');

// With attributes
FlagKit.identify('user-123', {
  'email': 'user@example.com',
  'plan': 'premium',
  'company': 'Acme Inc',
});
```

### Custom Context

```dart
// Build evaluation context
final context = EvaluationContextBuilder()
    .userId('user-456')
    .attribute('plan', 'enterprise')
    .attribute('team', 'engineering')
    .privateAttribute('email')  // Won't be sent to server
    .build();

FlagKit.setContext(context);

// Or pass context per-evaluation
final result = FlagKit.evaluate('feature', context);
```

### Clear Context

```dart
FlagKit.clearContext();
```

## Error Handling

```dart
try {
  await FlagKit.initialize(options);
} on FlagKitException catch (e) {
  if (e.isConfigError) {
    print('Configuration error: ${e.message}');
  } else if (e.isNetworkError) {
    print('Network error: ${e.message}');
  }
}
```

### Error Categories

- `isConfigError` - Invalid configuration (API key, URLs)
- `isNetworkError` - HTTP failures, timeouts, circuit breaker
- `isEvaluationError` - Flag evaluation failures
- `isSdkError` - SDK lifecycle errors (not initialized, etc.)

## Flutter Integration

### Provider Pattern

```dart
class FlagKitProvider extends InheritedWidget {
  final FlagKitClient client;

  const FlagKitProvider({
    required this.client,
    required Widget child,
  }) : super(child: child);

  static FlagKitClient of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FlagKitProvider>()!.client;
  }

  @override
  bool updateShouldNotify(FlagKitProvider oldWidget) => false;
}

// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final client = await FlagKit.initialize(
    FlagKitOptions(apiKey: 'sdk_your_api_key'),
  );

  runApp(
    FlagKitProvider(
      client: client,
      child: MyApp(),
    ),
  );
}
```

### Feature Widget

```dart
class FeatureFlag extends StatelessWidget {
  final String flagKey;
  final Widget enabled;
  final Widget disabled;

  const FeatureFlag({
    required this.flagKey,
    required this.enabled,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = FlagKit.getBooleanValue(flagKey, false);
    return isEnabled ? enabled : disabled;
  }
}

// Usage
FeatureFlag(
  flagKey: 'new-checkout',
  enabled: NewCheckoutWidget(),
  disabled: OldCheckoutWidget(),
)
```

## Advanced Features

### Circuit Breaker

The SDK includes automatic circuit breaker protection:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_your_api_key',
  circuitBreakerThreshold: 5,          // Opens after 5 failures
  circuitBreakerResetTimeout: Duration(seconds: 30),  // Half-open after 30s
);
```

### Retry with Backoff

Automatic retry with exponential backoff:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_your_api_key',
  retryAttempts: 3,   // Max 3 retries
  timeout: Duration(seconds: 10),
);
```

### Manual Polling

```dart
// Poll for updates manually
await FlagKit.pollForUpdates();

// Poll since a specific timestamp
await FlagKit.pollForUpdates('2024-01-15T10:30:00Z');
```

### Get All Flags

```dart
final allFlags = FlagKit.getAllFlags();

for (final entry in allFlags.entries) {
  print('${entry.key}: ${entry.value.value.rawValue}');
}
```

## API Key Formats

| Prefix | Type | Use Case |
|--------|------|----------|
| `sdk_` | Client SDK | Mobile and web applications |
| `srv_` | Server | Server-side applications |
| `cli_` | CLI | Command-line tools |

## Requirements

- Dart SDK 3.0.0 or higher
- Flutter 3.10.0 or higher (for Flutter projects)

## License

MIT License - see LICENSE file for details.
