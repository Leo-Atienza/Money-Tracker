import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/export_data_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_panel.dart';
import 'package:budget_tracker/widgets/luminous/glass_pill_chip.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.9e — Export Data widget smoke tests.
///
/// Covers the Luminous-redesign composition contract:
///   * [GlassTopAppBar] renders "Export Data" with a back button.
///   * Info banner renders inside a [GlassPanel].
///   * Three data-type options render with the expected titles.
///   * Date-range options render as [GlassPillChip].
///   * CSV + PDF export buttons render.
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
    Size surface = const Size(600, 2200),
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
          home: const ExportDataScreen(),
        ),
      ),
    );
  }

  testWidgets('GlassTopAppBar renders "Export Data" with back button',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Export Data'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('info banner renders inside a GlassPanel',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    final banner = find.textContaining('Export your transactions as a CSV');
    expect(banner, findsOneWidget);
    final panel = find.ancestor(of: banner, matching: find.byType(GlassPanel));
    expect(panel, findsOneWidget);
  });

  testWidgets('three export-type options render with expected titles',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.text('All Transactions'), findsOneWidget);
    expect(find.text('Expenses Only'), findsOneWidget);
    expect(find.text('Income Only'), findsOneWidget);
  });

  testWidgets('date-range options render as GlassPillChip', (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.byType(GlassPillChip), findsNWidgets(5));
    for (final label in const [
      'All Time',
      'This Month',
      'Last Month',
      'This Year',
      'Custom Range',
    ]) {
      expect(find.text(label), findsOneWidget,
          reason: 'Date pill "$label" should render exactly once.');
    }
  });

  testWidgets('Export to CSV + PDF buttons render', (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.text('Export to CSV'), findsOneWidget);
    expect(find.text('Export to PDF'), findsOneWidget);
  });
}
