extends RefCounted
class_name LogService

# ==============================================================================
# Crash-adjacent logging + minimal analytics (Docs/LAUNCH_READINESS.md Section 3)
# ==============================================================================
# Two jobs, both deliberately small:
#
# 1. A "did the previous session end cleanly?" signal. GDScript has no try/catch and script code
#    inside a crashing process cannot run after the crash, so this is NOT full crash reporting —
#    it is the honest ceiling: a marker file written at launch and removed on a clean shutdown.
#    If the next launch finds the marker still present, the previous session did not exit
#    cleanly, and we upload the tail of Godot's own log file as an `error` event. Read the code
#    comment, not just the name: this catches unclean exits, not every crash, and never claims to.
#
# 2. A tiny funnel: a handful of named events posted to `public.client_events`, answering "did
#    the tutorial work" and "did anyone come back". Keep the list short on purpose.
#
# Every network call here is fire-and-forget and must never block or crash the game — see
# SupabaseClient.post_client_event(), which returns a result but is safe to ignore.

const SESSION_MARKER_PATH := "user://session_open.marker"
# Godot's own rotating log file, only written when debug/file_logging/enable_file_logging is on
# (see project.godot). Path is the engine default.
const ENGINE_LOG_PATH := "user://logs/godot.log"
const CRASH_TAIL_LINES := 60

# Starter funnel — the deliberately small set from the launch doc. Add sparingly.
const EV_TUTORIAL_STARTED := "tutorial_started"
const EV_TUTORIAL_COMPLETED := "tutorial_completed"
const EV_FIRST_BATTLE_WON := "first_battle_won"
const EV_STAGE_25_REACHED := "stage_25_reached"
const EV_DAY2_RETURN := "day2_return"
const EV_DAY7_RETURN := "day7_return"

# Onboarding-entry funnel. These exist because the very first screen a new player can be asked to
# interact with had no instrumentation at all, which made the most likely early drop-off the one
# thing the data could not show.
#
# `SpiritGame._ready` routes a player with no account name to the account setup screen *before*
# the map and before any battle, so the ordering a new player meets is: intro cutscene -> type a
# name -> map -> first fight. The first event in this file (`tutorial_started`) is only emitted
# from the battle screen, i.e. after that gate, so a player who quit at the name prompt produced
# no event whatsoever — indistinguishable in the data from someone who never launched the game.
#
# `shown` and `completed` are separated on purpose: the interesting quantity is the ratio, and a
# screen that is shown and never completed is a specific, fixable finding. `detail.method` records
# which path got them through (typed name / Apple / Google / email), which is what decides whether
# the third-party sign-in buttons are pulling their weight.
const EV_ACCOUNT_SETUP_SHOWN := "account_setup_shown"
const EV_ACCOUNT_SETUP_COMPLETED := "account_setup_completed"
const EV_INTRO_COMPLETED := "intro_completed"

# Every event name this file defines, so a test can assert that each one is actually emitted
# somewhere instead of trusting a constant that nothing calls. A declared-but-never-fired event is
# invisible: it looks like a metric, it reports nothing, and no crash tells you.
const ALL_EVENTS := [
	EV_TUTORIAL_STARTED, EV_TUTORIAL_COMPLETED, EV_FIRST_BATTLE_WON, EV_STAGE_25_REACHED,
	EV_DAY2_RETURN, EV_DAY7_RETURN,
	EV_ACCOUNT_SETUP_SHOWN, EV_ACCOUNT_SETUP_COMPLETED, EV_INTRO_COMPLETED,
]

# ------------------------------------------------------------------------------
# Clean-shutdown marker
# ------------------------------------------------------------------------------

static func mark_session_start() -> void:
	var f := FileAccess.open(SESSION_MARKER_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(str(Time.get_unix_time_from_system()))

static func clear_session_marker() -> void:
	if FileAccess.file_exists(SESSION_MARKER_PATH):
		DirAccess.remove_absolute(SESSION_MARKER_PATH)

# True when a previous launch wrote the marker but never cleared it — i.e. it did not shut down
# cleanly. Pure filesystem check, no network: safe to call and assert from tests.
static func previous_session_crashed() -> bool:
	return FileAccess.file_exists(SESSION_MARKER_PATH)

static func crash_log_tail(max_lines: int = CRASH_TAIL_LINES) -> String:
	if not FileAccess.file_exists(ENGINE_LOG_PATH):
		return ""
	var f := FileAccess.open(ENGINE_LOG_PATH, FileAccess.READ)
	if f == null:
		return ""
	var all := f.get_as_text()
	var lines := all.split("\n")
	var start := maxi(0, lines.size() - max_lines)
	var tail: PackedStringArray = []
	for i in range(start, lines.size()):
		tail.append(lines[i])
	return "\n".join(tail)

# Called once from SpiritGame._ready(). Records the session, and if the previous one died
# uncleanly, uploads its log tail. Guarded against the headless test runner: tests must not fire
# a real network POST at startup, and a repeated in-process relaunch would otherwise look like a
# "crash" every run. Real devices (any non-headless display) get the feature.
static func begin_session(game: Node = null, report_crash: bool = true) -> void:
	var crashed := previous_session_crashed()
	mark_session_start()
	if crashed and report_crash and DisplayServer.get_name() != "headless":
		post_event("error", "unclean_session_exit", {
			"log_tail": crash_log_tail(),
		}, game)

# Called from SpiritGame._notification(WmCloseRequest) — a normal, player-initiated quit.
static func end_session_cleanly() -> void:
	clear_session_marker()

# ------------------------------------------------------------------------------
# Analytics / error events
# ------------------------------------------------------------------------------

static func post_event(kind: String, name: String, detail: Dictionary = {}, node: Node = null) -> Dictionary:
	return await SupabaseClient.post_client_event(kind, name, detail, node)

# Fire-and-forget wrapper for call sites that don't care about the result and must not wait.
static func event(name: String, detail: Dictionary = {}, node: Node = null) -> void:
	post_event("event", name, detail, node)
