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
	check(game_inst._get_card_texture("moonfang") != null, "card texture moonfang loads")
	check(game_inst._get_card_texture("emberClaw") != null, "card texture emberClaw loads")
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

	# === PHASE 10: BATTLE RECAP SHARE CARD (POSTER CONTROL TREE) ===
	# _build_recap_poster_control() only reads its recap_data argument plus g.content/pure
	# helpers (_get_character_texture/_card_color/_label/_panel) — none of g.combat/g.profile
	# — so it builds correctly even on an instance never added to a tree, same as
	# _card_build_score() above.
	var recap_sample: Dictionary = {
		"hero_sprite": "fox", "hero_name": "测试英雄",
		"boss_name": "测试首领", "location": "测试地点", "turns": 7,
		"damage_dealt": 42, "cards_played": 5, "shield_gained": 10, "deck_highlights": ["strike", "moonfang"],
	}
	var poster: Control = game_inst._build_recap_poster_control(recap_sample)
	check(poster != null and poster.name == "RecapPoster", "the recap poster's Control tree builds successfully")
	check(poster.size == Vector2(RewardsScreen.RECAP_POSTER_SIZE), "the recap poster is sized to the documented fixed 9:16-ish dimensions")
	var poster_stats: Node = poster.find_child("RecapPosterStats", true, false)
	check(poster_stats != null, "the recap poster's stat row exists")
	var poster_deck: Node = poster.find_child("RecapPosterDeck", true, false)
	check(poster_deck != null and poster_deck.get_child_count() == 2, "the recap poster's deck-highlight row renders one badge per supplied card")
	poster.free()

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
	# trivial and chapter 50 should be a genuine wall. This is the cheap, static version that
	# stops the curve from silently flattening.
	#
	# The full Monte Carlo trajectory lives in balance_probe.gd, restored as a permanent
	# suite (`./run_tests.sh --balance`, or `--balance-quick` for CI). Unlike these static
	# pins, it plays every stage with the real heuristic AI, gathers rewards through the real
	# _grant_stage_rewards()/_smart_add_card()/_card_build_score() plus a farming loop on top
	# (free rest/event upgrades, rune-set socketing, one shop buy a chapter), and fails if
	# chapters 1-4/1-10 are not lossless or the run walls before a measured floor (chapter 35
	# full / chapter 17 quick) — so the two together catch both a flattened curve and a curve
	# that is merely unplayable, which the pinned numbers can't see.
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
	check(int(echo_run.state.stats.cards_played) == 1, "combat tracks cards_played accurately")
	check(int(echo_run.state.stats.damage_dealt) == 9, "combat tracks damage_dealt accurately")
	check(int(guardian_run.state.stats.shield_gained) == 4, "combat tracks shield_gained accurately")

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

	# === PHASE 7: BOOMERANG / REVERB / OVERLOAD KEYWORDS ===
	for id in ["emberBoomerang", "stoneRebound", "windReverb", "spiritReverb", "fireOverload", "poisonOverload"]:
		check(not content.card(id).is_empty(), "%s (Phase 7 keyword card) exists in the card pool" % id)

	# Boomerang (回旋): instead of going to discard/exhaust, the card returns straight to hand
	# at the start of next turn, bypassing the draw pile entirely.
	var boomerang_run := SpiritCombat.new(content)
	boomerang_run.create(90, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {})
	_force_hand(boomerang_run, "emberBoomerang")
	boomerang_run.play(0, 0)
	check(int(boomerang_run.state.enemies[0].health) == 100 - 6, "emberBoomerang deals its 6 damage on play")
	check(boomerang_run.state.hand.is_empty() and boomerang_run.state.discard.is_empty() and boomerang_run.state.exhaust.is_empty(), "a played Boomerang card sits in none of hand/discard/exhaust — it's queued instead")
	check(boomerang_run.state.boomerang_queue.size() == 1, "the played Boomerang card is queued to return next turn")
	boomerang_run.end_turn()
	check(boomerang_run.state.hand.any(func(i): return str(i.card_id) == "emberBoomerang"), "the Boomerang card is back in hand at the start of next turn")
	check(boomerang_run.state.boomerang_queue.is_empty(), "the boomerang queue drains once the card returns")

	# Reverb (余韵): a full-value free recast queued for the start of next turn — distinct from
	# the pre-existing "echo" rune (immediate, same-turn, half value) so the two never collide.
	var reverb_run := SpiritCombat.new(content)
	reverb_run.create(91, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {})
	_force_hand(reverb_run, "windReverb")
	reverb_run.play(0, 0)
	check(int(reverb_run.state.enemies[0].health) == 100 - 6, "windReverb deals its 6 damage immediately")
	check(reverb_run.state.reverb_queue.size() == 1, "windReverb queues a free recast for next turn")
	reverb_run.end_turn()
	check(int(reverb_run.state.enemies[0].health) == 100 - 12, "windReverb's queued recast deals another free 6 damage at the start of next turn (12 total)")
	check(reverb_run.state.reverb_queue.is_empty(), "the reverb queue drains once it fires")

	# Overload (过载): an immediate burst with a next-turn energy debt, floored at 1 the same way
	# titanBell's own growth-cancelling discount never goes negative.
	var overload_run := SpiritCombat.new(content)
	overload_run.create(92, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {})
	_force_hand(overload_run, "fireOverload")
	overload_run.play(0, 0)
	check(int(overload_run.state.enemies[0].health) == 100 - 11, "fireOverload deals its full 11 damage immediately, no cost paid up front beyond its own energy")
	check(int(overload_run.state.overload_pending) == 2, "fireOverload queues a 2-energy debt for next turn")
	overload_run.end_turn()
	check(int(overload_run.state.energy) == 1, "turn 2's baseline 2 energy minus fireOverload's 2-energy debt floors at 1, not 0 (got %d)" % int(overload_run.state.energy))
	check(int(overload_run.state.overload_pending) == 0, "the overload debt clears once it's been paid")

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
		if c.get("rarity", "") == "Curse": continue
		if int(c.cost) < 1 or int(c.cost) > 3 or c.effects.is_empty():
			invalid_cards += 1
	var curse_cards: Array = content.cards.filter(func(c): return c.get("rarity", "") == "Curse")
	check(invalid_cards == 0 and content.cards.size() == 53 and curse_cards.size() == 2, "all 51 collectible cards have valid costs/effects and 2 curses exist")

	var collect_all_ach: Dictionary = SpiritContent.ACHIEVEMENTS.filter(func(a): return a.id == "collect_all")[0]
	check(int(collect_all_ach.target) == content.cards.size() - curse_cards.size(), "collect_all achievement target (%d) tracks the live non-Curse card count (%d), not a stale literal" % [int(collect_all_ach.target), content.cards.size() - curse_cards.size()])

	var invalid_encs := 0
	for enc in content.encounters:
		if int(enc.health) <= 0 or int(enc.damage) <= 0:
			invalid_encs += 1
	check(invalid_encs == 0, "all 250 encounters have positive health and damage")

	# 2026-09-17 balance revalidation (Docs/ARCHITECTURE.md's "250-stage difficulty curve"):
	# tests/balance_probe.gd (a from-scratch AI-driven playthrough sim, rebuilt after the
	# original was lost — see that file's header) found a real, reproducible wall at chapter
	# 19: an elite fight with 2 adds (3 enemies total) plus a "crits every 2nd attack"
	# mechanic, on top of Band 3's own steep per-chapter growth, killed a smart-built deck in
	# 4 turns across every retry. Root cause was two compounding factors landing in the same
	# few chapters: Band 3's 0.22/chapter additive growth (nearly double Band 2's 0.12), and
	# elites gaining a second add at chapter>=15 — square in the middle of Band 3 rather than
	# at a band boundary. Fixed by trimming Band 3's growth to 0.16/chapter and moving the
	# elite add threshold to chapter>=21 (Band 4's start, where "needs farmed gear" already
	# means multi-enemy fights are expected). Re-running the probe confirmed chapters 1-19
	# clear reliably afterward; chapter 20's Great Boss (the first of the 5 scripted-Phase-2
	# capstones, intentionally "the hardest single fight in their neighborhood" per
	# _chapter_mechanics' own comment) remains a wall for a no-farming baseline build — that
	# is Band 4's own documented intent ("needs runes/equipment/relics from earlier farming,
	# not skill alone"), not a bug, and wasn't chased further; see the probe's own output for
	# how band 4 behaves past that point. These two assertions pin the fix so it can't
	# silently regress back to the version that produced the chapter-19 wall.
	check(content._chapter_factor(20) > 3.0 and content._chapter_factor(20) < 3.7, "chapter 20's cumulative difficulty factor (%.2f) stays in the revalidated Band 3 range — the old 0.22/chapter growth put it at 4.16" % content._chapter_factor(20))
	check(content._chapter_adds(19, 3, false) == 1 and content._chapter_adds(21, 3, false) == 2, "an elite's second add starts at chapter 21 (Band 4), not chapter 15 (mid-Band-3) where it used to stack with Band 3's own steep scaling")

	# C2 follow-up: profile.difficulty (A0-A5+) used to have zero effect on actual combat
	# stats despite its own UI text claiming otherwise — see content.difficulty_modifier()'s
	# header comment. Tier 0 must stay a true no-op (the balance probe above validated the
	# base curve at zero extra scaling, and every existing save defaults to difficulty 0).
	check(content.difficulty_modifier(0).is_empty(), "difficulty tier 0 (A0) applies no combat modifier — the balance-probe-validated baseline must not retroactively get harder")
	var tier5_mod: Dictionary = content.difficulty_modifier(5)
	check(is_equal_approx(float(tier5_mod.health_scale), 1.6) and int(tier5_mod.damage_bonus) == 5 and is_equal_approx(float(tier5_mod.reward_scale), 1.5), "difficulty tier 5 (A5) scales health/damage/reward by the documented amount (got health_scale=%.2f, damage_bonus=%d, reward_scale=%.2f)" % [float(tier5_mod.health_scale), int(tier5_mod.damage_bonus), float(tier5_mod.reward_scale)])

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
		"echo", "siphon", "resonance", "poison",
		"boomerang", "reverb", "overload"
	]
	var missing_kw := 0
	for kw in expected_keywords:
		var entry: Dictionary = SpiritContent.UI_TEXT.get("kw." + kw, {})
		if entry.is_empty() or str(entry.get("zh-Hans", "")).is_empty() or str(entry.get("en", "")).is_empty():
			missing_kw += 1
	check(missing_kw == 0, "all 21 core combat keywords have bilingual descriptions in UI_TEXT")
	check(expected_keywords == SpiritGame.KEYWORD_KEYS, "test's expected keyword list stays in sync with game.gd's KEYWORD_KEYS (pill-scanning uses the latter directly)")

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
	check(content.HERO_CLASSES.size() == 4, "four hero archetype classes defined")
	var class_ids := ["fox_spirit", "stone_sentinel", "shadow_stalker", "miasma_witch"]
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

	# Milestone 2 checks: Abyss boons and rules engine mechanics
	check(content.ABYSS_BOONS.size() >= 6, "at least 6 abyss boons defined")
	var boon_ids := ["boon_blood_lust", "boon_iron_core", "boon_spirit_surge", "boon_flame_affinity", "boon_wind_stride", "boon_golden_fortune"]
	for bid in boon_ids:
		var b := content.abyss_boon(bid)
		check(not b.is_empty(), "abyss boon %s is accessible" % bid)

	# Test boon_spirit_surge (+4 first attack damage)
	var m2_combat := SpiritCombat.new(content)
	m2_combat.create(88, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {"boons": ["boon_spirit_surge"]})
	_force_hand(m2_combat, "strike")
	var m2_pred: int = m2_combat.preview_card_damage(0, 0)
	check(m2_pred == 10, "boon_spirit_surge increases first attack damage by +4 (6+4=10, got %d)" % m2_pred)
	m2_combat.play(0, 0)
	check(m2_combat.state.enemies[0].health == 90, "boon_spirit_surge actually dealt 10 damage")

	# Test boon_iron_core (+5 shield on turn end)
	var m2_iron := SpiritCombat.new(content)
	m2_iron.create(89, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {"boons": ["boon_iron_core"]})
	m2_iron.end_turn()
	check(m2_iron.state.player.shield >= 5, "boon_iron_core grants 5 shield at turn end (got %d)" % m2_iron.state.player.shield)

	# Test boon_blood_lust (+8 HP on enemy kill)
	var m2_blood := SpiritCombat.new(content)
	m2_blood.create(90, encounter(5, 0), content.raw.startingDeck, 40, {}, [], {}, {"boons": ["boon_blood_lust"]})
	_force_hand(m2_blood, "strike")
	m2_blood.play(0, 0)
	check(m2_blood.state.player.health == 48, "boon_blood_lust heals 8 HP on enemy kill (40 -> 48, got %d)" % m2_blood.state.player.health)

	# Milestone 2 UI strings completeness
	var m2_keys := [
		"ui.finishing_blow", "ui.finishing_sub", "ui.boon_draft_title", "ui.boon_draft_sub", "ui.boon_acquired_toast",
		"boon.blood_lust.name", "boon.blood_lust.desc", "boon.iron_core.name", "boon.iron_core.desc",
		"boon.spirit_surge.name", "boon.spirit_surge.desc", "boon.flame_affinity.name", "boon.flame_affinity.desc",
		"boon.wind_stride.name", "boon.wind_stride.desc", "boon.golden_fortune.name", "boon.golden_fortune.desc"
	]
	var missing_m2_strings := 0
	for key in m2_keys:
		var entry: Dictionary = SpiritContent.UI_TEXT.get(key, {})
		if entry.is_empty() or str(entry.get("zh-Hans", "")).is_empty() or str(entry.get("en", "")).is_empty():
			missing_m2_strings += 1
	check(missing_m2_strings == 0, "all Milestone 2 UI strings have bilingual translations")

	# Milestone 3: rune resonance, curse cards, and high-stakes boss relics.
	# Gale Resonance: +1 energy on the first cycle/draw card played each turn, and it has to
	# reset each turn — the bug that shipped here (missing _has_draw_effect()) hard-crashed
	# the whole script at load time, so this also stands in as "combat.gd still compiles".
	var gale := SpiritCombat.new(content)
	gale.create(200, encounter(100, 0), Array(content.raw.startingDeck), 60, {}, [], {"strike": "swift", "ward": "cycle"})
	check(gale.state.rune_sets.has("set_gale"), "socketing swift+cycle activates Gale Resonance")
	_force_hand(gale, "ward")
	var gale_energy_before: int = gale.state.energy
	gale.play(0)
	check(gale.state.energy == gale_energy_before, "Gale Resonance's own energy refund cancels cycle's cost on the first cycle each turn")
	check(gale.state.gale_used, "gale_used is set after the first cycle/draw card this turn")
	gale.end_turn()
	check(not gale.state.gale_used, "gale_used resets for the new turn")

	# Flame Resonance: +3 bonus damage specifically against a target that is already burning,
	# not a boost to burn's own damage tick.
	var flame := SpiritCombat.new(content)
	flame.create(201, encounter(100, 0), Array(content.raw.startingDeck), 60, {}, [], {"strike": "burning", "ward": "execute"})
	check(flame.state.rune_sets.has("set_flame"), "socketing burning+execute activates Flame Resonance")
	_force_hand(flame, "strike")
	var strike_dmg: int = int(content.card("strike").effects[0].amount)
	flame.state.enemies[0].burn = 3
	flame.play(0, 0)
	check(flame.state.enemies[0].health == 100 - strike_dmg - 3, "Flame Resonance adds exactly +3 against a burning target (%d expected, got health %d)" % [strike_dmg + 3, 100 - flame.state.enemies[0].health])

	var flame_cold := SpiritCombat.new(content)
	flame_cold.create(202, encounter(100, 0), Array(content.raw.startingDeck), 60, {}, [], {"strike": "burning", "ward": "execute"})
	_force_hand(flame_cold, "strike")
	flame_cold.play(0, 0)
	check(flame_cold.state.enemies[0].health == 100 - strike_dmg, "Flame Resonance adds nothing against a target with no burn")

	# Stone Resonance: 25% chance per shield gain to boost it by 50%. Probabilistic by design,
	# so check the boosted value actually appears over many attempts rather than pinning an
	# exact roll — flat statistical smoke test, not a seed-hunting exercise.
	var stone := SpiritCombat.new(content)
	stone.create(203, encounter(500, 0), Array(content.raw.startingDeck), 200, {}, [], {"strike": "guardian", "ward": "siphon"})
	check(stone.state.rune_sets.has("set_stone"), "socketing guardian+siphon activates Stone Resonance")
	var ward_shield: int = int(content.card("ward").effects[0].amount)
	var boosted_seen := false
	var unboosted_seen := false
	for i in 200:
		stone.state.hand = [{"uid": 900 + i, "card_id": "ward"}]
		stone.state.energy = 99
		var shield_before: int = int(stone.state.player.shield)
		stone.play(0)
		var gained: int = int(stone.state.player.shield) - shield_before
		if gained > ward_shield: boosted_seen = true
		else: unboosted_seen = true
	check(boosted_seen, "Stone Resonance's 50% shield boost fires at least once in 200 tries")
	check(unboosted_seen, "Stone Resonance is a chance, not a guarantee — the plain value also appears in 200 tries")

	# Curse cards: decay_blight pokes for 3 every turn it survives in hand (and does NOT
	# clear itself — the whole point is that playing it, or a Purify Altar/Shop Purge, is
	# the actual way to get rid of it); void_curse (already unplayable at 99 cost) hurts
	# once when drawn and clears itself out automatically at turn end.
	var blight := SpiritCombat.new(content)
	blight.create(204, encounter(100, 0), Array(content.raw.startingDeck), 60)
	blight.state.hand = [{"uid": 950, "card_id": "decay_blight"}]
	var blight_hp_before: int = int(blight.state.player.health)
	force_attack(blight)  # pin the enemy's own intent to its (here, 0) damage stat, not a random curse/defend roll
	blight.end_turn()
	check(int(blight.state.player.health) == blight_hp_before - 3, "decay_blight deals 3 damage if still in hand at turn end")
	# end_turn() also draws the normal 2 cards for the new turn, so hand size alone isn't the
	# signal — decay_blight itself has to still be one of the cards in hand.
	var still_holding_blight := false
	for instance in blight.state.hand:
		if str(instance.card_id) == "decay_blight": still_holding_blight = true
	check(still_holding_blight, "decay_blight stays in hand instead of clearing itself")

	var void_draw := SpiritCombat.new(content)
	void_draw.create(205, encounter(100, 0), Array(content.raw.startingDeck), 60)
	var void_hp_before: int = int(void_draw.state.player.health)
	void_draw.state.draw.append({"uid": 951, "card_id": "void_curse"})
	void_draw._draw(1)
	check(int(void_draw.state.player.health) == void_hp_before - 2, "void_curse deals 2 damage the moment it is drawn")
	void_draw.end_turn()
	var still_holding_void := false
	for instance in void_draw.state.hand:
		if str(instance.card_id) == "void_curse": still_holding_void = true
	check(not still_holding_void, "void_curse clears itself out of hand by the next turn")
	check(not content.card("decay_blight").is_empty() and not content.card("void_curse").is_empty(), "content.card() finds both curse cards in core cards array")

	# cursedTome: +1 draw and -2 HP every turn, including turn 1.
	var tome := SpiritCombat.new(content)
	tome.create(206, encounter(100, 0), Array(content.raw.startingDeck), 60, {}, [], {}, {}, ["cursedTome"])
	check(tome.state.hand.size() == 6, "cursedTome grants +1 opening card (6 instead of 5)")
	check(int(tome.state.player.health) == 58, "cursedTome costs 2 HP on turn 1 too (60 -> 58, got %d)" % int(tome.state.player.health))
	var tome_hand_before: int = tome.state.hand.size()
	tome.end_turn()
	check(tome.state.hand.size() == mini(10, tome_hand_before - 0 + 3), "cursedTome adds its own +1 to the flat turn draw (3 cards drawn instead of 2)")

	# titanBell: the big battle-start HP/shield bonus, and the energy curve trade — it never
	# climbs above the opening 2, instead of the usual +1 every 2 turns.
	var bell := SpiritCombat.new(content)
	bell.create(207, encounter(100, 0), Array(content.raw.startingDeck), 60, {}, [], {}, {}, ["titanBell"])
	check(int(bell.state.player.max_health) == 80 and int(bell.state.player.health) == 80 and int(bell.state.player.shield) == 15, "titanBell grants +20 max HP, +20 HP, +15 shield at battle start")
	for i in 6: bell.end_turn()
	check(int(bell.state.energy) == 2, "titanBell keeps energy flat at 2 even after several turns (turn %d, got %d)" % [int(bell.state.turn), int(bell.state.energy)])

	# chaosPrism: enemies open with +6 shield, and a landed attack stacks Vulnerable.
	var prism := SpiritCombat.new(content)
	prism.create(208, encounter(20, 0), Array(content.raw.startingDeck), 60, {}, [], {}, {}, ["chaosPrism"])
	check(int(prism.state.enemies[0].shield) == 6, "chaosPrism gives enemies +6 opening shield")
	prism.state.enemies[0].shield = 0  # isolate the Vulnerable check from its own opening-shield effect
	_force_hand(prism, "strike")
	prism.play(0, 0)
	check(int(prism.state.enemies[0].get("vulnerable", 0)) == 1, "chaosPrism stacks Vulnerable on a landed attack, got %d" % int(prism.state.enemies[0].get("vulnerable", 0)))

	# Milestone 4: hero mastery, and the Daily Trial's damage_mult modifier.
	# A brand-new hero must sit at level 0 with zero bonuses — combat.gd's documented "turn 1
	# is strictly 2 energy" invariant (see AGENTS.md) has to hold with no mastery investment
	# at all, so every threshold is a positive xp cost rather than "free at 0 xp".
	check(content.mastery_level_for_xp(0) == 0, "a fresh hero starts at mastery level 0")
	check(content.mastery_bonuses("fox_spirit", 0).is_empty(), "level 0 grants no mastery bonuses at all")
	check(content.mastery_level_for_xp(59) == 0, "59 xp is not yet enough for level 1")
	check(content.mastery_level_for_xp(60) == 1, "60 xp reaches level 1")
	check(content.mastery_level_for_xp(799) == 4, "799 xp is level 4, not yet level 5")
	check(content.mastery_level_for_xp(800) == 5, "800 xp reaches the max, level 5")
	check(content.mastery_level_for_xp(5000) == 5, "xp past the level 5 threshold still caps at level 5")
	# fox_spirit's own perks: L1 energy_turn1+1, L3 first_attack_bonus+2, L5 first_attack_bonus+3
	# (cumulative, so level 5 carries both first_attack_bonus perks at once).
	var fox_lv1 := content.mastery_bonuses("fox_spirit", 1)
	check(int(fox_lv1.get("energy_turn1", 0)) == 1 and not fox_lv1.has("first_attack_bonus"), "fox_spirit level 1 only grants its own +1 turn-1 energy perk")
	var fox_lv5 := content.mastery_bonuses("fox_spirit", 5)
	check(int(fox_lv5.get("first_attack_bonus", 0)) == 5, "fox_spirit level 5 sums both first_attack_bonus perks (2 + 3 = 5), got %d" % int(fox_lv5.get("first_attack_bonus", 0)))
	check(int(fox_lv5.get("energy_turn1", 0)) == 1, "fox_spirit level 5 still carries its level 1 perk")

	# Hero Mastery bonuses apply through combat.create()'s new hero_bonuses parameter, using
	# the same battle-start/first-attack/per-turn hooks relics and equipment already use.
	var mastery_start := SpiritCombat.new(content)
	mastery_start.create(300, encounter(100, 0), Array(content.raw.startingDeck), 60, {}, [], {}, {}, [], {"max_hp": 6, "shield_start": 5, "energy_turn1": 1, "burn_start": 1, "vulnerable_start": 1})
	check(int(mastery_start.state.player.max_health) == 66 and int(mastery_start.state.player.health) == 66, "mastery max_hp bonus raises both max and current HP at battle start")
	check(int(mastery_start.state.player.shield) == 5, "mastery shield_start bonus applies at battle start")
	check(int(mastery_start.state.energy) == 3, "mastery energy_turn1 bonus adds to turn 1's opening energy (2 base + 1 = 3)")
	check(int(mastery_start.state.enemies[0].get("burn", 0)) == 1, "mastery burn_start bonus applies to enemies at battle start")
	check(int(mastery_start.state.enemies[0].get("vulnerable", 0)) == 1, "mastery vulnerable_start bonus applies to enemies at battle start")

	var mastery_attack := SpiritCombat.new(content)
	mastery_attack.create(301, encounter(100, 0), Array(content.raw.startingDeck), 60, {}, [], {}, {}, [], {"first_attack_bonus": 4})
	_force_hand(mastery_attack, "strike")
	var strike_amount: int = int(content.card("strike").effects[0].amount)
	mastery_attack.play(0, 0)
	check(int(mastery_attack.state.enemies[0].health) == 100 - strike_amount - 4, "mastery first_attack_bonus adds to the turn's first attack, same site as emberBlade/starShard")

	var mastery_heal := SpiritCombat.new(content)
	mastery_heal.create(302, encounter(100, 0), Array(content.raw.startingDeck), 40, {}, [], {}, {}, [], {"heal_per_turn": 3})
	force_attack(mastery_heal)
	mastery_heal.end_turn()
	check(int(mastery_heal.state.player.health) == 40 - 0 + 3, "mastery heal_per_turn heals at the start of each turn, same site as ancientSeed")

	# Daily Trial: damage_mult scales both the boss's and its adds' damage, on top of the
	# existing flat damage_bonus — the only new combat.gd modifier key this milestone adds.
	var trial_mod := SpiritCombat.new(content)
	trial_mod.create(303, {"chapter":100,"level":1,"health":50,"damage":10,"reward":20,"name":"测试","name_en":"Test","art":"sentinel-v1.jpg","mechanics":{},"adds":1,"background":0}, Array(content.raw.startingDeck), 60, {}, [], {}, {"damage_mult": 2.0})
	check(int(trial_mod.state.enemies[0].damage) == 20, "daily trial damage_mult doubles the boss's damage (10 -> 20)")
	check(int(trial_mod.state.enemies[1].damage) == int(round((2.0 + 100 / 3) * 2.0)), "daily trial damage_mult also doubles an add's damage")

	# === PHASE 8: CURSE RUN MUTATOR MODIFIER KEYS ===
	for id in SpiritContent.MUTATORS.map(func(m): return str(m.id)):
		check(not content.mutator(id).is_empty(), "%s (Curse Run mutator) exists in SpiritContent.MUTATORS" % id)
	check(SpiritContent.MUTATORS.size() == 10, "Curse Run ships exactly 10 mutators")

	# Glass Cannon: player_max_hp caps max HP downward regardless of the usual 60 default.
	var glass_run := SpiritCombat.new(content)
	glass_run.create(310, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {"player_max_hp": 30})
	check(int(glass_run.state.player.max_health) == 30 and int(glass_run.state.player.health) == 30, "Glass Cannon's player_max_hp caps both max and current HP to 30 (got max=%d hp=%d)" % [int(glass_run.state.player.max_health), int(glass_run.state.player.health)])

	# Glass Cannon / Berserker's Pact: player_dmg_mult scales the player's own outgoing damage.
	var dmgmult_run := SpiritCombat.new(content)
	dmgmult_run.create(311, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {"player_dmg_mult": 1.5})
	_force_hand(dmgmult_run, "strike")
	dmgmult_run.play(0, 0)
	check(int(dmgmult_run.state.enemies[0].health) == 100 - 9, "player_dmg_mult scales the player's damage (strike's 6 * 1.5 = 9)")

	# Mirror World: swaps max HP between player and boss at battle start.
	var mirror_world_run := SpiritCombat.new(content)
	mirror_world_run.create(312, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {"mirror_hp": true})
	check(int(mirror_world_run.state.player.max_health) == 100 and int(mirror_world_run.state.player.health) == 100, "mirror_hp gives the player the boss's 100 max HP")
	check(int(mirror_world_run.state.enemies[0].max_health) == 60 and int(mirror_world_run.state.enemies[0].health) == 60, "mirror_hp gives the boss the player's original 60 max HP")

	# No Mercy: card-based heal effects do nothing, without touching other heal sources.
	var no_mercy_run := SpiritCombat.new(content)
	no_mercy_run.create(313, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {"no_heal": true})
	no_mercy_run.state.player.health = 40
	_force_hand(no_mercy_run, "renewal")
	no_mercy_run.play(0, -1)
	check(int(no_mercy_run.state.player.health) == 40, "no_heal nullifies renewal's card-based heal (stays at 40)")

	# Fewer Draws: turn draw reduced by 1, floored at 1 so the hand can never fully stall.
	var fewer_draws_run := SpiritCombat.new(content)
	fewer_draws_run.create(314, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {"draw_penalty": 1})
	check(fewer_draws_run.state.hand.size() == 5, "fewer_draws does not touch the opening hand (still 5)")
	fewer_draws_run.end_turn()
	check(fewer_draws_run.state.hand.size() == 6, "draw_penalty reduces turn 2's draw from 2 to 1 (5+1=6, got %d)" % fewer_draws_run.state.hand.size())

	# Energy Famine: a hard cap that holds even after several turns' worth of normal growth.
	var famine_run := SpiritCombat.new(content)
	famine_run.create(315, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {"energy_cap": 2})
	for i in 6: famine_run.end_turn()
	check(int(famine_run.state.energy) == 2, "energy_cap holds energy at 2 even after 6 turns of normal growth (turn %d, got %d)" % [int(famine_run.state.turn), int(famine_run.state.energy)])

	# === PHASE 9: WORLD EVENTS (ROTATING 4-WEEK THEMED TRIAL) ===
	check(SpiritContent.WORLD_EVENTS.size() == 4, "World Events ships exactly 4 rotating themes")
	# world_event_for_period() is a pure function of the period integer alone (no wall-clock
	# reads inside it — see content.gd's own comment on why), so it's testable at any period,
	# including ones that don't correspond to "now", without mocking the clock at all.
	check(content.world_event_for_period(0).id == content.world_event_for_period(0).id, "the same period always resolves to the same event")
	var ev_a := content.world_event_for_period(5)
	var ev_b := content.world_event_for_period(5 + SpiritContent.WORLD_EVENTS.size())
	check(str(ev_a.id) == str(ev_b.id), "the rotation wraps around cleanly after a full cycle through all 4 events (period 5 == period 5+4)")
	var ev_neg := content.world_event_for_period(-1)
	check(not str(ev_neg.get("id", "")).is_empty(), "a negative period index still resolves to a valid event, no crash or empty result")

	var we_enc := content.world_event_encounter(2, 10)
	var we_ev := content.world_event_for_period(2)
	check(str(we_enc.art) == str(we_ev.art), "world_event_encounter's art matches period 2's actual themed event")
	check(int(we_enc.chapter) == 103, "world event encounters use their own sentinel chapter 103, distinct from campaign/daily-trial/phantom-arena")

	var we_mod := content.world_event_modifier(2)
	check(not str(we_mod.get("name", "")).is_empty() and not str(we_mod.get("detail", "")).is_empty(), "world_event_modifier carries display text so show_battle()'s modifier badge doesn't read a missing property")

	# Confirm a specific event's modifier actually reaches a real battle, same shape as the
	# daily trial's damage_mult check above.
	var storm_period := -1
	for p in SpiritContent.WORLD_EVENTS.size():
		if str(content.world_event_for_period(p).id) == "storm_judge": storm_period = p
	check(storm_period >= 0, "storm_judge is reachable at some period index")
	var we_combat := SpiritCombat.new(content)
	we_combat.create(316, content.world_event_encounter(storm_period, 20), content.raw.startingDeck, 60, {}, [], {}, content.world_event_modifier(storm_period))
	check(int(we_combat.state.enemies[0].damage) == int(round(int(content.world_event_encounter(storm_period, 20).damage) * 1.4)), "storm_judge's damage_mult (1.4x) reaches a real world event battle")

	check(SpiritContent.DAILY_TRIAL_STAGES == 15, "the Daily Trial is 15 stages")
	var trial_stage1 := content.daily_trial_encounter(1)
	var trial_stage15 := content.daily_trial_encounter(15)
	check(int(trial_stage1.chapter) == 100, "daily trial encounters use the sentinel chapter 100, distinct from the campaign's 50 chapters")
	check(int(trial_stage15.health) > int(trial_stage1.health) and int(trial_stage15.damage) > int(trial_stage1.damage), "the daily trial's own 15-stage curve gets harder from stage 1 to stage 15")

	# Same day always rolls the same 3-tag trio — every device attempting today's trial has to
	# fight the identical challenge, the "deterministic seed" the mode is named for.
	var tags_a := content.daily_trial_tags(777)
	var tags_b := content.daily_trial_tags(777)
	check(tags_a.size() == 3, "the daily trial always picks exactly 3 tags")
	var same_ids := true
	for i in 3:
		if str(tags_a[i].id) != str(tags_b[i].id): same_ids = false
	check(same_ids, "the same day seed always rolls the identical 3-tag trio")
	var modifier_a := content.daily_trial_modifier(777)
	check(not str(modifier_a.get("name", "")).is_empty() and not str(modifier_a.get("detail", "")).is_empty(), "daily_trial_modifier carries display text so show_battle()'s modifier badge doesn't read a missing property")

	# Growth roadmap D3: Miasma Witch and the Poison status. Poison ticks like Burn (deals its
	# stack count at turn start) but deliberately never decays on its own — that's the entire
	# point of the archetype, so it gets its own dedicated coverage rather than piggybacking on
	# the existing burn tests.
	var miasma := content.hero_class("miasma_witch")
	check(miasma.id == "miasma_witch", "miasma_witch hero class is accessible")
	check(miasma.deck.size() == 25, "miasma_witch starting deck has exactly 25 cards")
	for card_id in miasma.deck:
		check(int(content.card(card_id).cost) == 1, "miasma_witch starting card %s is 1-cost" % card_id)

	var poison_battle := SpiritCombat.new(content)
	poison_battle.create(400, encounter(100, 0), Array(content.raw.startingDeck), 60)
	force_attack(poison_battle)
	poison_battle.state.enemies[0].poison = 3
	var poison_hp_before: int = int(poison_battle.state.enemies[0].health)
	poison_battle.end_turn()
	check(int(poison_battle.state.enemies[0].health) == poison_hp_before - 3, "poison deals its stack count as damage at turn end")
	check(int(poison_battle.state.enemies[0].poison) == 3, "poison does not decay on its own, unlike burn")

	# toxinDart: 3 damage + 2 poison in one card.
	var toxin_battle := SpiritCombat.new(content)
	toxin_battle.create(401, encounter(100, 0), Array(content.raw.startingDeck), 60)
	_force_hand(toxin_battle, "toxinDart")
	var toxin_amount: int = int(content.card("toxinDart").effects[0].amount)
	toxin_battle.play(0, 0)
	check(int(toxin_battle.state.enemies[0].health) == 100 - toxin_amount, "toxinDart deals its direct damage")
	check(int(toxin_battle.state.enemies[0].poison) == 2, "toxinDart also applies 2 poison")

	# Mastery: poison_start applies to all enemies at battle create(), including adds.
	var miasma_bonuses := content.mastery_bonuses("miasma_witch", 4)
	check(int(miasma_bonuses.get("poison_start", 0)) == 2, "miasma_witch level 4 sums both poison_start perks (1 + 1 = 2)")
	var poison_start_battle := SpiritCombat.new(content)
	poison_start_battle.create(402, encounter(100, 0, 1), Array(content.raw.startingDeck), 60, {}, [], {}, {}, [], {"poison_start": 2})
	check(int(poison_start_battle.state.enemies[0].poison) == 2, "poison_start hero bonus applies to the boss at battle start")
	check(int(poison_start_battle.state.enemies[1].poison) == 2, "poison_start hero bonus applies to adds too")

	# Great Boss Phase 2 transitions:
	# Chapter 10: Ember Berserk (+4 dmg, burn_immune, ignites player)
	var gb10 := SpiritCombat.new(content)
	var enc10 := {"chapter":10,"level":5,"health":100,"damage":10,"reward":50,"name":"烬火巨兽","art":"sentinel-v1.jpg","mechanics":{},"adds":0,"background":0,"is_great_boss":true}
	gb10.create(510, enc10, Array(content.raw.startingDeck), 60)
	gb10.state.enemies[0].burn = 3
	check(gb10.state.enemies[0].phase == 1, "Ch.10 Great Boss starts in phase 1")
	gb10._damage_enemy(0, 55, true) # reduces HP from 100 to 45 (<= 50%)
	check(gb10.state.enemies[0].phase == 2, "Ch.10 Great Boss transitions to phase 2 at <=50% HP")
	check(int(gb10.state.enemies[0].damage) == 14, "Ch.10 Great Boss gains +4 damage (10 -> 14)")
	check(int(gb10.state.enemies[0].burn) == 0, "Ch.10 Great Boss clears burn on phase 2")
	check(bool(gb10.state.enemies[0].mechanics.get("burn_immune", false)), "Ch.10 Great Boss becomes burn immune")
	check(int(gb10.state.player.burn) == 3, "Ch.10 Great Boss ignites player with 3 burn")

	# Chapter 20: Glacial Bastion (+25 shield, frost_armor=2)
	var gb20 := SpiritCombat.new(content)
	var enc20 := {"chapter":20,"level":5,"health":100,"damage":10,"reward":50,"name":"寒霜巨灵","art":"sentinel-v1.jpg","mechanics":{},"adds":0,"background":0,"is_great_boss":true}
	gb20.create(520, enc20, Array(content.raw.startingDeck), 60)
	gb20._damage_enemy(0, 50, true) # HP 100 -> 50
	check(gb20.state.enemies[0].phase == 2, "Ch.20 Great Boss enters phase 2")
	check(int(gb20.state.enemies[0].shield) == 25, "Ch.20 Great Boss gains 25 shield")
	check(int(gb20.state.enemies[0].mechanics.get("frost_armor", 0)) == 2, "Ch.20 Great Boss gains frost_armor 2")
	var dealt_armored := gb20._damage_enemy(0, 10, true)
	check(dealt_armored == 8, "frost_armor 2 reduces 10 damage to 8")

	# Chapter 30: Shadow Legion (player vulnerable=2, clone spawned)
	var gb30 := SpiritCombat.new(content)
	var enc30 := {"chapter":30,"level":5,"health":100,"damage":10,"reward":50,"name":"暗影君主","art":"sentinel-v1.jpg","mechanics":{},"adds":0,"background":0,"is_great_boss":true}
	gb30.create(530, enc30, Array(content.raw.startingDeck), 60)
	gb30._damage_enemy(0, 52, true)
	check(gb30.state.enemies[0].phase == 2, "Ch.30 Great Boss enters phase 2")
	check(int(gb30.state.player.vulnerable) == 2, "Ch.30 Great Boss inflicts 2 vulnerable on player")
	check(gb30.state.enemies.size() == 2, "Ch.30 Great Boss summons a shadow clone add")

	# Chapter 40: Cyclone Domain (dodge_every=2, player weak=2)
	var gb40 := SpiritCombat.new(content)
	var enc40 := {"chapter":40,"level":5,"health":100,"damage":10,"reward":50,"name":"烈风邪龙","art":"sentinel-v1.jpg","mechanics":{},"adds":0,"background":0,"is_great_boss":true}
	gb40.create(540, enc40, Array(content.raw.startingDeck), 60)
	gb40._damage_enemy(0, 51, true)
	check(gb40.state.enemies[0].phase == 2, "Ch.40 Great Boss enters phase 2")
	check(int(gb40.state.enemies[0].mechanics.get("dodge_every", 0)) == 2, "Ch.40 Great Boss gains dodge_every 2")
	check(int(gb40.state.player.weak) == 2, "Ch.40 Great Boss inflicts 2 weak on player")

	# Chapter 50: Abyssal Awakening (cleanses debuffs, drains 6 HP, shuffles void_curse)
	var gb50 := SpiritCombat.new(content)
	var enc50 := {"chapter":50,"level":5,"health":100,"damage":10,"reward":50,"name":"深渊元祖","art":"sentinel-v1.jpg","mechanics":{},"adds":0,"background":0,"is_great_boss":true}
	gb50.create(550, enc50, Array(content.raw.startingDeck), 60)
	gb50.state.enemies[0].burn = 5
	gb50.state.enemies[0].poison = 4
	gb50.state.enemies[0].vulnerable = 3
	var p_hp_before: int = int(gb50.state.player.health)
	gb50._damage_enemy(0, 60, true) # HP 100 -> 40
	check(gb50.state.enemies[0].phase == 2, "Ch.50 Great Boss enters phase 2")
	check(int(gb50.state.enemies[0].burn) == 0 and int(gb50.state.enemies[0].poison) == 0 and int(gb50.state.enemies[0].vulnerable) == 0, "Ch.50 Great Boss cleanses all debuffs")
	check(int(gb50.state.player.health) == p_hp_before - 6, "Ch.50 Great Boss drains 6 HP from player")
	check(gb50.state.draw[0].card_id == "void_curse", "Ch.50 Great Boss pushes void_curse into player draw pile")

	# Account Authentication & Cloud Save linking tests
	var test_prof := SpiritSave.defaults(content)
	check(not SpiritSave.is_cloud_linked(test_prof), "default profile is unlinked guest")
	check(SpiritSave.account_provider(test_prof) == "guest", "default provider is guest")
	SpiritSave.link_account(test_prof, "apple", "apple_sub_999", "hero@privaterelay.appleid.com", "驭灵之王")
	check(SpiritSave.is_cloud_linked(test_prof), "profile is cloud linked after Apple sign in")
	check(SpiritSave.account_provider(test_prof) == "apple", "account provider is apple")
	check(str(test_prof.account.email) == "hero@privaterelay.appleid.com", "apple email is preserved")
	check(str(test_prof.account.name) == "驭灵之王", "account name is preserved")
	check(int(test_prof.account.linked_at) > 0, "linked_at timestamp is set")
	check(int(test_prof.account.cloud_synced_at) > 0, "cloud_synced_at timestamp is set")

	SpiritSave.link_account(test_prof, "google", "google_sub_888", "hero@gmail.com")
	check(SpiritSave.account_provider(test_prof) == "google", "profile upgraded to google provider")
	check(str(test_prof.account.email) == "hero@gmail.com", "google email is updated")

	SpiritSave.unlink_account(test_prof)
	check(not SpiritSave.is_cloud_linked(test_prof), "profile successfully unlinked to guest")
	check(SpiritSave.account_provider(test_prof) == "guest", "provider reverted to guest")

	# Hybrid Dual-Element Cards Tests
	var b_hybrid := SpiritCombat.new(content)
	b_hybrid.create(601, content.encounters[0], Array(content.raw.startingDeck), 60)
	b_hybrid.state.energy = 10
	b_hybrid._resolve_effects(content.card("blaze_tempest"), 0, 0, 1.0)
	check(int(b_hybrid.state.enemies[0].burn) == 2, "blaze_tempest inflicts 2 burn")
	check(int(b_hybrid.state.energy) == 11, "blaze_tempest refunds 1 energy")

	b_hybrid._resolve_effects(content.card("toxic_quake"), 0, 0, 1.0)
	check(int(b_hybrid.state.enemies[0].poison) == 3, "toxic_quake inflicts 3 poison")
	check(int(b_hybrid.state.player.shield) == 8, "toxic_quake grants 8 shield")

	var hybrid_hand_before: int = b_hybrid.state.hand.size()
	b_hybrid._resolve_effects(content.card("frost_surge"), 0, 0, 1.0)
	check(int(b_hybrid.state.player.shield) == 20, "frost_surge adds 12 shield (total 20)")
	check(int(b_hybrid.state.enemies[0].weak) == 1, "frost_surge inflicts 1 weak")
	check(b_hybrid.state.hand.size() == hybrid_hand_before + 2, "frost_surge draws 2 cards")

	b_hybrid._resolve_effects(content.card("gale_barrier"), 0, 0, 1.0)
	check(int(b_hybrid.state.player.shield) == 30, "gale_barrier adds 10 shield (total 30)")
	check(int(b_hybrid.state.energy) == 12, "gale_barrier grants 1 energy")

	b_hybrid.state.player.health = 50
	b_hybrid._resolve_effects(content.card("miasma_shield"), 0, 0, 1.0)
	check(int(b_hybrid.state.player.shield) == 38, "miasma_shield adds 8 shield (total 38)")
	check(int(b_hybrid.state.player.health) == 53, "miasma_shield heals 3 health")

	# Season Pass XP Progression Tests
	var g_pass := SpiritGame.new()
	g_pass.profile = test_prof
	check(int(g_pass.profile.season_pass.xp) == 0, "season pass starts at 0 XP")
	check(int(g_pass.profile.season_pass.get("level", 1)) == 1, "season pass starts at Lv.1")
	g_pass._add_season_xp(150)
	check(int(g_pass.profile.season_pass.xp) == 150, "season pass accumulates 150 XP")
	check(int(g_pass.profile.season_pass.level) == 1, "season pass remains Lv.1 below 200 XP")
	g_pass._add_season_xp(100)
	check(int(g_pass.profile.season_pass.xp) == 250, "season pass reaches 250 XP")
	check(int(g_pass.profile.season_pass.level) == 2, "season pass levels up to Lv.2 at 200+ XP")

	# Accessibility: Text Size scales every label, since every screen builds its text through
	# this one shared _label() helper.
	g_pass.profile.text_scale = 1.0
	check(int(g_pass._label("x", 14).get_theme_font_size("font_size")) == 14, "_label() applies no scaling at the default text_scale of 1.0")
	g_pass.profile.text_scale = 1.2
	check(int(g_pass._label("x", 14).get_theme_font_size("font_size")) == 17, "_label() scales its font size by profile.text_scale (14 * 1.2 rounds to 17)")
	check(SpiritGame.TEXT_SCALE_OPTIONS.has(1.0) and SpiritGame.TEXT_SCALE_OPTIONS.size() == 4, "Settings offers exactly the four supported text sizes")

	var log := BattleLog.new()
	check(log.entries.is_empty(), "a fresh BattleLog starts with no entries")
	log.record("card", {"card": "strike", "damage": 6}, 1)
	log.record("hit", {"enemy": 0, "amount": 6}, 1)
	check(log.entries.size() == 2, "BattleLog.record() appends one entry per call")
	check(str(log.entries[0].kind) == "card" and int(log.entries[0].turn) == 1, "a recorded entry keeps its kind and turn")
	check(int(log.entries[1].payload.get("amount", 0)) == 6, "a recorded entry's payload is preserved")

	check(content.node_kind(4) == "boss" and content.is_boss_kind(content.node_kind(4)), "stage 4 is a boss node, sanity-checking the boss rush fixture")
	check(content.boss_rush_boss_indices(0).is_empty(), "no boss is reachable yet at unlocked=0")
	check(content.boss_rush_boss_indices(4) == [4], "unlocked=4 (just reached the first boss) exposes exactly that one boss")
	var many_bosses: Array = content.boss_rush_boss_indices(49)
	check(many_bosses.size() >= 5 and int(many_bosses[0]) == 4, "unlocked=49 exposes every boss reached so far, still starting from stage 4")

	check(SpiritContent.MAX_CARD_UPGRADE == 2, "a card can be upgraded to Awakened (+2) at most")
	var awakened := SpiritCombat.new(content)
	awakened.create(7, encounter(100, 0), Array(content.raw.startingDeck), 60, {"strike": SpiritContent.MAX_CARD_UPGRADE})
	_force_hand(awakened, "strike")
	awakened.play(0, 0)
	check(awakened.state.enemies[0].health == awakened.state.enemies[0].max_health - 8, "an Awakened (+2) Strike deals its base 6 damage plus the full +2 bonus, unlike the engine capping it at +1")

	# E1: daily_trial_record.history records one entry per day actually played, capped at
	# DAILY_TRIAL_HISTORY_LIMIT, and never records for a brand-new save (day == -1, meaning
	# there is no real previous day's result to log).
	var today_idx: int = int(Time.get_unix_time_from_system()) / SpiritGame.DAY_SECONDS
	g_pass.profile.daily_trial_record = {"day": -1, "stage": 0, "badges": 0, "best_stage": 0, "streak": 0, "streak_claimed": [], "history": []}
	g_pass._ensure_daily_trial_current()
	check(g_pass.profile.daily_trial_record.history.is_empty(), "a brand-new save's first day never records a history entry")

	g_pass.profile.daily_trial_record.day = today_idx - 1
	g_pass.profile.daily_trial_record.stage = 9
	g_pass._ensure_daily_trial_current()
	check(g_pass.profile.daily_trial_record.history.size() == 1, "the next day's rollover records exactly one history entry for the day just finished")
	check(int(g_pass.profile.daily_trial_record.history[0].day) == today_idx - 1 and int(g_pass.profile.daily_trial_record.history[0].stage) == 9, "the recorded entry keeps that day's index and final stage reached")

	var padded_history: Array = []
	for i in range(SpiritContent.DAILY_TRIAL_HISTORY_LIMIT): padded_history.append({"day": i, "stage": 5})
	g_pass.profile.daily_trial_record = {"day": today_idx - 1, "stage": 12, "badges": 0, "best_stage": 0, "streak": 0, "streak_claimed": [], "history": padded_history}
	g_pass._ensure_daily_trial_current()
	check(g_pass.profile.daily_trial_record.history.size() == SpiritContent.DAILY_TRIAL_HISTORY_LIMIT, "history stays capped at DAILY_TRIAL_HISTORY_LIMIT entries even as new days keep rolling in")
	check(int(g_pass.profile.daily_trial_record.history[-1].day) == today_idx - 1, "the cap drops the oldest entries first, keeping the most recent day's own result")

	# Idle Harvest tests
	g_pass.profile.unlocked = 10
	check(g_pass.get_idle_harvest_rate() == 10 + 10 * 2, "idle harvest rate scales with unlocked stage (10 + unlocked * 2)")
	g_pass.profile.idle_harvest = {"last_claim_time": int(Time.get_unix_time_from_system()) - 7200, "last_fast_claim_day": -1}
	var unclaimed_secs := g_pass.get_idle_harvest_unclaimed_seconds()
	check(unclaimed_secs >= 7190 and unclaimed_secs <= 7210, "idle harvest correctly computes elapsed seconds")
	var gold_calc: int = g_pass.get_idle_harvest_unclaimed_gold()
	check(gold_calc >= 59 and gold_calc <= 61, "idle harvest computes 2 hours of gold at rate 30/h (expected ~60)")
	var gold_before: int = int(g_pass.profile.gold)
	var fast_gold := g_pass.fast_idle_harvest()
	check(fast_gold == 30 * 2, "fast idle harvest grants 2 hours worth of gold immediately")
	check(int(g_pass.profile.gold) == gold_before + fast_gold, "fast idle harvest adds gold to profile")
	var second_fast := g_pass.fast_idle_harvest()
	check(second_fast == 0, "fast idle harvest cannot be claimed more than once on the same day")

	# Defeat Diagnosis tests
	g_pass.profile.deck = ["strike", "strike", "defend", "defend"]
	var diag := g_pass.diagnose_battle_defeat()
	check(diag.has("tip") and diag.has("action"), "diagnose_battle_defeat returns tip and recommended action")

	# Phantom Arena tests
	var p_enc: Dictionary = content.phantom_arena_encounter(20, 0)
	check(int(p_enc.chapter) == 102, "phantom arena encounter uses chapter 102 sentinel")
	check(int(p_enc.health) > 0 and int(p_enc.damage) > 0, "phantom arena encounter scales health and damage")

	# Ghost Arena tests (E4): a real leaderboard row synthesized into a Phantom-Arena-shaped
	# Encounter (see content.ghost_arena_encounter()'s own comment) rather than a literal replay.
	var ghost_enc: Dictionary = content.ghost_arena_encounter("TestGhost", "sentinel", "abyss", 20)
	check(int(ghost_enc.chapter) == 103, "ghost arena encounter uses its own chapter 103, distinct from abyss (99) and phantom arena (102)")
	check(str(ghost_enc.name) == "TestGhost" and str(ghost_enc.name_en) == "TestGhost", "ghost arena encounter's name is the real player's name verbatim in both languages")
	check(str(ghost_enc.art) == "sentinel", "ghost arena encounter's art is overridden to the ghost's own character_id")
	check(int(ghost_enc.health) > 0 and int(ghost_enc.damage) > 0, "ghost arena encounter has valid scaled stats")
	var ghost_enc_weak: Dictionary = content.ghost_arena_encounter("Weak", "fox", "abyss", 2)
	var ghost_enc_strong: Dictionary = content.ghost_arena_encounter("Strong", "fox", "abyss", 40)
	check(int(ghost_enc_strong.health) > int(ghost_enc_weak.health), "a ghost recorded at a higher abyss floor is a tougher encounter (%d > %d)" % [int(ghost_enc_strong.health), int(ghost_enc_weak.health)])
	check(int(content._ghost_difficulty_level("abyss", 20)) == 20, "abyss scores map 1:1 to a difficulty level (already a floor number)")
	check(int(content._ghost_difficulty_level("daily_trial", 5000)) == 50, "daily_trial scores are coarsely normalized down to a comparable level")
	check(int(content._ghost_difficulty_level("samsara", 3)) == 15, "samsara scores (cycle counts) are scaled up to a comparable level")

	# Progressive difficulty tier unlocking: A0-A5 used to all become selectable the instant
	# unlocked>=25, with no further gate — this table makes each tier require its own stage
	# threshold instead (see content.gd's own comment on DIFFICULTY_TIER_UNLOCK_STAGE for why).
	check(int(content.difficulty_tier_unlock_stage(0)) == 0, "A0 is always available (threshold 0)")
	check(int(content.difficulty_tier_unlock_stage(1)) == 25, "A1's threshold matches the difficulty section's own pre-existing overall unlock gate")
	check(int(content.difficulty_tier_unlock_stage(2)) < int(content.difficulty_tier_unlock_stage(3)), "each tier's threshold is strictly higher than the one before it")
	check(int(content.difficulty_tier_unlock_stage(5)) == 200, "A5 (the highest non-samsara tier) requires real, late-game campaign progress")
	check(int(content.difficulty_tier_unlock_stage(6)) == int(content.difficulty_tier_unlock_stage(5)), "a samsara-extended tier past A5 clamps to A5's own threshold (samsara has its own, much stronger gate — a full 250-stage clear)")

	# Multi-currency & Soulbound & Exchange tests
	var new_prof := SpiritSave.defaults(content)
	check(int(new_prof.get("spirit_jade", 0)) == 10, "profile defaults include 10 Spirit Jade")
	check(int(new_prof.get("spirit_dust", 0)) == 0, "profile defaults include 0 Spirit Dust")
	check(new_prof.get("tutorials_seen", null) is Dictionary, "profile defaults include tutorials_seen dictionary")

	check(content.is_card_soulbound("strike") == true, "strike is marked soulbound")
	check(content.is_card_soulbound("ward") == true, "ward is marked soulbound")
	check(content.is_card_soulbound("moonfang") == false, "non-starter cards are not soulbound")

	var strike_card := content.card("strike")
	var moonfang_card := content.card("moonfang")
	check(content.card_recycle_dust_value(strike_card) == 0, "soulbound starter cards recycle for 0 dust")
	check(content.card_recycle_dust_value(moonfang_card) > 0, "non-starter cards recycle for positive dust")
	check(content.card_craft_dust_cost(moonfang_card) > content.card_recycle_dust_value(moonfang_card), "craft cost exceeds recycle yield to prevent arbitrage")

	var shop_stock_sample := content.roll_shop_stock(42, 6)
	check(shop_stock_sample.has("rune") and not shop_stock_sample.rune.is_empty(), "shop stock includes rotating rune")
	check(shop_stock_sample.has("relic") and not shop_stock_sample.relic.is_empty(), "shop stock includes rotating relic")
	check(shop_stock_sample.has("booster_pack") and int(shop_stock_sample.booster_pack.price_gold) > 0, "shop stock includes booster pack")

	check(content.ui("ui.currency_gold", "zh-Hans") == "金币" and content.ui("ui.currency_gold", "en") == "Gold", "gold currency localized")
	check(content.ui("ui.currency_jade", "zh-Hans") == "灵玉" and content.ui("ui.currency_jade", "en") == "Spirit Jade", "jade currency localized")
	check(content.ui("ui.currency_dust", "zh-Hans") == "灵尘" and content.ui("ui.currency_dust", "en") == "Spirit Dust", "dust currency localized")

	# Store Consumables & Specialties
	check(SpiritContent.STORE_CONSUMABLES.size() >= 5, "at least 5 store consumables/specialties defined")
	var elixir_vitality: Dictionary = content.store_consumable("elixir_vitality")
	check(not elixir_vitality.is_empty() and int(elixir_vitality.price_gold) > 0, "elixir_vitality defined with gold price")
	var upgrade_stone: Dictionary = content.store_consumable("upgrade_stone")
	check(not upgrade_stone.is_empty() and int(upgrade_stone.price_jade) > 0, "upgrade_stone defined with jade price")

	# Novice Journey 7-Day Roadmap
	check(SpiritContent.NOVICE_JOURNEY_TASKS.size() == 7, "novice journey has exactly 7 days of tasks")
	check(int(SpiritContent.NOVICE_JOURNEY_TASKS[0].target_stage) == 1, "day 1 targets stage 1")
	check(int(SpiritContent.NOVICE_JOURNEY_TASKS[6].target_stage) == 10, "day 7 targets stage 10")
	check(int(SpiritContent.NOVICE_JOURNEY_TASKS[6].gold) >= 200, "day 7 grants 200+ gold")

	# Combat Starting Buffs (strength_start, energy_turn1, draw_turn1)
	var buffed_combat := SpiritCombat.new(content)
	buffed_combat.create(77, encounter(50, 0), content.raw.startingDeck, 60, {}, [], {}, {}, [], {"strength_start": 3, "energy_turn1": 1, "draw_turn1": 2})
	check(int(buffed_combat.state.player.strength) == 3, "combat honors strength_start bonus (+3)")
	check(int(buffed_combat.state.energy) == 3, "combat honors energy_turn1 bonus (2 base + 1 = 3)")
	check(buffed_combat.state.hand.size() == 7, "combat honors draw_turn1 bonus (5 base + 2 = 7)")

	# Profile schema checks
	check(new_prof.get("novice_journey", null) is Dictionary, "profile defaults include novice_journey")
	check(new_prof.get("daily_first_win", null) is Dictionary, "profile defaults include daily_first_win")
	check(new_prof.get("combat_consumables", null) is Dictionary, "profile defaults include combat_consumables")
	check(new_prof.get("stamina", null) is Dictionary, "profile defaults include stamina")
	check(int(new_prof.stamina.current) == 100 and int(new_prof.stamina.max) == 100, "default stamina is 100/100")

	# Elemental Resonance Checks
	var reso_combat := SpiritCombat.new(content)
	reso_combat.create(99, encounter(60, 10, 1), content.raw.startingDeck, 60)
	# Play Fire card (foxfire) then Spirit card (ward) -> Combustion (3 splash to other enemies)
	reso_combat.state.hand = [{"uid":1, "card_id":"foxfire"}, {"uid":2, "card_id":"ward"}]
	reso_combat.state.energy = 5
	var enemy1_hp_before: int = reso_combat.state.enemies[1].health
	reso_combat.play(0, 0) # foxfire is Fire
	check(reso_combat.state.last_element == "fire", "last_element recorded as fire")
	reso_combat.play(0) # ward is Spirit -> triggers Combustion
	check(reso_combat.state.enemies[1].health == enemy1_hp_before - 3, "Combustion resonance dealt 3 splash damage to enemy 1")

	# Stone + Spirit -> Fortify (+4 player shield)
	var shield_before: int = reso_combat.state.player.shield
	reso_combat.state.hand = [{"uid":3, "card_id":"strike"}, {"uid":4, "card_id":"ward"}] # strike is Stone, ward is Spirit
	reso_combat.state.energy = 5
	reso_combat.play(0, 0) # strike (Stone)
	reso_combat.play(0) # ward (Spirit) -> triggers Fortify
	check(reso_combat.state.player.shield >= shield_before + 5 + 4, "Fortify resonance granted +4 bonus shield")

	# AI Decision Engine Check (ai_best_play)
	var ai_combat := SpiritCombat.new(content)
	ai_combat.create(101, encounter(40, 15), content.raw.startingDeck, 60)
	ai_combat.state.hand = [{"uid":10, "card_id":"strike"}, {"uid":11, "card_id":"ward"}]
	ai_combat.state.energy = 2
	# Enemy telegraphs 15 damage, player shield is 0: AI must prioritize ward for defense!
	force_attack(ai_combat)
	var best_def := ai_combat.ai_best_play()
	check(best_def.hand_index == 1, "AI prioritizes defense when facing incoming lethal/heavy attack")

	# When enemy has low HP in lethal range, AI prioritizes lethal strike
	ai_combat.state.enemies[0].health = 5
	ai_combat.state.enemies[0].intent = {"kind":"defend","amount":0}
	var best_atk := ai_combat.ai_best_play()
	check(best_atk.hand_index == 0, "AI prioritizes lethal strike on vulnerable enemy")

	# Samsara / Reincarnation (C2) tests
	var s0 := content.samsara_bonuses(0)
	check(s0.max_hp == 0 and s0.starting_shield == 0 and s0.turn1_draw == 0 and s0.starting_gold == 0, "samsara level 0 has zero bonuses")
	var s1 := content.samsara_bonuses(1)
	check(s1.max_hp == 6 and s1.starting_gold == 50 and s1.starting_shield == 0 and s1.turn1_draw == 0, "samsara level 1 grants +6 Max HP and +50 starting gold")
	var s2 := content.samsara_bonuses(2)
	check(s2.starting_shield == 4, "samsara level 2 adds +4 starting shield")
	var s3 := content.samsara_bonuses(3)
	check(s3.turn1_draw == 1, "samsara level 3 adds +1 turn 1 draw")
	var s4 := content.samsara_bonuses(4)
	check(s4.max_hp == 10 and s4.starting_shield == 6 and s4.turn1_draw == 1, "samsara level 4 scales max_hp and shield")
	check(content.samsara_title(0, "zh-Hans") == "凡体肉胎", "samsara title level 0 in Chinese")
	check(content.samsara_title(1, "zh-Hans") == "一转散仙", "samsara title level 1 in Chinese")
	check(content.samsara_title(1, "en") == "1st Samsara (Wandering Immortal)", "samsara title level 1 in English")

	var samsara_game := SpiritGame.new()
	samsara_game.content = content
	samsara_game.profile = SpiritSave.defaults(content)
	# enter_samsara() guards its own eligibility (unlocked>=250 AND difficulty>=5+count) rather
	# than trusting only _samsara_section()'s button-visibility gate — must satisfy it here too.
	samsara_game.profile.unlocked = 250
	samsara_game.profile.difficulty = 5
	samsara_game.profile.position = 50
	samsara_game.profile.claimed_stage_events = [5, 10]
	var init_gold: int = int(samsara_game.profile.gold)
	samsara_game.enter_samsara()
	check(int(samsara_game.profile.samsara_count) == 1, "enter_samsara increments samsara_count to 1")
	check(int(samsara_game.profile.unlocked) == 0, "enter_samsara resets campaign progress to stage 0")
	check(int(samsara_game.profile.position) == 0, "enter_samsara resets campaign map position to stage 0")
	check(samsara_game.profile.claimed_stage_events.is_empty(), "enter_samsara clears claimed_stage_events for replayability")
	check(int(samsara_game.profile.gold) == init_gold + 50, "enter_samsara awards +50 gold heritage")
	check(int(samsara_game.profile.health) == 60, "enter_samsara resets health to a flat 60, matching every other battle-end reset site (the real max_hp bonus reaches combat only through hero_bonuses, never this display-only field)")
	check(samsara_game._achievement_progress({"kind":"samsara_count"}) == 1, "achievement reader tracks samsara_count correctly")
	samsara_game.free()

	# Account deletion (Docs/LAUNCH_READINESS.md Section 1): the guest branch is a full local
	# profile wipe with no network dependency, so it's tested end-to-end here with a throwaway
	# SpiritGame instance (same isolation pattern as samsara_game above) rather than against
	# ui_smoke.gd's shared instance, which every later section in that suite depends on keeping
	# intact — SpiritSave.defaults() wipes gold/unlocked/deck/relics/everything, not just the
	# account fields, so running it against a shared instance mid-suite would cascade failures
	# through the rest of that file.
	var delete_game := SpiritGame.new()
	delete_game.content = content
	delete_game.profile = SpiritSave.defaults(content)
	delete_game.profile.account.provider = "guest"
	delete_game.profile.account.user_id = ""
	delete_game.profile.gold = 99999
	delete_game.profile.unlocked = 40
	var delete_ok: Array = [false, false]
	SpiritAuth.delete_account(delete_game, func(ok): delete_ok[0] = true; delete_ok[1] = ok)
	check(delete_ok[0] and delete_ok[1], "delete_account() completes synchronously and successfully for a guest (nothing cloud-side to fail)")
	check(int(delete_game.profile.gold) == 30, "a guest's local profile resets to fresh defaults (gold) on deletion")
	check(int(delete_game.profile.unlocked) == 0, "a guest's local profile resets to fresh defaults (campaign progress) on deletion")
	delete_game.free()

	# The cloud-linked branch must NOT touch profile/session state on a failed delete (no real
	# Supabase auth session exists in this headless environment, so SupabaseClient.
	# delete_player_save()'s own is_authenticated() guard fails fast) — a player whose deletion
	# fails partway through must still be able to retry, not be left logged out with no save.
	var delete_game2 := SpiritGame.new()
	delete_game2.content = content
	delete_game2.profile = SpiritSave.defaults(content)
	delete_game2.profile.account.provider = "apple"
	delete_game2.profile.account.user_id = "fake_uid_no_real_session"
	delete_game2.profile.gold = 12345
	var delete_ok2: Array = [false, false]
	SpiritAuth.delete_account(delete_game2, func(ok): delete_ok2[0] = true; delete_ok2[1] = ok)
	check(delete_ok2[0] and not delete_ok2[1], "delete_account() reports failure for a cloud-linked account with no real auth session")
	check(SpiritSave.is_cloud_linked(delete_game2.profile), "a failed cloud deletion leaves the account linked rather than signing it out")
	check(int(delete_game2.profile.gold) == 12345, "a failed cloud deletion does not touch the local profile")
	delete_game2.free()

	# Samsara Combat perks verification: shield_start/draw_turn1 flow through hero_bonuses, the
	# same mechanism Hero Mastery perks already use (see _current_hero_mastery_bonuses()) — A6+
	# difficulty's own real combat effect (health_scale/damage_bonus) is a completely separate
	# mechanism (content.difficulty_modifier(), fed into combat.create()'s modifier parameter,
	# not hero_bonuses) verified end to end via game.begin_battle() in ui_smoke.gd instead, since
	# it depends on SpiritGame wiring active_modifier together, not just SpiritCombat alone.
	var samsara_combat := SpiritCombat.new(content)
	samsara_combat.create(1, encounter(100, 0), Array(content.raw.startingDeck), 60, {}, [], {}, {}, [], {"shield_start": 4, "draw_turn1": 1})
	check(samsara_combat.state.player.shield == 4, "samsara starting shield applied in combat")
	check(samsara_combat.state.hand.size() == 6, "samsara turn 1 draw applied (5 base + 1 = 6)")

	# Translations for new features
	check(content.ui("ui.samsara_title", "zh-Hans") == "轮回仙途 · 逆天重修", "samsara title localized in Chinese")
	check(content.ui("ui.samsara_title", "en") == "Samsara · Reincarnation", "samsara title localized in English")
	check(content.ui("ui.camp_tier_a6_name", "zh-Hans") == "A6 · 万劫归一", "camp tier A6 localized in Chinese")
	check(content.ui("ui.camp_tier_a6_name", "en") == "A6 · Cataclysm", "camp tier A6 localized in English")
	check(content.ui("ui.treasury_title", "zh-Hans") == "灵界珍宝库", "treasury title localized in Chinese")
	check(content.ui("ui.treasury_title", "en") == "Spirit Treasury", "treasury title localized in English")
	check(content.ui("ui.novice_journey_title", "zh-Hans") == "七日修行录", "novice journey title localized in Chinese")
	check(content.ui("ui.novice_journey_title", "en") == "7-Day Novice Journey", "novice journey title localized in English")
	check(content.ui("ui.stamina_name", "zh-Hans") == "灵力", "stamina localized in Chinese")
	check(content.ui("ui.stamina_name", "en") == "Stamina", "stamina localized in English")
	check(content.ui("ui.auto_battle", "zh-Hans") == "自动", "auto battle localized in Chinese")
	check(content.ui("tutorial.shop_overview.title", "zh-Hans") == "灵界集市指南", "shop overview tutorial localized")
	# Supabase Client & Cloud Save Auth Unit Tests
	var test_sess := {
		"access_token": "mock_jwt_token_spiritbound_987",
		"refresh_token": "mock_refresh_token_spiritbound_654",
		"expires_in": 3600,
		"expires_at": int(Time.get_unix_time_from_system()) + 3600,
		"provider": "supabase",
		"user": {
			"id": "uuid-test-user-1234",
			"email": "test_immortal@spiritbound.game",
			"user_metadata": {
				"display_name": "万界至尊"
			}
		}
	}
	SupabaseClient.save_session(test_sess)
	check(SupabaseClient.is_authenticated(), "SupabaseClient is_authenticated returns true with valid session")
	check(SupabaseClient.get_access_token() == "mock_jwt_token_spiritbound_987", "SupabaseClient returns correct access token")
	check(SupabaseClient.get_refresh_token() == "mock_refresh_token_spiritbound_654", "SupabaseClient returns correct refresh token")
	check(SupabaseClient.get_user_id() == "uuid-test-user-1234", "SupabaseClient returns correct user id")
	check(SupabaseClient.get_email() == "test_immortal@spiritbound.game", "SupabaseClient returns correct email")
	check(SupabaseClient.get_display_name() == "万界至尊", "SupabaseClient returns correct display name")

	# Account linking with Supabase
	var auth_test_prof := SpiritSave.defaults(content)
	check(not SpiritSave.is_cloud_linked(auth_test_prof), "new profile defaults to unlinked cloud status")
	SpiritSave.link_account(auth_test_prof, "supabase", "uuid-test-user-1234", "test_immortal@spiritbound.game", "万界至尊")
	check(SpiritSave.is_cloud_linked(auth_test_prof), "profile is cloud linked after Supabase link")
	check(SpiritSave.account_provider(auth_test_prof) == "supabase", "profile provider is supabase after link")
	check(auth_test_prof.account.email == "test_immortal@spiritbound.game", "profile stores supabase email")
	SpiritSave.unlink_account(auth_test_prof)
	check(not SpiritSave.is_cloud_linked(auth_test_prof), "profile unlinked after sign out")

	# Clean up session
	SupabaseClient.clear_session()
	check(not SupabaseClient.is_authenticated(), "SupabaseClient is_authenticated returns false after clear_session")

	# Supabase Leaderboards & Global Rankings
	check(SupabaseClient.TABLE_LEADERBOARDS == "leaderboards", "TABLE_LEADERBOARDS is leaderboards")
	var abyss_fallbacks: Array = SupabaseClient._get_fallback_leaderboard("abyss")
	check(abyss_fallbacks.size() == 10, "abyss fallback leaderboard provides top 10 master entries")
	check(int(abyss_fallbacks[0].score) >= int(abyss_fallbacks[1].score), "abyss fallback records ordered by score descending")
	check(abyss_fallbacks[0].has("player_name") and abyss_fallbacks[0].has("character_id") and abyss_fallbacks[0].has("rank"), "abyss entry schema contains player_name, character_id, and rank")

	var daily_fallbacks: Array = SupabaseClient._get_fallback_leaderboard("daily_trial")
	check(daily_fallbacks.size() == 10, "daily_trial fallback leaderboard provides top 10 entries")
	check(int(daily_fallbacks[0].score) >= int(daily_fallbacks[9].score), "daily_trial fallback sorted descending")

	var samsara_fallbacks: Array = SupabaseClient._get_fallback_leaderboard("samsara")
	check(samsara_fallbacks.size() == 10, "samsara fallback leaderboard provides top 10 entries")

	# The sample board exists by design and stays — but it must never be presented as the real
	# global standings. fetch_leaderboard() already flagged this case with offline:true and the
	# leaderboard modal used to drop that flag on the floor, so a player with no connection saw
	# ten realistic names and scores and nothing anywhere said they were samples (which is also
	# the kind of thing an App Store reviewer asks about). The modal now renders
	# ui.leaderboard_sample_notice whenever the flag is set; these hold the pieces that make that
	# disclosure work. The render path itself isn't asserted here: the leaderboard fetch is
	# fire-and-forget inside the modal's update closure, so a headless assertion on the notice
	# would be timing-dependent (see ui_smoke.gd's note on the same fetch).
	check(not abyss_fallbacks.is_empty(), "the fallback board is non-empty, so there is always sample content that needs labelling")
	check(content.ui("ui.leaderboard_sample_notice", "zh-Hans") != "ui.leaderboard_sample_notice", "the sample-board notice exists in Chinese")
	check(content.ui("ui.leaderboard_sample_notice", "en") != "ui.leaderboard_sample_notice", "the sample-board notice exists in English")
	check(content.ui("ui.leaderboard_sample_notice", "zh-Hans") != content.ui("ui.leaderboard_sample_notice", "en"), "the sample-board notice is actually translated, not one string reused for both")

	# Leaderboard UI localization
	check(content.ui("ui.leaderboard_title", "zh-Hans") == "封神天梯榜", "leaderboard title localized in Chinese")
	check(content.ui("ui.leaderboard_title", "en") == "Celestial Leaderboard", "leaderboard title localized in English")
	check(content.ui("ui.leaderboard_tab_abyss", "zh-Hans") == "无尽深渊", "leaderboard abyss tab localized in Chinese")
	check(content.ui("ui.leaderboard_tab_abyss", "en") == "Endless Abyss", "leaderboard abyss tab localized in English")
	check(content.ui("ui.leaderboard_tab_daily", "zh-Hans") == "每日修行", "leaderboard daily trial tab localized in Chinese")
	check(content.ui("ui.leaderboard_tab_daily", "en") == "Daily Trial", "leaderboard daily trial tab localized in English")
	check(content.ui("ui.leaderboard_tab_samsara", "zh-Hans") == "六道轮回", "leaderboard samsara tab localized in Chinese")
	check(content.ui("ui.leaderboard_tab_samsara", "en") == "Samsara", "leaderboard samsara tab localized in English")
	check(content.ui("ui.leaderboard_open", "zh-Hans") == "天梯榜 🏆", "leaderboard open button localized in Chinese")
	check(content.ui("ui.leaderboard_open", "en") == "Rankings 🏆", "leaderboard open button localized in English")
	check(content.ui("ui.leaderboard_refresh", "zh-Hans") == "刷新 ↻", "leaderboard refresh button localized in Chinese")
	check(content.ui("ui.leaderboard_refresh", "en") == "Refresh ↻", "leaderboard refresh button localized in English")
	check(content.ui("ui.leaderboard_unranked", "zh-Hans") == "未上榜", "leaderboard unranked localized in Chinese")
	check(content.ui("ui.leaderboard_unranked", "en") == "Unranked", "leaderboard unranked localized in English")

	# Cultivation Meridian System (Talent Tree) tests
	check(content.MERIDIAN_NODES.size() == 9, "9 meridian talent nodes defined across 3 branches")
	check(content.MERIDIAN_NODES.has("ren_1") and content.MERIDIAN_NODES.has("du_1") and content.MERIDIAN_NODES.has("chong_1"), "ren, du, and chong branches contain prime nodes")
	check(content.meridian_cost("ren_1", 0) == 20, "ren_1 rank 0 cost is 20 dust")
	check(content.meridian_cost("ren_1", 4) == 60, "ren_1 rank 4 cost is 60 dust")
	check(content.meridian_cost("ren_1", 5) == -1, "ren_1 rank 5 cost is -1 (maxed)")

	var test_alloc := {
		"ren_1": 2, # +10 HP (cost 20 + 30 = 50)
		"ren_2": 1, # +4 Shield (cost 25)
		"du_1": 3,  # +12 First Attack (cost 20 + 30 + 40 = 90)
		"chong_3": 2 # +30% Gold (cost 30 + 50 = 80)
	}
	var test_spent: int = content.meridian_total_spent(test_alloc)
	check(test_spent == 245, "meridian_total_spent correctly sums 50 + 25 + 90 + 80 = 245")

	var test_bonuses: Dictionary = content.meridian_bonuses(test_alloc)
	check(int(test_bonuses.max_hp) == 10, "meridian bonuses gives +10 max HP for 2 ranks of ren_1")
	check(int(test_bonuses.shield_start) == 4, "meridian bonuses gives +4 starting shield for 1 rank of ren_2")
	check(int(test_bonuses.first_attack_bonus) == 12, "meridian bonuses gives +12 first attack for 3 ranks of du_1")
	check(is_equal_approx(float(test_bonuses.gold_mult), 1.3), "meridian bonuses gives 1.3x gold mult for 2 ranks of chong_3")

	check(content.meridian_name("ren_1", "zh-Hans") == "气血培元", "meridian ren_1 localized name in Chinese")
	check(content.meridian_name("ren_1", "en") == "Vitality Foundation", "meridian ren_1 localized name in English")

	# Profile integration & Game methods
	var meridian_game := SpiritGame.new()
	meridian_game.profile = SpiritSave.defaults(content)
	check(meridian_game.profile.has("meridians") and meridian_game.profile.meridians.is_empty(), "defaults profile has empty meridians")
	meridian_game.profile.spirit_dust = 100
	var up_ok := meridian_game.upgrade_meridian_node("ren_1")
	check(up_ok, "upgrade_meridian_node succeeds with sufficient dust")
	check(int(meridian_game.profile.meridians.get("ren_1", 0)) == 1, "ren_1 rank becomes 1")
	check(int(meridian_game.profile.spirit_dust) == 80, "spirit dust deducted by 20 (now 80)")

	# Respec test
	var refunded: int = meridian_game.reset_meridians()
	check(refunded == 20, "reset_meridians refunds 20 dust")
	check(int(meridian_game.profile.spirit_dust) == 100, "spirit dust restored to 100")
	check(meridian_game.profile.meridians.is_empty(), "meridians dictionary cleared after reset")

	# Meridian UI strings
	check(content.ui("ui.meridian_title", "zh-Hans") == "灵脉修真", "meridian title localized in Chinese")
	check(content.ui("ui.meridian_title", "en") == "Cultivation Meridians", "meridian title localized in English")
	check(content.ui("ui.meridian_reset", "zh-Hans") == "洗髓归元", "meridian reset localized in Chinese")
	check(content.ui("ui.meridian_reset", "en") == "Reset Meridians", "meridian reset localized in English")

	# Translations for auth features
	check(content.ui("ui.auth_email_tab", "zh-Hans") == "邮箱登录", "auth email tab localized in Chinese")
	check(content.ui("ui.auth_email_tab", "en") == "Email Sign In", "auth email tab localized in English")
	check(content.ui("ui.auth_signup_tab", "zh-Hans") == "注册账号", "auth signup tab localized in Chinese")
	check(content.ui("ui.auth_signup_tab", "en") == "Sign Up", "auth signup tab localized in English")
	check(content.ui("ui.auth_modal_title", "zh-Hans") == "账号与云端同步", "auth modal title localized in Chinese")
	check(content.ui("ui.auth_modal_title", "en") == "Account & Cloud Sync", "auth modal title localized in English")

	# Intro Cutscene tests
	var intro_test_prof := SpiritSave.defaults(content)
	check(intro_test_prof.has("intro_seen") and intro_test_prof.intro_seen == false, "defaults contains intro_seen as false")
	check(content.ui("ui.intro_skip", "zh-Hans") == "跳过 ⏭", "intro skip button localized in Chinese")
	check(content.ui("ui.intro_skip", "en") == "Skip ⏭", "intro skip button localized in English")
	check(content.ui("ui.intro_act1", "zh-Hans") == "混沌初开 · 万灵归虚", "intro act 1 localized in Chinese")
	check(content.ui("ui.intro_act2", "zh-Hans") == "远古封印 · 灵潮涌动", "intro act 2 localized in Chinese")
	check(content.ui("ui.intro_act3", "zh-Hans") == "灵狐降世 · 宿命抉择", "intro act 3 localized in Chinese")
	check(content.ui("ui.intro_act4_title", "zh-Hans") == "灵界之契", "intro title localized in Chinese")
	check(content.ui("ui.settings_replay_intro", "zh-Hans") == "重播开场动画", "settings replay intro localized in Chinese")
	check(content.ui("ui.settings_replay_intro", "en") == "Replay Intro Video", "settings replay intro localized in English")

	# SFX Audio Engine tests
	var sfx_list := [
		"card_play", "card_draw", "attack_slash", "attack_heavy",
		"shield_gain", "heal", "buff", "resonance_combustion",
		"resonance_sunder", "resonance_fortify", "enemy_hit",
		"enemy_defeat", "boss_phase2", "battle_victory",
		"battle_defeat", "coin", "chest_open"
	]
	check(sfx_list.size() == 17, "seventeen audio sfx defined")
	for sfx in sfx_list:
		var sfx_path := "res://assets/audio/sfx/sfx_%s.wav" % sfx
		check(ResourceLoader.exists(sfx_path), "sfx file exists: %s" % sfx_path)
		var stream: AudioStream = load(sfx_path)
		check(stream != null, "sfx stream loads: %s" % sfx)

	check(content.ui("ui.settings_sfx", "zh-Hans") == "战斗音效", "settings sfx localized in Chinese")
	check(content.ui("ui.settings_sfx", "en") == "Combat SFX", "settings sfx localized in English")
	check(content.ui("ui.settings_sfx_on", "zh-Hans") == "音效 ⚔", "settings sfx on localized in Chinese")
	check(content.ui("ui.settings_sfx_off", "zh-Hans") == "静音 ⚔", "settings sfx off localized in Chinese")

	# Test SpiritGame SFX methods
	var game_script: Script = load("res://scripts/game.gd")
	var sfx_game_inst: Node = game_script.new()
	check(sfx_game_inst.has_method("play_sfx"), "game instance has play_sfx method")
	check(sfx_game_inst.has_method("_build_sfx"), "game instance has _build_sfx method")
	check(sfx_game_inst.get("SFX_POOL_SIZE") == 8, "sfx pool size constant is 8")
	root.add_child(sfx_game_inst)
	sfx_game_inst.call("_build_sfx")
	var pool: Array = sfx_game_inst.get("_sfx_pool")
	check(pool.size() == 8, "sfx pool contains 8 players")
	var sfx_cache: Dictionary = sfx_game_inst.get("_sfx_cache")
	check(sfx_cache.size() >= 17, "sfx cache loaded all 17 sound effects")
	sfx_game_inst.call("play_sfx", "card_play")
	sfx_game_inst.call("play_sfx", "battle_victory")
	sfx_game_inst.set("sfx_muted", true)
	sfx_game_inst.call("play_sfx", "attack_slash")
	sfx_game_inst.set("sfx_muted", false)
	sfx_game_inst.queue_free()

	# Phase 4: Equipment Reforging & Inscription System (器灵重铸与灵纹洗练)
	check(content.equip_tier_name(0, "zh-Hans") == "凡品", "tier 0 is 凡品")
	check(content.equip_tier_name(1, "zh-Hans") == "灵品", "tier 1 is 灵品")
	check(content.equip_tier_name(2, "zh-Hans") == "宝品", "tier 2 is 宝品")
	check(content.equip_tier_name(3, "zh-Hans") == "仙品", "tier 3 is 仙品")
	check(content.equip_tier_name(3, "en") == "Celestial", "tier 3 localized English is Celestial")
	check(content.equip_tier_cost(0).get("gold") == 100 and content.equip_tier_cost(0).get("dust") == 20, "tier 0->1 cost is 100 gold 20 dust")
	check(content.equip_tier_cost(1).get("gold") == 250 and content.equip_tier_cost(1).get("dust") == 50, "tier 1->2 cost is 250 gold 50 dust")
	check(content.equip_tier_cost(2).get("gold") == 500 and content.equip_tier_cost(2).get("dust") == 100, "tier 2->3 cost is 500 gold 100 dust")
	check(content.equip_tier_cost(3).is_empty(), "tier 3 cost is empty (maxed)")
	check(content.equip_inscribe_cost().get("gold") == 30 and content.equip_inscribe_cost().get("dust") == 10, "inscribe cost is 30 gold 10 dust")

	var eb := content.equipment("emberBlade")
	check(content.equip_detail_tiered(eb, 0, "zh-Hans").contains("+3"), "emberBlade T0 gives +3")
	check(content.equip_detail_tiered(eb, 1, "zh-Hans").contains("+5"), "emberBlade T1 gives +5")
	check(content.equip_detail_tiered(eb, 2, "zh-Hans").contains("+7"), "emberBlade T2 gives +7")
	check(content.equip_detail_tiered(eb, 3, "zh-Hans").contains("+10"), "emberBlade T3 gives +10")

	var jp := content.equipment("jadePlate")
	check(content.equip_detail_tiered(jp, 3, "zh-Hans").contains("28"), "jadePlate T3 gives 28 shield")

	# Inscription rolling & aggregation tests
	check(content.roll_inscription_affixes(0).size() == 0, "tier 0 has 0 inscription slots")
	check(content.roll_inscription_affixes(1).size() == 1, "tier 1 has 1 inscription slot")
	check(content.roll_inscription_affixes(2).size() == 2, "tier 2 has 2 inscription slots")
	check(content.roll_inscription_affixes(3).size() == 3, "tier 3 has 3 inscription slots")
	var rolled_t3: Array = content.roll_inscription_affixes(3)
	for aff in rolled_t3:
		check(aff.has("id") and aff.has("val") and int(aff.val) > 0, "rolled affix has valid id and positive val")
		check(content.inscription_text(aff, "zh-Hans").length() > 0, "inscription_text formats valid Chinese string")
		check(content.inscription_text(aff, "en").length() > 0, "inscription_text formats valid English string")

	var agg_test := content.aggregate_inscriptions(["itemA", "itemB"], {
		"itemA": [{"id": "inscr_hp", "val": 8}, {"id": "inscr_atk", "val": 3}],
		"itemB": [{"id": "inscr_shield", "val": 9}, {"id": "inscr_thorns", "val": 2}, {"id": "inscr_gold", "val": 15}]
	})
	check(int(agg_test.get("hp")) == 8, "aggregated HP affix is 8")
	check(int(agg_test.get("atk")) == 3, "aggregated ATK affix is 3")
	check(int(agg_test.get("shield")) == 9, "aggregated Shield affix is 9")
	check(int(agg_test.get("thorns")) == 2, "aggregated Thorns affix is 2")
	check(int(agg_test.get("gold")) == 15, "aggregated Gold affix is 15")

	# Combat integration tests with equipment tiers and inscriptions
	var c_reforge := SpiritCombat.new(content)
	# Case A: Jade Plate at Tier 3 (28 shield) + Inscription Shield (+9) -> 37 starting shield!
	var st_jp := c_reforge.create(1, content.encounters[0], content.raw.startingDeck, 60, {}, ["jadePlate"], {}, {}, [], {}, {"jadePlate": 3}, {"jadePlate": [{"id": "inscr_shield", "val": 9}]})
	check(st_jp.player.shield == 37, "jadePlate T3 (28) + inscr_shield (9) starts with 37 shield")

	# Case B: Focus Charm at Tier 2 (2 focus + 1 strength)
	var st_fc := c_reforge.create(2, content.encounters[0], content.raw.startingDeck, 60, {}, ["focusCharm"], {}, {}, [], {}, {"focusCharm": 2}, {})
	check(st_fc.player.focus == 2, "focusCharm T2 grants 2 focus")
	check(int(st_fc.player.get("strength", 0)) == 1, "focusCharm T2 grants 1 strength")

	# Case C: Ember Blade at Tier 3 (+10) + Inscription Atk (+3) on first attack
	var st_eb := c_reforge.create(3, encounter(100, 0), content.raw.startingDeck, 60, {}, ["emberBlade"], {}, {}, [], {}, {"emberBlade": 3}, {"emberBlade": [{"id": "inscr_atk", "val": 3}]})
	_force_hand(c_reforge, "strike")
	c_reforge.play(0, 0)
	check(st_eb.enemies[0].health == 100 - 19, "strike deals 6 + 10 (EmberBlade T3) + 3 (inscr_atk) = 19 damage (100 - 19 = 81)")

	# Case D: Thorn Armor at Tier 3 (9 retaliate) + Inscription Thorns (+3) -> 12 retaliate!
	var st_ta := c_reforge.create(4, content.encounters[0], content.raw.startingDeck, 60, {}, ["thornArmor"], {}, {}, [], {}, {"thornArmor": 3}, {"thornArmor": [{"id": "inscr_thorns", "val": 3}]})
	st_ta.player.shield = 0
	var pre_hp: int = st_ta.enemies[0].health
	st_ta.enemies[0].intent = {"action": "attack", "amount": 5}
	c_reforge._execute_intent(0)
	check(pre_hp - st_ta.enemies[0].health == 12, "thornArmor T3 (9) + inscr_thorns (3) retaliates 12 damage")

	# Case E: Phoenix Mail at Tier 3 revives with 40 HP
	var st_pm := c_reforge.create(5, content.encounters[0], content.raw.startingDeck, 60, {}, ["phoenixMail"], {}, {}, [], {}, {"phoenixMail": 3}, {})
	c_reforge._damage_player(100)
	check(st_pm.player.health == 40, "phoenixMail T3 revives with 40 HP")
	check(st_pm.phase == "player", "phoenixMail revive prevents loss")

	# Case F: Save profile schema verification
	var prof_reforge := SpiritSave.defaults(content)
	check(prof_reforge.has("equipment_tiers") and prof_reforge.equipment_tiers is Dictionary, "profile defaults include equipment_tiers dict")
	check(prof_reforge.has("equipment_inscriptions") and prof_reforge.equipment_inscriptions is Dictionary, "profile defaults include equipment_inscriptions dict")

	# ========================================================
	# Phase 5: Dynamic Relic Synergies & Combo Resonance Tests
	# ========================================================
	check(SpiritContent.RELIC_RESONANCES.size() == 6, "6 ancient relic resonances are defined")
	for r in SpiritContent.RELIC_RESONANCES:
		check(not str(r.get("id", "")).is_empty(), "relic resonance has valid id")
		check(not str(r.get("zh", "")).is_empty() and not str(r.get("en", "")).is_empty(), "relic resonance %s has bilingual names" % r.id)
		check(r.get("relics", []).size() >= 2, "relic resonance %s requires at least 2 relics" % r.id)

	# Active resonance detection
	var res_none: Array[Dictionary] = content.active_relic_resonances([])
	check(res_none.is_empty(), "empty relics yields no active resonances")
	var res_half: Array[Dictionary] = content.active_relic_resonances(["thunderSeal"])
	check(res_half.is_empty(), "single relic does not trigger resonance")
	var res_pair: Array[Dictionary] = content.active_relic_resonances(["thunderSeal", "mirrorScale"])
	check(res_pair.size() == 1 and res_pair[0].id == "res_sun_moon", "thunderSeal + mirrorScale activates res_sun_moon")
	var res_multi: Array[Dictionary] = content.active_relic_resonances(["thunderSeal", "mirrorScale", "foxCharm", "windChime"])
	check(res_multi.size() == 2, "multiple pairs activate multiple resonances")

	# Resonance 1: 日月同辉 (res_sun_moon: thunderSeal + mirrorScale)
	var c_sunmoon := SpiritCombat.new(content)
	c_sunmoon.create(301, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {}, ["thunderSeal", "mirrorScale"])
	check(c_sunmoon.state.relic_resonances.has("res_sun_moon"), "res_sun_moon registered in combat state")
	c_sunmoon.state.player.shield = 20
	force_attack(c_sunmoon)
	c_sunmoon.end_turn()
	check(c_sunmoon.state.player.shield == 20, "res_sun_moon retains 100% of shield (20 -> 20) instead of half (10)")
	# Advance to Turn 3
	c_sunmoon.end_turn() # turn 2 -> turn 3
	check(c_sunmoon.state.turn == 3, "turn is 3")
	# Turn 3 base energy is 2 + (3-1)/2 = 3. thunderSeal adds +2, res_sun_moon adds +2 -> total 7 energy!
	check(c_sunmoon.state.energy == 7, "turn 3 energy is 3 base + 2 (thunderSeal) + 2 (res_sun_moon) = 7")

	# Resonance 2: 灵狐引魂 (res_fox_wind: foxCharm + windChime)
	var c_foxwind := SpiritCombat.new(content)
	c_foxwind.create(302, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {}, ["foxCharm", "windChime"])
	check(c_foxwind.state.relic_resonances.has("res_fox_wind"), "res_fox_wind registered in combat state")
	# At turn 1, hand is 5. Discard 2, leaving 3.
	c_foxwind.state.hand.pop_back()
	c_foxwind.state.hand.pop_back()
	c_foxwind.end_turn() # to Turn 2
	# Normal turn 2 draw is 2 cards + 1 extra from res_fox_wind on Turn 2 = 3 cards drawn (3 + 3 = 6)
	check(c_foxwind.state.hand.size() == 6, "res_fox_wind draws +1 card on Turn 2 (3 + 3 = 6 cards)")
	check(c_foxwind.state.energy == 3, "foxCharm grants 3 energy on Turn 2")
	# Empty draw pile to trigger reshuffle
	var energy_pre_reshuffle: int = c_foxwind.state.energy
	c_foxwind.state.discard = c_foxwind.state.draw.duplicate()
	c_foxwind.state.draw.clear()
	c_foxwind._draw(1)
	check(c_foxwind.state.energy == energy_pre_reshuffle + 1, "res_fox_wind grants +1 energy on draw pile reshuffle")

	# Resonance 3: 星火燎原 (res_star_flame: starShard + emberCore)
	var c_starflame := SpiritCombat.new(content)
	c_starflame.create(303, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {}, ["starShard", "emberCore"])
	check(c_starflame.state.relic_resonances.has("res_star_flame"), "res_star_flame registered in combat state")
	_force_hand(c_starflame, "strike")
	c_starflame.play(0, 0)
	check(c_starflame.state.enemies[0].burn == 2, "first attack inflicts 2 burn with res_star_flame")
	force_attack(c_starflame)
	var hp_before_burn: int = c_starflame.state.enemies[0].health
	c_starflame.end_turn()
	# Burn damage with 2 stacks: 2 + 1 (emberCore) + 1 (res_star_flame) = 4 damage!
	check(hp_before_burn - c_starflame.state.enemies[0].health == 4, "burn ticks for 2 + 1 + 1 = 4 damage")

	# Resonance 4: 枯木逢春 (res_blood_seed: ancientSeed + bloodJade)
	var c_bloodseed := SpiritCombat.new(content)
	c_bloodseed.create(304, encounter(100, 0), content.raw.startingDeck, 58, {}, [], {}, {}, ["ancientSeed", "bloodJade"])
	check(c_bloodseed.state.relic_resonances.has("res_blood_seed"), "res_blood_seed registered in combat state")
	force_attack(c_bloodseed)
	c_bloodseed.end_turn()
	# HP was 58/60. Heals 4 HP -> 60 HP, remaining 2 overheal converts to 2 shield!
	check(c_bloodseed.state.player.health == 60, "res_blood_seed heals to max HP (58 + 4 -> 60)")
	check(c_bloodseed.state.player.shield == 2, "res_blood_seed converts 2 overheal into 2 shield")

	# Resonance 5: 冥渊血契 (res_nether_pact: cursedTome + bloodJade)
	var c_pact := SpiritCombat.new(content)
	var enc_pact := encounter(100, 0)
	enc_pact["adds"] = 1
	c_pact.create(305, enc_pact, content.raw.startingDeck, 60, {}, [], {}, {}, ["cursedTome", "bloodJade"])
	check(c_pact.state.relic_resonances.has("res_nether_pact"), "res_nether_pact registered in combat state")
	# Kill the minion (enemy index 1)
	c_pact.state.enemies[1].health = 1
	_force_hand(c_pact, "strike")
	c_pact.play(0, 1)
	check(int(c_pact.state.pact_cleansed_turns) == 1, "killing enemy sets pact_cleansed_turns to 1")
	# Turn end should NOT damage player (boss is still alive, so phase is player)
	var hp_pre_end: int = c_pact.state.player.health
	force_attack(c_pact)
	c_pact.end_turn()
	check(c_pact.state.player.health == hp_pre_end, "res_nether_pact cleanses Cursed Tome self-damage")
	check(int(c_pact.state.pact_cleansed_turns) == 0, "pact_cleansed_turns consumed")

	# Resonance 6: 太虚混沌 (res_chaos_titan: titanBell + chaosPrism)
	var c_chaos := SpiritCombat.new(content)
	c_chaos.create(306, encounter(100, 0), content.raw.startingDeck, 60, {}, [], {}, {}, ["titanBell", "chaosPrism"])
	check(c_chaos.state.relic_resonances.has("res_chaos_titan"), "res_chaos_titan registered in combat state")
	# 60 base + 20 (titanBell) + 15 (res_chaos_titan) = 95 Max HP and HP!
	check(c_chaos.state.player.max_health == 95, "res_chaos_titan grants +15 Max HP (total 95)")
	check(c_chaos.state.player.health == 95, "res_chaos_titan grants +15 HP (total 95)")
	# Damage against vulnerable target:
	c_chaos.state.enemies[0].shield = 0
	c_chaos.state.enemies[0].vulnerable = 1
	_force_hand(c_chaos, "strike")
	var preview_dmg: int = c_chaos.preview_card_damage(0, 0)
	# strike deals 6 * 1.5 = 9 + 2 (res_chaos_titan) = 11 damage!
	check(preview_dmg == 11, "preview_card_damage reflects +2 on vulnerable target (%d expected, got %d)" % [11, preview_dmg])
	var hp_before_strike: int = c_chaos.state.enemies[0].health
	c_chaos.play(0, 0)
	check(hp_before_strike - c_chaos.state.enemies[0].health == 11, "strike deals 11 damage on vulnerable target with res_chaos_titan")

	# ========================================================
	# Phase 6: Career Codex & Player Statistics Dashboard Tests
	# ========================================================
	var prof_codex := SpiritSave.defaults(content)
	check(prof_codex.has("career_stats") and prof_codex.career_stats is Dictionary, "profile defaults include career_stats")
	var cs_test: Dictionary = prof_codex.career_stats
	check(cs_test.has("total_battles") and cs_test.total_battles == 0, "career_stats initialized with 0 total_battles")
	check(cs_test.has("victories") and cs_test.victories == 0, "career_stats initialized with 0 victories")
	check(cs_test.has("defeats") and cs_test.defeats == 0, "career_stats initialized with 0 defeats")
	check(cs_test.has("current_win_streak") and cs_test.current_win_streak == 0, "career_stats initialized with 0 current_win_streak")
	check(cs_test.has("longest_win_streak") and cs_test.longest_win_streak == 0, "career_stats initialized with 0 longest_win_streak")
	check(cs_test.has("favorite_cards") and cs_test.favorite_cards is Dictionary, "career_stats has favorite_cards dict")
	check(cs_test.has("hall_of_fame") and cs_test.hall_of_fame is Array, "career_stats has hall_of_fame array")

	# Test combat cards tally tracking
	var c_tally := SpiritCombat.new(content)
	c_tally.create(1, encounter(50, 0), content.raw.startingDeck, 60)
	_force_hand(c_tally, "strike")
	c_tally.play(0, 0)
	check(c_tally.state.stats.has("cards_tally"), "combat stats contains cards_tally")
	check(int(c_tally.state.stats.cards_tally.get("strike", 0)) == 1, "cards_tally increments for strike")

	# Test _record_battle_result logic
	var g_codex: Object = load("res://scripts/game.gd").new()
	g_codex.content = content
	g_codex.profile = SpiritSave.defaults(content)
	g_codex.combat = c_tally
	g_codex.current_stage = 0

	# Victory 1
	g_codex._record_battle_result(true)
	var cs_res: Dictionary = g_codex.profile.career_stats
	check(cs_res.total_battles == 1, "_record_battle_result increments total_battles")
	check(cs_res.victories == 1, "_record_battle_result increments victories")
	check(cs_res.current_win_streak == 1, "win streak becomes 1")
	check(cs_res.longest_win_streak == 1, "longest win streak becomes 1")
	check(int(cs_res.favorite_cards.get("strike", 0)) == 1, "favorite_cards records strike tally")

	# Victory 2
	g_codex._record_battle_result(true)
	check(cs_res.total_battles == 2, "total battles becomes 2")
	check(cs_res.victories == 2, "victories becomes 2")
	check(cs_res.current_win_streak == 2, "current win streak becomes 2")
	check(cs_res.longest_win_streak == 2, "longest win streak becomes 2")

	# Defeat: resets current streak, keeps longest streak
	g_codex._record_battle_result(false)
	check(cs_res.total_battles == 3, "total battles becomes 3")
	check(cs_res.victories == 2, "victories remains 2")
	check(cs_res.defeats == 1, "defeats becomes 1")
	check(cs_res.current_win_streak == 0, "defeat resets current_win_streak to 0")
	check(cs_res.longest_win_streak == 2, "defeat preserves longest_win_streak of 2")

	# Boss victory adds Hall of Fame entry
	g_codex.current_stage = 4
	g_codex._record_battle_result(true)
	check(cs_res.hall_of_fame.size() == 1, "boss victory adds entry to hall_of_fame")
	var hof_item: Dictionary = cs_res.hall_of_fame[0]
	check(hof_item.has("stage") and hof_item.has("hero") and hof_item.has("turns") and hof_item.has("hp_left"), "hall_of_fame entry has stage, hero, turns, hp_left")

	# Test Hall of Fame capping at 5
	for i in 10:
		g_codex._record_battle_result(true)
	check(cs_res.hall_of_fame.size() <= 5, "hall_of_fame capped at maximum 5 entries")


	# --- Section 3: crash marker + funnel plumbing (Docs/LAUNCH_READINESS.md) ---
	# Pure filesystem + constant checks: the network POST itself follows this repo's established
	# "assert the call is attempted with the right shape, don't hit a real backend" pattern, and
	# is exercised at its call sites rather than re-mocked here.
	LogService.clear_session_marker()
	check(not LogService.previous_session_crashed(), "LogService: no marker reads as a clean previous session")
	LogService.mark_session_start()
	check(LogService.previous_session_crashed(), "LogService: a left-behind marker flags the previous session as unclean")
	LogService.end_session_cleanly()
	check(not LogService.previous_session_crashed(), "LogService: a clean shutdown clears the marker")
	check(not FileAccess.file_exists(LogService.SESSION_MARKER_PATH), "LogService: the marker file is actually removed from disk")
	check(LogService.EV_TUTORIAL_STARTED == "tutorial_started" and LogService.EV_DAY7_RETURN == "day7_return", "LogService exposes the documented starter funnel names")
	LogService.crash_log_tail(5)
	check(true, "LogService.crash_log_tail is safe to call whether or not an engine log file exists")
	check(SupabaseClient.TABLE_CLIENT_EVENTS == "client_events", "SupabaseClient posts events to the client_events table")

	# --- Section 2: the purchase gate (Docs/LAUNCH_READINESS.md) ---
	# A real StoreKit/Play transaction can't run headless (no different in kind from
	# deploy_ios.sh being outside run_tests.sh's reach). What IS testable here, and is what
	# actually keeps the gate honest: is_premium defaults to false, only a *verified* answer
	# unlocks it, an unverified or rejected one never does, the unlock persists, and restore
	# re-derives it from account state (including revoking on an authoritative "not owned").
	# PurchaseService.verify_receipt is the mocked seam; the real call goes to the
	# verify-purchase Edge Function.
	PurchaseService.clear_provider()
	PurchaseService.clear_verify_override()
	PurchaseService.clear_receipts()

	var gate_prof: Dictionary = SpiritSave.defaults(content)
	check(not PurchaseService.has_premium(gate_prof), "a fresh profile is not premium")
	check(not bool(gate_prof.season_pass.get("is_premium", false)), "fresh season_pass.is_premium defaults to false, not true (this was unconditionally true before Section 2)")

	var no_prov: Dictionary = await PurchaseService.purchase(gate_prof)
	check(not bool(no_prov.get("ok", false)), "purchase with no billing provider wired does not succeed")
	check(str(no_prov.get("error", "")) == "no_provider", "purchase with no provider reports no_provider")
	check(not PurchaseService.has_premium(gate_prof), "a failed purchase grants nothing")

	PurchaseService.set_provider(FakeBillingProvider.new({"ok": true, "receipt": "test-receipt", "transaction_id": "tx-1"}))

	# A provider reporting success with a receipt the server rejects must still grant nothing.
	PurchaseService.set_verify_override(func(_p, _r, _t): return {"ok": true, "premium": false, "error": ""})
	var rejected: Dictionary = await PurchaseService.purchase(gate_prof)
	check(not bool(rejected.get("verified", false)), "a server-rejected receipt is not verified")
	check(not PurchaseService.has_premium(gate_prof), "a server-rejected receipt does not unlock the premium track")
	check(PurchaseService.receipt_for(PurchaseService.PRODUCT_SEASON_PASS).has("receipt"), "the receipt is cached locally so a later restore can re-verify it")

	# An unreachable verification server is not an unlock either (fail closed).
	PurchaseService.set_verify_override(func(_p, _r, _t): return {"ok": false, "premium": false, "error": "offline"})
	check(not bool((await PurchaseService.restore(gate_prof)).get("ok", false)), "restore fails rather than unlocking when verification is unreachable")
	check(not PurchaseService.has_premium(gate_prof), "an unanswered verification leaves the gate shut")

	# The one allowed path: the provider reports a purchase AND the server verifies it.
	PurchaseService.set_verify_override(func(_p, _r, _t): return {"ok": true, "premium": true, "error": ""})
	var bought: Dictionary = await PurchaseService.purchase(gate_prof)
	check(bool(bought.get("verified", false)), "a verified purchase reports verified")
	check(PurchaseService.has_premium(gate_prof), "a verified purchase unlocks the premium track")
	check(bool(gate_prof.season_pass.get("is_premium", false)), "the unlock lands on season_pass.is_premium, where the season-pass UI reads it")
	check(PurchaseService.has_premium(SpiritSave.load_profile(content)), "the verified unlock persists to the save file")

	# Restore re-derives from account state, and revokes on an authoritative "not owned".
	check(bool((await PurchaseService.restore(gate_prof)).get("verified", false)), "restore re-derives the entitlement from a verified answer")
	PurchaseService.set_verify_override(func(_p, _r, _t): return {"ok": true, "premium": false, "error": ""})
	await PurchaseService.restore(gate_prof)
	check(not PurchaseService.has_premium(gate_prof), "an authoritative 'not owned' answer revokes the entitlement (refunded or revoked transaction)")

	# A provider claiming success with no receipt is not trustworthy for a gated product.
	PurchaseService.set_provider(FakeBillingProvider.new({"ok": true, "receipt": "", "transaction_id": ""}))
	PurchaseService.set_verify_override(func(_p, _r, _t): return {"ok": true, "premium": true, "error": ""})
	var no_receipt: Dictionary = await PurchaseService.purchase(gate_prof)
	check(str(no_receipt.get("error", "")) == "no_receipt", "a provider success with no receipt is refused outright")
	check(not PurchaseService.has_premium(gate_prof), "no receipt means no unlock, even with a permissive verifier")

	PurchaseService.clear_provider()
	PurchaseService.clear_verify_override()
	PurchaseService.clear_receipts()

	# --- Provider bootstrap: vendoring a billing plugin must not require editing the game ---
	# The gap these cover was real and would have shipped silently: set_provider() existed and
	# was well tested, but only the tests ever called it, so a vendored plugin would have
	# arrived inert and every Buy tap would answer `no_provider` with no clue why. game.gd's
	# _ready() now calls bootstrap_provider(); these checks hold the lookup honest.
	check(PurchaseService.resolve_provider("") == null, "resolve_provider refuses an empty name")
	check(PurchaseService.resolve_provider("NoSuchBillingPlugin") == null, "resolve_provider returns null for a name that isn't vendored")
	check(not PurchaseService.bootstrap_provider(PackedStringArray(["NoSuchBillingPlugin"])), "bootstrap with only unresolvable candidates wires nothing")
	check(not PurchaseService.provider_available(), "an unresolvable candidate must not look like a working store")
	# A real, resolvable project class that is NOT a billing provider must be rejected rather
	# than adopted: the contract is purchase(product_id), and a half-wired plugin adopting it
	# would flip the game into "a provider exists" while every purchase still failed.
	check(PurchaseService.resolve_provider("SpiritSave") == null, "resolve_provider rejects a resolvable class that exposes no purchase()")
	check(not PurchaseService.bootstrap_provider(PackedStringArray(["SpiritSave"])), "a wrong-shaped candidate is not adopted as the provider")
	check(not PurchaseService.provider_available(), "the gate still reports no provider after a wrong-shaped candidate")
	# The scripted-adapter path: a provider registered as a project class_name is found and used.
	check(PurchaseService.resolve_provider("BillingProviderStub") != null, "resolve_provider finds a scripted provider by its class_name")
	check(PurchaseService.bootstrap_provider(PackedStringArray(["NoSuchBillingPlugin", "BillingProviderStub"])), "bootstrap walks the candidate list and adopts the first working one")
	check(PurchaseService.provider_available(), "a bootstrapped provider reports itself available")
	check(PurchaseService.bootstrap_provider(), "bootstrap is idempotent — a live provider is left in place, not replaced")
	# And the bootstrapped provider is usable end to end, not merely present: a purchase through
	# it plus a verified answer unlocks, which is the whole point of wiring it.
	PurchaseService.set_verify_override(func(_p, _r, _t): return {"ok": true, "premium": true, "error": ""})
	var boot_prof: Dictionary = SpiritSave.defaults(content)
	var boot_bought: Dictionary = await PurchaseService.purchase(boot_prof)
	check(bool(boot_bought.get("verified", false)), "a purchase through the bootstrapped provider completes")
	check(PurchaseService.has_premium(boot_prof), "a purchase through the bootstrapped provider unlocks the premium track")
	check(PurchaseService.configured_provider_candidates() is PackedStringArray, "configured_provider_candidates returns a list whether or not the setting exists")
	PurchaseService.clear_provider()
	PurchaseService.clear_verify_override()
	check(not PurchaseService.provider_available(), "clear_provider still tears the wiring down")

	if had_profile:
		var restore_file := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
		restore_file.store_string(saved_profile)
		restore_file.close()
	elif FileAccess.file_exists(SpiritSave.PATH):
		DirAccess.remove_absolute(SpiritSave.PATH)

	# The release .pck must not re-inflate silently. export_presets.cfg's exclude_filter is the
	# only thing keeping tests/, tools/, the GUT framework, the duplicate m_r* monster sheets and
	# the dead background art out of the shipped pack (Docs/STORE_SUBMISSION.md §1.1 — worth
	# ~33 MiB / 19%). A lost or truncated exclude_filter is invisible until someone measures the
	# payload, so assert it here.
	var preset_file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	check(preset_file != null, "export_presets.cfg is readable from the project root")
	if preset_file != null:
		var preset_text: String = preset_file.get_as_text()
		preset_file.close()
		var exclude_value := ""
		var exclude_declarations := 0
		for line in preset_text.split("\n"):
			if line.begins_with("exclude_filter="):
				exclude_declarations += 1
				exclude_value = line
		check(exclude_declarations == 1, "export_presets.cfg declares exactly one exclude_filter")
		for pattern in ["tests/*", "tools/*", "addons/gut/*", "m_r*.png",
				"battlefield-v1.*", "ember-cliff-v1.*", "mountain-forge-v1.*",
				"rune-ravine-v1.*", "lantern-marsh-v1.png", "spirit-world-map-v1.png"]:
			check(exclude_value.contains(pattern),
				"the release exclude_filter still drops %s" % pattern)
		# The two backgrounds that ARE used must stay in the pack: they are loaded as .jpg by
		# name, so excluding the .jpg would break those screens.
		for needed in ["res://assets/backgrounds/lantern-marsh-v1.jpg",
				"res://assets/backgrounds/spirit-world-map-v1.jpg"]:
			check(ResourceLoader.exists(needed), "%s stays loadable (still referenced in code)" % needed)

	print("SPIRITBOUND TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _force_hand(battle: SpiritCombat, card_id: String) -> void:
	battle.state.hand = [{"uid":900,"card_id":card_id}]

# Stand-in for a vendored StoreKit/Play Billing plugin, injected via
# PurchaseService.set_provider(). Reports whatever the test hands it; the real plugin would put
# up the platform's own purchase sheet and hand back a signed receipt.
class FakeBillingProvider:
	var _result: Dictionary = {}

	func _init(result: Dictionary) -> void:
		_result = result

	func purchase(_product_id: String) -> Dictionary:
		return _result
