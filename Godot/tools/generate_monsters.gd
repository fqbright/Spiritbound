extends SceneTree

# Generates 125 distinct monster portraits across 5 Realms with 4 distinct visual tiers.
# All portraits have 100% transparent backgrounds (alpha = 0) with no rectangular border frames.
# Each portrait is composited from base creature art, elemental grading, and tier-specific runic VFX.

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

func _clean_silhouette_alpha(src: Image) -> Image:
	var img := Image.new()
	img.copy_from(src)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	
	# Check if corners are already cleanly transparent
	var c0 := img.get_pixel(0, 0)
	var c1 := img.get_pixel(w - 1, 0)
	var c2 := img.get_pixel(0, h - 1)
	var c3 := img.get_pixel(w - 1, h - 1)
	if c0.a < 0.05 and c1.a < 0.05 and c2.a < 0.05 and c3.a < 0.05:
		return img
	
	# Extract transparent silhouette by removing dark/solid background
	var center := Vector2(float(w) * 0.5, float(h) * 0.5)
	var max_r := float(w) * 0.45
	for y in range(h):
		var dy := float(y) - center.y
		for x in range(w):
			var dx := float(x) - center.x
			var dist := sqrt(dx * dx + dy * dy)
			var p := img.get_pixel(x, y)
			var lum := p.get_luminance()
			var radial_factor := clampf((max_r - dist) / (float(w) * 0.12), 0.0, 1.0)
			var lum_factor := clampf((lum - 0.10) / 0.16, 0.0, 1.0)
			var new_a := p.a * radial_factor * lum_factor
			if dist > max_r or new_a < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(p.r, p.g, p.b, new_a))
	return img

func _get_atlas_region(atlas: Image, cell_x: int, cell_y: int) -> Image:
	var cw := atlas.get_width() / 3
	var ch := atlas.get_height() / 3
	var region := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	region.blit_rect(atlas, Rect2i(cell_x * cw, cell_y * ch, cw, ch), Vector2i.ZERO)
	return region

func _init() -> void:
	print("--- Starting Spiritbound 125 Monster Portrait Generator (Transparent Silhouettes) ---")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(OUTPUT_DIR):
		dir.make_dir_recursive(OUTPUT_DIR)
	
	var loaded_bosses := []
	var loaded_enemies := []
	
	# 1. First priority: load canonical transparent cutouts from character-atlas-v3.png
	var atlas_path := ProjectSettings.globalize_path("res://assets/characters/character-atlas-v3.png")
	if FileAccess.file_exists(atlas_path):
		var atlas := Image.load_from_file(atlas_path)
		atlas.convert(Image.FORMAT_RGBA8)
		# 4 Bosses from atlas:
		loaded_bosses.append(_get_atlas_region(atlas, 1, 1)) # embercliff
		loaded_bosses.append(_get_atlas_region(atlas, 2, 1)) # lanternstone
		loaded_bosses.append(_get_atlas_region(atlas, 0, 2)) # mountainHeart
		loaded_bosses.append(_get_atlas_region(atlas, 1, 2)) # runebound
		
		# 5 Minions/Enemies from atlas:
		loaded_enemies.append(_get_atlas_region(atlas, 2, 2)) # ashRaven
		loaded_enemies.append(_get_atlas_region(atlas, 1, 0)) # sentinel
		loaded_enemies.append(_get_atlas_region(atlas, 2, 0)) # shadow
		loaded_enemies.append(_get_atlas_region(atlas, 0, 1)) # iron
		loaded_enemies.append(_get_atlas_region(atlas, 0, 0)) # fox
	
	# 2. Standalone transparent hero/spirit sprites
	var standalone_transparent := [
		"res://assets/characters/hero_miasma_witch.png",
		"res://assets/characters/hero_shadow_stalker.png",
		"res://assets/characters/hero_stone_sentinel.png",
		"res://assets/characters/hero_fox_spirit.png"
	]
	for p in standalone_transparent:
		var gpath := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gpath):
			var img := Image.load_from_file(gpath)
			img.convert(Image.FORMAT_RGBA8)
			loaded_enemies.append(img)
	
	# 3. Expo source assets cleaned of background
	for p in SRC_BOSSES:
		var gpath := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gpath):
			var img := Image.load_from_file(gpath)
			loaded_bosses.append(_clean_silhouette_alpha(img))
	
	for p in SRC_ENEMIES:
		var gpath := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gpath):
			var img := Image.load_from_file(gpath)
			loaded_enemies.append(_clean_silhouette_alpha(img))
	
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
				print("Generated %d/125 transparent monster portraits..." % count)
	
	print("Successfully generated all %d monster portraits with transparent backgrounds in %s" % [count, OUTPUT_DIR])
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
	# Canvas starts 100% transparent (alpha = 0 on all pixels)
	var img := Image.create(canvas_size, canvas_size, false, Image.FORMAT_RGBA8)
	var elem_col: Color = ELEMENT_PALETTES.get(element, Color(0.6, 0.7, 0.8))
	
	# 1. Optional subtle ethereal aura behind creature for Elites & Bosses (pure circular, fades to 0 well before edges)
	if tier >= 2:
		var center := Vector2(float(canvas_size) * 0.5, float(canvas_size) * 0.5)
		var glow_r: float = float(canvas_size) * 0.32 # radius ~164px, leaves at least 92px of pure transparent border
		var peak_a := 0.22 if tier == 2 else 0.32
		var start_y := maxi(0, int(center.y - glow_r))
		var end_y := mini(canvas_size - 1, int(center.y + glow_r))
		var start_x := maxi(0, int(center.x - glow_r))
		var end_x := mini(canvas_size - 1, int(center.x + glow_r))
		for y in range(start_y, end_y + 1):
			var dy := float(y) - center.y
			for x in range(start_x, end_x + 1):
				var dx := float(x) - center.x
				var dist := sqrt(dx * dx + dy * dy)
				if dist < glow_r:
					var falloff := 1.0 - (dist / glow_r)
					var col := elem_col
					col.a = falloff * falloff * peak_a
					img.set_pixel(x, y, col)
	
	# 2. Select base creature asset
	var src: Image = null
	if tier >= 3:
		var b_idx: int = (realm * 7 + idx) % bosses.size()
		src = bosses[b_idx]
	else:
		var e_idx: int = (realm * 5 + idx) % enemies.size()
		src = enemies[e_idx]
	
	# Resize creature and composite onto transparent canvas
	var creature := Image.new()
	creature.copy_from(src)
	
	# Sized strictly inside the 512x512 canvas so no creature touches the outer boundary
	var creature_size := 320
	if tier == 2: creature_size = 360
	elif tier == 3: creature_size = 400
	elif tier == 4: creature_size = 430
	
	creature.resize(creature_size, creature_size, Image.INTERPOLATE_LANCZOS)
	
	# 3. Apply color grading / elemental tinting to creature
	_apply_elemental_tint(creature, elem_col, tier, idx)
	
	# Composite creature in center
	var offset_x := (canvas_size - creature_size) / 2
	var offset_y := (canvas_size - creature_size) / 2
	img.blend_rect(creature, Rect2i(0, 0, creature_size, creature_size), Vector2i(offset_x, offset_y))
	
	# 4. Composite transparent VFX overlays (Runes, Auras, Blazes) according to tier
	if tier >= 2 and vfx_list.size() > 0:
		var vfx1: Image = vfx_list[(realm + idx) % vfx_list.size()]
		_composite_vfx(img, vfx1, elem_col, 0.55, false)
	
	if tier >= 3:
		var vfx2: Image = vfx_list[1] # barrier or seal
		_composite_vfx(img, vfx2, elem_col * 1.2, 0.65, true)
	
	if tier == 4:
		var vfx3: Image = vfx_list[0]
		_composite_vfx(img, vfx3, Color(1.0, 0.9, 0.6, 1.0), 0.8, false)
	
	# Note: NO _draw_tier_frame! Rectangle border frames are completely eliminated.
	# Background is 100% transparent.
	return img

func _apply_elemental_tint(img: Image, tint: Color, tier: int, seed_val: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	
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
	var sz := int(canvas.get_width() * 0.80)
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
		pos_y = canvas.get_height() - sz + 15
	canvas.blend_rect(v, Rect2i(0, 0, sz, sz), Vector2i(pos_x, pos_y))

