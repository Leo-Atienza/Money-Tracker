#!/usr/bin/env bash
#
# Pre-publish check for the release APK.
#
# Why this exists rather than relying on the Gradle warning: `flutter build apk`
# suppresses Gradle's output on success (a successful release build prints about
# four lines), so the `logger.warn` in android/app/build.gradle.kts is invisible
# in practice. Checking the built artifact is the only approach that survives
# that.
#
# What it enforces:
#   1. the artifact exists and is a plausible size,
#   2. the signature matches the project's intent — see below,
#   3. no x86/x86_64 native libraries (emulator-only dead weight in a download).
#
# On signing, the check is conditional rather than absolute, because
# debug-signed is the CURRENT DELIBERATE STATE of this project:
#
#   * android/key.properties present + APK debug-signed -> FAIL. The signing
#     config silently did not take effect, which is a real misconfiguration.
#   * android/key.properties absent -> WARN, exit 0. The app is distributed as
#     a direct APK download, not through Play, so a debug-signed build is
#     shippable. What matters is that the key is never lost — see
#     docs/RELEASE_SIGNING.md.
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
SHA=$(printf '%s\n' "$CERTS" | grep -m1 -i 'SHA-1 digest' || true)
printf '    %s\n    %s\n' "${DN:-<no DN reported>}" "${SHA:-<no SHA-1 reported>}"

IS_DEBUG_SIGNED=false
printf '%s\n' "$DN" | grep -qi 'CN=Android Debug' && IS_DEBUG_SIGNED=true

if [[ "$IS_DEBUG_SIGNED" == true ]]; then
  if [[ -f android/key.properties ]]; then
    fail "android/key.properties EXISTS but the APK is still debug-signed.
       The release signing config did not take effect — most likely storeFile
       does not resolve, or the build ran before the file was created. Check
       with:  cd android && ./gradlew :app:signingReport
       The release variant must report 'Config: release'."
  fi

  printf '%b    NOTE: debug-signed. That is expected — this project has no\n' "$YELLOW"
  printf '    android/key.properties yet, and for a direct APK download (no\n'
  printf '    Play Store) a debug-signed build installs and updates fine.%b\n' "$RESET"
  printf '    The debug key is randomly generated per machine, so this is NOT\n'
  printf '    a "anyone can forge an update" problem. The real exposure is\n'
  printf '    losing it: ~/.android/debug.keystore is the ONLY key that can\n'
  printf '    ever ship an update to existing installs. Back it up.\n'
  printf '    See docs/RELEASE_SIGNING.md.\n'
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
