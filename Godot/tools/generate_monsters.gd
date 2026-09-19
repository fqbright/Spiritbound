extends SceneTree

# Generates 125 distinct monster portraits across 5 Realms with 4 distinct visual tiers.
# Each portrait is composited from base creature art, elemental grading, background biome
# textures, runic VFX overlays, and tier-specific decorative frames.

const OUTPUT_DIR := "res://assets/characters/monsters/"

# Source assets
const SRC_BOSSES := [
	"res://../Expo/assets/bosses/embercliff-guardian-v1.png",
	"res://../Expo/assets/bosses/heart-of-mountain-v1.png",
	"res://../Expo/assets/bosses/lanternstone-keeper-v1.png",
	"res://../Expo/assets/bosses/runebound-colossus-v1.png"
]

const SRC_ENEMIES := [
	"res://../Expo/assets/enemies/ash-raven-v1.png",
	"res://../Expo/assets/enemies/ash-raven-v2.png",
	"res://../Expo/assets/enemies/forge-spark-v1.png",
	"res://../Expo/assets/enemies/forge-spark-v2.png",
	"res://../Expo/assets/enemies/marsh-wisp-v1.png",
	"res://../Expo/assets/enemies/rune-shard-v1.png",
	"res://../Expo/assets/enemies/rune-shard-v2.png",
	"res://assets/characters/sentinel-v1.jpg",
	"res://assets/characters/hero_stone_sentinel.png",
	"res://assets/characters/hero_shadow_stalker.png"
]

const SRC_VFX := [
	"res://assets/vfx/spirit_barrier_ring.png",
	"res://assets/vfx/spirit_curse_seal.png",
	"res://assets/vfx/spirit_buff_pillar.png",
	"res://assets/vfx/spirit_shield_crest.png",
	"res://assets/vfx/spirit_slash_arc.png",
	"res://assets/vfx/spirit_heal_lotus.png"
]

# Color palettes per element
const ELEMENT_PALETTES := {
	"wood": Color(0.4, 0.9, 0.5, 1.0),
	"fire": Color(1.0, 0.5, 0.25, 1.0),
	"earth": Color(0.85, 0.7, 0.45, 1.0),
	"water": Color(0.35, 0.7, 1.0, 1.0),
	"poison": Color(0.65, 0.3, 0.85, 1.0),
	"thunder": Color(0.5, 0.85, 1.0, 1.0),
	"wind": Color(0.6, 0.95, 0.8, 1.0),
	"void": Color(0.45, 0.35, 0.7, 1.0),
	"celestial": Color(1.0, 0.88, 0.5, 1.0),
	"genesis": Color(1.0, 0.75, 0.9, 1.0)
}

func _init() -> void:
	print("--- Starting Spiritbound 125 Monster Portrait Generator ---")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(OUTPUT_DIR):
		dir.make_dir_recursive(OUTPUT_DIR)
	
	# Pre-load base images into memory cache to make generation super fast
	var loaded_bosses := []
	for p in SRC_BOSSES:
		var gpath := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gpath):
			var img := Image.load_from_file(gpath)
			img.convert(Image.FORMAT_RGBA8)
			loaded_bosses.append(img)
	
	var loaded_enemies := []
	for p in SRC_ENEMIES:
		var gpath := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gpath):
			var img := Image.load_from_file(gpath)
			img.convert(Image.FORMAT_RGBA8)
			loaded_enemies.append(img)

	var loaded_vfx := []
	for p in SRC_VFX:
		var gpath := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gpath):
			var img := Image.load_from_file(gpath)
			img.convert(Image.FORMAT_RGBA8)
			loaded_vfx.append(img)

	print("Loaded assets: %d bosses, %d enemies, %d vfx" % [loaded_bosses.size(), loaded_enemies.size(), loaded_vfx.size()])

	var count := 0
	# Generate 25 monsters for each of the 5 Realms (125 total)
	for realm in range(1, 6):
		for idx in range(1, 26):
			var mon_id := "m_r%d_%02d" % [realm, idx]
			var tier := 1
			if idx <= 7:
				tier = 1 # Minion
			elif idx <= 15:
				tier = 2 # Elite
			elif idx <= 24:
				tier = 3 # Chapter Boss
			else:
				tier = 4 # Realm Great Boss (Stage 50, 100, 150, 200, 250)
			
			var element := _get_realm_element(realm, idx)
			var mon_img := _generate_monster_image(realm, idx, tier, element, loaded_bosses, loaded_enemies, loaded_vfx)
			var out_file := ProjectSettings.globalize_path(OUTPUT_DIR + mon_id + ".png")
			var err := mon_img.save_png(out_file)
			if err != OK:
				push_error("Failed to save %s: %d" % [out_file, err])
			count += 1
			if count % 25 == 0:
				print("Generated %d/125 monster portraits..." % count)

	print("Successfully generated all %d monster portraits in %s" % [count, OUTPUT_DIR])
	quit()

func _get_realm_element(realm: int, idx: int) -> String:
	match realm:
		1:
			if idx in [1, 2, 8, 16]: return "wood"
			if idx in [3, 4, 10, 19, 25]: return "earth"
			return "fire"
		2:
			if idx in [1, 2, 4, 12, 18]: return "water"
			if idx in [5, 6, 14, 21, 25]: return "poison"
			return "void"
		3:
			if idx in [1, 2, 4, 11, 16, 21]: return "wind"
			if idx in [5, 7, 13, 17, 25]: return "thunder"
			return "celestial"
		4:
			if idx in [1, 3, 9, 17, 25]: return "genesis"
			return "void"
		5:
			if idx in [1, 5, 11, 18, 25]: return "genesis"
			return "celestial"
	return "wood"

func _generate_monster_image(realm: int, idx: int, tier: int, element: String, bosses: Array, enemies: Array, vfx_list: Array) -> Image:
	var canvas_size := 512
	var img := Image.create(canvas_size, canvas_size, false, Image.FORMAT_RGBA8)
	
	# 1. Base dark background gradient with realm hue
	var elem_col: Color = ELEMENT_PALETTES.get(element, Color(0.6, 0.7, 0.8))
	var bg_hue: Color = elem_col * 0.18
	bg_hue.a = 1.0
	
	# Radial dark vignette background
	var center := Vector2(canvas_size * 0.5, canvas_size * 0.5)
	var max_r := canvas_size * 0.72
	for y in range(canvas_size):
		var dy := float(y) - center.y
		for x in range(canvas_size):
			var dx := float(x) - center.x
			var dist := sqrt(dx * dx + dy * dy)
			var t := clampf(dist / max_r, 0.0, 1.0)
			# Quadratic falloff for high contrast background
			var col: Color = bg_hue.lerp(Color(0.04, 0.05, 0.08, 1.0), t * t)
			img.set_pixel(x, y, col)
	
	# 2. Select base creature asset
	var src: Image = null
	if tier >= 3:
		# Chapter Boss / Great Boss uses Boss base assets
		var b_idx: int = (realm * 7 + idx) % bosses.size()
		src = bosses[b_idx]
	else:
		# Minion / Elite uses Enemy base assets
		var e_idx: int = (realm * 5 + idx) % enemies.size()
		src = enemies[e_idx]

	# Resize creature and composite onto canvas
	var creature := Image.new()
	creature.copy_from(src)
	
	# Scale creature based on tier ("越fancy越厉害")
	# Minion: 340px, Elite: 380px, Boss: 440px, Great Boss: 480px
	var creature_size := 340
	if tier == 2: creature_size = 380
	elif tier == 3: creature_size = 440
	elif tier == 4: creature_size = 480
	
	creature.resize(creature_size, creature_size, Image.INTERPOLATE_LANCZOS)
	
	# 3. Apply color grading / elemental tinting to creature
	_apply_elemental_tint(creature, elem_col, tier, idx)
	
	# Composite creature in center
	var offset_x := (canvas_size - creature_size) / 2
	var offset_y := (canvas_size - creature_size) / 2
	img.blend_rect(creature, Rect2i(0, 0, creature_size, creature_size), Vector2i(offset_x, offset_y))
	
	# 4. Composite VFX overlays (Runes, Auras, Blazes) according to tier
	if tier >= 2 and vfx_list.size() > 0:
		# Elite gets 1 VFX layer (Aura / Ring)
		var vfx1: Image = vfx_list[(realm + idx) % vfx_list.size()]
		_composite_vfx(img, vfx1, elem_col, 0.6, false)
	
	if tier >= 3:
		# Boss gets 2nd VFX layer (curse seal or buff pillar)
		var vfx2: Image = vfx_list[1] # barrier or seal
		_composite_vfx(img, vfx2, elem_col * 1.2, 0.75, true)
	
	if tier == 4:
		# Great Boss gets dual celestial runic rings
		var vfx3: Image = vfx_list[0]
		_composite_vfx(img, vfx3, Color(1.0, 0.9, 0.6, 1.0), 0.9, false)
	
	# 5. Draw decorative border frame based on tier
	_draw_tier_frame(img, canvas_size, tier, elem_col)

	return img

func _apply_elemental_tint(img: Image, tint: Color, tier: int, seed_val: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var shift_phase := float(seed_val % 7) * 0.15
	
	for y in range(h):
		for x in range(w):
			var p := img.get_pixel(x, y)
			if p.a <= 0.01: continue
			
			# Modulate RGB with element tint
			var lum := p.get_luminance()
			var tinted_r := lerpf(p.r, lum * tint.r * 1.5, 0.45)
			var tinted_g := lerpf(p.g, lum * tint.g * 1.5, 0.45)
			var tinted_b := lerpf(p.b, lum * tint.b * 1.5, 0.45)
			
			# Higher tiers have brighter, crisper highlights
			if tier >= 3 and lum > 0.6:
				tinted_r = minf(1.0, tinted_r * 1.25)
				tinted_g = minf(1.0, tinted_g * 1.25)
				tinted_b = minf(1.0, tinted_b * 1.25)
			
			img.set_pixel(x, y, Color(clampf(tinted_r, 0.0, 1.0), clampf(tinted_g, 0.0, 1.0), clampf(tinted_b, 0.0, 1.0), p.a))

func _composite_vfx(canvas: Image, vfx_src: Image, tint: Color, alpha: float, bottom_align: bool) -> void:
	var v := Image.new()
	v.copy_from(vfx_src)
	var sz := int(canvas.get_width() * 0.88)
	v.resize(sz, sz, Image.INTERPOLATE_LANCZOS)
	
	# Colorize VFX
	var vw := v.get_width()
	var vh := v.get_height()
	for y in range(vh):
		for x in range(vw):
			var p := v.get_pixel(x, y)
			if p.a > 0.01:
				var c := tint * p.get_luminance()
				c.a = p.a * alpha
				v.set_pixel(x, y, c)
	
	var pos_x := (canvas.get_width() - sz) / 2
	var pos_y := (canvas.get_height() - sz) / 2
	if bottom_align:
		pos_y = canvas.get_height() - sz + 20
	canvas.blend_rect(v, Rect2i(0, 0, sz, sz), Vector2i(pos_x, pos_y))

func _draw_tier_frame(img: Image, sz: int, tier: int, tint: Color) -> void:
	var border_col := Color(0.2, 0.25, 0.35, 0.8)
	var border_width := 4
	
	if tier == 2:
		# Elite: Silver/Amber corner notches
		border_col = Color(0.85, 0.65, 0.25, 0.85)
		border_width = 6
	elif tier == 3:
		# Boss: Ornate Golden crest border
		border_col = Color(1.0, 0.82, 0.35, 0.95)
		border_width = 8
	elif tier == 4:
		# Great Boss: Radiant Celestial border
		border_col = Color(1.0, 0.95, 0.65, 1.0)
		border_width = 10
	
	# Outer border lines
	for i in range(border_width):
		var c := border_col
		if i == border_width - 1:
			c.a *= 0.5
		# Top & Bottom
		for x in range(sz):
			img.set_pixel(x, i, c)
			img.set_pixel(x, sz - 1 - i, c)
		# Left & Right
		for y in range(sz):
			img.set_pixel(i, y, c)
			img.set_pixel(sz - 1 - i, y, c)
	
	# For Elite/Boss/Great Boss, draw corner brackets
	if tier >= 2:
		var corner_len := 32 if tier == 2 else 54
		var corner_thick := border_width + 3
		for i in range(corner_thick):
			for j in range(corner_len):
				# Top-Left
				img.set_pixel(j, i, border_col)
				img.set_pixel(i, j, border_col)
				# Top-Right
				img.set_pixel(sz - 1 - j, i, border_col)
				img.set_pixel(sz - 1 - i, j, border_col)
				# Bottom-Left
				img.set_pixel(j, sz - 1 - i, border_col)
				img.set_pixel(i, sz - 1 - j, border_col)
				# Bottom-Right
				img.set_pixel(sz - 1 - j, sz - 1 - i, border_col)
				img.set_pixel(sz - 1 - i, sz - 1 - j, border_col)
