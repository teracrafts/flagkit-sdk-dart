import 'error/error_code.dart';
import 'types/evaluation_context.dart';
import 'types/evaluation_result.dart';
import 'types/flag_state.dart';
import 'flagkit_client.dart';
import 'error/flagkit_exception.dart';
import 'flagkit_options.dart';

/// Static singleton factory for FlagKit SDK.
///
/// Provides a convenient way to access the FlagKit SDK globally.
/// Use [initialize] to create a client, then access it via [instance] or [getClient].
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

  /// Waits for the SDK to be ready.
  ///
  /// Throws [FlagKitException] if not initialized.
  static Future<void> waitForReady() {
    return getClient().waitForReady();
  }

  /// Identifies a user with optional attributes.
  static void identify(String userId, [Map<String, dynamic>? attributes]) {
    getClient().identify(userId, attributes);
  }

  /// Sets the global evaluation context.
  static void setContext(EvaluationContext context) {
    getClient().setContext(context);
  }

  /// Gets the current global context.
  static EvaluationContext? getContext() {
    return getClient().getContext();
  }

  /// Clears the global evaluation context.
  static void clearContext() {
    getClient().clearContext();
  }

  /// Resets to anonymous state.
  static void resetContext() {
    getClient().reset();
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

  /// Evaluates all flags and returns a map of results.
  static Future<Map<String, EvaluationResult>> evaluateAll(
      [EvaluationContext? context]) {
    return getClient().evaluateAll(context);
  }

  /// Evaluates multiple flags in a single request.
  static Future<Map<String, EvaluationResult>> evaluateBatch(
      List<String> flagKeys,
      [EvaluationContext? context]) {
    return getClient().evaluateBatch(flagKeys, context);
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

  /// Returns true if the flag exists in the cache.
  static bool hasFlag(String flagKey) {
    return getClient().hasFlag(flagKey);
  }

  /// Gets all flag keys from the cache.
  static List<String> getAllFlagKeys() {
    return getClient().getAllFlagKeys();
  }

  /// Gets all cached flags.
  static Map<String, FlagState> getAllFlags() {
    return getClient().getAllFlags();
  }

  /// Tracks a custom event.
  static void track(String eventType, [Map<String, dynamic>? eventData]) {
    getClient().track(eventType, eventData);
  }

  /// Flushes pending events immediately.
  static Future<void> flush() {
    return getClient().flush();
  }

  /// Forces a refresh of flag configurations from the server.
  static Future<void> refresh() {
    return getClient().refresh();
  }

  /// Polls for flag updates.
  static Future<void> pollForUpdates([String? since]) {
    return getClient().pollForUpdates(since);
  }

  /// Starts background polling for flag updates.
  static void startPolling() {
    getClient().startPolling();
  }

  /// Stops background polling.
  static void stopPolling() {
    getClient().stopPolling();
  }

  /// Returns true if polling is active.
  static bool get isPolling => _instance?.isPolling ?? false;

  /// Closes the SDK and releases resources.
  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  /// Resets the SDK state (for testing).
  static Future<void> reset() async {
    await _instance?.close();
    _instance = null;
    _initializing = false;
  }
}
