#!/bin/bash
set -e

# Spiritbound iOS One-Click Export & Wireless Deploy Script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/Godot"
BUILD_DIR="$PROJECT_DIR/build/ios"
PBXPROJ="$BUILD_DIR/Spiritbound.xcodeproj/project.pbxproj"
TEAM_ID="N5Q948HNBR"
BUNDLE_ID="com.jiacong.spiritbound"

echo "=================================================="
echo "  Spiritbound iOS Deploy: Team $TEAM_ID"
echo "=================================================="

MODE="all"
if [ "$1" == "--pck-only" ]; then
    MODE="pck"
elif [ "$1" == "--full-export" ]; then
    MODE="full"
elif [ "$1" == "--build-only" ]; then
    MODE="build"
fi

# Step 1: Export from Godot
if [ "$MODE" == "full" ]; then
    echo "📦 [1/4] Performing full Godot iOS export..."
    mkdir -p "$BUILD_DIR"
    godot --headless --path "$PROJECT_DIR" --export-debug "iOS" "$BUILD_DIR/Spiritbound.ipa"
elif [ "$MODE" != "build" ]; then
    echo "📦 [1/4] Fast-exporting Spiritbound.pck (game scripts & assets)..."
    mkdir -p "$BUILD_DIR"
    godot --headless --path "$PROJECT_DIR" --export-pack "iOS" "$BUILD_DIR/Spiritbound.pck"
fi

# Step 2: Ensure Xcode project signing is permanently configured
if [ -f "$PBXPROJ" ]; then
    echo "🔒 [2/4] Verifying Xcode Automatic Signing & Team ID..."
    python3 - <<PYEOF
import re

path = "$PBXPROJ"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Ensure DEVELOPMENT_TEAM is user team N5Q948HNBR
content = re.sub(r'DEVELOPMENT_TEAM\s*=\s*[^;]+;', 'DEVELOPMENT_TEAM = $TEAM_ID;', content)

# 2. Ensure CODE_SIGN_STYLE is Automatic
content = re.sub(r'CODE_SIGN_STYLE\s*=\s*[^;]+;', 'CODE_SIGN_STYLE = Automatic;', content)

# 3. Ensure ProvisioningStyle = Automatic in TargetAttributes
if 'ProvisioningStyle = Automatic;' not in content:
    content = content.replace('TargetAttributes = {', 'TargetAttributes = {\n\t\t\t\t\tD0BCFE3318AEBDA2004A7AAE = {\n\t\t\t\t\t\tLastSwiftMigration = 1250;\n\t\t\t\t\t\tProvisioningStyle = Automatic;\n\t\t\t\t\t};\n')

# 4. Architecture configuration for device and simulator
if '"ARCHS[sdk=iphoneos*]"' not in content:
    content = content.replace('buildSettings = {\n\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;', 'buildSettings = {\n\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n\t\t\t\t"ARCHS[sdk=iphoneos*]" = arm64;\n\t\t\t\t"ARCHS[sdk=iphonesimulator*]" = x86_64;')

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("   ✓ Xcode project signing locked to Team $TEAM_ID (Automatic)")
PYEOF
fi

if [ "$MODE" == "pck" ]; then
    echo "✅ PCK export complete! You can now press Cmd + R in Xcode to run."
    exit 0
fi

# Step 3: Find connected iOS device
echo "📱 [3/4] Locating connected iOS device..."
# Match the state column as a whole word: "unavailable" also contains "available".
DEVICE_LINE=$(xcrun devicectl list devices 2>/dev/null | grep -E "[[:space:]]connected[[:space:]]" | head -n 1)
DEVICE_ID=$(echo "$DEVICE_LINE" | grep -o -E "[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}" | head -n 1)
DEVICE_NAME=$(echo "$DEVICE_LINE" | awk '{print $1" "$2}')

if [ -z "$DEVICE_ID" ]; then
    echo "⚠️  No physical device connected via devicectl. Building for generic iOS..."
    DESTINATION="generic/platform=iOS"
else
    echo "   Found device: $DEVICE_NAME ($DEVICE_ID)"
    DESTINATION="id=$DEVICE_ID"
fi

# Step 4: Build Xcode project
echo "🔨 [4/4] Building with Xcode (Automatic Signing)..."
xcodebuild -project "$BUILD_DIR/Spiritbound.xcodeproj" \
    -scheme Spiritbound \
    -destination "$DESTINATION" \
    -allowProvisioningUpdates \
    build | tail -n 10

if [ -n "$DEVICE_ID" ]; then
    DERIVED_APP=$(find ~/Library/Developer/Xcode/DerivedData/Spiritbound-*/Build/Products/Debug-iphoneos -name "Spiritbound.app" -type d 2>/dev/null | head -n 1)
    if [ -n "$DERIVED_APP" ]; then
        echo "🚀 Wirelessly installing to $DEVICE_NAME..."
        xcrun devicectl device install app --device "$DEVICE_ID" "$DERIVED_APP"
        echo "✨ Launching Spiritbound on $DEVICE_NAME..."
        xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"
        echo "🎉 Game successfully launched on your iPhone!"
    fi
fi
