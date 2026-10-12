import 'package:budget_tracker/widgets/luminous/category_bento_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the two Add-screen defects in Leo's 2026-10 device
/// screenshots: an empty band between the CATEGORY header and the first row,
/// and category names cut to "Entertai…", "Freel…", "Invest…".
void main() {
  const defaultNames = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Health',
    'Education',
    'Bills',
    'Other',
    'Salary',
    'Freelance',
    'Investment',
    'Gift',
  ];

  Widget host({required double width, EdgeInsets padding = EdgeInsets.zero}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(padding: padding),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: CategoryBentoGrid(
                items: [
                  for (final name in defaultNames)
                    CategoryBentoItem(
                      id: name,
                      label: name,
                      icon: Icons.category,
                      color: Colors.teal,
                    ),
                ],
                selectedId: 'Food',
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('starts flush with its top edge under a status-bar inset',
      (tester) async {
    // The old GridView had no explicit padding, so it inherited this inset
    // as an empty band above the first row.
    await tester.pumpWidget(
      host(width: 280, padding: const EdgeInsets.only(top: 48)),
    );

    final gridTop = tester.getTopLeft(find.byType(CategoryBentoGrid)).dy;
    final firstChipTop = tester.getTopLeft(find.text('Food')).dy;
    // The label sits inside the chip's 8px padding and 48px min height, so
    // it is near the top — not 48px further down.
    expect(firstChipTop - gridTop, lessThan(24));
  });

  testWidgets('shows every default category name in full on a 360dp phone',
      (tester) async {
    // 360dp screen - 2 x 20 page gutter - 2 x 20 card padding = 280dp.
    // The test font draws every glyph a full em wide, wider than Hanken
    // Grotesk, so passing here is the conservative case.
    await tester.pumpWidget(host(width: 280));

    for (final name in defaultNames) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      expect(paragraph.didExceedMaxLines, isFalse, reason: name);
      expect(
        paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: name.length),
        ).map((box) => box.top).toSet(),
        hasLength(1),
        reason: '$name wrapped onto a second line',
      );
    }
  });

  testWidgets('every chip is at least a 48dp touch target', (tester) async {
    await tester.pumpWidget(host(width: 280));

    for (final name in defaultNames) {
      final chip = find.ancestor(
        of: find.text(name),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48),
          reason: name);
    }
  });

  testWidgets('tapping a chip reports its id', (tester) async {
    Object? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryBentoGrid(
            items: const [
              CategoryBentoItem(
                id: 'Bills',
                label: 'Bills',
                icon: Icons.receipt,
                color: Colors.blue,
              ),
            ],
            selectedId: null,
            onSelected: (id) => picked = id,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bills'));
    expect(picked, 'Bills');
  });
}
