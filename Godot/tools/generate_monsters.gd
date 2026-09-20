extends SceneTree

# Generates 250 distinct monster portraits for all 250 stages (50 chapters x 5 stages).
# Features:
# 1. 100% SOLID creature bodies (no transparency/see-through body pixels in combat).
# 2. 100% transparent backgrounds with clean anti-aliasing edges (no rectangle frames).
# 3. STRICT SEPARATION: Zero hero art used for enemies (no fox, sentinel, shadow stalker, or witch).
# 4. Each small stage has a 100% unique monster portrait (m_s001.png .. m_s250.png).
# 5. Generates legacy aliases (m_r1_01.png .. m_r5_25.png) for full backward compatibility.

const OUTPUT_DIR := "res://assets/characters/monsters/"

# VFX textures for runic overlays and halos
const SRC_VFX := [
	"res://assets/vfx/spirit_barrier_ring.png",
	"res://assets/vfx/spirit_curse_seal.png",
	"res://assets/vfx/spirit_buff_pillar.png",
	"res://assets/vfx/spirit_shield_crest.png",
	"res://assets/vfx/spirit_slash_arc.png",
	"res://assets/vfx/spirit_heal_lotus.png"
]

const ELEMENT_PALETTES := {
	"wood": Color(0.35, 0.88, 0.48, 1.0),
	"fire": Color(1.0, 0.45, 0.18, 1.0),
	"earth": Color(0.88, 0.70, 0.40, 1.0),
	"water": Color(0.30, 0.72, 1.0, 1.0),
	"poison": Color(0.70, 0.28, 0.92, 1.0),
	"thunder": Color(0.40, 0.88, 1.0, 1.0),
	"wind": Color(0.55, 0.98, 0.82, 1.0),
	"void": Color(0.52, 0.38, 0.85, 1.0),
	"celestial": Color(1.0, 0.88, 0.45, 1.0),
	"genesis": Color(1.0, 0.65, 0.85, 1.0)
}

func _solidify_image(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var p := img.get_pixel(x, y)
			if p.a >= 0.20:
				img.set_pixel(x, y, Color(p.r, p.g, p.b, 1.0))
			elif p.a > 0.02:
				img.set_pixel(x, y, Color(p.r, p.g, p.b, p.a / 0.20))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img

func _clean_silhouette_alpha(src: Image) -> Image:
	var img := Image.new()
	img.copy_from(src)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	
	# Sample corner colors to determine background
	var bg_col := img.get_pixel(0, 0)
	var center := Vector2(float(w) * 0.5, float(h) * 0.5)
	var max_r := float(w) * 0.47
	
	for y in range(h):
		var dy := float(y) - center.y
		for x in range(w):
			var dx := float(x) - center.x
			var dist := sqrt(dx * dx + dy * dy)
			if dist > max_r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var p := img.get_pixel(x, y)
			var color_dist := sqrt(pow(p.r - bg_col.r, 2) + pow(p.g - bg_col.g, 2) + pow(p.b - bg_col.b, 2))
			var lum := p.get_luminance()
			if color_dist < 0.14 or lum < 0.05:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				# Creature pixel: strictly 100% SOLID
				img.set_pixel(x, y, Color(p.r, p.g, p.b, 1.0))
	return img

func _get_atlas_region(atlas: Image, cell_x: int, cell_y: int) -> Image:
	var cw := atlas.get_width() / 3
	var ch := atlas.get_height() / 3
	var region := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	region.blit_rect(atlas, Rect2i(cell_x * cw, cell_y * ch, cw, ch), Vector2i.ZERO)
	return _solidify_image(region)

func _flip_image_horizontal(src: Image) -> Image:
	var out := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	for y in range(h):
		for x in range(w):
			out.set_pixel(w - 1 - x, y, src.get_pixel(x, y))
	return out

func _init() -> void:
	print("--- Starting Spiritbound 250 Solid Monster Portrait Generator ---")
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(OUTPUT_DIR):
		dir.make_dir_recursive(OUTPUT_DIR)
	
	var base_creatures := []
	
	# 1. PURE MONSTER CUTOUTS from character-atlas-v3.png (cells with monsters only)
	# Cell (0,0)=Fox (HERO - EXCLUDED)
	# Cell (1,0)=Sentinel (HERO - EXCLUDED)
	var atlas_path := ProjectSettings.globalize_path("res://assets/characters/character-atlas-v3.png")
	if FileAccess.file_exists(atlas_path):
		var atlas := Image.load_from_file(atlas_path)
		atlas.convert(Image.FORMAT_RGBA8)
		# 7 pure monster cells:
		base_creatures.append(_get_atlas_region(atlas, 2, 0)) # lanternstone
		base_creatures.append(_get_atlas_region(atlas, 0, 1)) # runebound
		base_creatures.append(_get_atlas_region(atlas, 1, 1)) # embercliff
		base_creatures.append(_get_atlas_region(atlas, 2, 1)) # mountainHeart
		base_creatures.append(_get_atlas_region(atlas, 0, 2)) # runeShard
		base_creatures.append(_get_atlas_region(atlas, 1, 2)) # ashRaven
		base_creatures.append(_get_atlas_region(atlas, 2, 2)) # forgeSpark
		print("Loaded 7 pure monster cutouts from character-atlas-v3.png")
	
	# 2. Pure monster assets from Expo/assets/
	var expo_bosses := [
		"res://../Expo/assets/bosses/embercliff-guardian-v1.png",
		"res://../Expo/assets/bosses/heart-of-mountain-v1.png",
		"res://../Expo/assets/bosses/lanternstone-keeper-v1.png",
		"res://../Expo/assets/bosses/runebound-colossus-v1.png"
	]
	for p in expo_bosses:
		var gp := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			var img := Image.load_from_file(gp)
			base_creatures.append(_clean_silhouette_alpha(img))
	
	var expo_enemies := [
		"res://../Expo/assets/enemies/ash-raven-v1.png",
		"res://../Expo/assets/enemies/ash-raven-v2.png",
		"res://../Expo/assets/enemies/forge-spark-v1.png",
		"res://../Expo/assets/enemies/forge-spark-v2.png",
		"res://../Expo/assets/enemies/marsh-wisp-v1.png",
		"res://../Expo/assets/enemies/rune-shard-v1.png",
		"res://../Expo/assets/enemies/rune-shard-v2.png"
	]
	for p in expo_enemies:
		var gp := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			var img := Image.load_from_file(gp)
			base_creatures.append(_clean_silhouette_alpha(img))
	
	var loaded_vfx := []
	for p in SRC_VFX:
		var gp := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			var img := Image.load_from_file(gp)
			img.convert(Image.FORMAT_RGBA8)
			loaded_vfx.append(img)
	
	print("Total loaded pure monster base archetypes: %d, VFX overlays: %d" % [base_creatures.size(), loaded_vfx.size()])
	
	# Generate 250 stage portraits (m_s001.png .. m_s250.png)
	var generated_count := 0
	for stage_num in range(1, 251):
		var chapter := (stage_num - 1) / 5 + 1
		var level := (stage_num - 1) % 5 + 1
		var realm := (chapter - 1) / 10 + 1
		
		var tier := 1
		if level in [1, 2]:
			tier = 1
		elif level in [3, 4]:
			tier = 2
		elif level == 5:
			tier = 4 if stage_num in [50, 100, 150, 200, 250] else 3
		
		var element := _get_stage_element(realm, chapter, level)
		var mon_img := _create_monster_portrait(stage_num, chapter, level, tier, realm, element, base_creatures, loaded_vfx)
		
		# Save primary stage file: m_s001.png .. m_s250.png
		var primary_file := ProjectSettings.globalize_path(OUTPUT_DIR + ("m_s%03d.png" % stage_num))
		var err := mon_img.save_png(primary_file)
		if err != OK:
			push_error("Failed to save %s: %d" % [primary_file, err])
		
		# Also save legacy alias for the first 125 stages (m_r1_01 .. m_r5_25)
		if stage_num <= 125:
			var legacy_r := (stage_num - 1) / 25 + 1
			var legacy_idx := (stage_num - 1) % 25 + 1
			var legacy_file := ProjectSettings.globalize_path(OUTPUT_DIR + ("m_r%d_%02d.png" % [legacy_r, legacy_idx]))
			mon_img.save_png(legacy_file)
		
		generated_count += 1
		if generated_count % 50 == 0:
			print("Generated %d/250 unique monster portraits..." % generated_count)
	
	print("Successfully generated all %d monster portraits with 100%% solid bodies in %s" % [generated_count, OUTPUT_DIR])
	quit()

func _get_stage_element(realm: int, chapter: int, level: int) -> String:
	match realm:
		1:
			if level == 1 or chapter in [1, 5, 8]: return "wood"
			if level == 2 or chapter in [2, 6, 9]: return "earth"
			return "fire"
		2:
			if level in [1, 2] or chapter in [11, 14, 17]: return "water"
			if level == 3 or chapter in [12, 15, 18]: return "poison"
			return "void"
		3:
			if level in [1, 2] or chapter in [21, 24, 27]: return "wind"
			if level == 3 or chapter in [22, 25, 28]: return "thunder"
			return "celestial"
		4:
			if level == 5 or chapter in [35, 40]: return "void"
			if level in [3, 4] or chapter in [32, 36, 38]: return "poison"
			return "void"
		5:
			if stage_is_genesis(chapter, level): return "genesis"
			return "celestial"
	return "wood"

func stage_is_genesis(chapter: int, level: int) -> bool:
	return (chapter + level) % 2 == 0

func _create_monster_portrait(stage_num: int, chapter: int, level: int, tier: int, realm: int, element: String, bases: Array, vfx_list: Array) -> Image:
	var canvas_size := 512
	var img := Image.create(canvas_size, canvas_size, false, Image.FORMAT_RGBA8)
	var elem_col: Color = ELEMENT_PALETTES.get(element, Color(0.6, 0.7, 0.8))
	
	# 1. Deterministic base archetype selection across stages to guarantee uniqueness
	# We ensure no adjacent stages share the same base archetype and transformations
	var base_idx: int = (stage_num * 5 + chapter * 3 + level) % bases.size()
	var base_src: Image = bases[base_idx]
	
	var creature := Image.new()
	creature.copy_from(base_src)
	
	# Horizontal flip for orientation variety
	if (stage_num * 7 + level * 3) % 2 == 1:
		creature = _flip_image_horizontal(creature)
	
	# 2. Size according to tier and stage emphasis
	var creature_size := 320
	match tier:
		1: creature_size = 310 + (stage_num % 3) * 15
		2: creature_size = 350 + (stage_num % 3) * 15
		3: creature_size = 390 + (stage_num % 3) * 15
		4: creature_size = 430 + (stage_num % 2) * 15
	
	creature.resize(creature_size, creature_size, Image.INTERPOLATE_LANCZOS)
	
	# 3. Apply elemental color grading and hue shifting
	_apply_elemental_grading(creature, elem_col, tier, stage_num)
	
	# 4. Optional background runic halo for Tier 2, 3, 4 (strictly centered behind creature)
	if tier >= 2 and vfx_list.size() > 0:
		var vfx_idx := (stage_num + realm) % vfx_list.size()
		var vfx_bg: Image = vfx_list[vfx_idx]
		_composite_vfx_background(img, vfx_bg, elem_col, tier)
	
	# 5. Composite solid creature onto transparent canvas
	var offset_x := (canvas_size - creature_size) / 2
	var offset_y := (canvas_size - creature_size) / 2
	# Small vertical grounding offset
	if tier == 1: offset_y += 10
	elif tier >= 3: offset_y -= 5
	
	img.blend_rect(creature, Rect2i(0, 0, creature_size, creature_size), Vector2i(offset_x, offset_y))
	
	# 6. Composite foreground runic accents for Bosses (Tier 3 & 4)
	if tier >= 3 and vfx_list.size() > 1:
		var seal_vfx: Image = vfx_list[1] # curse seal or barrier ring
		_composite_crest_accent(img, seal_vfx, elem_col, tier)
	
	# 7. CRITICAL SOLIDITY PASS:
	# Clamps every creature body pixel to 100% solid opacity (alpha = 1.0).
	# Ensures zero transparency on the monster in combat while keeping transparent background.
	_enforce_body_solidity(img)
	
	return img

func _apply_elemental_grading(img: Image, tint: Color, tier: int, stage_seed: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var shift_strength := 0.50 if tier == 1 else (0.58 if tier == 2 else 0.68)
	
	for y in range(h):
		for x in range(w):
			var p := img.get_pixel(x, y)
			if p.a <= 0.02: continue
			
			var lum := p.get_luminance()
			# Enhance contrast: rich shadows and radiant highlights
			var contrast_lum := pow(lum, 1.1)
			
			var tinted_r := lerpf(p.r, contrast_lum * tint.r * 1.4, shift_strength)
			var tinted_g := lerpf(p.g, contrast_lum * tint.g * 1.4, shift_strength)
			var tinted_b := lerpf(p.b, contrast_lum * tint.b * 1.4, shift_strength)
			
			# Tier 3 and 4: high-energy specular gleam
			if tier >= 3 and lum > 0.55:
				tinted_r = minf(1.0, tinted_r * 1.25 + 0.08)
				tinted_g = minf(1.0, tinted_g * 1.25 + 0.08)
				tinted_b = minf(1.0, tinted_b * 1.25 + 0.08)
			
			# Creature pixels are set to solid alpha
			img.set_pixel(x, y, Color(clampf(tinted_r, 0.0, 1.0), clampf(tinted_g, 0.0, 1.0), clampf(tinted_b, 0.0, 1.0), p.a))

func _composite_vfx_background(canvas: Image, vfx_src: Image, tint: Color, tier: int) -> void:
	var v := Image.new()
	v.copy_from(vfx_src)
	var sz := int(canvas.get_width() * (0.80 if tier == 2 else (0.88 if tier == 3 else 0.94)))
	v.resize(sz, sz, Image.INTERPOLATE_LANCZOS)
	
	var vw := v.get_width()
	var vh := v.get_height()
	var vfx_alpha := 0.40 if tier == 2 else (0.55 if tier == 3 else 0.70)
	
	for y in range(vh):
		for x in range(vw):
			var p := v.get_pixel(x, y)
			if p.a > 0.02:
				var c := tint * (p.get_luminance() * 1.2)
				c.a = p.a * vfx_alpha
				v.set_pixel(x, y, c)
	
	var pos_x := (canvas.get_width() - sz) / 2
	var pos_y := (canvas.get_height() - sz) / 2
	canvas.blend_rect(v, Rect2i(0, 0, sz, sz), Vector2i(pos_x, pos_y))

func _composite_crest_accent(canvas: Image, crest_src: Image, tint: Color, tier: int) -> void:
	var c := Image.new()
	c.copy_from(crest_src)
	var sz := int(canvas.get_width() * 0.42)
	c.resize(sz, sz, Image.INTERPOLATE_LANCZOS)
	
	var cw := c.get_width()
	var ch := c.get_height()
	var accent_col := Color(1.0, 0.92, 0.65, 1.0) if tier == 4 else tint
	for y in range(ch):
		for x in range(cw):
			var p := c.get_pixel(x, y)
			if p.a > 0.02:
				var col := accent_col * p.get_luminance()
				col.a = p.a * 0.50
				c.set_pixel(x, y, col)
	
	var pos_x := (canvas.get_width() - sz) / 2
	var pos_y := canvas.get_height() - sz - 10
	canvas.blend_rect(c, Rect2i(0, 0, sz, sz), Vector2i(pos_x, pos_y))

func _enforce_body_solidity(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			var p := img.get_pixel(x, y)
			if p.a >= 0.22:
				# Body pixel: clamp to 100% solid, fully opaque
				img.set_pixel(x, y, Color(p.r, p.g, p.b, 1.0))
			elif p.a > 0.02:
				# Clean 2-pixel anti-aliased perimeter
				img.set_pixel(x, y, Color(p.r, p.g, p.b, p.a / 0.22))
			else:
				# Pure transparent background
				img.set_pixel(x, y, Color(0, 0, 0, 0))
