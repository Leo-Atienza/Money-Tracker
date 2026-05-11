import 'package:budget_tracker/utils/clock.dart';
import 'package:budget_tracker/utils/pin_security_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 7.7 (NEXT_STEPS D.7) — PIN lockout flow under FakeClock.
///
/// The PinUnlockScreen relies on three branches in [PinSecurityHelper]:
///
/// 1. `verifyPin` accepts the right PIN immediately (counter resets).
/// 2. After [maxFailedAttempts] wrong PINs in a row the next call to
///    `isLockedOut` returns true and `getRemainingLockoutSeconds`
///    counts down from 300.
/// 3. Once `Clock.instance.now()` advances past the lockout window the
///    locked-out flag clears automatically on the next `isLockedOut`
///    call (the helper self-heals; the screen doesn't need to reset it).
///
/// Mounting the actual `PinUnlockScreen` in a widget test would pile on
/// `flutter_secure_storage` channel mocks for no extra coverage — the
/// branches above are the contract the UI depends on. Driving them
/// under [FakeClock] also makes the test sub-second (vs. wall-clock
/// waiting 5 minutes).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureBacking;
  late TestDefaultBinaryMessenger messenger;

  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() async {
    secureBacking = <String, String>{};
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      switch (call.method) {
        case 'read':
          final args = call.arguments as Map;
          return secureBacking[args['key'] as String];
        case 'write':
          final args = call.arguments as Map;
          final key = args['key'] as String;
          final value = args['value'] as String?;
          if (value == null) {
            secureBacking.remove(key);
          } else {
            secureBacking[key] = value;
          }
          return null;
        case 'delete':
          final args = call.arguments as Map;
          secureBacking.remove(args['key'] as String);
          return null;
        case 'readAll':
          return Map<String, String>.from(secureBacking);
        case 'deleteAll':
          secureBacking.clear();
          return null;
        case 'containsKey':
          final args = call.arguments as Map;
          return secureBacking.containsKey(args['key'] as String);
      }
      return null;
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
    Clock.instance = const Clock();
  });

  test('right PIN clears any failed-attempt count', () async {
    Clock.instance = FakeClock.fixed(DateTime(2026, 6, 1, 12, 0, 0));
    await PinSecurityHelper.setPin('9027');

    // One wrong attempt, then the right one.
    expect(await PinSecurityHelper.verifyPin('1234'), isFalse);
    expect(await PinSecurityHelper.getRemainingAttempts(), 4);

    expect(await PinSecurityHelper.verifyPin('9027'), isTrue);
    expect(await PinSecurityHelper.getRemainingAttempts(), 5,
        reason: 'success resets the failed-attempt counter');
    expect(await PinSecurityHelper.isLockedOut(), isFalse);
  });

  test('five wrong PINs in a row arms the lockout', () async {
    Clock.instance = FakeClock.fixed(DateTime(2026, 6, 1, 12, 0, 0));
    await PinSecurityHelper.setPin('9027');

    for (var i = 0; i < 5; i++) {
      expect(await PinSecurityHelper.verifyPin('1234'), isFalse);
    }

    expect(await PinSecurityHelper.isLockedOut(), isTrue);
    final remaining = await PinSecurityHelper.getRemainingLockoutSeconds();
    expect(remaining, 5 * 60,
        reason: '5-minute lockout window per source contract');
  });

  test('countdown reflects the moving clock', () async {
    final t0 = DateTime(2026, 6, 1, 12, 0, 0);
    Clock.instance = FakeClock.fixed(t0);
    await PinSecurityHelper.setPin('9027');

    for (var i = 0; i < 5; i++) {
      await PinSecurityHelper.verifyPin('1234');
    }
    expect(await PinSecurityHelper.getRemainingLockoutSeconds(), 5 * 60);

    // Two minutes pass — remaining should drop accordingly.
    Clock.instance = FakeClock.fixed(t0.add(const Duration(minutes: 2)));
    expect(await PinSecurityHelper.getRemainingLockoutSeconds(), 3 * 60);

    // Four-and-a-half minutes — 30 seconds left.
    Clock.instance = FakeClock.fixed(
      t0.add(const Duration(minutes: 4, seconds: 30)),
    );
    expect(await PinSecurityHelper.getRemainingLockoutSeconds(), 30);
  });

  test('isLockedOut self-heals once the window elapses', () async {
    final t0 = DateTime(2026, 6, 1, 12, 0, 0);
    Clock.instance = FakeClock.fixed(t0);
    await PinSecurityHelper.setPin('9027');

    for (var i = 0; i < 5; i++) {
      await PinSecurityHelper.verifyPin('1234');
    }
    expect(await PinSecurityHelper.isLockedOut(), isTrue);

    // Five minutes + 1 second later: the lockout has expired.
    Clock.instance = FakeClock.fixed(
      t0.add(const Duration(minutes: 5, seconds: 1)),
    );
    expect(await PinSecurityHelper.isLockedOut(), isFalse,
        reason: 'helper clears lockout data on the first call after expiry');
    expect(await PinSecurityHelper.getRemainingLockoutSeconds(), 0);
    expect(await PinSecurityHelper.getRemainingAttempts(), 5,
        reason: 'expiry resets the failed-attempt counter');
  });

  test('right PIN during a wrong-attempt streak resets without arming lockout',
      () async {
    Clock.instance = FakeClock.fixed(DateTime(2026, 6, 1, 12, 0, 0));
    await PinSecurityHelper.setPin('9027');

    // Four wrong attempts — still one chance left.
    for (var i = 0; i < 4; i++) {
      expect(await PinSecurityHelper.verifyPin('1234'), isFalse);
    }
    expect(await PinSecurityHelper.getRemainingAttempts(), 1);
    expect(await PinSecurityHelper.isLockedOut(), isFalse);

    // Correct PIN on the fifth attempt — counter snaps back to 5.
    expect(await PinSecurityHelper.verifyPin('9027'), isTrue);
    expect(await PinSecurityHelper.getRemainingAttempts(), 5);
    expect(await PinSecurityHelper.isLockedOut(), isFalse);
  });
}
