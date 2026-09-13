# Milestone 2 delivery

## Scope

Provide the first interactive single-enemy training battle and a concrete iOS app target. This is not the Alpha content milestone.

## Validation completed

- Core and SwiftUI package build on the available macOS SDK.
- App entry point typechecks against the built modules.
- UI model smoke check passed for playing a card, ending a turn and restarting.
- Xcode project and Info.plist syntax validation.
- Ten behavior checks: localization lookup, seeded start, rejected-action atomicity, pile conservation, Burn timing/decay, Focus consumption, defeat locking, data-derived bilingual descriptions, shield expiry and playable victory.
- English and Chinese layout rendering in a 390-point-wide native macOS host. Corrected End Turn contrast after visual inspection.

The assertion harness executes the repository's test method bodies but does not replace running XCTest in CI. No iOS simulator or device test is claimed.

## iOS acceptance pass still required

In full Xcode, build and launch the shared Spiritbound scheme on an iPhone simulator. Confirm the entire hand is reachable by scrolling and End Turn stays accessible. Inspect each pile and dismiss it; empty piles should explain their state. Spend energy to disable unaffordable cards. Play Foxfire and confirm Burn resolves after the enemy attacks. Play Focus then Strike to confirm the bonus is consumed. Finish a battle, restart, and verify resources reset. Switch languages during battle and confirm the combat state remains intact.

Repeat with larger accessibility text and VoiceOver, then on a physical device. Confirm portrait orientation, safe-area behavior and background/foreground behavior. Relaunch currently starts a fresh battle; save/resume is intentionally a later milestone.

## Remaining limitations

System symbols stand in for original creature art. The enemy has one fixed attack. No animations, audio, run map, rewards, persistence or additional spirit systems yet. UI localization is developer-authored and still needs native-speaker editorial review. The current app bundle identifier is a development placeholder. App Store icons, signing and distribution metadata are not configured.

## Layout previews

These are native macOS-host renders of the shared SwiftUI screen, not iPhone screenshots.

[English](Previews/battle-en.png) · [简体中文](Previews/battle-zh-Hans.png)
