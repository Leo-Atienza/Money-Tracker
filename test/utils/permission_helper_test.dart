import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/permission_helper.dart';

/// Tests for [PermissionHelper] (Phase 7 — NEXT_SESSION_HANDOFF
/// `lib/utils/permission_helper.dart` per-file gaps).
///
/// IMPORTANT host constraint: the unit-test host here is **not Android**
/// (`Platform.isAndroid == false`). Both public *permission-status* methods
/// short-circuit on the non-Android branch before they ever touch the
/// `permission_handler` / `budget_tracker/device_info` channels:
///
///   * `requestStoragePermission` → `if (!Platform.isAndroid) return true;`
///   * `hasStoragePermission`      → `if (!Platform.isAndroid) return true;`
///
/// The source exposes no seam to override `Platform.isAndroid` nor the
/// private `_cachedAndroidSdk` cache, so the SDK-33 / SDK-30 / SDK-29
/// branches (and the permanently-denied settings dialog reached only on
/// SDK ≤ 29) are unreachable from a non-Android host. Those cases are
/// reported as deferred rather than faked. What we *can* pin deterministically
/// and host-independently:
///
///   1. the non-Android contract of both status methods (return `true`);
///   2. all of `showPermissionDeniedSnackbar`, which has no `Platform` guard
///      and is fully widget-testable on any host — message, orange colour,
///      5-second duration, the "Settings" action that dispatches
///      `AppSettings.openAppSettings` (channel `openSettings`), and the
///      `!context.mounted` early-return guard.
void main() {
  // Guard: these host-independent assertions only hold on a non-Android host.
  // If this suite is ever run on Android the non-Android branch tests below
  // would be exercising a different code path, so assert the precondition.
  final bool runningOnAndroid = Platform.isAndroid;

  // The Android-branch tests below drive the SDK 29/30/33 paths through the
  // @visibleForTesting seams. Always clear them so an override never leaks
  // into the non-Android contract tests above.
  tearDown(PermissionHelper.debugResetForTest);

  group('PermissionHelper.requestStoragePermission (non-Android host)', () {
    testWidgets('returns true on non-Android without touching any channel',
        (tester) async {
      if (runningOnAndroid) {
        markTestSkipped('Host is Android; non-Android branch not exercised.');
        return;
      }

      // Spy on the permission_handler channel: it must NOT be called on the
      // non-Android branch (the method returns before any platform call).
      var permissionChannelCalls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const permissionChannel =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      messenger.setMockMethodCallHandler(permissionChannel, (call) async {
        permissionChannelCalls++;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(permissionChannel, null),
      );

      late bool result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await PermissionHelper.requestStoragePermission(ctx);
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();

      expect(result, isTrue);
      expect(permissionChannelCalls, 0,
          reason: 'non-Android branch must not call permission_handler');
    });
  });

  group('PermissionHelper.hasStoragePermission (non-Android host)', () {
    test('returns true on non-Android without checking permission status',
        () async {
      if (runningOnAndroid) {
        markTestSkipped('Host is Android; non-Android branch not exercised.');
        return;
      }

      var permissionChannelCalls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const permissionChannel =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      messenger.setMockMethodCallHandler(permissionChannel, (call) async {
        permissionChannelCalls++;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(permissionChannel, null),
      );

      final granted = await PermissionHelper.hasStoragePermission();

      expect(granted, isTrue);
      expect(permissionChannelCalls, 0,
          reason: 'non-Android branch returns before reading status');
    });
  });

  group('PermissionHelper.showPermissionDeniedSnackbar', () {
    // The app_settings plugin (v7) dispatches openAppSettings() to
    // method `openSettings` on this channel. Spy on it to prove the
    // "Settings" snackbar action actually opens settings.
    const appSettingsChannel =
        MethodChannel('com.spencerccf.app_settings/methods');

    late List<MethodCall> appSettingsCalls;
    late TestDefaultBinaryMessenger messenger;

    setUp(() {
      appSettingsCalls = <MethodCall>[];
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(appSettingsChannel, (call) async {
        appSettingsCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(appSettingsChannel, null);
    });

    Widget harness({required void Function(BuildContext) onPressed}) {
      return MaterialApp(
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

    testWidgets('shows an orange SnackBar with the permission message',
        (tester) async {
      await tester.pumpWidget(
        harness(
          onPressed: PermissionHelper.showPermissionDeniedSnackbar,
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump(); // start entrance animation

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, Colors.orange);
      expect(
        find.textContaining('Storage permission is required'),
        findsOneWidget,
      );
    });

    testWidgets('SnackBar shows for 5 seconds', (tester) async {
      await tester.pumpWidget(
        harness(
          onPressed: PermissionHelper.showPermissionDeniedSnackbar,
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump();

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.duration, const Duration(seconds: 5));
    });

    testWidgets('has a "Settings" action that opens app settings',
        (tester) async {
      await tester.pumpWidget(
        harness(
          onPressed: PermissionHelper.showPermissionDeniedSnackbar,
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pump(); // schedule snackbar
      await tester.pump(const Duration(milliseconds: 750)); // play it in

      final actionFinder = find.widgetWithText(SnackBarAction, 'Settings');
      expect(actionFinder, findsOneWidget);

      final action = tester.widget<SnackBarAction>(actionFinder);
      expect(action.textColor, Colors.white);

      // No settings call yet — only the tap should trigger it.
      expect(appSettingsCalls, isEmpty);

      await tester.tap(actionFinder);
      await tester.pump();
      await tester.idle();

      expect(appSettingsCalls.length, 1);
      expect(appSettingsCalls.single.method, 'openSettings');
    });

    testWidgets('no-op when context is unmounted (mounted guard)',
        (tester) async {
      // Capture a context that becomes unmounted after the widget is gone.
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                captured = ctx;
                return const Text('alive');
              },
            ),
          ),
        ),
      );

      // Replace the tree so `captured` is no longer mounted.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(captured.mounted, isFalse);

      // Should return early without throwing and without showing a SnackBar.
      PermissionHelper.showPermissionDeniedSnackbar(captured);
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Android SDK branches — exercised via the @visibleForTesting seams
  // (debugIsAndroidOverride + debugAndroidSdkOverride). These reach the
  // permission_handler channel, which we mock directly.
  //
  // Protocol (permission_handler_platform_interface 4.3.0):
  //   * Permission.storage.value == 15
  //   * checkPermissionStatus(15) -> int status
  //   * requestPermissions([15]) -> {15: int status}
  //   * status ints: 0 denied, 1 granted, 2 restricted, 4 permanentlyDenied
  // ---------------------------------------------------------------------------
  group('PermissionHelper Android SDK branches', () {
    const permissionChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');
    const int kStorage = 15;
    const int kDenied = 0;
    const int kGranted = 1;
    const int kRestricted = 2;
    const int kPermanentlyDenied = 4;

    late List<MethodCall> calls;
    late TestDefaultBinaryMessenger messenger;
    // Per-test configurable channel responses.
    late int checkStatus;
    late int requestStatus;

    setUp(() {
      calls = <MethodCall>[];
      checkStatus = kGranted;
      requestStatus = kGranted;
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(permissionChannel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'checkPermissionStatus':
            return checkStatus;
          case 'requestPermissions':
            return <int, int>{kStorage: requestStatus};
          default:
            return null;
        }
      });
      // Force the Android path; SDK is set per-test.
      PermissionHelper.debugIsAndroidOverride = true;
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(permissionChannel, null);
    });

    int statusChecks() =>
        calls.where((c) => c.method == 'checkPermissionStatus').length;
    int requests() =>
        calls.where((c) => c.method == 'requestPermissions').length;

    // Mounts a minimal tree (MaterialApp provides the Navigator the dialog
    // path needs) and returns a context BELOW it. The non-dialog branches
    // never touch the context, so we can await the future directly in the
    // test body — method-channel mock responses resolve on microtasks, which
    // a plain `await` drains without frame-pump counting.
    Future<BuildContext> mountContext(WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return ctx;
    }

    group('requestStoragePermission', () {
      testWidgets('SDK 33+ returns true without touching the channel',
          (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 33;
        final ctx = await mountContext(tester);
        final granted = await PermissionHelper.requestStoragePermission(ctx);

        expect(granted, isTrue);
        expect(calls, isEmpty,
            reason: 'SAF on API 33+ needs no permission call');
      });

      testWidgets('SDK 30 granted -> true (status check, no request)',
          (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 30;
        checkStatus = kGranted;
        final ctx = await mountContext(tester);
        final granted = await PermissionHelper.requestStoragePermission(ctx);

        expect(granted, isTrue);
        expect(statusChecks(), 1);
        expect(requests(), 0);
      });

      testWidgets('SDK 30 restricted (SAF-only) -> true', (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 30;
        checkStatus = kRestricted;
        final ctx = await mountContext(tester);
        final granted = await PermissionHelper.requestStoragePermission(ctx);

        expect(granted, isTrue);
        expect(requests(), 0);
      });

      testWidgets('SDK 30 permanentlyDenied -> true without requesting',
          (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 30;
        checkStatus = kPermanentlyDenied;
        final ctx = await mountContext(tester);
        final granted = await PermissionHelper.requestStoragePermission(ctx);

        expect(granted, isTrue, reason: 'SAF works regardless on API 30+');
        expect(requests(), 0);
      });

      testWidgets('SDK 30 denied -> requests, then true regardless',
          (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 30;
        checkStatus = kDenied;
        requestStatus = kDenied; // even a denied request still returns true
        final ctx = await mountContext(tester);
        final granted = await PermissionHelper.requestStoragePermission(ctx);

        expect(granted, isTrue);
        expect(statusChecks(), 1);
        expect(requests(), 1);
      });

      testWidgets('SDK 29 already granted -> true', (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 29;
        checkStatus = kGranted;
        final ctx = await mountContext(tester);
        final granted = await PermissionHelper.requestStoragePermission(ctx);

        expect(granted, isTrue);
        expect(statusChecks(), 1);
        expect(requests(), 0);
      });

      testWidgets('SDK 29 denied then request granted -> true', (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 29;
        checkStatus = kDenied;
        requestStatus = kGranted;
        final ctx = await mountContext(tester);
        final granted = await PermissionHelper.requestStoragePermission(ctx);

        expect(granted, isTrue);
        expect(statusChecks(), 1);
        expect(requests(), 1);
      });

      testWidgets('SDK 29 denied then request denied -> false', (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 29;
        checkStatus = kDenied;
        requestStatus = kDenied;
        final ctx = await mountContext(tester);
        final granted = await PermissionHelper.requestStoragePermission(ctx);

        expect(granted, isFalse);
        expect(requests(), 1);
      });

      testWidgets(
          'SDK 29 permanentlyDenied -> shows settings dialog; Cancel -> false',
          (tester) async {
        PermissionHelper.debugAndroidSdkOverride = 29;
        checkStatus = kPermanentlyDenied;

        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () async => result = await PermissionHelper
                      .requestStoragePermission(ctx),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();

        expect(find.text('Storage Permission Required'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(result, isFalse);
        expect(requests(), 0,
            reason: 'permanentlyDenied goes straight to the dialog');
      });
    });

    group('hasStoragePermission', () {
      test('SDK 30+ returns true without checking status', () async {
        PermissionHelper.debugAndroidSdkOverride = 30;
        final granted = await PermissionHelper.hasStoragePermission();

        expect(granted, isTrue);
        expect(statusChecks(), 0, reason: 'SAF on API 30+ needs no status read');
      });

      test('SDK 29 granted -> true', () async {
        PermissionHelper.debugAndroidSdkOverride = 29;
        checkStatus = kGranted;
        final granted = await PermissionHelper.hasStoragePermission();

        expect(granted, isTrue);
        expect(statusChecks(), 1);
      });

      test('SDK 29 denied -> false', () async {
        PermissionHelper.debugAndroidSdkOverride = 29;
        checkStatus = kDenied;
        final granted = await PermissionHelper.hasStoragePermission();

        expect(granted, isFalse);
        expect(statusChecks(), 1);
      });
    });
  });
}
