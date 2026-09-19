# Spiritbound — Godot 4

Portrait mobile card-battler engine and complete client, featuring a 250-stage campaign across 50 chapters, a 47-card pool, 12 equipment pieces, 10 card runes, 11 relics, finite deck mechanics, audio, original art, and full bilingual support (English + 简体中文). See the [root README](../README.md) for how it plays and [Docs/ARCHITECTURE.md](../Docs/ARCHITECTURE.md) for the difficulty curve.

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

Run the whole headless suite from the repository root:

```bash
./run_tests.sh          # core: test_runner + ui_smoke + e2e_playthrough
./run_tests.sh --all    # everything, including the balance trajectory bot
```

`test_runner.gd` covers the rules engine, `ui_smoke.gd` walks every screen plus a full combat
turn (it exists because the iOS Simulator cannot run this project), `e2e_playthrough.gd`
drives several real stages, and `balance_probe.gd` replays the 250-stage campaign to guard the
difficulty curve. Everything must pass; see [AGENTS.md](../AGENTS.md) for what to do before
touching combat or a screen.
