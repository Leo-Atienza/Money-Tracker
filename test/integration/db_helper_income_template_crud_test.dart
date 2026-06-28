import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/models/quick_template_model.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '_test_helpers.dart';

/// Integration coverage for the Income CRUD + Quick Template CRUD gaps
/// flagged in `docs/NEXT_SESSION_HANDOFF.md` (lines 2312–2329).
///
/// These drive the real [DatabaseHelper] against a file-backed SQLite DB
/// via `sqflite_common_ffi`. Each test gets a fresh DB through `makeFreshDb`
/// (see `_test_helpers.dart`), so every case is independent.
///
/// Targeted methods (only 🟡 Partial / ❌ Missing from the slice):
///   - createIncome  (🟡)  — round-trip, FK violation, double fidelity
///   - readAllIncome (🟡)  — account scope, date-DESC, corrupt-row drop, empty
///   - updateIncome  (❌)  — updates by id, rows-affected, missing-id no-op
///   - deleteIncome  (🟡)  — removes row + tag links, missing-id → 0
///   - moveIncomeToDeleted (🟡, object variant) — trash round-trip, tag scrub,
///                            UTC deletedAt, rollback on failure
///   - createTemplate / readAllTemplates / updateTemplate / deleteTemplate (❌)
///
/// Money note: amounts persist as REAL doubles but models carry `Decimal`.
/// We build `Decimal` via `Decimal.parse('25.00')` and compare on the
/// `double` getter (`.amount`) for round-trips.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late int accountId;

  setUp(() async {
    db = await makeFreshDb();
    accountId = await seedAccount(db);
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  // Helper: count transaction_tags rows for a given transaction.
  Future<int> tagLinkCount(int transactionId, String type) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transaction_tags '
      'WHERE transaction_id = ? AND transaction_type = ?',
      [transactionId, type],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // Helper: insert a tag and return its id.
  Future<int> seedTag(String name, int acct) async {
    return db.insert('tags', {
      'name': name,
      'color': '#00FF00',
      'account_id': acct,
    });
  }

  // Helper: link a transaction to a tag.
  Future<void> seedTransactionTag(
    int transactionId,
    String type,
    int tagId,
  ) async {
    await db.insert('transaction_tags', {
      'transaction_id': transactionId,
      'transaction_type': type,
      'tag_id': tagId,
    });
  }

  // Helper: count rows in a table.
  Future<int> rowCount(String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (rows.first['c'] as int?) ?? 0;
  }

  group('createIncome', () {
    test('round-trips via readAllIncome (fields preserved)', () async {
      final income = Income(
        amount: Decimal.parse('1234.56'),
        category: 'Salary',
        description: 'June paycheck',
        date: DateTime(2026, 6, 15),
        accountId: accountId,
      );

      final id = await DatabaseHelper().createIncome(income);
      expect(id, greaterThan(0));

      final all = await DatabaseHelper().readAllIncome(accountId);
      expect(all.length, 1);
      final read = all.first;
      expect(read.id, id);
      expect(read.category, 'Salary');
      expect(read.description, 'June paycheck');
      expect(read.accountId, accountId);
      // Amount persisted as REAL double; compare on the double getter.
      expect(read.amount, 1234.56);
      // Date stored as 'yyyy-MM-dd' string → parsed back to a DateTime.
      expect(read.date.year, 2026);
      expect(read.date.month, 6);
      expect(read.date.day, 15);
    });

    test('FK violation on a non-existent account_id throws', () async {
      final badIncome = Income(
        amount: Decimal.parse('10.00'),
        category: 'Salary',
        description: 'orphan',
        date: DateTime(2026, 6, 1),
        accountId: 999999, // no such account
      );

      // Conservative: assert *that* it throws, not the exact exception class
      // (the FFI backend's FK-violation type isn't worth pinning here).
      Object? thrown;
      try {
        await DatabaseHelper().createIncome(badIncome);
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull,
          reason: 'A bad account_id FK should abort the insert.');
      expect(await rowCount('income'), 0);
    });

    test('preserves double fidelity for a fractional amount', () async {
      final income = Income(
        amount: Decimal.parse('0.10'),
        category: 'Interest',
        description: 'tiny',
        date: DateTime(2026, 6, 2),
        accountId: accountId,
      );

      await DatabaseHelper().createIncome(income);

      final all = await DatabaseHelper().readAllIncome(accountId);
      expect(all.single.amount, 0.10);
    });
  });

  group('readAllIncome', () {
    test('returns only the queried account\'s rows', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedIncome(db, accountId: accountId, date: '2026-06-01', amount: 1.0);
      await seedIncome(db, accountId: accountId, date: '2026-06-02', amount: 2.0);
      await seedIncome(db, accountId: other, date: '2026-06-03', amount: 99.0);

      final mine = await DatabaseHelper().readAllIncome(accountId);
      expect(mine.length, 2);
      expect(mine.every((i) => i.accountId == accountId), isTrue);

      final theirs = await DatabaseHelper().readAllIncome(other);
      expect(theirs.length, 1);
      expect(theirs.single.amount, 99.0);
    });

    test('orders rows by date DESC', () async {
      await seedIncome(db, accountId: accountId, date: '2026-06-01', amount: 1.0);
      await seedIncome(db, accountId: accountId, date: '2026-06-10', amount: 10.0);
      await seedIncome(db, accountId: accountId, date: '2026-06-05', amount: 5.0);

      final rows = await DatabaseHelper().readAllIncome(accountId);
      final dates = rows.map((i) => i.date).toList();
      // Newest first.
      expect(dates.first.day, 10);
      expect(dates.last.day, 1);
      // Strictly descending.
      for (var i = 0; i < dates.length - 1; i++) {
        expect(
          dates[i].isAfter(dates[i + 1]) ||
              dates[i].isAtSameMomentAs(dates[i + 1]),
          isTrue,
        );
      }
    });

    test('drops a corrupt row (missing category) but keeps valid ones',
        () async {
      // Valid row through the seed helper.
      await seedIncome(db, accountId: accountId, date: '2026-06-01', amount: 5.0);
      // Corrupt row: category is empty → Income.fromMap throws ArgumentError,
      // tryFromMap returns null, _parseIncomeRows drops it. Insert raw so we
      // bypass model validation. (NOT NULL on category means empty-string,
      // which fromMap also rejects.)
      await db.insert('income', {
        'amount': 7.0,
        'category': '', // empty → rejected by Income.fromMap
        'description': 'corrupt',
        'date': '2026-06-02',
        'account_id': accountId,
      });

      final rows = await DatabaseHelper().readAllIncome(accountId);
      // Only the valid row survives the parse.
      expect(rows.length, 1);
      expect(rows.single.amount, 5.0);
    });

    test('returns an empty list for an account with no income', () async {
      final empty = await seedAccount(db, name: 'Empty', isDefault: 0);
      final rows = await DatabaseHelper().readAllIncome(empty);
      expect(rows, isEmpty);
    });
  });

  group('updateIncome', () {
    test('updates fields by id and returns rows-affected = 1', () async {
      final id = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-01',
        amount: 100.0,
        category: 'Salary',
        description: 'before',
      );

      final updated = Income(
        id: id,
        amount: Decimal.parse('250.00'),
        category: 'Bonus',
        description: 'after',
        date: DateTime(2026, 6, 20),
        accountId: accountId,
      );

      final affected = await DatabaseHelper().updateIncome(updated);
      expect(affected, 1);

      final rows = await DatabaseHelper().readAllIncome(accountId);
      expect(rows.length, 1);
      final read = rows.single;
      expect(read.id, id);
      expect(read.category, 'Bonus');
      expect(read.description, 'after');
      expect(read.amount, 250.0);
      expect(read.date.day, 20);
    });

    test('returns 0 rows-affected for a missing id (no-op)', () async {
      // No income rows exist; id 424242 matches nothing.
      final ghost = Income(
        id: 424242,
        amount: Decimal.parse('1.00'),
        category: 'Ghost',
        description: 'nope',
        date: DateTime(2026, 6, 1),
        accountId: accountId,
      );

      final affected = await DatabaseHelper().updateIncome(ghost);
      expect(affected, 0);
      // Table stays empty.
      expect(await rowCount('income'), 0);
    });

    test('does not touch sibling rows when updating one id', () async {
      final keepId = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-01',
        amount: 11.0,
        category: 'Keep',
      );
      final editId = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-02',
        amount: 22.0,
        category: 'Edit',
      );

      final edited = Income(
        id: editId,
        amount: Decimal.parse('99.00'),
        category: 'Edited',
        description: '',
        date: DateTime(2026, 6, 2),
        accountId: accountId,
      );
      final affected = await DatabaseHelper().updateIncome(edited);
      expect(affected, 1);

      final rows = await DatabaseHelper().readAllIncome(accountId);
      final keep = rows.firstWhere((i) => i.id == keepId);
      final edit = rows.firstWhere((i) => i.id == editId);
      expect(keep.category, 'Keep');
      expect(keep.amount, 11.0);
      expect(edit.category, 'Edited');
      expect(edit.amount, 99.0);
    });
  });

  group('deleteIncome', () {
    test('removes the income row and returns 1', () async {
      final id = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-01',
        amount: 50.0,
      );
      expect(await rowCount('income'), 1);

      final affected = await DatabaseHelper().deleteIncome(id);
      expect(affected, 1);
      expect(await rowCount('income'), 0);
    });

    test('scrubs this income\'s transaction_tags links', () async {
      final id = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-01',
        amount: 50.0,
      );
      final tagA = await seedTag('tagA', accountId);
      final tagB = await seedTag('tagB', accountId);
      await seedTransactionTag(id, 'income', tagA);
      await seedTransactionTag(id, 'income', tagB);
      expect(await tagLinkCount(id, 'income'), 2);

      await DatabaseHelper().deleteIncome(id);

      expect(await tagLinkCount(id, 'income'), 0);
      // The tags themselves still exist (only the junction links were scrubbed).
      expect(await rowCount('tags'), 2);
    });

    test('does not scrub another transaction\'s tag links', () async {
      final target = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-01',
        amount: 50.0,
      );
      final keep = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-02',
        amount: 60.0,
      );
      final tag = await seedTag('shared', accountId);
      await seedTransactionTag(target, 'income', tag);
      await seedTransactionTag(keep, 'income', tag);

      await DatabaseHelper().deleteIncome(target);

      expect(await tagLinkCount(target, 'income'), 0);
      expect(await tagLinkCount(keep, 'income'), 1);
    });

    test('returns 0 for a missing id', () async {
      final affected = await DatabaseHelper().deleteIncome(987654);
      expect(affected, 0);
    });
  });

  group('moveIncomeToDeleted (object variant)', () {
    test('moves the live row into deleted_income and scrubs tags', () async {
      final id = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-07',
        amount: 321.0,
        category: 'Freelance',
        description: 'gig',
      );
      final tag = await seedTag('work', accountId);
      await seedTransactionTag(id, 'income', tag);
      expect(await tagLinkCount(id, 'income'), 1);

      // Read the live row back as an Income to pass to the object variant.
      final live = (await DatabaseHelper().readAllIncome(accountId)).single;
      await DatabaseHelper().moveIncomeToDeleted(live);

      // Live row gone, tags scrubbed.
      expect(await rowCount('income'), 0);
      expect(await tagLinkCount(id, 'income'), 0);

      // Trash row created with the original id + preserved fields.
      final trash = await db.query('deleted_income');
      expect(trash.length, 1);
      final t = trash.single;
      expect(t['original_id'], id);
      expect((t['amount'] as num).toDouble(), 321.0);
      expect(t['category'], 'Freelance');
      expect(t['description'], 'gig');
      expect(t['account_id'], accountId);
      expect(t['date'], '2026-06-07');
    });

    test('writes deletedAt as a UTC ISO-8601 timestamp', () async {
      final id = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-07',
        amount: 5.0,
      );
      final live = (await DatabaseHelper().readAllIncome(accountId)).single;
      await DatabaseHelper().moveIncomeToDeleted(live);

      final trash = await db.query('deleted_income', where: 'original_id = ?', whereArgs: [id]);
      final deletedAt = trash.single['deletedAt'] as String;
      // UTC ISO-8601 ends with 'Z' and parses to a real DateTime in UTC.
      expect(deletedAt.endsWith('Z'), isTrue);
      final parsed = DateTime.parse(deletedAt);
      expect(parsed.isUtc, isTrue);
    });

    test('rolls back the whole move when the trash insert fails', () async {
      // Force the transaction to fail: an Income with a non-existent account_id
      // makes the `deleted_income` insert violate the account_id FK, so the
      // transaction aborts and the live `income` row must survive untouched.
      final id = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-06-07',
        amount: 42.0,
      );
      final tag = await seedTag('t', accountId);
      await seedTransactionTag(id, 'income', tag);

      // Build an Income whose accountId points nowhere → FK failure on the
      // deleted_income insert inside the txn.
      final poisoned = Income(
        id: id,
        amount: Decimal.parse('42.00'),
        category: 'Salary',
        description: '',
        date: DateTime(2026, 6, 7),
        accountId: 999999,
      );

      Object? thrown;
      try {
        await DatabaseHelper().moveIncomeToDeleted(poisoned);
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull,
          reason: 'The deleted_income FK violation should abort the txn.');

      // Rollback: live row + its tag link both intact, trash table empty.
      expect(await rowCount('income'), 1);
      expect(await tagLinkCount(id, 'income'), 1);
      expect(await rowCount('deleted_income'), 0);
    });
  });

  group('createTemplate', () {
    test('round-trips via readAllTemplates', () async {
      final t = QuickTemplate(
        name: 'Coffee',
        amount: Decimal.parse('4.50'),
        category: 'Food',
        paymentMethod: 'Card',
        type: 'expense',
        accountId: accountId,
        sortOrder: 2,
      );

      final id = await DatabaseHelper().createTemplate(t);
      expect(id, greaterThan(0));

      final all = await DatabaseHelper().readAllTemplates(accountId);
      expect(all.length, 1);
      final read = all.single;
      expect(read.id, id);
      expect(read.name, 'Coffee');
      expect(read.category, 'Food');
      expect(read.paymentMethod, 'Card');
      expect(read.type, 'expense');
      expect(read.accountId, accountId);
      expect(read.sortOrder, 2);
      expect(read.amount, 4.50);
    });

    test('FK violation on a non-existent account_id throws', () async {
      final t = QuickTemplate(
        name: 'Orphan',
        amount: Decimal.parse('1.00'),
        category: 'Misc',
        accountId: 999999,
      );

      Object? thrown;
      try {
        await DatabaseHelper().createTemplate(t);
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull,
          reason: 'A bad account_id FK should abort the template insert.');
      expect(await rowCount('quick_templates'), 0);
    });

    test('applies the model sortOrder default (0) when unset', () async {
      // QuickTemplate.sortOrder defaults to 0 in the model; verify it persists.
      final t = QuickTemplate(
        name: 'Default',
        amount: Decimal.parse('2.00'),
        category: 'Misc',
        accountId: accountId,
      );
      await DatabaseHelper().createTemplate(t);

      final read = (await DatabaseHelper().readAllTemplates(accountId)).single;
      expect(read.sortOrder, 0);
      // Model paymentMethod/type defaults also persist.
      expect(read.paymentMethod, 'Cash');
      expect(read.type, 'expense');
    });
  });

  group('readAllTemplates', () {
    test('orders by sortOrder ASC then name ASC', () async {
      // sortOrder: 1/Zebra, 1/Apple, 0/Beta → expect [Beta, Apple, Zebra].
      await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Zebra',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: accountId,
        sortOrder: 1,
      ));
      await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Apple',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: accountId,
        sortOrder: 1,
      ));
      await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Beta',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: accountId,
        sortOrder: 0,
      ));

      final names =
          (await DatabaseHelper().readAllTemplates(accountId)).map((t) => t.name).toList();
      expect(names, ['Beta', 'Apple', 'Zebra']);
    });

    test('is scoped to the queried account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Mine',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: accountId,
      ));
      await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Theirs',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: other,
      ));

      final mine = await DatabaseHelper().readAllTemplates(accountId);
      expect(mine.length, 1);
      expect(mine.single.name, 'Mine');
    });

    test('returns empty for an account with no templates', () async {
      final empty = await seedAccount(db, name: 'Empty', isDefault: 0);
      expect(await DatabaseHelper().readAllTemplates(empty), isEmpty);
    });
  });

  group('updateTemplate', () {
    test('updates fields by id and returns rows-affected = 1', () async {
      final id = await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Before',
        amount: Decimal.parse('1.00'),
        category: 'Old',
        accountId: accountId,
        sortOrder: 0,
      ));

      final affected = await DatabaseHelper().updateTemplate(QuickTemplate(
        id: id,
        name: 'After',
        amount: Decimal.parse('9.99'),
        category: 'New',
        paymentMethod: 'Card',
        type: 'income',
        accountId: accountId,
        sortOrder: 5,
      ));
      expect(affected, 1);

      final read = (await DatabaseHelper().readAllTemplates(accountId)).single;
      expect(read.id, id);
      expect(read.name, 'After');
      expect(read.category, 'New');
      expect(read.paymentMethod, 'Card');
      expect(read.type, 'income');
      expect(read.sortOrder, 5);
      expect(read.amount, 9.99);
    });

    test('returns 0 for a missing id (no-op)', () async {
      final affected = await DatabaseHelper().updateTemplate(QuickTemplate(
        id: 555555,
        name: 'Ghost',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: accountId,
      ));
      expect(affected, 0);
      expect(await rowCount('quick_templates'), 0);
    });
  });

  group('deleteTemplate', () {
    test('deletes by id and returns 1', () async {
      final id = await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Doomed',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: accountId,
      ));
      expect(await rowCount('quick_templates'), 1);

      final affected = await DatabaseHelper().deleteTemplate(id);
      expect(affected, 1);
      expect(await rowCount('quick_templates'), 0);
    });

    test('returns 0 for a missing id', () async {
      final affected = await DatabaseHelper().deleteTemplate(777777);
      expect(affected, 0);
    });

    test('only deletes the targeted template', () async {
      final keep = await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Keep',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: accountId,
      ));
      final drop = await DatabaseHelper().createTemplate(QuickTemplate(
        name: 'Drop',
        amount: Decimal.parse('1.00'),
        category: 'C',
        accountId: accountId,
      ));

      await DatabaseHelper().deleteTemplate(drop);

      final remaining = await DatabaseHelper().readAllTemplates(accountId);
      expect(remaining.length, 1);
      expect(remaining.single.id, keep);
      expect(remaining.single.name, 'Keep');
    });
  });
}
