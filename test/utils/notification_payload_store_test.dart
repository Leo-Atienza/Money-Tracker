import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/utils/notification_payload_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('storePendingPayload', () {
    test('null payload is a no-op', () async {
      await NotificationPayloadStore.storePendingPayload(null);
      expect(await NotificationPayloadStore.consumePendingPayload(), isNull);
    });

    test('empty string is a no-op', () async {
      await NotificationPayloadStore.storePendingPayload('');
      expect(await NotificationPayloadStore.consumePendingPayload(), isNull);
    });

    test('valid payload round-trips through consume', () async {
      await NotificationPayloadStore.storePendingPayload('bill_reminder:42');
      expect(
        await NotificationPayloadStore.consumePendingPayload(),
        'bill_reminder:42',
      );
    });

    // Phase 3.1: was previously "later store overwrites earlier" — the queue
    // semantics replace overwrite with append.
    test('later store appends to the queue', () async {
      await NotificationPayloadStore.storePendingPayload('first');
      await NotificationPayloadStore.storePendingPayload('second');
      final all = await NotificationPayloadStore.consumePendingPayloads();
      expect(all, ['first', 'second']);
    });
  });

  group('consumePendingPayloads', () {
    test('returns empty list when nothing stored', () async {
      expect(
        await NotificationPayloadStore.consumePendingPayloads(),
        isEmpty,
      );
    });

    test('preserves arrival order for multiple payloads', () async {
      await NotificationPayloadStore.storePendingPayload('a');
      await NotificationPayloadStore.storePendingPayload('b');
      await NotificationPayloadStore.storePendingPayload('c');

      expect(
        await NotificationPayloadStore.consumePendingPayloads(),
        ['a', 'b', 'c'],
      );
    });

    test('drains the queue (second read sees empty)', () async {
      await NotificationPayloadStore.storePendingPayload('one');
      await NotificationPayloadStore.storePendingPayload('two');

      final first = await NotificationPayloadStore.consumePendingPayloads();
      final second = await NotificationPayloadStore.consumePendingPayloads();

      expect(first, ['one', 'two']);
      expect(second, isEmpty);
    });

    test('picks up a legacy single-slot payload and migrates it', () async {
      // Simulate an upgrade from the pre-Phase-3.1 build where the store
      // used a single-string key.
      SharedPreferences.setMockInitialValues({
        'pending_notification_payload': 'legacy-bill',
      });

      final all = await NotificationPayloadStore.consumePendingPayloads();
      expect(all, ['legacy-bill']);

      // The legacy key should now be gone.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_notification_payload'), isNull);
    });

    test('merges legacy slot before queued payloads', () async {
      SharedPreferences.setMockInitialValues({
        'pending_notification_payload': 'legacy',
      });
      await NotificationPayloadStore.storePendingPayload('queued');

      final all = await NotificationPayloadStore.consumePendingPayloads();
      expect(all, ['legacy', 'queued']);
    });

    test('survives a malformed queue value (returns empty)', () async {
      SharedPreferences.setMockInitialValues({
        'pending_notification_payloads': 'not-json',
      });
      expect(
        await NotificationPayloadStore.consumePendingPayloads(),
        isEmpty,
      );
    });
  });

  group('consumePendingPayload (singular, back-compat)', () {
    test('returns null when nothing stored', () async {
      expect(await NotificationPayloadStore.consumePendingPayload(), isNull);
    });

    test('returns the oldest payload and drains the queue', () async {
      await NotificationPayloadStore.storePendingPayload('first');
      await NotificationPayloadStore.storePendingPayload('second');

      final first = await NotificationPayloadStore.consumePendingPayload();
      final remaining = await NotificationPayloadStore.consumePendingPayloads();

      expect(first, 'first');
      // Singular consume drains the entire queue — callers that only need
      // one item don't accidentally leave a stale second payload behind.
      expect(remaining, isEmpty);
    });
  });

  group('clearPendingPayloads', () {
    test('removes every pending payload without returning them', () async {
      await NotificationPayloadStore.storePendingPayload('one');
      await NotificationPayloadStore.storePendingPayload('two');
      await NotificationPayloadStore.clearPendingPayloads();
      expect(
        await NotificationPayloadStore.consumePendingPayloads(),
        isEmpty,
      );
    });

    test('is safe to call when nothing is stored', () async {
      await NotificationPayloadStore.clearPendingPayloads();
      expect(
        await NotificationPayloadStore.consumePendingPayloads(),
        isEmpty,
      );
    });

    test('also removes a legacy single-slot payload', () async {
      SharedPreferences.setMockInitialValues({
        'pending_notification_payload': 'legacy',
      });
      await NotificationPayloadStore.clearPendingPayloads();
      expect(
        await NotificationPayloadStore.consumePendingPayloads(),
        isEmpty,
      );
    });
  });

  group('clearPendingPayload back-compat alias', () {
    test('routes to clearPendingPayloads', () async {
      await NotificationPayloadStore.storePendingPayload('one');
      await NotificationPayloadStore.clearPendingPayload();
      expect(
        await NotificationPayloadStore.consumePendingPayloads(),
        isEmpty,
      );
    });
  });
}
