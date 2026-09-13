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

const RELICS = [
	{"id":"foxCharm","icon":"✦","color":"ffb765","zh":"绯狐护符","en":"Fox Charm","detail":"战斗首回合额外获得 1 次出牌。","detail_en":"Gain 1 extra play on the first turn."},
	{"id":"starShard","icon":"✧","color":"a2d9ff","zh":"碎星石","en":"Star Shard","detail":"每回合第一张攻击牌额外造成 2 点伤害。","detail_en":"First attack each turn deals +2 damage."},
	{"id":"ancientSeed","icon":"❦","color":"8ff5cf","zh":"古树之种","en":"Ancient Seed","detail":"每回合开始回复 2 点生命。","detail_en":"Restore 2 HP at the start of each turn."},
	{"id":"windChime","icon":"≋","color":"78e9ff","zh":"引灵风铃","en":"Spirit Chime","detail":"战斗开始时额外抽 2 张牌。","detail_en":"Draw 2 extra cards at battle start."},
	{"id":"bloodJade","icon":"❥","color":"ff7373","zh":"饮血玉","en":"Blood Jade","detail":"击败敌人回复 3 点生命。","detail_en":"Restore 3 HP when an enemy dies."},
	{"id":"thunderSeal","icon":"ϟ","color":"ffe08a","zh":"雷纹印","en":"Thunder Seal","detail":"每 3 回合开始时获得 2 点能量。","detail_en":"Gain 2 Energy every third turn."},
	{"id":"mirrorScale","icon":"◈","color":"b9a2ff","zh":"镜鳞甲","en":"Mirror Scale","detail":"回合结束时保留一半护盾。","detail_en":"Keep half of your Shield at end of turn."},
	{"id":"emberCore","icon":"♨","color":"ff9868","zh":"烬心","en":"Ember Core","detail":"燃烧每层额外造成 1 点伤害。","detail_en":"Burn deals 1 extra damage per stack."},
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

func chapter_name(chapter: int, language := "zh-Hans") -> String:
	var index: int = clampi(chapter, 0, CHAPTER_NAMES_ZH.size() - 1)
	if language == "zh-Hans": return CHAPTER_NAMES_ZH[index]
	return CHAPTER_NAMES_EN[index]

func waypoint_name(level: int, language := "zh-Hans") -> String:
	var index: int = clampi(level, 0, WAYPOINT_ZH.size() - 1)
	if language == "zh-Hans": return WAYPOINT_ZH[index]
	return WAYPOINT_EN[index]

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
	"ui.shop_potion": {"zh-Hans":"生命药剂 · 恢复 20 点生命", "en":"Health Potion · Restore 20 HP"},
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
	"ui.intent_name_attack": {"zh-Hans":"攻击", "en":"ATTACK"},
	"ui.intent_name_critical": {"zh-Hans":"暴击", "en":"CRIT"},
	"ui.intent_name_defend": {"zh-Hans":"防御", "en":"DEFEND"},
	"ui.intent_name_empower": {"zh-Hans":"强化", "en":"EMPOWER"},
	"ui.intent_name_curse": {"zh-Hans":"灼烧", "en":"BURN"},
	"ui.intent_name_attack_defend": {"zh-Hans":"攻防", "en":"ATK+DEF"},
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
	"ui.node_elite": {"zh-Hans":"精英", "en":"Elite"},
	"ui.node_event": {"zh-Hans":"事件", "en":"Event"},
	"ui.node_merchant": {"zh-Hans":"行商", "en":"Merchant"},
	"ui.node_rest": {"zh-Hans":"营地", "en":"Camp"},
	"ui.node_battle": {"zh-Hans":"战斗", "en":"Battle"},
	"ui.locked": {"zh-Hans":"未解锁", "en":"Locked"},
	"ui.energy_label": {"zh-Hans":"能量", "en":"Energy"},
	"ui.actions_label": {"zh-Hans":"出牌", "en":"Plays"},
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
	"ui.shop_gold": {"zh-Hans":"◆ %d", "en":"◆ %d"},
	"ui.shop_bought": {"zh-Hans":"已购入 %s", "en":"Bought %s"},
	"ui.rune_none_selected": {"zh-Hans":"点击符文选中，再点卡牌镶嵌", "en":"Tap a rune, then tap a card to socket"},
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
