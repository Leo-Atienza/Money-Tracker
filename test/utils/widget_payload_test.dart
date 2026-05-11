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
    monthName: 'November',
    expenses: r'$1,234.56',
    income: r'$5,000.00',
    balance: r'+$3,765.44',
    isPositive: true,
    currency: r'$',
  );

  group('WidgetPayload.redactIfLocked', () {
    test('returns input unchanged when PIN is disabled', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: false);
      expect(out.monthName, 'November');
      expect(out.expenses, r'$1,234.56');
      expect(out.income, r'$5,000.00');
      expect(out.balance, r'+$3,765.44');
      expect(out.isPositive, isTrue);
      expect(out.currency, r'$');
    });

    test('masks every monetary value with bullet token when PIN enabled', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: true);
      expect(out.expenses, WidgetPayload.redactedAmount);
      expect(out.income, WidgetPayload.redactedAmount);
      expect(out.balance, WidgetPayload.redactedAmount);
    });

    test('replaces month name with Locked label when PIN enabled', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: true);
      expect(out.monthName, WidgetPayload.redactedLabel);
    });

    test('preserves currency symbol so widget layout stays stable', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: true);
      // Currency code drives the symbol the widget renders alongside the
      // bullet token; locking the layout means the user sees `$ •••`
      // rather than the widget shifting width on toggle.
      expect(out.currency, sampleData.currency);
    });

    test('preserves isPositive so widget accent color stays stable', () {
      final negativeData = sampleData.copyWith(isPositive: false);
      final outPositive = WidgetPayload.redactIfLocked(
        sampleData,
        pinEnabled: true,
      );
      final outNegative = WidgetPayload.redactIfLocked(
        negativeData,
        pinEnabled: true,
      );
      expect(outPositive.isPositive, isTrue);
      expect(outNegative.isPositive, isFalse);
    });

    test('returns a new instance, never mutates input', () {
      final out = WidgetPayload.redactIfLocked(sampleData, pinEnabled: true);
      expect(out, isNot(same(sampleData)));
      // Source data unchanged.
      expect(sampleData.expenses, r'$1,234.56');
    });
  });
}
