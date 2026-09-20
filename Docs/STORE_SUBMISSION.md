# Store Submission Checklist

The store-side companion to [LAUNCH_READINESS.md](LAUNCH_READINESS.md). That file is the
*code* gate (account deletion, the purchase gate, logging); this one is everything that has to
be true on **Apple's** side for the submission to survive review.

Everything below was measured on this repo at commit `7bf8c62`, not assumed. Numbers that will
drift are marked with what they were measured against, so re-measure before trusting them.

---

## 1. Blocking before upload

### 1.1 The payload is 170 MB and the cellular limit is 200 MB

Measured: `Godot/build/ios/Spiritbound.pck` = **170,449,820 bytes (163 MiB)**. Apple's
over-the-cellular download limit is 200 MB; over Wi-Fi there is no practical cap. This is not a
rejection risk today, but it is 85% of a hard ceiling with art still being added, and exceeding
it is what produces the "this app requires Wi-Fi to download" warning that measurably costs
installs.

Where the bytes are (`du -sh Godot/assets/*`):

| Path | Size | Note |
| --- | --- | --- |
| `characters/` | 83 MB | 386 PNGs, incl. the 250 monster portraits |
| `chapters/` | 32 MB | |
| `audio/` | 28 MB | **30 `.wav` files, zero compressed formats** |
| `cards/`, `backgrounds/` | 40 MB | |
| `banners/` | 14 MB | |
| `fonts/` | 13 MB | one full CJK face, `LXGWWenKai-Medium.ttf` |

The two cheap wins, in order of payoff:

1. **Convert the 30 `.wav` files to OGG Vorbis.** Godot's WAV importer
   (`Godot/assets/audio/*.wav.import`) has `force/8_bit=false`, `force/mono=false`,
   `force/max_rate=false` — i.e. every file ships at its authored quality. For music and
   ambience, 96–128 kbps Vorbis is transparent to essentially every listener on a phone
   speaker; expect roughly a 10× reduction on those 28 MB. This is a pure asset change, no code.
2. **Subset the font.** 13 MB is one face covering all of CJK. Both shipped languages need
   hanzi, so it cannot simply be dropped, but `pyftsubset` against the actual glyph set the
   game renders (the `UI_TEXT` table is exhaustive — 935 keys, both `zh-Hans` and `en` complete,
   zero missing translations, verified) removes everything unused. Typically 60–80% off.

Then re-measure the `.pck`. If it lands under ~120 MB there is no size question left for a
long time. `Godot/tests/visual_snapshots.gd` gives a visual regression check if you touch art.

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

### 2.2 Version numbers say 0.2.0 / build 2

`Godot/export_presets.cfg` has `application/short_version="0.2.0"`,
`application/version="2"`. A first public release is normally `1.0.0`. The generated
`Spiritbound-Info.plist` derives `CFBundleShortVersionString` and `CFBundleVersion` from Xcode's
`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, with the preset as the source of truth — so set
both there, and confirm the built app's plist matches. `./release_ios.sh` prints the version that
actually reached the binary, and warns when the build number will collide with one already
uploaded (App Store Connect rejects duplicate build numbers per version).

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
`-allowProvisioningUpdates`, and records the version and commit next to the archive so a
TestFlight report can be traced back to a build.

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
