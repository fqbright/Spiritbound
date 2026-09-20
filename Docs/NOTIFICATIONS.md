# Notifications and the rating ask

Two retention/discovery features that share one problem: both want a small piece of iOS that
Godot does not provide, and neither should be allowed to become a half-wired feature that looks
finished. This file records exactly what is done, what is not, and what will break silently if
someone assumes the difference doesn't matter.

## 1. Local notifications — the GDScript half is done and tested

`Godot/scripts/notify_bridge.gd` (`class_name SpiritNotify`) is complete, headlessly tested, and
inert on every platform except a real iOS export.

**Why local, not push.** This game already runs three reset cycles and, before this, had no way
to tell a lapsed player any of them happened — a retention engine with the key left out
(`Docs/COMPETITIVE_RESEARCH.md` Finding 6). A local notification needs no server, no APNs
certificate, no `UIBackgroundModes` entitlement, and no ongoing cost. The OS delivers it whether
or not the app is running.

**The scheduling policy is a pure function.** `due_reminders(profile, now_unix)` takes the clock
as a parameter and returns `{id, title_key, body_key, fire_unix}` dictionaries. That is what makes
it testable: a test drives any date through it instead of waiting three days for a reminder to
mature. 25 assertions in `test_runner.gd` cover it, including the ones that matter most:

- A player who has not reached Chapter 1 gets **zero** reminders — the same `unlocked >= 5` gate
  the Camp tabs themselves use. (A first-session player being notified about content they cannot
  see yet is worse than not notifying at all.)
- Every `fire_unix` is in the future. A notification with a past timestamp fires immediately,
  which is a bug, not a nudge — so it's asserted rather than assumed.
- No id is scheduled twice, so cancel-then-reschedule can't leave duplicates.
- Once a cycle has actually been played, its reminder stops existing. Reminding someone about a
  reset they just completed is noise.
- Reopening the app pushes the re-engagement reminder further out. **This is what makes it
  self-cancelling**: an active player's copy is rescheduled every session and therefore never
  arrives, so only a genuinely lapsed player ever receives it.

**Lifecycle.** `game.gd` cancels everything in `_ready()` (no point notifying someone who is
already looking at the game) and reschedules on the way out, from both
`NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_WM_CLOSE_REQUEST`. Paused is the one that
actually fires when an iOS app is backgrounded or swiped away, which is the case that matters.

**Copy** lives in `content.gd`'s `UI_TEXT` like every other user-facing string (AGENTS.md rule 2),
even though a native call site consumes it rather than a Control. A notification is the one
surface a translator cannot open the app to check.

## 2. The native half — not written, and here is exactly what it needs

This is where the honest part starts. `SpiritNotify` forwards to `Engine.get_singleton("SpiritIOSNotify")`.
**Nothing registers that singleton yet**, so on iOS today every call is a no-op and no
notification will ever appear. That is a deliberate stopping point, not an oversight.

**What was established while looking, because it changes the earlier assessment:**

| Checked | Result |
| --- | --- |
| Godot 4.7.2 iOS template | **a single `dummy.h` / `dummy.cpp` / `dummy.swift`**, copied verbatim into every generated Xcode project. No header set, no plugin macros. |
| `.gdip` descriptor support | present in the editor binary (`$linker_flags`, `initialization`, `deinitialization`, `is_plugin_enabled`) |
| `Engine.has_singleton` in the shipped static lib | present — so `SpiritNotify._native()` works if something registers it |
| Build source (`.a`/`.xcframework` with Godot headers) | **absent.** The template ships a prebuilt 700 MB static library, not a framework with public headers. |

That last row is the real constraint, and it is why this stops here rather than guessing. Godot's
documented iOS plugin flow assumes the plugin's static library is compiled against Godot's own
headers. This project's export template does not ship them. There are two ways forward, and
choosing between them needs a person, not a default:

- **A — reproduce the header set.** Obtain headers matching the 4.7.2 template's ABI (build them
  from the engine at that tag, or take them from a matching official build) and write a proper
  plugin: Swift wrapping `UNUserNotificationCenter`, registered via the plugin macros, with
  `$initialization` / `$deinitialization` in `dummy.cpp`.
- **B — use the template's own extension point, if it exists.** `dummy.cpp` is compiled *into*
  the app target and its contents are `$cpp_code`, a placeholder the engine substitutes. If this
  template's export accepts arbitrary C++ there, a registration shim could go in without any
  header set at all. **I have not confirmed that this substitution is live in 4.7.2** — the
  placeholder is present in the source, but whether the exporter fills it is unverified, and I am
  not going to claim it works by reading a template file.

Either route also needs: the Swift/Obj-C file added to the exported Xcode project's build phases
(the export regenerates that project every time, so this must be scripted in `deploy_ios.sh`, not
clicked once in Xcode), and one real-device run — iOS only shows the permission prompt once per
install, so a wrong first prompt can't be undone by reinstalling over it on a device that already
answered.

**Until this is finished, notifications are off in production and nothing in the game pretends
otherwise.** `SpiritNotify.is_supported()` is false and `test_runner.gd` asserts that, so a test
run on a Mac will never report notification delivery as verified.

## 3. The rating ask — shipped, and one value must be filled in before submission

`Godot/scripts/rate_prompt.gd` (`class_name SpiritRate`) plus a button on the victory screen.

**`APP_STORE_ID` is `0`, so the feature is currently dormant.** This is on purpose. The id cannot
exist until the app exists in App Store Connect; a placeholder would produce a URL that 404s, and
`is_available()` returning false means neither the button nor the open can happen. `test_runner.gd`
asserts that state — including that `should_prompt()` is false while the id is unset, so a build
with no id never shows a button that cannot do anything.

**Set it, and re-run the tests, as part of the submission checklist** (also in
`Docs/STORE_SUBMISSION.md`): replace the `0` with the numeric id from App Store Connect.

**Why a URL and not `SKStoreReviewController`.** The native API shows a non-blocking in-app sheet
and is invisibly rate-limited by the OS; the tradeoff is it needs the same native plugin as
Section 2. The URL route opens the App Store's write-review form, where the star row is already
visible. It works today, with no plugin. For a first launch, switching apps once, at a moment the
player has just earned, is a fair trade for not blocking the feature.

**Where it appears, and why there.** On the victory screen, only on a **Great Boss kill**, at most
once per save. The store research puts the first Great Boss as the deepest point a first-session
player reaches, which makes it the highest-intent moment available. It is a button, not an
automatic jump: yanking a player out of the app from under a victory screen is the same class of
unannounced interruption the shop and dismantle confirmations exist to prevent.

**What is deliberately not instrumented.** `rate_prompt_shown` and `rate_prompt_tapped`, no more.
No API reports whether a review was actually left, so the profile flag is named `rated_prompted`
and must never be read as "rated". A high shown-to-tapped ratio with flat rating growth would say
the ask is appearing at the wrong moment; it cannot say a review was left, and the code never
implies it can.

## Before submitting

- [ ] Decide route A or B for the native plugin (Section 2) and finish it, or ship with
      notifications off — both are acceptable, shipping with a half-wired one is not.
- [ ] Set `SpiritRate.APP_STORE_ID` to the real App Store id.
- [ ] One real-device pass over the notification permission prompt (it is once-per-install).
- [ ] Confirm the App Store privacy declaration matches: notifications and the rating ask add no
      new data collection, which is the reason both were chosen over SDKs that would.
