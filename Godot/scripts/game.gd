extends Control

class TouchScrollContainer extends ScrollContainer:
	var _touch_start := Vector2.ZERO
	var _last_pos := Vector2.ZERO
	var _is_touching := false
	var _is_dragging := false
	var _velocity := Vector2.ZERO
	var drag_threshold := 8.0
	var allow_horizontal := false
	var allow_vertical := true

	func _ready() -> void:
		set_process(true)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree(): return
		var global_rect := get_global_rect()

		if event is InputEventScreenTouch:
			if event.pressed:
				if global_rect.has_point(event.position):
					_is_touching = true
					_is_dragging = false
					_touch_start = event.position
					_last_pos = event.position
					_velocity = Vector2.ZERO
			else:
				if _is_touching:
					_is_touching = false
					if _is_dragging:
						get_viewport().set_input_as_handled()
						_is_dragging = false

		elif event is InputEventScreenDrag:
			if _is_touching:
				var delta: Vector2 = event.position - _last_pos
				_last_pos = event.position
				if not _is_dragging and (event.position - _touch_start).length() > drag_threshold:
					_is_dragging = true
				if _is_dragging:
					get_viewport().set_input_as_handled()
					if allow_vertical:
						scroll_vertical -= int(delta.y)
					if allow_horizontal:
						scroll_horizontal -= int(delta.x)
					_velocity = delta * 40.0

		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					if global_rect.has_point(event.position):
						_is_touching = true
						_is_dragging = false
						_touch_start = event.position
						_last_pos = event.position
						_velocity = Vector2.ZERO
				else:
					if _is_touching:
						_is_touching = false
						if _is_dragging:
							get_viewport().set_input_as_handled()
							_is_dragging = false

		elif event is InputEventMouseMotion:
			if _is_touching:
				var delta: Vector2 = event.position - _last_pos
				_last_pos = event.position
				if not _is_dragging and (event.position - _touch_start).length() > drag_threshold:
					_is_dragging = true
				if _is_dragging:
					get_viewport().set_input_as_handled()
					if allow_vertical:
						scroll_vertical -= int(delta.y)
					if allow_horizontal:
						scroll_horizontal -= int(delta.x)
					_velocity = delta * 40.0

	func _process(delta: float) -> void:
		if not _is_touching and _velocity.length_squared() > 1.0:
			if allow_vertical:
				scroll_vertical -= int(_velocity.y * delta)
			if allow_horizontal:
				scroll_horizontal -= int(_velocity.x * delta)
			_velocity = _velocity.lerp(Vector2.ZERO, 6.0 * delta)


class HandCard extends Control:
	var hand_index := 0
	var card_data: Dictionary
	var game: Control
	var home_pos := Vector2.ZERO
	var home_rot := 0.0
	var is_held := false
	var is_dragging := false
	var drag_start := Vector2.ZERO
	var current_tween: Tween = null
	var target_enemy_idx := -1
	var preview_index := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		pivot_offset = Vector2(custom_minimum_size.x / 2.0, custom_minimum_size.y)

	func _gui_input(event: InputEvent) -> void:
		if game == null or game.combat == null or game.combat.state.phase != "player" or game.resolving: return

		if event is InputEventScreenTouch:
			if event.pressed:
				_on_touch_down(event.position)
				accept_event()
			else:
				_on_touch_up()
				accept_event()
		elif event is InputEventScreenDrag:
			if is_held:
				_on_drag(event.position)
				accept_event()
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_on_touch_down(event.position)
					accept_event()
				else:
					_on_touch_up()
					accept_event()
		elif event is InputEventMouseMotion:
			if is_held:
				_on_drag(event.position)
				accept_event()

	func _on_touch_down(local_pos: Vector2) -> void:
		is_held = true
		is_dragging = false
		drag_start = global_position + local_pos
		z_index = 60
		Input.vibrate_handheld(15)
		if current_tween: current_tween.kill()
		current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		current_tween.tween_property(self, "position:y", home_pos.y - 32.0, 0.18)
		current_tween.tween_property(self, "rotation", 0.0, 0.18)
		current_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.18)

	func _on_drag(local_pos: Vector2) -> void:
		var cur_global := global_position + local_pos
		var delta: Vector2 = cur_global - drag_start
		if not is_dragging and delta.length() > 6.0:
			is_dragging = true
		if is_dragging:
			if current_tween: current_tween.kill()
			global_position = cur_global - Vector2(custom_minimum_size.x / 2.0, custom_minimum_size.y / 2.0)
			rotation = 0.0
			scale = Vector2(1.12, 1.12)
			target_enemy_idx = -1
			if game:
				for box in game.enemy_boxes:
					if box and is_instance_valid(box):
						var rect: Rect2 = box.get_global_rect()
						if rect.has_point(cur_global):
							target_enemy_idx = int(box.get_meta("enemy_index"))
							game._set_enemy_targeted(target_enemy_idx, true)
						else:
							game._set_enemy_targeted(int(box.get_meta("enemy_index")), false)
				# Only rebuild the preview when the hovered enemy changes, not on every drag sample.
				if target_enemy_idx != preview_index:
					preview_index = target_enemy_idx
					if target_enemy_idx >= 0: game._show_damage_preview(card_data, target_enemy_idx)
					else: game._clear_damage_preview()

	func _on_touch_up() -> void:
		if not is_held: return
		is_held = false
		preview_index = -1
		if game:
			game._clear_damage_preview()
			for box in game.enemy_boxes:
				if box and is_instance_valid(box):
					game._set_enemy_targeted(int(box.get_meta("enemy_index")), false)

		var played := false
		if not is_dragging:
			# Defer the rebuild until this input callback has returned; playing a card
			# recreates the battle view and frees the current hand nodes.
			game.call_deferred("_tap_card", hand_index)
			is_dragging = false
			return

		if is_dragging and (position.y < home_pos.y - 60.0 or global_position.y < 580.0):
			var final_target := target_enemy_idx
			if final_target < 0 and card_data.get("kind", "Skill") == "Attack":
				var alive_indices := []
				for i in game.combat.state.enemies.size():
					if game.combat.state.enemies[i].health > 0:
						alive_indices.append(i)
				if alive_indices.size() == 1:
					final_target = alive_indices[0]
			played = game._attempt_play_card(hand_index, final_target)

		if not played:
			_spring_back()
		is_dragging = false

	func _spring_back() -> void:
		z_index = hand_index
		if current_tween: current_tween.kill()
		current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		current_tween.tween_property(self, "position", home_pos, 0.4)
		current_tween.tween_property(self, "rotation", home_rot, 0.3)
		current_tween.tween_property(self, "scale", Vector2.ONE, 0.3)


var content := SpiritContent.new()
var profile: Dictionary
var combat: SpiritCombat
var current_stage := 0
var active_modifier: Dictionary = {}
var root: Control
var overlay: Control
var map_canvas: Control
var map_scroll: TouchScrollContainer
var traveler: Sprite2D
var enemy_boxes: Array[Control] = []
var selected_rune := ""
var muted := false
var lang := "zh-Hans"
var resolving := false
var loadout_tab := "equipment"
var _back_action := Callable()
var _swipe_origin := Vector2.ZERO
var _swipe_tracking := false
var map_music: AudioStreamPlayer
var battle_music: AudioStreamPlayer
var font_cjk: Font = load("res://assets/fonts/NotoSansSC.ttf")

var _char_atlas_tex: Texture2D = null
var _card_atlas_1: Texture2D = null
var _card_atlas_2: Texture2D = null

const BG = Color("071116")
const PANEL = Color("10242b")
const JADE = Color("83e4c1")
const EMBER = Color("ff9a4c")
const GOLD = Color("dab56e")
const TEXT = Color("f7f3e8")
const MUTED = Color("bdd0d0")
const BATTLE_BACKGROUNDS = ["battlefield-v1.jpg","lantern-marsh-v1.jpg","rune-ravine-v1.jpg","ember-cliff-v1.jpg","mountain-forge-v1.jpg"]

const MAP_WIDTH = 366.0
const BAND_HEIGHT = 520.0
# Serpentine trail inside one chapter band, walked top to bottom as the stage index grows.
const BAND_NODES = [Vector2(76,118), Vector2(214,196), Vector2(112,286), Vector2(252,368), Vector2(166,456)]
const CHAPTER_BACKGROUNDS = [
	"spirit-world-map-v1.jpg","lantern-marsh-v1.jpg","rune-ravine-v1.jpg","ember-cliff-v1.jpg","mountain-forge-v1.jpg",
	"battlefield-v1.jpg","lantern-marsh-v1.jpg","spirit-world-map-v1.jpg","ember-cliff-v1.jpg","mountain-forge-v1.jpg",
]
# Each chapter gets its own wash of colour so repeated art still reads as a distinct region.
const CHAPTER_TINTS = [
	Color(0.72,0.88,0.86), Color(0.95,0.78,0.55), Color(0.72,0.80,1.00), Color(0.80,0.86,0.92), Color(0.74,0.92,0.72),
	Color(0.68,0.90,0.95), Color(0.70,0.96,0.80), Color(0.88,0.82,0.98), Color(1.00,0.72,0.56), Color(0.98,0.86,0.62),
]

const CHAR_KEYS = {
	"fox": Vector2i(0, 0),
	"sentinel": Vector2i(1, 0),
	"lanternstone": Vector2i(2, 0),
	"runebound": Vector2i(0, 1),
	"embercliff": Vector2i(1, 1),
	"mountainHeart": Vector2i(2, 1),
	"runeShard": Vector2i(0, 2),
	"ashRaven": Vector2i(1, 2),
	"forgeSpark": Vector2i(2, 2),
}

const CARD_ATLAS_1_POS = {
	"moonfang": Vector2i(0, 0),
	"renewal": Vector2i(1, 0),
	"spiritCurrent": Vector2i(0, 1),
	"ashRecall": Vector2i(1, 1),
}

const CARD_ATLAS_2_POS = {
	"emberClaw": Vector2i(0, 0),
	"mirrorWard": Vector2i(1, 0),
	"wildSpark": Vector2i(0, 1),
	"foxBlessing": Vector2i(1, 1),
	"stoneBreaker": Vector2i(0, 0),
	"calmWard": Vector2i(1, 0),
	"spiritLance": Vector2i(0, 1),
	"cinderHex": Vector2i(1, 1),
	"stormArc": Vector2i(0, 1),
	"soulBrand": Vector2i(0, 0),
	"twinMoon": Vector2i(1, 0),
	"finalFlare": Vector2i(1, 1),
	"mountainSeal": Vector2i(1, 0),
	"worldFlame": Vector2i(0, 0),
}

func _get_character_texture(key: String) -> Texture2D:
	if _char_atlas_tex == null:
		_char_atlas_tex = load("res://assets/characters/character-atlas-v3.png")
	if not CHAR_KEYS.has(key):
		key = "sentinel"
	var coord: Vector2i = CHAR_KEYS[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = _char_atlas_tex
	var cell_w := float(_char_atlas_tex.get_width()) / 3.0
	var cell_h := float(_char_atlas_tex.get_height()) / 3.0
	atlas.region = Rect2(coord.x * cell_w, coord.y * cell_h, cell_w, cell_h)
	return atlas

func _art_key_for_enemy(enemy: Dictionary) -> String:
	var art_str: String = str(enemy.get("art", ""))
	if art_str.contains("sentinel"): return "sentinel"
	if art_str.contains("lanternstone"): return "lanternstone"
	if art_str.contains("runebound"): return "runebound"
	if art_str.contains("embercliff"): return "embercliff"
	if art_str.contains("mountain") or art_str.contains("heart"): return "mountainHeart"
	if art_str.contains("raven"): return "ashRaven"
	if art_str.contains("shard"): return "runeShard"
	if art_str.contains("spark"): return "forgeSpark"
	var name_str: String = str(enemy.get("name", ""))
	if name_str.contains("守卫"): return "sentinel"
	if name_str.contains("提灯"): return "lanternstone"
	if name_str.contains("巨像"): return "runebound"
	if name_str.contains("烬崖"): return "embercliff"
	if name_str.contains("山岳"): return "mountainHeart"
	if name_str.contains("随从"): return "ashRaven"
	return "sentinel"

func _get_card_texture(card_id: String) -> Texture2D:
	if CARD_ATLAS_1_POS.has(card_id):
		if _card_atlas_1 == null: _card_atlas_1 = load("res://assets/cards/new-cards-atlas.jpg")
		var coord: Vector2i = CARD_ATLAS_1_POS[card_id]
		var atlas := AtlasTexture.new()
		atlas.atlas = _card_atlas_1
		var cell_size := Vector2(_card_atlas_1.get_width(), _card_atlas_1.get_height()) / Vector2(2.0, 2.0)
		atlas.region = Rect2(Vector2(coord) * cell_size, cell_size)
		return atlas
	elif CARD_ATLAS_2_POS.has(card_id):
		if _card_atlas_2 == null: _card_atlas_2 = load("res://assets/cards/new-cards-atlas-2.jpg")
		var coord: Vector2i = CARD_ATLAS_2_POS[card_id]
		var atlas := AtlasTexture.new()
		atlas.atlas = _card_atlas_2
		var cell_size := Vector2(_card_atlas_2.get_width(), _card_atlas_2.get_height()) / Vector2(2.0, 2.0)
		atlas.region = Rect2(Vector2(coord) * cell_size, cell_size)
		return atlas
	elif card_id in ["strike", "ward", "foxfire", "focus"]:
		return load("res://assets/cards/%s.jpg" % card_id)
	else:
		if _card_atlas_1 == null: _card_atlas_1 = load("res://assets/cards/new-cards-atlas.jpg")
		var atlas := AtlasTexture.new()
		atlas.atlas = _card_atlas_1
		atlas.region = Rect2(0, 0, float(_card_atlas_1.get_width()) / 2.0, float(_card_atlas_1.get_height()) / 2.0)
		return atlas

func t(key: String) -> String:
	return content.ui(key, lang)

func tf(key: String, args) -> String:
	if args is Array:
		return content.ui(key, lang) % args
	return content.ui(key, lang) % [args]

func _enemy_name(enemy: Dictionary) -> String:
	if lang == "en":
		return str(enemy.get("name_en", enemy.name))
	return str(enemy.name)

func _equip_name(item: Dictionary) -> String:
	return content.equip_name(item, lang)

func _equip_detail(item: Dictionary) -> String:
	return content.equip_detail(item, lang)

func _rune_name(rune: Dictionary) -> String:
	return content.rune_name(rune, lang)

func _rune_detail(rune: Dictionary) -> String:
	return content.rune_detail(rune, lang)

func _relic_name(item: Dictionary) -> String:
	return content.relic_name(item, lang)

func _relic_detail(item: Dictionary) -> String:
	return content.relic_detail(item, lang)

func _toggle_language() -> void:
	lang = "en" if lang == "zh-Hans" else "zh-Hans"
	profile.language = lang
	SpiritSave.write(profile)
	show_map()

func _ready() -> void:
	set_process_input(true)
	profile = SpiritSave.load_profile(content)
	lang = str(profile.get("language", "zh-Hans"))
	_build_audio()
	if SpiritSave.has_account_name(profile): show_map()
	else: show_account_setup()

func show_account_setup() -> void:
	_clear(); _play_music(false)
	var backdrop := _background("spirit-world-map-v1.jpg", .34); root.add_child(backdrop); root.move_child(backdrop, 0)
	var page := _create_page(10)
	page.alignment = BoxContainer.ALIGNMENT_CENTER

	var crest := TextureRect.new()
	crest.texture = _get_character_texture("fox")
	crest.custom_minimum_size = Vector2(0, 130)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	page.add_child(crest)

	page.add_child(_label("SPIRITBOUND", 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(_label(t("ui.account_welcome"), 15, JADE, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(_label(t("ui.account_prompt"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var field := LineEdit.new()
	field.placeholder_text = t("ui.account_placeholder")
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.max_length = 16
	field.custom_minimum_size = Vector2(0, 52)
	field.text = str(profile.get("account", {}).get("name", ""))
	if font_cjk: field.add_theme_font_override("font", font_cjk)
	field.add_theme_font_size_override("font_size", 16)
	field.add_theme_color_override("font_color", TEXT)
	field.add_theme_stylebox_override("normal", _panel(Color("10242b"), 12, Color("2a4d55")))
	field.add_theme_stylebox_override("focus", _panel(Color("14303a"), 12, JADE))
	page.add_child(field)

	page.add_child(_button(t("ui.account_start"), func(): _create_account(field.text), EMBER, Vector2(0, 52)))
	var lang_btn := _button(t("ui.lang_toggle"), func(): lang = "en" if lang == "zh-Hans" else "zh-Hans"; profile.language = lang; show_account_setup(), Color("17363e"), Vector2(0, 42))
	page.add_child(lang_btn)
	field.grab_focus()

func _create_account(raw_name: String) -> void:
	var chosen := raw_name.strip_edges()
	if chosen.is_empty():
		_toast(t("ui.account_need_name"))
		return
	var account: Dictionary = profile.get("account", SpiritSave.new_account())
	account.name = chosen
	profile.account = account
	SpiritSave.write(profile)
	show_map()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: SpiritSave.write(profile)

func _safe_top() -> int:
	var safe := DisplayServer.get_display_safe_area()
	var win_h := DisplayServer.window_get_size().y
	if win_h > 0 and safe.position.y > 0:
		return int(round(float(safe.position.y) * 844.0 / float(win_h)))
	return 46

func _safe_bottom() -> int:
	var safe := DisplayServer.get_display_safe_area()
	var win_h := DisplayServer.window_get_size().y
	if win_h > 0 and safe.size.y > 0:
		var inset := win_h - (safe.position.y + safe.size.y)
		if inset > 0:
			return int(round(float(inset) * 844.0 / float(win_h)))
	return 22

func _clear() -> void:
	for child in get_children():
		if child != map_music and child != battle_music: child.queue_free()
	_back_action = Callable()
	_swipe_tracking = false
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	overlay = Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.z_index = 500; root.add_child(overlay)

# iOS-style interactive back: a drag that starts on the left screen edge pops the page.
func _input(event: InputEvent) -> void:
	if not _back_action.is_valid(): return
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed; released = not event.pressed; pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed; released = not event.pressed; pos = event.position
	else:
		return

	if pressed:
		_swipe_tracking = pos.x <= 26.0
		_swipe_origin = pos
	elif released and _swipe_tracking:
		_swipe_tracking = false
		var delta: Vector2 = pos - _swipe_origin
		if delta.x > 64.0 and absf(delta.y) < 70.0:
			get_viewport().set_input_as_handled()
			Input.vibrate_handheld(12)
			var action := _back_action
			_back_action = Callable()
			action.call()

func _stat_bar(bar_width: float, bar_height: float, value: int, max_value: int, fill_color: Color, text: String, font_size := 9) -> ProgressBar:
	# ProgressBar draws its own fill, so the ratio survives being laid out by a parent container.
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(bar_width, bar_height)
	bar.size = Vector2(bar_width, bar_height)
	bar.max_value = maxf(1.0, float(max_value))
	bar.value = clampf(float(value), 0.0, float(max_value))
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var radius := int(bar_height / 2.0)
	bar.add_theme_stylebox_override("background", _panel(Color(0.02, 0.06, 0.08, 0.85), radius, Color(0, 0, 0, 0.45)))
	bar.add_theme_stylebox_override("fill", _panel(fill_color, radius))
	if not text.is_empty():
		var lbl := _label(text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(lbl)
	return bar

func _icon_badge(glyph: String, color: Color, diameter := 42, glyph_size := 20) -> Panel:
	# Equipment and runes ship as glyphs rather than art, so give each one a coloured medallion.
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.size = badge.custom_minimum_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
	style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	var lbl := _label(glyph, glyph_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	return badge

func _create_page(separation := 6) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", _safe_top())
	margin.add_theme_constant_override("margin_bottom", _safe_bottom())
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(margin)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", separation)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(page)
	return page

func _build_audio() -> void:
	map_music = AudioStreamPlayer.new(); map_music.stream = load("res://assets/audio/spirit-symphony-mobile.wav"); map_music.volume_db = -12; add_child(map_music)
	battle_music = AudioStreamPlayer.new(); battle_music.stream = load("res://assets/audio/ember-battle-mobile.wav"); battle_music.volume_db = -13; add_child(battle_music)
	map_music.finished.connect(func(): if not muted: map_music.play())
	battle_music.finished.connect(func(): if not muted: battle_music.play())

func _play_music(battle := false) -> void:
	if muted: return
	if battle: map_music.stop(); battle_music.play()
	else: battle_music.stop(); if not map_music.playing: map_music.play()

func _panel(color: Color, radius := 12, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = color
	style.corner_radius_top_left = radius; style.corner_radius_top_right = radius; style.corner_radius_bottom_left = radius; style.corner_radius_bottom_right = radius
	if border.a > 0: style.border_width_left = 1; style.border_width_right = 1; style.border_width_top = 1; style.border_width_bottom = 1; style.border_color = border
	return style

func _label(text: String, size := 14, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, autowrap := false) -> Label:
	var value := Label.new(); value.text = text
	if font_cjk: value.add_theme_font_override("font", font_cjk)
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = align
	if autowrap: value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else: value.autowrap_mode = TextServer.AUTOWRAP_OFF
	return value

func _button(text: String, callback: Callable, color := PANEL, min_size := Vector2(0,44)) -> Button:
	var value := Button.new(); value.text = text; value.custom_minimum_size = min_size
	if font_cjk: value.add_theme_font_override("font", font_cjk)
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", TEXT)
	value.add_theme_stylebox_override("normal", _panel(color, 10, GOLD))
	value.add_theme_stylebox_override("hover", _panel(color.lightened(.1), 10, JADE))
	value.add_theme_stylebox_override("pressed", _panel(color.darkened(.12), 10, EMBER))
	value.add_theme_stylebox_override("disabled", _panel(color.darkened(.3), 10, Color("3a4a50")))
	if callback.is_valid(): value.pressed.connect(callback)
	return value

func _texture(path: String) -> Texture2D:
	return load("res://assets/%s" % path)

func _background(file: String, opacity := .42) -> TextureRect:
	var image := TextureRect.new(); image.texture = _texture("backgrounds/%s" % file); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.modulate = Color(1,1,1,opacity); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _header(title: String, subtitle: String, back := Callable()) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 44
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	if back.is_valid():
		var back_btn := _button("‹", back, Color("17363e"), Vector2(36,34))
		back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(back_btn)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_child(_label(title, 16, TEXT))
	copy.add_child(_label(subtitle, 10, JADE))
	bar.add_child(copy)
	var stats := _label("♥ %d/60  ◆ %d" % [profile.health, profile.gold], 11, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	stats.custom_minimum_size.x = 95
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(stats)
	return bar

func show_map() -> void:
	_clear(); _play_music(false)
	var backdrop := ColorRect.new(); backdrop.color = BG; backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop); root.move_child(backdrop,0)
	var page := _create_page(4)

	var header := _header("SPIRITBOUND", t("ui.choose_dest"))
	var btn_lang := _button(t("ui.lang_toggle"), _toggle_language, Color("17363e"), Vector2(50,34))
	btn_lang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(btn_lang)
	var btn_camp := _button("✧%d" % profile.relics.size(), show_camp, Color("17363e"), Vector2(38,34))
	btn_camp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(btn_camp)
	var btn_music := _button("♫" if not muted else "♩", _toggle_music, Color("17363e"), Vector2(34,34))
	btn_music.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(btn_music)
	page.add_child(header)

	map_scroll = TouchScrollContainer.new()
	map_scroll.allow_vertical = true
	map_scroll.allow_horizontal = false
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(map_scroll)

	map_canvas = Control.new()
	map_canvas.custom_minimum_size = Vector2(MAP_WIDTH, BAND_HEIGHT * 10.0)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	map_scroll.add_child(map_canvas)
	for chapter in 10: _add_map_chapter(chapter)
	_add_routes()
	for index in 50: _add_stage_pin(index)

	traveler = Sprite2D.new()
	traveler.texture = _get_character_texture("fox")
	traveler.scale = Vector2(40.0 / 341.33, 40.0 / 341.33)
	traveler.position = _map_point(profile.position) - Vector2(0, 26)
	traveler.z_index = 25
	map_canvas.add_child(traveler)

	var t_idle := traveler.create_tween().set_loops()
	t_idle.tween_property(traveler, "position:y", traveler.position.y - 4.0, 0.75).set_trans(Tween.TRANS_SINE)
	t_idle.tween_property(traveler, "position:y", traveler.position.y + 2.0, 0.85).set_trans(Tween.TRANS_SINE)

	var dock_bg := PanelContainer.new()
	dock_bg.add_theme_stylebox_override("panel", _panel(Color("0c1a1f"), 26, Color("1f404d")))
	page.add_child(dock_bg)
	
	var dock := HBoxContainer.new()
	dock.custom_minimum_size.y = 52
	dock.add_theme_constant_override("separation", 0)
	dock.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_bg.add_child(dock)
	
	var items = [
		["▤\n" + t("ui.deck_btn").replace("▤\n", ""), show_deck],
		["⚔\n" + t("ui.equip_btn").replace("⚔\n", ""), show_loadout],
		["◆\n" + t("ui.shop_btn").replace("◆\n", ""), show_shop],
		["➜\n" + t("ui.next_btn").replace("➜\n", ""), _next_stage]
	]
	
	for i in items.size():
		var item = items[i]
		var btn := Button.new()
		btn.text = item[0]
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if font_cjk: btn.add_theme_font_override("font", font_cjk)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", GOLD)
		var s := StyleBoxEmpty.new()
		var h := StyleBoxFlat.new(); h.bg_color = Color(1,1,1,0.05); h.corner_radius_bottom_left = 26 if i==0 else 0; h.corner_radius_top_left = 26 if i==0 else 0; h.corner_radius_bottom_right = 26 if i==items.size()-1 else 0; h.corner_radius_top_right = 26 if i==items.size()-1 else 0
		var p := h.duplicate(); p.bg_color = Color(1,1,1,0.1)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_stylebox_override("pressed", p)
		btn.add_theme_stylebox_override("focus", s)
		btn.pressed.connect(item[1])
		dock.add_child(btn)
	await get_tree().process_frame
	if map_scroll: map_scroll.scroll_vertical = int(maxi(0, int(_map_point(profile.position).y - 280)))

func _map_point(index: int) -> Vector2:
	var node: Vector2 = BAND_NODES[index % 5]
	return Vector2(node.x, float(index / 5) * BAND_HEIGHT + node.y)

func _fade_strip(height: float, flipped: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BG.r, BG.g, BG.b, 1.0))
	gradient.set_color(1, Color(BG.r, BG.g, BG.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 4
	tex.height = 96
	tex.fill_from = Vector2(0, 1) if flipped else Vector2(0, 0)
	tex.fill_to = Vector2(0, 0) if flipped else Vector2(0, 1)
	var strip := TextureRect.new()
	strip.texture = tex
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.size = Vector2(MAP_WIDTH, height)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return strip

func _add_map_chapter(chapter: int) -> void:
	var tint: Color = CHAPTER_TINTS[chapter % CHAPTER_TINTS.size()]
	var band := Control.new()
	band.position = Vector2(0, float(chapter) * BAND_HEIGHT)
	band.size = Vector2(MAP_WIDTH, BAND_HEIGHT)
	band.custom_minimum_size = band.size
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(band)

	var art := TextureRect.new()
	art.texture = _texture("backgrounds/%s" % CHAPTER_BACKGROUNDS[chapter % CHAPTER_BACKGROUNDS.size()])
	art.size = Vector2(MAP_WIDTH, BAND_HEIGHT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(tint.r, tint.g, tint.b, 0.62)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(art)

	# Fade both seams into the page colour so consecutive chapters read as one continuous world.
	var top_fade := _fade_strip(84.0, false)
	band.add_child(top_fade)
	var bottom_fade := _fade_strip(84.0, true)
	bottom_fade.position = Vector2(0, BAND_HEIGHT - 84.0)
	band.add_child(bottom_fade)

	var locked: bool = chapter * 5 > int(profile.unlocked)
	var plaque := Panel.new()
	plaque.position = Vector2(MAP_WIDTH / 2.0 - 112.0, 24.0)
	plaque.size = Vector2(224, 52)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_theme_stylebox_override("panel", _panel(Color(0.02, 0.07, 0.09, 0.84), 14, tint if not locked else Color("39494e")))
	band.add_child(plaque)

	var plaque_stack := VBoxContainer.new()
	plaque_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plaque_stack.add_theme_constant_override("separation", 0)
	plaque_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	plaque_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(plaque_stack)
	plaque_stack.add_child(_label(tf("ui.chapter_title", chapter + 1), 11, tint if not locked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	plaque_stack.add_child(_label(content.chapter_name(chapter, lang), 17, TEXT if not locked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))

func _add_routes() -> void:
	var shadow := Line2D.new()
	shadow.width = 9.0
	shadow.default_color = Color(0.02, 0.05, 0.07, 0.55)
	shadow.z_index = 2
	shadow.joint_mode = Line2D.LINE_JOINT_ROUND
	var trail := Line2D.new()
	trail.width = 4.0
	trail.default_color = Color(1.0, 0.84, 0.48, 0.5)
	trail.z_index = 3
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	var walked := Line2D.new()
	walked.width = 4.0
	walked.default_color = Color(0.55, 0.93, 0.79, 0.9)
	walked.z_index = 4
	walked.joint_mode = Line2D.LINE_JOINT_ROUND
	for index in 50:
		var point := _map_point(index)
		shadow.add_point(point)
		trail.add_point(point)
		if index <= int(profile.unlocked): walked.add_point(point)
	map_canvas.add_child(shadow)
	map_canvas.add_child(trail)
	if walked.get_point_count() > 1: map_canvas.add_child(walked)

func _stage_glyph(index: int) -> String:
	match content.node_kind(index):
		"boss": return "★"
		"elite": return "✦"
		"event": return "?"
		"merchant": return "◆"
		"rest": return "♨"
		_: return "⚔"

func _add_stage_pin(index: int) -> void:
	var encounter: Dictionary = content.encounters[index]
	var point := _map_point(index)
	var locked := index > int(profile.unlocked)
	var is_current := index == int(profile.position)
	var kind := content.node_kind(index)
	var is_boss := kind == "boss"

	var pin_size := Vector2(62.0, 54.0) if not is_boss else Vector2(70.0, 60.0)
	var bg_color := Color("18414a")
	var border_color := JADE
	match kind:
		"boss": bg_color = Color("5d2f1c"); border_color = GOLD
		"elite": bg_color = Color("46265c"); border_color = Color("c79bff")
		"merchant": bg_color = Color("21484f"); border_color = Color("7fd8e8")
		"rest": bg_color = Color("1f4a3c"); border_color = Color("8ff5cf")
		"event": bg_color = Color("2a4058"); border_color = Color("9fc2ff")
	if locked:
		bg_color = Color("16262a")
		border_color = Color("36474c")
	elif is_current:
		bg_color = Color("8c542a")
		border_color = EMBER

	var pin := Button.new()
	pin.custom_minimum_size = pin_size
	pin.size = pin_size
	pin.position = point - pin_size / 2.0
	pin.disabled = locked
	pin.z_index = 10
	pin.focus_mode = Control.FOCUS_NONE
	pin.add_theme_stylebox_override("normal", _panel(bg_color, 16, border_color))
	pin.add_theme_stylebox_override("hover", _panel(bg_color.lightened(0.12), 16, EMBER))
	pin.add_theme_stylebox_override("pressed", _panel(bg_color.darkened(0.15), 16, GOLD))
	pin.add_theme_stylebox_override("disabled", _panel(bg_color, 16, Color("2b393d")))
	pin.pressed.connect(func(): _travel_to(index))
	map_canvas.add_child(pin)

	var pin_stack := VBoxContainer.new()
	pin_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pin_stack.add_theme_constant_override("separation", -1)
	pin_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	pin_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(pin_stack)
	pin_stack.add_child(_label("🔒" if locked else _stage_glyph(index), 15 if not locked else 12, border_color if not locked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	pin_stack.add_child(_label("%d-%d" % [encounter.chapter, encounter.level], 13 if is_boss else 12, TEXT if not locked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if is_current and not locked:
		var halo := pin.create_tween().set_loops()
		halo.tween_property(pin, "modulate", Color(1.25, 1.12, 0.95), 0.85).set_trans(Tween.TRANS_SINE)
		halo.tween_property(pin, "modulate", Color.WHITE, 0.85).set_trans(Tween.TRANS_SINE)

	var caption := _label(content.waypoint_name(index % 5, lang) if not locked else t("ui.locked"), 10, TEXT if not locked else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.size = Vector2(112.0, 16.0)
	caption.position = Vector2(point.x - 56.0, point.y + pin_size.y / 2.0 + 3.0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(caption)

func _travel_to(index: int) -> void:
	if index > int(profile.unlocked): return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(traveler, "position", _map_point(index) - Vector2(0, 26), 0.65)
	for value in range(int(profile.position), index + 1):
		tween.parallel().tween_method(func(y): map_scroll.scroll_vertical = int(y), float(map_scroll.scroll_vertical), float(maxi(0, int(_map_point(index).y - 280))), 0.65)
	await tween.finished; profile.position = index; SpiritSave.write(profile)
	var kind := content.node_kind(index)
	if kind in ["event","merchant","rest"] and index == int(profile.unlocked): show_event(index,kind)
	else: begin_battle(index)

func _next_stage() -> void:
	if int(profile.position) < int(profile.unlocked): _travel_to(int(profile.position)+1)
	else: _travel_to(int(profile.position))

func _modifier(seed: int, stage: int) -> Dictionary:
	var options := [
		{"id":"reinforced","name":"重甲军势","name_en":"Reinforced Army","detail":"敌人生命 +30%，金币 +35%","detail_en":"Enemy HP +30%, Gold +35%","health_scale":1.3,"reward_scale":1.35},
		{"id":"frenzy","name":"血月狂怒","name_en":"Blood Frenzy","detail":"敌人攻击 +3，金币 +30%","detail_en":"Enemy ATK +3, Gold +30%","damage_bonus":3,"reward_scale":1.3},
		{"id":"swarm","name":"狩猎群落","name_en":"Hunting Swarm","detail":"增加一名敌人，金币 +40%","detail_en":"+1 Enemy, Gold +40%","extra_enemy":1,"health_scale":1.08,"reward_scale":1.4},
		{"id":"rebirth","name":"不灭余烬","name_en":"Undying Embers","detail":"敌人可能复活，金币 +50%","detail_en":"Enemies may revive, Gold +50%","revive":.45,"health_scale":1.1,"damage_bonus":1,"reward_scale":1.5},
		{"id":"eclipse","name":"灵蚀天象","name_en":"Spirit Eclipse","detail":"生命与攻击提升，金币 +45%","detail_en":"Enemy HP & ATK boosted, Gold +45%","health_scale":1.18,"damage_bonus":2,"reward_scale":1.45},
	]
	var value: int = absi(seed ^ ((stage + 1) * 2654435761))
	return {} if value % 100 < 48 else options[(value / 100) % options.size()]

func begin_battle(index: int) -> void:
	current_stage = index
	var seed := int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	active_modifier = _modifier(seed,index)
	combat = SpiritCombat.new(content)
	var equipped: Array = profile.equipment_slots.values()
	combat.create(seed,content.encounters[index],profile.deck,int(profile.health),profile.upgrades,equipped,profile.card_runes,active_modifier,profile.relics)
	combat.event.connect(_combat_event)
	show_battle()
	_maybe_end_turn()

func show_battle() -> void:
	_clear(); _play_music(true); enemy_boxes.clear()
	var encounter: Dictionary = content.encounters[current_stage]
	var bg := _background(BATTLE_BACKGROUNDS[encounter.background],.28); root.add_child(bg); root.move_child(bg,0)
	var page := _create_page(4)

	var top := HBoxContainer.new(); top.custom_minimum_size.y = 44
	top.add_child(_label("%d-%d  %s" % [encounter.chapter,encounter.level,content.stage_name(current_stage, lang)], 13, JADE))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer)
	top.add_child(_label(tf("ui.turn_n", combat.state.turn), 11, GOLD))
	var leave_btn := _button("⌂", _leave_battle, Color("17363e"), Vector2(36,34))
	leave_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(leave_btn); page.add_child(top)

	if not active_modifier.is_empty():
		var m_name = active_modifier.name_en if lang == "en" else active_modifier.name
		var m_det = active_modifier.detail_en if lang == "en" else active_modifier.detail
		var modifier := _label("✥ %s  ·  %s" % [m_name, m_det], 10, Color("ffe2b0"), HORIZONTAL_ALIGNMENT_CENTER)
		modifier.custom_minimum_size.y = 28
		modifier.add_theme_stylebox_override("normal", _panel(Color("54261f"), 9, EMBER))
		page.add_child(modifier)

	if not combat.state.equipment.is_empty() or not profile.relics.is_empty():
		var gear := HBoxContainer.new()
		gear.alignment = BoxContainer.ALIGNMENT_CENTER
		gear.add_theme_constant_override("separation", 8)
		for id in combat.state.equipment:
			var item := content.equipment(id)
			if not item.is_empty(): gear.add_child(_label("%s %s" % [item.icon, _equip_name(item)], 9, GOLD))
		for id in profile.relics:
			var relic := content.relic(id)
			if not relic.is_empty(): gear.add_child(_label("%s %s" % [relic.icon, _relic_name(relic)], 9, Color(relic.color)))
		page.add_child(gear)

	var enemy_area := HBoxContainer.new()
	enemy_area.custom_minimum_size.y = 205.0
	enemy_area.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_area.add_theme_constant_override("separation", 10)
	page.add_child(enemy_area)
	for index in combat.state.enemies.size():
		if combat.state.enemies[index].health <= 0: continue
		var box := _enemy_view(index)
		enemy_area.add_child(box)
		enemy_boxes.append(box)

	page.add_child(_build_player_stage())

	var push_down := Control.new()
	push_down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(push_down)

	if combat.state.phase == "player":
		_add_hand(page)
	else:
		var outcome := _label(t("ui.battle_won") if combat.state.phase == "won" else t("ui.battle_lost"), 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		outcome.size_flags_vertical = Control.SIZE_EXPAND_FILL; outcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; page.add_child(outcome)
		page.add_child(_button(t("ui.open_chest") if combat.state.phase == "won" else t("ui.return_map"), show_reward if combat.state.phase == "won" else _leave_battle, EMBER, Vector2(0,50)))

func _intent_style(intent: Dictionary) -> Dictionary:
	var kind := str(intent.get("kind", "attack"))
	var amount := int(intent.get("amount", 0))
	match kind:
		"critical":
			return {"text": tf("ui.intent_critical", amount), "bg": Color("8c2f19"), "border": Color("ff8d5c"), "text_color": Color("ffe1c9")}
		"defend":
			return {"text": tf("ui.intent_defend", amount), "bg": Color("15364f"), "border": Color("7fb8e8"), "text_color": Color("d6ecff")}
		"empower":
			return {"text": tf("ui.intent_empower", amount), "bg": Color("3a1f52"), "border": Color("c79bff"), "text_color": Color("ecdcff")}
		"curse":
			return {"text": tf("ui.intent_curse", amount), "bg": Color("2f4420"), "border": Color("a8dd6c"), "text_color": Color("e2f7c6")}
		"attack_defend":
			return {"text": tf("ui.intent_attack_defend", [amount, int(intent.get("shield", 0))]), "bg": Color("4a2a1c"), "border": Color("e0a878"), "text_color": Color("ffe7d2")}
		_:
			return {"text": tf("ui.intent_attack", amount), "bg": Color(0.29, 0.11, 0.07, 0.92), "border": Color("e39761"), "text_color": Color("ffe1c9")}

func _enemy_view(index: int) -> Control:
	var enemy: Dictionary = combat.state.enemies[index]
	var unit := Control.new()
	unit.name = "Enemy_%d" % index
	var enemy_count := maxi(1, combat.state.enemies.size())
	var u_width: float = minf(112.0, (366.0 - 10.0 * float(enemy_count - 1)) / float(enemy_count))
	unit.custom_minimum_size = Vector2(u_width, 205.0)
	unit.size = unit.custom_minimum_size
	unit.set_meta("enemy_index", index)
	unit.mouse_filter = Control.MOUSE_FILTER_PASS

	var center_x := u_width / 2.0

	var glow := PanelContainer.new()
	glow.name = "TargetGlow"
	glow.custom_minimum_size = Vector2(74.0, 20.0)
	glow.size = glow.custom_minimum_size
	glow.position = Vector2(center_x - 37.0, 114.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _panel(Color(1.0, 0.86, 0.42, 0.25), 10, Color(1.0, 0.86, 0.42, 0.5)))
	glow.modulate.a = 0.2
	unit.add_child(glow)

	var art_key := _art_key_for_enemy(enemy)
	var sprite := Sprite2D.new()
	sprite.name = "MonsterSprite"
	sprite.texture = _get_character_texture(art_key)
	var sprite_side := clampf(u_width - 16.0, 70.0, 96.0)
	var spr_size := Vector2(sprite_side, sprite_side)
	var cell_w := float(_char_atlas_tex.get_width()) / 3.0
	var scale_factor: float = minf(spr_size.x / cell_w, spr_size.y / cell_w)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.position = Vector2(center_x, 26.0 + spr_size.y / 2.0)
	unit.add_child(sprite)

	var idle := sprite.create_tween().set_loops()
	idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
	idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)

	var intent: Dictionary = enemy.get("intent", {})
	var intent_style := _intent_style(intent)
	var intent_bg := Panel.new()
	intent_bg.custom_minimum_size = Vector2(66.0, 24.0)
	intent_bg.size = intent_bg.custom_minimum_size
	intent_bg.position = Vector2(center_x - 33.0, 0.0)
	intent_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_bg.add_theme_stylebox_override("panel", _panel(intent_style.bg, 12, intent_style.border))
	var intent_lbl := _label(intent_style.text, 11, intent_style.text_color, HORIZONTAL_ALIGNMENT_CENTER)
	intent_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intent_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intent_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_bg.add_child(intent_lbl)
	unit.add_child(intent_bg)

	var element: String = enemy.get("element", "")
	if not element.is_empty():
		var el_lbl := _label(t("element.%s" % element), 8, Color("8de7e0") if element == "water" else Color("ff9a6d"), HORIZONTAL_ALIGNMENT_CENTER)
		el_lbl.position = Vector2(4, 4)
		unit.add_child(el_lbl)

	var name_lbl := _label(_enemy_name(enemy), 10, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.position = Vector2(0, 128.0)
	name_lbl.size = Vector2(u_width, 18.0)
	unit.add_child(name_lbl)

	var hp_bar_w := u_width - 12.0
	var hp_bar := _stat_bar(hp_bar_w, 16.0, int(enemy.health), int(enemy.max_health), Color(enemy.get("tint", "83e4c1")), "%d/%d" % [enemy.health, enemy.max_health], 9)
	hp_bar.name = "HealthBar"
	hp_bar.position = Vector2(6.0, 148.0)
	unit.add_child(hp_bar)

	var badges := HBoxContainer.new()
	badges.position = Vector2(0.0, 167.0)
	badges.size = Vector2(u_width, 18.0)
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 5)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit.add_child(badges)
	if int(enemy.shield) > 0: badges.add_child(_label("◆%d" % enemy.shield, 10, Color("9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER))
	if int(enemy.burn) > 0: badges.add_child(_label("♨%d" % enemy.burn, 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER))
	if int(enemy.stun) > 0: badges.add_child(_label("✸%d" % enemy.stun, 10, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER))

	return unit

func _build_player_stage() -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(366.0, 118.0)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var center_x := 366.0 / 2.0

	var sprite := Sprite2D.new()
	sprite.name = "PlayerSprite"
	sprite.texture = _get_character_texture("fox")
	var spr_size := Vector2(74.0, 74.0)
	var cell_w := float(_char_atlas_tex.get_width()) / 3.0
	var scale_factor: float = minf(spr_size.x / cell_w, spr_size.y / cell_w)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.set_meta("base_scale", scale_factor)
	sprite.position = Vector2(center_x, 37.0)
	stage.add_child(sprite)

	var idle := sprite.create_tween().set_loops()
	idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
	idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)

	var max_hp: int = int(combat.state.player.get("max_health", 60))
	var hp_bar := _stat_bar(168.0, 18.0, int(combat.state.player.health), max_hp, EMBER, "%s  ♥ %d/%d" % [t("ui.spirit_name"), combat.state.player.health, max_hp], 10)
	hp_bar.position = Vector2(center_x - 84.0, 78.0)
	stage.add_child(hp_bar)

	var badges := HBoxContainer.new()
	badges.position = Vector2(center_x - 84.0, 98.0)
	badges.size = Vector2(168.0, 18.0)
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 8)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(badges)
	if int(combat.state.player.shield) > 0: badges.add_child(_label("◆ %d" % combat.state.player.shield, 11, Color("9fd8ff")))
	if int(combat.state.player.focus) > 0: badges.add_child(_label("◉ %d" % combat.state.player.focus, 11, Color("ffe08a")))
	if int(combat.state.player.burn) > 0: badges.add_child(_label("♨ %d" % combat.state.player.burn, 11, Color("ff9868")))

	return stage

func _pile_chip(count: int, caption: String, number_color: Color) -> Panel:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(52.0, 46.0)
	chip.size = chip.custom_minimum_size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _panel(Color("0c1a1f"), 10, Color("1f404d")))
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(stack)
	stack.add_child(_label(str(count), 17, number_color, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label(caption, 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return chip

func _add_hand(page: VBoxContainer) -> void:
	# Resource row sits on its own line; previously these floated over the fanned cards.
	var status := HBoxContainer.new()
	status.custom_minimum_size.y = 48
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 10)
	page.add_child(status)

	status.add_child(_pile_chip(combat.state.draw.size(), t("ui.draw_pile"), Color("f3e8cf")))

	var orb := Panel.new()
	orb.custom_minimum_size = Vector2(48.0, 48.0)
	orb.size = orb.custom_minimum_size
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_theme_stylebox_override("panel", _panel(Color("003140"), 24, Color("4dc5e8")))
	var orb_lbl := _label("⚡%d" % combat.state.energy, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	orb_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orb_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	orb_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(orb_lbl)
	status.add_child(orb)

	# Remaining plays as pips: the turn ends by itself once they run out, so there is no End Turn button.
	var plays := VBoxContainer.new()
	plays.alignment = BoxContainer.ALIGNMENT_CENTER
	plays.add_theme_constant_override("separation", 1)
	plays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(plays)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plays.add_child(pips)
	var total_plays: int = maxi(2, int(combat.state.actions))
	for i in total_plays:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lit: bool = i < int(combat.state.actions)
		pip.add_theme_stylebox_override("panel", _panel(GOLD if lit else Color("23383d"), 7, GOLD if lit else Color("32474c")))
		pips.add_child(pip)
	plays.add_child(_label(t("ui.actions_label"), 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	status.add_child(_pile_chip(combat.state.discard.size(), t("ui.discard_pile"), Color("a8b2b5")))

	var hand_zone := Control.new()
	hand_zone.custom_minimum_size = Vector2(366.0, 186.0)
	hand_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(hand_zone)

	var count: int = combat.state.hand.size()
	for index in count:
		var card_tile := _card_view(combat.state.hand[index], index, count)
		hand_zone.add_child(card_tile)

func _tap_card(hand_index: int) -> void:
	_attempt_play_card(hand_index, -1)

func _has_playable_card() -> bool:
	if combat == null: return false
	for instance in combat.state.hand:
		var card := content.card(instance.card_id)
		if not card.is_empty() and int(card.cost) <= int(combat.state.energy): return true
	return false

func _card_view(instance: Dictionary, index: int, count: int) -> HandCard:
	var card := content.card(instance.card_id)
	var tile := HandCard.new()
	tile.hand_index = index
	tile.card_data = card
	tile.game = self
	tile.custom_minimum_size = Vector2(116.0, 168.0)
	tile.size = tile.custom_minimum_size

	var accent: Color = _card_color(card)
	var rune_id: String = profile.card_runes.get(card.id, "")
	var border_col: Color = _rune_color(rune_id, accent)

	var frame := PanelContainer.new()
	frame.name = "CardFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _panel(Color("15262b"), 12, border_col))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(frame)

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 2)
	frame.add_child(stack)

	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size.y = 82.0
	art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_frame.add_theme_stylebox_override("panel", _panel(Color("0a171b"), 6))
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art := TextureRect.new()
	art.texture = _get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Card artwork is portrait-oriented; preserve the full illustration instead of cropping it.
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var art_clip := PanelContainer.new()
	art_clip.clip_contents = true
	art_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_clip.add_theme_stylebox_override("panel", _panel(Color.TRANSPARENT, 6))
	art_clip.add_child(art)
	art_frame.add_child(art_clip)
	stack.add_child(art_frame)
	
	var cost_badge := PanelContainer.new()
	cost_badge.custom_minimum_size = Vector2(26, 26)
	cost_badge.position = Vector2(-8, -8)
	cost_badge.add_theme_stylebox_override("panel", _panel(accent, 13, Color("2b1a10")))
	var cost_lbl := _label(str(card.cost), 16, Color("160b06"), HORIZONTAL_ALIGNMENT_CENTER)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_lbl)
	tile.add_child(cost_badge)

	var rune_info: Dictionary = content.rune(rune_id)
	if not rune_info.is_empty():
		var r_lbl := _label(rune_info.icon, 16, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
		r_lbl.position = Vector2(116.0 - 24.0, -6.0)
		tile.add_child(r_lbl)

	var up_lvl: int = int(profile.upgrades.get(card.id, 0))
	var name_text: String = content.text(card.nameKey, lang) + (" +" if up_lvl > 0 else "")
	var name_lbl := _label(name_text, 10, Color("23150d"), HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.add_theme_stylebox_override("normal", _panel(Color("ead6a9"), 4))
	stack.add_child(name_lbl)

	var kind_lbl := _label("%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), t("element.%s" % card.get("element", "spirit"))], 7, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(kind_lbl)

	var desc_lbl := _label(_card_description(card), 7, Color("2b241b"), HORIZONTAL_ALIGNMENT_CENTER, true)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_stylebox_override("normal", _panel(Color("f3e8cf"), 4))
	stack.add_child(desc_lbl)

	var center_idx: float = (count - 1) / 2.0
	var distance: float = float(index) - center_idx
	var spacing: float = minf(64.0, 250.0 / maxf(1.0, float(count - 1)))
	var center_x: float = 366.0 / 2.0
	tile.home_rot = deg_to_rad(distance * 2.8)
	tile.home_pos = Vector2(center_x + distance * spacing - 58.0, 10.0 + absf(distance) * 4.2)
	tile.position = tile.home_pos
	tile.rotation = tile.home_rot
	tile.z_index = index

	return tile

# Mirrors the bonuses combat.play() applies, so the number on screen matches what lands.
func _predict_damage(card: Dictionary, enemy_index: int) -> Dictionary:
	var result := {"damage": 0, "blocked": 0, "lethal": false, "is_attack": false}
	if combat == null or enemy_index < 0 or enemy_index >= combat.state.enemies.size(): return result
	var base := 0
	for effect in card.effects:
		if effect.operation == "damage" and effect.target == "opponent": base += int(effect.amount)
	if base <= 0: return result
	result.is_attack = true

	var bonus := int(combat.state.upgrades.get(card.id, 0))
	if int(combat.state.player.focus) > 0: bonus += 3 * int(combat.state.player.focus)
	if not bool(combat.state.first_attack):
		if combat.state.equipment.has("emberBlade"): bonus += 3
		if combat.state.get("relics", []).has("starShard"): bonus += 2
	var rune: String = combat.state.runes.get(card.id, "")
	if rune == "resonance": bonus += int(combat.state.elements.get(card.get("element", ""), 0))

	var enemy: Dictionary = combat.state.enemies[enemy_index]
	var total := 0
	for effect in card.effects:
		if effect.operation != "damage" or effect.target != "opponent": continue
		var amount: int = maxi(1, int(effect.amount) + bonus)
		if rune == "execute" and enemy.health <= enemy.max_health * 0.25: amount = int(round(amount * 1.5))
		if card.get("special", "") == "critical": amount *= 2
		total += amount
	if rune == "echo": total += int(round(total * 0.5))

	var pierce: bool = card.get("special", "") == "pierce" or combat.state.equipment.has("stoneSpear")
	var blocked: int = 0 if pierce else mini(int(enemy.shield), total)
	result.blocked = blocked
	result.damage = maxi(0, total - blocked)
	result.lethal = result.damage >= int(enemy.health)
	return result

func _show_damage_preview(card: Dictionary, enemy_index: int) -> void:
	_clear_damage_preview()
	if overlay == null: return
	var prediction := _predict_damage(card, enemy_index)
	if not prediction.is_attack: return
	var box: Control = null
	for candidate in enemy_boxes:
		if candidate and is_instance_valid(candidate) and int(candidate.get_meta("enemy_index")) == enemy_index:
			box = candidate
			break
	if box == null: return

	var holder := VBoxContainer.new()
	holder.name = "DamagePreview"
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 0)
	holder.position = box.global_position + Vector2(box.size.x / 2.0 - 40.0, -34.0)
	holder.size = Vector2(80, 42)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(holder)

	var tone: Color = Color("ff6f5e") if prediction.lethal else Color("ffe6b8")
	holder.add_child(_label("−%d" % prediction.damage, 26, tone, HORIZONTAL_ALIGNMENT_CENTER))
	if prediction.lethal:
		holder.add_child(_label(t("ui.preview_lethal"), 11, Color("ff9c8c"), HORIZONTAL_ALIGNMENT_CENTER))
	elif prediction.blocked > 0:
		holder.add_child(_label(tf("ui.preview_blocked", prediction.blocked), 10, Color("9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER))

func _clear_damage_preview() -> void:
	if overlay == null: return
	var existing := overlay.get_node_or_null("DamagePreview")
	if existing: existing.queue_free()

func _shake_screen(intensity: float, duration := 0.24) -> void:
	if root == null: return
	var origin := root.position
	var shake := root.create_tween()
	var steps := 5
	for i in steps:
		var falloff: float = intensity * (1.0 - float(i) / float(steps))
		var offset := Vector2(randf_range(-falloff, falloff), randf_range(-falloff, falloff))
		shake.tween_property(root, "position", origin + offset, duration / float(steps))
	shake.tween_property(root, "position", origin, duration / float(steps))

func _set_enemy_targeted(enemy_index: int, targeted: bool) -> void:
	for box in enemy_boxes:
		if box and is_instance_valid(box) and int(box.get_meta("enemy_index")) == enemy_index:
			var glow: Control = box.get_node_or_null("TargetGlow")
			if glow:
				glow.modulate.a = 1.0 if targeted else 0.2
			var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
			if sprite:
				var base_scale: float = float(sprite.get_meta("base_scale", 1.0))
				sprite.scale = Vector2.ONE * base_scale * (1.08 if targeted else 1.0)

# Stays synchronous so callers get a real bool back; the animation runs in _resolve_play.
func _attempt_play_card(hand_index: int, target: int) -> bool:
	if combat == null or combat.state.phase != "player" or resolving: return false
	var before: Array = []
	for enemy in combat.state.enemies: before.append(int(enemy.health))
	if not combat.play(hand_index, target):
		_toast(t("ui.target_invalid"))
		return false
	resolving = true
	_resolve_play(before)
	return true

func _resolve_play(before: Array) -> void:
	for i in combat.state.enemies.size():
		if i < before.size() and before[i] > combat.state.enemies[i].health:
			await _animate_enemy_hit(i, before[i] - combat.state.enemies[i].health, combat.state.enemies[i].health <= 0)
	show_battle()
	await _maybe_end_turn()
	resolving = false

# There is no End Turn button, so the turn has to hand itself over: when the plays run out,
# and also when plays remain but nothing in hand is affordable, which would otherwise soft-lock.
func _maybe_end_turn() -> void:
	var guard := 0
	while combat != null and combat.state.phase == "player" and guard < 12:
		guard += 1
		var out_of_plays: bool = int(combat.state.actions) <= 0
		var nothing_playable := not _has_playable_card()
		if not out_of_plays and not nothing_playable: return
		if nothing_playable and not out_of_plays: _toast(t("ui.no_playable"))
		await get_tree().create_timer(0.28).timeout
		if combat == null or combat.state.phase != "player": return
		await _enemy_turn()

func _animate_enemy_hit(enemy_index: int, amount: int, defeated: bool) -> void:
	var box: Control = null
	for candidate in enemy_boxes:
		if candidate and is_instance_valid(candidate) and int(candidate.get_meta("enemy_index")) == enemy_index:
			box = candidate
			break
	if box == null: return

	var popup := _label("−%d" % amount, 34, Color("ff6f5e") if defeated else Color("fff4d3"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = box.global_position + Vector2(box.size.x / 2.0 - 40.0, 34.0)
	popup.size = Vector2(80, 40)
	popup.z_index = 200
	popup.pivot_offset = Vector2(40, 20)
	popup.scale = Vector2(0.5, 0.5)
	overlay.add_child(popup)
	var punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(popup, "scale", Vector2(1.2, 1.2), 0.14)
	punch.tween_property(popup, "scale", Vector2.ONE, 0.1)

	Input.vibrate_handheld(18 if not defeated else 45)
	_shake_screen(9.0 if defeated else clampf(float(amount) * 0.45, 2.5, 7.0))

	var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
	var tween := create_tween().set_parallel(true)
	if sprite:
		var orig_x := sprite.position.x
		var shake := create_tween()
		shake.tween_property(sprite, "position:x", orig_x - 8.0, 0.05)
		shake.tween_property(sprite, "position:x", orig_x + 8.0, 0.05)
		shake.tween_property(sprite, "position:x", orig_x, 0.06)
		shake.parallel().tween_property(sprite, "modulate", Color(2.0, 0.4, 0.4), 0.08)
		shake.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	tween.tween_property(popup, "position:y", popup.position.y - 45.0, 0.45)
	tween.tween_property(popup, "modulate:a", 0.0, 0.45)
	if defeated:
		tween.tween_property(box, "modulate:a", 0.0, 0.4)
		tween.tween_property(box, "scale", Vector2(0.4, 0.4), 0.4)
	await tween.finished
	popup.queue_free()

func _enemy_turn() -> void:
	for box in enemy_boxes:
		if box == null or not is_instance_valid(box): continue
		var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
		if sprite:
			var orig_y := sprite.position.y
			var tween := create_tween()
			tween.tween_property(sprite, "position:y", orig_y + 24.0, 0.12)
			tween.tween_property(sprite, "position:y", orig_y, 0.14)
			await tween.finished
	var before_health: int = combat.state.player.health
	combat.end_turn()
	if combat.state.player.health < before_health:
		Input.vibrate_handheld(35)
		await _animate_player_hit(before_health - combat.state.player.health)
	show_battle()

func _animate_player_hit(amount: int) -> void:
	var popup := _label("−%d" % amount, 38, Color("ff786a"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = Vector2(155, 480)
	popup.size = Vector2(80, 44)
	popup.z_index = 200
	popup.pivot_offset = Vector2(40, 22)
	popup.scale = Vector2(0.5, 0.5)
	overlay.add_child(popup)
	var punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(popup, "scale", Vector2(1.25, 1.25), 0.14)
	punch.tween_property(popup, "scale", Vector2.ONE, 0.1)
	_shake_screen(clampf(float(amount) * 0.7, 4.0, 12.0), 0.3)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 60.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	
	var player_node: Sprite2D = get_tree().root.find_child("PlayerSprite", true, false) as Sprite2D
	if player_node:
		var orig_x: float = player_node.position.x
		var shake := create_tween()
		shake.tween_property(player_node, "position:x", orig_x - 12.0, 0.05)
		shake.tween_property(player_node, "position:x", orig_x + 12.0, 0.05)
		shake.tween_property(player_node, "position:x", orig_x, 0.06)
		shake.parallel().tween_property(player_node, "modulate", Color(2.0, 0.4, 0.4), 0.08)
		shake.tween_property(player_node, "modulate", Color.WHITE, 0.12)
		
	await tween.finished
	popup.queue_free()

func _combat_event(kind: String, payload: Dictionary) -> void:
	if kind == "intent":
		var style := _intent_style({"kind": payload.kind, "amount": payload.amount})
		var tip: String = {"defend": "ui.intent_tip_defend", "empower": "ui.intent_tip_empower", "curse": "ui.intent_tip_curse"}.get(str(payload.kind), "")
		if not tip.is_empty(): _toast("%s %s" % [t(tip), style.text], style.border)
	elif kind == "player_burn": _toast("♨ −%d" % payload.amount, Color("ff9868"))
	elif kind == "revive": _toast(tf("ui.revive_toast", payload.amount),Color("9bffd3"))
	elif kind == "equipment":
		var item := content.equipment(payload.id); if not item.is_empty(): _toast("%s %s" % [item.icon, _equip_name(item)],GOLD)
	elif kind == "card" and not str(payload.rune).is_empty():
		var rune := content.rune(payload.rune); _toast("%s %s" % [rune.icon, _rune_name(rune)],Color(rune.color))

func _toast(message: String, color := TEXT) -> void:
	if overlay == null: return
	var toast := _label(message, 14, color, HORIZONTAL_ALIGNMENT_CENTER)
	toast.position = Vector2(65, 110); toast.size = Vector2(260, 40)
	toast.add_theme_stylebox_override("normal", _panel(Color("153d42"), 14, color))
	overlay.add_child(toast)
	var tween := create_tween(); tween.tween_property(toast,"position:y",86,.22); tween.tween_interval(.55); tween.tween_property(toast,"modulate:a",0.0,.25); tween.tween_callback(toast.queue_free)

func _leave_battle() -> void:
	if combat != null: profile.health = maxi(1,int(combat.state.player.health))
	SpiritSave.write(profile); show_map()

func show_reward() -> void:
	_clear(); _play_music(false)
	var page := _create_page(8)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_label(t("ui.battle_won"), 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var chest := TextureRect.new(); var atlas := AtlasTexture.new(); atlas.atlas = _texture("chest-atlas-v1.png"); atlas.region = Rect2(0,0,atlas.atlas.get_width()/2.0,atlas.atlas.get_height()); chest.texture = atlas; chest.custom_minimum_size = Vector2(200,160); chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; page.add_child(chest)
	var open := _button(t("ui.open_chest"), Callable(), EMBER, Vector2(210,48)); open.pressed.connect(func(): _open_chest(chest,atlas,page,open)); page.add_child(open)

func _open_chest(chest: TextureRect, atlas: AtlasTexture, page: VBoxContainer, button: Button) -> void:
	button.disabled = true; Input.vibrate_handheld(35)
	var tween := create_tween(); tween.tween_property(chest,"rotation",-.04,.08); tween.tween_property(chest,"rotation",.04,.08); tween.tween_property(chest,"rotation",0.0,.08); await tween.finished
	atlas.region.position.x = atlas.atlas.get_width()/2.0; chest.texture = atlas
	var encounter: Dictionary = content.encounters[current_stage]; var multiplier: float = active_modifier.get("reward_scale",1.0); if profile.equipment_slots.values().has("fortuneSeal"): multiplier *= 1.15
	var gold := int(round(encounter.reward*multiplier)); profile.gold += gold; profile.health = mini(60,int(combat.state.player.health)+10); profile.unlocked = maxi(int(profile.unlocked),mini(49,current_stage+1)); profile.position = current_stage
	page.add_child(_label(tf("ui.gold_reward", gold), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var kind := content.node_kind(current_stage)
	if kind == "boss":
		var order := ["emberBlade","jadePlate","soulPendant","moonStaff","thornArmor","tideCharm","stoneSpear","mistCloak","fortuneSeal","stormBow","phoenixMail","focusCharm"]
		var id: String = order[(current_stage/5+int(profile.difficulty)*2)%order.size()]; if not profile.equipment_owned.has(id): profile.equipment_owned.append(id)
		var item := content.equipment(id); page.add_child(_reward_item(tf("ui.boss_equip_title", [item.icon, _equip_name(item)]), _equip_detail(item), GOLD))
		# Clearing a chapter also grants that chapter's relic, which persists for the whole run.
		var relic: Dictionary = SpiritContent.RELICS[(current_stage / 5) % SpiritContent.RELICS.size()]
		if not profile.relics.has(relic.id):
			profile.relics.append(relic.id)
			page.add_child(_reward_item(tf("ui.relic_reward_title", [relic.icon, _relic_name(relic)]), _relic_detail(relic), Color(relic.color)))
	if kind == "elite":
		var rune: Dictionary = SpiritContent.RUNES[(current_stage/5+int(profile.difficulty))%SpiritContent.RUNES.size()]; profile.rune_inventory[rune.id] = profile.rune_inventory.get(rune.id,0)+1
		page.add_child(_reward_item(tf("ui.elite_rune_title", [rune.icon, _rune_name(rune)]), _rune_detail(rune), Color(rune.color)))
	var options: Array = content.cards.filter(func(card): return card.rarity != "Starter")
	page.add_child(_label(t("ui.choose_card"), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 10)
	for offset in 3:
		var card: Dictionary = options[(current_stage+offset)%options.size()]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 150)
		var btn_style := _panel(Color("0c1a1f"), 8, _card_color(card))
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", _panel(Color("162e36"), 8, GOLD))
		btn.add_theme_stylebox_override("pressed", _panel(Color("081014"), 8, EMBER))
		btn.pressed.connect(func(): _claim_card(card))
		
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_theme_constant_override("separation", 0)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(stack)
		
		var art_clip := PanelContainer.new()
		art_clip.clip_contents = true
		art_clip.custom_minimum_size = Vector2(110, 90)
		art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var clip_style := _panel(Color.TRANSPARENT, 8)
		clip_style.corner_radius_bottom_left = 0
		clip_style.corner_radius_bottom_right = 0
		art_clip.add_theme_stylebox_override("panel", clip_style)
		
		var art := TextureRect.new()
		art.texture = _get_card_texture(card.id)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_clip.add_child(art)
		stack.add_child(art_clip)
		
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_vertical = Control.SIZE_EXPAND_FILL
		texts.add_child(_label(content.text(card.nameKey, lang), 10, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var kind_txt := "%s %s" % [t("kind.%s" % card.get("kind", "Skill")), t("element.%s" % card.get("element", "spirit"))]
		texts.add_child(_label(kind_txt, 8, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(texts)
		
		choices.add_child(btn)
	page.add_child(choices)
	page.add_child(_button(t("ui.skip_card"), _finish_reward, Color("19383f"), Vector2(220,44)))
	SpiritSave.write(profile)

func _reward_item(title: String, detail: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(340,54); panel.add_theme_stylebox_override("panel",_panel(Color("193839"),12,color)); var stack := VBoxContainer.new(); panel.add_child(stack); stack.add_child(_label(title, 12, color, HORIZONTAL_ALIGNMENT_CENTER)); stack.add_child(_label(detail, 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)); return panel

func _claim_card(card: Dictionary) -> void:
	profile.collection[card.id] = profile.collection.get(card.id,0)+1
	var replace := -1
	for i in profile.deck.size():
		if content.card(profile.deck[i]).rarity == "Starter": replace = i; break
	if replace >= 0: profile.deck[replace] = card.id
	_finish_reward()

func _finish_reward() -> void:
	SpiritSave.write(profile); show_map()

func show_event(index: int, kind: String) -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(12)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: String
	if kind == "event": title = t("ui.event_traveler")
	elif kind == "merchant": title = t("ui.event_merchant")
	elif kind == "rest": title = t("ui.event_rest")
	else: title = t("ui.event_default")
	page.add_child(_label("✦", 48, GOLD, HORIZONTAL_ALIGNMENT_CENTER)); page.add_child(_label(title, 21, TEXT, HORIZONTAL_ALIGNMENT_CENTER)); page.add_child(_label(t("ui.event_prompt"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if kind == "event":
		page.add_child(_button(t("ui.event_opt_gold"), func(): profile.gold += 25; SpiritSave.write(profile); begin_battle(index), EMBER, Vector2(280,48)))
		page.add_child(_button(t("ui.event_opt_heal"), func(): profile.health = mini(60,profile.health+15); SpiritSave.write(profile); begin_battle(index), Color("21594e"), Vector2(280,48)))
	elif kind == "rest":
		page.add_child(_button(t("ui.event_opt_rest_heal"), func(): profile.health = mini(60,profile.health+12); SpiritSave.write(profile); begin_battle(index), Color("21594e"), Vector2(280,48)))
		page.add_child(_button(t("ui.event_opt_upgrade"), func(): profile.upgrades[profile.deck[0]]=1; SpiritSave.write(profile); begin_battle(index), EMBER, Vector2(280,48)))
	else:
		page.add_child(_button(t("ui.event_opt_potion"), func(): if profile.gold>=30: profile.gold-=30; profile.health=mini(60,profile.health+25); SpiritSave.write(profile); begin_battle(index), EMBER, Vector2(280,48)))
		page.add_child(_button(t("ui.event_opt_direct"), func(): begin_battle(index), Color("21594e"), Vector2(280,48)))
	page.add_child(_button(t("ui.return_map"), show_map, Color("17363e"), Vector2(170,42)))

func show_shop() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var backdrop := _background("lantern-marsh-v1.jpg", .18); root.add_child(backdrop); root.move_child(backdrop, 0)
	var page := _create_page(8)
	page.add_child(_header(t("ui.shop_title"), t("ui.shop_sub"), show_map))

	var potion := Button.new()
	potion.custom_minimum_size.y = 62
	potion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion.focus_mode = Control.FOCUS_NONE
	var affordable: bool = int(profile.gold) >= 30
	potion.add_theme_stylebox_override("normal", _panel(Color("1d4a40"), 12, JADE if affordable else Color("2a3d42")))
	potion.add_theme_stylebox_override("hover", _panel(Color("245a4d"), 12, JADE))
	potion.add_theme_stylebox_override("pressed", _panel(Color("163a32"), 12, GOLD))
	potion.pressed.connect(_buy_potion)
	page.add_child(potion)
	var potion_row := HBoxContainer.new()
	potion_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	potion_row.add_theme_constant_override("separation", 10)
	potion_row.alignment = BoxContainer.ALIGNMENT_CENTER
	potion_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion.add_child(potion_row)
	var potion_badge := CenterContainer.new()
	potion_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_badge.add_child(_icon_badge("✚", JADE, 38, 19))
	potion_row.add_child(potion_badge)
	var potion_texts := VBoxContainer.new()
	potion_texts.alignment = BoxContainer.ALIGNMENT_CENTER
	potion_texts.add_theme_constant_override("separation", 1)
	potion_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_row.add_child(potion_texts)
	potion_texts.add_child(_label(t("ui.shop_potion"), 12, TEXT))
	potion_texts.add_child(_label(tf("ui.shop_gold", 30), 11, GOLD))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	for card in content.cards:
		if card.rarity == "Starter": continue
		var price := 90 if card.rarity == "Rare" else 60 if card.rarity == "Uncommon" else 40
		grid.add_child(_shop_card_tile(card, price))

func _shop_card_tile(card: Dictionary, price: int) -> Control:
	var accent := _card_color(card)
	var can_afford: bool = int(profile.gold) >= price
	var owned: int = int(profile.collection.get(card.id, 0))

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(176, 218)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _panel(Color("11242a"), 12, accent if can_afford else Color("24373d")))
	btn.add_theme_stylebox_override("hover", _panel(Color("173038"), 12, GOLD))
	btn.add_theme_stylebox_override("pressed", _panel(Color("0c1c21"), 12, EMBER))
	btn.pressed.connect(func(): _buy_card(card, price))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pad)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(stack)

	var art_row := Control.new()
	art_row.custom_minimum_size = Vector2(164, 90)
	art_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(art_row)
	art_row.add_child(_card_art_panel(card.id, Vector2(164, 90)))
	var badge := _cost_badge(int(card.cost), accent)
	badge.position = Vector2(4, 4)
	art_row.add_child(badge)
	var rarity_lbl := _label(card.rarity, 8, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	rarity_lbl.position = Vector2(88, 70)
	rarity_lbl.size = Vector2(72, 16)
	rarity_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	rarity_lbl.add_theme_constant_override("shadow_offset_y", 1)
	art_row.add_child(rarity_lbl)

	stack.add_child(_label(content.text(card.nameKey, lang), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label("%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), t("element.%s" % card.get("element", "spirit"))], 9, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := _label(_card_description(card), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.custom_minimum_size.y = 30
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)
	stack.add_child(_label("%s %d" % [t("ui.deck_owned_short"), owned], 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var price_tag := Panel.new()
	price_tag.custom_minimum_size.y = 30
	price_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_tag.add_theme_stylebox_override("panel", _panel(Color("2f4a22") if can_afford else Color("3a2723"), 8, GOLD if can_afford else Color("6b4038")))
	stack.add_child(price_tag)
	var price_lbl := _label(tf("ui.shop_gold", price), 13, GOLD if can_afford else Color("c78b7f"), HORIZONTAL_ALIGNMENT_CENTER)
	price_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_tag.add_child(price_lbl)

	return btn

func _buy_potion() -> void:
	if int(profile.gold) < 30: _toast(t("ui.shop_no_gold")); return
	profile.gold -= 30
	profile.health = mini(60, int(profile.health) + 20)
	SpiritSave.write(profile)
	show_shop()

func _buy_card(card: Dictionary, price: int) -> void:
	if profile.gold < price: _toast(t("ui.shop_no_gold")); return
	profile.gold -= price
	profile.collection[card.id] = profile.collection.get(card.id, 0) + 1
	SpiritSave.write(profile)
	show_shop()
	_toast(tf("ui.shop_bought", content.text(card.nameKey, lang)), JADE)

func _card_art_panel(card_id: String, art_size: Vector2, radius := 8) -> Control:
	var clip := Panel.new()
	clip.custom_minimum_size = art_size
	clip.size = art_size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_theme_stylebox_override("panel", _panel(Color("07161a"), radius))
	var art := TextureRect.new()
	art.texture = _get_card_texture(card_id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(art)
	return clip

func _cost_badge(cost: int, accent: Color, diameter := 26) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.size = badge.custom_minimum_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _panel(accent, int(diameter / 2.0), Color("2b1a10")))
	var lbl := _label(str(cost), int(diameter * 0.6), Color("160b06"), HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	return badge

func show_deck() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(6)
	page.add_child(_header(t("ui.deck_title"), tf("ui.deck_sub", profile.deck.size()), show_map))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var shown := 0
	for card in content.cards:
		var owned := int(profile.collection.get(card.id, 0))
		if owned == 0: continue
		grid.add_child(_deck_card_tile(card, owned))
		shown += 1
	if shown == 0:
		grid.add_child(_label(t("ui.deck_need_cards"), 12, MUTED))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	page.add_child(footer)
	var auto_btn := _button(t("ui.deck_auto_build"), _auto_build_deck, Color("2f4c68"))
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_btn.custom_minimum_size = Vector2(0, 48)
	footer.add_child(auto_btn)
	var ready: bool = profile.deck.size() == 25
	var confirm := _button("%s %d/25" % [t("ui.deck_confirm"), profile.deck.size()], _confirm_deck, EMBER if ready else Color("34464b"))
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size = Vector2(0, 48)
	footer.add_child(confirm)

func _deck_card_tile(card: Dictionary, owned: int) -> Control:
	var in_deck: int = profile.deck.count(card.id)
	var accent := _card_color(card)
	var rune_id: String = profile.card_runes.get(card.id, "")

	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(176, 226)
	tile.add_theme_stylebox_override("panel", _panel(Color("11242a"), 12, accent if in_deck > 0 else Color("24373d")))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(pad)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	pad.add_child(stack)

	var art_row := Control.new()
	art_row.custom_minimum_size = Vector2(164, 88)
	art_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(art_row)
	var art := _card_art_panel(card.id, Vector2(164, 88))
	art_row.add_child(art)
	var badge := _cost_badge(int(card.cost), accent)
	badge.position = Vector2(4, 4)
	art_row.add_child(badge)
	if not rune_id.is_empty():
		var rune_info := content.rune(rune_id)
		var rune_lbl := _label(rune_info.icon, 15, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
		rune_lbl.position = Vector2(140, 4)
		rune_lbl.size = Vector2(20, 20)
		art_row.add_child(rune_lbl)

	var up_lvl: int = int(profile.upgrades.get(card.id, 0))
	stack.add_child(_label(content.text(card.nameKey, lang) + (" +" if up_lvl > 0 else ""), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label("%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), t("element.%s" % card.get("element", "spirit"))], 9, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var desc := _label(_card_description(card), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.custom_minimum_size.y = 32
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)

	var counts := _label("%s %d · %s %d" % [t("ui.deck_in_deck"), in_deck, t("ui.deck_owned_short"), owned], 9, JADE if in_deck > 0 else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(counts)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(controls)
	var minus := _button("−", func(): _deck_change(card.id, -1), Color("593b32"), Vector2(50, 34))
	minus.disabled = in_deck <= 0
	controls.add_child(minus)
	var plus := _button("+", func(): _deck_change(card.id, 1), Color("245247"), Vector2(50, 34))
	plus.disabled = in_deck >= owned or profile.deck.size() >= 25
	controls.add_child(plus)

	return tile

func _confirm_deck() -> void:
	if profile.deck.size() != 25:
		_toast(tf("ui.deck_sub", profile.deck.size()))
		return
	SpiritSave.write(profile)
	show_map()

func _deck_change(id: String, amount: int) -> void:
	if amount > 0:
		if profile.deck.size() >= 25: _toast(t("ui.deck_full")); return
		if profile.deck.count(id) >= int(profile.collection.get(id, 0)): return
		profile.deck.append(id)
	elif amount < 0 and profile.deck.has(id):
		profile.deck.erase(id)
	SpiritSave.write(profile)
	show_deck()

func _card_build_score(card: Dictionary) -> float:
	var score: float = {"Rare": 30.0, "Uncommon": 20.0, "Common": 12.0, "Starter": 5.0}.get(card.get("rarity", "Common"), 10.0)
	score += float(int(profile.upgrades.get(card.id, 0))) * 6.0
	# Prefer cheap cards slightly: with only two plays a turn, expensive cards stall the curve.
	score -= float(int(card.cost)) * 2.5
	if not str(profile.card_runes.get(card.id, "")).is_empty(): score += 8.0
	return score

func _auto_build_deck() -> void:
	var pool: Array = []
	for card in content.cards:
		for i in int(profile.collection.get(card.id, 0)): pool.append(card)
	if pool.size() < 25:
		_toast(t("ui.deck_need_cards"))
		return
	pool.sort_custom(func(a, b): return _card_build_score(a) > _card_build_score(b))

	# Aim for a playable curve rather than just the highest-rarity cards. Each pool entry is one
	# owned copy, so tracking consumed indices keeps the deck within what the collection holds.
	var picked: Array = []
	var used := {}
	var attacks := 0
	var defence := 0
	for i in pool.size():
		if picked.size() >= 25: break
		var card: Dictionary = pool[i]
		var kind: String = card.get("kind", "Skill")
		if kind == "Attack" and attacks >= 14: continue
		if kind in ["Skill", "Power"] and defence >= 9: continue
		picked.append(card.id)
		used[i] = true
		if kind == "Attack": attacks += 1
		elif kind in ["Skill", "Power"]: defence += 1
	for i in pool.size():
		if picked.size() >= 25: break
		if used.has(i): continue
		picked.append(pool[i].id)

	profile.deck = picked
	SpiritSave.write(profile)
	show_deck()
	_toast(t("ui.deck_auto_done"), JADE)

func _tab_bar(tabs: Array, active: String, on_pick: Callable) -> Control:
	var bar := Panel.new()
	bar.custom_minimum_size.y = 44
	bar.add_theme_stylebox_override("panel", _panel(Color("0c1a1f"), 22, Color("1f404d")))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)
	for entry in tabs:
		var id: String = entry[0]
		var is_active: bool = id == active
		var btn := Button.new()
		btn.text = entry[1]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 44
		btn.focus_mode = Control.FOCUS_NONE
		if font_cjk: btn.add_theme_font_override("font", font_cjk)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color("10242b") if is_active else MUTED)
		btn.add_theme_color_override("font_hover_color", Color("10242b") if is_active else TEXT)
		var active_style := _panel(JADE, 22)
		btn.add_theme_stylebox_override("normal", active_style if is_active else StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", active_style if is_active else _panel(Color(1, 1, 1, 0.06), 22))
		btn.add_theme_stylebox_override("pressed", _panel(JADE.darkened(0.1), 22) if is_active else _panel(Color(1, 1, 1, 0.1), 22))
		btn.pressed.connect(func(): on_pick.call(id))
		row.add_child(btn)
	return bar

func show_loadout() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(6)
	page.add_child(_header(t("ui.loadout_title"), t("ui.loadout_sub"), show_map))
	page.add_child(_tab_bar([["equipment", t("ui.tab_equipment")], ["runes", t("ui.tab_runes")]], loadout_tab, func(id): loadout_tab = id; show_loadout()))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if loadout_tab == "equipment": _build_equipment_tab(list)
	else: _build_rune_tab(list)

func _build_equipment_tab(list: VBoxContainer) -> void:
	list.add_child(_label(t("ui.loadout_cur_equip"), 13, JADE))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	list.add_child(slots)
	for slot in ["weapon", "armor", "charm"]:
		var item := content.equipment(profile.equipment_slots.get(slot, ""))
		var filled: bool = not item.is_empty()
		var card := Panel.new()
		card.custom_minimum_size = Vector2(0, 96)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _panel(Color("16333a") if filled else Color("101f24"), 12, GOLD if filled else Color("2a3d42")))
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 2)
		card.add_child(stack)
		var badge_row := HBoxContainer.new()
		badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_child(badge_row)
		badge_row.add_child(_icon_badge(item.icon if filled else "＋", GOLD if filled else Color("3c5057"), 38, 18))
		stack.add_child(_label(t("ui.slot_%s" % slot), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(_label(_equip_name(item) if filled else t("ui.loadout_empty"), 11, TEXT if filled else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		slots.add_child(card)

	list.add_child(_label(t("ui.loadout_collection"), 13, JADE))
	for item in SpiritContent.EQUIPMENT:
		var owned: bool = profile.equipment_owned.has(item.id)
		var equipped: bool = profile.equipment_slots.get(item.slot, "") == item.id
		var status_text := t("ui.loadout_unequip") if equipped else (t("ui.loadout_equip") if owned else t("ui.loadout_unobtained"))
		var accent: Color = JADE if equipped else (GOLD if owned else Color("3c5057"))

		var btn := Button.new()
		btn.custom_minimum_size.y = 72
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("normal", _panel(Color("15383a") if equipped else Color("13282e"), 12, accent))
		btn.add_theme_stylebox_override("hover", _panel(Color("1b4544") if equipped else Color("17333a"), 12, accent))
		btn.add_theme_stylebox_override("pressed", _panel(Color("102c2e"), 12, accent))
		btn.add_theme_stylebox_override("disabled", _panel(Color("0e191d"), 12, Color("243135")))
		btn.disabled = not owned
		btn.pressed.connect(func(): _equip(item))
		list.add_child(btn)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(row)

		var badge_holder := CenterContainer.new()
		badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_holder.add_child(_icon_badge(item.icon, accent, 44, 21))
		row.add_child(badge_holder)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 2)
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(texts)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 6)
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(title_row)
		title_row.add_child(_label(_equip_name(item), 13, TEXT if owned else MUTED))
		title_row.add_child(_label("· %s" % t("ui.slot_%s" % item.slot), 9, MUTED))
		var detail := _label(_equip_detail(item), 9, JADE if owned else Color("445559"), HORIZONTAL_ALIGNMENT_LEFT, true)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(detail)

		var status := _label(status_text, 10, accent, HORIZONTAL_ALIGNMENT_RIGHT)
		status.custom_minimum_size.x = 48
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(status)

func _build_rune_tab(list: VBoxContainer) -> void:
	list.add_child(_label(t("ui.loadout_runes_bag"), 13, JADE))
	list.add_child(_label(t("ui.rune_none_selected"), 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var bag := GridContainer.new()
	bag.columns = 5
	bag.add_theme_constant_override("h_separation", 6)
	bag.add_theme_constant_override("v_separation", 6)
	list.add_child(bag)
	for rune in SpiritContent.RUNES:
		var available: int = int(profile.rune_inventory.get(rune.id, 0)) - profile.card_runes.values().count(rune.id)
		var color := Color(rune.color)
		var is_selected: bool = selected_rune == rune.id
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(66, 74)
		btn.focus_mode = Control.FOCUS_NONE
		btn.disabled = available <= 0
		btn.add_theme_stylebox_override("normal", _panel(Color("173a40") if is_selected else Color("12262b"), 12, color if is_selected else Color("28393e")))
		btn.add_theme_stylebox_override("hover", _panel(Color("1b444b"), 12, color))
		btn.add_theme_stylebox_override("pressed", _panel(Color("102026"), 12, color))
		btn.add_theme_stylebox_override("disabled", _panel(Color("0e191d"), 12, Color("222e31")))
		btn.pressed.connect(func(): selected_rune = "" if is_selected else rune.id; show_loadout())
		bag.add_child(btn)

		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 1)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(stack)
		stack.add_child(_label(rune.icon, 20, color if available > 0 else Color("3c5057"), HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(_label(_rune_name(rune), 9, TEXT if available > 0 else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(_label("×%d" % maxi(0, available), 9, GOLD if available > 0 else MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if not selected_rune.is_empty():
		var chosen := content.rune(selected_rune)
		var hint := _label("%s %s · %s" % [chosen.icon, _rune_name(chosen), _rune_detail(chosen)], 10, Color(chosen.color), HORIZONTAL_ALIGNMENT_CENTER, true)
		list.add_child(hint)

	list.add_child(_label(t("ui.loadout_deck_runes"), 13, JADE))
	for id in _unique(profile.deck):
		var card := content.card(id)
		var installed: Dictionary = content.rune(profile.card_runes.get(id, ""))
		var has_rune: bool = not installed.is_empty()
		var accent: Color = Color(installed.color) if has_rune else Color("2a3d42")

		var row_panel := Panel.new()
		row_panel.custom_minimum_size.y = 58
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, accent))
		list.add_child(row_panel)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 8)
		row_panel.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		pad.add_child(row)

		var art_holder := CenterContainer.new()
		art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(_card_art_panel(id, Vector2(34, 46), 6))
		row.add_child(art_holder)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 1)
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(texts)
		texts.add_child(_label(content.text(card.nameKey, lang), 12, TEXT))
		texts.add_child(_label("%s %s" % [installed.icon, _rune_name(installed)] if has_rune else t("ui.loadout_unsocketed"), 10, accent if has_rune else MUTED))

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(actions)
		if has_rune:
			actions.add_child(_button(t("ui.loadout_remove"), func(): profile.card_runes.erase(id); SpiritSave.write(profile); show_loadout(), Color("593b32"), Vector2(52, 36)))
		else:
			var socket_btn := _button(t("ui.loadout_socket"), func(): _socket(id), Color("245247"), Vector2(52, 36))
			socket_btn.disabled = selected_rune.is_empty()
			actions.add_child(socket_btn)

func _equip(item: Dictionary) -> void:
	if profile.equipment_slots.get(item.slot,"") == item.id: profile.equipment_slots.erase(item.slot)
	else: profile.equipment_slots[item.slot] = item.id
	SpiritSave.write(profile); show_loadout()

func _socket(card_id: String) -> void:
	if selected_rune.is_empty(): _toast(t("ui.loadout_select_first")); return
	var available: int = int(profile.rune_inventory.get(selected_rune,0)) - profile.card_runes.values().count(selected_rune)
	if available <= 0: return
	profile.card_runes[card_id] = selected_rune; SpiritSave.write(profile); selected_rune=""; show_loadout()

func _account_panel() -> Control:
	var account: Dictionary = profile.get("account", {})
	var panel := Panel.new()
	panel.custom_minimum_size.y = 128
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, GOLD))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	pad.add_child(stack)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	stack.add_child(head)
	var holder := CenterContainer.new()
	holder.add_child(_icon_badge("☰", GOLD, 40, 18))
	head.add_child(holder)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 1)
	head.add_child(names)
	names.add_child(_label(str(account.get("name", "—")), 15, TEXT))
	names.add_child(_label(t("ui.account_local"), 9, JADE))
	var rename_btn := _button(t("ui.account_rename"), show_account_setup, Color("17363e"), Vector2(52, 34))
	rename_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rename_btn)

	var created: int = int(account.get("created_at", 0))
	var created_text := Time.get_datetime_string_from_unix_time(created).split("T")[0] if created > 0 else "—"
	stack.add_child(_label(tf("ui.account_created", created_text), 9, MUTED))
	stack.add_child(_label("%s · %s" % [t("ui.account_id"), str(account.get("id", "—")).substr(0, 13)], 9, MUTED))

	var cloud := _button(t("ui.account_cloud"), Callable(), Color("1a2f36"), Vector2(0, 38))
	cloud.disabled = true
	stack.add_child(cloud)
	stack.add_child(_label(t("ui.account_cloud_hint"), 8, Color("5e7278"), HORIZONTAL_ALIGNMENT_LEFT, true))
	return panel

func show_camp() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(8)
	page.add_child(_header(t("ui.camp_title"), t("ui.camp_sub"), show_map))
	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	list.add_child(_account_panel())
	list.add_child(_label(tf("ui.camp_tier", profile.difficulty), 17, JADE, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	for value in 6:
		var button := _button("A%d"%value, func(): profile.difficulty=value; SpiritSave.write(profile); show_camp(), Color("245247") if value==profile.difficulty else Color("17363e"), Vector2(0,40))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(button)
	list.add_child(row)
	list.add_child(_label(tf("ui.camp_relics", profile.relics.size()), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if profile.relics.is_empty():
		list.add_child(_label(t("ui.relic_none"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		for id in profile.relics:
			var relic := content.relic(id)
			if relic.is_empty(): continue
			var color := Color(relic.color)
			var row_panel := Panel.new()
			row_panel.custom_minimum_size.y = 56
			row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_panel.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, color))
			list.add_child(row_panel)
			var pad := MarginContainer.new()
			pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
			row_panel.add_child(pad)
			var relic_row := HBoxContainer.new()
			relic_row.add_theme_constant_override("separation", 10)
			pad.add_child(relic_row)
			var holder := CenterContainer.new()
			holder.add_child(_icon_badge(relic.icon, color, 38, 18))
			relic_row.add_child(holder)
			var texts := VBoxContainer.new()
			texts.alignment = BoxContainer.ALIGNMENT_CENTER
			texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texts.add_theme_constant_override("separation", 1)
			relic_row.add_child(texts)
			texts.add_child(_label(_relic_name(relic), 12, TEXT))
			texts.add_child(_label(_relic_detail(relic), 9, color, HORIZONTAL_ALIGNMENT_LEFT, true))
	list.add_child(_label(t("ui.camp_desc"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

func _toggle_music() -> void:
	muted = not muted
	if muted: map_music.stop(); battle_music.stop()
	else: _play_music(false)
	show_map()

func _unique(values: Array) -> Array:
	var result := []
	for value in values:
		if not result.has(value): result.append(value)
	return result

func _card_color(card: Dictionary) -> Color:
	return {"Attack":Color("d95d37"),"Skill":Color("50b99b"),"Power":Color("a75bd6"),"Tactic":Color("4d9dd6")}.get(card.get("kind","Skill"),JADE)

func _rune_color(id: String, fallback: Color) -> Color:
	var rune := content.rune(id); return fallback if rune.is_empty() else Color(rune.color)

func _card_description(card: Dictionary) -> String:
	var parts := []
	for effect in card.effects:
		match effect.operation:
			"damage": parts.append(content.ui("desc.damage", lang) % effect.amount)
			"shield": parts.append(content.ui("desc.shield", lang) % effect.amount)
			"heal": parts.append(content.ui("desc.heal", lang) % effect.amount)
			"draw": parts.append(content.ui("desc.draw", lang) % effect.amount)
			"status":
				var st_name: String
				if effect.status == "burn":
					st_name = content.ui("desc.burn", lang) % effect.amount
				else:
					st_name = content.ui("desc.focus", lang) % effect.amount
				parts.append(st_name)
	var sep := " · " if lang == "en" else "，"
	return sep.join(parts)
