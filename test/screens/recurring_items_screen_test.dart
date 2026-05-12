import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/recurring_items_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_segmented_control.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.7 — RecurringItemsScreen widget smoke tests.
///
/// Covers the merged Luminous composition contract:
///   * [GlassTopAppBar] renders "Recurring Items" with a back button.
///   * [GlassSegmentedControl] flips the visible empty-state copy.
///   * Initial type from constructor controls which side renders first.
///
/// Behavioural flows (add/edit/delete a recurring item, notification
/// scheduling) are exercised at the AppState + DatabaseHelper level by
/// integration tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (_) async => null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    String initialType = 'expense',
    Size surface = const Size(420, 1400),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: RecurringItemsScreen(initialType: initialType),
        ),
      ),
    );
  }

  testWidgets(
    'GlassTopAppBar + GlassSegmentedControl render',
    (tester) async {
      await pumpHarness(tester);
      await tester.pumpAndSettle();

      expect(find.byType(GlassTopAppBar), findsOneWidget);
      expect(find.text('Recurring Items'), findsOneWidget);
      expect(find.byType(GlassSegmentedControl<String>), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    },
  );

  testWidgets(
    'initialType: expense shows expense empty state',
    (tester) async {
      await pumpHarness(tester, initialType: 'expense');
      await tester.pumpAndSettle();

      expect(find.text('No recurring expenses'), findsOneWidget);
      expect(find.text('No recurring income'), findsNothing);
    },
  );

  testWidgets(
    'initialType: income shows income empty state',
    (tester) async {
      await pumpHarness(tester, initialType: 'income');
      await tester.pumpAndSettle();

      expect(find.text('No recurring income'), findsOneWidget);
      expect(find.text('No recurring expenses'), findsNothing);
    },
  );

  testWidgets(
    'tapping Income segment swaps the visible empty state',
    (tester) async {
      await pumpHarness(tester, initialType: 'expense');
      await tester.pumpAndSettle();

      expect(find.text('No recurring expenses'), findsOneWidget);

      // Tap the "Income" label inside the segmented control.
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('No recurring income'), findsOneWidget);
      expect(find.text('No recurring expenses'), findsNothing);
    },
  );
}
