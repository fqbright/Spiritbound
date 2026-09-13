# Architecture decisions

## Initial platform choice

Swift is the initial iOS-first implementation choice. SpiritboundCore imports Foundation only, with no UI, network, storage, or monetization dependency. A future SwiftUI shell owns presentation and forwards player commands to the value-type engine. Android will need a deliberate core-port or shared-runtime decision; Swift does not provide an Android UI automatically. Revisit this before large content investment if simultaneous platform delivery becomes a requirement.

## Files and responsibilities

- Package.swift: platform boundary, resources, test target.
- Content.swift: content schema, decoding, validation, localized lookup.
- Combat.swift: combat snapshots, actions, piles, seeded RNG, effect execution, trigger dispatch.
- Resources/core.json: balancing, starting deck, cards, status definitions, translations.
- CombatTests.swift: behavior regression tests.

## Extension boundary

Statuses select event hooks, operations, stack scaling, decay and an optional next-attack modifier. The engine has no Burn-ID branch. Shield is a combatant damage resource handled through the generic shield operation. Effects target actor or opponent; this milestone supports one enemy. Trigger chains stop at depth 32 to prevent infinite recursion; production content should reject cycles during authoring and surface diagnostics.

The current effect vocabulary is intentionally small. Additional operations and modifier stages are needed for Weak, Vulnerable, Strength, Flow, Charge, transfer/consume/spread and more complex targeting. Do not add individual status-ID checks to Combat. Extend generic operations and test their interaction order.

Repeated damage effects can express multiple hits, but there is no author-friendly repeat operation yet. Exhaust is supported by data, though no starter card exhausts. Duration policies, card upgrades, temporary/generated cards, enemy intent definitions, replay serialization, structured event logs and save migrations remain future work.

## Determinism and ownership

Each Combat owns its content and random generator. Card instances use unique combat-local integer IDs, independent of definition IDs. Action preconditions run before mutations. Stable content arrays define status ordering. Seed replay is currently only promised within this implementation/toolchain; Swift's shuffle algorithm is not a versioned replay format.

## Content and product constraints

Keep stable content IDs separate from translated display names. Extend localization to all descriptions and UI before player-facing delivery. No external art or copied assets are included. Region-specific publishing requirements, accessibility, privacy and distribution planning belong in subsequent release milestones.

## Milestone 2: presentation and app shell

- BattlePresentation.swift: pure localized rules descriptions derived from actual effect data; shared by tests and UI.
- SpiritboundUI/BattleModel.swift: main-actor observable adapter; owns the combat snapshot and forwards validated commands. Errors become localized keys.
- SpiritboundUI/BattleView.swift: scrollable battle layout, card actions, statuses, hidden-order pile inspection, outcome and language controls.
- SpiritboundUI/SpiritboundRootView.swift: content loading and recoverable launch-error view.
- App/SpiritboundApp.swift: executable SwiftUI entry point.
- App/Spiritbound.xcodeproj: iPhone-only portrait app referencing the local Swift package; shared launch scheme and explicit Info.plist.

Presentation does not mutate combat internals or duplicate damage calculations. Intent reads the same enemyDamage rule used by the training enemy. Card descriptions interpolate effects; status descriptions interpolate definition values. Language changes redraw the view without restarting combat. Piles sort by definition ID and instance ID to hide future draw order. Only the language preference persists. The app has no network dependencies.
