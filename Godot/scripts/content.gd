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
	{"name":"雾林守卫", "name_en":"Mistwood Sentinel", "art":"sentinel-v1.jpg", "tint":"83e4c1"},
	{"name":"提灯石卫", "name_en":"Lanternstone Keeper", "art":"lanternstone-keeper-v1.jpg", "tint":"75d7d2"},
	{"name":"缚文巨像", "name_en":"Runebound Colossus", "art":"runebound-colossus-v1.jpg", "tint":"a3c8ff"},
	{"name":"烬崖守护者", "name_en":"Embercliff Guardian", "art":"embercliff-guardian-v1.jpg", "tint":"f0b16d"},
	{"name":"山岳之心", "name_en":"Heart of the Mountain", "art":"heart-of-mountain-v1.jpg", "tint":"e67c65"},
]

const EQUIPMENT = [
	{"id":"emberBlade","slot":"weapon","icon":"⚔","zh":"烬火长刀","en":"Ember Blade","detail":"每回合第一张攻击牌伤害 +3。","detail_en":"First attack each turn deals +3 damage."},
	{"id":"jadePlate","slot":"armor","icon":"⬢","zh":"翠玉战甲","en":"Jade Plate","detail":"战斗开始时获得 8 点护盾。","detail_en":"Start battle with 8 Shield."},
	{"id":"soulPendant","slot":"charm","icon":"◇","zh":"猎魂坠饰","en":"Soul Pendant","detail":"击败敌人回复 2 点生命，每场最多 3 次。","detail_en":"Heal 2 HP on kill, up to 3 times per battle."},
	{"id":"moonStaff","slot":"weapon","icon":"☾","zh":"月纹法杖","en":"Moon Staff","detail":"每回合第一张策略牌返还 1 点能量。","detail_en":"First Tactic each turn refunds 1 Energy."},
	{"id":"thornArmor","slot":"armor","icon":"✣","zh":"荆棘铠甲","en":"Thorn Armor","detail":"受到敌方伤害后反击 2 点。","detail_en":"Retaliate 2 damage when hit by enemies."},
	{"id":"tideCharm","slot":"charm","icon":"≋","zh":"灵潮玉佩","en":"Tide Charm","detail":"起手额外抽 1 张牌。","detail_en":"Draw 1 extra card at battle start."},
	{"id":"stoneSpear","slot":"weapon","icon":"➹","zh":"破岩灵枪","en":"Stone Spear","detail":"攻击牌无视敌方护盾。","detail_en":"Attacks pierce enemy Shield."},
	{"id":"mistCloak","slot":"armor","icon":"≈","zh":"流雾披风","en":"Mist Cloak","detail":"每第三次敌方攻击伤害归零。","detail_en":"Every 3rd enemy attack deals 0 damage."},
	{"id":"fortuneSeal","slot":"charm","icon":"◆","zh":"旅运金印","en":"Fortune Seal","detail":"胜利金币增加 15%。","detail_en":"Gold rewards increased by 15%."},
	{"id":"stormBow","slot":"weapon","icon":"ϟ","zh":"逐电长弓","en":"Storm Bow","detail":"击败敌人时抽 1 张牌。","detail_en":"Draw 1 card on kill."},
	{"id":"phoenixMail","slot":"armor","icon":"♨","zh":"涅槃羽衣","en":"Phoenix Mail","detail":"每场一次，以 15 点生命抵挡致命伤害。","detail_en":"Survive lethal damage once with 15 HP."},
	{"id":"focusCharm","slot":"charm","icon":"◉","zh":"凝神灵镜","en":"Focus Charm","detail":"战斗开始时获得 1 层凝神。","detail_en":"Start battle with 1 Focus."},
]

const RUNES = [
	{"id":"swift","icon":"»","zh":"迅捷","en":"Swift","detail":"每回合第一次使用不消耗出牌次数。","detail_en":"First play each turn spends no action.","color":"78e9ff"},
	{"id":"chain","icon":"⌁","zh":"连锁","en":"Chain","detail":"40% 单体伤害传递给另一名敌人。","detail_en":"40% single-target damage splashes to another enemy.","color":"a2d9ff"},
	{"id":"echo","icon":"◎","zh":"回响","en":"Echo","detail":"以 50% 数值重复卡牌效果。","detail_en":"Repeat card effect at 50% value.","color":"d1a8ff"},
	{"id":"siphon","icon":"◒","zh":"吸魂","en":"Siphon","detail":"获得伤害 25% 的护盾。","detail_en":"Gain Shield equal to 25% of damage dealt.","color":"80e4c0"},
	{"id":"burning","icon":"♨","zh":"灼烧","en":"Burning","detail":"伤害牌额外施加 2 层燃烧。","detail_en":"Attacks apply 2 additional Burn.","color":"ff9868"},
	{"id":"guardian","icon":"⬡","zh":"守御","en":"Guardian","detail":"使用时额外获得 4 点护盾。","detail_en":"Gain 4 Shield on play.","color":"8ff5cf"},
	{"id":"cycle","icon":"↻","zh":"循环","en":"Cycle","detail":"使用后放到抽牌堆底部。","detail_en":"Place at bottom of draw pile on play.","color":"ffd47c"},
	{"id":"cleanse","icon":"✦","zh":"净化","en":"Cleanse","detail":"使用时移除自身燃烧。","detail_en":"Remove Burn from self on play.","color":"f7f0bd"},
	{"id":"execute","icon":"✕","zh":"处决","en":"Execute","detail":"目标低于 25% 生命时伤害 +50%。","detail_en":"Deal +50% damage if target is below 25% HP.","color":"ff7373"},
	{"id":"resonance","icon":"◈","zh":"共鸣","en":"Resonance","detail":"本回合每张同属性牌使数值 +1。","detail_en":"+1 value per same-element card played this turn.","color":"b9a2ff"},
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
			"reward":16 + chapter * 5 + level * 2,"name":enemy.name,"name_en":enemy.get("name_en", enemy.name),"art":enemy.art,
			"mechanics":mechanics,"adds":adds,"background":(chapter - 1) % 5
		})

const UI_TEXT = {
	"ui.choose_dest": {"zh-Hans":"沿灵迹选择目的地", "en":"Follow the spirit trail"},
	"ui.lang_toggle": {"zh-Hans":"中/EN", "en":"EN/中"},
	"ui.deck_btn": {"zh-Hans":"▤\n牌组", "en":"▤\nDeck"},
	"ui.equip_btn": {"zh-Hans":"⚔\n装备", "en":"⚔\nGear"},
	"ui.shop_btn": {"zh-Hans":"◆\n商店", "en":"◆\nShop"},
	"ui.next_btn": {"zh-Hans":"➜\n下一关", "en":"➜\nNext"},
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
	"ui.shop_potion": {"zh-Hans":"✚ 生命药剂 · 恢复20生命 · ◆30", "en":"✚ Health Potion · Restore 20 HP · ◆30"},
	"ui.shop_no_gold": {"zh-Hans":"金币不足", "en":"Not enough gold"},
	"ui.shop_card_fmt": {"zh-Hans":"%s   ◆%d   拥有%d", "en":"%s   ◆%d   Owned %d"},
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
	"ui.camp_title": {"zh-Hans":"远征营地", "en":"Expedition Camp"},
	"ui.camp_sub": {"zh-Hans":"灵兽、遗物与挑战阶梯", "en":"Spirits, relics, and challenge tiers"},
	"ui.camp_tier": {"zh-Hans":"挑战等级 A%d", "en":"Challenge Tier A%d"},
	"ui.camp_relics": {"zh-Hans":"已获得遗物 %d/5", "en":"Relics collected %d/5"},
	"ui.camp_desc": {"zh-Hans":"更高挑战提高敌人生命与伤害；Boss装备奖励会轮换。", "en":"Higher tiers boost enemy HP & ATK; Boss equipment rotates."},
	"desc.damage": {"zh-Hans":"造成%d点伤害", "en":"Deal %d damage"},
	"desc.shield": {"zh-Hans":"获得%d点护盾", "en":"Gain %d Shield"},
	"desc.heal": {"zh-Hans":"回复%d点生命", "en":"Restore %d HP"},
	"desc.draw": {"zh-Hans":"抽%d张牌", "en":"Draw %d cards"},
	"desc.burn": {"zh-Hans":"施加%d层燃烧", "en":"Apply %d Burn"},
	"desc.focus": {"zh-Hans":"施加%d层凝神", "en":"Apply %d Focus"},
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
