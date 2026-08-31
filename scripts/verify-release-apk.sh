#!/usr/bin/env bash
#
# Pre-publish gate for the release APK.
#
# Why this exists rather than relying on the Gradle warning: `flutter build apk`
# suppresses Gradle's output on success (a successful release build prints about
# four lines), so the `logger.warn` in android/app/build.gradle.kts is invisible
# in practice. A debug-signed APK would sail through unnoticed — which is
# exactly how every release up to v5.1.2 shipped signed with the public Android
# debug key.
#
# This inspects the built artifact itself and refuses to pass it if:
#   1. it is signed with the debug key (anyone can forge an in-place update),
#   2. it still carries x86/x86_64 native libraries (emulator-only dead weight),
#   3. the file is missing or suspiciously small.
#
# Usage:  ./scripts/verify-release-apk.sh [path/to/app-release.apk]
# Exit 0 = safe to publish. Non-zero = do not publish.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

fail() {
  printf '\n%bFAIL%b — %s\n' "$RED" "$RESET" "$1" >&2
  exit 1
}

section() { printf '\n==> %s\n' "$1"; }

# --- 1. artifact exists and is plausible -------------------------------------
section "artifact"
[[ -f "$APK" ]] || fail "no APK at $APK — build it first"

BYTES=$(stat -c %s "$APK" 2>/dev/null || stat -f %z "$APK")
printf '    %s\n    %s bytes (%s MB)\n' "$APK" "$BYTES" "$((BYTES / 1048576))"
# A real release APK is tens of MB; anything tiny means a truncated or partial
# write rather than a finished build.
(( BYTES > 10000000 )) || fail "APK is only $BYTES bytes — that is not a complete build"

# --- 2. signer is NOT the debug key ------------------------------------------
section "signing"
SDK_DIR="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/AppData/Local/Android/Sdk}}"
APKSIGNER=$(find "$SDK_DIR/build-tools" \( -name 'apksigner.bat' -o -name 'apksigner' \) 2>/dev/null \
  | sort | tail -1)

if [[ -z "$APKSIGNER" ]]; then
  # Refusing to pass is the safe default: an unverifiable signature is exactly
  # the condition this script exists to catch.
  fail "apksigner not found under $SDK_DIR/build-tools — cannot verify the signature"
fi

CERTS=$("$APKSIGNER" verify --print-certs "$APK" 2>&1) || fail "apksigner could not verify $APK"
DN=$(printf '%s\n' "$CERTS" | grep -m1 'certificate DN:' || true)
printf '    %s\n' "${DN:-<no DN reported>}"

if printf '%s\n' "$DN" | grep -qi 'CN=Android Debug'; then
  fail "APK is signed with the ANDROID DEBUG KEY. Do not publish it.
       The debug key's password is public (androiddebugkey/android), so anyone
       could sign a forged update that Android installs over this app.
       Set up android/key.properties — see docs/RELEASE_SIGNING.md."
fi

# --- 3. no emulator-only ABIs ------------------------------------------------
section "ABIs"
ABIS=$(unzip -l "$APK" | grep -oE 'lib/[^/]+/' | sort -u | tr -d '/' | sed 's|^lib||')
printf '    packaged: %s\n' "$(echo "$ABIS" | tr '\n' ' ')"

if unzip -l "$APK" | grep -q 'lib/x86'; then
  printf '%b    x86/x86_64 libraries are present — that is ~6 MB of emulator-only\n' "$YELLOW"
  printf '    code in a published download.%b\n' "$RESET"
  fail "x86 ABIs present; build with --target-platform android-arm64,android-arm"
fi

printf '\n%brelease APK verified — safe to publish%b\n' "$GREEN" "$RESET"
