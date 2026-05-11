#!/usr/bin/env bash
#
# Phase 8.1 — pre-merge gate.
#
# Runs the two non-negotiable checks every commit on `release/v5.0.0`
# (and eventually `main`) must pass:
#
#   1. `flutter analyze` — zero issues. The repo's baseline is "No issues
#      found"; anything less than that breaks CI.
#   2. `flutter test` — every test, every time. The suite includes the
#      structural lint tests under `test/lint/` that enforce:
#        - no `Navigator.pushNamed` to unregistered routes
#        - no `context.watch<AppState>` outside the allow-list
#        - no `print(` / `withOpacity(` / `GoogleFonts` / package
#          self-imports / `import '../main.dart'` inside `lib/`
#        - hardened AndroidManifest (allowBackup=false, etc.)
#        - notification visibility = private
#        - reduced blur sigma + RepaintBoundary placement
#        - NotificationHelper singleton, FocusManager hooks, etc.
#
# Exit code 0 on green, non-zero on failure.
#
# Invocation: `./scripts/preflight.sh` from the repo root (or from
# anywhere — the script chdir's to its own directory's parent).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

section() {
  printf '\n==> %s\n' "$1"
}

fail() {
  printf '\n%bFAIL%b — %s\n' "$RED" "$RESET" "$1" >&2
  exit 1
}

# 1. Static analyzer.
section "flutter analyze"
if ! flutter analyze; then
  fail "flutter analyze reported issues"
fi

# 2. Full test suite (includes test/lint/ structural checks).
section "flutter test"
if ! flutter test --concurrency=4; then
  fail "flutter test failed"
fi

# 3. Belt-and-braces grep — duplicates the lint tests' coverage so a
#    hand-grep in CI surfaces the offender even if the test file is
#    accidentally deleted. Each pattern below MUST be empty.
section "forbidden pattern sweep (lib/)"

scan() {
  local pattern="$1"
  local label="$2"
  if grep -rn --include='*.dart' -E "$pattern" lib/ 2>/dev/null; then
    fail "Forbidden pattern hit: $label"
  fi
}

scan '\.withOpacity\s*\('                              "withOpacity(  (use withValues(alpha: …))"
scan '(^|[^A-Za-z_])print\s*\('                        'print(  (use debugPrint or CrashLog.record)'
scan 'GoogleFonts'                                     'GoogleFonts reference  (Phase 2.3 removed package)'
scan "import +['\"]\\.\\.?/main\\.dart['\"]"           "import '../main.dart'  (Phase 2.1 extracted AppColors)"
scan "import +['\"]package:budget_tracker/"            'package self-import  (use relative path)'

printf '\n%bpreflight green%b\n' "$GREEN" "$RESET"
