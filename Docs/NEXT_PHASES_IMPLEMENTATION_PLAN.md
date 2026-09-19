# Next Phases Implementation Plan: Spiritbound Post-Launch Roadmap

This implementation plan lays out the next sequential phases of Spiritbound development, prioritized by **Impact / Effort Ratio** without requiring external backend servers. Any successor agent can immediately pick up **Phase 7** or subsequent phases following the repository standards.

---

## Completed Phases Reference
- ✅ **Phase 1**: Dynamic Encounter Mechanics & Boss Modifiers
- ✅ **Phase 2**: Compendium Mastery Milestones & Bestiary Lore
- ✅ **Phase 3**: Endless Abyss Mode Expansion & Modifiers
- ✅ **Phase 4**: Equipment Reforging & Inscription System (器灵重铸与灵纹洗练)
- ✅ **Phase 5**: Dynamic Relic Synergies & Combo Resonance (法宝共鸣系统)
- ✅ **Phase 6**: Career Codex & Player Statistics Dashboard (旅者典籍) — done 2026-09-19. Added
  as a `career` tab in Compendium (8 tabs total now, not the 4 this plan originally assumed —
  cards/gear/runes/relics/bestiary/achievements/chronicle already existed). `profile.
  career_stats` deliberately does NOT duplicate victories/total damage/total gold/highest Abyss
  floor, which already live in `lifetime_stats`/`abyss_record` — only tracks what nothing else
  did: win/loss streaks, per-battle shield/cards totals, favorite hero/cards, and a 3-entry
  Hall of Fame of Great Boss kills (most recent 3, not score-ranked — see the section below for
  why). Tracking hooks: `game._track_career_win()` (called once from the top of
  `_grant_stage_rewards()`, covering all 7 win paths uniformly) and `game._track_career_defeat()`/
  `_track_career_retreat()` (called from `_leave_battle()`, which — per AGENTS.md's own trap
  entry on this function — only ever fires for a loss or manual retreat, never a win, so there's
  no double-counting risk between the two hook points). See `Docs/GROWTH_ROADMAP.md`'s progress
  log for the full account, including a real test-pollution bug this phase's own testing caught
  and fixed (simulating a Great Boss win through the real reward pipeline rolls a real random
  relic into the profile, same as a real player would get).

---

## Phase 7: New Combat Keywords — Retain, Echo, Overload (新战斗词条系统)
**Impact: High | Effort: Medium | Backend: None**

### 1. Goal Description
Expand combat depth and card variety by introducing 3 core keywords that create novel deckbuilding strategies:
1. **留存 (Retain)**: The card is not discarded at the end of turn, remaining in hand until played.
2. **灵响 (Echo)**: When played, queues an echo of its primary effect to cast for free at the start of the next player turn.
3. **过载 (Overload)**: Provides an immediate explosive tempo effect (e.g. 0-cost or high power) but reduces maximum energy on the subsequent turn.

### 2. Combat Rules Integration (`combat.gd`)
- `end_turn()`: Retain cards stay in hand while other cards go to discard pile.
- `start_turn()`: Drains `state.echo_queue`, firing queued abilities before normal play.
- Overload counter reduces turn energy formula: `max(1, base_energy - state.overload_pending)`.

### 3. Content Additions (`content.gd`, `core.json`)
- Add 6 new cards (2 for each keyword) across elemental classes.
- Add visual keyword tooltips and glowing badge frames.

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
