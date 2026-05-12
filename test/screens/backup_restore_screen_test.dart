import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/backup_restore_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.9h — Backup & Restore widget smoke tests.
///
/// Covers the Luminous-redesign composition contract:
///   * [GlassTopAppBar] renders "Backup & Restore" with back button.
///   * Export-backup CTA "Save Backup" is wired into the screen.
///   * Restore-backup CTA "Choose Backup File" is wired into the screen.
///
/// `_loadBackups()` in initState reads from the app-support directory.
/// In the test environment this resolves to an empty path-provider stub
/// and the future settles in milliseconds; we drive past it with a
/// short `runAsync` delay.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (_) async => null);
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => '.dart_tool/test_path_provider',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    Size surface = const Size(420, 2000),
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
          home: const BackupRestoreScreen(),
        ),
      ),
    );
  }

  Future<void> pumpThroughLoad(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  testWidgets('GlassTopAppBar renders "Backup & Restore" with back button',
      (tester) async {
    await pumpHarness(tester);
    await pumpThroughLoad(tester);

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('Export + Restore CTAs render', (tester) async {
    await pumpHarness(tester);
    await pumpThroughLoad(tester);

    expect(find.text('Save Backup'), findsOneWidget);
    expect(find.text('Share Backup'), findsOneWidget);
    expect(find.text('Choose Backup File'), findsOneWidget);
  });
}
