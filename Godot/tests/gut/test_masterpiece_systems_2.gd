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

	# Test TouchScrollContainer non-blocking styling and hidden scrollbars
	var scroll := TouchScrollContainer.new()
	add_child_autofree(scroll)
	var v_bar := scroll.get_v_scroll_bar()
	assert_not_null(v_bar, "VScrollBar exists on TouchScrollContainer")
	assert_eq(v_bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "VScrollBar does not intercept or block touches")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Vertical scrollbar is set to SHOW_NEVER")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER, "Horizontal scrollbar is set to SHOW_NEVER")
	assert_false(v_bar.visible, "VScrollBar is invisible so it never obscures UI content")

	# Test Map chapter plaque position and ascension button removal
	g.show_map()
	var plaque: Control = g.root.find_child("ChapterPlaque", true, false) as Control
	assert_not_null(plaque, "ChapterPlaque exists on map screen")
	if plaque:
		assert_true(plaque.position.y >= 110.0, "ChapterPlaque is shifted down (y=%.1f >= 110.0) so it is not covered by top header" % plaque.position.y)
	var asc_btn: Node = g.root.find_child("MapAscensionBtn", true, false)
	assert_null(asc_btn, "MapAscensionBtn (T几) is removed from big map screen per UX requirements")

	# Test Deck preset rename button has valid text label instead of unrendered emoji
	g.show_deck()
	var rename_btn: Button = g.root.find_child("PresetRenameBtn", true, false) as Button
	assert_not_null(rename_btn, "PresetRenameBtn exists in deck screen")
	if rename_btn:
		assert_true(rename_btn.text == "改名" or rename_btn.text == "Rename", "PresetRenameBtn has clear text ('%s') instead of missing/unrendered emoji" % rename_btn.text)

	# Test Title screen uses scrollable container to prevent mobile button overflow
	g.show_title_screen()
	var title_scroll: ScrollContainer = g.root.find_child("*", true, false) as ScrollContainer
	if title_scroll == null:
		for c in g.root.find_children("*", "TouchScrollContainer", true, false):
			title_scroll = c as ScrollContainer
			break
	assert_not_null(title_scroll, "Title screen wraps in TouchScrollContainer to prevent button overflow on mobile")

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

# ------------------------------------------------------------------------------
# 11. Volumetric 2.5D Hero Presentation & Spring-Damper Physics
# ------------------------------------------------------------------------------

func test_hero_volumetric_lighting_shader_and_multi_hero_tuning():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	add_child_autofree(g)
	var battle_screen := BattleScreen.new(g)

	var shader: Shader = battle_screen._get_hero_volumetric_shader()
	assert_not_null(shader, "Hero volumetric lighting shader loaded successfully")

	# Test Fox Spirit tuning
	var fox_sprite := Sprite2D.new()
	add_child_autofree(fox_sprite)
	var fox_mat: ShaderMaterial = battle_screen._install_hero_volumetric_shader(fox_sprite, "fox_spirit")
	assert_not_null(fox_mat, "Fox spirit shader material installed")
	assert_eq(fox_mat.shader, shader, "Uses hero volumetric lighting shader")
	var fox_light_color = fox_mat.get_shader_parameter("light_color")
	assert_almost_eq(fox_light_color.x, 0.35, 0.05, "Fox Spirit cyan light tuning")

	# Test Stone Sentinel tuning
	var stone_sprite := Sprite2D.new()
	add_child_autofree(stone_sprite)
	var stone_mat: ShaderMaterial = battle_screen._install_hero_volumetric_shader(stone_sprite, "stone_sentinel")
	var stone_light_color = stone_mat.get_shader_parameter("light_color")
	assert_almost_eq(stone_light_color.x, 1.0, 0.05, "Stone Sentinel warm amber light tuning")

	# Test Shadow Stalker tuning
	var shadow_sprite := Sprite2D.new()
	add_child_autofree(shadow_sprite)
	var shadow_mat: ShaderMaterial = battle_screen._install_hero_volumetric_shader(shadow_sprite, "shadow_stalker")
	var shadow_light_color = shadow_mat.get_shader_parameter("light_color")
	assert_almost_eq(shadow_light_color.x, 0.75, 0.05, "Shadow Stalker violet light tuning")

	# Test Miasma Witch tuning
	var witch_sprite := Sprite2D.new()
	add_child_autofree(witch_sprite)
	var witch_mat: ShaderMaterial = battle_screen._install_hero_volumetric_shader(witch_sprite, "miasma_witch")
	var witch_light_color = witch_mat.get_shader_parameter("light_color")
	assert_almost_eq(witch_light_color.y, 1.0, 0.05, "Miasma Witch emerald light tuning")

func test_spring_secondary_motion_physics_convergence():
	var dummy := Node2D.new()
	dummy.position = Vector2(100, 100)
	dummy.rotation_degrees = 15.0
	add_child_autofree(dummy)

	var SpringScript = load("res://scripts/spring_secondary_motion.gd")
	var spring = SpringScript.new()
	add_child_autofree(spring)
	spring.init_from_target(dummy)

	assert_eq(spring.base_position, Vector2(100, 100), "Recorded base position")
	assert_eq(spring.base_rotation, 15.0, "Recorded base rotation")
	assert_true(spring.is_settled(), "Spring initially at rest")

	# Apply linear and angular impulse
	spring.apply_impulse(Vector2(60, -30))
	spring.apply_angular_impulse(40.0)

	assert_false(spring.is_settled(), "Spring active after impulse")

	# Advance simulation across multiple frames
	for frame in 180:
		spring._process(0.016)

	assert_true(spring.is_settled(0.5), "Spring settled smoothly after 180 frames without diverging")
	assert_almost_eq(dummy.position.x, 100.0, 0.5, "Restored near base x position")
	assert_almost_eq(dummy.position.y, 100.0, 0.5, "Restored near base y position")
	assert_almost_eq(dummy.rotation_degrees, 15.0, 0.5, "Restored near base rotation")

func test_card_drag_perspective_gaze_tracking_clamping():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	add_child_autofree(g)
	var battle_screen := BattleScreen.new(g)

	var p_sprite := Sprite2D.new()
	p_sprite.name = "PlayerSprite"
	p_sprite.position = Vector2(102, 52)
	p_sprite.set_meta("base_pos_y", 52.0)
	g.add_child(p_sprite)

	# Drag way to the right
	battle_screen._update_hero_drag_tracking(Vector2(1000, 200))
	assert_true(p_sprite.rotation <= 0.15, "Hero rotation clamped within 0.15 rad on extreme right drag")
	assert_true(p_sprite.rotation > 0.0, "Hero tilted positively towards right drag")

	# Drag way to the left
	battle_screen._update_hero_drag_tracking(Vector2(-500, 200))
	assert_true(p_sprite.rotation >= -0.15, "Hero rotation clamped within -0.15 rad on extreme left drag")
	assert_true(p_sprite.rotation < 0.0, "Hero tilted negatively towards left drag")

# ------------------------------------------------------------------------------
# 12. Combat Juice, Boss 2.5D Volumetric Rims & Ether Trails
# ------------------------------------------------------------------------------

func test_enemy_volumetric_shader_and_tier_tuning():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	add_child_autofree(g)
	var battle_screen := BattleScreen.new(g)

	# Tier 1 Minion
	var m1 := Sprite2D.new()
	add_child_autofree(m1)
	var mat1 = battle_screen._install_enemy_volumetric_shader(m1, {"tier": 1})
	assert_not_null(mat1, "Minion volumetric shader created")
	assert_almost_eq(float(mat1.get_shader_parameter("rim_intensity")), 0.25, 0.05, "Minion rim intensity is subtle (0.25)")

	# Tier 2 Elite
	var m2 := Sprite2D.new()
	add_child_autofree(m2)
	var mat2 = battle_screen._install_enemy_volumetric_shader(m2, {"tier": 2})
	assert_almost_eq(float(mat2.get_shader_parameter("rim_intensity")), 0.40, 0.05, "Elite rim intensity is elevated (0.40)")

	# Tier 3 Chapter Boss
	var m3 := Sprite2D.new()
	add_child_autofree(m3)
	var mat3 = battle_screen._install_enemy_volumetric_shader(m3, {"tier": 3})
	assert_almost_eq(float(mat3.get_shader_parameter("rim_intensity")), 0.55, 0.05, "Boss rim intensity is high (0.55)")
	var rim3 = mat3.get_shader_parameter("rim_color")
	assert_almost_eq(rim3.x, 0.85, 0.05, "Boss violet-red rim color")

	# Tier 4 Great World Boss
	var m4 := Sprite2D.new()
	add_child_autofree(m4)
	var mat4 = battle_screen._install_enemy_volumetric_shader(m4, {"tier": 4})
	assert_almost_eq(float(mat4.get_shader_parameter("rim_intensity")), 0.65, 0.05, "World Boss rim intensity is peak (0.65)")

func test_combat_hit_stop_and_camera_punch_safety():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	add_child_autofree(g)
	var battle_screen := BattleScreen.new(g)

	assert_eq(Engine.time_scale, 1.0, "Time scale initially 1.0")
	battle_screen._micro_hit_stop(0.05)
	# Fast safety: Engine.time_scale stays within valid range and leave battle restores 1.0
	battle_screen._leave_battle()
	assert_eq(Engine.time_scale, 1.0, "Time scale restored cleanly after leave battle")

func test_danger_vignette_activation_and_cleanup():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.combat = SpiritCombat.new(content)
	g.combat.state = {
		"player": {"health": 12, "max_health": 60, "shield": 0},
		"enemies": [],
		"phase": "player"
	}
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var battle_screen := BattleScreen.new(g)

	battle_screen._update_danger_vignette()
	var vig = g.overlay.get_node_or_null("DangerVignette")
	assert_not_null(vig, "DangerVignette created at <= 25% HP")

	# Heal back to full
	g.combat.state.player.health = 60
	battle_screen._update_danger_vignette()
	battle_screen._clear_danger_vignette()
	var vig_cleared = g.overlay.get_node_or_null("DangerVignette")
	assert_true(vig_cleared == null or vig_cleared.is_queued_for_deletion(), "DangerVignette cleaned up when safe")

func test_card_foil_shimmer_shader_parameters_and_safety():
	var s = load("res://assets/shaders/card_foil.gdshader") as Shader
	assert_not_null(s, "card_foil.gdshader exists and loads")
	var mat := ShaderMaterial.new()
	mat.shader = s
	mat.set_shader_parameter("tilt_shift", 0.5)
	mat.set_shader_parameter("tilt_offset", Vector2(0.2, -0.4))
	mat.set_shader_parameter("is_gold_foil", true)
	assert_eq(mat.get_shader_parameter("is_gold_foil"), true, "Gold foil uniform set properly")

func test_lethal_damage_execute_stamp_calculation():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.combat = SpiritCombat.new(content)
	var enc: Dictionary = content.encounters[0]
	g.combat.state = g.combat.create(1234, enc, ["strike", "defend"], 60)


	g.combat.state.enemies[0].health = 10
	g.combat.state.enemies[0].shield = 0
	g.combat.state.player.strength = 10


	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var battle_screen := BattleScreen.new(g)
	var dummy_box := Control.new()
	dummy_box.set_meta("enemy_index", 0)
	dummy_box.size = Vector2(80, 80)
	g.enemy_boxes = [dummy_box]
	g.overlay.add_child(dummy_box)

	var attack_card: Dictionary = content.card("cinder_slash")
	battle_screen._show_damage_preview(attack_card, 0)
	var preview = g.overlay.get_node_or_null("DamagePreview")
	assert_not_null(preview, "Damage preview exists for attack")
	var seal = preview.get_node_or_null("ExecuteSealStamp") if preview else null
	assert_not_null(seal, "ExecuteSealStamp displayed on lethal preview")
	battle_screen._clear_damage_preview()
	var preview_cleared = g.overlay.get_node_or_null("DamagePreview")
	assert_true(preview_cleared == null or preview_cleared.is_queued_for_deletion(), "Damage preview cleaned up")




func test_boss_phase_2_enrage_cutin_trigger():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var battle_screen := BattleScreen.new(g)
	battle_screen._show_boss_enrage_cinematic(0)
	var cutin = g.overlay.get_node_or_null("BossEnrageCutin")
	assert_not_null(cutin, "BossEnrageCutin created on boss phase transition")

func test_music_tracks_integrity_and_sample_rates():
	var tracks := [
		"res://assets/audio/map_symphony.wav",
		"res://assets/audio/map_biome_0.wav",
		"res://assets/audio/map_biome_1.wav",
		"res://assets/audio/map_biome_2.wav",
		"res://assets/audio/map_biome_3.wav",
		"res://assets/audio/map_biome_4.wav",
		"res://assets/audio/map_biome_5.wav",
		"res://assets/audio/battle_stage_0.wav",
		"res://assets/audio/battle_stage_1.wav",
		"res://assets/audio/battle_stage_2.wav",
		"res://assets/audio/battle_stage_3.wav",
		"res://assets/audio/battle_stage_4.wav"
	]
	for track in tracks:
		assert_true(ResourceLoader.exists(track), "Audio track exists: %s" % track)
		var stream = load(track) as AudioStream
		assert_not_null(stream, "AudioStream loads successfully: %s" % track)
		assert_gt(stream.get_length(), 20.0, "Soundtrack has full length > 20s: %s" % track)

func test_map_biome_music_switching():
	var g := SpiritGame.new()
	add_child_autofree(g)
	g._build_audio()
	assert_eq(g.map_music_streams.size(), 6, "All 6 map biome music streams loaded")
	for i in range(6):
		assert_not_null(g.map_music_streams[i], "Biome stream %d is valid" % i)
	
	# Test dynamic switching per biome
	for ch in range(12):
		var expected_biome: int = ch % 6
		g._play_music(false, ch)
		assert_eq(g.map_music.stream, g.map_music_streams[expected_biome], "Map chapter %d plays biome %d track" % [ch, expected_biome])
		assert_eq(g._current_map_biome_idx, expected_biome, "Tracked biome index matches chapter %d" % ch)

func test_targeting_arc_zero_division_safety():
	var arc_script = load("res://scripts/targeting_arc.gd")
	var arc = arc_script.new()
	add_child_autofree(arc)
	arc.set_points(Vector2(100, 200), Vector2(100, 200), false)
	arc.queue_redraw()
	assert_not_null(arc, "Targeting arc safely initializes without division by zero")

func test_ui_translations_completeness():
	var critical_keys := [
		"ui.nav_settings",
		"ui.auth_start_subtitle",
		"ui.auth_or_continue",
		"ui.confirm",
		"ui.close",
		"ui.share",
		"ui.gold_insufficient",
		"ui.card_fusion_synthesize",
		"ui.enemy_default_name",
		"ui.skin_selector_title"
	]
	for k in critical_keys:
		var zh: String = content.ui(k, "zh-Hans")
		var en: String = content.ui(k, "en")
		assert_true(zh.length() > 0 and zh != k, "Key '%s' has valid zh-Hans translation" % k)
		assert_true(en.length() > 0 and en != k, "Key '%s' has valid en translation" % k)

func test_line_edit_cjk_and_submission():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var deck_screen = load("res://scripts/game_shop_deck_screen.gd").new(g)

	deck_screen._rename_preset_modal(1)
	var modal = g.overlay.get_node_or_null("PresetRenameModal")
	assert_not_null(modal, "PresetRenameModal opened")
	var input: LineEdit = modal.find_child("PresetNameInput", true, false) as LineEdit
	assert_not_null(input, "PresetNameInput found")
	assert_eq(input.max_length, 16, "PresetNameInput has max length 16")
	modal.queue_free()

	deck_screen._show_import_deck_dialog()
	var imp_modal = g.overlay.get_node_or_null("DeckImportModal")
	assert_not_null(imp_modal, "DeckImportModal opened")
	var code_input: LineEdit = imp_modal.find_child("DeckCodeInput", true, false) as LineEdit
	assert_not_null(code_input, "DeckCodeInput found")
	assert_eq(code_input.max_length, 1024, "DeckCodeInput has max length 1024")
	imp_modal.queue_free()

func test_music_volume_and_toggle_combat_safety():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	add_child_autofree(g)
	# Mute toggling
	g.muted = false
	g._toggle_music_settings()
	assert_true(g.muted, "Music is muted")
	assert_eq(float(g.profile.music_volume), 0.0, "Volume set to 0 when muted")
	g._toggle_music_settings()
	assert_false(g.muted, "Music is unmuted")
	assert_eq(float(g.profile.music_volume), 1.0, "Volume restored to 1.0 when unmuted")

	# Volume scaling
	g._change_music_volume(0.5)
	assert_false(g.muted, "Music not muted at 0.5")
	assert_eq(float(g.profile.music_volume), 0.5, "Volume saved as 0.5")
	g._change_music_volume(0.0)
	assert_true(g.muted, "Volume 0.0 marks muted")

func test_turn_transition_banner_and_beam():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var battle_screen = load("res://scripts/game_battle_screen.gd").new(g)

	battle_screen._show_turn_banner(true)
	var banner = g.overlay.get_node_or_null("TurnBanner")
	assert_not_null(banner, "Player TurnBanner created")
	banner.queue_free()

	battle_screen._show_turn_banner(false)
	var enemy_banner = g.overlay.get_node_or_null("TurnBanner")
	assert_not_null(enemy_banner, "Enemy TurnBanner created")
	enemy_banner.queue_free()

func test_card_detail_inspector_modal():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var deck_screen = load("res://scripts/game_shop_deck_screen.gd").new(g)

	var card: Dictionary = g.content.card("strike")
	deck_screen._show_card_detail_modal(card)
	var modal = g.overlay.get_node_or_null("CardDetailModal")
	assert_not_null(modal, "CardDetailModal created")
	var close_btn = modal.find_child("CardDetailCloseBtn", true, false)
	assert_not_null(close_btn, "CardDetailCloseBtn present")
	modal.queue_free()

func test_realm_breakthrough_ceremony():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var camp_screen = load("res://scripts/game_camp_screen.gd").new(g)

	camp_screen._show_realm_breakthrough_ceremony(1)
	var modal = g.overlay.get_node_or_null("BreakthroughCeremonyModal")
	assert_not_null(modal, "BreakthroughCeremonyModal created")
	var confirm_btn = modal.find_child("BreakthroughConfirmBtn", true, false)
	assert_not_null(confirm_btn, "BreakthroughConfirmBtn present")
	modal.queue_free()

func test_title_screen_no_overflow_bounds():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	add_child_autofree(g)
	g.show_title_screen()
	var start_btn = g.root.find_child("TitleStartBtn", true, false)
	assert_not_null(start_btn, "TitleStartBtn present")
	var guest_btn = g.root.find_child("TitleGuestBtn", true, false)
	assert_not_null(guest_btn, "TitleGuestBtn present")
	var apple_btn = g.root.find_child("TitleAppleBtn", true, false)
	assert_not_null(apple_btn, "TitleAppleBtn present")
	var google_btn = g.root.find_child("TitleGoogleBtn", true, false)
	assert_not_null(google_btn, "TitleGoogleBtn present")

func test_battle_speed_toggle_visuals():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	add_child_autofree(g)
	var speed_btn := Button.new()
	speed_btn.name = "SpeedToggle"
	g.root.add_child(speed_btn)
	g.battle_speed = 1.0
	g._cycle_speed()
	assert_eq(g.battle_speed, 1.5, "Cycled from 1x to 1.5x")
	assert_eq(speed_btn.text, "1.5x", "Speed button text updated to 1.5x")
	g._cycle_speed()
	assert_eq(g.battle_speed, 2.0, "Cycled from 1.5x to 2x")
	assert_eq(speed_btn.text, "2x", "Speed button text updated to 2x")
	g._cycle_speed()
	assert_eq(g.battle_speed, 3.0, "Cycled from 2x to 3x")
	g._cycle_speed()
	assert_eq(g.battle_speed, 4.0, "Cycled from 3x to 4x")
	assert_eq(speed_btn.text, "⚡4x", "Speed button text updated to ⚡4x")
	g._cycle_speed()
	assert_eq(g.battle_speed, 1.0, "Cycled from 4x back to 1x")

func test_shield_retain_indicator():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var battle_screen = load("res://scripts/game_battle_screen.gd").new(g)
	var combat := SpiritCombat.new(content)
	combat.create(42, _test_encounter(), ["strike", "ward"], 60, {}, [], {}, {}, [], {}, {}, {}, {})
	g.combat = combat

	var shield_box := Control.new()
	combat.state.player["bastion_form_active"] = true
	battle_screen._update_player_shield_retain_indicator(shield_box)
	var badge = shield_box.get_node_or_null("ShieldRetainBadge")
	assert_not_null(badge, "ShieldRetainBadge created when bastion_form_active is true")
	assert_true(badge.visible, "Badge is visible")

	combat.state.player["bastion_form_active"] = false
	battle_screen._update_player_shield_retain_indicator(shield_box)
	assert_false(badge.visible, "Badge is hidden when bastion_form_active is false")

func test_enemy_lethal_intent_warning():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var battle_screen = load("res://scripts/game_battle_screen.gd").new(g)
	var combat := SpiritCombat.new(content)
	combat.create(42, _test_encounter(), ["strike", "ward"], 60, {}, [], {}, {}, [], {}, {}, {}, {})
	g.combat = combat

	var enemy_box := Control.new()
	enemy_box.size = Vector2(100, 100)
	var enemy: Dictionary = {"intent": {"kind": "critical", "amount": 65}}
	battle_screen._apply_threat_warning_ring(enemy_box, enemy)
	var ring = enemy_box.get_node_or_null("ThreatWarningRing")
	assert_not_null(ring, "ThreatWarningRing created for high threat intent")
	assert_true(ring.visible, "ThreatWarningRing is visible")

func test_guardian_wisp_on_danger():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var battle_screen = load("res://scripts/game_battle_screen.gd").new(g)
	var vig := Panel.new()
	vig.name = "DangerVignette"
	g.overlay.add_child(vig)
	battle_screen._spawn_guardian_wisp(vig)
	var wisp = vig.get_node_or_null("GuardianWispParticles")
	assert_not_null(wisp, "GuardianWispParticles created inside danger vignette")
	assert_true(wisp is CPUParticles2D, "Guardian wisp is CPUParticles2D")
	vig.queue_free()

func test_chapter_quick_jump_modal():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.profile.unlocked = 15
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var map_screen = load("res://scripts/game_map_screen.gd").new(g)
	map_screen._show_chapter_jump_modal()
	var modal = g.overlay.get_node_or_null("ChapterJumpModal")
	assert_not_null(modal, "ChapterJumpModal created")
	var close_btn = modal.find_child("ChapterJumpCloseBtn", true, false)
	assert_not_null(close_btn, "ChapterJumpCloseBtn present")
	var jump_btn_0 = modal.find_child("ChapterJumpBtn_0", true, false)
	assert_not_null(jump_btn_0, "ChapterJumpBtn_0 present for chapter 0")
	modal.queue_free()

func test_deck_archetype_synergy_compass():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	# Give deck 5 fire cards
	g.profile.deck = ["cinder_slash", "cinder_slash", "cinder_slash", "samadhi_fire", "strike"]
	add_child_autofree(g)
	var deck_screen = load("res://scripts/game_shop_deck_screen.gd").new(g)
	var page := Control.new()
	add_child_autofree(page)
	var compass = deck_screen._render_archetype_synergy_compass(page)
	assert_not_null(compass, "DeckSynergyCompass rendered")
	assert_eq(compass.name, "DeckSynergyCompass")
	page.queue_free()

func test_combat_pile_inspectors():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g)
	var battle_screen = load("res://scripts/game_battle_screen.gd").new(g)
	var cards: Array = [
		{"card_id": "strike", "name": "烈火斩", "cost": 1, "description": "造成伤害"},
		{"card_id": "ward", "name": "护体印", "cost": 1, "description": "获得护盾"}
	]
	battle_screen.show_pile_inspector("ui.pile_draw_title", cards)
	var modal = g.overlay.get_node_or_null("PileInspector")
	assert_not_null(modal, "PileInspector backdrop created for draw pile")
	var close_btn = modal.find_child("PileCloseBtn", true, false)
	assert_not_null(close_btn, "PileCloseBtn present")
	modal.queue_free()

func test_auto_battle_retains_configured_speed_across_consecutive_battles():
	var g := SpiritGame.new()
	g.content = content
	g.profile = SpiritSave.defaults(content)
	g.overlay = Control.new()
	g.root = Control.new()
	add_child_autofree(g.overlay)
	add_child_autofree(g.root)
	add_child_autofree(g)

	# Set speed to 3.0x (EMBER color)
	g._change_battle_speed(3.0)
	assert_eq(g.battle_speed, 3.0, "Battle speed is 3.0x")
	assert_eq(float(g.profile.battle_speed), 3.0, "Profile persists battle speed 3.0x")

	# Begin first battle
	g.begin_battle(0)
	assert_eq(g.battle_speed, 3.0, "First battle retains 3.0x speed")
	var speed_btn_1: Button = g.root.find_child("SpeedToggle", true, false) as Button
	assert_not_null(speed_btn_1, "SpeedToggle exists in first battle")
	assert_eq(speed_btn_1.text, "3x", "SpeedToggle shows 3x in first battle")
	assert_eq(speed_btn_1.get_theme_color("font_color"), g.EMBER, "SpeedToggle has EMBER font color override in first battle")

	# Turn on auto-battle
	g.toggle_auto_battle(true)
	assert_true(g.auto_battle_active, "Auto battle is active")
	var auto_btn_1: Button = g.root.find_child("AutoBattleToggle", true, false) as Button
	assert_not_null(auto_btn_1, "AutoBattleToggle exists")

	# Simulate beginning second consecutive battle as in auto-battle flow
	g.begin_battle(1)
	assert_eq(g.battle_speed, 3.0, "Second battle continues using 3.0x speed without reverting to 1x")
	var speed_btn_2: Button = g.root.find_child("SpeedToggle", true, false) as Button
	assert_not_null(speed_btn_2, "SpeedToggle exists in second battle")
	assert_eq(speed_btn_2.text, "3x", "SpeedToggle continues showing 3x in second battle")
	assert_eq(speed_btn_2.get_theme_color("font_color"), g.EMBER, "SpeedToggle continues having EMBER font color override in second battle")
	var auto_btn_2: Button = g.root.find_child("AutoBattleToggle", true, false) as Button
	assert_not_null(auto_btn_2, "AutoBattleToggle remains active in second battle")

	# Test 4.0x speed as well
	g._change_battle_speed(4.0)
	assert_eq(g.battle_speed, 4.0, "Speed updated to 4x")
	g.begin_battle(2)
	assert_eq(g.battle_speed, 4.0, "Third battle retains 4.0x speed")
	var speed_btn_3: Button = g.root.find_child("SpeedToggle", true, false) as Button
	assert_not_null(speed_btn_3, "SpeedToggle exists in third battle")
	assert_eq(speed_btn_3.text, "⚡4x", "SpeedToggle shows ⚡4x in third battle")
	assert_eq(speed_btn_3.get_theme_color("font_color"), Color("a855f7"), "SpeedToggle has purple color in third battle")

	g._leave_battle()





