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

func _on_touch_down(local_pos: Vector2) -> void:
	is_held = true
	is_dragging = false
	_press_time_ms = Time.get_ticks_msec()
	drag_start = global_position + local_pos
	z_index = 60
	Input.vibrate_handheld(15)
	# Light up what this card may hit as soon as it leaves the hand.
	if game: game._show_valid_targets(game._card_target_mode(card_data))
	if current_tween: current_tween.kill()
	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position:y", home_pos.y - 32.0, 0.18)
	current_tween.tween_property(self, "rotation", 0.0, 0.18)
	current_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.18)

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
	if not is_dragging and delta.length() > 6.0:
		is_dragging = true
		# A peek is "let me read this," not a drag — the instant a real drag starts,
		# drop the peek and fall straight into the normal drag-to-target flow.
		_end_preview()
		if game: game._show_cancel_zone(true)
	if is_dragging:
		if current_tween: current_tween.kill()
		global_position = cur_global - Vector2(custom_minimum_size.x / 2.0, custom_minimum_size.y / 2.0)
		rotation = 0.0
		scale = Vector2(1.12, 1.12)
		target_enemy_idx = -1
		# A card that acts on you cannot be aimed at an enemy, so it never hovers one.
		if game and game._card_target_mode(card_data) == "enemy":
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
				if target_enemy_idx >= 0:
					if game: game._haptic("card_drag")
					game._show_damage_preview(card_data, target_enemy_idx)
				else: game._clear_damage_preview()

func _on_touch_up() -> void:
	if not is_held: return
	is_held = false
	preview_index = -1
	if game:
		game._clear_damage_preview()
		game._clear_valid_targets()
		game._show_cancel_zone(false)

	# The peek has been showing since the moment this touch began; decide now, from how
	# long that actually was, whether this reads as a tap (plays the card) or a hold
	# (just closes the peek — holding a card to read it should never also play it).
	var was_quick_tap: bool = Time.get_ticks_msec() - _press_time_ms < TAP_THRESHOLD_MS
	_end_preview()

	var played := false
	if not is_dragging:
		if was_quick_tap:
			# Defer the rebuild until this input callback has returned; playing a card
			# recreates the battle view and frees the current hand nodes.
			game.call_deferred("_tap_card", hand_index)
		else:
			_spring_back()
		is_dragging = false
		return

	# If dropped in the cancel zone (bottom hand region) or below 560y, cancel play cleanly
	if is_dragging and global_position.y < 560.0 and position.y < home_pos.y - 60.0:
		var final_target := target_enemy_idx
		if final_target < 0 and game._card_target_mode(card_data) == "enemy":
			# Dropped short of any enemy: with one left there is no ambiguity to resolve.
			var alive_indices: Array = game._living_enemies()
			if alive_indices.size() == 1: final_target = alive_indices[0]
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


