import 'dart:io';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../models/income_model.dart';

/// CSV separator options for international compatibility.
/// Many European countries use semicolons because comma is their decimal separator.
enum CsvSeparator {
  comma(','),
  semicolon(';');

  final String value;
  const CsvSeparator(this.value);

  /// FIX: Auto-detect appropriate separator based on locale
  /// European locales typically use comma as decimal separator, so use semicolon for CSV
  static CsvSeparator fromLocale(String localeString) {
    // European locales that use comma as decimal separator
    const europeanLocales = [
      'de',
      'fr',
      'es',
      'it',
      'nl',
      'pl',
      'pt',
      'ru',
      'sv',
      'da',
      'fi',
      'no',
      'cs',
      'el',
      'hu',
      'ro',
      'sk',
      'tr',
      'bg',
      'hr',
      'et',
      'lv',
      'lt',
      'sl',
    ];

    final languageCode = localeString.split('_').first.toLowerCase();
    return europeanLocales.contains(languageCode)
        ? CsvSeparator.semicolon
        : CsvSeparator.comma;
  }
}

class CsvExporter {
  /// Exports expenses to CSV file.
  ///
  /// [separator] - Use [CsvSeparator.semicolon] for countries that use comma
  /// as decimal separator (Germany, France, Brazil, etc.) to ensure Excel compatibility.
  /// Default is [CsvSeparator.comma] for US/UK locales.
  static Future<File> exportExpenses(
    List<Expense> expenses,
    String currencySymbol, {
    CsvSeparator separator = CsvSeparator.comma,
  }) async {
    final now = DateTime.now();
    // M5: build the CSV body off the UI isolate — large exports otherwise
    // serialize every row + summary synchronously on the main thread.
    final csv = await compute(
      buildExpensesCsv,
      CsvExpenseParams(expenses, separator, now),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'expenses_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(csv);
    return file;
  }

  /// Builds the expense-report CSV body. Pure computation (no platform
  /// channels) so it is safe to run inside a `compute()` isolate.
  @visibleForTesting
  static String buildExpensesCsv(CsvExpenseParams params) {
    final expenses = params.expenses;
    final separator = params.separator;
    final now = params.now;
    final csvData = StringBuffer();
    final sep = separator.value;

    // Report header
    csvData.writeln('FinanceFlow - Expense Report');
    csvData.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}');
    csvData.writeln('');

    // Column header
    csvData.writeln(
      'Date${sep}Description${sep}Category${sep}Amount${sep}Paid${sep}Remaining${sep}Status',
    );

    // L23: accumulate the summary totals in Decimal-space so they fold the
    // same way app_state does (app_state.dart:2196) and the CSV summary rows
    // match the in-app figures bit-for-bit instead of drifting a cent over
    // large datasets. Per-row cells stay double (single values, 2dp).
    Decimal totalAmount = Decimal.zero;
    Decimal totalPaid = Decimal.zero;
    Decimal totalRemaining = Decimal.zero;
    final Map<String, Decimal> categoryTotals = {};

    for (final expense in expenses) {
      final date = DateFormat('yyyy-MM-dd').format(expense.date);
      final description = _escapeCsv(expense.description, separator);
      final category = _escapeCsv(expense.category, separator);
      final amount = _formatNumber(expense.amount, separator);
      final paid = _formatNumber(expense.amountPaid, separator);
      final remaining = _formatNumber(expense.remainingAmount, separator);
      final status = expense.isPaid ? 'Paid' : 'Unpaid';

      csvData.writeln(
        '$date$sep$description$sep$category$sep$amount$sep$paid$sep$remaining$sep$status',
      );

      // Accumulate totals
      totalAmount += expense.amountDecimal;
      totalPaid += expense.amountPaidDecimal;
      totalRemaining += expense.remainingAmountDecimal;
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? Decimal.zero) +
              expense.amountDecimal;
    }

    // Summary section
    csvData.writeln('');
    csvData.writeln('--- SUMMARY ---');
    csvData.writeln('Total Transactions$sep${expenses.length}');
    csvData.writeln(
      'Total Amount$sep${_formatNumber(totalAmount.toDouble(), separator)}',
    );
    csvData.writeln(
      'Total Paid$sep${_formatNumber(totalPaid.toDouble(), separator)}',
    );
    csvData.writeln(
      'Total Remaining$sep${_formatNumber(totalRemaining.toDouble(), separator)}',
    );
    csvData.writeln('');
    csvData.writeln('--- BY CATEGORY ---');
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedCategories) {
      csvData.writeln(
        '${_escapeCsv(entry.key, separator)}$sep${_formatNumber(entry.value.toDouble(), separator)}',
      );
    }

    return csvData.toString();
  }

  /// Formats a number for CSV export using locale-aware formatting.
  /// FIX: Use proper NumberFormat with locale instead of simple string replacement
  /// This correctly handles thousand separators and decimal points
  static String _formatNumber(
    double value,
    CsvSeparator separator, {
    String? locale,
  }) {
    // Use locale-specific number formatting
    final NumberFormat formatter;

    if (separator == CsvSeparator.semicolon) {
      // European format: use comma as decimal separator
      // Example locales: de_DE, fr_FR, etc.
      formatter = NumberFormat.decimalPattern(locale ?? 'de_DE');
    } else {
      // US/UK format: use dot as decimal separator
      formatter = NumberFormat.decimalPattern(locale ?? 'en_US');
    }

    // Force exactly 2 decimal places
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;

    return formatter.format(value);
  }

  /// Escapes a value for CSV, handling the separator character and formula injection.
  ///
  /// Security: Prevents CSV formula injection attacks by prefixing dangerous
  /// characters with a single quote. Excel/Sheets formulas start with =, +, -, @, etc.
  /// See OWASP: https://owasp.org/www-community/attacks/CSV_Injection
  static String _escapeCsv(String value, CsvSeparator separator) {
    if (value.isEmpty) return value;

    String result = value;

    // Prevent formula injection: prefix dangerous characters with single quote
    // This prevents =, +, -, @, tab, carriage return from being interpreted as formulas
    const dangerousPrefixes = ['=', '+', '-', '@', '\t', '\r'];
    if (dangerousPrefixes.any((prefix) => result.startsWith(prefix))) {
      result = "'$result";
    }

    // Check for the actual separator being used, quotes, and newlines
    if (result.contains(separator.value) ||
        result.contains('"') ||
        result.contains('\n')) {
      return '"${result.replaceAll('"', '""')}"';
    }
    return result;
  }

  /// Exports income to CSV file.
  static Future<File> exportIncome(
    List<Income> incomes,
    String currencySymbol, {
    CsvSeparator separator = CsvSeparator.comma,
  }) async {
    final now = DateTime.now();
    // M5: build off the UI isolate (see exportExpenses).
    final csv = await compute(
      buildIncomeCsv,
      CsvIncomeParams(incomes, separator, now),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'income_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(csv);
    return file;
  }

  /// Builds the income-report CSV body. Pure computation; `compute()`-safe.
  @visibleForTesting
  static String buildIncomeCsv(CsvIncomeParams params) {
    final incomes = params.incomes;
    final separator = params.separator;
    final now = params.now;
    final csvData = StringBuffer();
    final sep = separator.value;

    // Report header
    csvData.writeln('FinanceFlow - Income Report');
    csvData.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}');
    csvData.writeln('');

    // Column header
    csvData.writeln('Date${sep}Description${sep}Category${sep}Amount');

    // L23: Decimal-space accumulation (see buildExpensesCsv).
    Decimal totalAmount = Decimal.zero;
    final Map<String, Decimal> categoryTotals = {};

    for (final income in incomes) {
      final date = DateFormat('yyyy-MM-dd').format(income.date);
      final description = _escapeCsv(income.description, separator);
      final category = _escapeCsv(income.category, separator);
      final amount = _formatNumber(income.amount, separator);

      csvData.writeln('$date$sep$description$sep$category$sep$amount');

      // Accumulate totals
      totalAmount += income.amountDecimal;
      categoryTotals[income.category] =
          (categoryTotals[income.category] ?? Decimal.zero) +
              income.amountDecimal;
    }

    // Summary section
    csvData.writeln('');
    csvData.writeln('--- SUMMARY ---');
    csvData.writeln('Total Transactions$sep${incomes.length}');
    csvData.writeln(
      'Total Income$sep${_formatNumber(totalAmount.toDouble(), separator)}',
    );
    csvData.writeln('');
    csvData.writeln('--- BY CATEGORY ---');
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedCategories) {
      csvData.writeln(
        '${_escapeCsv(entry.key, separator)}$sep${_formatNumber(entry.value.toDouble(), separator)}',
      );
    }

    return csvData.toString();
  }

  /// Exports all transactions (expenses + income) to a single CSV file.
  static Future<File> exportAllTransactions(
    List<Expense> expenses,
    List<Income> incomes,
    String currencySymbol, {
    CsvSeparator separator = CsvSeparator.comma,
  }) async {
    final now = DateTime.now();
    // M5: build off the UI isolate (see exportExpenses).
    final csv = await compute(
      buildAllTransactionsCsv,
      CsvAllTxParams(expenses, incomes, separator, now),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'transactions_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(csv);
    return file;
  }

  /// Builds the combined-transactions CSV body. Pure computation; `compute()`-safe.
  @visibleForTesting
  static String buildAllTransactionsCsv(CsvAllTxParams params) {
    final expenses = params.expenses;
    final incomes = params.incomes;
    final separator = params.separator;
    final now = params.now;
    final csvData = StringBuffer();
    final sep = separator.value;

    // Report header
    csvData.writeln('FinanceFlow - All Transactions Report');
    csvData.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}');
    csvData.writeln('');

    // Column header
    csvData.writeln(
      'Date${sep}Type${sep}Description${sep}Category${sep}Amount${sep}Status',
    );

    // Combine and sort by date
    final allTransactions = <_TransactionRow>[];

    // L23: Decimal-space accumulation (see buildExpensesCsv).
    Decimal totalIncome = Decimal.zero;
    Decimal totalExpenses = Decimal.zero;

    for (final expense in expenses) {
      allTransactions.add(
        _TransactionRow(
          date: expense.date,
          type: 'Expense',
          description: expense.description,
          category: expense.category,
          amount: -expense.amount, // Negative for expenses
          status: expense.isPaid ? 'Paid' : 'Unpaid',
        ),
      );
      totalExpenses += expense.amountDecimal;
    }

    for (final income in incomes) {
      allTransactions.add(
        _TransactionRow(
          date: income.date,
          type: 'Income',
          description: income.description,
          category: income.category,
          amount: income.amount,
          status: '-',
        ),
      );
      totalIncome += income.amountDecimal;
    }

    // Sort by date descending
    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Data rows
    for (final transaction in allTransactions) {
      final date = DateFormat('yyyy-MM-dd').format(transaction.date);
      final type = transaction.type;
      final description = _escapeCsv(transaction.description, separator);
      final category = _escapeCsv(transaction.category, separator);
      final amount = _formatNumber(transaction.amount, separator);
      final status = transaction.status;

      csvData.writeln(
        '$date$sep$type$sep$description$sep$category$sep$amount$sep$status',
      );
    }

    // Summary section
    csvData.writeln('');
    csvData.writeln('--- SUMMARY ---');
    csvData.writeln('Total Transactions$sep${allTransactions.length}');
    csvData.writeln(
      'Total Income$sep${_formatNumber(totalIncome.toDouble(), separator)}',
    );
    csvData.writeln(
      'Total Expenses$sep${_formatNumber(totalExpenses.toDouble(), separator)}',
    );
    csvData.writeln(
      'Net Balance$sep${_formatNumber((totalIncome - totalExpenses).toDouble(), separator)}',
    );

    return csvData.toString();
  }
}

/// Internal class for combining transactions
class _TransactionRow {
  final DateTime date;
  final String type;
  final String description;
  final String category;
  final double amount;
  final String status;

  _TransactionRow({
    required this.date,
    required this.type,
    required this.description,
    required this.category,
    required this.amount,
    required this.status,
  });
}

/// `compute()` payload for [CsvExporter.buildExpensesCsv]. Public so the pure
/// builder can be unit-tested directly without spawning an isolate.
class CsvExpenseParams {
  final List<Expense> expenses;
  final CsvSeparator separator;
  final DateTime now;
  CsvExpenseParams(this.expenses, this.separator, this.now);
}

/// `compute()` payload for [CsvExporter.buildIncomeCsv].
class CsvIncomeParams {
  final List<Income> incomes;
  final CsvSeparator separator;
  final DateTime now;
  CsvIncomeParams(this.incomes, this.separator, this.now);
}

/// `compute()` payload for [CsvExporter.buildAllTransactionsCsv].
class CsvAllTxParams {
  final List<Expense> expenses;
  final List<Income> incomes;
  final CsvSeparator separator;
  final DateTime now;
  CsvAllTxParams(this.expenses, this.incomes, this.separator, this.now);
}
