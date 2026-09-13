extends RefCounted
class_name SpiritContent

var raw: Dictionary
var cards: Array
var encounters: Array[Dictionary] = []

const CHAPTER_NAMES_ZH = ["雾林", "烬河三角洲", "雷鸣群峰", "岩甲城塞", "荆棘荒野", "万灵潮汐", "翠玉圣域", "幻雾长原", "怒焰火山", "万象熔炉"]
const CHAPTER_NAMES_EN = ["Mistwood", "Ember Delta", "Thunder Peaks", "Stone Citadel", "Thorn Wilds", "Spirit Tide", "Jade Sanctuary", "Mirage Expanse", "Fury Caldera", "Worldforge"]
const WAYPOINT_ZH = ["入口", "渡口", "神社", "要塞", "王座"]
const WAYPOINT_EN = ["Trailhead", "Crossing", "Shrine", "Stronghold", "Crown"]
const ENEMIES = [
	{"name":"雾林守卫", "art":"sentinel-v1.jpg", "tint":"83e4c1"},
	{"name":"提灯石卫", "art":"lanternstone-keeper-v1.jpg", "tint":"75d7d2"},
	{"name":"缚文巨像", "art":"runebound-colossus-v1.jpg", "tint":"a3c8ff"},
	{"name":"烬崖守护者", "art":"embercliff-guardian-v1.jpg", "tint":"f0b16d"},
	{"name":"山岳之心", "art":"heart-of-mountain-v1.jpg", "tint":"e67c65"},
]

const EQUIPMENT = [
	{"id":"emberBlade","slot":"weapon","icon":"⚔","zh":"烬火长刀","detail":"每回合第一张攻击牌伤害 +3。"},
	{"id":"jadePlate","slot":"armor","icon":"⬢","zh":"翠玉战甲","detail":"战斗开始时获得 8 点护盾。"},
	{"id":"soulPendant","slot":"charm","icon":"◇","zh":"猎魂坠饰","detail":"击败敌人回复 2 点生命，每场最多 3 次。"},
	{"id":"moonStaff","slot":"weapon","icon":"☾","zh":"月纹法杖","detail":"每回合第一张策略牌返还 1 点能量。"},
	{"id":"thornArmor","slot":"armor","icon":"✣","zh":"荆棘铠甲","detail":"受到敌方伤害后反击 2 点。"},
	{"id":"tideCharm","slot":"charm","icon":"≋","zh":"灵潮玉佩","detail":"起手额外抽 1 张牌。"},
	{"id":"stoneSpear","slot":"weapon","icon":"➹","zh":"破岩灵枪","detail":"攻击牌无视敌方护盾。"},
	{"id":"mistCloak","slot":"armor","icon":"≈","zh":"流雾披风","detail":"每第三次敌方攻击伤害归零。"},
	{"id":"fortuneSeal","slot":"charm","icon":"◆","zh":"旅运金印","detail":"胜利金币增加 15%。"},
	{"id":"stormBow","slot":"weapon","icon":"ϟ","zh":"逐电长弓","detail":"击败敌人时抽 1 张牌。"},
	{"id":"phoenixMail","slot":"armor","icon":"♨","zh":"涅槃羽衣","detail":"每场一次，以 15 点生命抵挡致命伤害。"},
	{"id":"focusCharm","slot":"charm","icon":"◉","zh":"凝神灵镜","detail":"战斗开始时获得 1 层凝神。"},
]

const RUNES = [
	{"id":"swift","icon":"»","zh":"迅捷","detail":"每回合第一次使用不消耗出牌次数。","color":"78e9ff"},
	{"id":"chain","icon":"⌁","zh":"连锁","detail":"40% 单体伤害传递给另一名敌人。","color":"a2d9ff"},
	{"id":"echo","icon":"◎","zh":"回响","detail":"以 50% 数值重复卡牌效果。","color":"d1a8ff"},
	{"id":"siphon","icon":"◒","zh":"吸魂","detail":"获得伤害 25% 的护盾。","color":"80e4c0"},
	{"id":"burning","icon":"♨","zh":"灼烧","detail":"伤害牌额外施加 2 层燃烧。","color":"ff9868"},
	{"id":"guardian","icon":"⬡","zh":"守御","detail":"使用时额外获得 4 点护盾。","color":"8ff5cf"},
	{"id":"cycle","icon":"↻","zh":"循环","detail":"使用后放到抽牌堆底部。","color":"ffd47c"},
	{"id":"cleanse","icon":"✦","zh":"净化","detail":"使用时移除自身燃烧。","color":"f7f0bd"},
	{"id":"execute","icon":"✕","zh":"处决","detail":"目标低于 25% 生命时伤害 +50%。","color":"ff7373"},
	{"id":"resonance","icon":"◈","zh":"共鸣","detail":"本回合每张同属性牌使数值 +1。","color":"b9a2ff"},
]

func _init() -> void:
	var file := FileAccess.open("res://data/core.json", FileAccess.READ)
	raw = JSON.parse_string(file.get_as_text())
	cards = raw.cards
	_build_encounters()

func card(id: String) -> Dictionary:
	for value in cards:
		if value.id == id: return value
	return {}

func text(key: String, language := "zh-Hans") -> String:
	return str(raw.translations.get(language, raw.translations.en).get(key, key))

func stage_name(index: int, language := "zh-Hans") -> String:
	var chapter := index / 5
	var level := index % 5
	if language == "zh-Hans": return "%s·%s" % [CHAPTER_NAMES_ZH[chapter], WAYPOINT_ZH[level]]
	return "%s · %s" % [CHAPTER_NAMES_EN[chapter], WAYPOINT_EN[level]]

func node_kind(index: int) -> String:
	var level := index % 5 + 1
	if level == 5: return "boss"
	if level == 3: return "elite"
	if level == 2: return "event" if (index / 5) % 2 == 0 else "merchant"
	if level == 4: return "rest"
	return "battle"

func equipment(id: String) -> Dictionary:
	for item in EQUIPMENT:
		if item.id == id: return item
	return {}

func rune(id: String) -> Dictionary:
	for item in RUNES:
		if item.id == id: return item
	return {}

func _build_encounters() -> void:
	for index in 50:
		var chapter: int = index / 5 + 1
		var level := index % 5 + 1
		var enemy: Dictionary = ENEMIES[(chapter + level - 2) % ENEMIES.size()]
		var mechanics := {}
		if chapter == 3: mechanics.critical_every = 3
		if chapter == 4: mechanics.shield_per_turn = 4
		if chapter == 5: mechanics.thorns = 1
		if chapter == 7: mechanics.regeneration = 3
		if chapter == 8: mechanics.dodge_every = 3
		if chapter == 9: mechanics.enrage = 1
		if chapter == 10: mechanics = {"shield_per_turn":3,"critical_every":3,"below_half":3}
		var adds := 0
		if (chapter >= 3 and level == 3) or (chapter >= 6 and level >= 2): adds += 1
		if (chapter >= 5 and level == 5) or (chapter == 10 and level >= 4): adds += 1
		encounters.append({
			"chapter":chapter,"level":level,"health":24 + level * 5 + (chapter - 1) * 7,
			"damage":3 + level + (2 if level >= 2 else 0) + int((chapter - 1) * .75),
			"reward":16 + chapter * 5 + level * 2,"name":enemy.name,"art":enemy.art,
			"mechanics":mechanics,"adds":adds,"background":(chapter - 1) % 5
		})
