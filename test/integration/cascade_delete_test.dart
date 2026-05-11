import 'package:budget_tracker/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';

import '_test_helpers.dart';

/// Read the `COUNT(*)` column from a `SELECT COUNT(*)…` query without
/// pulling in `package:sqflite`'s static helpers (the FFI test backend
/// doesn't re-export them).
Future<int> _count(dynamic db, String sql, List<Object?> args) async {
  final rows = await db.rawQuery(sql, args);
  final first = rows.isEmpty ? null : rows.first.values.first;
  return (first as int?) ?? 0;
}

/// Phase 7.5 (NEXT_STEPS D.5) — cascade-delete integration coverage.
///
/// Pins three behaviours that Phase 4 (schema v19) introduced:
///
/// 1. Soft-deleting a transaction must scrub its `transaction_tags`
///    rows BEFORE the live row is moved to the trash table. The trash
///    table itself doesn't carry tags, so leaving them behind would
///    orphan rows in `transaction_tags`.
///
/// 2. Hard-deleting a live transaction (no trash hop — happens when
///    bulk-clear runs or when restoring an account hard-deletes leftover
///    rows) must fire the `trg_transaction_tags_cleanup_expense` /
///    `_income` triggers and remove the tag links.
///
/// 3. `emptyTrash` truly removes the rows from the trash tables. The
///    trash table itself doesn't link to `transaction_tags` so there's
///    no junction cleanup at that step — but the count must drop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  Future<int> seedTag(dynamic db, String name, int accountId) async {
    return db.insert('tags', {
      'name': name,
      'color': '#FF0000',
      'account_id': accountId,
    });
  }

  Future<void> seedTransactionTag(
    dynamic db, {
    required int transactionId,
    required String transactionType,
    required int tagId,
  }) async {
    await db.insert('transaction_tags', {
      'transaction_id': transactionId,
      'transaction_type': transactionType,
      'tag_id': tagId,
    });
  }

  Future<int> countTransactionTagsFor(
    dynamic db, {
    required int transactionId,
    required String transactionType,
  }) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM transaction_tags WHERE transaction_id = ? AND transaction_type = ?',
      [transactionId, transactionType],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  test('moveToDeletedById scrubs transaction_tags before moving the row', () async {
    final db = await makeFreshDb();
    final accountId = await seedAccount(db);
    final expenseId = await seedExpense(
      db,
      accountId: accountId,
      date: '2026-05-15',
      amount: 12.34,
    );
    final tagA = await seedTag(db, 'tag-A', accountId);
    final tagB = await seedTag(db, 'tag-B', accountId);
    await seedTransactionTag(
      db,
      transactionId: expenseId,
      transactionType: 'expense',
      tagId: tagA,
    );
    await seedTransactionTag(
      db,
      transactionId: expenseId,
      transactionType: 'expense',
      tagId: tagB,
    );
    expect(
      await countTransactionTagsFor(
        db,
        transactionId: expenseId,
        transactionType: 'expense',
      ),
      2,
    );

    await DatabaseHelper().moveToDeletedById(expenseId);

    // Live row gone.
    final liveRows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
    );
    expect(liveRows, isEmpty);

    // Trash row present.
    final trashRows = await db.query(
      'deleted_expenses',
      where: 'original_id = ?',
      whereArgs: [expenseId],
    );
    expect(trashRows, hasLength(1));

    // Tags cleaned (Phase 4.5).
    expect(
      await countTransactionTagsFor(
        db,
        transactionId: expenseId,
        transactionType: 'expense',
      ),
      0,
    );

    // Tags themselves are NOT deleted — they're shared across rows.
    final tagRows = await db.query('tags');
    expect(tagRows, hasLength(2));
  });

  test('moveIncomeToDeletedById scrubs transaction_tags before moving the row', () async {
    final db = await makeFreshDb();
    final accountId = await seedAccount(db);
    final incomeId = await seedIncome(
      db,
      accountId: accountId,
      date: '2026-05-20',
      amount: 500.0,
    );
    final tagId = await seedTag(db, 'salary', accountId);
    await seedTransactionTag(
      db,
      transactionId: incomeId,
      transactionType: 'income',
      tagId: tagId,
    );

    await DatabaseHelper().moveIncomeToDeletedById(incomeId);

    final liveRows = await db.query(
      'income',
      where: 'id = ?',
      whereArgs: [incomeId],
    );
    expect(liveRows, isEmpty);

    final trashRows = await db.query(
      'deleted_income',
      where: 'original_id = ?',
      whereArgs: [incomeId],
    );
    expect(trashRows, hasLength(1));

    expect(
      await countTransactionTagsFor(
        db,
        transactionId: incomeId,
        transactionType: 'income',
      ),
      0,
    );
  });

  test('hard-deleting a live expense fires trg_transaction_tags_cleanup_expense', () async {
    // Phase 4.4 — the trigger exists to catch hard deletes that bypass
    // the soft-delete path. We exercise it here by running a raw DELETE
    // against `expenses` and asserting the junction row is gone.
    final db = await makeFreshDb();
    final accountId = await seedAccount(db);
    final expenseId = await seedExpense(
      db,
      accountId: accountId,
      date: '2026-05-15',
    );
    final tagId = await seedTag(db, 'misc', accountId);
    await seedTransactionTag(
      db,
      transactionId: expenseId,
      transactionType: 'expense',
      tagId: tagId,
    );

    await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);

    expect(
      await countTransactionTagsFor(
        db,
        transactionId: expenseId,
        transactionType: 'expense',
      ),
      0,
    );
  });

  test('hard-deleting a live income fires trg_transaction_tags_cleanup_income', () async {
    final db = await makeFreshDb();
    final accountId = await seedAccount(db);
    final incomeId = await seedIncome(
      db,
      accountId: accountId,
      date: '2026-05-15',
    );
    final tagId = await seedTag(db, 'misc', accountId);
    await seedTransactionTag(
      db,
      transactionId: incomeId,
      transactionType: 'income',
      tagId: tagId,
    );

    await db.delete('income', where: 'id = ?', whereArgs: [incomeId]);

    expect(
      await countTransactionTagsFor(
        db,
        transactionId: incomeId,
        transactionType: 'income',
      ),
      0,
    );
  });

  test('emptyTrash removes trash rows for the target account', () async {
    final db = await makeFreshDb();
    final accountId = await seedAccount(db);
    final otherAccountId = await seedAccount(
      db,
      name: 'Other',
      icon: '🎒',
      isDefault: 0,
    );

    // Seed three expenses + two incomes — soft-delete them all.
    for (var i = 0; i < 3; i++) {
      final id = await seedExpense(
        db,
        accountId: accountId,
        date: '2026-05-1${i + 1}',
        amount: 10.0 * (i + 1),
      );
      await DatabaseHelper().moveToDeletedById(id);
    }
    for (var i = 0; i < 2; i++) {
      final id = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-05-1${i + 1}',
        amount: 100.0 * (i + 1),
      );
      await DatabaseHelper().moveIncomeToDeletedById(id);
    }
    // One soft-deleted expense on the OTHER account — emptyTrash must
    // leave it alone (account-scoped).
    final otherExpenseId = await seedExpense(
      db,
      accountId: otherAccountId,
      date: '2026-05-15',
    );
    await DatabaseHelper().moveToDeletedById(otherExpenseId);

    expect(
      await _count(
        db,
        'SELECT COUNT(*) FROM deleted_expenses WHERE account_id = ?',
        [accountId],
      ),
      3,
    );
    expect(
      await _count(
        db,
        'SELECT COUNT(*) FROM deleted_income WHERE account_id = ?',
        [accountId],
      ),
      2,
    );

    await DatabaseHelper().emptyTrash(accountId);

    expect(
      await _count(
        db,
        'SELECT COUNT(*) FROM deleted_expenses WHERE account_id = ?',
        [accountId],
      ),
      0,
    );
    expect(
      await _count(
        db,
        'SELECT COUNT(*) FROM deleted_income WHERE account_id = ?',
        [accountId],
      ),
      0,
    );

    // Other account's trash row is untouched.
    expect(
      await _count(
        db,
        'SELECT COUNT(*) FROM deleted_expenses WHERE account_id = ?',
        [otherAccountId],
      ),
      1,
    );
  });
}
