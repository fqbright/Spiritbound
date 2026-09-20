# Working on Spiritbound

A portrait mobile card-battler in Godot 4.7.2. Read this before changing anything.

## Where things are

| Path | What it is |
| --- | --- |
| `Godot/scripts/combat.gd` | Rules engine. Cards, intents, relics, statuses. **No UI.** |
| `Godot/scripts/game.gd` | `SpiritGame`, the script attached to `Main.tscn`. Core state (`profile`, `combat`, `lang`, ...), lifecycle (`_init`/`_ready`/`_input`/`_clear`), generic UI primitives (`_button`/`_label`/`_panel`/`_header`/...), shared asset/texture loaders, quest/login-reward period-reset logic, the shared card-display helpers (`_card_color`/`_card_description`/...), the Settings screen, and a handful of small map-pin/replay functions — genuinely cross-cutting code with no single screen owner. Every screen itself lives in one of the composed classes below; `game.gd` holds a one-line delegator under each screen function's original name (e.g. `func show_map() -> void: _map_screen.show_map()`) so nothing outside `game.gd` (tests included) needed to change when the split happened. |
| `Godot/scripts/game_map_screen.gd` | `MapScreen` — the world map, chapter/waypoint rendering, terrain dressing, stage pins, the today-digest banner, travel animation. |
| `Godot/scripts/game_battle_screen.gd` | `BattleScreen` — the battle screen itself, hand/card rendering (including the enlarged peek and targeting/damage-preview), combat animation, the first-battle tutorial. |
| `Godot/scripts/game_rewards_screen.gd` | `RewardsScreen` — reward granting, the reward-details/chest-opening screens, Compendium discovery bookkeeping, hero mastery XP, the rest/merchant/event stage flow. |
| `Godot/scripts/game_shop_deck_screen.gd` | `ShopDeckScreen` — the shop, deck-purge/upgrade rituals, deck builder + auto-build scoring, equipment/rune loadout tabs. |
| `Godot/scripts/game_camp_screen.gd` | `CampScreen` — the Compendium catalog tabs, Camp (hero archetypes, difficulty tiers, relics), Quests, and the Daily Trial/Weekly Challenge/Abyss/Draft Arena/Boss Rush/Phantom Arena/Sandbox entry points. |
| `Godot/scripts/game_icon.gd`, `game_intent_icon.gd`, `game_hand_card.gd`, `game_touch_scroll_container.gd`, `game_dizzy_stars.gd` | Self-contained UI classes (`class_name`, globally resolvable) that used to be nested inside `game.gd`. `HandCard` already took its game-instance back-reference as a plain field before the split; the other four never touch outer state at all. |
| `Godot/scripts/content.gd` | Card/equipment/rune/relic data and all UI strings. |
| `Godot/scripts/save_store.gd` | Local profile, versioned for a future cloud sync. |
| `Godot/data/core.json` | Card definitions and balance numbers. |
| `Godot/tests/test_runner.gd` | Rules-engine regression suite. |
| `Godot/tests/ui_smoke.gd` | Headless walk over every screen and a full combat turn. |
| `Godot/tests/balance_probe.gd` | 250-stage balance trajectory bot — drives the real `game.gd` reward/deck-building pipeline (not a duplicated formula) through a full campaign run, with a diligent farming loop (free rest/event upgrades, rune-set socketing, one shop buy per chapter) layered on top, and fails CI if the four-band curve regresses below a measured floor (see `Docs/ARCHITECTURE.md`). `--gold`/`./run_tests.sh --balance-gold` reruns the same trajectory gold-constrained instead of topped-up, as a diagnostic (not yet gated) read on whether the economy, not just combat, stays beatable. |
| `Godot/addons/gut/` | Vendored [GUT](https://github.com/bitwes/Gut) (Godot Unit Test) framework, v9.4.0. Third-party code — don't hand-edit; re-vendor from upstream instead. |
| `Godot/tests/gut/test_*.gd` | GUT-based tests (`extends GutTest`, `assert_*` methods) — the newer, framework-backed alternative to this repo's older hand-rolled `check()`-style suites above. New test files here are auto-discovered by filename (`test_*.gd`), no registration needed. |
| `Godot/tools/generate_monsters.gd` | Offline, one-time art-generation tool — composited the 125 monster portraits under `Godot/assets/characters/monsters/` from base creature art (sourced from the otherwise-abandoned `Expo/assets/` prototype images below), elemental grading, biome backgrounds, VFX overlays, and tier frames. Not part of any test run; re-run by hand only if the monster set itself needs regenerating. |
| `Sources/`, `App/`, `Tests/`, `Expo/` | Abandoned Swift and React Native prototypes. Ignore them — except as one-time raw art source material for `Godot/tools/generate_monsters.gd` above, which is the only thing in this repo that still reads from `Expo/`. |
| `Docs/ARCHITECTURE.md` | Why the code is shaped this way. Read it before a structural change. |
| `Docs/GROWTH_ROADMAP.md` | Retention/growth feature backlog, ordered by impact. Check this for what's in progress before starting new feature work. |

## Verifying a change

Every agent working on this repository **MUST** run the automated verification suite before submitting any commit:

```bash
./run_tests.sh                 # Core suites: test_runner + ui_smoke + e2e_playthrough + balance_probe + gut
./run_tests.sh --all           # All 8 suites: core + chaos monkey + leak profiler + pixel-diff
./run_tests.sh --monkey        # Chaos Monkey stress tests (500+ random taps & invalid plays)
./run_tests.sh --leaks         # Memory & ObjectDB leak profiler (zero unbounded leaks)
./run_tests.sh --diff          # Recaptures the 7 screens and diffs them against baseline
./run_tests.sh --balance       # 250-stage balance trajectory bot (full, byte-reproducible)
./run_tests.sh --balance-quick # Same bot, retry-capped (~1s) — the CI-friendly form
./run_tests.sh --gut           # GUT suite alone (tests/gut/test_*.gd)
./run_tests.sh --snapshots     # Generates/refreshes 390x844 mobile screenshots (no diff/gate)
./run_tests.sh --refresh-baselines  # Recaptures and promotes to Pixel-Diff's committed baselines
```
`--diff` and `--refresh-baselines` need a real rendering driver (`get_image()` returns null
under `--headless`'s dummy renderer), so unlike every other suite here they run without
`--headless`, against whatever `DISPLAY` is already set — a real desktop session locally, or
Xvfb's virtual one in CI (see `.github/workflows/ci.yml`). Locally without a display: `xvfb-run
-a --server-args="-screen 0 400x900x24" ./run_tests.sh --diff`. **The Xvfb screen must be at
least as tall as the game's 390x844 portrait viewport** — see the Traps section below for what
a shorter one does.

Individual suite commands:
```bash
godot --headless --path Godot/ --script res://tests/test_runner.gd      # rules & balance regression (655 checks)
godot --headless --path Godot/ --script res://tests/ui_smoke.gd         # screens + unblocked clickability + battle turn
godot --headless --path Godot/ --script res://tests/e2e_playthrough.gd  # full multi-stage campaign playthrough bot
godot --headless --path Godot/ --script res://tests/balance_probe.gd    # 250-stage balance trajectory bot
godot --headless --path Godot/ -s addons/gut/gut_cmdln.gd -- -gdir=res://tests/gut -gexit  # GUT suite
godot --headless --path Godot/ --script res://tests/chaos_monkey.gd     # chaos monkey stress test
godot --headless --path Godot/ --script res://tests/leak_checker.gd     # memory and object leak profiler
godot --path Godot/ --rendering-driver opengl3 -s tests/visual_snapshots.gd # capture the 7 current screens (needs a real/Xvfb display)
godot --headless --path Godot/ --script res://tests/pixel_diff_test.gd  # diff those against Godot/tests/snapshots/baselines/
```

**Adding a new GUT test**: create `Godot/tests/gut/test_<name>.gd` with `extends GutTest`, one
`func test_<description>():` per case, using GUT's `assert_eq`/`assert_true`/`assert_not_null`/etc.
No registration step needed — `-gdir=res://tests/gut` auto-discovers every `test_*.gd` file there.
After adding the file, run `godot --headless --path Godot/ --import` once so Godot's class cache
picks up the new script before running it (see the CI trap above for why this matters).

All suites must pass with **0 failures**. GitHub CI (`.github/workflows/ci.yml`) runs `./run_tests.sh --all` (all 8 suites) on every push/PR to `main`, wrapped in `xvfb-run` (installed as its own CI step) so the Pixel-Diff suite's screen capture has a display to render into, after an explicit `godot --headless --path Godot/ --import` step (see the CI trap above — skip that step and every suite fails before running a single check) — the extra suites beyond core cost well under two minutes combined, so there's no reason CI should run less than everything.

**Visual regression is a real, automated gate, not just manual inspection.** The Pixel-Diff
suite (step 8 of `--all`) recaptures all 7 core screens and diffs each against a committed
baseline in `Godot/tests/snapshots/baselines/`, using perceptual color-tolerance + morphological
clustering (ignores anti-aliasing/font-hinting jitter, catches real layout/content changes) —
see `Godot/tests/pixel_diff_test.gd`. This used to be dead weight: the suite's own diffing logic
and the committed baselines were both real, but nothing ever generated a *current* snapshot in
CI (`--snapshots` wasn't part of `--all`, and needs a real rendering driver `--headless` can't
provide), so every screen silently skipped on every run, forever. Fixed by folding capture into
the diff suite itself and running the whole thing under Xvfb in CI — see git history around
2026-09-19 for the measured per-screen noise floor (run-to-run variance with zero real changes)
that the per-screen thresholds in `pixel_diff_test.gd` are set against; if a threshold ever looks
suspiciously tight against a fresh noise-floor measurement, loosen it rather than let the gate
flake, the same lesson `balance_probe.gd`'s CI-vs-full retry split and this file's own flaky-test
traps below already teach for other suites.

**If a UI change is intentional, refresh the baselines it affects**: `./run_tests.sh
--refresh-baselines`, then `godot --headless --path Godot/ --import`, then confirm `--diff`
passes, then review and commit the changed `Godot/tests/snapshots/baselines/*.png` yourself —
this step trusts that today's capture is correct, it does not check that for you. If `--diff`
fails and you *didn't* mean to change that screen, don't refresh — read the saved diff image
under `Godot/tests/snapshots/diffs/` first; that's the whole point of the gate.

**Visual Verification Without Physical iPhone**:
Run `./run_tests.sh --snapshots` to generate pixel-accurate 390x844 mobile frames in `Godot/tests/snapshots/` (`01_map_screen.png`, `02_battle_screen.png`, `03_rewards_screen.png`, `04_shop_screen.png`, `05_deck_screen.png`, `06_camp_screen.png`, `07_treasury_inspector.png`) for eyeballing without gating on baseline diff. Inspect these images to verify mobile UI layout, text truncation, and layer alignment without needing a physical phone attached.

**The iOS Simulator cannot run this project.** The official Godot 4.7.2 iOS export
templates ship a simulator library containing only an x86_64 slice, so there is nothing
to link against on Apple Silicon, and current iOS simulator runtimes no longer execute
x86_64 apps. Device deploy is `./deploy_ios.sh` with an iPhone connected. If no device is
attached, use `./run_tests.sh --snapshots` to inspect the rendered mobile frames.

## Rules for All Agents

1. **EVERY NEW FEATURE MUST HAVE CORRESPONDING TESTS (MANDATORY)**:
   - **Combat rules, balance, cards, relics, currencies, economy**: MUST add test assertions in `Godot/tests/test_runner.gd`.
   - **Difficulty-curve changes (the four bands in `content.gd`'s `_chapter_factor`, encounter health/damage scaling, the always-full-HP `begin_battle()` contract)**: MUST re-run `./run_tests.sh --balance` and either keep the guardrails green or update `Docs/ARCHITECTURE.md`'s "250-stage difficulty curve" section with the new measured numbers. Do not change those constants and trust the old curve description.
   - **Screens, buttons, modals, input handlers, navigation**: MUST add UI walk and clickability assertions in `Godot/tests/ui_smoke.gd`.
   - **Campaign flows, multi-stage transitions, rewards, shop buying**: MUST ensure `Godot/tests/e2e_playthrough.gd` exercises the flow without softlocks.
   - **NEVER** merge or push a new feature without adding automated test coverage for it.
2. **`combat.gd` never references a node, scene or `Control`.** That boundary is what makes
   the headless suites possible. Keep game rules out of `game.gd` too where you can.
3. **Every user-facing string goes in `UI_TEXT` in `content.gd` with both `zh-Hans` and
   `en`.** Never hardcode text in `game.gd`.
4. **Do not commit `Godot/.godot/` or the loose current screenshots directly under
   `Godot/tests/snapshots/*.png`** — those are regenerated by every `--diff`/`--snapshots`/
   `--refresh-baselines` run and gitignored. **Do** commit `Godot/tests/snapshots/baselines/*.png`
   when you deliberately refresh them (see "Visual regression is a real, automated gate" above) —
   those are the committed reference the Pixel-Diff suite gates every CI run against, not
   scratch output.
5. **Always run `./run_tests.sh` before committing.** A commit with failing checks will be rejected by git hooks and GitHub CI.
6. **Always consult and leverage the workspace skills in `.agents/skills/`**:
   - Modifying UI, GDScript, or screen layouts: Consult `.agents/skills/godot-game-dev/SKILL.md`.
   - Deploying to physical iOS or debugging devicectl: Consult `.agents/skills/ios-device-deploy/SKILL.md`.
   - Designing/tuning cards, relics, energy curves, or build scores: Consult `.agents/skills/spiritbound-balance-design/SKILL.md`.

## Traps that have already cost time here

Every one of these produced a wrong screen with no error in the log. They are the reason
`ui_smoke.gd` exists.

- **The screen split is composition, not inheritance — and every new cross-screen call
  needs a `g.` prefix, not a bare reference.** `game.gd` used to be one ~7200-line file;
  it's now `SpiritGame` plus five composed screen classes (`MapScreen`/`BattleScreen`/
  `RewardsScreen`/`ShopDeckScreen`/`CampScreen`, one per `game_*_screen.gd` file), each
  holding a `var g: SpiritGame` back-reference set in `_init()`. This is composition and
  not inheritance because it has to be: GDScript cannot statically resolve a parent script
  calling a method defined only in a child (verified experimentally during the split), and
  the screens call each other circularly (`show_map` → `show_camp` → `show_quests` →
  `show_map`, etc.), so no valid inheritance order exists. Practical fallout: (1) any
  function moved into one of these files must reach shared state or another screen's
  function through `g.` — a bare reference silently resolves to the wrong thing or fails
  to compile; (2) a bare `self` inside a moved method refers to the composition object, not
  the game instance — this bit `_card_view` assigning `tile.game = self` when it should be
  `tile.game = g`; (3) a delegator wrapping a function that `await`s internally must also
  `await` the call-through (`func show_map() -> void: await _map_screen.show_map()`), or
  the delegator returns before the real work finishes and every awaiting caller races
  ahead; (4) the four composition objects are built in `_init()`, not `_ready()`, because
  `test_runner.gd` instantiates `Main.tscn`'s script directly without adding it to a tree
  to test pure functions in isolation, and `_ready()` never fires for a node that never
  joins a tree. `game.gd` keeps one thin delegator per screen function under its original
  name specifically so nothing outside these files — including every test — had to change
  when a function moved; if you add a new screen function that something outside its own
  file calls (grep for it in the *other* `game_*.gd` files and in both test files, not just
  `game.gd`, before assuming it's safe to skip), add its delegator the same way.
- **GDScript warnings are errors.** `var x := some_dict.get(k)` fails the build, because
  `Dictionary.get()` returns `Variant`. Annotate the type: `var x: String = ...`.
- **Containers resize their children.** A `ColorRect` inside a `PanelContainer` is stretched
  to fill it every frame — that is why a health bar never moved. Use `ProgressBar` for bars,
  and parent manually-sized nodes to a plain `Control` or `Panel`.
- **Decorative children swallow input.** `PanelContainer` and `Panel` default to
  `MOUSE_FILTER_STOP`, so a panel over card art eats the tap. Set `MOUSE_FILTER_IGNORE` on
  anything decorative.
- **`z_index` beats tree order — but only for drawing.** A node added later still draws
  underneath a sibling with a higher `z_index` (map pins are 10, the traveller 25, floating
  bars 100, toasts 500) — but **GUI input dispatch never consults z_index at all**; it
  follows scene-tree sibling order exclusively (confirmed against Godot's own documented
  behavior — a commonly-hit engine gotcha, not something specific to this project). This bit
  `_modal_dialog()` and `_modal_backdrop()` directly: `_clear()` adds `overlay` to `root`
  first, before that screen's own page content exists yet, so every screen's content ends up
  *later* in `root`'s children and silently won every tap over whatever `overlay` held —
  Settings, the stage-replay prompt, and the deck-import modal were all genuinely
  un-clickable on a real device despite drawing correctly on top, and every headless check
  passed anyway because none of them simulate real touch dispatch (a `.pressed.emit()` call
  invokes the handler directly, bypassing hit-testing entirely). The fix — now the first line
  of both functions — is `root.move_child(overlay, root.get_child_count() - 1)`, run every
  time a modal opens, so tree order actually matches the z-index-driven visual order. Any new
  code that adds interactive content to `overlay` outside those two helpers needs the same
  line; `ui_smoke.gd`'s occlusion checker (`find_occlusion`/`_wins_input_over`) deliberately
  ignores z_index for exactly this reason — an earlier version compared z_index first and
  reported every modal button as unoccluded, missing this bug entirely.
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
- **A new `in_<mode>` battle-exclusivity flag needs a branch in `_leave_battle()`, not just the
  win path.** `game.gd` has one `in_X` boolean per side mode (Sandbox, Daily Trial, Weekly
  Challenge, Draft Arena, Boss Rush, Abyss, Phantom Arena) so `_grant_stage_rewards()` can route
  a win to that mode's own reward logic instead of the campaign's. It is easy to wire up the win
  path and forget the loss/retreat one: `_leave_battle()` needs its own explicit branch clearing
  the same flag, or a loss leaves it stuck `true` for the rest of the session — nothing crashes
  or logs when this happens. From then on every later battle (any mode, campaign included)
  silently misroutes through that mode's reward branch in `_grant_stage_rewards()`; for Draft
  Arena specifically it's worse, because `begin_battle()`'s `battle_deck` check reads
  `g.in_draft_battle` unconditionally, so every later battle also gets built from the stale
  draft deck instead of the real 25-card one. Both `in_draft_battle` and `in_weekly_challenge`
  shipped with exactly this gap — found only by reading `_leave_battle()` end to end and
  noticing which flags it didn't mention among the ones it did. `ui_smoke.gd` now forces a loss
  for every mode (`game.combat.state.phase = "lost"; game._leave_battle()`) and checks the flag
  actually clears; copy that shape for the next new mode instead of trusting the win path alone.
- **A fire-and-forget coroutine's tail runs even after the state it started with is gone.**
  `_attempt_play_card()` calls `_resolve_play()` without `await` (so the caller returns
  immediately while the animation plays out) — a pattern used throughout the battle screen. If
  the player leaves battle (`_leave_battle()`, a loss or a manual retreat) while that coroutine
  is still suspended mid-animation, Godot resumes it anyway once its timer/tween fires,
  regardless of what else has happened meanwhile — there is no implicit cancellation. Its tail
  used to call `show_battle()` unconditionally, which wipes whatever screen is *currently*
  showing, so a moment after the player navigated away the old battle screen would silently
  reappear over the map. `g.resolving` (every play-a-card check's busy guard) had the same
  problem: it was only ever cleared from inside that same tail, so a coroutine that never
  reached it left card-play blocked for the rest of the session, exactly the "stuck flag"
  shape above just for a boolean instead of an `in_<mode>` var. Fixed with `g.battle_session`,
  a counter bumped by both `begin_battle()` and `_leave_battle()`: `_resolve_play()` captures it
  synchronously at entry (before its first `await`, while it's still guaranteed correct) and
  checks it again right before the one call in its tail that touches the screen, bailing out if
  the session has moved on — and both bump sites also reset `g.resolving` directly rather than
  trusting the coroutine to get there. Any new fire-and-forget coroutine that survives past a
  point where the player could plausibly navigate away needs the same kind of check before it
  touches shared screen state, not just a `is_instance_valid()` guard on the nodes it animates
  (that prevents a crash; it does not prevent the tail from acting on stale state). The exact
  same shape turned up independently in `_travel_to()` (`game_map_screen.gd`): tapping a distant
  stage pin starts a fixed 2-second (or, across a chapter crossing, longer) hop animation with
  no input lock, so tapping Camp/Quests/another pin mid-hop used to leave the interrupted
  coroutine to call `show_event()`/`begin_battle()` on whatever screen the player had already
  moved to. Rather than a second bespoke counter, this one uses `g.screen_generation` — bumped
  by `_clear()` itself, the one shared choke point every screen transition already goes through
  — as a general-purpose version of the same cancellation-token pattern `battle_session` uses
  for battle specifically. One trap in reusing it: a branch that itself calls a function
  starting with its own `_clear()` (e.g. `show_chapter_transition()`) must not capture the
  generation *before* that call — its own clear already bumps the counter, so a value captured
  first is stale before the real wait even begins. `show_chapter_transition()`'s branch is left
  unguarded by `screen_generation` for exactly this reason; it already has its own equivalent
  protection (`is_instance_valid()` checks on its own transition nodes), which doesn't have this
  problem because it's inside the same function as the `_clear()` call, not outside it.
- **CI had been failing on every single push for this project's entire history, and nobody had
  looked.** Every headless test script references global `class_name` types (`SpiritContent`,
  `SpiritCombat`, `SpiritGame`, `SpiritSave`, and — once GUT was added — `GutTest`). Godot only
  resolves those from a generated cache under `Godot/.godot/`, which is gitignored and so never
  exists on a fresh checkout. `.github/workflows/ci.yml` checked out the repo, installed Godot,
  and went straight to `./run_tests.sh` with no import step in between — so `godot --headless -s
  tests/test_runner.gd` failed immediately with a wall of "Identifier ... not declared in the
  current scope" parse errors, before a single `check()` call ever ran, on every run, for the
  life of the project (confirmed against this repo's own Actions history — every run failed in
  ~10 seconds, far too fast to have reached the test suite at all). This is exactly why AGENTS.md
  already told agents to run `godot --headless --path Godot/ --editor --quit` after adding
  images: that command also happens to populate this same cache, so any agent who ran the full
  verification loop locally first (as instructed) never saw the failure — only a from-scratch CI
  checkout, which no one was actually reading the logs of, ever hit it. Fixed with a dedicated
  `godot --headless --path Godot/ --import` step (the purpose-built headless equivalent — "starts
  the editor, waits for any resources to be imported, then quits," no display needed) added to
  `ci.yml` before the test-suite step. Verified by reproducing the exact failure locally first
  (delete `Godot/.godot/` entirely, confirm the same parse errors appear character-for-character),
  then confirming the fix resolves it before pushing — the same revert-and-reconfirm discipline
  this file already asks for elsewhere, applied to CI infrastructure instead of game code. If you
  ever see this exact error shape in a fresh environment (a new sandbox, a new CI runner, a
  teammate's first clone), this is almost certainly why — run the import step, not `--editor`
  interactively, and don't assume "it works on my machine" means CI will agree, since your
  machine already has a warm cache from every previous run you've done.
- **An undersized Xvfb virtual screen produces a real-looking layout bug that isn't one.**
  While wiring the Pixel-Diff suite's screen capture into CI, an early attempt used `xvfb-run
  --server-args="-screen 0 640x480x24"` — wider than the game's 390x844 portrait viewport, but
  shorter. The resulting map-screen capture showed the bottom nav dock floating in the vertical
  middle of the screen instead of docked at the bottom, which looked exactly like the kind of
  anchor bug this file's own "Anchor presets resolve against the minimum size at call time" trap
  describes — except the dock's anchoring code was already correct (verified by finding it
  renders at the right position, stably, across 80 frames under `--headless`'s dummy driver).
  The actual cause: the dock's `anchor_top`/`anchor_bottom` math resolves against whatever height
  the real window *is*, not the game's configured resolution, and an X11 window capped at 480px
  tall is not 844px tall no matter what the project settings say. Re-running with a screen at
  least as tall as the viewport (400x900 was used) fixed it immediately, no code changes needed.
  If a snapshot/screenshot capture under a fresh Xvfb setup ever shows a bottom- or edge-anchored
  element in the wrong place, check the virtual screen's dimensions before touching any layout
  code — the same way the CI-cache trap above says to suspect the cache before suspecting new
  test logic.
- **A screen that's non-deterministic in content, not just in a few noisy pixels, can eat an
  entire visual-diff threshold on its own.** Validating the Pixel-Diff suite's new Xvfb capture
  pipeline meant comparing two independent back-to-back captures of the same 7 screens with
  nothing else changed — the run-to-run noise floor a real threshold has to sit above. Six
  screens landed under 0.1%; the battle screen landed at 2.25%, against a 2.5% threshold, because
  `begin_battle()`'s draw shuffle (and occasionally its flavor modifier) is seeded from wall-clock
  time — see this file's own note on that seed elsewhere — so the captured hand (and sometimes
  the enemy count) genuinely differed every single capture, not just by a few anti-aliased
  pixels. `pixel_diff_test.gd`'s color-tolerance-plus-clustering de-noiser is built to absorb
  rendering jitter; it has no way to absorb "this is a legitimately different screen." Fixed in
  `visual_snapshots.gd` by forcing a fixed hand and enemy count right after `begin_battle(0)` and
  re-rendering, the same "poke combat state directly for determinism" pattern already used
  elsewhere (see `ui_smoke.gd`'s finishing-blow banner test) — not by loosening the threshold,
  which would have shipped a gate one unlucky roll away from flaking on an unrelated PR. Both
  fixes predate `SpiritGame.test_seed_override`/`_battle_seed()` (added right after, once it was
  clear this was the second bug from the same root cause in one session — see the next entry)
  and were left as-is rather than retrofitted: they force an exact scenario (a specific enemy
  count, revive disabled) that a fixed seed alone wouldn't guarantee without also solving for
  which seed value avoids every non-determinism source, which is a real but different property
  than "reproducible." A **new** test that just needs the whole battle reproducible — not a
  specific forced scenario — should set `test_seed_override` before calling any `begin_*_battle()`
  function instead of reinventing either of these two patches.
- **The same wall-clock-seed idiom above wasn't unique to `begin_battle()` — it was
  independently copy-pasted into 6 more battle-launch functions**, all in `game_camp_screen.gd`:
  `begin_boss_rush_battle`, `begin_curse_run_battle`, `begin_sandbox_battle`,
  `begin_abyss_battle`, `begin_world_event_battle`, `begin_phantom_arena` (`begin_daily_trial`/
  `begin_weekly_challenge` are fine — they seed from `day`/`week * 1000 + stage`, not wall-clock
  milliseconds, so they're already reproducible within the same day/week). `begin_abyss_battle`
  even feeds its seed into the same `_modifier()` whose "swarm"/"rebirth" rolls caused the two
  bugs above, meaning the identical flake was one GUT test or snapshot away from being
  rediscovered from scratch for Abyss, Boss Rush, Sandbox, or either arena. Deduplicated into one
  `SpiritGame._battle_seed()` (`game.gd`), which all 7 sites now call instead of inlining
  `Time.get_unix_time_from_system()` themselves, plus `test_seed_override` (default `-1`,
  meaning "disabled" — real gameplay is unaffected) so any current or future test can make any of
  these 7 modes' shuffle, flavor modifier, and enemy count fully reproducible with one line set
  before calling the relevant `begin_*_battle()`, instead of discovering the same non-determinism
  the hard way per mode. Covered by `tests/gut/test_battle_seed_override.gd`.
- **The same wall-clock idiom had a slower-motion twin: `int(Time.get_unix_time_from_system()) /
  DAY_SECONDS`, independently inlined at 6 call sites** (`game.gd`'s `_ensure_daily_trial_current`,
  `_ensure_phantom_arena_current`, `fast_idle_harvest`, and its idle-harvest-modal builder;
  `game_shop_deck_screen.gd`'s `_shop_period`/`_shop_reset_at`). Unlike the per-battle millisecond
  seed above, this one doesn't flake between two captures taken moments apart — it only changes
  once the real calendar day rolls over — so it survived the entire Xvfb/Pixel-Diff validation
  effort undetected and only surfaced when the sandbox's real clock actually crossed a day
  boundary mid-session: the shop screen's baseline (`04_shop_screen.png`, driven by
  `roll_shop_stock(day, ...)`) suddenly failed Pixel-Diff at 9%+ diff with no code change at all,
  because its rotating stock/sale/rune/relic had rolled to the new day. Same root cause and same
  fix shape as the battle seed: deduplicated into one `SpiritGame._current_day()`, all 6 sites now
  call instead of inlining the formula, plus `test_day_override` (default `-1`, same "disabled"
  convention) so a test can pin "today" the same way `test_seed_override` pins a battle's seed.
  `visual_snapshots.gd` sets `test_day_override = 20000` once, globally, before any of the 7
  screens are captured — cheap insurance since only the shop screen actually reads it, but nothing
  stops a future capturable screen from reading `_current_day()` too. If a Pixel-Diff baseline ever
  fails with no corresponding code change, check whether the real calendar day moved since that
  baseline was captured before assuming a real regression — this is the second time in one session
  wall-clock content has silently eaten a visual-diff threshold from underneath a passing baseline,
  just on a different clock granularity than the first.
- **A "backfill if this field is entirely missing" migration guard stops protecting you the
  moment the table it backfills from grows a new entry.** `save_store.gd`'s migration for
  `feature_unlocks_seen` (an array of `SpiritContent.FEATURE_UNLOCKS` ids already marked "seen"
  so `game._check_feature_unlocks()` doesn't re-toast something a player unlocked ages ago)
  originally only ran its backfill loop `if not parsed.has("feature_unlocks_seen")` — correct
  for a save from before the field existed, but silent for a save that already had the field
  from an earlier version of the game once `FEATURE_UNLOCKS` itself grew new entries (exactly
  what happened when per-tier difficulty-unlock entries were added). An existing player already
  well past a new entry's threshold would have gotten that entry's toast fired for real on their
  very next qualifying action, having never been backfilled, since the field-presence check had
  already been satisfied by the OLD version's entries. Fixed by making the backfill loop run
  unconditionally on every load instead — idempotent (an id already in the array is skipped), so
  there's no cost to always checking every current `FEATURE_UNLOCKS` entry against the loaded
  profile's stats rather than only reasoning about "was this field missing." Any future table
  with the same shape (a persisted "already seen/claimed/granted" id list checked against a
  growable data table) needs backfill logic that survives the table growing, not just logic that
  survives the field being absent — check the whole table on every load, not just once.

## Game rules worth knowing before touching balance

- Energy opens at 2 and climbs by 1 every two turns (turns 1-2 -> 2, 3-4 -> 3, 5-6 -> 4, ...;
  see `end_turn()` in `combat.gd`: `state.energy = 2 + int((state.turn - 1) / 2)`), not a flat
  per-turn amount — a long fight gradually loosens up instead of staying exactly as tight on
  turn 20 as turn 1. No cap on the number of cards played — energy alone gates plays. Card
  costs run 1/2/3 (18/19/3 cards respectively) so energy is a real constraint on a built-out
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
- The turn auto-hands-over once nothing left in hand is affordable (empty hand or every
  remaining card costs more than remaining energy) — see `_maybe_end_turn()` in
  `game_battle_screen.gd`. A **manual Pass button also exists** (`PassTurnBtn`, calling
  `_pass_turn()`) for voluntarily ending a turn while holding unspent cards. There used to
  also be a fixed plays-per-turn cap (`state.actions`); it was removed so cost, not an
  arbitrary play count, is the only constraint. Swift's rune refunds energy; foxCharm grants
  1 extra energy on turn 2.
- Enemies roll an intent a turn ahead and `_execute_intent` spends exactly the telegraphed
  amount. Never recompute it at execution time — the promise is the mechanic.
- A card with any `target: "opponent"` effect aims at enemies; everything else aims at the
  player. `_is_attack` (damage only) drives damage bonuses; `_targets_opponent` drives
  targeting. Conflating them either loses pure-debuff cards or wastes Focus on them.
- 53 cards (46 collectible across 22/21/3 one-/two-/three-costs, plus 5 starters and 2
  curses — the Phase 7 boomerang/reverb/overload keyword cards brought the collectible pool up
  from 40), 250 stages across 50 chapters, a four-band difficulty curve (see
  Docs/ARCHITECTURE.md), and three enemy debuffs beyond burn/stun: `vulnerable` (+50% damage
  taken) and `weak` (-25% damage dealt), both decaying by one enemy turn; `poison`
  (`enemy.poison`), Miasma Witch's signature status, deals its stack count as damage every
  turn like Burn but — unlike Burn — never decays on its own, only clearing on a heal or a
  kill. `strength` is the player-side counterpart to Focus — permanent for the battle instead
  of a one-shot burst — and all of these live as generic dictionary fields (`enemy.vulnerable`,
  `enemy.poison`, `player.strength`), not special-cased branches, so a new status is usually a
  `desc.<name>` string plus one read site, not an engine rewrite (poison itself was exactly
  that: one non-decaying tick line in `end_turn()`, reusing the fully generic `status` effect
  operation for the apply side — see `_resolve_effects()`'s `"status"` case, unchanged).
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

**Fonts**: `Cinzel-SemiBold.ttf` (Latin display face) with `LXGWWenKai-Medium.ttf` set as its
`.fallbacks` entry for CJK glyphs, composed once in `_load_game_font()` (`game.gd`) and applied
via `add_theme_font_override` inside the two shared primitives (`_label()`, `_button()`) that
build almost every piece of text in the game — so most new UI gets this for free. A few call
sites build a raw `Label`/`Button`/`LineEdit` directly instead of going through those helpers
and need an explicit extra override line (grep for existing ones before assuming a new raw
node needs it too). `project.godot`'s `[gui] theme/custom_font` is the project-wide fallback
for anything that skips even that — it points at `LXGWWenKai-Medium.ttf` (CJK-capable on its
own, unlike Cinzel) specifically so a raw Control that no one remembered to style still shows
correct text instead of Godot's built-in non-CJK default. Don't delete a font file just
because a script-only grep finds no hits — check `project.godot`'s theme block too.

The visual presentation blends high-detail painted assets with procedural vector accents:
- **Map is a single-chapter view, not a scrollable 50-chapter strip.** `show_map()` renders
  exactly one chapter at a time (`g.current_map_chapter`, `_add_map_chapter(active_chapter)` +
  `_add_routes(active_chapter)` + that chapter's 5 stage pins), with `◀`/`▶` buttons on the
  chapter plaque (gated by `profile.unlocked`) and a "Back to Current" button when browsing
  away from your real position — the old auto-scroll-to-position multi-band map is gone. Each
  chapter's 5 waypoints now run bottom-to-top on screen (stage 1 at the bottom, the chapter
  boss at the top) — `BIOME_PATH_WAYPOINTS`/`CHAPTER_PATH_WAYPOINTS` were reordered for this,
  but `profile.position`/`profile.unlocked` are still plain 0-249 stage indices, so this was
  save-compatible (only where an index renders changed, not what it means).
  - **Realm transition cutscene**: clearing a chapter's 5th/final stage (not a replay) sets
    `pending_rewards.chapter_transition` (`game_rewards_screen.gd`, near the other
    `is_chapter_final` handling), which `_finish_reward()` uses to call
    `show_chapter_transition(cleared_ch, next_ch)` instead of going straight back to the map —
    a real full-screen sequence (art fade, "Chapter N Cleared" text, the hero walking to the
    new chapter's first pin, tap-to-skip) before landing on `show_map()` for the new chapter.
  - **Asset pipeline**: Checks `res://assets/chapters/chapter_%d.png` (**390x844 PNG, full
    screen** — was 390x520 before the single-chapter-view redesign; don't trust the smaller
    number if you see it anywhere else uncorrected). If present, loads that unique chapter
    background directly.
  - **Fallback & modulation**: If a specific chapter file is absent, falls back to `_biome_textures` (`res://assets/biomes/biome_0..5.png`) with per-chapter regional tint modulation (`Color.WHITE.lerp(tint, 0.35)`) and alternating horizontal flipping (`((chapter / 6) % 2 == 1)`), providing unique visual atmospheres across all 50 chapters without obvious repetition.
  - **Adding unique chapter art**: All 50 chapters (`chapter_0.png` through `chapter_49.png`, 390x844 PNG) now have dedicated unique backgrounds in `Godot/assets/chapters/` matching the chapter lore and names from `content.gd`. Run `godot --headless --path Godot/ --editor --quit` whenever new images are added to regenerate `.import` metadata.
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
  - `SettingsButton` (gear ⚙) opens `show_settings()`, which is now the *only* place to change
    language or mute audio — the map header used to carry its own separate lang-toggle and
    music-toggle buttons alongside Quest/Camp/Settings, and with the F2 Settings screen
    duplicating both, packing 5 buttons plus the logo into one row was overflowing on some
    devices. Both were removed from `show_map()`'s header (their handlers, `_toggle_language()`
    and `_toggle_music()`, were deleted too — `_change_language()`/`_toggle_music_settings()`
    inside `show_settings()` are the only way to do either now). Don't re-add a lang/music
    button to the header without removing something else first — the row has no spare width.
  - `MapChallengeRail` — a vertical icon rail on the right edge of the map (not the header;
    `_add_map_challenge_rail()`), giving one-tap access to Camp's "挑战" tab via
    `_open_camp_challenges()`. Used to be two separate icons (Daily Trial "scroll" + Abyss
    "orb"); now unified into one `MapTrialShortcutBtn` (`nav_trial.png`) covering the whole
    tab, not just those two modes. The icon dims
    when the feature is still locked (`profile.unlocked` gates from A2) but stays tappable —
    tapping always opens Camp's Challenges tab, which already renders the real unlock
    requirement text; the rail itself is too narrow to duplicate that.
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
  - **4 Hero Archetypes / Classes (`content.HERO_CLASSES`)**:
    - **Fox Spirit Master (灵狐行者 / `fox_spirit`)**: Agile fire/gale caster with `foxCharm` and `foxfire` combos.
    - **Stone Sentinel (岩铠卫士 / `stone_sentinel`)**: Immovable fortress with `ancientSeed`, heavy armor, and `stoneBreaker` shield conversion.
    - **Shadow Stalker (夜影刺客 / `shadow_stalker`)**: Lethal critical assassin with `starShard`, `moonfang`, and `cinderHex`.
    - **Miasma Witch (瘴气巫女 / `miasma_witch`)**: Attrition mage built around Poison — a
      non-decaying DoT status (`enemy.poison`, ticks every turn until healed or the target
      dies, unlike Burn's 1/turn decay) applied via `toxinDart`/`witherTouch`.
      **Art Directive**: Miasma Witch's official bespoke portrait **requires a real human artist to produce (需真人画师出图，严禁由AI生成)** to match the master painted character atlas style. AI agents must NOT attempt to generate this asset. The standalone portrait loader (`res://assets/characters/miasma_witch.png`) is already in place in `game.gd`'s `_get_character_texture()` to load the standalone PNG once the human artist delivers it. Any code sizing this sprite (in battle, on the hero-select panel, anywhere else `_get_character_texture()` is called) must use the *resolved texture's own* `get_width()`, not a hardcoded atlas-cell divisor.
    - All 4 class starting decks strictly follow the 25-card, all 1-cost balance rule.
    - Selecting a hero class in Camp updates the traveler map avatar and loadout.
  - **Endless Abyss Mode (`show_abyss` / `begin_abyss_battle`)**: Infinite gauntlet where enemies and gold rewards scale by floor (`content.abyss_encounter(floor)`). Tracks `profile.abyss_floor` and `profile.abyss_record`.
  - **Boss Rush (`begin_boss_rush_battle`)**: refights every boss the player has already beaten,
    back to back, cycling through `content.boss_rush_boss_indices(unlocked)` and escalating
    enemy health/damage each full loop back through the same pool. A loss costs only the
    current bout, not the streak (`profile.boss_rush_floor`/`boss_rush_record`).
  - **Curse Run (`begin_curse_run_battle`, `SpiritContent.MUTATORS`)**: an opt-in, self-selected
    handicap gauntlet unlocked at Ascension Tier A2+ (`profile.difficulty >= 2`) — pick one of
    10 mutators (Glass Cannon, Energy Famine, Mirror World, Haunted Deck, Ironclad Will, Elite
    Gauntlet, Barren Harvest, Berserker's Pact, No Mercy, Fewer Draws) and fight an escalating
    floor gauntlet built on `content.abyss_encounter()`'s own scaling, with that mutator's
    combat.gd modifier keys layered on top (`player_max_hp`/`player_dmg_mult`/`energy_cap`/
    `mirror_hp`/`no_heal`/`draw_penalty` are new, generic keys added for this; `extra_enemy`/
    `damage_mult` reuse existing ones). Progress (`profile.curse_run.floors`/`records`) is
    tracked per mutator rather than shared, since switching mutators mid-climb would otherwise
    dump a fragile build (e.g. Glass Cannon's 30-HP cap) into a floor scaled for a completely
    different handicap. Reaching floor `SpiritContent.CURSE_RUN_BADGE_FLOOR` (5) with a given
    mutator unlocks that mutator's permanent cosmetic badge (`profile.curse_run.cleared`), shown
    as a checkmark on its own picker button from then on. `Haunted Deck`/`Ironclad Will` are
    handled entirely at the battle-launch call site (an extra `decay_blight` spliced into a
    duplicated battle-only deck array; an empty relics array) rather than as combat.gd modifier
    keys, since neither needs a new generic engine hook when the call site can just build the
    right input directly. Same "attempt vs. run" loss handling as every other side mode here —
    see this file's own trap entry on `_leave_battle()` needing an explicit branch per mode.
  - **Sandbox (`begin_sandbox_battle`)**: zero-stakes practice bout against any stage already
    reached, picked via a stage stepper in Camp's Challenges tab. Always a full 60 HP
    regardless of real campaign health, grants no rewards, and never writes `profile.health`
    on the way out — purely for testing a deck/loadout risk-free.
  - **AFK Harvest / "宗门灵修" (`get_idle_harvest_rate/_unclaimed_gold`, `claim_idle_harvest`,
    `fast_idle_harvest`, `show_idle_harvest_modal`)**: a passive gold generator, `10 +
    profile.unlocked*2` gold/hour, accrued from `profile.idle_harvest.last_claim_time` and
    capped at 12 hours' worth. `fast_idle_harvest()` is a once-per-day instant 2-hour-worth
    burst claim. Pure formula, no `content.gd` table. Surfaced via the map's right rail
    (`_add_map_right_rail()`'s pouch icon) and as a shortcut button from both the
    already-cleared-stage prompt and the post-defeat diagnosis card (see below) — it's the
    main thing the game now points a stuck player toward, now that campaign health resets in
    full every battle and can't be attrition-managed the way the tuned difficulty curve
    originally assumed (see Docs/ARCHITECTURE.md's "250-stage difficulty curve" section).
  - **Phantom Arena / "虚影演武" (`begin_phantom_arena`, `content.PHANTOM_CULTIVATORS`)**: a
    daily-limited duel mode against one of 4 fixed phantom-cultivator bosses, scaled by
    `profile.unlocked`. Reuses the full existing combat pipeline (same deck/upgrades/relics/
    mastery) — no new systems, just new encounter data plus `profile.phantom_arena = {day,
    wins_today, claimed_today}` (daily reset via `_ensure_phantom_arena_current()`). A win
    grants gold per the normal `_grant_stage_rewards()` path; a separate once-daily bonus
    chest unlocks after your first win of the day. A loss is inert — full HP restored, no
    streak or floor tracked, closer to Sandbox's "repeatable side activity" than Abyss's
    escalating gauntlet.
  - **World Events / "世界活动" (`begin_world_event_battle`, `content.WORLD_EVENTS`)**: a
    themed duel that rotates every 4 weeks — which of the 4 events (Ember Lord/Frost Widow/
    Withered King/Storm Judge) is active is a pure function of a period index
    (`content.world_event_for_period(period)`), computed from wall-clock time only at the one
    call site that needs to (`game._ensure_world_event_current()`), the same seed-in/
    pure-function-out split `daily_trial_tags()` already uses so this is testable at any period
    without mocking the clock. Each event's combat.gd modifier is built entirely from keys
    other modes already added (`damage_bonus`/`extra_enemy`/`damage_mult`/`no_heal`/
    `health_scale`) — no new engine surface for this feature. Freely repeatable like Phantom
    Arena/Sandbox (no floor or streak), with a permanent per-event cosmetic badge
    (`profile.world_event_record.badges`) auto-granted on the first win of each 4-week period,
    mirroring Curse Run's badge shape (Phase 8) rather than Phantom Arena's separate
    manual-claim chest button.
  - **Spirit Draft Arena / "灵界轮抽竞技场" (`show_spirit_draft`, `profile.draft_arena`)**: a
    7-round 3-pick-1 card draft — each round offers 3 random cards excluding Starter and Curse
    rarities — building a 15-card deck on top of a fixed 8-card seed (4 `strike` + 4 `ward`).
    Once the deck is complete (`draft.active = true`), it's a gauntlet against escalating
    campaign encounters (stage index `wins * 2`, capped at the last encounter) that ends at
    `SpiritContent.DRAFT_WIN_CAP` (6) wins — a "Grand Champion" toast plus a 500-gold/
    200-season-XP bonus on top of the normal per-win payout — or `SpiritContent.DRAFT_LOSS_CAP`
    (3) losses, whichever comes first. Like Sandbox/Phantom Arena/Boss Rush, it reuses the
    player's real profile (relics/equipment/mastery/upgrades) rather than a synthetic loadout —
    only the deck itself is swapped, in `begin_battle()`'s `battle_deck` check (`g.in_draft_battle`
    and `draft_arena.deck.size() >= 15`). Every way a run can end — the win cap, the loss cap,
    and abandoning it early from the battle-ready screen — must reset the same fields
    (`active`/`round`/`deck`/`current_pool`/`wins`/`losses`) back to their fresh-save shape, or
    the next run inherits a stale one; `SpiritGame._reset_draft_run()` is the one shared place
    that does it, so a new ending never needs to remember the shape by hand (see this file's
    "Traps" section for the stuck-flag bug this mode shipped with before that helper existed).
  - **A cleared stage can never be re-fought — this is a real, enforced gate, not just a
    warning label.** Tapping an already-cleared pin (`_on_pin_pressed()` → `_is_replay(index)`)
    opens `_show_replay_mode_prompt()`, which offers only informational shortcuts (Cultivate/
    Tune Deck/Phantom Arena) — there is no button anywhere that starts a battle against a
    stage below `profile.unlocked`. (An earlier version of this screen's copy already claimed
    "past stages cannot be farmed repeatedly" while the Normal/Hard Replay buttons underneath
    it still worked exactly as before; that mismatch is what got fixed here — if you're
    tempted to add a "replay for reduced rewards" path back, that promise is the reason not
    to without changing the copy too.)

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

- **Meta-progression: compendium, hero mastery, daily trial (`show_compendium`,
  `_hero_archetypes_section`, `begin_daily_trial`)**:
  - **Compendium (`show_compendium`)** is a 5-tab gallery (cards, gear, runes, relics,
    bestiary) over `profile.compendium_discovered` — a permanent discovery log, not a live
    inventory, kept separate from `profile.collection`/`equipment_owned`/`relics`/
    `rune_inventory` so a card or relic stays "discovered" forever once seen. The
    `_x_discovered()` helpers in `game.gd` OR the compendium flag with the existing
    inventory array as a fallback, so saves from before this milestone show their
    already-owned items as discovered without a migration pass. Curse cards
    (`rarity == "Curse"`) are excluded from the card tab — they're enemy-inflicted battle
    hazards nothing ever "collects", and including them would leave a permanently
    uncompletable entry. Bestiary entries are `SpiritContent.ENEMIES` — 125 unique monsters (25
    per realm × 5 realms, each with bilingual lore, an `element`, a `tint` color, and a
    `tier` 1-4 of Minion/Elite/Boss/Cataclysm that drives both its battle-screen presentation
    (aura ring, boss crown, screen-shake on entry) and its Compendium name prefix), resolved
    from an encounter's `art`/`art_key` field by `_art_key_for_enemy` and rendered as a
    standalone portrait (`res://assets/characters/monsters/<key>.png`) rather than the older
    fixed 3x3 atlas — see `Godot/tools/generate_monsters.gd` for the offline art-generation
    tool behind them. Marked discovered the moment a battle starts against that monster.
  - **Hero Mastery (`content.HERO_MASTERY_PERKS` / `mastery_bonuses()`)**: every battle win
    grants `profile.hero_masteries[hero_id].xp` to whichever hero is currently equipped
    (boss kills worth double, campaign replays halved — see `_grant_mastery_xp` in
    `game.gd`), climbing a permanent Lv1-5 track with one always-on perk per level,
    cumulative. **Level 0 (zero perks) has to be reachable at 0 xp** — combat.gd's
    documented "turn 1 is strictly 2 energy" invariant broke the first time this shipped,
    because Lv1 was free and fox_spirit's Lv1 perk was `energy_turn1`. Every threshold in
    `HERO_MASTERY_XP_FOR_LEVEL` is a positive cost for exactly this reason; don't make a
    level free again without checking every "under all conditions" invariant in this file.
    Perks are a small reusable vocabulary (`max_hp`, `shield_start`, `energy_turn1`,
    `first_attack_bonus`, `heal_per_turn`, `burn_start`, `vulnerable_start`) resolved into a
    flat bonus dict and passed as `combat.create()`'s `hero_bonuses` parameter — the same
    battle-start/first-attack/per-turn hook sites relics and equipment already use, so a new
    hero needs a new `HERO_MASTERY_PERKS` row, not new engine code.
  - **Daily Trial (`content.daily_trial_encounter/_tags/_modifier`, `begin_daily_trial`)** is
    a 15-stage gauntlet independent of campaign progress, resetting at the same day boundary
    as the daily quests (`_ensure_daily_trial_current`, mirroring `_ensure_quests_current`).
    Every device rolls the same 3-tag trio for the same day (`_shuffled_indices` on the day
    index, same deterministic-per-period approach `roll_quests`/`roll_shop_stock` already
    use) — each tag maps to exactly one existing `combat.gd` modifier key
    (`damage_mult`/`health_scale`/`extra_enemy`/`revive`/`damage_bonus`) so combining up to 3
    of the 5 is always a plain dictionary union, never two tags fighting over one key.
    `damage_mult` is the one genuinely new `combat.gd` modifier this milestone adds. A loss
    costs the attempt, not the run — `daily_trial_record.stage` only advances on a win, so
    the next try that day re-fights the same stage, same "attempt vs. run" split Abyss
    already uses. `content.daily_trial_modifier()` must always carry `name`/`name_en`/
    `detail`/`detail_en` (synthesized from the day's tag names/descriptions) because
    `show_battle()`'s modifier badge reads those four fields unconditionally — an early
    version of this returned only the raw combat.gd keys and crashed the battle screen the
    moment a trial started.

## Handoff & verification notes for future agents

- **Verifying changes**: see "Verifying a change" near the top of this file for the full
  `./run_tests.sh` command set. Don't duplicate suite names/check counts here — they drift out
  of sync with reality otherwise, which is exactly how this note once ended up pointing at only
  2 of what are now 8 suites with a check count hundreds stale. For the balance curve
  specifically, `Docs/ARCHITECTURE.md`'s "250-stage difficulty curve" section is the canonical
  account of its current measured state; `Docs/BALANCE_REVALIDATION.md` has the fuller
  write-up of one rebuild of that suite plus a standing backlog of suggestions for extending it
  further.
- **Deploying to iOS**:
  Run `./deploy_ios.sh --full-export` with the iPhone unlocked and connected. If the screen is locked, `devicectl` reports `unavailable`.
- **Importing newly added images**:
  Always run `godot --headless --path Godot/ --editor --quit` after adding `.png` or `.jpg` assets to generate `.import` metadata before testing or packaging.
