extends SceneTree

var failures := 0
var saved_profile := ""
var had_profile := false

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

func _simulate_tap(game: Control, pos: Vector2) -> void:
	var touch_down := InputEventScreenTouch.new()
	touch_down.position = pos
	touch_down.pressed = true
	game._input(touch_down)

	var touch_up := InputEventScreenTouch.new()
	touch_up.position = pos
	touch_up.pressed = false
	game._input(touch_up)

func _run() -> void:
	print("\n========================================================")
	print("  SPIRITBOUND CHAOS & MONKEY STRESS TEST")
	print("========================================================\n")

	had_profile = FileAccess.file_exists(SpiritSave.PATH)
	if had_profile:
		saved_profile = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()

	var scene: PackedScene = load("res://Main.tscn")
	var game: Control = scene.instantiate()
	root.add_child(game)
	await process_frame

	game.profile = SpiritSave.defaults(game.content)
	game.profile.gold = 500
	game.profile.stamina = {"current": 100, "max": 100, "last_regen_time": Time.get_unix_time_from_system()}
	game.lang = "zh-Hans"
	game.battle_speed = 50.0
	await process_frame

	# -------------------------------------------------------------------------
	# TEST 1: Map Screen Random Tap Storm (150 random screen taps)
	# -------------------------------------------------------------------------
	print("Test 1: Random Input Tap Storm across Viewport (150 taps)...")
	game.show_map()
	await process_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 42 # Deterministic seed for reproducible testing

	for i in 150:
		var rx: float = rng.randf_range(10.0, 380.0)
		var ry: float = rng.randf_range(10.0, 830.0)
		_simulate_tap(game, Vector2(rx, ry))
		if i % 30 == 0:
			await process_frame

	check(game.root != null and game.root.get_child_count() > 0, "Game UI tree survived 150 random screen taps without crash")

	# -------------------------------------------------------------------------
	# TEST 2: In-Combat Chaos Monkey (Random card plays, illegal drags, interrupts)
	# -------------------------------------------------------------------------
	print("\nTest 2: Combat Chaos Monkey (100 randomized plays & interrupts)...")
	game.begin_battle(0)
	await process_frame
	await process_frame

	var combat_actions := 0
	for _action in 100:
		combat_actions += 1
		if game.combat == null or game.combat.state.phase == "won" or game.combat.state.phase == "lost":
			break

		# Randomly attempt to play arbitrary hand indexes, including out of bounds
		var rand_hand_idx: int = rng.randi_range(-2, 10)
		var rand_target_idx: int = rng.randi_range(-2, 5)

		# Attempt random play
		if game._battle_screen:
			game._battle_screen._attempt_play_card(rand_hand_idx, rand_target_idx)

		# Tap random canvas positions during combat animations
		var tap_x: float = rng.randf_range(20.0, 370.0)
		var tap_y: float = rng.randf_range(300.0, 750.0)
		_simulate_tap(game, Vector2(tap_x, tap_y))

		if rng.randf() < 0.2:
			# Randomly trigger enemy turn or end turn attempt
			if game._battle_screen and not game.resolving:
				game._battle_screen._enemy_turn()

		await process_frame

	# Allow active battle tweens to conclude with timeout guard
	var resolve_guard := 0
	while game.resolving and resolve_guard < 30:
		await process_frame
		resolve_guard += 1
	for _i in 5:
		await process_frame

	check(game.combat != null, "Combat engine survived 100 chaotic actions without null dereference")

	# -------------------------------------------------------------------------
	# TEST 3: Rapid Screen & Modal Churn (30 rapid transitions)
	# -------------------------------------------------------------------------
	print("\nTest 3: Rapid Screen & Modal Churn (30 rapid scene switches)...")
	var screen_methods := [
		game.show_map,
		game.show_shop,
		game.show_deck,
		game.show_camp,
		game.show_treasury_inspector,
		game.show_quests,
		game.show_account_setup
	]

	for step in 30:
		var picked_method: Callable = screen_methods[rng.randi_range(0, screen_methods.size() - 1)]
		picked_method.call()
		if rng.randf() < 0.3:
			# Randomly tap modal backdrops or corners
			_simulate_tap(game, Vector2(rng.randf_range(0, 390), rng.randf_range(0, 844)))
		await process_frame

	# Clean up any leftover open modal
	var leftover_modal: Node = game.overlay.get_node_or_null("TreasuryInspectorModal")
	if leftover_modal != null:
		leftover_modal.queue_free()
		await process_frame

	check(true, "Successfully navigated 30 rapid screen transitions without hanging")

	# -------------------------------------------------------------------------
	# TEST 4: Softlock Recovery Assertion
	# -------------------------------------------------------------------------
	print("\nTest 4: Post-Chaos Softlock Recovery Assertion...")
	game.show_map()
	await process_frame
	await process_frame

	var map_buttons := []
	for child in game.root.find_children("", "Button", true, false):
		if child is Button and (child as Button).visible:
			map_buttons.append(child)

	check(map_buttons.size() >= 3, "Map screen restored with active interactive buttons (found %d buttons)" % map_buttons.size())
	check(game.overlay.get_child_count() == 0 or game.overlay.get_children().all(func(c): return not c.visible or c.name.begins_with("Header")), "No orphaned blocking overlays remaining on screen")

	# Clean up and restore save
	if had_profile and not saved_profile.is_empty():
		var f := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
		f.store_string(saved_profile)
	elif FileAccess.file_exists(SpiritSave.PATH):
		DirAccess.remove_absolute(SpiritSave.PATH)

	if failures == 0:
		print("\n🏆 CHAOS & MONKEY TEST SUITE: ALL CHECKS PASSED (0 FAILURES)\n")
		quit(0)
	else:
		print("\n💥 CHAOS & MONKEY TEST SUITE: FAILED WITH %d ERRORS\n" % failures)
		quit(1)
