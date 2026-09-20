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

# De-flaked Image Diffing:
# 1. Color tolerance: filters subtle subpixel text hinting / antialiasing shifts.
# 2. Morphological 3x3 clustering: filters isolated single-pixel noise (particle motes, GPU raster jitter)
#    while reliably detecting true UI regressions (buttons, text changes, missing icons).
func diff_images(img_a: Image, img_b: Image, color_tolerance: float = 0.10, min_cluster_neighbors: int = 2) -> Dictionary:
	var w: int = img_a.get_width()
	var h: int = img_a.get_height()
	if w != img_b.get_width() or h != img_b.get_height():
		return {
			"dimension_mismatch": true,
			"diff_pixels": w * h,
			"raw_diff_pixels": w * h,
			"total_pixels": w * h,
			"diff_ratio": 1.0,
			"diff_image": null
		}

	var total_pixels: int = w * h
	var raw_diff_count := 0
	var diff_map := []
	diff_map.resize(total_pixels)
	diff_map.fill(false)

	# Pass 1: Measure color distance with perceptual threshold
	for y in h:
		for x in w:
			var c1: Color = img_a.get_pixel(x, y)
			var c2: Color = img_b.get_pixel(x, y)
			var delta: float = (absf(c1.r - c2.r) + absf(c1.g - c2.g) + absf(c1.b - c2.b) + absf(c1.a - c2.a)) / 4.0
			if delta > color_tolerance:
				diff_map[y * w + x] = true
				raw_diff_count += 1

	# Pass 2: Morphological De-noising
	var clustered_diff_count := 0
	var diff_img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in h:
		for x in w:
			var idx: int = y * w + x
			var c1: Color = img_a.get_pixel(x, y)
			if not diff_map[idx]:
				# Matched pixel: dimmed background for visual context
				diff_img.set_pixel(x, y, Color(c1.r * 0.15, c1.g * 0.15, c1.b * 0.15, 1.0))
				continue

			# Check 3x3 neighborhood for connectivity (filter isolated subpixel jitter)
			var neighbors := 0
			for dy in [-1, 0, 1]:
				var ny: int = y + dy
				if ny < 0 or ny >= h: continue
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0: continue
					var nx: int = x + dx
					if nx < 0 or nx >= w: continue
					if diff_map[ny * w + nx]:
						neighbors += 1

			if neighbors >= min_cluster_neighbors:
				clustered_diff_count += 1
				# Highlight true clustered difference in bright magenta
				diff_img.set_pixel(x, y, Color(1.0, 0.05, 0.55, 1.0))
			else:
				# Filtered isolated noise: treat as matched
				diff_img.set_pixel(x, y, Color(c1.r * 0.15, c1.g * 0.15, c1.b * 0.15, 1.0))

	var ratio: float = float(clustered_diff_count) / float(total_pixels)
	return {
		"dimension_mismatch": false,
		"raw_diff_pixels": raw_diff_count,
		"diff_pixels": clustered_diff_count,
		"total_pixels": total_pixels,
		"diff_ratio": ratio,
		"diff_image": diff_img
	}

func _initialize() -> void:
	_run()

func _run() -> void:
	print("\n========================================================")
	print("  SPIRITBOUND DE-FLAKED VISUAL PIXEL-DIFF SUITE")
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
	# TEST CASE 2: Synthetic Mutation & Anomaly Detection (Clustered)
	# -------------------------------------------------------------------------
	print("\nTest 2: Clustered Mutation Detection vs Isolated Noise Rejection...")
	var mutated_img := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	mutated_img.fill(Color(0.2, 0.5, 0.8, 1.0))
	# A) Inject isolated 1-pixel noise at corners (should be filtered out by de-flaker)
	mutated_img.set_pixel(5, 5, Color.WHITE)
	mutated_img.set_pixel(95, 95, Color.WHITE)
	# B) Inject a true 20x20 clustered UI element change
	for y in range(40, 60):
		for x in range(40, 60):
			mutated_img.set_pixel(x, y, Color.RED)

	var anomaly_res: Dictionary = diff_images(test_img, mutated_img)
	check(int(anomaly_res.raw_diff_pixels) == 402, "Raw color delta detected all 402 modified pixels (including 2 isolated noise specks)")
	check(int(anomaly_res.diff_pixels) == 400, "De-noiser successfully filtered out 2 isolated noise specks (exactly 400 clustered pixels kept)")
	check(is_equal_approx(float(anomaly_res.diff_ratio), 400.0 / 10000.0), "Clustered diff ratio matches expected 4.0%%")

	# -------------------------------------------------------------------------
	# TEST CASE 3: Core Mobile Screen Baselines Verification
	# -------------------------------------------------------------------------
	print("\nTest 3: Core Mobile Screen Baseline Comparisons...")
	var screens := [
		"01_map_screen.png",
		"02_battle_screen.png",
		"03_rewards_screen.png",
		"04_shop_screen.png",
		"05_deck_screen.png",
		"06_camp_screen.png",
		"07_treasury_inspector.png",
		# Added when the snapshotter grew from 7 screens to 9. Both of these were being captured on
		# every single run and then compared against nothing — see the enumeration guard below.
		"08_codex_screen.png",
		"09_challenges_screen.png"
	]

	# Screen-adaptive thresholds (tight bounds for static UI, reasonable tolerance for dynamic scenes)
	var screen_thresholds := {
		"01_map_screen.png": 0.018,         # 1.8% max allowed (painted landscape)
		"02_battle_screen.png": 0.025,      # 2.5% max allowed (monster sprite & effects)
		"03_rewards_screen.png": 0.008,     # 0.8% max allowed (static UI)
		"04_shop_screen.png": 0.010,        # 1.0% max allowed (shelf list)
		"05_deck_screen.png": 0.008,        # 0.8% max allowed (static grid)
		"06_camp_screen.png": 0.010,        # 1.0% max allowed (tabs and list)
		"07_treasury_inspector.png": 0.010, # 1.0% max allowed (modal dialog)
		"08_codex_screen.png": 0.010,       # 1.0% max allowed (static list)
		"09_challenges_screen.png": 0.012   # 1.2% max allowed (grouped cards + dock)
	}

	# Enumerate what was actually captured instead of trusting this file's own hand-written lists.
	# Those lists have drifted before and nothing noticed: visual_snapshots.gd grew from 7 screens
	# to 9 when the codex and trial-challenges screens were added, and neither the screens array
	# nor the thresholds dict above was updated — so both new screens were captured on every run
	# and then compared against nothing at all. The trial-challenges screen, freshly redesigned at
	# the time, was the one screen in the game with no visual regression gate whatsoever. These
	# checks make the next addition fail here rather than pass quietly, and they cost one
	# directory read.
	var captured: Array[String] = []
	var snap_dir := DirAccess.open(SNAPSHOT_DIR)
	if snap_dir == null:
		fail("Cannot open %s to enumerate the captured snapshots." % SNAPSHOT_DIR)
	else:
		for entry in snap_dir.get_files():
			if not entry.begins_with(".") and entry.ends_with(".png"):
				captured.append(entry)
		captured.sort()

	check(captured.size() > 0,
		"Current snapshots exist to diff against (found %d in %s)" % [captured.size(), SNAPSHOT_DIR])
	for captured_file in captured:
		check(screens.has(captured_file),
			"%s is listed in this suite's screens array — an unlisted snapshot is captured but never gated" % captured_file)
		check(screen_thresholds.has(captured_file),
			"%s has a per-screen threshold of its own" % captured_file)

	for screen_file in screens:
		var baseline_path := "%s/%s" % [BASELINE_DIR, screen_file]
		var current_path := "%s/%s" % [SNAPSHOT_DIR, screen_file]

		# Both of these branches used to print a warning and `continue`, which makes this a gate
		# that cannot fail for the very reason it exists: delete a baseline and its regression
		# check quietly vanishes from the suite instead of the run going red. run_tests.sh always
		# captures the current snapshots before invoking this script (step 8), so a missing
		# current snapshot means the capture failed — not that there is nothing worth checking.
		if not FileAccess.file_exists(baseline_path):
			fail("%s has no committed baseline at %s — refusing to silently drop a whole screen." % [screen_file, baseline_path])
			continue
		if not FileAccess.file_exists(current_path):
			fail("%s was not captured to %s — run_tests.sh captures before diffing, so this means the capture failed." % [screen_file, current_path])
			continue

		var img_base := Image.load_from_file(ProjectSettings.globalize_path(baseline_path))
		var img_curr := Image.load_from_file(ProjectSettings.globalize_path(current_path))

		if img_base == null or img_curr == null:
			fail("Failed loading image pair for %s" % screen_file)
			continue

		var res: Dictionary = diff_images(img_base, img_curr)
		var diff_pct: float = float(res.diff_ratio) * 100.0
		var max_allowed: float = float(screen_thresholds.get(screen_file, 0.015))

		if float(res.diff_ratio) <= max_allowed:
			check(true, "%s matches baseline (clustered diff: %.2f%%%%, raw: %d px, filtered: %d px, allowed <= %.2f%%%%)" % [
				screen_file,
				diff_pct,
				int(res.raw_diff_pixels),
				int(res.diff_pixels),
				max_allowed * 100.0
			])
		else:
			var diff_save_path := "%s/diff_%s" % [DIFF_OUTPUT_DIR, screen_file]
			if res.diff_image != null:
				res.diff_image.save_png(ProjectSettings.globalize_path(diff_save_path))
			fail("%s exceeded visual difference threshold (got %.2f%%%%, max allowed %.2f%%%%). Diff saved to %s" % [screen_file, diff_pct, max_allowed * 100.0, diff_save_path])

	if failures == 0:
		print("\n🏆 DE-FLAKED PIXEL-DIFF SUITE: ALL CHECKS PASSED (0 FAILURES)\n")
		quit(0)
	else:
		print("\n💥 DE-FLAKED PIXEL-DIFF SUITE: FAILED WITH %d ERRORS\n" % failures)
		quit(1)
