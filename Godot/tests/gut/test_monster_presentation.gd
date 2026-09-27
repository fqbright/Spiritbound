extends GutTest

# ==============================================================================
# Tests for Monster Visual Presentation: Clean Organic Sprites Without Circles
# ==============================================================================

var content: SpiritContent

func before_all():
	content = SpiritContent.new()

func _create_game() -> SpiritGame:
	var g := SpiritGame.new()
	g.content = content
	g.lang = "zh-Hans"
	g.profile = SpiritSave.defaults(content)
	g.root = Control.new()
	g.root.custom_minimum_size = Vector2(390, 844)
	g.root.size = g.root.custom_minimum_size
	g.overlay = Control.new()
	g.overlay.custom_minimum_size = Vector2(390, 844)
	g.overlay.size = g.overlay.custom_minimum_size
	g.add_child(g.root)
	g.add_child(g.overlay)
	return g

# ------------------------------------------------------------------------------
# 1. Battle Screen: Enemies Must Not Have Circular Aura Rings or Token Borders
# ------------------------------------------------------------------------------

func test_enemies_have_no_circular_aura_rings():
	for stage_idx in [2, 4, 49]: # Stage 3 (tier 2), Stage 5 (tier 3 boss), Stage 50 (tier 4 great boss)
		var game := _create_game()
		game.current_stage = stage_idx
		game.begin_battle(stage_idx)

		# Set lethal intent on first enemy to verify lethal aura is also not circular
		if game.combat and game.combat.state and game.combat.state.enemies.size() > 0:
			game.combat.state.enemies[0]["intent"] = {"kind": "attack", "amount": 999}
		
		game.show_battle()

		# Verify no circular aura panels exist anywhere in the unit tree
		var elite_ring: Control = game.root.find_child("EliteAuraRing", true, false)
		var boss_ring: Control = game.root.find_child("BossAuraRing", true, false)
		var great_boss_ring: Control = game.root.find_child("GreatBossCelestialFormation", true, false)
		var lethal_ring: Control = game.root.find_child("LethalThreatAura", true, false)

		assert_null(elite_ring, "Stage %d must not have circular EliteAuraRing" % stage_idx)
		assert_null(boss_ring, "Stage %d must not have circular BossAuraRing" % stage_idx)
		assert_null(great_boss_ring, "Stage %d must not have circular GreatBossCelestialFormation" % stage_idx)
		assert_null(lethal_ring, "Stage %d must not have circular LethalThreatAura" % stage_idx)

		# Bosses must still keep their distinctive crowns for tier distinction
		if stage_idx in [4, 49]:
			var crown: Control = game.root.find_child("BossCrownHalo", true, false)
			assert_not_null(crown, "Stage %d boss should have BossCrownHalo crest" % stage_idx)

		game.free()

# ------------------------------------------------------------------------------
# 2. Monster Asset Quality: Transparent Corners & Non-Circular Boundaries
# ------------------------------------------------------------------------------

func test_monster_assets_have_transparent_corners_and_organic_silhouettes():
	var test_samples: Array[String] = ["m_s001.png", "m_s005.png", "m_s050.png", "m_s100.png", "m_s200.png", "m_s250.png"]
	for filename: String in test_samples:
		var path: String = "res://assets/characters/monsters/" + filename
		assert_true(ResourceLoader.exists(path), "%s must exist in monsters directory" % filename)
		var tex: Texture2D = load(path)
		assert_not_null(tex, "Failed to load %s" % path)
		var img: Image = tex.get_image()
		assert_not_null(img, "Failed to get Image from %s" % path)

		var w := img.get_width()
		var h := img.get_height()

		# Corners must be 100% transparent (no rectangular frames or circular disk backgrounds)
		var tl: Color = img.get_pixel(0, 0)
		var tr: Color = img.get_pixel(w - 1, 0)
		var bl: Color = img.get_pixel(0, h - 1)
		var br: Color = img.get_pixel(w - 1, h - 1)
		assert_eq(tl.a, 0.0, "%s top-left corner must be transparent" % filename)
		assert_eq(tr.a, 0.0, "%s top-right corner must be transparent" % filename)
		assert_eq(bl.a, 0.0, "%s bottom-left corner must be transparent" % filename)
		assert_eq(br.a, 0.0, "%s bottom-right corner must be transparent" % filename)

		# Center pixel or body pixels must be solid
		var center: Color = img.get_pixel(w / 2, h / 2)
		assert_gt(center.a, 0.5, "%s body at center must be solid" % filename)
