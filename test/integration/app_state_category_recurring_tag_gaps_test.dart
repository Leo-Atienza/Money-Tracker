import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/models/quick_template_model.dart';
import 'package:budget_tracker/models/recurring_income_model.dart';
import 'package:budget_tracker/models/tag_model.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// Stage D.1 remainder — AppState gap coverage for the Category / Quick-template
/// / Recurring / Tag method clusters called out as 🟡 Partial / ❌ Missing in
/// docs/NEXT_SESSION_HANDOFF.md (lines 2833-2920).
///
/// These mirror the seed → mutate → assert-in-memory (and, where relevant,
/// assert-on-disk via DatabaseHelper().database) shape of
/// app_state_crud_test.dart. They deliberately do NOT re-cover the ✅ rows that
/// crud_test / use_template_test / recurring_processing_test already lock.
///
/// Boilerplate (mock channels + makeFreshDb + bootstrap/makeExpense/makeIncome)
/// is copied from app_state_crud_test.dart.
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

  // ---------------------------------------------------------------------------
  // Category methods — addCategory validation gaps.
  // ---------------------------------------------------------------------------

  group('addCategory validation', () {
    test('rejects empty name with ArgumentError', () async {
      final state = await bootstrap();
      expect(() => state.addCategory(''), throwsArgumentError);
    });

    test('rejects whitespace-only name with ArgumentError', () async {
      final state = await bootstrap();
      expect(() => state.addCategory('   '), throwsArgumentError);
    });

    test('rejects case-insensitive duplicate within the same type', () async {
      final state = await bootstrap();
      await state.addCategory('Travel', type: 'expense');

      // Same name, different case, same type → duplicate.
      expect(
        () => state.addCategory('travel', type: 'expense'),
        throwsArgumentError,
      );
      // Only one 'Travel'-ish expense category exists.
      final matches = state.expenseCategories
          .where((c) => c.name.toLowerCase() == 'travel')
          .length;
      expect(matches, 1);
    });

    test('trims surrounding whitespace before persisting', () async {
      final state = await bootstrap();
      await state.addCategory('  Spaced  ', type: 'expense');

      expect(state.categories.any((c) => c.name == 'Spaced'), isTrue,
          reason: 'name should be stored trimmed');
    });

    test('allows the same name across different types', () async {
      final state = await bootstrap();
      // Use a name unlikely to collide with default seeds in either type.
      await state.addCategory('Crossover', type: 'expense');
      await state.addCategory('Crossover', type: 'income');

      expect(
        state.expenseCategories.any((c) => c.name == 'Crossover'),
        isTrue,
      );
      expect(
        state.incomeCategories.any((c) => c.name == 'Crossover'),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Category methods — updateCategory rename propagation + skip path.
  // ---------------------------------------------------------------------------

  group('updateCategory rename propagation', () {
    test('rename back-propagates to income rows', () async {
      final state = await bootstrap();
      final original =
          state.categories.firstWhere((c) => c.type == 'income');
      await state.addIncome(
        makeIncome(state, category: original.name, description: 'inc-pre'),
      );

      final renamed = original.copyWith(name: '${original.name}-INC');
      await state.updateCategory(renamed, oldName: original.name);

      final survivor =
          state.incomes.firstWhere((i) => i.description == 'inc-pre');
      expect(survivor.category, '${original.name}-INC',
          reason: 'rename must back-propagate to existing income rows');
    });

    test('rename back-propagates to budgets', () async {
      final state = await bootstrap();
      final original =
          state.categories.firstWhere((c) => c.type == 'expense');
      await state.setBudget(original.name, 150);
      expect(state.budgets.any((b) => b.category == original.name), isTrue);

      final renamed = original.copyWith(name: '${original.name}-B');
      await state.updateCategory(renamed, oldName: original.name);

      expect(
        state.budgets.any((b) => b.category == '${original.name}-B'),
        isTrue,
        reason: 'rename must back-propagate to budgets',
      );
      expect(
        state.budgets.any((b) => b.category == original.name),
        isFalse,
        reason: 'no budget should keep the old category name',
      );
    });

    test('rename back-propagates to quick templates', () async {
      final state = await bootstrap();
      final original =
          state.categories.firstWhere((c) => c.type == 'expense');
      await state.addTemplate(
        QuickTemplate(
          name: 'tmpl',
          amount: Decimal.parse('9.00'),
          category: original.name,
          type: 'expense',
          accountId: state.currentAccountId,
        ),
      );

      final renamed = original.copyWith(name: '${original.name}-T');
      await state.updateCategory(renamed, oldName: original.name);

      expect(
        state.quickTemplates
            .firstWhere((t) => t.name == 'tmpl')
            .category,
        '${original.name}-T',
        reason: 'rename must back-propagate to quick templates',
      );
    });

    test('color/icon-only update (no name change) leaves dependent rows intact',
        () async {
      final state = await bootstrap();
      final original =
          state.categories.firstWhere((c) => c.type == 'expense');
      await state.addExpense(
        makeExpense(state, category: original.name, description: 'keepme'),
      );

      // oldName omitted → updateCategory takes the no-rename branch.
      final recolored = original.copyWith(color: '#123456', icon: 'star');
      await state.updateCategory(recolored);

      final after =
          state.categories.firstWhere((c) => c.id == original.id);
      expect(after.color, '#123456');
      expect(after.icon, 'star');
      expect(after.name, original.name,
          reason: 'name must be unchanged on a color/icon-only update');
      // Existing expense keeps the same (unchanged) category name.
      expect(
        state.expenses
            .firstWhere((e) => e.description == 'keepme')
            .category,
        original.name,
      );
    });

    test('re-entrant updateCategory does not crash or double-rename', () async {
      // Two near-simultaneous renames. The _categoryRenameInProgress guard
      // early-returns the second if it lands mid-flight; in the common case
      // the mutex serialises them so the second sees the already-renamed
      // category. Either way the operation must not throw and the cache must
      // end in a consistent state.
      final state = await bootstrap();
      final original =
          state.categories.firstWhere((c) => c.type == 'expense');

      final renamed = original.copyWith(name: '${original.name}-R');
      final f1 = state.updateCategory(renamed, oldName: original.name);
      final f2 = state.updateCategory(renamed, oldName: original.name);
      await Future.wait([f1, f2]);

      // The renamed category exists exactly once; no leftover phantom.
      final matches = state.categories
          .where((c) => c.name == '${original.name}-R')
          .length;
      expect(matches, 1,
          reason: 'a re-entrant rename must not duplicate the category');
    });
  });

  // ---------------------------------------------------------------------------
  // Category methods — bulkReassignCategory (distinct from reassign+delete).
  // ---------------------------------------------------------------------------

  group('bulkReassignCategory', () {
    test('moves expenses to the target category, leaving the source category row',
        () async {
      final state = await bootstrap();
      await state.addCategory('Src', type: 'expense');
      final target = state.expenseCategories
          .firstWhere((c) => c.name != 'Src');
      await state.addExpense(
        makeExpense(state, category: 'Src', description: 'move-exp'),
      );

      final notifies = <void>[];
      state.addListener(() => notifies.add(null));

      await state.bulkReassignCategory('Src', target.name, 'expense');

      expect(
        state.expenses
            .firstWhere((e) => e.description == 'move-exp')
            .category,
        target.name,
        reason: 'expense must be reassigned to the target category',
      );
      // bulkReassignCategory does NOT delete the source category (unlike
      // reassignCategoryAndDelete) — the category row survives.
      expect(state.categories.any((c) => c.name == 'Src'), isTrue,
          reason: 'bulkReassignCategory must not delete the source category');
      expect(notifies, isNotEmpty,
          reason: 'bulkReassignCategory must call notifyListeners');
    });

    test('moves income rows for type==income', () async {
      final state = await bootstrap();
      await state.addCategory('IncSrc', type: 'income');
      final target = state.incomeCategories
          .firstWhere((c) => c.name != 'IncSrc');
      await state.addIncome(
        makeIncome(state, category: 'IncSrc', description: 'move-inc'),
      );

      await state.bulkReassignCategory('IncSrc', target.name, 'income');

      expect(
        state.incomes
            .firstWhere((i) => i.description == 'move-inc')
            .category,
        target.name,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Category methods — bulkDeleteTransactionsByCategory.
  // ---------------------------------------------------------------------------

  group('bulkDeleteTransactionsByCategory', () {
    test('removes all matching expenses, leaves other categories untouched',
        () async {
      final state = await bootstrap();
      await state.addCategory('Wipe', type: 'expense');
      final keepCat = state.expenseCategories
          .firstWhere((c) => c.name != 'Wipe');

      await state.addExpense(
        makeExpense(state, category: 'Wipe', description: 'wipe-1'),
      );
      await state.addExpense(
        makeExpense(state, category: 'Wipe', description: 'wipe-2'),
      );
      await state.addExpense(
        makeExpense(state, category: keepCat.name, description: 'survivor'),
      );

      await state.bulkDeleteTransactionsByCategory('Wipe', 'expense');

      expect(
        state.expenses.any((e) => e.category == 'Wipe'),
        isFalse,
        reason: 'all expenses in the wiped category must be gone',
      );
      expect(
        state.expenses.any((e) => e.description == 'survivor'),
        isTrue,
        reason: 'expenses in other categories must be untouched',
      );
    });

    test('income variant removes matching income only', () async {
      final state = await bootstrap();
      await state.addCategory('WipeInc', type: 'income');
      final keepCat = state.incomeCategories
          .firstWhere((c) => c.name != 'WipeInc');

      await state.addIncome(
        makeIncome(state, category: 'WipeInc', description: 'inc-wipe'),
      );
      await state.addIncome(
        makeIncome(state, category: keepCat.name, description: 'inc-keep'),
      );

      await state.bulkDeleteTransactionsByCategory('WipeInc', 'income');

      expect(state.incomes.any((i) => i.category == 'WipeInc'), isFalse);
      expect(state.incomes.any((i) => i.description == 'inc-keep'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Category methods — usage / count helpers.
  // ---------------------------------------------------------------------------

  group('getCategoryUsageInRecurring', () {
    test('counts recurring income for a category and 0 for an unused one',
        () async {
      final state = await bootstrap();
      final incomeCat = state.incomeCategories.isNotEmpty
          ? state.incomeCategories.first.name
          : 'Other';

      await state.addRecurringIncome(
        RecurringIncome(
          description: 'monthly pay',
          amount: Decimal.parse('2000'),
          category: incomeCat,
          accountId: state.currentAccountId,
          dayOfMonth: 1,
          frequency: RecurringFrequency.monthly,
        ),
      );

      final usage = state.getCategoryUsageInRecurring(incomeCat);
      expect(usage['recurringIncome'], 1);
      expect(usage['recurringExpenses'], 0);

      final unused = state.getCategoryUsageInRecurring('NoSuchCategory');
      expect(unused['recurringIncome'], 0);
      expect(unused['recurringExpenses'], 0);
    });
  });

  group('countTransactionsByCategory', () {
    test('counts expenses for type==expense and 0 for an unused category',
        () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(state, category: 'Food', description: 'c1'),
      );
      await state.addExpense(
        makeExpense(state, category: 'Food', description: 'c2'),
      );

      expect(await state.countTransactionsByCategory('Food', 'expense'), 2);
      expect(
        await state.countTransactionsByCategory('DefinitelyUnused', 'expense'),
        0,
      );
    });

    test('counts income for type!=expense', () async {
      final state = await bootstrap();
      final incomeCat = state.incomeCategories.isNotEmpty
          ? state.incomeCategories.first.name
          : 'Salary';
      await state.addIncome(
        makeIncome(state, category: incomeCat, description: 'i1'),
      );

      expect(await state.countTransactionsByCategory(incomeCat, 'income'), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Quick templates — income template routing (only expense path is covered
  // by crud_test / use_template_test).
  // ---------------------------------------------------------------------------

  group('useTemplate (income routing)', () {
    test('income template adds an income row of the right amount/category',
        () async {
      final state = await bootstrap();
      final incomeCat = state.incomeCategories.isNotEmpty
          ? state.incomeCategories.first.name
          : 'Salary';
      await state.addTemplate(
        QuickTemplate(
          name: 'side gig',
          amount: Decimal.parse('42.00'),
          category: incomeCat,
          type: 'income',
          accountId: state.currentAccountId,
        ),
      );
      final template =
          state.quickTemplates.firstWhere((t) => t.name == 'side gig');
      final beforeIncomes = state.incomes.length;
      final beforeExpenses = state.expenses.length;

      await state.useTemplate(template);

      expect(state.incomes.length, beforeIncomes + 1,
          reason: 'income-type template must add an income row');
      expect(state.expenses.length, beforeExpenses,
          reason: 'income template must not create an expense');
      expect(
        state.incomes.any((i) =>
            i.description == 'side gig' &&
            (i.amount - template.amount).abs() < 0.001 &&
            i.category == template.category),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Recurring income — addRecurringIncome + updateRecurringIncome do NOT touch
  // the notification platform (only the expense path schedules reminders), so
  // these round-trips can await directly without the swallow-the-crash dance.
  // ---------------------------------------------------------------------------

  group('recurring income update (no notification path)', () {
    RecurringIncome makeRecurringIncome(
      AppState state, {
      String description = 'salary',
      double amount = 3000,
      int dayOfMonth = 15,
    }) {
      return RecurringIncome(
        description: description,
        amount: Decimal.parse(amount.toString()),
        category: state.incomeCategories.isNotEmpty
            ? state.incomeCategories.first.name
            : 'Other',
        accountId: state.currentAccountId,
        dayOfMonth: dayOfMonth,
        frequency: RecurringFrequency.monthly,
      );
    }

    test('updateRecurringIncome persists a description + day edit', () async {
      final state = await bootstrap();
      await state.addRecurringIncome(makeRecurringIncome(state));
      final original = state.recurringIncomes.first;

      final updated = original.copyWithDecimal(
        description: 'salary-edited',
        dayOfMonth: 20,
      );
      await state.updateRecurringIncome(updated);

      final after =
          state.recurringIncomes.firstWhere((r) => r.id == original.id);
      expect(after.description, 'salary-edited');
      expect(after.dayOfMonth, 20);
    });

    test('toggling isActive off persists', () async {
      final state = await bootstrap();
      await state.addRecurringIncome(makeRecurringIncome(state));
      final original = state.recurringIncomes.first;
      expect(original.isActive, isTrue);

      await state.updateRecurringIncome(
        original.copyWithDecimal(isActive: false),
      );

      final after =
          state.recurringIncomes.firstWhere((r) => r.id == original.id);
      expect(after.isActive, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Tag methods — none of these are covered anywhere else.
  // ---------------------------------------------------------------------------

  group('tag CRUD', () {
    test('addTag persists + appears in tags/allTags with notify', () async {
      final state = await bootstrap();
      final notifies = <void>[];
      state.addListener(() => notifies.add(null));

      await state.addTag('groceries', color: '#00FF00');

      expect(state.tags.any((t) => t['name'] == 'groceries'), isTrue);
      final mapped = state.allTags;
      expect(mapped.any((t) => t.name == 'groceries' && t.color == '#00FF00'),
          isTrue,
          reason: 'allTags must map the raw tag map into a Tag with color');
      expect(notifies, isNotEmpty,
          reason: 'addTag must call notifyListeners');
    });

    test('updateTag edits name + color', () async {
      final state = await bootstrap();
      await state.addTag('old-name', color: '#111111');
      final tagId = state.tags
          .firstWhere((t) => t['name'] == 'old-name')['id'] as int;

      await state.updateTag(tagId, 'new-name', color: '#222222');

      final updated = state.allTags.firstWhere((t) => t.id == tagId);
      expect(updated.name, 'new-name');
      expect(updated.color, '#222222');
      expect(state.tags.any((t) => t['name'] == 'old-name'), isFalse);
    });

    test('deleteTag removes it from the cache', () async {
      final state = await bootstrap();
      await state.addTag('to-delete');
      final tagId = state.tags
          .firstWhere((t) => t['name'] == 'to-delete')['id'] as int;

      await state.deleteTag(tagId);

      expect(state.tags.any((t) => t['id'] == tagId), isFalse);
      expect(state.allTags.any((t) => t.id == tagId), isFalse);
    });

    test('allTags returns one Tag per raw map', () async {
      final state = await bootstrap();
      await state.addTag('a');
      await state.addTag('b');

      expect(state.allTags, hasLength(state.tags.length));
      expect(state.allTags.map((t) => t.name).toSet(), containsAll(['a', 'b']));
    });
  });

  group('tag <-> transaction junction', () {
    test('addTagToTransaction then getTagsForTransaction returns the tag',
        () async {
      final state = await bootstrap();
      final expenseId = await state.addExpense(
        makeExpense(state, description: 'tagged'),
      );
      await state.addTag('important');
      final tagId =
          state.tags.firstWhere((t) => t['name'] == 'important')['id'] as int;

      await state.addTagToTransaction(expenseId, 'expense', tagId);

      final tags = await state.getTagsForTransaction(expenseId, 'expense');
      expect(tags, isA<List<Tag>>());
      expect(tags.any((t) => t.id == tagId && t.name == 'important'), isTrue);
    });

    test('getTagsForTransaction is empty when no tags attached', () async {
      final state = await bootstrap();
      final expenseId = await state.addExpense(
        makeExpense(state, description: 'untagged'),
      );

      final tags = await state.getTagsForTransaction(expenseId, 'expense');
      expect(tags, isEmpty);
    });

    test('removeTagFromTransaction detaches the junction row', () async {
      final state = await bootstrap();
      final expenseId = await state.addExpense(
        makeExpense(state, description: 'detach-me'),
      );
      await state.addTag('temp');
      final tagId =
          state.tags.firstWhere((t) => t['name'] == 'temp')['id'] as int;
      await state.addTagToTransaction(expenseId, 'expense', tagId);
      expect(
        (await state.getTagsForTransaction(expenseId, 'expense')),
        isNotEmpty,
      );

      await state.removeTagFromTransaction(expenseId, 'expense', tagId);

      expect(
        (await state.getTagsForTransaction(expenseId, 'expense')),
        isEmpty,
      );
    });

    test('re-adding the same tag is idempotent (ConflictAlgorithm.ignore)',
        () async {
      final state = await bootstrap();
      final expenseId = await state.addExpense(
        makeExpense(state, description: 'idem'),
      );
      await state.addTag('dup');
      final tagId =
          state.tags.firstWhere((t) => t['name'] == 'dup')['id'] as int;

      await state.addTagToTransaction(expenseId, 'expense', tagId);
      await state.addTagToTransaction(expenseId, 'expense', tagId);

      final tags = await state.getTagsForTransaction(expenseId, 'expense');
      expect(tags.where((t) => t.id == tagId), hasLength(1),
          reason: 're-adding the same tag must not create a duplicate row');
    });
  });
}
