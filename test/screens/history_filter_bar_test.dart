import 'package:budget_tracker/screens/history/history_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// History's filter chips each read as ONE TalkBack node that carries the
/// tap. A Semantics wrapper around every chip used to add a second labelled
/// node with no action, so TalkBack announced each chip twice.
void main() {
  late int allTimeTaps, rangeTaps, rangeClears, sortTaps;

  Future<void> pumpBar(WidgetTester tester, {required bool withRange}) async {
    allTimeTaps = rangeTaps = rangeClears = sortTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryFilterBar(
            searchController: TextEditingController(),
            searchTerm: '',
            onSearchChanged: (_) {},
            onSearchCleared: () {},
            searchAllTime: false,
            isLoadingAllTime: false,
            onAllTimeChanged: (_) => allTimeTaps++,
            dateRange: withRange
                ? DateTimeRange(
                    start: DateTime(2026, 10, 1),
                    end: DateTime(2026, 10, 12),
                  )
                : null,
            formatDateRange: (_) => 'Oct 1 - Oct 12',
            onDateRangeRequested: () => rangeTaps++,
            onDateRangeCleared: () => rangeClears++,
            sortOrder: 'newest',
            sortLabelFor: (_) => 'Newest',
            sortIconFor: (_) => Icons.arrow_downward,
            onShowSortOptions: () => sortTaps++,
            categoryChips: const [],
          ),
        ),
      ),
    );
  }

  /// Every semantics node whose label mentions [text].
  List<SemanticsNode> nodesMentioning(String text) => find.semantics
      .byPredicate((node) => node.label.contains(text))
      .evaluate()
      .toList();

  testWidgets('each chip is one node that carries its tap', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester, withRange: true);

    for (final label in ['All time', 'Date range: Oct 1 - Oct 12', 'Sort by']) {
      final nodes = nodesMentioning(label);
      expect(nodes, hasLength(1), reason: '"$label" is announced once');
      expect(
        nodes.single.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: '"$label" can be activated from TalkBack',
      );
    }

    tester.semantics.tap(find.semantics.byPredicate(
        (node) => node.label.contains('All time')));
    tester.semantics.tap(find.semantics.byPredicate(
        (node) => node.label.contains('Date range:')));
    tester.semantics.tap(find.semantics.byPredicate(
        (node) => node.label.contains('Sort by')));
    await tester.pump();
    expect([allTimeTaps, rangeTaps, sortTaps], [1, 1, 1]);
    handle.dispose();
  });

  testWidgets('the date range can still be cleared from TalkBack',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester, withRange: true);

    tester.semantics.tap(find.semantics.byPredicate(
        (node) => node.tooltip == 'Clear date range'));
    await tester.pump();
    expect(rangeClears, 1);
    handle.dispose();
  });

  testWidgets('without a range the chip offers to pick one', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester, withRange: false);

    expect(nodesMentioning('Select date range'), hasLength(1));
    expect(find.byTooltip('Clear date range'), findsNothing);
    handle.dispose();
  });
}
