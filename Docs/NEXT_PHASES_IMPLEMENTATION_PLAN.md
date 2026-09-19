# Next Phases Implementation Plan: Spiritbound Post-Launch Roadmap

This implementation plan lays out the next sequential phases of Spiritbound development, prioritized by **Impact / Effort Ratio** without requiring external backend servers. Any successor agent can immediately pick up **Phase 10** or subsequent phases following the repository standards.

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

---

## Phase 10: Battle Recap Share Card Generator (战报画卷 / 社交分享)
**Impact: High | Effort: Medium | Backend: None**

### 1. Goal Description
Off-screen `SubViewport` screenshot generator rendering a high-aesthetic 9:16 recap poster (Hero portrait, Boss defeated, turns taken, deck build, and QR code) after Great Boss defeats and Abyss milestones.

---

## Verification & Deployment Guidelines for Successor Agents
1. **Never touch `combat.gd` with UI/Node code** — strictly headless.
2. **Always update both `zh-Hans` and `en` in `content.gd:UI_TEXT`**.
3. **Run `./run_tests.sh` before every commit** — must pass with 0 failures.
4. **Deploy to physical iPhone via `./deploy_ios.sh`**.
