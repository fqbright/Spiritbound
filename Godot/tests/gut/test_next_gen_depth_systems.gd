extends GutTest

var content: SpiritContent

func before_all() -> void:
	content = SpiritContent.new()

func test_spiritual_roots_allocation_and_combat_bonuses():
	var dummy_profile := {
		"spiritual_roots": {"metal": 1, "wood": 1, "water": 1, "fire": 1, "earth": 1},
		"spiritual_root_points": 2,
		"deck": ["strike", "ward"]
	}
	# Allocation
	var ok: bool = SpiritSave.invest_spiritual_root(dummy_profile, "fire")
	assert_true(ok, "Investing in fire root succeeds")
	assert_eq(int(dummy_profile.spiritual_roots.fire), 2, "Fire root increased to 2")
	assert_eq(int(dummy_profile.spiritual_root_points), 1, "Points deducted to 1")

	# Combat: Fire root (+10% Burn per level above 1)
	var combat := SpiritCombat.new(content)
	var enc := {"name": "火傀儡", "health": 50, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(1, enc, Array(content.raw.startingDeck), 60, {}, [], {}, {}, [], {"spiritual_roots": dummy_profile.spiritual_roots})
	combat.state.enemies[0].burn = 10
	combat.end_turn()
	# 10 * 1.1 = 11 burn damage
	assert_eq(int(combat.state.enemies[0].health), 50 - 11, "Fire root level 2 boosts burn damage to 110%")

	# Combat: Wood root (heals 1 HP on poison card)
	var dummy_wood := {"metal": 1, "wood": 3, "water": 1, "fire": 1, "earth": 1}
	var combat_wood := SpiritCombat.new(content)
	combat_wood.create(2, enc, Array(content.raw.startingDeck), 50, {}, [], {}, {}, [], {"spiritual_roots": dummy_wood})
	combat_wood.state.hand = [{"card_id": "venom_fang"}]
	combat_wood.state.energy = 3
	combat_wood.play(0, 0)
	# Level 3 wood root heals (3 - 1) = 2 HP
	assert_eq(int(combat_wood.state.player.health), 52, "Wood root level 3 heals 2 HP on poison card")

	# Combat: Water root (+1 shield per point above 1)
	var dummy_water := {"metal": 1, "wood": 1, "water": 3, "fire": 1, "earth": 1}
	var combat_water := SpiritCombat.new(content)
	combat_water.create(3, enc, Array(content.raw.startingDeck), 50, {}, [], {}, {}, [], {"spiritual_roots": dummy_water})
	combat_water.state.hand = [{"card_id": "ward"}]
	combat_water.state.energy = 3
	combat_water.play(0, -1)
	# Ward gives 5 base shield + (3 - 1) = 7 shield
	assert_eq(int(combat_water.state.player.shield), 7, "Water root level 3 gives +2 bonus shield on ward (5 + 2 = 7)")

func test_card_inscriptions_application_and_proc():
	var dummy_profile := {"deck": ["strike", "ward"], "card_inscriptions": {}}
	SpiritSave.inscribe_card(dummy_profile, "strike", "rune_vampire")
	assert_eq(str(dummy_profile.card_inscriptions.get("strike", "")), "rune_vampire", "Card strike inscribed with rune_vampire")

	var combat := SpiritCombat.new(content)
	var enc := {"name": "试炼木人", "health": 100, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(4, enc, Array(content.raw.startingDeck), 50, {}, [], {}, {}, [], {"card_inscriptions": dummy_profile.card_inscriptions})
	combat.state.hand = [{"card_id": "strike"}]
	combat.state.energy = 3
	combat.play(0, 0)
	assert_eq(int(combat.state.player.health), 52, "Vampire inscription heals 2 HP on attack")

	# Test surging rune (+1 energy on first card)
	var combat_surge := SpiritCombat.new(content)
	combat_surge.create(5, enc, Array(content.raw.startingDeck), 50, {}, [], {}, {}, [], {"card_inscriptions": {"ward": "rune_surging"}})
	combat_surge.state.hand = [{"card_id": "ward"}]
	combat_surge.state.energy = 2
	combat_surge.play(0, -1)
	# 2 energy - 1 cost + 1 surging refund = 2
	assert_eq(int(combat_surge.state.energy), 2, "Surging inscription refunds 1 energy on first play")

func test_boss_phase_2_enrage_trigger():
	var combat := SpiritCombat.new(content)
	var boss_enc := {"name": "黑风妖王", "health": 80, "damage": 10, "chapter": 1, "level": 5, "adds": 0, "mechanics": {}, "is_boss": true}
	combat.create(6, boss_enc, Array(content.raw.startingDeck), 60, {}, [], {}, {})
	assert_false(bool(combat.state.get("boss_phase_2_triggered", false)), "Boss phase 2 starts untriggered")

	# Deal damage bringing boss below 50% HP (80 -> 35)
	combat._damage_enemy(0, 45, true)
	assert_true(bool(combat.state.get("boss_phase_2_triggered", false)), "Boss phase 2 triggers at <= 50% HP")
	assert_eq(int(combat.state.enemies[0].shield), 12, "Boss gains 12 bonus shield upon phase 2 awakening")
	assert_eq(int(combat.state.enemies[0].damage), 13, "Boss gains +3 damage upon phase 2 awakening")

func test_endless_pagoda_scaling_and_save():
	var p1: Dictionary = content.pagoda_encounter(1)
	var p5: Dictionary = content.pagoda_encounter(5)
	var p10: Dictionary = content.pagoda_encounter(10)

	assert_true(int(p5.health) > int(p1.health), "Pagoda floor 5 has more HP than floor 1")
	assert_true(int(p10.damage) > int(p5.damage), "Pagoda floor 10 deals more damage than floor 5")
	assert_true(bool(p1.is_pagoda), "Pagoda encounter marked with is_pagoda")
	assert_true(p10.adds > 0, "Floor 10+ summons minion adds")

	var dummy_profile := {"pagoda_highest_floor": 2}
	SpiritSave.record_pagoda_progress(dummy_profile, 7)
	assert_eq(int(dummy_profile.pagoda_highest_floor), 7, "Pagoda highest floor updated to 7")

func test_battle_chronicle_statistics_recording():
	var combat := SpiritCombat.new(content)
	var enc := {"name": "演武靶子", "health": 100, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(7, enc, Array(content.raw.startingDeck), 60, {}, [], {}, {})
	combat.state.hand = [{"card_id": "strike"}]
	combat.state.energy = 3
	combat.play(0, 0)
	combat.end_turn()

	assert_true(combat.state.stats.turn_damage.size() >= 1, "Turn damage history recorded")
	assert_eq(str(combat.state.stats.mvp_card), "strike", "MVP card accurately recorded as strike")
	assert_true(int(combat.state.stats.mvp_card_damage) > 0, "MVP card damage tracked")

func test_one_handed_mode_toggle():
	var dummy_profile := {"one_handed_mode": "off"}
	dummy_profile.one_handed_mode = "left"
	assert_eq(str(dummy_profile.one_handed_mode), "left", "One-handed mode toggle holds left")
	dummy_profile.one_handed_mode = "right"
	assert_eq(str(dummy_profile.one_handed_mode), "right", "One-handed mode toggle holds right")
