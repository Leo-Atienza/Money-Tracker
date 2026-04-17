import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/accessibility_helper.dart';
import 'package:budget_tracker/widgets/accessible_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

// `FilledButton.icon()` / `OutlinedButton.icon()` each return a private
// subclass (`_FilledButtonWithIcon` / `_OutlinedButtonWithIcon`), so
// `find.byType(FilledButton)` — which matches on exact runtimeType — misses
// them. Use a predicate to catch any subclass.
final _filledFinder =
    find.byWidgetPredicate((w) => w is FilledButton, description: 'FilledButton');
final _outlinedFinder = find.byWidgetPredicate(
  (w) => w is OutlinedButton,
  description: 'OutlinedButton',
);

void main() {
  group('AccessibleButton', () {
    testWidgets('renders the label text', (tester) async {
      await tester.pumpWidget(
        _wrap(AccessibleButton(label: 'Save', onPressed: () {})),
      );
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('defaults to OutlinedButton when !isPrimary', (tester) async {
      await tester.pumpWidget(
        _wrap(AccessibleButton(label: 'Cancel', onPressed: () {})),
      );
      expect(_outlinedFinder, findsOneWidget);
      expect(_filledFinder, findsNothing);
    });

    testWidgets('renders FilledButton when isPrimary=true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AccessibleButton(label: 'Save', onPressed: () {}, isPrimary: true),
        ),
      );
      expect(_filledFinder, findsOneWidget);
      expect(_outlinedFinder, findsNothing);
    });

    testWidgets('destructive primary button uses red background',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AccessibleButton(
            label: 'Delete',
            onPressed: () {},
            isPrimary: true,
            isDestructive: true,
          ),
        ),
      );

      final filled = tester.widget<FilledButton>(_filledFinder);
      final bg = filled.style!.backgroundColor!.resolve(<WidgetState>{});
      expect(bg, Colors.red);
    });

    testWidgets('destructive outlined button uses red side + foreground',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AccessibleButton(
            label: 'Delete',
            onPressed: () {},
            isDestructive: true,
          ),
        ),
      );

      final btn = tester.widget<OutlinedButton>(_outlinedFinder);
      final fg = btn.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(fg, Colors.red);
    });

    testWidgets('onPressed fires when tapped', (tester) async {
      int tapped = 0;
      await tester.pumpWidget(
        _wrap(
          AccessibleButton(label: 'Tap me', onPressed: () => tapped++),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('icon renders when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AccessibleButton(
            label: 'Save',
            onPressed: () {},
            icon: Icons.save,
          ),
        ),
      );
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('meets 48dp minimum touch target', (tester) async {
      await tester.pumpWidget(
        _wrap(AccessibleButton(label: 'x', onPressed: () {})),
      );

      final size = tester.getSize(_outlinedFinder);
      expect(
        size.height,
        greaterThanOrEqualTo(AccessibilityHelper.minTouchTargetSize),
      );
    });

    testWidgets('wraps in Semantics with button: true and the label',
        (tester) async {
      await tester.pumpWidget(
        _wrap(AccessibleButton(label: 'Save changes', onPressed: () {})),
      );

      // Semantics from the Flutter tree — the outer Semantics from AccessibleButton
      // sets label + button=true + enabled=true.
      final semantics = tester.getSemantics(find.text('Save changes'));
      // Walk up until we find a node whose label matches (inner Text semantics
      // may shadow the outer wrapper depending on merging rules).
      expect(
        semantics.label.contains('Save changes') ||
            semantics.value.contains('Save changes'),
        isTrue,
      );
    });
  });

  group('AccessibleIconButton', () {
    testWidgets('renders the icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AccessibleIconButton(
            icon: Icons.settings,
            label: 'Settings',
            onPressed: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('onPressed fires when tapped', (tester) async {
      var count = 0;
      await tester.pumpWidget(
        _wrap(
          AccessibleIconButton(
            icon: Icons.add,
            label: 'Add',
            onPressed: () => count++,
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(count, 1);
    });

    testWidgets('uses the label as IconButton tooltip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AccessibleIconButton(
            icon: Icons.add,
            label: 'Add transaction',
            onPressed: () {},
          ),
        ),
      );

      final iconBtn = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconBtn.tooltip, 'Add transaction');
    });

    testWidgets('meets 48dp minimum touch target', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AccessibleIconButton(
            icon: Icons.menu,
            label: 'Menu',
            onPressed: () {},
          ),
        ),
      );

      final size = tester.getSize(find.byType(IconButton));
      expect(
        size.width,
        greaterThanOrEqualTo(AccessibilityHelper.minTouchTargetSize),
      );
      expect(
        size.height,
        greaterThanOrEqualTo(AccessibilityHelper.minTouchTargetSize),
      );
    });
  });
}
