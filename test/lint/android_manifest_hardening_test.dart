import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FIX Phase 1.9 — Android backup / data-extraction hardening.
///
/// Money Tracker holds every penny the user has ever logged.
/// `adb backup com.moneytracker.app` (or Google Drive auto-backup, or
/// the new-phone set-up wizard on Android 12+) had been allowed by
/// default — anyone with physical access to an unlocked device could
/// pull an unencrypted SQLite dump.
///
/// Phase 1.9 closes three surfaces:
///
/// 1. `android:allowBackup="false"` on `<application>` — disables
///    legacy ADB backup AND Google Drive auto-backup for SDK < 31.
/// 2. `android:fullBackupContent="false"` — belt-and-braces for SDK 23-30.
/// 3. `android:dataExtractionRules="@xml/data_extraction_rules"`
///    plus the matching `xml/data_extraction_rules.xml` deny-all for
///    SDK 31+ (`cloud-backup` and `device-transfer`).
///
/// This test reads the manifest + the rules file and pins them in
/// place so a future flip of `allowBackup` doesn't slip through.
/// Manual verification: `adb backup -f test.ab com.moneytracker.app`
/// should produce an empty/failed backup.
void main() {
  test('AndroidManifest disables backup + extraction', () {
    final src = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      src.contains('android:allowBackup="false"'),
      isTrue,
      reason: 'allowBackup must be false to disable legacy ADB '
          'backup + Google Drive auto-backup. Phase 1.9.',
    );
    expect(
      src.contains('android:fullBackupContent="false"'),
      isTrue,
      reason: 'fullBackupContent=false belt-and-braces for SDK 23-30.',
    );
    expect(
      src.contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      isTrue,
      reason: 'dataExtractionRules must point at the deny-all rules '
          'file. Required for SDK 31+ where the per-surface model '
          'replaces the all-or-nothing fullBackupContent.',
    );
  });

  test('data_extraction_rules.xml denies cloud-backup AND device-transfer',
      () {
    final rulesPath =
        File('android/app/src/main/res/xml/data_extraction_rules.xml');
    expect(rulesPath.existsSync(), isTrue,
        reason: 'xml/data_extraction_rules.xml is missing.');
    final src = rulesPath.readAsStringSync();
    expect(
      src.contains('<cloud-backup>'),
      isTrue,
      reason: 'Cloud-backup surface must be explicitly declared so '
          'we can add `<exclude>` directives.',
    );
    expect(
      src.contains('<device-transfer>'),
      isTrue,
      reason: 'Device-transfer surface must be declared (Android 12+ '
          'new-phone setup wizard).',
    );
    // The rules file must exclude all known data domains. We check a
    // couple of representative tokens; the file is small enough that
    // a single grep is sufficient.
    for (final domain in const ['database', 'sharedpref', 'root']) {
      expect(
        src.contains('domain="$domain"'),
        isTrue,
        reason: 'Domain "$domain" must be excluded on both surfaces.',
      );
    }
  });
}
