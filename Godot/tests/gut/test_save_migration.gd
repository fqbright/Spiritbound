extends GutTest
# Regression coverage for SpiritSave.load_profile()'s migration path — loading a save file
# shaped like an older schema must fill in sane defaults for every field added since, without
# crashing and without clobbering whatever real data the old save already had. Directly
# motivated by the rebirth_count/samsara_count collision found while merging two parallel
# prestige-system implementations: two independently-built features both added a new profile
# field to defaults()'s same giant dictionary literal, and nothing in this suite previously
# exercised "what does loading a save from before either field existed actually produce."
#
# Writes fixture JSON directly to the real save file (SpiritSave.PATH) and restores whatever
# was really there afterward — the same borrow-and-restore discipline ui_smoke.gd already
# follows for the same file, so this suite doesn't contaminate a real save or other test runs.

var content: SpiritContent
var had_real_save: bool
var real_save_text: String

func before_all():
	content = SpiritContent.new()
	had_real_save = FileAccess.file_exists(SpiritSave.PATH)
	if had_real_save:
		real_save_text = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()

func after_all():
	if had_real_save:
		FileAccess.open(SpiritSave.PATH, FileAccess.WRITE).store_string(real_save_text)
	else:
		SpiritSave.reset()

func _write_fixture(data) -> void:
	FileAccess.open(SpiritSave.PATH, FileAccess.WRITE).store_string(JSON.stringify(data))

func test_ancient_save_missing_most_fields_gets_sane_defaults():
	# Simulates a save from well before samsara_count/spirit_jade/hero_masteries/stamina/
	# draft_arena/phantom_arena/... existed — only the handful of fields present at the very
	# start of this save format.
	_write_fixture({
		"gold": 250, "health": 45, "unlocked": 12, "position": 12,
		"deck": content.raw.startingDeck, "difficulty": 2,
	})
	var profile: Dictionary = SpiritSave.load_profile(content)

	# Real data the old save actually had must survive migration untouched.
	assert_eq(int(profile.gold), 250, "an old save's real gold value survives migration")
	assert_eq(int(profile.unlocked), 12, "an old save's real campaign progress survives migration")
	assert_eq(int(profile.difficulty), 2, "an old save's real difficulty selection survives migration")

	# Every field added to the save shape since must get a sane default, not be absent/null.
	assert_eq(int(profile.get("samsara_count", -1)), 0, "samsara_count defaults to 0 on an ancient save")
	assert_eq(int(profile.get("spirit_jade", -1)), 10, "spirit_jade defaults on an ancient save")
	assert_eq(int(profile.get("spirit_dust", -1)), 0, "spirit_dust defaults on an ancient save")
	assert_true(profile.get("hero_masteries") is Dictionary, "hero_masteries defaults to a Dictionary on an ancient save")
	assert_true(profile.get("achievements_unlocked") is Dictionary, "achievements_unlocked defaults to a Dictionary")
	assert_true(profile.get("stamina") is Dictionary and int(profile.stamina.get("current", -1)) == 100, "stamina defaults fully (current=100) on an ancient save")
	assert_true(profile.get("draft_arena") is Dictionary, "draft_arena defaults to a Dictionary on an ancient save")
	assert_true(profile.get("phantom_arena") is Dictionary, "phantom_arena defaults to a Dictionary on an ancient save")
	assert_true(profile.get("novice_journey") is Dictionary, "novice_journey defaults to a Dictionary on an ancient save")
	assert_true(profile.get("combat_consumables") is Dictionary, "combat_consumables defaults to a Dictionary on an ancient save")
	assert_true(profile.get("idle_harvest") is Dictionary, "idle_harvest defaults to a Dictionary on an ancient save")
	assert_true(profile.get("account") is Dictionary and profile.account.has("id"), "a save from before accounts existed gets one assigned on load")
	assert_eq(int(profile.schema_version), SpiritSave.SCHEMA_VERSION, "schema_version is always bumped to current on load")

func test_daily_trial_record_missing_newer_subfields_gets_upgraded_in_place():
	_write_fixture({
		"gold": 80,
		"daily_trial_record": {"day": 5, "stage": 9, "badges": 2, "best_stage": 9},
	})
	var profile: Dictionary = SpiritSave.load_profile(content)
	assert_eq(int(profile.daily_trial_record.day), 5, "existing daily_trial_record.day survives migration")
	assert_eq(int(profile.daily_trial_record.stage), 9, "existing daily_trial_record.stage survives migration")
	assert_eq(int(profile.daily_trial_record.get("streak", -1)), 0, "daily_trial_record.streak is backfilled when the record predates it")
	assert_true(profile.daily_trial_record.get("streak_claimed") is Array, "daily_trial_record.streak_claimed is backfilled when missing")
	assert_true(profile.daily_trial_record.get("history") is Array, "daily_trial_record.history is backfilled when missing")

func test_account_missing_newer_subfields_gets_upgraded_in_place():
	_write_fixture({
		"gold": 80,
		"account": {"id": "existing-real-uuid", "name": "Traveler"},
	})
	var profile: Dictionary = SpiritSave.load_profile(content)
	assert_eq(str(profile.account.id), "existing-real-uuid", "an existing account id survives migration, is not replaced")
	assert_eq(str(profile.account.name), "Traveler", "an existing account name survives migration")
	assert_eq(str(profile.account.get("provider", "")), "guest", "account.provider is backfilled to guest when missing")
	assert_eq(str(profile.account.get("user_id", "MISSING")), "", "account.user_id is backfilled to an empty string when missing")
	assert_eq(int(profile.account.get("linked_at", -1)), 0, "account.linked_at is backfilled when missing")

func test_feature_unlocks_seen_backfills_already_crossed_thresholds_on_ancient_save():
	# An old save has necessarily already lived past whatever unlock thresholds it currently
	# exceeds, so migration must mark those as "already seen" — otherwise a returning player
	# with unlocked=12 would get a "New: Endless Abyss!" toast for a mode they've had for weeks.
	# unlocked=12 clears ch1_features (>=5) and abyss (>=10) but not difficulty_tiers (>=25);
	# difficulty=2 clears curse_run (>=2) independently, on the other profile field.
	_write_fixture({"gold": 80, "unlocked": 12, "difficulty": 2})
	var profile: Dictionary = SpiritSave.load_profile(content)
	var seen: Array = profile.feature_unlocks_seen
	assert_true(seen.has("ch1_features"), "unlocked=12 backfills ch1_features (threshold 5) as already seen")
	assert_true(seen.has("abyss"), "unlocked=12 backfills abyss (threshold 10) as already seen")
	assert_true(seen.has("curse_run"), "difficulty=2 backfills curse_run (threshold 2) as already seen")
	assert_false(seen.has("difficulty_tiers"), "unlocked=12 has not crossed difficulty_tiers' threshold of 25, so it is not backfilled")

func test_feature_unlocks_seen_empty_on_brand_new_save():
	var profile: Dictionary = SpiritSave.defaults(content)
	assert_true(profile.feature_unlocks_seen is Array and profile.feature_unlocks_seen.is_empty(), "a fresh save starts with no unlocks marked seen, since unlocked/difficulty both start at 0")

func test_feature_unlocks_seen_backfills_new_entries_added_after_the_field_already_existed():
	# Regression test for a real bug: the original backfill only ran when feature_unlocks_seen
	# was entirely ABSENT, so a save that already had the field (from a previous version of this
	# game) never got re-checked when SpiritContent.FEATURE_UNLOCKS itself later grew new
	# entries (exactly what happened when the per-tier A2-A5 unlock toasts were added). Without
	# this, an existing player already at unlocked=120 — past tier_a2 (50) and tier_a3 (100)'s
	# thresholds — would have both of those toasts fire back to back on their very next battle
	# win, for tiers they'd already had available for weeks.
	_write_fixture({
		"gold": 80, "unlocked": 120, "difficulty": 0,
		"feature_unlocks_seen": ["ch1_features", "abyss", "difficulty_tiers"],
	})
	var profile: Dictionary = SpiritSave.load_profile(content)
	var seen: Array = profile.feature_unlocks_seen
	assert_true(seen.has("ch1_features") and seen.has("abyss") and seen.has("difficulty_tiers"), "entries already marked seen before this version survive migration untouched")
	assert_true(seen.has("tier_a2"), "unlocked=120 backfills the newly-added tier_a2 (threshold 50) as already seen, even though feature_unlocks_seen already existed")
	assert_true(seen.has("tier_a3"), "unlocked=120 backfills the newly-added tier_a3 (threshold 100) as already seen")
	assert_false(seen.has("tier_a4"), "unlocked=120 has not crossed tier_a4's threshold of 150, so it is correctly not backfilled")

func test_corrupted_deck_falls_back_to_starting_deck():
	_write_fixture({"gold": 80, "deck": ["strike", "ward"]})
	var profile: Dictionary = SpiritSave.load_profile(content)
	assert_eq(profile.deck.size(), 25, "a deck with the wrong card count falls back to the 25-card starting deck")
	assert_eq(profile.deck, content.raw.startingDeck, "the fallback deck matches startingDeck exactly")

func test_completely_invalid_json_falls_back_to_defaults_without_crashing():
	FileAccess.open(SpiritSave.PATH, FileAccess.WRITE).store_string("this is not valid json {{{")
	var profile: Dictionary = SpiritSave.load_profile(content)
	assert_eq(int(profile.gold), 30, "invalid JSON falls back to a fresh default profile rather than crashing")
	assert_eq(int(profile.unlocked), 0, "invalid JSON's fallback profile starts at stage 0")

func test_valid_json_that_is_not_an_object_falls_back_to_defaults():
	_write_fixture("just a string, not a save object")
	var profile: Dictionary = SpiritSave.load_profile(content)
	assert_eq(int(profile.gold), 30, "a JSON value that isn't a Dictionary falls back to a fresh default profile")
