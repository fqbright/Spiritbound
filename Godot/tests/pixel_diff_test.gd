extends SceneTree

const BASELINE_DIR := "res://tests/snapshots/baselines"
const SNAPSHOT_DIR := "res://tests/snapshots"
const DIFF_OUTPUT_DIR := "res://tests/snapshots/diffs"

var failures := 0

func fail(message: String) -> void:
	failures += 1
	print("  ❌ FAIL: %s" % message)
	printerr("  ❌ FAIL: %s" % message)

func check(condition: bool, message: String) -> void:
	if condition:
		print("  ✅ ok: %s" % message)
	else:
		fail(message)

func diff_images(img_a: Image, img_b: Image, tolerance: float = 0.08) -> Dictionary:
	var w: int = img_a.get_width()
	var h: int = img_a.get_height()
	if w != img_b.get_width() or h != img_b.get_height():
		return {
			"dimension_mismatch": true,
			"diff_pixels": w * h,
			"total_pixels": w * h,
			"diff_ratio": 1.0,
			"diff_image": null
		}

	var total_pixels: int = w * h
	var diff_pixels: int = 0
	var diff_img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in h:
		for x in w:
			var c1: Color = img_a.get_pixel(x, y)
			var c2: Color = img_b.get_pixel(x, y)
			var delta: float = (absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b) + absf(c1.a - c2.a)) / 4.0

			if delta > tolerance:
				diff_pixels += 1
				# Highlight difference in bright magenta
				diff_img.set_pixel(x, y, Color(1.0, 0.05, 0.55, 1.0))
			else:
				# Dim background to make differences pop
				diff_img.set_pixel(x, y, Color(c1.r * 0.15, c1.g * 0.15, c1.b * 0.15, 1.0))

	var ratio: float = float(diff_pixels) / float(total_pixels)
	return {
		"dimension_mismatch": false,
		"diff_pixels": diff_pixels,
		"total_pixels": total_pixels,
		"diff_ratio": ratio,
		"diff_image": diff_img
	}

func _initialize() -> void:
	_run()

func _run() -> void:
	print("\n========================================================")
	print("  SPIRITBOUND VISUAL PIXEL-DIFF TEST SUITE")
	print("========================================================\n")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIFF_OUTPUT_DIR))

	# -------------------------------------------------------------------------
	# TEST CASE 1: Identity Comparison (0% diff)
	# -------------------------------------------------------------------------
	print("Test 1: Identity Self-Comparison...")
	var test_img := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	test_img.fill(Color(0.2, 0.5, 0.8, 1.0))
	var self_res: Dictionary = diff_images(test_img, test_img)
	check(float(self_res.diff_ratio) == 0.0, "Self-comparison produces exact 0.0% difference")
	check(int(self_res.diff_pixels) == 0, "Self-comparison produces 0 differing pixels")

	# -------------------------------------------------------------------------
	# TEST CASE 2: Synthetic Mutation Detection
	# -------------------------------------------------------------------------
	print("\nTest 2: Synthetic Mutation & Anomaly Detection...")
	var mutated_img := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	mutated_img.fill(Color(0.2, 0.5, 0.8, 1.0))
	# Inject a 20x20 red square anomaly
	for y in range(40, 60):
		for x in range(40, 60):
			mutated_img.set_pixel(x, y, Color.RED)

	var anomaly_res: Dictionary = diff_images(test_img, mutated_img)
	var expected_ratio: float = 400.0 / 10000.0 # 4.0%
	check(is_equal_approx(float(anomaly_res.diff_ratio), expected_ratio), "Anomaly detection matches expected 4.0%% diff (got %.2f%%%%)" % (anomaly_res.diff_ratio * 100.0))
	check(int(anomaly_res.diff_pixels) == 400, "Exact 400 anomalous pixels identified")
	check(anomaly_res.diff_image != null, "Diff delta heatmap image generated")

	# -------------------------------------------------------------------------
	# TEST CASE 3: Core Mobile Screen Baselines Verification
	# -------------------------------------------------------------------------
	print("\nTest 3: Core Mobile Screen Baseline Pixel Comparisons...")
	var screens := [
		"01_map_screen.png",
		"02_battle_screen.png",
		"03_rewards_screen.png",
		"04_shop_screen.png",
		"05_deck_screen.png",
		"06_camp_screen.png",
		"07_treasury_inspector.png"
	]

	var max_allowed_tolerance := 0.02 # 2.0% allowed for font hinting/particle noise

	for screen_file in screens:
		var baseline_path := "%s/%s" % [BASELINE_DIR, screen_file]
		var current_path := "%s/%s" % [SNAPSHOT_DIR, screen_file]

		if not FileAccess.file_exists(baseline_path):
			print("  ⚠️ Skipping %s: baseline does not exist yet" % screen_file)
			continue
		if not FileAccess.file_exists(current_path):
			print("  ⚠️ Skipping %s: current snapshot does not exist yet" % screen_file)
			continue

		var img_base := Image.load_from_file(ProjectSettings.globalize_path(baseline_path))
		var img_curr := Image.load_from_file(ProjectSettings.globalize_path(current_path))

		if img_base == null or img_curr == null:
			fail("Failed loading image pair for %s" % screen_file)
			continue

		var res: Dictionary = diff_images(img_base, img_curr)
		var diff_pct: float = float(res.diff_ratio) * 100.0

		if float(res.diff_ratio) <= max_allowed_tolerance:
			check(true, "%s matches baseline within threshold (diff: %.2f%%%%)" % [screen_file, diff_pct])
		else:
			var diff_save_path := "%s/diff_%s" % [DIFF_OUTPUT_DIR, screen_file]
			if res.diff_image != null:
				res.diff_image.save_png(ProjectSettings.globalize_path(diff_save_path))
			fail("%s exceeded visual difference threshold (got %.2f%%%%, max allowed %.2f%%%%). Diff saved to %s" % [screen_file, diff_pct, max_allowed_tolerance * 100.0, diff_save_path])

	if failures == 0:
		print("\n🏆 PIXEL-DIFF TEST SUITE: ALL CHECKS PASSED (0 FAILURES)\n")
		quit(0)
	else:
		print("\n💥 PIXEL-DIFF TEST SUITE: FAILED WITH %d ERRORS\n" % failures)
		quit(1)
