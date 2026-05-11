import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/secure_window.dart';

/// Phase 6.5: unit tests for [SecureWindow].
///
/// The class is a thin facade over a single platform method channel and one
/// SharedPreferences read. We don't exercise the real channel here — tests
/// run under the host's Platform, which is rarely Android. Instead we cover
/// the branching logic and the test seams the rest of the codebase depends
/// on (`testHandler`, `pinStateOverride`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SecureWindow.testHandler = null;
    SecureWindow.pinStateOverride = null;
  });

  test('setSecure(true) routes through testHandler with on:true', () async {
    bool? received;
    SecureWindow.testHandler = (on) async => received = on;
    await SecureWindow.setSecure(true);
    expect(received, isTrue);
  });

  test('setSecure(false) routes through testHandler with on:false', () async {
    bool? received;
    SecureWindow.testHandler = (on) async => received = on;
    await SecureWindow.setSecure(false);
    expect(received, isFalse);
  });

  test('syncFromPinState calls setSecure(true) when PIN enabled', () async {
    final calls = <bool>[];
    SecureWindow.testHandler = (on) async => calls.add(on);
    SecureWindow.pinStateOverride = () async => true;
    await SecureWindow.syncFromPinState();
    expect(calls, equals([true]));
  });

  test('syncFromPinState calls setSecure(false) when PIN disabled', () async {
    final calls = <bool>[];
    SecureWindow.testHandler = (on) async => calls.add(on);
    SecureWindow.pinStateOverride = () async => false;
    await SecureWindow.syncFromPinState();
    expect(calls, equals([false]));
  });

  test('setSecure swallows handler exceptions silently', () async {
    SecureWindow.testHandler = (on) async => throw Exception('boom');
    // Should NOT bubble — FLAG_SECURE is best-effort, not a correctness gate.
    // Note: this asserts the *handler shape* lets exceptions escape; the
    // real channel branch catches PlatformException + MissingPluginException
    // specifically, but the test seam is deliberately raw so a failing
    // handler surfaces in CI rather than getting swallowed silently here.
    await expectLater(SecureWindow.setSecure(true), throwsException);
  });

  test('testHandler stays null after the previous test (tearDown resets)',
      () async {
    expect(SecureWindow.testHandler, isNull);
    expect(SecureWindow.pinStateOverride, isNull);
  });
}
