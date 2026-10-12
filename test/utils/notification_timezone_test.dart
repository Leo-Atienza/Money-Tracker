import 'package:budget_tracker/utils/notification_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// S22 (audit Open, reminders row): `tz.local` was never set, so repeating
/// reminders kept a UTC time of day and moved an hour against the wall clock
/// at each DST change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('budget_tracker/device_info');

  setUpAll(tz.initializeTimeZones);

  setUp(() => tz.setLocalLocation(tz.UTC));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    tz.setLocalLocation(tz.UTC);
  });

  void phoneZone(String? id) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return call.method == 'timeZone' ? id : null;
    });
  }

  test('reminders use the phone zone, so 9 AM stays 9 AM across DST',
      () async {
    phoneZone('America/Toronto');

    await NotificationHelper.setLocalTimeZone();

    expect(tz.local.name, 'America/Toronto');
    // The same wall-clock time either side of the March change is a
    // different UTC hour, which is what a UTC-located repeat got wrong.
    final winter = tz.TZDateTime(tz.local, 2026, 1, 5, 9);
    final summer = tz.TZDateTime(tz.local, 2026, 7, 5, 9);
    expect(winter.toUtc().hour, 14);
    expect(summer.toUtc().hour, 13);
  });

  test('an id the database does not know leaves UTC', () async {
    phoneZone('Mars/Olympus_Mons');

    await NotificationHelper.setLocalTimeZone();

    expect(tz.local.name, tz.UTC.name);
  });

  test('no native side (tests, other platforms) leaves UTC', () async {
    await NotificationHelper.setLocalTimeZone();

    expect(tz.local.name, tz.UTC.name);
  });
}
