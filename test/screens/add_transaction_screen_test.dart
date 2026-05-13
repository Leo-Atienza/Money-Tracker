import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/add_transaction_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/category_bento_grid.dart';
import 'package:budget_tracker/widgets/luminous/glass_panel.dart';
import 'package:budget_tracker/widgets/luminous/glass_segmented_control.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.5 — `AddTransactionScreen` widget tests.
///
/// Covers the surfaces that are inexpensive at the widget layer:
///   * Luminous composition contract (GlassTopAppBar + segmented control +
///     save button).
///   * Field-preservation contract on the type toggle (R15): shared
///     scalars survive, `_category` resets, `_amountPaid` is one-way
///     cleared when toggling to Income.
///   * First-launch tooltip — appears once, persists dismissal in
///     SharedPreferences.
///   * Edit-mode hides the segmented control and re-labels the save
///     button.
///
/// **End-to-end submission** (addExpense / addIncome called from the
/// save button) is covered by the integration suite at
/// `test/integration/app_state_crud_test.dart`. Driving it through this
/// widget harness would require `AppState.loadData()`, which kicks off
/// a fire-and-forget `_processRecurringInBackground()` that interleaves
/// with `pumpAndSettle()` and never settles. The harness below
/// deliberately avoids `loadData` so the screen still renders (with an
/// empty category bento) and the toggle / tooltip / edit-mode contracts
/// can be exercised without the recurring-processor pump-loop hazard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  late TestDefaultBinaryMessenger messenger;

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null)
      ..setMockMethodCallHandler(secureChannel, (_) async => null)
      ..setMockMethodCallHandler(
        pathProviderChannel,
        (_) async => '.dart_tool/test_path_provider',
      );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() async {
    messenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null)
      ..setMockMethodCallHandler(secureChannel, null)
      ..setMockMethodCallHandler(pathProviderChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    required AppState state,
    TransactionType initialType = TransactionType.expense,
    Expense? expense,
    Size surface = const Size(420, 1400),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: AddTransactionScreen(
            initialType: initialType,
            expense: expense,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'renders GlassTopAppBar + segmented control + save button',
    (tester) async {
      final state = AppState();
      await pumpHarness(tester, state: state);
      await tester.pumpAndSettle();

      expect(find.byType(GlassTopAppBar), findsOneWidget);
      expect(find.text('Add Transaction'), findsOneWidget);
      expect(find.byType(GlassSegmentedControl<TransactionType>),
          findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Add Expense'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'type toggle preserves amount + description controllers (R15)',
    (tester) async {
      final state = AppState();
      await pumpHarness(tester, state: state);
      await tester.pumpAndSettle();

      // Expense mode: 3 TextFormFields — amount (0), description (1),
      // amount-paid (2). Without [AppState.loadData] the form still
      // renders all sections; the category card shows its empty-state
      // copy. The toggle contract under test does not depend on
      // categories existing.
      await tester.enterText(find.byType(TextFormField).at(0), '99.99');
      await tester.enterText(find.byType(TextFormField).at(1), 'lunch');
      await tester.pumpAndSettle();

      // Toggle to Income.
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      final amount = tester.widget<TextFormField>(
        find.byType(TextFormField).at(0),
      );
      final desc = tester.widget<TextFormField>(
        find.byType(TextFormField).at(1),
      );
      expect(amount.controller?.text, '99.99',
          reason: 'amount controller must survive the type toggle');
      expect(desc.controller?.text, 'lunch',
          reason: 'description controller must survive the type toggle');

      // Save button label flips and the expense-only cards disappear.
      expect(
        find.widgetWithText(ElevatedButton, 'Add Income'),
        findsOneWidget,
      );
      expect(find.text('PAYMENT METHOD'), findsNothing);
      expect(find.text('AMOUNT PAID (OPTIONAL)'), findsNothing);
    },
  );

  testWidgets(
    'toggling Income → Expense round-trip resets amount-paid to default 0',
    (tester) async {
      final state = AppState();
      await pumpHarness(tester, state: state);
      await tester.pumpAndSettle();

      // Expense mode: enter a non-default amount-paid.
      await tester.enterText(find.byType(TextFormField).at(0), '100');
      await tester.enterText(find.byType(TextFormField).at(2), '50');
      await tester.pumpAndSettle();

      // Toggle to Income — amount-paid card unmounts.
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.text('AMOUNT PAID (OPTIONAL)'), findsNothing);

      // Toggle back to Expense — amount-paid card reappears with the
      // default '0'. The user-entered '50' must NOT survive (one-way
      // clear is the R15 mitigation; documented in
      // `_AddTransactionScreenState._onTypeChanged`).
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      expect(find.text('AMOUNT PAID (OPTIONAL)'), findsOneWidget);

      final amountPaid = tester.widget<TextFormField>(
        find.byType(TextFormField).at(2),
      );
      expect(amountPaid.controller?.text, '0',
          reason:
              'amount-paid resets to default "0" (user-entered 50 must not survive)');

      // Sanity: amount itself survived round-trip.
      final amount = tester.widget<TextFormField>(
        find.byType(TextFormField).at(0),
      );
      expect(amount.controller?.text, '100',
          reason: 'amount survives type toggle');
    },
  );

  testWidgets(
    'first-launch tooltip renders, dismisses on Got it, and stays dismissed',
    (tester) async {
      final state = AppState();
      // Fresh SharedPreferences (set in setUp) → tooltip key absent →
      // screen reads `false` and shows the coach mark.
      await pumpHarness(tester, state: state);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Switch between Expense and Income'),
        findsOneWidget,
        reason: 'tooltip must appear on first launch',
      );
      expect(find.widgetWithText(TextButton, 'Got it'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Got it'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Switch between Expense and Income'),
        findsNothing,
        reason: 'tooltip must disappear after Got it',
      );

      // Re-pump a fresh screen — dismissal persists via
      // SharedPreferences so the user never sees it twice.
      final state2 = AppState();
      await pumpHarness(tester, state: state2);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Switch between Expense and Income'),
        findsNothing,
        reason: 'tooltip must NOT reappear after persisting dismissal',
      );
    },
  );

  testWidgets(
    'edit-mode expense hides the segmented control and shows Update Expense',
    (tester) async {
      final state = AppState();
      final expense = Expense(
        id: 7,
        amount: Decimal.parse('12.34'),
        category: 'Food',
        description: 'seeded',
        date: DateTime.parse('2026-05-12'),
        accountId: 1,
      );

      // Wider surface lets the bento grid's 4-column layout breathe —
      // narrower surfaces clip the archived-category placeholder vertically.
      await pumpHarness(
        tester,
        state: state,
        expense: expense,
        surface: const Size(800, 1600),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(
        find.byType(GlassSegmentedControl<TransactionType>),
        findsNothing,
        reason: 'segmented toggle is hidden in edit mode',
      );
      expect(
        find.textContaining('Switch between Expense and Income'),
        findsNothing,
        reason: 'first-launch tooltip is suppressed in edit mode',
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Update Expense'),
        findsOneWidget,
      );
      // The form panels still render even though categories aren't loaded
      // — the screen shows an archived-category placeholder for "Food".
      expect(find.byType(GlassPanel), findsWidgets);
      expect(find.text('Food'), findsWidgets);
    },
  );

  // -------------------------------------------------------------------------
  // Stage D.2 — seeded-data AddTransaction assertions.
  //
  // The original Phase 5.5 tests deliberately avoid `loadData()` because
  // the recurring processor races `pumpAndSettle`. The seeded suite drains
  // it inside `tester.runAsync()` and then uses bounded `pump()` calls.
  // -------------------------------------------------------------------------

  Future<void> pumpSeededHarness(
    WidgetTester tester, {
    required AppState state,
    TransactionType initialType = TransactionType.expense,
    Expense? expense,
    Size surface = const Size(800, 1600),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: AddTransactionScreen(
            initialType: initialType,
            expense: expense,
          ),
        ),
      ),
    );
  }

  Future<void> pumpAndDrain(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets(
    'after loadData(), CategoryBentoGrid renders seeded expense categories',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpSeededHarness(tester, state: state);
      await pumpAndDrain(tester);

      // The CATEGORY card switches from the empty-state copy to a real
      // CategoryBentoGrid once seeded categories exist.
      expect(
        find.text('No expense categories yet — tap New to add one.'),
        findsNothing,
      );
      expect(find.byType(CategoryBentoGrid), findsOneWidget);
      // Default expense categories — assert against the labels the grid
      // renders. `CategoryBentoItem` is a data class (not a widget); the
      // visible artifact is the label Text.
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Transport'), findsWidgets);
    },
  );

  testWidgets(
    'after toggle to Income, CategoryBentoGrid renders income categories',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpSeededHarness(tester, state: state);
      await pumpAndDrain(tester);

      // Save button label flips when toggled to Income.
      expect(find.widgetWithText(ElevatedButton, 'Add Expense'),
          findsOneWidget);
      await tester.tap(find.text('Income'));
      await pumpAndDrain(tester);
      expect(find.widgetWithText(ElevatedButton, 'Add Income'),
          findsOneWidget);

      // The income category list also surfaces from the bootstrap; the
      // empty-state copy must NOT appear.
      expect(
        find.text('No income categories yet — tap New to add one.'),
        findsNothing,
      );
      expect(find.byType(CategoryBentoGrid), findsOneWidget);
    },
  );

  testWidgets(
    'AppState.addExpense end-to-end with the seeded bootstrap data',
    (tester) async {
      // The screen-driven save path involves Navigator.pop() inside an
      // async callback, which races widget disposal in flutter_test and
      // leaves the ElevatedButton finder empty mid-tap. The screen's
      // submit code path is otherwise identical to the unit-level
      // `state.addExpense` it calls — we exercise that here so the
      // contract is locked without the dispose race.
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpSeededHarness(tester, state: state);
      await pumpAndDrain(tester);

      // Pre-condition: no expenses yet.
      expect(state.expenses, isEmpty);

      // Drive the same mutator the Save button would.
      await tester.runAsync(() async {
        await state.addExpense(Expense(
          amount: Decimal.parse('42.50'),
          category: 'Food',
          description: 'taco',
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      // Post-condition: AppState's filtered (selected-month) list has the
      // expense.
      expect(state.expenses, isNotEmpty);
      expect(state.expenses.first.description, 'taco');
      expect(state.expenses.first.amount, 42.5);
      expect(state.expenses.first.category, 'Food');
    },
  );
}
