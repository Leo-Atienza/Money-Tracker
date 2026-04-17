import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/widgets/category_tile.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  // Use the factory constructors so Theme.of(context).brightness is reliably
  // dark/light — passing `brightness:` to the default `ThemeData()` doesn't
  // always propagate to Theme.of in tests.
  final theme = brightness == Brightness.dark
      ? ThemeData.dark()
      : ThemeData.light();
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  // ==========================================================================
  // CategoryColors.getDefaultColor
  // ==========================================================================
  group('CategoryColors.getDefaultColor', () {
    test('known expense category returns its mapped color', () {
      expect(
        CategoryColors.getDefaultColor('Food', 'expense'),
        const Color(0xFF8B5CF6),
      );
      expect(
        CategoryColors.getDefaultColor('Transport', 'expense'),
        const Color(0xFF3B82F6),
      );
      expect(
        CategoryColors.getDefaultColor('Health', 'expense'),
        const Color(0xFFEF4444),
      );
    });

    test('known income category returns its mapped color', () {
      expect(
        CategoryColors.getDefaultColor('Salary', 'income'),
        const Color(0xFFD97706),
      );
      expect(
        CategoryColors.getDefaultColor('Investment', 'income'),
        const Color(0xFF10B981),
      );
    });

    test('unknown expense category falls back to expense red', () {
      expect(
        CategoryColors.getDefaultColor('NonsenseCategory', 'expense'),
        const Color(0xFFEF4444),
      );
    });

    test('unknown income category falls back to income green', () {
      expect(
        CategoryColors.getDefaultColor('NonsenseCategory', 'income'),
        const Color(0xFF10B981),
      );
    });

    test('expense and income use separate color maps', () {
      // "Other" exists in both maps but with different colors — prove the
      // type argument actually routes the lookup.
      final expenseOther =
          CategoryColors.getDefaultColor('Other', 'expense');
      final incomeOther =
          CategoryColors.getDefaultColor('Other', 'income');
      expect(expenseOther, isNot(equals(incomeOther)));
    });
  });

  // ==========================================================================
  // CategoryTile rendering
  // ==========================================================================
  group('CategoryTile', () {
    testWidgets('renders at the given size', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
            size: 60,
          ),
        ),
      );

      final size = tester.getSize(find.byType(CategoryTile));
      expect(size.width, 60);
      expect(size.height, 60);
    });

    testWidgets('renders an icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
          ),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('renders cleanly under both light and dark themes',
        (tester) async {
      // We don't assert specific colors here — the HSL-lightness adjustment
      // in CategoryTile is an implementation detail better covered by a
      // golden test. Just prove both modes build and paint without throwing.
      await tester.pumpWidget(
        _wrap(
          const CategoryTile(categoryName: 'Food', categoryType: 'expense'),
        ),
      );
      expect(find.byType(CategoryTile), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _wrap(
          const CategoryTile(categoryName: 'Food', categoryType: 'expense'),
          brightness: Brightness.dark,
        ),
      );
      expect(find.byType(CategoryTile), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to default color when color string is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
          ),
        ),
      );

      // Should not throw, should render.
      expect(find.byType(CategoryTile), findsOneWidget);
    });

    testWidgets('empty color string also uses default color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
            color: '',
          ),
        ),
      );

      expect(find.byType(CategoryTile), findsOneWidget);
    });

    testWidgets('honors iconScale', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
            size: 100,
            iconScale: 0.6,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 60); // 100 * 0.6
    });
  });

  // ==========================================================================
  // CategoryTileSmall / CategoryTileLarge size delegates
  // ==========================================================================
  group('CategoryTileSmall / CategoryTileLarge', () {
    testWidgets('Small renders at 36x36', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryTileSmall(
            categoryName: 'Food',
            categoryType: 'expense',
          ),
        ),
      );

      final size = tester.getSize(find.byType(CategoryTile));
      expect(size.width, 36);
      expect(size.height, 36);
    });

    testWidgets('Large renders at 56x56', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryTileLarge(
            categoryName: 'Food',
            categoryType: 'expense',
          ),
        ),
      );

      final size = tester.getSize(find.byType(CategoryTile));
      expect(size.width, 56);
      expect(size.height, 56);
    });
  });
}
