extends GutTest

# ==============================================================================
# Tests for Retention Systems (P0-P4) & Real Authentication Verification
# ==============================================================================

var content: SpiritContent

func before_all():
	content = SpiritContent.new()
	SpiritAuth.simulate_mode = false

func after_all():
	SpiritAuth.simulate_mode = false

func _create_game() -> SpiritGame:
	var g := SpiritGame.new()
	g.content = content
	g.lang = "zh-Hans"
	g.profile = SpiritSave.defaults(content)
	g.root = Control.new()
	g.overlay = Control.new()
	g.add_child(g.root)
	g.add_child(g.overlay)
	return g

# ------------------------------------------------------------------------------
# P0: Guaranteed Hero Capstone on Chapter 1 Boss
# ------------------------------------------------------------------------------

func test_first_boss_card_rewards_guarantee_hero_capstone():
	var game := _create_game()
	game.profile.hero_class = "fox_spirit"
	game.current_stage = 4 # Stage 4 is Chapter 1 Boss (m_s005)
	game.profile.first_boss_capstone_awarded = false

	var rewards_screen = game._rewards_screen
	var options: Array = rewards_screen._get_reward_card_options()
	assert_eq(options.size(), 3, "Offers 3 card choices")
	
	var has_capstone := false
	for c in options:
		if rewards_screen._is_capstone_card(str(c.get("id", ""))):
			has_capstone = true
			assert_true(c.id == "samadhiFire" or c.id == "spiritSurge", "Capstone matches fox_spirit")
	assert_true(has_capstone, "Guaranteed hero capstone card present on Chapter 1 Boss")
	assert_true(bool(game.profile.get("first_boss_capstone_awarded", false)), "first_boss_capstone_awarded flag set to true")
	game.free()

func test_sentinel_boss_card_rewards_guarantee_sentinel_capstone():
	var game := _create_game()
	game.profile.hero_class = "stone_sentinel"
	game.current_stage = 4
	game.profile.first_boss_capstone_awarded = false

	var rewards_screen = game._rewards_screen
	var options: Array = rewards_screen._get_reward_card_options()
	var cap_ids: Array = []
	for c in options:
		if rewards_screen._is_capstone_card(str(c.get("id", ""))):
			cap_ids.append(c.id)
	assert_true(cap_ids.has("shieldSlam") or cap_ids.has("bastionForm"), "Sentinel capstone dropped on boss 1")
	game.free()

# ------------------------------------------------------------------------------
# P1: 7-Day Archetype Journey
# ------------------------------------------------------------------------------

func test_seven_day_journey_content_and_rewards():
	var journey: Array = content.seven_day_journey()
	assert_eq(journey.size(), 7, "7-Day journey has exactly 7 days of milestones")
	
	for day_idx in range(1, 8):
		var task: Dictionary = content.seven_day_journey_day(day_idx)
		assert_false(task.is_empty(), "Day %d task exists" % day_idx)
		assert_true(str(task.get("reward_card", "")).length() > 0, "Day %d rewards a capstone card" % day_idx)
		assert_true(int(task.get("gold", 0)) > 0, "Day %d rewards gold" % day_idx)
		assert_true(int(task.get("jade", 0)) > 0, "Day %d rewards jade" % day_idx)

func test_seven_day_journey_claim_and_completion():
	var game := _create_game()
	var camp_screen = game._camp_screen
	var task1: Dictionary = content.seven_day_journey_day(1)

	# Before completing requirements
	game.profile.career_stats.total_cards_played = 0
	assert_false(camp_screen._is_seven_day_quest_completed(task1), "Day 1 quest not completed with 0 cards")

	# Meet requirements
	game.profile.career_stats.total_cards_played = 10
	assert_true(camp_screen._is_seven_day_quest_completed(task1), "Day 1 quest completed after playing cards")

	# Claim reward
	var initial_gold: int = int(game.profile.get("gold", 0))
	var initial_jade: int = int(game.profile.get("spirit_jade", 0))
	camp_screen._claim_seven_day_reward(1, task1)

	var claimed: Array = game.profile.seven_day_journey.get("claimed", [])
	assert_true(claimed.has(1), "Day 1 marked as claimed")
	assert_true(int(game.profile.get("gold", 0)) > initial_gold, "Gold granted")
	assert_true(int(game.profile.get("spirit_jade", 0)) > initial_jade, "Jade granted")
	assert_true(int(game.profile.collection.get(task1.reward_card, 0)) > 0, "Capstone card added to collection")
	game.free()

# ------------------------------------------------------------------------------
# P2: Deep Offline Expeditions (4h / 8h / 12h Milestones)
# ------------------------------------------------------------------------------

func test_idle_harvest_offline_expeditions_milestones():
	var game := _create_game()
	var now: int = int(Time.get_unix_time_from_system())

	# 1. Test 4-Hour Milestone
	game.profile.idle_harvest.last_claim_time = now - 15000 # ~4.1 hours
	var init_dust: int = int(game.profile.get("spirit_dust", 0))
	game.claim_idle_harvest()
	assert_eq(int(game.profile.get("spirit_dust", 0)), init_dust + 20, "4h offline expedition grants +20 spirit dust")
	assert_true(game.profile.rune_inventory.size() > 0, "4h offline expedition grants rare rune")

	# 2. Test 8-Hour Milestone
	game.profile.idle_harvest.last_claim_time = now - 30000 # ~8.3 hours
	var init_jade: int = int(game.profile.get("spirit_jade", 0))
	game.claim_idle_harvest()
	assert_true(int(game.profile.get("spirit_jade", 0)) >= init_jade + 10, "8h offline expedition grants +10 spirit jade")

	# 3. Test 12-Hour Milestone (Max Cap)
	game.profile.idle_harvest.last_claim_time = now - 45000 # >12 hours
	game.profile.hero_class = "fox_spirit"
	var init_samadhi: int = int(game.profile.collection.get("samadhiFire", 0))
	game.claim_idle_harvest()
	assert_true(int(game.profile.collection.get("samadhiFire", 0)) > init_samadhi, "12h offline expedition grants capstone gold card")
	game.free()

# ------------------------------------------------------------------------------
# P3: Top Deck Inspector
# ------------------------------------------------------------------------------

func test_leaderboard_deck_inspector_opens_modal():
	var game := _create_game()
	var camp_screen = game._camp_screen

	camp_screen._show_player_deck_inspector_modal("TopPlayer001", "fox", "abyss", 120)
	var modal: Node = game.overlay.get_node_or_null("PlayerDeckInspectorModal")
	assert_true(modal != null, "PlayerDeckInspectorModal opened in game overlay")

	# Clean up modal
	if modal != null:
		modal.queue_free()
	game.free()

# ------------------------------------------------------------------------------
# P4: Fast Combat Speed Cycling (1.0x / 2.0x / 3.0x)
# ------------------------------------------------------------------------------

func test_battle_speed_cycling_1x_2x_3x():
	var game := _create_game()
	assert_eq(SpiritGame.BATTLE_SPEED_OPTIONS, [1.0, 1.5, 2.0, 3.0], "BATTLE_SPEED_OPTIONS includes 1.0, 1.5, 2.0, 3.0")
	
	game.battle_speed = 1.0
	game._cycle_speed()
	assert_eq(game.battle_speed, 1.5, "1.0x cycles to 1.5x")
	
	game._cycle_speed()
	assert_eq(game.battle_speed, 2.0, "1.5x cycles to 2.0x")
	
	game._cycle_speed()
	assert_eq(game.battle_speed, 3.0, "2.0x cycles to 3.0x")
	
	game._cycle_speed()
	assert_eq(game.battle_speed, 1.0, "3.0x cycles back to 1.0x")
	game.free()

# ------------------------------------------------------------------------------
# Auth Verification: No fake bypass when unmocked
# ------------------------------------------------------------------------------

func test_auth_does_not_silently_fake_login_when_unmocked():
	var game := _create_game()
	SpiritAuth.simulate_mode = false
	
	var apple_res := {"called": false, "ok": true}
	SpiritAuth.sign_in_with_apple(game, func(ok: bool, _p: String):
		apple_res["called"] = true
		apple_res["ok"] = ok
	)
	assert_true(apple_res["called"], "Apple sign-in callback executed")
	assert_false(apple_res["ok"], "Apple sign-in without native singleton does NOT fake success")
	assert_false(SpiritSave.is_cloud_linked(game.profile), "Profile remains unlinked")
	
	var google_res := {"called": false, "ok": true}
	SpiritAuth.sign_in_with_google(game, func(ok: bool, _p: String):
		google_res["called"] = true
		google_res["ok"] = ok
	)
	assert_true(google_res["called"], "Google sign-in callback executed")
	assert_false(google_res["ok"], "Google sign-in without native singleton does NOT fake success")
	assert_false(SpiritSave.is_cloud_linked(game.profile), "Profile remains unlinked")
	game.free()

# ------------------------------------------------------------------------------
# Progressive Onboarding: 15-Stage Progressive Disclosure & Ceremony Modals
# ------------------------------------------------------------------------------

func test_progressive_feature_unlock_milestones():
	var game := _create_game()
	game.profile.feature_unlocks_seen = []
	game.profile.unlocked = 0

	# Stage 0: Nothing unlocked yet
	game._check_feature_unlocks()
	assert_eq(game.profile.feature_unlocks_seen.size(), 0, "No unlocks at stage 0")

	# Stage 2: Shop unlocks
	game.profile.unlocked = 2
	game._check_feature_unlocks()
	assert_true(game.profile.feature_unlocks_seen.has("shop"), "Shop unlocked at stage 2")
	var shop_modal: Node = game.overlay.find_child("FeatureUnlockModal_shop", true, false)
	assert_not_null(shop_modal, "FeatureUnlockModal_shop popup spawned on milestone crossing")
	var confirm_btn: Button = shop_modal.find_child("UnlockConfirmBtn", true, false) as Button
	assert_not_null(confirm_btn, "Confirm button exists in unlock modal")
	confirm_btn.pressed.emit()
	assert_null(game.overlay.find_child("FeatureUnlockModal_shop", true, false), "Modal dismissed on confirm button click")

	# Stage 5: Camp unlocks
	game.profile.unlocked = 5
	game._check_feature_unlocks()
	assert_true(game.profile.feature_unlocks_seen.has("ch1_features"), "Camp unlocked at stage 5 (Ch1 clear)")

	# Stage 6: Trials & Quests unlock
	game.profile.unlocked = 6
	game._check_feature_unlocks()
	assert_true(game.profile.feature_unlocks_seen.has("trial_and_quests"), "Trials & Quests unlocked at stage 6")

	# Stage 8: Equipment unlocks
	game.profile.unlocked = 8
	game._check_feature_unlocks()
	assert_true(game.profile.feature_unlocks_seen.has("equipment"), "Equipment unlocked at stage 8")

	# Stage 15: Meridians unlock
	game.profile.unlocked = 15
	game._check_feature_unlocks()
	assert_true(game.profile.feature_unlocks_seen.has("meridians_and_codex"), "Meridians unlocked at stage 15 (Ch3 clear)")
	game.free()

func test_map_dock_and_header_progressive_lock_states():
	var game := _create_game()
	game.profile.unlocked = 0
	game.show_map()

	var camp_btn: Node = game.root.find_child("CampButton", true, false)
	assert_not_null(camp_btn, "CampButton exists at stage 0 for test compatibility")
	var camp_icon := camp_btn.get_child(0) as TextureRect
	assert_true(camp_icon.modulate.a < 0.9, "Camp icon is dimmed when locked at stage 0")

	var quest_btn: Node = game.root.find_child("QuestButton", true, false)
	assert_not_null(quest_btn, "QuestButton exists at stage 0")
	var quest_icon := quest_btn.get_child(0) as TextureRect
	assert_true(quest_icon.modulate.a < 0.9, "Quest icon is dimmed when locked at stage 0")

	# Now test at unlocked = 15 (fully graduated onboarding)
	game.profile.unlocked = 15
	game.show_map()

	var camp_btn_u: Node = game.root.find_child("CampButton", true, false)
	var camp_icon_u := camp_btn_u.get_child(0) as TextureRect
	assert_true(camp_icon_u.modulate.a >= 0.99, "Camp icon is fully bright when unlocked at stage 15")

	var quest_btn_u: Node = game.root.find_child("QuestButton", true, false)
	var quest_icon_u := quest_btn_u.get_child(0) as TextureRect
	assert_true(quest_icon_u.modulate.a >= 0.99, "Quest icon is fully bright when unlocked at stage 15")
	game.free()

func test_camp_meridian_progressive_lock_states():
	var game := _create_game()
	game.profile.unlocked = 5
	game.show_camp()

	var meridian_btn_locked: Button = game.root.find_child("MeridianOpenBtn", true, false) as Button
	assert_not_null(meridian_btn_locked, "MeridianOpenBtn exists at stage 5")
	assert_true(meridian_btn_locked.disabled, "MeridianOpenBtn is disabled before stage 15")

	# Progress to stage 15
	game.profile.unlocked = 15
	game.show_camp()

	var meridian_btn_unlocked: Button = game.root.find_child("MeridianOpenBtn", true, false) as Button
	assert_not_null(meridian_btn_unlocked, "MeridianOpenBtn exists at stage 15")
	assert_false(meridian_btn_unlocked.disabled, "MeridianOpenBtn is active at stage 15")
	game.free()

func test_status_chip_clickable_opens_info_popup():
	var game := _create_game()
	game.begin_battle(0)
	var chip_btn: Button = game._battle_screen._status_chip_clickable("poison", "◆", 5, Color("a75bd6")) as Button
	assert_not_null(chip_btn, "Status chip is wrapped in a clickable Button")
	chip_btn.emit_signal("pressed")
	var popup: Node = game.overlay.find_child("InfoPopup", true, false)
	assert_not_null(popup, "Clicking status chip opens InfoPopup")
	game.free()

func test_stage_quick_sweep_deducts_stamina_and_awards_rewards():
	var game := _create_game()
	game.profile.unlocked = 5
	game.profile.stamina.current = 100
	var gold_before: int = int(game.profile.gold)
	var dust_before: int = int(game.profile.spirit_dust)

	game._sweep_stage(1)

	assert_eq(int(game.profile.stamina.current), 95, "Sweeping a stage costs exactly 5 stamina")
	assert_true(int(game.profile.gold) > gold_before, "Sweeping awards gold")
	assert_true(int(game.profile.spirit_dust) >= dust_before, "Sweeping awards spirit dust")
	var modal: Node = game.overlay.find_child("SweepResultModal", true, false)
	assert_not_null(modal, "Sweep result modal is displayed with rewards")
	game.free()

func test_stamina_and_harvest_local_notifications():
	var profile: Dictionary = SpiritSave.defaults(SpiritContent.new())
	profile.unlocked = 5
	profile.stamina = {"current": 60, "max": 100, "last_regen_time": 1000}
	profile.idle_harvest = {"last_claim_time": 2000, "last_fast_claim_day": -1}
	var now := 3000

	var reminders: Array = SpiritNotify.due_reminders(profile, now)
	var has_stamina := false
	var has_harvest := false
	for r in reminders:
		if str(r.get("id")) == SpiritNotify.ID_STAMINA: has_stamina = true
		if str(r.get("id")) == SpiritNotify.ID_HARVEST: has_harvest = true

	assert_true(has_stamina, "SpiritNotify schedules ID_STAMINA when stamina < max")
	assert_true(has_harvest, "SpiritNotify schedules ID_HARVEST when idle harvest is active")

func test_achievement_claim_and_claim_all_grants_spirit_jade():
	var game := _create_game()
	game.profile.achievements_unlocked = {"win10": true, "win50": true}
	game.profile.achievements_claimed = {}
	game.profile.spirit_jade = 10

	game._camp_screen._claim_single_achievement("win10", 10)
	assert_eq(int(game.profile.spirit_jade), 20, "Claiming win10 awards 10 jade")
	assert_true(bool(game.profile.achievements_claimed.get("win10", false)), "win10 marked claimed")

	game._camp_screen._claim_all_achievements()
	assert_true(bool(game.profile.achievements_claimed.get("win50", false)), "win50 claimed by claim all")
	assert_true(int(game.profile.spirit_jade) >= 45, "Spirit jade includes all claimed achievements")
	game.free()

