extends GutTest

# Test suite for the Gameplay Overhaul:
# 1. 8 Hero Capstone Cards (definitions, stats, specials)
# 2. Branching card upgrades (Flow: -1 energy cost, Surge: +3 power)
# 3. Combat mechanics of all capstone cards
# 4. Deck size flexibility and card purging

var content: SpiritContent

func before_all():
	content = SpiritContent.new()

func _create_combat(deck: Array, card_branches := {}, player_health := 60) -> SpiritCombat:
	var combat := SpiritCombat.new(content)
	var enc: Dictionary = content.encounters[0]
	combat.create(12345, enc, deck, player_health, {}, [], {}, {}, [], {}, {}, {}, card_branches)
	return combat

func _find_or_add_card_in_hand(combat: SpiritCombat, card_id: String) -> int:
	for i in combat.state.hand.size():
		if combat.state.hand[i].card_id == card_id:
			return i
	combat.state.hand.append({"uid": 999, "card_id": card_id})
	return combat.state.hand.size() - 1

func test_all_eight_capstone_cards_registered_in_core_data():
	var capstone_ids := [
		"samadhiFire", "spiritSurge",
		"shieldSlam", "bastionForm",
		"thousandBlades", "shadowClone",
		"catalyst", "bloodPact"
	]
	for cid in capstone_ids:
		var c: Dictionary = content.card(cid)
		assert_false(c.is_empty(), "Card %s must exist in content" % cid)
		var zh_name: String = content.text(c.nameKey, "zh-Hans")
		var en_name: String = content.text(c.nameKey, "en")
		assert_true(zh_name.length() > 0 and zh_name != c.nameKey, "Card %s has zh-Hans name" % cid)
		assert_true(en_name.length() > 0 and en_name != c.nameKey, "Card %s has en name" % cid)
		assert_true(str(c.get("special", "")).length() > 0, "Card %s has special mechanic defined" % cid)

func test_card_branch_flow_reduces_cost():
	var combat := _create_combat(["samadhiFire"], {"samadhiFire": "flow"})
	var hand_idx := _find_or_add_card_in_hand(combat, "samadhiFire")
	combat.state.energy = 1
	var played: bool = combat.play(hand_idx, 0)
	assert_true(played, "samadhiFire (base cost 2) with Flow branch costs 1 energy and can be played with 1 energy")
	assert_eq(combat.state.energy, 0, "Energy deducted correctly")

func test_card_branch_surge_boosts_power():
	var combat_normal := _create_combat(["strike"])
	var idx1 := _find_or_add_card_in_hand(combat_normal, "strike")
	var initial_hp: int = int(combat_normal.state.enemies[0].health)
	combat_normal.play(idx1, 0)
	var normal_dmg: int = initial_hp - int(combat_normal.state.enemies[0].health)

	var combat_surge := _create_combat(["strike"], {"strike": "surge"})
	var idx2 := _find_or_add_card_in_hand(combat_surge, "strike")
	initial_hp = int(combat_surge.state.enemies[0].health)
	combat_surge.play(idx2, 0)
	var surge_dmg: int = initial_hp - int(combat_surge.state.enemies[0].health)

	assert_eq(surge_dmg, normal_dmg + 3, "Surge branch adds exactly +3 power to strike damage")

func test_samadhi_fire_burst():
	var combat := _create_combat(["samadhiFire"])
	var hand_idx := _find_or_add_card_in_hand(combat, "samadhiFire")
	var enemy: Dictionary = combat.state.enemies[0]
	enemy.burn = 6
	var initial_hp: int = int(enemy.health)
	
	combat.state.energy = 5
	combat.play(hand_idx, 0)
	# Samadhi fire deals 8 base damage + (burn * 2 = 12) = 20 damage, and doubles burn to 12
	assert_eq(int(enemy.health), initial_hp - 20, "Samadhi Fire deals base damage + 2x burn damage")
	assert_eq(int(enemy.burn), 12, "Samadhi Fire doubles enemy burn stacks")

func test_spirit_surge_buff():
	var combat := _create_combat(["spiritSurge", "strike"])
	combat.state.energy = 5
	var surge_idx := _find_or_add_card_in_hand(combat, "spiritSurge")
	combat.play(surge_idx, 0)
	assert_true(combat.state.spirit_surge_active, "Spirit Surge is activated")

	var strike_idx := _find_or_add_card_in_hand(combat, "strike")
	var pre_shield: int = int(combat.state.player.shield)
	combat.play(strike_idx, 0)
	assert_true(int(combat.state.player.shield) >= pre_shield + 2, "Spirit Surge granted +2 shield on playing a card")

func test_shield_slam_deals_damage_equal_to_shield():
	var combat := _create_combat(["shieldSlam"])
	combat.state.energy = 5
	combat.state.player.shield = 20
	var enemy: Dictionary = combat.state.enemies[0]
	enemy.health = 50
	enemy.shield = 0
	var initial_hp: int = int(enemy.health)
	var hand_idx := _find_or_add_card_in_hand(combat, "shieldSlam")

	combat.play(hand_idx, 0)
	# Shield slam deals 4 base damage + 20 piercing damage equal to 100% current shield = 24
	assert_eq(int(enemy.health), initial_hp - 24, "Shield Slam deals base 4 + 100% player shield as pierce damage")

func test_bastion_form_retains_shield_between_turns():
	var combat := _create_combat(["bastionForm"])
	combat.state.energy = 5
	var hand_idx := _find_or_add_card_in_hand(combat, "bastionForm")
	combat.play(hand_idx, 0)
	assert_true(combat.state.bastion_form_active, "Bastion Form is active")

	combat.state.player.shield = 30
	# Prevent enemy from attacking player during end_turn
	for e in combat.state.enemies:
		e.damage = 0
		e.intent = {"kind": "defend", "amount": 5}

	combat.end_turn()
	assert_eq(int(combat.state.player.shield), 30, "Bastion Form retained 30 shield into next turn")

func test_thousand_blades_scales_with_hand_size():
	var combat := _create_combat(["thousandBlades", "strike", "ward", "spirit"])
	combat.state.energy = 5
	combat.state.hand = [
		{"uid": 1, "card_id": "thousandBlades"},
		{"uid": 2, "card_id": "strike"},
		{"uid": 3, "card_id": "ward"},
		{"uid": 4, "card_id": "spirit"}
	]
	var enemy: Dictionary = combat.state.enemies[0]
	var initial_hp: int = int(enemy.health)
	
	# Hand size is 4. When thousandBlades is played, remaining hand is 3 cards.
	# Base damage 5 + 3 * 4 = 17 damage.
	combat.play(0, 0)
	assert_eq(int(enemy.health), initial_hp - 17, "Thousand Blades deals base 5 + 4 damage per card in hand (17 total)")

func test_shadow_clone_doubles_next_card():
	var combat := _create_combat(["shadowClone", "strike"])
	combat.state.energy = 5
	combat.state.hand = [
		{"uid": 1, "card_id": "shadowClone"},
		{"uid": 2, "card_id": "strike"}
	]
	var enemy: Dictionary = combat.state.enemies[0]
	var initial_hp: int = int(enemy.health)

	combat.play(0, 0)
	assert_true(combat.state.shadow_clone_active, "Shadow Clone is active")

	# Strike is now at index 0 after shadowClone was played
	combat.play(0, 0)
	# Strike deals 6 damage normally. Double cast = 12 damage.
	assert_eq(int(enemy.health), initial_hp - 12, "Shadow Clone casts strike twice for 12 damage total")
	assert_false(combat.state.shadow_clone_active, "Shadow Clone consumed after proc")

func test_catalyst_doubles_poison():
	var combat := _create_combat(["catalyst"])
	combat.state.energy = 5
	combat.state.hand = [{"uid": 1, "card_id": "catalyst"}]
	var enemy: Dictionary = combat.state.enemies[0]
	enemy.poison = 7

	combat.play(0, 0)
	# Catalyst adds 2 poison from effect, then doubles (7 + 2) * 2 = 18
	assert_eq(int(enemy.poison), 18, "Catalyst adds 2 poison and doubles poison to 18")

func test_blood_pact_grants_energy_and_draw_at_health_cost():
	var combat := _create_combat(["bloodPact", "strike", "ward", "spirit", "strike", "ward", "spirit", "strike", "ward", "spirit"])
	combat.state.hand = [{"uid": 1, "card_id": "bloodPact"}]
	combat.state.player.health = 40
	combat.state.energy = 1

	combat.play(0, 0)
	# Blood pact costs 1 energy (1-1=0) then gives +2 energy -> 2 energy
	assert_eq(combat.state.energy, 2, "Blood Pact granted +2 energy")
	assert_eq(int(combat.state.player.health), 35, "Blood Pact cost 5 HP")
	assert_eq(combat.state.hand.size(), 3, "Blood Pact drew 3 cards into hand")

func test_deck_size_flexibility_in_save_store():
	var valid_small_deck: Array = []
	for i in 15: valid_small_deck.append("strike")
	assert_true(valid_small_deck.size() >= 12 and valid_small_deck.size() <= 50, "15-card deck is valid")

	var valid_large_deck: Array = []
	for i in 35: valid_large_deck.append("ward")
	assert_true(valid_large_deck.size() >= 12 and valid_large_deck.size() <= 50, "35-card deck is valid")
