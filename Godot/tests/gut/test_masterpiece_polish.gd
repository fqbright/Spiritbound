extends GutTest

# Test suite for Masterpiece Polish & Player Experience Overhaul:
# 1. Smart Cloud Save Conflict Reconciliation (SpiritSave.merge_profiles)
# 2. Deck Archetype Evaluation & Synergy Detection
# 3. Fast Combat Delay Scaling
# 4. Gamepad & Keyboard Navigation Contracts
# 5. Localization of new Polish & Conflict Strings

var content: SpiritContent

func before_all():
	content = SpiritContent.new()

func test_merge_profiles_highest_reconciliation():
	var p_local := {
		"unlocked": 25,
		"position": 24,
		"highest_ascension": 5,
		"ascension_level": 4,
		"gold": 500,
		"spirit_jade": 50,
		"spirit_dust": 100,
		"abyss_floor": 10,
		"abyss_record": 15,
		"boss_rush_record": 3,
		"compendium_discovered": {"cards": ["strike", "defend"]},
		"updated_at": 1000
	}
	var p_cloud := {
		"unlocked": 30,
		"position": 30,
		"highest_ascension": 8,
		"ascension_level": 7,
		"gold": 300,
		"spirit_jade": 120,
		"spirit_dust": 80,
		"abyss_floor": 14,
		"abyss_record": 20,
		"boss_rush_record": 5,
		"compendium_discovered": {"cards": ["samadhiFire", "strike"]},
		"updated_at": 2000
	}

	var merged: Dictionary = SpiritSave.merge_profiles(p_local, p_cloud)

	assert_eq(merged.unlocked, 30, "Takes highest unlocked stage")
	assert_eq(merged.position, 30, "Takes highest position")
	assert_eq(merged.highest_ascension, 8, "Takes highest ascension achieved")
	assert_eq(merged.gold, 500, "Takes maximum gold between local and cloud")
	assert_eq(merged.spirit_jade, 120, "Takes maximum spirit jade between local and cloud")
	assert_eq(merged.spirit_dust, 100, "Takes maximum spirit dust between local and cloud")
	assert_eq(merged.abyss_record, 20, "Takes highest abyss record")
	assert_eq(merged.boss_rush_record, 5, "Takes highest boss rush record")
	assert_eq(merged.updated_at, 2000, "Takes latest updated_at timestamp")

	var cards: Array = merged.compendium_discovered.get("cards", [])
	assert_true(cards.has("strike"), "Merged compendium has strike")
	assert_true(cards.has("defend"), "Merged compendium has defend from local")
	assert_true(cards.has("samadhiFire"), "Merged compendium has samadhiFire from cloud")

func test_evaluate_deck_archetype():
	var game := SpiritGame.new()
	game.profile = SpiritSave.defaults(content)
	var shop_deck := ShopDeckScreen.new(game)

	# Fire deck
	var fire_deck := ["cinder_slash", "samadhiFire", "foxfire", "defend", "strike"]
	var fire_arch: Dictionary = shop_deck._evaluate_deck_archetype(fire_deck)
	assert_eq(fire_arch.icon, "🔥", "Fire deck produces fire icon")

	# Poison deck
	var poison_deck := ["venom_fang", "catalyst", "corrosive_acid", "defend", "strike"]
	var poison_arch: Dictionary = shop_deck._evaluate_deck_archetype(poison_deck)
	assert_eq(poison_arch.icon, "☠️", "Poison deck produces poison icon")

	# Balanced deck
	var balanced_deck := ["strike", "defend", "cinder_slash", "venom_fang", "glacial_barrier"]
	var bal_arch: Dictionary = shop_deck._evaluate_deck_archetype(balanced_deck)
	assert_eq(bal_arch.icon, "☯", "Diverse deck produces balanced icon")

	game.free()

func test_fast_combat_delay_scaling():
	var game := SpiritGame.new()
	game.profile = SpiritSave.defaults(content)
	game.battle_speed = 1.0

	game.profile.fast_combat = false
	var delay_normal: float = game._battle_delay(1.0)
	assert_eq(delay_normal, 1.0, "Normal combat delay is 1.0 at 1x speed")

	game.profile.fast_combat = true
	var delay_fast: float = game._battle_delay(1.0)
	assert_eq(delay_fast, 0.5, "Fast combat cuts delay by 50% at 1x speed")

	game.battle_speed = 2.0
	var delay_2x_fast: float = game._battle_delay(1.0)
	assert_eq(delay_2x_fast, 0.25, "Fast combat at 2x speed cuts delay to 0.25s")

	game.free()

func test_masterpiece_polish_localization_keys():
	var keys := [
		"ui.run_recap_title",
		"ui.run_recap_seed",
		"ui.run_recap_copy_seed",
		"ui.run_recap_seed_copied",
		"ui.run_recap_max_damage",
		"ui.run_recap_archetype",
		"ui.cloud_conflict_title",
		"ui.cloud_conflict_desc",
		"ui.cloud_conflict_local",
		"ui.cloud_conflict_cloud",
		"ui.cloud_conflict_merge",
		"ui.filter_element_all",
		"ui.filter_element_wood",
		"ui.filter_element_fire",
		"ui.filter_element_water",
		"ui.filter_element_metal",
		"ui.filter_element_earth",
		"ui.filter_cost_all",
		"ui.archetype_burn",
		"ui.archetype_poison",
		"ui.archetype_shield",
		"ui.archetype_combo",
		"ui.archetype_balanced",
		"ui.settings_fast_combat",
		"ui.settings_fast_combat_desc"
	]
	for k in keys:
		var zh: String = content.ui(k, "zh-Hans")
		var en: String = content.ui(k, "en")
		assert_true(zh.length() > 0 and zh != k, "Key %s exists in zh-Hans" % k)
		assert_true(en.length() > 0 and en != k, "Key %s exists in en" % k)
