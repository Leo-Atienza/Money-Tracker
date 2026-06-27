import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/theme/luminous_tokens.dart';
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

  Future<void> pump(
    WidgetTester tester,
    int index, [
    ValueChanged<int>? onTap,
    Brightness brightness = Brightness.light,
  ]) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
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

  // The fill/stroke Container is the BoxDecoration-bearing child of the
  // BackdropFilter blur layer.
  Container fillContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(Container),
      ),
    );
  }

  // The Icon for a given destination, found by its IconData.
  Icon iconFor(WidgetTester tester, IconData data) {
    return tester.widget<Icon>(find.byIcon(data));
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

  group('FloatingGlassNavDestination', () {
    test('constructs and round-trips its fields', () {
      const d = FloatingGlassNavDestination(
        icon: Icons.wallet_outlined,
        selectedIcon: Icons.wallet,
        label: 'Wallet',
      );
      expect(d.icon, Icons.wallet_outlined);
      expect(d.selectedIcon, Icons.wallet);
      expect(d.label, 'Wallet');
    });
  });

  group('FloatingGlassNavBar rendering', () {
    testWidgets('renders one labeled column per destination, uppercased',
        (tester) async {
      await pump(tester, 0);
      // One Expanded slot per destination.
      expect(find.byType(Expanded), findsNWidgets(destinations.length));
      // Each label is shown uppercased.
      for (final d in destinations) {
        expect(find.text(d.label.toUpperCase()), findsOneWidget);
        // The original-case label exists only on the Semantics node, not Text.
        expect(find.text(d.label), findsNothing);
      }
    });

    testWidgets('tapping each index fires onTap(i) exactly once', (tester) async {
      final calls = <int>[];
      await pump(tester, 0, calls.add);
      await tester.tap(find.text('HOME'));
      await tester.tap(find.text('HISTORY'));
      await tester.tap(find.text('ANALYTICS'));
      expect(calls, [0, 1, 2]);
    });

    testWidgets('press emits a selection-click haptic', (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      await pump(tester, 0);
      await tester.tap(find.text('HISTORY'));
      await tester.pump();
      expect(haptics, hasLength(1));
      expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('selected vs unselected icon', () {
    testWidgets('selected index shows selectedIcon; others show icon',
        (tester) async {
      await pump(tester, 1); // History selected
      // Selected destination renders its filled selectedIcon.
      expect(find.byIcon(Icons.history), findsOneWidget); // selected
      expect(find.byIcon(Icons.history_outlined), findsNothing);
      // Non-selected destinations render their outlined icon.
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.home), findsNothing);
      expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsNothing);
    });

    testWidgets('selected icon + label use the active primaryContainer color',
        (tester) async {
      await pump(tester, 0); // Home selected
      final selectedIcon = iconFor(tester, Icons.home);
      expect(selectedIcon.color, LuminousTokens.primaryContainer);

      final selectedLabel = tester.widget<Text>(find.text('HOME'));
      expect(selectedLabel.style?.color, LuminousTokens.primaryContainer);

      // A non-selected label does NOT use the active color.
      final inactiveLabel = tester.widget<Text>(find.text('HISTORY'));
      expect(inactiveLabel.style?.color, isNot(LuminousTokens.primaryContainer));
    });
  });

  group('center icon size boundary', () {
    testWidgets('center destination (index 2) icon is 26px, others 24px',
        (tester) async {
      await pump(tester, 0);
      // index 0 + index 1 are outlined (24), index 2 (center) is 26.
      expect(iconFor(tester, Icons.home).size, 24); // selected, index 0
      expect(iconFor(tester, Icons.history_outlined).size, 24); // index 1
      expect(iconFor(tester, Icons.bar_chart_outlined).size, 26); // index 2
    });
  });

  group('dark vs light fill/stroke', () {
    testWidgets('light mode uses glassFill', (tester) async {
      await pump(tester, 0, null, Brightness.light);
      final deco = fillContainer(tester).decoration as BoxDecoration;
      expect(deco.color, LuminousTokens.glassFill);
      // Light stroke alpha ~0.4.
      final side = (deco.border as Border).top;
      expect(side.color, Colors.white.withValues(alpha: 0.4));
    });

    testWidgets('dark mode swaps to translucent black fill + dimmer stroke',
        (tester) async {
      await pump(tester, 0, null, Brightness.dark);
      final deco = fillContainer(tester).decoration as BoxDecoration;
      expect(deco.color, Colors.black.withValues(alpha: 0.45));
      final side = (deco.border as Border).top;
      expect(side.color, Colors.white.withValues(alpha: 0.22));
    });
  });

  group('glass chrome', () {
    testWidgets('applies a backdrop blur at the token sigma', (tester) async {
      await pump(tester, 0);
      final bf = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(
        bf.filter,
        ImageFilter.blur(
          sigmaX: LuminousTokens.glassBlurSigma,
          sigmaY: LuminousTokens.glassBlurSigma,
        ),
      );
    });
  });
}
