import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/trash_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.9f — Trash widget smoke tests.
///
/// Covers the Luminous-redesign composition contract:
///   * Top app bar uses [GlassTopAppBar] with a back button.
///   * Empty-trash IconButton is absent when there are no items.
///
/// Behavioural flows (restore / permanent delete / empty-trash dialog)
/// are exercised at the AppState + DatabaseHelper level by the existing
/// integration tests (`cascade_delete_test.dart`). The richer per-item
/// state checks are deferred to D.6 hero widget tests, which seed the DB
/// with deleted rows before pumping.
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
          home: const TrashScreen(),
        ),
      ),
    );
  }

  testWidgets('GlassTopAppBar renders "Trash" with back button',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('empty-trash IconButton is absent when there are no items',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(
      find.byTooltip('Empty Trash'),
      findsNothing,
      reason: 'No items ⇒ delete-forever IconButton should not render.',
    );
  });
}
