---
name: ios-device-deploy
description: >-
  CRITICAL RULE: You MUST use this specialist skill whenever building, deploying,
  or debugging Spiritbound on physical iOS devices via Xcode and devicectl, or
  handling user requests to deploy to phone, install app, or test on-device.
---

# iOS Device Deployment Skill

This skill provides step-by-step procedures for deploying Spiritbound to connected
Apple devices (e.g. `xu’s iPhone`).

## Quick Deployment

Run the automated deploy script:
```bash
.agents/skills/ios-device-deploy/scripts/deploy.sh
```

Or run manually:
```bash
# 1. Build Godot pck and Xcode target
./deploy_ios.sh

# 2. Check connected devices
xcrun devicectl list devices 2>/dev/null | grep -E "iPhone|iPad"

# 3. Install app to device
xcrun devicectl device install app --device "<DEVICE_UUID>" \
  "/Users/xujiacong/Library/Developer/Xcode/DerivedData/Spiritbound-deccbpwvmgfumcavfavitektjtkf/Build/Products/Debug-iphoneos/Spiritbound.app"

# 4. Launch app process
xcrun devicectl device process launch --device "<DEVICE_UUID>" com.jiacong.spiritbound
```

## Diagnosing Device States

When checking `xcrun devicectl list devices`:

| State | Meaning | Resolution |
|---|---|---|
| `connected` | Ready for deploy | Proceed with install and launch. |
| `unavailable` | Physically or wirelessly visible, but tunnel not established | 1. Ask user to **unlock iPhone screen**.<br>2. Prompt user to tap **Trust This Computer**.<br>3. Check USB cable connection (`ioreg -p IOUSB -w0 -l \| grep iPhone`). |
| Empty / Not listed | Device completely disconnected | Check USB connection or ensure Mac and iPhone share the same Wi-Fi. |

## Important Platform Constraints

- **No iOS Simulator support**: The official Godot 4.7.2 iOS export templates only
  include x86_64 slices and do not run on Apple Silicon simulators. Never attempt to
  boot an iOS simulator for this project.
- **Real device verification**: Do not claim visual verification unless deployed to a
  physical device and confirmed by the user. Headless test runs (`test_runner.gd`, `ui_smoke.gd`)
  are the acceptable substitute for code logic and layout sanity checks.
