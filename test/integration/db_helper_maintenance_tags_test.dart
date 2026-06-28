import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:budget_tracker/database/database_helper.dart';

import '_test_helpers.dart';

/// Phase 7 / Stage D — DatabaseHelper maintenance + backup plumbing + Tag
/// CRUD/junction coverage (NEXT_SESSION_HANDOFF.md §"Maintenance",
/// §"Backup / restore plumbing", §"Tag CRUD + junction").
///
/// Every expected value below is DERIVED FROM the lib source:
///   * `deleteAccount` runs a `db.transaction` that deletes the account's
///     expenses/income; the AFTER-DELETE triggers
///     `trg_transaction_tags_cleanup_expense` / `_income` purge the matching
///     `transaction_tags` rows atomically (L28). The txn also explicitly
///     deletes the account's `tags`, and the `tags`→`transaction_tags`
///     `ON DELETE CASCADE` removes any junction rows that survived.
///   * `purgeExpiredDeletedAccounts` deletes `deleted_accounts` rows whose
///     `deletedAt < now-30d` (UTC ISO8601). It tries to delete the file named
///     by `data` only `if (await file.exists())`, so a non-existent path is a
///     safe no-op for the file branch.
///   * `getDeletedAccounts` is a pure read ordered `deletedAt DESC` — no purge.
///   * Tag junction has a UNIQUE index on
///     `(transaction_id, transaction_type, tag_id)`, so `addTagToTransaction`
///     (ConflictAlgorithm.ignore) is idempotent.
///
/// `deleteAccount` writes a backup JSON file via
/// `getApplicationDocumentsDirectory()`, so this file mirrors the
/// path_provider / secure-storage / notifications / home_widget mock
/// boilerplate from `app_state_crud_test.dart`. We exercise
/// `DatabaseHelper.deleteAccount` DIRECTLY (no `restoreDeletedAccount`), which
/// avoids the orphaned-file-cleanup race that forced the AppState-level
/// round-trip test to be skipped.
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

  late Database db;

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

    db = await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null)
      ..setMockMethodCallHandler(secureChannel, null)
      ..setMockMethodCallHandler(pathProviderChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  Future<int> count(String sql, List<Object?> args) async {
    final rows = await db.rawQuery(sql, args);
    final first = rows.isEmpty ? null : rows.first.values.first;
    return (first as int?) ?? 0;
  }

  // ===================================================================
  // L28 — deleteAccount atomic junction + row purge
  // ===================================================================
  group('deleteAccount — L28 atomic transaction_tags + row purge', () {
    test(
      'leaves ZERO transaction_tags / expenses / income for the deleted account',
      () async {
        // Non-default account so deleteAccount is permitted.
        final accountId =
            await seedAccount(db, name: 'Trashable', isDefault: 0);

        final expenseId = await seedExpense(
          db,
          accountId: accountId,
          date: '2026-05-10',
          amount: 12.34,
        );
        final incomeId = await seedIncome(
          db,
          accountId: accountId,
          date: '2026-05-11',
          amount: 500.0,
        );

        // Tags + junction links via the public Tag API.
        final tagA = await DatabaseHelper().createTag('food', accountId);
        final tagB = await DatabaseHelper().createTag('salary', accountId);
        await DatabaseHelper()
            .addTagToTransaction(expenseId, 'expense', tagA);
        await DatabaseHelper()
            .addTagToTransaction(incomeId, 'income', tagB);

        // Sanity: links exist before the delete.
        expect(
          await count('SELECT COUNT(*) FROM transaction_tags', const []),
          2,
        );

        await DatabaseHelper().deleteAccount(accountId);

        // Account-scoped rows gone.
        expect(
          await count(
            'SELECT COUNT(*) FROM expenses WHERE account_id = ?',
            [accountId],
          ),
          0,
        );
        expect(
          await count(
            'SELECT COUNT(*) FROM income WHERE account_id = ?',
            [accountId],
          ),
          0,
        );
        expect(
          await count(
            'SELECT COUNT(*) FROM tags WHERE account_id = ?',
            [accountId],
          ),
          0,
        );
        // The AFTER-DELETE triggers + tags cascade leave ZERO junction rows.
        expect(
          await count('SELECT COUNT(*) FROM transaction_tags', const []),
          0,
        );
        // The account row itself is gone.
        expect(
          await count(
            'SELECT COUNT(*) FROM accounts WHERE id = ?',
            [accountId],
          ),
          0,
        );
      },
    );

    test('does not touch a sibling account\'s transactions or tags', () async {
      final victim = await seedAccount(db, name: 'Victim', isDefault: 0);
      final keeper = await seedAccount(db, name: 'Keeper', isDefault: 0);

      final victimExpense =
          await seedExpense(db, accountId: victim, date: '2026-05-10');
      final keeperExpense =
          await seedExpense(db, accountId: keeper, date: '2026-05-10');

      final victimTag = await DatabaseHelper().createTag('v', victim);
      final keeperTag = await DatabaseHelper().createTag('k', keeper);
      await DatabaseHelper()
          .addTagToTransaction(victimExpense, 'expense', victimTag);
      await DatabaseHelper()
          .addTagToTransaction(keeperExpense, 'expense', keeperTag);

      await DatabaseHelper().deleteAccount(victim);

      // Keeper untouched.
      expect(
        await count(
          'SELECT COUNT(*) FROM expenses WHERE account_id = ?',
          [keeper],
        ),
        1,
      );
      expect(
        await count(
          'SELECT COUNT(*) FROM tags WHERE account_id = ?',
          [keeper],
        ),
        1,
      );
      expect(
        await count(
          'SELECT COUNT(*) FROM transaction_tags WHERE tag_id = ?',
          [keeperTag],
        ),
        1,
      );
    });

    test('throws when deleting the default account', () async {
      // seedAccount defaults to isDefault: 1.
      final defaultAccount = await seedAccount(db, name: 'Default');
      expect(
        () => DatabaseHelper().deleteAccount(defaultAccount),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when the account id does not exist', () async {
      expect(
        () => DatabaseHelper().deleteAccount(999999),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ===================================================================
  // Soft-deleted accounts: purge vs pure read
  // ===================================================================
  group('purgeExpiredDeletedAccounts / getDeletedAccounts', () {
    // Insert a deleted_accounts metadata row directly. `data` is NOT NULL and
    // names a file path; we point it at a path that does NOT exist so the
    // `if (await file.exists())` file-delete branch is skipped.
    Future<int> seedDeletedAccount(String name, String deletedAtIso) async {
      return db.insert('deleted_accounts', {
        'original_id': 4242,
        'name': name,
        'deletedAt': deletedAtIso,
        'data': '.dart_tool/test_path_provider/nonexistent_$name.json',
      });
    }

    test('removes rows older than 30 days, keeps recent ones', () async {
      final old = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 40))
          .toIso8601String();
      final recent = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 5))
          .toIso8601String();

      await seedDeletedAccount('OldAccount', old);
      await seedDeletedAccount('RecentAccount', recent);

      expect(
        await count('SELECT COUNT(*) FROM deleted_accounts', const []),
        2,
      );

      await DatabaseHelper().purgeExpiredDeletedAccounts();

      // Only the recent row survives.
      expect(
        await count('SELECT COUNT(*) FROM deleted_accounts', const []),
        1,
      );
      final survivors = await db.query('deleted_accounts');
      expect(survivors.single['name'], 'RecentAccount');
    });

    test('keeps everything when nothing is older than 30 days', () async {
      final recent = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      await seedDeletedAccount('A', recent);
      await seedDeletedAccount('B', recent);

      await DatabaseHelper().purgeExpiredDeletedAccounts();

      expect(
        await count('SELECT COUNT(*) FROM deleted_accounts', const []),
        2,
      );
    });

    test('getDeletedAccounts is a pure read — does NOT purge expired rows',
        () async {
      final old = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 90))
          .toIso8601String();
      await seedDeletedAccount('VeryOld', old);

      // A read must not delete the expired row (L30 regression).
      final rows = await DatabaseHelper().getDeletedAccounts();
      expect(rows, hasLength(1));
      expect(
        await count('SELECT COUNT(*) FROM deleted_accounts', const []),
        1,
      );
    });

    test('getDeletedAccounts returns rows most-recent-first (deletedAt DESC)',
        () async {
      final older = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 10))
          .toIso8601String();
      final newer = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      await seedDeletedAccount('Older', older);
      await seedDeletedAccount('Newer', newer);

      final rows = await DatabaseHelper().getDeletedAccounts();
      expect(rows, hasLength(2));
      // DESC → newest deletedAt first.
      expect(rows.first['name'], 'Newer');
      expect(rows.last['name'], 'Older');
    });

    test('getDeletedAccounts returns empty list when none exist', () async {
      final rows = await DatabaseHelper().getDeletedAccounts();
      expect(rows, isEmpty);
    });
  });

  // ===================================================================
  // Maintenance
  // ===================================================================
  group('maintenance', () {
    test('vacuum() completes without error on a populated DB', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-05-10');
      // Should not throw.
      await DatabaseHelper().vacuum();
      // DB still usable afterwards.
      expect(
        await count('SELECT COUNT(*) FROM expenses', const []),
        1,
      );
    });

    test('analyze() completes without error', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-05-10');
      await DatabaseHelper().analyze();
      // DB still usable afterwards.
      expect(
        await count('SELECT COUNT(*) FROM expenses', const []),
        1,
      );
    });

    test('needsMaintenance() is false on a fresh DB', () async {
      // A freshly created DB has a near-empty freelist → < 20% bloat.
      expect(await DatabaseHelper().needsMaintenance(), isFalse);
    });

    test('performMaintenance(force: true) runs vacuum+analyze without error',
        () async {
      final accountId = await seedAccount(db, isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-05-10');

      // force: true bypasses the needsMaintenance gate and must complete
      // (orphan-cleanup + expired-purge errors are swallowed internally).
      await DatabaseHelper().performMaintenance(force: true);

      expect(
        await count('SELECT COUNT(*) FROM expenses', const []),
        1,
      );
    });

    test('performMaintenance(force: false) on a fresh DB completes (no-op gate)',
        () async {
      // needsMaintenance() is false here, so vacuum/analyze are skipped, but
      // the method still runs orphan-cleanup + purge without throwing.
      await DatabaseHelper().performMaintenance();
      // No assertion on internal work — just that it returned cleanly.
      expect(true, isTrue);
    });
  });

  // ===================================================================
  // Backup / restore plumbing
  // ===================================================================
  group('backup plumbing', () {
    test('getDatabasePath() ends with the hardcoded db filename', () async {
      // NOTE seam: getDatabasePath hardcodes `expense_tracker_v4.db` and
      // ignores `databaseNameOverride`, so the returned path is NOT the
      // unique per-test file. We only assert the trailing filename.
      final dbPath = await DatabaseHelper().getDatabasePath();
      expect(dbPath, endsWith('expense_tracker_v4.db'));
    });

    test('getDatabaseSize() returns a non-negative size', () async {
      // Same seam: this reads the hardcoded path, which may or may not exist
      // under FFI tests. Either way the contract is "file length or 0", so the
      // robust invariant is >= 0.
      final size = await DatabaseHelper().getDatabaseSize();
      expect(size, greaterThanOrEqualTo(0));
    });

    test('closeDatabase() then database getter re-initializes a usable handle',
        () async {
      // Seed through the current handle.
      final accountId = await seedAccount(db, isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-05-10');

      await DatabaseHelper().closeDatabase();

      // Next access re-opens the same underlying file (override is stable
      // across the close) and the row is still there.
      final reopened = await DatabaseHelper().database;
      final rows = await reopened.rawQuery('SELECT COUNT(*) FROM expenses');
      expect((rows.first.values.first as int?) ?? 0, 1);
    });

    test('closeDatabase() is a safe no-op when called twice', () async {
      await DatabaseHelper().closeDatabase();
      // Second close with nothing open must not throw.
      await DatabaseHelper().closeDatabase();
      // And the DB still re-inits afterwards.
      final reopened = await DatabaseHelper().database;
      expect(reopened.isOpen, isTrue);
    });
  });

  // ===================================================================
  // Tag CRUD
  // ===================================================================
  group('tag CRUD', () {
    test('createTag round-trips name/color/account via readAllTags', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final tagId =
          await DatabaseHelper().createTag('groceries', accountId, color: '#00FF00');
      expect(tagId, greaterThan(0));

      final tags = await DatabaseHelper().readAllTags(accountId);
      expect(tags, hasLength(1));
      expect(tags.single['name'], 'groceries');
      expect(tags.single['color'], '#00FF00');
      expect(tags.single['account_id'], accountId);
    });

    test('createTag accepts a null color', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final tagId = await DatabaseHelper().createTag('no-color', accountId);
      final tags = await DatabaseHelper().readAllTags(accountId);
      expect(tags.single['id'], tagId);
      expect(tags.single['color'], isNull);
    });

    test('createTag with a non-existent account violates the FK', () async {
      // tags.account_id → accounts(id); foreign_keys = ON (onConfigure).
      expect(
        () => DatabaseHelper().createTag('orphan', 987654),
        throwsA(anything),
      );
    });

    test('readAllTags is account-scoped and ordered name ASC', () async {
      final a = await seedAccount(db, name: 'A', isDefault: 0);
      final b = await seedAccount(db, name: 'B', isDefault: 0);
      await DatabaseHelper().createTag('zebra', a);
      await DatabaseHelper().createTag('apple', a);
      await DatabaseHelper().createTag('other-account-tag', b);

      final tagsA = await DatabaseHelper().readAllTags(a);
      expect(tagsA.map((t) => t['name']).toList(), ['apple', 'zebra']);

      final tagsB = await DatabaseHelper().readAllTags(b);
      expect(tagsB.map((t) => t['name']).toList(), ['other-account-tag']);
    });

    test('readAllTags returns empty for an account with no tags', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      expect(await DatabaseHelper().readAllTags(accountId), isEmpty);
    });

    test('updateTag changes name + color by id', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final tagId =
          await DatabaseHelper().createTag('old', accountId, color: '#111111');

      final affected =
          await DatabaseHelper().updateTag(tagId, 'new', color: '#222222');
      expect(affected, 1);

      final tags = await DatabaseHelper().readAllTags(accountId);
      expect(tags.single['name'], 'new');
      expect(tags.single['color'], '#222222');
    });

    test('updateTag can null-out the color', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final tagId =
          await DatabaseHelper().createTag('c', accountId, color: '#333333');

      await DatabaseHelper().updateTag(tagId, 'c');

      final tags = await DatabaseHelper().readAllTags(accountId);
      expect(tags.single['color'], isNull);
    });

    test('updateTag on a missing id affects zero rows', () async {
      final affected = await DatabaseHelper().updateTag(424242, 'ghost');
      expect(affected, 0);
    });

    test('deleteTag removes the tag and returns 1', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final tagId = await DatabaseHelper().createTag('temp', accountId);

      final affected = await DatabaseHelper().deleteTag(tagId);
      expect(affected, 1);
      expect(await DatabaseHelper().readAllTags(accountId), isEmpty);
    });

    test('deleteTag cascades to its transaction_tags junction rows', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final expenseId =
          await seedExpense(db, accountId: accountId, date: '2026-05-10');
      final tagId = await DatabaseHelper().createTag('linked', accountId);
      await DatabaseHelper().addTagToTransaction(expenseId, 'expense', tagId);

      expect(
        await count(
          'SELECT COUNT(*) FROM transaction_tags WHERE tag_id = ?',
          [tagId],
        ),
        1,
      );

      await DatabaseHelper().deleteTag(tagId);

      // tags→transaction_tags ON DELETE CASCADE removes the junction row.
      expect(
        await count(
          'SELECT COUNT(*) FROM transaction_tags WHERE tag_id = ?',
          [tagId],
        ),
        0,
      );
    });

    test('deleteTag on a missing id returns 0', () async {
      expect(await DatabaseHelper().deleteTag(515151), 0);
    });
  });

  // ===================================================================
  // Tag junction
  // ===================================================================
  group('tag junction', () {
    test('addTagToTransaction creates a link visible via getTagsForTransaction',
        () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final expenseId =
          await seedExpense(db, accountId: accountId, date: '2026-05-10');
      final tagId = await DatabaseHelper().createTag('coffee', accountId);

      await DatabaseHelper().addTagToTransaction(expenseId, 'expense', tagId);

      final tags =
          await DatabaseHelper().getTagsForTransaction(expenseId, 'expense');
      expect(tags, hasLength(1));
      expect(tags.single['id'], tagId);
      expect(tags.single['name'], 'coffee');
    });

    test('addTagToTransaction is idempotent — duplicate is ignored (no throw)',
        () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final expenseId =
          await seedExpense(db, accountId: accountId, date: '2026-05-10');
      final tagId = await DatabaseHelper().createTag('dup', accountId);

      await DatabaseHelper().addTagToTransaction(expenseId, 'expense', tagId);
      // Second insert hits the UNIQUE index and is ignored via
      // ConflictAlgorithm.ignore — must NOT throw and must NOT duplicate.
      await DatabaseHelper().addTagToTransaction(expenseId, 'expense', tagId);

      expect(
        await count(
          'SELECT COUNT(*) FROM transaction_tags '
          'WHERE transaction_id = ? AND transaction_type = ? AND tag_id = ?',
          [expenseId, 'expense', tagId],
        ),
        1,
      );
    });

    test('removeTagFromTransaction removes the target link, leaves others',
        () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final expenseId =
          await seedExpense(db, accountId: accountId, date: '2026-05-10');
      final tagA = await DatabaseHelper().createTag('a', accountId);
      final tagB = await DatabaseHelper().createTag('b', accountId);

      await DatabaseHelper().addTagToTransaction(expenseId, 'expense', tagA);
      await DatabaseHelper().addTagToTransaction(expenseId, 'expense', tagB);

      await DatabaseHelper()
          .removeTagFromTransaction(expenseId, 'expense', tagA);

      final remaining =
          await DatabaseHelper().getTagsForTransaction(expenseId, 'expense');
      expect(remaining, hasLength(1));
      expect(remaining.single['id'], tagB);
    });

    test('getTagsForTransaction is type-scoped (expense vs income same id)',
        () async {
      final accountId = await seedAccount(db, isDefault: 0);
      // Deliberately make an expense and income that could share an id value;
      // the link is scoped by transaction_type, so they must not bleed.
      final expenseId =
          await seedExpense(db, accountId: accountId, date: '2026-05-10');
      final incomeId =
          await seedIncome(db, accountId: accountId, date: '2026-05-10');
      final expenseTag = await DatabaseHelper().createTag('exp', accountId);
      final incomeTag = await DatabaseHelper().createTag('inc', accountId);

      await DatabaseHelper()
          .addTagToTransaction(expenseId, 'expense', expenseTag);
      await DatabaseHelper()
          .addTagToTransaction(incomeId, 'income', incomeTag);

      final expTags =
          await DatabaseHelper().getTagsForTransaction(expenseId, 'expense');
      expect(expTags.map((t) => t['id']).toList(), [expenseTag]);

      final incTags =
          await DatabaseHelper().getTagsForTransaction(incomeId, 'income');
      expect(incTags.map((t) => t['id']).toList(), [incomeTag]);
    });

    test('getTagsForTransaction returns empty when no links exist', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final expenseId =
          await seedExpense(db, accountId: accountId, date: '2026-05-10');
      expect(
        await DatabaseHelper().getTagsForTransaction(expenseId, 'expense'),
        isEmpty,
      );
    });

    test('getTransactionIdsForTag returns matching ids, type-scoped', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final e1 =
          await seedExpense(db, accountId: accountId, date: '2026-05-10');
      final e2 =
          await seedExpense(db, accountId: accountId, date: '2026-05-11');
      final inc =
          await seedIncome(db, accountId: accountId, date: '2026-05-10');
      final tagId = await DatabaseHelper().createTag('shared', accountId);

      await DatabaseHelper().addTagToTransaction(e1, 'expense', tagId);
      await DatabaseHelper().addTagToTransaction(e2, 'expense', tagId);
      await DatabaseHelper().addTagToTransaction(inc, 'income', tagId);

      final expenseIds =
          await DatabaseHelper().getTransactionIdsForTag(tagId, 'expense');
      expect(expenseIds.toSet(), {e1, e2});

      final incomeIds =
          await DatabaseHelper().getTransactionIdsForTag(tagId, 'income');
      expect(incomeIds, [inc]);
    });

    test('getTransactionIdsForTag returns empty for an unused tag', () async {
      final accountId = await seedAccount(db, isDefault: 0);
      final tagId = await DatabaseHelper().createTag('lonely', accountId);
      expect(
        await DatabaseHelper().getTransactionIdsForTag(tagId, 'expense'),
        isEmpty,
      );
    });

    test(
      'readAllTransactionTags is account-scoped via the tags JOIN, ordered id ASC',
      () async {
        final a = await seedAccount(db, name: 'A', isDefault: 0);
        final b = await seedAccount(db, name: 'B', isDefault: 0);

        final aExpense =
            await seedExpense(db, accountId: a, date: '2026-05-10');
        final bExpense =
            await seedExpense(db, accountId: b, date: '2026-05-10');

        final aTag1 = await DatabaseHelper().createTag('a1', a);
        final aTag2 = await DatabaseHelper().createTag('a2', a);
        final bTag = await DatabaseHelper().createTag('b1', b);

        await DatabaseHelper().addTagToTransaction(aExpense, 'expense', aTag1);
        await DatabaseHelper().addTagToTransaction(aExpense, 'expense', aTag2);
        await DatabaseHelper().addTagToTransaction(bExpense, 'expense', bTag);

        final aLinks = await DatabaseHelper().readAllTransactionTags(a);
        // Only account A's two links, none of B's.
        expect(aLinks, hasLength(2));
        expect(
          aLinks.map((r) => r['tag_id']).toSet(),
          {aTag1, aTag2},
        );
        // Ordered by junction id ASC.
        final ids = aLinks.map((r) => r['id'] as int).toList();
        final sorted = [...ids]..sort();
        expect(ids, sorted);

        final bLinks = await DatabaseHelper().readAllTransactionTags(b);
        expect(bLinks, hasLength(1));
        expect(bLinks.single['tag_id'], bTag);
      },
    );

    test('readAllTransactionTags returns empty for an account with no links',
        () async {
      final accountId = await seedAccount(db, isDefault: 0);
      expect(
        await DatabaseHelper().readAllTransactionTags(accountId),
        isEmpty,
      );
    });
  });
}
