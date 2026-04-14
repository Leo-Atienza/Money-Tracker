import 'dart:math';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budget_tracker/database/database_helper.dart';

/// FIX Phase 3b: shared scaffolding for integration tests.
///
/// These tests drive real [DatabaseHelper] code end-to-end against a
/// file-backed SQLite database via `sqflite_common_ffi` — no mocks, no
/// fakes, no platform plugins. Every test file in `test/integration/`
/// should:
///
/// ```dart
/// setUp(() async {
///   await makeFreshDb();
/// });
/// ```
///
/// `sqfliteFfiInit` is idempotent and the `databaseFactory` swap is
/// process-global, so calling `setUpDbFfi` from every test file is safe.
/// `makeFreshDb` assigns a unique `databaseNameOverride` on every call
/// so that Flutter's parallel test-file isolates don't collide on the
/// shared `getDatabasesPath()` file (SQLITE_BUSY / "database is locked").

bool _ffiInitialized = false;
final Random _random = Random();
int _dbCounter = 0;

/// Initialize the sqflite FFI backend and swap the global
/// [databaseFactory] so every subsequent `openDatabase` call resolves
/// through the FFI factory.
///
/// Idempotent: calling this multiple times in a single test process is
/// a no-op after the first invocation.
void setUpDbFfi() {
  if (_ffiInitialized) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiInitialized = true;
}

/// Convenience helper: initialize FFI, pick a unique database filename
/// for this test, reset the `DatabaseHelper` singleton, and return the
/// `Database` handle ready for seeding.
///
/// The unique-name-per-call pattern is essential because Flutter `test`
/// runs each test FILE in a separate isolate and by default runs those
/// isolates IN PARALLEL. All isolates share `getDatabasesPath()` on the
/// same machine, so a fixed `expense_tracker_v4.db` name causes parallel
/// integration test files to fight over the same file and trigger
/// `SQLITE_BUSY`. Every call here picks a fresh
/// `test_${counter}_${timestamp}_${random}.db` name and assigns it to
/// `DatabaseHelper.databaseNameOverride`, so both `_initDatabase` and
/// `resetForTesting` target that unique file.
Future<Database> makeFreshDb() async {
  setUpDbFfi();
  _dbCounter++;
  final unique =
      'test_${_dbCounter}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}.db';
  DatabaseHelper.databaseNameOverride = unique;
  await DatabaseHelper.resetForTesting();
  return DatabaseHelper().database;
}

/// Insert a minimal account row and return its ID. Most integration
/// tests need at least one account because every `expenses`/`income`
/// row has a `NOT NULL` `account_id` foreign key.
Future<int> seedAccount(
  Database db, {
  String name = 'Test Account',
  String icon = '💼',
  String color = '#FF0000',
  int isDefault = 1,
  String currencyCode = 'USD',
}) async {
  return db.insert('accounts', {
    'name': name,
    'icon': icon,
    'color': color,
    'isDefault': isDefault,
    'currencyCode': currencyCode,
  });
}

/// Insert a minimal expense row and return its ID. `date` must be a
/// 10-char ISO-like string (`yyyy-MM-dd`) to match the column's
/// comparison semantics — see Bug 2 fix in `database_helper.dart`.
Future<int> seedExpense(
  Database db, {
  required int accountId,
  required String date,
  double amount = 10.0,
  String category = 'Food',
  String description = 'test',
  double amountPaid = 0.0,
  String paymentMethod = 'Cash',
}) async {
  return db.insert('expenses', {
    'amount': amount,
    'category': category,
    'description': description,
    'date': date,
    'account_id': accountId,
    'amountPaid': amountPaid,
    'paymentMethod': paymentMethod,
  });
}

/// Insert a minimal income row and return its ID.
Future<int> seedIncome(
  Database db, {
  required int accountId,
  required String date,
  double amount = 100.0,
  String category = 'Salary',
  String description = 'test income',
}) async {
  return db.insert('income', {
    'amount': amount,
    'category': category,
    'description': description,
    'date': date,
    'account_id': accountId,
  });
}
