# Spiritbound

## Expo Go version

The playable React Native port is in `Expo/`. It targets Expo SDK 57 and runs in Expo Go 57.0.0. See `Expo/README.md` for phone setup, commands, and the current file-watcher limitation.

Milestone 2: a native portrait training battle, built on the tested Swift combat foundation.

## Open and run on iPhone simulator

1. Open `App/Spiritbound.xcodeproj` in full Xcode with an iOS SDK and Swift 6 support.
2. Select the shared **Spiritbound** scheme and an iPhone simulator running iOS 17 or newer.
3. Run. No third-party packages, services or credentials are required.
4. For a physical device, select your development team and replace the development bundle identifier in Signing & Capabilities.

Tap cards to play them against the sentinel, then end the turn. Inspect any pile, change language with the globe menu, or restart. A new battle shuffles the ten-card starting deck. Restarting an active battle asks before replacing it.

## Delivered

- UI-independent combat module with seeded randomness, unique card instances, four piles, energy, shield, Burn, Focus and terminal states.
- SwiftUI battle screen with visible enemy intent, health and status explanations, adaptive scrollable card grid, pile sheets and outcome panel.
- English and Simplified Chinese UI, cards, effects and status explanations; remembered language preference with system-language default.
- VoiceOver labels for cards, controls and resources; scalable text and scrollable content. Device accessibility testing remains pending.
- JSON balance data, ten regression checks, and a shared iPhone Xcode app scheme.

The training enemy and spirit use system-symbol placeholders. No final creature artwork, audio, save/resume, run map or progression is included yet. Battles restart on app relaunch; only the language preference is saved.

## Package checks

From this directory use `swift build` and `swift test`. The package supports iOS 17+ and macOS 14+; macOS support allows compilation and headless rules checks without an iOS simulator.

In this delivery environment, both core and SwiftUI modules compile with Swift 6.3.1. Ten combat/presentation checks passed through a temporary assertion harness using the same XCTest method bodies. The app entry point typechecks against the macOS-built modules, and the project/plist files pass syntax validation. English and Chinese screens were visually inspected using a 390-point-wide native macOS host; this is not iOS runtime verification.

Standard XCTest, Xcode project build, iOS simulator/device behavior and touch/VoiceOver interaction still require full Xcode. This machine currently provides only Command Line Tools. No iOS binary is included.

## Provisional combat rules

Draw five cards and refresh to three energy per turn. Unplayed cards discard at end of turn. Shield clears at its owner's next turn start. The sentinel attacks for seven damage. Burn deals shield-absorbed damage at its owner's turn end, then loses one stack. Focus adds three damage to the first damage effect of the next attack and is consumed; Focus stacks add together. Numeric balance values live in JSON.

## Next milestone

Validate the battle on iOS, then expand the combat system with a modifier pipeline, duration policies, card upgrades and additional Crimson Fox Burn interactions before introducing run progression. See `Docs/ROADMAP.md`, `Docs/ARCHITECTURE.md` and `Docs/MILESTONE-2.md`.
