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
	return {"schema_version":SCHEMA_VERSION,"account":new_account(),"updated_at":0,"gold":30,"spirit_jade":10,"spirit_dust":0,"health":60,"unlocked":0,"position":0,"deck":content.raw.startingDeck.duplicate(),"deck_presets":{"1":content.raw.startingDeck.duplicate(),"2":content.raw.startingDeck.duplicate(),"3":content.raw.startingDeck.duplicate()},"deck_preset_names":{"1":"预设 1","2":"预设 2","3":"预设 3"},"active_deck_preset":1,"foil_cards":[],"run_history":[],"familiar_stage":0,"familiar_affinity":0,"astral_roots":{"metal":0,"wood":0,"water":0,"fire":0,"earth":0},"astral_sparks":0,"pagoda_highest_floor":1,"card_affixes":{},"fused_cards":[],"active_hexagram":"","bestiary_kills":{},"hero_skins":{"fox_spirit":"default","ironclad_sentinel":"default"},"auto_battle_enabled":false,"collection":collection,"upgrades":{},"card_branches":{},"first_boss_capstone_awarded":false,"seven_day_journey":{"unlocked_day":1,"claimed":[],"progress":{}},"relics":[],"equipment_owned":[],"equipment_slots":{},"equipment_tiers":{},"equipment_inscriptions":{},"rune_inventory":{},"card_runes":{},"difficulty":0,"language":"zh-Hans","battle_speed":1.0,"hero_class":"fox_spirit","abyss_floor":1,"abyss_record":0,"abyss_boons":[],"daily_quests":[],"daily_reset_at":0,"weekly_quests":[],"weekly_reset_at":0,"claimed_stage_events":[],"compendium_discovered":[],"compendium_milestones_claimed":[],"hero_masteries":{},"daily_trial_record":{"day":-1,"stage":0,"badges":0,"best_stage":0,"streak":0,"streak_claimed":[],"history":[]},"tutorial_seen":false,"tutorials_seen":{},"login_reward":{"week":-1,"days":[],"claimed":[]},"lifetime_stats":{},"career_stats":{"total_battles":0,"victories":0,"defeats":0,"current_win_streak":0,"longest_win_streak":0,"total_damage_dealt":0,"total_shield_gained":0,"total_cards_played":0,"elites_slain":0,"bosses_slain":0,"favorite_hero":"fox_spirit","favorite_cards":{},"hall_of_fame":[]},"achievements_unlocked":{},"achievements_claimed":{},"reduce_motion":false,"season_pass":{"season_id":1,"season_name":"灵火初醒","xp":0,"claimed_free":[],"claimed_premium":[]},"boss_rush_floor":1,"boss_rush_record":0,"text_scale":1.0,"idle_harvest":{"last_claim_time":0,"last_fast_claim_day":-1},"phantom_arena":{"day":-1,"wins_today":0,"claimed_today":false},"novice_journey":{"claimed":[]},"daily_first_win":{"day":-1,"claimed":false},"combat_consumables":{"strength":0,"focus":0,"energy":0},"stamina":{"current":100,"max":100,"last_regen_time":0},"samsara_count":0,"intro_seen":false,"meridians":{},"curse_run":{"selected":"","floors":{},"records":{},"cleared":[]},"world_event_record":{"period":-1,"claimed":false,"badges":[]},"feature_unlocks_seen":[],"friends":[],"first_seen_day":-1,"return_days_reported":[],"win_streak":0,"max_win_streak":0,"haptics_enabled":true,"music_volume":1.0,"sfx_volume":1.0,"ascension_level":0,"highest_ascension":0,"phantom_guard":{},"pending_sync_queue":[],"daily_challenge_runs":{},"fast_combat":false,"target_fps":60,"eco_mode":false,"card_mastery":{},"herb_garden":{"purple_lingzhi":3,"sun_grass":3,"frost_flower":3,"last_harvest_time":0},"alchemy_pills":{"qi_pill":1,"iron_shield_pill":1,"nine_turn_pill":0},"pagoda_soul_pacts":[],"destiny_boons":[]}

static func load_profile(content: SpiritContent) -> Dictionary:
	var base := defaults(content)
	var parsed = null
	if FileAccess.file_exists(PATH):
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var txt: String = file.get_as_text()
			if not txt.is_empty():
				parsed = JSON.parse_string(txt)
	# If primary save is missing or corrupted, attempt recovery from .bak
	if not parsed is Dictionary and FileAccess.file_exists(PATH + ".bak"):
		var bak_file := FileAccess.open(PATH + ".bak", FileAccess.READ)
		if bak_file != null:
			var bak_txt: String = bak_file.get_as_text()
			if not bak_txt.is_empty():
				var bak_parsed = JSON.parse_string(bak_txt)
				if bak_parsed is Dictionary:
					parsed = bak_parsed
	if not parsed is Dictionary: return base
	for key in parsed: base[key] = parsed[key]
	base.gold = maxi(0, int(base.get("gold", 30)))
	base.spirit_jade = maxi(0, int(base.get("spirit_jade", 10)))
	base.spirit_dust = maxi(0, int(base.get("spirit_dust", 0)))
	base.music_volume = clampf(float(base.get("music_volume", 1.0)), 0.0, 1.0)
	base.sfx_volume = clampf(float(base.get("sfx_volume", 1.0)), 0.0, 1.0)
	base.text_scale = clampf(float(base.get("text_scale", 1.0)), 0.8, 1.3)
	if not base.deck is Array or base.deck.size() < 12 or base.deck.size() > 50: base.deck = content.raw.startingDeck.duplicate()
	if base.get("deck_presets") is Dictionary:
		for p_key in base.deck_presets:
			var p_deck = base.deck_presets[p_key]
			if not p_deck is Array or p_deck.size() < 12 or p_deck.size() > 50:
				base.deck_presets[p_key] = content.raw.startingDeck.duplicate()
	if not base.get("card_branches") is Dictionary: base.card_branches = {}
	if not base.has("first_boss_capstone_awarded"): base.first_boss_capstone_awarded = false
	if not base.get("seven_day_journey") is Dictionary: base.seven_day_journey = {"unlocked_day": 1, "claimed": [], "progress": {}}
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
	if not base.get("career_stats") is Dictionary:
		base.career_stats = {
			"total_battles": int(base.lifetime_stats.get("win_battles", 0)),
			"victories": int(base.lifetime_stats.get("win_battles", 0)),
			"defeats": 0,
			"current_win_streak": 0,
			"longest_win_streak": 0,
			"total_damage_dealt": int(base.lifetime_stats.get("deal_damage", 0)),
			"total_shield_gained": int(base.lifetime_stats.get("gain_shield", 0)),
			"total_cards_played": int(base.lifetime_stats.get("play_card", 0)),
			"elites_slain": int(base.lifetime_stats.get("clear_elite_or_boss", 0)),
			"bosses_slain": int(base.lifetime_stats.get("defeat_great_boss", 0)),
			"favorite_hero": str(base.get("hero_class", "fox_spirit")),
			"favorite_cards": {},
			"hall_of_fame": []
		}
	else:
		var cs: Dictionary = base.career_stats
		if not cs.has("total_battles"): cs.total_battles = 0
		if not cs.has("victories"): cs.victories = int(base.lifetime_stats.get("win_battles", 0))
		if not cs.has("defeats"): cs.defeats = 0
		if not cs.has("current_win_streak"): cs.current_win_streak = 0
		if not cs.has("longest_win_streak"): cs.longest_win_streak = 0
		if not cs.has("total_damage_dealt"): cs.total_damage_dealt = int(base.lifetime_stats.get("deal_damage", 0))
		if not cs.has("total_shield_gained"): cs.total_shield_gained = int(base.lifetime_stats.get("gain_shield", 0))
		if not cs.has("total_cards_played"): cs.total_cards_played = int(base.lifetime_stats.get("play_card", 0))
		if not cs.has("elites_slain"): cs.elites_slain = int(base.lifetime_stats.get("clear_elite_or_boss", 0))
		if not cs.has("bosses_slain"): cs.bosses_slain = int(base.lifetime_stats.get("defeat_great_boss", 0))
		if not cs.has("favorite_hero"): cs.favorite_hero = str(base.get("hero_class", "fox_spirit"))
		if not cs.get("favorite_cards") is Dictionary: cs.favorite_cards = {}
		if not cs.get("hall_of_fame") is Array: cs.hall_of_fame = []
	if not base.get("achievements_unlocked") is Dictionary: base.achievements_unlocked = {}
	if not base.get("achievements_claimed") is Dictionary: base.achievements_claimed = {}
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
	if not base.get("feature_unlocks_seen") is Array: base.feature_unlocks_seen = []
	# Runs unconditionally on every load, not just when the field is entirely missing: a save
	# from before this field existed has necessarily already lived past whatever unlock
	# thresholds it currently exceeds, so those must be backfilled as "already seen" the same
	# way — but a save that already HAS the field (from a previous version of this game) also
	# needs each entry checked individually, because SpiritContent.FEATURE_UNLOCKS itself grows
	# over time (this is exactly what happened when the per-tier A2-A5 entries were added after
	# feature_unlocks_seen already shipped). Backfilling only on total absence would have missed
	# those for every existing player already past stage 50/100/150/200 — their very next
	# battle win would have fired 2-4 "New!" toasts back to back for tiers they'd had available
	# for weeks, since _toast() has no queue (see game._check_feature_unlocks()'s own comment).
	# Idempotent either way: an id already in the array is simply skipped, so this is safe to
	# run every single load rather than only reasoning about it once at migration time.
	var seen_unlocks: Array = base.feature_unlocks_seen
	for entry in SpiritContent.FEATURE_UNLOCKS:
		var unlock_id: String = str(entry.id)
		if seen_unlocks.has(unlock_id): continue
		var current: int = int(base.unlocked) if str(entry.kind) == "unlocked" else int(base.difficulty)
		if current >= int(entry.threshold): seen_unlocks.append(unlock_id)
	base.feature_unlocks_seen = seen_unlocks
	if not base.get("friends") is Array: base.friends = []
	# map_choices stores the player's branch path selection per stage index (String key).
	# An empty dict means no choices made yet (all nodes are undecided / use fallback).
	if not base.get("map_choices") is Dictionary: base.map_choices = {}
	if not base.get("stamina") is Dictionary:
		base.stamina = {"current":100,"max":100,"last_regen_time":0}
	else:
		base.stamina.max = maxi(10, int(base.stamina.get("max", 100)))
		base.stamina.current = clampi(int(base.stamina.get("current", 100)), 0, int(base.stamina.max))
		if not base.stamina.has("last_regen_time"): base.stamina.last_regen_time = 0
	# Saves written before accounts existed get one on load rather than on next write.
	if not base.get("account") is Dictionary or not base.account.has("id"): base.account = new_account()
	if not base.account.has("provider") or base.account.provider == "local": base.account.provider = "guest"
	if not base.account.has("user_id"): base.account.user_id = ""
	if not base.account.has("email"): base.account.email = ""
	if not base.account.has("linked_at"): base.account.linked_at = 0
	if not base.account.has("cloud_synced_at"): base.account.cloud_synced_at = 0
	if not base.has("win_streak"): base.win_streak = int(base.get("career_stats", {}).get("current_win_streak", 0))
	if not base.has("max_win_streak"): base.max_win_streak = int(base.get("career_stats", {}).get("longest_win_streak", 0))
	if not base.has("haptics_enabled"): base.haptics_enabled = true
	if not base.has("music_volume"): base.music_volume = 1.0
	if not base.has("sfx_volume"): base.sfx_volume = 1.0
	if not base.get("deck_presets") is Dictionary:
		base.deck_presets = {"1": base.deck.duplicate(), "2": base.deck.duplicate(), "3": base.deck.duplicate()}
	if not base.get("deck_preset_names") is Dictionary:
		base.deck_preset_names = {"1": "预设 1", "2": "预设 2", "3": "预设 3"}
	if not base.has("active_deck_preset"): base.active_deck_preset = 1
	if not base.get("foil_cards") is Array: base.foil_cards = []
	if not base.get("run_history") is Array: base.run_history = []
	if not base.has("familiar_stage"): base.familiar_stage = 0
	if not base.has("familiar_affinity"): base.familiar_affinity = 0
	if not base.get("astral_roots") is Dictionary:
		base.astral_roots = {"metal": 0, "wood": 0, "water": 0, "fire": 0, "earth": 0}
	if not base.has("astral_sparks"): base.astral_sparks = 0
	if not base.has("pagoda_highest_floor"): base.pagoda_highest_floor = 1
	if not base.get("card_affixes") is Dictionary: base.card_affixes = {}
	if not base.get("fused_cards") is Array: base.fused_cards = []
	if not base.has("active_hexagram"): base.active_hexagram = ""
	if not base.get("bestiary_kills") is Dictionary: base.bestiary_kills = {}
	if not base.get("hero_skins") is Dictionary:
		base.hero_skins = {"fox_spirit": "default", "ironclad_sentinel": "default"}
	if not base.has("auto_battle_enabled"): base.auto_battle_enabled = false
	if not base.has("ascension_level"): base.ascension_level = 0
	if not base.has("highest_ascension"): base.highest_ascension = 0
	if not base.get("phantom_guard") is Dictionary: base.phantom_guard = {}
	if not base.get("pending_sync_queue") is Array: base.pending_sync_queue = []
	if not base.get("daily_challenge_runs") is Dictionary: base.daily_challenge_runs = {}
	if not base.has("cultivation_realm"): base.cultivation_realm = 0
	if not base.has("cultivation_exp"): base.cultivation_exp = 0
	if not base.get("lethal_puzzles_cleared") is Array: base.lethal_puzzles_cleared = []
	if not base.has("purged_cards_count"): base.purged_cards_count = 0
	if not base.get("spiritual_roots") is Dictionary:
		base.spiritual_roots = {"metal": 1, "wood": 1, "water": 1, "fire": 1, "earth": 1}
	if not base.has("spiritual_root_points"): base.spiritual_root_points = 3
	if not base.get("card_inscriptions") is Dictionary: base.card_inscriptions = {}
	if not base.has("one_handed_mode"): base.one_handed_mode = "off"
	if not base.has("target_fps"): base.target_fps = 60
	if not base.has("eco_mode"): base.eco_mode = false
	if not base.get("card_mastery") is Dictionary: base.card_mastery = {}
	if not base.get("herb_garden") is Dictionary:
		base.herb_garden = {"purple_lingzhi": 3, "sun_grass": 3, "frost_flower": 3, "last_harvest_time": 0}
	if not base.get("alchemy_pills") is Dictionary:
		base.alchemy_pills = {"qi_pill": 1, "iron_shield_pill": 1, "nine_turn_pill": 0}
	if not base.get("pagoda_soul_pacts") is Array: base.pagoda_soul_pacts = []
	if not base.get("destiny_boons") is Array: base.destiny_boons = []
	base.schema_version = SCHEMA_VERSION
	return base

static func write(profile: Dictionary) -> void:
	# updated_at is what a future cloud sync compares to resolve which copy is newer.
	profile.updated_at = int(Time.get_unix_time_from_system())
	profile.schema_version = SCHEMA_VERSION
	var json_payload := JSON.stringify(profile, "  ")
	# 1. Write to temporary file first (atomic write)
	var tmp_path := PATH + ".tmp"
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file != null:
		tmp_file.store_string(json_payload)
		tmp_file.close()
		# 2. Backup existing valid save
		if FileAccess.file_exists(PATH):
			var cur_file := FileAccess.open(PATH, FileAccess.READ)
			if cur_file != null:
				var cur_text := cur_file.get_as_text()
				cur_file.close()
				if not cur_text.is_empty():
					var bak_file := FileAccess.open(PATH + ".bak", FileAccess.WRITE)
					if bak_file != null:
						bak_file.store_string(cur_text)
						bak_file.close()
		# 3. Commit tmp to target PATH
		var dir := DirAccess.open("user://")
		if dir != null:
			if FileAccess.file_exists(PATH):
				dir.remove(PATH.get_file())
			dir.rename(tmp_path.get_file(), PATH.get_file())
		else:
			var direct_file := FileAccess.open(PATH, FileAccess.WRITE)
			if direct_file != null:
				direct_file.store_string(json_payload)
				direct_file.close()
	else:
		var direct_file := FileAccess.open(PATH, FileAccess.WRITE)
		if direct_file != null:
			direct_file.store_string(json_payload)
			direct_file.close()
	if OS.get_name() == "iOS":
		var icloud_f := FileAccess.open("user://icloud_trigger.json", FileAccess.WRITE)
		if icloud_f != null:
			icloud_f.store_string(JSON.stringify({"action": "save", "payload": json_payload}))
			icloud_f.close()
		var act_f := FileAccess.open("user://live_activity_trigger.json", FileAccess.WRITE)
		if act_f != null:
			act_f.store_string(JSON.stringify({
				"stamina": profile.get("stamina", {}).get("current", 100),
				"max_stamina": profile.get("stamina", {}).get("max", 100),
				"realm": int(profile.get("cultivation_realm", 0)),
				"highest_pagoda": int(profile.get("pagoda_highest_floor", 1))
			}))
			act_f.close()

static func invest_spiritual_root(profile: Dictionary, element: String) -> bool:
	if int(profile.get("spiritual_root_points", 0)) <= 0: return false
	if not profile.get("spiritual_roots") is Dictionary:
		profile.spiritual_roots = {"metal": 1, "wood": 1, "water": 1, "fire": 1, "earth": 1}
	if not profile.spiritual_roots.has(element): return false
	profile.spiritual_roots[element] = int(profile.spiritual_roots[element]) + 1
	profile.spiritual_root_points = int(profile.get("spiritual_root_points", 0)) - 1
	write(profile)
	return true

static func inscribe_card(profile: Dictionary, card_id: String, rune_kind: String) -> bool:
	if not profile.get("card_inscriptions") is Dictionary:
		profile.card_inscriptions = {}
	profile.card_inscriptions[card_id] = rune_kind
	write(profile)
	return true

static func record_pagoda_progress(profile: Dictionary, floor: int) -> void:
	profile.pagoda_highest_floor = maxi(int(profile.get("pagoda_highest_floor", 1)), floor)
	write(profile)

static func purge_card_from_deck(profile: Dictionary, card_id: String) -> bool:
	if not profile.get("deck") is Array: return false
	var deck: Array = profile.deck
	if deck.size() <= 12: return false
	var idx := deck.find(card_id)
	if idx == -1: return false
	deck.remove_at(idx)
	profile.purged_cards_count = int(profile.get("purged_cards_count", 0)) + 1
	write(profile)
	return true

static func advance_cultivation_realm(profile: Dictionary) -> bool:
	var cur: int = int(profile.get("cultivation_realm", 0))
	if cur >= 4: return false
	profile.cultivation_realm = cur + 1
	profile.cultivation_exp = 0
	# Award realm breakthrough bonus
	profile.health = clampi(int(profile.get("health", 60)) + 10, 1, 100)
	write(profile)
	return true

static func has_account_name(profile: Dictionary) -> bool:
	return not str(profile.get("account", {}).get("name", "")).strip_edges().is_empty()

static func is_cloud_linked(profile: Dictionary) -> bool:
	var provider: String = str(profile.get("account", {}).get("provider", "guest"))
	var user_id: String = str(profile.get("account", {}).get("user_id", "")).strip_edges()
	return (provider in ["apple", "google", "supabase", "email", "device"]) and not user_id.is_empty()

static func account_provider(profile: Dictionary) -> String:
	return str(profile.get("account", {}).get("provider", "guest"))

static func link_account(profile: Dictionary, provider: String, user_id: String, email: String = "", display_name: String = "") -> void:
	if not profile.get("account") is Dictionary:
		profile.account = new_account()
	profile.account.provider = provider
	profile.account.user_id = user_id
	if not email.is_empty():
		profile.account.email = email
	if not display_name.is_empty():
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
	if FileAccess.file_exists(PATH + ".tmp"): DirAccess.remove_absolute(PATH + ".tmp")
	if FileAccess.file_exists(PATH + ".bak"): DirAccess.remove_absolute(PATH + ".bak")

static func merge_profiles(local_p: Dictionary, cloud_p: Dictionary) -> Dictionary:
	var merged := local_p.duplicate(true)
	merged.unlocked = maxi(int(local_p.get("unlocked", 0)), int(cloud_p.get("unlocked", 0)))
	merged.position = maxi(int(local_p.get("position", 0)), int(cloud_p.get("position", 0)))
	merged.highest_ascension = maxi(int(local_p.get("highest_ascension", 0)), int(cloud_p.get("highest_ascension", 0)))
	merged.ascension_level = mini(int(merged.highest_ascension), maxi(int(local_p.get("ascension_level", 0)), int(cloud_p.get("ascension_level", 0))))
	merged.gold = maxi(int(local_p.get("gold", 0)), int(cloud_p.get("gold", 0)))
	merged.spirit_jade = maxi(int(local_p.get("spirit_jade", 0)), int(cloud_p.get("spirit_jade", 0)))
	merged.spirit_dust = maxi(int(local_p.get("spirit_dust", 0)), int(cloud_p.get("spirit_dust", 0)))
	merged.abyss_floor = maxi(int(local_p.get("abyss_floor", 1)), int(cloud_p.get("abyss_floor", 1)))
	merged.abyss_record = maxi(int(local_p.get("abyss_record", 0)), int(cloud_p.get("abyss_record", 0)))
	merged.boss_rush_record = maxi(int(local_p.get("boss_rush_record", 0)), int(cloud_p.get("boss_rush_record", 0)))
	var c_disc: Dictionary = local_p.get("compendium_discovered", {}).duplicate(true)
	var cloud_disc: Dictionary = cloud_p.get("compendium_discovered", {})
	for k in cloud_disc:
		if not c_disc.has(k) or not (c_disc[k] is Array):
			c_disc[k] = []
		if cloud_disc[k] is Array:
			for item in cloud_disc[k]:
				if not c_disc[k].has(item):
					c_disc[k].append(item)
	merged.compendium_discovered = c_disc
	merged.updated_at = maxi(int(local_p.get("updated_at", 0)), int(cloud_p.get("updated_at", 0)))
	return merged

static func get_mastery_tier_for_count(count: int) -> int:
	if count >= 60: return 3 # 出神入化 (Awakened)
	if count >= 30: return 2 # 融会贯通
	if count >= 10: return 1 # 初窥门径
	return 0 # 未入流

static func add_card_mastery(profile: Dictionary, card_id: String, amount: int = 1) -> Dictionary:
	if not profile.get("card_mastery") is Dictionary:
		profile.card_mastery = {}
	var cur: int = int(profile.card_mastery.get(card_id, 0))
	var new_val: int = cur + amount
	profile.card_mastery[card_id] = new_val
	var old_tier := get_mastery_tier_for_count(cur)
	var new_tier := get_mastery_tier_for_count(new_val)
	write(profile)
	return {"card_id": card_id, "count": new_val, "tier": new_tier, "leveled_up": new_tier > old_tier}

static func get_card_mastery_tier(profile: Dictionary, card_id: String) -> int:
	var count: int = int(profile.get("card_mastery", {}).get(card_id, 0))
	return get_mastery_tier_for_count(count)

static func is_card_awakened(profile: Dictionary, card_id: String) -> bool:
	return get_card_mastery_tier(profile, card_id) >= 3

static func harvest_herbs(profile: Dictionary) -> Dictionary:
	if not profile.get("herb_garden") is Dictionary:
		profile.herb_garden = {"purple_lingzhi": 0, "sun_grass": 0, "frost_flower": 0, "last_harvest_time": 0}
	var gained := {
		"purple_lingzhi": 2,
		"sun_grass": 2,
		"frost_flower": 2
	}
	for herb in gained:
		profile.herb_garden[herb] = int(profile.herb_garden.get(herb, 0)) + gained[herb]
	profile.herb_garden.last_harvest_time = int(Time.get_unix_time_from_system())
	write(profile)
	return gained

static func craft_pill(profile: Dictionary, recipe_id: String) -> bool:
	if not profile.get("herb_garden") is Dictionary:
		profile.herb_garden = {"purple_lingzhi": 0, "sun_grass": 0, "frost_flower": 0, "last_harvest_time": 0}
	if not profile.get("alchemy_pills") is Dictionary:
		profile.alchemy_pills = {"qi_pill": 0, "iron_shield_pill": 0, "nine_turn_pill": 0}
	var recipe: Dictionary = SpiritContent.ALCHEMY_RECIPES.get(recipe_id, {})
	if recipe.is_empty(): return false
	var cost: Dictionary = recipe.get("cost", {})
	for herb in cost:
		if int(profile.herb_garden.get(herb, 0)) < int(cost[herb]):
			return false
	for herb in cost:
		profile.herb_garden[herb] = int(profile.herb_garden.get(herb, 0)) - int(cost[herb])
	profile.alchemy_pills[recipe_id] = int(profile.alchemy_pills.get(recipe_id, 0)) + 1
	write(profile)
	return true

static func consume_pill(profile: Dictionary, pill_id: String) -> bool:
	if not profile.get("alchemy_pills") is Dictionary:
		return false
	var cur: int = int(profile.alchemy_pills.get(pill_id, 0))
	if cur <= 0: return false
	profile.alchemy_pills[pill_id] = cur - 1
	write(profile)
	return true

static func bind_soul_pact(profile: Dictionary, pact_id: String) -> bool:
	if not profile.get("pagoda_soul_pacts") is Array:
		profile.pagoda_soul_pacts = []
	if not SpiritContent.PAGODA_SOUL_PACTS.has(pact_id):
		return false
	if profile.pagoda_soul_pacts.has(pact_id):
		return false
	profile.pagoda_soul_pacts.append(pact_id)
	write(profile)
	return true

static func unbind_soul_pact(profile: Dictionary, pact_id: String) -> bool:
	if not profile.get("pagoda_soul_pacts") is Array: return false
	var idx: int = profile.pagoda_soul_pacts.find(pact_id)
	if idx == -1: return false
	profile.pagoda_soul_pacts.remove_at(idx)
	write(profile)
	return true

static func set_target_fps(profile: Dictionary, fps: int) -> void:
	profile.target_fps = fps
	write(profile)

static func set_eco_mode(profile: Dictionary, enabled: bool) -> void:
	profile.eco_mode = enabled
	write(profile)


