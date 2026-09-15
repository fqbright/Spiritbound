extends RefCounted
class_name SpiritSave

const PATH := "user://spiritbound-save.json"
# Bump when the save shape changes; the sync layer will use it to decide on migration.
const SCHEMA_VERSION := 4

static func new_account() -> Dictionary:
	return {
		"id": _uuid(),
		"name": "",
		"provider": "local",
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
	return {"schema_version":SCHEMA_VERSION,"account":new_account(),"updated_at":0,"gold":30,"health":60,"unlocked":0,"position":0,"deck":content.raw.startingDeck.duplicate(),"collection":collection,"upgrades":{},"relics":[],"equipment_owned":[],"equipment_slots":{},"rune_inventory":{},"card_runes":{},"difficulty":0,"language":"zh-Hans","battle_speed":1.0,"hero_class":"fox_spirit","abyss_floor":1,"abyss_record":0,"abyss_boons":[],"daily_quests":[],"daily_reset_at":0,"weekly_quests":[],"weekly_reset_at":0,"claimed_stage_events":[],"compendium_discovered":{},"hero_masteries":{},"daily_trial_record":{"day":-1,"stage":0,"badges":0,"best_stage":0},"tutorial_seen":false}

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
	if not base.get("claimed_stage_events") is Array: base.claimed_stage_events = []
	if not base.get("abyss_boons") is Array: base.abyss_boons = []
	if not base.get("compendium_discovered") is Dictionary: base.compendium_discovered = {}
	if not base.get("hero_masteries") is Dictionary: base.hero_masteries = {}
	if not base.get("daily_trial_record") is Dictionary: base.daily_trial_record = {"day":-1,"stage":0,"badges":0,"best_stage":0}
	# Saves written before accounts existed get one on load rather than on next write.
	if not base.get("account") is Dictionary or not base.account.has("id"): base.account = new_account()
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

static func reset() -> void:
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(PATH)
