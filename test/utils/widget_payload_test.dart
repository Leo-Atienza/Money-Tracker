import 'package:budget_tracker/utils/widget_payload.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 6.4 — Home widget redaction.
///
/// The launcher widget shows even on the lock screen, so the payload
/// must be redacted whenever PIN protection is enabled. These tests
/// pin the contract so a regression that leaks balances on the lock
/// screen fails CI before it ships.
void main() {
  const sampleData = WidgetData(
    monthKey: '2026-11',
    monthName: 'November',
    balance: r'-$3,765.44',
    income: r'$5,000.00',
    expenses: r'$8,765.44',
  );

  group('WidgetPayload.redactIfLocked', () {
    test('returns input unchanged when PIN is disabled', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: false);
      expect(out.monthKey, '2026-11');
      expect(out.monthName, 'November');
      expect(out.balance, r'-$3,765.44');
      expect(out.income, r'$5,000.00');
      expect(out.expenses, r'$8,765.44');
    });

    test('masks every monetary value with bullet token when PIN enabled', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: true);
      expect(out.balance, WidgetPayload.redactedAmount);
      expect(out.income, WidgetPayload.redactedAmount);
      expect(out.expenses, WidgetPayload.redactedAmount);
    });

    test('hides the balance sign along with the amount', () {
      // The sign alone says the account is overdrawn.
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: true);
      expect(out.balance, isNot(contains('-')));
    });

    test('keeps the month so the widget still labels and rolls over', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: true);
      expect(out.monthKey, '2026-11');
      expect(out.monthName, 'November');
    });

    test('returns a new instance, never mutates input', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: true);
      expect(out, isNot(same(sampleData)));
      // Source data unchanged.
      expect(sampleData.expenses, r'$8,765.44');
    });
  });

  group('WidgetData.toWidgetFields', () {
    test('uses the keys BudgetWidgetProvider reads', () {
      expect(sampleData.toWidgetFields(), {
        'month_key': '2026-11',
        'month_name': 'November',
        'balance': r'-$3,765.44',
        'income': r'$5,000.00',
        'expenses': r'$8,765.44',
      });
    });

    test('prefixes every key for the following month', () {
      expect(
        sampleData.toWidgetFields(prefix: 'next_').keys,
        [
          'next_month_key',
          'next_month_name',
          'next_balance',
          'next_income',
          'next_expenses',
        ],
      );
    });
  });
}
