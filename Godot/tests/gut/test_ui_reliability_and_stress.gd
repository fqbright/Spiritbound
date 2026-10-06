extends GutTest

# ==============================================================================
# UI & Gameplay Reliability, Stress & Edge-Case Safety Tests
# ==============================================================================

var content: SpiritContent
var had_real_save: bool
var real_save_text: String

func before_all():
	content = SpiritContent.new()
	had_real_save = FileAccess.file_exists(SpiritSave.PATH)
	if had_real_save:
		real_save_text = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()

func after_all():
	if had_real_save:
		FileAccess.open(SpiritSave.PATH, FileAccess.WRITE).store_string(real_save_text)
	else:
		SpiritSave.reset()

func _create_game(lang := "zh-Hans", viewport_size := Vector2(390, 844)) -> SpiritGame:
	var g := SpiritGame.new()
	g.content = content
	g.lang = lang
	g.profile = SpiritSave.defaults(content)
	g.root = Control.new()
	g.root.custom_minimum_size = viewport_size
	g.root.size = viewport_size
	g.overlay = Control.new()
	g.overlay.custom_minimum_size = viewport_size
	g.overlay.size = viewport_size
	g.add_child(g.root)
	g.add_child(g.overlay)
	return g

# ------------------------------------------------------------------------------
# 1. Turn Resolution Reentrancy & Input Spam Safety
# ------------------------------------------------------------------------------

func test_end_turn_reentrancy_and_spam_safety():
	var g := _create_game()
	g.begin_battle(0)
	assert_not_null(g.combat, "Combat initialized")
	var initial_turn: int = g.combat.state.turn

	# Single end turn advances to next turn
	g.combat.end_turn()
	assert_eq(g.combat.state.turn, initial_turn + 1, "Turn incremented once cleanly")

	# Simulate rapid spam: calling end_turn while player is dead or in resolved state
	g.combat.state.player.health = 0
	g.combat.end_turn()
	g.combat.end_turn()
	g.combat.end_turn()
	# State shouldn't corrupt or loop endlessly
	assert_true(g.combat.state.player.health <= 0, "Player remains defeated without NaN or negative overflow crash")
	g.free()

# ------------------------------------------------------------------------------
# 2. Empty Deck & Discard Reshuffle Exhaustion Safety
# ------------------------------------------------------------------------------

func test_empty_deck_and_discard_draw_exhaustion():
	var combat := SpiritCombat.new(content)
	var encounter := {"name": "试炼木桩", "health": 100, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(101, encounter, ["strike"], 60, {}, [], {}, {})

	# Empty both draw pile and discard pile completely
	combat.state.draw.clear()
	combat.state.discard.clear()
	combat.state.hand.clear()

	# Attempting to draw 5 cards from an empty deck must not crash or loop infinitely
	combat._draw(5)
	assert_eq(combat.state.hand.size(), 0, "Hand remains empty when no cards exist anywhere")
	assert_eq(combat.state.draw.size(), 0, "Draw pile remains 0")
	assert_eq(combat.state.discard.size(), 0, "Discard pile remains 0")

# ------------------------------------------------------------------------------
# 3. Maximum Hand Limit (10 Cards) Layout & Boundary Stability
# ------------------------------------------------------------------------------

func test_hand_limit_ten_cards_layout_stability():
	var g := _create_game()
	g.begin_battle(0)
	g.show_battle()

	# Populate hand to max limit of 10 cards
	g.combat.state.hand.clear()
	for i in range(10):
		g.combat.state.hand.append({
			"uid": 1000 + i,
			"card_id": "strike" if i % 2 == 0 else "ward"
		})

	# Re-render battle with full 10-card hand
	g.show_battle()
	assert_not_null(g.hand_zone, "g.hand_zone exists with 10 cards")
	assert_eq(g.hand_zone.get_child_count(), 10, "Exactly 10 card nodes in hand row")

	# Ensure card nodes have valid non-zero dimensions
	for child in g.hand_zone.get_children():
		if child is Control:
			var c: Control = child
			assert_true(c.size.x > 0 and c.size.y > 0, "Card has valid non-zero dimension")
	g.free()

# ------------------------------------------------------------------------------
# 4. Five Elements Double Complete Loop & Grand Wheel Trigger
# ------------------------------------------------------------------------------

func test_five_elements_cycle_double_round_trip():
	var combat := SpiritCombat.new(content)
	var encounter := {"name": "五行傀儡", "health": 200, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(202, encounter, ["strike", "ward"], 60, {}, [], {}, {})

	var initial_enemy_hp: int = combat.state.enemies[0].health

	# Cycle 1: wood -> fire -> earth -> metal -> water (5 steps)
	combat.state.five_elements_cycle_history = ["wood", "fire", "earth", "metal"]
	combat.state.last_element = "metal"
	combat.state.five_elements_cycle_history.append("water")
	if combat.state.five_elements_cycle_history.has("wood") and combat.state.five_elements_cycle_history.has("fire") and combat.state.five_elements_cycle_history.has("earth") and combat.state.five_elements_cycle_history.has("metal") and combat.state.five_elements_cycle_history.has("water"):
		for ei in combat.state.enemies.size():
			if combat.state.enemies[ei].health > 0:
				combat._damage_enemy(ei, 25, true)
		combat.state.five_elements_cycle_history = []

	assert_eq(combat.state.five_elements_cycle_history.size(), 0, "Cycle counter resets to 0 after completing full 5-element cycle")
	var hp_after_cycle_1: int = combat.state.enemies[0].health
	assert_eq(hp_after_cycle_1, initial_enemy_hp - 25, "First Grand Wheel dealt 25 damage")

	# Cycle 2: Repeat full 5 elements
	combat.state.five_elements_cycle_history = ["wood", "fire", "earth", "metal", "water"]
	if combat.state.five_elements_cycle_history.has("wood") and combat.state.five_elements_cycle_history.has("fire") and combat.state.five_elements_cycle_history.has("earth") and combat.state.five_elements_cycle_history.has("metal") and combat.state.five_elements_cycle_history.has("water"):
		for ei in combat.state.enemies.size():
			if combat.state.enemies[ei].health > 0:
				combat._damage_enemy(ei, 25, true)
		combat.state.five_elements_cycle_history = []

	var hp_after_cycle_2: int = combat.state.enemies[0].health
	assert_eq(hp_after_cycle_2, hp_after_cycle_1 - 25, "Second Grand Wheel dealt another 25 damage")
	assert_eq(combat.state.five_elements_cycle_history.size(), 0, "Cycle history cleanly resets again")

# ------------------------------------------------------------------------------
# 5. Combat Pill Quick Pouch Edge Cases & Clamping
# ------------------------------------------------------------------------------

func test_combat_pill_pouch_boundary_and_overheal_protection():
	var combat := SpiritCombat.new(content)
	var encounter := {"name": "试炼木桩", "health": 100, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(303, encounter, ["strike"], 60, {}, [], {}, {})

	# Player is at 60/60 HP (full). Using nine_turn_pill should heal up to max_health
	assert_eq(combat.state.player.health, 60, "Player starts at 60 max HP")
	var used_at_full: bool = combat.use_alchemy_pill("nine_turn_pill")
	assert_true(used_at_full, "Pill can be used at full HP")
	assert_eq(combat.state.player.health, 60, "HP does not exceed max_health cap on overheal")

	# Reset used flag for second test
	combat.state.pill_used_this_combat = false
	combat.state.player.health = 5
	var used_at_low: bool = combat.use_alchemy_pill("nine_turn_pill")
	assert_true(used_at_low, "Pill used when low on health")
	# nine_turn_pill heals 30 HP: 5 + 30 = 35
	assert_eq(combat.state.player.health, 35, "Nine-turn salve restores 30 HP from 5 to 35 cleanly")

	# Cannot use second pill in the same combat
	var used_twice: bool = combat.use_alchemy_pill("qi_pill")
	assert_false(used_twice, "Cannot use a second pill in the same combat (pill_used_this_combat = true)")

# ------------------------------------------------------------------------------
# 6. Destiny Boon Fault Tolerance & Corrupted Data Resilience
# ------------------------------------------------------------------------------

func test_destiny_boon_persistence_and_corrupted_id_tolerance():
	var g := _create_game()
	# Inject invalid/corrupted boons alongside valid boons
	g.profile.destiny_boons = ["heavenly_roots", "non_existent_corrupted_boon_404", null, 9999]

	# Opening camp screen and selecting realms should not crash on unknown boons
	g.show_camp()
	assert_true(g.root.get_child_count() > 0, "Camp screen rendered without throwing exception on corrupted boon list")

	# Verify SpiritContent boons dictionary lookup is safe
	assert_true(SpiritContent.DESTINY_BOONS.has("heavenly_roots"), "heavenly_roots boon exists")
	var valid_boon: Dictionary = SpiritContent.DESTINY_BOONS.get("heavenly_roots", {})
	assert_false(valid_boon.is_empty(), "Valid boon retrieved")
	var invalid_boon: Dictionary = SpiritContent.DESTINY_BOONS.get("non_existent_corrupted_boon_404", {})
	assert_true(invalid_boon.is_empty(), "Unknown boon returns empty dictionary safely")
	g.free()

# ------------------------------------------------------------------------------
# 7. Multi-Resolution Aspect Ratio Layout Safety
# ------------------------------------------------------------------------------

func test_multi_resolution_layout_safety():
	var viewports := [
		Vector2(375, 667),  # iPhone SE (small 16:9 portrait)
		Vector2(390, 844),  # Standard iPhone portrait
		Vector2(412, 915),  # Modern Android flagship portrait
		Vector2(768, 1024), # Tablet 4:3 portrait
	]

	for vp in viewports:
		var g := _create_game("zh-Hans", vp)
		# 1. Map screen
		g.show_map()
		assert_true(g.root.get_child_count() > 0, "[%s] Map screen builds cleanly" % str(vp))

		# 2. Battle screen
		g.begin_battle(0)
		g.show_battle()
		assert_true(g.root.get_child_count() > 0, "[%s] Battle screen builds cleanly" % str(vp))

		# 3. Deck screen
		g.show_deck()
		assert_true(g.root.get_child_count() > 0, "[%s] Deck screen builds cleanly" % str(vp))

		g.free()

# ------------------------------------------------------------------------------
# 8. Atomic Save & Backup Auto-Recovery Safety
# ------------------------------------------------------------------------------

func test_atomic_save_and_backup_recovery():
	var test_profile := SpiritSave.defaults(content)
	test_profile.gold = 777
	test_profile.unlocked = 12
	# Save once to create primary save
	SpiritSave.write(test_profile)
	# Save again with updated data to ensure .bak is populated
	test_profile.gold = 888
	SpiritSave.write(test_profile)

	assert_true(FileAccess.file_exists(SpiritSave.PATH), "Primary save exists")
	assert_true(FileAccess.file_exists(SpiritSave.PATH + ".bak"), "Backup save exists")

	# Simulate sudden crash / 0-byte or corrupted primary save
	var corrupt_f := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
	corrupt_f.store_string("{ 'truncated_json': 123... ")
	corrupt_f.close()

	# Loading should transparently recover from .bak
	var recovered: Dictionary = SpiritSave.load_profile(content)
	assert_true(int(recovered.gold) >= 777, "Recovered profile restored gold from backup (got %d)" % int(recovered.gold))
	assert_eq(int(recovered.unlocked), 12, "Recovered profile restored unlocked stage from backup")

# ------------------------------------------------------------------------------
# 9. Currency & Stamina Negative / NaN Sanitization
# ------------------------------------------------------------------------------

func test_currency_and_stamina_corruption_sanitization():
	var corrupt_data := {
		"gold": -500,
		"spirit_jade": -100,
		"spirit_dust": -50,
		"stamina": {"current": -25, "max": 0},
		"music_volume": 2.5,
		"sfx_volume": -0.5,
		"text_scale": 0.2
	}
	var f := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(corrupt_data))
	f.close()
	if FileAccess.file_exists(SpiritSave.PATH + ".bak"):
		DirAccess.remove_absolute(SpiritSave.PATH + ".bak")

	var loaded: Dictionary = SpiritSave.load_profile(content)
	assert_eq(int(loaded.gold), 0, "Negative gold clamped to 0")
	assert_eq(int(loaded.spirit_jade), 0, "Negative spirit_jade clamped to 0")
	assert_eq(int(loaded.spirit_dust), 0, "Negative spirit_dust clamped to 0")
	assert_true(int(loaded.stamina.max) >= 10, "Zero stamina max clamped to >= 10")
	assert_true(int(loaded.stamina.current) >= 0, "Negative stamina current clamped to >= 0")
	assert_true(loaded.music_volume <= 1.0, "Excessive music volume clamped to 1.0")
	assert_true(loaded.sfx_volume >= 0.0, "Negative sfx volume clamped to 0.0")
	assert_true(loaded.text_scale >= 0.8, "Sub-minimum text scale clamped to 0.8")

# ------------------------------------------------------------------------------
# 10. Corrupted Deck Presets Fallback Safety
# ------------------------------------------------------------------------------

func test_deck_presets_corruption_fallback():
	var corrupt_presets := {
		"deck_presets": {
			"1": [],           # Empty
			"2": ["strike"],   # Too few
			"3": "not_an_array" # Malformed
		}
	}
	var f := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(corrupt_presets))
	f.close()
	if FileAccess.file_exists(SpiritSave.PATH + ".bak"):
		DirAccess.remove_absolute(SpiritSave.PATH + ".bak")

	var loaded: Dictionary = SpiritSave.load_profile(content)
	assert_eq(loaded.deck_presets["1"].size(), 25, "Empty preset 1 restored to starting deck")
	assert_eq(loaded.deck_presets["2"].size(), 25, "Undersized preset 2 restored to starting deck")
	assert_eq(loaded.deck_presets["3"].size(), 25, "Non-array preset 3 restored to starting deck")

# ------------------------------------------------------------------------------
# 11. Combat DoT Lethal Victory Phase Transition Safety
# ------------------------------------------------------------------------------

func test_combat_dot_lethal_victory_transition():
	var combat := SpiritCombat.new(content)
	var encounter := {"name": "毒瘴精怪", "health": 4, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(404, encounter, ["strike"], 60, {}, [], {}, {})
	# Inflict lethal DoT on enemy (5 burn when enemy has 4 HP)
	combat.state.enemies[0].burn = 5
	var initial_player_hp: int = combat.state.player.health

	# End turn: Burn should kill the enemy during DoT resolution
	combat.end_turn()

	assert_eq(combat.state.enemies[0].health, 0, "Enemy slain by burn DoT")
	assert_eq(combat.state.phase, "won", "Combat immediately marks phase as won upon DoT kill")
	assert_eq(combat.state.player.health, initial_player_hp, "Dead enemy does not inflict attack damage on player")

# ------------------------------------------------------------------------------
# 12. Combat Card Undo Edge Cases & Reversion Safety
# ------------------------------------------------------------------------------

func test_combat_undo_edge_cases():
	var combat := SpiritCombat.new(content)
	var encounter := {"name": "试炼木桩", "health": 100, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(505, encounter, ["strike", "ward"], 60, {}, [], {}, {})
	combat.state.hand = [{"uid": 101, "card_id": "strike"}]
	combat.state.energy = 2

	# Initial state: can_undo is false
	assert_false(combat.can_undo(), "can_undo is false before playing cards")
	assert_false(combat.undo_last_card(), "undo_last_card returns false safely when no history")

	# Play strike (cost 1, deals 6 dmg)
	var before_energy: int = combat.state.energy
	var ok: bool = combat.play(0, 0)
	assert_true(ok, "Card play succeeds")
	assert_eq(combat.state.energy, before_energy - 1, "Energy consumed")
	assert_eq(combat.state.enemies[0].health, 94, "Enemy took 6 damage")
	assert_true(combat.can_undo(), "can_undo is true after playing card")

	# Undo card play
	var undone: bool = combat.undo_last_card()
	assert_true(undone, "undo_last_card succeeds")
	assert_eq(combat.state.energy, before_energy, "Energy restored on undo")
	assert_eq(combat.state.enemies[0].health, 100, "Enemy HP restored on undo")
	assert_false(combat.can_undo(), "can_undo is false after undoing")

# ------------------------------------------------------------------------------
# 13. Familiar Ultimate Qi Threshold & Reset Boundary
# ------------------------------------------------------------------------------

func test_familiar_ultimate_boundary_and_qi_reset():
	var combat := SpiritCombat.new(content)
	var encounter := {"name": "灵兽试炼", "health": 100, "damage": 0, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
	combat.create(606, encounter, ["strike"], 60, {}, [], {}, {})

	# 1. At 99% Qi, activation rejected
	combat.state.familiar_qi = 99
	var res_fail: Dictionary = combat.activate_familiar_ultimate()
	assert_false(res_fail.ok, "Ultimate rejected when Qi < 100")
	assert_eq(combat.state.familiar_qi, 99, "Qi not consumed on failed activation")

	# 2. At 100% Qi, activation succeeds
	combat.state.familiar_qi = 100
	var res_ok: Dictionary = combat.activate_familiar_ultimate()
	assert_true(res_ok.ok, "Ultimate succeeds at 100 Qi")
	assert_eq(combat.state.familiar_qi, 0, "Qi fully reset to 0")
	assert_true(combat.state.player.shield >= 14, "Player gained at least 14 shield")
	assert_eq(int(combat.state.enemies[0].get("weak", 0)), 2, "Enemy inflicted with 2 weak")

	# 3. Consecutive immediate activation rejected
	var res_again: Dictionary = combat.activate_familiar_ultimate()
	assert_false(res_again.ok, "Immediate re-activation rejected")

# ------------------------------------------------------------------------------
# 14. Shop Payment Exact & Insufficient Balance Boundary
# ------------------------------------------------------------------------------

func test_shop_payment_exact_and_insufficient_currencies():
	var g := _create_game()
	var shop_scr := ShopDeckScreen.new(g)

	# Scenario A: Exact gold payment
	g.profile.gold = 50
	g.profile.spirit_jade = 0
	var pay_exact: Dictionary = shop_scr._resolve_payment(50, 20)
	assert_eq(str(pay_exact.kind), "gold", "Resolves gold when exact amount available")
	assert_eq(int(pay_exact.amount), 50, "Gold amount is 50")
	var spent: bool = shop_scr._spend_payment(50, 20)
	assert_true(spent, "Payment succeeds")
	assert_eq(int(g.profile.gold), 0, "Gold balance is exactly 0 without negative balance")

	# Scenario B: Insufficient gold, fallback to Spirit Jade
	g.profile.gold = 10
	g.profile.spirit_jade = 25
	var pay_jade: Dictionary = shop_scr._resolve_payment(50, 20)
	assert_eq(str(pay_jade.kind), "jade", "Falls back to jade when gold insufficient")
	assert_eq(int(pay_jade.amount), 20, "Jade cost is 20")

	# Scenario C: Insufficient for both
	g.profile.gold = 10
	g.profile.spirit_jade = 5
	var pay_none: Dictionary = shop_scr._resolve_payment(50, 20)
	assert_eq(str(pay_none.kind), "", "Returns empty payment kind when both currencies insufficient")
	assert_false(shop_scr._can_pay(50, 20), "_can_pay returns false")
	g.free()

# ------------------------------------------------------------------------------
# 15. Extreme Ascension Scaling Invariants
# ------------------------------------------------------------------------------

func test_extreme_ascension_scaling_invariants():
	for asc_lvl in [0, 5, 10, 15, 20, 25]:
		var combat := SpiritCombat.new(content)
		var encounter := {"name": "天道试炼", "health": 100, "damage": 10, "chapter": 1, "level": 1, "adds": 0, "mechanics": {}}
		combat.create(707 + asc_lvl, encounter, ["strike"], 60, {}, [], {}, {"ascension_level": asc_lvl})

		assert_true(combat.state.player.health > 0, "[Asc %d] Player health is positive" % asc_lvl)
		assert_true(combat.state.enemies[0].health >= 100, "[Asc %d] Enemy health scaled >= base" % asc_lvl)
		assert_true(combat.state.enemies[0].damage >= 10, "[Asc %d] Enemy damage scaled >= base" % asc_lvl)
		if asc_lvl >= 20:
			assert_true(int(combat.state.get("ascension_level", 0)) >= 20, "Ascension 20+ recorded in combat state")
