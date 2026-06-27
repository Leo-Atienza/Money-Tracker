import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/widgets/luminous/glass_donut_chart.dart';

/// Wraps [child] in a sized MaterialApp scaffold so CustomPaint and Theme
/// lookups resolve. Mirrors the harness in luminous_components_smoke_test.dart.
Widget _wrap(Widget child, {Size size = const Size(400, 800)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

Widget _wrapThemed(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: child),
  );
}

void main() {
  group('DonutSlice', () {
    test('holds label, value, and color verbatim', () {
      const slice = DonutSlice(label: 'Food', value: 42.5, color: Colors.teal);
      expect(slice.label, 'Food');
      expect(slice.value, 42.5);
      expect(slice.color, Colors.teal);
    });
  });

  group('GlassDonutChart', () {
    // Case 2: empty slices / total <= 0 → track only, no throw, center shows.
    testWidgets('empty slices renders track only without throwing, center shows',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            slices: [],
            center: Text('EMPTY'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('EMPTY'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // Case 2 variant: total<=0 via all-zero / negative-cancelling values → early return.
    testWidgets('all-zero slice values (total<=0) does not throw',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            slices: [
              DonutSlice(label: 'A', value: 0, color: Colors.red),
              DonutSlice(label: 'B', value: 0, color: Colors.blue),
            ],
            center: Text('ZERO'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ZERO'), findsOneWidget);
    });

    // Case 3: single slice (value>0) → near-full ring, no throw.
    testWidgets('single positive slice renders without throwing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            slices: [
              DonutSlice(label: 'Only', value: 100, color: Colors.green),
            ],
            center: Text('100%'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('100%'), findsOneWidget);
    });

    // Case 4: center==null → no center child, no throw.
    testWidgets('null center renders without throwing and shows no center text',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            slices: [
              DonutSlice(label: 'A', value: 1, color: Colors.red),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // Confirm the widget itself constructed with a null center.
      final chart = tester.widget<GlassDonutChart>(find.byType(GlassDonutChart));
      expect(chart.center, isNull);
    });

    // Case 5: custom size/thickness applied; honored on the SizedBox.
    testWidgets('custom size sizes the chart box', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            size: 120,
            thickness: 12,
            sliceGap: 0.1,
            slices: [
              DonutSlice(label: 'A', value: 50, color: Colors.red),
              DonutSlice(label: 'B', value: 50, color: Colors.blue),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final chart = tester.widget<GlassDonutChart>(find.byType(GlassDonutChart));
      expect(chart.size, 120);
      expect(chart.thickness, 12);
      expect(chart.sliceGap, 0.1);
      // The outer SizedBox uses the requested size.
      final box = tester.getSize(find.byType(GlassDonutChart));
      expect(box.width, 120);
      expect(box.height, 120);
    });

    // Case 5 boundary: thickness > size must not throw (radius math can go
    // negative; painter must tolerate it via stroke clamping, no assertion).
    testWidgets('thickness greater than size does not throw (radius boundary)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            size: 40,
            thickness: 80,
            slices: [
              DonutSlice(label: 'A', value: 30, color: Colors.red),
              DonutSlice(label: 'B', value: 70, color: Colors.blue),
            ],
            center: Text('X'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('X'), findsOneWidget);
    });

    // Case 6: shouldRepaint contract — observable via the public widget.
    // Changing a slice value rebuilds and repaints without throwing.
    testWidgets('repaints cleanly when slice value changes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            key: ValueKey('chart'),
            slices: [
              DonutSlice(label: 'A', value: 60, color: Colors.red),
              DonutSlice(label: 'B', value: 40, color: Colors.blue),
            ],
          ),
        ),
      );
      // Same key → element reused → painter shouldRepaint path exercised.
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            key: ValueKey('chart'),
            slices: [
              DonutSlice(label: 'A', value: 10, color: Colors.red),
              DonutSlice(label: 'B', value: 90, color: Colors.blue),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final chart = tester.widget<GlassDonutChart>(find.byType(GlassDonutChart));
      expect(chart.slices.first.value, 10);
    });

    // Case 6: repaint on slice count change.
    testWidgets('repaints cleanly when slice count changes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            key: ValueKey('chart'),
            slices: [
              DonutSlice(label: 'A', value: 60, color: Colors.red),
              DonutSlice(label: 'B', value: 40, color: Colors.blue),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            key: ValueKey('chart'),
            slices: [
              DonutSlice(label: 'A', value: 33, color: Colors.red),
              DonutSlice(label: 'B', value: 33, color: Colors.blue),
              DonutSlice(label: 'C', value: 34, color: Colors.green),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final chart = tester.widget<GlassDonutChart>(find.byType(GlassDonutChart));
      expect(chart.slices.length, 3);
    });

    // Case 6: repaint on color change.
    testWidgets('repaints cleanly when slice color changes', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            key: ValueKey('chart'),
            slices: [
              DonutSlice(label: 'A', value: 50, color: Colors.red),
              DonutSlice(label: 'B', value: 50, color: Colors.blue),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        _wrap(
          const GlassDonutChart(
            key: ValueKey('chart'),
            slices: [
              DonutSlice(label: 'A', value: 50, color: Colors.orange),
              DonutSlice(label: 'B', value: 50, color: Colors.blue),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final chart = tester.widget<GlassDonutChart>(find.byType(GlassDonutChart));
      expect(chart.slices.first.color, Colors.orange);
    });
  });

  // Direct assertions on the painter's shouldRepaint contract, via the
  // @visibleForTesting DonutPainter seam. The widget tests above only observe
  // it indirectly (no throw on rebuild); here we pin the exact boolean.
  group('DonutPainter.shouldRepaint (direct)', () {
    const trackA = Color(0x11223344);
    const trackB = Color(0x55667788);
    final base = <DonutSlice>[
      const DonutSlice(label: 'A', value: 60, color: Colors.red),
      const DonutSlice(label: 'B', value: 40, color: Colors.blue),
    ];

    DonutPainter painter({
      List<DonutSlice>? slices,
      double thickness = 28,
      double sliceGap = 0.04,
      Color trackColor = trackA,
    }) {
      return DonutPainter(
        slices: slices ?? base,
        thickness: thickness,
        sliceGap: sliceGap,
        trackColor: trackColor,
      );
    }

    test('false when nothing changed (same slice list)', () {
      expect(painter().shouldRepaint(painter()), isFalse);
    });

    test('false for an equal-but-distinct slice list', () {
      final copy = <DonutSlice>[
        const DonutSlice(label: 'A', value: 60, color: Colors.red),
        const DonutSlice(label: 'B', value: 40, color: Colors.blue),
      ];
      expect(painter(slices: copy).shouldRepaint(painter()), isFalse);
    });

    test('true when thickness changes', () {
      expect(painter(thickness: 30).shouldRepaint(painter()), isTrue);
    });

    test('true when sliceGap changes', () {
      expect(painter(sliceGap: 0.08).shouldRepaint(painter()), isTrue);
    });

    test('true when trackColor changes', () {
      expect(painter(trackColor: trackB).shouldRepaint(painter()), isTrue);
    });

    test('true when slice count changes', () {
      final three = <DonutSlice>[
        ...base,
        const DonutSlice(label: 'C', value: 20, color: Colors.green),
      ];
      expect(painter(slices: three).shouldRepaint(painter()), isTrue);
    });

    test('true when a slice value changes', () {
      final changed = <DonutSlice>[
        const DonutSlice(label: 'A', value: 10, color: Colors.red),
        const DonutSlice(label: 'B', value: 40, color: Colors.blue),
      ];
      expect(painter(slices: changed).shouldRepaint(painter()), isTrue);
    });

    test('true when a slice color changes', () {
      final changed = <DonutSlice>[
        const DonutSlice(label: 'A', value: 60, color: Colors.orange),
        const DonutSlice(label: 'B', value: 40, color: Colors.blue),
      ];
      expect(painter(slices: changed).shouldRepaint(painter()), isTrue);
    });
  });

  group('DonutLegend', () {
    // Case 1: one row per slice with label + formatted value.
    testWidgets('renders one row per slice with label and formatted value',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonutLegend(
            slices: const [
              DonutSlice(label: 'Food', value: 60, color: Colors.red),
              DonutSlice(label: 'Rent', value: 40, color: Colors.blue),
            ],
            valueFormatter: (s) => '\$${s.value.toStringAsFixed(0)}',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('\$60'), findsOneWidget);
      expect(find.text('\$40'), findsOneWidget);
      // One color swatch (Container) + label + value per slice.
      expect(find.byType(Container), findsNWidgets(2));
    });

    // Case 2: empty slices → empty column, no throw.
    testWidgets('empty slices renders empty column without throwing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonutLegend(
            slices: const [],
            valueFormatter: (s) => s.value.toString(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DonutLegend), findsOneWidget);
      // No rows: no swatch Containers rendered.
      expect(find.byType(Container), findsNothing);
    });

    // Case 3: valueFormatter invoked once per slice.
    testWidgets('valueFormatter is invoked once per slice', (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(
        _wrap(
          DonutLegend(
            slices: const [
              DonutSlice(label: 'A', value: 1, color: Colors.red),
              DonutSlice(label: 'B', value: 2, color: Colors.blue),
              DonutSlice(label: 'C', value: 3, color: Colors.green),
            ],
            valueFormatter: (s) {
              seen.add(s.label);
              return 'v${s.value.toStringAsFixed(0)}';
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(seen, containsAll(<String>['A', 'B', 'C']));
      expect(seen.length, 3);
      expect(find.text('v1'), findsOneWidget);
      expect(find.text('v2'), findsOneWidget);
      expect(find.text('v3'), findsOneWidget);
    });

    // Case 4: long label uses ellipsis overflow.
    testWidgets('long label uses ellipsis overflow', (tester) async {
      const longLabel =
          'A very long category label that will not fit on one line at all';
      await tester.pumpWidget(
        _wrap(
          DonutLegend(
            slices: const [
              DonutSlice(label: longLabel, value: 5, color: Colors.red),
            ],
            valueFormatter: (s) => s.value.toStringAsFixed(0),
          ),
          size: const Size(200, 400),
        ),
      );
      expect(tester.takeException(), isNull);
      final labelText = tester.widget<Text>(find.text(longLabel));
      expect(labelText.overflow, TextOverflow.ellipsis);
    });

    // The swatch color matches the slice color (legend semantics).
    testWidgets('color swatch matches slice color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonutLegend(
            slices: const [
              DonutSlice(label: 'Tagged', value: 7, color: Color(0xFF123456)),
            ],
            valueFormatter: (s) => s.value.toStringAsFixed(0),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF123456));
    });

    // Renders in both dark and light themes without throwing (theme.textTheme
    // fallback path is exercised in either brightness).
    testWidgets('renders in light and dark themes without throwing',
        (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          _wrapThemed(
            DonutLegend(
              slices: const [
                DonutSlice(label: 'A', value: 1, color: Colors.red),
              ],
              valueFormatter: (s) => s.value.toStringAsFixed(0),
            ),
            brightness: brightness,
          ),
        );
        expect(tester.takeException(), isNull,
            reason: 'failed for $brightness');
        expect(find.text('A'), findsOneWidget);
      }
    });
  });
}
