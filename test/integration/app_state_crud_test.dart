import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// Phase 7 / Stage D.1 — AppState CRUD mutator coverage.
///
/// One end-to-end test per mutator-of-interest:
///   * Seed a fresh FFI DB via `makeFreshDb()`.
///   * Bring up an [AppState] (which bootstraps a default account + default
///     categories on first `loadData()`).
///   * Exercise the mutator and assert against both the in-memory cache
///     and the on-disk row.
///
/// These tests deliberately avoid the screen widgets — they exist to lock
/// the contract of AppState as a Provider, so that future refactors of
/// HistoryScreen / AddTransactionScreen / RecurringItemsScreen can replace
/// any of the UI without silently regressing the underlying mutators.
void main() {
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null)
      ..setMockMethodCallHandler(secureChannel, null)
      ..setMockMethodCallHandler(pathProviderChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  Future<AppState> bootstrap() async {
    final state = AppState();
    await state.loadData();
    return state;
  }

  Expense makeExpense(
    AppState state, {
    double amount = 25.0,
    String category = 'Food',
    String description = 'lunch',
    DateTime? date,
    double amountPaid = 0,
    String paymentMethod = 'Cash',
  }) {
    return Expense(
      amount: Decimal.parse(amount.toString()),
      category: category,
      description: description,
      date: date ?? DateTime.now(),
      accountId: state.currentAccountId,
      amountPaid: Decimal.parse(amountPaid.toString()),
      paymentMethod: paymentMethod,
    );
  }

  Income makeIncome(
    AppState state, {
    double amount = 3000.0,
    String category = 'Salary',
    String description = 'pay',
    DateTime? date,
  }) {
    return Income(
      amount: Decimal.parse(amount.toString()),
      category: category,
      description: description,
      date: date ?? DateTime.now(),
      accountId: state.currentAccountId,
    );
  }

  group('addExpense', () {
    test('persists row + appears in in-memory list', () async {
      final state = await bootstrap();
      final notifies = <void>[];
      state.addListener(() => notifies.add(null));

      final id = await state.addExpense(makeExpense(state));

      expect(id, isNonZero);
      expect(state.expenses, isNotEmpty);
      expect(state.expenses.any((e) => e.id == id), isTrue);
      expect(notifies, isNotEmpty,
          reason: 'addExpense must call notifyListeners');
    });

    test('rejects zero / negative amount with ArgumentError', () async {
      final state = await bootstrap();
      expect(
        () => state.addExpense(makeExpense(state, amount: 0)),
        throwsArgumentError,
      );
    });

    test('rejects empty description with ArgumentError', () async {
      final state = await bootstrap();
      expect(
        () => state.addExpense(makeExpense(state, description: '')),
        throwsArgumentError,
      );
    });

    test('rejects empty category with ArgumentError', () async {
      final state = await bootstrap();
      expect(
        () => state.addExpense(makeExpense(state, category: '')),
        throwsArgumentError,
      );
    });
  });

  group('addIncome', () {
    test('persists row + appears in in-memory list', () async {
      final state = await bootstrap();
      final id = await state.addIncome(makeIncome(state));

      expect(id, isNonZero);
      expect(state.incomes, isNotEmpty);
      expect(state.incomes.any((i) => i.id == id), isTrue);
    });

    test('rejects zero amount with ArgumentError', () async {
      final state = await bootstrap();
      expect(
        () => state.addIncome(makeIncome(state, amount: 0)),
        throwsArgumentError,
      );
    });
  });

  group('delete + trash flow (expense)', () {
    test('deleteExpense moves the row to trash, removing from active list',
        () async {
      final state = await bootstrap();
      final id = await state.addExpense(makeExpense(state));
      expect(state.expenses.any((e) => e.id == id), isTrue);

      await state.deleteExpense(id);

      expect(
        state.expenses.any((e) => e.id == id),
        isFalse,
        reason: 'Trashed expense must vanish from the active cache',
      );

      final deleted = await state.getDeletedExpenses();
      expect(
        deleted.any((row) => row['description'] == 'lunch'),
        isTrue,
        reason: 'Deleted expense must surface in the trash view',
      );
    });
  });

  group('delete + trash flow (income)', () {
    test('deleteIncome moves the row to trash, removing from active list',
        () async {
      final state = await bootstrap();
      final id = await state.addIncome(makeIncome(state, description: 'march pay'));
      expect(state.incomes.any((i) => i.id == id), isTrue);

      await state.deleteIncome(id);

      expect(state.incomes.any((i) => i.id == id), isFalse);
      final deleted = await state.getDeletedIncome();
      expect(
        deleted.any((row) => row['description'] == 'march pay'),
        isTrue,
      );
    });
  });

  group('accounts', () {
    test('addAccount rejects empty / whitespace name', () async {
      final state = await bootstrap();
      expect(() => state.addAccount(''), throwsArgumentError);
      expect(() => state.addAccount('   '), throwsArgumentError);
    });

    test('addAccount appends a new account', () async {
      final state = await bootstrap();
      final before = state.accounts.length;

      await state.addAccount('Savings');

      expect(state.accounts, hasLength(before + 1));
      expect(state.accounts.any((a) => a.name == 'Savings'), isTrue);
    });

    test('setDefaultAccount flips the default exclusively', () async {
      final state = await bootstrap();
      await state.addAccount('Savings');
      final savings =
          state.accounts.firstWhere((a) => a.name == 'Savings');

      await state.setDefaultAccount(savings.id!);

      final defaults = state.accounts.where((a) => a.isDefault).toList();
      expect(defaults, hasLength(1),
          reason: 'Exactly one account is the default');
      expect(defaults.single.id, savings.id);
    });

    test('deleteAccount refuses to delete the last account', () async {
      final state = await bootstrap();
      expect(state.accounts, hasLength(1));
      expect(
        () => state.deleteAccount(state.accounts.single.id!),
        throwsArgumentError,
      );
    });

    test('deleteAccount removes a non-current account from the list',
        () async {
      final state = await bootstrap();
      await state.addAccount('Savings');
      final savings =
          state.accounts.firstWhere((a) => a.name == 'Savings');

      await state.deleteAccount(savings.id!);

      expect(state.accounts.any((a) => a.id == savings.id), isFalse);
    });
  });

  group('categories', () {
    test('addCategory + deleteCategory round-trips an account-scoped row',
        () async {
      final state = await bootstrap();
      final before = state.categories.length;

      await state.addCategory(
        'CustomCat',
        type: 'expense',
        color: '#FF0000',
        icon: 'shopping_bag',
      );

      expect(state.categories.length, before + 1);
      final added =
          state.categories.firstWhere((c) => c.name == 'CustomCat');

      await state.deleteCategory(added.id!);

      expect(
        state.categories.any((c) => c.id == added.id),
        isFalse,
      );
    });
  });

  group('setBudget', () {
    test('upserts a budget for the selected month', () async {
      final state = await bootstrap();
      final categoryNames = state.categories
          .where((c) => c.type == 'expense')
          .map((c) => c.name)
          .toList();
      expect(categoryNames, isNotEmpty,
          reason: 'Default categories should seed at least one expense category');
      final firstCategory = categoryNames.first;

      await state.setBudget(firstCategory, 250.0);

      expect(state.budgets.any((b) => b.category == firstCategory), isTrue);
      final budget =
          state.budgets.firstWhere((b) => b.category == firstCategory);
      expect(budget.amount, 250.0);
    });

    test('overwrites an existing budget rather than duplicating', () async {
      final state = await bootstrap();
      final category = state.categories
          .firstWhere((c) => c.type == 'expense')
          .name;

      await state.setBudget(category, 100);
      await state.setBudget(category, 400);

      final matching =
          state.budgets.where((b) => b.category == category).toList();
      expect(matching, hasLength(1));
      expect(matching.single.amount, 400.0);
    });
  });
}
