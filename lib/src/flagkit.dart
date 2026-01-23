import 'error_code.dart';
import 'evaluation_context.dart';
import 'evaluation_result.dart';
import 'flag_state.dart';
import 'flagkit_client.dart';
import 'flagkit_exception.dart';
import 'flagkit_options.dart';

/// Static singleton factory for FlagKit SDK.
class FlagKit {
  static FlagKitClient? _instance;
  static bool _initializing = false;

  FlagKit._();

  /// Returns true if the SDK has been initialized.
  static bool get isInitialized => _instance != null;

  /// Returns the current client instance, or null if not initialized.
  static FlagKitClient? get instance => _instance;

  /// Initializes the FlagKit SDK with the given options.
  ///
  /// Throws [FlagKitException] if already initialized.
  static Future<FlagKitClient> initialize(FlagKitOptions options) async {
    if (_instance != null) {
      throw FlagKitException.sdkError(
        ErrorCode.sdkAlreadyInitialized,
        'FlagKit SDK is already initialized',
      );
    }

    if (_initializing) {
      throw FlagKitException.sdkError(
        ErrorCode.sdkAlreadyInitialized,
        'FlagKit SDK is already being initialized',
      );
    }

    _initializing = true;

    try {
      final client = FlagKitClient(options);
      await client.initialize();
      _instance = client;
      return client;
    } finally {
      _initializing = false;
    }
  }

  /// Creates a client without fetching initial flags.
  ///
  /// Useful when you want to use bootstrap data only.
  static FlagKitClient createClient(FlagKitOptions options) {
    if (_instance != null) {
      throw FlagKitException.sdkError(
        ErrorCode.sdkAlreadyInitialized,
        'FlagKit SDK is already initialized',
      );
    }

    final client = FlagKitClient(options);
    _instance = client;
    return client;
  }

  /// Returns the initialized client.
  ///
  /// Throws [FlagKitException] if not initialized.
  static FlagKitClient getClient() {
    if (_instance == null) {
      throw FlagKitException.sdkError(
        ErrorCode.sdkNotInitialized,
        'FlagKit SDK is not initialized. Call initialize() first.',
      );
    }
    return _instance!;
  }

  /// Identifies a user with optional attributes.
  static void identify(String userId, [Map<String, dynamic>? attributes]) {
    getClient().identify(userId, attributes);
  }

  /// Sets the global evaluation context.
  static void setContext(EvaluationContext context) {
    getClient().setContext(context);
  }

  /// Clears the global evaluation context.
  static void clearContext() {
    getClient().clearContext();
  }

  /// Evaluates a flag synchronously using cached values.
  static EvaluationResult evaluate(String flagKey,
      [EvaluationContext? context]) {
    return getClient().evaluate(flagKey, context);
  }

  /// Evaluates a flag asynchronously, fetching from server if needed.
  static Future<EvaluationResult> evaluateAsync(String flagKey,
      [EvaluationContext? context]) {
    return getClient().evaluateAsync(flagKey, context);
  }

  /// Gets a boolean flag value with a default.
  static bool getBooleanValue(String flagKey, bool defaultValue,
      [EvaluationContext? context]) {
    return getClient().getBooleanValue(flagKey, defaultValue, context);
  }

  /// Gets a string flag value with a default.
  static String getStringValue(String flagKey, String defaultValue,
      [EvaluationContext? context]) {
    return getClient().getStringValue(flagKey, defaultValue, context);
  }

  /// Gets a number flag value with a default.
  static double getNumberValue(String flagKey, double defaultValue,
      [EvaluationContext? context]) {
    return getClient().getNumberValue(flagKey, defaultValue, context);
  }

  /// Gets an integer flag value with a default.
  static int getIntValue(String flagKey, int defaultValue,
      [EvaluationContext? context]) {
    return getClient().getIntValue(flagKey, defaultValue, context);
  }

  /// Gets a JSON flag value with a default.
  static Map<String, dynamic>? getJsonValue(
      String flagKey, Map<String, dynamic>? defaultValue,
      [EvaluationContext? context]) {
    return getClient().getJsonValue(flagKey, defaultValue, context);
  }

  /// Gets all cached flags.
  static Map<String, FlagState> getAllFlags() {
    return getClient().getAllFlags();
  }

  /// Polls for flag updates.
  static Future<void> pollForUpdates([String? since]) {
    return getClient().pollForUpdates(since);
  }

  /// Closes the SDK and releases resources.
  static void close() {
    _instance?.close();
    _instance = null;
  }

  /// Resets the SDK state (for testing).
  static void reset() {
    _instance?.close();
    _instance = null;
    _initializing = false;
  }
}
