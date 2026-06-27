import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/widgets/luminous/organic_blob_background.dart';
import 'package:budget_tracker/theme/luminous_tokens.dart';

/// Wraps the background under a MaterialApp with an explicit brightness +
/// surface size so the dark/light branch and the `MediaQuery.sizeOf` blob
/// sizing are both deterministic.
Widget _wrap(
  Widget child, {
  required Brightness brightness,
  Size size = const Size(400, 800),
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      // Background is meant to sit behind content; a Stack mirrors real use.
      child: Stack(children: [child]),
    ),
  );
}

/// The ColoredBox the widget itself paints (dark uses surface, light uses
/// LuminousTokens.background). The widget returns ColoredBox as its top node,
/// so the first ColoredBox *inside* OrganicBlobBackground is the base — scoping
/// to the subtree skips framework-internal ColoredBoxes higher in the tree.
ColoredBox _rootColoredBox(WidgetTester tester) {
  return tester.widget<ColoredBox>(
    find
        .descendant(
          of: find.byType(OrganicBlobBackground),
          matching: find.byType(ColoredBox),
        )
        .first,
  );
}

void main() {
  group('OrganicBlobBackground — render branches', () {
    testWidgets('renders without throwing in light mode', (tester) async {
      await tester.pumpWidget(
        _wrap(const OrganicBlobBackground(), brightness: Brightness.light),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OrganicBlobBackground), findsOneWidget);
    });

    testWidgets('renders without throwing in dark mode', (tester) async {
      await tester.pumpWidget(
        _wrap(const OrganicBlobBackground(), brightness: Brightness.dark),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(OrganicBlobBackground), findsOneWidget);
    });

    testWidgets('light and dark take different branches (two blobs each)',
        (tester) async {
      // Each branch builds exactly two radial-gradient blobs via DecoratedBox.
      await tester.pumpWidget(
        _wrap(const OrganicBlobBackground(), brightness: Brightness.light),
      );
      expect(find.byType(DecoratedBox), findsNWidgets(2));

      await tester.pumpWidget(
        _wrap(const OrganicBlobBackground(), brightness: Brightness.dark),
      );
      expect(find.byType(DecoratedBox), findsNWidgets(2));
    });
  });

  group('OrganicBlobBackground — base color per branch', () {
    testWidgets('light branch base color is LuminousTokens.background',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const OrganicBlobBackground(), brightness: Brightness.light),
      );
      expect(_rootColoredBox(tester).color, LuminousTokens.background);
    });

    testWidgets('dark branch base color is colorScheme.surface',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const OrganicBlobBackground(), brightness: Brightness.dark),
      );
      // Derive the expected surface from the same theme the widget read, so
      // the assertion stays correct even if the dark surface token changes.
      final ctx = tester.element(find.byType(OrganicBlobBackground));
      final expectedSurface = Theme.of(ctx).colorScheme.surface;
      expect(_rootColoredBox(tester).color, expectedSurface);
    });

    test('light and dark base colors are distinct constants', () {
      // The two per-branch widget tests above already pin each base color
      // (light → LuminousTokens.background, dark → colorScheme.surface). This
      // asserts the underlying invariant — those two source colors differ —
      // without a second pumpWidget on the same tester, which is order-fragile
      // (a reused element can retain the previous frame's ColoredBox and the
      // assertion then flakes only when run after other widget tests).
      final darkSurface =
          ThemeData(brightness: Brightness.dark).colorScheme.surface;
      expect(LuminousTokens.background, isNot(equals(darkSurface)));
    });
  });

  group('OrganicBlobBackground — IgnorePointer pass-through', () {
    testWidgets('blobs are wrapped in IgnorePointer (one per blob)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const OrganicBlobBackground(), brightness: Brightness.light),
      );
      // Two blobs → two IgnorePointer wrappers inside the widget, each
      // ignoring. Scope to the widget's own subtree so framework-level
      // IgnorePointers (MaterialApp/Overlay) don't inflate the count.
      final ignorePointers = tester.widgetList<IgnorePointer>(
        find.descendant(
          of: find.byType(OrganicBlobBackground),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointers.length, 2);
      for (final ip in ignorePointers) {
        expect(ip.ignoring, isTrue);
      }
    });

    testWidgets('overlay content stays tappable through the background',
        (tester) async {
      // The background's blobs extend off-screen and overlap content. The
      // IgnorePointer wrappers must let taps reach a button painted on top.
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Stack(
              children: [
                const OrganicBlobBackground(),
                Center(
                  child: ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('Tap me'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('OrganicBlobBackground — MediaQuery.sizeOf sizing boundaries', () {
    testWidgets('survives a tiny surface without overflow throw',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OrganicBlobBackground(),
          brightness: Brightness.light,
          size: const Size(1, 1),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a large surface without overflow throw',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OrganicBlobBackground(),
          brightness: Brightness.dark,
          size: const Size(4000, 8000),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('blob diameter scales with MediaQuery width', (tester) async {
      // Light top-right blob diameter is width * 0.72. Doubling the surface
      // width must roughly double that blob's rendered size — proving the
      // widget reads MediaQuery.sizeOf rather than a fixed constant.
      double topRightBlobWidth(WidgetTester t) {
        // Each blob is a SizedBox(width: diameter) directly wrapping a
        // DecoratedBox(circle). Scope to the widget's subtree and grab the
        // first such SizedBox — the top-right blob (declared first in the
        // light branch Stack).
        final blobBox = find
            .descendant(
              of: find.byType(OrganicBlobBackground),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.child is DecoratedBox,
              ),
            )
            .first;
        return t.widget<SizedBox>(blobBox).width!;
      }

      await tester.pumpWidget(
        _wrap(
          const OrganicBlobBackground(),
          brightness: Brightness.light,
          size: const Size(400, 800),
        ),
      );
      final narrow = topRightBlobWidth(tester);

      await tester.pumpWidget(
        _wrap(
          const OrganicBlobBackground(),
          brightness: Brightness.light,
          size: const Size(800, 800),
        ),
      );
      final wide = topRightBlobWidth(tester);

      // width*0.72: 288 at 400px, 576 at 800px.
      expect(narrow, closeTo(288, 0.001));
      expect(wide, closeTo(576, 0.001));
    });
  });
}
