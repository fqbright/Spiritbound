# Next Phases Implementation Plan: Spiritbound Post-Launch Roadmap

This implementation plan lays out the next sequential phases of Spiritbound development, prioritized by **Impact / Effort Ratio** without requiring external backend servers. All 10 phases are now complete — see the Completed Phases Reference below. A successor agent picking this file up next should treat it as a template for how to structure a *new* roadmap (read `Docs/GROWTH_ROADMAP.md`'s progress log for the full history first), not as a source of further pending work.

---

## Completed Phases Reference
- ✅ **Phase 1**: Dynamic Encounter Mechanics & Boss Modifiers
- ✅ **Phase 2**: Compendium Mastery Milestones & Bestiary Lore
- ✅ **Phase 3**: Endless Abyss Mode Expansion & Modifiers
- ✅ **Phase 4**: Equipment Reforging & Inscription System (器灵重铸与灵纹洗练)
- ✅ **Phase 5**: Dynamic Relic Synergies & Combo Resonance (法宝共鸣系统)
- ✅ **Phase 6**: Career Codex & Player Statistics Dashboard (旅者典籍) — done 2026-09-19. Added
  as a `career` Compendium tab (8 tabs total, not the 4 this plan assumed) reusing
  `lifetime_stats`/`abyss_record` for counters that already existed elsewhere. See
  `Docs/GROWTH_ROADMAP.md`'s progress log for the full account.
- ✅ **Phase 7**: New Combat Keywords (新战斗词条系统) — done 2026-09-19. Shipped as **Boomerang
  (回旋)**/**Reverb (余韵)**/**Overload (过载)** (plan's "Retain"/"Echo" renamed — Retain would be
  a no-op here, Echo collides with the pre-existing rune of the same name) plus 6 new cards. See
  `Docs/GROWTH_ROADMAP.md`'s progress log for the full account, including a live balance-scorer
  gap this phase's own regression testing found and fixed.
- ✅ **Phase 8**: Mutator & "Curse Run" Challenge Mode (咒缚流局) — done 2026-09-19. Shipped as
  `SpiritContent.MUTATORS`, 10 opt-in handicaps fought as an Abyss-shaped floor gauntlet, gated
  at Ascension Tier A2+. One named mutator ("Draft Only") didn't fit a gold-only-reward gauntlet
  mode and was replaced with **Ironclad Will** (no relics allowed). See
  `Docs/GROWTH_ROADMAP.md`'s progress log for the full account.
- ✅ **Phase 9**: Seasonal World Events & Rotating Modifiers (世界活动) — done 2026-09-19.
  Shipped as `SpiritContent.WORLD_EVENTS`, 4 themes rotating on a 4-week period computed from
  wall-clock time (`game._ensure_world_event_current()`) but resolved by a pure function of that
  period integer (`content.world_event_for_period()`), so it's testable at any period without
  mocking the clock. Reuses every combat.gd modifier key Phases 1-8 already added — no new
  engine surface. See `Docs/GROWTH_ROADMAP.md`'s progress log for the full account.
- ✅ **Phase 10**: Battle Recap Share Card Generator (战报画卷) — done 2026-09-19. Most of this
  had actually already shipped under an earlier "E2" milestone (`show_run_recap()` — hero
  portrait, boss defeated, deck highlights); this phase added the 3 real gaps against the
  plan's literal spec: turns taken, an Abyss-milestone trigger alongside the existing Great
  Boss one, and — the actual "off-screen SubViewport screenshot generator" the plan names —
  real image capture behind what had been a stub Share button that only toasted "saved"
  without saving anything. Skipped the plan's QR code (no backend, nothing for it to point
  at). Found and fixed 2 real pre-existing bugs while wiring the Abyss trigger: a missing
  `game.gd` delegator for `begin_abyss_battle()`, and a ~48%-of-the-time crash in the battle
  HUD's modifier badge. See `Docs/GROWTH_ROADMAP.md`'s progress log for the full account.

---

## Open finding for whoever picks this up next (2026-09-20)

**`is_great_boss` is read but never written — the five hardcoded Great Boss phase-2
transitions are unreachable in the campaign.**

`combat.gd` gates the chapter-matched phase-2 abilities (chapters 10/20/30/40/50, inside
`_trigger_great_boss_phase_2()`) on `bool(state.get("is_great_boss", false))`, which it reads
from the *encounter* dict. `state.is_great_boss` is populated from
`encounter.get("is_great_boss", false)` — and `content._build_encounters()` never sets that
key on any of the 250 encounter dicts it builds. `_chapter_mechanics(chapter, is_great_boss)`
computes the flag correctly for its own use, so Great Bosses still get their three-mechanic
band; it is only the hardcoded phase-2 specials that never fire.

Deliberately **left unfixed** rather than changed silently, because wiring it up makes all five
Great Bosses meaningfully harder and could push the balance wall below the documented stage-170
floor (it currently sits at stage 199 — chapter 40). It is also less urgent now than it was:
the ten authored boss mechanics give those bosses their own phase-2 behaviour via
`phase2_threshold` in their `ENEMIES` mechanics dicts, so they are no longer mechanically bare.

To resolve: set `"is_great_boss": is_great_boss` in `_build_encounters()`'s encounter literal,
then re-run the **full** `./run_tests.sh --balance` and confirm the wall stays at or above
stage 170. `tests/boss_mechanics_test.gd` already asserts the no-double-application guard
between the hardcoded path and the authored `phase2_damage_boost`, so the boost will not be
counted twice whichever way this is decided.

Also worth knowing: `game_map_screen.gd` had a bare undeclared `profile` (should be
`g.profile`) that broke parsing for the whole UI layer, and `combat.gd` had escaped quotes
inside its `state` dict literal. Both were parse errors, i.e. the kind that a compile-only
check catches in one second — but only if something actually loads the project. A single-file
`--check-only` does **not** (it cannot resolve the cross-script `SpiritContent` type). Use the
full suite.

1. **Never touch `combat.gd` with UI/Node code** — strictly headless.
2. **Always update both `zh-Hans` and `en` in `content.gd:UI_TEXT`**.
3. **Run `./run_tests.sh` before every commit** — must pass with 0 failures.
4. **Deploy to physical iPhone via `./deploy_ios.sh`**.
