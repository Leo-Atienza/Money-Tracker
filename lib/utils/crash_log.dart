import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// FIX Phase 3a: Rolling local crash log + global error handler wiring.
///
/// The app had zero global error handlers before this: `FlutterError.onError`
/// was left at its default (print-to-console in debug, silent in release),
/// `PlatformDispatcher.instance.onError` was unset, and `runApp` was not
/// wrapped in a `runZonedGuarded`. Any crash in production disappeared
/// without a trace, so the "weekly/biweekly recurring never fires" and
/// "widget shows 0.00" bugs sat on real devices for weeks before they were
/// spotted by a code audit.
///
/// This class:
///
/// - Intercepts framework errors via `FlutterError.onError`
/// - Intercepts escaping async errors via `PlatformDispatcher.instance.onError`
/// - Is called from `runZonedGuarded` in `main()` (async errors in the zone)
/// - Writes each crash record to `crash.log` in the platform's application
///   support directory (not visible in the file browser, but accessible via
///   the in-app Settings → Crash Log screen and exportable with share_plus)
/// - Rotates log files at 256 KB, keeping up to 3 back files
///   (`crash.log` → `crash.log.1` → `crash.log.2`)
///
/// Usage:
/// ```dart
/// void main() {
///   runZonedGuarded(() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     await CrashLog.init(appVersion: '4.4.0+6');
///     runApp(const MyApp());
///   }, (error, stack) {
///     CrashLog.record(error, stack: stack, context: 'zone');
///   });
/// }
/// ```
class CrashLog {
  CrashLog._();

  /// Maximum size of a single log file before rotation.
  @visibleForTesting
  static const int maxLogBytes = 256 * 1024;

  /// Number of rotated files kept on disk (including the active one).
  @visibleForTesting
  static const int maxLogFiles = 3;

  static const String _logFilename = 'crash.log';

  static String _appVersion = 'unknown';
  static bool _initialized = false;

  /// Cached application support directory. Reset via [resetForTesting].
  static Directory? _cachedDir;

  /// Test-only override for the log directory. When set, [_logDir] returns
  /// this instead of the platform's application support directory. Allows
  /// the unit test to write into a temp directory without stubbing out
  /// `path_provider`.
  @visibleForTesting
  static Directory? directoryOverride;

  /// Chain of pending writes. Appending records are serialized so
  /// simultaneous errors don't interleave bytes in the log file.
  static Future<void> _writeQueue = Future<void>.value();

  /// Initialize the crash log and wire global error handlers.
  ///
  /// Idempotent: calling twice is a no-op. Safe to call from `main()` before
  /// `runApp()`. [appVersion] should be a compact identifier like
  /// `"4.4.0+6"` — it's prepended to every crash record so the exported log
  /// can be correlated with a specific build.
  static Future<void> init({required String appVersion}) async {
    if (_initialized) return;
    _appVersion = appVersion;
    _initialized = true;

    // 1. Flutter framework errors: widget build, layout, paint, gesture.
    FlutterError.onError = (details) {
      // Keep the default behavior (dump to console in debug, no-op in
      // release) so developers still see errors during local runs.
      FlutterError.presentError(details);
      record(
        details.exceptionAsString(),
        stack: details.stack,
        context: details.context?.toDescription(),
      );
    };

    // 2. Async errors that escape the Flutter framework zone. Returning
    //    `true` tells the engine the error has been handled and prevents
    //    the default terminate-with-stack behavior on release.
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack: stack, context: 'platform_dispatcher');
      return true;
    };
  }

  /// Record an error to the rolling log. Safe to call from any zone. Does
  /// not throw — failures are swallowed and printed to the debug console.
  ///
  /// [error] is converted to its string representation. [stack] is optional
  /// but strongly recommended. [context] is an optional free-form string
  /// (e.g. `'zone'`, `'recurring_processor'`, `'restore_backup'`) used to
  /// narrow down the call site when reading the log later.
  static Future<void> record(
    Object error, {
    StackTrace? stack,
    String? context,
  }) {
    // Serialize writes so concurrent errors don't produce interleaved bytes
    // in the log file.
    final next = _writeQueue.then(
      (_) => _writeRecord(
        error: error.toString(),
        stack: stack,
        context: context,
      ),
    );
    _writeQueue = next;
    return next;
  }

  /// Return the entire log (oldest rotated file first, then the active
  /// file). Used by the in-app crash log screen. Never throws.
  static Future<String> readAll() async {
    try {
      final dir = await _logDir();
      if (dir == null) return '';
      final buffer = StringBuffer();
      // Oldest → newest so the output reads chronologically.
      for (int i = maxLogFiles - 1; i >= 0; i--) {
        final file = _fileAt(dir, i);
        if (await file.exists()) {
          buffer.write(await file.readAsString());
        }
      }
      return buffer.toString();
    } catch (e) {
      return 'Error reading crash log: $e';
    }
  }

  /// Delete every rotated crash log file. Used by the Settings screen.
  /// Silent on error.
  static Future<void> clear() async {
    try {
      final dir = await _logDir();
      if (dir == null) return;
      for (int i = 0; i < maxLogFiles; i++) {
        final file = _fileAt(dir, i);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to clear crash log: $e');
    }
  }

  /// Reset all internal state. Test-only.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _appVersion = 'unknown';
    _cachedDir = null;
    directoryOverride = null;
    _writeQueue = Future<void>.value();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static Future<Directory?> _logDir() async {
    if (directoryOverride != null) return directoryOverride;
    if (_cachedDir != null) return _cachedDir;
    try {
      _cachedDir = await getApplicationSupportDirectory();
      return _cachedDir;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to get app support dir: $e');
      return null;
    }
  }

  static File _fileAt(Directory dir, int index) {
    final name = index == 0 ? _logFilename : '$_logFilename.$index';
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  static Future<void> _writeRecord({
    required String error,
    StackTrace? stack,
    String? context,
  }) async {
    try {
      final dir = await _logDir();
      if (dir == null) return;
      if (!await dir.exists()) await dir.create(recursive: true);

      final active = _fileAt(dir, 0);
      await _rotateIfNeeded(dir, active);

      final text = _formatRecord(
        error: error,
        stack: stack,
        context: context,
      );
      await active.writeAsString(text, mode: FileMode.append, flush: true);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to write crash log: $e');
    }
  }

  /// Rotate files when the active file would exceed [maxLogBytes].
  ///
  /// `crash.log.2` is deleted first (we only keep [maxLogFiles] files),
  /// then every remaining file is shifted up by one index. After rotation,
  /// the active file is empty and ready to receive new records.
  static Future<void> _rotateIfNeeded(Directory dir, File active) async {
    if (!await active.exists()) return;
    final size = await active.length();
    if (size < maxLogBytes) return;

    // Shift from the oldest slot down to slot 0:
    // crash.log.(N-1) is deleted, crash.log.(N-2) becomes crash.log.(N-1),
    // ..., crash.log becomes crash.log.1.
    for (int i = maxLogFiles - 1; i >= 1; i--) {
      final src = _fileAt(dir, i - 1);
      final dst = _fileAt(dir, i);
      if (await src.exists()) {
        if (await dst.exists()) await dst.delete();
        await src.rename(dst.path);
      }
    }
  }

  static String _formatRecord({
    required String error,
    StackTrace? stack,
    String? context,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final platform = redactPii(
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
    final buffer = StringBuffer()
      ..writeln('===== $timestamp =====')
      ..writeln('App: FinanceFlow $_appVersion')
      ..writeln('Platform: $platform');
    if (context != null && context.isNotEmpty) {
      buffer.writeln('Context: ${redactPii(context)}');
    }
    buffer.writeln('Error: ${redactPii(error)}');
    if (stack != null) {
      buffer
        ..writeln('Stack:')
        ..writeln(redactPii(stack.toString()));
    }
    buffer.writeln();
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Phase 6.6: PII redaction
  // ---------------------------------------------------------------------------

  /// Mask the highest-likelihood PII leaks before a record is persisted.
  /// Targets four classes that show up empirically in this app's logs:
  ///
  /// - **User paths.** The build host's username typically appears verbatim
  ///   in every stack trace as `C:\Users\jane\…` (or `/home/jane/…`).
  ///   The path *structure* survives; only the username is masked.
  /// - **Email addresses.** Defensive — the app doesn't handle them today,
  ///   but a future export-share flow could surface one in a wrapped
  ///   exception message.
  /// - **Currency-tagged amounts** (`$`, `€`, `£`, `¥`, `₹`). The app's
  ///   core data is money; any DB failure message can carry a formatted
  ///   balance into the error string.
  /// - **Long digit runs** that look like credit-card numbers (16 digits
  ///   with optional separators). The app doesn't store cards, but a
  ///   pasted-in description could.
  ///
  /// Pure function — safe to call from any zone, never throws.
  @visibleForTesting
  static String redactPii(String input) {
    if (input.isEmpty) return input;
    var out = input;
    out = out.replaceAll(_emailRe, '[email]');
    out = out.replaceAllMapped(
      _winUserPathRe,
      (m) => '${m.group(1)}[user]',
    );
    out = out.replaceAllMapped(
      _unixUserPathRe,
      (m) => '${m.group(1)}[user]',
    );
    out = out.replaceAll(_creditCardRe, '[cc]');
    out = out.replaceAll(_currencyRe, '[amount]');
    return out;
  }

  static final RegExp _emailRe = RegExp(
    r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b',
  );

  /// `C:\Users\jane\…` or `C:/Users/jane/…` — capture the prefix so the
  /// path keeps its shape (`C:\Users\[user]\…`).
  static final RegExp _winUserPathRe = RegExp(
    r'([A-Za-z]:[\\/]Users[\\/])[^\\/\s\x22\x27]+',
  );

  /// `/home/jane/…` and `/Users/jane/…` — same shape-preserving capture.
  static final RegExp _unixUserPathRe = RegExp(
    r'(/(?:home|Users)/)[^/\s\x22\x27]+',
  );

  /// 16 digits with optional `-` / space separators (`4111-1111-1111-1111`,
  /// `4111 1111 1111 1111`, `4111111111111111`). Loose enough to catch
  /// pasted card numbers, tight enough that an order id rarely matches.
  static final RegExp _creditCardRe = RegExp(
    r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b',
  );

  /// Currency-tagged amounts: `$123`, `$1,234.56`, `€5.00`, etc.
  static final RegExp _currencyRe = RegExp(
    r'[\$€£¥₹]\s?\d[\d,]*(?:\.\d+)?',
  );
}
