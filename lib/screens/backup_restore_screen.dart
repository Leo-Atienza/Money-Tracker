import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import '../utils/backup_helper.dart';
import '../providers/app_state.dart';
import '../constants/spacing.dart';
import '../main.dart'; // for AppColors

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  List<Map<String, dynamic>> _backupsWithInfo = [];
  List<File> _allBackupFiles = []; // FIX: Keep track of all backup files
  bool _loading = true;
  bool _isExporting = false; // FIX: Track export operation state
  bool _isRestoring = false; // FIX: Track restore operation state
  bool _loadingMore = false; // FIX: Track loading more backups
  bool _isSelectionMode = false; // FIX: Track bulk delete selection mode
  final Set<String> _selectedBackups = {}; // FIX: Track selected backup paths
  static const int _initialLoadCount =
      20; // FIX: Only load 20 most recent backups initially
  static const int _loadMoreCount = 20; // FIX: Load 20 more when user requests

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  /// FIX: Check if there's enough storage space before backup operation
  /// Returns true if enough space, false otherwise
  /// NOTE: Currently not used as BackupHelper handles storage checks internally
  /// Kept for potential future enhancements
  // ignore: unused_element
  Future<bool> _hasEnoughStorage({required int requiredBytes}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // ignore: unused_local_variable
      final stat = await dir.stat();
      // We can't directly get available space in Dart, but we can check if we have write permission
      // and estimate based on file sizes. For simplicity, we'll create a test file.
      // A more robust solution would use platform channels to get actual free space.

      // Estimate: if required is > 100MB, warn the user
      const largeFileThreshold = 100 * 1024 * 1024; // 100MB
      if (requiredBytes > largeFileThreshold) {
        return await _confirmLargeOperation(requiredBytes);
      }
      return true;
    } catch (e) {
      return true; // If we can't check, proceed anyway
    }
  }

  /// FIX: Ask user to confirm large operations
  Future<bool> _confirmLargeOperation(int bytes) async {
    final sizeMB = (bytes / (1024 * 1024)).toStringAsFixed(1);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Large Backup'),
        content: Text(
          'This backup is $sizeMB MB. Make sure you have enough storage space available.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// FIX: Show user-friendly error message based on exception type
  String _getFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Permission denied. Please check app permissions in settings.';
    } else if (errorString.contains('space') ||
        errorString.contains('storage')) {
      return 'Not enough storage space. Please free up some space and try again.';
    } else if (errorString.contains('not found') ||
        errorString.contains('no such file')) {
      return 'File not found. It may have been moved or deleted.';
    } else if (errorString.contains('invalid') ||
        errorString.contains('corrupt')) {
      return 'Invalid or corrupted backup file. Please select a valid backup.';
    } else if (errorString.contains('timeout') ||
        errorString.contains('time out')) {
      return 'Operation timed out. Please try again.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your connection.';
    } else if (errorString.contains('file picker')) {
      return 'Failed to open file picker. Try restarting the app or check permissions.';
    } else if (errorString.contains('write')) {
      return 'Failed to write backup file. Check storage permissions and available space.';
    } else {
      // Include partial error details for debugging
      final firstLine = error.toString().split('\n').first;
      return 'Error: ${firstLine.substring(0, 100.clamp(0, firstLine.length))}';
    }
  }

  /// FIX: Show dialog with automatic timeout protection to prevent trap dialogs
  /// Returns true if operation completed, false if timed out
  /// NOTE: Currently not used as timeout is handled directly in restore operations
  /// Kept for potential future enhancements
  // ignore: unused_element
  Future<bool> _showProgressDialogWithTimeout({
    required String message,
    required Future<void> Function() operation,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    bool dialogShown = false;
    // ignore: unused_local_variable
    bool operationCompleted = false;
    bool timedOut = false;

    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: Spacing.lg),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      );
      dialogShown = true;

      // Run operation with timeout
      await operation().timeout(
        timeout,
        onTimeout: () {
          timedOut = true;
          throw TimeoutException(
            'Operation timed out after ${timeout.inSeconds} seconds',
          );
        },
      );

      operationCompleted = true;
      return true;
    } catch (e) {
      if (timedOut && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Operation took too long and was cancelled. Your data is safe. Please try again.',
            ),
            backgroundColor: Theme.of(context).extension<AppColors>()!.warningOrange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      rethrow;
    } finally {
      // Always close dialog if it was shown
      if (mounted && dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  /// FIX: Lazy loading - only load metadata for backups that are visible
  /// Initially loads 20 most recent backups, more can be loaded on demand
  Future<void> _loadBackups({bool loadMore = false}) async {
    // FIX: Don't clear list while refreshing - prevents flash
    if (_backupsWithInfo.isEmpty && !loadMore) {
      setState(() => _loading = true);
    } else if (loadMore) {
      setState(() => _loadingMore = true);
    }

    try {
      // FIX: Get list of all backup files (fast - just file names, no metadata)
      if (!loadMore) {
        try {
          _allBackupFiles = await BackupHelper().getBackupList();
        } catch (e) {
          // If we can't get the backup list, just show empty state
          if (kDebugMode) debugPrint('Error getting backup list: $e');
          _allBackupFiles = [];
        }
      }
      if (!mounted) return;

      // FIX: Calculate how many we've already loaded and how many to load
      final alreadyLoadedCount = _backupsWithInfo.length;
      final startIndex = loadMore ? alreadyLoadedCount : 0;
      final endIndex = loadMore
          ? (alreadyLoadedCount + _loadMoreCount).clamp(
              0,
              _allBackupFiles.length,
            )
          : _initialLoadCount.clamp(0, _allBackupFiles.length);

      // FIX: Only process the subset we need (not all 500!)
      final backupsToLoad =
          _allBackupFiles.skip(startIndex).take(endIndex - startIndex).toList();

      // FIX: Batch process to prevent "too many open files" error
      // FIX: For refresh, build complete list before updating UI to prevent flicker
      final backupsWithInfo = loadMore
          ? List<Map<String, dynamic>>.from(_backupsWithInfo)
          : <Map<String, dynamic>>[];
      const batchSize = 10;

      for (var i = 0; i < backupsToLoad.length; i += batchSize) {
        final batch = backupsToLoad.skip(i).take(batchSize);
        final batchResults = await Future.wait(
          batch.map((backup) async {
            try {
              final info = await BackupHelper().getBackupInfo(backup);
              return {
                'file': backup,
                'date': info['date'],
                'size': info['size'],
              };
            } catch (e) {
              // Skip corrupt/unreadable backups instead of failing entirely
              if (kDebugMode) {
                debugPrint('Skipping unreadable backup ${backup.path}: $e');
              }
              return null;
            }
          }),
        );

        // Filter out null results from corrupt backups
        final validBackups =
            batchResults.whereType<Map<String, dynamic>>().toList();
        if (validBackups.isNotEmpty) {
          backupsWithInfo.addAll(validBackups);
        }

        if (!mounted) return;

        // FIX: Only update UI after each batch when loading more
        // For refresh, update once at the end to prevent flicker
        if (loadMore) {
          setState(() {
            _backupsWithInfo = List.from(backupsWithInfo);
          });
        }
      }

      // FIX: For refresh, update UI once with complete data
      if (!loadMore && mounted) {
        setState(() {
          _backupsWithInfo = List.from(backupsWithInfo);
        });
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      // FIX: Handle errors during backup loading with user-friendly messages
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          // If there was an error, show empty state rather than erroring out
          if (_backupsWithInfo.isEmpty) {
            _backupsWithInfo = [];
            _allBackupFiles = [];
          }
        });

        // Only show error if it's not just "no backups found"
        final errorString = e.toString().toLowerCase();
        if (!errorString.contains('not found') &&
            !errorString.contains('no such')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getFriendlyErrorMessage(e)),
              backgroundColor: Theme.of(context).extension<AppColors>()!.expenseRed,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _exportBackup() async {
    // FIX: Prevent multiple simultaneous exports
    if (_isExporting) return;

    if (kDebugMode) debugPrint('_exportBackup called');
    setState(() => _isExporting = true);

    // FIX: Track if dialog is currently shown to prevent navigation bugs
    bool dialogShown = false;
    String? savedPath;

    try {
      // NOTE: Android 13+ uses SAF (Storage Access Framework) via FilePicker
      // which handles permissions automatically - no explicit permission needed.
      if (kDebugMode) debugPrint('Starting backup save process...');

      savedPath = await BackupHelper().saveBackupToUserSelectedLocation(
        onProcessingStart: () {
          // Show loading dialog while creating backup
          if (kDebugMode) debugPrint('Showing loading dialog...');
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const PopScope(
                canPop: false,
                child: AlertDialog(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: Spacing.lg),
                      Expanded(child: Text('Creating backup...')),
                    ],
                  ),
                ),
              ),
            );
            dialogShown = true;
          }
        },
        onProcessingEnd: () {
          // Close the dialog before file picker opens
          if (kDebugMode) {
            debugPrint('Closing loading dialog for file picker...');
          }
          if (mounted && dialogShown) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogShown = false;
          }
        },
      );
      if (kDebugMode) {
        debugPrint('saveBackupToUserSelectedLocation returned: $savedPath');
      }

      if (!mounted) {
        if (kDebugMode) {
          debugPrint('Widget unmounted after backup, skipping UI update');
        }
        return;
      }

      if (savedPath != null) {
        if (kDebugMode) {
          debugPrint('Backup successful, showing success message');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup saved successfully!'),
            backgroundColor: Theme.of(context).extension<AppColors>()!.incomeGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        if (kDebugMode) debugPrint('Reloading backup list...');
        await _loadBackups();
        if (kDebugMode) debugPrint('Backup list reloaded');
      } else {
        // User cancelled - not an error
        if (kDebugMode) debugPrint('User cancelled backup');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup cancelled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      // FIX: Close dialog if shown
      if (kDebugMode) debugPrint('!!! ERROR in _exportBackup: $e');
      if (kDebugMode) debugPrint('Stack trace: $stackTrace');
      if (mounted && dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        final errorMessage = _getFriendlyErrorMessage(e);
        if (kDebugMode) debugPrint('Showing error to user: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).extension<AppColors>()!.expenseRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // FIX: Always re-enable button
      if (kDebugMode) {
        debugPrint('_exportBackup finally block, re-enabling button');
      }
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareBackup() async {
    // FIX: Track dialog state for Share operation
    bool dialogShown = false;

    try {
      // NOTE: Share creates backup in app's internal storage (no permission needed)
      // then uses system share sheet. No explicit storage permission required.
      // FIX: Add loading feedback for Share operation with timeout protection
      await BackupHelper().shareDatabase(
        onProcessingStart: () {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const PopScope(
                canPop: false,
                child: AlertDialog(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: Spacing.lg),
                      Expanded(child: Text('Creating backup for sharing...')),
                    ],
                  ),
                ),
              ),
            ).timeout(
              const Duration(minutes: 3),
              onTimeout: () {
                throw TimeoutException('Share operation timed out');
              },
            );
            dialogShown = true;
          }
        },
      );

      // FIX: Close dialog if shown
      if (mounted && dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      // FIX: Refresh backup list after sharing (now populated in Recent Backups)
      await _loadBackups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup created and ready to share!'),
            backgroundColor: Theme.of(context).extension<AppColors>()!.incomeGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // FIX: Close dialog if shown
      if (mounted && dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getFriendlyErrorMessage(e)),
            backgroundColor: Theme.of(context).extension<AppColors>()!.expenseRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// FIX: Restore from a specific file (e.g., from Recent Backups list)
  Future<void> _restoreFromFile(File backupFile) async {
    // FIX: Prevent multiple simultaneous restores
    if (_isRestoring) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogTheme = Theme.of(context);
        final dialogAppColors = dialogTheme.extension<AppColors>()!;
        return AlertDialog(
          title: const Text('Restore Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Restore from "${backupFile.path.split(Platform.pathSeparator).last}"?',
                style: dialogTheme.textTheme.titleSmall,
              ),
              const SizedBox(height: Spacing.md),
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: dialogAppColors.infoBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                  border: Border.all(
                    color: dialogAppColors.infoBlue.withAlpha(100),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: dialogAppColors.infoBlue,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        'A safety backup of your current data will be created before restoring.',
                        style: dialogTheme.textTheme.bodySmall?.copyWith(
                          color: dialogTheme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'This will replace all current data.',
                style: dialogTheme.textTheme.bodyMedium?.copyWith(
                  color: dialogTheme.colorScheme.error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: dialogAppColors.warningOrange,
              ),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await _performRestore(sourceFile: backupFile);
  }

  /// FIX: Improved restore flow - file picker FIRST, then confirm (no UX friction if user cancels picker)
  Future<void> _restoreBackup() async {
    // FIX: Prevent multiple simultaneous restores
    if (_isRestoring) return;

    // NOTE: Android 13+ uses SAF (Storage Access Framework) via FilePicker
    // which handles permissions automatically - no explicit permission needed.
    // FIX: File picker is shown INSIDE restoreDatabase(), which will return 'cancelled' if user cancels
    // This eliminates the UX friction of showing a warning dialog before the user even selects a file
    await _performRestore();
  }

  /// FIX #1: Centralized restore logic with proper dialog state management
  Future<void> _performRestore({File? sourceFile}) async {
    setState(() => _isRestoring = true);

    // FIX #1: Track dialog state to prevent race conditions
    bool dialogShown = false;
    bool safetyBackupCreated = false;
    BuildContext? dialogContext;

    try {
      final appState = context.read<AppState>();

      // FIX #1: Start restore process with timeout protection, pass sourceFile if provided
      final result = await BackupHelper()
          .restoreDatabase(
        closeDatabase: () => appState.closeDatabase(),
        sourceFile: sourceFile,
        onStart: () {
          // FIX #1: Show dialog only when file is selected and processing begins
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                dialogContext =
                    context; // FIX #1: Store context for reliable cleanup
                return const PopScope(
                  canPop: false,
                  child: AlertDialog(
                    content: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: Spacing.lg),
                        Expanded(child: Text('Restoring backup...')),
                      ],
                    ),
                  ),
                );
              },
            );
            dialogShown = true;
            safetyBackupCreated = true;
          }
        },
      )
          .timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          throw TimeoutException('Restore operation timed out');
        },
      );

      // FIX #1: Close dialog if it was shown using stored context
      if (dialogShown && dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
        dialogShown = false;
        dialogContext = null;
      }

      if (!mounted) return;

      switch (result) {
        case RestoreResult.success:
          // FIX: Always reload data after restore to re-establish DB connection
          await appState.reloadAfterRestore();

          if (mounted) {
            // FIX: Show success message mentioning safety backup
            final message = safetyBackupCreated
                ? 'Backup restored successfully!\nA safety backup of your previous data was saved.'
                : 'Backup restored successfully!';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor:
                    Theme.of(context).extension<AppColors>()!.incomeGreen,
                duration: const Duration(seconds: 4),
              ),
            );

            // FIX: Stay on backup screen after restore instead of navigating away
            // Reload the backup list to show updated backups
            await _loadBackups();
          }
          break;

        case RestoreResult.cancelled:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restore cancelled'),
              duration: Duration(seconds: 2),
            ),
          );
          break;

        case RestoreResult.invalidFile:
          // FIX: Reload DB connection after error
          await appState.reloadAfterRestore();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Invalid backup file. Please select a valid database backup.',
                ),
                backgroundColor:
                    Theme.of(context).extension<AppColors>()!.expenseRed,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          break;

        case RestoreResult.incompatibleVersion:
          // FIX Bug #9: Backup was created by a newer app version whose
          // database schema the installed app cannot open. Tell the user
          // to update the app rather than silently failing on DB open.
          await appState.reloadAfterRestore();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'This backup was created with a newer version of Money Tracker. '
                  'Please update the app before restoring this backup.',
                ),
                backgroundColor:
                    Theme.of(context).extension<AppColors>()!.expenseRed,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          break;

        case RestoreResult.fileNotFound:
          // FIX: Reload DB connection after error
          await appState.reloadAfterRestore();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Backup file not found. It may have been moved or deleted.',
                ),
                backgroundColor:
                    Theme.of(context).extension<AppColors>()!.expenseRed,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          break;

        case RestoreResult.error:
          // FIX: CRITICAL - Reload DB connection after error to prevent app crash
          await appState.reloadAfterRestore();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Error restoring backup. Your data is safe. Please try again.',
                ),
                backgroundColor:
                    Theme.of(context).extension<AppColors>()!.expenseRed,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          break;
      }
    } catch (e) {
      // FIX #1: Close dialog if shown using stored context - prevents orphaned dialogs
      if (dialogShown && dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
        dialogShown = false;
        dialogContext = null;
      }
      if (mounted) {
        final appState = context.read<AppState>();
        await appState
            .reloadAfterRestore(); // FIX: Prevent orphaned DB connection
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getFriendlyErrorMessage(e)),
              backgroundColor:
                  Theme.of(context).extension<AppColors>()!.expenseRed,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      // FIX #1: Always clean up dialog and re-enable button
      if (dialogShown && dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  /// FIX: Toggle selection mode for bulk delete
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedBackups.clear();
      }
    });
  }

  /// FIX: Toggle backup selection
  void _toggleBackupSelection(String backupPath) {
    setState(() {
      if (_selectedBackups.contains(backupPath)) {
        _selectedBackups.remove(backupPath);
      } else {
        _selectedBackups.add(backupPath);
      }
    });
  }

  /// FIX: Select all visible backups
  void _selectAllBackups() {
    setState(() {
      _selectedBackups.clear();
      for (var backup in _backupsWithInfo) {
        _selectedBackups.add((backup['file'] as File).path);
      }
    });
  }

  /// FIX: Delete selected backups
  Future<void> _deleteSelectedBackups() async {
    if (_selectedBackups.isEmpty) return;

    final count = _selectedBackups.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backups'),
        content: Text(
          'Delete $count backup${count > 1 ? 's' : ''}?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).extension<AppColors>()!.expenseRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      int deleted = 0;
      for (var path in _selectedBackups.toList()) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await BackupHelper().deleteBackup(file);
            deleted++;
          }
        } catch (e) {
          // Continue deleting others even if one fails
          if (kDebugMode) debugPrint('Failed to delete $path: $e');
        }
      }

      if (mounted) {
        _selectedBackups.clear();
        _isSelectionMode = false;
        await _loadBackups();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deleted $deleted backup${deleted > 1 ? 's' : ''} successfully',
              ),
              backgroundColor:
                  Theme.of(context).extension<AppColors>()!.incomeGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getFriendlyErrorMessage(e)),
            backgroundColor:
                Theme.of(context).extension<AppColors>()!.expenseRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        title: Text(
          _isSelectionMode
              ? '${_selectedBackups.length} selected'
              : 'Backup & Restore',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: _isSelectionMode
            ? [
                if (_backupsWithInfo.isNotEmpty)
                  TextButton(
                    onPressed: _selectAllBackups,
                    child: const Text('Select All'),
                  ),
                if (_selectedBackups.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: theme.extension<AppColors>()!.expenseRed,
                    ),
                    onPressed: _deleteSelectedBackups,
                  ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBackups, // FIX: Pull-to-refresh capability
              child: ListView(
                padding: const EdgeInsets.all(Spacing.screenPadding),
                children: [
                  // Export Section
                  _SectionCard(
                    icon: Icons.backup,
                    title: 'Export Backup',
                    subtitle: 'Create a backup file of your data',
                    color: theme.colorScheme.primary,
                    child: Column(
                      children: [
                        const SizedBox(height: Spacing.sm),
                        // CRITICAL FIX: Clarify that Save Backup lets user choose location
                        ElevatedButton.icon(
                          onPressed: (_isExporting || _isRestoring)
                              ? null
                              : _exportBackup,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.save_alt),
                          label: Text(
                            _isExporting ? 'Creating...' : 'Save Backup',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                            vertical: Spacing.xxs,
                          ),
                          child: Text(
                            'Choose where to save the backup file',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        // CRITICAL FIX: Clarify that Share creates backup in app folder AND opens share menu
                        OutlinedButton.icon(
                          onPressed: (_isExporting || _isRestoring)
                              ? null
                              : _shareBackup,
                          icon: const Icon(Icons.share),
                          label: const Text('Share Backup'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                            vertical: Spacing.xxs,
                          ),
                          child: Text(
                            'Create backup and share via apps (also saved to Recent Backups)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Spacing.xl),

                  // Restore Section
                  _SectionCard(
                    icon: Icons.restore,
                    title: 'Restore Backup',
                    subtitle: 'Import data from a backup file',
                    color: theme.colorScheme.tertiary,
                    child: Column(
                      children: [
                        const SizedBox(height: Spacing.sm),
                        ElevatedButton.icon(
                          onPressed: (_isExporting || _isRestoring)
                              ? null
                              : _restoreBackup, // FIX: Disable during operations
                          icon: _isRestoring
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.upload),
                          label: Text(
                            _isRestoring
                                ? 'Restoring...'
                                : 'Choose Backup File',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.tertiary,
                            foregroundColor: theme.colorScheme.onTertiary,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          '⚠️ Warning: This will replace all current data',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Spacing.xl),

                  // FIX: Recent Backups header with bulk select button
                  Row(
                    children: [
                      Text(
                        'RECENT BACKUPS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (_backupsWithInfo.isNotEmpty && !_isSelectionMode)
                        TextButton.icon(
                          onPressed: _toggleSelectionMode,
                          icon: const Icon(Icons.checklist, size: 18),
                          label: const Text('Select'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),

                  if (_backupsWithInfo.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(Spacing.xl),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(Spacing.radiusLarge),
                      ),
                      child: Center(
                        child: Text(
                          'No backups found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // FIX: Show loaded backups (lazy loading) with selection mode support
                    ..._backupsWithInfo.map((backupInfo) {
                      final file = backupInfo['file'] as File;
                      final isSelected = _selectedBackups.contains(file.path);

                      return _BackupTile(
                        backup: file,
                        date: backupInfo['date'] as DateTime,
                        size: backupInfo['size'] as int,
                        isSelectionMode: _isSelectionMode,
                        isSelected: isSelected,
                        onTap: _isSelectionMode
                            ? () => _toggleBackupSelection(file.path)
                            : () => _restoreFromFile(
                                  file,
                                ), // FIX: Make tiles tappable for restore
                        onDelete: () async {
                          // FIX: Add error handling to delete operation with friendly messages
                          try {
                            final fileToDelete = backupInfo['file'] as File;
                            await BackupHelper().deleteBackup(fileToDelete);
                            await _loadBackups();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backup deleted successfully'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_getFriendlyErrorMessage(e)),
                                backgroundColor: Theme.of(context)
                                    .extension<AppColors>()!
                                    .expenseRed,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                      );
                    }),

                    // FIX: Show "Load More" button if there are more backups to load
                    if (_backupsWithInfo.length < _allBackupFiles.length) ...[
                      const SizedBox(height: Spacing.sm),
                      Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(Spacing.radiusMedium),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Showing ${_backupsWithInfo.length} of ${_allBackupFiles.length} backups',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: Spacing.sm),
                            OutlinedButton.icon(
                              onPressed: _loadingMore
                                  ? null
                                  : () => _loadBackups(loadMore: true),
                              icon: _loadingMore
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_downward),
                              label: Text(
                                _loadingMore
                                    ? 'Loading...'
                                    : 'Load More Backups',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 40),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Spacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Spacing.radiusLarge),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: color.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(Spacing.radiusMedium),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _BackupTile extends StatelessWidget {
  final File backup;
  final DateTime date;
  final int size;
  final VoidCallback onTap; // FIX: Add onTap for restore
  final VoidCallback onDelete;
  final bool isSelectionMode; // FIX: Selection mode support
  final bool isSelected; // FIX: Is this backup selected

  const _BackupTile({
    required this.backup,
    required this.date,
    required this.size,
    required this.onTap, // FIX: Required onTap parameter
    required this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedSize = BackupHelper().formatFileSize(size);

    final appColors = theme.extension<AppColors>()!;

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withAlpha(100)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Spacing.radiusMedium),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap, // FIX: Make tile tappable for restore or selection
        leading: isSelectionMode
            ? Checkbox(value: isSelected, onChanged: (_) => onTap())
            : Icon(Icons.save_alt, color: theme.colorScheme.primary),
        title: Text(
          DateFormat.yMMMd().add_jm().format(
                date,
              ), // FIX: Locale-aware date/time
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          isSelectionMode ? formattedSize : '$formattedSize • Tap to restore',
        ), // FIX: Different hint for selection mode
        trailing: isSelectionMode
            ? null
            : IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: appColors.expenseRed,
                ),
                onPressed: () async {
                  // FIX: Show backup date/time in delete confirmation
                  final formattedDate = DateFormat.yMMMd().add_jm().format(
                        date,
                      ); // FIX: Locale-aware
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      final dialogAppColors =
                          Theme.of(context).extension<AppColors>()!;
                      return AlertDialog(
                        title: const Text('Delete Backup'),
                        content: Text(
                          'Delete backup from $formattedDate?\n\nThis cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: dialogAppColors.expenseRed,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmed == true) {
                    onDelete();
                  }
                },
              ),
      ),
    );
  }
}
