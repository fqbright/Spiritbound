# Launch Readiness

**This is a hard gate, not a wishlist.** Spiritbound is not to be submitted (or resubmitted) to
the App Store / Play Store until every section below has its **Definition of Done** met. This
file exists because "add more features" and "safe to ship" turned out to be different questions
— see the audit that produced this doc (2026-09-20 conversation, no code changes made in that
session; this file is the output of it) for the reasoning. If you are an agent picking this up
cold: read this whole file before touching anything, then work the sections in the order given
in "Suggested execution order" at the bottom. Each section is close to independent, but the
order matters for risk (compliance blockers before nice-to-haves) and for avoiding rework
(logging infra before the purchase flow that will want to log its own failures).

Standard repo discipline applies to all of this: every new feature needs test coverage per
AGENTS.md rule 1, `./run_tests.sh --all` must pass before every commit, one commit per
completed/verified piece of work rather than one giant commit at the end, and any new
user-facing string goes in `UI_TEXT` (`content.gd`) with both `zh-Hans` and `en`.

## Why this file exists (evidence, not assertion)

A grep-based audit of this repo (2026-09-20) found:
- Zero privacy-policy, terms-of-service, or account-deletion code anywhere in the repo.
- Zero crash-reporting or analytics infrastructure — the only "telemetry" hits are
  `balance_probe.gd`/`e2e_playthrough.gd` printing their own bot run stats, not anything that
  reaches a real backend from a real player's device.
- `game.gd:770` sets `profile.season_pass = {..., "is_premium": true}` unconditionally in
  `defaults()` (or wherever this profile is seeded — grep `is_premium` in `game.gd` and
  `game_camp_screen.gd` to confirm the current exact call sites, since this file may have moved
  by the time you read it) — every player currently gets full premium season-pass rewards with
  no purchase, and there is no StoreKit/Play Billing code anywhere in the repo.
- The Supabase anon key is embedded directly in `supabase_client.gd` (by Supabase's own design —
  this is not itself a bug), but this repo has no way to confirm from the client code alone
  whether Row Level Security actually restricts `player_saves`/`leaderboards` to their owning
  user. `submit_score()`/`upload_player_save()` POST directly with no server-side validation.

The user's own answers when this was discussed: **launch will include real-money monetization**
(so the `is_premium: true` default is a real gap, not an intentional choice), **the app is
already mid-submission / has a store listing started** (so account deletion is the sharpest and
most time-sensitive gap — it's a common real rejection reason under Apple Guideline 5.1.1(v) for
any app offering account creation, which this one does via Apple/Google/email sign-in), and
**a real device has already had a thorough recent test pass** (so a full hardware soak-test is
not part of this file's scope — see the note in "Non-code items" below for the one narrower
device-testing ask that's still worth doing).

---

## 1. Account deletion (blocking — do this first)

Apple Guideline 5.1.1(v): any app that lets a user create an account must let them delete it
from inside the app, not just via a support email. This repo has zero code for this today.

**Requirements:**
- A reachable entry point from Settings (`show_settings()` in `game.gd` — the existing account
  section already shows linked-provider status and a rename option; add deletion near there).
- A destructive-action confirmation flow — this is data loss, not a normal settings change, so
  it needs the same weight as other irreversible actions in this codebase (compare
  `ui.meridian_reset_confirm`'s confirmation-dialog pattern in `game_camp_screen.gd`). Do not
  make this a single tap.
- On confirmation, in this order:
  1. If cloud-linked (`SpiritSave.is_cloud_linked(profile)`), delete that user's row from
     `public.player_saves` via a Supabase REST DELETE (mirror `upload_player_save()`'s request
     shape in `supabase_client.gd`, using the account's own bearer token so RLS naturally scopes
     it to their own row — do not attempt this with an elevated key from the client).
  2. Also decide what happens to any `public.leaderboards` rows the account submitted. Deleting
     them outright is simplest and safest for a first pass; anonymizing (`player_name` gets set
     to a placeholder value) is the fancier alternative. Pick one and document which in the
     commit message — don't leave it ambiguous.
  3. Clear the local session (`SpiritAuth`'s sign-out path) and reset the local save
     (`SpiritSave.reset()` or equivalent — check its current behavior before reusing it, since
     it may need a variant that also clears the on-disk file rather than just leaving a fresh
     default profile in memory).
  4. Return to a fresh, logged-out state — whatever screen a brand-new install lands on.

- **Security constraint, do not skip this:** actually deleting the underlying Supabase
  `auth.users` record (as opposed to just the `player_saves`/`leaderboards` rows) requires a
  privileged admin API call, which needs the Supabase **service-role key** — a secret that must
  **never** be embedded in the Godot client under any circumstance. Embedding it would give
  anyone who decompiles the shipped app full admin access to the entire Supabase project
  (every player's data, not just their own). If you don't have a way to make that call from a
  trusted server context (a Supabase Edge Function, a small backend endpoint, anything that
  isn't the client binary), do **not** attempt it from the client. Wiping
  `player_saves`/`leaderboards` and signing the user out locally already satisfies the practical
  intent of 5.1.1(v) for most reviewers; flag the "delete the actual auth user" piece as a
  manual/deploy task for whoever has Supabase project access, rather than building an insecure
  version of it. Say this explicitly in your PR/commit description so it doesn't get missed.

**Test coverage:** `ui_smoke.gd` should walk the Settings entry point, confirmation dialog
(cancel path leaves the account untouched — assert this explicitly), and confirm path (local
save resets, session clears). The actual Supabase DELETE call can't be verified against a real
backend in a headless test any more than the rest of this repo's Supabase-touching code can —
follow the same pattern already established for leaderboard/friend tests: assert the request is
attempted with the right shape, don't wait on or assert against real network results.

**Definition of Done:** a player can delete their account from Settings, with a confirmation
step; their cloud save is removed; their local save resets to fresh; they're returned to a
logged-out state; `ui_smoke.gd` covers the flow; `./run_tests.sh --all` is green; the
service-role-key constraint above was respected (grep the diff for "service_role" / any new
secret-looking constant before considering this done).

---

## 2. Real-money purchase gate for the season pass (blocking — do this second)

**Current gap:** every profile gets `season_pass.is_premium: true` for free (see evidence
above). Since real-money monetization is planned, this cannot ship as-is — either gate it
behind a real purchase, or explicitly flip the default to `false` and make the premium track
genuinely premium.

**Requirements:**
- Godot has no built-in StoreKit (iOS) or Play Billing (Android) support. Research the current
  best-maintained Godot 4.7-compatible plugin for each platform before starting — don't assume
  a specific plugin name from outside this doc, since the ecosystem changes; check what's
  actively maintained and Godot-4-compatible at the time you do this work, not what may have
  been current when this doc was written.
- A purchase entry point in the season pass UI (`_season_pass_section()`/`show_season_pass()` in
  `game_camp_screen.gd` — grep for the current premium-track rendering to find exactly where the
  "you don't have this yet" state should offer a buy button instead of just showing locked rows).
- A "Restore Purchases" flow. This is not optional — Apple review checks for it on any app with
  non-consumable purchases, and without it a player who reinstalls or switches devices loses
  access to something they paid for.
- Receipt/transaction verification before flipping `is_premium` to `true`. Client-side-only
  verification (just trusting whatever the purchase plugin reports locally) is spoofable by a
  jailbroken/rooted device. Server-side verification (Apple's App Store Server API / Google
  Play Developer API, called from a trusted server context, not the client) is the correct
  approach; if that's not feasible in this pass, at minimum don't skip this consideration
  silently — document the tradeoff you chose and why.
- **Same service-role-key constraint as Section 1** applies to any server-side verification
  work: whatever calls Apple/Google's server APIs needs its own credentials, and none of them
  belong in the Godot client.
- Decide what happens to saves that already have `is_premium: true` from before this change
  (existing beta/TestFlight testers, if any exist — check whether any real external testers
  currently have live saves before deciding; if none exist yet, this is moot and you can just
  change the default cleanly).

**Test coverage:** the real purchase flow cannot be exercised in a headless test — no different
in kind from `deploy_ios.sh`/physical-device-only testing already being out of `run_tests.sh`'s
reach per AGENTS.md. What *is* testable and must be tested: `profile.season_pass.is_premium`
only ever becomes `true` through the verified-purchase code path (not some other unrelated one);
the premium-locked UI correctly reflects `is_premium: false` by default; a mocked "purchase
verified" event correctly updates state and persists it; "Restore Purchases" correctly
re-derives `is_premium` from account state. Add these to `test_runner.gd`/`ui_smoke.gd` as
appropriate; be explicit in comments about what's mocked and why the real transaction can't be.

**Definition of Done:** `is_premium` defaults to `false` and only becomes `true` via a verified
purchase or a working "Restore Purchases"; a purchase UI exists in the season pass screen; the
plugin choice and verification approach are documented in the commit message; test coverage
exists for everything listed above; `./run_tests.sh --all` is green.

---

## 3. Crash/error logging + minimal analytics (strongly recommended before launch)

No SDK integration needed for a first pass — reuse the exact pattern already proven this session
for leaderboards and friends: a small Supabase table, a plain REST POST from
`supabase_client.gd`. This needs a **new Supabase table**, which — same as every other new-table
situation encountered so far in this repo's history — cannot be created from the Godot client;
whoever has Supabase dashboard/CLI access needs to create it (with an appropriate RLS policy:
insert-only from clients, no read-back needed, since nothing in the client ever needs to read
its own past events back).

**Suggested shape** (adjust freely, this is a starting point, not a spec to follow blindly):
a single `public.client_events` table with columns roughly like `id`, `user_id` (nullable, for
guests), `kind` (`"error"` | `"event"`), `name` (text), `detail` (jsonb), `app_version`,
`platform`, `created_at`. One table for both crash-adjacent errors and funnel events keeps this
simple; split it into two tables later only if it actually gets unwieldy.

**Crash detection, realistically scoped:** GDScript has no exception/catch mechanism, and a true
native engine crash can't be caught by script code running inside the crashing process — don't
promise more than Godot can deliver here. The buildable version: enable Godot's built-in session
log file (`ProjectSettings` → `debug/file_logging/enable_file_logging`), and on each app launch,
check whether the *previous* session ended cleanly (write a "session started" marker at launch,
clear it on a clean shutdown path — e.g. `NOTIFICATION_WM_CLOSE_REQUEST` — and if a new launch
finds the marker still set, the previous session didn't exit cleanly). When that happens, upload
the tail of the previous log file to `client_events` as a `kind: "error"` row before continuing
normally. This is the realistic ceiling for a GDScript-only crash signal without a native SDK —
say so in the code comment, don't let it read as full crash reporting if it isn't.

**Minimal analytics — start small, don't instrument everything:** a short starter list of
funnel events posted at their natural call sites, e.g. `tutorial_started`, `tutorial_completed`,
`first_battle_won`, `stage_25_reached` (difficulty tiers unlock), `day2_return`, `day7_return`,
`friend_added`, `ghost_duel_started`. Resist the urge to wire up dozens of events in this first
pass — a small, deliberately chosen set that answers "did the tutorial work" and "did anyone
come back" is worth more than exhaustive coverage nobody looks at.

**Test coverage:** same offline-tolerant pattern as every other Supabase-touching test in this
repo — assert the event-posting call is attempted with the right shape and doesn't crash or
block the UI if the network call fails, don't assert against real backend data.

**Definition of Done:** the `client_events` table exists (confirm with whoever has dashboard
access, or check yourself if you have Supabase CLI/API access); the clean-shutdown/crash-tail
mechanism is wired up and tested; the starter event list is posted from its call sites; nothing
about this logging can block or crash the game itself if the network call fails;
`./run_tests.sh --all` is green.

---

## 4. Non-code items (can't be closed by an agent alone — verify, don't skip)

- **Row Level Security.** Confirm `public.player_saves` only allows a row's owner to read/write
  it, and confirm whatever policy exists on `public.leaderboards` and the new `client_events`
  table is intentional (public leaderboard reads are fine by design; unrestricted writes from
  anyone are not). If you have Supabase dashboard or CLI/API access, check this directly and
  report what you found instead of assuming; if you don't, say so explicitly rather than silently
  skipping it.
- **Privacy policy content.** A listing already exists per the user, so a policy URL is
  presumably already on file — but confirm it actually covers what's collected now: account
  email/name from sign-in, gameplay/save data synced via Supabase (name it as a sub-processor),
  and, once Section 3 ships, the new crash/analytics events. This is a content-accuracy check,
  not "create a policy from scratch."
- **Store listing metadata.** Once Section 1 ships, confirm the account-deletion capability is
  also reflected in App Store Connect's app privacy / account deletion questionnaire, not just
  present in the binary — Apple asks for this in two places.
- **One more device pass on this session's newest UI.** The user confirmed a thorough recent
  device test pass already happened, so this is narrow, not a full soak test: the Friends modal,
  Ghost Arena duel flow, and the new progressive difficulty-tier picker (all added the same day
  this doc was written) haven't had real-device eyes on them yet specifically. Worth one focused
  pass on just those three before final submission, on top of whatever this section's other
  items require.

---

## Suggested execution order

1. **Account deletion** (Section 1) — self-contained, no dependency on the other two, and the
   most time-sensitive given the app is already mid-submission.
2. **Crash/error logging + analytics** (Section 3) — no dependency on Section 2, and having it
   in place before the purchase flow ships means purchase failures can actually be observed
   instead of shipping blind a second time.
3. **Purchase gate** (Section 2) — largest, most external-dependency-heavy (plugin research,
   App Store Connect/Play Console product configuration outside this repo, receipt
   verification design); do this last so it can lean on Section 3's logging for its own
   failure cases.

Each section is its own commit (or small set of commits), each passing `./run_tests.sh --all`
on its own before moving to the next — not one giant change at the end. **The game is not
ready to submit until all three Definitions of Done above are met and the non-code items in
Section 4 have been actively verified, not assumed.**
