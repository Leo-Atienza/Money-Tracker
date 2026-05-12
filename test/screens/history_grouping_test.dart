import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/screens/history/history_grouping.dart';
import 'package:budget_tracker/utils/date_helper.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense({
  required DateTime date,
  String category = 'Food',
  String description = 'lunch',
}) {
  return Expense(
    amount: Decimal.parse('10.00'),
    category: category,
    description: description,
    date: date,
    accountId: 1,
  );
}

Income _income({
  required DateTime date,
  String category = 'Salary',
  String description = 'pay',
}) {
  return Income(
    amount: Decimal.parse('100.00'),
    category: category,
    description: description,
    date: date,
    accountId: 1,
  );
}

void main() {
  group('groupByDay', () {
    test('splits items at midnight boundary into separate buckets', () {
      final lateMay11 = DateTime(2026, 5, 11, 23, 59, 59);
      final earlyMay12 = DateTime(2026, 5, 12, 0, 0, 1);
      final items = <dynamic>[
        _expense(date: lateMay11),
        _expense(date: earlyMay12),
      ];

      final grouped = groupByDay(items);

      expect(grouped.keys, containsAll(<String>['2026-05-11', '2026-05-12']));
      expect(grouped['2026-05-11'], hasLength(1));
      expect(grouped['2026-05-12'], hasLength(1));
    });

    test('groups same-day items regardless of time', () {
      final morning = DateTime(2026, 5, 12, 8);
      final evening = DateTime(2026, 5, 12, 22);
      final items = <dynamic>[
        _expense(date: morning),
        _income(date: evening),
      ];

      final grouped = groupByDay(items);

      expect(grouped, hasLength(1));
      expect(grouped['2026-05-12'], hasLength(2));
    });

    test('empty input returns empty map', () {
      expect(groupByDay(const <dynamic>[]), isEmpty);
    });
  });

  group('groupByCategory', () {
    test('groups same-category items together regardless of date', () {
      final items = <dynamic>[
        _expense(date: DateTime(2026, 5, 1), category: 'Food'),
        _expense(date: DateTime(2026, 5, 12), category: 'Food'),
        _expense(date: DateTime(2026, 5, 12), category: 'Transport'),
      ];

      final grouped = groupByCategory(items);

      expect(grouped.keys, containsAll(<String>['Food', 'Transport']));
      expect(grouped['Food'], hasLength(2));
      expect(grouped['Transport'], hasLength(1));
    });

    test('empty input returns empty map', () {
      expect(groupByCategory(const <dynamic>[]), isEmpty);
    });
  });

  group('sortGroupKeys', () {
    test('newestFirst sorts yyyy-MM-dd keys descending', () {
      final sorted = sortGroupKeys(
        ['2026-05-01', '2026-05-12', '2026-04-30'],
        GroupSortOrder.newestFirst,
      );

      expect(sorted, ['2026-05-12', '2026-05-01', '2026-04-30']);
    });

    test('oldestFirst sorts yyyy-MM-dd keys ascending', () {
      final sorted = sortGroupKeys(
        ['2026-05-12', '2026-04-30', '2026-05-01'],
        GroupSortOrder.oldestFirst,
      );

      expect(sorted, ['2026-04-30', '2026-05-01', '2026-05-12']);
    });

    test('alphabetical sorts category keys A→Z', () {
      final sorted = sortGroupKeys(
        ['Transport', 'Food', 'Entertainment'],
        GroupSortOrder.alphabetical,
      );

      expect(sorted, ['Entertainment', 'Food', 'Transport']);
    });

    test('does not mutate the input iterable', () {
      final input = <String>['c', 'a', 'b'];
      final sorted = sortGroupKeys(input, GroupSortOrder.alphabetical);

      expect(input, ['c', 'a', 'b']);
      expect(sorted, ['a', 'b', 'c']);
    });
  });

  group('formatDateHeader', () {
    test('returns TODAY for current date regardless of time component', () {
      final now = DateHelper.today().add(const Duration(hours: 14));
      expect(formatDateHeader(now), 'TODAY');
    });

    test('returns YESTERDAY for the previous calendar day', () {
      final yesterday = DateHelper.today().subtract(const Duration(days: 1));
      expect(formatDateHeader(yesterday), 'YESTERDAY');
    });

    test('returns weekday + month/day in caps for older dates', () {
      // Pick a fixed date far enough back that today/yesterday checks never hit.
      final fixed = DateTime(2020, 3, 15);
      final result = formatDateHeader(fixed);
      expect(result, isNotEmpty);
      expect(result, result.toUpperCase());
      expect(result, contains('MAR'));
      expect(result, contains('15'));
    });
  });

  group('formatDateHeaderWithMonth', () {
    test('uses TODAY / YESTERDAY rules just like formatDateHeader', () {
      final today = DateHelper.today();
      final yesterday = today.subtract(const Duration(days: 1));

      expect(formatDateHeaderWithMonth(today), 'TODAY');
      expect(formatDateHeaderWithMonth(yesterday), 'YESTERDAY');
    });

    test('omits the year for same-year dates', () {
      final fixedNow = DateTime(2026, 6, 1);
      final sameYear = DateTime(2026, 3, 15);

      final result = formatDateHeaderWithMonth(sameYear, now: fixedNow);

      expect(result, contains('MAR'));
      expect(result, contains('15'));
      expect(result, isNot(contains('2026')));
    });

    test('includes the year for prior-year dates', () {
      final fixedNow = DateTime(2026, 6, 1);
      final priorYear = DateTime(2024, 12, 31);

      final result = formatDateHeaderWithMonth(priorYear, now: fixedNow);

      expect(result, contains('2024'));
    });
  });
}
