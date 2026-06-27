import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/screens/history/history_list.dart';
import 'package:budget_tracker/utils/premium_animations.dart';

void main() {
  Expense expense(int i) => Expense(
        id: i,
        amount: Decimal.fromInt(10 + i),
        category: 'Food',
        description: 'tx$i',
        date: DateTime.utc(2026, 1, 1),
        accountId: 1,
        amountPaid: Decimal.zero,
        paymentMethod: 'Cash',
      );

  Widget tile(BuildContext context, Expense e) =>
      SizedBox(height: 40, child: Text('tile_${e.id}'));

  Future<void> pumpList(
    WidgetTester tester, {
    required List<dynamic> items,
    required String sortOrder,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 6000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryList(
            items: items,
            sortOrder: sortOrder,
            showMonth: false,
            scrollController: null,
            isLoadingMore: false,
            hasMoreData: false,
            maxTotalResults: 1000,
            totalLoaded: items.length,
            onRefresh: () async {},
            expenseTileBuilder: tile,
            incomeTileBuilder: (c, i) => const SizedBox.shrink(),
            datedExpenseTileBuilder: (c, e, {bool showMonth = false}) => tile(c, e),
            datedIncomeTileBuilder: (c, i, {bool showMonth = false}) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('M7: grouped list renders a flat header + all item tiles',
      (tester) async {
    final items = List.generate(20, expense);
    await pumpList(tester, items: items, sortOrder: 'category');

    // One group header ("FOOD") + every item tile present (flattened, not a
    // single eager Column hidden off-screen).
    expect(find.text('FOOD'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      expect(find.text('tile_$i'), findsOneWidget);
    }
  });

  testWidgets('M8: at most 12 tiles per group get the stagger wrapper',
      (tester) async {
    final items = List.generate(20, expense);
    await pumpList(tester, items: items, sortOrder: 'category');

    // 20 tiles, but only the first 12 are wrapped in StaggeredListItem.
    expect(find.byType(StaggeredListItem), findsNWidgets(12));
  });

  testWidgets('M8: flat (amount-sort) list also caps the stagger at 12',
      (tester) async {
    final items = List.generate(20, expense);
    await pumpList(tester, items: items, sortOrder: 'highest');

    expect(find.byType(StaggeredListItem), findsNWidgets(12));
    for (var i = 0; i < 20; i++) {
      expect(find.text('tile_$i'), findsOneWidget);
    }
  });
}
