extends GutTest

# Test suite for Next-Gen Masterpiece Systems (10 Systems):
# 1. Card Mastery & Awakening Ascendancy
# 2. In-Battle Live Deck Odds Oracle
# 3. Boss Combat Barks & Dialogue Integrity
# 4. Cave Abode Herb Garden & Alchemy Cauldron
# 5. Physical Card 3D Inertial Tilt & Micro-Parallax
# 6. Endless Pagoda Demonic Soul Pacts
# 7. Adaptive Multi-Track Tension Audio
# 8. Thermal Eco Saver & 120 FPS Settings
# 9. Daoist Victory Scroll & Battle Tapestry
# 10. Weather & Elemental Battlefield Synergy

var content: SpiritContent

func before_all():
	content = SpiritContent.new()

func _test_encounter() -> Dictionary:
	return {
		"name": "测试妖王",
		"name_en": "Test Demon",
		"art_key": "m_s001",
		"health": 100,
		"damage": 10,
		"mechanics": {},
		"chapter": 1,
		"tier": 1
	}

func _find_card_in_hand(combat: SpiritCombat, card_id: String) -> int:
	for i in combat.state.hand.size():
		if combat.state.hand[i].card_id == card_id:
			return i
	combat.state.hand.append({"uid": 9999, "card_id": card_id})
	return combat.state.hand.size() - 1

# ------------------------------------------------------------------------------
# 1. Card Mastery & Awakening
# ------------------------------------------------------------------------------

func test_card_mastery_and_awakening():
	var p: Dictionary = SpiritSave.defaults(content)
	assert_eq(SpiritSave.get_card_mastery_tier(p, "strike"), 0, "Initial mastery tier is 0")
	assert_false(SpiritSave.is_card_awakened(p, "strike"), "Initial card is not awakened")

	SpiritSave.add_card_mastery(p, "strike", 10)
	assert_eq(SpiritSave.get_card_mastery_tier(p, "strike"), 1, "Tier 1 Initiate at >= 10 plays")

	SpiritSave.add_card_mastery(p, "strike", 20)
	assert_eq(SpiritSave.get_card_mastery_tier(p, "strike"), 2, "Tier 2 Adept at >= 30 plays")

	SpiritSave.add_card_mastery(p, "strike", 30)
	assert_eq(SpiritSave.get_card_mastery_tier(p, "strike"), 3, "Tier 3 Awakened at >= 60 plays")
	assert_true(SpiritSave.is_card_awakened(p, "strike"), "Card is now Awakened")

	# Test combat with awakened card
	var combat := SpiritCombat.new(content)
	var bonuses := {"awakened_cards": ["strike", "ward"]}
	combat.create(42, _test_encounter(), ["strike", "strike", "ward"], 60, {}, [], {}, {}, [], bonuses, {}, {}, {})

	# Awakened Strike: base damage 6 + 3 awakened bonus = 9
	var s_idx := _find_card_in_hand(combat, "strike")
	var init_enemy_hp: int = combat.state.enemies[0].health
	combat.play(s_idx, 0)
	var dealt: int = init_enemy_hp - combat.state.enemies[0].health
	assert_eq(dealt, 9, "Awakened strike deals 6 + 3 = 9 damage")

	# Awakened Ward: base shield 5 + 4 stats + 3 awakened bonus = 12, and Taiji shield retain flag set
	combat.state.energy = 3
	var prev_shield: int = combat.state.player.shield
	var w_idx := _find_card_in_hand(combat, "ward")
	combat.play(w_idx, 0)
	var shield_gained: int = combat.state.player.shield - prev_shield
	assert_eq(shield_gained, 12, "Awakened ward grants 12 shield (5 base + 4 stats + 3 awakened)")
	assert_eq(combat.state.get("taiji_retained_shield", 0), 3, "Taiji retained shield recorded")

# ------------------------------------------------------------------------------
# 2. In-Battle Live Deck Odds Oracle
# ------------------------------------------------------------------------------

func test_deck_oracle_hypergeometric_odds():
	var battle_screen_script = load("res://scripts/game_battle_screen.gd")

	# 10 cards total, 3 targets, drawing 5 cards
	# P(at least one target) = 1 - (7/10 * 6/9 * 5/8 * 4/7 * 3/6) = 1 - 0.0833 = ~0.9167
	var odds: float = battle_screen_script._hypergeom_at_least_one(10, 3, 5)
	assert_almost_eq(odds, 0.9167, 0.005, "Hypergeometric calculation matches expected probability")

	# Edge cases
	assert_eq(battle_screen_script._hypergeom_at_least_one(10, 0, 5), 0.0, "0 targets has 0 odds")
	assert_eq(battle_screen_script._hypergeom_at_least_one(10, 10, 5), 1.0, "All targets has 1.0 odds")
	assert_eq(battle_screen_script._hypergeom_at_least_one(0, 0, 5), 0.0, "Empty deck returns 0")

# ------------------------------------------------------------------------------
# 3. Boss Combat Barks & Dialogue Integrity
# ------------------------------------------------------------------------------

func test_boss_combat_barks_data():
	var barks: Dictionary = SpiritContent.BOSS_COMBAT_BARKS
	assert_true(barks.has("intro"), "Has intro barks")
	assert_true(barks.has("phase2"), "Has phase2 barks")
	assert_true(barks.has("heavy_hit"), "Has heavy hit barks")
	assert_true(barks.has("player_low_hp"), "Has player low HP barks")
	assert_true(barks.has("defeat"), "Has defeat barks")

	for category in barks:
		var entries: Array = barks[category]
		assert_gt(entries.size(), 0, "Category %s has barks" % category)
		for entry in entries:
			assert_gt(str(entry.get("zh", "")).length(), 0, "Bark has Chinese text")
			assert_gt(str(entry.get("en", "")).length(), 0, "Bark has English text")

# ------------------------------------------------------------------------------
# 4. Cave Abode Herb Garden & Alchemy Cauldron
# ------------------------------------------------------------------------------

func test_herb_garden_harvest_and_alchemy_crafting():
	var p: Dictionary = SpiritSave.defaults(content)
	var prev_lingzhi: int = int(p.herb_garden.purple_lingzhi)

	var harvested: Dictionary = SpiritSave.harvest_herbs(p)
	assert_gt(int(harvested.get("purple_lingzhi", 0)), 0, "Harvested purple lingzhi")
	assert_eq(int(p.herb_garden.purple_lingzhi), prev_lingzhi + 2, "Profile updated with harvested herbs")

	# Crafting Qi Gathering Pill (recipe: qi_pill)
	p.herb_garden.purple_lingzhi = 10
	p.herb_garden.sun_grass = 10
	var prev_pill_count: int = int(p.alchemy_pills.get("qi_pill", 0))
	var craft_ok: bool = SpiritSave.craft_pill(p, "qi_pill")
	assert_true(craft_ok, "Successfully crafted qi_pill")
	assert_eq(int(p.alchemy_pills.get("qi_pill", 0)), prev_pill_count + 1, "Pill inventory incremented")

	# Crafting with insufficient herbs
	p.herb_garden.purple_lingzhi = 0
	var craft_fail: bool = SpiritSave.craft_pill(p, "qi_pill")
	assert_false(craft_fail, "Fails to craft when herbs are missing")

	# In-battle pill consumption
	var combat := SpiritCombat.new(content)
	combat.create(42, _test_encounter(), ["strike"], 60, {}, [], {}, {}, [], {}, {}, {}, {})
	combat.state.energy = 0
	var used: bool = combat.use_alchemy_pill("qi_pill")
	assert_true(used, "Used qi_pill in combat")
	assert_eq(combat.state.energy, 2, "Qi pill restored 2 energy")
	assert_true(bool(combat.state.get("pill_used_this_combat", false)), "Pill marked as used this combat")

	# Only 1 pill allowed per combat
	var used_again: bool = combat.use_alchemy_pill("qi_pill")
	assert_false(used_again, "Cannot use second pill in same combat")

# ------------------------------------------------------------------------------
# 5. Endless Pagoda Demonic Soul Pacts
# ------------------------------------------------------------------------------

func test_pagoda_soul_pacts():
	var p: Dictionary = SpiritSave.defaults(content)
	assert_true(SpiritSave.bind_soul_pact(p, "asura_blood_pact"), "Bound Asura pact")
	assert_has(p.pagoda_soul_pacts, "asura_blood_pact", "Profile contains Asura pact")
	assert_false(SpiritSave.bind_soul_pact(p, "asura_blood_pact"), "Cannot double-bind same pact")

	# 1. Asura blood pact: max HP reduced by 25%, 20% leech on damage dealt
	var combat_asura := SpiritCombat.new(content)
	var asura_mod := {"pagoda_soul_pacts": ["asura_blood_pact"]}
	combat_asura.create(42, _test_encounter(), ["strike"], 60, {}, [], {}, asura_mod, [], {}, {}, {}, {})
	assert_eq(combat_asura.state.player.max_health, int(60 * 0.75), "Max HP reduced by 25%")

	combat_asura.state.player.health = 10
	var s_idx := _find_card_in_hand(combat_asura, "strike")
	combat_asura.play(s_idx, 0)
	assert_gt(combat_asura.state.player.health, 10, "Leech heals player on damage dealt")

	# 2. Ten Thousand Swords: 2x attack damage if no defense played
	var combat_swords := SpiritCombat.new(content)
	var swords_mod := {"pagoda_soul_pacts": ["ten_thousand_swords"]}
	combat_swords.create(42, _test_encounter(), ["strike"], 60, {}, [], {}, swords_mod, [], {}, {}, {}, {})
	var e_hp_start: int = combat_swords.state.enemies[0].health
	var sw_idx := _find_card_in_hand(combat_swords, "strike")
	combat_swords.play(sw_idx, 0)
	var swords_dmg: int = e_hp_start - combat_swords.state.enemies[0].health
	assert_eq(swords_dmg, 12, "Base 6 damage doubled to 12 by Ten Thousand Swords pact")

	# 3. Adamantine Body: retains full shield on turn end, all cards cost +1
	var combat_adam := SpiritCombat.new(content)
	var adam_mod := {"pagoda_soul_pacts": ["adamantine_body"]}
	combat_adam.create(42, _test_encounter(), ["ward"], 60, {}, [], {}, adam_mod, [], {}, {}, {}, {})
	combat_adam.state.player.shield = 20
	for e in combat_adam.state.enemies:
		e.damage = 0
		e.intent = {"kind": "defend", "amount": 5}
	combat_adam.end_turn()
	assert_eq(combat_adam.state.player.shield, 20, "Adamantine body retains all shield across turns")

# ------------------------------------------------------------------------------
# 6. Weather & Elemental Battlefield Synergy
# ------------------------------------------------------------------------------

func test_weather_synergies():
	# 1. Thunderstorm: bonus 3 piercing lightning damage with thunder element card
	var combat_storm := SpiritCombat.new(content)
	var storm_mod := {"weather_affix": "thunderstorm"}
	combat_storm.create(42, _test_encounter(), ["thunderclap"], 60, {}, [], {}, storm_mod, [], {}, {}, {}, {})
	var e_hp_init: int = combat_storm.state.enemies[0].health
	var tc_idx := _find_card_in_hand(combat_storm, "thunderclap")
	combat_storm.play(tc_idx, 0)
	assert_eq(e_hp_init - combat_storm.state.enemies[0].health, 6 + 3, "Thunderstorm adds +3 lightning damage")

	# 2. Rain: heals 2 HP when playing water card (frost_surge)
	var combat_rain := SpiritCombat.new(content)
	var rain_mod := {"weather_affix": "rain"}
	combat_rain.create(42, _test_encounter(), ["frost_surge"], 60, {}, [], {}, rain_mod, [], {}, {}, {}, {})
	combat_rain.state.player.health = 20
	var fs_idx := _find_card_in_hand(combat_rain, "frost_surge")
	combat_rain.play(fs_idx, 0)
	assert_eq(combat_rain.state.player.health, 22, "Rain heals 2 HP on water/wood card play")

	# 3. Fog: start battle with 1 stack of Fog Veil (evade first hit)
	var combat_fog := SpiritCombat.new(content)
	var fog_mod := {"weather_affix": "fog"}
	combat_fog.create(42, _test_encounter(), ["strike"], 60, {}, [], {}, fog_mod, [], {}, {}, {}, {})
	assert_eq(combat_fog.state.get("player_fog_veil", 0), 1, "Player has 1 stack of Fog Veil at battle start")

# ------------------------------------------------------------------------------
# 7. Performance & Eco Mode Settings
# ------------------------------------------------------------------------------

func test_performance_and_eco_settings():
	var p: Dictionary = SpiritSave.defaults(content)
	assert_eq(p.get("target_fps", 60), 60, "Default FPS is 60")
	assert_false(p.get("eco_mode", false), "Default Eco mode is false")

	SpiritSave.set_target_fps(p, 120)
	assert_eq(p.target_fps, 120, "Target FPS set to 120")

	SpiritSave.set_eco_mode(p, true)
	assert_true(p.eco_mode, "Eco mode set to true")

# ------------------------------------------------------------------------------
# 8. Currency Display: Contextual Currency Display Across Screens
# ------------------------------------------------------------------------------

func test_contextual_currency_display_across_screens():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.profile.spirit_dust = 0 # Ensure dust is 0
	add_child_autofree(g)

	# 1. Map Header ("SPIRITBOUND"): exactly 4 currency pills (Gold, Jade, Stamina, Dust)
	var map_hdr: HBoxContainer = g._header("SPIRITBOUND", "")
	add_child_autofree(map_hdr)
	var gold_row: BoxContainer = map_hdr.find_child("HeaderGoldRow", true, false) as BoxContainer
	assert_not_null(gold_row, "HeaderGoldRow exists on map")
	assert_eq(gold_row.get_child_count(), 4, "Map header displays exactly 4 currencies (Gold, Jade, Stamina, Dust)")
	assert_not_null(gold_row.find_child("HeaderDustPill", true, false), "Dust pill is shown on map")

	# 2. Shop Header: 3 currencies (Gold, Jade, Dust) - Dust is used for exchange/crafting in shop!
	var shop_hdr: HBoxContainer = g._header(g.t("ui.shop_title"), "Store", func(): pass)
	add_child_autofree(shop_hdr)
	var shop_box: BoxContainer = shop_hdr.find_child("HeaderStatsBox", true, false) as BoxContainer
	assert_not_null(shop_box, "HeaderStatsBox exists on shop")
	assert_eq(shop_box.get_child_count(), 3, "Shop header displays 3 currencies (Gold, Jade, Dust)")
	assert_not_null(shop_box.find_child("HeaderDustPill", true, false), "Dust pill is shown in shop")
	assert_null(shop_box.find_child("HeaderStaminaPill", true, false), "Stamina pill is NOT in shop")

	# 3. Camp Header: 4 currencies (Gold, Jade, Stamina, Dust) - all 4 make sense in camp!
	var camp_hdr: HBoxContainer = g._header(g.t("ui.camp_title"), "Camp", func(): pass)
	add_child_autofree(camp_hdr)
	var camp_box: BoxContainer = camp_hdr.find_child("HeaderStatsBox", true, false) as BoxContainer
	assert_not_null(camp_box, "HeaderStatsBox exists on camp")
	assert_eq(camp_box.get_child_count(), 4, "Camp header displays 4 currencies (Gold, Jade, Stamina, Dust)")
	assert_not_null(camp_box.find_child("HeaderDustPill", true, false), "Dust pill is shown in camp")
	assert_not_null(camp_box.find_child("HeaderStaminaPill", true, false), "Stamina pill is shown in camp")

	# 4. Quests Header: 3 currencies (Gold, Jade, Stamina)
	var quests_hdr: HBoxContainer = g._header(g.t("ui.quests_title"), "Quests", func(): pass)
	add_child_autofree(quests_hdr)
	var quests_box: BoxContainer = quests_hdr.find_child("HeaderStatsBox", true, false) as BoxContainer
	assert_not_null(quests_box, "HeaderStatsBox exists on quests")
	assert_eq(quests_box.get_child_count(), 3, "Quests header displays 3 currencies (Gold, Jade, Stamina)")
	assert_not_null(quests_box.find_child("HeaderStaminaPill", true, false), "Stamina pill is shown in quests")
	assert_null(quests_box.find_child("HeaderDustPill", true, false), "Dust pill is NOT in quests")

# 9. Account Sign Out: Bound vs Guest Progress
# ------------------------------------------------------------------------------

func test_account_sign_out_bound_vs_guest():
	var g := SpiritGame.new()
	g.content = content
	add_child_autofree(g)
	g.profile = SpiritSave.defaults(content)
	g.profile.gold = 500

	# Scenario A: Pure guest signs out -> progress is preserved
	SpiritAuth.sign_out(g)
	assert_eq(int(g.profile.gold), 500, "Guest profile progress is retained on sign out")

	# Scenario B: Cloud-linked account signs out -> profile resets to defaults for new account
	SpiritSave.link_account(g.profile, "google", "goog_12345", "test@gmail.com", "Tester")
	assert_true(SpiritSave.is_cloud_linked(g.profile), "Account is now cloud-linked")
	g.profile.gold = 9999

	SpiritAuth.sign_out(g)
	assert_false(SpiritSave.is_cloud_linked(g.profile), "Account is unlinked after sign out")
	assert_eq(int(g.profile.gold), 30, "Cloud-linked account progress is reset to starter defaults (30 gold) so new login starts clean")

# 10. Camp Screen UI Layout & Scrollbar Styling
# ------------------------------------------------------------------------------

func test_camp_screen_layout_and_scrollbar_styling():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	add_child_autofree(g)

	# Test TouchScrollContainer non-blocking styling
	var scroll := TouchScrollContainer.new()
	add_child_autofree(scroll)
	var v_bar := scroll.get_v_scroll_bar()
	assert_not_null(v_bar, "VScrollBar exists on TouchScrollContainer")
	assert_eq(v_bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "VScrollBar does not intercept or block touches")

	# Test Camp screen sections layout
	var camp_scr := CampScreen.new(g)
	var titles_sec: Control = camp_scr._prestige_titles_section()
	add_child_autofree(titles_sec)
	var grid: GridContainer = titles_sec.find_child("GridContainer", true, false) as GridContainer
	if grid == null:
		for c in titles_sec.find_children("*", "GridContainer", true, false):
			grid = c as GridContainer
			break
	assert_not_null(grid, "Prestige titles uses GridContainer to prevent horizontal overflow")
	assert_eq(grid.columns, 3, "Prestige titles uses 3 columns")

	var garden_sec: Control = camp_scr._sanctuary_garden_section()
	add_child_autofree(garden_sec)
	var pet_btn: Button = garden_sec.find_child("PetFamiliarBtn", true, false) as Button
	assert_not_null(pet_btn, "PetFamiliarBtn exists in sanctuary garden")
	assert_eq(pet_btn.get_theme_font_size("font_size"), 10, "Familiar buttons use compact font size to avoid overflow")
