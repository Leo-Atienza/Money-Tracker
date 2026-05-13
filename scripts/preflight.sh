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
# Phase 7.10 (D.10): also gate on the pass count so a silent drop in
# coverage (test file deleted, expectations weakened) still fails CI
# even when the remaining tests pass. The floor is the previous-release
# baseline + 50 — bump it each release to ratchet up coverage.
TEST_COUNT_MIN=1750
TEST_OUT=$(mktemp)
trap 'rm -f "$TEST_OUT"' EXIT
if ! flutter test --concurrency=4 --reporter=expanded 2>&1 | tee "$TEST_OUT"; then
  fail "flutter test failed"
fi
# `--reporter=expanded` prints the final tally as either
# `+NNNN: All tests passed!`, `+NNNN ~SS: All tests passed!` (with
# skipped tests), or `+NNNN -M: Some tests failed.`. Parse the leading
# `+NNNN` from the last line that contains "All tests passed!" — the
# previous block has already exited non-zero if any test failed.
PASS_COUNT=$(grep -oE '\+[0-9]+( ~[0-9]+)?: All tests passed!' "$TEST_OUT" \
  | tail -1 | grep -oE '\+[0-9]+' | head -1 | tr -d '+')
if [[ -z "$PASS_COUNT" ]]; then
  fail "could not parse pass count from flutter test output"
fi
printf '\n==> test pass count: %s (gate: >=%s)\n' "$PASS_COUNT" "$TEST_COUNT_MIN"
if (( PASS_COUNT < TEST_COUNT_MIN )); then
  fail "test pass count $PASS_COUNT is below gate $TEST_COUNT_MIN"
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
