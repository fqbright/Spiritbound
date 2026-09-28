extends Control
class_name IntroCutscene

signal completed

const DURATION := 20.0
var _elapsed: float = 0.0
var _finished: bool = false
var _callback: Callable = Callable()

var _bg: ColorRect
var _video_player: VideoStreamPlayer
var _act_label: Label
var _skip_btn: Button
var _fader: ColorRect
var _audio_player: AudioStreamPlayer
var _lang := "zh-Hans"

func setup(lang_code: String = "zh-Hans", on_done: Callable = Callable()) -> void:
	_lang = lang_code
	_callback = on_done

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Deep Space Fallback Background
	_bg = ColorRect.new()
	_bg.name = "IntroBackground"
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color("04080c")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# 2. 20-Second Cinematic Video Stream Player (Card Art Style)
	_video_player = VideoStreamPlayer.new()
	_video_player.name = "IntroVideoPlayer"
	_video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video_player.expand = true
	_video_player.loop = false
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep video audio muted in the video stream and play the pristine uncompressed audio via AudioStreamPlayer
	_video_player.volume_db = -80.0
	
	var video_path := "res://assets/video/intro_cutscene.ogv"
	if ResourceLoader.exists(video_path):
		var stream := VideoStreamTheora.new()
		stream.file = video_path
		_video_player.stream = stream
		_video_player.autoplay = true
		_video_player.finished.connect(func(): _finish_intro(false))
	add_child(_video_player)

	# Start video playback
	if _video_player.stream != null:
		_video_player.play()

	# 3. Cinematic Subtitle Narrative Caption (Bottom Center)
	_act_label = Label.new()
	_act_label.name = "IntroActLabel"
	_act_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_act_label.offset_bottom = -130
	_act_label.offset_top = -190
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_act_label.add_theme_font_size_override("font_size", 16)
	_act_label.add_theme_color_override("font_color", Color("83e4c1"))
	_act_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_act_label.add_theme_constant_override("shadow_offset_x", 1)
	_act_label.add_theme_constant_override("shadow_offset_y", 2)
	var cjk_font: FontFile = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	if cjk_font != null:
		_act_label.add_theme_font_override("font", cjk_font)
	_act_label.modulate.a = 0.0
	_act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_act_label)

	# 4. Top-Right Skip Button with Countdown
	_skip_btn = Button.new()
	_skip_btn.name = "IntroSkipBtn"
	_skip_btn.text = "跳过 20s ⏭" if _lang == "zh-Hans" else "Skip 20s ⏭"
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

	# 5. Transition Fade Overlay
	_fader = ColorRect.new()
	_fader.name = "IntroFader"
	_fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fader.color = Color(0, 0, 0, 1.0)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fader)

	# Initial fade in from black (0.6s)
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 0.0, 0.6)

	# 6. High-Fidelity Orchestral Soundtrack
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "IntroAudioPlayer"
	var audio_path := "res://assets/audio/spirit-path-mobile.wav"
	if not ResourceLoader.exists(audio_path):
		audio_path = "res://assets/audio/spirit-path-v2.wav"
	if ResourceLoader.exists(audio_path):
		_audio_player.stream = load(audio_path)
		_audio_player.volume_db = -3.0
		add_child(_audio_player)
		_audio_player.play()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		# Tap anywhere accelerates/highlights skip button
		if _skip_btn != null:
			_skip_btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
			var tw := create_tween()
			tw.tween_property(_skip_btn, "modulate", Color.WHITE, 0.4)

func _process(delta: float) -> void:
	if _finished: return
	_elapsed += delta

	# Update countdown text on skip button
	var rem := int(ceil(maxf(0.0, DURATION - _elapsed)))
	if _skip_btn != null:
		if rem > 0:
			_skip_btn.text = ("跳过 %ds ⏭" if _lang == "zh-Hans" else "Skip %ds ⏭") % rem
		else:
			_skip_btn.text = "跳过 ⏭" if _lang == "zh-Hans" else "Skip ⏭"

	# Four-Act Cinematic Timeline Subtitles (20-second progression)
	if _elapsed < 5.0:
		_act_step("混沌初开 · 万灵归虚" if _lang == "zh-Hans" else "From primordial chaos, mystical essence awakens...", _elapsed / 5.0)
	elif _elapsed < 10.0:
		_act_step("五行流转 · 万法争鸣" if _lang == "zh-Hans" else "The five elemental forces surge across heaven and earth...", (_elapsed - 5.0) / 5.0)
	elif _elapsed < 15.0:
		_act_step("灵狐降世 · 宿命抉择" if _lang == "zh-Hans" else "The Spirit Fox awakens to defy destiny...", (_elapsed - 10.0) / 5.0)
	elif _elapsed < 19.5:
		_act_step("灵契缔结 · 踏破轮回" if _lang == "zh-Hans" else "A spirit pact is forged to break the cycle of samsara...", (_elapsed - 15.0) / 4.5)
	else:
		_finish_intro(false)

func _act_step(caption: String, prog: float) -> void:
	if _act_label == null: return
	_act_label.text = caption
	# Smooth sin arc for fade-in, sustain, and fade-out of subtitles
	_act_label.modulate.a = sin(clampf(prog, 0.0, 1.0) * PI)

func _finish_intro(by_skip: bool = false) -> void:
	if _finished: return
	_finished = true
	set_process(false)

	# Stop video playback
	if _video_player != null:
		_video_player.stop()

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
		tw.tween_property(_fader, "color:a", 1.0, 0.4)
		if _audio_player != null and _audio_player.playing:
			tw.parallel().tween_property(_audio_player, "volume_db", -40.0, 0.4)
		await tw.finished

	if _audio_player != null:
		_audio_player.stop()

	completed.emit()
	if _callback.is_valid():
		_callback.call()

	queue_free()
