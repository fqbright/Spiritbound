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
#   ./release_ios.sh                           # export-release + archive; leaves the .xcarchive
#   ./release_ios.sh --build-number 7          # override the build number for this archive
#   ./release_ios.sh --upload                  # archive, then export + upload to App Store Connect
#
# What it deliberately does NOT do: bump the marketing version (application/short_version in
# Godot/export_presets.cfg). That is a release decision, not a build detail — set it yourself
# and commit it, so the version in the binary always matches a commit.
#
# Signing: an archive needs a *distribution* identity and profile, not the "iPhone Developer"
# debug ones in the preset. --allowProvisioningUpdates lets Xcode create/fetch them from the
# Apple account already signed into Xcode, which is why there is no password anywhere here.
# If your account has no distribution certificate yet, open Xcode → Settings → Accounts and
# let it make one, or the archive step fails with a clear "no signing certificate" error.
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
PRESET_VERSION="$(grep -m1 'application/short_version' "$PROJECT_DIR/export_presets.cfg" | cut -d'"' -f2)"
PRESET_BUILD="$(grep -m1 'application/version' "$PROJECT_DIR/export_presets.cfg" | cut -d'"' -f2)"
SHORT_VERSION="$PRESET_VERSION"
[ -n "$BUILD_NUMBER" ] || BUILD_NUMBER="$PRESET_BUILD"
PBXPROJ="$BUILD_DIR/Spiritbound.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
    EXPORTED_VERSION="$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed 's/.*= *//; s/;//' | tr -d ' ')"
    EXPORTED_BUILD="$(grep -m1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed 's/.*= *//; s/;//' | tr -d ' ')"
    [ -n "$EXPORTED_VERSION" ] && SHORT_VERSION="$EXPORTED_VERSION"
    [ -z "$BUILD_NUMBER_ARG" ] && [ -n "$EXPORTED_BUILD" ] && BUILD_NUMBER="$EXPORTED_BUILD"
    if [ -n "$EXPORTED_VERSION" ] && [ "$EXPORTED_VERSION" != "$PRESET_VERSION" ]; then
        echo -e "${YELLOW}  ⚠ Exported project says version $EXPORTED_VERSION but export_presets.cfg"
        echo -e "    says $PRESET_VERSION — the Xcode project was not regenerated from the preset."
        echo -e "    Delete $BUILD_DIR and re-export before archiving.${NC}"
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
echo -e "\n${YELLOW}[4/6] xcodebuild archive (distribution signing)${NC}"
mkdir -p "$ARCHIVE_DIR"
# With CODE_SIGN_STYLE=Automatic and -allowProvisioningUpdates, Xcode automatically selects
# the Apple Distribution identity for `archive` actions (and Apple Development for `build`).
# Do NOT also pass CODE_SIGN_IDENTITY="Apple Distribution" — that overrides automatic signing
# for a specific identity while the project is set to Automatic, which Xcode rejects as a
# conflict ("automatically signed for development, but a conflicting code signing identity
# Apple Distribution has been manually specified").
run xcodebuild -project "$BUILD_DIR/Spiritbound.xcodeproj" \
    -scheme Spiritbound \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    archive

# Check the artifact, not the exit status. `xcodebuild archive` succeeds just as happily for a
# development-signed build as for a distribution-signed one, and nothing in its output says which
# you got, so the only trustworthy answer is the provisioning profile embedded in the .app. An
# App Store distribution profile carries no ProvisionedDevices list and disallows debugging; a
# development profile has both. This is the difference that decides whether the upload works.
if [ "$DRY_RUN" = false ]; then
    EMBEDDED_PROFILE="$ARCHIVE_PATH/Products/Applications/Spiritbound.app/embedded.mobileprovision"
    if [ ! -f "$EMBEDDED_PROFILE" ]; then
        echo -e "${RED}✗ The archive has no embedded.mobileprovision — nothing to verify signing against.${NC}"
        exit 1
    fi
    PROFILE_PLIST="$(mktemp)"
    security cms -D -i "$EMBEDDED_PROFILE" > "$PROFILE_PLIST" 2>/dev/null
    PROFILE_NAME="$(plutil -extract Name raw "$PROFILE_PLIST" 2>/dev/null || echo '(unreadable)')"
    if plutil -extract ProvisionedDevices raw "$PROFILE_PLIST" >/dev/null 2>&1; then
        echo -e "${RED}✗ The archive is signed with a DEVELOPMENT profile:" 
        echo -e "${RED}    $PROFILE_NAME${NC}"
        echo -e "${RED}  It contains a ProvisionedDevices list, which an App Store profile never does.${NC}"
        echo -e "${RED}  This archive cannot be submitted; App Store Connect would reject it at upload with${NC}"
        echo -e "${RED}  an error that does not mention signing. Create an Apple Distribution certificate${NC}"
        echo -e "${RED}  (Xcode → Settings → Accounts → Manage Certificates → +) and re-run.${NC}"
        rm -f "$PROFILE_PLIST"
        exit 1
    fi
    echo "  ✓ Distribution-signed: $PROFILE_NAME (no device list, debugging disallowed)"
    rm -f "$PROFILE_PLIST"
fi

if [ "$UPLOAD" = false ]; then
    echo -e "\n${GREEN}✓ Archived to $ARCHIVE_PATH${NC}"
    echo "  Next, either:"
    echo "    ./release_ios.sh --upload            # export + upload to App Store Connect"
    echo "    open \"$ARCHIVE_PATH\"                # or use Xcode Organizer's Distribute button"
    echo "  Then add the build to a TestFlight group and walk Docs/STORE_SUBMISSION.md."
    exit 0
fi

# ---- Export for App Store Connect -------------------------------------------
# destination=upload makes -exportArchive do the App Store Connect upload itself, which is the
# current supported path (xcrun altool is deprecated). It uses the Apple ID already signed into
# Xcode; pass -authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID instead if
# this machine is not signed in (see Xcode → Settings → Accounts → App Store Connect API key).
echo -e "\n${YELLOW}[5/6] Export + upload to App Store Connect${NC}"
TEAM_ID="$(grep -m1 'application/app_store_team_id' "$PROJECT_DIR/export_presets.cfg" | cut -d'"' -f2)"
if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}✗ application/app_store_team_id is empty in export_presets.cfg.${NC}"; exit 1
fi

mkdir -p "$EXPORT_DIR"
cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>${TEAM_ID}</string>
    <key>uploadSymbols</key><true/>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
EOF
echo "  Wrote $EXPORT_OPTIONS"
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
