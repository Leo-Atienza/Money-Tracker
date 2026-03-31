// FIX #9, #16, #50: Comprehensive dialog helpers for confirmations and warnings
import 'package:flutter/material.dart';
import '../constants/spacing.dart';
import '../main.dart';
import 'haptic_helper.dart';

class DialogHelpers {
  /// FIX #9: Budget deletion warning with mid-month impact
  static Future<bool> showBudgetDeletionWarning(
    BuildContext context, {
    required String categoryName,
    required double currentSpending,
    required double budgetAmount,
    required String currency,
  }) async {
    await HapticHelper.mediumImpact();

    if (!context.mounted) return false;

    final appColors = Theme.of(context).extension<AppColors>()!;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: appColors.warningOrange),
            SizedBox(width: Spacing.sm),
            const Text('Delete Budget?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to delete the budget for "$categoryName".'),
            SizedBox(height: Spacing.md),
            Container(
              padding: EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: appColors.warningOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                border: Border.all(color: appColors.warningOrange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Status:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: Spacing.xs),
                  Text('Budget: $currency${budgetAmount.toStringAsFixed(2)}'),
                  Text('Spent: $currency${currentSpending.toStringAsFixed(2)}'),
                  SizedBox(height: Spacing.xs),
                  const Text(
                    '⚠️ Deleting this budget will:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Text('• Remove budget tracking for this category'),
                  const Text('• Stop budget alerts for remaining days'),
                  const Text('• Cannot be undone'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: appColors.expenseRed),
            child: const Text('Delete Budget'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// FIX #50: Currency conversion warning
  static Future<String?> showCurrencyChangeWarning(
    BuildContext context, {
    required String oldCurrency,
    required String newCurrency,
    required int transactionCount,
  }) async {
    await HapticHelper.mediumImpact();

    if (!context.mounted) return null;

    final appColors = Theme.of(context).extension<AppColors>()!;

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: appColors.warningOrange),
            SizedBox(width: Spacing.sm),
            const Text('Change Currency?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are changing currency from $oldCurrency to $newCurrency.',
            ),
            SizedBox(height: Spacing.md),
            Text('You have $transactionCount existing transactions.'),
            SizedBox(height: Spacing.md),
            Container(
              padding: EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: appColors.infoBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                border: Border.all(color: appColors.infoBlue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose how to handle existing amounts:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: Spacing.sm),
                  const Text('1. Keep amounts as-is (Recommended)'),
                  const Text('   Example: \$100 becomes ₹100'),
                  SizedBox(height: Spacing.xs),
                  const Text('2. Clear all data and start fresh'),
                  const Text('   Permanently deletes all transactions'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'clear'),
            style: TextButton.styleFrom(foregroundColor: appColors.expenseRed),
            child: const Text('Clear All Data'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Keep Amounts'),
          ),
        ],
      ),
    );
  }

  /// FIX #16: Future date confirmation with "Don't ask again this session" option
  static bool _skipFutureDateWarning = false;

  static Future<bool> showFutureDateConfirmation(
    BuildContext context,
    DateTime selectedDate,
  ) async {
    // Skip if user chose "Don't ask again"
    if (_skipFutureDateWarning) return true;

    await HapticHelper.lightImpact();

    if (!context.mounted) return false;

    final appColors = Theme.of(context).extension<AppColors>()!;

    bool dontAskAgain = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.calendar_today, color: appColors.infoBlue),
              SizedBox(width: Spacing.sm),
              const Text('Future Date'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You selected a future date: ${_formatDate(selectedDate)}'),
              SizedBox(height: Spacing.md),
              const Text(
                'This transaction will be created with a future date.',
              ),
              SizedBox(height: Spacing.md),
              CheckboxListTile(
                value: dontAskAgain,
                onChanged: (value) {
                  setState(() {
                    dontAskAgain = value ?? false;
                  });
                },
                title: const Text(
                  "Don't ask again this session",
                  style: TextStyle(fontSize: 14),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Change Date'),
            ),
            FilledButton(
              onPressed: () {
                if (dontAskAgain) {
                  _skipFutureDateWarning = true;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  /// Reset future date warning flag (call on app restart)
  static void resetFutureDateWarning() {
    _skipFutureDateWarning = false;
  }

  static String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Generic confirmation dialog
  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDangerous = false,
  }) async {
    await HapticHelper.lightImpact();

    if (!context.mounted) return false;

    final appColors = Theme.of(context).extension<AppColors>()!;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDangerous
                ? FilledButton.styleFrom(backgroundColor: appColors.expenseRed)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
