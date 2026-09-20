#!/bin/bash
set -e

# Spiritbound iOS One-Click Export & Wireless Deploy Script
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi
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

if [ ! -d "$BUILD_DIR/Spiritbound.xcodeproj" ] && [ "$MODE" != "build" ]; then
    echo "⚠️  Xcode project not found at $BUILD_DIR/Spiritbound.xcodeproj, switching to full export..."
    MODE="full"
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
DETECTED_TEAM=$(security find-identity -v -p codesigning 2>/dev/null | grep -o -E "\([A-Z0-9]{10}\)" | tr -d '()' | head -n 1)
if [ -n "$DETECTED_TEAM" ]; then
    TEAM_ID="$DETECTED_TEAM"
fi

# Step 2.1: Patch dummy.cpp with missing weak symbols for iOS 18.5 SDK
DUMMY_CPP="$BUILD_DIR/Spiritbound/dummy.cpp"
if [ -f "$DUMMY_CPP" ]; then
    if ! grep -q "CADynamicRangeAutomatic" "$DUMMY_CPP"; then
        cat << 'EOF' >> "$DUMMY_CPP"

extern "C" {
    __attribute__((visibility("default"))) void* CADynamicRangeAutomatic = nullptr;
    __attribute__((visibility("default"))) void* CADynamicRangeConstrainedHigh = nullptr;
    __attribute__((visibility("default"))) void* CADynamicRangeHigh = nullptr;
    __attribute__((visibility("default"))) void* CADynamicRangeStandard = nullptr;
    __attribute__((visibility("default"))) void* MTLTensorDomain = nullptr;
}
EOF
        echo "   ✓ Patched dummy.cpp with Metal/QuartzCore compatibility symbols"
    fi
fi

if [ -f "$PBXPROJ" ]; then
    echo "🔒 [2/4] Verifying Xcode Automatic Signing & Team ID..."
    python3 - <<PYEOF
import re

path = "$PBXPROJ"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Ensure DEVELOPMENT_TEAM is user team
content = re.sub(r'DEVELOPMENT_TEAM\s*=\s*[^;]+;', 'DEVELOPMENT_TEAM = $TEAM_ID;', content)
content = re.sub(r'DevelopmentTeam\s*=\s*[^;]+;', 'DevelopmentTeam = $TEAM_ID;', content)

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

# Step 3: Build Xcode project (always generic/platform=iOS so device lock doesn't block compile)
echo "🔨 [3/4] Building with Xcode (Automatic Signing)..."
xcodebuild -project "$BUILD_DIR/Spiritbound.xcodeproj" \
    -scheme Spiritbound \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    build | tail -n 10

# Step 4: Install and launch on device
echo "📱 [4/4] Locating connected iOS device for install..."
DERIVED_APP=$(find ~/Library/Developer/Xcode/DerivedData/Spiritbound-*/Build/Products/Debug-iphoneos -name "Spiritbound.app" -type d 2>/dev/null | head -n 1)

if [ -z "$DERIVED_APP" ]; then
    echo "❌ Could not find built Spiritbound.app in DerivedData"
    exit 1
fi

# Wait up to 60 seconds for device to be connected/available
DEVICE_LINE=""
for i in {1..30}; do
    DEVICE_LINE=$(xcrun devicectl list devices 2>/dev/null | grep -E "[[:space:]](connected|available)" | head -n 1 || true)
    if [ -n "$DEVICE_LINE" ]; then
        break
    fi
    echo "   Waiting for device tunnel (please ensure iPhone screen is unlocked)... ($i/30)"
    sleep 2
done

if [ -z "$DEVICE_LINE" ]; then
    DEVICE_LINE=$(xcrun devicectl list devices 2>/dev/null | grep -E "iPhone|iPad" | head -n 1 || true)
    STATE=$(echo "$DEVICE_LINE" | awk '{print $5}')
    echo "⚠️  Device found but state is '$STATE' (not 'connected')."
    echo "   Please UNLOCK your iPhone screen with Face ID/Passcode."
    echo "   Once unlocked, run: ./deploy_ios.sh"
    exit 1
fi

DEVICE_ID=$(echo "$DEVICE_LINE" | grep -o -E "([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}|[0-9A-Fa-f]{40})" | head -n 1)
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(echo "$DEVICE_LINE" | awk -F'[(]UDID[)]' '{print $1}' | awk '{print $NF}')
fi
DEVICE_NAME=$(echo "$DEVICE_LINE" | awk '{print $1" "$2}')

echo "🚀 Installing to $DEVICE_NAME ($DEVICE_ID)..."
INSTALLED=0
for attempt in {1..5}; do
    if xcrun devicectl device install app --device "$DEVICE_ID" "$DERIVED_APP"; then
        INSTALLED=1
        break
    else
        echo "⚠️  Install attempt $attempt failed (DDI or wireless tunnel settling), retrying in 3s..."
        sleep 3
    fi
done

if [ $INSTALLED -eq 0 ]; then
    echo "❌ Failed to install app after 5 attempts."
    exit 1
fi

echo "✨ Launching Spiritbound on $DEVICE_NAME..."
xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"
echo "🎉 Game successfully launched on your iPhone!"
