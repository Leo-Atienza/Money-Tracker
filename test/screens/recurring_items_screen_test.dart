import 'package:budget_tracker/models/recurring_expense_model.dart';
import 'package:budget_tracker/models/recurring_income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/recurring_items_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_segmented_control.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.7 — RecurringItemsScreen widget smoke tests.
///
/// Covers the merged Luminous composition contract:
///   * [GlassTopAppBar] renders "Recurring Items" with a back button.
///   * [GlassSegmentedControl] flips the visible empty-state copy.
///   * Initial type from constructor controls which side renders first.
///
/// Behavioural flows (add/edit/delete a recurring item, notification
/// scheduling) are exercised at the AppState + DatabaseHelper level by
/// integration tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (_) async => null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    String initialType = 'expense',
    Size surface = const Size(420, 1400),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: RecurringItemsScreen(initialType: initialType),
        ),
      ),
    );
  }

  testWidgets(
    'GlassTopAppBar + GlassSegmentedControl render',
    (tester) async {
      await pumpHarness(tester);
      await tester.pumpAndSettle();

      expect(find.byType(GlassTopAppBar), findsOneWidget);
      expect(find.text('Recurring Items'), findsOneWidget);
      expect(find.byType(GlassSegmentedControl<String>), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    },
  );

  testWidgets(
    'initialType: expense shows expense empty state',
    (tester) async {
      await pumpHarness(tester, initialType: 'expense');
      await tester.pumpAndSettle();

      expect(find.text('No recurring expenses'), findsOneWidget);
      expect(find.text('No recurring income'), findsNothing);
    },
  );

  testWidgets(
    'initialType: income shows income empty state',
    (tester) async {
      await pumpHarness(tester, initialType: 'income');
      await tester.pumpAndSettle();

      expect(find.text('No recurring income'), findsOneWidget);
      expect(find.text('No recurring expenses'), findsNothing);
    },
  );

  testWidgets(
    'tapping Income segment swaps the visible empty state',
    (tester) async {
      await pumpHarness(tester, initialType: 'expense');
      await tester.pumpAndSettle();

      expect(find.text('No recurring expenses'), findsOneWidget);

      // Tap the "Income" label inside the segmented control.
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('No recurring income'), findsOneWidget);
      expect(find.text('No recurring expenses'), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // Stage D.2 — seeded-data RecurringItems assertions.
  //
  // Same pump pattern as the other hero D.2 tests: `loadData` fires a
  // background recurring processor, so seed via `tester.runAsync` then
  // `pump()` with a bounded duration (no `pumpAndSettle`).
  // -------------------------------------------------------------------------

  Future<void> pumpWithState(
    WidgetTester tester, {
    required AppState state,
    String initialType = 'expense',
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
          home: RecurringItemsScreen(initialType: initialType),
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
    'seeded recurring expenses show on the Expenses tab',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addRecurringExpense(RecurringExpense(
          description: 'Netflix',
          amount: Decimal.parse('14.99'),
          category: 'Entertainment',
          dayOfMonth: 5,
          accountId: state.currentAccountId,
        ));
        await state.addRecurringExpense(RecurringExpense(
          description: 'Rent',
          amount: Decimal.parse('1200'),
          category: 'Housing',
          dayOfMonth: 1,
          accountId: state.currentAccountId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpWithState(tester, state: state, initialType: 'expense');
      await pumpAndDrain(tester);

      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      // No empty state once data is seeded.
      expect(find.text('No recurring expenses'), findsNothing);
    },
  );

  testWidgets(
    'seeded recurring income shows on the Income tab',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addRecurringIncome(RecurringIncome(
          description: 'Paycheck',
          amount: Decimal.parse('3000'),
          category: 'Salary',
          dayOfMonth: 15,
          accountId: state.currentAccountId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpWithState(tester, state: state, initialType: 'income');
      await pumpAndDrain(tester);

      expect(find.text('Paycheck'), findsOneWidget);
      expect(find.text('No recurring income'), findsNothing);
    },
  );

  testWidgets(
    'segment toggle preserves seeded data across both views',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addRecurringExpense(RecurringExpense(
          description: 'Gym',
          amount: Decimal.parse('40'),
          category: 'Health',
          dayOfMonth: 10,
          accountId: state.currentAccountId,
        ));
        await state.addRecurringIncome(RecurringIncome(
          description: 'Freelance',
          amount: Decimal.parse('500'),
          category: 'Side',
          dayOfMonth: 20,
          accountId: state.currentAccountId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpWithState(tester, state: state, initialType: 'expense');
      await pumpAndDrain(tester);

      // Expenses tab — Gym visible, Freelance hidden.
      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('Freelance'), findsNothing);

      // Tap Income segment.
      await tester.tap(find.text('Income'));
      await pumpAndDrain(tester);

      expect(find.text('Freelance'), findsOneWidget);
      expect(find.text('Gym'), findsNothing);

      // Back to Expenses — Gym should reappear.
      await tester.tap(find.text('Expenses'));
      await pumpAndDrain(tester);

      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('Freelance'), findsNothing);
    },
  );
}
