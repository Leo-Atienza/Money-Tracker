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

    test('later store overwrites earlier unconsumed payload', () async {
      await NotificationPayloadStore.storePendingPayload('first');
      await NotificationPayloadStore.storePendingPayload('second');
      expect(
        await NotificationPayloadStore.consumePendingPayload(),
        'second',
      );
    });
  });

  group('consumePendingPayload', () {
    test('returns null when nothing stored', () async {
      expect(await NotificationPayloadStore.consumePendingPayload(), isNull);
    });

    test('clears the payload after reading (consume semantics)', () async {
      await NotificationPayloadStore.storePendingPayload('one-shot');

      final first = await NotificationPayloadStore.consumePendingPayload();
      final second = await NotificationPayloadStore.consumePendingPayload();

      expect(first, 'one-shot');
      expect(second, isNull);
    });
  });

  group('clearPendingPayload', () {
    test('removes a pending payload without returning it', () async {
      await NotificationPayloadStore.storePendingPayload('discard-me');
      await NotificationPayloadStore.clearPendingPayload();
      expect(await NotificationPayloadStore.consumePendingPayload(), isNull);
    });

    test('is safe to call when no payload is stored', () async {
      await NotificationPayloadStore.clearPendingPayload();
      expect(await NotificationPayloadStore.consumePendingPayload(), isNull);
    });
  });
}
