extends Control
class_name IntroCutscene

signal completed

const DURATION := 10.0
var _elapsed: float = 0.0
var _finished: bool = false
var _callback: Callable = Callable()

var _bg: ColorRect
var _particles: CPUParticles2D
var _rune_circle: Control
var _shockwave: Control
var _hero_sprite: TextureRect
var _hero_aura: TextureRect
var _orbs_container: Control
var _title_box: VBoxContainer
var _title_label: Label
var _chinese_title_label: Label
var _sub_label: Label
var _act_label: Label
var _skip_btn: Button
var _fader: ColorRect
var _audio_player: AudioStreamPlayer
var _lang := "zh-Hans"

var _shockwave_radius: float = 0.0
var _shockwave_alpha: float = 0.0
var _rune_spin_speed: float = 0.5
var _rune_angle: float = 0.0
var _rune_alpha: float = 0.0
var _rune_scale: float = 0.6

func setup(lang_code: String = "zh-Hans", on_done: Callable = Callable()) -> void:
	_lang = lang_code
	_callback = on_done

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Deep Space Background
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color("04080c")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# 2. Spiritual Ember Particles
	_particles = CPUParticles2D.new()
	_particles.position = get_viewport_rect().size / 2.0
	_particles.amount = 45
	_particles.lifetime = 2.4
	_particles.speed_scale = 1.0
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 180.0
	_particles.gravity = Vector2(0, -25)
	_particles.spread = 180.0
	_particles.initial_velocity_min = 20.0
	_particles.initial_velocity_max = 60.0
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 5.0
	_particles.color = Color("83e4c1")
	add_child(_particles)

	# 3. Rotating Ancient Runic Circle
	_rune_circle = Control.new()
	_rune_circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rune_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rune_circle.draw.connect(_on_draw_rune_circle)
	add_child(_rune_circle)

	# 4. Hero Visual Anchor & Aura
	var vp_size := get_viewport_rect().size
	var center_pos := vp_size / 2.0 + Vector2(0, -30)

	_hero_aura = TextureRect.new()
	if ResourceLoader.exists("res://assets/characters/fox_rig/ground_aura.png"):
		_hero_aura.texture = load("res://assets/characters/fox_rig/ground_aura.png")
	_hero_aura.custom_minimum_size = Vector2(240, 240)
	_hero_aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_aura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_aura.position = center_pos - Vector2(120, 120)
	_hero_aura.modulate = Color(1, 1, 1, 0.0)
	_hero_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero_aura)

	_hero_sprite = TextureRect.new()
	var hero_path := "res://assets/characters/fox_rig/fox_body.png"
	if not ResourceLoader.exists(hero_path):
		hero_path = "res://assets/characters/hero_fox_spirit.png"
	if ResourceLoader.exists(hero_path):
		_hero_sprite.texture = load(hero_path)
	_hero_sprite.custom_minimum_size = Vector2(180, 180)
	_hero_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_sprite.position = center_pos - Vector2(90, 90)
	_hero_sprite.modulate = Color(1, 1, 1, 0.0)
	_hero_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero_sprite)

	# 5. Orbiting Spirit Orbs
	_orbs_container = Control.new()
	_orbs_container.position = center_pos
	_orbs_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orbs_container.modulate.a = 0.0
	_orbs_container.draw.connect(_on_draw_spirit_orbs)
	add_child(_orbs_container)

	# 6. Expanding Shockwave Ring
	_shockwave = Control.new()
	_shockwave.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shockwave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shockwave.draw.connect(_on_draw_shockwave)
	add_child(_shockwave)

	# 7. Act Captions (Center-Bottom)
	_act_label = Label.new()
	_act_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_act_label.offset_bottom = -140
	_act_label.offset_top = -200
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_act_label.add_theme_font_size_override("font_size", 16)
	_act_label.add_theme_color_override("font_color", Color("83e4c1"))
	var cjk_font: FontFile = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	if cjk_font != null:
		_act_label.add_theme_font_override("font", cjk_font)
	_act_label.modulate.a = 0.0
	_act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_act_label)

	# 8. Climax Title Card (Center)
	_title_box = VBoxContainer.new()
	_title_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_box.add_theme_constant_override("separation", 8)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.modulate.a = 0.0

	var cinzel_font: FontFile = load("res://assets/fonts/Cinzel-SemiBold.ttf")
	_title_label = Label.new()
	_title_label.text = "SPIRITBOUND"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color("dab56e"))
	if cinzel_font != null:
		_title_label.add_theme_font_override("font", cinzel_font)
	_title_box.add_child(_title_label)

	_chinese_title_label = Label.new()
	_chinese_title_label.text = "灵界之契"
	_chinese_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chinese_title_label.add_theme_font_size_override("font_size", 22)
	_chinese_title_label.add_theme_color_override("font_color", Color("f7f3e8"))
	if cjk_font != null:
		_chinese_title_label.add_theme_font_override("font", cjk_font)
	_title_box.add_child(_chinese_title_label)

	_sub_label = Label.new()
	_sub_label.text = "踏破轮回 · 重铸仙途" if _lang == "zh-Hans" else "Defy the cycles. Forge your legend."
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 13)
	_sub_label.add_theme_color_override("font_color", Color("83e4c1"))
	if cjk_font != null:
		_sub_label.add_theme_font_override("font", cjk_font)
	_title_box.add_child(_sub_label)

	add_child(_title_box)

	# 9. Top-Right Skip Button
	_skip_btn = Button.new()
	_skip_btn.name = "IntroSkipBtn"
	_skip_btn.text = "跳过 10s ⏭" if _lang == "zh-Hans" else "Skip 10s ⏭"
	_skip_btn.custom_minimum_size = Vector2(100, 36)
	_skip_btn.anchor_left = 1.0
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_top = 0.0
	_skip_btn.anchor_bottom = 0.0
	_skip_btn.offset_left = -116
	_skip_btn.offset_top = 48
	_skip_btn.offset_right = -16
	_skip_btn.offset_bottom = 84

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.12, 0.15, 0.8)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color("dab56e")
	_skip_btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color(0.1, 0.2, 0.25, 0.95)
	_skip_btn.add_theme_stylebox_override("hover", sb_hover)
	_skip_btn.add_theme_stylebox_override("pressed", sb_hover)
	_skip_btn.add_theme_color_override("font_color", Color("f7f3e8"))
	_skip_btn.add_theme_font_size_override("font_size", 12)
	if cjk_font != null:
		_skip_btn.add_theme_font_override("font", cjk_font)
	_skip_btn.pressed.connect(func(): _finish_intro(true))
	add_child(_skip_btn)

	# 10. Transition Fade Overlay
	_fader = ColorRect.new()
	_fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fader.color = Color(0, 0, 0, 1.0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fader)

	# Initial fade in from black (0.6s)
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 0.0, 0.6)

	# Audio Setup
	_audio_player = AudioStreamPlayer.new()
	var audio_path := "res://assets/audio/spirit-path-mobile.wav"
	if not ResourceLoader.exists(audio_path):
		audio_path = "res://assets/audio/spirit-path.wav"
	if ResourceLoader.exists(audio_path):
		_audio_player.stream = load(audio_path)
		_audio_player.volume_db = -4.0
		add_child(_audio_player)
		_audio_player.play()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		# Tap anywhere accelerates/highlights skip
		if _skip_btn != null:
			_skip_btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
			var tw := create_tween()
			tw.tween_property(_skip_btn, "modulate", Color.WHITE, 0.4)

func _process(delta: float) -> void:
	if _finished: return
	_elapsed += delta

	# Update countdown text
	var rem := int(ceil(maxf(0.0, DURATION - _elapsed)))
	if _skip_btn != null:
		if rem > 0:
			_skip_btn.text = ("跳过 %ds ⏭" if _lang == "zh-Hans" else "Skip %ds ⏭") % rem
		else:
			_skip_btn.text = "跳过 ⏭" if _lang == "zh-Hans" else "Skip ⏭"

	# Timeline State Machine
	if _elapsed < 2.5:
		_act_1_step(_elapsed / 2.5)
	elif _elapsed < 5.5:
		_act_2_step((_elapsed - 2.5) / 3.0)
	elif _elapsed < 8.0:
		_act_3_step((_elapsed - 5.5) / 2.5)
	elif _elapsed < 10.0:
		_act_4_step((_elapsed - 8.0) / 2.0)
	else:
		_finish_intro(false)

	# Rotate ancient rune array
	_rune_angle += _rune_spin_speed * delta
	if _rune_circle != null:
		_rune_circle.queue_redraw()
	if _orbs_container != null:
		_orbs_container.queue_redraw()
	if _shockwave != null and _shockwave_alpha > 0.001:
		_shockwave.queue_redraw()

# ------------------------------------------------------------------------------
# Act 1: 灵界初醒 · 混沌无序 (0s - 2.5s)
# ------------------------------------------------------------------------------
func _act_1_step(prog: float) -> void:
	if _act_label != null:
		_act_label.text = "混沌初开 · 万灵归虚" if _lang == "zh-Hans" else "From primordial chaos, spirits arose..."
		_act_label.modulate.a = sin(prog * PI)
	_rune_alpha = clampf(prog * 0.4, 0.0, 0.4)
	_rune_spin_speed = 0.4 + prog * 0.4
	if _particles != null:
		_particles.initial_velocity_min = 20.0 + prog * 30.0

# ------------------------------------------------------------------------------
# Act 2: 远古封印 · 灵潮涌动 (2.5s - 5.5s)
# ------------------------------------------------------------------------------
func _act_2_step(prog: float) -> void:
	if _act_label != null:
		_act_label.text = "远古封印 · 灵潮涌动" if _lang == "zh-Hans" else "Ancient seals shatter, mystical tides surge..."
		_act_label.modulate.a = sin(prog * PI)
	_rune_scale = 0.6 + prog * 0.4
	_rune_alpha = clampf(0.4 + prog * 0.6, 0.0, 1.0)
	_rune_spin_speed = 0.8 + prog * 2.5

	# At 80% through Act 2 (seal cracking burst)
	if prog > 0.8 and _shockwave_radius == 0.0:
		_trigger_seal_burst()

# ------------------------------------------------------------------------------
# Act 3: 灵狐降世 · 宿命抉择 (5.5s - 8.0s)
# ------------------------------------------------------------------------------
func _act_3_step(prog: float) -> void:
	if _act_label != null:
		_act_label.text = "灵狐降世 · 宿命抉择" if _lang == "zh-Hans" else "The Spirit Fox awakens to defy destiny..."
		_act_label.modulate.a = sin(prog * PI)
	if _hero_sprite != null:
		_hero_sprite.modulate.a = clampf(prog * 1.5, 0.0, 1.0)
		_hero_sprite.position.y = (get_viewport_rect().size.y / 2.0 - 120) + sin(prog * PI * 2.0) * 8.0
	if _hero_aura != null:
		_hero_aura.modulate.a = clampf(prog * 0.8, 0.0, 0.8)
	if _orbs_container != null:
		_orbs_container.modulate.a = clampf(prog * 1.2, 0.0, 1.0)
	if _particles != null:
		_particles.color = Color("ff9a4c").lerp(Color("dab56e"), prog)

# ------------------------------------------------------------------------------
# Act 4: 灵契缔结 · SPIRITBOUND (8.0s - 10.0s)
# ------------------------------------------------------------------------------
func _act_4_step(prog: float) -> void:
	if _act_label != null:
		_act_label.modulate.a = maxf(0.0, 1.0 - prog * 2.0)
	if _hero_sprite != null:
		_hero_sprite.modulate.a = maxf(0.1, 1.0 - prog * 0.8)
	if _hero_aura != null:
		_hero_aura.modulate.a = maxf(0.0, 0.8 - prog)
	if _orbs_container != null:
		_orbs_container.modulate.a = maxf(0.0, 1.0 - prog)
	if _title_box != null:
		_title_box.modulate.a = clampf(prog * 2.0, 0.0, 1.0)

func _trigger_seal_burst() -> void:
	_shockwave_radius = 20.0
	_shockwave_alpha = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_shockwave_radius", 320.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_shockwave_alpha", 0.0, 0.8)

func _on_draw_rune_circle() -> void:
	if _rune_circle == null or _rune_alpha < 0.01: return
	var center := get_viewport_rect().size / 2.0 + Vector2(0, -30)
	var radius := 140.0 * _rune_scale

	# Outer Glowing Ring
	_rune_circle.draw_arc(center, radius, 0, TAU, 64, Color(0.85, 0.71, 0.43, _rune_alpha * 0.7), 2.5)
	_rune_circle.draw_arc(center, radius * 0.75, 0, TAU, 48, Color(0.51, 0.89, 0.76, _rune_alpha * 0.5), 1.5)
	_rune_circle.draw_arc(center, radius * 0.5, 0, TAU, 32, Color(0.85, 0.71, 0.43, _rune_alpha * 0.4), 1.0)

	# 8 Cardinal Rune Nodes
	for i in range(8):
		var ang := _rune_angle + i * (TAU / 8.0)
		var pt := center + Vector2(cos(ang), sin(ang)) * radius
		_rune_circle.draw_circle(pt, 4.0, Color(1.0, 0.85, 0.5, _rune_alpha))
		var pt_inner := center + Vector2(cos(-ang * 1.5), sin(-ang * 1.5)) * (radius * 0.75)
		_rune_circle.draw_circle(pt_inner, 2.5, Color(0.51, 0.89, 0.76, _rune_alpha * 0.8))

func _on_draw_spirit_orbs() -> void:
	if _orbs_container == null or _orbs_container.modulate.a < 0.01: return
	var r := 90.0
	for i in range(3):
		var ang := _rune_angle * 1.5 + i * (TAU / 3.0)
		var orb_pt := Vector2(cos(ang), sin(ang)) * r
		_orbs_container.draw_circle(orb_pt, 7.0, Color(0.51, 0.89, 0.76, _orbs_container.modulate.a * 0.9))
		_orbs_container.draw_circle(orb_pt, 3.5, Color(1, 1, 1, _orbs_container.modulate.a))

func _on_draw_shockwave() -> void:
	if _shockwave == null or _shockwave_alpha < 0.01: return
	var center := get_viewport_rect().size / 2.0 + Vector2(0, -30)
	_shockwave.draw_arc(center, _shockwave_radius, 0, TAU, 48, Color(1.0, 0.95, 0.75, _shockwave_alpha), 4.0)

func _finish_intro(by_skip: bool = false) -> void:
	if _finished: return
	_finished = true
	set_process(false)

	# If skipped or in headless mode, complete immediately without waiting for tween
	if by_skip or DisplayServer.get_name() == "headless":
		if _audio_player != null:
			_audio_player.stop()
		completed.emit()
		if _callback.is_valid():
			_callback.call()
		queue_free()
		return

	# Smooth fade to black on natural timeline end in visual window mode
	if _fader != null:
		var tw := create_tween()
		tw.tween_property(_fader, "color:a", 1.0, 0.35)
		if _audio_player != null and _audio_player.playing:
			tw.parallel().tween_property(_audio_player, "volume_db", -40.0, 0.35)
		await tw.finished

	if _audio_player != null:
		_audio_player.stop()

	completed.emit()
	if _callback.is_valid():
		_callback.call()

	queue_free()
