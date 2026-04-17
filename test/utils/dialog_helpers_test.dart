import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/main.dart' show AppColors;
import 'package:budget_tracker/utils/dialog_helpers.dart';

const _testAppColors = AppColors(
  expenseRed: Color(0xFFAA1111),
  incomeGreen: Color(0xFF1AAA1A),
  warningOrange: Color(0xFFFFAA00),
  infoBlue: Color(0xFF1A5AFF),
);

/// Pumps a MaterialApp with AppColors in the theme, and hands the captured
/// [BuildContext] back via [onContext] once the first frame is drawn. This
/// avoids the async-button-onPressed timing issue: the dialog helpers all
/// `await HapticHelper.lightImpact()` before calling `showDialog`, and
/// `tester.tap` + `pumpAndSettle` does not always advance past that awaited
/// platform-channel call reliably. Capturing the context lets us invoke the
/// dialog directly from the test body and `pumpAndSettle` through its
/// lifecycle.
Future<BuildContext> _pumpAndCaptureContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light().copyWith(
        extensions: const [_testAppColors],
      ),
      home: Scaffold(
        body: Builder(
          builder: (ctx) {
            captured = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  // All dialog helpers `await HapticHelper.*()` before calling `showDialog`.
  // `HapticFeedback.*` hits the `flutter/platform` channel — in unit tests
  // there's no real handler, so the Future never resolves and `showDialog`
  // is never reached. Install a null-returning mock so the haptic await
  // completes immediately and the dialog actually opens.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall _) async => null,
    );
    // Ensure no state from previous tests leaks the "don't ask again" flag.
    DialogHelpers.resetFutureDateWarning();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // ==========================================================================
  // showConfirmation
  // ==========================================================================
  group('showConfirmation', () {
    testWidgets('returns true when Confirm is tapped', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);

      final resultFuture = DialogHelpers.showConfirmation(
        ctx,
        title: 'Really?',
        message: 'This cannot be undone.',
      );
      await tester.pumpAndSettle();

      expect(find.text('Really?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isTrue);
    });

    testWidgets('returns false when Cancel is tapped', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showConfirmation(
        ctx,
        title: 'X',
        message: 'Y',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isFalse);
    });

    testWidgets('returns false when barrier is tapped (dismissed)',
        (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showConfirmation(
        ctx,
        title: 'X',
        message: 'Y',
      );
      await tester.pumpAndSettle();

      // Tap modal barrier to dismiss.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await resultFuture, isFalse);
    });

    testWidgets('respects custom confirm/cancel labels', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showConfirmation(
        ctx,
        title: 'Delete account',
        message: 'Goodbye',
        confirmText: 'Yes, delete it',
        cancelText: 'Keep it',
      );
      await tester.pumpAndSettle();

      expect(find.text('Yes, delete it'), findsOneWidget);
      expect(find.text('Keep it'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isFalse);
    });

    testWidgets('isDangerous=true gives the confirm button a red background',
        (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showConfirmation(
        ctx,
        title: 'X',
        message: 'Y',
        isDangerous: true,
      );
      await tester.pumpAndSettle();

      final filledFinder = find.byWidgetPredicate(
        (w) => w is FilledButton,
        description: 'FilledButton',
      );
      final filled = tester.widget<FilledButton>(filledFinder);
      final bg = filled.style!.backgroundColor!.resolve(<WidgetState>{});
      expect(bg, _testAppColors.expenseRed);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await resultFuture;
    });
  });

  // ==========================================================================
  // showBudgetDeletionWarning
  // ==========================================================================
  group('showBudgetDeletionWarning', () {
    testWidgets('shows category name, budget, and spent amounts',
        (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showBudgetDeletionWarning(
        ctx,
        categoryName: 'Groceries',
        currentSpending: 123.45,
        budgetAmount: 500.00,
        currency: '\$',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Groceries'), findsWidgets);
      expect(find.textContaining('500.00'), findsOneWidget);
      expect(find.textContaining('123.45'), findsOneWidget);
      expect(find.text('Delete Budget'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await resultFuture, isFalse);
    });

    testWidgets('returns true when Delete Budget is tapped', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showBudgetDeletionWarning(
        ctx,
        categoryName: 'Food',
        currentSpending: 0,
        budgetAmount: 100,
        currency: '\$',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Budget'));
      await tester.pumpAndSettle();

      expect(await resultFuture, isTrue);
    });
  });

  // ==========================================================================
  // showCurrencyChangeWarning
  // ==========================================================================
  group('showCurrencyChangeWarning', () {
    testWidgets('returns "keep" when Keep Amounts is tapped', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showCurrencyChangeWarning(
        ctx,
        oldCurrency: 'USD',
        newCurrency: 'EUR',
        transactionCount: 7,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('USD'), findsWidgets);
      expect(find.textContaining('EUR'), findsWidgets);
      expect(find.textContaining('7'), findsWidgets);

      await tester.tap(find.text('Keep Amounts'));
      await tester.pumpAndSettle();
      expect(await resultFuture, 'keep');
    });

    testWidgets('returns "clear" when Clear All Data is tapped',
        (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showCurrencyChangeWarning(
        ctx,
        oldCurrency: 'USD',
        newCurrency: 'GBP',
        transactionCount: 0,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear All Data'));
      await tester.pumpAndSettle();
      expect(await resultFuture, 'clear');
    });

    testWidgets('returns null when Cancel is tapped', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final resultFuture = DialogHelpers.showCurrencyChangeWarning(
        ctx,
        oldCurrency: 'USD',
        newCurrency: 'JPY',
        transactionCount: 2,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await resultFuture, isNull);
    });
  });

  // ==========================================================================
  // showFutureDateConfirmation + session skip flag
  // ==========================================================================
  group('showFutureDateConfirmation', () {
    testWidgets('returns true when Continue is tapped', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final future = DateTime.now().add(const Duration(days: 5));
      final resultFuture =
          DialogHelpers.showFutureDateConfirmation(ctx, future);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(await resultFuture, isTrue);
    });

    testWidgets('returns false when Change Date is tapped', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final future = DateTime.now().add(const Duration(days: 10));
      final resultFuture =
          DialogHelpers.showFutureDateConfirmation(ctx, future);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Date'));
      await tester.pumpAndSettle();
      expect(await resultFuture, isFalse);
    });

    testWidgets(
        '"Don\'t ask again" + Continue short-circuits subsequent prompts',
        (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final future = DateTime.now().add(const Duration(days: 2));

      // First invocation: tick the checkbox and hit Continue.
      final first = DialogHelpers.showFutureDateConfirmation(ctx, future);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(await first, isTrue);

      // Second invocation: should resolve to true immediately, no dialog.
      final second = DialogHelpers.showFutureDateConfirmation(ctx, future);
      // Drain microtasks.
      await tester.pump();
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Change Date'), findsNothing);
      expect(await second, isTrue);
    });

    testWidgets('resetFutureDateWarning re-enables the prompt', (tester) async {
      final ctx = await _pumpAndCaptureContext(tester);
      final future = DateTime.now().add(const Duration(days: 1));

      // Prime the skip flag.
      final first = DialogHelpers.showFutureDateConfirmation(ctx, future);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await first;

      // Reset and confirm the dialog shows again.
      DialogHelpers.resetFutureDateWarning();

      final second = DialogHelpers.showFutureDateConfirmation(ctx, future);
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);

      // Dismiss so the test exits cleanly.
      await tester.tap(find.text('Change Date'));
      await tester.pumpAndSettle();
      await second;
    });
  });
}
