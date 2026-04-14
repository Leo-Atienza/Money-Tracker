import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budget_tracker/database/database_helper.dart';

/// FIX Phase 3b: shared scaffolding for integration tests.
///
/// These tests drive real [DatabaseHelper] code end-to-end against an
/// in-memory SQLite database via `sqflite_common_ffi` — no mocks, no
/// fakes, no platform plugins. Every test file in `test/integration/`
/// should:
///
/// ```dart
/// setUp(() async {
///   setUpDbFfi();
///   await DatabaseHelper.resetForTesting();
/// });
/// ```
///
/// `sqfliteFfiInit` is idempotent and the `databaseFactory` swap is
/// process-global, so calling `setUpDbFfi` from every test file is safe.
/// `resetForTesting` drops the singleton's cached database so the next
/// access triggers a fresh `_initDatabase` cycle against the FFI factory.

bool _ffiInitialized = false;

/// Initialize the sqflite FFI backend and swap the global
/// [databaseFactory] so every subsequent `openDatabase` call resolves
/// to an in-memory SQLite database under the hood.
///
/// Idempotent: calling this multiple times in a single test process is
/// a no-op after the first invocation.
void setUpDbFfi() {
  if (_ffiInitialized) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  _ffiInitialized = true;
}

/// Convenience helper: initialize FFI, reset the `DatabaseHelper`
/// singleton, and return the `Database` handle ready for seeding.
///
/// Use this when a test doesn't need any special setup beyond a clean
/// DB — most integration tests in this pass can call this from their
/// `setUp` block.
Future<Database> makeFreshDb() async {
  setUpDbFfi();
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
