# Competitive research

Measured 2026-09-20 against Apple's own public iTunes Search/Lookup API — no third-party
estimates, no vendor dashboards. The exact script is `Godot/tools/store_research.py`; the JSON it
writes is thrown away by default (`--keep-json` keeps it). Anyone can re-run it and get today's
numbers.

**What this data is not.** Apple exposes rating counts and metadata. It does **not** expose
downloads, revenue, DAU, retention or session length. Everything below is therefore a
*popularity proxy from public listings*: "how many ratings this listing has accumulated, and how
fast". Treat the ratios as real and the absolute numbers as indicative. In particular a rating
count is lifetime-cumulative and storefront-scoped, so it reflects the whole life of the title in
one country, not current health.

## Spiritbound's own numbers, for comparison

| | Value | Source |
| --- | ---: | --- |
| Cards | 53 (51-card pool + 2 curses) | `Godot/data/core.json` `cards` |
| Starting deck | 25 | `core.json` `startingDeck` |
| Bestiary entries | 250 | `content.gd` `ENEMIES` (`"id"` count) |
| Chapters / stages | 50 / 250 | `CHAPTER_NAMES_*`, `clampi(..., 1, 250)` |
| Heroes | 4 | `content.gd` `HERO_CLASSES` |
| Equipment / runes / relics | 12 / 10 / 11 (33 build items) | `content.gd` |
| Achievements | 23 | `content.gd` `ACHIEVEMENTS` |
| Localised strings | 952 keys × 2 languages (en, zh-Hans) | `UI_TEXT` |
| Download size | 61 MB | last iOS export, `pck_audit.py` |
| Version | 1.0.0 / build 1 | export preset |

## The 20 comparables

Indie/self-published deckbuilders and card roguelikes on the US storefront, plus three
large live-service card games as the ceiling.

| Title | Price | US ratings | Avg | Size | Last update | Age | Ratings/yr | Storefront languages |
| --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| MARVEL SNAP | Free | 135,277 | 4.69 | 340 MB | 2026-09-15 | 3.9y | 34,480 | 14 |
| Hearthstone | Free | 121,660 | 4.15 | 855 MB | 2026-09-15 | 12.4y | 9,788 | 12 |
| Legends of Runeterra | Free | 62,700 | 4.83 | 192 MB | 2026-09-14 | 6.4y | 9,804 | 14 |
| Loop Hero | Free | 3,873 | 4.88 | 212 MB | 2025-04-25 | 2.4y | 1,620 | 12 |
| Slay the Spire | $9.99 | 3,220 | 4.25 | 889 MB | 2025-08-05 | 6.3y | 514 | 1 |
| Card Guardians | Free | 3,094 | 4.64 | 418 MB | 2026-08-29 | 4.6y | 677 | 6 |
| Night of the Full Moon | Free | 2,406 | 4.51 | 1861 MB | 2026-06-24 | 8.9y | 270 | 7 |
| Ancient Gods | Free | 1,970 | 4.79 | 377 MB | 2026-04-25 | 3.8y | 521 | 8 |
| Pirates Outlaws | $0.99 | 1,833 | 4.47 | 279 MB | 2024-10-09 | 7.5y | 243 | 9 |
| Monster Train | $7.99 | 1,831 | 4.92 | 532 MB | 2023-03-16 | 3.9y | 469 | 6 |
| Abalon | Free | 991 | 4.84 | 116 MB | 2026-09-20 | 1.9y | 531 | 15 |
| Dawncaster | $4.99 | 924 | 4.68 | 1382 MB | 2026-09-19 | 5.5y | 167 | 1 |
| Slice & Dice | Free | 913 | 4.77 | 120 MB | 2026-05-29 | 2.5y | 365 | 1 |
| Buriedbornes2 | Free | 690 | 4.90 | 587 MB | 2026-09-09 | 2.7y | 256 | 11 |
| Wildfrost | Free | 511 | 4.16 | 723 MB | 2025-11-04 | 2.4y | 209 | 5 |
| Meteorfall: Journey | $3.99 | 469 | 4.58 | 591 MB | 2020-09-26 | 8.7y | 54 | 3 |
| Indies' Lies | Free | 439 | 4.59 | 1729 MB | 2025-08-21 | 5.0y | 88 | 3 |
| Dicey Dungeons | $4.99 | 221 | 4.57 | 842 MB | 2026-07-30 | 4.2y | 53 | 16 |
| Gordian Quest | Free | 124 | 4.65 | 1601 MB | 2026-05-05 | 1.5y | 83 | 12 |
| Vault of the Void | $6.99 | 76 | 4.76 | 538 MB | 2026-02-12 | 2.3y | 34 | 8 |

Derived: ratings/year quartiles **88 / 270 / 531** (indie tier). Size min/median/max
**116 / 591 / 1861 MB**. Price: 7 of 20 premium, $0.99–$9.99. Storefront languages average 8.2,
max 16.

## Finding 1 — Spiritbound is the smallest download in the entire set, by a wide margin

61 MB against a median of 591 MB. **16 of the 21 listings exceed Apple's 200 MB cellular
download limit**; Spiritbound doesn't, and after this session's compression work it isn't close.
The three titles closest in size (Abalon 116 MB, Slice & Dice 120 MB, Legends of Runeterra 192 MB)
are all doing well. This is a conversion advantage that no amount of content work can buy, and it
was the right thing to prioritise.

## Finding 2 — content *breadth* is the one axis Spiritbound loses badly

Every one of these listings leads its store copy with a card count:

| Game | Advertised card-ish count |
| --- | --- |
| Dawncaster | "over 900 stunning hand-illustrated cards" |
| Pirates Outlaws | "More than 700 cards and 200 relics" |
| Abalon | "500 cards" |
| Ancient Gods | "300 cards" |
| Monster Train | "over 250 cards, 5 clans, 10 levels each" |
| Night of the Full Moon | "176 companion / 81 equipment / 63 spell" |
| Wildfrost | "160 cards" |
| **Spiritbound** | **53 cards, 33 build items** |

Spiritbound's *structural* depth is competitive or better — 250 stages, 50 chapters, 250 bestiary
entries, 4 difficulty bands, and a prestige loop, against a median title that ships a handful of
act structures. But it is 3–17× short on the single number every store listing in this genre
competes on. This is more an **ASO/copy problem than a gameplay problem**: 53 cards is not thin
for play depth, it is thin for *a store page*. Two honest options, and they are not exclusive:

1. **Lead with numbers we win on** — 250 stages, 50 chapters, 250 bestiary entries, 61 MB,
   fully bilingual. The 250-entry bestiary in particular is a number no title in this table
   advertises.
2. **Grow the pool deliberately.** Each card costs definition + balance + test coverage. A
   realistic near-term target is not 300, it's the *next* round number that the store copy can
   honestly name (e.g. 100).

## Finding 3 — the mainland China storefront is nearly empty of these comparables

Same listings, queried per storefront (rating counts):

| Title | us | tw | hk | sg | my | cn |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Night of the Full Moon | 2,406 | 3,909 | 814 | 98 | 160 | **111,234** |
| Slay the Spire | 3,220 | 258 | – | 41 | 11 | **absent** |
| Dawncaster | 924 | 8 | 25 | 29 | 13 | **absent** |
| Card Guardians | 3,094 | 127 | 69 | 24 | 80 | **absent** |
| Loop Hero | 3,873 | 491 | 261 | 24 | 32 | **absent** |
| Ancient Gods | 1,970 | 242 | 155 | 73 | 44 | **absent** |
| Abalon | 991 | 99 | 36 | 4 | 12 | **absent** |
| MARVEL SNAP | 135,277 | 6,816 | 5,528 | 2,026 | 2,060 | **absent** |

Night of the Full Moon — the only comparable actually on the China storefront — earns **46× more
ratings there than in the US**. Spiritbound is a fully bilingual EN/zh-Hans 修仙-themed card game,
which is exactly the shape that competes in that market and almost none of its Western
comparables are present in it.

**Read this before treating it as a plan.** Listing a game in mainland China has a regulatory
requirement (a game publication licence, 版号/ISBN) that this repository cannot satisfy and which
I have not verified for this title. Treat Finding 3 as "verify the licence path, because the
upside is large", not as "ship to cn".

## Finding 4 — update cadence separates the alive from the dormant

The titles still accruing ratings fastest all shipped within the last few weeks: Dawncaster
2026-09-19, Abalon 2026-09-20, Buriedbornes2 2026-09-09, Card Guardians 2026-08-29. The dormant
ones are dormant in lockstep with their last update: Meteorfall: Journey (last update 2020-09-26)
is at 54 ratings/yr, Dicey Dungeons (2026-07-30) at 53, Vault of the Void at 34. Slay the Spire
has been quiet since 2025-08 and still runs at 514/yr off brand alone — that is the exception,
not the model.

The implication for a first launch is unglamorous: a cadence is worth more than a launch.

## Finding 5 — monetisation: the pattern that fits Spiritbound

13 of 20 are free, 7 premium (median ~$5). Wildfrost ships the most directly copyable model:
*"TRY BEFORE YOU BUY — play for free until you beat the first boss, unlock the full game with an
in-app purchase."* Spiritbound's `PurchaseService` gate is still a stub (by explicit decision —
purchases are deferred), which means a free launch is both the lower-risk path and the one the
majority of the comparable set takes. Launch free; add the unlock later, when the receipt
verification functions are real.

## Finding 6 — what the code says Spiritbound is missing

Checked by grep, not assumed:

| Lever | Found in repo? | Evidence |
| --- | --- | --- |
| Local/push notifications | **No** | zero matches for `UNUserNotification`/`request_permissions`/notification APIs; `Godot/addons/` contains only `gut` |
| In-app review prompt | **No** | zero matches for `requestReview`/`store_review` |
| StoreKit/Play Billing plugin | **No** | no `plugins/` entry in `project.godot`; `purchase_service.gd` waits on a provider that never bootstraps |
| Ads | **No** | only binary matches inside `libgodot.a` |
| Share sheet | **No** | `game_rewards_screen.gd` recolours an in-game poster to `user://` and tells the player to screenshot it — deliberate, and documented in-file |
| Daily / weekly / monthly cycles | **Yes** | `_ensure_daily_trial_current`, `_ensure_weekly_challenge_current`, login rewards |
| Cloud save + friends + ghost duels | **Yes** | Supabase `player_saves`, `leaderboards` |
| Analytics funnel | **Yes** (new) | `log_service.gd`, `client_events` |

The mismatch is stark: Spiritbound has **three retention cycles and no way to tell a lapsed player
that any of them reset**. That is a retention engine with the key left out, and it is the single
highest-leverage gap in this document.

## Recommended order

1. **Notifications** (roadmap B4, still open). Now genuinely buildable: the B4 entry says no
   `xcodebuild` exists in this environment, which was true of the earlier Linux sandbox and is
   **not** true of this session's Mac. Reminders for: daily trial reset, weekly challenge reset,
   login reward day 3/5/7, and a re-engagement nudge. Requires a small Godot iOS plugin plus a
   real-device pass.
2. **App Store rating prompt** at a proven-good moment (first Great Boss kill), not at launch.
   Ratings velocity is the discovery input, and the indie tier median is only 270/yr — the first
   few hundred ratings matter disproportionately.
3. **Decide Finding 2** — copy pivot (free), card pool growth (not free). Do the copy pivot
   first; it's a day's work and it's honest.
4. **Verify the China licence path** (Finding 3) before assuming anything about that storefront.
5. **Set a cadence** — the data says cadence beats launch (Finding 4).
6. **Free launch, unlock later** (Finding 5) — matches 13/20 and matches the current state of
   `PurchaseService`.
7. **Don't** do ads. Nothing here suggests they'd pay for themselves at this scale, and no
   comparable in this set is ad-supported in a way worth copying.

## Things I could not do

- **"Like/upvote similar games"** needs a signed-in Apple ID (or a community account) that is
  yours, not mine. I did not touch any account. If you want, the honest version is: I name the
  listings and communities worth supporting and you tap them — but I can't do it from here, and
  I'm not going to pretend otherwise.
- **Downloads, revenue, retention, DAU** — not exposed by any public Apple API. Not estimated
  here on purpose; a wrong number in a research doc is worse than a missing one.
- **China licence status, and whether the game's theme would clear Chinese store review** —
  needs a human with the paperwork.
