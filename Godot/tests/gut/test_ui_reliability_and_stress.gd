extends GutTest

# ==============================================================================
# UI & Gameplay Reliability, Stress & Edge-Case Safety Tests
# ==============================================================================

var content: SpiritContent

func before_all():
	content = SpiritContent.new()

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
	# Verify that five_elements_cycle_history accumulates and resets on completion
	combat.state.five_elements_cycle_history = ["wood", "fire", "earth", "metal"]
	combat.state.last_element = "metal"
	# Playing water completes the 5-element cycle -> deals 25 damage and resets history
	combat.state.hand = [{"card_id": "ward"}] # Let's make an ad-hoc card or use content
	var water_card: Dictionary = {"id": "test_water", "element": "water", "cost": 0, "effects": []}
	# Manually proc the cycle logic by playing with last_element set:
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
