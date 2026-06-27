import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/haptic_helper.dart';

/// Unit tests for [HapticHelper].
///
/// Every method is a thin wrapper over `HapticFeedback.*`, which routes through
/// `SystemChannels.platform` (the `flutter/platform` MethodChannel). We install
/// a mock handler on that channel — exactly as `dialog_helpers_test.dart` does —
/// and record every [MethodCall] so we can assert the *exact* channel contract
/// each wrapper produces.
///
/// Source-derived facts (Flutter SDK `haptic_feedback.dart`):
///   * Every impact/selection/vibrate call uses method `'HapticFeedback.vibrate'`.
///   * The variant is carried in the *argument*:
///       - lightImpact     -> 'HapticFeedbackType.lightImpact'
///       - mediumImpact    -> 'HapticFeedbackType.mediumImpact'
///       - heavyImpact     -> 'HapticFeedbackType.heavyImpact'
///       - selectionClick  -> 'HapticFeedbackType.selectionClick'
///       - vibrate()       -> argument is null (no variant)
///   * HapticHelper's semantic aliases delegate:
///       - budgetExceeded -> heavyImpact, itemDeleted -> mediumImpact,
///         success -> lightImpact, error -> vibrate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Records every call the helper pushes onto the platform channel.
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        log.add(call);
        return null; // platform haptics return void
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // The only platform method haptics ever emit.
  const String vibrateMethod = 'HapticFeedback.vibrate';

  /// Pulls out only the haptic calls — defensive in case the framework emits
  /// other platform-channel chatter during a test run.
  List<MethodCall> hapticCalls() =>
      log.where((c) => c.method == vibrateMethod).toList();

  group('impact wrappers send the correct HapticFeedbackType argument', () {
    test('lightImpact -> HapticFeedbackType.lightImpact', () async {
      await HapticHelper.lightImpact();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('mediumImpact -> HapticFeedbackType.mediumImpact', () async {
      await HapticHelper.mediumImpact();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
    });

    test('heavyImpact -> HapticFeedbackType.heavyImpact', () async {
      await HapticHelper.heavyImpact();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      expect(calls.single.arguments, 'HapticFeedbackType.heavyImpact');
    });

    test('selectionClick -> HapticFeedbackType.selectionClick', () async {
      await HapticHelper.selectionClick();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
    });
  });

  group('vibrate sends the no-argument form', () {
    test('vibrate -> HapticFeedback.vibrate with null argument', () async {
      await HapticHelper.vibrate();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      // The bare HapticFeedback.vibrate() passes no argument (unlike the
      // impact variants which carry a HapticFeedbackType string).
      expect(calls.single.arguments, isNull);
    });
  });

  group('semantic aliases delegate to the correct impact', () {
    test('budgetExceeded delegates to heavyImpact', () async {
      await HapticHelper.budgetExceeded();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      expect(calls.single.arguments, 'HapticFeedbackType.heavyImpact');
    });

    test('itemDeleted delegates to mediumImpact', () async {
      await HapticHelper.itemDeleted();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
    });

    test('success delegates to lightImpact', () async {
      await HapticHelper.success();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('error delegates to vibrate (no argument)', () async {
      await HapticHelper.error();
      final calls = hapticCalls();
      expect(calls, hasLength(1));
      expect(calls.single.method, vibrateMethod);
      expect(calls.single.arguments, isNull);
    });
  });

  group('resilience', () {
    test('completes without throwing when handler returns null', () async {
      // The default mock returns null; each wrapper should resolve cleanly.
      await expectLater(HapticHelper.lightImpact(), completes);
      await expectLater(HapticHelper.mediumImpact(), completes);
      await expectLater(HapticHelper.heavyImpact(), completes);
      await expectLater(HapticHelper.selectionClick(), completes);
      await expectLater(HapticHelper.vibrate(), completes);
      await expectLater(HapticHelper.budgetExceeded(), completes);
      await expectLater(HapticHelper.itemDeleted(), completes);
      await expectLater(HapticHelper.success(), completes);
      await expectLater(HapticHelper.error(), completes);
    });

    test('each wrapper emits exactly one platform call (no double-fire)',
        () async {
      await HapticHelper.lightImpact();
      await HapticHelper.mediumImpact();
      await HapticHelper.heavyImpact();
      await HapticHelper.selectionClick();
      await HapticHelper.vibrate();
      // 5 distinct triggers -> exactly 5 channel calls, in order.
      final calls = hapticCalls();
      expect(calls, hasLength(5));
      expect(
        calls.map((c) => c.arguments).toList(),
        <Object?>[
          'HapticFeedbackType.lightImpact',
          'HapticFeedbackType.mediumImpact',
          'HapticFeedbackType.heavyImpact',
          'HapticFeedbackType.selectionClick',
          null,
        ],
      );
    });
  });
}
