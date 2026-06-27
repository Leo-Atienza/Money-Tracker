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
}
