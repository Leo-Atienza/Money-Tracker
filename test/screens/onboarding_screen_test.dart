import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const channels = [
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    MethodChannel('home_widget'),
    MethodChannel('dexterous.com/flutter/local_notifications'),
  ];
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
    }
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => '.dart_tool/test_path_provider',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() {
    for (final channel in [...channels, pathProviderChannel]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  // S22 (audit Open, misc row): a second tap while the first load was still
  // writing added every sample row twice.
  testWidgets('a double tap on Load Sample Data loads it once',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = AppState();
    await tester.runAsync(state.loadData);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          routes: {'/home': (_) => const Text('HOME')},
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Load Sample Data'));
    await tester.tap(find.text('Load Sample Data'));
    // A real-time deadline: under the full parallel suite the sample load
    // took over 6s, past a fixed 40-round bound.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (find.text('HOME').evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Let a duplicate load, if one started, finish writing too.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));

    expect(find.text('HOME'), findsOneWidget);
    expect(
      state.incomes.where((i) => i.description == 'Monthly salary'),
      hasLength(1),
    );
  });
}
