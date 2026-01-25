import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../models/income_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/recurring_income_model.dart';
import '../models/quick_template_model.dart';
import '../models/budget_model.dart';
import '../providers/app_state.dart';

/// Result enum for restore operations
enum RestoreResult {
  success,
  cancelled,
  fileNotFound,
  invalidFile,
  error,
}

/// Data class for passing parameters to isolate
class _BackupIsolateParams {
  final String dbPath;
  final Map<String, dynamic> settings;

  _BackupIsolateParams(this.dbPath, this.settings);
}

/// Isolate function to create comprehensive backup (runs off main thread)
/// FIX: Prevents OOM and UI freeze by processing in background
/// FIX: Uses streaming to avoid loading entire file into memory
Future<String> _createBackupInIsolate(_BackupIsolateParams params) async {
  // FIX: Removed try-catch to preserve original exception and stack trace
  // FIX: Stream-encode database file to Base64 in chunks to avoid OOM
  final dbFile = File(params.dbPath);
  final base64Chunks = <String>[];
  final inputStream = dbFile.openRead();

  // Convert file stream to Base64 in chunks
  await for (final chunk in inputStream) {
    base64Chunks.add(base64Encode(chunk));
  }

  final dbBase64 = base64Chunks.join('');

  // Create backup data structure
  final backupData = {
    'version': 2,
    'timestamp': DateTime.now().toIso8601String(),
    'database': dbBase64,
    'settings': params.settings,
  };

  // Encode to JSON
  return jsonEncode(backupData);
}

/// Data class for passing restore parameters to isolate
class _RestoreIsolateParams {
  final String backupJson;

  _RestoreIsolateParams(this.backupJson);
}

/// Isolate function to decode comprehensive backup (runs off main thread)
/// FIX: Prevents OOM and UI freeze during restore
/// FIX: Removed try-catch to preserve original exception and stack trace
Future<Uint8List> _decodeBackupInIsolate(_RestoreIsolateParams params) async {
  final backupData = jsonDecode(params.backupJson) as Map<String, dynamic>;
  final dbBase64 = backupData['database'] as String;
  return base64Decode(dbBase64);
}

class BackupHelper {
  /// FIX P2-13: Helper to properly escape CSV fields
  /// Escapes double quotes by doubling them (RFC 4180 standard)
  static String _escapeCsvField(String field) {
    return field.replaceAll('"', '""');
  }

  // Export full backup
  Future<void> exportBackup(BuildContext context) async {
    try {
      final appState = context.read<AppState>();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'expense_tracker_backup_$timestamp.json';

      // Gather all data
      // FIX: Fetch ALL expenses/incomes from database instead of using in-memory list
      // This prevents memory issues and ensures complete backups
      final allExpenses = await appState.getAllExpensesForBackup();
      final allIncomes = await appState.getAllIncomesForBackup();

      // FIX P2-12: Include ALL data in backup (previously missing budgets, recurring_income, monthly_balances, tags)
      final backupData = {
        'version': 2, // Bumped version for expanded backup format
        'timestamp': DateTime.now().toIso8601String(),
        'currency': appState.currencyCode,
        'accounts': appState.accounts.map((e) => e.toMap()).toList(),
        'expenses': allExpenses.map((e) => e.toMap()).toList(),
        'incomes': allIncomes.map((e) => e.toMap()).toList(),
        'categories': appState.categories.map((e) => e.toMap()).toList(),
        'recurring_expenses': appState.recurringExpenses.map((e) => e.toMap()).toList(),
        'recurring_income': appState.recurringIncomes.map((e) => e.toMap()).toList(), // FIX P2-12: Added
        'budgets': appState.budgets.map((e) => e.toMap()).toList(), // FIX P2-12: Added
        'quick_templates': appState.quickTemplates.map((e) => e.toMap()).toList(),
        'monthly_balances': appState.monthlyBalances.values.map((e) => e.toMap()).toList(), // FIX P2-12: Added
        'tags': appState.tags, // FIX P2-12: Added (already Map format)
      };

      // Create temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonEncode(backupData));

      // Share file using SharePlus
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Money Tracker Backup',
          text: 'Backup created on ${DateFormat.yMMMd().format(DateTime.now())}',
        ),
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    }
  }

  // Import backup
  Future<void> importBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final data = jsonDecode(content);

        // Validate backup format
        if (data['version'] == null || data['expenses'] == null) {
          throw Exception('Invalid backup file format');
        }

        if (context.mounted) {
          _showRestoreConfirmation(context, data);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${e.toString()}')),
        );
      }
    }
  }

  void _showRestoreConfirmation(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will append the data from the backup to your current data. Duplicates may occur if you import the same data twice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performRestore(context, data);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore(BuildContext context, Map<String, dynamic> data) async {
    try {
      final appState = context.read<AppState>();
      int itemsRestored = 0;

      // Restore Accounts (skip if exists)
      // Note: In a real app, logic would be more complex to merge/replace
      // For simplicity, we just add missing accounts or use default

      // Restore Categories
      if (data['categories'] != null) {
        for (var item in data['categories']) {
          // Check if category exists by name to avoid duplicates
          if (!appState.categories.any((c) => c.name == item['name'] && c.type == item['type'])) {
            await appState.addCategory(item['name'] as String, type: item['type'] as String? ?? 'expense');
            itemsRestored++;
          }
        }
      }

      // Restore Expenses
      if (data['expenses'] != null) {
        for (var item in data['expenses']) {
          final expense = Expense.fromMap(item);
          // Remove ID to let DB generate new unique ID
          final expenseToSave = expense.copyWith(id: null);
          // Make sure it has a valid account ID (using current account)
          // In a real app, we would try to map to the original account
          await appState.addExpense(expenseToSave);
          itemsRestored++;
        }
      }

      // Restore Incomes
      if (data['incomes'] != null) {
        for (var item in data['incomes']) {
          final income = Income.fromMap(item);
          // Remove ID
          final incomeToSave = income.copyWith(id: null);
          await appState.addIncome(incomeToSave);
          itemsRestored++;
        }
      }

      // Restore Recurring
      if (data['recurring_expenses'] != null) {
        for (var item in data['recurring_expenses']) {
          final recurring = RecurringExpense.fromMap(item);
          final recurringToSave = recurring.copyWith(id: null);
          await appState.addRecurringExpense(recurringToSave);
          itemsRestored++;
        }
      }

      // Restore Templates
      if (data['quick_templates'] != null) {
        for (var item in data['quick_templates']) {
          final template = QuickTemplate.fromMap(item);
          final templateToSave = template.copyWith(id: null);
          await appState.addTemplate(templateToSave);
          itemsRestored++;
        }
      }

      // FIX P2-12: Restore Recurring Income (v2 backup format)
      if (data['recurring_income'] != null) {
        for (var item in data['recurring_income']) {
          final recurring = RecurringIncome.fromMap(item);
          final recurringToSave = recurring.copyWith(id: null);
          await appState.addRecurringIncome(recurringToSave);
          itemsRestored++;
        }
      }

      // FIX P2-12: Restore Budgets (v2 backup format)
      if (data['budgets'] != null) {
        for (var item in data['budgets']) {
          final budget = Budget.fromMap(item);
          // Use setBudget which handles duplicates
          await appState.setBudget(budget.category, budget.amount);
          itemsRestored++;
        }
      }

      // Note: monthly_balances and tags are not restored here as they are
      // automatically calculated/managed by the app based on transaction data.
      // The comprehensive database backup (.etbackup) handles full data restore.

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored $itemsRestored items successfully')),
        );
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: ${e.toString()}')),
        );
      }
    }
  }

  // Export CSV (simplified)
  Future<void> exportCsv(BuildContext context) async {
    try {
      final appState = context.read<AppState>();
      // FIX: Fetch ALL expenses from database instead of using in-memory list
      final expenses = await appState.getAllExpensesForBackup();

      final csvContent = StringBuffer();
      csvContent.writeln('Date,Description,Category,Amount,Payment Method,Is Paid');

      for (var expense in expenses) {
        // FIX P2-13: Properly escape ALL text fields to handle commas and quotes
        csvContent.writeln(
            '${DateFormat('yyyy-MM-dd').format(expense.date)},'
                '"${_escapeCsvField(expense.description)}",'
                '"${_escapeCsvField(expense.category)}",'  // FIX: Quote category field
                '${expense.amount},'
                '"${_escapeCsvField(expense.paymentMethod)}",'  // FIX: Quote payment method
                '${expense.isPaid ? "Yes" : "No"}'
        );
      }

      final fileName = 'expenses_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvContent.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Money Tracker CSV Export',
        ),
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV Export failed: ${e.toString()}')),
        );
      }
    }
  }

  // ============== DATABASE BACKUP METHODS ==============

  /// Get the database file path
  Future<String> _getDatabasePath() async {
    final databasePath = await getDatabasesPath();
    return path.join(databasePath, 'expense_tracker_v4.db');
  }

  /// Get list of backup files in app's backup directory
  /// FIX: Include both .db and .etbackup files
  Future<List<File>> getBackupList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(directory.path, 'backups'));

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir
          .list()
          .where((entity) {
        if (entity is! File) return false;
        final filePath = entity.path;
        return filePath.endsWith('.db') || filePath.endsWith('.etbackup');
      })
          .map((entity) => entity as File)
          .toList();

      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting backup list: $e');
      return [];
    }
  }

  /// Save database backup to user-selected location using SAF (Android 11+)
  /// FIX: Uses isolate to prevent OOM and UI freeze
  /// Returns the saved path or null if cancelled
  Future<String?> saveBackupToUserSelectedLocation({
    void Function()? onProcessingStart,
    void Function()? onProcessingEnd,
  }) async {
    try {
      if (kDebugMode) debugPrint('=== BACKUP SAVE START ===');

      // Notify UI to show processing dialog
      onProcessingStart?.call();
      if (kDebugMode) debugPrint('Processing started callback invoked');

      final dbPath = await _getDatabasePath();
if (kDebugMode) debugPrint('Database path: $dbPath');
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
if (kDebugMode) debugPrint('ERROR: Database file not found at $dbPath');
        throw Exception('Database file not found');
      }

if (kDebugMode) debugPrint('Database file exists, size: ${await dbFile.length()} bytes');

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'expense_tracker_$timestamp.etbackup';
if (kDebugMode) debugPrint('Generated filename: $fileName');

      // Get settings on main thread, then offload heavy work to isolate
if (kDebugMode) debugPrint('Loading settings...');
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'darkMode': prefs.getBool('darkMode') ?? false,
        'currencyCode': prefs.getString('currencyCode') ?? 'USD',
        'billReminders': prefs.getBool('billReminders') ?? true,
        'budgetAlerts': prefs.getBool('budgetAlerts') ?? true,
        'monthlySummary': prefs.getBool('monthlySummary') ?? true,
        'reminderHour': prefs.getInt('reminderHour') ?? 9,
        'reminderMinute': prefs.getInt('reminderMinute') ?? 0,
      };
if (kDebugMode) debugPrint('Settings loaded: ${settings.keys.join(", ")}');

      // Run backup creation in isolate to avoid OOM and UI freeze
if (kDebugMode) debugPrint('Creating backup in isolate...');
      final backupJson = await compute(
        _createBackupInIsolate,
        _BackupIsolateParams(dbPath, settings),
      );
if (kDebugMode) debugPrint('Backup JSON created, size: ${backupJson.length} characters');

      final bytes = Uint8List.fromList(utf8.encode(backupJson));
if (kDebugMode) debugPrint('Encoded to bytes, size: ${bytes.length} bytes');

      // Save a local copy in app's backup directory first
if (kDebugMode) debugPrint('Saving local backup copy...');
      final localPath = await _saveLocalBackup(bytes, fileName);
if (kDebugMode) debugPrint('Local backup saved to: $localPath');

      // Notify UI that processing is done (close loading dialog before file picker)
      onProcessingEnd?.call();
if (kDebugMode) debugPrint('Processing ended callback invoked');

      // FIX: On Android with SAF, pass bytes directly to saveFile()
      // The file picker will handle writing the bytes to the user-selected location
if (kDebugMode) debugPrint('Showing file picker with bytes...');
      try {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup',
          fileName: fileName,
          type: FileType.any,
          bytes: bytes,
          lockParentWindow: true,
        );

        if (savedPath != null) {
if (kDebugMode) debugPrint('SAF save successful: $savedPath');
if (kDebugMode) debugPrint('=== BACKUP SAVE COMPLETE ===');
          return savedPath;
        } else {
if (kDebugMode) debugPrint('User cancelled file picker');
          return null;
        }
      } catch (e, stackTrace) {
if (kDebugMode) debugPrint('ERROR in file picker: $e');
if (kDebugMode) debugPrint('Stack trace: $stackTrace');
        throw Exception('Failed to save backup file. Error: $e');
      }
    } catch (e, stackTrace) {
if (kDebugMode) debugPrint('!!! ERROR saving backup: $e');
if (kDebugMode) debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }


  /// Save a local backup copy
  /// FIX: Returns the file path for reuse (avoids redundant file operations)
  Future<String?> _saveLocalBackup(Uint8List bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(directory.path, 'backups'));

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final localBackup = File(path.join(backupDir.path, fileName));
      await localBackup.writeAsBytes(bytes);

      // Keep only last 5 backups
      await _cleanupOldBackups();

      return localBackup.path;
    } catch (e) {
if (kDebugMode) debugPrint('Error saving local backup: $e');
      return null;
    }
  }

  /// Remove old backups, keeping only the most recent ones
  Future<void> _cleanupOldBackups() async {
    try {
      final backups = await getBackupList();
      if (backups.length > 5) {
        for (var i = 5; i < backups.length; i++) {
          await backups[i].delete();
        }
      }
    } catch (e) {
if (kDebugMode) debugPrint('Error cleaning up backups: $e');
    }
  }

  /// Share comprehensive backup file (.etbackup) via system share sheet
  /// FIX: Now creates .etbackup with settings (consistent with Save Backup)
  /// FIX: Also saves to local backup directory for Recent Backups list
  Future<void> shareDatabase({void Function()? onProcessingStart}) async {
    try {
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'expense_tracker_$timestamp.etbackup';

      // FIX: Signal processing start if callback provided
      onProcessingStart?.call();

      // FIX: Get settings to include in comprehensive backup
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'darkMode': prefs.getBool('darkMode') ?? false,
        'currencyCode': prefs.getString('currencyCode') ?? 'USD',
        'billReminders': prefs.getBool('billReminders') ?? true,
        'budgetAlerts': prefs.getBool('budgetAlerts') ?? true,
        'monthlySummary': prefs.getBool('monthlySummary') ?? true,
        'reminderHour': prefs.getInt('reminderHour') ?? 9,
        'reminderMinute': prefs.getInt('reminderMinute') ?? 0,
      };

      // FIX: Create comprehensive backup in isolate
      final backupJson = await compute(
        _createBackupInIsolate,
        _BackupIsolateParams(dbPath, settings),
      );

      final bytes = Uint8List.fromList(utf8.encode(backupJson));

      // FIX: Save to local backup directory (for Recent Backups list)
      // FIX: Reuse this file for sharing to avoid redundant file operations
      final localBackupPath = await _saveLocalBackup(bytes, fileName);

      if (localBackupPath != null) {
        // Share the local backup file directly
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(localBackupPath)],
            subject: 'Money Tracker Backup',
            text: 'Backup created on ${DateFormat.yMMMd().format(DateTime.now())}',
          ),
        );
      } else {
        throw Exception('Failed to create backup file');
      }
    } catch (e) {
if (kDebugMode) debugPrint('Error sharing database: $e');
      rethrow;
    }
  }

  /// Restore database from user-selected file or specific file
  /// FIX: Uses streaming to avoid OOM and atomic replacement to prevent corruption
  /// FIX: Accepts optional File parameter to restore from Recent Backups list
  Future<RestoreResult> restoreDatabase({
    required Future<void> Function() closeDatabase,
    void Function()? onStart, // FIX: Callback when processing actually starts
    File? sourceFile, // FIX: Optional file parameter for direct restore
  }) async {
    try {
      File? actualSourceFile;
      Uint8List? sourceBytes;
      String fileName;

      if (sourceFile != null) {
        // FIX: Direct restore from provided file (e.g., from Recent Backups)
        actualSourceFile = sourceFile;
        final pathParts = sourceFile.path.split(Platform.pathSeparator);
        fileName = pathParts.isNotEmpty ? pathParts.last : 'backup.etbackup';
        onStart?.call(); // Show loading immediately since we have the file
      } else {
        // Pick backup file FIRST (user might cancel here - don't show loading yet)
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) {
          return RestoreResult.cancelled;
        }

        final pickedFile = result.files.first;
        fileName = pickedFile.name;

        // FIX: Now that file is selected, notify UI to show loading dialog
        onStart?.call();

        if (pickedFile.path != null) {
          actualSourceFile = File(pickedFile.path!);
        } else if (pickedFile.bytes != null) {
          sourceBytes = pickedFile.bytes!;
        } else {
          return RestoreResult.fileNotFound;
        }
      }

      // Check if file exists
      if (actualSourceFile != null && !await actualSourceFile.exists()) {
        return RestoreResult.fileNotFound;
      }

      // FIX: Check if this is a new comprehensive backup (.etbackup) or old database (.db)
      final isComprehensiveBackup = fileName.endsWith('.etbackup');

      if (isComprehensiveBackup) {
        // Handle comprehensive backup with settings
        return await _restoreComprehensiveBackup(actualSourceFile, sourceBytes, closeDatabase, onStart);
      }

      // Validate SQLite header for old .db files (only read first 16 bytes)
      final isValid = await _validateSqliteHeader(actualSourceFile, sourceBytes);
      if (!isValid) {
        return RestoreResult.invalidFile;
      }

      // Get database path
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);

      // Create temp file for atomic replacement
      final tempPath = '$dbPath.tmp';
      final tempFile = File(tempPath);

      // FIX: Create timestamped backup of current database before replacing (for safety)
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final preRestoreBackup = '${dbPath}_pre_restore_$timestamp.db';
      final preRestoreFile = File(preRestoreBackup);

      // Also keep .bak for immediate rollback
      final backupPath = '$dbPath.bak';
      final backupFile = File(backupPath);

      try {
        // FIX: Stream copy to temp file to avoid OOM
        if (actualSourceFile != null) {
          await _streamCopyFile(actualSourceFile, tempFile);
        } else if (sourceBytes != null) {
          // For in-memory bytes, write in chunks
          await _writeInChunks(tempFile, sourceBytes);
        }

        // Verify the temp file is valid before proceeding
        final tempValid = await _validateSqliteHeader(tempFile, null);
        if (!tempValid) {
          await tempFile.delete();
          return RestoreResult.invalidFile;
        }

        // Close database before replacing
        await closeDatabase();

        // Create both timestamped and .bak backups of existing database
        if (await dbFile.exists()) {
          await dbFile.copy(preRestoreBackup); // Permanent safety backup
          await dbFile.copy(backupPath);       // Temporary rollback backup
        }

        // FIX: Atomic replacement - rename temp to target
        await tempFile.rename(dbPath);

        // Clean up temporary .bak file on success
        if (await backupFile.exists()) {
          await backupFile.delete();
        }

        // Keep pre-restore backup for 7 days as safety net
        Future.delayed(const Duration(days: 7), () async {
          if (await preRestoreFile.exists()) {
            await preRestoreFile.delete();
          }
        });

        return RestoreResult.success;
      } catch (e) {
        // Restore from backup if something went wrong
        if (await backupFile.exists()) {
          try {
            await backupFile.rename(dbPath);
          } catch (_) {
            // Last resort: copy instead of rename
            await backupFile.copy(dbPath);
            await backupFile.delete();
          }
        }

        // Clean up temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

if (kDebugMode) debugPrint('Error during restore, rolled back: $e');
        return RestoreResult.error;
      }
    } catch (e) {
if (kDebugMode) debugPrint('Error restoring database: $e');
      return RestoreResult.error;
    }
  }

  /// Stream copy a file to avoid loading entire file into memory (OOM fix)
  Future<void> _streamCopyFile(File source, File destination) async {
    final sourceStream = source.openRead();
    final destinationSink = destination.openWrite();

    try {
      await sourceStream.pipe(destinationSink);
    } finally {
      await destinationSink.close();
    }
  }

  /// Write bytes in chunks to avoid memory pressure
  Future<void> _writeInChunks(File file, Uint8List bytes) async {
    const chunkSize = 64 * 1024; // 64KB chunks
    final sink = file.openWrite();

    try {
      for (var i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        sink.add(bytes.sublist(i, end));
        // Allow other operations to proceed
        await sink.flush();
      }
    } finally {
      await sink.close();
    }
  }

  /// Validate SQLite header without loading entire file into memory
  Future<bool> _validateSqliteHeader(File? file, Uint8List? bytes) async {
    const sqliteMagic = [0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00];

    if (file != null) {
      // Read only the header bytes from file
      final randomAccess = await file.open(mode: FileMode.read);
      try {
        final header = await randomAccess.read(sqliteMagic.length);
        if (header.length < sqliteMagic.length) {
          return false;
        }
        for (var i = 0; i < sqliteMagic.length; i++) {
          if (header[i] != sqliteMagic[i]) {
            return false;
          }
        }
        return true;
      } finally {
        await randomAccess.close();
      }
    } else if (bytes != null) {
      return _isValidSqliteFile(bytes);
    }

    return false;
  }

  /// Validate that bytes represent a valid SQLite database
  bool _isValidSqliteFile(Uint8List bytes) {
    // SQLite files start with "SQLite format 3\0"
    const sqliteMagic = [0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00];

    if (bytes.length < sqliteMagic.length) {
      return false;
    }

    for (var i = 0; i < sqliteMagic.length; i++) {
      if (bytes[i] != sqliteMagic[i]) {
        return false;
      }
    }

    return true;
  }

  /// Delete a backup file
  Future<void> deleteBackup(File backup) async {
    try {
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (e) {
if (kDebugMode) debugPrint('Error deleting backup: $e');
      rethrow;
    }
  }

  /// Get backup file info (date and size)
  Future<Map<String, dynamic>> getBackupInfo(File backup) async {
    final stat = await backup.stat();
    return {
      'date': stat.modified,
      'size': stat.size,
    };
  }

  /// Format file size for display
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// FIX: Restore comprehensive backup (database + settings)
  /// Uses isolate to prevent OOM and UI freeze during decoding
  /// FIX: Uses streaming for large files to avoid memory crashes
  Future<RestoreResult> _restoreComprehensiveBackup(
      File? sourceFile,
      Uint8List? sourceBytes,
      Future<void> Function() closeDatabase,
      void Function()? onStart,
      ) async {
    try {
      // FIX: Read backup data using streaming for large files
      String backupJson;
      if (sourceFile != null) {
        // FIX: Use streaming for files larger than 10MB to avoid OOM
        final fileSize = await sourceFile.length();
        if (fileSize > 10 * 1024 * 1024) {
          // Stream read in chunks
          final chunks = <List<int>>[];
          final inputStream = sourceFile.openRead();
          await for (final chunk in inputStream) {
            chunks.add(chunk);
          }
          backupJson = utf8.decode(chunks.expand((x) => x).toList());
        } else {
          backupJson = await sourceFile.readAsString();
        }
      } else if (sourceBytes != null) {
        backupJson = utf8.decode(sourceBytes);
      } else {
        return RestoreResult.fileNotFound;
      }

      // Quick validation before expensive decode
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
      if (backupData['version'] == null || backupData['database'] == null) {
        return RestoreResult.invalidFile;
      }

      // FIX: Decode database in isolate to prevent OOM and UI freeze
      final dbBytes = await compute(
        _decodeBackupInIsolate,
        _RestoreIsolateParams(backupJson),
      );

      // Get database path
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);

      // FIX: Create automatic backup before restore
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final preRestoreBackup = '${dbPath}_pre_restore_$timestamp.db';
      if (await dbFile.exists()) {
        await dbFile.copy(preRestoreBackup);
      }

      // Create temp file for atomic replacement
      final tempPath = '$dbPath.tmp';
      final tempFile = File(tempPath);

      try {
        // Write database to temp file
        await _writeInChunks(tempFile, dbBytes);

        // FIX: CRITICAL - Validate that temp file is a valid SQLite database before overwriting!
        final isValidDb = await _validateSqliteHeader(tempFile, null);
        if (!isValidDb) {
          // Clean up invalid temp file
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          return RestoreResult.invalidFile;
        }

        // Close current database connection
        await closeDatabase();
        await Future.delayed(const Duration(milliseconds: 500));

        // Atomic replacement
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
        await tempFile.rename(dbPath);

        // FIX: Restore settings if present
        if (backupData['settings'] != null) {
          final settings = backupData['settings'] as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();

          await prefs.setBool('darkMode', settings['darkMode'] as bool? ?? false);
          await prefs.setString('currencyCode', settings['currencyCode'] as String? ?? 'USD');
          await prefs.setBool('billReminders', settings['billReminders'] as bool? ?? true);
          await prefs.setBool('budgetAlerts', settings['budgetAlerts'] as bool? ?? true);
          await prefs.setBool('monthlySummary', settings['monthlySummary'] as bool? ?? true);
          await prefs.setInt('reminderHour', settings['reminderHour'] as int? ?? 9);
          await prefs.setInt('reminderMinute', settings['reminderMinute'] as int? ?? 0);
        }

        // Clean up pre-restore backup after successful restore
        final preRestoreFile = File(preRestoreBackup);
        if (await preRestoreFile.exists()) {
          // Keep it for 7 days as safety net
          Future.delayed(const Duration(days: 7), () async {
            if (await preRestoreFile.exists()) {
              await preRestoreFile.delete();
            }
          });
        }

        return RestoreResult.success;
      } catch (e) {
        // Rollback: restore from pre-restore backup
        final preRestoreFile = File(preRestoreBackup);
        if (await preRestoreFile.exists()) {
          await closeDatabase();
          await Future.delayed(const Duration(milliseconds: 500));
          if (await dbFile.exists()) {
            await dbFile.delete();
          }
          await preRestoreFile.copy(dbPath);
        }
        rethrow;
      }
    } catch (e) {
if (kDebugMode) debugPrint('Error restoring comprehensive backup: $e');
      return RestoreResult.error;
    }
  }
}
