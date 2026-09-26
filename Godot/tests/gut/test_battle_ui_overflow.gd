extends GutTest

# ==============================================================================
# Tests for Battle UI Layout & Overflow Prevention Across Languages (ZH & EN)
# ==============================================================================

var content: SpiritContent

func before_all():
	content = SpiritContent.new()

func _create_game(lang := "zh-Hans") -> SpiritGame:
	var g := SpiritGame.new()
	g.content = content
	g.lang = lang
	g.profile = SpiritSave.defaults(content)
	g.root = Control.new()
	g.root.custom_minimum_size = Vector2(390, 844)
	g.root.size = g.root.custom_minimum_size
	g.overlay = Control.new()
	g.overlay.custom_minimum_size = Vector2(390, 844)
	g.overlay.size = g.overlay.custom_minimum_size
	g.add_child(g.root)
	g.add_child(g.overlay)
	return g

# ------------------------------------------------------------------------------
# 1. Top Header Row: Truncation & Badges Sub-Row Never Exceed Screen Width (366px)
# ------------------------------------------------------------------------------

func test_top_header_never_overflows_in_chinese_and_english():
	for lang in ["zh-Hans", "en"]:
		var game := _create_game(lang)
		# Test with high chapter stage with long name
		game.profile.win_streak = 8
		game.current_stage = 4 # Boss stage
		game.begin_battle(4)

		# Add weather affix and combo count to trigger all badge widgets
		game.combat.state["weather_affix"] = "solar"
		game.combat.state["turn_combo_count"] = 4
		game.show_battle()

		var speed_btn: Control = game.root.find_child("SpeedToggle", true, false)
		var auto_btn: Control = game.root.find_child("AutoBattleToggle", true, false)
		var streak_badge: Control = game.root.find_child("BattleWinStreakBadge", true, false)
		var weather_badge: Control = game.root.find_child("BattleWeatherBadge", true, false)
		var combo_badge: Control = game.root.find_child("ComboMeterBadge", true, false)

		assert_not_null(speed_btn, "[%s] SpeedToggle exists" % lang)
		assert_not_null(auto_btn, "[%s] AutoBattleToggle exists" % lang)
		assert_not_null(streak_badge, "[%s] BattleWinStreakBadge exists" % lang)
		assert_not_null(weather_badge, "[%s] BattleWeatherBadge exists" % lang)
		assert_not_null(combo_badge, "[%s] ComboMeterBadge exists" % lang)

		# Row 1 (top_main): Stage label + Turn + SpeedToggle + AutoBattleToggle + LeaveBtn
		var top_main: HBoxContainer = speed_btn.get_parent() as HBoxContainer
		assert_not_null(top_main, "[%s] top_main exists" % lang)
		# The minimum size of top_main must comfortably fit within the 366px page
		assert_true(top_main.get_combined_minimum_size().x <= 366.0,
			"[%s] top_main combined minimum size (%f) <= 366.0" % [lang, top_main.get_combined_minimum_size().x])

		# Row 2 (top_sub): Badges sub-row
		var top_sub: HBoxContainer = streak_badge.get_parent() as HBoxContainer
		assert_not_null(top_sub, "[%s] top_sub exists" % lang)
		assert_true(top_sub.get_combined_minimum_size().x <= 366.0,
			"[%s] top_sub combined minimum size (%f) <= 366.0" % [lang, top_sub.get_combined_minimum_size().x])

		# Verify all 4 weather badges fit in sub-row
		for affix in ["solar", "frost", "thunder", "leyline"]:
			game.combat.state["weather_affix"] = affix
			game.show_battle()
			var w_badge: Control = game.root.find_child("BattleWeatherBadge", true, false)
			assert_not_null(w_badge, "[%s] Weather badge %s exists" % [lang, affix])
			var sub_row: HBoxContainer = w_badge.get_parent() as HBoxContainer
			assert_true(sub_row.get_combined_minimum_size().x <= 366.0,
				"[%s] sub_row with %s weather <= 366.0" % [lang, affix])

		game.queue_free()

# ------------------------------------------------------------------------------
# 2. Combat Action & Resource Bar: All 7 Buttons Fit Without Overflow (< 366px)
# ------------------------------------------------------------------------------

func test_combat_action_bar_all_buttons_never_overflow():
	for lang in ["zh-Hans", "en"]:
		var game := _create_game(lang)
		game.begin_battle(0)

		# Populate all piles so Draw, Discard, and Exhaust chips all render
		game.combat.state.draw = [{"card_id":"strike"}, {"card_id":"defend"}]
		game.combat.state.discard = [{"card_id":"strike"}]
		game.combat.state["exhaust"] = [{"card_id":"defend"}]

		# Set Qi gauge to 100% so Ultimate button renders in ready state
		game.combat.state["qi_gauge"] = 100
		assert_true(game.combat.can_cast_ultimate(), "Combat ultimate ready")

		# Create incoming damage that leaks past shield to trigger lethal/leak badge on Pass button
		game.combat.state.player.shield = 0
		game.combat.state.player.health = 10
		if not game.combat.state.enemies.is_empty():
			game.combat.state.enemies[0]["intent"] = {"kind":"attack", "amount": 15}

		# Simulate undo state for undo button
		game.combat.state["undo_state"] = game.combat.state.duplicate(true)
		assert_true(game.combat.can_undo(), "Combat undo is available")

		game.show_battle()

		var draw_chip: Control = game.root.find_child("DrawPileChip", true, false)
		var energy_orb: Control = game.root.find_child("EnergyOrb", true, false)
		var ult_btn: Button = game.root.find_child("UltimateQiMeter", true, false) as Button
		var discard_chip: Control = game.root.find_child("DiscardPileChip", true, false)
		var exhaust_chip: Control = game.root.find_child("ExhaustPileChip", true, false)
		var pass_btn: Button = game.root.find_child("PassTurnBtn", true, false) as Button
		var leak_badge: Control = game.root.find_child("PassTurnLeakBadge", true, false)
		var undo_btn: Button = game.root.find_child("CombatUndoBtn", true, false) as Button

		assert_not_null(draw_chip, "[%s] DrawPileChip present" % lang)
		assert_not_null(energy_orb, "[%s] EnergyOrb present" % lang)
		assert_not_null(ult_btn, "[%s] UltimateQiMeter present" % lang)
		assert_not_null(discard_chip, "[%s] DiscardPileChip present" % lang)
		assert_not_null(exhaust_chip, "[%s] ExhaustPileChip present" % lang)
		assert_not_null(pass_btn, "[%s] PassTurnBtn present" % lang)
		assert_not_null(leak_badge, "[%s] PassTurnLeakBadge present" % lang)
		assert_not_null(undo_btn, "[%s] CombatUndoBtn present" % lang)

		# Verify localized ult button text is concise and not printing raw key
		assert_ne(ult_btn.text, "ui.cast_ultimate", "[%s] Ultimate text must be localized" % lang)
		assert_true(ult_btn.text == "⚡神通" or ult_btn.text == "⚡Ult",
			"[%s] Ultimate button has concise label: got '%s'" % [lang, ult_btn.text])

		# Verify action bar (HBoxContainer status) total minimum width fits inside 366px
		var status_row: HBoxContainer = pass_btn.get_parent() as HBoxContainer
		assert_not_null(status_row, "[%s] status row exists" % lang)
		var combined_w: float = status_row.get_combined_minimum_size().x
		assert_true(combined_w <= 366.0,
			"[%s] Combat action row combined width (%f) must be <= 366.0" % [lang, combined_w])

		# Check total width manually: sum of custom_minimum_size.x + separation * gaps
		var total_items_w: float = 0.0
		var visible_children := 0
		for child in status_row.get_children():
			if child is Control and child.visible:
				total_items_w += (child as Control).custom_minimum_size.x
				visible_children += 1
		var sep: int = status_row.get_theme_constant("separation")
		var total_calc_w: float = total_items_w + float(maxi(0, visible_children - 1) * sep)
		assert_true(total_calc_w <= 366.0,
			"[%s] Total calculated action bar width (%f) must be <= 366.0" % [lang, total_calc_w])

		game.queue_free()

# ------------------------------------------------------------------------------
# 3. Enemy Status Badges: Wraps Cleanly in HFlowContainer Without Exceeding Unit Width
# ------------------------------------------------------------------------------

func test_enemy_status_badges_never_overflow_unit_width():
	var game := _create_game("en")
	game.begin_battle(0)

	# Ensure 3 enemies exist to test the tightest unit width (u_width = 112px)
	while game.combat.state.enemies.size() < 3:
		var extra_e: Dictionary = game.combat.state.enemies[0].duplicate(true)
		extra_e["health"] = 30
		extra_e["max_health"] = 30
		game.combat.state.enemies.append(extra_e)

	# Apply all 6 status effects simultaneously to all 3 enemies
	for e in game.combat.state.enemies:
		e["shield"] = 25
		e["burn"] = 8
		e["poison"] = 6
		e["stun"] = 1
		e["vulnerable"] = 2
		e["weak"] = 2

	game.show_battle()

	var unit_w := 112.0
	for i in range(3):
		var enemy_node: Control = game.root.find_child("Enemy_%d" % i, true, false)
		assert_not_null(enemy_node, "Enemy_%d node found" % i)
		var badges_container: Control = enemy_node.find_child("EnemyBadges", true, false)
		assert_not_null(badges_container, "EnemyBadges container found on Enemy_%d" % i)
		assert_true(badges_container is HFlowContainer, "EnemyBadges must be an HFlowContainer")

		# Check that all 6 status chips are present as children
		assert_eq(badges_container.get_child_count(), 6, "Enemy_%d has 6 status chips" % i)

		# Verify each status chip has compact width (<= 32px) so 3 fit per line on 112px unit
		for chip in badges_container.get_children():
			if chip is Control:
				assert_true(chip.custom_minimum_size.x <= 32.0,
					"Chip custom_minimum_size.x (%f) <= 32.0" % chip.custom_minimum_size.x)

		# badges_container custom_minimum_size.x is clamped to u_width
		assert_true(badges_container.custom_minimum_size.x <= unit_w,
			"Enemy_%d badges_container width (%f) <= unit_w (%f)" % [i, badges_container.custom_minimum_size.x, unit_w])

	game.queue_free()

# ------------------------------------------------------------------------------
# 4. Player Side Panel: Clamped to Max 4 Columns and Stays Within Screen Margin
# ------------------------------------------------------------------------------

func test_player_side_panel_never_overflows_screen():
	for lang in ["zh-Hans", "en"]:
		var game := _create_game(lang)
		game.begin_battle(0)

		# Apply maximum player statuses (7 statuses)
		game.combat.state.player.shield = 40
		game.combat.state.player.focus = 3
		game.combat.state.player["strength"] = 5
		game.combat.state.player.burn = 4
		game.combat.state.player["poison"] = 3
		game.combat.state.player["vulnerable"] = 2
		game.combat.state.player["weak"] = 1

		# Add stage modifier
		game.active_modifier = {
			"name": "天崩地裂", "name_en": "Cataclysm",
			"detail": "全场伤害提升", "detail_en": "All damage increased"
		}

		# Add equipment (3 items)
		game.combat.state.equipment = ["spiritSword", "ironShield", "jadeAmulet"]

		# Add relics (6 relics)
		game.combat.state["relics"] = ["foxCharm", "starShard", "ancientSeed", "windChime", "bloodJade", "thunderSeal"]

		# Add resonances (2 resonances)
		game.combat.state["relic_resonances"] = ["res_thunder_mirror", "res_blood_seed"]

		game.show_battle()

		var side_panel: HBoxContainer = game.root.find_child("PlayerSidePanel", true, false) as HBoxContainer
		assert_not_null(side_panel, "[%s] PlayerSidePanel found" % lang)

		# Must be clamped to at most 4 columns regardless of how many items exist
		var col_count := side_panel.get_child_count()
		assert_true(col_count <= 4,
			"[%s] PlayerSidePanel column count (%d) must be <= 4" % [lang, col_count])

		# Calculate right edge: side_panel.position.x + combined width
		var right_edge: float = side_panel.position.x + side_panel.get_combined_minimum_size().x
		assert_true(right_edge <= 366.0,
			"[%s] PlayerSidePanel right edge (%f) must not exceed screen page width (366.0)" % [lang, right_edge])

		game.queue_free()
