// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/luminous_tokens.dart';
import '../utils/csv_exporter.dart';
import '../utils/pdf_exporter.dart';
import '../utils/haptic_helper.dart';
import '../widgets/luminous/glass_panel.dart';
import '../widgets/luminous/glass_pill_chip.dart';
import '../widgets/luminous/glass_top_app_bar.dart';

/// Phase 5.9e — Export Data Luminous redesign.
///
/// Composition:
///   * [GlassTopAppBar] header ("Export Data") with BackButton leading.
///   * Info banner wrapped in [GlassPanel].
///   * Each "Data to Export" option rendered as a [GlassPanel]-wrapped
///     row (replaces the hand-rolled bordered container) with the
///     selection state still indicated by a check icon + primary tint.
///   * Date-range filter chips swapped to [GlassPillChip].
///   * Custom-range buttons reuse the Luminous panel surface so the
///     selection state reads consistently with the rest of the screen.
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  String _exportType = 'all'; // 'all', 'expenses', 'income'
  String _dateRange = 'all_time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTopAppBar(
            leading: BackButton(color: theme.colorScheme.onSurface),
            title: 'Export Data',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                LuminousTokens.containerPadding,
                LuminousTokens.stackGap,
                LuminousTokens.containerPadding,
                LuminousTokens.sectionMargin,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info banner
                  GlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Export your transactions as a CSV file that can be opened in Excel, Google Sheets, or other spreadsheet applications.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LuminousTokens.sectionMargin),

                  // Data To Export header
                  _SectionHeader(theme: theme, label: 'DATA TO EXPORT'),
                  const SizedBox(height: 12),
                  _buildOptionCard(
                    theme: theme,
                    title: 'All Transactions',
                    subtitle: 'Expenses and income combined',
                    icon: Icons.all_inclusive,
                    isSelected: _exportType == 'all',
                    onTap: () => setState(() => _exportType = 'all'),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionCard(
                    theme: theme,
                    title: 'Expenses Only',
                    subtitle: 'Only expense transactions',
                    icon: Icons.arrow_upward,
                    isSelected: _exportType == 'expenses',
                    onTap: () => setState(() => _exportType = 'expenses'),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionCard(
                    theme: theme,
                    title: 'Income Only',
                    subtitle: 'Only income transactions',
                    icon: Icons.arrow_downward,
                    iconColor: appColors.incomeGreen,
                    isSelected: _exportType == 'income',
                    onTap: () => setState(() => _exportType = 'income'),
                  ),
                  const SizedBox(height: LuminousTokens.sectionMargin),

                  // Date Range header
                  _SectionHeader(theme: theme, label: 'DATE RANGE'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDateChip('All Time', 'all_time'),
                      _buildDateChip('This Month', 'this_month'),
                      _buildDateChip('Last Month', 'last_month'),
                      _buildDateChip('This Year', 'this_year'),
                      _buildDateChip('Custom Range', 'custom'),
                    ],
                  ),
                  if (_dateRange == 'custom') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateButton(
                            theme: theme,
                            label: 'Start Date',
                            date: _customStartDate,
                            onTap: () => _selectDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateButton(
                            theme: theme,
                            label: 'End Date',
                            date: _customEndDate,
                            onTap: () => _selectDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Export buttons
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isExporting ? null : _exportData,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.file_download),
                      label: Text(_isExporting ? 'Exporting...' : 'Export to CSV'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : _exportToPdf,
                      icon: _isExporting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_isExporting ? 'Exporting...' : 'Export to PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'CSV for spreadsheets • PDF for professional reports',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tint = isSelected ? theme.colorScheme.primary : null;
    return InkWell(
      onTap: () {
        HapticHelper.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(LuminousTokens.radiusLg),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (tint ?? theme.colorScheme.onSurface)
                    .withValues(alpha: isSelected ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? (tint ?? theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, String value) {
    return GlassPillChip(
      label: label,
      selected: _dateRange == value,
      onTap: () {
        HapticHelper.lightImpact();
        setState(() {
          _dateRange = value;
          if (value != 'custom') {
            _customStartDate = null;
            _customEndDate = null;
          }
        });
      },
    );
  }

  Widget _buildDateButton({
    required ThemeData theme,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LuminousTokens.radiusLg),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat.yMMMd().format(date)
                        : 'Select date',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: date != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate =
        isStart ? (_customStartDate ?? now) : (_customEndDate ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _customStartDate = date;
          if (_customEndDate != null && _customEndDate!.isBefore(date)) {
            _customEndDate = date;
          }
        } else {
          _customEndDate = date;
          if (_customStartDate != null && _customStartDate!.isAfter(date)) {
            _customStartDate = date;
          }
        }
      });
    }
  }

  Future<void> _exportData() async {
    if (_dateRange == 'custom') {
      if (_customStartDate == null || _customEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both start and end dates'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isExporting = true);
    await HapticHelper.mediumImpact();

    try {
      final appState = context.read<AppState>();
      final appColors = Theme.of(context).extension<AppColors>()!;

      final DateTimeRange? dateFilter = _getDateRange();

      final allExpenses = await appState.getAllExpensesForBackup();
      final allIncome = await appState.getAllIncomesForBackup();

      final filteredExpenses = dateFilter != null
          ? allExpenses
              .where(
                (e) =>
                    !e.date.isBefore(dateFilter.start) &&
                    !e.date.isAfter(dateFilter.end),
              )
              .toList()
          : allExpenses;

      final filteredIncome = dateFilter != null
          ? allIncome
              .where(
                (i) =>
                    !i.date.isBefore(dateFilter.start) &&
                    !i.date.isAfter(dateFilter.end),
              )
              .toList()
          : allIncome;

      final locale = Localizations.localeOf(context).toString();
      final separator = CsvSeparator.fromLocale(locale);

      File file;
      String exportMessage;

      switch (_exportType) {
        case 'expenses':
          file = await CsvExporter.exportExpenses(
            filteredExpenses,
            appState.currency,
            separator: separator,
          );
          exportMessage = '${filteredExpenses.length} expenses exported';
          break;
        case 'income':
          file = await CsvExporter.exportIncome(
            filteredIncome,
            appState.currency,
            separator: separator,
          );
          exportMessage = '${filteredIncome.length} income records exported';
          break;
        default:
          file = await CsvExporter.exportAllTransactions(
            filteredExpenses,
            filteredIncome,
            appState.currency,
            separator: separator,
          );
          exportMessage =
              '${filteredExpenses.length + filteredIncome.length} transactions exported';
      }

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'FinanceFlow Export'),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exportMessage),
            behavior: SnackBarBehavior.floating,
            backgroundColor: appColors.incomeGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: appColors.expenseRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportToPdf() async {
    if (_dateRange == 'custom') {
      if (_customStartDate == null || _customEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both start and end dates'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isExporting = true);
    await HapticHelper.mediumImpact();

    try {
      final appState = context.read<AppState>();
      final appColors = Theme.of(context).extension<AppColors>()!;

      final DateTimeRange? dateFilter = _getDateRange();

      final allExpenses = await appState.getAllExpensesForBackup();
      final allIncome = await appState.getAllIncomesForBackup();

      final filteredExpenses = dateFilter != null
          ? allExpenses
              .where(
                (e) =>
                    !e.date.isBefore(dateFilter.start) &&
                    !e.date.isAfter(dateFilter.end),
              )
              .toList()
          : allExpenses;

      final filteredIncome = dateFilter != null
          ? allIncome
              .where(
                (i) =>
                    !i.date.isBefore(dateFilter.start) &&
                    !i.date.isAfter(dateFilter.end),
              )
              .toList()
          : allIncome;

      File file;
      String exportMessage;

      switch (_exportType) {
        case 'expenses':
          file = await PdfExporter.exportExpensesToPdf(
            expenses: filteredExpenses,
            currencySymbol: appState.currency,
            currencyCode: appState.currencyCode,
            title: 'Expense Report',
            startDate: dateFilter?.start,
            endDate: dateFilter?.end,
          );
          exportMessage =
              'PDF report created with ${filteredExpenses.length} expenses';
          break;
        case 'income':
          file = await PdfExporter.exportIncomeToPdf(
            incomes: filteredIncome,
            currencySymbol: appState.currency,
            currencyCode: appState.currencyCode,
            title: 'Income Report',
            startDate: dateFilter?.start,
            endDate: dateFilter?.end,
          );
          exportMessage =
              'PDF report created with ${filteredIncome.length} income records';
          break;
        default:
          final budgets = appState.currentMonthBudgets;
          final monthName = DateFormat.yMMMM().format(appState.selectedMonth);

          file = await PdfExporter.exportMonthlySummaryToPdf(
            expenses: filteredExpenses,
            incomes: filteredIncome,
            budgets: budgets,
            currencySymbol: appState.currency,
            currencyCode: appState.currencyCode,
            monthName: monthName,
            totalIncome: filteredIncome.fold(0.0, (sum, i) => sum + i.amount),
            totalExpenses: filteredExpenses.fold(
              0.0,
              (sum, e) => sum + e.amount,
            ),
            balance: filteredIncome.fold(0.0, (sum, i) => sum + i.amount) -
                filteredExpenses.fold(0.0, (sum, e) => sum + e.amount),
          );
          exportMessage =
              'PDF summary created with ${filteredExpenses.length + filteredIncome.length} transactions';
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'FinanceFlow PDF Report',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exportMessage),
            behavior: SnackBarBehavior.floating,
            backgroundColor: appColors.incomeGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: appColors.expenseRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  DateTimeRange? _getDateRange() {
    final now = DateTime.now();

    switch (_dateRange) {
      case 'this_month':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return DateTimeRange(
          start: lastMonth,
          end: DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59),
        );
      case 'this_year':
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          return DateTimeRange(
            start: _customStartDate!,
            end: DateTime(
              _customEndDate!.year,
              _customEndDate!.month,
              _customEndDate!.day,
              23,
              59,
              59,
            ),
          );
        }
        return null;
      default:
        return null; // all_time
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final ThemeData theme;
  final String label;
  const _SectionHeader({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
