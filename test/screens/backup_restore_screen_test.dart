import 'dart:io';

import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/backup_restore_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/utils/backup_crypto.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:file_picker/file_picker.dart';
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

  // -------------------------------------------------------------------------
  // Session 21 review fixes: confirm a picked file, time only the restore's
  // file work, close the progress dialog by its own route, and let the
  // passphrase prompt own its controller.
  // -------------------------------------------------------------------------

  /// Drives UI-started async work: file I/O and the database run on real
  /// I/O, so alternate real time with frames — until [until] holds when
  /// given (bounded, so a regression fails instead of hanging), then a few
  /// more rounds for the UI to settle.
  Future<void> settle(WidgetTester tester, {Finder? until}) async {
    Future<void> round() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    if (until != null) {
      for (var i = 0; i < 1000 && until.evaluate().isEmpty; i++) {
        await round();
      }
    }
    for (var i = 0; i < 30; i++) {
      await round();
    }
  }

  /// A per-test documents directory, so Recent Backups lists only what the
  /// test puts there.
  Future<Directory> useSandbox(WidgetTester tester) async {
    final sandbox = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('restore_screen_test_'),
    ))!;
    addTearDown(() {
      try {
        sandbox.deleteSync(recursive: true);
      } on FileSystemException {
        // A handle the restore still holds; the OS temp sweep gets it.
      }
    });
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => sandbox.path,
    );
    return sandbox;
  }

  Future<File> writeFile(
    WidgetTester tester,
    String path, {
    required bool encrypted,
  }) async {
    return (await tester.runAsync(() async {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        encrypted
            ? await BackupCrypto.encrypt(
                '{"version":4,"database":""}',
                'right-pass',
              )
            : 'not a backup',
      );
      return file;
    }))!;
  }

  String recentBackupPath(Directory sandbox, String name) => [
        sandbox.path,
        'backups',
        name,
      ].join(Platform.pathSeparator);

  Future<void> pumpRestoreHarness(
    WidgetTester tester, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: const BackupRestoreScreen(),
        ),
      ),
    );
    // The list (and its header) replaces the spinner once backups load.
    await settle(tester, until: find.text('RECENT BACKUPS'));
  }

  testWidgets('Choose Backup File asks before restoring the file it picked',
      (tester) async {
    final sandbox = await useSandbox(tester);
    final picked = await writeFile(
      tester,
      [sandbox.path, 'wrong-file.etbackup'].join(Platform.pathSeparator),
      encrypted: false,
    );
    final picker = _FakeFilePicker(_LocalPlatformFile(picked));
    final realPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = realPicker);
    await pumpRestoreHarness(tester);

    await tester.tap(find.text('Choose Backup File'));
    await settle(tester, until: find.byType(AlertDialog));

    // Restoring replaces all data: the pick alone must not start it.
    expect(picker.picks, 1);
    expect(find.text('Restore from "wrong-file.etbackup"?'), findsOneWidget);
    expect(find.text('Restoring backup...'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(tester);

    expect(find.text('Restoring backup...'), findsNothing);
    expect(find.text('Choose Backup File'), findsOneWidget);
  });

  testWidgets(
      'an encrypted restore waits on its passphrase prompt without timing '
      'out, and a wrong passphrase asks again cleanly', (tester) async {
    final sandbox = await useSandbox(tester);
    await writeFile(
      tester,
      recentBackupPath(sandbox, 'backup_1.etbackup'),
      encrypted: true,
    );
    await pumpRestoreHarness(tester);

    await tester.tap(find.textContaining('Tap to restore'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await settle(tester, until: find.text('Restore encrypted backup'));
    expect(find.text('Restore encrypted backup'), findsOneWidget);

    // The restore's timeout covers its file work only. It used to run
    // through this prompt too, and on expiry popped whatever was on top:
    // here, the prompt itself.
    await tester.pump(const Duration(minutes: 4));
    expect(find.text('Restore encrypted backup'), findsOneWidget);
    expect(find.text('Operation timed out. Please try again.'), findsNothing);

    // A wrong passphrase closes the prompt and opens a fresh one; the
    // closing prompt must not touch a controller that is already disposed.
    await tester.enterText(find.byType(TextField), 'wrong-pass');
    await tester.tap(find.widgetWithText(TextButton, 'Decrypt'));
    await settle(tester, until: find.text('Wrong passphrase — try again.'));
    expect(find.text('Wrong passphrase — try again.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(tester, until: find.text('Restore cancelled'));
    expect(find.text('Restore encrypted backup'), findsNothing);
    expect(find.text('Restoring backup...'), findsNothing);
    expect(find.text('Restore cancelled'), findsOneWidget);
  });

  testWidgets(
      'a restore that overruns its timeout closes only its own progress '
      'dialog and stays busy until the restore ends', (tester) async {
    final sandbox = await useSandbox(tester);
    await writeFile(
      tester,
      recentBackupPath(sandbox, 'broken.etbackup'),
      encrypted: false,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await pumpRestoreHarness(tester, navigatorKey: navigatorKey);

    await tester.tap(find.textContaining('Tap to restore'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pump();
    expect(find.text('Restoring backup...'), findsOneWidget);

    // A route lands above the progress dialog, as the PIN unlock screen
    // does when the app resumes mid-restore.
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Unlock')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // No real I/O has run since the restore started, so its file work is
    // still pending when the clock runs out.
    await tester.pump(const Duration(minutes: 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Unlock'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Restoring backup...'), findsNothing);
    // The restore cannot be cancelled, so the screen stays busy (no second
    // restore can start over it) until it ends.
    expect(find.text('Restoring...'), findsOneWidget);

    await settle(tester, until: find.text('Choose Backup File'));
    expect(find.text('Choose Backup File'), findsOneWidget);
    // The outcome still lands (queued behind the "taking longer" notice).
    final outcome =
        find.text('Invalid backup file. Please select a valid database backup.');
    await settle(tester, until: outcome);
    expect(outcome, findsOneWidget);
  });
}


/// Stands in for the system file picker: hands back one fixed file.
class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this.file);

  final PlatformFile? file;
  int picks = 0;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    picks++;
    return file;
  }
}

/// A picked file on local disk, as Android's picker returns after caching
/// the pick.
final class _LocalPlatformFile extends PlatformFile {
  _LocalPlatformFile(this._file);

  final File _file;

  @override
  String get name => _file.uri.pathSegments.last;

  @override
  Uri get uri => _file.absolute.uri;

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => null;

  @override
  Future<int> length() => _file.length();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      _file.openRead().map(Uint8List.fromList);
}
