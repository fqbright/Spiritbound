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
- `[ ]` **B1 — 累积型登录奖励 (rolling weekly login reward)**
  "Log in on any 3 of 7 days this week" reward strip, NOT a hard-reset daily streak (the
  research explicitly warns reset-based streaks are less sustainable — see the report's
  caution section). New `profile.login_reward: {week, days_logged: [], claimed_tier: int}`
  field, checked/updated once per session in `_ready()` alongside `_ensure_quests_current()`.
  Entry point: a small banner on the map or in Camp.
  *Builds on:* the exact day/week-boundary pattern in `_ensure_quests_current()`.
- `[ ]` **C1 — 成就系统 (achievements)**
  30-40 bilingual achievements (combat feats, collection milestones, mastery levels, abyss
  depth, daily trial badges). New `content.ACHIEVEMENTS` data + `profile.achievements_unlocked:
  Dictionary`. Add an "Achievements" tab to the existing Compendium tab bar rather than a new
  screen.
  *Builds on:* `show_compendium()`'s `_tab_bar()` + `_compendium_row()` shell.
- `[ ]` **F1 — 营地标签页化 (Camp becomes tabs, not one long scroll)**
  Camp has grown to 7 stacked sections (account, compendium, hero mastery, daily trial, abyss,
  difficulty, relics). Split into tabs (e.g. "角色" hero+mastery+difficulty, "挑战" abyss+daily
  trial, "收藏" compendium+relics+account) using the same `_tab_bar()` already proven in
  `show_loadout()`/`show_compendium()`. **Do this before C1/F2 add more entries to Camp** — the
  report's own caution section flags this sequencing.
  *Builds on:* `_tab_bar()`, `show_camp()`'s existing section functions (mostly just
  reorganized, not rewritten).
- `[ ]` **D3 — 第四英雄流派 (4th hero archetype)**
  A "持续伤害/资源循环" (DoT-stacking / resource-banking) archetype to sit alongside Fox
  Spirit (burst), Stone Sentinel (defense), Shadow Stalker (crit/vulnerable). Needs a full
  25-card starting deck (all 1-cost per the existing invariant), 1-2 signature cards with new
  mechanics if the DoT hook needs one, and a `HERO_MASTERY_PERKS` row.
  *Builds on:* `content.HERO_CLASSES` data shape, `content.HERO_MASTERY_PERKS`.

## Medium-high impact

- `[ ]` **D1 — 卡牌协同标签可视化 (on-card archetype tags)**
  A small icon on each card face indicating its archetype (🔥 burn / 🛡 shield / ⚡ draw /
  etc.) so players can recognize synergy while building a deck without memorizing all 36+
  cards. Pure content + `_card_view`/`_big_card_face` rendering change, no engine work.
  *Builds on:* `content.gd` card data (add a `tags: Array` field), `_card_view()`.
- `[ ]` **B4 — 本地推送提醒 (local iOS notifications)**
  Remind players when a login-streak day or daily quest is about to expire. **Needs a native
  iOS bridge** (Godot has no built-in local-notification API) — likely a small GDExtension or
  a plugin. Flag for a dedicated investigation spike before committing to an implementation
  approach; this is the one item in this list that may need a design decision from the human
  before an agent should just start coding it.
  *Builds on:* nothing yet — new native surface.
- `[ ]` **C2 — 轮回 / New Game+ 机制**
  A prestige layer for players who've maxed mastery, cleared all 250 stages, and beaten A5:
  reset campaign progress for a permanent small bonus, a new A6+ difficulty tier, or an
  exclusive card back. Needs real design decisions (what resets, what's kept, what the actual
  reward is) — sketch the exact mechanic before implementing.
  *Builds on:* `profile.difficulty` (A0-A5) ladder as the closest existing analog.
- `[ ]` **D4 — 大首领专属机制 (unique Great Boss phase mechanics)**
  Each of the 5 Great Bosses (every 10th chapter) currently differs only by stat scaling +
  generic mechanic flags. Give each one a real scripted phase transition (e.g. "immune to
  Burn below half HP", "summons an add every 5 turns"). Content-heavy: 5 new mechanic branches
  in `combat.gd`'s intent/mechanics resolution, keyed by chapter number.
  *Builds on:* `content._chapter_mechanics()`'s existing `is_great_boss` branch.

## Medium impact

- `[ ]` **A2 — 渐进式营地解锁**
  Compendium / Daily Trial / Abyss / rune sockets are all available to a zero-progress new
  save. Gate them behind first real progress (e.g. "clear Chapter 1") so Camp doesn't
  overwhelm on day one, and so unlocking each one reads as an earned moment.
  *Builds on:* `show_camp()`'s section-visibility conditions (do this alongside/after F1).
- `[ ]` **A3 — 首胜战报回顾**
  For a new player's first 2-3 battles, show a simple recap card at the reward screen ("你造成
  了 X 点伤害 / 抽了 Y 张牌 / 触发了 Z 次符文效果") so the numbers on screen connect back to
  what they actually did.
  *Builds on:* `show_reward_details()`.
- `[ ]` **A4 — 新手推荐流派标记**
  Tag Fox Spirit "推荐新手" with a one-line reason (energy-friendly, immediate burst) on the
  hero-select panel, reducing first-minute decision paralysis across 3 (soon 4, once D3 lands)
  archetypes.
  *Builds on:* `_hero_archetypes_section()`.
- `[ ]` **B2 — 每日试炼连续通关奖励**
  Track consecutive days the Daily Trial was fully cleared; unlock a one-time reward (title,
  card back) at 3/7/14-day milestones — the Wildfrost "unique charm for completing the daily"
  idea, layered onto what's already shipped.
  *Builds on:* `profile.daily_trial_record` (add a `streak` field).
- `[ ]` **B3 — 每周主题挑战**
  Reuse the Daily Trial's tag-modifier engine at a weekly cadence (e.g. "本周限定牌组主题",
  "双倍精英奖励周") with the same deterministic-per-period seeding already used for daily
  quests/shop/trial tags.
  *Builds on:* `content.daily_trial_tags()`'s deterministic-seed pattern, `_shuffled_indices()`.
- `[ ]` **C3 — 图鉴里程碑奖励**
  The Compendium currently only *displays* a discovery percentage — it produces no reward.
  Unlock real content (a legendary card, an exclusive card back) at 50%/80%/100% discovery.
  *Builds on:* `_compendium_totals()`.
- `[ ]` **D2 — 重复关卡词条化**
  Replaying a cleared stage today is just "half gold, no drops." Offer an opt-in "harder
  replay" using the Daily Trial's tag-modifier system in exchange for normal (not halved)
  drops — gives grinding players a reason to vary their replays.
  *Builds on:* `content.daily_trial_modifier()`'s tag-combination logic.
- `[ ]` **E1 — 试炼历史走势图 (local-only)**
  A simple trend line of `daily_trial_record.best_stage` over time. Purely local data, no
  backend needed.
  *Builds on:* extend `daily_trial_record` with a bounded history array.
- `[ ]` **E2 — 战报分享卡片 (local-only)**
  A shareable "run recap" image (hero, deck highlights, damage dealt) generated client-side
  after a win or a Great Boss kill — pure client-side rendering, no server dependency.
  *Builds on:* `_card_art_panel()`, `_panel()` and friends for the composed image.
- `[ ]` **F2 — 独立设置页面**
  Language, battle speed, and music mute are scattered across the map header and battle HUD
  with no single entry point. Consolidate into one Settings screen (gear icon near the account
  panel), and add a "reduce motion" toggle while there.
  *Builds on:* `_toggle_language()`, `_cycle_speed()`, `_toggle_music()`.

## Medium-low impact

- `[ ]` **C4 — 图鉴首杀额外奖励**
  A small one-time gold/XP bonus the instant an enemy is newly marked discovered in the
  bestiary, so filling the Compendium has in-battle feedback, not just a Camp screen number.
  *Builds on:* the `_mark_discovered("bestiary", ...)` call sites added in Milestone 4.
- `[ ]` **F3 — 卡组构筑搜索与筛选**
  Filter chips (element/kind/rarity) + a text search on the deck-builder card list — standard
  for a collection-heavy card game, low risk, low effort.
  *Builds on:* the deck-builder screen's card list rendering.
- `[ ]` **F4 — 色觉友好的状态图标**
  Vulnerable/Weak/Burn currently differ mainly by color. Add a shape/glyph differentiator so
  colorblind players (and anyone on a washed-out screen) can tell them apart at a glance.
  *Builds on:* `_intent_style()` and wherever status icons are drawn in battle.

## Blocked — needs a backend decision, not implementable in this local-only architecture

- `[ ]` **E3 — 云存档 + 好友排行榜**
  `save_store.gd` already carries an `account.id` UUID "for a future cloud sync" per its own
  comment, but there is no backend today. This is the natural first feature once one exists —
  do not attempt a local stand-in that would need throwing away.
- `[ ]` **E4 — 异步"幽灵对战"**
  Recorded-run AI opponents need a backend to store and serve run recordings. Same blocker as
  E3; sequence after it, not before.

---

## Progress Log

Append newest entries at the top. Each entry: date, what changed, why, anything the next
agent needs to know that isn't obvious from the diff.

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
