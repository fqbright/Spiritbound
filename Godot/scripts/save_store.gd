extends RefCounted
class_name SpiritSave

const PATH := "user://spiritbound-save.json"

static func defaults(content: SpiritContent) -> Dictionary:
	var collection := {}
	for id in content.raw.startingDeck: collection[id] = collection.get(id,0) + 1
	return {"gold":30,"health":60,"unlocked":0,"position":0,"deck":content.raw.startingDeck.duplicate(),"collection":collection,"upgrades":{},"relics":[],"equipment_owned":[],"equipment_slots":{},"rune_inventory":{},"card_runes":{},"difficulty":0,"language":"zh-Hans"}

static func load_profile(content: SpiritContent) -> Dictionary:
	var base := defaults(content)
	if not FileAccess.file_exists(PATH): return base
	var file := FileAccess.open(PATH,FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return base
	for key in parsed: base[key] = parsed[key]
	if not base.deck is Array or base.deck.size() != 25: base.deck = content.raw.startingDeck.duplicate()
	base.health = clampi(int(base.health),1,60)
	base.unlocked = clampi(int(base.unlocked),0,49)
	base.position = clampi(int(base.position),0,49)
	return base

static func write(profile: Dictionary) -> void:
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(profile,"  "))

static func reset() -> void:
	if FileAccess.file_exists(PATH): DirAccess.remove_absolute(PATH)
