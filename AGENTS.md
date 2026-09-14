# Working on Spiritbound

A portrait mobile card-battler in Godot 4.7.2. Read this before changing anything.

## Where things are

| Path | What it is |
| --- | --- |
| `Godot/scripts/combat.gd` | Rules engine. Cards, intents, relics, statuses. **No UI.** |
| `Godot/scripts/game.gd` | Every screen, built in code rather than scenes. |
| `Godot/scripts/content.gd` | Card/equipment/rune/relic data and all UI strings. |
| `Godot/scripts/save_store.gd` | Local profile, versioned for a future cloud sync. |
| `Godot/data/core.json` | Card definitions and balance numbers. |
| `Godot/tests/test_runner.gd` | Rules-engine regression suite. |
| `Godot/tests/ui_smoke.gd` | Headless walk over every screen and a full combat turn. |
| `Sources/`, `App/`, `Tests/`, `Expo/` | Abandoned Swift and React Native prototypes. Ignore them. |
| `Docs/ARCHITECTURE.md` | Why the code is shaped this way. Read it before a structural change. |

## Verifying a change

```bash
godot --headless --path Godot/ --script res://tests/test_runner.gd   # rules
godot --headless --path Godot/ --script res://tests/ui_smoke.gd      # screens + a combat turn
```

Both must pass. Run `ui_smoke.gd` for anything touching a screen — it is not optional
polish, it is the only thing standing in for a simulator.

**The iOS Simulator cannot run this project.** The official Godot 4.7.2 iOS export
templates ship a simulator library containing only an x86_64 slice, so there is nothing
to link against on Apple Silicon, and current iOS simulator runtimes no longer execute
x86_64 apps. Device deploy is `./deploy_ios.sh` with an iPhone connected. If no device is
attached, say so rather than claiming a change was visually verified.

## Rules

1. **`combat.gd` never references a node, scene or `Control`.** That boundary is what makes
   the headless suites possible. Keep game rules out of `game.gd` too where you can.
2. **Every user-facing string goes in `UI_TEXT` in `content.gd` with both `zh-Hans` and
   `en`.** Never hardcode text in `game.gd`.
3. **Add the assertion that would have caught your bug.** Rules changes go in
   `test_runner.gd`, screen changes in `ui_smoke.gd`.
4. **Do not commit `Godot/.godot/`** — it is regenerated editor cache. It is unfortunately
   already tracked; just do not add to the churn.
5. **State how you verified.** Headless-only is acceptable. Claiming a visual check you did
   not perform is not.

## Traps that have already cost time here

Every one of these produced a wrong screen with no error in the log. They are the reason
`ui_smoke.gd` exists.

- **GDScript warnings are errors.** `var x := some_dict.get(k)` fails the build, because
  `Dictionary.get()` returns `Variant`. Annotate the type: `var x: String = ...`.
- **Containers resize their children.** A `ColorRect` inside a `PanelContainer` is stretched
  to fill it every frame — that is why a health bar never moved. Use `ProgressBar` for bars,
  and parent manually-sized nodes to a plain `Control` or `Panel`.
- **Decorative children swallow input.** `PanelContainer` and `Panel` default to
  `MOUSE_FILTER_STOP`, so a panel over card art eats the tap. Set `MOUSE_FILTER_IGNORE` on
  anything decorative.
- **`z_index` beats tree order.** A node added later still draws underneath a sibling with a
  higher `z_index`. Map pins are 10, the traveller 25, floating bars 100, toasts 500.
- **Anchor presets resolve against the minimum size at call time.** Calling
  `set_anchors_and_offsets_preset` before adding children bakes in a zero size, and a plain
  `Control` parent never recomputes it — the node collapses and silently disappears. Set
  anchors and offsets by hand for floating bars.
- **Bind looping tweens to the node they animate** (`sprite.create_tween()`), not to the game
  root. Root-bound tweens outlive the screen rebuild and spin as zero-duration loops.
- **Restore transforms from a recorded base, and make sure it is recorded.** Enemy sprites
  read `base_scale` from a meta that was never set on them, fell back to `1.0`, and ended up
  three times their real size after every action.
- **A wrong type annotation kills a coroutine silently.** Assigning a `Sprite2D` to a
  `Control` variable raised mid-`await` and aborted the turn handoff with no crash.
- **`ui_smoke.gd` writes through to the real save file.** It borrows and restores it; if you
  add steps that grant rewards, keep that discipline or runs contaminate each other.

## Game rules worth knowing before touching balance

- 3 energy per turn, no cap on the number of cards played — energy alone gates plays. Card
  costs run 1/2/3 (18/15/3 cards respectively) so energy is a real constraint on a built-out
  deck. Keep the starting deck (`startingDeck` in `core.json`) all 1-cost — the first
  stretch of the campaign is meant to be forgiving, and that is where the difficulty curve
  controls it, not card costs. `test_runner.gd` pins the cost spread and asserts that two
  2-cost cards cannot both fit in one turn; if you touch `core.json` costs, keep that
  assertion honest rather than loosening it.
- There is no End Turn button: the turn ends itself once nothing left in hand is affordable
  (empty hand or every remaining card costs more than remaining energy) — see
  `_maybe_end_turn()` in `game.gd`. There used to also be a fixed plays-per-turn cap
  (`state.actions`); it was removed so cost, not an arbitrary play count, is the only
  constraint. Swift's rune and the foxCharm relic were both action-based and are now
  energy-based (refund/grant energy instead of an extra play) — keep that in mind if you see
  older references to "actions" anywhere.
- Enemies roll an intent a turn ahead and `_execute_intent` spends exactly the telegraphed
  amount. Never recompute it at execution time — the promise is the mechanic.
- A card with any `target: "opponent"` effect aims at enemies; everything else aims at the
  player. `_is_attack` (damage only) drives damage bonuses; `_targets_opponent` drives
  targeting. Conflating them either loses pure-debuff cards or wastes Focus on them.
- 36 cards, 250 stages across 50 chapters, a four-band difficulty curve (see
  Docs/ARCHITECTURE.md), and two enemy debuffs beyond burn/stun: `vulnerable` (+50% damage
  taken) and `weak` (-25% damage dealt), both decaying by one enemy turn. `strength` is the
  player-side counterpart to Focus — permanent for the battle instead of a one-shot burst —
  and both live as generic dictionary fields (`enemy.vulnerable`, `player.strength`), not
  special-cased branches, so a new status is usually a `desc.<name>` string plus one read
  site, not an engine rewrite.
- `_card_build_score` in `game.gd` drives both "smart-build" and "smart-add" and has to
  reflect what a card's effects are actually worth, not just its rarity — see the
  "250-stage difficulty curve" section in Docs/ARCHITECTURE.md for what went wrong the one
  time it didn't. If you add an operation or status the scorer doesn't know about, it silently
  scores as zero; give it a case.
- Any encounter mechanic key in `content.gd` (`shield_per_turn`, `regeneration`,
  `dodge_every`, `enrage`, `critical_every`, `below_half`, `thorns`) is only real if
  `combat.gd` reads it somewhere — `thorns` sat in the data for an entire prior milestone
  doing nothing before anyone noticed. Grep for the key in `combat.gd` before trusting that
  an encounter modifier does what its name implies.

## Visual art: current state, and integrating real assets

The visual presentation blends high-detail painted assets with procedural vector accents:
- **Map chapter backgrounds** — `_add_map_chapter()` calls `_get_chapter_map_texture(chapter: int) -> Texture2D`.
  - **Asset pipeline**: Checks `res://assets/chapters/chapter_%d.png` (390x520 PNG). If present, loads that unique chapter background directly.
  - **Fallback & modulation**: If a specific chapter file is absent, falls back to `_biome_textures` (`res://assets/biomes/biome_0..5.png`) with per-chapter regional tint modulation (`Color.WHITE.lerp(tint, 0.35)`) and alternating horizontal flipping (`((chapter / 6) % 2 == 1)`), providing unique visual atmospheres across all 50 chapters without obvious repetition.
  - **Adding unique chapter art**: Place 390x520 PNGs into `Godot/assets/chapters/` named `chapter_0.png` through `chapter_49.png`, run `godot --headless --path Godot/ --editor --quit` to import, and the game automatically displays each chapter's unique painted illustration 1:1.
  - **Chapter quick-jump strip**: `_jump_strip_item` renders miniature chapter previews through `_get_chapter_map_texture(chapter)`.
  - **Terrain dressing**: `_add_terrain_dressing()` adds subtle vector accents with softened alpha (0.2-0.35) so they do not overpower the painted illustrations, while preserving the collision-avoidance checks verified by `ui_smoke.gd`.
- **Card frames and layouts** — Cards across hand (`_card_view`), shop (`_shop_card_tile`), and deck (`_deck_card_tile`):
  - **Full-bleed art & frame**: Card illustration (`_get_card_texture`) and ornate frame (`card_frame_golden.png`) occupy the entire card rectangle (`PRESET_FULL_RECT`).
  - **Cutout info box**: An elegant semi-translucent dark panel (`Color(0.06, 0.12, 0.16, 0.90)`) is carved out in the lower-middle portion of the card, housing card title, element/kind tags, effect description, owned/deck status counters, and action/buy buttons.
  - **Floating badges**: Energy cost badge floats top-left; rune icon and rarity star row float top-right.
- **Battle interaction (no enlarge popup)** — Hand card tapping in battle plays directly (for defensive/skill cards, or attack cards when only one enemy is alive). When multiple enemies are alive, tapping an attack card arms targeting directly on that card, and tapping a target enemy executes the attack. Tapping an armed card again deselects it. No enlarged modal preview popup is shown.
- **Stage pins** — `_add_stage_pin()` overlays `assets/map_pin_rune.png` atop the procedural pin badge, tail, and shadow.
- **Character/monster art and battle backgrounds** — `character-atlas-v3.png` (3x3 grid, `CHAR_KEYS` maps names to cells) via `_get_character_texture()`, and `BATTLE_BACKGROUNDS` (`assets/backgrounds/*.jpg`) for battle backdrops and setup.

## Handoff & verification notes for future agents

- **Verifying changes**:
  ```bash
  godot --headless --path Godot/ --script res://tests/test_runner.gd   # rules (47 checks)
  godot --headless --path Godot/ --script res://tests/ui_smoke.gd      # screens + combat turn
  ```
  Both must pass without failures before committing.
- **Deploying to iOS**:
  Run `./deploy_ios.sh --full-export` with the iPhone unlocked and connected. If the screen is locked, `devicectl` reports `unavailable`.
- **Importing newly added images**:
  Always run `godot --headless --path Godot/ --editor --quit` after adding `.png` or `.jpg` assets to generate `.import` metadata before testing or packaging.
