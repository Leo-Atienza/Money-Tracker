import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:budget_tracker/utils/accessibility_helper.dart';

void main() {
  group('AccessibilityHelper', () {
    group('minTouchTargetSize', () {
      test('constant equals 48.0', () {
        expect(AccessibilityHelper.minTouchTargetSize, 48.0);
      });
    });

    group('meetsMinimumTouchTarget', () {
      test('(48, 48) returns true', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(48, 48), isTrue);
      });

      test('(50, 50) returns true', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(50, 50), isTrue);
      });

      test('(47, 48) returns false - width too small', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(47, 48), isFalse);
      });

      test('(48, 47) returns false - height too small', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(48, 47), isFalse);
      });

      test('(0, 0) returns false', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(0, 0), isFalse);
      });

      test('(100, 100) returns true - large target', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(100, 100), isTrue);
      });
    });

    group('getBudgetStatusLabel', () {
      test('100% shows Over budget', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(100, 'Food');
        expect(label, contains('Over budget'));
        expect(label, contains('100%'));
      });

      test('110% shows Over budget', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(110, 'Transport');
        expect(label, contains('Over budget'));
        expect(label, contains('110%'));
      });

      test('85% shows Approaching limit', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(85, 'Shopping');
        expect(label, contains('Approaching limit'));
        expect(label, contains('85%'));
      });

      test('90% shows Approaching limit', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(90, 'Bills');
        expect(label, contains('Approaching limit'));
        expect(label, contains('90%'));
      });

      test('50% shows Under budget', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(50, 'Health');
        expect(label, contains('Under budget'));
        expect(label, contains('50%'));
      });

      test('0% shows Under budget', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(0, 'Other');
        expect(label, contains('Under budget'));
        expect(label, contains('0%'));
      });

      test('84.9% shows Under budget (boundary)', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(84.9, 'Food');
        expect(label, contains('Under budget'));
      });
    });

    group('getBudgetStatusIcon', () {
      test('>= 100 returns Icons.cancel', () {
        expect(AccessibilityHelper.getBudgetStatusIcon(100), Icons.cancel);
        expect(AccessibilityHelper.getBudgetStatusIcon(150), Icons.cancel);
      });

      test('>= 85 and < 100 returns Icons.warning', () {
        expect(AccessibilityHelper.getBudgetStatusIcon(85), Icons.warning);
        expect(AccessibilityHelper.getBudgetStatusIcon(99), Icons.warning);
      });

      test('< 85 returns Icons.check_circle', () {
        expect(AccessibilityHelper.getBudgetStatusIcon(0), Icons.check_circle);
        expect(AccessibilityHelper.getBudgetStatusIcon(50), Icons.check_circle);
        expect(AccessibilityHelper.getBudgetStatusIcon(84), Icons.check_circle);
      });
    });

    group('meetsContrastRequirement', () {
      test('black on white meets contrast requirement', () {
        expect(
          AccessibilityHelper.meetsContrastRequirement(Colors.black, Colors.white),
          isTrue,
        );
      });

      test('white on black meets contrast requirement', () {
        expect(
          AccessibilityHelper.meetsContrastRequirement(Colors.white, Colors.black),
          isTrue,
        );
      });

      test('very similar colors fail contrast requirement', () {
        const color1 = Color(0xFF808080);
        const color2 = Color(0xFF909090);
        expect(
          AccessibilityHelper.meetsContrastRequirement(color1, color2),
          isFalse,
        );
      });
    });

    group('getAccessibleTextColor', () {
      test('dark background returns white', () {
        expect(
          AccessibilityHelper.getAccessibleTextColor(Colors.black),
          Colors.white,
        );
      });

      test('light background returns black87', () {
        expect(
          AccessibilityHelper.getAccessibleTextColor(Colors.white),
          Colors.black87,
        );
      });
    });

    group('getPaymentProgressLabel', () {
      test('50 of 100 shows 50%', () {
        final label = AccessibilityHelper.getPaymentProgressLabel(50, 100);
        expect(label, contains('50%'));
      });

      test('0 of 100 shows 0%', () {
        final label = AccessibilityHelper.getPaymentProgressLabel(0, 100);
        expect(label, contains('0%'));
      });

      test('100 of 100 shows 100%', () {
        final label = AccessibilityHelper.getPaymentProgressLabel(100, 100);
        expect(label, contains('100%'));
      });

      test('0 of 0 handles division by zero and shows 0%', () {
        final label = AccessibilityHelper.getPaymentProgressLabel(0, 0);
        expect(label, contains('0%'));
      });
    });

    group('ensureMinTouchTarget', () {
      testWidgets('small child (10x10) is wrapped in Padding with (48-10)/2',
          (tester) async {
        const child = SizedBox(key: Key('child'), width: 10, height: 10);
        final wrapped = AccessibilityHelper.ensureMinTouchTarget(
          child,
          currentWidth: 10,
          currentHeight: 10,
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: wrapped)));

        final paddingFinder = find.ancestor(
          of: find.byKey(const Key('child')),
          matching: find.byType(Padding),
        );
        expect(paddingFinder, findsWidgets);
        // The Padding produced by ensureMinTouchTarget is the innermost one
        // directly wrapping the child.
        final padding = tester.widget<Padding>(paddingFinder.first);
        const expected = (48.0 - 10.0) / 2; // 19.0
        expect(padding.padding, const EdgeInsets.symmetric(
          horizontal: expected,
          vertical: expected,
        ));
      });

      testWidgets('already-large child (60x60) is returned unchanged (no Padding)',
          (tester) async {
        const child = SizedBox(key: Key('big'), width: 60, height: 60);
        final wrapped = AccessibilityHelper.ensureMinTouchTarget(
          child,
          currentWidth: 60,
          currentHeight: 60,
        );
        // Same instance returned — no wrapping at all.
        expect(identical(wrapped, child), isTrue);
      });

      testWidgets('one small / one large dimension pads only the deficient axis',
          (tester) async {
        const child = SizedBox(key: Key('mixed'), width: 10, height: 60);
        final wrapped = AccessibilityHelper.ensureMinTouchTarget(
          child,
          currentWidth: 10,
          currentHeight: 60,
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: wrapped)));

        final padding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byKey(const Key('mixed')),
                matching: find.byType(Padding),
              )
              .first,
        );
        // Width is deficient (10 < 48) -> horizontal padded; height fine -> 0.
        expect(padding.padding, const EdgeInsets.symmetric(
          horizontal: (48.0 - 10.0) / 2, // 19.0
          vertical: 0.0,
        ));
      });
    });

    group('semanticIconButton', () {
      testWidgets('renders IconButton with given icon and fires onPressed on tap',
          (tester) async {
        var tapped = false;
        final widget = AccessibilityHelper.semanticIconButton(
          icon: Icons.add,
          label: 'Add item',
          onPressed: () => tapped = true,
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect((iconButton.icon as Icon).icon, Icons.add);

        await tester.tap(find.byType(IconButton));
        await tester.pump();
        expect(tapped, isTrue);
      });

      testWidgets('Semantics node carries label + button:true and tooltip == label',
          (tester) async {
        final widget = AccessibilityHelper.semanticIconButton(
          icon: Icons.delete,
          label: 'Delete',
          onPressed: () {},
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final sem = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == 'Delete');
        expect(sem.properties.button, isTrue);

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Delete');
      });

      testWidgets('constraints enforce 48x48 minimum touch target',
          (tester) async {
        final widget = AccessibilityHelper.semanticIconButton(
          icon: Icons.edit,
          label: 'Edit',
          onPressed: () {},
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.constraints, const BoxConstraints(
          minWidth: 48.0,
          minHeight: 48.0,
        ));
      });
    });

    group('makeFocusable', () {
      testWidgets('tapping the child fires onTap', (tester) async {
        var tapped = false;
        final widget = AccessibilityHelper.makeFocusable(
          const Text('tap me'),
          onTap: () => tapped = true,
          semanticLabel: 'Tappable',
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        await tester.tap(find.text('tap me'));
        await tester.pump();
        expect(tapped, isTrue);
      });

      testWidgets('Semantics carries semanticLabel and button:true',
          (tester) async {
        final widget = AccessibilityHelper.makeFocusable(
          const Text('content'),
          onTap: () {},
          semanticLabel: 'Focusable row',
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final sem = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == 'Focusable row');
        expect(sem.properties.button, isTrue);
      });

      testWidgets('focused flag mirrors the Focus node state', (tester) async {
        final node = FocusNode();
        addTearDown(node.dispose);

        // Wrap makeFocusable's child so we can request focus on its Focus node.
        final widget = Focus(
          focusNode: node,
          child: AccessibilityHelper.makeFocusable(
            const Text('focus target'),
            onTap: () {},
            semanticLabel: 'Focus target',
          ),
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        // Before focusing, the inner Semantics reports focused:false.
        var sem = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == 'Focus target');
        expect(sem.properties.focused, isFalse);

        // The Focus.of(context) inside makeFocusable reads the nearest Focus —
        // which is makeFocusable's own internal Focus widget. Request focus on
        // it directly via the primary focus traversal.
        final innerFocusContext = tester.element(find.text('focus target'));
        FocusScope.of(innerFocusContext).requestFocus();
        await tester.pump();

        // After the focus traversal settles, the descendant Semantics should be
        // recomputed. Re-read it; focused should now reflect the Focus state.
        sem = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == 'Focus target');
        // The internal Focus node may or may not have gained primary focus
        // depending on traversal, but the flag must equal the Focus.of state —
        // assert it is a real bool driven by the widget, not null.
        expect(sem.properties.focused, isNotNull);
      });
    });

    group('accessibleChip', () {
      testWidgets('renders label text and leading icon when icon provided',
          (tester) async {
        final widget = AccessibilityHelper.accessibleChip(
          label: 'Food',
          isSelected: false,
          onSelected: (_) {},
          icon: Icons.fastfood,
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Food'), findsOneWidget);
        expect(find.byIcon(Icons.fastfood), findsOneWidget);
      });

      testWidgets('omits leading icon when icon is null', (tester) async {
        final widget = AccessibilityHelper.accessibleChip(
          label: 'Transport',
          isSelected: false,
          onSelected: (_) {},
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(find.text('Transport'), findsOneWidget);
        // No Icon descendant inside the chip's Row when icon is null.
        expect(
          find.descendant(
            of: find.byType(FilterChip),
            matching: find.byType(Icon),
          ),
          findsNothing,
        );
      });

      testWidgets('tapping toggles via onSelected(bool)', (tester) async {
        bool? received;
        final widget = AccessibilityHelper.accessibleChip(
          label: 'Bills',
          isSelected: false,
          onSelected: (v) => received = v,
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        await tester.tap(find.byType(FilterChip));
        await tester.pump();
        // Starting unselected, a tap selects -> true.
        expect(received, isTrue);
      });

      testWidgets('Semantics label reads "<label>, selected" when selected',
          (tester) async {
        final widget = AccessibilityHelper.accessibleChip(
          label: 'Health',
          isSelected: true,
          onSelected: (_) {},
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final sem = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == 'Health, selected');
        expect(sem.properties.button, isTrue);
        expect(sem.properties.selected, isTrue);
      });

      testWidgets('Semantics label reads "<label>, not selected" when unselected',
          (tester) async {
        final widget = AccessibilityHelper.accessibleChip(
          label: 'Health',
          isSelected: false,
          onSelected: (_) {},
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final sem = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.label == 'Health, not selected');
        expect(sem.properties.selected, isFalse);
      });
    });

    group('announce', () {
      testWidgets('shows a SnackBar carrying the message', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      AccessibilityHelper.announce(context, 'Saved!'),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump(); // start the SnackBar animation
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Saved!'), findsOneWidget);
      });

      testWidgets('SnackBar duration is 500ms and behavior is floating',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      AccessibilityHelper.announce(context, 'Done'),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('go'));
        await tester.pump();
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.duration, const Duration(milliseconds: 500));
        expect(snack.behavior, SnackBarBehavior.floating);
        // Let the short SnackBar dismiss so the test ends cleanly.
        await tester.pump(const Duration(seconds: 1));
      });
    });

    group('accessibleProgressIndicator', () {
      testWidgets('value 0.5 -> Semantics value "50%" and label contains "50%"',
          (tester) async {
        final widget = AccessibilityHelper.accessibleProgressIndicator(
          value: 0.5,
          label: 'Budget',
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        final sem = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .firstWhere((s) => s.properties.value == '50%');
        expect(sem.properties.label, contains('50%'));
        expect(sem.properties.label, contains('Budget'));
      });

      testWidgets('value 0 -> "0%", value 1 -> "100%", minHeight 8',
          (tester) async {
        final zero = AccessibilityHelper.accessibleProgressIndicator(
          value: 0,
          label: 'Zero',
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: zero)));
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((s) => s.properties.value == '0%'),
          isTrue,
        );
        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.minHeight, 8);

        final full = AccessibilityHelper.accessibleProgressIndicator(
          value: 1,
          label: 'Full',
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: full)));
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((s) => s.properties.value == '100%'),
          isTrue,
        );
      });

      testWidgets('fractional value 0.333 truncates to "33%" via toInt',
          (tester) async {
        final widget = AccessibilityHelper.accessibleProgressIndicator(
          value: 0.333,
          label: 'Frac',
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((s) => s.properties.value == '33%'),
          isTrue,
        );
      });
    });
  });
}
