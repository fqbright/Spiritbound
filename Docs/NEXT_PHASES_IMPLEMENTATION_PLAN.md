# Next Phases Implementation Plan: Spiritbound Post-Launch Roadmap

This implementation plan lays out the next sequential phases of Spiritbound development, prioritized by **Impact / Effort Ratio** without requiring external backend servers. Any successor agent can immediately pick up **Phase 8** or subsequent phases following the repository standards.

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
  (回旋)**/**Reverb (余韵)**/**Overload (过载)** — the plan's "Retain"/"Echo" names were renamed
  (Retain would be a no-op in a game with no end-of-turn discard; Echo collides with the
  pre-existing "echo" rune) — plus 6 new cards, 2 per keyword. Found and fixed 2 pre-existing
  bugs along the way (the keyword-pill tooltip never read `card.special`'s real top-level shape;
  a stale `collect_all` achievement literal) and one live game-balance gap that adding content
  exposed (`_card_build_score()`'s shield weighting, since a bigger card pool reshuffles every
  downstream RNG-seeded roll in `balance_probe.gd`'s 250-stage regression check). See
  `Docs/GROWTH_ROADMAP.md`'s progress log for the full account.

---

## Phase 8: Mutator & "Curse Run" Challenge Mode (咒缚流局 / 词缀挑战)
**Impact: Medium-High | Effort: Medium | Backend: None**

### 1. Goal Description
Provide high-level players (unlocked at Ascension 2+) with 10 opt-in run mutators that alter fundamental game rules for higher challenge and prestige badges:
- **Glass Cannon (脆刃)**: Max HP capped at 30, all attack damage +50%.
- **Energy Famine (灵力枯竭)**: Energy capped at 2 every turn.
- **Mirror World (颠倒乾坤)**: Swap Player and Enemy starting HP.
- **Haunted Deck (百鬼夜行)**: At each rest site, 1 random card turns into a spectral curse.
- **Draft Only (灵火轮选)**: All card rewards follow 3-pick-1 Spirit Draft rules.

### 2. UI & Camp Integration
- Camp Challenges tab gets a "咒缚挑战 (Curse Modifiers)" selector.
- Mutator run completion yields exclusive cosmetic badges and titles.

---

## Phase 9: Seasonal World Events & Rotating Modifiers (限时世界活动)
**Impact: High | Effort: Medium-High | Backend: None (Local Deterministic Calendar)**

### 1. Goal Description
Rotating 4-week thematic world events (e.g. "Season of the Ember Lord") with unique stage route modifiers, limited challenge nodes, and cosmetic seasonal rewards.

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
