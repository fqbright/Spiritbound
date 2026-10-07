extends Control
class_name HandCard

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
var is_previewing := false
var _press_time_ms := 0
var _last_drag_pos := Vector2.ZERO
var _ether_trail: Line2D = null

# Below this, a press-then-release-without-dragging counts as a quick tap that plays the
# card. At or above it, the same release just closes the peek without playing — press and
# hold a card to read it, without that hold accidentally playing it once you let go.
const TAP_THRESHOLD_MS := 220
# The peek used to appear only after a short delay (waiting to see whether the touch was
# a hold, not a tap) — but that delay put Godot's input state in limbo for exactly the
# window iOS's own long-press/haptic-touch gesture recognition watches for, and it could
# swallow the matching release before Godot's per-Control _gui_input ever saw it, leaving
# the card enlarged forever. Showing the peek immediately on every press (this now decides
# tap-vs-hold retroactively at release, from _press_time_ms, instead of gating on a
# mid-gesture timer) removes that waiting window entirely. _input() below watches the raw
# event stream (not hit-tested to this Control) as a second, independent way to notice a
# release, and this cap is the last-resort backstop if even that never arrives.
const PREVIEW_MAX_DURATION := 1.2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = Vector2(custom_minimum_size.x / 2.0, custom_minimum_size.y)

# Runs for every input event regardless of which Control it hit-tests to, unlike
# _gui_input — the one path that still notices a release even if the OS intercepted the
# gesture before Godot's normal GUI dispatch got a matching touch-up for this Control.
func _input(event: InputEvent) -> void:
	if not is_previewing: return
	var released := false
	if event is InputEventScreenTouch and not event.pressed: released = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: released = true
	if released: _end_preview()

func _end_preview() -> void:
	if not is_previewing: return
	is_previewing = false
	if game: game._clear_hold_preview()

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

func _displace_neighbors(displace: bool) -> void:
	if game == null or not is_instance_valid(game.hand_zone): return
	for child in game.hand_zone.get_children():
		if child == self or not (child is HandCard): continue
		var other := child as HandCard
		if not is_instance_valid(other): continue
		if other.is_held or other.is_dragging: continue
		if displace:
			var diff: int = other.hand_index - hand_index
			if diff == 0: continue
			var sign_val: float = -1.0 if diff < 0 else 1.0
			var factor: float = 1.0 / float(abs(diff))
			var offset_x: float = sign_val * (16.0 * factor + 4.0)
			var offset_rot: float = deg_to_rad(sign_val * 2.0 * factor)
			if other.current_tween: other.current_tween.kill()
			other.current_tween = other.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			other.current_tween.tween_property(other, "position:x", other.home_pos.x + offset_x, 0.15)
			other.current_tween.tween_property(other, "rotation", other.home_rot + offset_rot, 0.15)
		else:
			if other.current_tween: other.current_tween.kill()
			other.current_tween = other.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			other.current_tween.tween_property(other, "position:x", other.home_pos.x, 0.18)
			other.current_tween.tween_property(other, "rotation", other.home_rot, 0.18)

func _on_touch_down(local_pos: Vector2) -> void:
	is_held = true
	is_dragging = false
	_press_time_ms = Time.get_ticks_msec()
	drag_start = global_position + local_pos
	_last_drag_pos = drag_start
	z_index = 60
	Input.vibrate_handheld(15)
	_displace_neighbors(true)
	# Light up what this card may hit as soon as it leaves the hand.
	if game: game._show_valid_targets(game._card_target_mode(card_data))
	if current_tween: current_tween.kill()
	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position:y", home_pos.y - 32.0, 0.18)
	current_tween.tween_property(self, "rotation", 0.0, 0.18)
	current_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.18)
	var card_frame := get_node_or_null("CardFrame")
	if card_frame and is_instance_valid(card_frame):
		current_tween.tween_property(card_frame, "modulate", Color(1.14, 1.14, 1.10, 1.0), 0.18)

	# Show the peek right away (see the const comment above for why there is no delay
	# here any more) — _on_touch_up decides afterwards, from how long it was actually
	# held, whether this was a tap that plays the card or a hold that just closes it.
	is_previewing = true
	if game: game._show_hold_preview(card_data)
	var cap := get_tree().create_timer(PREVIEW_MAX_DURATION)
	cap.timeout.connect(func():
		if is_instance_valid(self): _end_preview()
	)

func _on_drag(local_pos: Vector2) -> void:
	var cur_global := global_position + local_pos
	var delta: Vector2 = cur_global - drag_start
	var vel_x: float = cur_global.x - _last_drag_pos.x if _last_drag_pos != Vector2.ZERO else 0.0
	_last_drag_pos = cur_global
	if not is_dragging and delta.length() > 6.0:
		is_dragging = true
		# A peek is "let me read this," not a drag — the instant a real drag starts,
		# drop the peek and fall straight into the normal drag-to-target flow.
		_end_preview()
		if game: game._show_cancel_zone(true)
	if is_dragging:
		if current_tween: current_tween.kill()
		global_position = cur_global - Vector2(custom_minimum_size.x / 2.0, custom_minimum_size.y / 2.0)
		var target_rot: float = clampf(vel_x * 0.016 + delta.x * 0.0016, -0.28, 0.28)
		rotation = lerpf(rotation, target_rot, 0.45)
		var tilt_y_squash: float = 1.0 - absf(target_rot) * 0.15
		scale = Vector2(1.15, 1.15 * tilt_y_squash)
		if game and game.has_method("_update_hero_drag_tracking"):
			game._update_hero_drag_tracking(cur_global)
		if game and game.has_method("_update_battle_parallax"):
			game._update_battle_parallax(delta)
		var card_frame := get_node_or_null("CardFrame")
		if card_frame:
			for child in card_frame.get_children():
				if child is TextureRect and child.material is ShaderMaterial:
					child.material.set_shader_parameter("tilt_shift", clampf(delta.x * 0.015, -1.0, 1.0))
					child.material.set_shader_parameter("tilt_offset", Vector2(clampf(delta.x * 0.008, -1.0, 1.0), clampf(delta.y * 0.008, -1.0, 1.0)))
		if game and game.overlay:
			if _ether_trail == null:
				_ether_trail = Line2D.new()
				_ether_trail.name = "CardEtherTrail"
				_ether_trail.width = 6.0
				_ether_trail.joint_mode = Line2D.LINE_JOINT_ROUND
				_ether_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
				_ether_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
				var curve := Curve.new()
				curve.add_point(Vector2(0.0, 0.2))
				curve.add_point(Vector2(1.0, 1.0))
				_ether_trail.width_curve = curve
				var elem: String = str(card_data.get("element", ""))
				match elem:
					"Fire": _ether_trail.default_color = Color(1.0, 0.55, 0.20, 0.75)
					"Water": _ether_trail.default_color = Color(0.35, 0.75, 1.0, 0.75)
					"Storm": _ether_trail.default_color = Color(0.85, 0.45, 1.0, 0.75)
					"Earth": _ether_trail.default_color = Color(1.0, 0.85, 0.35, 0.75)
					"Toxin": _ether_trail.default_color = Color(0.35, 0.95, 0.50, 0.75)
					_: _ether_trail.default_color = Color(0.90, 0.95, 1.0, 0.65)
				_ether_trail.z_index = 340
				game.overlay.add_child(_ether_trail)
			_ether_trail.add_point(cur_global)
			if _ether_trail.get_point_count() > 14:
				_ether_trail.remove_point(0)
		if game and game.has_method("_preview_energy_drain"):
			game._preview_energy_drain(int(card_data.get("cost", 0)))
		target_enemy_idx = -1
		# A card that acts on you cannot be aimed at an enemy, so it never hovers one.
		if game and game._card_target_mode(card_data) == "enemy":
			var hovered_box: Control = null
			for box in game.enemy_boxes:
				if box and is_instance_valid(box):
					var rect: Rect2 = box.get_global_rect()
					if rect.has_point(cur_global):
						target_enemy_idx = int(box.get_meta("enemy_index"))
						hovered_box = box
						game._set_enemy_targeted(target_enemy_idx, true)
					else:
						game._set_enemy_targeted(int(box.get_meta("enemy_index")), false)
			# Only rebuild the preview when the hovered enemy changes, not on every drag sample.
			if target_enemy_idx != preview_index:
				preview_index = target_enemy_idx
				if target_enemy_idx >= 0:
					if game: game._haptic("heavy")
					game._show_damage_preview(card_data, target_enemy_idx)
				else: game._clear_damage_preview()

			# Update the cubic bezier targeting arc from card top to drag point / locked enemy
			var arc_start := global_position + Vector2(custom_minimum_size.x * 0.5, 4.0)
			var arc_target := cur_global
			if hovered_box and is_instance_valid(hovered_box):
				arc_target = hovered_box.global_position + hovered_box.size * 0.5
			if game.has_method("_update_targeting_arc"):
				game._update_targeting_arc(arc_start, arc_target, target_enemy_idx >= 0)

var _last_tap_time_ms := 0

func _on_touch_up() -> void:
	_last_drag_pos = Vector2.ZERO
	if not is_held: return
	is_held = false
	preview_index = -1
	_displace_neighbors(false)
	if game:
		if game.has_method("_clear_targeting_arc"):
			game._clear_targeting_arc()
		if game.has_method("_clear_energy_drain_preview"):
			game._clear_energy_drain_preview()
		if game.has_method("_clear_hero_drag_tracking"):
			game._clear_hero_drag_tracking()
		if game.has_method("_reset_battle_parallax"):
			game._reset_battle_parallax()
		game._clear_damage_preview()
		game._clear_valid_targets()
		game._show_cancel_zone(false)

	var now_ms: int = Time.get_ticks_msec()
	var was_quick_tap: bool = now_ms - _press_time_ms < TAP_THRESHOLD_MS
	var is_double_tap: bool = was_quick_tap and (now_ms - _last_tap_time_ms < 320)
	_last_tap_time_ms = now_ms
	_end_preview()
	_clear_ether_trail()

	var played := false
	if not is_dragging:
		if is_double_tap:
			var target_mode: String = game._card_target_mode(card_data) if game else "none"
			var auto_target: int = -1
			if target_mode == "enemy" and game:
				var living: Array = game._living_enemies()
				if not living.is_empty(): auto_target = living[0]
			played = game._attempt_play_card(hand_index, auto_target)
		elif was_quick_tap:
			game.call_deferred("_tap_card", hand_index)
		else:
			_spring_back()
		is_dragging = false
		return

	# Quick-Cast upward flick for non-targeted cards (defense, buff, draw)
	var is_flick_up: bool = is_dragging and (position.y < home_pos.y - 45.0) and absf(position.x - home_pos.x) < 90.0
	if is_flick_up and game and game._card_target_mode(card_data) != "enemy":
		played = game._attempt_play_card(hand_index, -1)

	# If dropped in the cancel zone (bottom hand region) or below 560y, cancel play cleanly
	if not played and is_dragging and global_position.y < 560.0 and position.y < home_pos.y - 60.0:
		var final_target := target_enemy_idx
		if final_target < 0 and game._card_target_mode(card_data) == "enemy":
			var alive_indices: Array = game._living_enemies()
			if alive_indices.size() == 1: final_target = alive_indices[0]
		played = game._attempt_play_card(hand_index, final_target)

	if not played:
		_spring_back()
	is_dragging = false


func _clear_ether_trail() -> void:
	if _ether_trail != null:
		var trail := _ether_trail
		_ether_trail = null
		if is_instance_valid(trail):
			var tw := trail.create_tween()
			tw.tween_property(trail, "modulate:a", 0.0, 0.18)
			tw.tween_callback(trail.queue_free)

func _spring_back() -> void:
	z_index = hand_index
	if current_tween: current_tween.kill()
	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position", home_pos, 0.4)
	current_tween.tween_property(self, "rotation", home_rot, 0.3)
	current_tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	var card_frame := get_node_or_null("CardFrame")
	if card_frame and is_instance_valid(card_frame):
		current_tween.tween_property(card_frame, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)


