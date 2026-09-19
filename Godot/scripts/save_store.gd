extends RefCounted
class_name SpiritSave

const PATH := "user://spiritbound-save.json"
# Bump when the save shape changes; the sync layer will use it to decide on migration.
const SCHEMA_VERSION := 4

static func new_account() -> Dictionary:
	return {
		"id": _uuid(),
		"name": "",
		"provider": "guest",
		"user_id": "",
		"email": "",
		"linked_at": 0,
		"cloud_synced_at": 0,
		"created_at": int(Time.get_unix_time_from_system()),
	}

static func _uuid() -> String:
	# Random enough to identify a save across devices without a backend issuing ids.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chunks: Array[String] = []
	for i in 4: chunks.append("%08x" % rng.randi())
	return "-".join(chunks)

static func defaults(content: SpiritContent) -> Dictionary:
	var collection := {}
	for id in content.raw.startingDeck: collection[id] = collection.get(id,0) + 1
	return {"schema_version":SCHEMA_VERSION,"account":new_account(),"updated_at":0,"gold":30,"spirit_jade":10,"spirit_dust":0,"health":60,"unlocked":0,"position":0,"deck":content.raw.startingDeck.duplicate(),"collection":collection,"upgrades":{},"relics":[],"equipment_owned":[],"equipment_slots":{},"equipment_tiers":{},"equipment_inscriptions":{},"rune_inventory":{},"card_runes":{},"difficulty":0,"language":"zh-Hans","battle_speed":1.0,"hero_class":"fox_spirit","abyss_floor":1,"abyss_record":0,"abyss_boons":[],"daily_quests":[],"daily_reset_at":0,"weekly_quests":[],"weekly_reset_at":0,"claimed_stage_events":[],"compendium_discovered":{},"compendium_milestones_claimed":[],"hero_masteries":{},"daily_trial_record":{"day":-1,"stage":0,"badges":0,"best_stage":0,"streak":0,"streak_claimed":[],"history":[]},"tutorial_seen":false,"tutorials_seen":{},"login_reward":{"week":-1,"days":[],"claimed":[]},"lifetime_stats":{},"achievements_unlocked":{},"reduce_motion":false,"season_pass":{"season_id":1,"season_name":"灵火初醒","xp":0,"claimed_free":[],"claimed_premium":[]},"boss_rush_floor":1,"boss_rush_record":0,"text_scale":1.0,"idle_harvest":{"last_claim_time":0,"last_fast_claim_day":-1},"phantom_arena":{"day":-1,"wins_today":0,"claimed_today":false},"novice_journey":{"claimed":[]},"daily_first_win":{"day":-1,"claimed":false},"combat_consumables":{"strength":0,"focus":0,"energy":0},"stamina":{"current":100,"max":100,"last_regen_time":0},"samsara_count":0,"intro_seen":false,"meridians":{},"career_stats":{"defeats":0,"total_shield_gained":0,"total_cards_played":0,"elites_slain":0,"bosses_slain":0,"current_win_streak":0,"longest_win_streak":0,"favorite_cards":{},"favorite_hero":{},"hall_of_fame":[]},"curse_run":{"selected":"","floors":{},"records":{},"cleared":[]},"world_event_record":{"period":-1,"claimed":false,"badges":[]}}

static func load_profile(content: SpiritContent) -> Dictionary:
	var base := defaults(content)
	if not FileAccess.file_exists(PATH): return base
	var file := FileAccess.open(PATH,FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return base
	for key in parsed: base[key] = parsed[key]
	if not base.deck is Array or base.deck.size() != 25: base.deck = content.raw.startingDeck.duplicate()
	var last_stage: int = content.encounters.size() - 1
	base.health = clampi(int(base.health),1,60)
	base.unlocked = clampi(int(base.unlocked),0,last_stage)
	base.position = clampi(int(base.position),0,last_stage)
	if not base.has("intro_seen"): base.intro_seen = false
	if not base.has("samsara_count"): base.samsara_count = 0
	if not base.has("spirit_jade"): base.spirit_jade = 10
	if not base.has("spirit_dust"): base.spirit_dust = 0
	if not base.get("meridians") is Dictionary: base.meridians = {}
	if not base.get("equipment_tiers") is Dictionary: base.equipment_tiers = {}
	if not base.get("equipment_inscriptions") is Dictionary: base.equipment_inscriptions = {}
	if not base.get("tutorials_seen") is Dictionary: base.tutorials_seen = {}
	if not base.get("claimed_stage_events") is Array: base.claimed_stage_events = []
	if not base.get("abyss_boons") is Array: base.abyss_boons = []
	if not base.get("compendium_discovered") is Dictionary: base.compendium_discovered = {}
	if not base.get("compendium_milestones_claimed") is Array: base.compendium_milestones_claimed = []
	if not base.get("hero_masteries") is Dictionary: base.hero_masteries = {}
	if not base.get("daily_trial_record") is Dictionary:
		base.daily_trial_record = {"day":-1,"stage":0,"badges":0,"best_stage":0,"streak":0,"streak_claimed":[],"history":[]}
	else:
		if not base.daily_trial_record.has("streak"): base.daily_trial_record.streak = 0
		if not base.daily_trial_record.has("streak_claimed"): base.daily_trial_record.streak_claimed = []
		if not base.daily_trial_record.has("history"): base.daily_trial_record.history = []
	if not base.get("login_reward") is Dictionary: base.login_reward = {"week":-1,"days":[],"claimed":[]}
	if not base.get("lifetime_stats") is Dictionary: base.lifetime_stats = {}
	if not base.get("achievements_unlocked") is Dictionary: base.achievements_unlocked = {}
	if not base.has("reduce_motion"): base.reduce_motion = false
	if not base.get("season_pass") is Dictionary:
		base.season_pass = {"season_id":1,"season_name":"灵火初醒","xp":0,"claimed_free":[],"claimed_premium":[]}
	if not base.get("draft_arena") is Dictionary:
		base.draft_arena = {"active": false, "wins": 0, "losses": 0, "round": 1, "deck": [], "current_pool": []}
	if not base.has("boss_rush_floor"): base.boss_rush_floor = 1
	if not base.has("boss_rush_record"): base.boss_rush_record = 0
	if not base.has("text_scale"): base.text_scale = 1.0
	if not base.get("idle_harvest") is Dictionary:
		base.idle_harvest = {"last_claim_time":0,"last_fast_claim_day":-1}
	if not base.get("phantom_arena") is Dictionary:
		base.phantom_arena = {"day":-1,"wins_today":0,"claimed_today":false}
	if not base.get("novice_journey") is Dictionary:
		base.novice_journey = {"claimed":[]}
	if not base.get("daily_first_win") is Dictionary:
		base.daily_first_win = {"day":-1,"claimed":false}
	if not base.get("combat_consumables") is Dictionary:
		base.combat_consumables = {"strength":0,"focus":0,"energy":0}
	if not base.get("career_stats") is Dictionary:
		base.career_stats = {"defeats":0,"total_shield_gained":0,"total_cards_played":0,"elites_slain":0,"bosses_slain":0,"current_win_streak":0,"longest_win_streak":0,"favorite_cards":{},"favorite_hero":{},"hall_of_fame":[]}
	else:
		for key in ["defeats","total_shield_gained","total_cards_played","elites_slain","bosses_slain","current_win_streak","longest_win_streak"]:
			if not base.career_stats.has(key): base.career_stats[key] = 0
		if not base.career_stats.get("favorite_cards") is Dictionary: base.career_stats.favorite_cards = {}
		if not base.career_stats.get("favorite_hero") is Dictionary: base.career_stats.favorite_hero = {}
		if not base.career_stats.get("hall_of_fame") is Array: base.career_stats.hall_of_fame = []
	if not base.get("curse_run") is Dictionary:
		base.curse_run = {"selected":"","floors":{},"records":{},"cleared":[]}
	else:
		if not base.curse_run.has("selected"): base.curse_run.selected = ""
		if not base.curse_run.get("floors") is Dictionary: base.curse_run.floors = {}
		if not base.curse_run.get("records") is Dictionary: base.curse_run.records = {}
		if not base.curse_run.get("cleared") is Array: base.curse_run.cleared = []
	if not base.get("world_event_record") is Dictionary:
		base.world_event_record = {"period":-1,"claimed":false,"badges":[]}
	else:
		if not base.world_event_record.has("period"): base.world_event_record.period = -1
		if not base.world_event_record.has("claimed"): base.world_event_record.claimed = false
		if not base.world_event_record.get("badges") is Array: base.world_event_record.badges = []
	if not base.get("stamina") is Dictionary:
		base.stamina = {"current":100,"max":100,"last_regen_time":0}
	else:
		if not base.stamina.has("current"): base.stamina.current = 100
		if not base.stamina.has("max"): base.stamina.max = 100
		if not base.stamina.has("last_regen_time"): base.stamina.last_regen_time = 0
	# Saves written before accounts existed get one on load rather than on next write.
	if not base.get("account") is Dictionary or not base.account.has("id"): base.account = new_account()
	if not base.account.has("provider") or base.account.provider == "local": base.account.provider = "guest"
	if not base.account.has("user_id"): base.account.user_id = ""
	if not base.account.has("email"): base.account.email = ""
	if not base.account.has("linked_at"): base.account.linked_at = 0
	if not base.account.has("cloud_synced_at"): base.account.cloud_synced_at = 0
	base.schema_version = SCHEMA_VERSION
	return base

static func write(profile: Dictionary) -> void:
	# updated_at is what a future cloud sync compares to resolve which copy is newer.
	profile.updated_at = int(Time.get_unix_time_from_system())
	profile.schema_version = SCHEMA_VERSION
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(profile,"  "))

static func has_account_name(profile: Dictionary) -> bool:
	return not str(profile.get("account", {}).get("name", "")).strip_edges().is_empty()

static func is_cloud_linked(profile: Dictionary) -> bool:
	var provider: String = str(profile.get("account", {}).get("provider", "guest"))
	var user_id: String = str(profile.get("account", {}).get("user_id", "")).strip_edges()
	return (provider in ["apple", "google", "supabase", "email"]) and not user_id.is_empty()

static func account_provider(profile: Dictionary) -> String:
	return str(profile.get("account", {}).get("provider", "guest"))

static func link_account(profile: Dictionary, provider: String, user_id: String, email: String = "", display_name: String = "") -> void:
	if not profile.get("account") is Dictionary:
		profile.account = new_account()
	profile.account.provider = provider
	profile.account.user_id = user_id
	if not email.is_empty():
		profile.account.email = email
	if not display_name.is_empty() and str(profile.account.get("name", "")).strip_edges().is_empty():
		profile.account.name = display_name
	profile.account.linked_at = int(Time.get_unix_time_from_system())
	profile.account.cloud_synced_at = int(Time.get_unix_time_from_system())
	write(profile)

static func unlink_account(profile: Dictionary) -> void:
	if not profile.get("account") is Dictionary:
		profile.account = new_account()
	profile.account.provider = "guest"
	profile.account.user_id = ""
	profile.account.email = ""
	profile.account.linked_at = 0
	profile.account.cloud_synced_at = 0
	write(profile)

static func reset() -> void:
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(PATH)
