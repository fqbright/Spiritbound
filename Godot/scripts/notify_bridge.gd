extends RefCounted
class_name SpiritNotify

# Local (not remote) iOS notifications for the three retention cycles this game already runs:
# the daily trial/quest reset, the weekly challenge/log reset, the rolling weekly login reward,
# and a re-engagement nudge for a player who has stopped opening the app.
#
# WHY THIS EXISTS: the game ships three separate reset cycles and, before this file, no way to
# tell a lapsed player that any of them happened. A local notification needs no server, no APNs
# certificate and no `UIBackgroundModes` entitlement — the OS fires it whether or not the app is
# running — which is exactly the shape this feature wants.
#
# WHAT THIS FILE IS AND IS NOT. This is the entire verifiable half: the scheduling policy (a pure
# function, `due_reminders`, so it can be asserted headlessly) and the wrapper that forwards to
# the native side. The native side is NOT here yet — see `_native()` below and
# Docs/NOTIFICATIONS.md. Everything in this file is a no-op off iOS, so the headless suites can
# call it freely; that split is deliberate and is what keeps a platform dependency one layer
# above `combat.gd`.

const IOS_SINGLETON := "SpiritIOSNotify"

const ID_DAILY := "spiritbound.daily"
const ID_WEEKLY := "spiritbound.weekly"
const ID_LOGIN := "spiritbound.login"
const ID_RETURN := "spiritbound.return"

const DAY_SECONDS := 86400
const WEEK_SECONDS := 604800

# Local hour to fire a "cycle reset" reminder at, measured from the reset boundary. The day/week
# bucket in this game is derived from unix time, not from the device's calendar, so these fire
# at a fixed offset rather than at a wall-clock hour the player would recognise. 10:00-ish after
# the reset was chosen over firing at the boundary itself: a notification delivered at midnight
# is one most players wake up to already dismissed.
const RESET_REMINDER_OFFSET := 10 * 3600
# Evening nudge for a login streak that is about to be broken or extended.
const LOGIN_REMINDER_OFFSET := 19 * 3600
# "Come back" nudge, scheduled from the moment the app is closed rather than from a boundary.
const RETURN_DELAY := 3 * DAY_SECONDS

# --- native forwarding -------------------------------------------------------------------

# The native plugin singleton, or null when it isn't there (every non-iOS run, and any iOS build
# until the plugin is compiled in — see Docs/NOTIFICATIONS.md). Callers must never notice the
# difference, which is why every public function below checks this first.
static func _native() -> Object:
	if not Engine.has_singleton(IOS_SINGLETON):
		return null
	return Engine.get_singleton(IOS_SINGLETON)

static func is_supported() -> bool:
	return _native() != null

# Idempotent, and safe to call on every launch: iOS only ever shows the system prompt once.
static func request_permission() -> void:
	var plugin := _native()
	if plugin != null:
		plugin.call("requestPermission")

static func schedule(id: String, title: String, body: String, fire_unix_time: int) -> void:
	var plugin := _native()
	if plugin != null:
		plugin.call("schedule", id, title, body, fire_unix_time)

static func cancel(id: String) -> void:
	var plugin := _native()
	if plugin != null:
		plugin.call("cancel", id)

static func cancel_all() -> void:
	var plugin := _native()
	if plugin != null:
		plugin.call("cancelAll")

# --- scheduling policy -------------------------------------------------------------------

# Everything the player could be reminded about, as `{id, title, body, fire_unix}` in
# `content.UI_TEXT` key form rather than as resolved strings — so this stays a pure function and
# the wrapper does the localising. Sorted soonest-first; at most one entry per id.
#
# Kept free of `Time.get_unix_time_from_system()` on purpose: `now_unix` is a parameter, so a
# test can drive any date straight through it instead of waiting three days to see a reminder.
static func due_reminders(profile: Dictionary, now_unix: int) -> Array:
	var out: Array = []
	var unlocked: int = int(profile.get("unlocked", 0))
	# Nothing before Chapter 1: a player who has not met the daily trial yet should not be
	# notified about it. Mirrors the `unlocked >= 5` gate the Camp tabs themselves use.
	if unlocked < 5:
		return out
	var day: int = now_unix / DAY_SECONDS
	var week: int = now_unix / WEEK_SECONDS
	var next_day: int = (day + 1) * DAY_SECONDS
	var next_week: int = (week + 1) * WEEK_SECONDS

	var trial: Dictionary = profile.get("daily_trial_record", {})
	if int(trial.get("day", -1)) != day:
		out.append(_entry(ID_DAILY, "push.daily.title", "push.daily.body",
			next_day + RESET_REMINDER_OFFSET))

	var weekly: Dictionary = profile.get("weekly_challenge_record", {})
	if int(weekly.get("week", -1)) != week:
		out.append(_entry(ID_WEEKLY, "push.weekly.title", "push.weekly.body",
			next_week + RESET_REMINDER_OFFSET))

	# The login reward is the one cycle with a deadline that can still be missed after it resets
	# (the week's tally rolls over), so it gets an evening nudge on top of tomorrow's reset one.
	var login: Dictionary = profile.get("login_reward", {})
	var logged: Array = login.get("days", [])
	if logged.size() < 7:
		out.append(_entry(ID_LOGIN, "push.login.title", "push.login.body",
			next_day + LOGIN_REMINDER_OFFSET))

	# Re-engagement. Scheduled from the moment of closing, so it is only ever delivered to a
	# player who genuinely stopped — rescheduling on every close (see SpiritNotify.reschedule)
	# means an active player's copy keeps being pushed back and never arrives.
	out.append(_entry(ID_RETURN, "push.return.title", "push.return.body", now_unix + RETURN_DELAY))
	return out

static func _entry(id: String, title_key: String, body_key: String, fire_unix: int) -> Dictionary:
	return {"id": id, "title": title_key, "body": body_key, "fire_unix": fire_unix}

# Replace every pending Spiritbound reminder with a fresh set for the current profile.
#
# Cancel-then-schedule, never "schedule once": without the cancel, a quest claimed and then the
# app closed again would leave the already-resolved reminder pending, and the player would be
# notified about a cycle they had already completed. Called on every close, not once per save.
#
# `resolve` is the caller's localisation function (`game.gd`'s `t`), passed in rather than looked
# up here because `SpiritContent`'s string helpers are instance methods and building an instance
# just to read a string table would drag content bootstrapping into a close handler. It also
# makes this function testable with a plain stub that returns the key.
static func reschedule(profile: Dictionary, now_unix: int, resolve: Callable) -> Array:
	cancel_all()
	var scheduled: Array = []
	for reminder in due_reminders(profile, now_unix):
		var item: Dictionary = reminder
		schedule(
			str(item.get("id", "")),
			str(resolve.call(str(item.get("title", "")))),
			str(resolve.call(str(item.get("body", "")))),
			int(item.get("fire_unix", 0)))
		scheduled.append(item.get("id"))
	return scheduled
