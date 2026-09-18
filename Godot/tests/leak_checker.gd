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

func _settle() -> void:
	for _i in 5:
		await process_frame

func _run() -> void:
	print("\n========================================================")
	print("  SPIRITBOUND MEMORY & OBJECT LEAK PROFILER")
	print("========================================================\n")

	had_profile = FileAccess.file_exists(SpiritSave.PATH)
	if had_profile:
		saved_profile = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()

	var scene: PackedScene = load("res://Main.tscn")
	var game: Control = scene.instantiate()
	root.add_child(game)
	await _settle()

	game.profile = SpiritSave.defaults(game.content)
	game.profile.gold = 500
	game.profile.spirit_jade = 100
	game.lang = "zh-Hans"
	game.battle_speed = 50.0
	game.show_map()
	await _settle()

	var base_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var base_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var base_mem_mb: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)

	print("Initial Engine Baseline:")
	print("  • Active Nodes:  %d" % base_nodes)
	print("  • Living Objects: %d" % base_objects)
	print("  • Static Memory:  %.2f MB\n" % base_mem_mb)

	# -------------------------------------------------------------------------
	# TEST 1: Modal Churn Leak Check (Open & Close 8 times)
	# -------------------------------------------------------------------------
	print("Test 1: Modal Open/Dismiss Lifecycle (8 cycles)...")
	for i in 8:
		game.show_treasury_inspector()
		await process_frame
		var modal: Node = game.overlay.get_node_or_null("TreasuryInspectorModal")
		if modal:
			modal.queue_free()
		await process_frame

	await _settle()
	var post_modal_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var modal_node_delta: int = post_modal_nodes - base_nodes
	check(modal_node_delta <= 5, "Modal open/close leaves no orphaned nodes (delta: %d nodes, allowed <= 5)" % modal_node_delta)

	# -------------------------------------------------------------------------
	# TEST 1b: SamsaraModal Churn Leak Check (C2, added 2026-09-17 alongside the feature
	# itself — the only other modal this profiler knew about was the pre-existing
	# TreasuryInspectorModal above, and AGENTS.md's "every new feature needs tests" rule
	# extends to this profiler too, not just ui_smoke.gd's functional coverage).
	# -------------------------------------------------------------------------
	print("\nTest 1b: SamsaraModal Open/Dismiss Lifecycle (8 cycles)...")
	game.profile.unlocked = 250
	game.profile.difficulty = 5
	game.camp_tab = "challenges"
	game.show_camp()
	await _settle()
	# A fresh baseline taken on this same screen/tab right before the churn loop, rather than
	# reusing the shared base_nodes captured on the map screen at the very top: Camp's
	# Challenges tab (9 stacked sections) legitimately has more static nodes than the map, and
	# a much-further-progressed profile.unlocked also changes what the map itself renders, so
	# comparing this test's post-churn count against that unrelated baseline produced a
	# false-positive "leak" that had nothing to do with the modal open/close cycle under test.
	var samsara_base_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 8:
		game.show_camp()
		await process_frame
		var samsara_enter_btn: Button = game.root.find_child("SamsaraEnterBtn", true, false) as Button
		if samsara_enter_btn:
			samsara_enter_btn.pressed.emit()
			await process_frame
		var samsara_modal: Node = game.overlay.get_node_or_null("SamsaraModal")
		if samsara_modal:
			samsara_modal.queue_free()
		await process_frame

	await _settle()
	var post_samsara_modal_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var samsara_modal_node_delta: int = post_samsara_modal_nodes - samsara_base_nodes
	check(samsara_modal_node_delta <= 5, "SamsaraModal open/close leaves no orphaned nodes (delta: %d nodes, allowed <= 5)" % samsara_modal_node_delta)
	game.profile.unlocked = 0
	game.profile.difficulty = 0
	game.show_map()
	await _settle()

	# -------------------------------------------------------------------------
	# TEST 2: Screen Navigation Round Trips (5 complete cycles)
	# -------------------------------------------------------------------------
	print("\nTest 2: Multi-Screen Navigation Lifecycle (5 round trips)...")
	for i in 5:
		game.show_shop()
		await process_frame
		game.show_deck()
		await process_frame
		game.show_camp()
		await process_frame
		game.show_map()
		await process_frame

	await _settle()
	var post_nav_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var nav_node_delta: int = post_nav_nodes - base_nodes
	check(nav_node_delta <= 10, "Screen navigation returns cleanly to baseline node count (delta: %d nodes, allowed <= 10)" % nav_node_delta)

	# -------------------------------------------------------------------------
	# TEST 3: Combat Enter & Exit Lifecycle (4 cycles)
	# -------------------------------------------------------------------------
	print("\nTest 3: Combat Enter & Exit Lifecycle (4 cycles)...")
	for i in 4:
		game.begin_battle(0)
		await process_frame
		await process_frame
		# Exit back to map
		game.show_map()
		await process_frame
		await process_frame

	await _settle()
	var post_combat_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var combat_node_delta: int = post_combat_nodes - base_nodes
	check(combat_node_delta <= 15, "Combat entry/exit cleans up all battle UI and monster nodes (delta: %d nodes, allowed <= 15)" % combat_node_delta)

	var final_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var final_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var final_mem_mb: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)

	print("\n--------------------------------------------------------")
	print("  📊 Memory & Object Profiling Summary:")
	print("  • Initial Nodes:  %d  -> Final: %d (net delta: %+d)" % [base_nodes, final_nodes, final_nodes - base_nodes])
	print("  • Initial Objects: %d -> Final: %d (net delta: %+d)" % [base_objects, final_objects, final_objects - base_objects])
	print("  • Memory Usage:   %.2f MB -> Final: %.2f MB" % [base_mem_mb, final_mem_mb])
	print("--------------------------------------------------------")

	# Clean up and restore save
	if had_profile and not saved_profile.is_empty():
		var f := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
		f.store_string(saved_profile)
	elif FileAccess.file_exists(SpiritSave.PATH):
		DirAccess.remove_absolute(SpiritSave.PATH)

	if failures == 0:
		print("\n🏆 LEAK PROFILER: ALL CHECKS PASSED (0 UNBOUNDED LEAKS)\n")
		quit(0)
	else:
		print("\n💥 LEAK PROFILER: FAILED WITH %d ERRORS\n" % failures)
		quit(1)
