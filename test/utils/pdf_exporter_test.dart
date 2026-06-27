import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:budget_tracker/utils/pdf_exporter.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/models/budget_model.dart';

/// M5: the PDF build bodies were moved into static `compute()`-safe builders so
/// they run off the UI isolate. PDF rendering can't be meaningfully asserted in
/// a unit test, so we lock the output structurally: the builders must return a
/// well-formed PDF byte stream (magic header + EOF marker) for a small dataset.
void main() {
  // %PDF — the PDF magic header bytes every document must start with.
  const pdfMagic = [0x25, 0x50, 0x44, 0x46];
  // %%EOF — the trailer marker that closes a PDF.
  const eofMarker = [0x25, 0x25, 0x45, 0x4F, 0x46];

  bool startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  /// True if [needle] occurs anywhere within [bytes].
  bool containsBytes(Uint8List bytes, List<int> needle) {
    if (needle.isEmpty || bytes.length < needle.length) return false;
    for (var i = 0; i <= bytes.length - needle.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (bytes[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  void expectWellFormedPdf(Uint8List bytes) {
    expect(bytes, isNotEmpty);
    expect(
      startsWith(bytes, pdfMagic),
      isTrue,
      reason: 'PDF bytes must begin with the %PDF magic header',
    );
    expect(
      containsBytes(bytes, eofMarker),
      isTrue,
      reason: 'PDF bytes must contain the %%EOF trailer marker',
    );
  }

  final expenses = <Expense>[
    Expense(
      amount: Decimal.parse('12.34'),
      category: 'Food',
      description: 'Lunch',
      date: DateTime(2024, 1, 1),
      accountId: 1,
    ),
    Expense(
      amount: Decimal.parse('56.78'),
      category: 'Transport',
      description: 'Bus pass',
      date: DateTime(2024, 1, 2),
      accountId: 1,
      amountPaid: Decimal.parse('56.78'),
    ),
  ];

  final incomes = <Income>[
    Income(
      amount: Decimal.parse('1000.00'),
      category: 'Salary',
      description: 'Monthly pay',
      date: DateTime(2024, 1, 1),
      accountId: 1,
    ),
    Income(
      amount: Decimal.parse('25.50'),
      category: 'Gift',
      description: 'Birthday',
      date: DateTime(2024, 1, 3),
      accountId: 1,
    ),
  ];

  final budgets = <Budget>[
    Budget(
      category: 'Food',
      amount: Decimal.parse('200.00'),
      accountId: 1,
      month: DateTime(2024, 1),
    ),
  ];

  final now = DateTime(2024, 1, 15, 9, 30);

  group('PdfExporter.buildExpensesPdf', () {
    test('produces a well-formed PDF for a small dataset', () async {
      final bytes = await PdfExporter.buildExpensesPdf(
        PdfExpenseParams(
          expenses: expenses,
          currencySymbol: r'$',
          title: 'Expense Report',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          category: null,
          now: now,
        ),
      );
      expectWellFormedPdf(bytes);
    });

    test('produces a well-formed PDF for an empty dataset', () async {
      final bytes = await PdfExporter.buildExpensesPdf(
        PdfExpenseParams(
          expenses: const [],
          currencySymbol: r'$',
          title: null,
          startDate: null,
          endDate: null,
          category: null,
          now: now,
        ),
      );
      expectWellFormedPdf(bytes);
    });
  });

  group('PdfExporter.buildIncomePdf', () {
    test('produces a well-formed PDF for a small dataset', () async {
      final bytes = await PdfExporter.buildIncomePdf(
        PdfIncomeParams(
          incomes: incomes,
          currencySymbol: r'$',
          title: 'Income Report',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          now: now,
        ),
      );
      expectWellFormedPdf(bytes);
    });
  });

  group('PdfExporter.buildMonthlySummaryPdf', () {
    test('produces a well-formed PDF for a small dataset', () async {
      final bytes = await PdfExporter.buildMonthlySummaryPdf(
        PdfMonthlySummaryParams(
          expenses: expenses,
          incomes: incomes,
          budgets: budgets,
          currencySymbol: r'$',
          monthName: 'January 2024',
          totalIncome: 1025.50,
          totalExpenses: 69.12,
          balance: 956.38,
          now: now,
        ),
      );
      expectWellFormedPdf(bytes);
    });
  });
}
