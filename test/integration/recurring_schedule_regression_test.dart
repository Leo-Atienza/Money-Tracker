import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/date_helper.dart';

import '_test_helpers.dart';

/// 2026-10 review — the recurring processor end to end (real AppState +
/// sqflite_common_ffi DB).
///
/// - `lastCreated` must be stored as the last INSTANCE's date. Storing the
///   day processing ran made the next monthly instance land a month late and
///   skipped the month after it.
/// - Every account's recurring items post, not only the current account's.
/// - An item past its end date still pays the instances that fell due
///   before the end.
void main() {
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null);
    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  final today = DateHelper.today();
  final thisMonth1st = DateTime.utc(today.year, today.month, 1);
  final lastMonth1st = DateTime.utc(today.year, today.month - 1, 1);
  final twoMonthsAgo1st = DateTime.utc(today.year, today.month - 2, 1);
  final threeMonthsAgo1st = DateTime.utc(today.year, today.month - 3, 1);

  Future<int> seedMonthlyBill(
    Database db, {
    required int accountId,
    required DateTime lastCreated,
    String description = 'rent',
    String? endDate,
  }) {
    return db.insert('recurring_expenses', {
      'description': description,
      'amount': 100.0,
      'category': 'Bills',
      'dayOfMonth': 1,
      'isActive': 1,
      'lastCreated': DateHelper.toDateString(lastCreated),
      'account_id': accountId,
      'paymentMethod': 'Cash',
      'occurrenceCount': 0,
      'frequency': 0, // monthly
      'endDate': endDate,
    });
  }

  Future<List<String>> expenseDates(Database db, String description) async {
    final rows = await db.query(
      'expenses',
      columns: ['date'],
      where: 'description = ?',
      whereArgs: [description],
      orderBy: 'date ASC',
    );
    return [for (final r in rows) r['date'] as String];
  }

  test('stores the instance date, not the run day, as lastCreated', () async {
    final db = await DatabaseHelper().database;
    final id = await seedMonthlyBill(db, accountId: 1, lastCreated: lastMonth1st);

    final appState = AppState();
    await appState.runRecurringProcessingForTesting();

    expect(
      await expenseDates(db, 'rent'),
      [DateHelper.toDateString(thisMonth1st)],
    );
    final row = (await db.query(
      'recurring_expenses',
      where: 'id = ?',
      whereArgs: [id],
    ))
        .single;
    expect(row['lastCreated'], DateHelper.toDateString(thisMonth1st));
    expect(row['occurrenceCount'], 1);
    appState.dispose();
  });

  test("posts another account's bills too", () async {
    final db = await DatabaseHelper().database;
    final savings = await seedAccount(db, name: 'Savings', isDefault: 0);
    await seedMonthlyBill(
      db,
      accountId: savings,
      lastCreated: lastMonth1st,
      description: 'savings fee',
    );

    // A bare AppState reads account 1 as current.
    final appState = AppState();
    await appState.runRecurringProcessingForTesting();

    final rows = await db.query(
      'expenses',
      where: 'description = ?',
      whereArgs: ['savings fee'],
    );
    expect(rows, hasLength(1));
    expect(rows.single['account_id'], savings);
    appState.dispose();
  });

  test('an ended bill still pays what fell due before it ended', () async {
    final db = await DatabaseHelper().database;
    // Last paid three months ago, ended mid-way through the month after.
    final endedOn = DateTime.utc(twoMonthsAgo1st.year, twoMonthsAgo1st.month, 15);
    await seedMonthlyBill(
      db,
      accountId: 1,
      lastCreated: threeMonthsAgo1st,
      description: 'gym',
      endDate: DateHelper.toDateString(endedOn),
    );

    final appState = AppState();
    await appState.runRecurringProcessingForTesting();

    expect(
      await expenseDates(db, 'gym'),
      [DateHelper.toDateString(twoMonthsAgo1st)],
    );
    appState.dispose();
  });
}
