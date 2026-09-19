# Spiritbound

A portrait mobile card-battler built in Godot 4. You play a spirit tamer working
up a 250-stage campaign across 50 chapters, building a 25-card deck from a pool of
47 and fitting it with equipment, runes and relics along the way. Difficulty runs
in four bands — see [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md#the-250-stage-difficulty-curve)
for the curve and how it was tuned.

Fully bilingual — English and 简体中文 — switchable at any time from the map.

> Status: playable end to end and running on device, but still in active
> development. Balance, art and progression are all subject to change.

## How it plays

Each turn opens with **2 energy**, climbing to 3 on turn 3, 4 on turn 5, and so
on. Energy alone gates what you can play — there is no fixed plays-per-turn cap —
and the turn hands itself over once nothing left in hand is affordable. A **Pass**
button lets you end a turn early with cards still in hand. Enemies telegraph their
next move a turn ahead (attack, defend, empower, curse, or a combination) and then
do exactly what they showed, so you can always plan against a known board.

Drag a card onto an enemy and the predicted damage appears above it, including
Focus, equipment, relic and rune bonuses, plus how much their shield will absorb
and whether the hit is lethal.

## Running it

Requires **Godot 4.7.2** (`brew install --cask godot`).

```bash
godot --path Godot/
```

The design viewport is 390 × 844 portrait.

### On an iPhone

Requires Xcode 16+ and an Apple developer account (a free one works).

```bash
./deploy_ios.sh
```

This exports the project, configures signing, then builds, installs and launches
on a connected device. See [Godot/README.md](Godot/README.md) for the manual
Xcode route and signing details.

**The iOS Simulator does not work** and this is not a project bug: the official
Godot 4.7.2 iOS export templates ship a simulator library that contains only an
x86_64 slice, despite being packaged under an `ios-arm64_x86_64-simulator`
folder. On Apple Silicon there is no arm64 slice to link against, and recent iOS
simulator runtimes no longer execute x86_64 apps, so the usual workaround is
dead too. Test on a physical device, or use the headless suites below.

## Tests

The whole suite runs headlessly from the repository root:

```bash
./run_tests.sh                 # core: test_runner + ui_smoke + e2e_playthrough
./run_tests.sh --all           # everything, including the balance trajectory bot
./run_tests.sh --balance       # 250-stage balance trajectory bot (byte-reproducible)
./run_tests.sh --balance-quick # the same bot, retry-capped — the CI-friendly form
```

`test_runner.gd` covers the rules engine (575 checks). `ui_smoke.gd` walks every
screen and plays a full combat turn — it exists because the simulator is
unavailable, and it asserts things that are hard to eyeball, for example that the
damage preview equals the damage actually dealt and that enemies execute exactly
the intent they telegraphed. `e2e_playthrough.gd` drives several real stages end
to end. `balance_probe.gd` replays the entire 250-stage campaign with the game's
own heuristic AI and fails if the four-band difficulty curve drifts — see
[Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md#the-250-stage-difficulty-curve) for the
measured numbers. These suites have already caught several bugs that unit tests
could not, including a type error that silently killed a coroutine mid-turn and a
parse error that left the main script unattached.

## Layout

| Path | What it is |
| --- | --- |
| `Godot/scripts/combat.gd` | Rules engine — cards, intents, relics, statuses. No UI. |
| `Godot/scripts/game.gd` | Game shell that composes the per-screen scripts (`game_*_screen.gd`) and holds shared helpers. |
| `Godot/scripts/content.gd` | Card/equipment/rune/relic definitions and all UI strings. |
| `Godot/scripts/save_store.gd` | Local profile, versioned and ready for cloud sync. |
| `Godot/data/core.json` | Card definitions and balance numbers. |
| `Docs/` | Architecture and roadmap notes from the Swift era. |

Combat logic is deliberately kept free of UI code, which is what makes the
headless test suites possible.

### Legacy prototypes

`Sources/`, `App/` and `Tests/` hold the original Swift/SwiftUI prototype
(`swift build && swift test`), and `Expo/` holds a React Native one. Both predate
the Godot port and are kept for reference only — neither is maintained.

## Why this is open source

Spiritbound is public because the interesting part of it is not the game, it is
everything around building one this way.

Most of this codebase was written by AI coding agents working against a running
game, and the failures were more instructive than the successes. Several bugs in
here were invisible to unit tests and only showed up by driving the real UI: a
health bar that never moved because a container silently resized its child every
frame, a turn that never ended because a wrong type annotation aborted a
coroutine without crashing. The project keeps its scaffolding — the headless
smoke test, the test that compares predicted damage against dealt damage — in
the repository rather than throwing it away, because that scaffolding is the
part worth copying.

It is also a reasonably complete small game rather than a toy: a rules engine
with no UI dependencies, a bilingual interface, a real iOS build and deploy
pipeline, and a save format built for sync before any backend exists. If you are
building a mobile card game, or working out how to verify software an agent
wrote for you, there should be something here you can take.

No contributor licence agreement, no roadmap you have to agree with. Fork it and
do what you want with the code.

## Contributing

Issues and pull requests are welcome — bug reports especially, since the game
gets tested on exactly one device.

Before opening a PR:

1. **Run the suite.** `./run_tests.sh` for rules and screen changes; if you
   touched the difficulty curve, also run `./run_tests.sh --balance` (or
   `--balance-quick`). Everything must pass.
2. **Add a check for what you changed.** If you fix a bug, add the assertion
   that would have caught it. Combat and balance go in `test_runner.gd`; screens
   in `ui_smoke.gd`; campaign flows in `e2e_playthrough.gd`.
3. **Keep combat free of UI.** `combat.gd` must never reference a node, scene or
   `Control`. That boundary is what keeps the game testable headlessly.
4. **Say how you verified it.** "Tests pass" is fine for rules work. For UI work,
   say whether you ran it on a device, in the editor, or only headlessly —
   headless-only is acceptable, just be explicit about it.

Both languages need to stay in sync: user-facing strings live in `UI_TEXT` in
`content.gd` and every entry needs `zh-Hans` and `en`. Never hardcode a string
in `game.gd`.

Some things to know before you dig in:

- `game.gd` builds its UI in code rather than with scenes. That is unusual for
  Godot and it makes the file long, but it keeps every screen in one searchable
  place.
- GDScript warnings are errors in this project. `var x := some_dictionary.get(k)`
  will fail the build, because `Dictionary.get()` returns `Variant` — annotate
  the type explicitly.
- Containers resize their children. If you need a node to keep a size you set
  yourself, parent it to a `Control` or `Panel`, not a `PanelContainer`.
- Bind looping tweens to the node they animate (`sprite.create_tween()`), not to
  the game root, or they outlive the screen and spin as zero-duration loops.

## Licence

Source code is MIT. **Artwork and audio are not** — they are All Rights Reserved
and excluded from the MIT grant. You can build and play the game, and reuse the
code freely; you cannot ship the assets. See [LICENSE](LICENSE) for the exact
boundary.
