import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../error/error_code.dart';
import '../error/flagkit_exception.dart';

/// Status of a persisted event.
enum EventStatus {
  /// Event persisted, not yet sent.
  pending('pending'),

  /// Event is currently being sent.
  sending('sending'),

  /// Event successfully sent to server.
  sent('sent'),

  /// Event failed to send after max retries.
  failed('failed');

  const EventStatus(this.value);
  final String value;

  static EventStatus fromString(String? value) {
    switch (value) {
      case 'pending':
        return EventStatus.pending;
      case 'sending':
        return EventStatus.sending;
      case 'sent':
        return EventStatus.sent;
      case 'failed':
        return EventStatus.failed;
      default:
        return EventStatus.pending;
    }
  }
}

/// A persisted event record.
class PersistedEvent {
  /// Unique event ID.
  final String id;

  /// Event type.
  final String type;

  /// Event data.
  final Map<String, dynamic>? data;

  /// Timestamp when event occurred.
  final int timestamp;

  /// Current status of the event.
  final EventStatus status;

  /// Timestamp when event was sent (if applicable).
  final int? sentAt;

  const PersistedEvent({
    required this.id,
    required this.type,
    this.data,
    required this.timestamp,
    required this.status,
    this.sentAt,
  });

  /// Creates a new pending event.
  factory PersistedEvent.create({
    required String type,
    Map<String, dynamic>? data,
  }) {
    return PersistedEvent(
      id: _generateEventId(),
      type: type,
      data: data,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      status: EventStatus.pending,
    );
  }

  /// Creates from JSON.
  factory PersistedEvent.fromJson(Map<String, dynamic> json) {
    return PersistedEvent(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'unknown',
      data: json['data'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as int? ?? 0,
      status: EventStatus.fromString(json['status'] as String?),
      sentAt: json['sentAt'] as int?,
    );
  }

  /// Converts to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      if (data != null) 'data': data,
      'timestamp': timestamp,
      'status': status.value,
      if (sentAt != null) 'sentAt': sentAt,
    };
  }

  /// Creates a copy with updated status.
  PersistedEvent copyWith({
    EventStatus? status,
    int? sentAt,
  }) {
    return PersistedEvent(
      id: id,
      type: type,
      data: data,
      timestamp: timestamp,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  static String _generateEventId() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    return 'evt_${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

/// Logger interface for event persistence.
typedef EventPersistenceLogger = void Function(String level, String message);

/// Configuration for event persistence.
class EventPersistenceConfig {
  /// Maximum number of events to persist.
  final int maxEvents;

  /// Interval between disk flushes.
  final Duration flushInterval;

  /// Buffer size before triggering flush.
  final int bufferSize;

  /// Retention period for sent events before cleanup.
  final Duration retentionPeriod;

  const EventPersistenceConfig({
    this.maxEvents = 10000,
    this.flushInterval = const Duration(milliseconds: 1000),
    this.bufferSize = 100,
    this.retentionPeriod = const Duration(hours: 24),
  });

  static const defaultConfig = EventPersistenceConfig();
}

/// Manages crash-resilient event persistence using write-ahead logging.
///
/// Events are written to disk before being queued for sending, ensuring
/// that events are not lost in case of crashes or unexpected termination.
///
/// Uses JSON Lines format (.jsonl) for storage and file locking for
/// concurrent access safety.
class EventPersistence {
  final String _storagePath;
  final EventPersistenceConfig _config;
  final EventPersistenceLogger? _logger;

  final List<PersistedEvent> _buffer = [];
  Timer? _flushTimer;
  bool _closed = false;

  /// In-memory index of persisted events by ID.
  final Map<String, PersistedEvent> _eventIndex = {};

  /// Lock file path.
  String get _lockFilePath => '$_storagePath/flagkit-events.lock';

  /// Current log file path.
  String get _currentLogFilePath {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return '$_storagePath/flagkit-events-$timestamp-$random.jsonl';
  }

  /// Creates a new event persistence manager.
  ///
  /// [storagePath] - Directory for event storage files.
  /// [config] - Configuration options.
  /// [logger] - Optional logger for debug/error messages.
  EventPersistence({
    required String storagePath,
    EventPersistenceConfig config = EventPersistenceConfig.defaultConfig,
    EventPersistenceLogger? logger,
  })  : _storagePath = storagePath,
        _config = config,
        _logger = logger {
    _startFlushTimer();
  }

  /// Persists an event to the buffer.
  ///
  /// Events are buffered and periodically flushed to disk.
  /// Returns the event ID for tracking.
  String persist(PersistedEvent event) {
    if (_closed) {
      throw FlagKitException.sdkError(
        ErrorCode.sdkNotInitialized,
        'Event persistence has been closed',
      );
    }

    // Check max events limit
    if (_eventIndex.length >= _config.maxEvents) {
      _log('warn', 'Max persisted events limit reached, dropping oldest event');
      _removeOldestPendingEvent();
    }

    _buffer.add(event);
    _eventIndex[event.id] = event;

    // Flush if buffer is full
    if (_buffer.length >= _config.bufferSize) {
      _scheduleFlush();
    }

    return event.id;
  }

  /// Flushes buffered events to disk.
  ///
  /// Uses file locking to prevent corruption from concurrent access.
  Future<void> flush() async {
    if (_buffer.isEmpty || _closed) {
      return;
    }

    final eventsToFlush = List<PersistedEvent>.from(_buffer);
    _buffer.clear();

    await _withFileLock(() async {
      await _writeEvents(eventsToFlush);
    });
  }

  /// Marks events as sent.
  ///
  /// Updates the status of the specified events to 'sent'.
  Future<void> markSent(List<String> eventIds) async {
    if (_closed || eventIds.isEmpty) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    for (final id in eventIds) {
      final event = _eventIndex[id];
      if (event != null) {
        _eventIndex[id] = event.copyWith(
          status: EventStatus.sent,
          sentAt: now,
        );
      }
    }

    // Write status updates to disk
    await _withFileLock(() async {
      await _writeStatusUpdates(eventIds, EventStatus.sent, now);
    });
  }

  /// Marks events as sending.
  ///
  /// Updates the status of the specified events to 'sending'.
  Future<void> markSending(List<String> eventIds) async {
    if (_closed || eventIds.isEmpty) {
      return;
    }

    for (final id in eventIds) {
      final event = _eventIndex[id];
      if (event != null) {
        _eventIndex[id] = event.copyWith(status: EventStatus.sending);
      }
    }

    await _withFileLock(() async {
      await _writeStatusUpdates(eventIds, EventStatus.sending, null);
    });
  }

  /// Marks events as pending (for retry after failure).
  Future<void> markPending(List<String> eventIds) async {
    if (_closed || eventIds.isEmpty) {
      return;
    }

    for (final id in eventIds) {
      final event = _eventIndex[id];
      if (event != null) {
        _eventIndex[id] = event.copyWith(status: EventStatus.pending);
      }
    }

    await _withFileLock(() async {
      await _writeStatusUpdates(eventIds, EventStatus.pending, null);
    });
  }

  /// Recovers pending events from disk on startup.
  ///
  /// Returns a list of events that need to be sent.
  Future<List<PersistedEvent>> recover() async {
    if (_closed) {
      return [];
    }

    final recoveredEvents = <PersistedEvent>[];

    await _withFileLock(() async {
      try {
        await _ensureStorageDirectory();

        final dir = Directory(_storagePath);
        if (!await dir.exists()) {
          return;
        }

        final files = await dir
            .list()
            .where((entity) =>
                entity is File && entity.path.endsWith('.jsonl'))
            .cast<File>()
            .toList();

        // Sort by filename (which includes timestamp)
        files.sort((a, b) => a.path.compareTo(b.path));

        // Read all event files and build index
        final allEvents = <String, PersistedEvent>{};

        for (final file in files) {
          try {
            final lines = await file.readAsLines();
            for (final line in lines) {
              if (line.trim().isEmpty) continue;

              try {
                final json = jsonDecode(line) as Map<String, dynamic>;
                final event = PersistedEvent.fromJson(json);

                // Status update record
                if (json.containsKey('status') && !json.containsKey('type')) {
                  final existingEvent = allEvents[json['id']];
                  if (existingEvent != null) {
                    allEvents[json['id']] = existingEvent.copyWith(
                      status: EventStatus.fromString(json['status'] as String?),
                      sentAt: json['sentAt'] as int?,
                    );
                  }
                } else {
                  // Full event record
                  allEvents[event.id] = event;
                }
              } catch (e) {
                _log('warn', 'Failed to parse event line: $e');
              }
            }
          } catch (e) {
            _log('warn', 'Failed to read event file ${file.path}: $e');
          }
        }

        // Filter for pending and sending events (sending = crashed mid-send)
        for (final event in allEvents.values) {
          if (event.status == EventStatus.pending ||
              event.status == EventStatus.sending) {
            recoveredEvents.add(event.copyWith(status: EventStatus.pending));
            _eventIndex[event.id] = event;
          }
        }

        _log('info', 'Recovered ${recoveredEvents.length} pending events');
      } catch (e) {
        _log('error', 'Failed to recover events: $e');
      }
    });

    return recoveredEvents;
  }

  /// Cleans up old sent events beyond the retention period.
  Future<void> cleanup() async {
    if (_closed) {
      return;
    }

    await _withFileLock(() async {
      try {
        final dir = Directory(_storagePath);
        if (!await dir.exists()) {
          return;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final retentionMs = _config.retentionPeriod.inMilliseconds;
        final cutoff = now - retentionMs;

        // Remove old sent events from index
        final toRemove = <String>[];
        for (final entry in _eventIndex.entries) {
          if (entry.value.status == EventStatus.sent &&
              entry.value.sentAt != null &&
              entry.value.sentAt! < cutoff) {
            toRemove.add(entry.key);
          }
        }

        for (final id in toRemove) {
          _eventIndex.remove(id);
        }

        // Compact event files
        await _compactEventFiles();

        _log('info', 'Cleaned up ${toRemove.length} old events');
      } catch (e) {
        _log('error', 'Failed to cleanup events: $e');
      }
    });
  }

  /// Gets all pending events from the index.
  List<PersistedEvent> getPendingEvents() {
    return _eventIndex.values
        .where((e) => e.status == EventStatus.pending)
        .toList();
  }

  /// Gets the current event count.
  int get eventCount => _eventIndex.length;

  /// Closes the persistence manager.
  ///
  /// Flushes any pending events and cleans up resources.
  Future<void> close() async {
    if (_closed) {
      return;
    }

    _closed = true;
    _stopFlushTimer();

    // Final flush
    if (_buffer.isNotEmpty) {
      try {
        await flush();
      } catch (e) {
        _log('error', 'Failed to flush on close: $e');
      }
    }

    // Cleanup old events
    try {
      await cleanup();
    } catch (e) {
      _log('error', 'Failed to cleanup on close: $e');
    }
  }

  // Private methods

  Future<void> _ensureStorageDirectory() async {
    final dir = Directory(_storagePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> _writeEvents(List<PersistedEvent> events) async {
    try {
      await _ensureStorageDirectory();

      // Find or create current log file
      final logFile = await _getOrCreateLogFile();

      // Append events as JSON lines
      final sink = logFile.openWrite(mode: FileMode.append);
      try {
        for (final event in events) {
          sink.writeln(jsonEncode(event.toJson()));
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      _log('debug', 'Wrote ${events.length} events to disk');
    } catch (e) {
      _log('error', 'Failed to write events: $e');
      // Re-add to buffer for retry
      _buffer.insertAll(0, events);
    }
  }

  Future<void> _writeStatusUpdates(
    List<String> eventIds,
    EventStatus status,
    int? sentAt,
  ) async {
    try {
      await _ensureStorageDirectory();

      final logFile = await _getOrCreateLogFile();
      final sink = logFile.openWrite(mode: FileMode.append);
      try {
        for (final id in eventIds) {
          final update = {
            'id': id,
            'status': status.value,
            if (sentAt != null) 'sentAt': sentAt,
          };
          sink.writeln(jsonEncode(update));
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } catch (e) {
      _log('error', 'Failed to write status updates: $e');
    }
  }

  Future<File> _getOrCreateLogFile() async {
    final dir = Directory(_storagePath);
    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
        .cast<File>()
        .toList();

    if (files.isNotEmpty) {
      // Use the most recent file if it's not too old
      files.sort((a, b) => b.path.compareTo(a.path));
      final latestFile = files.first;
      final stat = await latestFile.stat();

      // Create new file if latest is older than 1 hour or larger than 10MB
      if (DateTime.now().difference(stat.modified).inHours < 1 &&
          stat.size < 10 * 1024 * 1024) {
        return latestFile;
      }
    }

    // Create new log file
    return File(_currentLogFilePath);
  }

  Future<void> _compactEventFiles() async {
    try {
      final dir = Directory(_storagePath);
      if (!await dir.exists()) return;

      final files = await dir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
          .cast<File>()
          .toList();

      if (files.length <= 1) return;

      // Sort by name (oldest first)
      files.sort((a, b) => a.path.compareTo(b.path));

      // Keep only pending events in a new file
      final pendingEvents = _eventIndex.values
          .where((e) =>
              e.status == EventStatus.pending ||
              e.status == EventStatus.sending)
          .toList();

      if (pendingEvents.isEmpty) {
        // Delete all old files
        for (final file in files) {
          await file.delete();
        }
        return;
      }

      // Write pending events to a new file
      final newLogFile = File(_currentLogFilePath);
      final sink = newLogFile.openWrite();
      try {
        for (final event in pendingEvents) {
          sink.writeln(jsonEncode(event.toJson()));
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // Delete old files
      for (final file in files) {
        await file.delete();
      }
    } catch (e) {
      _log('error', 'Failed to compact event files: $e');
    }
  }

  Future<void> _withFileLock(Future<void> Function() action) async {
    await _ensureStorageDirectory();

    RandomAccessFile? lockFile;
    try {
      // Create/open lock file
      lockFile = await File(_lockFilePath).open(mode: FileMode.write);

      // Acquire exclusive lock
      await lockFile.lock(FileLock.exclusive);

      // Execute action
      await action();
    } finally {
      // Release lock and close file
      if (lockFile != null) {
        try {
          await lockFile.unlock();
        } catch (_) {
          // Ignore unlock errors
        }
        await lockFile.close();
      }
    }
  }

  void _removeOldestPendingEvent() {
    // Find oldest pending event
    PersistedEvent? oldest;
    for (final event in _eventIndex.values) {
      if (event.status == EventStatus.pending) {
        if (oldest == null || event.timestamp < oldest.timestamp) {
          oldest = event;
        }
      }
    }

    if (oldest != null) {
      _eventIndex.remove(oldest.id);
    }
  }

  void _startFlushTimer() {
    _flushTimer = Timer.periodic(_config.flushInterval, (_) {
      if (!_closed && _buffer.isNotEmpty) {
        _scheduleFlush();
      }
    });
  }

  void _stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void _scheduleFlush() {
    Future.microtask(() => flush().catchError((e) {
          _log('error', 'Scheduled flush failed: $e');
        }));
  }

  void _log(String level, String message) {
    _logger?.call(level, message);
  }
}
