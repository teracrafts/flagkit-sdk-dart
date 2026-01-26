import 'dart:io';

import 'package:test/test.dart';
import 'package:flagkit/flagkit.dart';

void main() {
  group('EventPersistence', () {
    late String testStoragePath;
    late EventPersistence persistence;

    setUp(() async {
      // Create a unique temp directory for each test
      testStoragePath = '${Directory.systemTemp.path}/flagkit_test_${DateTime.now().millisecondsSinceEpoch}';
      await Directory(testStoragePath).create(recursive: true);

      persistence = EventPersistence(
        storagePath: testStoragePath,
        config: const EventPersistenceConfig(
          maxEvents: 100,
          flushInterval: Duration(milliseconds: 100),
          bufferSize: 5,
        ),
      );
    });

    tearDown(() async {
      await persistence.close();
      // Clean up test directory
      final dir = Directory(testStoragePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    group('Event Persistence', () {
      test('persists events to buffer', () {
        final event = PersistedEvent.create(
          type: 'test_event',
          data: {'key': 'value'},
        );

        final id = persistence.persist(event);

        expect(id, isNotEmpty);
        expect(persistence.eventCount, equals(1));
      });

      test('generates unique event IDs', () {
        final event1 = PersistedEvent.create(type: 'event1');
        final event2 = PersistedEvent.create(type: 'event2');

        final id1 = persistence.persist(event1);
        final id2 = persistence.persist(event2);

        expect(id1, isNot(equals(id2)));
      });

      test('flushes events to disk', () async {
        final event = PersistedEvent.create(
          type: 'flush_test',
          data: {'test': true},
        );

        persistence.persist(event);
        await persistence.flush();

        // Check that file was created
        final dir = Directory(testStoragePath);
        final files = await dir
            .list()
            .where((e) => e is File && e.path.endsWith('.jsonl'))
            .toList();

        expect(files, isNotEmpty);

        // Verify content
        final file = files.first as File;
        final content = await file.readAsString();
        expect(content, contains('flush_test'));
      });

      test('auto-flushes when buffer is full', () async {
        // Buffer size is 5, so adding 5 events should trigger flush
        for (var i = 0; i < 5; i++) {
          persistence.persist(PersistedEvent.create(type: 'event_$i'));
        }

        // Give time for async flush
        await Future.delayed(const Duration(milliseconds: 200));

        final dir = Directory(testStoragePath);
        final files = await dir
            .list()
            .where((e) => e is File && e.path.endsWith('.jsonl'))
            .toList();

        expect(files, isNotEmpty);
      });
    });

    group('Event Recovery', () {
      test('recovers pending events on startup', () async {
        // Persist and flush some events
        final event1 = PersistedEvent.create(type: 'recover_event_1');
        final event2 = PersistedEvent.create(type: 'recover_event_2');

        persistence.persist(event1);
        persistence.persist(event2);
        await persistence.flush();

        // Close and create new persistence instance
        await persistence.close();

        final newPersistence = EventPersistence(
          storagePath: testStoragePath,
          config: const EventPersistenceConfig(),
        );

        final recovered = await newPersistence.recover();

        expect(recovered.length, equals(2));
        expect(recovered.any((e) => e.type == 'recover_event_1'), isTrue);
        expect(recovered.any((e) => e.type == 'recover_event_2'), isTrue);

        await newPersistence.close();
      });

      test('recovers events marked as sending (crashed mid-send)', () async {
        // Create an event and mark it as sending
        final event = PersistedEvent.create(type: 'sending_event');
        persistence.persist(event);
        await persistence.flush();
        await persistence.markSending([event.id]);

        // Close and create new persistence instance
        await persistence.close();

        final newPersistence = EventPersistence(
          storagePath: testStoragePath,
          config: const EventPersistenceConfig(),
        );

        final recovered = await newPersistence.recover();

        // Should recover sending events as pending
        expect(recovered.length, equals(1));
        expect(recovered.first.status, equals(EventStatus.pending));

        await newPersistence.close();
      });

      test('does not recover sent events', () async {
        final event = PersistedEvent.create(type: 'sent_event');
        persistence.persist(event);
        await persistence.flush();
        await persistence.markSent([event.id]);

        // Close and create new persistence instance
        await persistence.close();

        final newPersistence = EventPersistence(
          storagePath: testStoragePath,
          config: const EventPersistenceConfig(),
        );

        final recovered = await newPersistence.recover();

        expect(recovered, isEmpty);

        await newPersistence.close();
      });
    });

    group('Event Status', () {
      test('marks events as sending', () async {
        final event = PersistedEvent.create(type: 'status_test');
        persistence.persist(event);
        await persistence.flush();

        await persistence.markSending([event.id]);

        final pending = persistence.getPendingEvents();
        expect(pending, isEmpty);
      });

      test('marks events as sent', () async {
        final event = PersistedEvent.create(type: 'sent_test');
        persistence.persist(event);
        await persistence.flush();

        await persistence.markSent([event.id]);

        final pending = persistence.getPendingEvents();
        expect(pending, isEmpty);
      });

      test('reverts events to pending on failure', () async {
        final event = PersistedEvent.create(type: 'revert_test');
        persistence.persist(event);
        await persistence.flush();

        await persistence.markSending([event.id]);
        await persistence.markPending([event.id]);

        final pending = persistence.getPendingEvents();
        expect(pending.length, equals(1));
      });
    });

    group('Cleanup', () {
      test('removes old sent events during cleanup', () async {
        // Create persistence with very short retention
        final shortRetentionPersistence = EventPersistence(
          storagePath: testStoragePath,
          config: const EventPersistenceConfig(
            retentionPeriod: Duration(milliseconds: 1),
          ),
        );

        final event = PersistedEvent.create(type: 'cleanup_test');
        shortRetentionPersistence.persist(event);
        await shortRetentionPersistence.flush();
        await shortRetentionPersistence.markSent([event.id]);

        // Wait for retention period to pass
        await Future.delayed(const Duration(milliseconds: 10));

        await shortRetentionPersistence.cleanup();

        expect(shortRetentionPersistence.eventCount, equals(0));

        await shortRetentionPersistence.close();
      });
    });

    group('File Locking', () {
      test('multiple persistence instances can coexist with locking', () async {
        final persistence1 = EventPersistence(
          storagePath: testStoragePath,
          config: const EventPersistenceConfig(),
        );

        final persistence2 = EventPersistence(
          storagePath: testStoragePath,
          config: const EventPersistenceConfig(),
        );

        // Both should be able to persist events
        persistence1.persist(PersistedEvent.create(type: 'event_from_1'));
        persistence2.persist(PersistedEvent.create(type: 'event_from_2'));

        // Flush both (uses file locking)
        await persistence1.flush();
        await persistence2.flush();

        // Verify both events were written
        final dir = Directory(testStoragePath);
        final files = await dir
            .list()
            .where((e) => e is File && e.path.endsWith('.jsonl'))
            .toList();

        var foundEvent1 = false;
        var foundEvent2 = false;

        for (final entity in files) {
          final file = entity as File;
          final content = await file.readAsString();
          if (content.contains('event_from_1')) foundEvent1 = true;
          if (content.contains('event_from_2')) foundEvent2 = true;
        }

        expect(foundEvent1, isTrue);
        expect(foundEvent2, isTrue);

        await persistence1.close();
        await persistence2.close();
      });
    });

    group('Max Events Limit', () {
      test('drops oldest event when max limit reached', () async {
        final limitedPersistence = EventPersistence(
          storagePath: testStoragePath,
          config: const EventPersistenceConfig(
            maxEvents: 3,
            bufferSize: 10,
          ),
        );

        // Add 4 events - first one should be dropped
        limitedPersistence.persist(PersistedEvent.create(type: 'event_1'));
        limitedPersistence.persist(PersistedEvent.create(type: 'event_2'));
        limitedPersistence.persist(PersistedEvent.create(type: 'event_3'));
        limitedPersistence.persist(PersistedEvent.create(type: 'event_4'));

        expect(limitedPersistence.eventCount, equals(3));

        await limitedPersistence.close();
      });
    });

    group('PersistedEvent', () {
      test('serializes to JSON correctly', () {
        final event = PersistedEvent(
          id: 'evt_test123',
          type: 'test_type',
          data: {'key': 'value', 'nested': {'inner': true}},
          timestamp: 1234567890000,
          status: EventStatus.pending,
        );

        final json = event.toJson();

        expect(json['id'], equals('evt_test123'));
        expect(json['type'], equals('test_type'));
        expect(json['data']['key'], equals('value'));
        expect(json['data']['nested']['inner'], isTrue);
        expect(json['timestamp'], equals(1234567890000));
        expect(json['status'], equals('pending'));
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'id': 'evt_test456',
          'type': 'deserialized_type',
          'data': {'foo': 'bar'},
          'timestamp': 9876543210000,
          'status': 'sent',
          'sentAt': 9876543220000,
        };

        final event = PersistedEvent.fromJson(json);

        expect(event.id, equals('evt_test456'));
        expect(event.type, equals('deserialized_type'));
        expect(event.data?['foo'], equals('bar'));
        expect(event.timestamp, equals(9876543210000));
        expect(event.status, equals(EventStatus.sent));
        expect(event.sentAt, equals(9876543220000));
      });

      test('copyWith creates correct copy', () {
        final original = PersistedEvent(
          id: 'evt_original',
          type: 'original_type',
          timestamp: 1000,
          status: EventStatus.pending,
        );

        final copied = original.copyWith(
          status: EventStatus.sent,
          sentAt: 2000,
        );

        expect(copied.id, equals(original.id));
        expect(copied.type, equals(original.type));
        expect(copied.timestamp, equals(original.timestamp));
        expect(copied.status, equals(EventStatus.sent));
        expect(copied.sentAt, equals(2000));
      });
    });

    group('EventStatus', () {
      test('parses status strings correctly', () {
        expect(EventStatus.fromString('pending'), equals(EventStatus.pending));
        expect(EventStatus.fromString('sending'), equals(EventStatus.sending));
        expect(EventStatus.fromString('sent'), equals(EventStatus.sent));
        expect(EventStatus.fromString('failed'), equals(EventStatus.failed));
        expect(EventStatus.fromString('unknown'), equals(EventStatus.pending));
        expect(EventStatus.fromString(null), equals(EventStatus.pending));
      });
    });
  });

  group('EventQueue with Persistence', () {
    late String testStoragePath;

    setUp(() async {
      testStoragePath = '${Directory.systemTemp.path}/flagkit_queue_test_${DateTime.now().millisecondsSinceEpoch}';
      await Directory(testStoragePath).create(recursive: true);
    });

    tearDown(() async {
      final dir = Directory(testStoragePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('BaseEvent has unique ID', () {
      final event1 = BaseEvent(
        eventType: 'test',
        timestamp: DateTime.now().toIso8601String(),
        sdkVersion: '1.0.0',
        sdkLanguage: 'dart',
        sessionId: 'session1',
        environmentId: 'env1',
      );

      final event2 = BaseEvent(
        eventType: 'test',
        timestamp: DateTime.now().toIso8601String(),
        sdkVersion: '1.0.0',
        sdkLanguage: 'dart',
        sessionId: 'session1',
        environmentId: 'env1',
      );

      expect(event1.id, isNotEmpty);
      expect(event2.id, isNotEmpty);
      expect(event1.id, isNot(equals(event2.id)));
    });

    test('BaseEvent includes ID in JSON', () {
      final event = BaseEvent(
        id: 'custom_id',
        eventType: 'test',
        timestamp: '2024-01-01T00:00:00Z',
        sdkVersion: '1.0.0',
        sdkLanguage: 'dart',
        sessionId: 'session1',
        environmentId: 'env1',
      );

      final json = event.toJson();

      expect(json['id'], equals('custom_id'));
    });

    test('BaseEvent.fromPersistedEvent creates correct event', () {
      final persisted = PersistedEvent(
        id: 'evt_persisted',
        type: 'persisted_type',
        data: {'action': 'click'},
        timestamp: 1704067200000, // 2024-01-01T00:00:00Z
        status: EventStatus.pending,
      );

      final baseEvent = BaseEvent.fromPersistedEvent(
        persisted,
        sdkVersion: '1.0.0',
        sessionId: 'session123',
        environmentId: 'env456',
        userId: 'user789',
      );

      expect(baseEvent.id, equals('evt_persisted'));
      expect(baseEvent.eventType, equals('persisted_type'));
      expect(baseEvent.sdkVersion, equals('1.0.0'));
      expect(baseEvent.sessionId, equals('session123'));
      expect(baseEvent.environmentId, equals('env456'));
      expect(baseEvent.userId, equals('user789'));
      expect(baseEvent.sdkLanguage, equals('dart'));
    });
  });
}
