# Growth Roadmap

Tracks every recommendation from the "灵界拓展手记" growth-research report (2026-09-15,
https://claude.ai/artifact/7W6TF1vQ4j3ji7a8HWpi1B) — new-user onboarding, daily/weekly
retention loops, meta-progression, gameplay depth, social, and UI polish.

**This file is the handoff document.** Whoever (human or agent) picks this up next: read the
"Progress Log" at the bottom first for the most recent state, then work top-down through the
unchecked items below. Items are ordered by impact tier (high → medium-high → medium →
medium-low), with effort as a tiebreaker inside a tier. Do not reorder items once started —
append notes instead, so the ordering itself stays a reliable record of intent.

## Execution discipline (same as every prior milestone)

```bash
godot --headless --path Godot/ --script res://tests/test_runner.gd   # rules
godot --headless --path Godot/ --script res://tests/ui_smoke.gd      # screens + combat turn
```

Both must pass with 0 failures before a commit. Rules changes get a `test_runner.gd`
assertion; screen changes get a `ui_smoke.gd` assertion (AGENTS.md rule 3). Commit after each
completed, verified item (or a small tightly-related group) — do not batch unrelated items
into one commit, since quota can run out mid-session and a smaller commit is a cleaner handoff
point. Update this file's checkbox and add a one-line note in the same commit.

If a headless run seems to hang instead of finishing in a few seconds, suspect a compile error
(a missing function, a bad type annotation) before suspecting an infinite loop — see AGENTS.md's
"A missing function is a silent, permanent hang here, not a crash."

---

## High impact

- `[x]` **A1 — 首战互动教程 (first-battle tutorial)** — done 2026-09-15
  Implemented as a 4-step slide carousel (`_show_battle_tutorial()`/`_render_tutorial_step()`
  in game.gd) shown once, gated on `profile.tutorial_seen` and `index == 0`, triggered from
  `begin_battle()`. NOT gated on the player actually performing each action — see the note
  below on why. Content: hand/energy, drag-to-target, auto-end-turn, rewards/growth.
  *Built on:* `_modal_backdrop()` (exactly as AGENTS.md's documented pattern), the
  `_button()`/`_panel()` primitives. 4 new checks in `ui_smoke.gd`'s `== first-battle
  tutorial ==` section; both suites 0 failures.
- `[x]` **B1 — 累积型登录奖励 (rolling weekly login reward)** — done 2026-09-15
  `profile.login_reward: {week, days: [], claimed: []}`; `_ensure_login_reward_current()`
  (called from `_ready()`) logs today's day-index at most once per day, resets on a new week,
  never on a missed day mid-week. 3 tiers (`SpiritContent.LOGIN_REWARD_TIERS`: 3/5/7 days →
  30/60/100 gold). Placed as a new section at the top of `show_quests()` — not Camp — since it
  belongs with the other "commissions" mentally and Camp is already crowded (see F1's note).
  `_has_claimable_quest()` (drives the map's QuestButton red dot) extended to also check
  login-reward tiers, so it's discoverable without opening Quests speculatively.
  *Built on:* `_quest_section()`'s row layout, `_stat_bar()`, the day/week-boundary pattern
  already in `_ensure_quests_current()`. 189/0 rules (unaffected), UI smoke +7 checks, 0
  failures.
- `[x]` **C1 — 成就系统 (achievements)** — done 2026-09-15
  22 bilingual achievements across combat totals, gold, chests, shop purchases, rune plays,
  card/relic collection, mastery level, abyss depth, daily trial badges, and Compendium %.
  `content.ACHIEVEMENTS` (each a `kind` + either a `stat` key or nothing) + new
  `profile.lifetime_stats: Dictionary` (a permanent counterpart to the period-scoped
  daily/weekly quest progress, bumped in `_advance_quest()` itself — no new event-hook call
  sites needed anywhere in combat/reward code) + `profile.achievements_unlocked: Dictionary`.
  6th tab ("成就") added to the Compendium's existing `_tab_bar()`, NOT a new screen.
  *Built on:* `_advance_quest()` (extended, not replaced), `show_compendium()`'s tab bar,
  `_stat_bar()`. 189/0 rules unaffected, UI smoke +9 checks, 0 failures.
- `[x]` **F1 — 营地标签页化 (Camp becomes tabs, not one long scroll)** — done 2026-09-15
  Split into 3 tabs via the same `_tab_bar()` already proven in `show_loadout()`/
  `show_compendium()`: "角色" (account + hero archetypes/mastery), "挑战" (Daily Trial +
  Abyss + difficulty ladder), "收藏" (Compendium entry + relics owned). C1 and B1 had already
  landed on Compendium/Quests respectively rather than Camp specifically to avoid making this
  worse before it was fixed — see their progress-log notes.
  *Built on:* `_tab_bar()`; the section-builder functions (`_account_panel()`,
  `_hero_archetypes_section()`, etc.) were reorganized into 3 new composing functions, not
  rewritten. 189/0 rules unaffected. UI smoke: every existing Camp-content assertion had to be
  updated to set `camp_tab` before checking (a label/button that used to always be on screen
  is now on exactly one of 3 tabs) — see the progress log for the one this would have silently
  broken if missed. +5 new checks, 0 failures.
- `[x]` **D3 — 第四英雄流派 (4th hero archetype)** — done 2026-09-15, with one known gap
  **瘴气巫女 / Miasma Witch** (`miasma_witch`): an attrition archetype built around a new
  status, **Poison** (`enemy.poison`) — ticks like Burn (deals its stack count as damage every
  turn) but, unlike Burn, **never decays on its own**; only a heal or a kill clears it. Applied
  via 2 new signature cards (`toxinDart`: 3 damage + 2 poison; `witherTouch`: 4 poison, no
  direct damage) plus a resource-cycling `miasmaBrew` (shield + `recycleDiscard`, an existing
  generic special, not a new one). 25-card starting deck (11 strike/8 ward/3 toxinDart/2
  witherTouch/1 miasmaBrew), 5-level mastery track mirroring fox_spirit's shape (`max_hp` →
  `poison_start` → `first_attack_bonus` → `poison_start` → `first_attack_bonus`), starting
  relic `bloodJade`.
  **Known gap, designated for Human Artist:** no unique human-painted portrait. `character-atlas-v3.png`
  is a fixed 3x3 grid and all 9 cells are already claimed (3 heroes + the shared 5-enemy pool
  + 1 spare). This hero borrows Stone Sentinel's sprite as a placeholder, with an explicit
  directive that **this portrait requires a real human artist to produce (需真人画师出图，非AI生成)**.
  AI agents must NOT attempt to generate this asset. The standalone texture loader in `game.gd`
  (`res://assets/characters/miasma_witch.png`) is prepared to receive the official artwork once
  delivered by the human artist.
  *Built on:* `content.HERO_CLASSES`/`HERO_MASTERY_PERKS` data shape; `_resolve_effects()`'s
  already-fully-generic `"status"` operation needed zero changes to apply Poison — only the
  non-decaying tick line in `combat.gd`'s `end_turn()` and a `poison_start` hero-bonus hook
  (mirroring `burn_start`/`vulnerable_start` exactly) were new. 226/0 rules (+34, mostly a
  per-card 1-cost loop over the new 25-card deck), UI smoke +6 checks, both suites 0 failures.
  **Also found and spun off separately** (not fixed here, tracked as its own session): while
  auditing the card pool, `decay_blight`/`void_curse` (the Milestone-3 curse cards) turned out
  to live only in core.json's dead `"statuses"` array, never in `"cards"` — meaning
  `content.card("decay_blight")` has always silently returned `{}`, so a curse card drawn into
  a real hand would render with the wrong color and no description. Combat math is unaffected
  (combat.gd checks card_id strings directly, never `content.card()`), which is why no test
  caught it. Out of scope for D3; a separate task was spawned for it.

## Medium-high impact

- `[x]` **D1 — 卡牌协同标签可视化 (on-card synergy tags)** — done 2026-09-15
  `_card_synergy_tags(card)` derives glyphs (🔥burn ☣poison 💢vulnerable 🌀weak 💪strength
  🃏draw ⚔cleave ✹critical) straight from a card's own `effects`/`special` every call, rather
  than hand-authoring a separate `tags` field the report originally sketched — a derived
  function can never drift out of sync with what the card actually does, which a stored data
  field could. Only tags that map to a real existing system are included (a rune set, a hero
  mastery perk, or "hits every enemy" for elite/add-heavy fights) — plain damage/shield/heal
  aren't synergy signals, they're just what most cards do, so they're deliberately excluded.
  Wired into the shared `_kind_element_line()` helper, which replaced 5 duplicated inline
  `"%s · %s" % [kind, element]` label calls across `_big_card_face`, `_card_view`,
  `_pile_card_tile`, `_shop_card_tile`, and `_deck_card_tile` — the deck builder and shop were
  the two the report's own framing cared about most ("recognize synergy while building a
  deck"), the other three came along for free once the line was shared. Left `show_deck_purge`/
  `show_deck_upgrade` (which show kind+rarity, not kind+element — a different line entirely)
  and the Compendium's card tab untouched for this pass; a future pass could extend
  `_kind_element_line()` or a sibling helper to those without new design work.
  *Built on:* `content.gd` card `effects`/`special` data (no schema change). 226/0 rules
  unaffected (this is 100% a game.gd rendering concern — correctly zero rules-engine change),
  UI smoke +5 checks, 0 failures.
- `[ ]` **B4 — 本地推送提醒 (local iOS notifications)**
  Remind players when a login-streak day or daily quest is about to expire. **Needs a native
  iOS bridge** (Godot has no built-in local-notification API) — likely a small GDExtension or
  a plugin. Flag for a dedicated investigation spike before committing to an implementation
  approach; this is the one item in this list that may need a design decision from the human
  before an agent should just start coding it.
  *Builds on:* nothing yet — new native surface.
- `[x]` **C2 — 轮回 / New Game+ 机制 (Samsara Reincarnation Prestige)** — done 2026-09-17
  Comprehensive prestige layer unlocked after clearing all 250 stages or Ascension 5:
  - **Rebirth & Heritage**: resets campaign progress (`unlocked = 0`, `position = 0`, `claimed_stage_events = []`) while permanently preserving all card collections, upgrades, equipment, runes, relics, masteries, currencies (Gold, Jade, Dust, Stamina), and achievements.
  - **Samsara Blessings (`content.samsara_bonuses()`)**: scaling permanent combat perks per rebirth level:
    - Lv 1 ("凡蜕化灵"): +6 Max HP, +50 Gold heritage.
    - Lv 2 ("太虚凝气"): +4 Starting Shield in every battle.
    - Lv 3 ("灵机顿悟"): +1 Card Draw on Turn 1.
    - Lv 4+ ("九转登仙"): +4 Max HP and +2 Starting Shield per additional tier.
  - **New Ascension Tier A6 ("万劫归一 / Cataclysm")**: Enemies have +25% HP and start with 2 Strength. Unlocked once reincarnated at least once (`samsara_count >= 1`).
  - **Samsara Section & Modal**: `_samsara_section()` in Camp Challenges tab displaying current realm title (`content.samsara_title()`) and active blessings, with `show_samsara_modal()` explaining preserved assets vs. resets.
  - **Achievement**: Added "轮回证道" (`samsara1`) platinum achievement.
  *Built on:* `content.samsara_bonuses()`, `game.enter_samsara()`, `show_samsara_modal()`, `_samsara_section()`.
- `[x]` **D4 — 大首领专属机制 (unique Great Boss phase mechanics)** — done 2026-09-15
  Each of the 5 Great Bosses (Chapters 10, 20, 30, 40, 50 at Stage 50, 100, 150, 200, 250)
  features a unique scripted Phase 2 transition when HP falls below 50%:
  - Ch. 10 (Ember Lord): "Ember Berserk" (+4 damage, clears burn and becomes burn-immune, ignites player with 3 burn).
  - Ch. 20 (Frost Titan): "Glacial Bastion" (+25 shield, gains frost_armor=2 reducing all incoming hit damage by 2).
  - Ch. 30 (Shadow Sovereign): "Shadow Legion" (inflicts 2 Vulnerable on player, summons Shadow Clone add).
  - Ch. 40 (Gale Wyrm): "Cyclone Domain" (gains dodge_every=2, inflicts 2 Weak on player).
  - Ch. 50 (Abyssal Primordial): "Abyssal Awakening" (cleanses all debuffs, drains 6 HP from player, shuffles Void Curse into player's draw pile).
  Displays animated cinematic `BossPhaseBanner` during battle. 247/0 rules (+20 checks), UI smoke passing.
  *Built on:* `combat.gd`'s `_trigger_great_boss_phase_2()`, `BossPhaseBanner` in `game.gd`.

## Medium impact

- `[x]` **A2 — 渐进式营地解锁** — done 2026-09-15
  Camp features are progressively unlocked based on `profile.unlocked` campaign progress:
  - Compendium & Daily Trial: unlocked after Chapter 1 (`unlocked >= 5`).
  - Endless Abyss: unlocked after Chapter 2 (`unlocked >= 10`).
  - Ascension Difficulty Tiers: unlocked after Chapter 5 (`unlocked >= 25`).
  *Builds on:* `_compendium_section()`, `_daily_trial_section()`, `_abyss_section()`, `_difficulty_tier_section()`.
- `[x]` **A3 — 首胜战报回顾** — done 2026-09-15
  Added `VictoryRecapCard` in `show_reward_details()` for early victory stages (`current_stage < 3`
  or `unlocked <= 3`). Displays damage dealt, cards played, and shields gained tracked via `combat.state.stats`.
  *Builds on:* `combat.state.stats`, `show_reward_details()`.
- `[x]` **A4 — 新手推荐流派标记** — done 2026-09-15
  Tagged Fox Spirit with `BeginnerRecBadge` ("✦ 新手推荐") and explanatory text highlighting
  generous energy and steady burst damage in `_hero_archetypes_section()`.
  *Builds on:* `_hero_archetypes_section()`.
- `[x]` **B2 — 每日试炼连续通关奖励** — done 2026-09-15
  Added `streak` and `streak_claimed` to `profile.daily_trial_record`. Tracks consecutive
  days of clearing the 15-stage daily trial; grants bonus gold at 3-day (100g), 7-day (250g),
  and 14-day (500g) streaks. Displayed in the daily trial stats row.
  *Builds on:* `profile.daily_trial_record`.
- `[x]` **B3 — 每周主题挑战** — done 2026-09-15
  An 8-stage gauntlet (`SpiritContent.WEEKLY_CHALLENGE_STAGES`) resetting on a `WEEK_SECONDS`
  boundary (`_ensure_weekly_challenge_current()`), seeded the same deterministic-per-period way
  as the Daily Trial but drawing exactly one themed tag per week instead of a combined trio
  (`content.weekly_challenge_tag()`/`WEEKLY_CHALLENGE_TAGS`: Iron Horde/Savage Tide/Twin Pack/
  Bounty Week). Rendered via `_weekly_challenge_section()` in Camp's Challenges tab, right below
  the Daily Trial; gated behind the same `unlocked >= 5` (Chapter 1) threshold as Daily Trial/
  Compendium. `reward_mult` (Bounty Week's tag) isn't a `combat.gd` key — nothing there reads
  gold — so it's applied directly in `_grant_stage_rewards()`'s new `in_weekly_challenge` branch,
  the same way campaign `reward_scale` already works.
  *Builds on:* `content.daily_trial_tags()`'s deterministic-seed pattern, `_shuffled_indices()`.
- `[x]` **C3 — 图鉴里程碑奖励** — done 2026-09-15
  Added `CompendiumMilestonesBar` in `show_compendium()`. Tracks collection progress across
  cards, equipment, runes, relics, and bestiary. Grants gold and exclusive milestone rewards
  upon reaching 50% (150 gold), 80% (350 gold), and 100% (800 gold + exclusive achievement).
  Claim state persisted in `profile.compendium_milestones_claimed`.
  *Builds on:* `_compendium_totals()`.
- `[x]` **D2 — 重复关卡词条化** — done 2026-09-15
  Tapping an already-cleared stage pin opens `_show_replay_mode_prompt()`, offering choice between
  Standard Replay (half gold, no drops) and Trial Replay (hard affix modifier + restores 100% gold
  rewards and item/equipment drops). Supported via `begin_hard_replay(index)` and `is_hard_replay`.
  *Builds on:* `_show_replay_mode_prompt()`, `begin_hard_replay()`.
- `[x]` **E1 — 试炼历史走势图 (local-only)** — done 2026-09-15
  A simple vertical-bar trend line of `daily_trial_record.best_stage` over recent days (`DailyTrialTrendChart` in `game_camp_screen.gd`). Purely local data, bounded to `DAILY_TRIAL_HISTORY_LIMIT` entries via `_ensure_daily_trial_current()`.
  *Builds on:* `daily_trial_record.history`, `_daily_trial_trend_chart()`.
- `[x]` **E2 — 战报分享卡片 (local-only)** — done 2026-09-15
  Composed screenshot-friendly `RunRecapCard` for Great Boss victories rendered client-side via `show_run_recap()` in `game_rewards_screen.gd`. Surfaces hero portrait, damage dealt, cards played, shields gained, deck highlights, and share hint.
  *Builds on:* `combat.state.stats`, `show_run_recap()`.
- `[x]` **F2 — 独立设置页面** — done 2026-09-15
  Consolidated settings into dedicated `show_settings()` modal accessible via `SettingsButton` (gear ⚙)
  in map top bar and Camp. Configures language, battle speed (1.0x / 1.5x / 2.0x), audio mute, and
  accessibility "reduce motion" (`profile.reduce_motion: bool`), automatically disabling map particles.
  *Builds on:* `show_settings()`, `SettingsButton`, `profile.reduce_motion`.

## Medium-low impact

- `[x]` **C4 — 图鉴首杀额外奖励** — done 2026-09-15
  `_mark_discovered()` now returns whether the entry was newly discovered (was `void`); every
  `_mark_discovered("bestiary", ...)` call site (campaign, Abyss, Daily Trial, Weekly Challenge)
  checks that return and calls `_grant_bestiary_discovery_bonus(encounter)` on a true result:
  +20 gold, +6 mastery XP, and a toast naming the enemy. Since all of these call sites fire at
  battle *start* (not on a win), this reads to the player as "first time facing this foe," not
  literally a kill — matching what the codebase actually tracks rather than adding new
  first-defeat state.
  *Builds on:* the `_mark_discovered("bestiary", ...)` call sites added in Milestone 4.
- `[x]` **F3 — 卡组构筑搜索与筛选** — done 2026-09-15
  Integrated `DeckSearchInput` (text search by name, id, and rules text), `DeckKindChips`
  (All, Attack, Skill, Power, Tactic), and `DeckElementChips` (All, Neutral, Fire, Gale, Stone,
  Water, Poison) in `show_deck()`. Real-time multi-criteria filtering over card collection.
  *Builds on:* `show_deck()`.
- `[x]` **F4 — 色觉友好的状态图标** — done 2026-09-15
  Equipped all combat status chips with distinct geometric silhouettes: Shield (⬢ Hexagon),
  Burn (▲ Up-Triangle), Poison (◆ Diamond), Vulnerable (▼ Down-Triangle), Weak (● Circle),
  Stun (✸ Burst), Strength (★ Star), Focus (◉ Bullseye). Colorblind and grayscale friendly.
  *Builds on:* `_status_chip()`, unit status rows.

## Unblocked via Supabase — Cloud Save & Auth Live

- `[x]` **E3 (Part 1) — Supabase 云端多方式登录与双向云存档**
  - 集成 Supabase REST API & Auth: 邮箱密码登录/注册、一键免密设备登录、Apple / Google 第三方 ID Token 认证。
  - 双向云存档同步 (`public.player_saves`): 时间戳自动比对与冲突消解、Token 自动刷新重试、离线沙盒安全回退。
- `[ ]` **E3 (Part 2) — 好友排行榜** (待后续增加 `public.leaderboards` 表)
- `[ ]` **E4 — 异步"幽灵对战"**
  Recorded-run AI opponents need a backend to store and serve run recordings. Same blocker as
  E3; sequence after it, not before.

---

## Progress Log

Append newest entries at the top. Each entry: date, what changed, why, anything the next
agent needs to know that isn't obvious from the diff.

### 2026-09-17 — 10-Second Cinematic Opening Intro with Skip Functionality
Designed and implemented an epic, real-time procedural 10-second opening cinematic cutscene:
- **Real-Time Cinematic Cutscene (`Godot/scripts/game_intro_cutscene.gd`)**:
  - Zero-bloat, retina 60/120fps procedural presentation tailored for 390x844 mobile viewport.
  - Four distinct cinematic movements:
    - Act I (0-2.5s): Primordial chaos with swirling spirit embers (`CPUParticles2D`).
    - Act II (2.5-5.5s): Dual-layered rotating ancient runic circle with exploding shockwave seal burst.
    - Act III (5.5-8.0s): Fox Spirit avatar emergence with orbiting spirit orbs and breathing luminescence.
    - Act IV (8.0-10.0s): Majestic golden "SPIRITBOUND / 灵界之契" title card slam and subtitle.
  - Elegant top-right Skip button (`IntroSkipBtn`) with live countdown (`跳过 10s ⏭`, `跳过 9s ⏭` ... `跳过 ⏭`).
  - Smooth fade-to-black transition with audio crossfade.
- **Game Lifecycle & Settings Integration (`Godot/scripts/game.gd`)**:
  - Plays automatically on first launch (`profile.intro_seen = false`) for real players, then smoothly transitions to map or account creation.
  - Replay button (`ReplayIntroBtn`) added in Settings menu ("重播开场动画 / Replay Intro Video").
- **Verification & Test Coverage**:
  - Unit tests in `Godot/tests/test_runner.gd` verifying `intro_seen` defaults and bilingual strings.
  - UI smoke tests in `Godot/tests/ui_smoke.gd` verifying `play_intro_cutscene()`, `IntroSkipBtn` presence, click execution, and clean disposal.
  - All 6 test suites passed cleanly with 0 failures.

### 2026-09-17 — Supabase Multi-Provider Auth & Two-Way Cloud Save Sync
Integrated Supabase backend for multi-method authentication and cloud save synchronization:
- **Supabase REST & Auth Client (`Godot/scripts/supabase_client.gd`)**:
  - Direct integration with Supabase Auth (`/auth/v1/signup`, `/auth/v1/token?grant_type=password`, `/auth/v1/token?grant_type=id_token`, `/auth/v1/token?grant_type=refresh_token`, `/auth/v1/recover`, `/auth/v1/logout`).
  - Persistent session management (`user://spiritbound_session.json`) with auto-refresh on HTTP 401 token expiry.
  - PostgREST database client for `public.player_saves` with upsert (`Prefer: resolution=merge-duplicates`) and timestamp-based conflict resolution.
- **Unified Authentication Service (`Godot/scripts/auth_service.gd`)**:
  - `sign_in_with_supabase()`, `sign_up_with_supabase()`, `reset_password()`, `sign_in_with_apple()`, `sign_in_with_google()`, and `sync_cloud_save()`.
  - Automatic two-way cloud sync: pulls remote save, compares `updated_at`, merges/downloads if newer, or uploads local progress if newer.
- **In-Game Auth UI & Modals (`Godot/scripts/game.gd`)**:
  - `show_auth_modal()`: Tabbed interface for Email Login and Registration, LineEdit inputs with password masking, error/hint notifications, rate limit awareness, quick Apple & Google OAuth buttons, password recovery prompt.
  - Start Screen & Settings Modal enhancements: "邮箱登录" button on initial account setup, "账号与云端同步" modal trigger in Settings, linked account badge, "立即同步到云端", and "退出账号".
- **Comprehensive Automated Test Coverage**:
  - Unit tests in `Godot/tests/test_runner.gd` for session storage, token helpers, account link/unlink, and Supabase provider states.
  - UI smoke tests in `Godot/tests/ui_smoke.gd` for modal opening, tab toggling, field visibility, and clean dismissal.
  - All 6 test suites passed cleanly with 0 failures.

### 2026-09-17 — C2 Samsara Reincarnation Prestige System & Roadmap Sync
Implemented C2 from the Growth Roadmap and synchronized roadmap tracking for previously built items (E1, E2):
- **Samsara / Reincarnation Prestige System (`profile.samsara_count`)**:
  - Gated behind clearing Chapter 50 (unlocked >= 249) or Ascension 5.
  - Rebirth (`game.enter_samsara()`): resets stage progression (`unlocked = 0`, `position = 0`, `claimed_stage_events = []`) while preserving all card collections, card upgrades, runes, equipment inventory, relics, hero masteries, currencies (Gold, Spirit Jade, Spirit Dust, Stamina), and achievements.
  - Permanent Combat Perks (`content.samsara_bonuses()`):
    - Lv 1: "凡蜕化灵" (+6 Max HP, +50 Rebirth Gold).
    - Lv 2: "太虚凝气" (+4 Starting Shield in every combat).
    - Lv 3: "灵机顿悟" (+1 Card Draw on Turn 1).
    - Lv 4+: "九转登仙" (+4 Max HP & +2 Starting Shield per additional reincarnation).
  - Unlocks Ascension **A6** ("万劫归一 / Cataclysm"): Enemies have +25% HP and start with 2 Strength. Available in Camp difficulty ladder once reincarnated.
  - UI & Modal: Added `_samsara_section()` in Camp Challenges tab and atmospheric `show_samsara_modal()` explaining preserved assets and rebirth rewards.
  - Achievement: "轮回证道" (`samsara1`) added to `content.ACHIEVEMENTS` and evaluated in `_achievement_progress()`.
  - Roadmap Sync: Ticked checkboxes for E1 (Daily Trial Trend Chart) and E2 (Run Recap Card) which were verified active in code.
- **Verification**: `test_runner.gd` (374 checks, 0 failures) and `ui_smoke.gd` (all checks passed) verified green.

### 2026-09-17 — Strategic Depth (Elemental Resonance), Auto-Battle Idle Progression, and Stamina System
Implemented directly per user direction to deepen combat strategy, prevent infinite brute-force grinding, and provide auto-battle idle progression:
- **Strategic Depth (五行元素共鸣 / Elemental Resonance)**:
  - Sequenced elemental card plays trigger powerful resonant chain reactions:
    - **Combustion (灵火燎原, Fire + Spirit/Gale)**: Deals 3 splash damage to all other living enemies.
    - **Sunder (破甲震荡, Water + Stone/Poison)**: Destroys up to 5 enemy shield and inflicts 1 Vulnerable.
    - **Fortify (金石磐石, Stone + Spirit/Stone)**: Grants player +4 bonus Shield.
  - Sequenced combat events are dispatched via `resonance` signals and tracked on `state.last_element`.
- **Stamina / Spiritual Energy System (灵元气海 / `profile.stamina`)**:
  - `current: 100, max: 100`, naturally regenerates 1 point every 300s (5 minutes).
  - Campaign stage entry costs 5 Stamina. Insufficient stamina blocks battle and opens the Stamina Modal.
  - Supports rapid recharge with Spirit Jade (10 Jade -> +50 Stamina, capped at 150).
  - Prominent Stamina Pill (⚡) in the top HUD and Treasury Inspector with live countdown to next regen.
- **Auto-Battle & Idle Progression System (一键挂机推图)**:
  - Intelligent heuristic card & target evaluation (`combat.ai_best_play()`): prioritizes survival shields when threatened, executes low-HP targets, plays zero-cost powers/buffs, and exploits elemental resonance.
  - Full automated loop: auto-plays combat -> auto-claims chest -> auto-selects best card -> checks stamina -> hops to next node -> loops until defeat or stamina depletion.
  - Safe termination: automatically halts on combat defeat, stamina exhaustion, or manual toggle, with a complete progress toast summary.
  - Accessible via `AutoBattleToggle` button in battle top bar and `MapAutoPushBtn` on the map action rail.
- **Verification**: `test_runner.gd` (351 checks, 0 failures) and `ui_smoke.gd` (all checks passed) verified green.

### 2026-09-17 — 7-Day Novice Journey, Store Consumables & Specialties, Treasury Inspector, Contextual Tutorials, and Retention Loops
Implemented directly per user direction to expand merchandise, optimize multi-currency utility, boost novice retention, and complete onboarding tutorials:
- **7-Day Novice Journey (`profile.novice_journey`)**: Progressive 7-stage milestone track embedded in `show_quests()` rewarding large amounts of Gold, Spirit Jade, and Spirit Dust. Unlocked milestones are surfaced in the Map Digest summary card.
- **Store Consumables & Specialties Shelf (`SpiritContent.STORE_CONSUMABLES`)**:
  - `elixir_vitality`: Recovers 25 HP immediately upon purchase.
  - `elixir_might`: Pre-battle potion granting +2 Strength on turn 1.
  - `elixir_focus`: Pre-battle potion granting +1 Energy and +1 Focus on turn 1.
  - `upgrade_stone`: Direct consumable opening the Deck Upgrade screen to upgrade any owned card.
  - `dust_ore`: Alchemy resource converting 80 Gold into 35 Spirit Dust.
  - All consumable starting bonuses (`strength_start`, `focus_start`, `draw_turn1`) integrate directly into `combat.gd:create()` and auto-clear upon battle start in `game_rewards_screen.gd`.
- **Treasury Inspector & Currency Ledger (`show_treasury_inspector()`)**:
  - Currency pill in the top header is now clickable, opening a comprehensive breakdown of Gold, Spirit Jade, and Spirit Dust with current utility rules and fast conversions (e.g. Jade -> Gold, Gold -> Dust).
- **Daily First Win & Boss Jade Drops**:
  - Added `daily_first_win` (+50 Gold, +5 Jade on first battle win each day).
  - Bosses and Great Bosses now reward bonus Spirit Jade (+10 and +20 respectively).
- **Contextual Onboarding Tutorials**:
  - `shop_overview`: Explains curated daily cards, alchemy, and specialty elixirs when first entering the Shop.
  - `deck_synergies`: Guides archetype synergies and deck upgrades upon first opening the Deck screen.
  - `combat_survival`: Emergency survival guide triggered during battle when player HP drops to 25 or below.
- **Verification**: Both `test_runner.gd` (341 checks, 0 failures) and `ui_smoke.gd` (all checks passed) verified green.

### 2026-09-16 — Off-roadmap batch: battle VFX/rig overhaul, map redesign, AFK Harvest, Phantom
### Arena, HP-reset rule change; plus doc-drift fixes and 2 bug fixes found reviewing it
None of this maps to an existing lettered item above — it landed as 12 commits with empty
commit bodies, and this file wasn't updated as it went in, which is why this entry exists
after the fact rather than checkboxes moving to `[x]` in place. Recording it now so it isn't
lost like the others already found un-logged in this same review pass.

**What shipped** (not implemented by whoever is reading this entry — reviewed and partly
fixed by the next agent, see below): a diagonal battle formation with a fox-specific layered
rig (body/tail/orb/ground-aura, each with its own secondary-motion tween) and a card-play VFX
chain (shield unfold → character-attach → barrier ring; heal bloom; buff pillar; attack slash)
dispatched by effect category, not hero or element; Cinzel+WenKai fonts (see AGENTS.md); a
single-chapter map view replacing the old scrollable 50-chapter strip, with a realm-transition
cutscene on clearing a chapter and the 5 in-chapter waypoints reordered bottom-to-top (see
AGENTS.md's Map section for both); AFK Harvest and Phantom Arena (see AGENTS.md); a
defeat-diagnosis card after a loss with a rule-based tip; and the single biggest rules change
in the batch — every stage, win or lose, now resets `profile.health` to a flat 60, removing
the inter-battle healing/attrition the tuned difficulty curve was originally validated against
(Docs/ARCHITECTURE.md's "250-stage difficulty curve" section now documents this gap directly).

**Reviewed 2026-09-16, user consulted on the two genuinely ambiguous calls**:
- **HP-reset-to-60-every-battle: user chose to keep it as-is.** Not reverted. Docs/
  ARCHITECTURE.md updated to say plainly that the curve's tuning premise no longer holds and
  hasn't been revalidated, rather than silently continuing to assert something now false.
- **"Cleared stages can't be farmed" copy vs. code mismatch: user chose to make the copy true.**
  The replay-prompt text already claimed this while the Normal/Hard Replay buttons underneath
  still worked exactly as before (commit-message overstatement, not implemented). Fixed by
  actually removing the battle-entry path for an already-cleared stage — see AGENTS.md's new
  bullet on this — and deleting everything that only existed to support the now-impossible
  replay case (`is_hard_replay`, the reward-halving branch, 6 orphaned UI_TEXT strings).

**Bugs found and fixed in this same review pass** (both pre-existing, not introduced by the
12-commit batch itself, but the batch made the first one far more visible and the second one
is unrelated):
- **Battle screen always showed Fox Spirit regardless of the equipped hero.**
  `_build_player_stage()` hardcoded `"fox"` for both the rig gate and the sprite fallback.
  Fixed to key off `content.hero_class(profile.hero_class).sprite`; also fixed the fallback's
  sprite scaling, which assumed a fixed atlas-cell width even for Miasma Witch's standalone
  portrait (wrong pixel size for that texture) — now uses the resolved texture's own
  `get_width()`, matching how the map traveler avatar already handled the same situation.
- **`NotoSansSC.ttf` (17.7MB) looked orphaned by the font swap** (zero script references) but
  was still `project.godot`'s `[gui] theme/custom_font` — a script-only grep misses project
  settings. Repointed that setting to `LXGWWenKai-Medium.ttf` (CJK-capable on its own) first,
  confirmed zero references anywhere, then deleted it. If you're ever about to delete an
  asset because grep found nothing, check `project.godot` too before trusting that.

**Still not addressed, flagged for whoever picks this up next**:
- `show_chapter_transition()` (`game_map_screen.gd`) throws "Cannot call method 'create_tween'
  on a previously freed instance" under `ui_smoke.gd` — a real async race (a tween racing
  against a later `_clear()`), not something introduced by this review's own changes (confirmed
  present before any of this session's edits). It doesn't currently fail a specific `check()`,
  so both suites still report all-green, but the underlying bug is real.
- `diagnose_battle_defeat()`'s `action` field (`"deck"` vs `"cultivate"`) is computed but never
  consumed — the defeat-diagnosis card shows both buttons unconditionally regardless of which
  action was recommended.
- `spirit_curse_seal.png` was painted for this batch's VFX set but never wired to anything —
  the Curse cards (`decay_blight`/`void_curse`) and the enemy "curse" intent still have no
  visual treatment.
- The Fox Spirit rig's 4 textures (`fox_body`/`fox_tail`/`fox_orb`/`ground_aura`) and
  `spirit_shield_crest.png` all ship at 1024×1024 despite rendering at roughly 40-95px on
  screen — worth downscaling for app size/decode cost before this ships anywhere real.
- Of the 12 commits, only 3 touched either test file — the visually biggest ones (the rig, the
  VFX chain, the diagonal layout, all 3 map commits) shipped with zero new assertions, against
  this project's own Rule #3. Both suites currently pass, but that's because nothing added by
  those commits is being checked, not because it was verified against a written assertion.

### 2026-09-15 — game.gd split into 5 composed screen classes (user-requested tech debt)
Not a report item — the user asked for this directly after `game.gd` grew to ~7200 lines
across this session's feature work. Result: `game.gd` (now `class_name SpiritGame`) is down
to 1343 lines (-81%), with the rest in `game_map_screen.gd` (MapScreen), `game_battle_screen.gd`
(BattleScreen), `game_rewards_screen.gd` (RewardsScreen), `game_shop_deck_screen.gd`
(ShopDeckScreen), and `game_camp_screen.gd` (CampScreen), plus 5 already-self-contained nested
UI classes (GameIcon, HandCard, IntentIcon, TouchScrollContainer, DizzyStars) pulled into their
own files first as a zero-risk warm-up. See AGENTS.md's new first "trap" entry for the
composition-pattern mechanics (why composition and not inheritance, the `g.` prefix
convention, and the four specific bug classes that pattern's mechanical extraction produced
— bare `self`, bare engine methods, missing `await` propagation through a delegator, and
`_init()` vs `_ready()` for composition-object construction) — read that before touching any
of these files, since every one of those bug classes compiles/runs fine in the wrong way and
only shows up as a wrong screen or a hung coroutine, not a clear error.
Each of the 6 extraction stages (nested classes, Map, Battle, Rewards, ShopDeck, Camp) was
verified independently: 250/0 rules + full ui_smoke.gd pass, plus a purpose-built corruption
scanner (checks every string literal, every dotted-access site, and every bare reference to
a still-elsewhere game.gd member) run against each new file before wiring its delegators —
and committed separately, so a problem in a later stage never had to be diagnosed against a
pile of unrelated changes. Real bugs the scanner (and, twice, `test_runner.gd`/`ui_smoke.gd`
themselves) caught along the way: a card's `GameIcon.kind = "profile"` string literal
corrupted to `"g.profile"` (a naive find/replace doesn't know it's inside a string); a
`pending_rewards` dict key `"is_hard_replay"` corrupted the same way; `traveler.create_tween()`
and `pin.create_tween()` corrupted to `traveler.g.create_tween()` (a bare-word substitution
doesn't know it's already dotted onto something else — fixed generally with a negative
lookbehind for a preceding `.` on every substitution from the Battle extraction onward);
`isn't`/`doesn't` in comments corrupted to `isn'g.t`/`doesn'g.t` (GDScript's `\b` treats the
trailing "t" in a contraction as its own word — fixed by requiring `t`/`tf` be followed by
`(`, since neither is ever passed as a bare Callable); several bare Callable/signal
references the call-syntax-only dependency scan can't see by construction
(`_cycle_speed`/`_pass_turn` passed to `_button()`, `_combat_event` passed to
`combat.event.connect()`, `show_account_setup`/`show_map` passed to `_header()`) — a
same-file post-hoc scan for every bare occurrence of every other file's members (not just
call-syntax) is now the standard last step, not an afterthought.
The shared card-display helpers (`_card_color`, `_card_description`, `_card_synergy_tags`,
`_kind_element_line`, `_rune_color`, `_unique`) got mechanically swept into the Camp
extraction's range (they sat physically adjacent to `_select_abyss_boon`) and were moved
back out to `game.gd` afterward — every other screen already calls them via `g.`, so leaving
them in CampScreen would have worked, but "CampScreen" is a misleading home for logic with
no connection to camp or quests.

### 2026-09-15 — B3 weekly challenge, C4 bestiary discovery bonus, and a new map "today digest" card shipped
Three items done together in one pass: B3 and C4 from the backlog above, plus a "today digest"
card — not one of the original 24 report items, proposed during this session's own feature
investigation and approved by the user alongside the map-path fix.
- **B3 / C4**: see their own checklist entries above for what shipped and why.
- **Today digest**: `_add_map_digest_banner()` renders a slim dismissible-by-nature (not by a
  button — it just reflects state, same as the two notification dots it summarizes) strip
  right under the map header, e.g. "✦ 2 项奖励待领取", counting ready-to-claim daily/weekly
  quests, login reward tiers, and Compendium milestones in one place — `_claimable_reward_count()`
  is a plain sum over the same three checks `_has_claimable_quest()`/`_has_claimable_camp_reward()`
  already run separately for their respective button dots. Tapping it opens Quests if any
  quest/login reward is ready, else Camp's Collection tab (`_open_map_digest()`) — whichever
  screen actually holds the claim button for what's shown. Hidden entirely when the count is 0,
  so a fully-caught-up player sees nothing extra on the map.
One test-authoring pitfall hit while adding the digest's ui_smoke coverage: the new test block
force-sets `profile.compendium_milestones_claimed` and `profile.login_reward` to get an exact,
predictable count, but an existing *later* section ("milestone 4") asserts the 50% milestone
"starts unclaimed" against whatever the profile still holds — without restoring both fields
afterward, that later assertion failed. Fixed by saving both values immediately before the
digest block and restoring them in the same place the pre-existing `saved_daily`/`saved_weekly`/
etc. restoration already happens — the same "this suite shares one profile across every
section" trap this file's own F1/rail-test entries already flagged, still worth re-stating
because it keeps recurring with each new stateful test block.
Verified 250/0 rules / UI smoke all passing, including 8 new B3 assertions (record reset,
section renders, encounter curve honors the week's own modifier, full 8-stage clear awards
exactly 1 badge, enter button hides once cleared), 2 new C4 assertions (first-sighting bonus
fires once, a repeat encounter grants nothing), and 4 new digest assertions (exact count,
banner+button exist when something's claimable, banner disappears at zero).

### 2026-09-15 — Map path/pins aligned to painted road art, line hidden, fixed-pace travel (user-reported)
Not one of the original 24 report items — user reported the map's stage pins didn't sit on
the actual road painted into each chapter's background art. Root cause: `_chapter_waypoints()`
still used the old `BIOME_PATH_WAYPOINTS` (6 hand-picked point-sets, reused + mirrored across
all 50 chapters) from back when only 6 biome images existed — once every chapter got bespoke
unique art, those 6 shapes stopped corresponding to anything actually painted, and the
`(chapter/6)%2` mirroring flip made half of them wrong in the *opposite* direction on top of
that.
Fix: built a Python (PIL+numpy) image-analysis pipeline against all 50
`assets/chapters/chapter_N.png` files — HSV "pathness" score (`v*(1-s)`, bright+desaturated),
a **per-image percentile threshold** (top ~10%) rather than a fixed one (brightness varies
hugely chapter to chapter), refined with **sequential row-to-row tracking** (each point
prefers the cluster nearest the *previous* point, not image-center) to stop the centerline
jumping to unrelated bright patches — this tracking step was the single biggest accuracy win.
4 chapters needed manual coordinate overrides where the heuristic structurally can't apply:
7 & 18 are abstract dune art with no single distinguishable path; 8 & 26 are lava chapters
where the path is the *darkest* feature against glowing lava, inverting the "bright=path"
assumption. Result spliced in as a new 50-entry `CHAPTER_PATH_WAYPOINTS` const in `game.gd`,
consumed by `_chapter_waypoints()` (now preferring per-chapter waypoints via a new
`_chapter_has_unique_art()` helper, falling back to the old biome system only when a chapter's
art file is actually missing) and by `_add_map_chapter()` (fixed to never flip a chapter with
unique art — the old flip was a leftover from the 6-biome-reuse era that had become actively
harmful).
Per explicit user request, stopped drawing the generic decorative connector line: `road_bed`/
`trail` Line2D nodes in `_add_routes()` are now `.visible = false` (geometry/points still
computed and assigned, just not rendered) since the waypoints now exactly trace the real
painted road and a second drawn line would visually clash with it. The green `walked`
progress line is unaffected.
Also per explicit user request, reworked `_travel_to()`'s animation: was one fixed-duration
tween (0.65s) for the whole trip regardless of distance; now chains one fixed
`TRAVEL_SECONDS_PER_STAGE := 2.0`-second tween per intermediate stage hop, so backtracking
many stages takes proportionally longer while a single adjacent hop still reads as brisk
(empirically confirmed: a 2-hop jump took exactly 4.0s in a live test).
One real bug hit while adding the new travel-timing test: checking `traveler.position` after
a full multi-hop journey completed threw "previously freed" — arriving at certain stages
(e.g. an elite battle) synchronously chains into `begin_battle()` → `show_battle()` →
`_clear()`, which frees the *entire* prior map scene graph (including `traveler`) in the same
step that sets `profile.position`. There's no safe window from outside to read the old
`traveler` reference after that; the fix was to just not assert on it — `profile.position`
landing on the right stage combined with the elapsed-time check already covers correctness
and timing. Worth remembering for any future test that holds a node reference across a
screen-transition-triggering call.
Verified 250/0 rules (unaffected, screens-only) / UI smoke all passing, including 4 rewritten
assertions (the old ones tested the now-obsolete biome-mirroring behavior directly) and new
coverage for per-chapter waypoint uniqueness, road-line invisibility, and hop timing.
Committed as `02510db`.

### 2026-09-15 — Map header overflow fixed; Challenges rail added (user-reported, follow-on from F1)
Not one of the original 24 report items — a direct user bug report after the F2/F3/F4/D4/
art-pass commits landed. Two related fixes:
1. **Header overflow**: `show_map()`'s top row had grown to 5 buttons (lang, quest, camp,
   music, settings) plus the new fantasy logo (fixed 104px-wide `TextureRect`, replacing what
   used to be a compressible text label) — packed to the point of visibly overflowing on the
   user's device. Fix: removed the lang-toggle and music-toggle buttons from the header
   entirely, since `show_settings()` (F2) already has full controls for both — they were pure
   duplication once F2 landed. Deleted the now-dead `_toggle_language()`/`_toggle_music()`
   handlers along with them (confirmed zero remaining call sites first). `show_account_setup()`
   keeps its own separate, unrelated lang button — not touched.
2. **Challenges rail**: user asked for Camp's "挑战" (Challenges: Daily Trial + Abyss) tab to
   be reachable from the map, explicitly *not* by adding to the already-full header — "竖着放，
   放在最右边" (stack it vertically, on the far right). Added `_add_map_challenge_rail()`: a
   vertical `VBoxContainer` anchored to the map's right edge (independent of the header row
   entirely) with two icon buttons (reusing existing `GameIcon` kinds — `"scroll"` for Trial,
   `"orb"` for Abyss, no new icon-drawing code needed) that jump straight to Camp's Challenges
   tab. Dims locked icons rather than hiding them; tapping always navigates through regardless
   of lock state, since Camp already renders the real unlock-requirement text and the rail is
   too narrow to duplicate it.
Verified 250/0 rules (unaffected, screens-only), UI smoke +8 checks incl. one that hit real
test contamination: the rail test taps the Trial shortcut (setting `camp_tab = "challenges"`)
many sections before the actual `== camp ==` section's own "defaults to character tab"
assertion runs later in the same long-lived suite — had to explicitly reset `camp_tab` back to
"character" right after, the same one-shared-profile-across-sections trap this file's F1 entry
already flagged. Deployed to the user's device for their own visual confirmation — headless
tests can't see actual pixel overflow, only that the nodes exist with nonzero size.

### 2026-09-15 — Phase 3: Dedicated Settings, Deck Filters, Colorblind Glyphs, Victory Recap & Hard Replays shipped (F2, F3, F4, A3, D2)
1. **F2 Dedicated Settings Screen**: Built `show_settings()` modal, opened via `SettingsButton` (gear ⚙) in map top header and Camp. Provides controls for Language (zh-Hans / en), Battle Animation Speed (1.0x / 1.5x / 2.0x), BGM Audio Mute, and Accessibility "Reduce Motion" (`profile.reduce_motion: bool`), which automatically disables map particle emitters.
2. **F3 Deck Builder Search & Filters**: Added real-time search input (`DeckSearchInput`) and category chip filters for Kind (`DeckKindChips`: All, Attack, Skill, Power, Tactic) and Elements (`DeckElementChips`: All, Neutral, Fire, Gale, Stone, Water, Poison) in `show_deck()`.
3. **F4 Colorblind-Friendly Status Glyphs**: Upgraded all combat status chips across enemies and player to use distinct geometric silhouettes alongside colors: Shield (⬢ Hexagon), Burn (▲ Up-Triangle), Poison (◆ Diamond), Vulnerable (▼ Down-Triangle), Weak (● Circle), Stun (✸ Burst Star), Strength (★ Star), Focus (◉ Bullseye). Recognizable in grayscale.
4. **A3 First Victory Performance Recap**: Added `VictoryRecapCard` displaying battle performance metrics (damage dealt, cards played, shield absorbed) on early stage victories (`current_stage < 3` or `unlocked <= 3`), backed by `combat.state.stats`.
5. **D2 Opt-in Hard Replays**: Tapping cleared stage pins presents `_show_replay_mode_prompt()` modal offering Standard Replay (half gold, no drops) vs Trial Replay (applies `trial_hard` affix, restores 100% full gold and equipment/rune item drops) via `begin_hard_replay(index)`.
Both test suites passing (250 rules checks, UI smoke passing).

### 2026-09-15 — Phase 2: Beginner recommendation, Camp progressive unlocking, Daily Trial streak, and Compendium milestones shipped (A4, A2, B2, C3)
1. **A4 Beginner Hero Recommendation**: Fox Spirit master panel highlighted with `BeginnerRecBadge` ("✦ 新手推荐") and beginner-friendly tooltip in `_hero_archetypes_section()`.
2. **A2 Progressive Camp Unlocking**: Camp features are gated behind campaign progression milestones (`profile.unlocked`):
   - Compendium & Daily Trial: unlocked after Chapter 1 (`unlocked >= 5`).
   - Endless Abyss: unlocked after Chapter 2 (`unlocked >= 10`).
   - Ascension Difficulty Tiers: unlocked after Chapter 5 (`unlocked >= 25`).
   Locked sections show a clear chapter requirement badge while keeping container buttons disabled so automated testing retains access without regression.
3. **B2 Daily Trial Streak Tracking**: Added `streak` and `streak_claimed` in `daily_trial_record`. Consecutive days of clearing all 15 stages increment streak and award bonus gold at 3 days (100g), 7 days (250g), and 14 days (500g). Displayed in trial stats row.
4. **C3 Compendium Milestones**: Added `CompendiumMilestonesBar` and claim system (`profile.compendium_milestones_claimed`) in `show_compendium()` for 50%, 80%, and 100% catalog discovery thresholds.
Both test suites passing (247 rules checks, UI smoke passing).

### 2026-09-15 — D4 Great Boss Phase 2 mechanics shipped & core.json curses bug fixed
1. Fixed core.json curse cards placement: `decay_blight` and `void_curse` were moved from
the `"statuses"` array into `"cards"` array. Updated shop/reward filters to cleanly exclude
`rarity == "Curse"`, ensuring `collect_all` achievement remains at 39 collectible cards.
2. D4 Great Boss Phase Transitions: all 5 Great Bosses (Chapters 10, 20, 30, 40, 50) feature
scripted Phase 2 mechanics triggering at <=50% HP threshold in `combat.gd`:
- Ch.10 Ember Lord: +4 damage, clears burn, becomes burn_immune, ignites player with 3 burn.
- Ch.20 Frost Titan: gains 25 shield, gains `frost_armor=2` (reducing all incoming damage by 2).
- Ch.30 Shadow Sovereign: inflicts 2 Vulnerable, spawns Shadow Clone minion.
- Ch.40 Gale Wyrm: gains `dodge_every=2`, inflicts 2 Weak on player.
- Ch.50 Abyssal Primordial: cleanses debuffs, drains 6 HP from player, pushes Void Curse into draw pile.
Cinematic `BossPhaseBanner` displays on phase transition in `game.gd`. 247/0 rules (+20 checks),
UI smoke passed.

### 2026-09-15 — D1 on-card synergy tags shipped
Deliberately deviated from the report's own sketch ("add a `tags: Array` field" to card data)
in favor of deriving tags from `effects`/`special` at render time — a stored field is one more
thing to keep in sync by hand across 39 cards (and counting, after D3), and a mistake there is
a silent content bug no test would catch unless someone thought to assert every card's tags
individually. A derived function is self-verifying by construction. If a future card effect
type needs a tag that doesn't map cleanly to `_card_synergy_tags()`'s current match arms, add
a case there — don't reach for a stored field as the easier-looking shortcut.
An easy trap hit while writing this one's test_runner.gd coverage before catching it: this is
purely a `game.gd` rendering concern, and `test_runner.gd` never instantiates `SpiritGame` at
all (only `SpiritContent`/`SpiritCombat` directly) — so `game._card_synergy_tags(...)` isn't
callable there no matter how "just testing a pure function" it feels. The test moved to
`ui_smoke.gd` instead. AGENTS.md rule 3 already says this explicitly ("screen changes go in
ui_smoke.gd") — worth re-reading before assuming a new helper's test suite based on how
stateless the helper feels rather than which script actually defines it.

### 2026-09-15 — D3 fourth hero archetype (Miasma Witch) shipped, portrait deferred
This is the first item on this roadmap that shipped with a **known, deliberate, documented
gap** rather than fully finished — see the checklist entry above for the full reasoning. Short
version: the hero-portrait pipeline (`character-atlas-v3.png`, a fixed 3x3 grid,
`_get_character_texture()`) has no spare cell, and I have no way to generate new painted art.
Rather than block the whole feature or silently ship a hero that looks exactly like Stone
Sentinel, it borrows that sprite dimmed with an explicit "art coming soon" badge. If you're
picking this up to add the real portrait: the atlas math is `cell_w = atlas.width/3`,
`cell_h = atlas.height/3`, `Rect2(coord.x*cell_w, coord.y*cell_h, cell_w, cell_h)` — either the
source PNG needs a 4th column/row (changing that divisor and every existing `CHAR_KEYS`
coordinate along with it — risky, touches all 3 existing heroes and 5 enemies), or simpler:
give Miasma Witch its own separate texture file and a small branch in
`_get_character_texture()`/the two call sites (`show_map()`'s traveler, `_hero_archetypes_
section()`) that checks for it before falling into the atlas path. The second option is much
lower-risk.
Also spun off a real, unrelated bug found while auditing the card pool (decay_blight/void_curse
invisible to `content.card()`) as its own spawned task rather than fixing it inline — see that
task's own commit when it lands, and check whether `ACHIEVEMENTS`' `collect_all` target (see
the code comment right above it) needs to drop by 2 once it does.
While building Poison, discovered `content.cards.size()` had been hardcoded to 36 in two
places (a `test_runner.gd` assertion, and this file's D1/AGENTS.md's card-count mentions) that
don't automatically track reality — every future card addition should grep for the literal
count rather than assume nothing references it.

### 2026-09-15 — F1 Camp tabs shipped
The real risk in this change wasn't the game.gd rewrite — it was that `ui_smoke.gd` had
several checks that called `game.show_camp()` and then looked for content that used to always
render (hero archetypes title, AbyssEnterBtn, CompendiumOpenBtn, DailyTrialEnterBtn) but now
only renders on ONE of three tabs, whichever `camp_tab` happens to already be set to from
whatever the previous section left it at. Two of these (hero title + abyss title/button) were
originally asserted from the *same* `show_camp()` call, which is no longer possible at all
now that they live on different tabs — that pair had to become two separate `show_camp()`
calls with `camp_tab` set explicitly between them, not just "add a camp_tab assignment before
the existing check." Every future screen-reorganization change (tabs, moved sections) should
grep the test files for anything that finds content by label/button-text/node-name on that
screen before assuming the reorg is UI-only — the assertions encode assumptions about layout
that the reorg itself breaks.

### 2026-09-15 — C1 achievement system shipped
The report estimated "30-40 achievements"; shipped 22. Cut for the same reason F1/C2/D3 all
carry a "needs a real design pass" flag rather than being padded to a round number — a fixed
`target` int baked into `content.ACHIEVEMENTS` at write time is a real commitment (e.g.
`collect_all`'s target of 34 is `36 total cards - 2 curse cards`, hardcoded rather than
computed, matching how `test_runner.gd` already hardcodes "twelve equipment definitions"
elsewhere in this codebase) — it's cheap to add more rows to `ACHIEVEMENTS` later, so 22 solid
ones beat 40 padded ones for a first pass. If you add more: every achievement needs a `kind`
that already has a reader in `_achievement_progress()` (stat / mastery_level / abyss_floor /
daily_trial_badges / compendium_percent / relic_count / card_collection) — a new `kind` needs
a new match arm there, same "grep before trusting a data key does anything" trap AGENTS.md
already documents for `combat.gd` mechanics.
No new call sites anywhere in combat.gd or the reward-granting code: `_advance_quest()`
already fires at every real gameplay signal (a win, damage, a chest, a purchase), so bumping
`profile.lifetime_stats` there for free was the whole trick — resist the urge to add a
separate `_track_achievement_stat()` call scattered through combat code if a future stat
doesn't fit this shape; look for whether it already flows through `_advance_quest` first.

### 2026-09-15 — B1 rolling weekly login reward shipped
Placed the entry point in `show_quests()` rather than Camp — a deliberate deviation from a
literal reading of the report (which sketched it as "a banner on the map or in Camp"), because
Camp already has 7 stacked sections and F1 (not yet done) is specifically about *reducing*
that, not adding a 8th before the cleanup happens. Quests already covers "periodic commissions
you check in on," so a login-reward strip fits there without waiting on F1.
One thing to watch: `_has_claimable_quest()` now calls `_ensure_login_reward_current()` on
every check (it's called often — it drives a notification dot rendered on every `show_map()`).
That function is idempotent within a calendar day (checked via the `days.has(today)` guard
before writing), so this doesn't spam `SpiritSave.write()` — but if a future change adds
per-open-of-the-app tracking, make sure to keep that idempotency, not "log a visit" per call.

### 2026-09-15 — A1 first-battle tutorial shipped
A 4-step dismissible slide carousel (`TUTORIAL_STEPS`, `_show_battle_tutorial()`,
`_render_tutorial_step()`, `_tutorial_next_step/_prev_step()`, `_finish_tutorial()`, all in
`game.gd`) shown once per profile on `begin_battle(0)` when `not profile.tutorial_seen`.
Deliberately **not** wired to actual gameplay actions (a real card drag, a real turn
auto-ending) — hooking every card-play code path (drag, tap-to-play, tap-to-target) reliably
would be real engine surface for a first pass; the carousel just explains those things up
front instead. If a future pass wants "true" step-gated onboarding (don't advance until the
player actually plays a card), the natural hook point is wherever `combat.play()` is called
from game.gd's input handlers — there wasn't a single existing choke point for that, unlike
`begin_battle()` which is the one true entry point for "a battle is starting."
One pitfall hit and fixed before committing: a GDScript string literal used a bare `"..."`
containing embedded ASCII double-quotes (`这里没有"结束回合"按钮`), which breaks the outer
string delimiter — GDScript doesn't error loudly on this in a way that's easy to spot in a
huge dict literal, so it's easy to miss. Fixed by switching that one entry to single-quote
delimiters. Watch for this in any future bilingual UI_TEXT entry that needs to quote a term.
Also caught before committing: an Edit's `old_string` anchored on `func begin_daily_trial()`
matched the *nearest preceding* occurrence of the target lines, which turned out to be inside
`begin_abyss_battle()` (which has no `index` variable at all) rather than `begin_battle()` —
a reminder that a same-shaped code block repeated 2-3 times in one file needs a more specific
anchor, not just "the next function's name," or the edit lands in the wrong copy silently.
189 rules checks (unchanged — this is a screens-only feature) / UI smoke all passing,
including 4 new assertions. Committed as (see git log for hash at time of your reading).

### 2026-09-15 — Roadmap created
Report published as an artifact (see link at top). Full 24-item backlog transcribed here,
ordered by impact per the user's explicit request, so implementation can proceed across
however many sessions/agents it takes without re-deriving priority. Nothing implemented yet
as of this entry.
