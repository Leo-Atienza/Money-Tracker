import 'dart:async';

import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/pin_setup_screen.dart';
import 'package:budget_tracker/screens/pin_unlock_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// S22 (audit Open, security row): the PIN gate fails closed, the unlock pad
/// waits for the real PIN length, and setup refuses a guessable PIN.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> store;
  // Every read fails like a Keystore error while true.
  late bool storeBroken;
  // Reads of these keys fail while the rest of the store works.
  late Set<String> failingReads;
  // Holds every read back until completed (null = answer at once).
  Completer<void>? readGate;

  setUp(() {
    store = <String, String>{};
    storeBroken = false;
    failingReads = <String>{};
    readGate = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
      final key = (call.arguments as Map)['key'] as String?;
      switch (call.method) {
        case 'read':
          await readGate?.future;
          if (storeBroken || failingReads.contains(key)) {
            throw PlatformException(code: 'Exception', message: 'Keystore');
          }
          return store[key];
        case 'write':
          final value = (call.arguments as Map)['value'] as String?;
          if (value == null) {
            store.remove(key);
          } else {
            store[key!] = value;
          }
          return null;
        case 'delete':
          store.remove(key);
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  // A syntactically valid S22 record for a 4-digit PIN. Nothing here derives
  // a key from it: every test that uses it fails or stops before the check.
  void storeFourDigitPin() {
    store['pin_enabled'] = 'true';
    store['app_pin_hash'] = 'pbkdf2_sha256\$100000\$c2FsdHNhbHQ=\$a2V5\$4';
  }

  ThemeData theme() => buildLuminousTheme(
        brightness: Brightness.light,
        appColorsExtension: AppColors.fromBrightness(Brightness.light),
      );

  /// Opens the unlock screen from a button, so the route's result can be
  /// read back once it pops.
  // The emulator's logical size. (The pads overflow shorter screens and
  // larger text; that is the audit's UI row, fixed separately.)
  Future<void> phoneSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<List<bool?>> openUnlock(WidgetTester tester) async {
    await phoneSurface(tester);
    final results = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: theme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const PinUnlockScreen()),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return results;
  }

  VoidCallback? keyTap(WidgetTester tester, String digit) =>
      tester
          .widget<InkWell>(
            find.ancestor(of: find.text(digit), matching: find.byType(InkWell)),
          )
          .onTap;

  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('PinUnlockScreen', () {
    testWidgets('the keypad takes no digits until the PIN length has loaded',
        (tester) async {
      storeFourDigitPin();
      readGate = Completer<void>();
      await openUnlock(tester);

      expect(keyTap(tester, '1'), isNull,
          reason: 'before the length loads, a 6-digit PIN would be '
              'submitted at the 4th digit');

      readGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(keyTap(tester, '1'), isNotNull);
    });

    testWidgets(
        'an unreadable store offers Try again; once it reads with no PIN set, '
        'the user is let through', (tester) async {
      storeBroken = true;
      final results = await openUnlock(tester);

      expect(find.text("Couldn't check your PIN. Try again."), findsOneWidget);
      expect(keyTap(tester, '1'), isNull);

      storeBroken = false; // readable again, and no PIN was ever set
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(results, [true]);
    });

    testWidgets('a store that fails while checking is not a wrong PIN',
        (tester) async {
      storeFourDigitPin();
      await openUnlock(tester);
      failingReads.add('app_pin_hash');

      await tapDigits(tester, '9027');
      // The failed read completes outside fake time (the store falls back
      // to SharedPreferences before giving up); give it a real turn.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't check your PIN. Try again."), findsOneWidget);
      expect(find.textContaining('Incorrect PIN'), findsNothing);
      expect(store.containsKey('pin_failed_attempts'), isFalse,
          reason: 'a storage fault must not count toward the lockout');
    });
  });

  group('PinSetupScreen', () {
    testWidgets('refuses a PIN anyone would guess first', (tester) async {
      await phoneSurface(tester);
      await tester.pumpWidget(
        MaterialApp(theme: theme(), home: const PinSetupScreen()),
      );
      await tester.pump();

      await tapDigits(tester, '1111');

      expect(find.text('Avoid using all identical digits.'), findsOneWidget);
      expect(find.text('Confirm your PIN'), findsNothing,
          reason: 'a refused PIN is not taken to the confirm step');
      expect(store.containsKey('app_pin_hash'), isFalse);
    });
  });

  group('AppState.initializeLockState', () {
    test('an unreadable store keeps a cold start locked (fail closed)',
        () async {
      storeBroken = true;
      final state = AppState();
      addTearDown(state.dispose);

      await state.initializeLockState();
      await state.lockStateReady;

      expect(state.isLocked, isTrue);
    });

    test('a readable store with no PIN unlocks the cold start', () async {
      final state = AppState();
      addTearDown(state.dispose);

      await state.initializeLockState();

      expect(state.isLocked, isFalse);
    });
  });
}
