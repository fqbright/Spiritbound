# Balance Revalidation & Doc Corrections

Status: complete and green as of when it was written — since superseded by a merge with a
parallel session's own rebuild of this same suite. **The specific numbers below (chapter 20
wall, digest `933924288`, "now 7 suites," the guardrail reaching only "chapter 11") describe
that snapshot, not the current probe** — left as-is rather than rewritten, since this doc is a
dated record of what that pass found and fixed. For the current, actually-merged behavior
(the farming loop, the chapter 40/20 full/quick depths, the 8-suite count, the `--balance-gold`
mode), see Docs/ARCHITECTURE.md's "250-stage difficulty curve" section — that is the canonical
account from here on. This is still the handoff note for whoever picks up the **suggestions**
below, most of which remain relevant regardless of which probe implementation is current; read
it before re-touching this area, but verify any specific number here against ARCHITECTURE.md
first.

## Why this work happened

The four-band difficulty curve in `content.gd`'s `_chapter_factor` was tuned back when a
**win carried accumulated damage into the next stage** — i.e. `_grant_stage_rewards()` only
restored full health on a *loss*, so a chapter had real attrition pressure. The
"reset full HP per battle, remove inter-battle healing" change later made **every** stage
(win or lose) reset `profile.health` to a flat 60, and `begin_battle()` now passes a literal
`60` into `combat.create()` rather than the profile's current health. That invalidated the
premise the curve was tuned against, and `Docs/ARCHITECTURE.md` was left carrying a warning
that the curve "has not been revalidated". The original one-off trajectory bot had been
deleted, so there was no way to re-check the curve.

## What was built

`Godot/tests/balance_probe.gd` — a permanent, byte-reproducible trajectory suite that replays
the whole 250-stage campaign with the game's own heuristic AI.

- It drives the real `SpiritCombat` engine **directly** rather than through `begin_battle()`,
  because `begin_battle()` seeds the shuffle and `active_modifier` from
  `Time.get_unix_time_from_system()` and is therefore not reproducible.
- Seeds are derived from the `(stage, attempt)` index, never the clock, so a run is
  byte-identical across machines. The full run prints a trajectory digest for pinning.
- Progression and drafting still go through the **real** functions —
  `_grant_stage_rewards()` and `_smart_add_card()` / `_card_build_score` — so the deck evolves
  the way a real autopilot player's would.
- It tops up stamina and gold every stage, so it measures **combat difficulty only**, not the
  gold economy. (Modeling the economy was explicitly out of scope for this pass.)
- It stops at the first stage it cannot clear: a lost stage grants no reward, so the deck
  cannot improve and every later stage would be unwinnable anyway.

### Guardrails (hard pass/fail — non-zero exit on failure)

1. Chapters 1-4 clearable on autopilot (zero losses).
2. Chapters 1-10 clearable without a single loss.
3. The bot reaches chapter 11 before any wall.
4. No stage exceeds the 300-turn softlock guard.

Digest pinning is **off by default** (`EXPECTED_DIGEST := NO_DIGEST`) so a legitimate retune
does not fail CI; turn it on deliberately if you want to pin a known-good trajectory.

## How to run it

```bash
./run_tests.sh --balance        # full: 8 retries per stage, byte-reproducible (~0.7s)
./run_tests.sh --balance-quick  # retry-capped to 1, CI-friendly (~0.8s)
./run_tests.sh --all            # everything (now 7 suites, including this one)
```

## Measured result (full mode, current rules)

Re-measured after rebasing onto the Phase 4-5 merge (relic synergies, equipment reforging,
talent tree). The new systems pushed the first wall out from stage 92 to stage 99.

| Band | Battles | Wins | Losses | Avg turns/win |
|------|---------|------|--------|---------------|
| Chapters 1-4  | 12 | 12 | 0 | ~3.2 |
| Chapters 5-10 | 18 | 18 | 0 | ~4.4 |
| Chapters 11-20| 30 | 29 | 12 (across retries) | ~5.9 |

First wall at **stage 99 / chapter 20**. Trajectory digest: `933924288` (the pre-merge value
was `1806550714`; the digest moving is expected when the engine changes). In `--balance-quick`
the retry cap is lower, so the wall arrives earlier — that is expected, not a regression.

Conclusion: the four-band curve still holds against the always-full-HP rules. Chapters 1-10
remain lossless on autopilot and the band only starts to bite around chapter 17-20, which is
where it is supposed to. The "has not been revalidated" warning is therefore cleared, and
`Docs/ARCHITECTURE.md` now records these measured numbers instead.

## Verified

- `./run_tests.sh --balance-quick` → exit 0, `CURVE HOLDS (0 FAILURES)`.
- `./run_tests.sh --all` → all suites green.
- `Godot/tests/balance_probe.gd.uid` generated, matching every other test script.

The `WARNING: 2 ObjectDB instances were leaked at exit` / `1 resources still in use` lines are
a **pre-existing project-wide teardown artifact** — `e2e_playthrough.gd` emits the identical
warning — and are unrelated to this suite. Exit codes are still 0.

## Documentation corrections made in the same pass

While writing this, several stale claims were found that did not match the code, and were
fixed. Verified against `Godot/data/core.json` and `content.gd` at the time of writing:

| Claim (before) | Reality (after) | Where |
|---|---|---|
| "36-card pool" | **47-card pool** | `README.md`, `Godot/README.md` |
| "39 cards", "18/15/3" costs | **47 cards**; collectible costs are **18/19/3** (40 collectible + 5 starters + 2 curses) | `AGENTS.md` |
| "8 relics" | **11 relics** (12 equipment, 10 runes) | `Godot/README.md` |
| "Each turn you get 3 energy and 2 plays" | Opens at **2 energy**, +1 every two turns; **no plays-per-turn cap** (energy alone gates plays) | `README.md` |
| "There is no End Turn button" | Auto-handoff **plus a manual `PassTurnBtn`** (`_pass_turn()`) — the button was added after those docs were written | `README.md`, `AGENTS.md`, `game_battle_screen.gd` comment, balance-design skill |
| `ARCHITECTURE.md`: `energy` (3/turn), `actions` (2/turn) | energy opens at 2 and climbs; the `actions` cap **was removed** | `Docs/ARCHITECTURE.md` |
| "Run both suites" / two-command test blocks | `./run_tests.sh` (core) and `./run_tests.sh --all` | `README.md`, `Godot/README.md`, `Docs/GROWTH_ROADMAP.md`, skills |
| `game.gd` = "Every screen: map, battle, deck, equipment, shop, camp" | `game.gd` is the composition shell; screens live in `game_*_screen.gd` | `README.md` |
| `test_runner.gd` "189 checks" | **399 checks** | `AGENTS.md` |

Also fixed a cosmetic numbering bug in `run_tests.sh`: two sections were both labelled `5`,
and the step counters still said `[1/3]` / `[2/3]` / `[3/3]` from when there were three steps.

## Remaining suggestions for the next agent

These were opinions, not completed work, when this doc was first written. This repo's balance
probe has since been merged with a second, independently-built rewrite from a parallel session
(see Docs/ARCHITECTURE.md's "250-stage difficulty curve" for the synthesis and what it changed);
the note under each item below is what happened to that suggestion in the process, written by
whichever agent did that merge:

1. **Model the gold economy.** ✅ Done. `balance_probe.gd` gained a `--gold`/`--balance-gold`
   mode (`./run_tests.sh --balance-gold`) that runs the same farmed trajectory without topping
   gold up every stage, so the farming loop's shop/merchant spends are real. Result: chapter 37
   before the first wall (vs. chapter 40 with gold assumed infinite) and 8,798 gold still
   unspent at the end — the Shop can't absorb gold as fast as the campaign generates it, so
   "is progression affordable" already reads as a comfortable yes. Left as diagnostic telemetry
   rather than a hard CI gate, since one measurement isn't enough to responsibly floor a
   regression check against yet.

2. **Pin the digest once the curve is considered frozen.** Still not done, deliberately. The
   merge changed the probe's architecture and the curve's measured depth outright (chapter 39→40
   full, plus the new chapter 20 quick-mode figure), so `1806550714` is now stale on its face —
   pinning immediately after a change this size would just guarantee the next legitimate tweak
   fails CI for the wrong reason. `EXPECTED_DIGEST` stays `NO_DIGEST`; the current live digests
   (1405138167 full / 972245937 quick) are printed by every run if a future agent wants to pin
   once the curve holds still for a while.

3. **Broaden the bot past the first wall.** Not done. The farming loop already extends real
   measurement to chapter 40 (up from chapter 20), which covers most of what this suggestion
   was after, but a synthetic "tuned starter deck per band" for chapters past that wall needs a
   real design call (which deck, which relics/equipment to assume) that isn't this merge's to
   make unilaterally.

4. **De-duplicate the test-invocation guidance.** Partially done. While reconciling the two
   probes, several of these files (this doc included, plus `AGENTS.md`, `README.md`, and the
   `godot-game-dev` skill) turned out to have drifted *again* already — a stale card count (47
   vs. the real 53), a stale check count (575 vs. 655), and a bestiary description describing 5
   sprites where 125 unique monsters now exist. Fixed those on sight, and fixed the skill's
   `verify.sh` helper, which had drifted worse than a doc ever could: it silently ran only 2 of
   the 8 real suites instead of restating a stale list, so it now just delegates to
   `./run_tests.sh` instead of keeping its own copy. Did not attempt a full restructure to one
   canonical source for the rest — README.md and AGENTS.md serve different audiences (human
   contributor vs. agent instructions) and some duplication between them is expected in most
   projects; the actual failure mode worth guarding against is an executable copy that goes
   stale silently, which was the one fixed here.

5. **The `active_modifier` time-seed.** Not done. Still the highest-risk item on this list —
   it touches every real battle's core seeding, not just test infrastructure, and this
   session's own experience reconciling an unrelated pre-existing test flake (see
   `ui_smoke.gd`'s "finishing-blow banner" check, now documented in AGENTS.md's Traps section)
   was a fresh reminder of how easy it is to misjudge a timing/seeding change in this codebase
   without dedicated, isolated verification. Left for a session that can give it that.

6. **The pre-existing ObjectDB leak warning.** Not done, and this merge now has a considered
   opinion on why not: `leak_checker.gd`'s own delta-based checks (open/close a modal N times,
   assert the node count returns to baseline) already confirm zero *unbounded* leaks, which is
   the property that actually matters. The raw "N ObjectDB instances leaked at exit" warning
   varies run to run (observed 2 to 457 across different suites in this merge's own verification
   pass) because it's counting whatever a headless script's `quit()` didn't get around to
   tearing down before the process ended, not a real accumulating leak. Chasing it to exactly
   zero would mean chasing engine shutdown-order noise rather than fixing anything.
