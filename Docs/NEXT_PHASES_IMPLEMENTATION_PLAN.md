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

## Verification & Deployment Guidelines for Successor Agents
1. **Never touch `combat.gd` with UI/Node code** — strictly headless.
2. **Always update both `zh-Hans` and `en` in `content.gd:UI_TEXT`**.
3. **Run `./run_tests.sh` before every commit** — must pass with 0 failures.
4. **Deploy to physical iPhone via `./deploy_ios.sh`**.
