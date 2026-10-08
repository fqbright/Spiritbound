extends GutTest

# ==============================================================================
# UI Alignment, Overflow Guard & Game Balance Integrity Tests
# ==============================================================================

var content: SpiritContent
var had_real_save: bool
var real_save_text: String

func before_all() -> void:
	content = SpiritContent.new()
	had_real_save = FileAccess.file_exists(SpiritSave.PATH)
	if had_real_save:
		real_save_text = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()

func after_all() -> void:
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
# 1. Camp Screen: Hero Spotlight & Spiritual Roots Overflow & Alignment
# ------------------------------------------------------------------------------

func test_camp_hero_spotlight_and_roots_no_overflow_both_languages():
	for lang in ["zh-Hans", "en"]:
		var g := _create_game(lang)
		g.profile.spiritual_root_points = 3
		g.camp_tab = "character"
		g.show_camp()

		# Check Hero Spotlight panel
		var spotlight: Control = g.root.find_child("HeroSpotlightPanel", true, false)
		assert_not_null(spotlight, "[%s] HeroSpotlightPanel exists" % lang)
		if spotlight:
			assert_true(spotlight.get_combined_minimum_size().x <= 366.0,
				"[%s] HeroSpotlightPanel width (%f) <= 366.0" % [lang, spotlight.get_combined_minimum_size().x])

		# Check Spiritual Roots section
		var roots_sec: Control = g.root.find_child("SpiritualRootsSection", true, false)
		assert_not_null(roots_sec, "[%s] SpiritualRootsSection exists" % lang)
		if roots_sec:
			assert_true(roots_sec.get_combined_minimum_size().x <= 366.0,
				"[%s] SpiritualRootsSection width (%f) <= 366.0" % [lang, roots_sec.get_combined_minimum_size().x])

			# Verify each of the 5 elements has a distinct button
			for elem in ["metal", "wood", "water", "fire", "earth"]:
				var btn: Button = roots_sec.find_child("RootBtn_%s" % elem, true, false) as Button
				assert_not_null(btn, "[%s] RootBtn_%s exists" % [lang, elem])
				if btn:
					assert_true(btn.text.length() > 0, "[%s] RootBtn_%s has non-empty text '%s'" % [lang, elem, btn.text])
					assert_true(btn.tooltip_text.length() > 0, "[%s] RootBtn_%s has descriptive tooltip" % [lang, elem])

		# Switch to Challenges tab to check Pagoda section
		g.camp_tab = "challenges"
		g.show_camp()
		var pagoda_sec: Control = g.root.find_child("EndlessPagodaSection", true, false)
		assert_not_null(pagoda_sec, "[%s] EndlessPagodaSection exists" % lang)
		if pagoda_sec:
			assert_true(pagoda_sec.get_combined_minimum_size().x <= 366.0,
				"[%s] EndlessPagodaSection width (%f) <= 366.0" % [lang, pagoda_sec.get_combined_minimum_size().x])

		g.free()

# ------------------------------------------------------------------------------
# 2. Rewards Screen: Card Choices & Item Plaques Overflow & Layout Guard
# ------------------------------------------------------------------------------

func test_rewards_screen_card_choices_and_items_alignment():
	for lang in ["zh-Hans", "en"]:
		var g := _create_game(lang)
		g.pending_rewards = {
			"gold": 65,
			"streak_bonus_gold": 15,
			"equipment": "emberBlade",
			"relic": "foxCharm",
			"rune": "swift"
		}

		var rew_screen := RewardsScreen.new(g)
		rew_screen.show_reward_details()

		# Check spoils row
		var streak_lbl: Control = g.root.find_child("RewardStreakBonusLabel", true, false)
		assert_not_null(streak_lbl, "[%s] RewardStreakBonusLabel exists" % lang)

		# Check skip button
		var skip_btn: Button = g.root.find_child("RewardSkipBtn", true, false) as Button
		assert_not_null(skip_btn, "[%s] RewardSkipBtn exists" % lang)

		# Check reward item plaques
		var blade: Dictionary = content.equipment("emberBlade")
		if not blade.is_empty():
			var plaque: Control = rew_screen._reward_item("Ember Blade", "First attack deals +3 damage", g.GOLD)
			assert_true(plaque.custom_minimum_size.x <= 366.0, "[%s] Reward item plaque fits in 366px screen" % lang)

		# Check card row layout & Capstone highlight
		var capstone_card: Dictionary = content.card("samadhiFire")
		if not capstone_card.is_empty():
			var cap_row: Control = rew_screen._reward_card_row(capstone_card)
			assert_true(cap_row.get_combined_minimum_size().x <= 366.0, "[%s] Capstone card row fits in 366px" % lang)

		var normal_card: Dictionary = content.card("strike")
		if not normal_card.is_empty():
			var norm_row: Control = rew_screen._reward_card_row(normal_card)
			assert_true(norm_row.get_combined_minimum_size().x <= 366.0, "[%s] Normal card row fits in 366px" % lang)

		g.free()

# ------------------------------------------------------------------------------
# 3. Shop & Deck Purge: Layout & Boundaries Guard
# ------------------------------------------------------------------------------

func test_shop_and_deck_purge_alignment_and_bounds():
	for lang in ["zh-Hans", "en"]:
		var g := _create_game(lang)
		var shop_scr := ShopDeckScreen.new(g)

		# 1. Deck Purge screen
		shop_scr.show_deck_purge(Callable(), 50)
		var purge_header: Control = g.root.find_child("HeaderLeftBox", true, false)
		assert_not_null(purge_header, "[%s] Purge screen header exists" % lang)

		# 2. Shop Curated screen
		shop_scr.show_shop()
		var restock_btn: Control = g.root.find_child("ShopRestockBtn", true, false)
		var purge_svc: Control = g.root.find_child("ShopPurgeBtn", true, false)
		var pack_btn: Control = g.root.find_child("ShopPackBtn", true, false)

		assert_not_null(restock_btn, "[%s] Shop restock button exists" % lang)
		assert_not_null(purge_svc, "[%s] Shop purge service button exists" % lang)
		assert_not_null(pack_btn, "[%s] Shop pack button exists" % lang)

		if purge_svc and pack_btn:
			var svc_row: HBoxContainer = purge_svc.get_parent() as HBoxContainer
			assert_not_null(svc_row, "[%s] svc_row container exists" % lang)
			if svc_row:
				assert_true(svc_row.get_combined_minimum_size().x <= 366.0,
					"[%s] Shop service row width (%f) <= 366.0" % [lang, svc_row.get_combined_minimum_size().x])

		g.free()

# ------------------------------------------------------------------------------
# 4. Five Elements Spiritual Root Perks Invariants & Investment Bounds
# ------------------------------------------------------------------------------

func test_spiritual_root_perks_invariants():
	var elements := ["metal", "wood", "water", "fire", "earth"]
	for elem in elements:
		assert_true(SpiritContent.SPIRITUAL_ROOT_PERKS.has(elem), "Spiritual root perk exists for element: %s" % elem)
		var perk: Dictionary = SpiritContent.SPIRITUAL_ROOT_PERKS[elem]
		assert_true(str(perk.get("name_zh", "")).length() > 0, "Perk %s has Chinese name" % elem)
		assert_true(str(perk.get("name_en", "")).length() > 0, "Perk %s has English name" % elem)
		assert_true(str(perk.get("desc_zh", "")).length() > 0, "Perk %s has Chinese description" % elem)
		assert_true(str(perk.get("desc_en", "")).length() > 0, "Perk %s has English description" % elem)

	# Investment logic invariants
	var test_profile := {
		"spiritual_roots": {"metal": 1, "wood": 1, "water": 1, "fire": 1, "earth": 1},
		"spiritual_root_points": 0
	}
	# Zero points: investment should fail safely
	var fail_res: bool = SpiritSave.invest_spiritual_root(test_profile, "metal")
	assert_false(fail_res, "Cannot invest spiritual roots when points == 0")
	assert_eq(int(test_profile.spiritual_roots.metal), 1, "Metal root remains 1")

	# Add 1 point: investment should succeed
	test_profile.spiritual_root_points = 1
	var succ_res: bool = SpiritSave.invest_spiritual_root(test_profile, "metal")
	assert_true(succ_res, "Can invest spiritual roots when points > 0")
	assert_eq(int(test_profile.spiritual_roots.metal), 2, "Metal root increased to 2")
	assert_eq(int(test_profile.spiritual_root_points), 0, "Points deducted to 0")

# ------------------------------------------------------------------------------
# 5. Balance Probe Quick & Full Mode Config Invariants
# ------------------------------------------------------------------------------

func test_balance_probe_retry_allowance_invariant():
	var probe_script_path := "res://tests/balance_probe.gd"
	assert_true(FileAccess.file_exists(probe_script_path), "balance_probe.gd exists")
	var text: String = FileAccess.open(probe_script_path, FileAccess.READ).get_as_text()

	# In quick mode, QUICK_MAX_RETRIES must be >= 2 so that an unlucky card draw on stage 70
	# gets at least 1 retry, avoiding spurious CI test wall failures.
	assert_true(text.contains("const QUICK_MAX_RETRIES := 2") or text.contains("const QUICK_MAX_RETRIES := 3"),
		"QUICK_MAX_RETRIES is configured to at least 2 in balance_probe.gd")

# ------------------------------------------------------------------------------
# 6. Title / Login Screen: Button and Label No-Overflow Guard
# ------------------------------------------------------------------------------

func test_title_login_screen_buttons_and_labels_no_overflow():
	for lang in ["zh-Hans", "en"]:
		var g := _create_game(lang)
		g.show_title_screen()

		var start_btn: Control = g.root.find_child("TitleStartBtn", true, false)
		assert_not_null(start_btn, "[%s] TitleStartBtn exists" % lang)
		if start_btn:
			assert_true(start_btn.get_combined_minimum_size().x <= 366.0,
				"[%s] TitleStartBtn width <= 366.0" % lang)

		var dev_btn: Control = g.root.find_child("TitleDeviceAuthBtn", true, false)
		var auth_btn: Control = g.root.find_child("TitleAuthBtn", true, false)
		if dev_btn and auth_btn:
			var auth_row: HBoxContainer = dev_btn.get_parent() as HBoxContainer
			assert_not_null(auth_row, "[%s] auth_row exists" % lang)
			if auth_row:
				var auth_w: float = auth_row.get_combined_minimum_size().x
				assert_true(auth_w <= 366.0,
					"[%s] Title auth_row width (%f) must be <= 366.0" % [lang, auth_w])

		var apple_btn: Control = g.root.find_child("TitleAppleBtn", true, false)
		var google_btn: Control = g.root.find_child("TitleGoogleBtn", true, false)
		var guest_btn: Button = g.root.find_child("TitleGuestBtn", true, false) as Button
		if apple_btn and google_btn and guest_btn:
			var oauth_row: HBoxContainer = apple_btn.get_parent() as HBoxContainer
			assert_not_null(oauth_row, "[%s] oauth_row exists" % lang)
			if oauth_row:
				var oauth_w: float = oauth_row.get_combined_minimum_size().x
				assert_true(oauth_w <= 366.0,
					"[%s] Title oauth_row width (%f) must be <= 366.0" % [lang, oauth_w])
			# Assert guest button has concise label, avoiding the unlinked paragraph
			assert_true(guest_btn.text == "游客账号" or guest_btn.text == "Guest",
				"[%s] TitleGuestBtn has concise label '%s'" % [lang, guest_btn.text])

		# Verify all controls on the title page fit within 366.0
		if start_btn:
			var page: Control = start_btn.get_parent() as Control
			if page:
				for child in page.get_children():
					if child is Control and child.visible:
						var c_min_w: float = (child as Control).get_combined_minimum_size().x
						assert_true(c_min_w <= 366.0,
							"[%s] Title child '%s' width (%f) <= 366.0" % [lang, child.name, c_min_w])

		g.free()

