# Architecture

Background for anyone going deeper than [AGENTS.md](../AGENTS.md), which is the quick
reference. This explains why the code is shaped the way it is.

## The one boundary that matters

`combat.gd` is the rules engine and it never touches a node, scene or `Control`. It takes a
seed, an encounter, a deck and a list of owned equipment/runes/relics, and it returns a
plain `Dictionary` of state. `game.gd` reads that dictionary and draws it.

Everything else follows from that. Because the engine is pure data:

- The rules can be tested without a display, which matters more here than usual — the iOS
  Simulator cannot run this project at all (see below), so headless testing is not a
  convenience, it is the only automated verification that exists.
- A battle is reproducible from its seed, so a balance question can be answered by running
  a hundred combats in a loop rather than by playing.
- `ui_smoke.gd` can drive real screens and assert on engine state at the same time. The test
  that compares the on-screen damage preview against the damage actually dealt only works
  because both sides are reachable from one process.

The pressure on this boundary is always the same: some UI detail needs a number the engine
computes privately. Resist recomputing it in `game.gd`. `_predict_damage` duplicates the
bonus arithmetic and is tested against the real result for exactly that reason; if the two
ever drift, the test fails rather than the player being misled.

## Combat state

One dictionary, deliberately flat and JSON-shaped:

- `player` — health, max_health, shield, burn, focus.
- `enemies` — each with health, shield, burn, stun, mechanics, and an `intent`.
- `draw` / `hand` / `discard` / `exhaust` — arrays of `{uid, card_id}`. The uid is
  combat-local so two copies of a card are distinguishable.
- `energy` (3/turn), `actions` (2/turn), `turn`, `phase`.
- `equipment`, `runes`, `relics`, `upgrades`, `modifier` — the run's modifiers, passed in.
- Per-turn latches: `swift_used`, `first_attack`, `moon_used`, `elements`.

`phase` is `player`, `won` or `lost`. The UI reads it to decide what to draw and when to
hand off to the reward screen.

## Enemy intents are promises

`_plan_intents` runs at the end of `create` and at the end of every `end_turn`, so the next
action is always decided and visible a full turn ahead. `_execute_intent` then spends
exactly the amount that was stored — it never recomputes.

That distinction is the mechanic. If execution recalculated damage, dropping an enemy below
half health mid-turn would change the hit that was already telegraphed, and blocking would
become a guess. Anything that makes an enemy stronger takes effect on the *next* intent.

Intents are weighted by the enemy's own stats and mechanics, and a non-attack intent never
repeats twice running, which otherwise reads as the enemy stalling.

## Cards and targeting

A card is a list of effects, each with an `operation`, an `amount` and a `target` of
`actor` or `opponent`. Two different questions get asked about a card and they must not be
conflated:

- `_targets_opponent` — does it need an enemy? Anything with an opponent-facing effect.
- `_is_attack` — does it deal damage? Only this earns Focus and first-attack bonuses.

Using the damage check for targeting silently broke every pure-debuff card: they were played
with no target, and `_resolve_effects` drops opponent statuses when the target index is -1,
so they did nothing at all. Using the targeting check for bonuses would be the opposite
error, burning Focus on a card that deals no damage.

Runes and relics layer on top as flags read during `play` and `end_turn` rather than as
subclasses. Adding one means adding a branch, not a type.

## Content and localisation

`content.gd` holds card/equipment/rune/relic definitions plus `UI_TEXT`, a dictionary of
every user-facing string in both `zh-Hans` and `en`. Card balance numbers live separately in
`data/core.json`.

Strings are centralised so neither language can quietly fall behind — a missing key is
visible as the key itself rather than as an English string leaking into a Chinese screen.
Language switches redraw the current screen without disturbing combat state.

## Screens

`game.gd` builds every screen in code rather than with `.tscn` scenes. This is unusual for
Godot and makes the file long. The trade was deliberate: one searchable place for all UI,
no divergence between a scene file and the script driving it, and screens that can be
constructed and asserted on from a test. The cost is that layout bugs are invisible until
something renders — which is what the trap list in AGENTS.md is made of.

Screens rebuild wholesale rather than updating in place. `_clear()` frees the tree and the
`show_*` function constructs it again from current state. Simple and free of stale-view
bugs, at the cost of rebuilding on every card played.

## Saves

`save_store.gd` writes one JSON profile carrying `schema_version`, an `account` block with a
locally generated UUID, and `updated_at`. There is no backend. The fields exist so that
adding one later is a sync decision rather than a migration: `updated_at` is what a
last-write-wins merge would compare, and the account id identifies the save across devices.

## Testing, and why there are two suites

`test_runner.gd` covers the rules engine directly — card interactions, equipment, relics,
intent execution, the save schema.

`ui_smoke.gd` instantiates the real game, walks every screen and plays a full combat turn.
It exists because the iOS Simulator cannot run this project: the official Godot 4.7.2 iOS
export templates ship a simulator library with only an x86_64 slice, so there is nothing to
link against on Apple Silicon, and current simulator runtimes no longer execute x86_64 apps.
A physical device is the only way to see the game, which makes an automated screen walk the
only thing that catches regressions between device sessions.

It earns its place. It has caught a type error that silently killed a coroutine mid-turn, a
parse error that left the whole script unattached, a floating bar collapsed to zero height,
a bar hidden behind map pins, and an enemy sprite left at three times its size. None of
those raised an error; all of them were plainly wrong on screen.

## The 250-stage difficulty curve

`_chapter_factor` maps a chapter number to a health/damage multiplier in four bands, chosen
to end on a chapter boundary rather than an arbitrary stage number:

- Chapters 1-4 (stages 1-20): +8% per chapter. Meant to be clearable on autopilot.
- Chapters 5-10 (stages 21-50): +12% per chapter. Card sequencing starts to matter.
- Chapters 11-20 (stages 51-100): +16% per chapter (was +22% — see the 2026-09-17
  revalidation below). Needs a deliberately built deck.
- Chapters 21-50 (stages 101-250): ×1.062 per chapter, compounding. Meant to outpace
  whatever a straight-line playthrough brings with it — the intended levers past this point
  are runes, equipment, relics from farming earlier stages, hero mastery, Rebirth (see below),
  and later in-app purchases, not better play.

Every 10th chapter is a "great boss" combining three mechanics at once (shield regen,
frequent crits, a below-half-health damage spike), scaling with the arc, plus one of five
unique scripted Phase 2 transitions below 50% HP (see AGENTS.md's D4 entry) — intentionally
"the hardest single fight in their neighborhood," not a curve mistake if a straight-through
build finds one hard.

These constants did not come from guessing. `Godot/tests/test_runner.gd` has the permanent,
cheap version of the check — bosses at chapters 1/10/20/50 are pinned, plus (as of
2026-09-17) `_chapter_factor(20)`'s value and the elite add-count at chapters 19/21, so the
curve can't silently regress back to the version that broke chapter 19 — but the bands
themselves are tuned against `Godot/tests/balance_probe.gd`, a from-scratch AI-driven
playthrough simulator (see below for why "from scratch"). It drives `combat.gd` directly (no
`Main.tscn`/node instantiation at all — simulating all 250 stages takes well under a second),
using `combat.ai_best_play()` as the in-battle decision-maker and the same `_card_build_score`
formula (duplicated locally, like `_predict_damage` duplicates combat.gd's bonus arithmetic
for the same reason) real reward-picking uses to grow the deck realistically stage by stage.

**2026-09-15: the original probe was deleted after its one-time use** (never survived in this
repo's history) after finding and motivating fixes for two real production bugs, both
invisible until someone actually tried to win with the deck the game itself would build:

- **`_chapter_mechanics` had a "thorns" mechanic that combat.gd never read.** It had been in
  the encounter data since the original 50-stage version — every "thorns" enemy fought
  identically to one with no mechanic at all. Fixed by actually wiring it to reflect damage
  in `_damage_enemy`.
- **`_card_build_score` — the function behind both "smart-build" and "smart-add" — scored
  almost pure rarity** (Rare +30, Common +12, a small cost penalty) with no regard for what a
  card actually does. It happily filled a 25-card deck with narrow Power/Tactic utility cards
  at the expense of reliable damage, and that deck then lost repeatedly to an ordinary
  two-enemy chapter 7 boss — nowhere near the intended "needs deckbuilding" band. Rewritten to
  score a card by what its effects are actually worth, with rarity and cost as minor nudges.

**2026-09-16/17: the HP-reset change made that probe's own pass/fail signal obsolete before
anyone re-ran it.** The original bot's "getting stuck after eight losses is a real signal"
reasoning depended on a win carrying accumulated HP damage into the next stage — real
attrition pressure across a chapter. Once every stage (win or lose) started resetting
`profile.health` to a flat 60 (a deliberate, confirmed decision — moving resource pressure
onto the gold economy, AFK Harvest, Phantom Arena instead — not reverted here), that
reasoning stopped applying, and the curve went unvalidated against the game as it actually
plays for the better part of two milestones.

**2026-09-17: revalidated.** Rebuilding the probe from scratch (the deleted original's exact
implementation didn't survive) and running it against the current rules found a real,
reproducible wall: an elite fight at chapter 19 — 3 enemies (2 adds) plus a "crits every 2nd
attack" mechanic — killed an AI-piloted, smart-built deck in 4 turns on every retry, no matter
how many attempts. Root cause was two things compounding in the same handful of chapters
rather than at a band boundary: Band 3's 0.22/chapter additive growth (nearly double Band 2's
0.12) and elites gaining their second add at chapter 15 — square in the middle of Band 3
rather than lining up with Band 4's own "multi-enemy fights are expected" territory. Fixed by
trimming Band 3 to 0.16/chapter and moving the elite add threshold to chapter 21. Re-running
confirmed chapters 1-19 now clear reliably (Band 1/2: 100% first-try; Band 3: 97% eventually
cleared, 93% first-try, climbing from ~3 to ~6 average turns per win as the bands progress —
the "increasingly needs investment" shape the four bands are supposed to have). Chapter 20's
Great Boss remains an immediate wall for this probe's baseline build (no rune-set socketing,
no merchant purchases, no Rebirth bonuses, a single non-maxed hero) — expected, not a bug,
since that's both an intentional capstone fight and the literal first stage of Band 4, whose
own documented intent is "needs farming, not skill alone." Continuing the probe past that one
wall (a diagnostic-only mode real players can't use, since progress can't skip an unbeaten
stage) showed Band 4 collapsing hard soon after without a maturing build to match its
compounding growth — consistent with "this band assumes investment," not itself re-tuned,
since simulating the intended farming loop (Rebirth cycles, hero mastery, AFK Harvest gold,
socketed rune sets) was out of scope for this pass. If a future pass wants to actually validate
Band 4, modeling that farming loop — not just retrying the same static build — is the
prerequisite, the same way this pass's own fix depended on modeling deck growth realistically
rather than assuming a fixed deck throughout.
