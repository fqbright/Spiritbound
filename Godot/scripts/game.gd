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

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		pivot_offset = Vector2(custom_minimum_size.x / 2.0, custom_minimum_size.y)

	func _gui_input(event: InputEvent) -> void:
		if game == null or game.combat == null or game.combat.state.phase != "player": return

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

	func _on_touch_up() -> void:
		if not is_held: return
		is_held = false
		if game:
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
const MAP_POINTS = [Vector2(70,80), Vector2(270,165), Vector2(115,255), Vector2(275,345), Vector2(195,430)]
const BATTLE_BACKGROUNDS = ["battlefield-v1.jpg","lantern-marsh-v1.jpg","rune-ravine-v1.jpg","ember-cliff-v1.jpg","mountain-forge-v1.jpg"]

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
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	overlay = Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.z_index = 500; root.add_child(overlay)

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
	var backdrop := _background("spirit-world-map-v1.jpg",.3); root.add_child(backdrop); root.move_child(backdrop,0)
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

	map_canvas = Control.new(); map_canvas.custom_minimum_size = Vector2(366,5000); map_scroll.add_child(map_canvas)
	for chapter in 10: _add_map_chapter(chapter)
	_add_routes()
	for index in 50: _add_stage_pin(index)

	traveler = Sprite2D.new()
	traveler.texture = _get_character_texture("fox")
	traveler.scale = Vector2(40.0 / 341.33, 40.0 / 341.33)
	traveler.position = _map_point(profile.position) - Vector2(0, 26)
	traveler.z_index = 25
	map_canvas.add_child(traveler)

	var t_idle := create_tween().set_loops()
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
	return Vector2(100.0 + (index % 2) * 160.0, 100.0 + index * 80.0)

func _add_map_chapter(chapter: int) -> void:
	var c_lbl := _label(tf("ui.chapter_title", chapter + 1), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	c_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	c_lbl.add_theme_constant_override("shadow_offset_y", 2)
	c_lbl.add_theme_constant_override("shadow_outline_size", 4)
	c_lbl.position = Vector2(0, chapter * 400.0 + 160.0)
	c_lbl.size = Vector2(366.0, 80.0)
	map_canvas.add_child(c_lbl)

func _add_routes() -> void:
	var line := Line2D.new(); line.width = 5; line.default_color = Color(1.0, 0.84, 0.48, 0.65); line.z_index = 2
	for index in 50: line.add_point(_map_point(index))
	map_canvas.add_child(line)

func _add_stage_pin(index: int) -> void:
	var encounter: Dictionary = content.encounters[index]
	var point := _map_point(index)
	var locked := index > int(profile.unlocked)
	var is_current := index == int(profile.position)
	var is_boss: bool = (index + 1) % 5 == 0

	var pin_size := Vector2(56, 44)
	var pin_text := "%d-%d" % [encounter.chapter, encounter.level] if not locked else "◇"
	var bg_color := Color("23584d")
	var border_color := GOLD if is_boss else JADE
	if locked:
		bg_color = Color("1b2d31")
		border_color = Color("384a4f")
	elif is_current:
		bg_color = Color("8c542a")
		border_color = EMBER

	var pin := Button.new()
	pin.text = ("★ " if is_boss and not locked else "") + pin_text
	pin.custom_minimum_size = pin_size
	pin.size = pin_size
	pin.position = point - pin_size / 2.0
	pin.disabled = locked
	pin.z_index = 10
	if font_cjk: pin.add_theme_font_override("font", font_cjk)
	pin.add_theme_font_size_override("font_size", 12)
	pin.add_theme_color_override("font_color", TEXT if not locked else MUTED)
	pin.add_theme_stylebox_override("normal", _panel(bg_color, 12, border_color))
	pin.add_theme_stylebox_override("hover", _panel(bg_color.lightened(0.1), 12, EMBER))
	pin.add_theme_stylebox_override("pressed", _panel(bg_color.darkened(0.15), 12, GOLD))
	pin.add_theme_stylebox_override("disabled", _panel(bg_color, 12, Color("283538")))
	pin.pressed.connect(func(): _travel_to(index))
	map_canvas.add_child(pin)

	var name := _label(content.stage_name(index, lang), 10, TEXT if not locked else MUTED)
	name.position = point + Vector2(34 if point.x < 185 else -136, -10)
	name.size = Vector2(100, 20)
	map_canvas.add_child(name)

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
	combat.create(seed,content.encounters[index],profile.deck,int(profile.health),profile.upgrades,equipped,profile.card_runes,active_modifier)
	combat.event.connect(_combat_event)
	show_battle()

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

	if not combat.state.equipment.is_empty():
		var gear := HBoxContainer.new(); gear.alignment = BoxContainer.ALIGNMENT_CENTER
		for id in combat.state.equipment:
			var item := content.equipment(id); gear.add_child(_label("%s %s" % [item.icon, _equip_name(item)], 9, GOLD))
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

	var idle := create_tween().set_loops()
	idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
	idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)

	var intent: int = int(enemy.damage) + (int(enemy.mechanics.get("below_half", 0)) if enemy.health <= enemy.max_health / 2 else 0)
	var critical: bool = enemy.mechanics.get("critical_every", 0) > 0 and (enemy.attacks + 1) % enemy.mechanics.critical_every == 0
	var intent_bg := PanelContainer.new()
	intent_bg.custom_minimum_size = Vector2(56.0, 22.0)
	intent_bg.size = intent_bg.custom_minimum_size
	intent_bg.position = Vector2(center_x - 28.0, 2.0)
	intent_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_bg.add_theme_stylebox_override("panel", _panel(Color("8c2f19") if critical else Color(0.29, 0.11, 0.07, 0.92), 11, Color("e39761")))
	var intent_lbl := _label(tf("ui.crit_intent", intent * 2) if critical else tf("ui.attack_intent", intent), 10, Color("ffe1c9"), HORIZONTAL_ALIGNMENT_CENTER)
	intent_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var hp_bg := PanelContainer.new()
	hp_bg.name = "HealthBar"
	hp_bg.custom_minimum_size = Vector2(hp_bar_w, 16.0)
	hp_bg.size = hp_bg.custom_minimum_size
	hp_bg.position = Vector2(6.0, 148.0)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_theme_stylebox_override("panel", _panel(Color(0.02, 0.06, 0.08, 0.78), 8))
	unit.add_child(hp_bg)

	var hp_ratio: float = clampf(float(enemy.health) / maxf(1.0, float(enemy.max_health)), 0.0, 1.0)
	var hp_fill := ColorRect.new()
	hp_fill.color = Color(enemy.get("tint", "83e4c1"))
	hp_fill.size = Vector2(hp_bar_w * hp_ratio, 16.0)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(hp_fill)

	var hp_text := "♥ %d/%d" % [enemy.health, enemy.max_health]
	if enemy.shield > 0:
		hp_text += " ◆%d" % enemy.shield
	var hp_lbl := _label(hp_text, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	hp_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bg.add_child(hp_lbl)

	return unit

func _build_player_stage() -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(366.0, 100.0)
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

	var idle := create_tween().set_loops()
	idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
	idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)

	var hp_bg := PanelContainer.new()
	hp_bg.custom_minimum_size = Vector2(146.0, 18.0)
	hp_bg.size = hp_bg.custom_minimum_size
	hp_bg.position = Vector2(center_x - 73.0, 78.0)
	hp_bg.add_theme_stylebox_override("panel", _panel(Color(0.02, 0.06, 0.08, 0.8), 9))
	stage.add_child(hp_bg)

	var p_ratio: float = clampf(float(combat.state.player.health) / 60.0, 0.0, 1.0)
	var p_fill := ColorRect.new()
	p_fill.color = EMBER
	p_fill.size = Vector2(146.0 * p_ratio, 18.0)
	hp_bg.add_child(p_fill)

	var p_text := "%s  ♥ %d/60" % [t("ui.spirit_name"), combat.state.player.health]
	if combat.state.player.shield > 0:
		p_text += " ◆%d" % combat.state.player.shield
	var p_lbl := _label(p_text, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	p_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bg.add_child(p_lbl)

	return stage

func _add_hand(page: VBoxContainer) -> void:
	var hint := _label(t("ui.drag_hint"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	page.add_child(hint)

	var hand_zone := Control.new()
	hand_zone.custom_minimum_size = Vector2(366.0, 184.0)
	hand_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(hand_zone)

	var draw_pile := PanelContainer.new()
	draw_pile.custom_minimum_size = Vector2(50, 64)
	draw_pile.position = Vector2(10.0, 100.0)
	draw_pile.add_theme_stylebox_override("panel", _panel(Color("0c1a1f"), 6, Color("1f404d")))
	var draw_stack := VBoxContainer.new()
	draw_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	draw_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_stack.add_child(_label("%d" % combat.state.draw.size(), 20, Color("f3e8cf"), HORIZONTAL_ALIGNMENT_CENTER))
	draw_stack.add_child(_label(t("ui.draw_pile"), 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	draw_pile.add_child(draw_stack)
	hand_zone.add_child(draw_pile)

	var discard_pile := PanelContainer.new()
	discard_pile.custom_minimum_size = Vector2(50, 64)
	discard_pile.position = Vector2(306.0, 100.0)
	discard_pile.add_theme_stylebox_override("panel", _panel(Color("0c1a1f"), 6, Color("1f404d")))
	var discard_stack := VBoxContainer.new()
	discard_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	discard_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	discard_stack.add_child(_label("%d" % combat.state.discard.size(), 20, Color("a8b2b5"), HORIZONTAL_ALIGNMENT_CENTER))
	discard_stack.add_child(_label(t("ui.discard_pile"), 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	discard_pile.add_child(discard_stack)
	hand_zone.add_child(discard_pile)

	var orb := PanelContainer.new()
	orb.custom_minimum_size = Vector2(54.0, 54.0)
	orb.position = Vector2(8.0, 24.0)
	orb.add_theme_stylebox_override("panel", _panel(Color("003140"), 27, Color("4dc5e8")))
	
	var orb_stack := VBoxContainer.new()
	orb_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	orb_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orb_stack.add_child(_label(str(combat.state.actions), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var e_lbl := _label("⚡%d" % combat.state.energy, 9, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	orb_stack.add_child(e_lbl)
	orb.add_child(orb_stack)
	hand_zone.add_child(orb)

	var count: int = combat.state.hand.size()
	for index in count:
		var card_tile := _card_view(combat.state.hand[index], index, count)
		hand_zone.add_child(card_tile)

	var end_turn := _button(t("ui.end_turn"), _request_end_turn, Color("17363e"), Vector2(132, 36))
	end_turn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(end_turn)

func _tap_card(hand_index: int) -> void:
	if combat == null or combat.state.phase != "player": return
	_attempt_play_card(hand_index, -1)

func _request_end_turn() -> void:
	if combat == null or combat.state.phase != "player": return
	await _enemy_turn()

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

func _set_enemy_targeted(enemy_index: int, targeted: bool) -> void:
	for box in enemy_boxes:
		if box and is_instance_valid(box) and int(box.get_meta("enemy_index")) == enemy_index:
			var glow: Control = box.get_node_or_null("TargetGlow")
			if glow:
				glow.modulate.a = 1.0 if targeted else 0.2
			var sprite: Control = box.get_node_or_null("MonsterSprite")
			if sprite:
				var base_scale: float = float(sprite.get_meta("base_scale", 1.0))
				sprite.scale = Vector2.ONE * base_scale * (1.08 if targeted else 1.0)

func _attempt_play_card(hand_index: int, target: int) -> bool:
	if combat == null or combat.state.phase != "player": return false
	var before: Array = []
	for enemy in combat.state.enemies: before.append(enemy.health)
	if not combat.play(hand_index, target):
		_toast(t("ui.target_invalid"))
		return false

	for i in combat.state.enemies.size():
		if before[i] > combat.state.enemies[i].health:
			await _animate_enemy_hit(i, before[i] - combat.state.enemies[i].health, combat.state.enemies[i].health <= 0)
	show_battle()
	if combat.state.phase == "player" and combat.state.actions <= 0:
		await get_tree().create_timer(0.3).timeout
		await _enemy_turn()
	return true

func _animate_enemy_hit(enemy_index: int, amount: int, defeated: bool) -> void:
	var box: Control = null
	for candidate in enemy_boxes:
		if candidate and is_instance_valid(candidate) and int(candidate.get_meta("enemy_index")) == enemy_index:
			box = candidate
			break
	if box == null: return

	var popup := _label("−%d" % amount, 32, Color("fff4d3"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = box.global_position + Vector2(20, 40)
	popup.z_index = 200
	overlay.add_child(popup)

	var sprite: Control = box.get_node_or_null("MonsterSprite")
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
		var sprite: Control = box.get_node_or_null("MonsterSprite")
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
	var popup := _label("−%d" % amount, 36, Color("ff786a"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = Vector2(160, 480)
	popup.z_index = 200
	overlay.add_child(popup)
	
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
	if kind == "revive": _toast(tf("ui.revive_toast", payload.amount),Color("9bffd3"))
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
	var page := _create_page(6)
	page.add_child(_header(t("ui.shop_title"), t("ui.shop_sub"), show_map))
	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 6); scroll.add_child(list)
	list.add_child(_button(t("ui.shop_potion"), func(): if profile.gold>=30: profile.gold-=30; profile.health=mini(60,profile.health+20); SpiritSave.write(profile); show_shop(), Color("245247"), Vector2(0,52)))
	for card in content.cards:
		if card.rarity == "Starter": continue
		var price := 90 if card.rarity == "Rare" else 60 if card.rarity == "Uncommon" else 40
		
		var btn := Button.new()
		btn.custom_minimum_size.y = 56
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", _panel(Color("17363e"), 8))
		btn.add_theme_stylebox_override("hover", _panel(Color("1c444e"), 8))
		btn.add_theme_stylebox_override("pressed", _panel(Color("11282e"), 8))
		btn.pressed.connect(func(): _buy_card(card, price))
		
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(row)
		
		var art := TextureRect.new()
		art.texture = _get_card_texture(card.id)
		art.custom_minimum_size = Vector2(36, 56)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var clip := PanelContainer.new()
		clip.clip_contents = true
		clip.custom_minimum_size = Vector2(36, 56)
		clip.add_theme_stylebox_override("panel", _panel(Color.TRANSPARENT, 4))
		clip.add_child(art)
		row.add_child(clip)
		
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(_label(content.text(card.nameKey, lang), 12, TEXT))
		texts.add_child(_label("◆ %d    ( %s: %d )" % [price, "拥有" if lang == "zh-Hans" else "Owned", int(profile.collection.get(card.id,0))], 9, GOLD))
		row.add_child(texts)
		
		list.add_child(btn)

func _buy_card(card: Dictionary, price: int) -> void:
	if profile.gold < price: _toast(t("ui.shop_no_gold")); return
	profile.gold -= price; profile.collection[card.id] = profile.collection.get(card.id,0)+1; SpiritSave.write(profile); show_shop()

func show_deck() -> void:
	_clear(); _play_music(false)
	var page := _create_page(6)
	page.add_child(_header(t("ui.deck_title"), tf("ui.deck_sub", profile.deck.size()), show_map))
	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 6); scroll.add_child(list)
	for card in content.cards:
		var owned := int(profile.collection.get(card.id,0)); if owned == 0: continue
		var used: int = profile.deck.count(card.id); var row := HBoxContainer.new()
		
		var art := TextureRect.new()
		art.texture = _get_card_texture(card.id)
		art.custom_minimum_size = Vector2(32, 48)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var clip := PanelContainer.new()
		clip.clip_contents = true
		clip.custom_minimum_size = Vector2(32, 48)
		clip.add_theme_stylebox_override("panel", _panel(Color.TRANSPARENT, 4))
		clip.add_child(art)
		row.add_child(clip)
		
		var name := _label(tf("ui.deck_owned_fmt", [content.text(card.nameKey, lang), owned]), 11, TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(name)
		row.add_child(_button("−", func(): _deck_change(card.id,-1), Color("593b32"), Vector2(36,36)))
		row.add_child(_label(str(used), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(_button("+", func(): _deck_change(card.id,1), Color("245247"), Vector2(36,36)))
		list.add_child(row)
	page.add_child(_button(tf("ui.deck_confirm_fmt", profile.deck.size()), func(): if profile.deck.size()==25: SpiritSave.write(profile); show_map(), EMBER, Vector2(0,48)))

func _deck_change(id: String, amount: int) -> void:
	if amount > 0 and profile.deck.size() < 25 and profile.deck.count(id) < int(profile.collection.get(id,0)): profile.deck.append(id)
	elif amount < 0 and profile.deck.has(id): profile.deck.erase(id)
	show_deck()

func show_loadout() -> void:
	_clear(); _play_music(false)
	var page := _create_page(6)
	page.add_child(_header(t("ui.loadout_title"), t("ui.loadout_sub"), show_map))
	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",6); scroll.add_child(list)
	list.add_child(_label(t("ui.loadout_cur_equip"), 14, JADE))
	var slots := HBoxContainer.new(); slots.add_theme_constant_override("separation", 8)
	for slot in ["weapon","armor","charm"]:
		var item := content.equipment(profile.equipment_slots.get(slot,""))
		slots.add_child(_label("%s\n%s" % [slot, _equip_name(item) if not item.is_empty() else t("ui.loadout_empty")], 9, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	list.add_child(slots); list.add_child(_label(t("ui.loadout_collection"), 14, JADE))
	for item in SpiritContent.EQUIPMENT:
		var owned: bool = profile.equipment_owned.has(item.id); var equipped: bool = profile.equipment_slots.get(item.slot,"") == item.id
		var status_text := t("ui.loadout_unequip") if equipped else (t("ui.loadout_equip") if owned else t("ui.loadout_unobtained"))
		
		var btn := Button.new()
		btn.custom_minimum_size.y = 60
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", _panel(Color("245247") if equipped else Color("17363e"), 8))
		btn.add_theme_stylebox_override("hover", _panel(Color("2d6356") if equipped else Color("1c444e"), 8))
		btn.add_theme_stylebox_override("pressed", _panel(Color("1b4037") if equipped else Color("11282e"), 8))
		btn.add_theme_stylebox_override("disabled", _panel(Color("101a1d"), 8))
		btn.disabled = not owned
		btn.pressed.connect(func(): _equip(item))
		
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(row)
		
		var icon_lbl := _label(item.icon, 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		icon_lbl.custom_minimum_size = Vector2(60, 60)
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(icon_lbl)
		
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(_label("%s · %s" % [_equip_name(item), status_text], 12, TEXT if owned else MUTED))
		texts.add_child(_label(_equip_detail(item), 9, JADE if owned else Color("384a4f")))
		row.add_child(texts)
		
		list.add_child(btn)
	list.add_child(_label(t("ui.loadout_runes_bag"), 14, JADE)); var runes_row := HBoxContainer.new(); runes_row.add_theme_constant_override("separation", 4)
	for rune in SpiritContent.RUNES:
		var available: int = int(profile.rune_inventory.get(rune.id,0)) - profile.card_runes.values().count(rune.id)
		var button := _button("%s %s ×%d" % [rune.icon, _rune_name(rune), maxi(0,available)], func(): selected_rune=rune.id; show_loadout(), Color("24444b") if selected_rune==rune.id else Color("17363e"), Vector2(0,44))
		button.disabled = available <= 0; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; runes_row.add_child(button)
	list.add_child(runes_row); list.add_child(_label(t("ui.loadout_deck_runes"), 14, JADE))
	for id in _unique(profile.deck):
		var card := content.card(id); var installed: Dictionary = content.rune(profile.card_runes.get(id,"")); var r_name := _rune_name(installed) if not installed.is_empty() else t("ui.loadout_unsocketed")
		var row := HBoxContainer.new(); var copy := _label("%s\n%s" % [content.text(card.nameKey, lang), r_name], 10, TEXT)
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(copy)
		row.add_child(_button(t("ui.loadout_remove"), func(): profile.card_runes.erase(id); SpiritSave.write(profile); show_loadout(), Color("593b32"), Vector2(48,34)))
		row.add_child(_button(t("ui.loadout_socket"), func(): _socket(id), Color("245247"), Vector2(52,34)))
		list.add_child(row)

func _equip(item: Dictionary) -> void:
	if profile.equipment_slots.get(item.slot,"") == item.id: profile.equipment_slots.erase(item.slot)
	else: profile.equipment_slots[item.slot] = item.id
	SpiritSave.write(profile); show_loadout()

func _socket(card_id: String) -> void:
	if selected_rune.is_empty(): _toast(t("ui.loadout_select_first")); return
	var available: int = int(profile.rune_inventory.get(selected_rune,0)) - profile.card_runes.values().count(selected_rune)
	if available <= 0: return
	profile.card_runes[card_id] = selected_rune; SpiritSave.write(profile); selected_rune=""; show_loadout()

func show_camp() -> void:
	_clear(); _play_music(false)
	var page := _create_page(8)
	page.add_child(_header(t("ui.camp_title"), t("ui.camp_sub"), show_map))
	var list := VBoxContainer.new(); list.size_flags_vertical = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 10); page.add_child(list)
	list.add_child(_label(tf("ui.camp_tier", profile.difficulty), 17, JADE, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	for value in 6:
		var button := _button("A%d"%value, func(): profile.difficulty=value; SpiritSave.write(profile); show_camp(), Color("245247") if value==profile.difficulty else Color("17363e"), Vector2(0,40))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(button)
	list.add_child(row)
	list.add_child(_label(tf("ui.camp_relics", profile.relics.size()), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
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
