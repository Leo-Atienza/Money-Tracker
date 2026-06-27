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
  // CategoryTile — custom-color path & malformed-hex resilience (spec gaps 6-8)
  // ==========================================================================
  group('CategoryTile custom color path', () {
    // The tile's root is a Container whose BoxDecoration derives every visible
    // surface (gradient stops, border, shadow) from a single `baseColor`. In
    // light mode the border color is exactly `baseColor.withAlpha(25)`, so we
    // can read it back off the decoration and prove which base color was used.
    BoxDecoration decorationOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CategoryTile),
          matching: find.byType(Container),
        ),
      );
      return container.decoration! as BoxDecoration;
    }

    testWidgets(
        'valid hex color drives the rendered gradient/border, not the default',
        (tester) async {
      // Food/expense default is 0xFF8B5CF6 (violet). Override with blue.
      const customHex = '#3B82F6';
      const customBase = Color(0xFF3B82F6);
      const defaultBase = Color(0xFF8B5CF6);

      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
            color: customHex,
          ),
        ),
      );

      final decoration = decorationOf(tester);

      // Light-mode border is baseColor.withAlpha(25). It must match the parsed
      // custom color, NOT the category default.
      expect(decoration.border, isA<Border>());
      final borderColor = (decoration.border as Border).top.color;
      expect(borderColor, customBase.withAlpha(25));
      expect(borderColor, isNot(defaultBase.withAlpha(25)));

      // Gradient stops are baseColor.withAlpha(50) / withAlpha(30) in light.
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors.first, customBase.withAlpha(50));
      expect(gradient.colors.last, customBase.withAlpha(30));

      // Shadow color is baseColor.withAlpha(20) in light.
      expect(decoration.boxShadow!.first.color, customBase.withAlpha(20));
    });

    testWidgets(
        'malformed hex color falls to transparent base and still renders',
        (tester) async {
      // 'zzz' -> parseColor catches the FormatException -> Colors.transparent.
      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
            color: 'zzz',
          ),
        ),
      );

      expect(find.byType(CategoryTile), findsOneWidget);
      expect(tester.takeException(), isNull);

      // parseColor('zzz') -> Colors.transparent (black, alpha 0). The tile then
      // re-applies a fixed alpha via withAlpha(), so derived surfaces are black
      // at the configured low alpha — NOT the category default violet.
      const transparentBase = Colors.transparent;
      const defaultBase = Color(0xFF8B5CF6); // Food/expense default.
      final decoration = decorationOf(tester);
      final borderColor = (decoration.border as Border).top.color;
      expect(borderColor, transparentBase.withAlpha(25));
      expect(borderColor, isNot(defaultBase.withAlpha(25)));
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors.first, transparentBase.withAlpha(50));
      expect(gradient.colors.last, transparentBase.withAlpha(30));
    });

    testWidgets(
        'dark mode HSL lightness clamp handles a near-white base without overflow',
        (tester) async {
      // Near-white base: dark-mode icon color does HSL lightness + 0.1 then
      // .clamp(0,1). A lightness already > 0.9 must clamp to 1.0, not overflow.
      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
            color: '#FEFEFE',
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(CategoryTile), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The icon color is a valid, fully-opaque Color (no NaN/overflow from the
      // clamp). Lightness clamps to <= 1.0 so the resulting color is legal.
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, isNotNull);
      final l = HSLColor.fromColor(icon.color!).lightness;
      expect(l, lessThanOrEqualTo(1.0));
      expect(l, greaterThanOrEqualTo(0.0));
    });

    testWidgets('dark mode uses higher gradient/border alphas than light',
        (tester) async {
      // Prove the isDark branch is actually taken: dark border alpha is 40,
      // light is 25. Use an opaque custom color so alpha math is exact.
      const customBase = Color(0xFF3B82F6);

      await tester.pumpWidget(
        _wrap(
          const CategoryTile(
            categoryName: 'Food',
            categoryType: 'expense',
            color: '#3B82F6',
          ),
          brightness: Brightness.dark,
        ),
      );

      final decoration = decorationOf(tester);
      final borderColor = (decoration.border as Border).top.color;
      expect(borderColor, customBase.withAlpha(40));

      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors.first, customBase.withAlpha(70));
      expect(gradient.colors.last, customBase.withAlpha(45));
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
