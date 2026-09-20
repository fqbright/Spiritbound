# Store Submission Checklist

The store-side companion to [LAUNCH_READINESS.md](LAUNCH_READINESS.md). That file is the
*code* gate (account deletion, the purchase gate, logging); this one is everything that has to
be true on **Apple's** side for the submission to survive review.

Everything below was measured on this repo at commit `7bf8c62`, not assumed. Numbers that will
drift are marked with what they were measured against, so re-measure before trusting them.

---

## 1. Blocking before upload

### 1.1 Payload size — measured on the `.pck`, not the source tree

Apple's over-the-cellular download limit is 200 MB (over Wi-Fi there is no practical cap).
Exceeding it is what produces the "requires Wi-Fi to download" warning that measurably costs
installs, so the number to watch is the **shipped `Spiritbound.pck`**.

**Use `python3 Godot/tools/pck_audit.py <pck>` for this, never `du -sh Godot/assets/*`.** Godot
re-imports every asset and packs the *imported* form, so the two disagree — badly. An earlier
revision of this section reasoned from the source tree and got the ranking of what to fix
**wrong**, which is why the script exists:

| Measured on | audio | textures | fonts |
| --- | --- | --- | --- |
| `du -sh Godot/assets/*` (source) | 28 MB | ~177 MB | 13 MB |
| **inside the shipped `.pck`** | **5.6 MiB** | **146.8 MiB** | **9.1 MiB** |

The source-tree view suggests audio is a headline cost. It is not: every `.wav.import` already
has `compress/mode=2` (**QOA**, a lossy codec), so the 30 tracks occupy 5.6 MiB in the pack.
"Convert the WAVs to OGG" — the old advice here — would have saved ~4 MiB and was not worth
doing. Trust the artifact.

Real breakdown of the 170,449,820-byte pack at `2e1af47` is **90.3% texture**, and that is the
whole story:

| Group | Size | Note |
| --- | --- | --- |
| `.ctex` texture data | 146.8 MiB | 604 textures, from `assets/characters/` (394 PNGs), `chapters/`, `banners/`, `cards/`, `backgrounds/` |
| `.fontdata` | 9.1 MiB | `LXGWWenKai-Medium.ttf`, one full CJK face |
| `.sample` (QOA audio) | 5.6 MiB | already compressed |
| `.gdc` + scripts + `data/` | 1.1 MiB | |

**Landing in this pass, verified by re-export.** Two changes, no re-encode, no visual risk:

**(a) `export_presets.cfg` now excludes what no build should ship.** `tests/` and `tools/` were
being packed into the release artifact, `addons/gut/` (the test framework) was too, and
`assets/characters/monsters/m_r*.png` are **byte-identical duplicates** of the `m_s*.png` sheets
with zero references anywhere in `scripts/` or `data/` (checked by `md5` and by `grep`).

**(b) The export directory is wiped before exporting.** `Godot/build/ios` sits *inside* the
project, and `export_filter="all_resources"` scans the project tree — so on the **second and
later** releases Godot scans its own previous output and packs it into the new `.pck`: 18
zero-byte `Images.xcassets` entries, a duplicate `Icon-*.png` import per generated app icon, and
20 `Can't open file from path 'res://build/...'` errors during export. The first release on a
fresh clone never shows it, which is why it survived this long. The already-built pack in this
repo was affected. `release_ios.sh` now clears `build/ios` first (`build/` is gitignored and
fully regenerated), which makes repeated exports reproducible.

**(c) Dead background art is excluded too.** In `assets/backgrounds/` six basenames ship as
both `.png` and `.jpg`. Grepping every `.gd`/`.json`/`.tscn`/`.tres`/`.cfg` in the project for
both the full filename *and* the bare stem shows four (`battlefield-v1`, `ember-cliff-v1`,
`mountain-forge-v1`, `rune-ravine-v1`) are referenced **nowhere at all**, and for the two that
are used (`lantern-marsh-v1`, `spirit-world-map-v1`) only the `.jpg` is ever loaded -- the `.png`
half is dead. There is no directory scan over `assets/backgrounds`; `_background()` is only ever
called with string literals, so nothing resolves these by name at runtime. Excluded rather than
deleted, so the art stays in the repo and it is one line to revert.

```
before  170,449,820 bytes (162.5 MiB)   20 export errors, non-reproducible
after   136,084,320 bytes (129.8 MiB)   -32.8 MiB, -19.2%, 0 errors, 1120 entries
```

Cumulative: **-19.2%, all of it bytes that were never reachable.** `./run_tests.sh` green
(720 checks, ui_smoke, e2e, balance, GUT 19/19) after every step.

Reproducibility check that caught (b): exporting twice in a row without the wipe produced
`147,709,736` vs `147,705,952` bytes — the same commit does not yield the same pack, and the
difference is garbage. `./run_tests.sh` green (720 checks) after both changes.

**What is still on the table, in order of payoff:**

1. **638 of 668 texture `.import` files are `compress/mode=0` (Lossless)** — i.e. the art ships
   as effectively raw RGBA. `project.godot` already sets
   `textures/vram_compression/import_etc2_astc=true`, so switching them to
   `compress/mode=2` (VRAM Compressed) is the one change with a 2–4× lever on 90% of the payload.
   It is *not* free: ETC2/ASTC is lossy and will be visible on gradients and soft shading, so
   this is a quality call, and it needs `godot --headless --import`, a re-measure and
   `Godot/tests/visual_snapshots.gd`. Do it deliberately or not at all.
2. **Duplicate `.png`/`.jpg` pairs ship side by side.** `backgrounds/` contains seven
   same-basename pairs (`battlefield-v1`, `ember-cliff-v1`, `lantern-marsh-v1`,
   `mountain-forge-v1`, `rune-ravine-v1`, `spirit-world-map-v1`, …), as do `cards/moonfang` and
   `cards/renewal`. The `.jpg` duplicates are ~0.25–0.5 MB each. Most of those basenames appear
   in *no* script, so the likely fix is deletion rather than exclusion — but confirm each
   reference first; two of them (`lantern-marsh-v1`, `spirit-world-map-v1`) are referenced
   somewhere and must not be guessed at.
3. **Subset the font** (9.1 MiB). Both shipped languages need hanzi so the face cannot be
   dropped, but `pyftsubset` against the glyphs the game actually renders can remove the rest.
   The `UI_TEXT` table is exhaustive — 935 keys, `zh-Hans` and `en` both complete, zero missing
   translations, verified — so the glyph set is known rather than estimated.
4. **Stale import cache.** `Godot/.godot/imported/NotoSansSC.ttf-*.fontdata` is 13 MB of orphan:
   its source `NotoSansSC.ttf` **is not in the repo**, it is not referenced by any script or by
   `project.godot`, and it is **not** in the pack (confirmed via `pck_audit.py`). It is only
   local disk, so it is not a shipping problem — but do not mistake it for a shipped font, and
   do not "fix" the 13 MB by editing `assets/fonts/`.

Re-run `pck_audit.py` after any art change. `Godot/tests/visual_snapshots.gd` is the visual
regression check.

### 1.1b The test gate used to pass without running

Found while adding the assertion above, and worth stating because it affects every other claim in
this file: `run_tests.sh` ran each suite and then printed `✓ ... passed!` **unconditionally**,
never checking the exit status or the output. Godot exits `0` when a script fails to *parse*, so a
syntax error produced this:

```
SCRIPT ERROR: Parse Error: Cannot find member "filter" in base "PackedStringArray".
  🎉 ALL SELECTED SPIRITBOUND TESTS PASSED CLEANLY!
```

The unit tests had not run at all. Any "the suite is green" claim from before this fix was
therefore a claim about the exit code of a process that will happily return `0` having executed
nothing.

Suites 1–4, 6–8 now go through a `run_suite` helper that fails on `SCRIPT ERROR` /
`Parse Error` / `Failed to load script`, fails if the suite's success line is **absent** (so a
silently-skipped suite is a failure, not a pass), and fails on a non-zero status. Verified by
injecting a parse error into `test_runner.gd`: the script now exits `1` instead of reporting
success.

### 1.2 The purchase gate cannot unlock anything yet

`Docs/LAUNCH_READINESS.md` §2 is implemented in code, but the last mile is outside this repo:

- **No billing plugin is vendored.** `Godot/addons/` contains only GUT. So `Buy` and `Restore`
  in the season-pass screen answer `no_provider` and grant nothing. This is fail-closed by
  design, but it means **there is currently nothing for a player to buy** — the premium track is
  simply locked forever.
  `PurchaseService.bootstrap_provider()` now wires a plugin automatically from
  `project.godot`'s `spiritbound/purchase/provider_candidates` setting (see
  `Godot/scripts/purchase_service.gd`), so vendoring one is a config change rather than a code
  change. Research the current Godot 4.7-compatible StoreKit / Play Billing plugin rather than
  trusting a name from any doc, including this one.
- **The two verification stubs are still stubs.** `supabase/functions/verify-purchase/index.ts`
  returns `verified: false` with `apple_verification_not_implemented` /
  `google_verification_not_implemented` even when credentials are set. Deploying the function
  does **not** make purchases work. Implement those two functions against Apple's App Store
  Server API and Google's Play Developer API first.
- **Product id** is `spiritbound_season_pass_1` (`PurchaseService.PRODUCT_SEASON_PASS`) — create
  exactly that in App Store Connect, as a **non-consumable**, because `Restore Purchases` is
  implemented and required for non-consumables.
- Deploying the functions and creating the tables is scripted: `./deploy_supabase.sh
  --project-ref <ref>` (§1–§3 of LAUNCH_READINESS.md in one command).

### 1.3 Account deletion must be deployed, or it is a rejection

The client flow, the confirmation modal and the `delete-account` Edge Function all exist and are
tested. **Undeployed, the function is a 404 and the account survives on Supabase's side** —
which is precisely the Guideline 5.1.1(v) failure the whole section exists to prevent. Run
`./deploy_supabase.sh`, which also curl-checks both functions answer.

Apple asks about this in **two** places: the binary must have the capability (it does) *and*
App Store Connect's account-deletion questionnaire must say so. Do both.

### 1.4 Privacy policy and terms

There is no privacy-policy or terms-of-service document anywhere in this repo (files, not code —
`Godot/build/ios/PrivacyInfo.xcprivacy` is Godot's generated manifest, not a policy). A listing
already exists per the user, so a policy URL is presumably on file — but confirm it actually
covers what the app now collects:

- account email / name from Apple, Google or email sign-in,
- gameplay and save data synced to Supabase — **name Supabase as a sub-processor**,
- leaderboard display names and scores (visible to other players by design),
- and, once `client_events` is live, crash-adjacent log tails plus funnel events.

The App Privacy answers in App Store Connect ("Data Linked to You", "Identifiers", "Usage Data")
have to match that wording. This is an accuracy check, not a document to write from scratch.

---

## 2. Should fix before review

### 2.1 Offline leaderboards show fabricated players — now disclosed

`SupabaseClient._get_fallback_leaderboard()` substitutes ten invented names
(`无极剑仙`, `幻月灵狐`, `碧落丹圣`, …) when the network call fails or the table is empty. The
sample board itself is deliberate and covered by six existing tests, so it stays.

The problem was that `fetch_leaderboard()` already returned `offline: true` for this case and
**the leaderboard modal dropped that flag on the floor**: a player on a plane saw ten realistic
names and scores rendered as the real global standings, with nothing anywhere to say otherwise.
Fabricated social proof presented as real is the kind of thing that turns a routine review into
a question about the app's honesty — and it is a bad experience regardless of review.

Fixed: the modal now renders `ui.leaderboard_sample_notice` ("⚠️ sample standings, not real
scores") whenever the flag is set. The stricter alternative — mirroring
`fetch_leaderboard_for_users()`, which already refuses to fake friends — would mean deleting the
sample board outright; that would also delete a deliberate, tested design choice, so labelling
it was the smaller and more honest change. Revisit if you would rather have the empty state.

### 2.2 Version numbers say 1.0.0 / build 1

`Godot/export_presets.cfg` has `application/short_version="1.0.0"`,
`application/version="1"` — raised from `0.2.0` / `2` in this pass, since a first public release
is normally `1.0.0`.

How the number reaches the binary, verified by re-exporting rather than assumed:

- `Spiritbound-Info.plist` does **not** contain the version; it contains the build-setting
  references `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`.
- The literals live in the **generated** `Spiritbound.xcodeproj/project.pbxproj`, and Godot
  rewrites them from the preset on every export: the fresh export made in this pass contains
  `MARKETING_VERSION = 1.0.0` / `CURRENT_PROJECT_VERSION = 1`, while the pre-existing
  `Godot/build/ios/` still contains `0.2.0` / `2`.

**The trap:** the preset is the source of truth only at export time, so a `build/ios/` directory
that is not re-exported keeps whatever version it was last written with, and archiving that
stale tree ships the old number. This is not hypothetical — one exists in this repo right now:
`Godot/build/ios/` still says `0.2.0` / `2` while the preset says `1.0.0` / `1`.

`release_ios.sh` re-exports on every run (that is why it is the release path), which is what
keeps the two in sync. It also now reads the version **out of the exported
`project.pbxproj`** rather than out of `export_presets.cfg`, so the number it prints and records
next to the archive is the one that will actually ship; if the exported project and the preset
disagree it says so and tells you to delete `Godot/build/ios/` and re-export. Do not archive
that directory by hand. To check it yourself:

```bash
grep MARKETING_VERSION Godot/build/ios/Spiritbound.xcodeproj/project.pbxproj
```

On build numbers, be precise about what the script can and cannot know: it warns when you are
reusing the number committed in `export_presets.cfg`, because it **cannot see what you have
already uploaded** — App Store Connect rejects a duplicate build number for the same version,
and only you know whether one exists. Pass `--build-number <n+1>` to silence it. Numbers only
have to be unique *within* a version train, so `1` is fine under `1.0.0` even if `0.2.0` build
`2` already exists.

### 2.3 Export compliance — verified OK, but it is template-owned

`ITSAppUsesNonExemptEncryption = false` **is** present in the exported
`Godot/build/ios/Spiritbound/Spiritbound-Info.plist`, and it comes from Godot's own 4.7.2 iOS
template — the app uses no non-exempt encryption (HTTPS/TLS to Supabase is exempt). This is the
key that stops App Store Connect asking the export-compliance question on every upload, so it is
worth knowing it is inherited rather than authored: **it is a generated file, regenerated on
every export; do not hand-edit it.** If a future Godot template bump drops the key,
`release_ios.sh` warns about it explicitly at export time.

Corollary, since it is an easy trap: `App/Info.plist` at the repo root is **not** part of the
iOS build. `App/`, `Sources/`, `Tests/` and `Expo/` are the abandoned Swift and React Native
prototypes per `AGENTS.md`; the shipped artifact is the Godot export at
`Godot/build/ios/Spiritbound/Spiritbound-Info.plist`. Editing the root `App/Info.plist` has no
effect on a release.

### 2.4 One focused device pass

Per LAUNCH_READINESS.md §4: the Friends modal, the Ghost Arena duel flow and the progressive
difficulty-tier picker were never seen on real hardware. Narrow, not a full soak test — but the
iOS Simulator cannot run this project at all (see `README.md`), so a real device is the only
place those screens get eyes.

---

## 3. Release procedure

```bash
./deploy_supabase.sh --project-ref <ref>   # §1-§3 infra: tables, functions, secrets check
./release_ios.sh --dry-run                 # review the whole flow, change nothing
./release_ios.sh --upload                  # export-release → archive → upload to App Store Connect
```

`release_ios.sh` is the release path; `deploy_ios.sh` remains the developer loop (debug build
installed over the cable). The release script refuses a dirty working tree on purpose — an
archive has to correspond to a commit — runs `./run_tests.sh` first, exports with
`--export-release` (never `--export-debug`), archives with distribution signing via
`-allowProvisioningUpdates`, and records the version (read from the exported Xcode project),
the build number and the commit next to the archive so a TestFlight report can be traced back to
a build. It also asserts, post-export, that the generated `Info.plist` still carries
`ITSAppUsesNonExemptEncryption` (§2.3), and that the exported marketing version matches the
preset (§2.2).

Before uploading, re-measure the payload — it is the one gate that is cheap to check and
expensive to discover late:

```bash
python3 Godot/tools/pck_audit.py Godot/build/ios/Spiritbound.pck
```

Expect ~130 MiB (136,084,320 bytes) after the changes in §1.1; anything much larger means the
`exclude_filter` was lost, the stale `build/ios` was packed back in, or new art landed
uncompressed. `./run_tests.sh` now asserts the exclusions still hold, so a lost `exclude_filter`
fails the suite instead of silently inflating the release.

Then, in App Store Connect: attach the build to a TestFlight group, complete the
export-compliance question if it appears, confirm App Privacy and the account-deletion
questionnaire, and submit.

---

## 4. Needs a human with credentials — cannot be closed from this repo

| Item | Why it needs you |
| --- | --- |
| Deploy `delete-account` + `verify-purchase` | Supabase project access (`supabase login`) |
| Create `client_events` + `entitlements` tables | Supabase dashboard / DB connection string |
| Set Apple/Google verification secrets | App Store Connect + Play Console service accounts |
| Create the store product `spiritbound_season_pass_1` | App Store Connect / Play Console |
| Vendor a Godot 4.7 billing plugin | Choice of plugin + native build integration |
| Implement the two `verify-*` functions | The SDKs + the credentials above |
| Privacy policy wording, App Privacy answers | App Store Connect access |
| RLS confirmation on `player_saves` / `leaderboards` | Supabase dashboard (the repo's SQL files set it for the new tables; the two existing ones are unverified) |
| Real-device pass on the new UI | A device |

Section 4 of LAUNCH_READINESS.md is explicit that these are verified, not assumed. None of them
became untrue because the code landed.
