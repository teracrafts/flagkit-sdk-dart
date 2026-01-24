import 'dart:async';

import '../error/error_code.dart';
import '../error/flagkit_exception.dart';
import '../http/http_client.dart';

/// Types of events that can be tracked.
enum EventType {
  /// Flag evaluation event.
  evaluation('evaluation'),

  /// User identification event.
  identify('identify'),

  /// Custom tracking event.
  track('track'),

  /// Page view event.
  pageView('page_view'),

  /// SDK initialized event.
  sdkInitialized('sdk_initialized'),

  /// Context changed event.
  contextChanged('context_changed');

  const EventType(this.value);
  final String value;
}

/// Base event structure.
class BaseEvent {
  /// The type of event.
  final String eventType;

  /// ISO 8601 timestamp when the event occurred.
  final String timestamp;

  /// SDK version.
  final String sdkVersion;

  /// SDK language identifier.
  final String sdkLanguage;

  /// Session identifier.
  final String sessionId;

  /// Environment identifier.
  final String environmentId;

  /// Additional event data.
  final Map<String, dynamic>? eventData;

  /// User ID if available.
  final String? userId;

  const BaseEvent({
    required this.eventType,
    required this.timestamp,
    required this.sdkVersion,
    required this.sdkLanguage,
    required this.sessionId,
    required this.environmentId,
    this.eventData,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'timestamp': timestamp,
      'sdkVersion': sdkVersion,
      'sdkLanguage': sdkLanguage,
      'sessionId': sessionId,
      'environmentId': environmentId,
      if (eventData != null) 'eventData': eventData,
      if (userId != null) 'userId': userId,
    };
  }
}

/// Configuration for the event queue.
class EventQueueConfig {
  /// Maximum number of events to batch before sending. Default: 10
  final int batchSize;

  /// Flush interval in milliseconds. Default: 30000 (30 seconds)
  final int flushIntervalMs;

  /// Maximum queue size before dropping oldest events. Default: 1000
  final int maxQueueSize;

  /// Sample rate for events (0.0 to 1.0). Default: 1.0 (all events)
  final double sampleRate;

  /// Event types that are enabled. Use ['*'] for all. Default: ['*']
  final List<String> enabledEventTypes;

  /// Event types that are explicitly disabled. Default: []
  final List<String> disabledEventTypes;

  const EventQueueConfig({
    this.batchSize = 10,
    this.flushIntervalMs = 30000,
    this.maxQueueSize = 1000,
    this.sampleRate = 1.0,
    this.enabledEventTypes = const ['*'],
    this.disabledEventTypes = const [],
  });

  /// Default event queue configuration.
  static const defaultConfig = EventQueueConfig();
}

/// Options for creating an event queue.
class EventQueueOptions {
  /// HTTP client for sending events.
  final FlagKitHttpClient httpClient;

  /// Session identifier.
  final String sessionId;

  /// Environment identifier.
  final String environmentId;

  /// SDK version.
  final String sdkVersion;

  /// Event queue configuration.
  final EventQueueConfig config;

  const EventQueueOptions({
    required this.httpClient,
    required this.sessionId,
    required this.environmentId,
    required this.sdkVersion,
    this.config = EventQueueConfig.defaultConfig,
  });
}

/// Manages event batching and delivery.
///
/// Features:
/// - Batching (default: 10 events or 30 seconds)
/// - Automatic retry on failure
/// - Event sampling
/// - Graceful shutdown
class EventQueue {
  final List<BaseEvent> _queue = [];
  final FlagKitHttpClient _httpClient;
  final EventQueueConfig _config;
  final String _sessionId;
  final String _sdkVersion;

  String _environmentId;
  String? _userId;
  Timer? _flushTimer;
  bool _isFlushing = false;
  bool _isClosed = false;

  EventQueue(EventQueueOptions options)
      : _httpClient = options.httpClient,
        _config = options.config,
        _sessionId = options.sessionId,
        _sdkVersion = options.sdkVersion,
        _environmentId = options.environmentId {
    _startFlushTimer();
  }

  /// Sets the environment ID.
  void setEnvironmentId(String id) {
    _environmentId = id;
  }

  /// Sets the current user ID.
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Tracks a custom event.
  ///
  /// Returns true if the event was queued, false if it was dropped
  /// (due to sampling, disabled event types, or queue overflow).
  bool track(String eventType, [Map<String, dynamic>? eventData]) {
    if (_isClosed) {
      return false;
    }

    // Validate event type
    if (eventType.isEmpty) {
      return false;
    }

    // Check if event type is enabled
    if (!_isEventTypeEnabled(eventType)) {
      return false;
    }

    // Apply sampling
    if (!_shouldSample(eventType)) {
      return false;
    }

    // Create event
    final event = BaseEvent(
      eventType: eventType,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      sdkVersion: _sdkVersion,
      sdkLanguage: 'dart',
      sessionId: _sessionId,
      environmentId: _environmentId,
      eventData: eventData,
      userId: _userId,
    );

    // Add to queue
    _addToQueue(event);

    return true;
  }

  /// Tracks an evaluation event.
  bool trackEvaluation(
    String flagKey,
    dynamic value,
    String reason, {
    Map<String, dynamic>? context,
  }) {
    return track(EventType.evaluation.value, {
      'flagKey': flagKey,
      'value': value,
      'reason': reason,
      if (context != null) 'context': context,
    });
  }

  /// Tracks an identify event.
  bool trackIdentify(String userId, [Map<String, dynamic>? attributes]) {
    return track(EventType.identify.value, {
      'userId': userId,
      if (attributes != null) 'attributes': attributes,
    });
  }

  /// Flushes pending events immediately.
  ///
  /// Returns the number of events that were sent successfully.
  Future<int> flush() async {
    if (_queue.isEmpty || _isFlushing) {
      return 0;
    }

    _isFlushing = true;

    // Get events to send
    final events = List<BaseEvent>.from(_queue);
    _queue.clear();

    try {
      await _sendEvents(events);
      return events.length;
    } catch (error) {
      // Re-queue failed events (up to max size)
      final availableSpace = _config.maxQueueSize - _queue.length;
      final requeue = events.take(availableSpace).toList();
      _queue.insertAll(0, requeue);
      rethrow;
    } finally {
      _isFlushing = false;
    }
  }

  /// Returns the current queue size.
  int get queueSize => _queue.length;

  /// Returns the queued events (for debugging).
  List<BaseEvent> get queuedEvents => List.unmodifiable(_queue);

  /// Clears the event queue without sending.
  void clearQueue() {
    _queue.clear();
  }

  /// Stops the event queue.
  ///
  /// If [flushBeforeClose] is true, attempts to send pending events first.
  Future<void> close({bool flushBeforeClose = true}) async {
    if (_isClosed) {
      return;
    }

    _isClosed = true;
    _stopFlushTimer();

    if (flushBeforeClose && _queue.isNotEmpty) {
      try {
        await flush();
      } catch (_) {
        // Ignore errors during shutdown
      }
    }
  }

  void _addToQueue(BaseEvent event) {
    // Enforce max queue size
    if (_queue.length >= _config.maxQueueSize) {
      // Drop oldest event
      _queue.removeAt(0);
    }

    _queue.add(event);

    // Flush if batch size reached
    if (_queue.length >= _config.batchSize) {
      // Schedule async flush to avoid blocking
      Future.microtask(() => flush().catchError((_) => 0));
    }
  }

  Future<void> _sendEvents(List<BaseEvent> events) async {
    if (events.isEmpty) {
      return;
    }

    try {
      await _httpClient.postVoid(
        '/sdk/events/batch',
        {'events': events.map((e) => e.toJson()).toList()},
      );
    } catch (error) {
      throw FlagKitException.networkError(
        ErrorCode.eventSendFailed,
        'Failed to send events: $error',
        error,
      );
    }
  }

  bool _isEventTypeEnabled(String eventType) {
    // Check disabled list first
    if (_config.disabledEventTypes.contains(eventType)) {
      return false;
    }

    // Check enabled list
    if (_config.enabledEventTypes.contains('*') ||
        _config.enabledEventTypes.contains(eventType)) {
      return true;
    }

    return false;
  }

  bool _shouldSample(String eventType) {
    if (_config.sampleRate >= 1.0) {
      return true;
    }
    if (_config.sampleRate <= 0.0) {
      return false;
    }

    // Use a simple random sampling
    return _randomDouble() < _config.sampleRate;
  }

  // Extracted for testability
  double _randomDouble() {
    return DateTime.now().microsecondsSinceEpoch % 1000 / 1000.0;
  }

  void _startFlushTimer() {
    if (_flushTimer != null) {
      return;
    }

    _flushTimer = Timer.periodic(
      Duration(milliseconds: _config.flushIntervalMs),
      (_) {
        if (!_isClosed) {
          flush().catchError((_) => 0);
        }
      },
    );
  }

  void _stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
