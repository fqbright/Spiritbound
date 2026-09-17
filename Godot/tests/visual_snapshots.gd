extends SceneTree

const SNAPSHOT_DIR := "res://tests/snapshots"

func _initialize() -> void:
	_run()

func _capture_screen(filename: String) -> void:
	# Yield frames and force redraw pass
	for _i in 3:
		await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var img: Image = root.get_texture().get_image()
	if img != null:
		var full_path := "%s/%s" % [SNAPSHOT_DIR, filename]
		var err := img.save_png(full_path)
		if err == OK:
			print("  📸 Captured [%s] -> %s (%dx%d)" % [filename, full_path, img.get_width(), img.get_height()])
		else:
			printerr("  ❌ Failed saving snapshot %s: error %d" % [full_path, err])
	else:
		printerr("  ❌ Viewport image was null for %s" % filename)

func _run() -> void:
	print("\n========================================================")
	print("  SPIRITBOUND MOBILE VISUAL SNAPSHOTTER (390x844)")
	print("========================================================\n")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SNAPSHOT_DIR))

	var scene: PackedScene = load("res://Main.tscn")
	var game: Control = scene.instantiate()
	root.add_child(game)
	await process_frame

	# Setup baseline mock profile
	game.profile = SpiritSave.defaults(game.content)
	game.profile.gold = 420
	game.profile.spirit_jade = 85
	game.profile.currencies = {
		"gold": 420,
		"spirit_jade": 85,
		"trial_token": 60,
		"abyss_shard": 15
	}
	game.profile.stamina = {
		"current": 85,
		"max": 100,
		"last_regen_time": Time.get_unix_time_from_system()
	}
	game.lang = "zh-Hans"
	await process_frame

	# 1. Map Screen
	print("1/7 Rendering Map Screen...")
	game.show_map()
	await _capture_screen("01_map_screen.png")

	# 2. Battle Screen
	print("2/7 Rendering Battle Screen...")
	game.begin_battle(0)
	await process_frame
	for _i in 10:
		await process_frame
	await _capture_screen("02_battle_screen.png")

	# 3. Rewards & Loot Screen
	print("3/7 Rendering Rewards Screen...")
	game._grant_stage_rewards()
	game.show_reward_details()
	await _capture_screen("03_rewards_screen.png")

	# 4. Shop Screen
	print("4/7 Rendering Shop Screen...")
	game.show_shop()
	await _capture_screen("04_shop_screen.png")

	# 5. Deck Screen
	print("5/7 Rendering Deck Screen...")
	game.show_deck()
	await _capture_screen("05_deck_screen.png")

	# 6. Camp Hub Screen
	print("6/7 Rendering Camp Hub Screen...")
	game.show_camp()
	await _capture_screen("06_camp_screen.png")

	# 7. Treasury Inspector Modal
	print("7/7 Rendering Treasury Inspector...")
	game.show_map()
	await process_frame
	game.show_treasury_inspector()
	await _capture_screen("07_treasury_inspector.png")

	print("\n========================================================")
	print("  🎉 ALL 7 SCREENSHOTS CAPTURED TO Godot/tests/snapshots/")
	print("========================================================\n")
	quit(0)
