#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# release_ios.sh — version-number regression test (no build, no network, ~1s)
# ==============================================================================
# Why this file exists
# ---------------------
# `--build-number` used to reach nothing but an echo statement. The script read the number it
# would print, then archived whatever CURRENT_PROJECT_VERSION happened to be in the generated
# Xcode project. So `./release_ios.sh --upload --build-number 21` would print
# "uploading build 21" and upload build 20 — the exact number App Store Connect dedupes on, whose
# rejection (ITMS-4238 "Redundant Binary Upload") never mentions version overrides.
#
# The same block also *adopted* the build number from the exported pbxproj, so a stale
# Godot/build/ios/ left over from an older run silently decided what the release claimed to be:
# observed 2026-09-20, --dry-run printed "build 1" while export_presets.cfg said 20.
#
# Both failures are invisible to every other suite in this repo: they are not Godot code, they
# need no rendering, and they only show up as a wrong number in a log line or a rejected upload
# minutes later. Hence a plain shell test, asserting on the decision rather than on a build.
#
# What it checks
# --------------
#   1. --build-number <n> wins, and is reported as n.
#   2. With no flag, the number comes from export_presets.cfg (never from a stale export).
#   3. The archive command actually carries both values as xcodebuild build-setting overrides —
#      i.e. the number is *applied*, not merely printed.
#   4. The build number is never reassigned from the exported pbxproj.
#   5. Invalid / valueless --build-number values fail loudly instead of silently falling back.
#
# --dry-run is used throughout because it prints the resolved numbers and runs no build; it also
# continues past preflight failures by design, so this test does not require an Apple Distribution
# certificate, a signed-in App Store Connect account, or a configured machine.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_SCRIPT="$REPO_DIR/release_ios.sh"
PRESET="$REPO_DIR/Godot/export_presets.cfg"

PASS=0
FAIL=0
ok()   { echo "  ✓ $1"; PASS=$((PASS + 1)); }
bad()  { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "== release_ios.sh version-number regression =="

[ -f "$RELEASE_SCRIPT" ] || { echo "  ✗ missing $RELEASE_SCRIPT"; exit 1; }
[ -f "$PRESET" ]         || { echo "  ✗ missing $PRESET"; exit 1; }

PRESET_BUILD="$(grep -m1 'application/version' "$PRESET" | cut -d'"' -f2)"
PRESET_SHORT="$(grep -m1 'application/short_version' "$PRESET" | cut -d'"' -f2)"

# --- 1 & 2: what number does a run report? -----------------------------------
reported_build() {   # reported_build [--build-number N]
    "$RELEASE_SCRIPT" --dry-run "$@" 2>&1 \
        | sed -n 's/.*Marketing version [^,]*, build \([0-9]*\).*/\1/p' | head -1
}

GOT="$(reported_build --build-number 21)"
[ "$GOT" = "21" ] && ok "--build-number 21 is reported as 21" \
                  || bad "--build-number 21 reported '$GOT' (expected 21)"

GOT="$(reported_build)"
[ "$GOT" = "$PRESET_BUILD" ] && ok "no flag reports export_presets.cfg's $PRESET_BUILD" \
                             || bad "no flag reported '$GOT' (expected preset $PRESET_BUILD)"

# The stale-export trap: a leftover Godot/build/ios/ used to be able to override this. Assert the
# decision cannot come from there by checking the script never assigns BUILD_NUMBER from it.
if grep -qE 'BUILD_NUMBER="\$EXPORTED_BUILD"' "$RELEASE_SCRIPT"; then
    bad "BUILD_NUMBER is still adopted from the exported pbxproj (stale export can rename a release)"
else
    ok "BUILD_NUMBER is never taken from the exported pbxproj"
fi

# --- 3: is the number actually applied to the build? -------------------------
# The archive line is where it has to appear; a number that only reaches echo is the original bug.
ARCHIVE_CMD="$(sed -n '/^run xcodebuild -project/,/^    archive$/p' "$RELEASE_SCRIPT")"
if printf '%s' "$ARCHIVE_CMD" | grep -q 'CURRENT_PROJECT_VERSION="\$BUILD_NUMBER"'; then
    ok "archive passes CURRENT_PROJECT_VERSION=\$BUILD_NUMBER (the number reaches the artifact)"
else
    bad "archive does not pass CURRENT_PROJECT_VERSION — --build-number would be inert again"
fi
if printf '%s' "$ARCHIVE_CMD" | grep -q 'MARKETING_VERSION="\$SHORT_VERSION"'; then
    ok "archive passes MARKETING_VERSION=\$SHORT_VERSION"
else
    bad "archive does not pass MARKETING_VERSION"
fi

# Both overrides are only meaningful because the template resolves its plist keys to them. If a
# future template inlines literals instead, these arguments become decorative and this whole
# mechanism silently stops working -- so assert the indirection the overrides rely on.
# Note the plist puts each key and its value on separate lines, so this reads the value line that
# follows the key rather than trying to match both on one line (the first version of this check
# did exactly that and "passed" by skipping, which is the failure mode it was written to catch).
TEMPLATE_PLIST="$(mktemp)"
if unzip -p "$HOME/Library/Application Support/Godot/export_templates"/4.*.stable/ios.zip \
        'godot_apple_embedded/godot_apple_embedded-Info.plist' > "$TEMPLATE_PLIST" 2>/dev/null \
        && [ -s "$TEMPLATE_PLIST" ]; then
    if grep -A1 '<key>CFBundleVersion</key>' "$TEMPLATE_PLIST" \
            | grep -q 'CURRENT_PROJECT_VERSION'; then
        ok "iOS template resolves CFBundleVersion to \$(CURRENT_PROJECT_VERSION)"
    else
        bad "template's CFBundleVersion is not \$(CURRENT_PROJECT_VERSION) — the override is inert"
    fi
    if grep -A1 '<key>CFBundleShortVersionString</key>' "$TEMPLATE_PLIST" \
            | grep -q 'MARKETING_VERSION'; then
        ok "iOS template resolves CFBundleShortVersionString to \$(MARKETING_VERSION)"
    else
        bad "template's CFBundleShortVersionString is not \$(MARKETING_VERSION)"
    fi
else
    echo "  – template not found; skipped (install iOS export templates to run this check)"
fi
rm -f "$TEMPLATE_PLIST"

# --- 4: the archive is verified, not assumed --------------------------------
if grep -q 'plutil -extract CFBundleVersion raw "\$ARCHIVED_PLIST"' "$RELEASE_SCRIPT"; then
    ok "archive's own Info.plist is checked after the build"
else
    bad "no post-archive CFBundleVersion check — a silently-ignored override would go unnoticed"
fi

# --- 5: bad input fails loudly ----------------------------------------------
expect_fail() {   # expect_fail <label> <args...>
    local label="$1"; shift
    if "$RELEASE_SCRIPT" --dry-run "$@" >/dev/null 2>&1; then
        bad "$label was accepted (expected a non-zero exit)"
    else
        ok "$label is rejected"
    fi
}
expect_fail "--build-number abc" abc
expect_fail "--build-number (no value)" ""
expect_fail "--build-number -1" -1

# --- 6: the export/re-sign step, and which artifact the signing checks read -----
# Distribution signing moved out of the archive and into -exportArchive, so the file that decides
# whether an upload works is now the .ipa. These assert the checks followed it there, that the
# archive no longer hard-fails on the development profile it is expected to carry (that conflict
# made a route-B archive impossible: measured 2026-09-21), and that a plain run cannot upload.
if grep -qF 'xcodebuild -exportArchive' "$RELEASE_SCRIPT"; then
    ok "an -exportArchive step exists (the .ipa is produced by the script)"
else
    bad "no -exportArchive step — nothing re-signs the archive for distribution"
fi

if grep -qF '<key>method</key><string>app-store-connect</string>' "$RELEASE_SCRIPT"; then
    ok "export uses method=app-store-connect"
else
    bad "export does not use app-store-connect (Xcode 15 rejects the old 'app-store' value)"
fi

# The regression that motivated route B: a development-signed archive is the *expected* input here.
if grep -qF 'The archive is signed with a DEVELOPMENT profile' "$RELEASE_SCRIPT"; then
    bad "the archive still hard-fails on a development profile — distribution signing could never run"
else
    ok "the archive no longer fails on a development profile (distribution is checked on the .ipa)"
fi

if grep -qF 'ProvisionedDevices raw "$IPA_PROFILE_PLIST"' "$RELEASE_SCRIPT"; then
    ok "the .ipa's embedded profile is checked for a device list"
else
    bad "the .ipa's profile is not checked for ProvisionedDevices — a dev-signed upload could slip through"
fi

if grep -qF 'get-task-allow' "$RELEASE_SCRIPT" && grep -qF 'IPA_GTA' "$RELEASE_SCRIPT"; then
    ok "the .ipa is checked for get-task-allow (a debuggable build must not upload)"
else
    bad "get-task-allow is not checked on the .ipa"
fi

if grep -qF '*Distribution*)' "$RELEASE_SCRIPT"; then
    ok "the .ipa's signing Authority must be a Distribution certificate"
else
    bad "the .ipa's signing Authority is not verified to be a Distribution one"
fi

if grep -qF 'beta-reports-active' "$RELEASE_SCRIPT"; then
    ok "the TestFlight entitlement (beta-reports-active) is reported"
else
    bad "beta-reports-active is not checked — a build TestFlight refuses would look fine"
fi

# A plain `./release_ios.sh` must never reach Apple. The verify-only export is the one that passes
# an empty destination; destination=upload must belong solely to the --upload path.
if grep -qF 'write_export_options "$EXPORT_OPTIONS" ""' "$RELEASE_SCRIPT"; then
    ok "the verify-only export sets no destination (a plain run uploads nothing)"
else
    bad "the non-upload export may be setting destination=upload — a plain run could upload"
fi

if grep -qF 'write_export_options "$EXPORT_OPTIONS" "upload"' "$RELEASE_SCRIPT"; then
    ok "--upload is the only path that sets destination=upload"
else
    bad "no upload path found — --upload would export without uploading"
fi

echo "== $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] || exit 1
