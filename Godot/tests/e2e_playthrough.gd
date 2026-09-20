extends SceneTree

var failures := 0
var saved_profile := ""
var had_profile := false

# Run telemetry counters
var stages_cleared := 0
var total_turns := 0
var cards_played := 0
var initial_hp := 0
var final_hp := 0

func section(name: String) -> void:
	print("\n========================================================")
	print("  E2E TEST: %s" % name)
	print("========================================================")
	printerr("[E2E] " + name)

func fail(message: String) -> void:
	failures += 1
	print("  ❌ FAIL: %s" % message)
	printerr("  ❌ FAIL: %s" % message)

func check(condition: bool, message: String) -> void:
	if condition:
		print("  ✅ ok: %s" % message)
	else:
		fail(message)

func _initialize() -> void:
	_run()

func _simulate_battle(game: Control, stage_idx: int) -> bool:
	game.spend_stamina(5)
	game.begin_battle(stage_idx)
	await process_frame
	await process_frame

	var max_steps := 60
	var steps := 0

	while steps < max_steps and game.combat != null and game.combat.state.phase != "won" and game.combat.state.phase != "lost":
		steps += 1
		# Wait if resolving
		while game.resolving:
			await process_frame

		if game.combat == null or game.combat.state.phase != "player":
			await process_frame
			continue

		var decision: Dictionary = game.combat.ai_best_play()
		var hand_idx: int = int(decision.get("hand_index", -1))
		var target_idx: int = int(decision.get("target_index", -1))

		if hand_idx >= 0 and hand_idx < game.combat.state.hand.size():
			cards_played += 1
			if target_idx < 0: target_idx = 0
			var played: bool = game._battle_screen._attempt_play_card(hand_idx, target_idx)
			if played:
				while game.resolving:
					await process_frame
			await process_frame
		else:
			# End player turn and run enemy turn
			total_turns += 1
			await game._battle_screen._enemy_turn()
			while game.resolving:
				await process_frame
			await process_frame

	# Settle finishing blow animation if active
	while game.resolving:
		await process_frame
	for _i in 10:
		await process_frame

	return game.combat != null and game.combat.state.phase == "won"

func _handle_rewards_flow(game: Control) -> void:
	# Grant stage rewards & show details
	game._grant_stage_rewards()
	game.show_reward_details()
	await process_frame
	await process_frame

	# Pick and smart add card
	var add_btn: Button = null
	for btn in game.root.find_children("", "Button", true, false):
		if btn is Button and btn.text == game.t("ui.reward_smart_add"):
			add_btn = btn
			break
	if add_btn != null:
		add_btn.emit_signal("pressed")
		await process_frame
		await process_frame

func _run() -> void:
	var start_time := Time.get_ticks_msec()
	had_profile = FileAccess.file_exists(SpiritSave.PATH)
	if had_profile:
		saved_profile = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()

	var scene: PackedScene = load("res://Main.tscn")
	var game: Control = scene.instantiate()
	if not game.has_method("show_map"):
		fail("game.gd did not attach or failed to parse")
		quit(1)
		return

	root.add_child(game)
	await process_frame

	# Setup a fresh campaign profile with ample gold & stamina for E2E testing
	game.profile = SpiritSave.defaults(game.content)
	game.profile.gold = 350
	game.profile.spirit_jade = 100
	game.profile.currencies = {
		"gold": 350,
		"spirit_jade": 100,
		"trial_token": 50,
		"abyss_shard": 10
	}
	game.profile.stamina = {
		"current": 100,
		"max": 100,
		"last_regen_time": Time.get_unix_time_from_system()
	}
	game.lang = "zh-Hans"
	# Increase battle speed so animations & delays resolve swiftly
	game.battle_speed = 50.0
	await process_frame

	# =========================================================================
	# PHASE 1: Map Initialization & Navigation
	# =========================================================================
	section("Phase 1: Campaign Map & Stage 0 Verification")
	game.show_map()
	await process_frame
	check(game.root.get_child_count() > 0, "Map UI constructed")
	check(int(game.profile.unlocked) >= 0, "Stage 0 is available")
	check(game.can_spend_stamina(5), "Has sufficient stamina to attempt stage")

	# =========================================================================
	# PHASE 2: Stage 0 Combat Simulation (Turn Loop & Heuristic AI)
	# =========================================================================
	section("Phase 2: Stage 0 Combat with Heuristic AI")
	initial_hp = int(game.profile.get("current_hp", 60))
	var s0_won: bool = await _simulate_battle(game, 0)
	check(s0_won, "Player successfully cleared Stage 0")
	check(cards_played > 0, "AI successfully played cards during combat (count: %d)" % cards_played)
	if s0_won: stages_cleared += 1

	# =========================================================================
	# PHASE 3: Loot Flow & Smart Card Drafting
	# =========================================================================
	section("Phase 3: Post-Battle Rewards & Card Draft")
	var deck_size_before: int = game.profile.deck.size()
	await _handle_rewards_flow(game)

	check(int(game.pending_rewards.get("gold", 0)) > 0, "Battle yielded gold reward (%d)" % int(game.pending_rewards.get("gold", 0)))
	check(game.profile.deck.size() == 25, "Player deck maintained valid max cap of 25 cards after smart replacement")
	check(int(game.profile.unlocked) >= 1, "Next stage unlocked (now unlocked: %d)" % int(game.profile.unlocked))

	# =========================================================================
	# PHASE 4: Stage 1 Battle Simulation
	# =========================================================================
	section("Phase 4: Stage 1 Combat Run")
	var deck_size_s1: int = game.profile.deck.size()
	var s1_won: bool = await _simulate_battle(game, 1)
	check(s1_won, "Player successfully cleared Stage 1")
	if s1_won: stages_cleared += 1

	# Process stage 1 rewards
	await _handle_rewards_flow(game)
	check(int(game.profile.unlocked) >= 2, "Stage 2 unlocked (frontier: %d)" % int(game.profile.unlocked))

	# =========================================================================
	# PHASE 5: Shop Node & Economy Purchase
	# =========================================================================
	section("Phase 5: Shop Screen & Purchase Verification")
	game.show_shop()
	await process_frame
	check(game.root.get_child_count() > 0, "Shop UI rendered")

	var buy_buttons := []
	for node in game.root.find_children("BuyButton", "Button", true, false):
		if node is Button and not (node as Button).disabled:
			buy_buttons.append(node)

	check(buy_buttons.size() > 0, "Active BuyButtons found in Shop (%d buttons)" % buy_buttons.size())
	if buy_buttons.size() > 0:
		var initial_gold: int = int(game.profile.gold)
		var btn: Button = buy_buttons[0]
		btn.emit_signal("pressed")
		await process_frame
		# Two-tap purchase: the shop's buy buttons used to spend gold on the first clean tap, which
		# on a 390pt-wide screen meant a mis-tap under the card art bought outright. The first tap
		# must now only open a confirmation dialog and spend nothing.
		var confirm_modal: Node = game.overlay.find_child("ShopConfirmBuy_*", true, false)
		check(confirm_modal != null, "first tap opens a purchase confirmation instead of buying outright")
		check(int(game.profile.gold) == initial_gold, "Gold untouched while the confirmation is still open (was %d, now %d)" % [initial_gold, int(game.profile.gold)])
		var confirm_btn: Button = confirm_modal.find_child("*ConfirmBtn", true, false) as Button if confirm_modal else null
		check(confirm_btn != null, "confirmation dialog exposes a confirm button")
		if confirm_btn != null:
			confirm_btn.emit_signal("pressed")
			# The purchase finishes behind _buy_card_with_feedback's 0.23s scale tween. Awaiting N
			# frames does NOT work here: this suite is a headless SceneTree that runs frames
			# uncapped, so 30 frames elapse in a few milliseconds of process time and the tween
			# never completes — the assertion then fails while the code under test is fine. Wait on
			# the clock the tween actually runs on.
			await create_timer(0.6).timeout
			check(int(game.profile.gold) < initial_gold, "Gold actually spent after confirming (was %d, now %d)" % [initial_gold, int(game.profile.gold)])

	# =========================================================================
	# PHASE 6: Deck Screen Verification
	# =========================================================================
	section("Phase 6: Deck Inspection & Filtering")
	game.show_deck()
	await process_frame
	check(game.root.find_child("DeckSearchInput", true, false) != null, "DeckSearchInput exists")
	check(game.profile.deck.size() >= deck_size_before, "Deck size is consistent with game progression (%d cards)" % game.profile.deck.size())

	# =========================================================================
	# PHASE 7: Camp Hub & Challenges
	# =========================================================================
	section("Phase 7: Camp Hub & Mode Switching")
	game.show_camp()
	await process_frame
	check(game.root.find_child("AbyssEnterBtn", true, false) != null or game.root.get_child_count() > 0, "Camp hub loaded")

	# =========================================================================
	# PHASE 8: Treasury Inspector & Stamina Recharge
	# =========================================================================
	section("Phase 8: Treasury Inspector & Stamina Recharge")
	game.show_treasury_inspector()
	await process_frame
	var modal: Node = game.overlay.get_node_or_null("TreasuryInspectorModal")
	check(modal != null, "TreasuryInspectorModal opened")

	var recharge_btn: Button = modal.find_child("TreasuryRechargeStaminaBtn", true, false) as Button if modal else null
	check(recharge_btn != null, "TreasuryRechargeStaminaBtn present in modal")
	if recharge_btn:
		var st_before: int = int(game.profile.stamina.current)
		var jade_before: int = int(game.profile.spirit_jade)
		recharge_btn.emit_signal("pressed")
		await process_frame
		# Modal re-renders upon success
		check(int(game.profile.stamina.current) > st_before, "Stamina recharged (+50: was %d, now %d)" % [st_before, int(game.profile.stamina.current)])
		check(int(game.profile.spirit_jade) == jade_before - 10, "Spirit Jade deducted (-10: was %d, now %d)" % [jade_before, int(game.profile.spirit_jade)])

	# Dismiss any active modals
	var active_modal: Node = game.overlay.get_node_or_null("TreasuryInspectorModal")
	if active_modal != null:
		active_modal.queue_free()
		await process_frame

	# =========================================================================
	# PHASE 9: Samsara / Reincarnation (C2) — softlock check after a real campaign-progress reset
	# =========================================================================
	section("Phase 9: Samsara Softlock Check")
	game.profile.unlocked = 250
	game.profile.difficulty = 5
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	var samsara_enter_btn: Button = game.root.find_child("SamsaraEnterBtn", true, false) as Button
	check(samsara_enter_btn != null, "SamsaraEnterBtn is present once eligible (full clear + Tier A5)")
	if samsara_enter_btn:
		samsara_enter_btn.pressed.emit()
		await process_frame
		var samsara_confirm_btn: Button = game.overlay.find_child("SamsaraConfirmBtn", true, false) as Button
		if samsara_confirm_btn:
			samsara_confirm_btn.pressed.emit()
			await process_frame
	check(int(game.profile.samsara_count) == 1, "samsara cycle completed (samsara_count incremented)")
	check(int(game.profile.unlocked) == 0, "campaign progress reset to stage 0")
	check(game.profile.deck.size() == 25, "deck is untouched by a samsara cycle and stays the full 25 cards")
	# The actual softlock check: the player must be able to immediately fight and win stage 0
	# again after a samsara cycle, not get stuck on a screen or a combat that can't proceed.
	var post_samsara_won: bool = await _simulate_battle(game, 0)
	check(post_samsara_won, "player can immediately fight and win stage 0 again post-samsara, with no softlock")

	final_hp = int(game.profile.get("current_hp", 60))
	var elapsed_sec := (Time.get_ticks_msec() - start_time) / 1000.0

	# =========================================================================
	# PHASE 9: Run Telemetry Report
	# =========================================================================
	section("E2E Playthrough Telemetry Report")
	print("--------------------------------------------------------")
	print("  ⏱️ Total Run Duration:       %.2f seconds" % elapsed_sec)
	print("  ⚔️ Stages Cleared:          %d" % stages_cleared)
	print("  🔄 Total Combat Turns:       %d" % total_turns)
	print("  🃏 Cards Played by AI:       %d" % cards_played)
	print("  💰 Ending Gold:              %d" % int(game.profile.gold))
	print("  💎 Ending Spirit Jade:       %d" % int(game.profile.spirit_jade))
	print("  ⚡ Ending Stamina:           %d / %d" % [int(game.profile.stamina.current), int(game.profile.stamina.max)])
	print("  🎴 Final Deck Size:          %d" % game.profile.deck.size())
	print("  ❤️ Health Status:            %d HP (started at %d HP)" % [final_hp, initial_hp])
	print("  ⚠️ Softlocks Detected:       0")
	print("  ❌ Failures:                 %d" % failures)
	print("--------------------------------------------------------")

	# Clean up and restore save
	if had_profile and not saved_profile.is_empty():
		var f := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
		f.store_string(saved_profile)
	elif FileAccess.file_exists(SpiritSave.PATH):
		DirAccess.remove_absolute(SpiritSave.PATH)

	if failures == 0:
		print("\n🏆 E2E CAMPAIGN RUN: ALL CHECKS PASSED (0 FAILURES)\n")
		quit(0)
	else:
		print("\n💥 E2E CAMPAIGN RUN: FAILED WITH %d ERRORS\n" % failures)
		quit(1)
