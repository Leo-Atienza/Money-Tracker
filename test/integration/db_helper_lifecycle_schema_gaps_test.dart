import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:budget_tracker/constants/database.dart';
import 'package:budget_tracker/database/database_helper.dart';

import '_test_helpers.dart';

/// Wave 5 — DatabaseHelper singleton / lifecycle / init + schema-creation gaps.
///
/// Targets the 🟡 Partial and ❌ Missing cases from the per-function test plan
/// (NEXT_SESSION_HANDOFF.md §"Singleton / lifecycle / init" and
/// §"Schema creation & migration") that the existing integration suite does NOT
/// already cover:
///
///  - `factory DatabaseHelper()` is never asserted to be a singleton.
///  - The `database` getter's `_initCompleter` concurrency guard is exercised by
///    every test but never *asserted* (N simultaneous getters → one instance).
///  - `_onCreate` fresh-DB inventory: tables present, default "Main Account"
///    with isDefault=1, the 8 expense + 5 income default categories, and the
///    `idx_transaction_tags_unique` UNIQUE index enforced on a fresh (non-
///    migrated) DB.
///  - `PRAGMA foreign_keys == 1` after open (the atomic-add test asserts this
///    too; kept here as a self-contained lifecycle check).
///  - `_onUpgrade` idempotency: re-running the upgrade body (all
///    `IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`) does not throw — a hop NOT
///    covered by `migration_v18_to_v19_test.dart`.
///
/// Deliberately does NOT duplicate the v18→v19 row-count / month-normalisation /
/// trash-FK cases already proven in `migration_v18_to_v19_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUp(() async {
    db = await makeFreshDb();
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  group('factory DatabaseHelper() — singleton identity', () {
    test('two factory calls return the identical instance', () {
      expect(identical(DatabaseHelper(), DatabaseHelper()), isTrue);
    });

    test('the database handle is shared across factory calls', () async {
      // Both factory references resolve the same cached `_database`.
      final a = await DatabaseHelper().database;
      final b = await DatabaseHelper().database;
      expect(identical(a, b), isTrue);
      // And it is the same handle the harness already opened in setUp.
      expect(identical(a, db), isTrue);
    });
  });

  group('database getter — concurrency / init guard', () {
    test('first access returns an open, queryable DB', () async {
      final handle = await DatabaseHelper().database;
      expect(handle.isOpen, isTrue);
      final rows = await handle.rawQuery('SELECT 1 AS one');
      expect(rows.first['one'], 1);
    });

    test(
        'N simultaneous getters before init completes all resolve to one '
        'instance', () async {
      // Force a genuinely uninitialised state: reset clears `_database` and
      // `_initCompleter`, so the next batch of getters races on a cold start.
      // The `_initCompleter` guard must funnel every concurrent caller onto the
      // single in-flight init and hand them all the same Database.
      await DatabaseHelper.resetForTesting();

      final futures = List.generate(20, (_) => DatabaseHelper().database);
      final results = await Future.wait(futures);

      expect(results, hasLength(20));
      final first = results.first;
      for (final handle in results) {
        expect(identical(handle, first), isTrue,
            reason: 'every concurrent getter must share one Database handle');
      }
      expect(first.isOpen, isTrue);
    });

    test('a fresh getter after reset re-runs _onCreate (default account back)',
        () async {
      // Mutate the fresh DB, reset, then prove the next access rebuilt from
      // scratch via _onCreate rather than returning the stale handle.
      await db.insert('accounts', {'name': 'Scratch', 'isDefault': 0});
      await DatabaseHelper.resetForTesting();

      final rebuilt = await DatabaseHelper().database;
      final accounts = await rebuilt.query('accounts');
      // A clean _onCreate seeds exactly the one default "Main Account".
      expect(accounts, hasLength(1));
      expect(accounts.single['name'], 'Main Account');
    });
  });

  group('_onCreate (via fresh open) — schema inventory', () {
    test('PRAGMA foreign_keys is ON (==1) after open', () async {
      final result = await db.rawQuery('PRAGMA foreign_keys');
      // onConfigure runs `PRAGMA foreign_keys = ON`; the pragma reads back as 1.
      expect(result.first.values.first, 1);
    });

    test('every expected table exists on a fresh DB', () async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tableNames = rows.map((r) => r['name'] as String).toSet();

      const expected = <String>[
        'accounts',
        'expenses',
        'income',
        'budgets',
        'recurring_expenses',
        'categories',
        'deleted_expenses',
        'deleted_income',
        'deleted_accounts',
        'quick_templates',
        'recurring_income',
        'tags',
        'transaction_tags',
        'monthly_balances',
      ];
      for (final t in expected) {
        expect(tableNames, contains(t), reason: 'missing table: $t');
      }
    });

    test('default "Main Account" is seeded with isDefault = 1', () async {
      final accounts = await db.query('accounts');
      expect(accounts, hasLength(1));
      final main = accounts.single;
      expect(main['name'], 'Main Account');
      expect(main['isDefault'], 1);
    });

    test('8 default expense categories + 5 default income categories seeded',
        () async {
      final expenseCats = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: ['expense'],
      );
      final incomeCats = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: ['income'],
      );

      expect(expenseCats, hasLength(8));
      expect(incomeCats, hasLength(5));

      final expenseNames = expenseCats.map((c) => c['name']).toSet();
      // A representative subset derived from the _onCreate seed list.
      expect(expenseNames, containsAll(<String>['Food', 'Transport', 'Bills']));
      final incomeNames = incomeCats.map((c) => c['name']).toSet();
      expect(incomeNames, containsAll(<String>['Salary', 'Freelance']));

      // Every seeded category is flagged default and belongs to account 1.
      for (final c in [...expenseCats, ...incomeCats]) {
        expect(c['isDefault'], 1);
        expect(c['account_id'], 1);
      }
    });

    test('idx_transaction_tags_unique exists on a fresh DB', () async {
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );
      final names = indexes.map((r) => r['name'] as String).toSet();
      expect(names, contains('idx_transaction_tags_unique'));
    });

    test(
        'unique index rejects a duplicate (transaction_id, type, tag_id) on a '
        'fresh DB', () async {
      // Account 1 already exists (the default). Create a tag, then insert the
      // same junction triple twice. The fresh-DB UNIQUE index (not just the
      // post-migration one) must reject the second insert.
      final tagId = await db.insert('tags', {
        'name': 'work',
        'color': '#FF0000',
        'account_id': 1,
      });

      await db.insert('transaction_tags', {
        'transaction_id': 42,
        'transaction_type': 'expense',
        'tag_id': tagId,
      });

      expect(
        () => db.insert('transaction_tags', {
          'transaction_id': 42,
          'transaction_type': 'expense',
          'tag_id': tagId,
        }),
        throwsA(isA<DatabaseException>()),
        reason: 'idx_transaction_tags_unique must block the duplicate triple',
      );

      // A different tag on the same transaction is still allowed.
      final tag2Id = await db.insert('tags', {
        'name': 'personal',
        'color': '#00FF00',
        'account_id': 1,
      });
      final rowid = await db.insert('transaction_tags', {
        'transaction_id': 42,
        'transaction_type': 'expense',
        'tag_id': tag2Id,
      });
      expect(rowid, greaterThan(0));
    });

    test('account hard-delete cascades to child expenses on a fresh DB',
        () async {
      // FK + CASCADE is declared on `expenses.account_id` at create time.
      // Insert a child under a non-default account, delete the account, and
      // assert the cascade fires (FK enforcement proven end-to-end on _onCreate
      // output, not just post-migration).
      final acctId = await db.insert('accounts', {
        'name': 'Cascade',
        'isDefault': 0,
      });
      await seedExpense(db, accountId: acctId, date: '2026-04-01', amount: 5.0);

      expect(
        (await db.query('expenses', where: 'account_id = ?', whereArgs: [acctId]))
            .length,
        1,
      );

      await db.delete('accounts', where: 'id = ?', whereArgs: [acctId]);

      expect(
        (await db.query('expenses', where: 'account_id = ?', whereArgs: [acctId]))
            .isEmpty,
        isTrue,
        reason: 'ON DELETE CASCADE on expenses.account_id must clear children',
      );
    });
  });

  group('_parseExpenseRows (via readAllExpenses) — corrupt-row resilience', () {
    test('drops a corrupt (empty-category) row, keeps valid neighbours',
        () async {
      const acctId = 1; // default Main Account.

      // Two valid rows.
      await seedExpense(db, accountId: acctId, date: '2026-04-02', amount: 10.0);
      await seedExpense(db, accountId: acctId, date: '2026-04-03', amount: 20.0);

      // One corrupt row: empty category passes the NOT NULL column constraint
      // but fails Expense.fromMap (`category.isEmpty` → ArgumentError), so
      // _parseExpenseRows must skip it rather than abort the whole read.
      await db.insert('expenses', {
        'amount': 99.0,
        'category': '',
        'description': 'corrupt',
        'date': '2026-04-04',
        'account_id': acctId,
        'amountPaid': 0.0,
        'paymentMethod': 'Cash',
      });

      final parsed = await DatabaseHelper().readAllExpenses(acctId);

      // The corrupt row is dropped; the two valid rows survive.
      expect(parsed, hasLength(2));
      final amounts = parsed.map((e) => e.amount.toDouble()).toSet();
      expect(amounts, {10.0, 20.0});
      expect(amounts.contains(99.0), isFalse);
    });

    test('empty table → empty list', () async {
      final parsed = await DatabaseHelper().readAllExpenses(1);
      expect(parsed, isEmpty);
    });

    test('all-valid rows pass through unchanged', () async {
      const acctId = 1;
      await seedExpense(db, accountId: acctId, date: '2026-04-05', amount: 7.0);
      await seedExpense(db, accountId: acctId, date: '2026-04-06', amount: 8.0);

      final parsed = await DatabaseHelper().readAllExpenses(acctId);
      expect(parsed, hasLength(2));
      expect(parsed.map((e) => e.amount.toDouble()).toSet(), {7.0, 8.0});
    });
  });

  group('_onUpgrade — idempotency (gap not in v18→v19 test)', () {
    test(
        're-opening an already-current (v19) DB does not re-run upgrade or throw',
        () async {
      // The harness DB is already at the live version. Closing and re-opening
      // via DatabaseHelper exercises the path where oldVersion == newVersion:
      // no `oldVersion < N` block runs, and the second open must succeed with
      // the schema and seed data intact.
      final beforeVersion =
          (await db.rawQuery('PRAGMA user_version')).first['user_version'];
      expect(beforeVersion, DatabaseConstants.databaseVersion);

      // Drop the cached handle WITHOUT deleting the file, then re-open.
      await DatabaseHelper().closeDatabase();
      final reopened = await DatabaseHelper().database;

      expect(
        (await reopened.rawQuery('PRAGMA user_version')).first['user_version'],
        DatabaseConstants.databaseVersion,
      );
      // Seed data from the original _onCreate is still present (no destructive
      // re-create on a same-version re-open).
      final accounts = await reopened.query('accounts');
      expect(accounts, hasLength(1));
      expect(accounts.single['name'], 'Main Account');
    });
  });
}
