import 'package:budget_tracker/models/recurring_expense_model.dart';
import 'package:budget_tracker/models/recurring_income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/recurring_items_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/utils/currency_helper.dart';
import 'package:budget_tracker/utils/premium_animations.dart';
import 'package:budget_tracker/widgets/luminous/glass_segmented_control.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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
  // Deleting a recurring expense cancels its bill reminder, which needs a
  // notifications platform; the plugin registrant does not run in tests.
  FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();

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

  // -------------------------------------------------------------------------
  // Session 21 review fixes.
  // -------------------------------------------------------------------------

  /// Drives UI-started async work (the database runs on real I/O) until
  /// [until] holds, bounded, then lets the UI settle.
  Future<void> drainAsync(
    WidgetTester tester, {
    required bool Function() until,
  }) async {
    Future<void> round() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    for (var i = 0; i < 1000 && !until(); i++) {
      await round();
    }
    for (var i = 0; i < 30; i++) {
      await round();
    }
  }

  Future<AppState> seeded(
    WidgetTester tester, {
    Map<String, String> expenses = const {},
    Map<String, String> incomes = const {},
  }) async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      for (final e in expenses.entries) {
        await state.addRecurringExpense(RecurringExpense(
          description: e.key,
          amount: Decimal.parse(e.value),
          category: 'Bills',
          dayOfMonth: 5,
          accountId: state.currentAccountId,
        ));
      }
      for (final e in incomes.entries) {
        await state.addRecurringIncome(RecurringIncome(
          description: e.key,
          amount: Decimal.parse(e.value),
          category: 'Salary',
          dayOfMonth: 15,
          accountId: state.currentAccountId,
        ));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    return state;
  }

  /// Pushes the screen over a base route, as Settings does, so a stray
  /// extra pop shows up as the screen disappearing.
  Future<void> pumpPushed(
    WidgetTester tester, {
    required AppState state,
    String initialType = 'expense',
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: const Scaffold(body: Text('Base route')),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: padding),
          child: RecurringItemsScreen(initialType: initialType),
        ),
      ),
    );
    await pumpAndDrain(tester);
  }

  testWidgets(
      'recurring expense cards start flush under a status-bar inset and '
      'keep their spacing outside the border', (tester) async {
    final state = await seeded(
      tester,
      expenses: {'Netflix': '15.99', 'Rent': '1200'},
    );
    await pumpPushed(
      tester,
      state: state,
      padding: const EdgeInsets.only(top: 48),
    );

    final list = find.byType(ListView);
    final firstRow = find.byType(StaggeredListItem).first;
    expect(
      tester.getTopLeft(firstRow).dy - tester.getTopLeft(list).dy,
      lessThan(1),
    );

    // The 16dp gap sat inside each card's border, so bordered cards touched.
    final cards = find.byType(AnimatedPressCard);
    final gap = tester.getRect(cards.at(1)).top -
        tester.getRect(cards.at(0)).bottom;
    expect(gap, closeTo(16, 0.5));
  });

  testWidgets('recurring amounts show their cents', (tester) async {
    final state = await seeded(
      tester,
      expenses: {'Netflix': '15.99'},
      incomes: {'Paycheck': '1234.50'},
    );
    await pumpPushed(tester, state: state);

    // toStringAsFixed(0) showed $15.99 as "$16".
    expect(find.text(r'$15.99'), findsOneWidget);
    expect(find.text(r'$16'), findsNothing);

    await tester.tap(find.text('Income'));
    await pumpAndDrain(tester);
    expect(find.text(r'$1,234.50'), findsOneWidget);
  });

  Future<void> typeAmount(WidgetTester tester, String text) async {
    final field = find.descendant(
      of: find.widgetWithText(TextFormField, 'Amount'),
      matching: find.byType(EditableText),
    );
    // One keystroke at a time, the way a keyboard delivers them.
    for (final ch in text.split('')) {
      final current = tester.widget<EditableText>(field).controller.text;
      await tester.enterText(field, current + ch);
      await tester.pump();
    }
  }

  EditableText amountField(WidgetTester tester) => tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Amount'),
          matching: find.byType(EditableText),
        ),
      );

  for (final type in ['expense', 'income']) {
    testWidgets('the $type amount field keeps a typed decimal comma',
        (tester) async {
      final state = await seeded(tester);
      await pumpPushed(tester, state: state, initialType: type);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpAndDrain(tester);
      await typeAmount(tester, '15,49');

      // The old filter dropped the comma, so "15,49" became 1549 a month.
      final field = amountField(tester);
      expect(CurrencyHelper.parseDecimal(field.controller.text), 15.49);
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    });
  }

  testWidgets('a double tap on Delete deletes a recurring expense once and '
      'leaves the screen open', (tester) async {
    final state = await seeded(tester, expenses: {'Netflix': '15.99'});
    await pumpPushed(tester, state: state);

    await tester.longPress(find.text('Netflix'));
    await pumpAndDrain(tester);
    final delete = find.widgetWithText(TextButton, 'Delete');
    await tester.tap(delete);
    await tester.tap(delete, warnIfMissed: false);
    await drainAsync(tester, until: () => state.recurringExpenses.isEmpty);

    expect(state.recurringExpenses, isEmpty);
    expect(find.byType(RecurringItemsScreen), findsOneWidget);
    expect(find.text('Delete Recurring Expense?'), findsNothing);
  });

  testWidgets('a double tap on Delete deletes a recurring income once and '
      'leaves the screen open', (tester) async {
    final state = await seeded(tester, incomes: {'Paycheck': '3000'});
    await pumpPushed(tester, state: state, initialType: 'income');

    await tester.longPress(find.text('Paycheck'));
    await pumpAndDrain(tester);
    final delete = find.widgetWithText(TextButton, 'Delete');
    await tester.tap(delete);
    await tester.tap(delete, warnIfMissed: false);
    await drainAsync(tester, until: () => state.recurringIncomes.isEmpty);

    expect(state.recurringIncomes, isEmpty);
    expect(find.byType(RecurringItemsScreen), findsOneWidget);
    expect(find.text('Delete Recurring Income?'), findsNothing);
  });

  testWidgets('the recurring income sheet points income up, as Home does',
      (tester) async {
    final state = await seeded(tester);
    await pumpPushed(tester, state: state, initialType: 'income');

    await tester.tap(find.byType(FloatingActionButton));
    await pumpAndDrain(tester);

    expect(find.text('Add Recurring Income'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });
}

/// No-op notifications platform: lets reminder bookkeeping run in tests.
class _NoopNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel({required int id, String? tag}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return const [];
  }
}
