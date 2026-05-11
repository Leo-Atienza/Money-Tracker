import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 8.1 — structural lint covering the patterns the master plan
/// forbids. These cannot be expressed in `analysis_options.yaml`
/// directly (no custom linter package), so they live here as
/// grep-against-the-tree assertions. Adding one new file that violates
/// any of these rules fails CI.
///
/// Rules covered:
/// 1. **No `withOpacity(` in lib/** — Flutter 3.27+ flagged `withOpacity`
///    as deprecated. Every fade now goes through
///    `Color.withValues(alpha: …)` so the alpha channel is preserved in
///    wide-gamut color spaces.
/// 2. **No `print(` in lib/** — production code logs via `debugPrint`
///    (release-stripped) or `CrashLog.record` (persistent). Stray
///    `print` calls bypass both and dump to the IDE console only.
/// 3. **No `GoogleFonts` reference in lib/** — Phase 2.3 bundled
///    Hanken Grotesk as a variable font asset and removed the package.
/// 4. **No `import '../main.dart'` in lib/** — Phase 2.1 extracted
///    `AppColors` and other shared symbols out of `main.dart` so
///    sub-trees can stop importing the app's entrypoint.
/// 5. **No `import 'package:budget_tracker/...'` from inside lib/** —
///    use a relative path so the file moves with the package.
///
/// The walker honors `// ignore: forbidden_pattern` on the same line if
/// a single principled exception is ever needed (none today).
void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    fail('test/lint/no_forbidden_patterns_test must run from the repo root.');
  }
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  // Patterns mapped to a description shown when the test fails. The
  // matcher is a compiled regex applied line-by-line so the failure
  // message can include exact `file:line` coordinates.
  final rules = <String, RegExp>{
    'withOpacity(': RegExp(r'\.withOpacity\s*\('),
    'print( (use debugPrint or CrashLog.record)':
        RegExp(r'(?<![A-Za-z_])print\s*\('),
    'GoogleFonts reference (Phase 2.3 removed google_fonts)':
        RegExp(r'GoogleFonts'),
    "import '../main.dart' (Phase 2.1 extracted AppColors)":
        RegExp(r"""import\s+['\"]\.\./?main\.dart['\"]"""),
    "import 'package:budget_tracker/' from inside lib (use relative path)":
        RegExp(r"""import\s+['\"]package:budget_tracker/"""),
  };

  // Skip the test files this lint test itself ships under — otherwise
  // the regex above matches the test source code. (Currently empty —
  // every lib file is in scope.)
  const ignoredPaths = <String>{};

  group('lib/ free of forbidden patterns', () {
    for (final entry in rules.entries) {
      test(entry.key, () {
        final hits = <String>[];
        for (final file in dartFiles) {
          if (ignoredPaths.contains(file.path)) continue;
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.trimLeft().startsWith('//')) continue;
            if (line.contains('// ignore: forbidden_pattern')) continue;
            if (entry.value.hasMatch(line)) {
              hits.add('${file.path}:${i + 1}  ${line.trim()}');
            }
          }
        }
        expect(
          hits,
          isEmpty,
          reason:
              'Forbidden pattern "${entry.key}" found at:\n${hits.join('\n')}',
        );
      });
    }
  });
}
