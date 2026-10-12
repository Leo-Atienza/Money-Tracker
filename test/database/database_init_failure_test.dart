import 'package:budget_tracker/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// A database that fails to open is an expected path since the storage fix
/// (an unreadable SQLCipher key fails the open into the load-error card).
/// The failure must reach the caller once, and nowhere else: the init
/// completer used to complete with an error nobody listened to, which the
/// zone reported as an unhandled async error — a test failure here, and a
/// spurious crash report on a device.
///
/// This file never installs a databaseFactory, so every open fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a failed open is reported to the caller, not as an unhandled error',
      () async {
    await expectLater(DatabaseHelper().database, throwsA(isA<StateError>()));
  });

  test('a later open retries instead of replaying the old failure', () async {
    // Each attempt runs the open again (the completer is reset), so it
    // fails the same way rather than hanging on a spent completer.
    await expectLater(DatabaseHelper().database, throwsA(isA<StateError>()));
    await expectLater(DatabaseHelper().database, throwsA(isA<StateError>()));
  });
}
