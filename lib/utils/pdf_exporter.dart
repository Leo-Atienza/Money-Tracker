import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../models/income_model.dart';
import '../models/budget_model.dart';

/// Helper class for exporting financial data to PDF format
/// Provides professional-looking PDF reports for expenses, income, and budgets
class PdfExporter {
  /// Export expenses to PDF with optional filtering by date range and category
  static Future<File> exportExpensesToPdf({
    required List<Expense> expenses,
    required String currencySymbol,
    required String currencyCode,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat.yMMMd();
    final now = DateTime.now();
    final reportTitle = title ?? 'Expense Report';

    // Group expenses by category for summary
    final Map<String, double> categoryTotals = {};
    double grandTotal = 0.0;

    for (final expense in expenses) {
      categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0.0) + expense.amount;
      grandTotal += expense.amount;
    }

    // Sort categories by amount (descending)
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated: ${dateFormat.format(now)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if (startDate != null && endDate != null)
                    pw.Text(
                      'Period: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  if (category != null)
                    pw.Text(
                      'Category: $category',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Expenses:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        '$currencySymbol${grandTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Number of Transactions:'),
                      pw.Text('${expenses.length}'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Category Breakdown
            if (sortedCategories.isNotEmpty) ...[
              pw.Text(
                'Category Breakdown',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Percentage', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Data rows with alternating colors
                  ...sortedCategories.asMap().entries.map((mapEntry) {
                    final index = mapEntry.key;
                    final entry = mapEntry.value;
                    final percentage = grandTotal > 0 ? (entry.value / grandTotal * 100) : 0.0;
                    final isEvenRow = index % 2 == 0;
                    return pw.TableRow(
                      decoration: isEvenRow
                          ? const pw.BoxDecoration(color: PdfColors.grey50)
                          : null,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(entry.key),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$currencySymbol${entry.value.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${percentage.toStringAsFixed(1)}%'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // Detailed Transaction List
            pw.Text(
              'Detailed Transactions',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                  ],
                ),
                // Data rows with alternating colors
                ...expenses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final expense = entry.value;
                  final isEvenRow = index % 2 == 0;
                  return pw.TableRow(
                    decoration: isEvenRow
                        ? const pw.BoxDecoration(color: PdfColors.grey50)
                        : null,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(dateFormat.format(expense.date), style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(expense.description, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(expense.category, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(expense.paymentMethod, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '$currencySymbol${expense.amount.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),

            // Footer
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Money Tracker - Financial Report',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    // Save the PDF file
    final output = await getTemporaryDirectory();
    final fileName = 'expense_report_${now.millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Export income to PDF
  static Future<File> exportIncomeToPdf({
    required List<Income> incomes,
    required String currencySymbol,
    required String currencyCode,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat.yMMMd();
    final now = DateTime.now();
    final reportTitle = title ?? 'Income Report';

    // Group income by category for summary
    final Map<String, double> categoryTotals = {};
    double grandTotal = 0.0;

    for (final income in incomes) {
      categoryTotals[income.category] = (categoryTotals[income.category] ?? 0.0) + income.amount;
      grandTotal += income.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated: ${dateFormat.format(now)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if (startDate != null && endDate != null)
                    pw.Text(
                      'Period: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Income:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        '$currencySymbol${grandTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Number of Transactions:'),
                      pw.Text('${incomes.length}'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Category Breakdown (similar to expenses)
            if (sortedCategories.isNotEmpty) ...[
              pw.Text(
                'Category Breakdown',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Percentage', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Data rows with alternating colors
                  ...sortedCategories.asMap().entries.map((mapEntry) {
                    final index = mapEntry.key;
                    final entry = mapEntry.value;
                    final percentage = grandTotal > 0 ? (entry.value / grandTotal * 100) : 0.0;
                    final isEvenRow = index % 2 == 0;
                    return pw.TableRow(
                      decoration: isEvenRow
                          ? const pw.BoxDecoration(color: PdfColors.grey50)
                          : null,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(entry.key),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$currencySymbol${entry.value.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${percentage.toStringAsFixed(1)}%'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // Detailed Transaction List
            pw.Text(
              'Detailed Transactions',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Data rows with alternating colors
                ...incomes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final income = entry.value;
                  final isEvenRow = index % 2 == 0;
                  return pw.TableRow(
                    decoration: isEvenRow
                        ? const pw.BoxDecoration(color: PdfColors.grey50)
                        : null,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(dateFormat.format(income.date)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(income.description),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(income.category),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$currencySymbol${income.amount.toStringAsFixed(2)}'),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final fileName = 'income_report_${now.millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Export monthly summary to PDF (expenses + income + budgets)
  static Future<File> exportMonthlySummaryToPdf({
    required List<Expense> expenses,
    required List<Income> incomes,
    required List<Budget> budgets,
    required String currencySymbol,
    required String currencyCode,
    required String monthName,
    required double totalIncome,
    required double totalExpenses,
    required double balance,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat.yMMMd();
    final now = DateTime.now();

    // Calculate category spending
    final Map<String, double> categorySpending = {};
    for (final expense in expenses) {
      categorySpending[expense.category] = (categorySpending[expense.category] ?? 0.0) + expense.amount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Monthly Financial Summary',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    monthName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.Text(
                    'Generated: ${dateFormat.format(now)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Financial Overview
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Income:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        '$currencySymbol${totalIncome.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Expenses:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        '$currencySymbol${totalExpenses.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Net Balance:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        '$currencySymbol${balance.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: balance >= 0 ? PdfColors.green700 : PdfColors.red700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Budget Performance
            if (budgets.isNotEmpty) ...[
              pw.Text(
                'Budget Performance',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Budget', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Spent', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...budgets.map((budget) {
                    final spent = categorySpending[budget.category] ?? 0.0;
                    final percentage = budget.amount > 0 ? (spent / budget.amount * 100) : 0.0;
                    final status = percentage > 100 ? 'Over' : percentage > 90 ? 'Warning' : 'On Track';

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(budget.category),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$currencySymbol${budget.amount.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$currencySymbol${spent.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '$status (${percentage.toStringAsFixed(0)}%)',
                            style: pw.TextStyle(
                              color: percentage > 100
                                  ? PdfColors.red700
                                  : percentage > 90
                                      ? PdfColors.orange700
                                      : PdfColors.green700,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final fileName = 'monthly_summary_${now.millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }
}
