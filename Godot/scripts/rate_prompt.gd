extends RefCounted
class_name SpiritRate

# "Rate this game" prompting, and the reason it is a URL rather than a native call.
#
# iOS has a proper API for this (`SKStoreReviewController.requestReview`), but reaching it needs
# a native plugin — the same plugin SpiritNotify needs (see Docs/NOTIFICATIONS.md). Opening the
# App Store's *write a review* URL through `OS.shell_open` needs nothing at all: iOS hands it to
# the App Store app, the player lands on this game's review form with the star row already
# visible, and it works today. The tradeoff is real and worth stating: `requestReview` shows a
# non-blocking sheet and is rate-limited invisibly by the OS, whereas this switches apps. For a
# first launch, switching apps once, at a moment the player has just earned, is an acceptable
# trade for not blocking the feature on a plugin.

# Must be set to the real numeric App Store id before this does anything. It cannot be known
# until the app exists in App Store Connect, so it is deliberately left at 0 with
# `is_available()` returning false rather than shipping a URL that 404s — see
# Docs/NOTIFICATIONS.md's "before you submit" list.
const APP_STORE_ID := 0

# The stage the first Great Boss sits on. Used only to describe the moment in comments/tests; the
# actual trigger is `pending_rewards.great_boss_kill`, which is set by the reward flow itself.
const FIRST_GREAT_BOSS_STAGE := 50

static func is_available() -> bool:
	return APP_STORE_ID > 0

static func review_url() -> String:
	return "https://apps.apple.com/app/id%d?action=write-review" % APP_STORE_ID

# Asked at a moment the player earned, asked once, and never asked again.
#
# Deliberately NOT "after N launches" or "after N minutes": this game's own funnel data
# (Docs/COMPETITIVE_RESEARCH.md) says the first Great Boss kill is the deepest point a
# first-session player reaches, so it is the highest-intent moment available. Rating velocity is
# the discovery input that matters most for a title in this genre — the indie-tier median is
# only 270 ratings/year — so the first few hundred ratings are worth prompting for at the best
# available moment rather than at launch.
static func should_prompt(profile: Dictionary) -> bool:
	if not is_available():
		return false
	if bool(profile.get("rated_prompted", false)):
		return false
	# A player who has already reached a Great Boss but somehow has no kill recorded (a save
	# from an older build) still qualifies — the flag is what gates this, not the stat.
	return bool(profile.get("lifetime_stats", {}).get("bosses_slain", 0)) \
		or int(profile.get("unlocked", 0)) >= FIRST_GREAT_BOSS_STAGE

# Records that the ask happened, regardless of whether the player rated anything. There is no
# API that reports back whether a review was left, so this must never be treated as "rated".
static func mark_prompted(profile: Dictionary) -> void:
	profile.rated_prompted = true

# Returns whether a page was actually opened, so the caller can fall back to the in-game recap
# poster (game_rewards_screen.gd) instead of silently doing nothing.
static func open_review_page() -> bool:
	if not is_available():
		return false
	OS.shell_open(review_url())
	return true
