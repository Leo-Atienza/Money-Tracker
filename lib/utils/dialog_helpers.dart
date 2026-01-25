// FIX #9, #16, #50: Comprehensive dialog helpers for confirmations and warnings
import 'package:flutter/material.dart';
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

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Delete Budget?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to delete the budget for "$categoryName".'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Status:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Budget: $currency${budgetAmount.toStringAsFixed(2)}'),
                  Text('Spent: $currency${currentSpending.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Change Currency?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are changing currency from $oldCurrency to $newCurrency.'),
            const SizedBox(height: 16),
            Text('You have $transactionCount existing transactions.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Choose how to handle existing amounts:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text('1. Keep amounts as-is (Recommended)'),
                  Text('   Example: \$100 becomes ₹100'),
                  SizedBox(height: 8),
                  Text('2. Clear all data and start fresh'),
                  Text('   Permanently deletes all transactions'),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

    bool dontAskAgain = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue),
              SizedBox(width: 12),
              Text('Future Date'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You selected a future date: ${_formatDate(selectedDate)}'),
              const SizedBox(height: 16),
              const Text('This transaction will be created with a future date.'),
              const SizedBox(height: 16),
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
