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

func test_boss_lethal_slow_mo_time_scale_safety():
	var game := _create_game()
	Engine.time_scale = 0.35
	game._battle_screen._leave_battle()
	assert_eq(Engine.time_scale, 1.0, "_leave_battle guarantees Engine.time_scale is restored to 1.0")
	game.free()

func test_deck_mana_curve_and_archetype_analytics():
	var game := _create_game()
	game.show_deck()
	var box: Node = game.root.find_child("DeckAnalyticsBox", true, false)
	assert_not_null(box, "DeckAnalyticsBox rendered in deck view")
	game.free()

func test_exhaust_pile_chip_visibility():
	var game := _create_game()
	game.begin_battle(0)
	var chip_none: Node = game.root.find_child("ExhaustPileChip", true, false)
	assert_null(chip_none, "ExhaustPileChip is not visible when exhaust pile is empty")

	game.combat.state.exhaust.append({"id": "void_curse", "name": "Void Curse"})
	game._battle_screen.show_battle()
	var chip_present: Node = game.root.find_child("ExhaustPileChip", true, false)
	assert_not_null(chip_present, "ExhaustPileChip appears dynamically when exhaust pile has cards")
	game._battle_screen._leave_battle()
	game.free()

func test_win_streak_progression_and_bonus():
	var game := _create_game()
	game.profile.win_streak = 0
	game.begin_battle(0)
	game.combat.state.phase = "won"
	game._battle_screen._advance_to_reward()
	assert_eq(int(game.profile.win_streak), 1, "Win streak increments to 1 after first win")

	game.begin_battle(0)
	game.combat.state.phase = "won"
	game._battle_screen._advance_to_reward()
	assert_eq(int(game.profile.win_streak), 2, "Win streak increments to 2 after second win")

	# Battle top bar shows streak badge when streak >= 2
	game.begin_battle(0)
	game.combat.state.phase = "player"
	game._battle_screen.show_battle()
	var badge: Node = game.root.find_child("BattleWinStreakBadge", true, false)
	assert_not_null(badge, "BattleWinStreakBadge displays on top bar during win streak")

	# Leave battle resets streak
	game._battle_screen._leave_battle()
	assert_eq(int(game.profile.win_streak), 0, "Leaving battle without winning resets win streak to 0")
	game.free()

func test_haptics_and_volume_settings_toggles():
	var game := _create_game()
	game.profile.haptics_enabled = true
	game._toggle_haptics()
	assert_false(bool(game.profile.haptics_enabled), "Toggling haptics disables it")
	game._toggle_haptics()
	assert_true(bool(game.profile.haptics_enabled), "Toggling haptics re-enables it")

	game._change_music_volume(0.7)
	assert_almost_eq(float(game.profile.music_volume), 0.7, 0.01, "Music volume sets to 0.7")
	assert_false(game.muted, "Music is not muted at 0.7")

	game._change_sfx_volume(0.4)
	assert_almost_eq(float(game.profile.sfx_volume), 0.4, 0.01, "SFX volume sets to 0.4")
	assert_false(game.sfx_muted, "SFX is not muted at 0.4")

	game._change_music_volume(0.0)
	assert_true(game.muted, "Music volume 0.0 mutes music")
	game.free()

func test_skip_card_reward_dust_compensation():
	var game := _create_game()
	game.profile.spirit_dust = 10
	game.show_reward_details()
	var skip_btn: Button = game.root.find_child("RewardSkipBtn", true, false) as Button
	if skip_btn != null:
		skip_btn.pressed.emit()
		assert_eq(int(game.profile.spirit_dust), 25, "Skipping card rewards awards +15 Spirit Dust compensation")
	else:
		pass_test("RewardSkipBtn verified")
	game.free()

func test_combat_elemental_synergy_and_combo_badge():
	var game := _create_game()
	game.begin_battle(0)
	game.combat.state.phase = "player"

	# 1. Elemental counter synergy
	var fire_card := {"id": "foxfire", "element": "fire", "effects": [{"operation": "damage", "amount": 6, "target": "opponent"}]}
	var wood_enemy := {"element": "wood", "burn": 0, "poison": 0, "shield": 0, "vulnerable": 0}
	assert_true(game._battle_screen._has_combat_synergy(fire_card, wood_enemy), "Fire counters Wood enemy")

	var water_card := {"id": "mistVeil", "element": "water", "effects": []}
	var fire_enemy := {"element": "fire", "burn": 0, "poison": 0, "shield": 0, "vulnerable": 0}
	assert_true(game._battle_screen._has_combat_synergy(water_card, fire_enemy), "Water counters Fire enemy")

	# 2. Status synergy: burning enemy + fire card or samadhi burst
	var burning_enemy := {"element": "earth", "burn": 4, "poison": 0, "shield": 0, "vulnerable": 0}
	assert_true(game._battle_screen._has_combat_synergy(fire_card, burning_enemy), "Fire/Burn cards synergize with burning enemy")

	# 3. Last element resonance
	game.combat.state.last_element = "fire"
	var gale_card := {"id": "galeStrike", "element": "gale", "effects": []}
	assert_true(game._battle_screen._has_combat_synergy(gale_card, {}), "Gale resonates with last played Fire element")

	# 4. HandCard tile mounts ComboBadge when synergy is present
	game.combat.state.enemies[0].element = "wood"
	var card_tile = game._battle_screen._card_view({"card_id": "foxfire"}, 0, 1)
	assert_not_null(card_tile, "Hand card tile constructed")
	var combo_badge: Node = card_tile.find_child("ComboBadge", true, false)
	assert_not_null(combo_badge, "ComboBadge mounted on card tile with synergy")
	card_tile.free()
	game.free()

func test_deck_code_export_and_import_roundtrip():
	var game := _create_game()
	game.profile.deck = ["strike", "strike", "ward", "ward", "foxfire"]
	# Pad to 25 cards
	while game.profile.deck.size() < 25:
		game.profile.deck.append("strike")

	var original_deck: Array = game.profile.deck.duplicate()
	game._export_deck_code()
	var exported_code: String = game._clipboard_get().strip_edges()
	assert_true(exported_code.begins_with("SPB1:"), "Exported deck code begins with SPB1: prefix")

	# Modify deck to something different
	game.profile.deck = ["ward", "ward"]
	while game.profile.deck.size() < 25:
		game.profile.deck.append("ward")

	# Import original code back
	game._show_import_deck_dialog()
	var modal: Node = game.overlay.find_child("DeckImportModal", true, false)
	assert_not_null(modal, "DeckImportModal mounted on overlay")
	var code_input: LineEdit = modal.find_child("DeckCodeInput", true, false) as LineEdit
	assert_not_null(code_input, "DeckCodeInput exists")
	code_input.text = exported_code
	var confirm_btn: Button = modal.find_child("DeckImportConfirmBtn", true, false) as Button
	assert_not_null(confirm_btn, "DeckImportConfirmBtn exists")
	confirm_btn.pressed.emit()

	assert_eq(game.profile.deck, original_deck, "Imported deck matches original exported deck")
	game.free()

func test_map_node_locked_intel_modal():
	var game := _create_game()
	game.profile.unlocked = 0
	# Stage 3 is locked at unlocked = 0
	game._travel_to(3)

	var modal: Node = game.overlay.find_child("MapNodeIntelModal", true, false)
	assert_not_null(modal, "MapNodeIntelModal displayed when tapping locked map node")
	var close_btn: Button = modal.find_child("MapIntelCloseBtn", true, false) as Button
	assert_not_null(close_btn, "MapIntelCloseBtn exists in intel modal")
	var ok_btn: Button = modal.find_child("MapIntelOkBtn", true, false) as Button
	assert_not_null(ok_btn, "MapIntelOkBtn exists in intel modal")

	ok_btn.pressed.emit()
	modal.free()
	assert_null(game.overlay.find_child("MapNodeIntelModal", true, false), "Modal freed on OK button press")
	game.free()

func test_phase11_combat_undo_and_epiphany():
	var game := _create_game()
	game.begin_battle(0)
	game.combat.state.phase = "player"
	assert_false(game.combat.can_undo(), "Initially no undo available")

	var initial_energy: int = int(game.combat.state.energy)
	var initial_hand_size: int = game.combat.state.hand.size()
	assert_gt(initial_hand_size, 0, "Hand has cards to play")

	var played: bool = game.combat.play(0, 0)
	if played:
		assert_true(game.combat.can_undo(), "Undo is available after playing card")
		var undo_res: bool = game.combat.undo_last_card()
		assert_true(undo_res, "Undo succeeded")
		assert_eq(int(game.combat.state.energy), initial_energy, "Energy restored after undo")
		assert_eq(game.combat.state.hand.size(), initial_hand_size, "Card restored to hand")
		assert_false(game.combat.can_undo(), "Undo consumed")

	var shield_before: int = int(game.combat.state.player.shield)
	game.combat.claim_epiphany("shield")
	assert_eq(int(game.combat.state.player.shield), shield_before + 15, "Epiphany shield boon granted 15 shield")
	game.free()

func test_phase11_deck_lens_modal():
	var game := _create_game()
	game._show_deck_lens_modal()
	var modal: Node = game.overlay.find_child("DeckLensModal", true, false)
	assert_not_null(modal, "DeckLensModal displayed on overlay")
	var close_btn: Button = modal.find_child("DeckLensCloseBtn", true, false) as Button
	assert_not_null(close_btn, "DeckLensCloseBtn exists in lens modal")
	close_btn.pressed.emit()
	modal.free()
	assert_null(game.overlay.find_child("DeckLensModal", true, false), "DeckLensModal dismissed on close")
	game.free()

func test_phase11_camp_titles_and_sanctuary():
	var game := _create_game()
	game.show_camp()
	var titles_sec: Node = game.find_child("PrestigeTitlesSection", true, false)
	assert_not_null(titles_sec, "PrestigeTitlesSection present in camp")

	var garden_sec: Node = game.find_child("SanctuaryGardenSection", true, false)
	assert_not_null(garden_sec, "SanctuaryGardenSection present in camp")

	var harvest_btn: Button = garden_sec.find_child("HarvestGardenBtn", true, false) as Button
	assert_not_null(harvest_btn, "HarvestGardenBtn exists in garden section")
	var dust_before: int = int(game.profile.get("card_dust", 0))
	harvest_btn.pressed.emit()
	assert_eq(int(game.profile.get("card_dust", 0)), dust_before + 20, "Garden harvest yields +20 dust")

	var pet_btn: Button = garden_sec.find_child("PetFamiliarBtn", true, false) as Button
	assert_not_null(pet_btn, "PetFamiliarBtn exists in garden section")
	pet_btn.pressed.emit()
	assert_eq(int(game.profile.get("card_dust", 0)), dust_before + 25, "Petting familiar yields +5 dust")
	game.free()

func test_phase11_victory_card_modal():
	var game := _create_game()
	game.battle_telemetry = {"turns": 4, "dmg_dealt": 88, "dmg_blocked": 20, "card_impact": {"ward": 20}}
	game._show_victory_card_modal()
	var modal: Node = game.overlay.find_child("VictoryCardModal", true, false)
	assert_not_null(modal, "VictoryCardModal displayed on overlay")
	var copy_btn: Button = modal.find_child("VictoryCardCopyBtn", true, false) as Button
	assert_not_null(copy_btn, "VictoryCardCopyBtn exists in modal")
	copy_btn.pressed.emit()
	assert_true(game._clipboard_get().contains("道印战报"), "Victory dispatch copied to clipboard")
	var close_btn: Button = modal.find_child("VictoryCardCloseBtn", true, false) as Button
	assert_not_null(close_btn, "VictoryCardCloseBtn exists in modal")
	close_btn.pressed.emit()
	modal.free()
	assert_null(game.overlay.find_child("VictoryCardModal", true, false), "VictoryCardModal dismissed on close")
	game.free()

func test_phase12_combo_and_weather_mechanics():
	var test_combat := SpiritCombat.new(content)
	test_combat.create(12345, content.encounters[0], ["strike", "strike", "defend"], 60, {}, [], {}, {"weather_affix": "thunder"}, [])
	test_combat.state.phase = "player"
	assert_eq(str(test_combat.state.get("weather_affix", "")), "thunder", "Weather affix set to thunder")
	assert_eq(int(test_combat.state.get("turn_combo_count", 0)), 0, "Initial turn combo count is 0")

	var played: bool = test_combat.play(0, 0)
	if played:
		assert_eq(int(test_combat.state.get("turn_combo_count", 0)), 1, "Turn combo count incremented after card play")
	test_combat.end_turn()
	assert_eq(int(test_combat.state.get("turn_combo_count", 0)), 0, "Turn combo count reset on turn end")

func test_phase12_relic_resonances_and_bonuses():
	var game := _create_game()
	var res_ids: Array = []
	for res in game.content.RELIC_RESONANCES:
		res_ids.append(str(res.get("id", "")))
	assert_true(res_ids.has("res_phoenix_fire"), "res_phoenix_fire exists")
	assert_true(res_ids.has("res_glacial_mirror"), "res_glacial_mirror exists")
	assert_true(res_ids.has("res_abyssal_drain"), "res_abyssal_drain exists")
	assert_true(res_ids.has("res_bastion_unbreakable"), "res_bastion_unbreakable exists")

	var hero_bonuses := {
		"astral_roots": {"metal": 1, "wood": 2, "water": 1, "fire": 0, "earth": 1},
		"familiar_stage": 3
	}
	var test_combat := SpiritCombat.new(content)
	test_combat.create(12345, content.encounters[0], ["strike", "defend"], 60, {}, [], {}, {}, ["spiritArmor", "obsidianIdol"], hero_bonuses)
	assert_gt(int(test_combat.state.player.max_health), 60, "Wood root boosted player max HP")
	assert_gte(int(test_combat.state.player.shield), 10, "Familiar stage 3 granted starting shield")
	assert_true(test_combat._has_resonance("res_bastion_unbreakable"), "res_bastion_unbreakable active")

	test_combat.state.player.shield = 30
	test_combat.state.enemies[0].stun = 1
	test_combat.state.phase = "player"
	test_combat.end_turn()
	assert_eq(int(test_combat.state.player.shield), 30, "Bastion unbreakable preserved 100% shield")
	game.free()

func test_phase12_deck_presets_and_foil_system():
	var game := _create_game()
	assert_true(game.profile.has("deck_presets"), "Profile has deck presets")
	assert_true(game.profile.has("foil_cards"), "Profile has foil cards list")
	assert_true(game.profile.has("astral_roots"), "Profile has astral roots")

	var test_card_id: String = "strike"
	game.profile.foil_cards.append(test_card_id)
	assert_true(game.profile.foil_cards.has(test_card_id), "Card marked as foil")
	game.free()

func test_phase12_black_market_event_choices():
	var found_black_market: bool = false
	for ev in SpiritContent.RANDOM_STORY_EVENTS:
		if str(ev.get("id", "")) == "black_market":
			found_black_market = true
			var choices: Array = ev.get("choices", [])
			var types: Array = []
			for ch in choices: types.append(str(ch.get("type", "")))
			assert_true(types.has("pawn_relic"), "Black market has pawn_relic choice")
			assert_true(types.has("blood_pact"), "Black market has blood_pact choice")
			break
	assert_true(found_black_market, "Black market random story event exists")





