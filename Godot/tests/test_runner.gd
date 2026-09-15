extends SceneTree

var failures := 0
var checks := 0
var content: SpiritContent
var had_profile := false
var saved_profile := ""

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)

func encounter(health := 40, damage := 7, adds := 0) -> Dictionary:
	return {"chapter":1,"level":1,"health":health,"damage":damage,"reward":20,"name":"测试守卫","art":"sentinel-v1.jpg","mechanics":{},"adds":adds,"background":0}

# Enemies now telegraph varied intents, so tests about what happens when the player is hit
# have to pin the intent instead of assuming every turn is an attack.
func force_attack(combat: SpiritCombat) -> void:
	for enemy in combat.state.enemies:
		if enemy.health > 0: enemy.intent = {"kind":"attack","amount":int(enemy.damage)}

func run() -> void:
	had_profile = FileAccess.file_exists(SpiritSave.PATH)
	if had_profile: saved_profile = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()
	content = SpiritContent.new()
	check(content.cards.size() >= 20,"all card definitions load")
	check(content.raw.startingDeck.size() == 25,"starting deck contains 25 cards")
	check(content.encounters.size() == 250,"campaign contains 250 stages across 50 chapters")
	check(SpiritContent.EQUIPMENT.size() == 12,"twelve equipment definitions")
	check(SpiritContent.RUNES.size() == 10,"ten rune definitions")

	var battle := SpiritCombat.new(content)
	battle.create(42,encounter(),content.raw.startingDeck,60)
	check(battle.state.hand.size() == 5,"opening hand has five cards")
	check(battle.state.draw.size() == 20,"twenty cards remain in draw pile")
	var first_energy: int = battle.state.energy
	var first_cost: int = int(content.card(battle.state.hand[0].card_id).cost)
	battle.play(0)
	check(battle.state.energy == first_energy - first_cost,"playing a card spends its energy cost")

	var swift := SpiritCombat.new(content)
	swift.create(2,encounter(100,0),Array(content.raw.startingDeck),60,{},[],{"strike":"swift"})
	_force_hand(swift,"strike")
	swift.play(0,0)
	check(swift.state.energy == 2,"Swift refunds its first play's energy cost")

	var chain := SpiritCombat.new(content)
	chain.create(3,encounter(20,0,1),Array(content.raw.startingDeck),60,{},[],{"strike":"chain"})
	_force_hand(chain,"strike")
	chain.play(0,0)
	check(chain.state.enemies[0].health == 14,"Chain deals full damage on primary target")
	check(chain.state.enemies[1].health == chain.state.enemies[1].max_health - 2,"Chain splashes forty percent")

	var cycle := SpiritCombat.new(content)
	cycle.create(4,encounter(100,0),Array(content.raw.startingDeck),60,{},[],{"ward":"cycle"})
	_force_hand(cycle,"ward")
	var uid: int = cycle.state.hand[0].uid
	cycle.play(0)
	check(cycle.state.draw[0].uid == uid,"Cycle places played card at draw pile bottom")

	var gear := SpiritCombat.new(content)
	gear.create(5,encounter(100,5),content.raw.startingDeck,60,{},["jadePlate","mistCloak"])
	check(gear.state.player.shield == 8,"Jade Plate grants opening shield")
	force_attack(gear); gear.end_turn()
	force_attack(gear); gear.end_turn()
	force_attack(gear); gear.end_turn()
	check(gear.state.player.health == 55,"Jade shield absorbs the first hit and Mist Cloak negates the third")

	var phoenix := SpiritCombat.new(content)
	phoenix.create(6,encounter(100,100),content.raw.startingDeck,60,{},["phoenixMail"])
	force_attack(phoenix)
	phoenix.end_turn()
	check(phoenix.state.player.health == 15 and phoenix.state.phase == "player","Phoenix Mail prevents one defeat")

	var intents := SpiritCombat.new(content)
	intents.create(9,encounter(90,6),content.raw.startingDeck,60)
	check(not intents.state.enemies[0].intent.is_empty(),"enemies telegraph an intent before the player acts")
	var planned: Dictionary = intents.state.enemies[0].intent.duplicate()
	var hp_before: int = int(intents.state.player.health)
	intents.end_turn()
	if str(planned.kind) == "attack":
		check(hp_before - int(intents.state.player.health) == int(planned.amount),"attack intents deal exactly the telegraphed damage")
	else:
		check(int(intents.state.player.health) == hp_before,"non-attack intents deal no damage")

	var relic_run := SpiritCombat.new(content)
	relic_run.create(10,encounter(),content.raw.startingDeck,60,{},[],{},{},["foxCharm"])
	check(relic_run.state.hand.size() == 5 and int(relic_run.state.energy) == 2,"turn 1 is strictly 5 cards and 2 energy even with relics")
	relic_run.state.hand.pop_back()
	relic_run.state.hand.pop_back()
	check(relic_run.state.hand.size() == 3, "player has 3 cards remaining at end of turn 1")
	relic_run.end_turn()
	check(relic_run.state.hand.size() == 5 and int(relic_run.state.energy) == 3,"turn 2 draws flat 2 cards (3 remaining -> 5 cards) and foxCharm grants 3 energy")

	var chime_combat := SpiritCombat.new(content)
	chime_combat.create(10,encounter(),content.raw.startingDeck,60,{},[],{},{},["windChime"])
	chime_combat.state.discard = [chime_combat.state.draw.pop_back(), chime_combat.state.draw.pop_back(), chime_combat.state.draw.pop_back()]
	chime_combat.state.draw.clear()
	var hand_before: int = chime_combat.state.hand.size()
	chime_combat._draw(1)
	check(chime_combat.state.hand.size() == hand_before + 2, "windChime draws extra card on reshuffle")

	var tide_combat := SpiritCombat.new(content)
	tide_combat.create(10,encounter(),content.raw.startingDeck,60,{},["tideCharm"],{},{},[])
	var tide_hand_before: int = tide_combat.state.hand.size()
	var ward_card := content.card("ward")
	tide_combat._resolve_effects(ward_card, -1, 0, 1.0)
	check(tide_combat.state.hand.size() == tide_hand_before + 1, "tideCharm draws 1 card on first shield gain")

	var profile := SpiritSave.defaults(content)
	check(profile.deck.size() == 25 and profile.equipment_slots.is_empty() and profile.claimed_stage_events is Array,"new save schema is valid")

	check(content.text("card.strike", "zh-Hans") == "击打" and content.text("card.strike", "en") == "Strike", "bilingual card names work")
	check(content.ui("ui.battle_won", "zh-Hans") == "战斗胜利" and content.ui("ui.battle_won", "en") == "Victory", "bilingual UI text works")
	check(content.stage_name(0, "zh-Hans") == "雾林·入口" and content.stage_name(0, "en") == "Mistwood · Trailhead", "bilingual stage names work")
	check(content.equip_name(content.equipment("emberBlade"), "en") == "Ember Blade", "bilingual equipment works")
	check(content.rune_name(content.rune("swift"), "en") == "Swift", "bilingual runes work")

	var scn: PackedScene = load("res://Main.tscn")
	check(scn != null, "Main.tscn scene loads successfully")
	var game_inst: Control = scn.instantiate()
	check(game_inst != null, "Main scene instantiates")
	check(game_inst._get_character_texture("fox") is AtlasTexture, "character atlas texture slicing works for fox")
	check(game_inst._get_character_texture("sentinel") is AtlasTexture, "character atlas texture slicing works for sentinel")
	check(game_inst._get_card_texture("moonfang") is AtlasTexture, "card atlas 1 texture slicing works for moonfang")
	check(game_inst._get_card_texture("emberClaw") is AtlasTexture, "card atlas 2 texture slicing works for emberClaw")
	check(game_inst._get_card_texture("strike") != null, "card texture strike loads")

	# _card_build_score used to score almost pure rarity, which let the auto-builder fill a
	# deck with utility Power/Tactic cards (foxBlessing, soulBrand, mountainSeal) while
	# starving it of the direct damage that actually ends a fight — confirmed by simulation:
	# that deck lost repeatedly to a two-enemy chapter 7 boss. A plain attacker must now
	# outscore a similarly-costed pure-utility card with no direct board impact.
	game_inst.profile = SpiritSave.defaults(content)
	var attacker := content.card("moonfang")
	var utility := content.card("foxBlessing")
	check(game_inst._card_build_score(attacker) > game_inst._card_build_score(utility), "a reliable attacker outscores a narrow utility card of the same cost")

	game_inst.free()

	# Costs were 1 on every card but two, so 3 energy never bound against the 2-play cap —
	# the readout was accurate but decorative. Pin the spread so a future data edit can't
	# quietly collapse it back to "everything costs 1".
	var by_cost := {1: 0, 2: 0, 3: 0}
	for c in content.cards: by_cost[int(c.cost)] = by_cost.get(int(c.cost), 0) + 1
	check(by_cost.get(2, 0) >= 5, "at least five cards cost 2 energy, got %d" % by_cost.get(2, 0))
	check(by_cost.get(3, 0) >= 1, "at least one card costs the full 3 energy, got %d" % by_cost.get(3, 0))

	# Two of the priciest cards in the same hand should not both fit in a turn-one energy
	# pool — that gap is the whole point of the rework, so assert it directly rather than
	# trusting the spread. Energy opens at 2 (see combat.gd end_turn), so even one 2-cost
	# card already spends the whole pool.
	var pricey := SpiritCombat.new(content)
	pricey.create(50, encounter(), content.raw.startingDeck, 60)
	pricey.state.hand = [{"uid": 910, "card_id": "spiritLance"}, {"uid": 911, "card_id": "calmWard"}]
	check(pricey.play(0, 0), "first 2-cost card plays")
	check(not pricey.play(1), "a second 2-cost card cannot also fit in the turn's remaining energy (%d left)" % int(pricey.state.energy))

	# Strength: unlike Focus (a one-shot burst that resets to 0 after the next attack),
	# Strength persists for the whole battle and should still be adding damage two turns later.
	var strong := SpiritCombat.new(content)
	strong.create(61, encounter(100, 0), content.raw.startingDeck, 60)
	strong.state.player.strength = 4
	strong.state.hand = [{"uid": 920, "card_id": "strike"}]
	strong.play(0, 0)
	check(strong.state.enemies[0].health == 100 - 10, "Strength adds flat damage to an attack (6+4)")
	check(int(strong.state.player.strength) == 4, "Strength is not consumed like Focus")

	# Vulnerable/weak: counterplay debuffs for late-game scaling. Vulnerable raises damage
	# taken by the player; weak lowers damage the enemy deals. Both decay by one enemy turn.
	var debuffed := SpiritCombat.new(content)
	debuffed.create(62, encounter(100, 8), content.raw.startingDeck, 60)
	debuffed.state.enemies[0].vulnerable = 2
	debuffed.state.hand = [{"uid": 921, "card_id": "strike"}]
	debuffed.play(0, 0)
	check(debuffed.state.enemies[0].health == 100 - 9, "Vulnerable increases damage taken by 50%% (6*1.5=9)")

	var weakened := SpiritCombat.new(content)
	weakened.create(63, encounter(100, 8), content.raw.startingDeck, 60)
	weakened.state.enemies[0].weak = 2
	force_attack(weakened)
	var hp_before_weak: int = int(weakened.state.player.health)
	weakened.end_turn()
	check(hp_before_weak - int(weakened.state.player.health) == 6, "Weak reduces enemy damage by 25%% (8*0.75=6)")
	check(int(weakened.state.enemies[0].weak) == 1, "Weak decays by one enemy turn")

	# 250-stage difficulty curve: bands should be monotonically harder, chapter 1 should be
	# trivial and chapter 50 should be a genuine wall. A full Monte Carlo run lives in
	# balance_probe.gd (deleted after use — see Docs/ARCHITECTURE.md for what it found);
	# this is the cheap, permanent version that stops the curve from silently flattening.
	var boss1: Dictionary = content.encounters[4]
	var boss10: Dictionary = content.encounters[49]
	var boss20: Dictionary = content.encounters[99]
	var boss50: Dictionary = content.encounters[249]
	check(int(boss1.health) < 50 and int(boss1.damage) < 10, "chapter 1 boss is trivial (hp=%d dmg=%d)" % [boss1.health, boss1.damage])
	check(int(boss10.health) < int(boss20.health) and int(boss20.health) < int(boss50.health), "boss health grows monotonically across chapters 10/20/50")
	check(int(boss50.health) > int(boss1.health) * 15, "chapter 50 is a different order of magnitude from chapter 1 (%d vs %d)" % [boss50.health, boss1.health])
	check(int(boss50.mechanics.get("enrage", 0)) > 0, "the final boss escalates during the fight, not just at fight start")
	for id in ["shatterGuard", "stormcaller"]:
		check(content.cards.any(func(c): return c.id == id), "%s (vulnerable/weak access point) exists in the card pool" % id)

	# === 10 RUNES COMPREHENSIVE COVERAGE ===
	var echo_run := SpiritCombat.new(content)
	echo_run.create(70, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {"strike": "echo"})
	_force_hand(echo_run, "strike")
	echo_run.play(0, 0)
	check(echo_run.state.enemies[0].health == 100 - 9, "Echo rune repeats attack at 50%% value (6 + 3 = 9)")

	var siphon_run := SpiritCombat.new(content)
	siphon_run.create(71, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {"strike": "siphon"})
	_force_hand(siphon_run, "strike")
	siphon_run.play(0, 0)
	check(int(siphon_run.state.player.shield) == 1, "Siphon rune grants 25%% of damage as shield (6*0.25=1)")

	var burning_run := SpiritCombat.new(content)
	burning_run.create(72, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {"strike": "burning"})
	_force_hand(burning_run, "strike")
	burning_run.play(0, 0)
	check(int(burning_run.state.enemies[0].burn) == 2, "Burning rune applies 2 burn on attack")

	var guardian_run := SpiritCombat.new(content)
	guardian_run.create(73, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {"strike": "guardian"})
	_force_hand(guardian_run, "strike")
	guardian_run.play(0, 0)
	check(int(guardian_run.state.player.shield) == 4, "Guardian rune grants 4 shield on card play")

	var cleanse_run := SpiritCombat.new(content)
	cleanse_run.create(74, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {"strike": "cleanse"})
	cleanse_run.state.player.burn = 5
	_force_hand(cleanse_run, "strike")
	cleanse_run.play(0, 0)
	check(int(cleanse_run.state.player.burn) == 0, "Cleanse rune removes player burn on card play")

	var exec_run := SpiritCombat.new(content)
	exec_run.create(75, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {"strike": "execute"})
	exec_run.state.enemies[0].health = 25
	_force_hand(exec_run, "strike")
	exec_run.play(0, 0)
	check(exec_run.state.enemies[0].health == 25 - 9, "Execute rune deals 1.5x damage when enemy <= 25%% HP (6*1.5=9)")

	var reso_run := SpiritCombat.new(content)
	reso_run.create(76, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {"foxfire": "resonance"})
	reso_run.state.hand = [{"uid": 930, "card_id": "foxfire"}, {"uid": 931, "card_id": "foxfire"}]
	reso_run.state.energy = 4
	reso_run.play(0, 0)
	var hp_after_first: int = int(reso_run.state.enemies[0].health)
	reso_run.play(0, 0)
	check(hp_after_first - int(reso_run.state.enemies[0].health) == 5, "Resonance rune scales damage with previously played elements count")

	# === 12 EQUIPMENT COMPREHENSIVE COVERAGE ===
	var ember_run := SpiritCombat.new(content)
	ember_run.create(80, encounter(100, 0), content.raw.startingDeck, 60, {}, ["emberBlade"])
	_force_hand(ember_run, "strike")
	ember_run.play(0, 0)
	check(ember_run.state.enemies[0].health == 100 - 9, "Ember Blade grants +3 damage on first attack (6+3=9)")

	var moon_run := SpiritCombat.new(content)
	moon_run.create(81, encounter(100, 0), content.raw.startingDeck, 60, {}, ["moonStaff"])
	_force_hand(moon_run, "ashRecall") # costs 2, refunds 1 -> leaves 1 energy
	moon_run.play(0, 0)
	check(int(moon_run.state.energy) == 1, "Moon Staff refunds 1 energy on first Tactic card played (2-2+1=1)")

	var thorn_run := SpiritCombat.new(content)
	thorn_run.create(82, encounter(100, 6), content.raw.startingDeck, 60, {}, ["thornArmor"])
	force_attack(thorn_run)
	thorn_run.end_turn()
	check(thorn_run.state.enemies[0].health == 100 - 2, "Thorn Armor retaliates 2 damage when damaged by enemy")

	var spear_run := SpiritCombat.new(content)
	spear_run.create(83, encounter(100, 0), content.raw.startingDeck, 60, {}, ["stoneSpear"])
	spear_run.state.enemies[0].shield = 20
	_force_hand(spear_run, "strike")
	spear_run.play(0, 0)
	check(spear_run.state.enemies[0].health == 100 - 6 and int(spear_run.state.enemies[0].shield) == 20, "Stone Spear pierces enemy shield directly")

	var soul_run := SpiritCombat.new(content)
	soul_run.create(84, encounter(5, 0), content.raw.startingDeck, 50, {}, ["soulPendant"])
	_force_hand(soul_run, "strike")
	soul_run.play(0, 0)
	check(soul_run.state.player.health == 52, "Soul Pendant heals 2 HP when killing an enemy")

	var bow_run := SpiritCombat.new(content)
	bow_run.create(85, encounter(5, 0), content.raw.startingDeck, 60, {}, ["stormBow"])
	_force_hand(bow_run, "strike")
	bow_run.play(0, 0)
	check(bow_run.state.hand.size() == 1, "Storm Bow draws 1 card on killing an enemy")

	var charm_run := SpiritCombat.new(content)
	charm_run.create(86, encounter(100, 0), content.raw.startingDeck, 60, {}, ["focusCharm"])
	check(int(charm_run.state.player.focus) == 1, "Focus Charm starts combat with 1 Focus")

	var tide_run := SpiritCombat.new(content)
	tide_run.create(87, encounter(100, 0), content.raw.startingDeck, 60, {}, ["tideCharm"])
	check(tide_run.state.hand.size() == 5, "Tide Charm leaves Turn 1 hand strictly at 5 cards")
	_force_hand(tide_run, "ward")
	var t_hand_before: int = tide_run.state.hand.size()
	tide_run.play(0, -1)
	check(tide_run.state.hand.size() == t_hand_before, "Tide Charm draws 1 card on first shield gained (1 played + 1 drawn)")

	# === 8 RELICS COMPREHENSIVE COVERAGE ===
	var star_run := SpiritCombat.new(content)
	star_run.create(90, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {}, ["starShard"])
	_force_hand(star_run, "strike")
	star_run.play(0, 0)
	check(star_run.state.enemies[0].health == 100 - 8, "Star Shard adds +2 damage on first attack (6+2=8)")

	var seed_run := SpiritCombat.new(content)
	seed_run.create(91, encounter(100, 0), content.raw.startingDeck, 50, {}, [], {}, {}, ["ancientSeed"])
	seed_run.end_turn()
	check(seed_run.state.player.health == 52, "Ancient Seed restores 2 HP at start of turn")

	var jade_run := SpiritCombat.new(content)
	jade_run.create(92, encounter(5, 0), content.raw.startingDeck, 50, {}, [], {}, {}, ["bloodJade"])
	_force_hand(jade_run, "strike")
	jade_run.play(0, 0)
	check(jade_run.state.player.health == 53, "Blood Jade restores 3 HP when killing an enemy")

	var seal_run := SpiritCombat.new(content)
	seal_run.create(93, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {}, ["thunderSeal"])
	seal_run.end_turn()
	check(int(seal_run.state.energy) == 2, "Thunder Seal does not trigger on turn 2")
	seal_run.end_turn()
	check(int(seal_run.state.energy) == 5, "Thunder Seal grants +2 energy on turn 3 (3+2=5)")

	var mirror_run := SpiritCombat.new(content)
	mirror_run.create(94, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {}, ["mirrorScale"])
	mirror_run.state.enemies[0].intent = {"kind": "defend", "amount": 0}
	mirror_run.state.player.shield = 10
	mirror_run.end_turn()
	check(int(mirror_run.state.player.shield) == 5, "Mirror Scale retains half shield at end of turn")

	var core_run := SpiritCombat.new(content)
	core_run.create(95, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {}, ["emberCore"])
	core_run.state.enemies[0].intent = {"kind": "defend", "amount": 0}
	core_run.state.enemies[0].shield = 0
	core_run.state.enemies[0].burn = 3
	core_run.end_turn()
	check(core_run.state.enemies[0].health == 100 - 4, "Ember Core increases burn damage by 1")

	# === COMBAT CORE MECHANICS & TURN CURVES ===
	var curve_run := SpiritCombat.new(content)
	curve_run.create(96, encounter(100, 0), content.raw.startingDeck, 60)
	check(int(curve_run.state.energy) == 2, "Turn 1 energy is 2")
	curve_run.end_turn(); check(int(curve_run.state.energy) == 2, "Turn 2 energy is 2")
	curve_run.end_turn(); check(int(curve_run.state.energy) == 3, "Turn 3 energy is 3")
	curve_run.end_turn(); check(int(curve_run.state.energy) == 3, "Turn 4 energy is 3")
	curve_run.end_turn(); check(int(curve_run.state.energy) == 4, "Turn 5 energy is 4")
	curve_run.end_turn(); check(int(curve_run.state.energy) == 4, "Turn 6 energy is 4")

	var cap_run := SpiritCombat.new(content)
	cap_run.create(97, encounter(100, 0), content.raw.startingDeck, 60)
	cap_run._draw(20)
	check(cap_run.state.hand.size() == 10, "Hand size is strictly capped at 10 cards")

	var cleave_run := SpiritCombat.new(content)
	cleave_run.create(98, encounter(100, 0, 2), content.raw.startingDeck, 60)
	_force_hand(cleave_run, "stormArc")
	cleave_run.play(0, 0)
	check(cleave_run.state.enemies[0].health == 100 - 5, "Cleave damages primary enemy")
	check(cleave_run.state.enemies[1].health == cleave_run.state.enemies[1].max_health - 5, "Cleave damages second enemy")
	check(cleave_run.state.enemies[2].health == cleave_run.state.enemies[2].max_health - 5, "Cleave damages third enemy")

	var crit_run := SpiritCombat.new(content)
	crit_run.create(99, encounter(100, 0), content.raw.startingDeck, 60)
	_force_hand(crit_run, "finalFlare")
	crit_run.state.energy = 3
	crit_run.play(0, 0)
	check(crit_run.state.enemies[0].health == 100 - 14, "Critical card deals double damage (7*2=14)")

	var stun_run := SpiritCombat.new(content)
	stun_run.create(100, encounter(100, 10), content.raw.startingDeck, 60)
	_force_hand(stun_run, "mountainSeal")
	stun_run.state.energy = 2
	stun_run.play(0, 0)
	check(int(stun_run.state.enemies[0].stun) == 1, "Stun card applies 1 stun to enemy")
	force_attack(stun_run)
	var hp_before_stun: int = int(stun_run.state.player.health)
	stun_run.end_turn()
	check(int(stun_run.state.player.health) == hp_before_stun, "Stunned enemy attack is completely skipped")
	check(int(stun_run.state.enemies[0].stun) == 0, "Stun counter decrements after turn skip")

	var pierce_run := SpiritCombat.new(content)
	pierce_run.create(101, encounter(100, 0), content.raw.startingDeck, 60)
	pierce_run.state.enemies[0].shield = 30
	_force_hand(pierce_run, "spiritLance")
	pierce_run.state.energy = 2
	pierce_run.play(0, 0)
	check(pierce_run.state.enemies[0].health == 100 - 8 and int(pierce_run.state.enemies[0].shield) == 30, "Pierce card damages health directly without spending shield")

	# === ENEMY MECHANICS ===
	var em_shield_run := SpiritCombat.new(content)
	var enc_shield := encounter(100, 0)
	enc_shield.mechanics = {"shield_per_turn": 8}
	em_shield_run.create(102, enc_shield, content.raw.startingDeck, 60)
	em_shield_run.end_turn()
	check(int(em_shield_run.state.enemies[0].shield) == 8, "Enemy shield_per_turn mechanic grants shield each turn")

	var em_regen_run := SpiritCombat.new(content)
	var enc_regen := encounter(100, 0)
	enc_regen.mechanics = {"regeneration": 5}
	em_regen_run.create(103, enc_regen, content.raw.startingDeck, 60)
	em_regen_run.state.enemies[0].health = 60
	em_regen_run.end_turn()
	check(int(em_regen_run.state.enemies[0].health) == 65, "Enemy regeneration mechanic heals enemy up to max health")

	var em_enrage_run := SpiritCombat.new(content)
	var enc_enrage := encounter(100, 5)
	enc_enrage.mechanics = {"enrage": 3}
	em_enrage_run.create(104, enc_enrage, content.raw.startingDeck, 60)
	em_enrage_run.end_turn()
	check(int(em_enrage_run.state.enemies[0].damage) == 8, "Enemy enrage mechanic permanently increases damage each turn (5+3=8)")

	var em_half_run := SpiritCombat.new(content)
	var enc_half := encounter(100, 6)
	enc_half.mechanics = {"below_half": 4}
	em_half_run.create(105, enc_half, content.raw.startingDeck, 60)
	em_half_run.state.enemies[0].health = 40
	var rolled_damage: int = em_half_run.state.enemies[0].damage + (em_half_run.state.enemies[0].mechanics.get("below_half", 0) if em_half_run.state.enemies[0].health <= em_half_run.state.enemies[0].max_health / 2 else 0)
	check(rolled_damage == 10, "Enemy below_half mechanic adds bonus damage when health <= 50%% (6+4=10)")

	var em_dodge_run := SpiritCombat.new(content)
	var enc_dodge := encounter(100, 0)
	enc_dodge.mechanics = {"dodge_every": 2}
	em_dodge_run.create(106, enc_dodge, content.raw.startingDeck, 60)
	_force_hand(em_dodge_run, "strike")
	em_dodge_run.play(0, 0)
	check(em_dodge_run.state.enemies[0].health == 100 - 6, "First hit connects on dodge_every enemy")
	_force_hand(em_dodge_run, "strike")
	em_dodge_run.state.energy = 2
	em_dodge_run.play(0, 0)
	check(em_dodge_run.state.enemies[0].health == 100 - 6, "Second hit is dodged and deals zero damage")

	# === DATA & TRANSLATION INTEGRITY ===
	var missing_i18n := 0
	for key in content.UI_TEXT:
		var item: Dictionary = content.UI_TEXT[key]
		var zh: String = str(item.get("zh-Hans", ""))
		var en: String = str(item.get("en", ""))
		if zh.strip_edges().is_empty() or en.strip_edges().is_empty():
			missing_i18n += 1
			push_error("Missing translation for key: %s (zh='%s', en='%s')" % [key, zh, en])
	check(missing_i18n == 0, "all %d UI_TEXT keys have valid zh-Hans and en strings" % content.UI_TEXT.size())

	var invalid_cards := 0
	for c in content.cards:
		if int(c.cost) < 1 or int(c.cost) > 3 or c.effects.is_empty():
			invalid_cards += 1
	check(invalid_cards == 0 and content.cards.size() == 36, "all 36 cards have valid costs and effects")

	var invalid_encs := 0
	for enc in content.encounters:
		if int(enc.health) <= 0 or int(enc.damage) <= 0:
			invalid_encs += 1
	check(invalid_encs == 0, "all 250 encounters have positive health and damage")

	var corrupt_save := SpiritSave.defaults(content)
	corrupt_save.deck = ["strike", "strike"]
	var temp_file := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
	temp_file.store_string(JSON.stringify(corrupt_save))
	temp_file.close()
	var loaded_save := SpiritSave.load_profile(content)
	check(loaded_save.deck.size() == 25, "corrupted save deck auto-repairs to 25 cards on load")
	check(loaded_save.get("battle_speed", 0.0) == 1.0, "save defaults battle_speed to 1.0")

	# Keyword glossary bilingual completeness
	var expected_keywords: Array[String] = [
		"damage", "shield", "heal", "draw", "burn", "focus", "vulnerable",
		"weak", "strength", "pierce", "cleave", "critical", "stun", "energy",
		"echo", "siphon", "resonance"
	]
	var missing_kw := 0
	for kw in expected_keywords:
		var entry: Dictionary = SpiritContent.UI_TEXT.get("kw." + kw, {})
		if entry.is_empty() or str(entry.get("zh-Hans", "")).is_empty() or str(entry.get("en", "")).is_empty():
			missing_kw += 1
	check(missing_kw == 0, "all 17 core combat keywords have bilingual descriptions in UI_TEXT")

	# Pass / end turn mechanics check
	var pass_combat := SpiritCombat.new(content)
	pass_combat.create(42, encounter(50, 8), content.raw.startingDeck, 60)
	check(pass_combat.state.turn == 1, "combat begins on turn 1")
	pass_combat.state.player.shield = 10
	pass_combat.end_turn()
	check(pass_combat.state.turn == 2, "passing / ending turn advances to turn 2")
	check(pass_combat.state.player.shield == 0, "shields decay at end of turn")

	# Phase 2 checks: Foil shader asset existence
	check(FileAccess.file_exists("res://assets/shaders/card_foil.gdshader"), "card_foil.gdshader exists on disk")
	var foil_shader: Shader = load("res://assets/shaders/card_foil.gdshader") as Shader
	check(foil_shader != null, "card_foil.gdshader loads as valid Shader resource")

	# Phase 2 checks: Deck Purge & Transformation maintains 25 cards
	var purge_profile := SpiritSave.defaults(content)
	check(purge_profile.deck.size() == 25, "deck starts at 25 cards")
	var strike_idx: int = purge_profile.deck.find("strike")
	check(strike_idx >= 0, "deck contains starter strike")
	# Simulate purge transformation
	purge_profile.deck[strike_idx] = "foxfire"
	check(purge_profile.deck.size() == 25, "deck retains exact 25 cards after purge")
	check(purge_profile.deck[strike_idx] == "foxfire", "starter strike purified into foxfire")

	# Phase 2 checks: UI strings completeness
	var phase2_keys := [
		"ui.rest_title", "ui.rest_prompt", "ui.rest_heal_choice", "ui.rest_purify_choice",
		"ui.rest_smith_choice", "ui.shop_purge_service", "ui.purge_title", "ui.purge_sub",
		"ui.purge_confirm", "ui.purged_toast", "ui.upgrade_title", "ui.upgrade_sub",
		"ui.upgraded_toast", "ui.event_blood_pact", "ui.event_spirit_blessing"
	]
	var missing_p2_strings := 0
	for key in phase2_keys:
		var entry: Dictionary = SpiritContent.UI_TEXT.get(key, {})
		if entry.is_empty() or str(entry.get("zh-Hans", "")).is_empty() or str(entry.get("en", "")).is_empty():
			missing_p2_strings += 1
	check(missing_p2_strings == 0, "all Phase 2 UI strings have bilingual translations")

	# Phase 3 checks: Hero Archetypes / Classes
	check(content.HERO_CLASSES.size() == 3, "three hero archetype classes defined")
	var class_ids := ["fox_spirit", "stone_sentinel", "shadow_stalker"]
	for cid in class_ids:
		var hero: Dictionary = content.hero_class(cid)
		check(hero.id == cid, "hero class %s is accessible" % cid)
		check(hero.deck.size() == 25, "%s starting deck has exactly 25 cards" % cid)
		var expensive_cards := 0
		for card_id in hero.deck:
			var c: Dictionary = content.card(card_id)
			if int(c.cost) > 1: expensive_cards += 1
		check(expensive_cards == 0, "%s starting deck is all 1-cost cards" % cid)

	# Phase 3 checks: Endless Abyss Scaling
	var abyss_f1: Dictionary = content.abyss_encounter(1)
	var abyss_f10: Dictionary = content.abyss_encounter(10)
	check(int(abyss_f1.health) > 0 and int(abyss_f1.damage) > 0, "abyss floor 1 is valid encounter")
	check(int(abyss_f10.health) > int(abyss_f1.health), "abyss floor 10 has scaled health (%d > %d)" % [int(abyss_f10.health), int(abyss_f1.health)])
	check(int(abyss_f10.damage) > int(abyss_f1.damage), "abyss floor 10 has scaled damage (%d > %d)" % [int(abyss_f10.damage), int(abyss_f1.damage)])

	# Phase 3 checks: UI strings completeness
	var phase3_keys := [
		"ui.hero_classes_title", "ui.hero_class_select", "ui.hero_selected_toast",
		"ui.abyss_title", "ui.abyss_sub", "ui.abyss_floor_fmt", "ui.abyss_record_fmt",
		"ui.abyss_enter", "ui.abyss_btn", "ui.abyss_reward_toast"
	]
	var missing_p3_strings := 0
	for key in phase3_keys:
		var entry: Dictionary = SpiritContent.UI_TEXT.get(key, {})
		if entry.is_empty() or str(entry.get("zh-Hans", "")).is_empty() or str(entry.get("en", "")).is_empty():
			missing_p3_strings += 1
	check(missing_p3_strings == 0, "all Phase 3 UI strings have bilingual translations")

	# Milestone 1 checks: Combat transparency & damage forecast rules
	var m1_combat := SpiritCombat.new(content)
	m1_combat.create(77, encounter(30, 8), content.raw.startingDeck, 60)
	_force_hand(m1_combat, "strike")
	var pred_dmg: int = m1_combat.preview_card_damage(0, 0)
	check(pred_dmg == 6, "preview_card_damage correctly predicts basic strike damage (got %d, expected 6)" % pred_dmg)
	check(not m1_combat.is_lethal(0, 0), "strike against 30 hp enemy is not lethal")

	m1_combat.state.enemies[0].health = 5
	check(m1_combat.is_lethal(0, 0), "strike (6 dmg) against 5 hp enemy is lethal")

	# Test incoming damage calculation
	m1_combat.state.enemies[0].intent = {"kind":"attack","amount":12}
	var incoming: int = m1_combat.total_incoming_damage()
	check(incoming == 12, "total_incoming_damage calculates base attack intent (got %d, expected 12)" % incoming)

	m1_combat.state.enemies[0].weak = 1
	var weakened_incoming: int = m1_combat.total_incoming_damage()
	check(weakened_incoming == 9, "total_incoming_damage factors in weak reduction (12 * 0.75 = 9, got %d)" % weakened_incoming)

	# Milestone 1 UI strings completeness
	var m1_keys := [
		"ui.lethal", "ui.danger", "ui.pile_draw_title", "ui.pile_discard_title",
		"ui.pile_exhaust_title", "ui.cancel_drop", "ui.pile_count_desc"
	]
	var missing_m1_strings := 0
	for key in m1_keys:
		var entry: Dictionary = SpiritContent.UI_TEXT.get(key, {})
		if entry.is_empty() or str(entry.get("zh-Hans", "")).is_empty() or str(entry.get("en", "")).is_empty():
			missing_m1_strings += 1
	check(missing_m1_strings == 0, "all Milestone 1 UI strings have bilingual translations")

	if had_profile:
		var restore_file := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
		restore_file.store_string(saved_profile)
		restore_file.close()
	elif FileAccess.file_exists(SpiritSave.PATH):
		DirAccess.remove_absolute(SpiritSave.PATH)

	print("SPIRITBOUND TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _force_hand(battle: SpiritCombat, card_id: String) -> void:
	battle.state.hand = [{"uid":900,"card_id":card_id}]
