// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../utils/csv_exporter.dart';
import '../utils/pdf_exporter.dart';
import '../utils/haptic_helper.dart';

/// Screen for exporting transaction data to various formats
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  // Export options
  String _exportType = 'all'; // 'all', 'expenses', 'income'
  String _dateRange = 'all_time'; // 'all_time', 'this_month', 'last_month', 'this_year', 'custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Export Data',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Export your transactions as a CSV file that can be opened in Excel, Google Sheets, or other spreadsheet applications.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Data Type Section
            Text(
              'DATA TO EXPORT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
              iconColor: Colors.green,
              isSelected: _exportType == 'income',
              onTap: () => setState(() => _exportType = 'income'),
            ),

            const SizedBox(height: 32),

            // Date Range Section
            Text(
              'DATE RANGE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDateChip(theme, 'All Time', 'all_time'),
                _buildDateChip(theme, 'This Month', 'this_month'),
                _buildDateChip(theme, 'Last Month', 'last_month'),
                _buildDateChip(theme, 'This Year', 'this_year'),
                _buildDateChip(theme, 'Custom Range', 'custom'),
              ],
            ),

            // Custom date range picker
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

            // PDF Export button
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

            // Note about formats
            Center(
              child: Text(
                'CSV for spreadsheets • PDF for professional reports',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
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
    return InkWell(
      onTap: () {
        HapticHelper.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(20)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withAlpha(30)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(ThemeData theme, String label, String value) {
    final isSelected = _dateRange == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        HapticHelper.lightImpact();
        setState(() {
          _dateRange = value;
          if (value != 'custom') {
            _customStartDate = null;
            _customEndDate = null;
          }
        });
      },
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primary.withAlpha(30),
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
                Text(
                  date != null
                      ? DateFormat.yMMMd().format(date)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: date != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
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
    final initialDate = isStart
        ? (_customStartDate ?? now)
        : (_customEndDate ?? now);

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
          // Ensure end date is not before start date
          if (_customEndDate != null && _customEndDate!.isBefore(date)) {
            _customEndDate = date;
          }
        } else {
          _customEndDate = date;
          // Ensure start date is not after end date
          if (_customStartDate != null && _customStartDate!.isAfter(date)) {
            _customStartDate = date;
          }
        }
      });
    }
  }

  Future<void> _exportData() async {
    // Validate custom date range
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

      // Get date range
      final DateTimeRange? dateFilter = _getDateRange();

      // Get all data from database
      final allExpenses = await appState.getAllExpensesForBackup();
      final allIncome = await appState.getAllIncomesForBackup();

      // Filter by date range if applicable
      final filteredExpenses = dateFilter != null
          ? allExpenses.where((e) =>
              !e.date.isBefore(dateFilter.start) &&
              !e.date.isAfter(dateFilter.end)).toList()
          : allExpenses;

      final filteredIncome = dateFilter != null
          ? allIncome.where((i) =>
              !i.date.isBefore(dateFilter.start) &&
              !i.date.isAfter(dateFilter.end)).toList()
          : allIncome;

      // Determine separator based on locale
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
          exportMessage = '${filteredExpenses.length + filteredIncome.length} transactions exported';
      }

      // Share the file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Money Tracker Export',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exportMessage),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
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
    // Validate custom date range
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

      // Get date range
      final DateTimeRange? dateFilter = _getDateRange();

      // Get all data from database
      final allExpenses = await appState.getAllExpensesForBackup();
      final allIncome = await appState.getAllIncomesForBackup();

      // Filter by date range if applicable
      final filteredExpenses = dateFilter != null
          ? allExpenses.where((e) =>
              !e.date.isBefore(dateFilter.start) &&
              !e.date.isAfter(dateFilter.end)).toList()
          : allExpenses;

      final filteredIncome = dateFilter != null
          ? allIncome.where((i) =>
              !i.date.isBefore(dateFilter.start) &&
              !i.date.isAfter(dateFilter.end)).toList()
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
          exportMessage = 'PDF report created with ${filteredExpenses.length} expenses';
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
          exportMessage = 'PDF report created with ${filteredIncome.length} income records';
          break;
        default:
          // For "all transactions", create a summary report
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
            totalExpenses: filteredExpenses.fold(0.0, (sum, e) => sum + e.amount),
            balance: filteredIncome.fold(0.0, (sum, i) => sum + i.amount) -
                    filteredExpenses.fold(0.0, (sum, e) => sum + e.amount),
          );
          exportMessage = 'PDF summary created with ${filteredExpenses.length + filteredIncome.length} transactions';
      }

      // Share the file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Money Tracker PDF Report',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exportMessage),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
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
            end: DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59),
          );
        }
        return null;
      default:
        return null; // all_time
    }
  }
}
