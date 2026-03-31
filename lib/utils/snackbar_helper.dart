// FIX #27: Consistent SnackBar styling across the app
import 'package:flutter/material.dart';
import '../constants/spacing.dart';
import '../main.dart';

class SnackBarHelper {
  /// Show success message
  /// FIX #27: Consistent green styling for success messages
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    final appColors = Theme.of(context).extension<AppColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: Spacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: appColors.incomeGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusSmall),
        ),
      ),
    );
  }

  /// Show error message
  /// FIX #27: Consistent red styling for errors
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;

    final appColors = Theme.of(context).extension<AppColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            SizedBox(width: Spacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: appColors.expenseRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusSmall),
        ),
      ),
    );
  }

  /// Show warning message
  /// FIX #27: Consistent orange styling for warnings
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    final appColors = Theme.of(context).extension<AppColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            SizedBox(width: Spacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: appColors.warningOrange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusSmall),
        ),
      ),
    );
  }

  /// Show info message
  /// FIX #27: Consistent blue styling for information
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;

    final appColors = Theme.of(context).extension<AppColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            SizedBox(width: Spacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: appColors.infoBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusSmall),
        ),
      ),
    );
  }

  /// Show undo snackbar with action
  /// FIX #22: Consistent undo styling
  static void showUndo(
    BuildContext context,
    String message,
    VoidCallback onUndo,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusSmall),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.yellow[700],
          onPressed: onUndo,
        ),
      ),
    );
  }
}
