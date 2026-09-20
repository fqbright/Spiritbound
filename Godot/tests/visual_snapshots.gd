extends SceneTree

const SNAPSHOT_DIR := "res://tests/snapshots"

func _initialize() -> void:
	_run()

func _freeze_for_snapshot(game: Control) -> void:
	# 1. Disable ambient particle emitters so motes don't cause random noise
	for p in game.find_children("", "CPUParticles2D", true, false):
		var cpu := p as CPUParticles2D
		cpu.emitting = false
		cpu.speed_scale = 0.0
	for p in game.find_children("", "GPUParticles2D", true, false):
		var gpu := p as GPUParticles2D
		gpu.emitting = false
		gpu.speed_scale = 0.0

	# 2. Pause active tweens so idle bobbing / breathing pauses deterministically
	for t in game.get_tree().get_processed_tweens():
		if t and t.is_valid():
			t.pause()

	# 3. Disable caret blinking on text inputs
	for le in game.find_children("", "LineEdit", true, false):
		(le as LineEdit).caret_blink = false

func _capture_screen(game: Control, filename: String) -> void:
	# Yield frames to ensure UI elements are positioned
	for _i in 3:
		await process_frame

	# Deterministic freeze
	_freeze_for_snapshot(game)
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

	# Setup deterministic mock profile with constant timestamps
	game.profile = SpiritSave.defaults(game.content)
	game.profile.gold = 420
	game.profile.spirit_jade = 85
	game.profile.currencies = {
		"gold": 420,
		"spirit_jade": 85,
		"trial_token": 60,
		"abyss_shard": 15
	}
	# Freeze timestamps so countdown labels never vary
	game.profile.stamina = {
		"current": 85,
		"max": 100,
		"last_regen_time": 1700000000
	}
	game.profile.daily_reset_at = 1700086400
	game.profile.weekly_reset_at = 1700600000
	game.profile.tutorial_seen = true
	game.lang = "zh-Hans"
	# The shop's daily stock/sale/rune/relic (game_shop_deck_screen.gd's _shop_period(), via
	# game._current_day()) is a pure function of the real calendar day, so its baseline would
	# otherwise silently bake in whatever day it happened to be captured and then genuinely
	# differ — not flake, actually differ — the next time the real date rolls over. Same "wall-
	# clock content defeats a visual-diff threshold" shape as the battle screen's fix just below,
	# just on a day boundary instead of a per-battle one, so it survives many back-to-back
	# captures before ever showing up. Pinned to an arbitrary fixed day for the same reason the
	# battle screen below is pinned to a fixed hand/enemy count.
	game.test_day_override = 20000
	await process_frame

	# 1. Map Screen
	print("1/9 Rendering Map Screen...")
	game.show_map()
	await _capture_screen(game, "01_map_screen.png")

	# 2. Battle Screen
	print("2/9 Rendering Battle Screen...")
	game.begin_battle(0)
	await process_frame
	# begin_battle()'s per-battle modifier and draw shuffle are both seeded from wall-clock time
	# (see game_battle_screen.gd's own comment on begin_battle()'s seed line), so this screen
	# would otherwise show a different hand on every capture, and roughly one capture in ten an
	# extra "swarm" enemy — measured to eat most of this screen's diff-tolerance budget on its
	# own when comparing two back-to-back captures of an otherwise-unchanged pipeline. Force both
	# back to a fixed, representative state and re-render — the same "poke combat state
	# directly, then rebuild the screen" pattern ui_smoke.gd's finishing-blow test uses for the
	# same reason.
	if game.combat.state.enemies.size() > 1:
		game.combat.state.enemies.resize(1)
	game.combat.state.hand = [
		{"uid": 90001, "card_id": "strike"},
		{"uid": 90002, "card_id": "ward"},
		{"uid": 90003, "card_id": "strike"},
		{"uid": 90004, "card_id": "ward"},
		{"uid": 90005, "card_id": "strike"},
	]
	game.show_battle()
	await process_frame
	for _i in 10:
		await process_frame
	await _capture_screen(game, "02_battle_screen.png")

	# 3. Rewards & Loot Screen
	print("3/9 Rendering Rewards Screen...")
	game._grant_stage_rewards()
	game.show_reward_details()
	await _capture_screen(game, "03_rewards_screen.png")

	# 4. Shop Screen
	print("4/9 Rendering Shop Screen...")
	game.show_shop()
	await _capture_screen(game, "04_shop_screen.png")

	# 5. Deck Screen
	print("5/9 Rendering Deck Screen...")
	game.show_deck()
	await _capture_screen(game, "05_deck_screen.png")

	# 6. Camp Hub Screen
	print("6/9 Rendering Camp Hub Screen...")
	game.show_camp()
	await _capture_screen(game, "06_camp_screen.png")

	# 7. Treasury Inspector Modal
	print("7/9 Rendering Treasury Inspector...")
	game.show_map()
	await process_frame
	game.show_treasury_inspector()
	await _capture_screen(game, "07_treasury_inspector.png")

	# 8. Career Codex Screen
	print("8/9 Rendering Career Codex Screen...")
	game.compendium_tab = "codex"
	game.show_compendium()
	await _capture_screen(game, "08_codex_screen.png")

	# 9. Trial Challenges Screen — the screen this snapshotter was missing entirely, which is why
	# the duplicate-banner problem (two cards sharing banner_phantom_arena.png) survived: nothing
	# ever rendered it for review. Forced to a mid-game state so every mode is unlocked, since a
	# default profile shows eight of ten cards lock-collapsed and none of the real layout.
	print("9/9 Rendering Trial Challenges Screen...")
	game.profile.unlocked = 20
	game.profile.difficulty = 1
	game.camp_tab = "challenges"
	game.show_challenges()
	await _capture_screen(game, "09_challenges_screen.png")

	print("\n========================================================")
	print("  🎉 ALL 9 SCREENSHOTS CAPTURED TO Godot/tests/snapshots/")
	print("========================================================\n")
	quit(0)
