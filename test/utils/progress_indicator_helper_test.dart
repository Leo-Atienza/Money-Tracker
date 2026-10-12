import 'package:budget_tracker/utils/progress_indicator_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// S22 (audit Open): progress dialogs were closed with a blind pop, which
/// took down whatever sat on top instead (a passphrase prompt, the PIN
/// unlock screen) or stranded the dialog when the opener had unmounted.
void main() {
  late BuildContext homeContext;
  // The spinner never settles, so pumps while it shows are bounded.
  const transition = Duration(milliseconds: 500);

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        homeContext = context;
        return const Text('HOME');
      }),
    ));
  }

  testWidgets('the closer closes its own dialog', (tester) async {
    await pumpHome(tester);
    final close = ProgressIndicatorHelper.show(homeContext, message: 'Working');
    await tester.pump(transition);
    expect(find.text('Working'), findsOneWidget);

    close();
    await tester.pumpAndSettle();
    expect(find.text('Working'), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a route pushed above the dialog survives the close',
      (tester) async {
    await pumpHome(tester);
    final close = ProgressIndicatorHelper.show(homeContext, message: 'Working');
    await tester.pump(transition);
    Navigator.of(homeContext, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const Text('ABOVE')),
    );
    await tester.pump(transition);

    close();
    await tester.pumpAndSettle();
    expect(find.text('ABOVE'), findsOneWidget);
    expect(find.text('Working', skipOffstage: false), findsNothing);
  });

  testWidgets('a second close does nothing', (tester) async {
    await pumpHome(tester);
    final close = ProgressIndicatorHelper.show(homeContext, message: 'Working');
    await tester.pump(transition);

    close();
    close();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
