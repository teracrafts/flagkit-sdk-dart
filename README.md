# FlagKit Dart/Flutter SDK

Official Dart/Flutter SDK for [FlagKit](https://flagkit.dev) feature flag management.

## Requirements

- Dart SDK 3.0.0+
- Flutter 3.10.0+ (for Flutter projects)

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

## Features

- **Type-safe evaluation** - Boolean, string, number, and JSON flag types
- **Local caching** - Fast evaluations with configurable TTL and optional encryption
- **Background polling** - Automatic flag updates
- **Event tracking** - Analytics with batching and crash-resilient persistence
- **Resilient** - Circuit breaker, retry with exponential backoff, offline support
- **Flutter integration** - Provider pattern and widget helpers
- **Security** - PII detection, request signing, bootstrap verification, timing attack protection

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
  localPort: 8200,                             // Use local server on port 8200
);
```

Or use the builder pattern:

```dart
final options = FlagKitOptions.builder('sdk_your_api_key')
    .pollingInterval(Duration(seconds: 60))
    .cacheTtl(Duration(minutes: 10))
    .maxCacheSize(500)
    .localPort(8200)  // Use local server on port 8200
    .build();
```

### Local Development

For local development with a FlagKit server running on localhost:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_your_api_key',
  localPort: 8200,  // Uses http://localhost:8200/api/v1
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

## Security Features

### PII Detection

The SDK can detect and warn about potential PII in contexts and events:

```dart
// Enable strict PII mode - throws errors instead of warnings
final options = FlagKitOptions(
  apiKey: 'sdk_...',
  strictPIIMode: true,
);

// Attributes containing PII will throw SecurityException
try {
  FlagKit.identify('user-123', {'email': 'user@example.com'});
} on FlagKitException catch (e) {
  print('PII error: ${e.message}');
}

// Use privateAttribute to mark fields as intentionally containing PII
final context = EvaluationContextBuilder()
    .userId('user-123')
    .attribute('email', 'user@example.com')
    .privateAttribute('email')  // Marks as intentionally private
    .build();
```

### Request Signing

POST requests are signed with HMAC-SHA256 for integrity:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_...',
  enableRequestSigning: false,  // Disable if needed (enabled by default)
);
```

### Bootstrap Signature Verification

Verify bootstrap data integrity using HMAC signatures:

```dart
// Create signed bootstrap data
final bootstrap = Security.createBootstrapSignature(
  flags: {'feature-a': true, 'feature-b': 'value'},
  apiKey: 'sdk_your_api_key',
);

// Use signed bootstrap with verification
final options = FlagKitOptions(
  apiKey: 'sdk_...',
  bootstrapConfig: bootstrap,
  bootstrapVerification: BootstrapVerificationConfig(
    enabled: true,
    maxAge: 86400000,  // 24 hours in milliseconds
    onFailure: 'error',  // 'warn' (default), 'error', or 'ignore'
  ),
);
```

### Cache Encryption

Enable AES-256-GCM encryption for cached flag data:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_...',
  enableCacheEncryption: true,
);
```

### Evaluation Jitter (Timing Attack Protection)

Add random delays to flag evaluations to prevent cache timing attacks:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_...',
  evaluationJitter: EvaluationJitterConfig(
    enabled: true,
    minMs: 5,
    maxMs: 15,
  ),
);
```

### Error Sanitization

Automatically redact sensitive information from error messages:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_...',
  errorSanitization: ErrorSanitizationConfig(
    enabled: true,
    preserveOriginal: false,  // Set true for debugging
  ),
);
```

## Event Persistence

Enable crash-resilient event persistence:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_...',
  persistEvents: true,
  eventStoragePath: '/path/to/storage',  // Optional
  maxPersistedEvents: 10000,
  persistenceFlushInterval: Duration(milliseconds: 1000),
);
```

## Key Rotation

Support seamless API key rotation:

```dart
final options = FlagKitOptions(
  apiKey: 'sdk_primary_key',
  secondaryApiKey: 'sdk_secondary_key',
);
// SDK will automatically failover to secondary key on 401 errors
```

## All Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `apiKey` | String | Required | API key for authentication |
| `secondaryApiKey` | String? | null | Secondary key for rotation |
| `pollingInterval` | Duration | 30s | Polling interval |
| `enablePolling` | bool | true | Enable background polling |
| `cacheTtl` | Duration | 300s | Cache TTL |
| `maxCacheSize` | int | 1000 | Maximum cache entries |
| `cacheEnabled` | bool | true | Enable local caching |
| `enableCacheEncryption` | bool | false | Enable AES-256-GCM encryption |
| `eventsEnabled` | bool | true | Enable event tracking |
| `eventBatchSize` | int | 10 | Events per batch |
| `eventFlushInterval` | Duration | 30s | Interval between flushes |
| `timeout` | Duration | 10s | Request timeout |
| `retryAttempts` | int | 3 | Number of retry attempts |
| `circuitBreakerThreshold` | int | 5 | Failures before circuit opens |
| `circuitBreakerResetTimeout` | Duration | 30s | Time before half-open |
| `bootstrap` | Map? | null | Initial flag values |
| `bootstrapConfig` | BootstrapConfig? | null | Signed bootstrap data |
| `bootstrapVerification` | Config | enabled | Bootstrap verification settings |
| `localPort` | int? | null | Local development port |
| `offline` | bool | false | Offline mode |
| `strictPIIMode` | bool | false | Error on PII detection |
| `enableRequestSigning` | bool | true | Enable request signing |
| `persistEvents` | bool | false | Enable event persistence |
| `eventStoragePath` | String? | null | Event storage directory |
| `maxPersistedEvents` | int | 10000 | Max persisted events |
| `persistenceFlushInterval` | Duration | 1s | Persistence flush interval |
| `evaluationJitter` | Config | disabled | Timing attack protection |
| `errorSanitization` | Config | enabled | Sanitize error messages |
| `onReady` | Function? | null | Ready callback |
| `onError` | Function? | null | Error callback |
| `onUpdate` | Function? | null | Update callback |

## License

MIT License - see LICENSE file for details.
