import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/widgets/luminous/floating_glass_nav_bar.dart';

void main() {
  const destinations = [
    FloatingGlassNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    FloatingGlassNavDestination(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'History',
    ),
    FloatingGlassNavDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Analytics',
    ),
  ];

  Future<void> pump(WidgetTester tester, int index, [ValueChanged<int>? onTap]) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingGlassNavBar(
            currentIndex: index,
            onTap: onTap ?? (_) {},
            destinations: destinations,
          ),
        ),
      ),
    );
  }

  // The per-destination Semantics node carries the human-readable label
  // (not the uppercased Text), so screen readers don't spell "H-O-M-E".
  Semantics navSem(WidgetTester tester, String label) {
    return tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == label);
  }

  testWidgets('M10: each destination is a labeled button node', (tester) async {
    await pump(tester, 0);
    for (final d in destinations) {
      final s = navSem(tester, d.label);
      expect(s.properties.button, isTrue,
          reason: '${d.label} must expose a button role');
      expect(s.properties.label, d.label);
    }
  });

  testWidgets('M10: only the current destination is marked selected',
      (tester) async {
    await pump(tester, 1); // History selected
    expect(navSem(tester, 'History').properties.selected, isTrue);
    expect(navSem(tester, 'Home').properties.selected, isFalse);
    expect(navSem(tester, 'Analytics').properties.selected, isFalse);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    int? tapped;
    await pump(tester, 0, (i) => tapped = i);
    await tester.tap(find.text('ANALYTICS'));
    expect(tapped, 2);
  });
}
