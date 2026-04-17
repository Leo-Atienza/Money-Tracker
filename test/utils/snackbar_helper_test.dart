import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/main.dart' show AppColors;
import 'package:budget_tracker/utils/snackbar_helper.dart';

/// A known-value AppColors so tests can assert on specific colors without
/// depending on ColorContrastHelper's WCAG adjustments.
const _testAppColors = AppColors(
  expenseRed: Color(0xFFAA1111),
  incomeGreen: Color(0xFF1AAA1A),
  warningOrange: Color(0xFFFFAA00),
  infoBlue: Color(0xFF1A5AFF),
);

Widget _harness({required void Function(BuildContext) onPressed}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: const [_testAppColors],
    ),
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => onPressed(ctx),
          child: const Text('trigger'),
        ),
      ),
    ),
  );
}

void main() {
  group('SnackBarHelper.showSuccess', () {
    testWidgets('shows green floating SnackBar with the message',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          onPressed: (ctx) => SnackBarHelper.showSuccess(ctx, 'Saved!'),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump(); // start entrance animation

      expect(find.text('Saved!'), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, _testAppColors.incomeGreen);
      expect(snack.behavior, SnackBarBehavior.floating);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('SnackBarHelper.showError', () {
    testWidgets('shows red floating SnackBar with error icon', (tester) async {
      await tester.pumpWidget(
        _harness(
          onPressed: (ctx) => SnackBarHelper.showError(ctx, 'Boom'),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();

      expect(find.text('Boom'), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, _testAppColors.expenseRed);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('errors show for 4 seconds (longer than success)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          onPressed: (ctx) => SnackBarHelper.showError(ctx, 'Boom'),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.duration, const Duration(seconds: 4));
    });
  });

  group('SnackBarHelper.showWarning', () {
    testWidgets('shows orange SnackBar with warning icon', (tester) async {
      await tester.pumpWidget(
        _harness(
          onPressed: (ctx) => SnackBarHelper.showWarning(ctx, 'Careful'),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, _testAppColors.warningOrange);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });
  });

  group('SnackBarHelper.showInfo', () {
    testWidgets('shows blue SnackBar with info icon', (tester) async {
      await tester.pumpWidget(
        _harness(
          onPressed: (ctx) => SnackBarHelper.showInfo(ctx, 'FYI'),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, _testAppColors.infoBlue);
      expect(find.byIcon(Icons.info), findsOneWidget);
    });
  });

  group('SnackBarHelper.showUndo', () {
    testWidgets('shows a SnackBar with an UNDO action that fires onUndo',
        (tester) async {
      var undoFired = 0;
      await tester.pumpWidget(
        _harness(
          onPressed: (ctx) => SnackBarHelper.showUndo(
            ctx,
            'Deleted',
            () => undoFired++,
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump(); // schedule snackbar entrance
      await tester.pump(const Duration(milliseconds: 750)); // play it in

      expect(find.text('Deleted'), findsOneWidget);
      // Tap the SnackBarAction directly — `find.text('UNDO')` matches the
      // inner Text, which may sit under a different gesture handler than the
      // action itself.
      final undoFinder = find.widgetWithText(SnackBarAction, 'UNDO');
      expect(undoFinder, findsOneWidget);
      await tester.tap(undoFinder);
      await tester.pump();

      expect(undoFired, 1);
    });

    testWidgets('UNDO snackbar has the 5-second duration', (tester) async {
      await tester.pumpWidget(
        _harness(
          onPressed: (ctx) => SnackBarHelper.showUndo(ctx, 'msg', () {}),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.duration, const Duration(seconds: 5));
    });
  });
}
