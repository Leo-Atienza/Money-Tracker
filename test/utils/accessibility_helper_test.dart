import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:budget_tracker/utils/accessibility_helper.dart';

void main() {
  group('AccessibilityHelper', () {
    group('minTouchTargetSize', () {
      test('constant equals 48.0', () {
        expect(AccessibilityHelper.minTouchTargetSize, 48.0);
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

      testWidgets(
          'exposes exactly ONE semantics node carrying label + button + tap',
          (tester) async {
        // Disposed explicitly at the end: the framework checks for live
        // handles BEFORE tearDown callbacks run.
        final handle = tester.ensureSemantics();
        final widget = AccessibilityHelper.semanticIconButton(
          icon: Icons.delete,
          label: 'Delete',
          onPressed: () {},
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

        // The tooltip is what a screen reader announces.
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.tooltip, 'Delete');

        // Regression: the old Semantics(label, button) wrapper around the
        // IconButton (which already carries its own node) made TalkBack
        // announce every header button twice. Exactly one node must carry
        // the label, and that node must be the actionable button.
        // On Android the tooltip becomes the node's content description, so
        // the actionable button node must be the one that carries it.
        expect(
          tester.getSemantics(find.byType(IconButton)),
          matchesSemantics(
            tooltip: 'Delete',
            isButton: true,
            hasTapAction: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasFocusAction: true,
          ),
        );

        // ...and it must be the ONLY node that says "Delete".
        var nodesSayingDelete = 0;
        void walk(SemanticsNode node) {
          final data = node.getSemanticsData();
          if (data.label == 'Delete' || data.tooltip == 'Delete') {
            nodesSayingDelete++;
          }
          node.visitChildren((child) {
            walk(child);
            return true;
          });
        }

        walk(tester.getSemantics(find.byType(MaterialApp)));
        expect(nodesSayingDelete, 1,
            reason: 'a second node means the button is announced twice');
        handle.dispose();
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
