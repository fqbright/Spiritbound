#!/bin/bash
set -euo pipefail

# ==============================================================================
# Spiritbound — iOS release build (archive → TestFlight / App Store)
# ==============================================================================
# deploy_ios.sh is the developer loop: it exports a DEBUG build, installs it on a cabled iPhone
# and launches it. That is the right tool 99% of the time. This is the other tool: the App Store
# artifact, which is a different build (release, distribution-signed, archived) and a different
# destination (App Store Connect). Before this script existed there was no release path in the
# repo at all — only `--export-debug` plus `xcodebuild build`, neither of which can be submitted.
#
# Usage:
#   ./release_ios.sh --dry-run                 # print every command, change nothing (start here)
#   ./release_ios.sh                           # archive + export a store-signed .ipa (no upload)
#   ./release_ios.sh --build-number 7          # override the build number for this archive
#   ./release_ios.sh --upload                  # ...then upload it to App Store Connect
#
# What it deliberately does NOT do: bump the marketing version (application/short_version in
# Godot/export_presets.cfg). That is a release decision, not a build detail — set it yourself
# and commit it, so the version in the binary always matches a commit.
#
# Signing happens in two stages, the way Xcode's own Organizer splits it:
#   [4/6] archive — signs with the identity the generated project resolves, which Godot's preset
#                   pins to "iPhone Developer". Pinning a distribution identity there instead makes
#                   Xcode refuse to archive at all: a manually specified identity conflicts with
#                   the project's automatic signing. So that pin is left alone.
#   [5/6] export  — -exportArchive re-signs that archive with an Apple Distribution identity and a
#                   Store provisioning profile, and produces the .ipa that gets uploaded.
# --allowProvisioningUpdates lets Xcode fetch or create the distribution certificate and profile
# from the Apple account signed into Xcode, which is why there is no password anywhere here. If the
# account has no distribution certificate yet: Xcode → Settings → Accounts → Manage Certificates.
# ==============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$REPO_DIR/Godot"
BUILD_DIR="$PROJECT_DIR/build/ios"
ARCHIVE_DIR="$PROJECT_DIR/build/release"
ARCHIVE_PATH="$ARCHIVE_DIR/Spiritbound.xcarchive"
EXPORT_DIR="$ARCHIVE_DIR/export"
EXPORT_OPTIONS="$ARCHIVE_DIR/ExportOptions.plist"
PRESET_NAME="iOS"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

UPLOAD=false
DRY_RUN=false
BUILD_NUMBER=""
BUILD_NUMBER_ARG=""       # non-empty only when the caller passed --build-number

while [ $# -gt 0 ]; do
    case "$1" in
        --upload)       UPLOAD=true; shift ;;
        --dry-run)      DRY_RUN=true; shift ;;
        --build-number) BUILD_NUMBER="${2:-}"; BUILD_NUMBER_ARG=true; shift 2 ;;
        -h|--help)      sed -n '4,29p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1 ;;
    esac
done

run() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}  [dry-run] $*${NC}"
    else
        "$@"
    fi
}

echo -e "${BLUE}=================================================="
echo -e "  Spiritbound: iOS RELEASE build"
echo -e "==================================================${NC}"

# ---- Preflight ---------------------------------------------------------------
echo -e "\n${YELLOW}[1/6] Preflight${NC}"

[ -d "/Applications/Xcode.app/Contents/Developer" ] && export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

if ! command -v godot >/dev/null 2>&1; then
    echo -e "${RED}✗ godot is not on PATH.${NC}"; exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo -e "${RED}✗ xcodebuild is not available.${NC}"; exit 1
fi

GODOT_VERSION="$(godot --version 2>/dev/null | sed -n '1p')"
# `godot --version` prints e.g. "4.7.2.stable.official.ed1daf0bf" while the export-templates
# folder is named "4.7.2.stable" — the build hash and the "official" tag are not part of it, so
# stripping only the last dot-segment lands on a path that never exists.
TEMPLATE_VERSION="$(printf '%s' "$GODOT_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+\.(stable|beta|rc[0-9]*|dev[0-9]*)).*/\1/')"
TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates/$TEMPLATE_VERSION"

# Preflight failures stop a real release, but must not stop --dry-run: reviewing the whole flow
# before committing to it is the entire point of that flag, and it is most useful exactly when
# the machine is not yet set up for a release.
PREFLIGHT_FAILED=false
fail_preflight() { echo -e "${RED}✗ $1${NC}"; PREFLIGHT_FAILED=true; }

# A missing template is the single most common reason a release export fails, and the error
# Godot prints for it is easy to misread as a project problem. Check it here instead. The iOS
# template specifically: a templates folder can exist with only some platforms installed.
if [ ! -f "$TEMPLATE_DIR/ios.zip" ]; then
    fail_preflight "Godot iOS export templates for $TEMPLATE_VERSION are not installed.
  Godot → Editor → Manage Export Templates → Download and Install.
  (Looked for $TEMPLATE_DIR/ios.zip)"
else
    echo "  ✓ Godot $GODOT_VERSION, iOS templates present"
fi

# A release artifact must be reproducible from a commit. A dirty tree means the binary contains
# something that exists nowhere in git — which is exactly how "it worked on my machine" ships.
if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
    fail_preflight "The working tree has uncommitted changes.
  Commit or stash them first: an archive has to match a commit."
    git -C "$REPO_DIR" status --short | sed 's/^/    /'
else
    echo "  ✓ Clean tree at $(git -C "$REPO_DIR" rev-parse --short HEAD)"
fi
RELEASE_COMMIT="$(git -C "$REPO_DIR" rev-parse --short HEAD)"

# An App Store archive has to be signed with an Apple Distribution identity. Godot's iOS preset
# writes application/code_sign_identity_release="iPhone Developer" into the exported Xcode project,
# and the archive step below used to pass no identity of its own, so it inherited that and produced
# an Apple Development-signed archive -- while still printing "✓ Archived" and exiting 0. That
# archive is not submittable: App Store Connect rejects it at upload, minutes later, with an error
# that never mentions signing. Measured on this machine (2026-09-20): an archive of this exact
# project signed as "Apple Development: jiacongxu@gmail.com (QYQ7WU2QAL)" with the development
# profile "iOS Team Provisioning Profile: com.jiacong.spiritbound". Checking here turns a confusing
# rejection at the end of a long release into an immediate, actionable message.
#
# A preflight failure rather than a hard stop, for the same reason as the others: --dry-run exists
# to walk the whole flow on a machine that is not set up for a release yet. And it deliberately
# does not affect ./deploy_ios.sh, which installs a development build on a cabled phone and needs
# no distribution certificate at all.
DIST_IDENTITY_COUNT="$(security find-identity -v -p codesigning 2>/dev/null | grep -cE 'Apple Distribution|iPhone Distribution' || true)"
if [ "${DIST_IDENTITY_COUNT:-0}" -eq 0 ]; then
    fail_preflight "No 'Apple Distribution' identity in the login keychain.
  With only 'Apple Development' present, the archive below signs a development build, reports
  success, and is then rejected by App Store Connect at upload time.
  Fix: Xcode → Settings → Accounts → select the team → Manage Certificates → + →
  Apple Distribution (requires a paid Apple Developer Program membership; the free Personal
  Team cannot issue one).
  Verify with: security find-identity -v -p codesigning | grep Distribution"
else
    echo "  ✓ Apple Distribution identity present ($DIST_IDENTITY_COUNT)"
fi

if [ "$PREFLIGHT_FAILED" = true ] && [ "$DRY_RUN" = false ]; then
    echo -e "\n${RED}Preflight failed — nothing was built.${NC}"
    exit 1
elif [ "$PREFLIGHT_FAILED" = true ]; then
    echo -e "\n${YELLOW}(dry run: continuing past the problems above to show the full flow)${NC}"
fi

# Tests are not optional before an artifact that goes to reviewers — AGENTS.md rule 1.
echo -e "\n${YELLOW}[2/6] Test suite (./run_tests.sh — required before a release)${NC}"
run "$REPO_DIR/run_tests.sh"

# ---- Export ------------------------------------------------------------------
echo -e "\n${YELLOW}[3/6] Godot release export (not --export-debug)${NC}"
# Wipe the previous export first. Godot's "all_resources" export filter scans the project tree,
# so an existing export inside the project (Godot/build/ios is under PROJECT_DIR) gets scanned
# and packed into the new .pck: 18 stale 0-byte Images.xcassets entries plus a second copy of
# every generated app icon, and "Can't open file from path 'res://build/...'" errors during
# export. Only visible on the second and later releases, because the first has no stale dir.
# Safe to delete -- build/ is gitignored and fully regenerated by this step.
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}  [dry-run] rm -rf $BUILD_DIR (stale export would otherwise be packed into the .pck)${NC}"
else
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
run godot --headless --path "$PROJECT_DIR" --export-release "$PRESET_NAME" "$BUILD_DIR/Spiritbound.ipa"

# Patch dummy.cpp with weak-symbol stubs that libgodot.a(metal_cpp.ios.template_release.arm64.o)
# references but that the iPhoneOS 18.5 SDK does not export as linkable symbols. The same patch
# lives in deploy_ios.sh for debug builds; both use the same Godot-generated dummy.cpp file.
# Without this the linker fails: "Undefined symbols: _CADynamicRangeAutomatic, _MTLTensorDomain".
DUMMY_CPP="$BUILD_DIR/Spiritbound/dummy.cpp"
if [ "$DRY_RUN" = false ] && [ -f "$DUMMY_CPP" ]; then
    if ! grep -q "CADynamicRangeAutomatic" "$DUMMY_CPP"; then
        cat << 'EOF' >> "$DUMMY_CPP"

extern "C" {
    __attribute__((visibility("default"))) void* CADynamicRangeAutomatic = nullptr;
    __attribute__((visibility("default"))) void* CADynamicRangeConstrainedHigh = nullptr;
    __attribute__((visibility("default"))) void* CADynamicRangeHigh = nullptr;
    __attribute__((visibility("default"))) void* CADynamicRangeStandard = nullptr;
    __attribute__((visibility("default"))) void* MTLTensorDomain = nullptr;
    int SDL_IsAppleTV(void) { return 0; }
    int SDL_IsIPad(void) { return 0; }
}
EOF
        echo "   ✓ Patched dummy.cpp with Metal/QuartzCore/SDL compatibility symbols"
    elif ! grep -q "SDL_IsAppleTV" "$DUMMY_CPP"; then
        cat << 'EOF' >> "$DUMMY_CPP"

extern "C" {
    int SDL_IsAppleTV(void) { return 0; }
    int SDL_IsIPad(void) { return 0; }
}
EOF
        echo "   ✓ Patched dummy.cpp with SDL compatibility symbols"
    else
        echo "   ✓ dummy.cpp already has compatibility symbols — no patch needed"
    fi
fi

# Godot regenerates the Xcode project and its Info.plist on every export, so anything that must
# be true of the shipped plist is asserted here, after the export, rather than edited into a
# generated file. ITSAppUsesNonExemptEncryption in particular is what stops App Store Connect
# asking the export-compliance question on every single upload.
PLIST="$BUILD_DIR/Spiritbound/Spiritbound-Info.plist"
if [ "$DRY_RUN" = false ] && [ -f "$PLIST" ]; then
    if plutil -extract ITSAppUsesNonExemptEncryption raw "$PLIST" >/dev/null 2>&1; then
        echo "  ✓ Info.plist declares ITSAppUsesNonExemptEncryption"
    else
        echo -e "${YELLOW}  ⚠ Info.plist has no ITSAppUsesNonExemptEncryption key — App Store Connect"
        echo -e "    will ask the export-compliance question on upload. The Godot 4.7.2 template"
        echo -e "    normally sets it to false (no non-exempt encryption is used); if a template"
        echo -e "    bump dropped it, add it back before uploading.${NC}"
    fi
fi

# The version that reached the *exported project*, recorded next to the archive. This is what you
# paste into TestFlight's "What to Test" so a tester report can be traced to a build.
#
# Read it from the exported pbxproj, not from export_presets.cfg: Godot only copies the preset
# into the Xcode project at export time, so the two can disagree (a stale or hand-archived
# Godot/build/ios/ keeps the number it was last written with). Reading the artifact and warning
# on a mismatch is the difference between reporting the shipped version and reporting the
# intended one. See Docs/STORE_SUBMISSION.md section 2.2.
# The preset is the source of truth for BOTH numbers, and both are handed to xcodebuild as build
# setting overrides at the archive step. That is what makes --build-number real: before this fix
# BUILD_NUMBER only ever reached an echo statement, so the script would print "uploading build 21"
# and upload build 20 — the exact number App Store Connect dedupes on (ITMS-4238).
#
# The exported project is still read, but now only to *warn* about staleness, never to decide the
# number. Deciding from it let a stale Godot/build/ios/ choose what the release claimed to be:
# measured 2026-09-20, --dry-run printed "build 1" (a two-day-old pbxproj) while the preset said 20.
PRESET_VERSION="$(grep -m1 'application/short_version' "$PROJECT_DIR/export_presets.cfg" | cut -d'"' -f2)"
PRESET_BUILD="$(grep -m1 'application/version' "$PROJECT_DIR/export_presets.cfg" | cut -d'"' -f2)"
SHORT_VERSION="$PRESET_VERSION"
[ -n "$BUILD_NUMBER" ] || BUILD_NUMBER="$PRESET_BUILD"

# A blank or non-numeric override is worse than no override: `CURRENT_PROJECT_VERSION=` would hand
# xcodebuild an empty build number to substitute into CFBundleVersion. Fail here instead, naming
# the file to fix, rather than deep inside the build or — worse — inside the uploaded plist.
if [ -z "$SHORT_VERSION" ]; then
    echo -e "${RED}✗ application/short_version is empty in export_presets.cfg — nothing to ship.${NC}"
    exit 1
fi
if [ -n "$BUILD_NUMBER_ARG" ] && [ -z "$BUILD_NUMBER" ]; then
    echo -e "${RED}✗ --build-number was given no value.${NC}"
    echo -e "${RED}  Pass an integer (e.g. --build-number 21), or drop the flag entirely to use"
    echo -e "${RED}  application/version from export_presets.cfg.${NC}"
    exit 1
fi
if [ -z "$BUILD_NUMBER" ] || ! printf '%s' "$BUILD_NUMBER" | grep -qE '^[0-9]+$'; then
    echo -e "${RED}✗ Build number is '${BUILD_NUMBER}' — it must be a positive integer.${NC}"
    echo -e "${RED}  Set application/version in export_presets.cfg, or pass --build-number <n>.${NC}"
    exit 1
fi

PBXPROJ="$BUILD_DIR/Spiritbound.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
    EXPORTED_VERSION="$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed 's/.*= *//; s/;//' | tr -d ' ')"
    EXPORTED_BUILD="$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed 's/.*= *//; s/;//' | tr -d ' ')"
    if [ -n "$EXPORTED_VERSION" ] && [ "$EXPORTED_VERSION" != "$PRESET_VERSION" ]; then
        echo -e "${YELLOW}  ⚠ Exported project says version $EXPORTED_VERSION but export_presets.cfg"
        echo -e "    says $PRESET_VERSION — the Xcode project was not regenerated from the preset."
        echo -e "    Delete $BUILD_DIR and re-export before archiving.${NC}"
    fi
    # The build-number half of that staleness check was missing, which is why the stale export got
    # to rename the release in silence. Warning (not adopting) still surfaces it, and the override
    # below guarantees the artifact carries the number we just logged.
    if [ -z "$BUILD_NUMBER_ARG" ] && [ -n "$EXPORTED_BUILD" ] && [ "$EXPORTED_BUILD" != "$PRESET_BUILD" ]; then
        echo -e "${YELLOW}  ⚠ Exported project says build $EXPORTED_BUILD but export_presets.cfg says"
        echo -e "    $PRESET_BUILD — archiving as $PRESET_BUILD anyway; the override below wins.${NC}"
    fi
fi
echo "  Marketing version $SHORT_VERSION, build $BUILD_NUMBER, commit $RELEASE_COMMIT"
if [ -z "$BUILD_NUMBER_ARG" ] && [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}  ⚠ Reusing build number $BUILD_NUMBER from export_presets.cfg. This script cannot"
    echo -e "    see what you have already uploaded — if a build with that number exists for"
    echo -e "    $SHORT_VERSION, App Store Connect will reject the upload. Pass --build-number <n+1>"
    echo -e "    to be safe.${NC}"
fi

# ---- Archive -----------------------------------------------------------------
echo -e "\n${YELLOW}[4/6] xcodebuild archive (development-signed; [5/6] re-signs for the store)${NC}"
mkdir -p "$ARCHIVE_DIR"
# With CODE_SIGN_STYLE=Automatic and -allowProvisioningUpdates, Xcode automatically selects
# the Apple Distribution identity for `archive` actions (and Apple Development for `build`).
# Do NOT also pass CODE_SIGN_IDENTITY="Apple Distribution" — that overrides automatic signing
# for a specific identity while the project is set to Automatic, which Xcode rejects as a
# conflict ("automatically signed for development, but a conflicting code signing identity
# Apple Distribution has been manually specified").
#
# MARKETING_VERSION and CURRENT_PROJECT_VERSION are build-setting overrides: xcodebuild applies
# them on top of the generated project for this invocation. They are what actually set the shipped
# numbers, because Godot's Info.plist template resolves CFBundleVersion to
# $(CURRENT_PROJECT_VERSION) and CFBundleShortVersionString to $(MARKETING_VERSION) — verified by
# dumping godot_apple_embedded-Info.plist out of the 4.7.2 ios.zip template; both are variables,
# not literals, so there is nothing else to edit and no reason to hand-patch generated files.
# This pair of arguments is the ONLY route by which --build-number reaches the artifact.
run xcodebuild -project "$BUILD_DIR/Spiritbound.xcodeproj" \
    -scheme Spiritbound \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    MARKETING_VERSION="$SHORT_VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    archive

# The archive is checked for the two facts that must hold wherever the signing happens: that it
# carries a signature at all, and that it carries the version numbers this run asked for.
#
# Its *identity* is deliberately not required to be a distribution one. Godot's preset pins
# "iPhone Developer" and the archive action honours it; pinning a distribution identity in there
# instead makes Xcode refuse to archive at all ("automatically signed for development, but a
# conflicting code signing identity Apple Distribution has been manually specified" — measured on
# this project, 2026-09-21). Distribution signing happens one step later, in [5/6], which is also
# how Xcode's Organizer splits the two.
if [ "$DRY_RUN" = false ]; then
    EMBEDDED_PROFILE="$ARCHIVE_PATH/Products/Applications/Spiritbound.app/embedded.mobileprovision"
    if [ ! -f "$EMBEDDED_PROFILE" ]; then
        echo -e "${RED}✗ The archive has no embedded.mobileprovision — there is nothing to re-sign.${NC}"
        exit 1
    fi
    PROFILE_PLIST="$(mktemp)"
    security cms -D -i "$EMBEDDED_PROFILE" > "$PROFILE_PLIST" 2>/dev/null
    PROFILE_NAME="$(plutil -extract Name raw "$PROFILE_PLIST" 2>/dev/null || echo '(unreadable)')"
    if plutil -extract ProvisionedDevices raw "$PROFILE_PLIST" >/dev/null 2>&1; then
        echo "  • Archive signed for development ($PROFILE_NAME)"
        echo "    Expected here: [5/6] re-signs it with the Apple Distribution identity for the store."
    else
        echo "  ✓ Archive already distribution-signed: $PROFILE_NAME"
    fi
    rm -f "$PROFILE_PLIST"

    # Same rule as the signing check above, applied to the version numbers: read the archive's own
    # Info.plist instead of trusting that the build-setting override took effect. An override that
    # silently does not apply yields an archive with the wrong CFBundleVersion, and the only
    # feedback is App Store Connect rejecting the upload minutes later as ITMS-4238 "Redundant
    # Binary Upload" — an error that never once mentions version overrides. This check is also the
    # empirical proof that --build-number reaches the artifact at all, which is precisely what the
    # script previously assumed while it only ever echoed the number.
    ARCHIVED_PLIST="$ARCHIVE_PATH/Products/Applications/Spiritbound.app/Info.plist"
    if [ ! -f "$ARCHIVED_PLIST" ]; then
        echo -e "${RED}✗ The archive has no Info.plist — cannot verify the shipped version.${NC}"
        exit 1
    fi
    ARCHIVED_SHORT="$(plutil -extract CFBundleShortVersionString raw "$ARCHIVED_PLIST" 2>/dev/null || echo '')"
    ARCHIVED_BUILD="$(plutil -extract CFBundleVersion raw "$ARCHIVED_PLIST" 2>/dev/null || echo '')"
    if [ "$ARCHIVED_SHORT" != "$SHORT_VERSION" ] || [ "$ARCHIVED_BUILD" != "$BUILD_NUMBER" ]; then
        echo -e "${RED}✗ The archive carries $ARCHIVED_SHORT ($ARCHIVED_BUILD), but this run asked for"
        echo -e "${RED}  $SHORT_VERSION ($BUILD_NUMBER). The build-setting override did not reach the"
        echo -e "${RED}  artifact — do not upload this.${NC}"
        exit 1
    fi
    echo "  ✓ Archive carries version $ARCHIVED_SHORT, build $ARCHIVED_BUILD (override applied)"
fi

# ---- Export for App Store Connect -------------------------------------------
# This is where the artifact becomes distributable, and the only place distribution signing
# happens. -exportArchive re-signs the archived .app with an Apple Distribution identity and a
# Store provisioning profile, then packages the .ipa; -allowProvisioningUpdates lets Xcode fetch or
# create that profile from the account signed into Xcode.
#
# method=app-store-connect is the current spelling of what older Xcode called "app-store" (Xcode 15
# removed the old value and errors on it). destination=upload is deliberately absent: this step
# only produces the .ipa, so every check below runs before anything is sent to Apple.
#
# The checks read the .ipa, not the archive, because the .ipa is what gets uploaded. Three signals
# decide whether it is submittable:
#   1. the signing certificate's Authority is an Apple Distribution one,
#   2. the embedded profile has no ProvisionedDevices list (App Store profiles never do),
#   3. get-task-allow is not true (an App Store build cannot be debugged).
# A development-signed .ipa fails all three and nothing in xcodebuild's output says so: App Store
# Connect's rejection arrives minutes later and never mentions signing. Checking here costs seconds
# and catches it on the file that would otherwise have been uploaded.
echo -e "\n${YELLOW}[5/6] Export for App Store Connect (re-signs for distribution)${NC}"
TEAM_ID="$(grep -m1 'application/app_store_team_id' "$PROJECT_DIR/export_presets.cfg" | cut -d'"' -f2)"
if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}✗ application/app_store_team_id is empty in export_presets.cfg.${NC}"; exit 1
fi

# $2 = destination: "" exports only, "upload" exports and sends the result to Apple.
write_export_options() {
    local path="$1" destination="$2"
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
        echo '<plist version="1.0"><dict>'
        echo '    <key>method</key><string>app-store-connect</string>'
        if [ -n "$destination" ]; then
            echo "    <key>destination</key><string>${destination}</string>"
        fi
        echo "    <key>teamID</key><string>${TEAM_ID}</string>"
        echo '    <key>uploadSymbols</key><true/>'
        echo '    <key>manageAppVersionAndBuildNumber</key><false/>'
        echo '</dict></plist>'
    } > "$path"
}

# A .ipa left over from an earlier run would be the one verified, and would pass every check
# below. build/ is gitignored and regenerated by this script, so removing it is safe.
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}  [dry-run] write $EXPORT_OPTIONS (method=app-store-connect, destination=not set)${NC}"
    echo -e "${YELLOW}  [dry-run] rm -rf $EXPORT_DIR (a stale .ipa would otherwise be the one verified)${NC}"
else
    write_export_options "$EXPORT_OPTIONS" ""
    rm -rf "$EXPORT_DIR"
fi
mkdir -p "$EXPORT_DIR"
echo "  Wrote $EXPORT_OPTIONS"

run xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates

if [ "$DRY_RUN" = false ]; then
    IPA="$EXPORT_DIR/Spiritbound.ipa"
    if [ ! -f "$IPA" ]; then
        echo -e "${RED}✗ -exportArchive produced no .ipa at $IPA${NC}"
        exit 1
    fi

    # Unpack just far enough to read the signed bundle: a .ipa is a zip whose Payload holds the
    # .app, and the signature, the profile and the shipped Info.plist all live inside it.
    VERIFY_DIR="$(mktemp -d)"
    unzip -q "$IPA" -d "$VERIFY_DIR"
    APP_BUNDLE="$(find "$VERIFY_DIR/Payload" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)"
    if [ -z "$APP_BUNDLE" ]; then
        echo -e "${RED}✗ The .ipa has no Payload/*.app — nothing to verify signing against.${NC}"
        rm -rf "$VERIFY_DIR"; exit 1
    fi

    # 1. The leaf Authority is the certificate that actually signed the app.
    SIGN_AUTHORITY="$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 | sed -n 's/^Authority=//p' | head -1 || true)"
    case "$SIGN_AUTHORITY" in
        *Distribution*) ;;
        *)
            echo -e "${RED}✗ The .ipa is not distribution-signed.${NC}"
            echo -e "${RED}    Authority: ${SIGN_AUTHORITY:-(no signature found)}${NC}"
            echo -e "${RED}  Expected an Apple Distribution certificate. App Store Connect rejects uploads${NC}"
            echo -e "${RED}  signed with Apple Development, minutes later, without mentioning signing.${NC}"
            rm -rf "$VERIFY_DIR"; exit 1 ;;
    esac

    # 2. An App Store profile carries no device list; a development one always does. This is the
    #    difference the earlier version of this script got wrong while printing "✓ Archived".
    IPA_PROFILE="$APP_BUNDLE/embedded.mobileprovision"
    IPA_PROFILE_PLIST="$(mktemp)"
    if ! security cms -D -i "$IPA_PROFILE" > "$IPA_PROFILE_PLIST" 2>/dev/null \
            || [ ! -s "$IPA_PROFILE_PLIST" ]; then
        echo -e "${RED}✗ The .ipa has no readable embedded.mobileprovision — signing cannot be trusted.${NC}"
        rm -f "$IPA_PROFILE_PLIST"; rm -rf "$VERIFY_DIR"; exit 1
    fi
    IPA_PROFILE_NAME="$(plutil -extract Name raw "$IPA_PROFILE_PLIST" 2>/dev/null || echo '(unreadable)')"
    if plutil -extract ProvisionedDevices raw "$IPA_PROFILE_PLIST" >/dev/null 2>&1; then
        echo -e "${RED}✗ The .ipa is signed with a DEVELOPMENT profile:${NC}"
        echo -e "${RED}    $IPA_PROFILE_NAME${NC}"
        echo -e "${RED}  It lists devices, which an App Store profile never does. Do not upload this.${NC}"
        rm -f "$IPA_PROFILE_PLIST"; rm -rf "$VERIFY_DIR"; exit 1
    fi
    rm -f "$IPA_PROFILE_PLIST"

    # 3. get-task-allow lets a debugger attach. A Store build must not have it set; normally it is
    #    present and false, but absent is equally fine.
    IPA_ENTITLEMENTS="$(mktemp)"
    codesign -d --entitlements :- "$APP_BUNDLE" > "$IPA_ENTITLEMENTS" 2>/dev/null || true
    IPA_GTA="$(plutil -extract get-task-allow raw "$IPA_ENTITLEMENTS" 2>/dev/null || echo '')"
    if [ "$IPA_GTA" = "true" ]; then
        echo -e "${RED}✗ The .ipa has get-task-allow=true — it is a debuggable build. Do not upload it.${NC}"
        rm -f "$IPA_ENTITLEMENTS"; rm -rf "$VERIFY_DIR"; exit 1
    fi

    echo "  ✓ Distribution-signed: $IPA_PROFILE_NAME"
    echo "      Authority: $SIGN_AUTHORITY"
    echo "      No ProvisionedDevices; get-task-allow ${IPA_GTA:-absent}"
    if plutil -extract beta-reports-active raw "$IPA_ENTITLEMENTS" >/dev/null 2>&1; then
        echo "  ✓ TestFlight entitlement present (beta-reports-active)"
    else
        echo -e "${YELLOW}  ⚠ No beta-reports-active entitlement — TestFlight may refuse this build.${NC}"
    fi
    rm -f "$IPA_ENTITLEMENTS"

    # The numbers are re-read from the .ipa rather than assumed from the archive: this is the file
    # App Store Connect dedupes on, and a wrong CFBundleVersion comes back as ITMS-4238 "Redundant
    # Binary Upload", an error that never mentions version overrides.
    IPA_PLIST="$APP_BUNDLE/Info.plist"
    IPA_SHORT="$(plutil -extract CFBundleShortVersionString raw "$IPA_PLIST" 2>/dev/null || echo '')"
    IPA_BUILD="$(plutil -extract CFBundleVersion raw "$IPA_PLIST" 2>/dev/null || echo '')"
    if [ "$IPA_SHORT" != "$SHORT_VERSION" ] || [ "$IPA_BUILD" != "$BUILD_NUMBER" ]; then
        echo -e "${RED}✗ The .ipa carries $IPA_SHORT ($IPA_BUILD), but this run asked for"
        echo -e "${RED}  $SHORT_VERSION ($BUILD_NUMBER). Do not upload this.${NC}"
        rm -rf "$VERIFY_DIR"; exit 1
    fi
    echo "  ✓ .ipa carries version $IPA_SHORT, build $IPA_BUILD"
    rm -rf "$VERIFY_DIR"
fi

if [ "$UPLOAD" = false ]; then
    echo -e "\n${GREEN}✓ Store-signed .ipa ready: $EXPORT_DIR/Spiritbound.ipa${NC}"
    echo "  Nothing has been uploaded. Next, either:"
    echo "    ./release_ios.sh --upload            # export again, then upload to App Store Connect"
    echo "    open \"$ARCHIVE_PATH\"                # or use Xcode Organizer's Distribute button"
    echo "  Then add the build to a TestFlight group and walk Docs/STORE_SUBMISSION.md."
    exit 0
fi

# ---- Upload ------------------------------------------------------------------
# destination=upload makes -exportArchive perform the App Store Connect upload itself, which is
# the current supported path (xcrun altool is deprecated). It re-runs the export above on purpose:
# xcodebuild treats export-and-upload as a single action, so there is no supported way to hand it
# the .ipa that was verified. The archive and the options are otherwise identical, so what it
# uploads is the same configuration that passed the checks. It uses the Apple ID already signed
# into Xcode; pass -authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID instead
# if this machine is not signed in (Xcode → Settings → Accounts → App Store Connect API key).
echo -e "\n${YELLOW}[6/6] Upload to App Store Connect${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}  [dry-run] rewrite $EXPORT_OPTIONS with destination=upload${NC}"
else
    write_export_options "$EXPORT_OPTIONS" "upload"
fi
echo -e "${YELLOW}  This is the point of no return: the next command uploads build $BUILD_NUMBER to Apple.${NC}"

run xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates

echo -e "\n${GREEN}✓ Uploaded $SHORT_VERSION ($BUILD_NUMBER) from commit $RELEASE_COMMIT${NC}"
echo "  Processing takes a few minutes; then in App Store Connect:"
echo "    - add the build to a TestFlight group (or submit for review)"
echo "    - complete the export-compliance question if it appears"
echo "    - confirm the App Privacy answers and the account-deletion capability"
echo "  Docs/STORE_SUBMISSION.md is the checklist for the rest."
