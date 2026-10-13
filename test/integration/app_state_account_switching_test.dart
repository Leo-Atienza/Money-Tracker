import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// 2026-10 review — account switching.
///
/// - `restoreDeletedAccount` switched to the restored account INSIDE the
///   write mutex; switchAccount's loaders take the same non-reentrant mutex,
///   so restoring deadlocked ("Restoring account…" forever).
/// - `_loadAccounts` re-picked the default account on every call, and
///   loadData runs on every resume: a user on "Savings" was silently moved
///   back to the default account and their next expense saved there.
///
/// Each test gets its own documents directory: deleteAccount writes a JSON
/// backup there, and the shared path other suites use races across parallel
/// test isolates (why the older restore test in app_state_crud_test is
/// skipped).
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

  late Directory docsDir;

  setUp(() async {
    docsDir = Directory.systemTemp.createTempSync('ff_accounts_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null)
      ..setMockMethodCallHandler(secureChannel, (_) async => null)
      ..setMockMethodCallHandler(
        pathProviderChannel,
        (_) async => docsDir.path,
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
    try {
      docsDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<AppState> bootstrap() async {
    final state = AppState();
    await state.loadData();
    return state;
  }

  test('restoring a deleted account completes and switches to it', () async {
    final state = await bootstrap();
    await state.addAccount('Trashable');
    final trashable = state.accounts.firstWhere((a) => a.name == 'Trashable');
    await state.deleteAccount(trashable.id!);
    final deleted = await state.getDeletedAccounts();
    final deletedId =
        deleted.firstWhere((row) => row['name'] == 'Trashable')['id'] as int;

    // Deadlocked before the fix — the timeout turns a hang into a failure.
    // Generous: under the full parallel suite this shares the connection
    // with loadData's background VACUUM and orphan sweep.
    await state
        .restoreDeletedAccount(deletedId)
        .timeout(const Duration(seconds: 45));

    expect(state.currentAccount?.name, 'Trashable');
    // And the write lock was released: a later write still goes through.
    await state
        .addAccount('After restore')
        .timeout(const Duration(seconds: 45));
    expect(state.accounts.any((a) => a.name == 'After restore'), isTrue);
    state.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a restored account keeps its default categories', () async {
    final state = await bootstrap();
    await state.addAccount('Side');
    final side = state.accounts.firstWhere((a) => a.name == 'Side');
    await state.switchAccount(side);
    await state.addCategory('Coffee'); // one custom category is enough
    await state.switchAccount(
      state.accounts.firstWhere((a) => a.isDefault),
    );
    await state.deleteAccount(side.id!);
    final deletedId = (await state.getDeletedAccounts())
        .firstWhere((row) => row['name'] == 'Side')['id'] as int;

    await state.restoreDeletedAccount(deletedId);

    final names = state.expenseCategories.map((c) => c.name).toSet();
    expect(names, containsAll(<String>['Coffee', 'Food', 'Bills']));
    expect(
      state.incomeCategories.map((c) => c.name),
      contains('Salary'),
    );
    state.dispose();
  });

  test('a reload (as on every resume) keeps the current account', () async {
    final state = await bootstrap();
    await state.addAccount('Savings');
    final savings = state.accounts.firstWhere((a) => a.name == 'Savings');
    await state.switchAccount(savings);

    await state.loadData();

    expect(state.currentAccount?.id, savings.id);
    expect(state.currentAccountId, savings.id);
    state.dispose();
  });

  test('making another account the default does not switch to it', () async {
    final state = await bootstrap();
    final main = state.currentAccount!;
    await state.addAccount('Savings');
    final savings = state.accounts.firstWhere((a) => a.name == 'Savings');

    await state.setDefaultAccount(savings.id!);

    expect(state.currentAccount?.id, main.id);
    state.dispose();
  });

  test('deleting the current account falls back to the default', () async {
    final state = await bootstrap();
    await state.addAccount('Savings');
    final savings = state.accounts.firstWhere((a) => a.name == 'Savings');
    await state.switchAccount(savings);

    await state.deleteAccount(savings.id!);

    expect(state.currentAccount?.isDefault, isTrue);
    state.dispose();
  });
}
