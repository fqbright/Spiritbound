# Spiritbound — Godot 4

Portrait mobile card-battler engine and complete client, featuring a 50-stage campaign, 12 equipment pieces, 10 card runes, finite deck mechanics, audio, original art, and full bilingual support (English + 简体中文).

## Requirements

- **Godot 4.7.2** Standard build (`brew install --cask godot`)
- **Xcode 16+** with iOS 16+ SDK (installed in `/Applications/Xcode.app`)

## How to Test on iPhone (Step-by-Step)

The iOS Xcode project has already been generated in `build/ios/Spiritbound.xcodeproj`.

### Option A: Via Xcode (Recommended for Physical iPhone)

1. Connect your iPhone to your Mac via USB or Wi-Fi.
2. Open the exported Xcode project:
   ```bash
   open Godot/build/ios/Spiritbound.xcodeproj
   ```
3. In Xcode:
   - Select the **Spiritbound** target in the left project navigator.
   - Go to the **Signing & Capabilities** tab.
   - Under **Signing**, choose your **Team** (your personal Apple ID / Free Developer Account works fine; no paid account required).
   - If needed, change the Bundle Identifier slightly (e.g. `com.yourname.spiritbound`) if the default is taken.
4. Select your connected iPhone from the device target list at the top toolbar.
5. Press **Cmd + R** (or click the **Play / Build & Run** button).
6. On your iPhone:
   - If prompted "Untrusted Developer", go to **Settings → General → VPN & Device Management**, tap your developer certificate, and tap **Trust**.
   - Tap Spiritbound to play!

### Option B: Via Command Line (Direct Simulator / Device Build)

To build headlessly targeting a connected device or simulator:

```bash
# Build for physical iPhone
xcodebuild -project Godot/build/ios/Spiritbound.xcodeproj -scheme Spiritbound -sdk iphoneos -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO

# Or re-export fresh from Godot anytime:
godot --headless --path Godot/ --export-debug "iOS" build/ios/Spiritbound.ipa
```

## Run in Godot Editor

1. Open Godot:
   ```bash
   godot -e --path Godot/
   ```
2. Press **F5** (or the Play button) to run the game.
3. The viewport runs at native mobile resolution `390 × 844` portrait.

## Language Support (Bilingual)

- Tap the **中/EN** button in the top navigation bar on the world map to toggle dynamically between English and 简体中文.
- Language preference is automatically saved to `user://spiritbound-save.json`.

## Automated Tests

Run the full headless regression test suite:

```bash
godot --headless --path Godot/ --script res://tests/test_runner.gd
```

**Status:** 21 checks, 0 failures.

Covers:
- Card definitions, 25-card starter deck, 50-stage campaign
- 12 equipment definitions and 10 rune definitions
- Opening hand drawing and action economy
- Swift rune action refunding
- Chain rune single-target and multi-enemy damage
- Cycle rune draw pile manipulation
- Opening shield and Mist Cloak damage mitigation
- Phoenix Mail fatal damage survival
- Save/profile schema validation
- Bilingual card, UI, stage, equipment, and rune localization

## Fixes & Improvements Delivered

1. **Fixed Focus Initial Value:** `player.focus` previously started at `1` in combat creation, granting an unintended free +3 damage bonus on the opening strike. Corrected to `0` (focus is only gained by playing Focus cards or through Focus Charm).
2. **Fixed Discard Reshuffle in Combat:** Drawing from an empty draw pile now reshuffles discard into draw (matching the canonical rules engine). Prevented premature game-over when deck was exhausted.
3. **Full Bilingual Support:** English and Simplified Chinese strings for all UI views (Map, Battle, Rewards, Camp, Shop, Deck, Loadout, Events) with real-time toggle.
4. **iOS Export Pipeline:** Configured `export_presets.cfg` with required iOS privacy manifests, app icons (1024x1024), and export templates; exported valid `Spiritbound.xcodeproj` verified with `xcodebuild`.
