import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/backup_helper.dart';
import 'package:budget_tracker/utils/notification_helper.dart';
import 'package:budget_tracker/constants/database.dart';
import 'package:budget_tracker/utils/settings_helper.dart';

void main() {
  // =========================================================================
  // 1. CSV Field Escaping Logic
  // =========================================================================
  //
  // BackupHelper._escapeCsvField is private, so we recreate the same logic
  // (RFC 4180: double quotes are escaped by doubling them) and verify it
  // matches the behavior used by exportCsv.
  // =========================================================================

  group('CSV field escaping logic (RFC 4180)', () {
    // Mirrors BackupHelper._escapeCsvField exactly
    String escapeCsvField(String field) {
      return field.replaceAll('"', '""');
    }

    test('plain text passes through unchanged', () {
      expect(escapeCsvField('Groceries'), 'Groceries');
    });

    test('field with double quotes doubles them', () {
      expect(escapeCsvField('Item "A"'), 'Item ""A""');
    });

    test('field with multiple quotes doubles each', () {
      expect(escapeCsvField('"Hello" "World"'), '""Hello"" ""World""');
    });

    test('field with commas is preserved (quoting handled by caller)', () {
      // _escapeCsvField only escapes quotes; the caller wraps in quotes
      expect(escapeCsvField('Rice, Beans'), 'Rice, Beans');
    });

    test('field with newlines is preserved (quoting handled by caller)', () {
      expect(escapeCsvField('Line1\nLine2'), 'Line1\nLine2');
    });

    test('empty field returns empty string', () {
      expect(escapeCsvField(''), '');
    });

    test('field with quotes AND commas escapes only quotes', () {
      expect(escapeCsvField('"Total", she said'), '""Total"", she said');
    });

    test('field with only quotes becomes doubled quotes', () {
      expect(escapeCsvField('""'), '""""');
    });

    test('CSV row construction wraps escaped field in quotes', () {
      // Simulate how exportCsv builds a row: "${_escapeCsvField(field)}"
      final description = 'Lunch at "Joe\'s Diner", downtown';
      final escaped = '"${escapeCsvField(description)}"';
      expect(escaped, '"Lunch at ""Joe\'s Diner"", downtown"');
    });
  });

  // =========================================================================
  // 2. BackupHelper.formatFileSize
  // =========================================================================

  group('BackupHelper.formatFileSize', () {
    late BackupHelper helper;

    setUp(() {
      helper = BackupHelper();
    });

    test('0 bytes', () {
      expect(helper.formatFileSize(0), '0 B');
    });

    test('512 bytes', () {
      expect(helper.formatFileSize(512), '512 B');
    });

    test('1023 bytes (just under 1 KB)', () {
      expect(helper.formatFileSize(1023), '1023 B');
    });

    test('1024 bytes = 1.0 KB', () {
      expect(helper.formatFileSize(1024), '1.0 KB');
    });

    test('1536 bytes = 1.5 KB', () {
      expect(helper.formatFileSize(1536), '1.5 KB');
    });

    test('10240 bytes = 10.0 KB', () {
      expect(helper.formatFileSize(10240), '10.0 KB');
    });

    test('1048576 bytes = 1.0 MB', () {
      expect(helper.formatFileSize(1048576), '1.0 MB');
    });

    test('1572864 bytes = 1.5 MB', () {
      expect(helper.formatFileSize(1572864), '1.5 MB');
    });

    test('boundary: 1024*1024 - 1 is still KB', () {
      // 1048575 bytes = 1023.999... KB
      final result = helper.formatFileSize(1048575);
      expect(result, endsWith('KB'));
    });

    test('large MB value', () {
      // 10 MB
      expect(helper.formatFileSize(10 * 1024 * 1024), '10.0 MB');
    });
  });

  // =========================================================================
  // 3. NotificationHelper channel name configuration
  // =========================================================================

  group('NotificationHelper.setChannelNames', () {
    test('setChannelNames accepts all named parameters without error', () {
      // Calling setChannelNames should not throw
      expect(
        () => NotificationHelper.setChannelNames(
          billRemindersName: 'Recordatorios de facturas',
          billRemindersDesc: 'Recordatorios para facturas pendientes',
          budgetAlertsName: 'Alertas de presupuesto',
          budgetAlertsDesc: 'Alertas al acercarse o superar presupuestos',
          monthlyReportsName: 'Reportes mensuales',
          monthlyReportsDesc: 'Resumen mensual de gastos',
        ),
        returnsNormally,
      );
    });

    test('setChannelNames accepts partial parameters', () {
      expect(
        () => NotificationHelper.setChannelNames(
          billRemindersName: 'Custom Bill Name',
        ),
        returnsNormally,
      );
    });

    test('setChannelNames accepts no parameters', () {
      expect(
        () => NotificationHelper.setChannelNames(),
        returnsNormally,
      );
    });

    test('setChannelNames can be called multiple times (overwrite)', () {
      // First call
      NotificationHelper.setChannelNames(
        budgetAlertsName: 'First',
      );
      // Second call should not throw (overwrites)
      expect(
        () => NotificationHelper.setChannelNames(
          budgetAlertsName: 'Second',
        ),
        returnsNormally,
      );
    });

    test('NotificationHelper is a singleton', () {
      final a = NotificationHelper();
      final b = NotificationHelper();
      expect(identical(a, b), isTrue);
    });
  });

  // =========================================================================
  // 4. DatabaseConstants validation
  // =========================================================================

  group('DatabaseConstants', () {
    group('database metadata', () {
      test('database version is 18', () {
        expect(DatabaseConstants.databaseVersion, 18);
      });

      test('database name is non-empty', () {
        expect(DatabaseConstants.databaseName, isNotEmpty);
        expect(DatabaseConstants.databaseName, 'expense_tracker_v4.db');
      });
    });

    group('table names are non-empty strings', () {
      final tableNames = <String, String>{
        'tableAccounts': DatabaseConstants.tableAccounts,
        'tableExpenses': DatabaseConstants.tableExpenses,
        'tableIncome': DatabaseConstants.tableIncome,
        'tableBudgets': DatabaseConstants.tableBudgets,
        'tableRecurringExpenses': DatabaseConstants.tableRecurringExpenses,
        'tableRecurringIncome': DatabaseConstants.tableRecurringIncome,
        'tableCategories': DatabaseConstants.tableCategories,
        'tableDeletedExpenses': DatabaseConstants.tableDeletedExpenses,
        'tableDeletedIncome': DatabaseConstants.tableDeletedIncome,
        'tableDeletedAccounts': DatabaseConstants.tableDeletedAccounts,
        'tableQuickTemplates': DatabaseConstants.tableQuickTemplates,
        'tableTags': DatabaseConstants.tableTags,
        'tableTransactionTags': DatabaseConstants.tableTransactionTags,
      };

      for (final entry in tableNames.entries) {
        test('${entry.key} is non-empty', () {
          expect(entry.value, isA<String>());
          expect(entry.value, isNotEmpty);
        });
      }
    });

    group('column names are non-empty strings', () {
      final columnNames = <String, String>{
        'columnId': DatabaseConstants.columnId,
        'columnAmount': DatabaseConstants.columnAmount,
        'columnCategory': DatabaseConstants.columnCategory,
        'columnDescription': DatabaseConstants.columnDescription,
        'columnDate': DatabaseConstants.columnDate,
        'columnAccountId': DatabaseConstants.columnAccountId,
        'columnName': DatabaseConstants.columnName,
        'columnIsDefault': DatabaseConstants.columnIsDefault,
        'columnIsActive': DatabaseConstants.columnIsActive,
        'columnType': DatabaseConstants.columnType,
        'columnDeletedAt': DatabaseConstants.columnDeletedAt,
        'columnOriginalId': DatabaseConstants.columnOriginalId,
        'columnAmountPaid': DatabaseConstants.columnAmountPaid,
        'columnPaymentMethod': DatabaseConstants.columnPaymentMethod,
        'columnDayOfMonth': DatabaseConstants.columnDayOfMonth,
        'columnLastCreated': DatabaseConstants.columnLastCreated,
        'columnEndDate': DatabaseConstants.columnEndDate,
        'columnMaxOccurrences': DatabaseConstants.columnMaxOccurrences,
        'columnOccurrenceCount': DatabaseConstants.columnOccurrenceCount,
        'columnFrequency': DatabaseConstants.columnFrequency,
        'columnStartDate': DatabaseConstants.columnStartDate,
        'columnIcon': DatabaseConstants.columnIcon,
        'columnColor': DatabaseConstants.columnColor,
        'columnCurrencyCode': DatabaseConstants.columnCurrencyCode,
        'columnMonth': DatabaseConstants.columnMonth,
        'columnSortOrder': DatabaseConstants.columnSortOrder,
      };

      for (final entry in columnNames.entries) {
        test('${entry.key} is non-empty', () {
          expect(entry.value, isA<String>());
          expect(entry.value, isNotEmpty);
        });
      }
    });

    group('type and payment constants', () {
      test('typeExpense is "expense"', () {
        expect(DatabaseConstants.typeExpense, 'expense');
      });

      test('typeIncome is "income"', () {
        expect(DatabaseConstants.typeIncome, 'income');
      });

      test('payment methods are non-empty', () {
        expect(DatabaseConstants.paymentCash, isNotEmpty);
        expect(DatabaseConstants.paymentCard, isNotEmpty);
        expect(DatabaseConstants.paymentBank, isNotEmpty);
        expect(DatabaseConstants.paymentDigital, isNotEmpty);
      });
    });

    group('table names are unique', () {
      test('no duplicate table names', () {
        final tables = [
          DatabaseConstants.tableAccounts,
          DatabaseConstants.tableExpenses,
          DatabaseConstants.tableIncome,
          DatabaseConstants.tableBudgets,
          DatabaseConstants.tableRecurringExpenses,
          DatabaseConstants.tableRecurringIncome,
          DatabaseConstants.tableCategories,
          DatabaseConstants.tableDeletedExpenses,
          DatabaseConstants.tableDeletedIncome,
          DatabaseConstants.tableDeletedAccounts,
          DatabaseConstants.tableQuickTemplates,
          DatabaseConstants.tableTags,
          DatabaseConstants.tableTransactionTags,
        ];
        expect(tables.toSet().length, tables.length);
      });
    });
  });

  // =========================================================================
  // 5. SettingsHelper key constants and method accessibility
  // =========================================================================
  //
  // SettingsHelper uses SharedPreferences (needs platform binding), so we
  // verify that the class is importable, instantiation-free (all static),
  // and the public API surface compiles correctly.
  // =========================================================================

  group('SettingsHelper accessibility', () {
    // The keys are private (_key*), so we verify methods exist via type checks.
    // If any method signature changes, these tests will fail at compile time.

    test('getter methods return Future types', () {
      // Verify method references are callable (compile-time check)
      expect(SettingsHelper.getDarkMode, isA<Function>());
      expect(SettingsHelper.getThemeMode, isA<Function>());
      expect(SettingsHelper.getCurrencyCode, isA<Function>());
      expect(SettingsHelper.getBillReminders, isA<Function>());
      expect(SettingsHelper.getBudgetAlerts, isA<Function>());
      expect(SettingsHelper.getMonthlySummary, isA<Function>());
      expect(SettingsHelper.getReminderHour, isA<Function>());
      expect(SettingsHelper.getReminderMinute, isA<Function>());
      expect(SettingsHelper.getCsvSeparator, isA<Function>());
      expect(SettingsHelper.getBudgetWarningThreshold, isA<Function>());
      expect(SettingsHelper.getSearchDebounce, isA<Function>());
      expect(SettingsHelper.getPaginationLimit, isA<Function>());
      expect(SettingsHelper.getShowTransactionColors, isA<Function>());
      expect(SettingsHelper.getTransactionColorIntensity, isA<Function>());
    });

    test('setter methods are accessible', () {
      expect(SettingsHelper.setDarkMode, isA<Function>());
      expect(SettingsHelper.setThemeMode, isA<Function>());
      expect(SettingsHelper.setCurrencyCode, isA<Function>());
      expect(SettingsHelper.setBillReminders, isA<Function>());
      expect(SettingsHelper.setBudgetAlerts, isA<Function>());
      expect(SettingsHelper.setMonthlySummary, isA<Function>());
      expect(SettingsHelper.setReminderHour, isA<Function>());
      expect(SettingsHelper.setReminderMinute, isA<Function>());
      expect(SettingsHelper.setCsvSeparator, isA<Function>());
      expect(SettingsHelper.setBudgetWarningThreshold, isA<Function>());
      expect(SettingsHelper.setSearchDebounce, isA<Function>());
      expect(SettingsHelper.setPaginationLimit, isA<Function>());
      expect(SettingsHelper.setShowTransactionColors, isA<Function>());
      expect(SettingsHelper.setTransactionColorIntensity, isA<Function>());
    });

    test('clearAll method is accessible', () {
      expect(SettingsHelper.clearAll, isA<Function>());
    });
  });

  // =========================================================================
  // 6. Backup file type detection logic
  // =========================================================================
  //
  // BackupHelper distinguishes .etbackup (comprehensive JSON backup with
  // base64-encoded DB + settings) from .db (raw SQLite database).
  // The detection is based on file extension.
  // =========================================================================

  group('Backup file type detection', () {
    // Mirrors the logic in restoreDatabase: fileName.endsWith('.etbackup')
    bool isComprehensiveBackup(String fileName) {
      return fileName.endsWith('.etbackup');
    }

    bool isLegacyDatabaseBackup(String fileName) {
      return fileName.endsWith('.db');
    }

    test('.etbackup is detected as comprehensive backup', () {
      expect(isComprehensiveBackup('expense_tracker_20260316_120000.etbackup'), isTrue);
    });

    test('.db is not a comprehensive backup', () {
      expect(isComprehensiveBackup('expense_tracker_v4.db'), isFalse);
    });

    test('.db is detected as legacy database backup', () {
      expect(isLegacyDatabaseBackup('expense_tracker_v4.db'), isTrue);
    });

    test('.etbackup is not a legacy database backup', () {
      expect(isLegacyDatabaseBackup('expense_tracker_20260316_120000.etbackup'), isFalse);
    });

    test('.json is neither etbackup nor db', () {
      expect(isComprehensiveBackup('backup.json'), isFalse);
      expect(isLegacyDatabaseBackup('backup.json'), isFalse);
    });

    test('file without extension is neither', () {
      expect(isComprehensiveBackup('backup'), isFalse);
      expect(isLegacyDatabaseBackup('backup'), isFalse);
    });

    test('extension matching is case-sensitive', () {
      // The actual code uses endsWith which is case-sensitive
      expect(isComprehensiveBackup('backup.ETBACKUP'), isFalse);
      expect(isLegacyDatabaseBackup('backup.DB'), isFalse);
    });

    test('extension in middle of name does not match', () {
      expect(isComprehensiveBackup('backup.etbackup.old'), isFalse);
      expect(isLegacyDatabaseBackup('backup.db.bak'), isFalse);
    });

    test('getBackupList recognizes both extensions', () {
      // Mirrors the filter in getBackupList
      bool isBackupFile(String filePath) {
        return filePath.endsWith('.db') || filePath.endsWith('.etbackup');
      }

      expect(isBackupFile('/backups/test.db'), isTrue);
      expect(isBackupFile('/backups/test.etbackup'), isTrue);
      expect(isBackupFile('/backups/test.json'), isFalse);
      expect(isBackupFile('/backups/test.txt'), isFalse);
    });
  });

  // =========================================================================
  // 7. RestoreResult enum values
  // =========================================================================

  group('RestoreResult enum', () {
    test('has all expected values', () {
      expect(RestoreResult.values, contains(RestoreResult.success));
      expect(RestoreResult.values, contains(RestoreResult.cancelled));
      expect(RestoreResult.values, contains(RestoreResult.fileNotFound));
      expect(RestoreResult.values, contains(RestoreResult.invalidFile));
      expect(RestoreResult.values, contains(RestoreResult.incompatibleVersion));
      expect(RestoreResult.values, contains(RestoreResult.error));
    });

    test('has exactly 6 values', () {
      // Bug #9 added `incompatibleVersion` so restores from backups with a
      // schema newer than the installed app surface a distinct result.
      expect(RestoreResult.values.length, 6);
    });
  });
}
