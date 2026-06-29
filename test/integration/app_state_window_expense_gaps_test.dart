import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/date_helper.dart';

import '_test_helpers.dart';

/// Stage D.1 remainder — gaps in the in-memory 2-month window + Expense
/// mutators that `app_state_crud_test.dart` leaves uncovered.
///
/// Scope (deliberately NON-overlapping with crud_test):
///   * The windowed cache: which months `loadData` / navigation hold in
///     memory, and the invariant that out-of-window rows live on disk but
///     not in `allExpenses`.
///   * `ensureMonthLoaded` dedup / idempotency / concurrency.
///   * `addExpenseRaw` round-trip + validation passthrough.
///   * `undoDelete` (distinct from `restoreDeletedExpense(id)`).
///   * `deleteExpense` edge cases: unknown id, out-of-window id.
///   * `addPayment` boundary (0.10), overpayment cap, multi-payment
///     accumulation, exact-cent recording (Decimal, no float drift).
///   * `getExpensesForSelectedMonth` + the `expenses` getter sort/filter.
///
/// Every test bootstraps a fresh [AppState] on a fresh FFI DB, so each is
/// independent. Expected values are derived from the AppState source, not
/// guessed: the window is keyed off `DateHelper.today()` (current + previous
/// month), `addPayment` records exactly what was tendered and caps at the
/// expense amount, and the `expenses` getter sorts date DESC then id DESC.
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
      date: date ?? DateHelper.today(),
      accountId: state.currentAccountId,
      amountPaid: Decimal.parse(amountPaid.toString()),
      paymentMethod: paymentMethod,
    );
  }

  // A date that is unambiguously OUTSIDE the loaded window (3 months back).
  // The window holds prev-month-start .. current-month-end, so a row keyed
  // to the 15th three months ago is never resident after loadData.
  DateTime threeMonthsBack() {
    final now = DateHelper.today();
    final m = DateHelper.subtractMonths(now, 3);
    return DateHelper.normalize(DateTime.utc(m.year, m.month, 15));
  }

  // A date inside the previous month (still inside the window, but NOT the
  // selected (current) month — used to prove getExpensesForSelectedMonth
  // filters by selectedMonth, not by the whole window).
  DateTime prevMonthMid() {
    final now = DateHelper.today();
    final m = DateHelper.subtractMonths(now, 1);
    return DateHelper.normalize(DateTime.utc(m.year, m.month, 15));
  }

  // -------------------------------------------------------------------------
  // In-memory 2-month window
  // -------------------------------------------------------------------------

  group('2-month window (loadData / _loadExpensesInternal)', () {
    test('after loadData, an out-of-window row is on disk but NOT in cache',
        () async {
      // Seed an out-of-window row directly on disk BEFORE bootstrap so the
      // initial loadData window-load is what excludes it.
      final accountId = await seedAccountForState();
      final db = await DatabaseHelper().database;
      await seedExpense(
        db,
        accountId: accountId,
        date: DateHelper.toDateString(threeMonthsBack()),
        amount: 42.0,
        description: 'ancient',
      );

      final state = await bootstrap();

      // The row exists on disk...
      final onDisk =
          await DatabaseHelper().readAllExpenses(state.currentAccountId);
      expect(
        onDisk.any((e) => e.description == 'ancient'),
        isTrue,
        reason: 'the seeded row must still be persisted',
      );

      // ...but is NOT in the 2-month window cache.
      expect(
        state.allExpenses.any((e) => e.description == 'ancient'),
        isFalse,
        reason: 'rows older than the previous month are excluded from the '
            'in-memory window',
      );
    });

    test('after loadData, a current-month row IS resident in the window',
        () async {
      final state = await bootstrap();
      await state.addExpense(makeExpense(state, description: 'fresh'));

      expect(
        state.allExpenses.any((e) => e.description == 'fresh'),
        isTrue,
        reason: 'current-month rows are always inside the window',
      );
    });

    test('a previous-month row is resident in the window but excluded from '
        'the selected (current) month view', () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(state, description: 'last-month', date: prevMonthMid()),
      );

      // Resident in the unfiltered window cache.
      expect(
        state.allExpenses.any((e) => e.description == 'last-month'),
        isTrue,
        reason: 'previous month is part of the 2-month window',
      );
      // But filtered out of the selected-month view (selectedMonth defaults
      // to the current month).
      expect(
        state.getExpensesForSelectedMonth().any(
              (e) => e.description == 'last-month',
            ),
        isFalse,
        reason: 'getExpensesForSelectedMonth filters to the current month',
      );
    });
  });

  // -------------------------------------------------------------------------
  // ensureMonthLoaded
  // -------------------------------------------------------------------------

  group('ensureMonthLoaded', () {
    test('loading an out-of-window month adds its rows without duplicating '
        'existing ones', () async {
      final state = await bootstrap();
      // Seed a current-month row so the cache is non-empty going in.
      await state.addExpense(makeExpense(state, description: 'current'));
      final beforeCount = state.allExpenses.length;

      // Seed an out-of-window row directly on disk so loadData didn't pull it.
      final db = await DatabaseHelper().database;
      final far = threeMonthsBack();
      await seedExpense(
        db,
        accountId: state.currentAccountId,
        date: DateHelper.toDateString(far),
        amount: 9.0,
        description: 'far-row',
      );

      await state.ensureMonthLoaded(far);

      expect(
        state.allExpenses.any((e) => e.description == 'far-row'),
        isTrue,
        reason: 'ensureMonthLoaded must pull the requested month into cache',
      );
      expect(
        state.allExpenses.any((e) => e.description == 'current'),
        isTrue,
        reason: 'pre-existing rows must survive the load',
      );
      // Exactly one new row entered the cache (the far-row).
      expect(state.allExpenses.length, beforeCount + 1);
    });

    test('is idempotent: a second call for the same month does not duplicate '
        'rows', () async {
      final state = await bootstrap();
      final db = await DatabaseHelper().database;
      final far = threeMonthsBack();
      await seedExpense(
        db,
        accountId: state.currentAccountId,
        date: DateHelper.toDateString(far),
        amount: 5.0,
        description: 'dup-probe',
      );

      await state.ensureMonthLoaded(far);
      final afterFirst = state.allExpenses.length;

      await state.ensureMonthLoaded(far);
      final afterSecond = state.allExpenses.length;

      expect(afterSecond, afterFirst,
          reason: 'the existing-id guard must prevent duplicate inserts');
      expect(
        state.allExpenses.where((e) => e.description == 'dup-probe').length,
        1,
      );
    });

    test('concurrent loads of the same month load its rows exactly once',
        () async {
      final state = await bootstrap();
      final db = await DatabaseHelper().database;
      final far = threeMonthsBack();
      await seedExpense(
        db,
        accountId: state.currentAccountId,
        date: DateHelper.toDateString(far),
        amount: 7.0,
        description: 'race-probe',
      );

      // Fire two concurrent loads; the write-mutex + re-check must serialize
      // them so the row is loaded only once.
      await Future.wait([
        state.ensureMonthLoaded(far),
        state.ensureMonthLoaded(far),
      ]);

      expect(
        state.allExpenses.where((e) => e.description == 'race-probe').length,
        1,
        reason: 'mutex + re-check-under-lock must dedupe concurrent loads',
      );
    });
  });

  // -------------------------------------------------------------------------
  // addExpenseRaw
  // -------------------------------------------------------------------------

  group('addExpenseRaw', () {
    test('round-trips amount/category/description/date/paymentMethod/'
        'amountPaid into a persisted row', () async {
      final state = await bootstrap();
      final date = DateHelper.today();

      final id = await state.addExpenseRaw(
        amount: 33.25,
        category: 'Food',
        description: 'raw-row',
        date: date,
        paymentMethod: 'Card',
        amountPaid: 10.0,
      );

      expect(id, isNonZero);
      final added = state.allExpenses.firstWhere((e) => e.id == id);
      expect(added.amount, closeTo(33.25, 0.001));
      expect(added.category, 'Food');
      expect(added.description, 'raw-row');
      expect(added.paymentMethod, 'Card');
      expect(added.amountPaid, closeTo(10.0, 0.001));
      expect(added.date.year, date.year);
      expect(added.date.month, date.month);
      expect(added.date.day, date.day);

      // And the same values are on disk.
      final onDisk =
          await DatabaseHelper().readAllExpenses(state.currentAccountId);
      final diskRow = onDisk.firstWhere((e) => e.id == id);
      expect(diskRow.amount, closeTo(33.25, 0.001));
      expect(diskRow.amountPaid, closeTo(10.0, 0.001));
      expect(diskRow.paymentMethod, 'Card');
    });

    test('amountPaid passthrough produces the correct isPaid', () async {
      final state = await bootstrap();

      // Fully paid: amountPaid >= amount.
      final paidId = await state.addExpenseRaw(
        amount: 20.0,
        category: 'Food',
        description: 'paid-raw',
        date: DateHelper.today(),
        paymentMethod: 'Cash',
        amountPaid: 20.0,
      );
      // Unpaid: amountPaid < amount.
      final unpaidId = await state.addExpenseRaw(
        amount: 20.0,
        category: 'Food',
        description: 'unpaid-raw',
        date: DateHelper.today(),
        paymentMethod: 'Cash',
        amountPaid: 5.0,
      );

      expect(
        state.allExpenses.firstWhere((e) => e.id == paidId).isPaid,
        isTrue,
      );
      expect(
        state.allExpenses.firstWhere((e) => e.id == unpaidId).isPaid,
        isFalse,
      );
    });

    test('invalid amount (0) bubbles the ArgumentError from addExpense',
        () async {
      final state = await bootstrap();
      expect(
        () => state.addExpenseRaw(
          amount: 0,
          category: 'Food',
          description: 'bad',
          date: DateHelper.today(),
          paymentMethod: 'Cash',
          amountPaid: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  // -------------------------------------------------------------------------
  // undoDelete  (distinct from restoreDeletedExpense(deletedId))
  // -------------------------------------------------------------------------

  group('undoDelete', () {
    test('brings the just-deleted row back into the active list', () async {
      final state = await bootstrap();
      final id = await state.addExpense(
        makeExpense(state, description: 'undo-me'),
      );
      await state.deleteExpense(id);
      expect(state.expenses.any((e) => e.description == 'undo-me'), isFalse);

      await state.undoDelete();

      expect(
        state.expenses.any((e) => e.description == 'undo-me'),
        isTrue,
        reason: 'undoDelete must restore the last-deleted expense',
      );
      // It must also leave the trash table empty for that row.
      final trash = await state.getDeletedExpenses();
      expect(trash.any((row) => row['description'] == 'undo-me'), isFalse);
    });

    test('no prior deletion → no-op, no throw, list unchanged', () async {
      final state = await bootstrap();
      await state.addExpense(makeExpense(state, description: 'survivor'));
      final before = state.allExpenses.length;

      // restoreLastDeleted is a no-op when the trash is empty.
      await state.undoDelete();

      expect(state.allExpenses.length, before);
      expect(
        state.expenses.any((e) => e.description == 'survivor'),
        isTrue,
      );
    });

    test('restores the MOST RECENT deletion when several were deleted',
        () async {
      final state = await bootstrap();
      final firstId =
          await state.addExpense(makeExpense(state, description: 'first'));
      final secondId =
          await state.addExpense(makeExpense(state, description: 'second'));

      // Delete first, then second — "second" is the most recent deletion.
      await state.deleteExpense(firstId);
      await state.deleteExpense(secondId);

      await state.undoDelete();

      expect(
        state.expenses.any((e) => e.description == 'second'),
        isTrue,
        reason: 'the most-recently deleted row (deletedAt DESC) restores first',
      );
      expect(
        state.expenses.any((e) => e.description == 'first'),
        isFalse,
        reason: 'the earlier deletion stays in the trash',
      );
    });
  });

  // -------------------------------------------------------------------------
  // deleteExpense edge cases
  // -------------------------------------------------------------------------

  group('deleteExpense edge cases', () {
    test('unknown id → early return, no throw, state unchanged', () async {
      final state = await bootstrap();
      await state.addExpense(makeExpense(state, description: 'keep'));
      final before = state.allExpenses.length;

      // 999999 is not a real row — moveToDeletedById returns null → return.
      await state.deleteExpense(999999);

      expect(state.allExpenses.length, before);
      expect(state.expenses.any((e) => e.description == 'keep'), isTrue);
    });

    test('deleting an out-of-window row works via moveToDeletedById',
        () async {
      final state = await bootstrap();
      // Seed an out-of-window row on disk (not in the in-memory cache).
      final db = await DatabaseHelper().database;
      final far = threeMonthsBack();
      final farId = await seedExpense(
        db,
        accountId: state.currentAccountId,
        date: DateHelper.toDateString(far),
        amount: 12.0,
        description: 'out-of-window-delete',
      );
      // Confirm it is genuinely not in the cache (so we exercise the
      // moveToDeletedById branch, not the in-cache branch).
      expect(
        state.allExpenses.any((e) => e.id == farId),
        isFalse,
        reason: 'precondition: the row must be outside the loaded window',
      );

      await state.deleteExpense(farId);

      // It is gone from disk's active table and now in the trash.
      final onDisk =
          await DatabaseHelper().readAllExpenses(state.currentAccountId);
      expect(onDisk.any((e) => e.id == farId), isFalse);
      final trash = await state.getDeletedExpenses();
      expect(
        trash.any((row) => row['description'] == 'out-of-window-delete'),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  // addPayment — boundary / cap / accumulation / exact-cent (the M1 surface)
  // -------------------------------------------------------------------------

  group('addPayment gaps', () {
    test('M1 boundary: a payment leaving exactly 0.10 remaining does NOT '
        'mark paid', () async {
      final state = await bootstrap();
      final id = await state.addExpense(makeExpense(state, amount: 100));
      final expense = state.expenses.firstWhere((e) => e.id == id);

      await state.addPayment(expense, 99.90); // 0.10 remaining

      final after = state.expenses.firstWhere((e) => e.id == id);
      expect(after.isPaid, isFalse,
          reason: 'the cap is `newPaid >= amount`; 99.90 < 100 stays unpaid');
      expect(after.amountPaid, closeTo(99.90, 0.001));
      expect(after.remainingAmount, closeTo(0.10, 0.001));
    });

    test('M1: a payment leaving 0.05 remaining records EXACTLY 0.05 short '
        'and stays unpaid', () async {
      final state = await bootstrap();
      final id = await state.addExpense(makeExpense(state, amount: 100));
      final expense = state.expenses.firstWhere((e) => e.id == id);

      // Post-M1, addPayment records exactly what was tendered (99.95) instead
      // of fabricating the last 5c. The expense stays unpaid.
      await state.addPayment(expense, 99.95);

      final after = state.expenses.firstWhere((e) => e.id == id);
      expect(after.isPaid, isFalse,
          reason: 'M1: a 5c shortfall must NOT auto-round to paid');
      expect(after.amountPaid, closeTo(99.95, 0.001),
          reason: 'records exactly the tendered sum, no fabricated cents');
      expect(after.remainingAmount, closeTo(0.05, 0.001));
    });

    test('overpayment caps amountPaid at the expense amount (no negative '
        'remaining)', () async {
      final state = await bootstrap();
      final id = await state.addExpense(makeExpense(state, amount: 40));
      final expense = state.expenses.firstWhere((e) => e.id == id);

      await state.addPayment(expense, 100); // wildly over

      final after = state.expenses.firstWhere((e) => e.id == id);
      expect(after.isPaid, isTrue);
      expect(after.amountPaid, closeTo(40, 0.001),
          reason: 'overpayment is capped at the expense amount');
      expect(after.remainingAmount, closeTo(0, 0.001));
    });

    test('multiple sequential partial payments accumulate to fully paid '
        '(0.33 + 0.33 + 0.34 on a 1.00 expense)', () async {
      final state = await bootstrap();
      final id = await state.addExpense(makeExpense(state, amount: 1.00));

      // Re-read the freshest expense before each payment — addPayment reloads
      // the window, so the cached instance's amountPaid is stale afterward.
      var expense = state.expenses.firstWhere((e) => e.id == id);
      await state.addPayment(expense, 0.33);
      expense = state.expenses.firstWhere((e) => e.id == id);
      expect(expense.isPaid, isFalse);
      expect(expense.amountPaid, closeTo(0.33, 0.001));

      await state.addPayment(expense, 0.33);
      expense = state.expenses.firstWhere((e) => e.id == id);
      expect(expense.isPaid, isFalse);
      expect(expense.amountPaid, closeTo(0.66, 0.001));

      await state.addPayment(expense, 0.34);
      expense = state.expenses.firstWhere((e) => e.id == id);
      expect(expense.isPaid, isTrue,
          reason: '0.33 + 0.33 + 0.34 == 1.00 exactly (Decimal, no drift)');
      expect(expense.amountPaid, closeTo(1.00, 0.001));
    });

    test('a partial payment >10c short keeps the row unpaid with exact '
        'remaining', () async {
      final state = await bootstrap();
      final id = await state.addExpense(makeExpense(state, amount: 50));
      final expense = state.expenses.firstWhere((e) => e.id == id);

      await state.addPayment(expense, 20); // 30 remaining

      final after = state.expenses.firstWhere((e) => e.id == id);
      expect(after.isPaid, isFalse);
      expect(after.amountPaid, closeTo(20, 0.001));
      expect(after.remainingAmount, closeTo(30, 0.001));
    });

    test('fires notifyListeners', () async {
      final state = await bootstrap();
      final id = await state.addExpense(makeExpense(state, amount: 10));
      final expense = state.expenses.firstWhere((e) => e.id == id);

      var notifies = 0;
      state.addListener(() => notifies++);

      await state.addPayment(expense, 5);

      expect(notifies, greaterThan(0),
          reason: 'addPayment must notify listeners after persisting');
    });
  });

  // -------------------------------------------------------------------------
  // getExpensesForSelectedMonth + expenses getter (sort/filter)
  // -------------------------------------------------------------------------

  group('getExpensesForSelectedMonth', () {
    test('returns only current-month rows, excluding previous-month rows',
        () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(state, description: 'this-month'),
      );
      await state.addExpense(
        makeExpense(state, description: 'prev-month', date: prevMonthMid()),
      );

      final selected = state.getExpensesForSelectedMonth();
      expect(selected.any((e) => e.description == 'this-month'), isTrue);
      expect(selected.any((e) => e.description == 'prev-month'), isFalse);
    });

    test('returns an empty list when no rows fall in the selected month',
        () async {
      final state = await bootstrap();
      // Only seed a previous-month row; current month has nothing.
      await state.addExpense(
        makeExpense(state, description: 'only-prev', date: prevMonthMid()),
      );

      expect(state.getExpensesForSelectedMonth(), isEmpty);
    });
  });

  group('expenses getter (sort + filter)', () {
    test('same-date rows are ordered by id descending (newest first)',
        () async {
      final state = await bootstrap();
      final today = DateHelper.today();
      final firstId = await state.addExpense(
        makeExpense(state, description: 'older-id', date: today),
      );
      final secondId = await state.addExpense(
        makeExpense(state, description: 'newer-id', date: today),
      );
      expect(secondId, greaterThan(firstId));

      final list = state.expenses;
      final firstIdx = list.indexWhere((e) => e.id == secondId);
      final secondIdx = list.indexWhere((e) => e.id == firstId);
      expect(firstIdx, lessThan(secondIdx),
          reason: 'for the same date, higher id sorts first (date DESC, id DESC)');
    });

    test('rows are ordered by date descending', () async {
      final state = await bootstrap();
      final now = DateHelper.today();
      // Two distinct days within the current month: pick day 5 and day 6 only
      // if they are not in the future; otherwise use two earlier in-month days.
      final earlier = DateHelper.normalize(DateTime.utc(now.year, now.month, 1));
      final later = now.day >= 2
          ? DateHelper.normalize(DateTime.utc(now.year, now.month, 2))
          : now; // fallback: at minimum the 1st vs today

      await state.addExpense(
        makeExpense(state, description: 'earlier-day', date: earlier),
      );
      await state.addExpense(
        makeExpense(state, description: 'later-day', date: later),
      );

      final list = state.expenses;
      // Only assert ordering if the two dates actually differ.
      if (earlier != later) {
        final laterIdx = list.indexWhere((e) => e.description == 'later-day');
        final earlierIdx =
            list.indexWhere((e) => e.description == 'earlier-day');
        expect(laterIdx, lessThan(earlierIdx),
            reason: 'newer date sorts before older date');
      } else {
        // Degenerate calendar position — at least confirm both are present.
        expect(list.any((e) => e.description == 'later-day'), isTrue);
        expect(list.any((e) => e.description == 'earlier-day'), isTrue);
      }
    });

    test('category filter narrows the returned list', () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(state, category: 'Food', description: 'food-row'),
      );
      // Use a second expense-type category if one exists; otherwise reuse Food
      // and assert the filter still includes the matching row.
      final otherCat = state.expenseCategories
          .map((c) => c.name)
          .firstWhere((n) => n != 'Food', orElse: () => 'Food');
      await state.addExpense(
        makeExpense(state, category: otherCat, description: 'other-row'),
      );

      state.setFilterCategory('Food');
      final filtered = state.expenses;
      expect(filtered.every((e) => e.category == 'Food'), isTrue);
      expect(filtered.any((e) => e.description == 'food-row'), isTrue);
      if (otherCat != 'Food') {
        expect(filtered.any((e) => e.description == 'other-row'), isFalse);
      }

      state.clearFilters();
      expect(
        state.expenses.any((e) => e.description == 'other-row'),
        isTrue,
        reason: 'clearFilters restores the unfiltered list',
      );
    });

    test('min/max amount filter is inclusive of the bounds', () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(state, amount: 10, description: 'ten'),
      );
      await state.addExpense(
        makeExpense(state, amount: 50, description: 'fifty'),
      );
      await state.addExpense(
        makeExpense(state, amount: 90, description: 'ninety'),
      );

      // [10, 50] inclusive → ten + fifty, not ninety.
      state.setAmountRange(10, 50);
      final filtered = state.expenses;
      expect(filtered.any((e) => e.description == 'ten'), isTrue,
          reason: 'min bound is inclusive');
      expect(filtered.any((e) => e.description == 'fifty'), isTrue,
          reason: 'max bound is inclusive');
      expect(filtered.any((e) => e.description == 'ninety'), isFalse);
    });

    test('paid-status filter narrows to paid / unpaid', () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(state, amount: 20, amountPaid: 20, description: 'is-paid'),
      );
      await state.addExpense(
        makeExpense(state, amount: 20, amountPaid: 0, description: 'is-unpaid'),
      );

      state.setPaidStatusFilter(true);
      expect(state.expenses.every((e) => e.isPaid), isTrue);
      expect(state.expenses.any((e) => e.description == 'is-paid'), isTrue);
      expect(state.expenses.any((e) => e.description == 'is-unpaid'), isFalse);

      state.setPaidStatusFilter(false);
      expect(state.expenses.every((e) => !e.isPaid), isTrue);
      expect(state.expenses.any((e) => e.description == 'is-unpaid'), isTrue);
    });

    test('editing an expense amount (same count) refreshes the cached list',
        () async {
      final state = await bootstrap();
      final id = await state.addExpense(
        makeExpense(state, amount: 25, description: 'editable'),
      );
      // Prime the cache.
      final firstRead = state.expenses;
      expect(
        firstRead.firstWhere((e) => e.id == id).amount,
        closeTo(25, 0.001),
      );

      final original = state.allExpenses.firstWhere((e) => e.id == id);
      await state.updateExpense(
        Expense(
          id: id,
          amount: Decimal.parse('99.00'),
          category: original.category,
          description: original.description,
          date: original.date,
          accountId: original.accountId,
          amountPaid: original.amountPaidDecimal,
          paymentMethod: original.paymentMethod,
        ),
      );

      // The content-hash must catch the amount change even though the row
      // count is unchanged.
      expect(
        state.expenses.firstWhere((e) => e.id == id).amount,
        closeTo(99.0, 0.001),
        reason: 'the cache hash includes amount, so an edit refreshes the list',
      );
    });
  });
}

/// Seed a default account directly so an out-of-window row can be inserted
/// against a known account id BEFORE the AppState bootstrap runs its first
/// loadData. AppState uses `currentAccountId == 1` until an account is loaded,
/// and the bootstrap auto-creates the default account with id 1, so seeding
/// the account here keeps the FK satisfied and the ids aligned.
Future<int> seedAccountForState() async {
  final db = await DatabaseHelper().database;
  // If the default account already exists (id 1), reuse it.
  final existing = await db.query('accounts', limit: 1);
  if (existing.isNotEmpty) {
    return existing.first['id'] as int;
  }
  return seedAccount(db);
}
