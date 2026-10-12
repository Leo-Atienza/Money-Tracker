import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/trash_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.9f — Trash widget smoke tests.
///
/// Covers the Luminous-redesign composition contract:
///   * Top app bar uses [GlassTopAppBar] with a back button.
///   * Empty-trash IconButton is absent when there are no items.
///
/// Behavioural flows (restore / permanent delete / empty-trash dialog)
/// are exercised at the AppState + DatabaseHelper level by the existing
/// integration tests (`cascade_delete_test.dart`). The richer per-item
/// state checks are deferred to D.6 hero widget tests, which seed the DB
/// with deleted rows before pumping.
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
          home: const TrashScreen(),
        ),
      ),
    );
  }

  testWidgets('GlassTopAppBar renders "Trash" with back button',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('empty-trash IconButton is absent when there are no items',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(
      find.byTooltip('Empty Trash'),
      findsNothing,
      reason: 'No items ⇒ delete-forever IconButton should not render.',
    );
  });

  // -------------------------------------------------------------------------
  // Session 21 review fix: 48dp touch targets on the per-item actions.
  // -------------------------------------------------------------------------

  testWidgets('restore and delete-forever are full 48dp touch targets',
      (tester) async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      final expenseId = await state.addExpense(Expense(
        amount: Decimal.parse('9.99'),
        category: 'Food',
        description: 'Snack',
        date: DateTime.now(),
        accountId: state.currentAccountId,
      ));
      await state.deleteExpense(expenseId);
      final incomeId = await state.addIncome(Income(
        amount: Decimal.parse('50'),
        category: 'Gift',
        description: 'Birthday',
        date: DateTime.now(),
        accountId: state.currentAccountId,
      ));
      await state.deleteIncome(incomeId);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: const TrashScreen(),
        ),
      ),
    );
    for (var i = 0; i < 1000 && find.text('Snack').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 700));

    void expectFullTargets() {
      for (final icon in [Icons.restore, Icons.delete_forever]) {
        final button = find.widgetWithIcon(IconButton, icon);
        // The app-bar "Empty Trash" button shares the delete_forever icon.
        for (final element in button.evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, greaterThanOrEqualTo(48), reason: '$icon');
          expect(size.height, greaterThanOrEqualTo(48), reason: '$icon');
        }
      }
    }

    expect(find.text('Snack'), findsOneWidget);
    expectFullTargets();

    await tester.tap(find.textContaining('Income ('));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Birthday'), findsOneWidget);
    expectFullTargets();
  });
}
