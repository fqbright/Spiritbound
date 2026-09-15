extends RefCounted
class_name SpiritContent

var raw: Dictionary
var cards: Array
var encounters: Array[Dictionary] = []

const CHAPTER_NAMES_ZH = [
	"雾林", "烬河三角洲", "雷鸣群峰", "岩甲城塞", "荆棘荒野", "万灵潮汐", "翠玉圣域", "幻雾长原", "怒焰火山", "万象熔炉",
	"沉沦废墟", "暗涌深渊", "亡灵回廊", "血月峡谷", "蚀骨沼泽", "寂静墓园", "裂魂断崖", "幽冥深渊", "噬影荒原", "深渊之王座",
	"云海孤峰", "雷霆天堑", "风蚀断岭", "星陨荒漠", "极光冰原", "苍穹回廊", "天穹裂隙", "流星圣域", "天狱回音", "苍穹主宰",
	"虚无之境", "归墟暗流", "湮灭回廊", "无光深渊", "亡界孤岛", "虚空裂痕", "归墟秘境", "万魂窟", "湮灭回音", "归墟主宰",
	"创世裂隙", "混沌回廊", "星辰熔炉", "永恒回音", "万象之眼", "创世深渊", "时空裂境", "万灵归一", "创世回音", "万象终焉",
]
const CHAPTER_NAMES_EN = [
	"Mistwood", "Ember Delta", "Thunder Peaks", "Stone Citadel", "Thorn Wilds", "Spirit Tide", "Jade Sanctuary", "Mirage Expanse", "Fury Caldera", "Worldforge",
	"Sunken Ruins", "Abyssal Current", "Wraith Corridor", "Bloodmoon Canyon", "Bonerot Marsh", "Silent Necropolis", "Soulrend Cliffs", "Netherdeep Abyss", "Shadowmaw Wastes", "Abyssal Throne",
	"Cloudsea Pinnacle", "Thunder Rift", "Windworn Ridge", "Starfall Desert", "Aurora Icefield", "Skybound Corridor", "Heaven's Fissure", "Meteor Sanctum", "Skyprison Echo", "Sovereign of the Sky",
	"Void Reaches", "Netherfall Current", "Oblivion Corridor", "Lightless Abyss", "Deadworld Isle", "Voidrift", "Netherfall Sanctum", "Chamber of Ten Thousand Souls", "Oblivion Echo", "Sovereign of the Void",
	"Genesis Rift", "Chaos Corridor", "Stellar Forge", "Eternal Echo", "Eye of Worlds", "Genesis Abyss", "Rift of Time", "Convergence of Spirits", "Genesis Echo", "The End of All",
]
const WAYPOINT_ZH = ["入口", "渡口", "神社", "要塞", "王座"]
const WAYPOINT_EN = ["Trailhead", "Crossing", "Shrine", "Stronghold", "Crown"]
const ENEMIES = [
	{"name":"雾林守卫", "name_en":"Mistwood Sentinel", "art":"sentinel-v1.jpg", "tint":"83e4c1"},
	{"name":"提灯石卫", "name_en":"Lanternstone Keeper", "art":"lanternstone-keeper-v1.jpg", "tint":"75d7d2"},
	{"name":"缚文巨像", "name_en":"Runebound Colossus", "art":"runebound-colossus-v1.jpg", "tint":"a3c8ff"},
	{"name":"烬崖守护者", "name_en":"Embercliff Guardian", "art":"embercliff-guardian-v1.jpg", "tint":"f0b16d"},
	{"name":"山岳之心", "name_en":"Heart of the Mountain", "art":"heart-of-mountain-v1.jpg", "tint":"e67c65"},
]

const EQUIPMENT = [
	{"id":"emberBlade","slot":"weapon","icon":"⚔","icon_kind":"sword","icon_flourish":"flame","zh":"烬火长刀","en":"Ember Blade","detail":"每回合第一张攻击牌伤害 +3。","detail_en":"First attack each turn deals +3 damage."},
	{"id":"jadePlate","slot":"armor","icon":"⬢","icon_kind":"shield","icon_flourish":"","zh":"翠玉战甲","en":"Jade Plate","detail":"战斗开始时获得 8 点护盾。","detail_en":"Start battle with 8 Shield."},
	{"id":"soulPendant","slot":"charm","icon":"◇","icon_kind":"pendant","icon_flourish":"eye","zh":"猎魂坠饰","en":"Soul Pendant","detail":"击败敌人回复 2 点生命，每场最多 3 次。","detail_en":"Heal 2 HP on kill, up to 3 times per battle."},
	{"id":"moonStaff","slot":"weapon","icon":"☾","icon_kind":"staff","icon_flourish":"crescent","zh":"月纹法杖","en":"Moon Staff","detail":"每回合第一张策略牌返还 1 点能量。","detail_en":"First Tactic each turn refunds 1 Energy."},
	{"id":"thornArmor","slot":"armor","icon":"✣","icon_kind":"shield","icon_flourish":"spike","zh":"荆棘铠甲","en":"Thorn Armor","detail":"受到敌方伤害后反击 2 点。","detail_en":"Retaliate 2 damage when hit by enemies."},
	{"id":"tideCharm","slot":"charm","icon":"≋","icon_kind":"pendant","icon_flourish":"wave","zh":"灵潮玉佩","en":"Tide Charm","detail":"起手额外抽 1 张牌。","detail_en":"Draw 1 extra card at battle start."},
	{"id":"stoneSpear","slot":"weapon","icon":"➹","icon_kind":"spear","icon_flourish":"","zh":"破岩灵枪","en":"Stone Spear","detail":"攻击牌无视敌方护盾。","detail_en":"Attacks pierce enemy Shield."},
	{"id":"mistCloak","slot":"armor","icon":"≈","icon_kind":"shield","icon_flourish":"wave","zh":"流雾披风","en":"Mist Cloak","detail":"每第三次敌方攻击伤害归零。","detail_en":"Every 3rd enemy attack deals 0 damage."},
	{"id":"fortuneSeal","slot":"charm","icon":"◆","icon_kind":"pendant","icon_flourish":"coin","zh":"旅运金印","en":"Fortune Seal","detail":"胜利金币增加 15%。","detail_en":"Gold rewards increased by 15%."},
	{"id":"stormBow","slot":"weapon","icon":"ϟ","icon_kind":"bow","icon_flourish":"","zh":"逐电长弓","en":"Storm Bow","detail":"击败敌人时抽 1 张牌。","detail_en":"Draw 1 card on kill."},
	{"id":"phoenixMail","slot":"armor","icon":"♨","icon_kind":"shield","icon_flourish":"wing","zh":"涅槃羽衣","en":"Phoenix Mail","detail":"每场一次，以 15 点生命抵挡致命伤害。","detail_en":"Survive lethal damage once with 15 HP."},
	{"id":"focusCharm","slot":"charm","icon":"◉","icon_kind":"pendant","icon_flourish":"spiral","zh":"凝神灵镜","en":"Focus Charm","detail":"战斗开始时获得 1 层凝神。","detail_en":"Start battle with 1 Focus."},
]

# Quest "type" values are the vocabulary game.gd's _advance_quest() understands. Each is
# tied to a signal that already exists in the game (a card played, a chest opened, a
# purchase made) rather than anything new the engine has to emit.
const DAILY_QUESTS = [
	{"id":"d_win3","type":"win_battles","target":3,"reward":40,"zh":"打赢 3 场战斗","en":"Win 3 battles"},
	{"id":"d_damage200","type":"deal_damage","target":200,"reward":35,"zh":"造成 200 点总伤害","en":"Deal 200 total damage"},
	{"id":"d_rune3","type":"play_runed_cards","target":3,"reward":30,"zh":"使用 3 次镶嵌符文的卡牌","en":"Play 3 rune-socketed cards"},
	{"id":"d_chest1","type":"open_chest","target":1,"reward":25,"zh":"开启 1 个胜利宝箱","en":"Open 1 victory chest"},
	{"id":"d_shop1","type":"shop_purchase","target":1,"reward":25,"zh":"在商店购买 1 次","en":"Make 1 purchase in the shop"},
	{"id":"d_gold100","type":"earn_gold","target":100,"reward":30,"zh":"累计获得 100 金币","en":"Earn 100 gold"},
]
const WEEKLY_QUESTS = [
	{"id":"w_eliteboss5","type":"clear_elite_or_boss","target":5,"reward":150,"zh":"击败 5 场精英或首领战斗","en":"Clear 5 elite or boss battles"},
	{"id":"w_damage2000","type":"deal_damage","target":2000,"reward":140,"zh":"累计造成 2000 点伤害","en":"Deal 2000 total damage"},
	{"id":"w_greatboss1","type":"defeat_great_boss","target":1,"reward":200,"zh":"击败 1 位大首领","en":"Defeat 1 great boss"},
	{"id":"w_collect5","type":"collect_cards","target":5,"reward":130,"zh":"收集 5 张新卡牌","en":"Collect 5 new cards"},
	{"id":"w_win15","type":"win_battles","target":15,"reward":160,"zh":"打赢 15 场战斗","en":"Win 15 battles"},
	{"id":"w_gold500","type":"earn_gold","target":500,"reward":120,"zh":"累计获得 500 金币","en":"Earn 500 gold"},
]

const RELICS = [
	{"id":"foxCharm","icon":"✦","icon_mark":"flame","color":"ffb765","zh":"绯狐护符","en":"Fox Charm","detail":"战斗首回合额外获得 1 点能量。","detail_en":"Gain 1 extra Energy on the first turn."},
	{"id":"starShard","icon":"✧","icon_mark":"sparkle","color":"a2d9ff","zh":"碎星石","en":"Star Shard","detail":"每回合第一张攻击牌额外造成 2 点伤害。","detail_en":"First attack each turn deals +2 damage."},
	{"id":"ancientSeed","icon":"❦","icon_mark":"leaf","color":"8ff5cf","zh":"古树之种","en":"Ancient Seed","detail":"每回合开始回复 2 点生命。","detail_en":"Restore 2 HP at the start of each turn."},
	{"id":"windChime","icon":"≋","icon_mark":"wave","color":"78e9ff","zh":"引灵风铃","en":"Spirit Chime","detail":"战斗开始时额外抽 2 张牌。","detail_en":"Draw 2 extra cards at battle start."},
	{"id":"bloodJade","icon":"❥","icon_mark":"drop","color":"ff7373","zh":"饮血玉","en":"Blood Jade","detail":"击败敌人回复 3 点生命。","detail_en":"Restore 3 HP when an enemy dies."},
	{"id":"thunderSeal","icon":"ϟ","icon_mark":"bolt","color":"ffe08a","zh":"雷纹印","en":"Thunder Seal","detail":"每 3 回合开始时获得 2 点能量。","detail_en":"Gain 2 Energy every third turn."},
	{"id":"mirrorScale","icon":"◈","icon_mark":"rings","color":"b9a2ff","zh":"镜鳞甲","en":"Mirror Scale","detail":"回合结束时保留一半护盾。","detail_en":"Keep half of your Shield at end of turn."},
	{"id":"emberCore","icon":"♨","icon_mark":"cross_blade","color":"ff9868","zh":"烬心","en":"Ember Core","detail":"燃烧每层额外造成 1 点伤害。","detail_en":"Burn deals 1 extra damage per stack."},
]

const RUNES = [
	{"id":"swift","icon":"»","icon_mark":"chevrons","zh":"迅捷","en":"Swift","detail":"每回合第一次使用免费（返还其能量费用）。","detail_en":"First play each turn is free (refunds its Energy cost).","color":"78e9ff"},
	{"id":"chain","icon":"⌁","icon_mark":"bolt","zh":"连锁","en":"Chain","detail":"40% 单体伤害传递给另一名敌人。","detail_en":"40% single-target damage splashes to another enemy.","color":"a2d9ff"},
	{"id":"echo","icon":"◎","icon_mark":"rings","zh":"回响","en":"Echo","detail":"以 50% 数值重复卡牌效果。","detail_en":"Repeat card effect at 50% value.","color":"d1a8ff"},
	{"id":"siphon","icon":"◒","icon_mark":"drop","zh":"吸魂","en":"Siphon","detail":"获得伤害 25% 的护盾。","detail_en":"Gain Shield equal to 25% of damage dealt.","color":"80e4c0"},
	{"id":"burning","icon":"♨","icon_mark":"flame","zh":"灼烧","en":"Burning","detail":"伤害牌额外施加 2 层燃烧。","detail_en":"Attacks apply 2 additional Burn.","color":"ff9868"},
	{"id":"guardian","icon":"⬡","icon_mark":"shield_mark","zh":"守御","en":"Guardian","detail":"使用时额外获得 4 点护盾。","detail_en":"Gain 4 Shield on play.","color":"8ff5cf"},
	{"id":"cycle","icon":"↻","icon_mark":"cycle_arrows","zh":"循环","en":"Cycle","detail":"使用后放到抽牌堆底部。","detail_en":"Place at bottom of draw pile on play.","color":"ffd47c"},
	{"id":"cleanse","icon":"✦","icon_mark":"sparkle","zh":"净化","en":"Cleanse","detail":"使用时移除自身燃烧。","detail_en":"Remove Burn from self on play.","color":"f7f0bd"},
	{"id":"execute","icon":"✕","icon_mark":"cross_blade","zh":"处决","en":"Execute","detail":"目标低于 25% 生命时伤害 +50%。","detail_en":"Deal +50% damage if target is below 25% HP.","color":"ff7373"},
	{"id":"resonance","icon":"◈","icon_mark":"wave","zh":"共鸣","en":"Resonance","detail":"本回合每张同属性牌使数值 +1。","detail_en":"+1 value per same-element card played this turn.","color":"b9a2ff"},
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

func chapter_name(chapter: int, language := "zh-Hans") -> String:
	var index: int = clampi(chapter, 0, CHAPTER_NAMES_ZH.size() - 1)
	if language == "zh-Hans": return CHAPTER_NAMES_ZH[index]
	return CHAPTER_NAMES_EN[index]

func waypoint_name(level: int, language := "zh-Hans") -> String:
	var index: int = clampi(level, 0, WAYPOINT_ZH.size() - 1)
	if language == "zh-Hans": return WAYPOINT_ZH[index]
	return WAYPOINT_EN[index]

func node_kind(index: int) -> String:
	var chapter := index / 5 + 1
	var level := index % 5 + 1
	# Every chapter ends on a boss; every tenth chapter ends on a great boss instead.
	if level == 5: return "greatboss" if chapter % 10 == 0 else "boss"
	if level == 3: return "elite"
	if level == 2: return "event" if (index / 5) % 2 == 0 else "merchant"
	if level == 4: return "rest"
	return "battle"

func is_boss_kind(kind: String) -> bool:
	return kind == "boss" or kind == "greatboss"

func equipment(id: String) -> Dictionary:
	for item in EQUIPMENT:
		if item.id == id: return item
	return {}

func rune(id: String) -> Dictionary:
	for item in RUNES:
		if item.id == id: return item
	return {}

func relic(id: String) -> Dictionary:
	for item in RELICS:
		if item.id == id: return item
	return {}

func relic_name(item: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return item.get("en", item.get("zh", ""))
	return item.get("zh", "")

func relic_detail(item: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return item.get("detail_en", item.get("detail", ""))
	return item.get("detail", "")

func quest_by_id(id: String) -> Dictionary:
	for q in DAILY_QUESTS:
		if q.id == id: return q
	for q in WEEKLY_QUESTS:
		if q.id == id: return q
	return {}

func quest_name(quest: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return quest.get("en", quest.get("zh", ""))
	return quest.get("zh", "")

# Deterministic per period so every device rolling over at the same reset time gets the
# same three quests that day/week, rather than fresh randomness on every reroll call.
func _shuffled_indices(size: int, seed_value: int) -> Array:
	var indices: Array = range(size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = indices[i]; indices[i] = indices[j]; indices[j] = tmp
	return indices

func roll_quests(catalog: Array, count: int, period_seed: int) -> Array:
	var indices := _shuffled_indices(catalog.size(), period_seed)
	var picked: Array = []
	for i in mini(count, indices.size()):
		var q: Dictionary = catalog[indices[i]].duplicate()
		q["progress"] = 0
		q["claimed"] = false
		picked.append(q)
	return picked

# Same deterministic-per-day approach as quests: every device sees the same stock and the
# same discounted slot until the next reset, rather than a fresh random shuffle on every
# visit to the shop.
func roll_shop_stock(day_seed: int, count: int) -> Dictionary:
	var pool: Array = cards.filter(func(c): return c.rarity != "Starter")
	var indices := _shuffled_indices(pool.size(), day_seed)
	var picked: Array = []
	for i in mini(count, indices.size()): picked.append(pool[indices[i]])
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed + 777
	var sale_index: int = rng.randi_range(0, maxi(0, picked.size() - 1))
	return {"cards": picked, "sale_index": sale_index}

# Four difficulty bands across 50 chapters (250 stages), each ending at a chapter boundary
# so the numbers line up with what a player actually experiences one chapter at a time:
#   1-4   (stages   1- 20): trivial, clearable on autopilot.
#   5-10  (stages  21- 50): card sequencing starts to matter.
#   11-20 (stages  51-100): needs a deliberately built deck.
#   21-50 (stages 101-250): needs runes/equipment/relics from earlier farming, not skill alone.
# Tuned against tests/balance_probe.gd — see Docs/ARCHITECTURE.md for the win-rate curve
# that came out of it and why these constants ended up where they did.
const BAND_1_END = 4
const BAND_2_END = 10
const BAND_3_END = 20

func _chapter_factor(chapter: int) -> float:
	if chapter <= BAND_1_END:
		return 1.0 + float(chapter - 1) * 0.08
	if chapter <= BAND_2_END:
		var base_a: float = 1.0 + float(BAND_1_END - 1) * 0.08
		return base_a + float(chapter - BAND_1_END) * 0.12
	if chapter <= BAND_3_END:
		var base_b: float = _chapter_factor(BAND_2_END)
		return base_b + float(chapter - BAND_2_END) * 0.22
	var base_c: float = _chapter_factor(BAND_3_END)
	return base_c * pow(1.062, float(chapter - BAND_3_END))

func _chapter_mechanics(chapter: int, is_great_boss: bool) -> Dictionary:
	if chapter <= 2: return {}
	if is_great_boss:
		# Every 10th chapter combines three mechanics at once, scaling with the arc — the
		# five great bosses are meant to be the hardest single fight in their neighborhood.
		var tier: int = chapter / 10
		return {"shield_per_turn": 2 + tier, "critical_every": maxi(2, 4 - tier), "below_half": 2 + tier, "enrage": tier}
	var band: int = 0
	if chapter <= BAND_2_END: band = 1
	elif chapter <= BAND_3_END: band = 2
	else: band = 3
	var archetypes := ["critical", "shield", "thorns", "regen", "dodge", "enrage"]
	match archetypes[(chapter - 1) % archetypes.size()]:
		"critical": return {"critical_every": maxi(2, 4 - band)}
		"shield": return {"shield_per_turn": 3 + band * 2}
		"thorns": return {"thorns": 1 + band}
		"regen": return {"regeneration": 2 + band * 2}
		"dodge": return {"dodge_every": maxi(2, 4 - band)}
		"enrage": return {"enrage": 1 + band}
	return {}

func _chapter_adds(chapter: int, level: int, is_great_boss: bool) -> int:
	var adds := 0
	if level == 3:
		# Elites: a real group fight from the deckbuilding band onward, which is exactly
		# why the cleave finishers (stormArc/worldFlame/spiritNova) exist.
		if chapter >= 3: adds += 1
		if chapter >= 15: adds += 1
		if chapter >= 35: adds += 1
	elif level in [1, 2]:
		if chapter >= 6: adds += 1
		if chapter >= 25: adds += 1
	elif level == 5:
		if chapter >= 5: adds += 1
		if is_great_boss: adds += 1
		if chapter >= 40: adds += 1
	return adds

func _build_encounters() -> void:
	var chapter_count: int = CHAPTER_NAMES_ZH.size()
	for index in chapter_count * 5:
		var chapter: int = index / 5 + 1
		var level := index % 5 + 1
		var enemy: Dictionary = ENEMIES[(chapter + level - 2) % ENEMIES.size()]
		var is_great_boss: bool = level == 5 and chapter % 10 == 0
		var mechanics := _chapter_mechanics(chapter, is_great_boss)
		var adds := _chapter_adds(chapter, level, is_great_boss)
		var factor: float = _chapter_factor(chapter)
		var level_health: float = 1.0 + float(level - 1) * 0.12
		var level_damage: float = 1.0 + float(level - 1) * 0.10
		encounters.append({
			"chapter":chapter,"level":level,
			"health":maxi(6, int(round(28.0 * factor * level_health))),
			"damage":maxi(2, int(round(4.0 * factor * level_damage))),
			"reward":int(round(16.0 + float(chapter) * 5.0 + float(level) * 2.0 + factor * 4.0)),
			"name":enemy.name,"name_en":enemy.get("name_en", enemy.name),"art":enemy.art,
			"mechanics":mechanics,"adds":adds,"background":(chapter - 1) % 5
		})

const UI_TEXT = {
	"ui.choose_dest": {"zh-Hans":"沿灵迹选择目的地", "en":"Follow the spirit trail"},
	"ui.lang_toggle": {"zh-Hans":"中/EN", "en":"EN/中"},
	"ui.deck_btn": {"zh-Hans":"牌组", "en":"Deck"},
	"ui.equip_btn": {"zh-Hans":"装备", "en":"Gear"},
	"ui.shop_btn": {"zh-Hans":"商店", "en":"Shop"},
	"ui.next_btn": {"zh-Hans":"下一关", "en":"Next"},
	"ui.chapter_n": {"zh-Hans":"第%d大关 · %s", "en":"Chapter %d · %s"},
	"ui.turn_n": {"zh-Hans":"回合 %d", "en":"Turn %d"},
	"ui.draw_pile": {"zh-Hans":"抽牌", "en":"Draw"},
	"ui.discard_pile": {"zh-Hans":"弃牌", "en":"Discard"},
	"ui.exhaust_pile": {"zh-Hans":"消耗", "en":"Exhaust"},
	"ui.spirit_name": {"zh-Hans":"绯狐", "en":"Crimson Fox"},
	"ui.player_status": {"zh-Hans":"%s   ♥ %d/60   ◆ 护盾 %d", "en":"%s   ♥ %d/60   ◆ Shield %d"},
	"ui.energy_actions": {"zh-Hans":"能量 %d    本回合还可出牌 %d", "en":"Energy %d    %d plays remaining"},
	"ui.end_turn": {"zh-Hans":"结束回合", "en":"End Turn"},
	"ui.battle_won": {"zh-Hans":"战斗胜利", "en":"Victory"},
	"ui.battle_lost": {"zh-Hans":"远征失败", "en":"Expedition Failed"},
	"ui.open_chest": {"zh-Hans":"打开胜利宝箱", "en":"Open Victory Chest"},
	"ui.return_map": {"zh-Hans":"返回地图", "en":"Return to Map"},
	"ui.drag_hint": {"zh-Hans":"拖出卡牌使用 · 伤害牌拖到敌人，增益牌可拖到空白处", "en":"Drag cards to play · Drag attacks onto enemies, buffs anywhere"},
	"ui.target_invalid": {"zh-Hans":"目标无效或资源不足", "en":"Invalid target or insufficient resources"},
	"ui.hp_lost": {"zh-Hans":"−%d 生命", "en":"−%d HP"},
	"ui.revive_toast": {"zh-Hans":"✥ 敌人复活 +%d", "en":"✥ Enemy revived +%d"},
	"ui.crit_intent": {"zh-Hans":"✹ 暴击 %d", "en":"✹ CRIT %d"},
	"ui.attack_intent": {"zh-Hans":"⚔ 攻击 %d", "en":"⚔ ATK %d"},
	"ui.add_name": {"zh-Hans":"灵迹随从", "en":"Spirit Minion"},
	"ui.gold_reward": {"zh-Hans":"◆ +%d 金币    ♥ 战后恢复 10", "en":"◆ +%d Gold    ♥ Post-battle heal 10"},
	"ui.boss_equip_title": {"zh-Hans":"%s 首领装备 · %s", "en":"%s Boss Equipment · %s"},
	"ui.elite_rune_title": {"zh-Hans":"%s 精英符文 · %s", "en":"%s Elite Rune · %s"},
	"ui.choose_card": {"zh-Hans":"选择一张新卡", "en":"Choose a new card"},
	"ui.skip_card": {"zh-Hans":"跳过卡牌并返回地图", "en":"Skip card & return to map"},
	"ui.event_traveler": {"zh-Hans":"迷雾中的旅者", "en":"Traveler in the Mist"},
	"ui.chapter_title": {"zh-Hans":"第 %d 章", "en":"Chapter %d"},
	"ui.event_merchant": {"zh-Hans":"路边行商", "en":"Roadside Merchant"},
	"ui.event_rest": {"zh-Hans":"灵火营地", "en":"Spirit Campfire"},
	"ui.event_default": {"zh-Hans":"旅途事件", "en":"Journey Event"},
	"ui.event_prompt": {"zh-Hans":"选择一项准备，然后进入本关战斗。", "en":"Choose a preparation, then enter battle."},
	"ui.event_opt_gold": {"zh-Hans":"接受委托 · ◆ +25", "en":"Accept commission · ◆ +25"},
	"ui.event_opt_heal": {"zh-Hans":"灵泉祝福 · ♥ +15", "en":"Spring blessing · ♥ +15"},
	"ui.event_opt_rest_heal": {"zh-Hans":"休息 · ♥ +12", "en":"Rest · ♥ +12"},
	"ui.event_opt_upgrade": {"zh-Hans":"强化一张牌", "en":"Upgrade a card"},
	"ui.event_opt_potion": {"zh-Hans":"购买药剂 · ◆30 / ♥+25", "en":"Buy potion · ◆30 / ♥+25"},
	"ui.event_opt_direct": {"zh-Hans":"直接进入战斗", "en":"Enter battle directly"},
	"ui.shop_title": {"zh-Hans":"灵契商店", "en":"Spirit Shop"},
	"ui.shop_sub": {"zh-Hans":"购买卡牌与生命药剂", "en":"Buy cards & health potions"},
	"ui.shop_potion": {"zh-Hans":"生命药剂 · 恢复 20 点生命", "en":"Health Potion · Restore 20 HP"},
	"ui.shop_no_gold": {"zh-Hans":"金币不足", "en":"Not enough gold"},
	"ui.shop_card_fmt": {"zh-Hans":"%s   ◆%d   拥有%d", "en":"%s   ◆%d   Owned %d"},
	"rarity.Starter": {"zh-Hans":"初始", "en":"Starter"},
	"rarity.Common": {"zh-Hans":"普通", "en":"Common"},
	"rarity.Uncommon": {"zh-Hans":"罕见", "en":"Uncommon"},
	"rarity.Rare": {"zh-Hans":"稀有", "en":"Rare"},
	"ui.deck_title": {"zh-Hans":"牌组构筑", "en":"Deck Builder"},
	"ui.deck_sub": {"zh-Hans":"固定 25 张 · 当前 %d/25", "en":"Fixed 25 cards · Current %d/25"},
	"ui.deck_owned_fmt": {"zh-Hans":"%s  拥有%d", "en":"%s  Owned %d"},
	"ui.deck_confirm_fmt": {"zh-Hans":"确认牌组 %d/25", "en":"Confirm deck %d/25"},
	"ui.loadout_title": {"zh-Hans":"装备与符文", "en":"Equipment & Runes"},
	"ui.loadout_sub": {"zh-Hans":"三个装备槽位 · 每种卡牌一个符文", "en":"Three equipment slots · One rune per card"},
	"ui.loadout_cur_equip": {"zh-Hans":"当前装备", "en":"Current Equipment"},
	"ui.loadout_empty": {"zh-Hans":"空", "en":"Empty"},
	"ui.loadout_collection": {"zh-Hans":"装备收藏", "en":"Equipment Collection"},
	"ui.loadout_unequip": {"zh-Hans":"卸下", "en":"Unequip"},
	"ui.loadout_equip": {"zh-Hans":"装备", "en":"Equip"},
	"ui.loadout_unobtained": {"zh-Hans":"未获得", "en":"Locked"},
	"ui.loadout_runes_bag": {"zh-Hans":"符文行囊 · 选择后镶嵌到卡牌", "en":"Rune Bag · Select then socket to card"},
	"ui.loadout_deck_runes": {"zh-Hans":"牌组符文", "en":"Deck Runes"},
	"ui.loadout_unsocketed": {"zh-Hans":"未镶嵌", "en":"None"},
	"ui.loadout_remove": {"zh-Hans":"取下", "en":"Remove"},
	"ui.loadout_socket": {"zh-Hans":"镶嵌", "en":"Socket"},
	"ui.loadout_select_first": {"zh-Hans":"请先选择符文", "en":"Please select a rune first"},
	"ui.camp_title": {"zh-Hans":"探险营地", "en":"Expedition Camp"},
	"ui.camp_sub": {"zh-Hans":"档案、遗物与挑战阶梯", "en":"Dossier, relics, and challenge tiers"},
	"ui.camp_tier": {"zh-Hans":"挑战等级 A%d", "en":"Challenge Tier A%d"},
	"ui.camp_relics": {"zh-Hans":"已获得遗物 %d/5", "en":"Relics collected %d/5"},
	"ui.camp_desc": {"zh-Hans":"更高挑战提高敌人生命与伤害；Boss装备奖励会轮换。", "en":"Higher tiers boost enemy HP & ATK; Boss equipment rotates."},
	"ui.thorns_toast": {"zh-Hans":"荆棘反伤 −%d", "en":"Thorns reflect −%d"},
	"ui.quests_title": {"zh-Hans":"探险委托", "en":"Quest Commissions"},
	"ui.quests_sub": {"zh-Hans":"每日与每周探险委派", "en":"Daily & weekly commissions"},
	"ui.quests_hint": {"zh-Hans":"完成每日与每周委派任务，获取金币奖励与探险声望。", "en":"Complete daily and weekly commission tasks to earn gold and renown."},
	"ui.quests_daily": {"zh-Hans":"每日任务", "en":"Daily Quests"},
	"ui.quests_weekly": {"zh-Hans":"每周任务", "en":"Weekly Quests"},
	"ui.quests_daily_reset": {"zh-Hans":"%s后重置", "en":"Resets in %s"},
	"ui.quest_claim": {"zh-Hans":"领取", "en":"Claim"},
	"ui.quest_claimed": {"zh-Hans":"已领取", "en":"Claimed"},
	"ui.quest_reward_fmt": {"zh-Hans":"◆ %d", "en":"◆ %d"},
	"ui.quest_claimed_toast": {"zh-Hans":"任务完成 +%d 金币", "en":"Quest complete +%d gold"},
	"ui.quest_ready_toast": {"zh-Hans":"✦ 有任务可以领取了", "en":"✦ A quest is ready to claim"},
	"ui.reward_choose": {"zh-Hans":"选择一张卡牌带走", "en":"Choose a card to take"},
	"ui.reward_collect": {"zh-Hans":"只收入收藏", "en":"Collect only"},
	"ui.reward_smart_add": {"zh-Hans":"✦ 智能入组", "en":"✦ Add to deck"},
	"ui.reward_owned": {"zh-Hans":"已有 %d 张", "en":"Owned %d"},
	"ui.reward_in_deck": {"zh-Hans":"牌组中 %d 张", "en":"%d in deck"},
	"ui.reward_collected": {"zh-Hans":"%s 已收入收藏", "en":"%s added to your collection"},
	"ui.reward_added": {"zh-Hans":"%s 已加入牌组", "en":"%s added to your deck"},
	"ui.reward_replaced": {"zh-Hans":"%s 入组，替换掉 %s", "en":"%s added, replacing %s"},
	"ui.reward_gold_line": {"zh-Hans":"◆ +%d 金币", "en":"◆ +%d gold"},
	"ui.reward_heal_line": {"zh-Hans":"♥ 战后恢复 10 点生命", "en":"♥ Recovered 10 HP"},
	"ui.target_pick": {"zh-Hans":"选择目标", "en":"Pick a target"},
	"ui.target_cancel": {"zh-Hans":"再次点击卡牌取消", "en":"Tap the card again to cancel"},
	"ui.tap_to_dismiss": {"zh-Hans":"点击空白处关闭", "en":"Tap outside to close"},
	"ui.account_welcome": {"zh-Hans":"踏入灵界", "en":"Enter the Spirit Realm"},
	"ui.account_prompt": {"zh-Hans":"为你的驭灵者取个名字", "en":"Name your spirit tamer"},
	"ui.account_placeholder": {"zh-Hans":"输入名字", "en":"Enter a name"},
	"ui.account_start": {"zh-Hans":"开始远征", "en":"Begin Expedition"},
	"ui.account_need_name": {"zh-Hans":"请先输入名字", "en":"Please enter a name first"},
	"ui.account_title": {"zh-Hans":"账号", "en":"Account"},
	"ui.account_local": {"zh-Hans":"本地账号", "en":"Local account"},
	"ui.account_id": {"zh-Hans":"存档 ID", "en":"Save ID"},
	"ui.account_created": {"zh-Hans":"创建于 %s", "en":"Created %s"},
	"ui.account_rename": {"zh-Hans":"改名", "en":"Rename"},
	"ui.account_cloud": {"zh-Hans":"云端同步（即将支持）", "en":"Cloud sync (coming soon)"},
	"ui.account_cloud_hint": {"zh-Hans":"存档已按云同步格式保存，接入 Apple / Google 登录后可直接上传。", "en":"Saves already use the cloud-sync format; Apple / Google sign-in can upload them as-is."},
	"ui.intent_attack": {"zh-Hans":"⚔ %d", "en":"⚔ %d"},
	"ui.intent_critical": {"zh-Hans":"✹ %d", "en":"✹ %d"},
	"ui.intent_defend": {"zh-Hans":"⬢ %d", "en":"⬢ %d"},
	"ui.intent_empower": {"zh-Hans":"▲ +%d", "en":"▲ +%d"},
	"ui.intent_curse": {"zh-Hans":"☣ %d", "en":"☣ %d"},
	"ui.intent_attack_defend": {"zh-Hans":"⚔%d ⬢%d", "en":"⚔%d ⬢%d"},
	"ui.intent_tip_attack": {"zh-Hans":"准备攻击", "en":"Preparing to attack"},
	"ui.intent_tip_defend": {"zh-Hans":"准备防御", "en":"Preparing to defend"},
	"ui.intent_tip_empower": {"zh-Hans":"准备强化", "en":"Preparing to empower"},
	"ui.intent_tip_curse": {"zh-Hans":"准备施加燃烧", "en":"Preparing to inflict Burn"},
	"ui.preview_lethal": {"zh-Hans":"致命", "en":"LETHAL"},
	"ui.preview_blocked": {"zh-Hans":"盾挡%d", "en":"%d blocked"},
	"ui.relic_title": {"zh-Hans":"遗物", "en":"Relics"},
	"ui.relic_reward_title": {"zh-Hans":"%s 遗物 · %s", "en":"%s Relic · %s"},
	"ui.relic_none": {"zh-Hans":"尚未获得遗物", "en":"No relics yet"},
	"ui.node_boss": {"zh-Hans":"首领", "en":"Boss"},
	"ui.node_greatboss": {"zh-Hans":"大首领", "en":"Great Boss"},
	"ui.reward_replay_note": {"zh-Hans":"重复挑战：金币减半，不再掉落卡牌、装备与符文。", "en":"Replay: half gold, and no card, equipment or rune drops."},
	"ui.node_elite": {"zh-Hans":"精英", "en":"Elite"},
	"ui.node_event": {"zh-Hans":"事件", "en":"Event"},
	"ui.node_merchant": {"zh-Hans":"行商", "en":"Merchant"},
	"ui.node_rest": {"zh-Hans":"营地", "en":"Camp"},
	"ui.node_battle": {"zh-Hans":"战斗", "en":"Battle"},
	"ui.locked": {"zh-Hans":"未解锁", "en":"Locked"},
	"ui.energy_label": {"zh-Hans":"能量", "en":"Energy"},
	"ui.auto_end_turn": {"zh-Hans":"回合结束", "en":"Turn over"},
	"ui.no_playable": {"zh-Hans":"无可出之牌 · 回合结束", "en":"No playable cards · turn ends"},
	"ui.deck_auto_build": {"zh-Hans":"✦ 智能构筑", "en":"✦ Auto-Build"},
	"ui.deck_confirm": {"zh-Hans":"确认牌组", "en":"Confirm Deck"},
	"ui.deck_in_deck": {"zh-Hans":"入组", "en":"In deck"},
	"ui.deck_owned_short": {"zh-Hans":"拥有", "en":"Owned"},
	"ui.deck_auto_done": {"zh-Hans":"已按属性均衡自动构筑", "en":"Auto-built a balanced deck"},
	"ui.deck_need_cards": {"zh-Hans":"卡牌收藏不足 25 张", "en":"Fewer than 25 cards owned"},
	"ui.deck_full": {"zh-Hans":"牌组已满 25 张", "en":"Deck is full at 25"},
	"ui.tab_equipment": {"zh-Hans":"装备", "en":"Equipment"},
	"ui.tab_runes": {"zh-Hans":"符文", "en":"Runes"},
	"ui.slot_weapon": {"zh-Hans":"武器", "en":"Weapon"},
	"ui.slot_armor": {"zh-Hans":"护甲", "en":"Armor"},
	"ui.slot_charm": {"zh-Hans":"灵佩", "en":"Charm"},
	"ui.shop_buy": {"zh-Hans":"购买", "en":"Buy"},
	"ui.shop_refresh": {"zh-Hans":"%s后上新", "en":"New stock in %s"},
	"ui.shop_sale": {"zh-Hans":"今日特惠", "en":"Today's Deal"},
	"ui.shop_next_price": {"zh-Hans":"下一张 ◆%d", "en":"Next copy ◆%d"},
	"ui.shop_gold": {"zh-Hans":"◆ %d", "en":"◆ %d"},
	"ui.shop_bought": {"zh-Hans":"已购入 %s", "en":"Bought %s"},
	"ui.rune_none_selected": {"zh-Hans":"点击符文选中，再点卡牌镶嵌", "en":"Tap a rune, then tap a card to socket"},
	"desc.damage": {"zh-Hans":"造成%d点伤害", "en":"Deal %d damage"},
	"desc.shield": {"zh-Hans":"获得%d点护盾", "en":"Gain %d Shield"},
	"desc.heal": {"zh-Hans":"回复%d点生命", "en":"Restore %d HP"},
	"desc.draw": {"zh-Hans":"抽%d张牌", "en":"Draw %d cards"},
	"desc.burn": {"zh-Hans":"施加%d层燃烧", "en":"Apply %d Burn"},
	"desc.focus": {"zh-Hans":"施加%d层凝神", "en":"Apply %d Focus"},
	"desc.vulnerable": {"zh-Hans":"施加%d回合易伤（受到伤害+50%%）", "en":"Apply %d Vulnerable (+50%% damage taken)"},
	"desc.weak": {"zh-Hans":"施加%d回合虚弱（造成伤害-25%%）", "en":"Apply %d Weak (-25%% damage dealt)"},
	"desc.strength": {"zh-Hans":"获得%d点本场力量（攻击牌永久+伤害）", "en":"Gain %d Strength this battle (permanent attack bonus)"},
	"desc.energy": {"zh-Hans":"获得%d点能量", "en":"Gain %d Energy"},
	"desc.special.pierce": {"zh-Hans":"无视护盾", "en":"Pierces Shield"},
	"desc.special.cleave": {"zh-Hans":"命中所有敌人", "en":"Hits all enemies"},
	"desc.special.critical": {"zh-Hans":"伤害翻倍", "en":"Double damage"},
	"desc.special.stun": {"zh-Hans":"眩晕目标一回合", "en":"Stuns target for a turn"},
	"desc.special.recoverExhaust": {"zh-Hans":"取回一张消耗牌", "en":"Return an exhausted card"},
	"desc.special.recycleDiscard": {"zh-Hans":"回收弃牌堆至多2张", "en":"Recycle up to 2 discards"},
}

func ui(key: String, language := "zh-Hans") -> String:
	var entry: Dictionary = UI_TEXT.get(key, {})
	if entry.is_empty(): return text(key, language)
	return str(entry.get(language, entry.get("en", key)))

func equip_name(item: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return item.get("en", item.get("zh", ""))
	return item.get("zh", "")

func equip_detail(item: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return item.get("detail_en", item.get("detail", ""))
	return item.get("detail", "")

func rune_name(rune: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return rune.get("en", rune.get("zh", ""))
	return rune.get("zh", "")

func rune_detail(rune: Dictionary, language := "zh-Hans") -> String:
	if language == "en": return rune.get("detail_en", rune.get("detail", ""))
	return rune.get("detail", "")
