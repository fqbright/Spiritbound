#!/bin/bash
set -e
set -o pipefail

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
# Read the team id from the signing identity Xcode created for this account.
# A plain `openssl x509` consumes only the first PEM block and exits, which delivers SIGPIPE
# to `security`; under `set -o pipefail` that aborts the whole script mid-deploy. It only
# happens once the keychain holds more than one signing identity, so it looks intermittent.
# Read every certificate, and make sure no stage of the pipeline exits before its input ends.
_CERT_PEMS="$(mktemp)"
security find-certificate -a -p > "$_CERT_PEMS" 2>/dev/null || true
DETECTED_TEAM=$(openssl crl2pkcs7 -nocrl -certfile "$_CERT_PEMS" 2>/dev/null \
    | openssl pkcs7 -print_certs -noout 2>/dev/null \
    | grep -o "OU=[A-Z0-9]\{10\}" | sed -n '1p' | cut -d= -f2 || true)
rm -f "$_CERT_PEMS"
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
    int SDL_IsAppleTV(void) { return 0; }
    int SDL_IsIPad(void) { return 0; }
    void StartAppleSignInWatcher(void);
}

__attribute__((constructor))
static void init_apple_auth_watcher(void) {
    StartAppleSignInWatcher();
}
EOF
        echo "   ✓ Patched dummy.cpp with Metal/QuartzCore/SDL compatibility symbols and auth watcher hook"
    elif ! grep -q "StartAppleSignInWatcher" "$DUMMY_CPP"; then
        cat << 'EOF' >> "$DUMMY_CPP"

extern "C" {
    void StartAppleSignInWatcher(void);
}

__attribute__((constructor))
static void init_apple_auth_watcher(void) {
    StartAppleSignInWatcher();
}
EOF
        echo "   ✓ Patched dummy.cpp with auth watcher hook"
    fi
fi

# Patch dummy.swift with native Sign in with Apple & OAuth URL interceptor
DUMMY_SWIFT="$BUILD_DIR/Spiritbound/dummy.swift"
if [ -f "$DUMMY_SWIFT" ]; then
    if ! grep -q "AppleAuthBridge" "$DUMMY_SWIFT"; then
        cat << 'EOF' >> "$DUMMY_SWIFT"

import Foundation
import UIKit
import AuthenticationServices

@available(iOS 13.0, *)
@objc public class AppleAuthBridge: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @objc public static let shared = AppleAuthBridge()

    @objc public func startSignIn() {
        DispatchQueue.main.async {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return UIWindow()
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userId = appleIDCredential.user
            let idTokenData = appleIDCredential.identityToken
            let idTokenString = idTokenData != nil ? String(data: idTokenData!, encoding: .utf8) ?? "" : ""
            let email = appleIDCredential.email ?? ""
            let givenName = appleIDCredential.fullName?.givenName ?? ""
            let familyName = appleIDCredential.fullName?.familyName ?? ""
            let displayName = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")

            let dict: [String: Any] = [
                "status": "success",
                "user_id": userId,
                "id_token": idTokenString,
                "identity_token": idTokenString,
                "email": email,
                "display_name": displayName
            ]
            saveResult(dict, filename: "auth_apple_result.json")
        }
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let dict: [String: Any] = [
            "status": "error",
            "error": error.localizedDescription
        ]
        AppURLInterceptor.saveResultToAll(dict, filename: "auth_apple_result.json")
    }

    private func saveResult(_ dict: [String: Any], filename: String) {
        AppURLInterceptor.saveResultToAll(dict, filename: filename)
    }
}

@objc public class AppURLInterceptor: NSObject {
    public static func getSearchDirectories() -> [URL] {
        var dirs: [URL] = []
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            dirs.append(docs)
        }
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            dirs.append(appSupport)
            dirs.append(appSupport.appendingPathComponent("Godot/app_userdata/Spiritbound"))
            dirs.append(appSupport.appendingPathComponent("Spiritbound"))
        }
        return dirs
    }

    public static func saveResultToAll(_ dict: [String: Any], filename: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) else { return }
        for dir in getSearchDirectories() {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent(filename)
            try? data.write(to: fileURL)
        }
    }

    @objc public static func setup() {
        if let gdtDelegate = NSClassFromString("GDTApplicationDelegate") {
            swizzleOpenURL(on: gdtDelegate)
            swizzleSceneOpenURL(on: gdtDelegate)
        }
        if let appDelegate = UIApplication.shared.delegate {
            swizzleOpenURL(on: type(of: appDelegate))
        }
        NotificationCenter.default.addObserver(forName: UIScene.willConnectNotification, object: nil, queue: .main) { notif in
            guard let scene = notif.object as? UIScene, let delegate = scene.delegate else { return }
            swizzleSceneOpenURL(on: type(of: delegate))
        }
    }

    private static func swizzleOpenURL(on cls: AnyClass) {
        let originalSelector = #selector(UIApplicationDelegate.application(_:open:options:))
        let swizzledSelector = #selector(appDelegateSwizzled_application(_:open:options:))
        if let swizzledMethod = class_getInstanceMethod(AppURLInterceptor.self, swizzledSelector) {
            if let originalMethod = class_getInstanceMethod(cls, originalSelector) {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            } else {
                class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            }
        }
    }

    private static func swizzleSceneOpenURL(on cls: AnyClass) {
        let originalSelector = #selector(UIWindowSceneDelegate.scene(_:openURLContexts:))
        let swizzledSelector = #selector(sceneSwizzled_openURLContexts(_:openURLContexts:))
        if let swizzledMethod = class_getInstanceMethod(AppURLInterceptor.self, swizzledSelector) {
            if let originalMethod = class_getInstanceMethod(cls, originalSelector) {
                method_exchangeImplementations(originalMethod, swizzledMethod)
            } else {
                class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            }
        }
    }

    @objc func appDelegateSwizzled_application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AppURLInterceptor.handleIncomingURL(url)
        return true
    }

    @available(iOS 13.0, *)
    @objc func sceneSwizzled_openURLContexts(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for ctx in URLContexts {
            AppURLInterceptor.handleIncomingURL(ctx.url)
        }
    }

    static func handleIncomingURL(_ url: URL) {
        let urlStr = url.absoluteString
        if url.scheme == "spiritbound-internal" && url.host == "apple-signin" {
            if #available(iOS 13.0, *) {
                AppleAuthBridge.shared.startSignIn()
            }
            return
        }
        if url.scheme == "spiritbound" {
            let dict: [String: Any] = ["url": urlStr]
            saveResultToAll(dict, filename: "oauth_callback_result.json")
        }
    }
}

@_cdecl("StartAppleSignInWatcher")
public func StartAppleSignInWatcher() {
    AppURLInterceptor.setup()
    DispatchQueue.global(qos: .userInteractive).async {
        while true {
            for dir in AppURLInterceptor.getSearchDirectories() {
                let trigger = dir.appendingPathComponent("auth_apple_trigger.json")
                if FileManager.default.fileExists(atPath: trigger.path) {
                    try? FileManager.default.removeItem(at: trigger)
                    DispatchQueue.main.async {
                        if #available(iOS 13.0, *) {
                            AppleAuthBridge.shared.startSignIn()
                        }
                    }
                    break
                }
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
    }
}
EOF
        echo "   ✓ Patched dummy.swift with native Sign in with Apple & URL interceptor"
    fi
fi

# Patch Spiritbound.entitlements with Sign in with Apple capability
ENTITLEMENTS="$BUILD_DIR/Spiritbound/Spiritbound.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    if ! grep -q "com.apple.developer.applesignin" "$ENTITLEMENTS"; then
        /usr/libexec/PlistBuddy -c "Add :com.apple.developer.applesignin array" "$ENTITLEMENTS" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :com.apple.developer.applesignin:0 string Default" "$ENTITLEMENTS" 2>/dev/null || true
        echo "   ✓ Added com.apple.developer.applesignin to Spiritbound.entitlements"
    fi
fi

PLIST="$BUILD_DIR/Spiritbound/Spiritbound-Info.plist"
if [ -f "$PLIST" ]; then
    if ! grep -q "spiritbound" "$PLIST"; then
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string spiritbound" "$PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:1 string spiritbound-internal" "$PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string com.jiacong.spiritbound" "$PLIST" 2>/dev/null || true
        echo "   ✓ Added URL Schemes (spiritbound, spiritbound-internal) to Spiritbound-Info.plist"
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
# Ask Xcode where the product actually landed instead of guessing. The shipped scheme sets
# buildConfiguration = Release for the build and Run actions, so a hardcoded
# ".../Debug-iphoneos" path does not find the app we just built -- it finds whatever stale
# Debug build an earlier session left in DerivedData, and installs that instead.
BUILT_PRODUCTS_DIR=$(xcodebuild -project "$BUILD_DIR/Spiritbound.xcodeproj" \
    -scheme Spiritbound \
    -destination "generic/platform=iOS" \
    -showBuildSettings 2>/dev/null \
    | sed -n 's/^[[:space:]]*BUILT_PRODUCTS_DIR = //p' | sed -n '1p')
DERIVED_APP="$BUILT_PRODUCTS_DIR/Spiritbound.app"

if [ -z "$BUILT_PRODUCTS_DIR" ] || [ ! -d "$DERIVED_APP" ]; then
    echo "❌ Could not find built Spiritbound.app (BUILT_PRODUCTS_DIR='$BUILT_PRODUCTS_DIR')"
    exit 1
fi
echo "   Using $DERIVED_APP"

# Refuse to install a bundle that does not carry the .pck we just exported, so a stale
# DerivedData copy can never be mistaken for the current build.
APP_PCK="$DERIVED_APP/Spiritbound.pck"
if [ -f "$APP_PCK" ] && [ -f "$BUILD_DIR/Spiritbound.pck" ]; then
    if [ "$(md5 -q "$APP_PCK")" != "$(md5 -q "$BUILD_DIR/Spiritbound.pck")" ]; then
        echo "❌ $DERIVED_APP does not contain the pck that was just exported."
        echo "   in bundle: $(md5 -q "$APP_PCK")"
        echo "   exported:  $(md5 -q "$BUILD_DIR/Spiritbound.pck")"
        echo "   This is stale build output. Delete $DERIVED_APP and re-run."
        exit 1
    fi
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

DEVICE_ID=$(echo "$DEVICE_LINE" | grep -o -E "([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}|[0-9A-Fa-f]{40})" | sed -n '1p')
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
LAUNCHED=0
for attempt in {1..5}; do
    if xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID" 2>/dev/null; then
        LAUNCHED=1
        echo "🎉 Game successfully launched on your iPhone!"
        break
    else
        echo "   Waiting for device unlock to launch... ($attempt/5)"
        sleep 2
    fi
done

if [ $LAUNCHED -eq 0 ]; then
    echo "📱 App installed successfully! Please tap the Spiritbound icon on your iPhone screen to open."
fi
