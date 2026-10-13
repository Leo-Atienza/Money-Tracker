import 'dart:io';

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
import '../utils/_pdf_text.dart';

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

  // Transaction dates are UTC midnight; local-time range edges shifted by the
  // UTC offset dropped the 1st (west of UTC) and took in next month's 1st.
  group('exportRangeFor', () {
    final today = DateTime.utc(2026, 10, 12);

    test('This month: UTC midnight bounds, end exclusive', () {
      final range = exportRangeFor('this_month', today: today)!;
      expect(range.start, DateTime.utc(2026, 10, 1));
      expect(range.end, DateTime.utc(2026, 11, 1));
      expect(isInExportRange(DateTime.utc(2026, 9, 30), range), isFalse);
      expect(isInExportRange(DateTime.utc(2026, 10, 1), range), isTrue);
      expect(isInExportRange(DateTime.utc(2026, 10, 31), range), isTrue);
      expect(isInExportRange(DateTime.utc(2026, 11, 1), range), isFalse);
    });

    test('Last month in January is the previous December', () {
      final range =
          exportRangeFor('last_month', today: DateTime.utc(2027, 1, 5))!;
      expect(range.start, DateTime.utc(2026, 12, 1));
      expect(range.end, DateTime.utc(2027, 1, 1));
    });

    test('This year runs Jan 1 up to next Jan 1', () {
      final range = exportRangeFor('this_year', today: today)!;
      expect(range.start, DateTime.utc(2026, 1, 1));
      expect(range.end, DateTime.utc(2027, 1, 1));
      expect(isInExportRange(DateTime.utc(2026, 12, 31), range), isTrue);
      expect(isInExportRange(DateTime.utc(2027, 1, 1), range), isFalse);
    });

    test('Custom range includes both picked days (picker dates are local)',
        () {
      final range = exportRangeFor(
        'custom',
        today: today,
        customStart: DateTime(2026, 10, 5),
        customEnd: DateTime(2026, 10, 20),
      )!;
      expect(isInExportRange(DateTime.utc(2026, 10, 4), range), isFalse);
      expect(isInExportRange(DateTime.utc(2026, 10, 5), range), isTrue);
      expect(isInExportRange(DateTime.utc(2026, 10, 20), range), isTrue);
      expect(isInExportRange(DateTime.utc(2026, 10, 21), range), isFalse);
    });

    test('All time, or a custom range missing a date, has no bounds', () {
      expect(exportRangeFor('all_time', today: today), isNull);
      expect(
        exportRangeFor('custom', today: today, customStart: DateTime(2026)),
        isNull,
      );
    });
  });

  group('summaryHeadingFor', () {
    final today = DateTime.utc(2026, 10, 12);

    test('All time is a plain summary with no month and no budgets', () {
      final heading = summaryHeadingFor(null);
      expect(heading.title, 'Financial Summary');
      expect(heading.period, 'All time');
      expect(heading.singleMonth, isFalse);
    });

    test('a whole calendar month is a monthly summary of that month', () {
      final heading =
          summaryHeadingFor(exportRangeFor('last_month', today: today));
      expect(heading.title, 'Monthly Financial Summary');
      expect(heading.period, 'September 2026');
      expect(heading.singleMonth, isTrue);

      final custom = summaryHeadingFor(exportRangeFor(
        'custom',
        today: today,
        customStart: DateTime(2026, 2, 1),
        customEnd: DateTime(2026, 2, 28),
      ));
      expect(custom.period, 'February 2026');
      expect(custom.singleMonth, isTrue);
    });

    test('a year or a partial month prints its date range', () {
      final year = summaryHeadingFor(exportRangeFor('this_year', today: today));
      expect(year.title, 'Financial Summary');
      expect(year.period, 'Jan 1, 2026 - Dec 31, 2026');
      expect(year.singleMonth, isFalse);

      final partial = summaryHeadingFor(exportRangeFor(
        'custom',
        today: today,
        customStart: DateTime(2026, 10, 5),
        customEnd: DateTime(2026, 10, 20),
      ));
      expect(partial.period, 'Oct 5, 2026 - Oct 20, 2026');
      expect(partial.singleMonth, isFalse);
    });
  });

  group('export + share', () {
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    late Directory temp;
    late List<String> sharedPaths;
    late Map<String, Uint8List> sharedBytes;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('export_screen_test');
      sharedPaths = [];
      sharedBytes = {};
      messenger.setMockMethodCallHandler(
          pathProviderChannel, (_) async => temp.path);
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        final paths = ((call.arguments as Map)['paths'] as List).cast<String>();
        for (final path in paths) {
          sharedPaths.add(path);
          sharedBytes[path] = File(path).readAsBytesSync();
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(pathProviderChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
      temp.deleteSync(recursive: true);
    });

    /// Taps [button] and lets the export's real I/O (database read, isolate,
    /// file write, share) run until the result SnackBar shows.
    Future<void> exportVia(WidgetTester tester, String button) async {
      await pumpHarness(tester);
      await tester.pump();
      await tester.tap(find.text(button));
      for (var i = 0;
          i < 100 && find.byType(SnackBar).evaluate().isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.byType(SnackBar), findsOneWidget);
    }

    for (final button in const ['Export to CSV', 'Export to PDF']) {
      testWidgets('$button shares a temp file and deletes it afterwards',
          (tester) async {
        await exportVia(tester, button);

        expect(sharedPaths, hasLength(1));
        final path = sharedPaths.single;
        expect(path, startsWith(temp.path));
        expect(sharedBytes[path], isNotEmpty,
            reason: 'the file must exist while it is being shared');
        expect(File(path).existsSync(), isFalse,
            reason: 'the export is deleted once shared');
      });
    }

    testWidgets('the default All Time PDF is not titled as a month',
        (tester) async {
      await exportVia(tester, 'Export to PDF');

      final text = drawnPdfText(sharedBytes[sharedPaths.single]!);
      expect(text, contains('Financial Summary All time'));
      expect(text, isNot(contains('Monthly')));
      expect(text, isNot(contains('Budget Performance')));
    });
  });
}
