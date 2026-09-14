extends SceneTree

var failures := 0
var checks := 0
var content: SpiritContent

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
	check(swift.state.energy == 3,"Swift refunds its first play's energy cost")

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
	relic_run.create(10,encounter(),content.raw.startingDeck,60,{},[],{},{},["windChime","foxCharm"])
	check(relic_run.state.hand.size() == 7 and int(relic_run.state.energy) == 4,"relics apply at battle start")

	var profile := SpiritSave.defaults(content)
	check(profile.deck.size() == 25 and profile.equipment_slots.is_empty(),"new save schema is valid")

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

	# Two of the priciest cards in the same hand should not both fit in 3 energy — that gap
	# is the whole point of the rework, so assert it directly rather than trusting the spread.
	var pricey := SpiritCombat.new(content)
	pricey.create(50, encounter(), content.raw.startingDeck, 60)
	pricey.state.hand = [{"uid": 910, "card_id": "spiritLance"}, {"uid": 911, "card_id": "calmWard"}]
	check(pricey.play(0, 0), "first 2-cost card plays")
	check(not pricey.play(1), "a second 2-cost card cannot also fit in 3 energy (%d left)" % int(pricey.state.energy))

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

	print("SPIRITBOUND TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _force_hand(battle: SpiritCombat, card_id: String) -> void:
	battle.state.hand = [{"uid":900,"card_id":card_id}]
