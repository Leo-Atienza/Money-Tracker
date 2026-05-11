import 'package:flutter/material.dart';

import '../utils/color_contrast_helper.dart';

/// Semantic color extension for expense/income/warning/info colors.
/// Uses WCAG-compliant colors from ColorContrastHelper.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color expenseRed;
  final Color incomeGreen;
  final Color warningOrange;
  final Color infoBlue;

  const AppColors({
    required this.expenseRed,
    required this.incomeGreen,
    required this.warningOrange,
    required this.infoBlue,
  });

  factory AppColors.fromBrightness(Brightness brightness) {
    final status = ColorContrastHelper.getStatusColors(brightness);
    return AppColors(
      expenseRed: status.error,
      incomeGreen: status.success,
      warningOrange: status.warning,
      infoBlue: status.info,
    );
  }

  @override
  AppColors copyWith({
    Color? expenseRed,
    Color? incomeGreen,
    Color? warningOrange,
    Color? infoBlue,
  }) {
    return AppColors(
      expenseRed: expenseRed ?? this.expenseRed,
      incomeGreen: incomeGreen ?? this.incomeGreen,
      warningOrange: warningOrange ?? this.warningOrange,
      infoBlue: infoBlue ?? this.infoBlue,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      expenseRed: Color.lerp(expenseRed, other.expenseRed, t)!,
      incomeGreen: Color.lerp(incomeGreen, other.incomeGreen, t)!,
      warningOrange: Color.lerp(warningOrange, other.warningOrange, t)!,
      infoBlue: Color.lerp(infoBlue, other.infoBlue, t)!,
    );
  }
}
