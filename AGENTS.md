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
- **A `TextureRect`'s explicitly-assigned `.position`/`.size` does not reliably stick once
  `expand_mode`/`stretch_mode` are also set — it can silently revert to the texture's own
  native pixel size.** `_add_ornate_frame`'s frame overlay was assigned `position = Vector2.ZERO;
  size = size` (the tile's size) and rendered at `card_frame_golden_border.png`'s actual
  728x1006 instead — a texture ~4x the tile in each dimension, so the tile showed nothing but
  a zoomed-in sliver of solid border. `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`
  does not have this problem, because anchors are recomputed continuously against the parent's
  current size rather than relying on a one-time size assignment surviving later property
  writes — that is what `_card_view`'s and `_big_card_face`'s frame overlays already used, and
  why they didn't hit this. Prefer anchors over an explicit `.size` for any `TextureRect`
  layered with `expand_mode`/`stretch_mode`, and if a diagnosis like this is ever needed again,
  add a test asserting the node's actual `.size` matches the parent instead of just asserting
  the node exists — existence alone missed this bug for two whole rounds.

## Game rules worth knowing before touching balance

- Energy opens at 2 and climbs by 1 every two turns (turns 1-2 -> 2, 3-4 -> 3, 5-6 -> 4, ...;
  see `end_turn()` in `combat.gd`: `state.energy = 2 + int((state.turn - 1) / 2)`), not a flat
  per-turn amount — a long fight gradually loosens up instead of staying exactly as tight on
  turn 20 as turn 1. No cap on the number of cards played — energy alone gates plays. Card
  costs run 1/2/3 (18/15/3 cards respectively) so energy is a real constraint on a built-out
  deck early on. Keep the starting deck (`startingDeck` in `core.json`) all 1-cost — the first
  stretch of the campaign is meant to be forgiving, and that is where the difficulty curve
  controls it, not card costs. `test_runner.gd` asserts that two 2-cost cards cannot both fit
  in turn one's energy; if you touch `core.json` costs or the energy formula, keep that
  assertion honest rather than loosening it.
- Hand size is not refilled to a target each turn — `end_turn()` draws a flat 2 cards
  (`_draw(2)`), so an unspent hand grows turn over turn until `_draw()`'s own 10-card cap
  kicks in. The opening hand at battle start is still 5 (`create()` still calls
  `_draw(5 + ...)`) — only the per-turn draw changed.
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
  - **Adding unique chapter art**: Place 390x520 PNGs into `Godot/assets/chapters/` named `chapter_0.png` through `chapter_49.png`, run `godot --headless --path Godot/ --editor --quit` to import, and the game automatically displays each chapter's unique painted illustration 1:1. Chapters 0 through 9 (Band 1: Mistwood, Ember Delta, Thunder Peaks, Stone Citadel, Thorn Wilds, Spirit Tide, Jade Sanctuary, Mirage Expanse, Fury Caldera, Worldforge) now each have unique, high-detail painted backgrounds matching their narrative identity from `content.gd`.
  - **Road alignment**: `_chapter_waypoints()` looks up `BIOME_PATH_WAYPOINTS[chapter % 6]`, five hand-picked points that trace the painted trail baked into the backgrounds, mirrored (`MAP_WIDTH - x`) when horizontally flipped.
  - There used to be a bottom quick-jump strip of small chapter-preview tiles (tap one to scroll the map to that chapter); it was removed by request. If it comes back, the previous implementation cached each tile's live terrain-wash texture rather than a placeholder swatch.
  - **Terrain dressing**: `_add_terrain_dressing()` adds subtle vector accents with softened alpha (0.2-0.35) so they do not overpower the painted illustrations, while preserving the collision-avoidance checks verified by `ui_smoke.gd`.
- **Card frames and layouts** — Cards across hand (`_card_view`), the enlarged peek (`_big_card_face`), shop (`_shop_card_tile`), and deck (`_deck_card_tile`) all use the same language: full-bleed illustration, then a solid near-opaque rules box from ~52% down (name/type line, then description), not a small boxed-in art thumbnail with text floating around it.
  - **The ornate frame is `card_frame_golden_border.png`, not `card_frame_golden.png`.** The raw asset is a wall-picture-frame shape — a wide ornate ring around a *small* transparent window (~half the image) plus a bottom medallion. Stretched over a whole card it either blurs into a translucent gold haze at hand-card size (fine scrollwork + lots of transparent gaps average out under a >5x minification) or, at any size, covers the full-bleed art and blocks the rules text under it. The derived asset keeps only the outer ring: first cropped to the ornament's own non-transparent content bounding box (the source has ~8-10% of transparent padding baked in around it — skip this crop and the border renders with a visible gap floating in from the card edge, no matter how much you widen the kept band, because that padding is untouched by the margin math), then keeping the outer ~16% of *that* cropped image as the visible band. The medallion is left in rather than punched out — clearing it where it crosses the kept band left a gap in the border — so it just merges into the bottom edge. Regenerate it from `card_frame_golden.png` with this same two-step crop if you need to retune the thickness; do not swap in the raw asset anywhere the card isn't life-sized.
  - Both `_card_view`'s and `_big_card_face`'s outer container must be a plain `Panel`, not `PanelContainer`. A `Container` force-fits *every* direct child to its own full rect — with the illustration, the anchored info box, and the frame overlay all as direct children, that silently collapsed the whole card into a solid block showing only whichever child was added last, with no error in the log.
  - **Floating badges**: Energy cost badge floats top-left; rune icon and rarity star row float top-right.
- **Battle interaction — hold to peek, tap to play.** Tapping a hand card in battle (release within `HandCard.TAP_THRESHOLD_MS`, no drag) plays it directly (or arms targeting, for an attack card with more than one enemy alive); holding it longer just closes an enlarged peek without playing. The peek (`_show_hold_preview`/`_big_card_face`) appears **immediately** on every press — there is deliberately no delay-before-showing to distinguish "might be a hold" first; `HandCard._on_touch_up` decides tap-vs-hold retroactively from `_press_time_ms` instead. An earlier version *did* wait ~200ms before showing the peek, reasoning that the wait itself sat in the window iOS's long-press/haptic-touch gesture recognition watches for; removing that delay was a real improvement but **did not fully fix it** — a long-enough hold's own release can still go missing outright on a real device (not just delayed), independent of anything Godot does before that point, and no combination of `HandCard._on_touch_up`, its raw `_input()` event watcher, or a flat `PREVIEW_MAX_DURATION` timeout closed it reliably by themselves. **The actual fix is `_show_hold_preview` wrapping the peek in `_modal_backdrop("HoldPreview", _clear_hold_preview)`** — a dimmed, full-screen `Button` behind the enlarged card — so a tap *anywhere* always closes it via Godot's own proven `Button.pressed`, completely independent of whatever happened (or didn't) to the original touch that opened it. Treat that backdrop as the guarantee and everything else (drag-cancels-it, the touch-up path, `_input()`, the timeout) as best-effort layers that make the *original* release feel instant when it does arrive. If you ever touch this again and are tempted to remove the backdrop in favor of "just fix the touch tracking" — don't; that was tried three times this session and none of it held up on-device.
- **Stage pins** — `_add_stage_pin()` overlays `assets/map_pin_rune.png` atop the procedural pin badge, tail, and shadow.
- **Character/monster art and battle backgrounds** — `character-atlas-v3.png` (3x3 grid, `CHAR_KEYS` maps names to cells) via `_get_character_texture()`, and `BATTLE_BACKGROUNDS` (`assets/backgrounds/*.jpg`) for battle backdrops and setup.
- **Quest discoverability and notification dots** — daily/weekly quests only ever lived inside `show_camp()`, and the map's only entry point into it used to be a `"✧%d"` (relic count) text button with no hint that quests, not just relics, were behind it. That button (`btn_camp`/`"CampButton"` in `show_map()`) now uses a drawn `"scroll"` `GameIcon` instead. `_add_notification_dot(anchor, btn_size)` overlays a small red-dot `Panel` (named `"NotificationDot"`) at a button's top-right corner; it is called on that scroll button when `_has_claimable_quest()` is true (any daily/weekly entry with `progress >= target` and not `claimed`), and inline on the dock's deck button when `_has_unused_cards()` is true (an owned card with more copies in `profile.collection` than are placed in `profile.deck`). If you add another place worth flagging this way (new shop stock, an unopened chest, etc.), follow the same "small red dot, named `NotificationDot`, condition function starting with `_has_`" shape so it stays easy to find and test.

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
