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
  kicks in. Opening hand at battle start is strictly 5 cards and opening energy is strictly 2.
  Turn 2 draws the flat 2 cards (e.g. 3 cards remaining on turn 1 -> 5 cards on turn 2).
  Relics and equipment must NEVER blow up hand size on turn 2 (foxCharm grants +1 energy on turn 2;
  windChime triggers when draw pile reshuffles; tideCharm triggers on first shield gained).
- There is no End Turn button: the turn ends itself once nothing left in hand is affordable
  (empty hand or every remaining card costs more than remaining energy) — see
  `_maybe_end_turn()` in `game.gd`. There used to also be a fixed plays-per-turn cap
  (`state.actions`); it was removed so cost, not an arbitrary play count, is the only
  constraint. Swift's rune refunds energy; foxCharm grants 1 extra energy on turn 2.
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
  - **Adding unique chapter art**: All 50 chapters (`chapter_0.png` through `chapter_49.png`, 390x520 PNG) now have dedicated unique backgrounds in `Godot/assets/chapters/` matching the chapter lore and names from `content.gd`. Run `godot --headless --path Godot/ --editor --quit` whenever new images are added to regenerate `.import` metadata.
  - **Road alignment**: `_chapter_waypoints()` looks up `BIOME_PATH_WAYPOINTS[chapter % 6]`, five hand-picked points that trace the painted trail baked into the backgrounds, mirrored (`MAP_WIDTH - x`) when horizontally flipped.
  - There used to be a bottom quick-jump strip of small chapter-preview tiles (tap one to scroll the map to that chapter); it was removed by request. If it comes back, the previous implementation cached each tile's live terrain-wash texture rather than a placeholder swatch.
  - **Terrain dressing**: `_add_terrain_dressing()` adds subtle vector accents with softened alpha (0.2-0.35) so they do not overpower the painted illustrations, while preserving the collision-avoidance checks verified by `ui_smoke.gd`.
- **Card frames and layouts** — Cards across hand (`_card_view`), the enlarged peek (`_big_card_face`), shop (`_shop_card_tile`), and deck (`_deck_card_tile`) all use the same language: full-bleed illustration, then a solid near-opaque rules box from ~52% down (name/type line, then description).
  - **Rarity-specific slender frames**: Card frames now vary distinctly by rarity via `_get_card_frame_texture(rarity: String) -> Texture2D`:
    - `card_frame_starter.png`: Rustic dark forged iron and bronze trim.
    - `card_frame_common.png`: Polished silver and steel beveled trim.
    - `card_frame_uncommon.png`: Luminous jade and mithril filigree trim.
    - `card_frame_rare.png`: Radiant golden baroque filigree trim (`card_frame_golden_border.png` is retained as an alias for backwards compatibility).
    - All 4 frames use a narrower border profile (~7-8% margin instead of ~16%), granting significantly more visible area to the card art and rules text while keeping clean outer isolation.
  - Both `_card_view`'s and `_big_card_face`'s outer container must be a plain `Panel`, not `PanelContainer`. A `Container` force-fits *every* direct child to its own full rect — with the illustration, the anchored info box, and the frame overlay all as direct children, that silently collapsed the whole card into a solid block showing only whichever child was added last, with no error in the log.
  - **Floating badges & icons**: Energy cost badge floats top-left; rarity star row and rune icon float top-right.
  - **Equipment and Rune painted icons**:
    - All 12 equipment pieces (`equip_emberBlade.png`, `equip_moonStaff`, `equip_stoneSpear`, etc.) in `res://assets/icons/` are rendered via `_equip_icon_badge(item, color, diameter)`.
    - All 10 runes (`rune_swift.png`, `rune_chain.png`, `rune_burning.png`, etc.) in `res://assets/icons/` are rendered via `_rune_icon_badge(rune, color, diameter)` in the rune bag, and directly loaded as crisp textured icons on card sockets in `_card_view`, `_big_card_face`, and `_deck_card_tile`.
- **Battle interaction — hold to peek, tap to play.** Tapping a hand card in battle (release within `HandCard.TAP_THRESHOLD_MS`, no drag) plays it directly (or arms targeting, for an attack card with more than one enemy alive); holding it longer just closes an enlarged peek without playing. The peek (`_show_hold_preview`/`_big_card_face`) appears **immediately** on every press — there is deliberately no delay-before-showing to distinguish "might be a hold" first; `HandCard._on_touch_up` decides tap-vs-hold retroactively from `_press_time_ms` instead. An earlier version *did* wait ~200ms before showing the peek, reasoning that the wait itself sat in the window iOS's long-press/haptic-touch gesture recognition watches for; removing that delay was a real improvement but **did not fully fix it** — a long-enough hold's own release can still go missing outright on a real device (not just delayed), independent of anything Godot does before that point, and no combination of `HandCard._on_touch_up`, its raw `_input()` event watcher, or a flat `PREVIEW_MAX_DURATION` timeout closed it reliably by themselves. **The actual fix is `_show_hold_preview` wrapping the peek in `_modal_backdrop("HoldPreview", _clear_hold_preview)`** — a dimmed, full-screen `Button` behind the enlarged card — so a tap *anywhere* always closes it via Godot's own proven `Button.pressed`, completely independent of whatever happened (or didn't) to the original touch that opened it. Treat that backdrop as the guarantee and everything else (drag-cancels-it, the touch-up path, `_input()`, the timeout) as best-effort layers that make the *original* release feel instant when it does arrive. If you ever touch this again and are tempted to remove the backdrop in favor of "just fix the touch tracking" — don't; that was tried three times this session and none of it held up on-device.
- **Stage pins** — `_add_stage_pin()` overlays `assets/map_pin_rune.png` atop the procedural pin badge, tail, and shadow.
- **Character/monster art and battle backgrounds** — `character-atlas-v3.png` (3x3 grid, `CHAR_KEYS` maps names to cells) via `_get_character_texture()`, and `BATTLE_BACKGROUNDS` (`assets/backgrounds/*.jpg`) for battle backdrops and setup.
- **Quest commissions and Hero Camp UI separation** — Daily and weekly quests are separated from `show_camp()` into their own dedicated entrance `show_quests()` (`"ui.quests_title"` / `"ui.quests_sub"`):
  - `QuestButton` (`"QuestButton"` in `show_map()`) links directly to `show_quests()`, rendered with a custom `"quest"` `GameIcon` (parchment scroll with rolled wooden rods and stamped red wax seal) and `assets/icons/quest.png`. It carries `_add_notification_dot()` when `_has_claimable_quest()` is true.
  - `CampButton` (`"CampButton"` in `show_map()`) links to `show_camp()`, rendered with a custom `"profile"` `GameIcon` (hero crest medallion) and `assets/icons/profile.png`. Camp is dedicated to the player account profile, ascension difficulty tiers (A0..A5), and relics collection.
  - Claiming any quest via `_claim_quest()` refreshes `show_quests()` directly.
- **Symphonic audio & dynamic stage combat soundtrack**:
  - `map_symphony.wav`: Grand neoclassical gothic symphony in the style of "The Undead Overture" / "The Dawn" (138 BPM, D Minor) featuring ominous tolling cathedral bells, relentless galloping 16th-note cello/viola ostinatos, soaring tragic yet triumphant violin and brass melodies, sweeping baroque harpsichord arpeggio cascades, choral pad swells, and martial double-kick orchestral percussion.
  - 5 Distinct battle tracks for chapter sub-stages (`_play_music(true, stage_lvl)`):
    - `battle_stage_0.wav` (Level 1: Trailhead): Agile, fast skirmish theme (116 BPM, E Minor) with staccato string ostinatos, woodwind leads, and snappy snare.
    - `battle_stage_1.wav` (Level 2: Crossing): Tactical martial march (122 BPM, G Minor) with driving cellos, marching snare rolls, and bold horn calls.
    - `battle_stage_2.wav` (Level 3: Shrine): Mystical ceremonial combat (106 BPM, C Minor / D Dorian) with ancient bells, solemn brass, and ethereal string pads.
    - `battle_stage_3.wav` (Level 4: Stronghold): Heavy fortress siege (130 BPM, D Minor) with driving war drums, aggressive brass stabs, and urgent 16th-note string ostinatos.
    - `battle_stage_4.wav` (Level 5: Crown / Great Boss): Epic climax boss symphony (140 BPM, B Minor) with thunderous timpani, soaring brass fanfares in octaves, glockenspiel, and sweeping choral sweeps.

- **Combat ergonomics & visual juice (Phase 1, 2, 3 enhancements)**:
  - **Battle Speed Toggle**: 1x / 1.5x / 2x cycling capsule button in battle HUD (`SpeedToggle`). Paced delays and animations scale via `_battle_delay(seconds)`. Persists to `profile.battle_speed`.
  - **Manual Pass / End Turn Button**: `PassTurnBtn` in combat status row allows voluntarily ending turn with unspent cards.
  - **Haptic Feedback Hierarchy**: Centralized `_haptic(type)` with 4 tiers (`tap`, `shield`, `hit`, `heavy`).
  - **Interactive Keyword Glossary Tooltips**: Scanning card mechanics in `_big_card_face` generates tappable keyword pills displaying bilingual rules explanations.
  - **Campfire Rest Site Rituals (`show_event` for `rest`)**:
    - `rest_heal`: Restore 20 HP.
    - `rest_purify`: Purify Altar (`show_deck_purge`) — banish a basic starter card and transform it into an elite spirit card (`foxfire`, `mirrorWard`, or `wildSpark`) while keeping the 25-card deck invariant.
    - `rest_smith`: Spirit Smith (`show_deck_upgrade`) — permanently upgrade a selected card to `+1`.
  - **Shop Oblivion Service (`ShopPurgeBtn`)**: Card removal service available for ◆50 gold in town.
  - **Holographic Card Foil Shader (`assets/shaders/card_foil.gdshader`)**: Real-time GLSL CanvasItem shader rendering iridescent sweeping rainbow foil reflection across Rare and Upgraded (`+1`) cards.
  - **3 Hero Archetypes / Classes (`content.HERO_CLASSES`)**:
    - **Fox Spirit Master (灵狐行者 / `fox_spirit`)**: Agile fire/gale caster with `foxCharm` and `foxfire` combos.
    - **Stone Sentinel (岩铠卫士 / `stone_sentinel`)**: Immovable fortress with `ancientSeed`, heavy armor, and `stoneBreaker` shield conversion.
    - **Shadow Stalker (夜影刺客 / `shadow_stalker`)**: Lethal critical assassin with `starShard`, `moonfang`, and `cinderHex`.
    - All 3 class starting decks strictly follow the 25-card, all 1-cost balance rule.
    - Selecting a hero class in Camp updates the traveler map avatar and loadout.
  - **Endless Abyss Mode (`show_abyss` / `begin_abyss_battle`)**: Infinite gauntlet where enemies and gold rewards scale by floor (`content.abyss_encounter(floor)`). Tracks `profile.abyss_floor` and `profile.abyss_record`.

- **Deckbuilding depth: rune resonance, curse cards, high-stakes boss relics**:
  - **Rune Resonance (`content.RUNE_SETS` / `content.active_rune_sets()`)**: socketing both
    runes of a pair (`swift`+`cycle` = Gale, `burning`+`execute` = Flame, `guardian`+`siphon`
    = Stone) anywhere in the deck activates that set for the whole battle. Flame adds +3
    damage to a hit landing on an already-burning target (`_resolve_effects`'s damage
    branch, per target so cleave can partially trigger it); Gale refunds 1 energy on the
    first cycle-rune or draw-effect card played each turn (`state.gale_used`, reset in
    `end_turn()` — it was NOT being reset before this milestone, so the bonus only ever
    fired once per whole battle); Stone has a 25% chance per shield gain to boost it 50%.
    The rune loadout tab shows all 3 sets with an active/inactive badge.
  - **Curse cards (`decay_blight`, `void_curse`)** are purely battle-scoped — an enemy's
    "curse" intent adds one to `state.discard`, and neither ever touches `profile.deck`, so
    they simply vanish when the battle ends either way (no Purify Altar/Shop Purge
    interaction needed or implemented). `void_curse` (cost 99, already unplayable) deals 2
    damage the instant it is drawn and auto-exhausts at end of turn; `decay_blight` deals 3
    damage every turn it survives in hand and deliberately does **not** clear itself —
    playing it for its own `exhaust:true` is the intended way to get rid of it. Both have an
    empty `effects` array, so `_card_color`/`_card_description` special-case
    `card.kind == "Curse"` rather than trying to synthesize a description from effects that
    don't exist.
  - **High-stakes boss relics (`SpiritContent.BOSS_RELIC_IDS`: `cursedTome`, `titanBell`,
    `chaosPrism`)** are exclusive to Great Boss kills — `_grant_stage_rewards()` draws a
    regular `boss`'s relic from `RELICS` minus this list, and a `greatboss`'s relic only
    from it. `cursedTome` (+1 draw, -2 HP every turn including turn 1) and `titanBell`
    (+20 max HP/+20 HP/+15 shield at battle start, and its "-1 energy cap every 2 turns" is
    implemented as *cancelling* the normal growth rather than actually going negative — energy
    just stays flat at the opening 2 all fight) both apply from turn 1, matching how
    `chaosPrism`'s own battle-start effect (+6 enemy shield) already worked; `chaosPrism`
    also stacks 1 Vulnerable on any attack that lands real damage (not fully shielded).
  - **A missing function is a silent, permanent hang here, not a crash.** `combat.gd` called
    `_has_draw_effect()` (for Gale Resonance) before that function existed anywhere in the
    script. GDScript's compile failure doesn't make Godot's headless script runner exit —
    it just sits there consuming ~0% CPU indefinitely. Several `test_runner.gd`/
    `ui_smoke.gd` processes were stuck for hours before this was caught; `ps aux | grep
    godot` and killing anything idle for more than a minute or two is the fix, not waiting
    longer. If a headless test run seems to hang rather than finish in a few seconds,
    suspect a compile error in a script it depends on before suspecting an infinite loop in
    test logic.

## Handoff & verification notes for future agents

- **Verifying changes**:
  ```bash
  godot --headless --path Godot/ --script res://tests/test_runner.gd   # rules (164 checks)
  godot --headless --path Godot/ --script res://tests/ui_smoke.gd      # screens + combat turn
  ```
  Both must pass without failures before committing.
- **Deploying to iOS**:
  Run `./deploy_ios.sh --full-export` with the iPhone unlocked and connected. If the screen is locked, `devicectl` reports `unavailable`.
- **Importing newly added images**:
  Always run `godot --headless --path Godot/ --editor --quit` after adding `.png` or `.jpg` assets to generate `.import` metadata before testing or packaging.
