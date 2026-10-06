extends GutTest

var content: SpiritContent

func before_all() -> void:
	content = SpiritContent.new()

func test_pentatonic_scale_combo_notes():
	var pentatonic := [1.0, 1.125, 1.25, 1.5, 1.667, 2.0]
	assert_eq(pentatonic.size(), 6, "Pentatonic scale contains exactly 6 stepping notes")
	assert_eq(pentatonic[0], 1.0, "Root note (Gong) is 1.0")
	assert_eq(pentatonic[5], 2.0, "High octave note is 2.0")

func test_purge_card_from_deck():
	var dummy_profile := {
		"deck": ["strike", "strike", "strike", "strike", "strike", "strike",
		         "ward", "ward", "ward", "ward", "ward", "ward", "foxfire"],
		"purged_cards_count": 0
	}
	assert_eq(dummy_profile.deck.size(), 13, "Deck starts with 13 cards")
	var ok: bool = SpiritSave.purge_card_from_deck(dummy_profile, "foxfire")
	assert_true(ok, "Purging succeeds when deck size > 12")
	assert_eq(dummy_profile.deck.size(), 12, "Deck reduced to 12 cards")
	assert_false(dummy_profile.deck.has("foxfire"), "Target card removed from deck")
	assert_eq(dummy_profile.purged_cards_count, 1, "purged_cards_count incremented")

	var ok_fail: bool = SpiritSave.purge_card_from_deck(dummy_profile, "strike")
	assert_false(ok_fail, "Purging rejected when deck is at minimum 12 cards")
	assert_eq(dummy_profile.deck.size(), 12, "Deck stays at 12 cards")

func test_cultivation_realm_progression():
	var dummy_profile := {
		"cultivation_realm": 0,
		"cultivation_exp": 100,
		"health": 60
	}
	var advanced: bool = SpiritSave.advance_cultivation_realm(dummy_profile)
	assert_true(advanced, "Advancing cultivation realm succeeds from Qi Refining to Foundation")
	assert_eq(dummy_profile.cultivation_realm, 1, "Realm set to 1 (筑基)")
	assert_eq(dummy_profile.cultivation_exp, 0, "Cultivation exp reset on breakthrough")
	assert_eq(dummy_profile.health, 70, "Max health bonus awarded on breakthrough")

func test_tribulation_lightning_mechanic():
	var combat := SpiritCombat.new(content)
	var encounter := {"name": "雷劫天威", "health": 100, "damage": 0, "chapter": 888, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(42, encounter, Array(content.raw.startingDeck), 60, {}, [], {}, {"is_tribulation": true})
	assert_true(combat.state.get("is_tribulation", false), "Combat initialized with is_tribulation = true")

	# Turn 1 ends (advancing to turn 2): No lightning
	combat.end_turn()
	assert_eq(combat.state.turn, 2, "Combat progressed to turn 2")
	assert_eq(combat.state.player.health, 60, "No lightning on turn 2 transition")

	# Turn 2 ends (advancing to turn 3): Lightning strikes on turn 3!
	var before_player_hp: int = combat.state.player.health
	var before_enemy_hp: int = combat.state.enemies[0].health
	combat.end_turn()
	assert_eq(combat.state.turn, 3, "Combat progressed to turn 3")
	assert_eq(combat.state.player.health, before_player_hp - 15, "Lightning deals 15 true damage to player on turn 3 transition")
	assert_eq(combat.state.enemies[0].health, before_enemy_hp - 25, "Lightning deals 25 damage to enemy on turn 3 transition")

func test_lethal_puzzles_content_and_encounter():
	assert_true(content.LETHAL_PUZZLES.size() >= 3, "At least 3 lethal puzzles defined")
	var p1: Dictionary = content.lethal_puzzle("puzzle_01")
	assert_false(p1.is_empty(), "puzzle_01 retrieved successfully")
	assert_eq(int(p1.energy), 3, "puzzle_01 has 3 energy")
	assert_true(p1.deck.size() > 0, "puzzle_01 has predetermined deck")

	var enc: Dictionary = content.lethal_puzzle_encounter(p1)
	assert_eq(int(enc.chapter), 999, "Puzzle encounter chapter set to 999")
	assert_eq(int(enc.health), 18, "Puzzle encounter health matches specification")

func test_familiar_qi_accumulation_and_ultimate():
	var combat := SpiritCombat.new(content)
	var encounter := {"name": "试炼守卫", "health": 80, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(1, encounter, ["strike", "strike", "strike", "strike", "strike"], 60)
	assert_eq(int(combat.state.get("familiar_qi", 0)), 0, "Familiar Qi starts at 0")

	# Not full: ultimate fails
	var fail_res: Dictionary = combat.activate_familiar_ultimate()
	assert_false(fail_res.get("ok", false), "Ultimate cannot be activated before Qi is full")

	# Play 5 cards -> +100 Qi
	for i in range(5):
		combat.state.hand = [{"card_id": "strike"}]
		combat.state.energy = 5
		combat.play(0, 0)

	assert_eq(int(combat.state.get("familiar_qi", 0)), 100, "5 card plays fill Familiar Qi to 100")

	# Activate ultimate
	var succ_res: Dictionary = combat.activate_familiar_ultimate()
	assert_true(succ_res.get("ok", false), "Ultimate activates when Qi reaches 100")
	assert_eq(int(combat.state.get("familiar_qi", 0)), 0, "Familiar Qi drains to 0 after ultimate")
	assert_true(int(combat.state.player.shield) >= 14, "Familiar ultimate grants 14 shield")
	assert_true(int(combat.state.enemies[0].weak) >= 2, "Familiar ultimate inflicts 2 weak on enemy")

func test_seasonal_qi_anomalies():
	# Summer blaze: +50% burn damage
	var combat_summer := SpiritCombat.new(content)
	var enc := {"name": "火傀儡", "health": 50, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat_summer.create(10, enc, ["strike"], 60, {}, [], {}, {"season": "season_summer_blaze"})
	combat_summer.state.enemies[0].burn = 4
	combat_summer.end_turn()
	# 4 * 1.5 = 6 burn damage
	assert_eq(int(combat_summer.state.enemies[0].health), 50 - 6, "Summer blaze deals 150% burn damage (4 * 1.5 = 6)")

	# Spring rain: heals on water/poison card
	var combat_spring := SpiritCombat.new(content)
	combat_spring.create(11, enc, ["venom_fang"], 50, {}, [], {}, {"season": "season_spring_rain"})
	combat_spring.state.hand = [{"card_id": "venom_fang"}]
	combat_spring.state.energy = 3
	combat_spring.play(0, 0)
	assert_eq(int(combat_spring.state.player.health), 52, "Spring rain heals player for 2 on poison card play")

func test_five_elements_generative_cycle_and_grand_wheel():
	var content := SpiritContent.new()
	var combat := SpiritCombat.new(content)
	var enc := {"name": "试道假人", "health": 100, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(777, enc, ["strike", "foxfire"], 60, {}, [], {}, {}, [], {"destiny_boons": ["heavenly_roots"]})

	# Test 1: Wood -> Fire (木生火: Burn +4 and draw 1)
	combat.state.last_element = "wood"
	combat.state.hand = [{"card_id": "foxfire"}] # fire
	combat.state.energy = 3
	var initial_draw_count: int = combat.state.draw.size()
	var events_recorded: Array = []
	combat.event.connect(func(kind, payload): events_recorded.append([kind, payload]))
	var ok: bool = combat.play(0, 0)
	assert_true(ok, "Playing fire card after wood succeeds")
	assert_eq(int(combat.state.enemies[0].burn), 3 + 4, "Wood -> Fire procs +4 burn (3 base + 4 cycle)")
	assert_true(events_recorded.any(func(e): return e[0] == "elemental_cycle_proc" and e[1].get("type") == "wood_fire"), "elemental_cycle_proc wood_fire event emitted")
	assert_true(events_recorded.any(func(e): return e[0] == "destiny_boon_proc" and e[1].get("id") == "heavenly_roots"), "heavenly_roots destiny boon refunded 1 energy")

	# Test 2: Fire -> Earth (火生土: Shield +6)
	combat.state.last_element = "fire"
	combat.state.hand = [{"card_id": "strike"}] # stone (earth)
	combat.state.energy = 3
	var shield_before: int = combat.state.player.shield
	combat.play(0, 0)
	assert_eq(combat.state.player.shield, shield_before + 6, "Fire -> Earth procs +6 shield")

func test_destiny_boons_mechanics():
	var content := SpiritContent.new()

	# Test 1: Sword heart (+50% dmg on first attack)
	var combat_sh := SpiritCombat.new(content)
	var enc := {"name": "剑客", "health": 100, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat_sh.create(888, enc, ["strike"], 60, {}, [], {}, {}, [], {"destiny_boons": ["sword_heart"]})
	combat_sh.state.hand = [{"card_id": "strike"}]
	combat_sh.state.energy = 2
	combat_sh.play(0, 0)
	# Strike is 6 dmg * 1.5 = 9 dmg
	assert_eq(combat_sh.state.enemies[0].health, 100 - 9, "Sword Heart deals 150% damage on first attack (6 * 1.5 = 9)")

	# Test 2: Alchemical physique (+50% pill effect)
	var combat_alc := SpiritCombat.new(content)
	combat_alc.create(889, enc, ["strike"], 60, {}, [], {}, {}, [], {"destiny_boons": ["alchemical_physique"]})
	assert_eq(combat_alc.state.player.shield, 4, "Alchemical physique starts combat with +4 shield")
	combat_alc.use_alchemy_pill("qi_pill")
	# Qi pill gives 2 energy * 1.5 = 3 energy
	assert_eq(combat_alc.state.energy, 2 + 3, "Qi gathering pill grants 3 energy (2 * 1.5)")

	# Test 3: Earth embrace (+2 bonus shield on defense cards)
	var combat_ee := SpiritCombat.new(content)
	combat_ee.create(890, enc, ["ward"], 60, {}, [], {}, {}, [], {"destiny_boons": ["earth_embrace"]})
	combat_ee.state.hand = [{"card_id": "ward"}] # 5 shield
	combat_ee.state.energy = 2
	combat_ee.play(0, -1)
	assert_eq(combat_ee.state.player.shield, 5 + 2, "Earth embrace grants +2 bonus shield (5 + 2 = 7)")

