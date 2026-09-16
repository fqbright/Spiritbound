extends Control

class TouchScrollContainer extends ScrollContainer:
	# Scroll position is kept as a float and only rounded on the way out; tracking it as an
	# int loses every sub-pixel step and is what made slow drags feel like they stuttered.
	var _touch_start := Vector2.ZERO
	var _last_pos := Vector2.ZERO
	var _last_time := 0.0
	var _is_touching := false
	var _is_dragging := false
	var _velocity := Vector2.ZERO
	var _pos := Vector2.ZERO
	var drag_threshold := 8.0
	var allow_horizontal := false
	var allow_vertical := true

	# Fraction of the fling speed surviving one second. Lower stops sooner.
	const FRICTION := 0.06
	const MIN_SPEED := 8.0
	const MAX_SPEED := 6000.0

	func _ready() -> void:
		set_process(true)
		mouse_filter = Control.MOUSE_FILTER_PASS
		_pos = Vector2(float(scroll_horizontal), float(scroll_vertical))

	func _limits() -> Vector2:
		var v_bar := get_v_scroll_bar()
		var h_bar := get_h_scroll_bar()
		var max_y: float = maxf(0.0, v_bar.max_value - v_bar.page) if v_bar else 0.0
		var max_x: float = maxf(0.0, h_bar.max_value - h_bar.page) if h_bar else 0.0
		return Vector2(max_x, max_y)

	func _apply(offset: Vector2) -> void:
		var limit := _limits()
		if allow_horizontal:
			_pos.x = clampf(_pos.x + offset.x, 0.0, limit.x)
			scroll_horizontal = int(round(_pos.x))
		if allow_vertical:
			_pos.y = clampf(_pos.y + offset.y, 0.0, limit.y)
			scroll_vertical = int(round(_pos.y))

	func _press(pos: Vector2) -> void:
		if not get_global_rect().has_point(pos): return
		_is_touching = true
		_is_dragging = false
		_touch_start = pos
		_last_pos = pos
		_last_time = Time.get_ticks_msec() / 1000.0
		_velocity = Vector2.ZERO
		_pos = Vector2(float(scroll_horizontal), float(scroll_vertical))

	func _drag_to(pos: Vector2) -> void:
		if not _is_touching: return
		var now := Time.get_ticks_msec() / 1000.0
		var dt: float = maxf(now - _last_time, 0.004)
		var delta: Vector2 = pos - _last_pos
		_last_pos = pos
		_last_time = now
		if not _is_dragging and (pos - _touch_start).length() > drag_threshold:
			_is_dragging = true
		if not _is_dragging: return
		get_viewport().set_input_as_handled()
		_apply(-delta)
		# Blend towards the instantaneous speed so one jittery sample cannot define the fling.
		var instant: Vector2 = (-delta / dt).limit_length(MAX_SPEED)
		_velocity = _velocity.lerp(instant, 0.4)

	func _release() -> void:
		if not _is_touching: return
		_is_touching = false
		if _is_dragging:
			get_viewport().set_input_as_handled()
			_is_dragging = false
			# A finger resting before release should stop the list, not fling it.
			if (Time.get_ticks_msec() / 1000.0) - _last_time > 0.09: _velocity = Vector2.ZERO
		else:
			_velocity = Vector2.ZERO

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree(): return
		if event is InputEventScreenTouch:
			if event.pressed: _press(event.position)
			else: _release()
		elif event is InputEventScreenDrag:
			_drag_to(event.position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _press(event.position)
			else: _release()
		elif event is InputEventMouseMotion:
			_drag_to(event.position)

	func _process(delta: float) -> void:
		if _is_touching or _velocity.length() < MIN_SPEED: return
		_apply(_velocity * delta)
		var limit := _limits()
		# Kill the glide at the ends instead of grinding against them.
		if allow_vertical and (_pos.y <= 0.0 or _pos.y >= limit.y): _velocity.y = 0.0
		if allow_horizontal and (_pos.x <= 0.0 or _pos.x >= limit.x): _velocity.x = 0.0
		_velocity *= pow(FRICTION, delta)
		if _velocity.length() < MIN_SPEED: _velocity = Vector2.ZERO


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
					if target_enemy_idx >= 0: game._show_damage_preview(card_data, target_enemy_idx)
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


# Drawn rather than glyph text: no bitmap art exists for these, and a real icon reads
# faster than a character from a font at combat-banner size.
class IntentIcon extends Control:
	var kind := "attack"
	var icon_color := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: float = size.x
		match kind:
			"defend": _draw_shield(s)
			"empower": _draw_chevrons(s)
			"curse": _draw_drop(s)
			"attack_defend":
				_draw_sword(s, 0.62, -0.12)
				_draw_shield(s * 0.56, Vector2(s * 0.58, s * 0.46))
			"critical":
				_draw_sword(s, 1.0, 0.0)
				_draw_sword(s, 1.0, 0.0, true)
				_draw_burst(s)
			_:
				_draw_sword(s, 1.0, 0.0)
				_draw_sword(s, 1.0, 0.0, true)

	func _blade(length: float, mirrored: bool) -> PackedVector2Array:
		# One blade pointing from lower-left to upper-right, as a thin hexagon with a
		# crossguard notch, built in a unit square then scaled by `length`.
		var pts := PackedVector2Array([
			Vector2(0.06, 0.94), Vector2(0.16, 0.94), Vector2(0.72, 0.38),
			Vector2(0.94, 0.16), Vector2(0.94, 0.06), Vector2(0.84, 0.06),
			Vector2(0.28, 0.62), Vector2(0.16, 0.84),
		])
		var out := PackedVector2Array()
		for p in pts:
			var q := p * length
			if mirrored: q.x = length - q.x
			out.append(q)
		return out

	func _draw_sword(s: float, scale_amt: float, rot_offset: float, mirrored := false) -> void:
		var blade := _blade(s, mirrored)
		var centered := PackedVector2Array()
		var center := Vector2(s, s) / 2.0
		for p in blade: centered.append((p - center) * scale_amt + center)
		draw_colored_polygon(centered, icon_color)
		# Hilt: a short perpendicular tick near the lower blade end.
		var hilt_center: Vector2 = centered[6].lerp(centered[7], 0.5)
		var dir: Vector2 = (centered[2] - centered[6]).normalized()
		var perp := Vector2(-dir.y, dir.x) * s * 0.09
		draw_line(hilt_center - perp, hilt_center + perp, icon_color, s * 0.05)

	func _draw_shield(s: float, offset := Vector2.ZERO) -> void:
		var pts := PackedVector2Array([
			Vector2(0.5, 0.04), Vector2(0.88, 0.18), Vector2(0.88, 0.5),
			Vector2(0.5, 0.96), Vector2(0.12, 0.5), Vector2(0.12, 0.18),
		])
		var out := PackedVector2Array()
		for p in pts: out.append(p * s + offset)
		draw_colored_polygon(out, Color(icon_color, 0.28))
		out.append(out[0])
		draw_polyline(out, icon_color, s * 0.07, true)

	func _draw_chevrons(s: float) -> void:
		for row in 2:
			var y: float = s * (0.68 - row * 0.32)
			var pts := PackedVector2Array([
				Vector2(s * 0.2, y), Vector2(s * 0.5, y - s * 0.28), Vector2(s * 0.8, y),
			])
			draw_polyline(pts, icon_color, s * 0.11, true)

	func _draw_drop(s: float) -> void:
		var pts := PackedVector2Array()
		var steps := 16
		for i in steps + 1:
			var t: float = float(i) / float(steps) * TAU
			var r: float = 0.34 * (1.0 - 0.35 * cos(t))
			pts.append(Vector2(0.5 + r * sin(t), 0.42 + r * -cos(t) + 0.16) * s)
		draw_colored_polygon(pts, icon_color)

	func _draw_burst(s: float) -> void:
		var center := Vector2(s, s) / 2.0
		for i in 6:
			var a: float = TAU * float(i) / 6.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(center + dir * s * 0.42, center + dir * s * 0.54, icon_color, s * 0.05)


# Every equipment/rune/relic/stage badge used to be one Unicode glyph in a coloured circle —
# readable, but flat, and no two items looked like they belonged to the same visual system.
# This draws an actual small icon instead: a base silhouette (sword/shield/pendant/staff/
# spear/bow for gear, a hexagon sigil frame for runes and relics) plus an optional flourish
# that carries the item's specific flavour, all vector shapes so no bitmap art is needed.
class GameIcon extends Control:
	var kind := "sword"      # base silhouette
	var flourish := ""       # small overlay mark, meaning depends on kind
	var icon_color := Color.WHITE
	var frame_color := Color.TRANSPARENT  # sigil ring colour for rune/relic marks; falls back to icon_color

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _frame() -> Color:
		return icon_color if frame_color == Color.TRANSPARENT else frame_color

	func _draw() -> void:
		var s: float = size.x
		match kind:
			"none": pass
			"shield": _draw_shield_body(s)
			"pendant": _draw_pendant_body(s)
			"staff": _draw_staff_body(s)
			"spear": _draw_spear_body(s)
			"bow": _draw_bow_body(s)
			"sigil": _draw_sigil_frame(s)
			"crossed_swords": _draw_crossed(s)
			"crown": _draw_crown(s, false)
			"grand_crown": _draw_crown(s, true)
			"orb": _draw_orb(s)
			"coin_stack": _draw_coin_stack(s)
			"campfire": _draw_campfire(s)
			"card_stack": _draw_card_stack_body(s)
			"arrow": _draw_arrow_body(s)
			"pine": _draw_pine_body(s)
			"boulder": _draw_boulder_body(s)
			"hill": _draw_hill_body(s)
			"star": _draw_star_body(s)
			"scroll": _draw_scroll_body(s)
			"quest": _draw_quest_body(s)
			"profile": _draw_profile_body(s)
			_: _draw_sword_body(s)
		if not flourish.is_empty(): _draw_mark(flourish, s, Vector2(s, s) / 2.0, s * 0.34)

	# ---- polygon helpers ----
	func _regular_polygon(center: Vector2, radius: float, sides: int, rot := 0.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in sides:
			var a: float = rot + TAU * float(i) / float(sides)
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		return pts

	func _star_points(center: Vector2, outer: float, inner: float, points: int, rot := -PI / 2.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in points * 2:
			var r := outer if i % 2 == 0 else inner
			var a: float = rot + PI * float(i) / float(points)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		return pts

	func _ring(center: Vector2, radius: float, width: float, color: Color) -> void:
		var pts := _regular_polygon(center, radius, 28)
		pts.append(pts[0])
		draw_polyline(pts, color, width, true)

	# ---- base silhouettes (drawn centred in the s x s square) ----
	func _draw_sword_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var blade := PackedVector2Array([
			c + Vector2(-0.05, -0.42) * s, c + Vector2(0.05, -0.42) * s,
			c + Vector2(0.08, 0.14) * s, c + Vector2(0.0, 0.22) * s, c + Vector2(-0.08, 0.14) * s,
		])
		draw_colored_polygon(blade, icon_color)
		draw_line(c + Vector2(-0.19, 0.12) * s, c + Vector2(0.19, 0.12) * s, icon_color, s * 0.07)
		var grip := Rect2(c + Vector2(-0.035, 0.14) * s, Vector2(0.07, 0.24) * s)
		draw_rect(grip, icon_color)

	func _draw_shield_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var pts := PackedVector2Array([
			c + Vector2(0.0, -0.40) * s, c + Vector2(0.32, -0.26) * s, c + Vector2(0.32, 0.06) * s,
			c + Vector2(0.0, 0.42) * s, c + Vector2(-0.32, 0.06) * s, c + Vector2(-0.32, -0.26) * s,
		])
		draw_colored_polygon(pts, Color(icon_color, 0.85))
		pts.append(pts[0])
		draw_polyline(pts, icon_color.lightened(0.25), s * 0.045, true)

	func _draw_pendant_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		draw_line(c + Vector2(0, -0.44) * s, c + Vector2(0, -0.2) * s, icon_color, s * 0.05)
		var gem := _regular_polygon(c + Vector2(0, 0.06) * s, s * 0.24, 6, -PI / 2.0)
		draw_colored_polygon(gem, icon_color)
		_ring(c + Vector2(0, -0.2) * s, s * 0.09, s * 0.035, icon_color)

	func _draw_staff_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		draw_line(c + Vector2(0, -0.3) * s, c + Vector2(0, 0.44) * s, icon_color, s * 0.06)
		_ring(c + Vector2(0, -0.36) * s, s * 0.11, s * 0.045, icon_color)

	func _draw_spear_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		draw_line(c + Vector2(0, -0.2) * s, c + Vector2(0, 0.44) * s, icon_color, s * 0.055)
		var tip := PackedVector2Array([c + Vector2(0, -0.46) * s, c + Vector2(0.1, -0.14) * s, c + Vector2(-0.1, -0.14) * s])
		draw_colored_polygon(tip, icon_color)

	func _draw_bow_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var arc := PackedVector2Array()
		for i in 13:
			var t: float = float(i) / 12.0
			var a: float = lerp(-PI * 0.36, PI * 0.36, t)
			arc.append(c + Vector2(cos(a), sin(a)) * s * 0.42)
		draw_polyline(arc, icon_color, s * 0.06, true)
		draw_line(arc[0], arc[arc.size() - 1], icon_color.darkened(0.1), s * 0.025)

	func _draw_crossed(s: float) -> void:
		var pivot := pivot_offset
		pivot_offset = Vector2(s, s) / 2.0
		rotation = deg_to_rad(-22)
		_draw_sword_body(s)
		rotation = deg_to_rad(22)
		_draw_sword_body(s)
		rotation = 0.0
		pivot_offset = pivot

	func _draw_crown(s: float, grand: bool) -> void:
		var c := Vector2(s, s) / 2.0
		var base_y := 0.16
		var peaks := PackedVector2Array([
			c + Vector2(-0.34, base_y) * s, c + Vector2(-0.34, -0.02) * s, c + Vector2(-0.17, 0.1) * s,
			c + Vector2(0.0, -0.34) * s, c + Vector2(0.17, 0.1) * s, c + Vector2(0.34, -0.02) * s,
			c + Vector2(0.34, base_y) * s,
		])
		draw_colored_polygon(peaks, icon_color)
		draw_rect(Rect2(c + Vector2(-0.34, base_y) * s, Vector2(0.68, 0.1) * s), icon_color.darkened(0.1))
		if grand:
			draw_colored_polygon(_regular_polygon(c + Vector2(0, -0.3) * s, s * 0.06, 6), Color.WHITE)

	func _draw_orb(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		draw_circle(c, s * 0.4, Color(icon_color, 0.35))
		draw_circle(c, s * 0.24, icon_color)
		draw_circle(c - Vector2(0.08, 0.08) * s, s * 0.08, Color(1, 1, 1, 0.8))

	func _draw_coin_stack(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		for i in 3:
			var oy := 0.18 - float(i) * 0.14
			_ring(c + Vector2(0, oy) * s, s * 0.24, s * 0.05, icon_color)
			draw_colored_polygon(_regular_polygon(c + Vector2(0, oy) * s, s * 0.19, 16), Color(icon_color, 0.5))

	func _draw_campfire(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		draw_line(c + Vector2(-0.28, 0.3) * s, c + Vector2(0.24, -0.02) * s, icon_color.darkened(0.2), s * 0.06)
		draw_line(c + Vector2(0.28, 0.3) * s, c + Vector2(-0.24, -0.02) * s, icon_color.darkened(0.2), s * 0.06)
		_draw_mark("flame", s, c + Vector2(0, -0.16) * s, s * 0.28)

	func _draw_sigil_frame(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var hex := _regular_polygon(c, s * 0.46, 6, -PI / 2.0)
		draw_colored_polygon(hex, Color(_frame(), 0.14))
		hex.append(hex[0])
		draw_polyline(hex, _frame(), s * 0.045, true)

	# A small fanned hand of three cards — the deck tab's icon.
	func _draw_card_stack_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var half := Vector2(0.16, 0.22) * s
		for i in 3:
			var rot: float = deg_to_rad(-14.0 + float(i) * 14.0)
			var offset := Vector2(float(i - 1) * 0.05, float(i - 1) * -0.02) * s
			var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
			var pts := PackedVector2Array()
			for corner in corners: pts.append(corner.rotated(rot) + c + offset)
			draw_colored_polygon(pts, Color(icon_color, 0.4 + float(i) * 0.2))
			pts.append(pts[0])
			draw_polyline(pts, icon_color, s * 0.028, true)

	# A single decisive chevron pointing onward — the "next stage" icon.
	func _draw_arrow_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var pts := PackedVector2Array([
			c + Vector2(-0.32, -0.2) * s, c + Vector2(0.06, -0.2) * s, c + Vector2(0.06, -0.38) * s,
			c + Vector2(0.4, 0.0) * s, c + Vector2(0.06, 0.38) * s, c + Vector2(0.06, 0.2) * s,
			c + Vector2(-0.32, 0.2) * s,
		])
		draw_colored_polygon(pts, icon_color)

	# ---- terrain dressing (scattered on the map background, not badge icons) ----
	func _draw_pine_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		draw_rect(Rect2(c + Vector2(-0.04, 0.26) * s, Vector2(0.08, 0.16) * s), icon_color.darkened(0.35))
		for i in 3:
			var w: float = 0.4 - float(i) * 0.1
			var y: float = 0.2 - float(i) * 0.2
			var tri := PackedVector2Array([
				c + Vector2(0, y - 0.18) * s, c + Vector2(w, y + 0.08) * s, c + Vector2(-w, y + 0.08) * s,
			])
			draw_colored_polygon(tri, icon_color)

	func _draw_boulder_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var pts := PackedVector2Array([
			c + Vector2(-0.38, 0.22) * s, c + Vector2(-0.3, -0.08) * s, c + Vector2(-0.08, -0.28) * s,
			c + Vector2(0.2, -0.22) * s, c + Vector2(0.38, 0.04) * s, c + Vector2(0.26, 0.26) * s,
			c + Vector2(-0.1, 0.3) * s,
		])
		draw_colored_polygon(pts, icon_color)
		var facet := PackedVector2Array([
			c + Vector2(-0.08, -0.24) * s, c + Vector2(0.16, -0.18) * s, c + Vector2(0.06, -0.02) * s, c + Vector2(-0.2, -0.02) * s,
		])
		draw_colored_polygon(facet, icon_color.lightened(0.18))

	func _draw_hill_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		for i in 2:
			var cx: float = -0.16 + float(i) * 0.3
			var pts := PackedVector2Array()
			var steps := 12
			for j in steps + 1:
				var t: float = float(j) / float(steps)
				var a: float = lerp(PI, 0.0, t)
				pts.append(c + Vector2(cx + cos(a) * 0.34, 0.14 - sin(a) * 0.3) * s)
			pts.append(c + Vector2(cx + 0.34, 0.32) * s)
			pts.append(c + Vector2(cx - 0.34, 0.32) * s)
			draw_colored_polygon(pts, Color(icon_color, 0.5 + float(i) * 0.2))

	# A classic 5-point rating star, filled solid — for rarity rows on shop/deck cards, not
	# the 4-point "sparkle" flourish used elsewhere for a magical glint.
	func _draw_star_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		draw_colored_polygon(_star_points(c, s * 0.46, s * 0.19, 5), icon_color)

	# A rolled quest scroll: a body rectangle with a rolled cylinder cap at top and bottom,
	# plus two ribbon lines standing in for its own text — for the quest-log entry point.
	func _draw_scroll_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var w: float = s * 0.62
		var body_top: float = s * 0.28
		var body_bottom: float = s * 0.72
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - w / 2.0, body_top), Vector2(c.x + w / 2.0, body_top),
			Vector2(c.x + w / 2.0, body_bottom), Vector2(c.x - w / 2.0, body_bottom),
		]), icon_color)
		draw_rect(Rect2(c.x - w / 2.0 - s * 0.05, body_top - s * 0.05, w + s * 0.1, s * 0.1), icon_color)
		draw_rect(Rect2(c.x - w / 2.0 - s * 0.05, body_bottom - s * 0.05, w + s * 0.1, s * 0.1), icon_color)
		var ink := icon_color.darkened(0.45)
		draw_line(Vector2(c.x - w * 0.3, c.y - s * 0.06), Vector2(c.x + w * 0.3, c.y - s * 0.06), ink, s * 0.045)
		draw_line(Vector2(c.x - w * 0.3, c.y + s * 0.08), Vector2(c.x + w * 0.15, c.y + s * 0.08), ink, s * 0.045)

	# Dedicated quest commission icon: parchment scroll with wax seal & ribbon star
	func _draw_quest_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		var w: float = s * 0.58
		var body_top: float = s * 0.22
		var body_bottom: float = s * 0.76
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - w / 2.0, body_top), Vector2(c.x + w / 2.0, body_top),
			Vector2(c.x + w / 2.0, body_bottom), Vector2(c.x - w / 2.0, body_bottom),
		]), Color(icon_color, 0.9))
		draw_rect(Rect2(c.x - w / 2.0 - s * 0.07, body_top - s * 0.05, w + s * 0.14, s * 0.07), icon_color.darkened(0.3))
		draw_rect(Rect2(c.x - w / 2.0 - s * 0.07, body_bottom - s * 0.02, w + s * 0.14, s * 0.07), icon_color.darkened(0.3))
		var ink := icon_color.darkened(0.45)
		draw_line(Vector2(c.x - w * 0.32, c.y - s * 0.12), Vector2(c.x + w * 0.32, c.y - s * 0.12), ink, s * 0.04)
		draw_line(Vector2(c.x - w * 0.32, c.y), Vector2(c.x + w * 0.18, c.y), ink, s * 0.04)
		draw_line(Vector2(c.x - w * 0.32, c.y + s * 0.12), Vector2(c.x + w * 0.05, c.y + s * 0.12), ink, s * 0.04)
		var seal_c := Vector2(c.x + w * 0.22, body_bottom - s * 0.10)
		draw_circle(seal_c, s * 0.13, Color("d94537"))
		draw_circle(seal_c, s * 0.07, Color("f4b23f"))

	# Dedicated hero profile / adventurer emblem: circular medallion with hooded hero silhouette
	func _draw_profile_body(s: float) -> void:
		var c := Vector2(s, s) / 2.0
		_ring(c, s * 0.42, s * 0.055, icon_color)
		var head_c := c + Vector2(0, -0.10) * s
		draw_circle(head_c, s * 0.15, icon_color)
		var torso := PackedVector2Array([
			c + Vector2(-0.28, 0.34) * s,
			c + Vector2(-0.18, 0.08) * s,
			c + Vector2(-0.08, 0.02) * s,
			c + Vector2(0.08, 0.02) * s,
			c + Vector2(0.18, 0.08) * s,
			c + Vector2(0.28, 0.34) * s,
		])
		draw_colored_polygon(torso, icon_color)

	# ---- flourishes / marks, drawn as a small overlay centred at `center` with radius `r` ----
	func _draw_mark(mark: String, s: float, center: Vector2, r: float) -> void:
		match mark:
			"flame":
				var pts := PackedVector2Array()
				for i in 17:
					var t: float = float(i) / 16.0 * TAU
					var rad: float = r * (1.0 - 0.35 * cos(t))
					pts.append(center + Vector2(rad * sin(t), rad * -cos(t) * 1.15 + r * 0.18))
				draw_colored_polygon(pts, icon_color)
			"drop":
				var pts := PackedVector2Array()
				for i in 17:
					var t: float = float(i) / 16.0 * TAU
					var rad: float = r * (1.0 - 0.35 * cos(t))
					pts.append(center + Vector2(rad * sin(t), rad * -cos(t) + r * 0.3))
				draw_colored_polygon(pts, icon_color)
			"wave":
				var pts := PackedVector2Array()
				for i in 13:
					var t: float = float(i) / 12.0
					pts.append(center + Vector2((t - 0.5) * r * 2.4, sin(t * TAU) * r * 0.4))
				draw_polyline(pts, icon_color, s * 0.05, true)
			"spike":
				for k in 3:
					var a: float = -PI / 2.0 + (float(k) - 1.0) * 0.7
					var dir := Vector2(cos(a), sin(a))
					draw_colored_polygon(PackedVector2Array([
						center - dir.orthogonal() * r * 0.18, center + dir * r * 1.3, center + dir.orthogonal() * r * 0.18,
					]), icon_color)
			"wing":
				for side in [-1.0, 1.0]:
					var pts := PackedVector2Array([center, center + Vector2(side * r * 1.2, -r * 0.5), center + Vector2(side * r * 1.3, r * 0.15), center + Vector2(side * r * 0.5, r * 0.1)])
					draw_colored_polygon(pts, Color(icon_color, 0.85))
			"eye":
				var pts := PackedVector2Array()
				for i in 13:
					var t: float = float(i) / 12.0 * TAU
					pts.append(center + Vector2(cos(t) * r, sin(t) * r * 0.5))
				draw_colored_polygon(pts, Color(icon_color, 0.3))
				draw_circle(center, r * 0.32, icon_color)
			"coin":
				_ring(center, r * 0.8, r * 0.18, icon_color)
			"spiral":
				var pts := PackedVector2Array()
				for i in 24:
					var t: float = float(i) / 23.0
					var a: float = t * TAU * 1.6
					pts.append(center + Vector2(cos(a), sin(a)) * r * t)
				draw_polyline(pts, icon_color, s * 0.045, true)
			"crescent":
				# True subtraction needs a stencil Godot's 2D canvas API doesn't expose here;
				# a dark offset overlay reads as a moon's shadow against this game's panels,
				# which are consistently dark, without one.
				draw_circle(center, r, icon_color)
				draw_circle(center + Vector2(r * 0.45, -r * 0.08), r * 0.86, Color(0.02, 0.05, 0.07, 0.92))
			"rings":
				_ring(center, r * 0.5, r * 0.1, icon_color)
				_ring(center, r, r * 0.1, Color(icon_color, 0.6))
			"shield_mark":
				var pts := PackedVector2Array([
					center + Vector2(0, -r), center + Vector2(r * 0.75, -r * 0.55), center + Vector2(r * 0.75, r * 0.15),
					center + Vector2(0, r), center + Vector2(-r * 0.75, r * 0.15), center + Vector2(-r * 0.75, -r * 0.55),
				])
				pts.append(pts[0])
				draw_polyline(pts, icon_color, r * 0.16, true)
			"cycle_arrows":
				var pts := PackedVector2Array()
				for i in 20:
					var t: float = float(i) / 19.0
					var a: float = lerp(-PI * 0.2, PI * 1.5, t)
					pts.append(center + Vector2(cos(a), sin(a)) * r)
				draw_polyline(pts, icon_color, r * 0.14, true)
				var head := pts[pts.size() - 1]
				var tang := (pts[pts.size() - 1] - pts[pts.size() - 3]).normalized()
				var perp := tang.orthogonal()
				draw_colored_polygon(PackedVector2Array([head + tang * r * 0.32, head + perp * r * 0.22, head - perp * r * 0.22]), icon_color)
			"sparkle":
				draw_colored_polygon(_star_points(center, r, r * 0.32, 4), icon_color)
			"cross_blade":
				for ang in [PI / 4.0, -PI / 4.0]:
					var dir := Vector2(cos(ang), sin(ang))
					draw_line(center - dir * r, center + dir * r, icon_color, r * 0.16)
			"bolt":
				var pts := PackedVector2Array([
					center + Vector2(0.12, -1.0) * r, center + Vector2(-0.35, 0.05) * r, center + Vector2(0.05, 0.05) * r,
					center + Vector2(-0.12, 1.0) * r, center + Vector2(0.35, -0.15) * r, center + Vector2(-0.05, -0.15) * r,
				])
				draw_colored_polygon(pts, icon_color)
			"leaf":
				var pts := PackedVector2Array()
				for i in 17:
					var t: float = float(i) / 16.0 * TAU
					pts.append(center + Vector2(sin(t) * r * 0.55, -cos(t) * r))
				draw_colored_polygon(pts, icon_color)
				draw_line(center + Vector2(0, r * 0.85), center + Vector2(0, -r * 0.85), icon_color.darkened(0.25), r * 0.08)


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
var pending_rewards: Dictionary = {}
var selected_card := -1
var advancing_to_reward := false
var pre_battle_health := 60
var in_abyss := false
var pending_boon_draft := false
var in_daily_trial := false
var compendium_tab := "cards"
var camp_tab := "character"
var battle_speed := 1.0
const BATTLE_SPEED_OPTIONS: Array[float] = [1.0, 1.5, 2.0]
var deck_filter_kind: String = "all"
var deck_filter_element: String = "all"
var deck_search_query: String = ""
var is_hard_replay: bool = false
var _back_action := Callable()
var _swipe_origin := Vector2.ZERO
var _swipe_tracking := false
var map_music: AudioStreamPlayer
var battle_music: AudioStreamPlayer
var battle_music_streams: Array[AudioStream] = []
var font_cjk: Font = load("res://assets/fonts/NotoSansSC.ttf")

var _char_atlas_tex: Texture2D = null
var _card_atlas_1: Texture2D = null
var _card_atlas_2: Texture2D = null
var _road_texture: NoiseTexture2D = null
var _mote_texture: GradientTexture2D = null
var _hit_flash_shader: Shader = null
var _card_foil_shader: Shader = null
var _ember_texture: GradientTexture2D = null
var _terrain_grain_texture: NoiseTexture2D = null
var _terrain_wash_cache: Dictionary = {}
var _map_pin_rune_tex: Texture2D = null
var _card_frame_border_tex: Texture2D = null
var _card_frame_cache: Dictionary = {}

func _get_card_frame_texture(rarity: String = "Common") -> Texture2D:
	if _card_frame_cache.has(rarity):
		return _card_frame_cache[rarity]
	var path := ""
	match rarity:
		"Starter": path = "res://assets/card_frame_starter.png"
		"Uncommon": path = "res://assets/card_frame_uncommon.png"
		"Rare": path = "res://assets/card_frame_rare.png"
		_: path = "res://assets/card_frame_common.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex != null:
			_card_frame_cache[rarity] = tex
			return tex
	if _card_frame_border_tex == null:
		_card_frame_border_tex = load("res://assets/card_frame_golden_border.png")
	return _card_frame_border_tex

var _map_tile_forest_tex: Texture2D = null
var _biome_textures: Array = []
var _chapter_map_cache: Dictionary = {}
var _icon_textures: Dictionary = {}
# Chapter waypoints are deterministic but not cheap to compute (a seeded RNG walk); they
# never change once generated, so cache per chapter for the life of the app.
var _map_waypoint_cache: Dictionary = {}

const BG = Color("071116")
const PANEL = Color("10242b")
const JADE = Color("83e4c1")
const EMBER = Color("ff9a4c")
const GOLD = Color("dab56e")
const TEXT = Color("f7f3e8")
const MUTED = Color("bdd0d0")
const BATTLE_BACKGROUNDS = ["battlefield-v1.jpg","lantern-marsh-v1.jpg","rune-ravine-v1.jpg","ember-cliff-v1.jpg","mountain-forge-v1.jpg"]

# The map is full-bleed: it spans the whole 390pt screen rather than sitting inside the
# page margins every other screen uses.
const MAP_WIDTH = 390.0
const BAND_HEIGHT = 520.0
# Keeps every stage pin clear of the screen edge and of the chapter plaque/fade at the top.
const ROAD_MARGIN_X = 62.0
const ROAD_TOP_CLEAR = 100.0
# Each chapter gets its own wash of colour so the terrain still reads as a distinct region.
const CHAPTER_TINTS = [
	Color(0.72,0.88,0.86), Color(0.95,0.78,0.55), Color(0.72,0.80,1.00), Color(0.80,0.86,0.92), Color(0.74,0.92,0.72),
	Color(0.68,0.90,0.95), Color(0.70,0.96,0.80), Color(0.88,0.82,0.98), Color(1.00,0.72,0.56), Color(0.98,0.86,0.62),
]

# Hand-picked to trace the actual painted trail/river/canyon-floor in each of the six
# chapter/biome backgrounds (assets/chapters/chapter_0..5.png, each exactly MAP_WIDTHxBAND_HEIGHT)
# at the five fixed stage heights below — a seeded random walk drew a nice-looking curve
# before there was real art to match, but it wandered wherever it liked, so pins and the
# drawn road sat over rocks and treetops instead of the actual path in the image. One entry
# per biome, indexed by chapter % 6 to match _get_chapter_map_texture's own cycling.
const BIOME_PATH_WAYPOINTS = [
	[Vector2(210, 112), Vector2(185, 208), Vector2(145, 304), Vector2(85, 396), Vector2(140, 480)],  # forest
	[Vector2(250, 112), Vector2(240, 208), Vector2(255, 304), Vector2(250, 396), Vector2(275, 480)],  # autumn plains
	[Vector2(200, 112), Vector2(190, 208), Vector2(185, 304), Vector2(180, 396), Vector2(165, 480)],  # glacier
	[Vector2(210, 112), Vector2(195, 208), Vector2(205, 304), Vector2(210, 396), Vector2(225, 480)],  # ember canyon
	[Vector2(200, 112), Vector2(190, 208), Vector2(220, 304), Vector2(205, 396), Vector2(240, 480)],  # mystic swamp
	[Vector2(200, 112), Vector2(180, 208), Vector2(210, 304), Vector2(190, 396), Vector2(200, 480)],  # sunlit ruins
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
	# No new bitmap art exists for these — reused slots follow the same pattern the rest
	# of the deck already uses (several cards already share one atlas cell).
	"ironHide": Vector2i(0, 0),
	"steadyPulse": Vector2i(1, 0),
	"shatterGuard": Vector2i(0, 1),
	"ironWill": Vector2i(1, 1),
	"wardBreaker": Vector2i(0, 0),
	"stormcaller": Vector2i(1, 0),
	"spiritNova": Vector2i(0, 1),
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
	"embercoal": Vector2i(0, 0),
	"emberVow": Vector2i(1, 0),
	"mendingWard": Vector2i(0, 1),
	"piercingBolt": Vector2i(1, 1),
	"phoenixEdge": Vector2i(0, 0),
	"titanForm": Vector2i(1, 0),
	"moltenCore": Vector2i(0, 1),
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
	if card_id in ["strike", "ward", "foxfire", "focus", "spiritCurrent"]:
		return load("res://assets/cards/%s.jpg" % card_id)
	elif CARD_ATLAS_1_POS.has(card_id):
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

func _get_chapter_map_texture(chapter: int) -> Texture2D:
	if _chapter_map_cache.has(chapter):
		return _chapter_map_cache[chapter]
	var specific_path := "res://assets/chapters/chapter_%d.png" % chapter
	if ResourceLoader.exists(specific_path):
		var tex: Texture2D = load(specific_path)
		if tex != null:
			_chapter_map_cache[chapter] = tex
			return tex
	if _biome_textures.is_empty():
		var biome_files := [
			"res://assets/biomes/biome_0_forest.png",
			"res://assets/biomes/biome_1_autumn.png",
			"res://assets/biomes/biome_2_glacier.png",
			"res://assets/biomes/biome_3_ember.png",
			"res://assets/biomes/biome_4_swamp.png",
			"res://assets/biomes/biome_5_ruins.png"
		]
		for f in biome_files:
			if ResourceLoader.exists(f):
				_biome_textures.append(load(f))
	if not _biome_textures.is_empty():
		var fallback_tex: Texture2D = _biome_textures[chapter % _biome_textures.size()]
		_chapter_map_cache[chapter] = fallback_tex
		return fallback_tex
	return null

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
	battle_speed = clampf(float(profile.get("battle_speed", 1.0)), 1.0, 2.0)
	_build_audio()
	_ensure_quests_current()
	_ensure_daily_trial_current()
	_ensure_login_reward_current()
	if SpiritSave.has_account_name(profile): show_map()
	else: show_account_setup()

const DAY_SECONDS := 86400
const WEEK_SECONDS := 604800

# Rerolls whichever list has aged past its period. period_seed is the period index itself
# (today's day number, this week's week number) so every reroll for the same period is
# identical — rerolling never happens more than once per period no matter how often this
# is called, since the new reset_at always lands in the future until the period elapses.
func _ensure_quests_current() -> void:
	var now := int(Time.get_unix_time_from_system())
	var changed := false
	if now >= int(profile.get("daily_reset_at", 0)):
		var day: int = now / DAY_SECONDS
		profile.daily_quests = content.roll_quests(SpiritContent.DAILY_QUESTS, 3, day)
		profile.daily_reset_at = (day + 1) * DAY_SECONDS
		changed = true
	if now >= int(profile.get("weekly_reset_at", 0)):
		var week: int = now / WEEK_SECONDS
		profile.weekly_quests = content.roll_quests(SpiritContent.WEEKLY_QUESTS, 3, 1000000 + week)
		profile.weekly_reset_at = (week + 1) * WEEK_SECONDS
		changed = true
	if changed: SpiritSave.write(profile)

# Same day-boundary rule as quests above: whichever day index the trial record was rolled
# for, once "now" moves past it the run resets to stage 0 — lifetime badges/best_stage are
# untouched, only the in-progress run.
func _ensure_daily_trial_current() -> void:
	var day: int = int(Time.get_unix_time_from_system()) / DAY_SECONDS
	var previous: Dictionary = profile.get("daily_trial_record", {})
	if int(previous.get("day", -1)) != day:
		var prev_day: int = int(previous.get("day", -1))
		var prev_stage: int = int(previous.get("stage", 0))
		var streak: int = int(previous.get("streak", 0))
		if prev_day == day - 1:
			if prev_stage < SpiritContent.DAILY_TRIAL_STAGES: streak = 0
		elif prev_day != -1:
			streak = 0
		profile.daily_trial_record = {
			"day": day,
			"stage": 0,
			"badges": int(previous.get("badges", 0)),
			"best_stage": int(previous.get("best_stage", 0)),
			"streak": streak,
			"streak_claimed": previous.get("streak_claimed", []).duplicate()
		}
		SpiritSave.write(profile)

# Rolling weekly login reward: a new week resets the tally, and today's day index is recorded
# at most once (calling this repeatedly in one session, e.g. once per _ready(), must not let a
# player "log in" more than once for the same calendar day). Deliberately never resets on a
# missed day mid-week — see content.gd's LOGIN_REWARD_TIERS comment for why a hard streak
# reset is the wrong shape here.
func _ensure_login_reward_current() -> void:
	var now := int(Time.get_unix_time_from_system())
	var week: int = now / WEEK_SECONDS
	var today: int = now / DAY_SECONDS
	var record: Dictionary = profile.get("login_reward", {})
	if int(record.get("week", -1)) != week:
		record = {"week": week, "days": [], "claimed": []}
	var days: Array = record.get("days", [])
	if not days.has(today):
		days.append(today)
		record.days = days
		profile.login_reward = record
		SpiritSave.write(profile)
	else:
		profile.login_reward = record

func _claim_login_reward(tier_index: int) -> void:
	if tier_index < 0 or tier_index >= SpiritContent.LOGIN_REWARD_TIERS.size(): return
	var tier: Dictionary = SpiritContent.LOGIN_REWARD_TIERS[tier_index]
	var record: Dictionary = profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	if days_logged < int(tier.days): return
	var claimed: Array = record.get("claimed", [])
	if claimed.has(int(tier.days)): return
	claimed.append(int(tier.days))
	record.claimed = claimed
	profile.login_reward = record
	profile.gold += int(tier.reward)
	SpiritSave.write(profile)
	_toast(tf("ui.login_reward_claimed_toast", int(tier.reward)), GOLD)
	show_quests()

# Drives the red notification dot on the camp/quest entry point — true the moment any daily
# or weekly quest, or a login reward tier, is complete and waiting on its reward, same as the
# claim buttons inside.
func _has_claimable_quest() -> bool:
	_ensure_quests_current()
	_ensure_login_reward_current()
	var record: Dictionary = profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	var claimed: Array = record.get("claimed", [])
	for tier in SpiritContent.LOGIN_REWARD_TIERS:
		if days_logged >= int(tier.days) and not claimed.has(int(tier.days)): return true
	for list_name in ["daily_quests", "weekly_quests"]:
		for entry in profile.get(list_name, []):
			if int(entry.get("progress", 0)) >= int(entry.get("target", 1)) and not bool(entry.get("claimed", false)):
				return true
	return false

# Drives the deck dock button's red dot — true whenever a card sits in the collection with
# more owned copies than are actually placed in the 25-card deck (a shop buy or a chest
# reward that never made it in).
func _has_unused_cards() -> bool:
	for id in profile.collection:
		if int(profile.collection[id]) > profile.deck.count(str(id)): return true
	return false

# A small red dot for "there is something to check in here" — the same language most mobile
# games use for unclaimed rewards or unseen content, so tapping in isn't a guess.
func _add_notification_dot(anchor: Control, btn_size: Vector2) -> void:
	var dot := Panel.new()
	dot.name = "NotificationDot"
	dot.custom_minimum_size = Vector2(13, 13)
	dot.size = dot.custom_minimum_size
	dot.position = Vector2(btn_size.x - 10.0, -3.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.z_index = 5
	dot.add_theme_stylebox_override("panel", _panel(EMBER, 7, Color("2b0a08")))
	anchor.add_child(dot)

# Speed-adjusted timer: combat delays are divided by battle_speed so 2x plays twice as fast.
func _battle_delay(seconds: float) -> float:
	return seconds / battle_speed

func _haptic(kind: String) -> void:
	match kind:
		"tap": Input.vibrate_handheld(10)
		"shield": Input.vibrate_handheld(25)
		"hit": Input.vibrate_handheld(40)
		"heavy": Input.vibrate_handheld(75)
		_: Input.vibrate_handheld(15)

func _cycle_speed() -> void:
	var idx: int = BATTLE_SPEED_OPTIONS.find(battle_speed)
	idx = (idx + 1) % BATTLE_SPEED_OPTIONS.size()
	battle_speed = BATTLE_SPEED_OPTIONS[idx]
	profile.battle_speed = battle_speed
	SpiritSave.write(profile)
	show_battle()

func _pass_turn() -> void:
	if combat == null or combat.state.phase != "player" or resolving: return
	_toast(t("ui.no_playable"))
	await get_tree().create_timer(_battle_delay(0.28)).timeout
	if combat == null or combat.state.phase != "player": return
	await _enemy_turn()

# Keywords that may appear on cards and warrant a tap-to-explain tooltip.
const KEYWORD_KEYS: Array[String] = [
	"damage", "shield", "heal", "draw", "burn", "focus", "vulnerable",
	"weak", "strength", "pierce", "cleave", "critical", "stun", "energy",
	"echo", "siphon", "resonance", "poison",
]

# Bumps progress on every not-yet-complete quest of this type in both lists. Called from
# the same real signals the rest of the game already fires — a card played, a chest
# opened, a purchase made — rather than anything invented just for quests.
func _advance_quest(quest_type: String, amount: int) -> void:
	if amount <= 0: return
	# A permanent running total alongside the period-scoped quest progress below — this is
	# the only hook lifetime achievement stats need, since every real gameplay signal that
	# matters (a win, damage dealt, a chest opened, a purchase) already flows through here.
	if not profile.get("lifetime_stats") is Dictionary: profile.lifetime_stats = {}
	profile.lifetime_stats[quest_type] = int(profile.lifetime_stats.get(quest_type, 0)) + amount
	var any_completed := false
	for list_name in ["daily_quests", "weekly_quests"]:
		var list: Array = profile.get(list_name, [])
		for q in list:
			if str(q.get("type", "")) != quest_type or bool(q.get("claimed", false)): continue
			var target := int(q.get("target", 0))
			var before := int(q.get("progress", 0))
			if before >= target: continue
			q.progress = mini(target, before + amount)
			if int(q.progress) >= target and before < target: any_completed = true
	SpiritSave.write(profile)
	if any_completed: _toast(t("ui.quest_ready_toast"), GOLD)
	_refresh_achievements()

# Achievement progress readers, one per ACHIEVEMENTS "kind" — most kinds just read an existing
# permanent profile field directly (nothing to duplicate), "stat" is the one kind backed by
# the lifetime_stats counter _advance_quest() maintains above.
func _achievement_progress(ach: Dictionary) -> int:
	match str(ach.get("kind", "stat")):
		"stat": return int(profile.get("lifetime_stats", {}).get(str(ach.get("stat", "")), 0))
		"mastery_level":
			var best := 0
			for hero_id in profile.get("hero_masteries", {}):
				var xp: int = int(profile.hero_masteries[hero_id].get("xp", 0))
				best = maxi(best, content.mastery_level_for_xp(xp))
			return best
		"abyss_floor": return int(profile.get("abyss_record", 0))
		"daily_trial_badges": return int(profile.get("daily_trial_record", {}).get("badges", 0))
		"compendium_percent":
			var totals: Vector2i = _compendium_totals()
			return int(round(100.0 * float(totals.x) / maxf(1.0, float(totals.y))))
		"relic_count": return profile.get("relics", []).size()
		"card_collection": return profile.get("collection", {}).size()
		_: return 0

# Unlocks are permanent and one-time: once achievements_unlocked[id] is true it never gets
# re-evaluated, so a stat that could ever regress (nothing currently does) can't un-toast.
func _refresh_achievements() -> void:
	if not profile.get("achievements_unlocked") is Dictionary: profile.achievements_unlocked = {}
	var changed := false
	for ach in SpiritContent.ACHIEVEMENTS:
		var id: String = str(ach.id)
		if bool(profile.achievements_unlocked.get(id, false)): continue
		if _achievement_progress(ach) >= int(ach.target):
			profile.achievements_unlocked[id] = true
			changed = true
			_toast(tf("ui.achievement_unlocked_toast", content.ui(ach.nameKey, lang)), GOLD)
	if changed: SpiritSave.write(profile)

func _claim_quest(list_name: String, quest_id: String) -> void:
	var list: Array = profile.get(list_name, [])
	for q in list:
		if str(q.get("id", "")) != quest_id: continue
		if bool(q.get("claimed", false)) or int(q.get("progress", 0)) < int(q.get("target", 0)): return
		q.claimed = true
		profile.gold += int(q.get("reward", 0))
		SpiritSave.write(profile)
		_toast(tf("ui.quest_claimed_toast", int(q.get("reward", 0))), GOLD)
		show_quests()
		return

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
	if _handle_targeting(event): return
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
			_haptic("tap")
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

# Status readout as a coloured chip rather than loose text, so shield/burn/focus are
# distinguishable at a glance during a turn instead of needing to be read.
func _status_chip(glyph: String, amount: int, color: Color, height := 19.0) -> Panel:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(38.0, height)
	chip.size = chip.custom_minimum_size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(color.r * 0.32, color.g * 0.32, color.b * 0.32, 0.94), int(height / 2.0), color)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	var lbl := _label("%s%d" % [glyph, amount], int(height * 0.58), color, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(lbl)
	return chip

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

# Same medallion frame as _icon_badge, but drawing a GameIcon (a real little sword/shield/
# pendant silhouette) instead of a Unicode glyph in a label.
func _drawn_icon_badge(kind: String, flourish: String, color: Color, diameter := 44, frame_color := Color.TRANSPARENT) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.size = badge.custom_minimum_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
	style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	var icon := GameIcon.new()
	icon.kind = kind
	icon.flourish = flourish
	icon.icon_color = color
	icon.frame_color = frame_color
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := diameter * 0.16
	icon.offset_left += inset; icon.offset_top += inset; icon.offset_right -= inset; icon.offset_bottom -= inset
	badge.add_child(icon)
	return badge

func _equip_icon_badge(item: Dictionary, color: Color, diameter := 44) -> Panel:
	var item_id: String = str(item.get("id", ""))
	var icon_path := "res://assets/icons/equip_%s.png" % item_id
	if not item_id.is_empty() and ResourceLoader.exists(icon_path):
		var badge := Panel.new()
		badge.custom_minimum_size = Vector2(diameter, diameter)
		badge.size = badge.custom_minimum_size
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
		style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
		badge.add_theme_stylebox_override("panel", style)
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(tr)
		return badge
	return _drawn_icon_badge(str(item.get("icon_kind", "sword")), str(item.get("icon_flourish", "")), color, diameter)

func _rune_icon_badge(rune: Dictionary, color: Color, diameter := 36) -> Panel:
	var rune_id: String = str(rune.get("id", ""))
	var icon_path := "res://assets/icons/rune_%s.png" % rune_id
	if not rune_id.is_empty() and ResourceLoader.exists(icon_path):
		var badge := Panel.new()
		badge.custom_minimum_size = Vector2(diameter, diameter)
		badge.size = badge.custom_minimum_size
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
		style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
		badge.add_theme_stylebox_override("panel", style)
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(tr)
		return badge
	return _sigil_icon_badge(str(rune.get("icon_mark", "sparkle")), color, diameter)

func _sigil_icon_badge(mark: String, color: Color, diameter := 44) -> Panel:
	return _drawn_icon_badge("sigil", mark, color, diameter, color)

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
	map_music = AudioStreamPlayer.new(); map_music.stream = load("res://assets/audio/map_symphony.wav"); map_music.volume_db = -10; add_child(map_music)
	battle_music = AudioStreamPlayer.new(); battle_music.volume_db = -10; add_child(battle_music)
	battle_music_streams = [
		load("res://assets/audio/battle_stage_0.wav"),
		load("res://assets/audio/battle_stage_1.wav"),
		load("res://assets/audio/battle_stage_2.wav"),
		load("res://assets/audio/battle_stage_3.wav"),
		load("res://assets/audio/battle_stage_4.wav"),
	]
	map_music.finished.connect(func(): if not muted: map_music.play())
	battle_music.finished.connect(func(): if not muted: battle_music.play())

func _play_music(battle := false, stage_level: int = 0) -> void:
	if muted: return
	if battle:
		map_music.stop()
		var stream_idx: int = clampi(stage_level, 0, battle_music_streams.size() - 1)
		if battle_music_streams.size() > stream_idx and battle_music_streams[stream_idx] != null:
			var target_stream: AudioStream = battle_music_streams[stream_idx]
			if battle_music.stream != target_stream or not battle_music.playing:
				battle_music.stream = target_stream
				battle_music.play()
		else:
			if not battle_music.playing: battle_music.play()
	else:
		battle_music.stop()
		if not map_music.playing: map_music.play()

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
	stats.custom_minimum_size.x = 80
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(stats)
	return bar

func show_map() -> void:
	_clear(); _play_music(false)
	var backdrop := ColorRect.new(); backdrop.color = BG; backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop); root.move_child(backdrop,0)

	# The scroller fills the screen edge to edge; the bar and dock float over it, so the
	# artwork runs under the status bar and home indicator instead of being letterboxed.
	map_scroll = TouchScrollContainer.new()
	map_scroll.allow_vertical = true
	map_scroll.allow_horizontal = false
	map_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(map_scroll)

	var overlay_page := Control.new()
	overlay_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Stage pins and the traveller carry their own z_index (10 and 25), which outranks tree
	# order, so the floating bars need to sit above that — but below the toast layer at 500.
	overlay_page.z_index = 100
	root.add_child(overlay_page)

	var top_shade := _fade_strip(float(_safe_top()) + 74.0, false)
	top_shade.size = Vector2(MAP_WIDTH, float(_safe_top()) + 74.0)
	top_shade.modulate.a = 0.9
	overlay_page.add_child(top_shade)

	# Anchored by hand rather than with a preset: a preset resolves its offsets from the
	# minimum size at call time, which is zero before the children exist, and the parent is
	# a plain Control so nothing ever recomputes it — the bar collapses to an invisible strip.
	var header_holder := MarginContainer.new()
	header_holder.anchor_left = 0.0
	header_holder.anchor_right = 1.0
	header_holder.anchor_top = 0.0
	header_holder.anchor_bottom = 0.0
	header_holder.offset_left = 0.0
	header_holder.offset_right = 0.0
	header_holder.offset_top = 0.0
	header_holder.offset_bottom = float(_safe_top()) + 50.0
	header_holder.add_theme_constant_override("margin_top", _safe_top())
	header_holder.add_theme_constant_override("margin_left", 12)
	header_holder.add_theme_constant_override("margin_right", 12)
	header_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_page.add_child(header_holder)

	var header := _header("SPIRITBOUND", t("ui.choose_dest"))
	var btn_lang := _button(t("ui.lang_toggle"), _toggle_language, Color("17363e"), Vector2(44,34))
	btn_lang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(btn_lang)

	var btn_size := Vector2(36, 34)

	# Dedicated quest commissions entry point with custom quest icon and claimable notification dot
	var btn_quests := _button("", show_quests, Color("17363e"), btn_size)
	btn_quests.name = "QuestButton"
	btn_quests.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var quest_icon := GameIcon.new()
	quest_icon.kind = "quest"
	quest_icon.icon_color = GOLD
	quest_icon.custom_minimum_size = Vector2(20, 20)
	quest_icon.size = quest_icon.custom_minimum_size
	quest_icon.position = (btn_size - quest_icon.size) / 2.0
	quest_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_quests.add_child(quest_icon)
	if _has_claimable_quest(): _add_notification_dot(btn_quests, btn_size)
	header.add_child(btn_quests)

	# Dedicated explorer camp / dossier & relics entry point
	var btn_camp := _button("", show_camp, Color("17363e"), btn_size)
	btn_camp.name = "CampButton"
	btn_camp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var camp_icon := GameIcon.new()
	camp_icon.kind = "profile"
	camp_icon.icon_color = GOLD
	camp_icon.custom_minimum_size = Vector2(20, 20)
	camp_icon.size = camp_icon.custom_minimum_size
	camp_icon.position = (btn_size - camp_icon.size) / 2.0
	camp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_camp.add_child(camp_icon)
	header.add_child(btn_camp)

	var btn_music := _button("♫" if not muted else "♩", _toggle_music, Color("17363e"), Vector2(32,34))
	btn_music.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(btn_music)

	var btn_settings := _button("⚙", show_settings, Color("17363e"), Vector2(32, 34))
	btn_settings.name = "SettingsButton"
	btn_settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(btn_settings)
	header_holder.add_child(header)

	var stage_count: int = content.encounters.size()
	var chapter_count: int = stage_count / 5
	map_canvas = Control.new()
	map_canvas.custom_minimum_size = Vector2(MAP_WIDTH, BAND_HEIGHT * float(chapter_count))
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	map_scroll.add_child(map_canvas)
	for chapter in chapter_count: _add_map_chapter(chapter)
	_add_region_borders(chapter_count)
	_add_routes()
	for index in stage_count: _add_stage_pin(index)
	_add_map_ambience()

	traveler = Sprite2D.new()
	var current_hero: Dictionary = content.hero_class(str(profile.get("hero_class", "fox_spirit")))
	traveler.texture = _get_character_texture(str(current_hero.get("sprite", "fox")))
	traveler.scale = Vector2(40.0 / 341.33, 40.0 / 341.33)
	traveler.position = _map_point(profile.position) - Vector2(0, 26)
	traveler.z_index = 25
	map_canvas.add_child(traveler)

	var t_idle := traveler.create_tween().set_loops()
	t_idle.tween_property(traveler, "position:y", traveler.position.y - 4.0, 0.75).set_trans(Tween.TRANS_SINE)
	t_idle.tween_property(traveler, "position:y", traveler.position.y + 2.0, 0.85).set_trans(Tween.TRANS_SINE)

	var dock_holder := MarginContainer.new()
	dock_holder.anchor_left = 0.0
	dock_holder.anchor_right = 1.0
	dock_holder.anchor_top = 1.0
	dock_holder.anchor_bottom = 1.0
	dock_holder.offset_left = 0.0
	dock_holder.offset_right = 0.0
	dock_holder.offset_top = -(float(_safe_bottom()) + 60.0)
	dock_holder.offset_bottom = 0.0
	dock_holder.add_theme_constant_override("margin_bottom", _safe_bottom())
	dock_holder.add_theme_constant_override("margin_left", 12)
	dock_holder.add_theme_constant_override("margin_right", 12)
	dock_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_page.add_child(dock_holder)

	var dock_bg := PanelContainer.new()
	dock_bg.add_theme_stylebox_override("panel", _panel(Color(0.047, 0.102, 0.122, 0.94), 26, Color("1f404d")))
	dock_holder.add_child(dock_bg)

	var dock := HBoxContainer.new()
	dock.custom_minimum_size.y = 52
	dock.add_theme_constant_override("separation", 0)
	dock.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_bg.add_child(dock)

	# Each dock slot pairs a drawn GameIcon (a real little glyph, not a font character doing
	# double duty) with the button's own text label pushed onto a second line beneath it —
	# the leading "\n" reserves that top line for the icon instead of drawing over it.
	var items = [
		["card_stack", "ui.deck_btn", show_deck],
		["shield", "ui.equip_btn", show_loadout],
		["coin_stack", "ui.shop_btn", show_shop],
		["arrow", "ui.next_btn", _next_stage]
	]

	for i in items.size():
		var item = items[i]
		var btn := Button.new()
		btn.text = "\n" + t(item[1])
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
		btn.pressed.connect(item[2])

		var icon := GameIcon.new()
		icon.kind = str(item[0])
		icon.icon_color = GOLD
		icon.custom_minimum_size = Vector2(20, 20)
		icon.size = icon.custom_minimum_size
		icon.anchor_left = 0.5; icon.anchor_right = 0.5
		icon.offset_left = -10.0; icon.offset_right = 10.0
		icon.offset_top = 8.0; icon.offset_bottom = 28.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

		# The deck slot gets the same "something to check in here" red dot whenever the
		# player owns a card copy that isn't in their current deck — cards obtained from a
		# reward chest or bought in the shop used to just sit in the collection unannounced.
		if str(item[0]) == "card_stack" and _has_unused_cards():
			var dot := Panel.new()
			dot.name = "NotificationDot"
			dot.anchor_left = 1.0; dot.anchor_right = 1.0
			dot.anchor_top = 0.0; dot.anchor_bottom = 0.0
			dot.offset_left = -20.0; dot.offset_right = -7.0
			dot.offset_top = 6.0; dot.offset_bottom = 19.0
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.z_index = 5
			dot.add_theme_stylebox_override("panel", _panel(EMBER, 7, Color("2b0a08")))
			btn.add_child(dot)

		dock.add_child(btn)

	await get_tree().process_frame
	if map_scroll: map_scroll.scroll_vertical = int(maxi(0, int(_map_point(profile.position).y - 360)))

# Every chapter used to reuse the exact same five pixel offsets, so the trail looked like a
# mechanical zigzag repeated 50 times. This walks a seeded random x each chapter instead —
# deterministic (same shape every time you view that chapter, no state to save) but no
# longer identical band to band.
func _chapter_waypoints(chapter: int) -> Array:
	if _map_waypoint_cache.has(chapter): return _map_waypoint_cache[chapter]
	# The road has to trace the trail actually painted into this chapter's background, not a
	# random walk — see BIOME_PATH_WAYPOINTS. _add_map_chapter flips the same background
	# horizontally every second time a biome repeats (chapter/6 odd); mirror the path to
	# match or the road runs straight over rocks and trees instead of the trail.
	var biome_idx: int = chapter % BIOME_PATH_WAYPOINTS.size()
	var flipped: bool = (chapter / BIOME_PATH_WAYPOINTS.size()) % 2 == 1
	var base_points: Array = BIOME_PATH_WAYPOINTS[biome_idx]
	var points: Array = []
	for p in base_points:
		var x: float = (MAP_WIDTH - p.x) if flipped else p.x
		points.append(Vector2(x, p.y))
	_map_waypoint_cache[chapter] = points
	return points

func _map_point(index: int) -> Vector2:
	var waypoints: Array = _chapter_waypoints(index / 5)
	var node: Vector2 = waypoints[index % 5]
	return Vector2(node.x, float(index / 5) * BAND_HEIGHT + node.y)

# Fits a smooth curve through exact waypoints (a Catmull-Rom-style spline expressed as
# per-point cubic Bezier handles) rather than the straight segments Line2D draws by default
# between raw points — this is what turns the trail from a zigzag into something that reads
# as a wandering path.
func _build_road_curve(points: PackedVector2Array) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = 6.0
	var n := points.size()
	for i in n:
		var prev: Vector2 = points[maxi(0, i - 1)]
		var next: Vector2 = points[mini(n - 1, i + 1)]
		var tangent: Vector2 = (next - prev) / 6.0
		var handle_in: Vector2 = Vector2.ZERO if i == 0 else -tangent
		var handle_out: Vector2 = Vector2.ZERO if i == n - 1 else tangent
		curve.add_point(points[i], handle_in, handle_out)
	return curve

# A small tileable dirt-road pattern generated at runtime — there is no bitmap art for a
# road, and FastNoiseLite's seamless output tiles along a Line2D's length for free.
func _get_road_texture() -> NoiseTexture2D:
	if _road_texture != null: return _road_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.12
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.generate_mipmaps = false
	tex.width = 64
	tex.height = 16
	tex.noise = noise
	_road_texture = tex
	return tex

# A soft radial glow for the ambient particles — GradientTexture2D's radial fill gives a
# clean falloff with no bitmap asset.
func _get_mote_texture() -> GradientTexture2D:
	if _mote_texture != null: return _mote_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.9))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 24
	tex.height = 24
	_mote_texture = tex
	return tex

# Fixed to the screen rather than the scrolling map canvas, so the atmosphere reads as
# weather over the whole view instead of specks pinned to particular map coordinates.
func _add_map_ambience() -> void:
	var current_chapter: int = int(profile.unlocked / 5)
	var biome_idx: int = current_chapter % 6

	var motes := CPUParticles2D.new()
	motes.name = "MapAmbienceParticles"
	motes.texture = _get_mote_texture()
	motes.position = Vector2(MAP_WIDTH / 2.0, 844.0 / 2.0)
	motes.amount = 24
	motes.lifetime = 6.5
	motes.preprocess = 6.5
	motes.emitting = not bool(profile.get("reduce_motion", false))
	motes.z_index = 90
	motes.local_coords = true
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(MAP_WIDTH / 2.0, 844.0 / 2.0)

	match biome_idx:
		0: # Mistwood: gentle green drifting spores
			motes.direction = Vector2(0.2, -1.0)
			motes.spread = 30.0
			motes.gravity = Vector2.ZERO
			motes.initial_velocity_min = 6.0
			motes.initial_velocity_max = 14.0
			motes.color = Color(0.70, 0.95, 0.80, 0.55)
		1: # Ashlands / Ember Canyon: warm rising fire sparks
			motes.direction = Vector2(0.1, -1.0)
			motes.spread = 20.0
			motes.gravity = Vector2(0, -10.0)
			motes.initial_velocity_min = 15.0
			motes.initial_velocity_max = 35.0
			motes.color = Color(1.0, 0.55, 0.22, 0.70)
		2: # Glacial Pass / Frost Peaks: falling snow crystals
			motes.direction = Vector2(0.15, 1.0)
			motes.spread = 40.0
			motes.gravity = Vector2(0, 14.0)
			motes.initial_velocity_min = 10.0
			motes.initial_velocity_max = 24.0
			motes.color = Color(0.85, 0.95, 1.0, 0.65)
		3: # Starfall Sanctuary: sparkling stardust
			motes.direction = Vector2(0.0, -0.5)
			motes.spread = 180.0
			motes.gravity = Vector2.ZERO
			motes.initial_velocity_min = 4.0
			motes.initial_velocity_max = 10.0
			motes.color = Color(0.95, 0.85, 1.0, 0.60)
		4: # Sunken Marsh: floating algae bubbles
			motes.direction = Vector2(-0.2, -1.0)
			motes.spread = 25.0
			motes.gravity = Vector2(0, -4.0)
			motes.initial_velocity_min = 5.0
			motes.initial_velocity_max = 12.0
			motes.color = Color(0.45, 0.92, 0.75, 0.55)
		5: # Abyssal Rift: void motes
			motes.direction = Vector2(0.0, -1.0)
			motes.spread = 35.0
			motes.gravity = Vector2(0, -8.0)
			motes.initial_velocity_min = 10.0
			motes.initial_velocity_max = 22.0
			motes.color = Color(0.75, 0.40, 1.0, 0.65)

	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.4

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 1.0))
	ramp.add_point(0.85, Color(1, 1, 1, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	motes.color_ramp = ramp
	root.add_child(motes)

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

	# A painted gradient wash stands in for the old stock photography: it can never look
	# "pasted on" over the vector road, because it is built from the same vector language as
	# everything drawn on top of it, instead of a rectangle of unrelated pixels underneath it.
	var wash := TextureRect.new()
	wash.texture = _get_terrain_wash_texture(chapter % CHAPTER_TINTS.size())
	wash.size = Vector2(MAP_WIDTH, BAND_HEIGHT)
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(wash)

	var grain := TextureRect.new()
	grain.texture = _get_terrain_grain_texture()
	grain.size = Vector2(MAP_WIDTH, BAND_HEIGHT)
	grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode = TextureRect.STRETCH_TILE
	grain.modulate = Color(1, 1, 1, 0.14)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(grain)

	var biome_tex: Texture2D = _get_chapter_map_texture(chapter)
	if biome_tex != null:
		var painted_tile := TextureRect.new()
		painted_tile.texture = biome_tex
		painted_tile.size = Vector2(MAP_WIDTH, BAND_HEIGHT)
		painted_tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painted_tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		# Apply chapter-specific regional atmospheric tint and alternating flip for unique visual identity
		painted_tile.modulate = Color.WHITE.lerp(tint, 0.35)
		painted_tile.flip_h = ((chapter / 6) % 2 == 1)
		painted_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(painted_tile)

	_add_terrain_dressing(band, chapter, tint)

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

# A soft vertical gradient in the chapter's own tint, darker at the seams than in the middle —
# cached per tint index since there are only ten tints shared across fifty chapters.
func _get_terrain_wash_texture(tint_index: int) -> GradientTexture2D:
	if _terrain_wash_cache.has(tint_index): return _terrain_wash_cache[tint_index]
	var tint: Color = CHAPTER_TINTS[tint_index]
	var gradient := Gradient.new()
	gradient.set_color(0, tint.darkened(0.55))
	gradient.add_point(0.45, tint.darkened(0.2))
	gradient.add_point(0.55, tint.darkened(0.2))
	gradient.set_color(gradient.get_point_count() - 1, tint.darkened(0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 128
	_terrain_wash_cache[tint_index] = tex
	return tex

# Low-frequency seamless noise, tiled at very low opacity over the wash so a band reads as
# painted terrain instead of a flat colour swatch. One instance is shared by every chapter.
func _get_terrain_grain_texture() -> NoiseTexture2D:
	if _terrain_grain_texture != null: return _terrain_grain_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.generate_mipmaps = false
	tex.width = 128
	tex.height = 128
	tex.noise = noise
	_terrain_grain_texture = tex
	return tex

# Scatters a handful of small vector pine/boulder/hill silhouettes across the band, testing
# each candidate spot against the chapter's own baked road curve so nothing is ever placed on
# or overlapping the path — this is what makes the terrain read as belonging to the road
# instead of a picture that happens to have a line drawn over it.
func _add_terrain_dressing(band: Control, chapter: int, tint: Color) -> void:
	var waypoints: Array = _chapter_waypoints(chapter)
	var curve := _build_road_curve(PackedVector2Array(waypoints))
	var baked: PackedVector2Array = curve.get_baked_points()
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter * 51797 + 5
	var deco_color: Color = tint.darkened(0.1)
	var kinds := ["pine", "boulder", "hill"]
	var placed := 0
	var attempts := 0
	while placed < 9 and attempts < 60:
		attempts += 1
		var p := Vector2(rng.randf_range(20.0, MAP_WIDTH - 20.0), rng.randf_range(ROAD_TOP_CLEAR, BAND_HEIGHT - 40.0))
		var clear := true
		for bp in baked:
			if p.distance_to(bp) < 32.0: clear = false; break
		if not clear: continue
		var deco := GameIcon.new()
		deco.kind = kinds[rng.randi_range(0, kinds.size() - 1)]
		deco.icon_color = deco_color
		var deco_size: float = rng.randf_range(26.0, 46.0)
		deco.custom_minimum_size = Vector2(deco_size, deco_size)
		deco.size = deco.custom_minimum_size
		deco.pivot_offset = deco.size / 2.0
		deco.position = p - deco.size / 2.0
		deco.rotation = rng.randf_range(-0.12, 0.12)
		deco.modulate.a = rng.randf_range(0.2, 0.35)
		deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(deco)
		placed += 1

# A hand-drawn-looking jagged seam between every pair of consecutive chapters, on top of the
# soft fade already blending them — the reference art reads as distinct territories meeting
# at a border, not one image dissolving into the next.
func _add_region_borders(chapter_count: int) -> void:
	for chapter in chapter_count - 1:
		var y := float(chapter + 1) * BAND_HEIGHT
		var tint_a: Color = CHAPTER_TINTS[chapter % CHAPTER_TINTS.size()]
		var tint_b: Color = CHAPTER_TINTS[(chapter + 1) % CHAPTER_TINTS.size()]
		var rng := RandomNumberGenerator.new()
		rng.seed = chapter * 7307 + 3
		var pts := PackedVector2Array()
		var steps := 10
		for i in steps + 1:
			var x: float = MAP_WIDTH * float(i) / float(steps)
			var jitter: float = 0.0 if i == 0 or i == steps else rng.randf_range(-16.0, 16.0)
			pts.append(Vector2(x, y + jitter))
		var border := Line2D.new()
		border.points = pts
		border.width = 2.5
		border.default_color = tint_a.lerp(tint_b, 0.5).darkened(0.55)
		border.default_color.a = 0.6
		border.z_index = 0
		border.antialiased = true
		map_canvas.add_child(border)

# Straight segments between waypoints read as a mechanical zigzag; baking a Catmull-Rom
# curve through the exact same points gives a road that curves the way a real trail would,
# without moving where any stage pin actually sits.
func _add_routes() -> void:
	var all_points := PackedVector2Array()
	var walked_points := PackedVector2Array()
	for index in content.encounters.size():
		var point := _map_point(index)
		all_points.append(point)
		if index <= int(profile.unlocked): walked_points.append(point)

	var road_bed := Line2D.new()
	road_bed.width = 22.0
	road_bed.default_color = Color(0.16, 0.11, 0.07, 0.5)
	road_bed.z_index = 1
	road_bed.joint_mode = Line2D.LINE_JOINT_ROUND
	road_bed.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road_bed.end_cap_mode = Line2D.LINE_CAP_ROUND
	road_bed.points = _build_road_curve(all_points).get_baked_points()
	map_canvas.add_child(road_bed)

	var trail := Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(0.62, 0.5, 0.34, 0.62)
	trail.texture = _get_road_texture()
	trail.texture_mode = Line2D.LINE_TEXTURE_TILE
	trail.z_index = 2
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.points = road_bed.points
	map_canvas.add_child(trail)

	if walked_points.size() > 1:
		var walked := Line2D.new()
		walked.width = 6.0
		walked.default_color = Color(0.55, 0.93, 0.79, 0.85)
		walked.z_index = 3
		walked.joint_mode = Line2D.LINE_JOINT_ROUND
		walked.begin_cap_mode = Line2D.LINE_CAP_ROUND
		walked.end_cap_mode = Line2D.LINE_CAP_ROUND
		walked.points = _build_road_curve(walked_points).get_baked_points()
		map_canvas.add_child(walked)

# (kind, flourish) for the drawn GameIcon on a map pin, keyed by node_kind().
func _stage_icon_shape(index: int) -> Array:
	match content.node_kind(index):
		"greatboss": return ["grand_crown", ""]
		"boss": return ["crown", ""]
		"elite": return ["none", "sparkle"]
		"event": return ["orb", ""]
		"merchant": return ["coin_stack", ""]
		"rest": return ["campfire", ""]
		_: return ["crossed_swords", ""]

func _add_stage_pin(index: int) -> void:
	var encounter: Dictionary = content.encounters[index]
	var point := _map_point(index)
	var locked := index > int(profile.unlocked)
	var is_current := index == int(profile.position)
	var kind := content.node_kind(index)
	var is_boss := content.is_boss_kind(kind)
	var is_great: bool = kind == "greatboss"

	var pin_size := Vector2(62.0, 54.0)
	if is_boss: pin_size = Vector2(84.0, 72.0) if is_great else Vector2(72.0, 62.0)
	var bg_color := Color("18414a")
	var border_color := JADE
	match kind:
		"greatboss": bg_color = Color("6b1f1f"); border_color = Color("ff5a4a")
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

	# A map-marker reads as "planted at this exact spot" through a shadow on the ground and a
	# tail pointing down at it, not by centering a badge on the point — so the badge sits
	# above `point` and only the tail's tip actually touches it.
	var tail_height := 11.0
	var badge_bottom_y := point.y - tail_height

	var shadow := Panel.new()
	shadow.custom_minimum_size = Vector2(30.0, 9.0)
	shadow.size = shadow.custom_minimum_size
	shadow.position = point - shadow.size / 2.0
	shadow.z_index = 1
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", _panel(Color(0, 0, 0, 0.4), 5))
	map_canvas.add_child(shadow)

	var tail := Polygon2D.new()
	var tail_half_w: float = pin_size.x * 0.15
	tail.polygon = PackedVector2Array([
		Vector2(point.x - tail_half_w, badge_bottom_y - 2.0),
		Vector2(point.x + tail_half_w, badge_bottom_y - 2.0),
		Vector2(point.x, point.y),
	])
	tail.color = bg_color
	tail.z_index = 9
	map_canvas.add_child(tail)

	var pin := Button.new()
	pin.custom_minimum_size = pin_size
	pin.size = pin_size
	pin.position = Vector2(point.x - pin_size.x / 2.0, badge_bottom_y - pin_size.y)
	pin.disabled = locked
	pin.z_index = 10
	pin.focus_mode = Control.FOCUS_NONE
	pin.add_theme_stylebox_override("normal", _panel(bg_color, 16, border_color))
	pin.add_theme_stylebox_override("hover", _panel(bg_color.lightened(0.12), 16, EMBER))
	pin.add_theme_stylebox_override("pressed", _panel(bg_color.darkened(0.15), 16, GOLD))
	pin.add_theme_stylebox_override("disabled", _panel(bg_color, 16, Color("2b393d")))
	pin.pressed.connect(func(): _on_pin_pressed(index))
	map_canvas.add_child(pin)

	if _map_pin_rune_tex == null: _map_pin_rune_tex = load("res://assets/map_pin_rune.png")
	var rune_overlay := TextureRect.new()
	rune_overlay.texture = _map_pin_rune_tex
	rune_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rune_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rune_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rune_overlay.modulate = Color(border_color.r, border_color.g, border_color.b, 0.75 if not locked else 0.35)
	rune_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(rune_overlay)

	var pin_stack := VBoxContainer.new()
	pin_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pin_stack.add_theme_constant_override("separation", -1)
	pin_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	pin_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(pin_stack)
	if locked:
		pin_stack.add_child(_label("🔒", 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var icon_size := 26.0
		if is_boss: icon_size = 38.0 if is_great else 30.0
		var shape: Array = _stage_icon_shape(index)
		var stage_icon := GameIcon.new()
		stage_icon.kind = str(shape[0])
		stage_icon.flourish = str(shape[1])
		stage_icon.icon_color = border_color
		stage_icon.custom_minimum_size = Vector2(icon_size, icon_size)
		stage_icon.size = stage_icon.custom_minimum_size
		var icon_holder := CenterContainer.new()
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(stage_icon)
		pin_stack.add_child(icon_holder)
	pin_stack.add_child(_label("%d-%d" % [encounter.chapter, encounter.level], 14 if is_boss else 12, TEXT if not locked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if is_boss and not locked:
		pin_stack.add_child(_label(t("ui.node_greatboss") if is_great else t("ui.node_boss"), 9, border_color, HORIZONTAL_ALIGNMENT_CENTER))

	if is_current and not locked:
		var halo := pin.create_tween().set_loops()
		halo.tween_property(pin, "modulate", Color(1.25, 1.12, 0.95), 0.85).set_trans(Tween.TRANS_SINE)
		halo.tween_property(pin, "modulate", Color.WHITE, 0.85).set_trans(Tween.TRANS_SINE)

	var caption := _label(content.waypoint_name(index % 5, lang) if not locked else t("ui.locked"), 10, TEXT if not locked else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.size = Vector2(112.0, 16.0)
	caption.position = Vector2(point.x - 56.0, point.y + 6.0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(caption)

func _travel_to(index: int) -> void:
	if index > int(profile.unlocked): return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(traveler, "position", _map_point(index) - Vector2(0, 26), 0.65)
	for value in range(int(profile.position), index + 1):
		tween.parallel().tween_method(func(y): map_scroll.scroll_vertical = int(y), float(map_scroll.scroll_vertical), float(maxi(0, int(_map_point(index).y - 360))), 0.65)
	await tween.finished; profile.position = index; SpiritSave.write(profile)
	var kind := content.node_kind(index)
	if kind in ["event","merchant","rest"] and not _is_stage_event_claimed(index) and not _is_replay(index):
		show_event(index, kind)
	else:
		begin_battle(index)

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
	if is_hard_replay:
		active_modifier = {
			"id": "trial_hard",
			"name": "试炼强化",
			"name_en": "Trial Hard",
			"detail": "敌人生命 +25%，攻击 +2，恢复全额掉落",
			"detail_en": "Enemy HP +25%, ATK +2, Full Drops",
			"health_scale": 1.25,
			"damage_bonus": 2,
			"reward_scale": 1.0
		}
	else:
		active_modifier = _modifier(seed, index)
	combat = SpiritCombat.new(content)
	var equipped: Array = profile.equipment_slots.values()
	combat.create(seed,content.encounters[index],profile.deck,int(profile.health),profile.upgrades,equipped,profile.card_runes,active_modifier,profile.relics,_current_hero_mastery_bonuses())
	combat.event.connect(_combat_event)
	_mark_discovered("bestiary", str(content.encounters[index].name))
	pre_battle_health = int(profile.health)
	advancing_to_reward = false
	selected_card = -1
	show_battle()
	if index == 0 and not bool(profile.get("tutorial_seen", false)): _show_battle_tutorial()
	_maybe_end_turn()

func show_battle() -> void:
	var encounter: Dictionary = _current_encounter()
	var stage_lvl: int = int(encounter.get("level", 1)) - 1
	_clear(); _play_music(true, stage_lvl); enemy_boxes.clear()
	var bg := _background(BATTLE_BACKGROUNDS[encounter.background],.28); root.add_child(bg); root.move_child(bg,0)
	var page := _create_page(4)

	var top := HBoxContainer.new(); top.custom_minimum_size.y = 44
	top.add_child(_label("%d-%d  %s" % [encounter.chapter,encounter.level,_current_stage_label()], 13, JADE))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer)
	top.add_child(_label(tf("ui.turn_n", combat.state.turn), 11, GOLD))
	var speed_label: String = (str(int(battle_speed)) if battle_speed == float(int(battle_speed)) else str(battle_speed)) + "x"
	var speed_btn := _button(speed_label, _cycle_speed, Color("1a3a42"), Vector2(44, 28))
	speed_btn.name = "SpeedToggle"
	speed_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(speed_btn)
	var leave_btn := _button("⌂", _leave_battle, Color("17363e"), Vector2(36,34))
	leave_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(leave_btn); page.add_child(top)

	if not active_modifier.is_empty() or not combat.state.equipment.is_empty() or not profile.relics.is_empty():
		var badge_row := HBoxContainer.new()
		badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
		badge_row.add_theme_constant_override("separation", 8)
		page.add_child(badge_row)

		if not active_modifier.is_empty():
			var m_name: String = active_modifier.name_en if lang == "en" else active_modifier.name
			var m_det: String = active_modifier.detail_en if lang == "en" else active_modifier.detail
			var mod_badge := _icon_badge("✥", Color("ffe2b0"), 34, 16)
			badge_row.add_child(_tap_wrap(mod_badge, func(): _show_info_popup(_icon_badge("✥", Color("ffe2b0"), 60, 26), m_name, m_det, EMBER)))

		for id in combat.state.equipment:
			var item := content.equipment(id)
			if item.is_empty(): continue
			var e_name: String = _equip_name(item)
			var e_det: String = _equip_detail(item)
			var e_badge := _equip_icon_badge(item, GOLD, 34)
			badge_row.add_child(_tap_wrap(e_badge, func(): _show_info_popup(_equip_icon_badge(item, GOLD, 60), e_name, e_det, GOLD)))

		for id in profile.relics:
			var relic := content.relic(id)
			if relic.is_empty(): continue
			var r_color := Color(relic.color)
			var r_name: String = _relic_name(relic)
			var r_det: String = _relic_detail(relic)
			var r_badge := _sigil_icon_badge(str(relic.get("icon_mark", "sparkle")), r_color, 34)
			badge_row.add_child(_tap_wrap(r_badge, func(): _show_info_popup(_sigil_icon_badge(str(relic.get("icon_mark", "sparkle")), r_color, 60), r_name, r_det, r_color)))

	var enemy_area := Control.new()
	enemy_area.custom_minimum_size = Vector2(366.0, 205.0)
	enemy_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_area.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(enemy_area)

	# A flat row reads fine for one or two enemies, but three or more in a straight line
	# looks like a spreadsheet. Fan them out around the centre instead: the middle slot is
	# "front" (full size, lowest), and slots further from centre step back and up, like a
	# loose wedge formation instead of a queue.
	var living_indices: Array = []
	for index in combat.state.enemies.size():
		if combat.state.enemies[index].health > 0: living_indices.append(index)
	var slot_count: int = maxi(1, combat.state.enemies.size())
	var u_width: float = minf(112.0, (366.0 - 10.0 * float(slot_count - 1)) / float(slot_count))
	var gap := 10.0
	var living_n := living_indices.size()
	var total_w: float = float(living_n) * u_width + float(maxi(0, living_n - 1)) * gap
	var start_x: float = (366.0 - total_w) / 2.0
	var center_slot: float = float(living_n - 1) / 2.0
	for order in living_n:
		var enemy_index: int = living_indices[order]
		var dist: float = absf(float(order) - center_slot)
		var depth_t: float = 0.0 if center_slot <= 0.0 else dist / center_slot
		var box := _enemy_view(enemy_index, depth_t)
		box.position = Vector2(start_x + float(order) * (u_width + gap), -depth_t * 26.0)
		box.z_index = 20 - int(round(depth_t * 8.0))
		enemy_area.add_child(box)
		enemy_boxes.append(box)

	var push_down := Control.new()
	push_down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(push_down)

	page.add_child(_build_player_stage())

	if combat.state.phase == "player":
		_add_hand(page)
	else:
		var won: bool = combat.state.phase == "won"
		var outcome := _label(t("ui.battle_won") if won else t("ui.battle_lost"), 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		outcome.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page.add_child(outcome)
		if won:
			# Straight through to the chest. This used to be a button labelled "open chest"
			# that led to a screen with another button labelled "open chest".
			_advance_to_reward()
		else:
			page.add_child(_button(t("ui.return_map"), _leave_battle, EMBER, Vector2(0, 50)))

func _intent_style(intent: Dictionary) -> Dictionary:
	var kind := str(intent.get("kind", "attack"))
	var amount := int(intent.get("amount", 0))
	# "text" (with its symbol) still goes into toasts, which have no room for a drawn icon;
	# "amount_text" is the plain number the banner shows next to the icon instead.
	match kind:
		"critical":
			return {"text": tf("ui.intent_critical", amount), "amount_text": str(amount), "bg": Color("8c2f19"), "border": Color("ff8d5c"), "text_color": Color("ffe1c9")}
		"defend":
			return {"text": tf("ui.intent_defend", amount), "amount_text": str(amount), "bg": Color("15364f"), "border": Color("7fb8e8"), "text_color": Color("d6ecff")}
		"empower":
			return {"text": tf("ui.intent_empower", amount), "amount_text": "+%d" % amount, "bg": Color("3a1f52"), "border": Color("c79bff"), "text_color": Color("ecdcff")}
		"curse":
			return {"text": tf("ui.intent_curse", amount), "amount_text": str(amount), "bg": Color("2f4420"), "border": Color("a8dd6c"), "text_color": Color("e2f7c6")}
		"attack_defend":
			return {"text": tf("ui.intent_attack_defend", [amount, int(intent.get("shield", 0))]), "amount_text": "%d/%d" % [amount, int(intent.get("shield", 0))], "bg": Color("4a2a1c"), "border": Color("e0a878"), "text_color": Color("ffe7d2")}
		_:
			return {"text": tf("ui.intent_attack", amount), "amount_text": str(amount), "bg": Color(0.29, 0.11, 0.07, 0.92), "border": Color("e39761"), "text_color": Color("ffe1c9")}

func _get_hit_flash_shader() -> Shader:
	if _hit_flash_shader == null: _hit_flash_shader = load("res://assets/shaders/hit_flash.gdshader")
	return _hit_flash_shader

func _get_card_foil_shader() -> Shader:
	if _card_foil_shader == null and ResourceLoader.exists("res://assets/shaders/card_foil.gdshader"):
		_card_foil_shader = load("res://assets/shaders/card_foil.gdshader")
	return _card_foil_shader

func _apply_card_foil(node: CanvasItem, rarity: String, upgraded: bool) -> void:
	if rarity == "Rare" or upgraded:
		var s := _get_card_foil_shader()
		if s:
			var mat := ShaderMaterial.new()
			mat.shader = s
			node.material = mat

# One shader material per sprite so a mid-flash overlap on one enemy never disturbs another.
func _install_hit_flash(sprite: CanvasItem) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_hit_flash_shader()
	sprite.material = mat
	return mat

func _flash_hit(sprite: CanvasItem, color := Color.WHITE, duration := 0.22) -> void:
	if sprite.material == null or not (sprite.material is ShaderMaterial): _install_hit_flash(sprite)
	var mat: ShaderMaterial = sprite.material
	mat.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("flash_amount", 1.0)
	var tween := sprite.create_tween()
	tween.tween_method(func(v): mat.set_shader_parameter("flash_amount", v), 1.0, 0.0, duration).set_trans(Tween.TRANS_QUAD)

# Squash-and-stretch impact: a fast non-uniform scale punch (wide+short) rather than a
# uniform scale bump — this is the single technique animation references cite most often
# for making a static sprite read as reacting to a hit instead of just wobbling.
func _squash_impact(sprite: Node2D, base_scale: float, strength := 0.22, duration := 0.22) -> void:
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(base_scale * (1.0 + strength), base_scale * (1.0 - strength)), duration * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(base_scale * (1.0 - strength * 0.4), base_scale * (1.0 + strength * 0.4)), duration * 0.32).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "scale", Vector2.ONE * base_scale, duration * 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# A soft halo behind a sprite for a status that has no natural "shape" of its own — shield
# and vulnerable both read as an aura, just in different colours and animation.
func _status_halo(size: Vector2, color: Color, pulsing: bool) -> Panel:
	var halo := Panel.new()
	halo.custom_minimum_size = size
	halo.size = size
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(color.r, color.g, color.b, 0.16), int(size.y / 2.0), Color(color, 0.75))
	style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
	halo.add_theme_stylebox_override("panel", style)
	if pulsing:
		var pulse := halo.create_tween().set_loops()
		pulse.tween_property(halo, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(halo, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	return halo

func _get_ember_texture() -> GradientTexture2D:
	if _ember_texture != null: return _ember_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.85, 0.4, 0.95))
	gradient.set_color(1, Color(1, 0.3, 0.1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 16
	tex.height = 16
	_ember_texture = tex
	return tex

func _burn_embers(size: Vector2) -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.name = "BurnFx"
	embers.texture = _get_ember_texture()
	embers.position = size / 2.0
	embers.amount = 8
	embers.lifetime = 1.1
	embers.emitting = true
	embers.local_coords = true
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(size.x * 0.35, size.y * 0.15)
	embers.direction = Vector2(0, -1)
	embers.spread = 20.0
	embers.gravity = Vector2(0, -18)
	embers.initial_velocity_min = 14.0
	embers.initial_velocity_max = 26.0
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.0
	return embers

# Three small sparks orbiting the head — the classic "seeing stars" stun read, drawn rather
# than requiring an animated sprite sheet.
class DizzyStars extends Control:
	var t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)
	func _process(delta: float) -> void:
		t += delta * 3.2
		queue_redraw()
	func _draw() -> void:
		var c := Vector2(size.x, size.y) / 2.0
		var r := size.x * 0.42
		for i in 3:
			var a: float = t + TAU * float(i) / 3.0
			var p := c + Vector2(cos(a), sin(a) * 0.5) * r
			var pts := PackedVector2Array()
			for k in 8:
				var rad := r * 0.16 if k % 2 == 0 else r * 0.32
				var aa: float = TAU * float(k) / 8.0
				pts.append(p + Vector2(cos(aa), sin(aa)) * rad)
			draw_colored_polygon(pts, Color(1.0, 0.9, 0.5, 0.9))

# Reads the current status values straight off the enemy/player dict and attaches whichever
# visual effects apply — called once per rebuild, so no state to track between frames.
func _apply_status_fx(unit: Control, sprite: Node2D, sprite_center: Vector2, sprite_radius: float, state: Dictionary) -> void:
	if int(state.get("shield", 0)) > 0:
		var halo := _status_halo(Vector2.ONE * sprite_radius * 2.3, Color("6fc7ff"), false)
		halo.position = sprite_center - Vector2.ONE * sprite_radius * 1.15
		unit.add_child(halo)
		unit.move_child(halo, 0)
	if int(state.get("vulnerable", 0)) > 0:
		var halo := _status_halo(Vector2.ONE * sprite_radius * 2.2, Color("ff6a5c"), true)
		halo.position = sprite_center - Vector2.ONE * sprite_radius * 1.1
		unit.add_child(halo)
		unit.move_child(halo, 0)
	if int(state.get("burn", 0)) > 0:
		var embers := _burn_embers(Vector2.ONE * sprite_radius * 2.0)
		embers.position = sprite_center
		unit.add_child(embers)
	if int(state.get("weak", 0)) > 0:
		sprite.modulate = Color(0.72, 0.72, 0.78, 1.0)
	if int(state.get("stun", 0)) > 0:
		var stars := DizzyStars.new()
		stars.custom_minimum_size = Vector2.ONE * sprite_radius * 1.6
		stars.size = stars.custom_minimum_size
		stars.position = sprite_center - Vector2(stars.size.x / 2.0, sprite_radius * 1.9)
		unit.add_child(stars)

func _enemy_view(index: int, depth_t := 0.0) -> Control:
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

	# A ring around the whole unit reads as "selectable" far better than scaling the sprite.
	# It is shown whenever a card that needs an enemy is in hand-play, not only on hover.
	var glow := Panel.new()
	glow.name = "TargetGlow"
	glow.custom_minimum_size = Vector2(u_width - 4.0, 150.0)
	glow.size = glow.custom_minimum_size
	glow.position = Vector2(2.0, 16.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _target_ring(false))
	glow.visible = selected_card >= 0 and enemy.health > 0
	unit.add_child(glow)

	var art_key := _art_key_for_enemy(enemy)
	var sprite := Sprite2D.new()
	sprite.name = "MonsterSprite"
	sprite.texture = _get_character_texture(art_key)
	# Depth reads through scale and tone, not through the hit box: the unit's own size/position
	# (used for taps and drag-targeting) stays exactly what _enemy_view always computed, only
	# the sprite drawn inside it shrinks and dims a touch for the "further back" slots.
	var sprite_side := clampf(u_width - 16.0, 70.0, 96.0) * lerpf(1.0, 0.82, depth_t)
	var spr_size := Vector2(sprite_side, sprite_side)
	var cell_w := float(_char_atlas_tex.get_width()) / 3.0
	var scale_factor: float = minf(spr_size.x / cell_w, spr_size.y / cell_w)
	sprite.scale = Vector2(scale_factor, scale_factor)
	# Animations restore scale from this meta. Without it they fell back to 1.0 and left the
	# enemy roughly three times its intended size after any action.
	sprite.set_meta("base_scale", scale_factor)
	sprite.position = Vector2(center_x, 26.0 + spr_size.y / 2.0)
	_install_hit_flash(sprite)
	unit.add_child(sprite)

	var weakened: bool = int(enemy.get("weak", 0)) > 0
	var idle := sprite.create_tween().set_loops()
	# Weak visibly saps the enemy's energy: a slower, shallower bob instead of the usual bounce.
	if weakened:
		idle.tween_property(sprite, "position:y", sprite.position.y - 2.0, 1.6).set_trans(Tween.TRANS_SINE)
		idle.tween_property(sprite, "position:y", sprite.position.y + 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	else:
		idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
		idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)
	_apply_status_fx(unit, sprite, sprite.position, spr_size.x / 2.0, enemy)

	# Intent banner: just the drawn icon (already distinct per intent kind — shield for
	# defend, crossed blades for attack, etc.) plus the number it promises. It used to also
	# spell the intent out in a caption line ("Attack"), which was redundant once the icon
	# actually reads on its own, and the extra line pushed the banner tall enough to crowd
	# whatever sits above the enemy row (the equipment/relic badges).
	var intent: Dictionary = enemy.get("intent", {})
	var intent_style := _intent_style(intent)
	var intent_w: float = minf(u_width, 104.0)
	var intent_bg := Panel.new()
	intent_bg.name = "IntentBanner"
	intent_bg.custom_minimum_size = Vector2(intent_w, 26.0)
	intent_bg.size = intent_bg.custom_minimum_size
	# Depth-staggered (flanking) enemies have their whole unit shifted up by depth_t*26 for
	# the wedge formation; add that back here so every enemy's banner lands at the same
	# screen height regardless of which row it is in, instead of a back-row banner drifting
	# higher and overlapping the row above the whole enemy area.
	intent_bg.position = Vector2(center_x - intent_w / 2.0, depth_t * 26.0)
	intent_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var intent_box := _panel(intent_style.bg, 11, intent_style.border)
	intent_box.border_width_left = 2; intent_box.border_width_right = 2
	intent_box.border_width_top = 2; intent_box.border_width_bottom = 2
	intent_bg.add_theme_stylebox_override("panel", intent_box)
	unit.add_child(intent_bg)

	var intent_row := HBoxContainer.new()
	intent_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	intent_row.add_theme_constant_override("separation", 4)
	intent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_bg.add_child(intent_row)
	var icon := IntentIcon.new()
	icon.kind = str(intent.get("kind", "attack"))
	icon.icon_color = intent_style.text_color
	icon.custom_minimum_size = Vector2(20, 20)
	icon.size = icon.custom_minimum_size
	intent_row.add_child(icon)
	intent_row.add_child(_label(intent_style.amount_text, 15, intent_style.text_color, HORIZONTAL_ALIGNMENT_CENTER))

	var telegraph := intent_bg.create_tween().set_loops()
	telegraph.tween_property(intent_bg, "modulate", Color(1.18, 1.18, 1.18), 0.9).set_trans(Tween.TRANS_SINE)
	telegraph.tween_property(intent_bg, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)

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
	if int(enemy.shield) > 0: badges.add_child(_status_chip("⬢", int(enemy.shield), Color("9fd8ff")))
	if int(enemy.burn) > 0: badges.add_child(_status_chip("▲", int(enemy.burn), Color("ff9868")))
	if int(enemy.get("poison", 0)) > 0: badges.add_child(_status_chip("◆", int(enemy.poison), Color("a75bd6")))
	if int(enemy.stun) > 0: badges.add_child(_status_chip("✸", int(enemy.stun), Color("ffe08a")))
	if int(enemy.get("vulnerable", 0)) > 0: badges.add_child(_status_chip("▼", int(enemy.vulnerable), Color("ff6b6b")))
	if int(enemy.get("weak", 0)) > 0: badges.add_child(_status_chip("●", int(enemy.weak), Color("b8c4c8")))

	return unit

func _build_player_stage() -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(366.0, 118.0)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var center_x := 366.0 / 2.0

	# Mirror of the enemy ring, lit when a card that acts on you is in play.
	var glow := Panel.new()
	glow.name = "PlayerTargetGlow"
	glow.custom_minimum_size = Vector2(200.0, 112.0)
	glow.size = glow.custom_minimum_size
	glow.position = Vector2(center_x - 100.0, 2.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _target_ring(false))
	glow.visible = false
	stage.add_child(glow)

	var sprite := Sprite2D.new()
	sprite.name = "PlayerSprite"
	sprite.texture = _get_character_texture("fox")
	var spr_size := Vector2(74.0, 74.0)
	var cell_w := float(_char_atlas_tex.get_width()) / 3.0
	var scale_factor: float = minf(spr_size.x / cell_w, spr_size.y / cell_w)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.set_meta("base_scale", scale_factor)
	sprite.position = Vector2(center_x, 37.0)
	_install_hit_flash(sprite)
	stage.add_child(sprite)

	var idle := sprite.create_tween().set_loops()
	idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
	idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)
	_apply_status_fx(stage, sprite, sprite.position, spr_size.x / 2.0, combat.state.player)

	var max_hp: int = int(combat.state.player.get("max_health", 60))
	var hp_bar := _stat_bar(168.0, 18.0, int(combat.state.player.health), max_hp, EMBER, "%s  ♥ %d/%d" % [t("ui.spirit_name"), combat.state.player.health, max_hp], 10)
	hp_bar.position = Vector2(center_x - 84.0, 78.0)
	stage.add_child(hp_bar)

	var incoming: int = combat.total_incoming_damage()
	var effective_hp: int = int(combat.state.player.health) + int(combat.state.player.shield)
	if incoming >= effective_hp and incoming > 0:
		var danger_badge := Panel.new()
		danger_badge.name = "DangerWarningBadge"
		danger_badge.custom_minimum_size = Vector2(96.0, 18.0)
		danger_badge.size = danger_badge.custom_minimum_size
		danger_badge.position = Vector2(center_x - 48.0, 58.0)
		danger_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d_style := _panel(Color(0.85, 0.15, 0.15, 0.95), 9, Color("ffc2c2"))
		d_style.border_width_left = 1; d_style.border_width_right = 1
		d_style.border_width_top = 1; d_style.border_width_bottom = 1
		danger_badge.add_theme_stylebox_override("panel", d_style)
		var d_label := _label("⚠ %s: %d" % [t("ui.danger"), incoming], 9, Color("ffffff"), HORIZONTAL_ALIGNMENT_CENTER)
		d_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		danger_badge.add_child(d_label)
		stage.add_child(danger_badge)
		var d_tw := danger_badge.create_tween().set_loops()
		d_tw.tween_property(danger_badge, "modulate:a", 0.55, 0.4).set_trans(Tween.TRANS_SINE)
		d_tw.tween_property(danger_badge, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

	var badges := HBoxContainer.new()
	badges.position = Vector2(center_x - 84.0, 98.0)
	badges.size = Vector2(168.0, 18.0)
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 8)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(badges)
	if int(combat.state.player.shield) > 0: badges.add_child(_status_chip("⬢", int(combat.state.player.shield), Color("9fd8ff"), 22.0))
	if int(combat.state.player.focus) > 0: badges.add_child(_status_chip("◉", int(combat.state.player.focus), Color("ffe08a"), 22.0))
	if int(combat.state.player.burn) > 0: badges.add_child(_status_chip("▲", int(combat.state.player.burn), Color("ff9868"), 22.0))
	if int(combat.state.player.get("poison", 0)) > 0: badges.add_child(_status_chip("◆", int(combat.state.player.poison), Color("a75bd6"), 22.0))
	if int(combat.state.player.get("strength", 0)) > 0: badges.add_child(_status_chip("★", int(combat.state.player.strength), Color("ffd700"), 22.0))
	if int(combat.state.player.get("vulnerable", 0)) > 0: badges.add_child(_status_chip("▼", int(combat.state.player.vulnerable), Color("ff6b6b"), 22.0))
	if int(combat.state.player.get("weak", 0)) > 0: badges.add_child(_status_chip("●", int(combat.state.player.weak), Color("b8c4c8"), 22.0))

	return stage

func _pile_chip(count: int, caption: String, number_color: Color, on_tap: Callable = Callable()) -> Panel:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(52.0, 46.0)
	chip.size = chip.custom_minimum_size
	chip.mouse_filter = Control.MOUSE_FILTER_PASS if on_tap.is_valid() else Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _panel(Color("0c1a1f"), 10, Color("1f404d")))
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(stack)
	stack.add_child(_label(str(count), 17, number_color, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label(caption, 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if on_tap.is_valid():
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		btn.add_theme_stylebox_override("focus", empty)
		btn.pressed.connect(on_tap)
		chip.add_child(btn)
	return chip

func _add_hand(page: VBoxContainer) -> void:
	if selected_card >= 0:
		var hint := _label("%s · %s" % [t("ui.target_pick"), t("ui.target_cancel")], 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		page.add_child(hint)

	# Resource row sits on its own line; previously these floated over the fanned cards.
	var status := HBoxContainer.new()
	status.custom_minimum_size.y = 48
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 10)
	page.add_child(status)

	var draw_chip := _pile_chip(combat.state.draw.size(), t("ui.draw_pile"), Color("f3e8cf"), func(): show_pile_inspector("ui.pile_draw_title", combat.state.draw))
	draw_chip.name = "DrawPileChip"
	status.add_child(draw_chip)

	# Energy is the only thing that gates a play now — there is no play-count limit, so this
	# orb (not a row of used-up pips) is the one number that actually matters each turn.
	var orb := Panel.new()
	orb.custom_minimum_size = Vector2(52, 52)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var orb_style := _panel(Color("0d3a4a"), 26, Color("6fd8ff"))
	orb_style.border_width_left = 2; orb_style.border_width_right = 2; orb_style.border_width_top = 2; orb_style.border_width_bottom = 2
	orb.add_theme_stylebox_override("panel", orb_style)
	var orb_stack := VBoxContainer.new()
	orb_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orb_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	orb_stack.add_theme_constant_override("separation", -3)
	orb_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(orb_stack)
	orb_stack.add_child(_label(str(int(combat.state.energy)), 20, Color("cdf1ff"), HORIZONTAL_ALIGNMENT_CENTER))
	orb_stack.add_child(_label(t("ui.energy_label"), 8, Color("8fd9f2"), HORIZONTAL_ALIGNMENT_CENTER))
	status.add_child(orb)

	var discard_chip := _pile_chip(combat.state.discard.size(), t("ui.discard_pile"), Color("a8b2b5"), func(): show_pile_inspector("ui.pile_discard_title", combat.state.discard))
	discard_chip.name = "DiscardPileChip"
	status.add_child(discard_chip)

	var pass_btn := _button(t("ui.pass_turn"), _pass_turn, Color("1c2a30"), Vector2(48, 44))
	pass_btn.name = "PassTurnBtn"
	status.add_child(pass_btn)

	var hand_zone := Control.new()
	hand_zone.custom_minimum_size = Vector2(366.0, 186.0)
	hand_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(hand_zone)

	var count: int = combat.state.hand.size()
	for index in count:
		var card_tile := _card_view(combat.state.hand[index], index, count)
		hand_zone.add_child(card_tile)

func _card_is_attack(card: Dictionary) -> bool:
	for effect in card.effects:
		if effect.operation == "damage" and effect.target == "opponent": return true
	return false

# A card either acts on an enemy or on you — never both, and never a choice between them.
# Anything with an opponent-facing effect aims at enemies; everything else aims at you.
func _card_target_mode(card: Dictionary) -> String:
	for effect in card.effects:
		if effect.get("target", "") == "opponent": return "enemy"
	return "self"

func _living_enemies() -> Array:
	var living: Array = []
	if combat == null: return living
	for i in combat.state.enemies.size():
		if combat.state.enemies[i].health > 0: living.append(i)
	return living

# Tapping an attack card with more than one enemy alive arms a target choice rather than
# guessing; everything else still plays on the first tap.
func _tap_card(hand_index: int) -> void:
	if combat == null or combat.state.phase != "player" or resolving: return
	if hand_index < 0 or hand_index >= combat.state.hand.size(): return
	if selected_card == hand_index:
		selected_card = -1
		show_battle()
		return
	var card := content.card(combat.state.hand[hand_index].card_id)
	if _card_is_attack(card) and _living_enemies().size() > 1:
		selected_card = hand_index
		show_battle()
		return
	selected_card = -1
	_attempt_play_card(hand_index, -1)

# Shared dim, tap-outside-to-dismiss backdrop for any full-screen modal (card preview,
# equipment/relic/modifier info) — one node name per caller so only that caller's _clear_*
# needs to know about it, and two modals can never stack on top of each other by accident.
func _modal_backdrop(node_name: String, on_dismiss: Callable) -> Button:
	var dim := Color("040a0c"); dim.a = 0.72
	var backdrop := Button.new()
	backdrop.name = node_name
	backdrop.flat = true
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.z_index = 300
	backdrop.add_theme_stylebox_override("normal", _panel(dim, 0))
	backdrop.add_theme_stylebox_override("hover", _panel(dim, 0))
	backdrop.add_theme_stylebox_override("pressed", _panel(dim, 0))
	backdrop.add_theme_stylebox_override("focus", _panel(dim, 0))
	if on_dismiss.is_valid(): backdrop.pressed.connect(on_dismiss)
	overlay.add_child(backdrop)
	return backdrop

# Wraps a non-interactive badge/icon Control (built with MOUSE_FILTER_IGNORE) in an
# invisible button so a whole row of small icons can each be tapped for detail, without
# every icon-drawing call site needing to know about buttons.
func _tap_wrap(control: Control, on_tap: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = control.custom_minimum_size
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(control)
	if on_tap.is_valid(): btn.pressed.connect(on_tap)
	return btn

# A small centered card (icon + name + full detail text) for anything that used to be an
# inline text label — the modifier banner and the equipment/relic row both used to spell
# their full description out on screen; now they're a badge you tap for the same information.
func _show_info_popup(icon: Control, title: String, detail: String, accent: Color) -> void:
	if overlay == null: return
	_clear_info_popup()
	var backdrop := _modal_backdrop("InfoPopup", _clear_info_popup)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 10)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card_style := _panel(Color("15262b"), 14, accent)
	card_style.content_margin_left = 18; card_style.content_margin_right = 18
	card_style.content_margin_top = 18; card_style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(icon)
	inner.add_child(_label(title, 15, Color("f3e8cf"), HORIZONTAL_ALIGNMENT_CENTER))
	var det_lbl := _label(detail, 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	det_lbl.custom_minimum_size.x = 200
	inner.add_child(det_lbl)

	center.add_child(_label(t("ui.tap_to_dismiss"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

func _clear_info_popup() -> void:
	if overlay == null: return
	var existing := overlay.get_node_or_null("InfoPopup")
	if existing: existing.queue_free()

# First-battle tutorial: a short dismissible slide carousel shown once per profile, right
# before the very first fight. Deliberately NOT gated on the player actually performing each
# action (dragging a card, letting a turn auto-end) — hooking every one of those reliably
# across drag/tap/target code paths is real engine surface for marginal gain over just
# explaining them up front. Tapping the backdrop, "跳过教程", or reaching the last step's
# "开始战斗" all do the same thing: mark tutorial_seen and get out of the way.
const TUTORIAL_STEPS: Array[String] = ["tutorial.1", "tutorial.2", "tutorial.3", "tutorial.4"]
var tutorial_step := 0

func _show_battle_tutorial() -> void:
	if overlay == null: return
	tutorial_step = 0
	_modal_backdrop("BattleTutorial", _finish_tutorial)
	_render_tutorial_step()

func _render_tutorial_step() -> void:
	var backdrop := overlay.get_node_or_null("BattleTutorial") as Control
	if backdrop == null: return
	for child in backdrop.get_children(): child.queue_free()

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 12)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)

	var card := PanelContainer.new()
	card.name = "TutorialCard"
	card.custom_minimum_size = Vector2(290, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card_style := _panel(Color("15262b"), 16, GOLD)
	card_style.content_margin_left = 20; card_style.content_margin_right = 20
	card_style.content_margin_top = 20; card_style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	card.add_child(inner)

	var key: String = TUTORIAL_STEPS[tutorial_step]
	inner.add_child(_label(tf("ui.tutorial_step_fmt", [tutorial_step + 1, TUTORIAL_STEPS.size()]), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	inner.add_child(_label(content.ui("%s.title" % key, lang), 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var desc_lbl := _label(content.ui("%s.desc" % key, lang), 12, Color("cfe3e0"), HORIZONTAL_ALIGNMENT_CENTER, true)
	desc_lbl.custom_minimum_size.x = 250
	inner.add_child(desc_lbl)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(actions)
	if tutorial_step > 0:
		var back_btn := _button(t("ui.tutorial_prev"), _tutorial_prev_step, Color("1a3d44"), Vector2(84, 40))
		actions.add_child(back_btn)
	var is_last: bool = tutorial_step >= TUTORIAL_STEPS.size() - 1
	var next_callback: Callable = _finish_tutorial if is_last else _tutorial_next_step
	var next_btn := _button(t("ui.tutorial_start") if is_last else t("ui.tutorial_next"), next_callback, EMBER, Vector2(120, 40))
	next_btn.name = "TutorialNextBtn"
	actions.add_child(next_btn)

	var skip_btn := _button(t("ui.tutorial_skip"), _finish_tutorial, Color.TRANSPARENT, Vector2(0, 30))
	skip_btn.name = "TutorialSkipBtn"
	skip_btn.add_theme_color_override("font_color", MUTED)
	center.add_child(skip_btn)

func _tutorial_next_step() -> void:
	tutorial_step += 1
	_render_tutorial_step()

func _tutorial_prev_step() -> void:
	tutorial_step -= 1
	_render_tutorial_step()

func _finish_tutorial() -> void:
	profile.tutorial_seen = true
	SpiritSave.write(profile)
	if overlay == null: return
	var existing := overlay.get_node_or_null("BattleTutorial")
	if existing: existing.queue_free()

# MTG Arena's hold-to-peek: press and hold a card in hand and an enlarged copy floats up so
# you can actually read it; the moment you drag (HandCard._on_drag) or lift your finger
# (HandCard._on_touch_up), it drops away again — never a modal, never a button, never a
# stop that has to be dismissed on its own. See HandCard.PREVIEW_HOLD_DELAY for the hold time.
func _show_hold_preview(card: Dictionary) -> void:
	if overlay == null: return
	_clear_hold_preview()

	# A held touch's own release is not reliably delivered after a long-enough hold — iOS's
	# own long-press/haptic-touch gesture recognition can swallow it before Godot ever sees a
	# touch-up, no matter how quickly Godot itself reacts to the press. HandCard still tries
	# the direct route (its own touch-up, a raw _input() watcher, dragging away, a flat
	# timeout), but this dimmed tap-anywhere backdrop — Godot's own proven Button.pressed,
	# not raw touch-sequence tracking — is what actually guarantees the peek can be closed.
	var backdrop := _modal_backdrop("HoldPreview", _clear_hold_preview)
	backdrop.z_index = 400

	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(holder)

	var rune_id: String = profile.card_runes.get(card.id, "")
	var face := _big_card_face(card, rune_id)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)

	face.pivot_offset = face.custom_minimum_size / 2.0
	face.scale = Vector2(0.7, 0.7)
	face.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "scale", Vector2(1.2, 1.2), 0.16)
	tw.tween_property(face, "modulate:a", 1.0, 0.12)

func _clear_hold_preview() -> void:
	if overlay == null: return
	var existing := overlay.get_node_or_null("HoldPreview")
	if existing: existing.queue_free()

# A bigger, static twin of the HandCard face in _card_view: same frame/art/cost/rune
# language, scaled up with room for the full effect text instead of a 7pt sliver of it.
func _big_card_face(card: Dictionary, rune_id: String) -> Panel:
	var accent: Color = _card_color(card)
	var border_col: Color = _rune_color(rune_id, accent)
	var size := Vector2(230.0, 320.0)

	# Same full-bleed-art-plus-rules-box language as _card_view's hand cards, just at a size
	# where the description reads comfortably — this is what a held-down peek shows enlarged,
	# so it should look like a bigger version of the same card, not a different template.
	# Plain Panel, not PanelContainer: a Container force-fits EVERY direct child to its own
	# rect, which is exactly what turned this into a solid block showing only the last child
	# added (the cost badge) — art, the info box, and the badges all need to keep their own
	# size and position instead of being fought over by auto-layout.
	var frame := Panel.new()
	frame.clip_contents = true
	frame.custom_minimum_size = size
	frame.size = size
	var frame_style := _panel(Color("0a171b"), 16, border_col)
	frame_style.border_width_left = 4; frame_style.border_width_right = 4
	frame_style.border_width_top = 4; frame_style.border_width_bottom = 4
	frame.add_theme_stylebox_override("panel", frame_style)

	var art := TextureRect.new()
	art.texture = _get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_rarity: String = str(card.get("rarity", "Common"))
	var up_lvl: int = int(profile.upgrades.get(card.id, 0))
	_apply_card_foil(art, card_rarity, up_lvl > 0)
	frame.add_child(art)

	var info_box := PanelContainer.new()
	info_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info_box.anchor_left = 0.0; info_box.anchor_right = 1.0
	info_box.anchor_top = 0.52; info_box.anchor_bottom = 1.0
	info_box.offset_left = 0; info_box.offset_right = 0
	info_box.offset_top = 0; info_box.offset_bottom = 0
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := _panel(Color(0.05, 0.09, 0.11, 0.97), 0)
	info_style.corner_radius_top_left = 8; info_style.corner_radius_top_right = 8
	info_style.border_width_top = 3; info_style.border_color = border_col
	# ~8% of the card width, clearing the slender border overlay added below
	info_style.content_margin_left = 20; info_style.content_margin_right = 20
	info_style.content_margin_top = 8; info_style.content_margin_bottom = 8
	info_box.add_theme_stylebox_override("panel", info_style)
	frame.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	info_box.add_child(stack)

	var name_text: String = content.text(card.nameKey, lang) + (" +" if up_lvl > 0 else "")
	var name_lbl := _label(name_text, 16, Color("f3e8cf"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(name_lbl)

	var kind_lbl := _label(_kind_element_line(card), 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(kind_lbl)

	var desc_lbl := _label(_card_description(card), 13, Color("e4ede8"), HORIZONTAL_ALIGNMENT_CENTER, true)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc_lbl)

	# Ornate slim card frame selected according to card rarity (Starter, Common, Uncommon, Rare)
	var border_overlay := TextureRect.new()
	border_overlay.texture = _get_card_frame_texture(card_rarity)
	border_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	border_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(border_overlay)

	var cost_badge := PanelContainer.new()
	cost_badge.custom_minimum_size = Vector2(38, 38)
	cost_badge.position = Vector2(-10, -10)
	cost_badge.add_theme_stylebox_override("panel", _panel(accent, 19, Color("2b1a10")))
	var cost_lbl := _label(str(int(card.cost)), 22, Color("160b06"), HORIZONTAL_ALIGNMENT_CENTER)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_lbl)
	frame.add_child(cost_badge)

	var rune_info: Dictionary = content.rune(rune_id)
	if not rune_info.is_empty():
		var rune_icon_path := "res://assets/icons/rune_%s.png" % rune_id
		if ResourceLoader.exists(rune_icon_path):
			var r_tr := TextureRect.new()
			r_tr.texture = load(rune_icon_path)
			r_tr.position = Vector2(size.x - 36.0, -8.0)
			r_tr.custom_minimum_size = Vector2(34, 34)
			r_tr.size = r_tr.custom_minimum_size
			r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(r_tr)
		else:
			var r_lbl := _label(rune_info.icon, 22, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
			r_lbl.position = Vector2(size.x - 34.0, -8.0)
			frame.add_child(r_lbl)

	# Keyword tooltip badges — small tappable pills at the bottom of the enlarged card peek,
	# so a player can tap any mechanic name to see what it does without leaving the card.
	var kw_set: Dictionary = {}
	for effect in card.effects:
		var op: String = str(effect.get("operation", ""))
		if op in KEYWORD_KEYS: kw_set[op] = true
		var status_key: String = str(effect.get("status", ""))
		if status_key in KEYWORD_KEYS: kw_set[status_key] = true
		for special in effect.get("special", []):
			var sp: String = str(special)
			if sp in KEYWORD_KEYS: kw_set[sp] = true
	if not rune_id.is_empty() and rune_id in KEYWORD_KEYS: kw_set[rune_id] = true
	if not kw_set.is_empty():
		var kw_flow := HBoxContainer.new()
		kw_flow.position = Vector2(8.0, size.y - 28.0)
		kw_flow.size = Vector2(size.x - 16.0, 24.0)
		kw_flow.alignment = BoxContainer.ALIGNMENT_CENTER
		kw_flow.add_theme_constant_override("separation", 4)
		kw_flow.mouse_filter = Control.MOUSE_FILTER_PASS
		frame.add_child(kw_flow)
		for kw_key in kw_set:
			var kw_name: String = str(kw_key).capitalize()
			var pill := Button.new()
			pill.text = kw_name
			pill.custom_minimum_size = Vector2(0, 22)
			pill.add_theme_font_size_override("font_size", 9)
			pill.add_theme_color_override("font_color", Color("cce8e0"))
			pill.add_theme_stylebox_override("normal", _panel(Color("1a3d44"), 6, JADE))
			pill.add_theme_stylebox_override("hover", _panel(Color("1a3d44"), 6, JADE))
			pill.add_theme_stylebox_override("pressed", _panel(Color("1a3d44"), 6, JADE))
			var kw_text: String = t("kw." + str(kw_key))
			pill.pressed.connect(func(): _show_info_popup(_label(kw_name, 18, JADE, HORIZONTAL_ALIGNMENT_CENTER), kw_name, kw_text, JADE))
			kw_flow.add_child(pill)

	return frame

func _handle_targeting(event: InputEvent) -> bool:
	if selected_card < 0 or combat == null or combat.state.phase != "player" or resolving: return false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and not event.pressed: pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: pos = event.position
	else: return false

	for box in enemy_boxes:
		if box == null or not is_instance_valid(box): continue
		if not box.get_global_rect().has_point(pos): continue
		var enemy_index := int(box.get_meta("enemy_index"))
		if combat.state.enemies[enemy_index].health <= 0: continue
		var card_index := selected_card
		selected_card = -1
		get_viewport().set_input_as_handled()
		_attempt_play_card(card_index, enemy_index)
		return true
	return false

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

	# 1. Base card container with clipping. Plain Panel, not PanelContainer — a Container
	# force-fits every direct child (art, the bottom info box, badges) to its own full rect,
	# which is what silently turned the whole card into a solid block showing only whichever
	# child got laid out last. A Panel just paints its stylebox and leaves children alone.
	# Note: the FULL ornate filigree texture (card_frame_golden.png) turns to a translucent
	# gold haze over the art when shrunk ~7.7x onto this 116x168 tile (fine scrollwork + lots
	# of transparent gaps average out under minification) — card_frame_golden_border.png (the
	# thin outer-ring derivative added below) keeps enough of that detail concentrated in a
	# narrower band to stay legible even at this size.
	var card_clip := Panel.new()
	card_clip.name = "CardFrame"
	card_clip.clip_contents = true
	card_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var clip_style := _panel(Color("0a171b"), 10, border_col)
	clip_style.border_width_left = 3; clip_style.border_width_right = 3
	clip_style.border_width_top = 3; clip_style.border_width_bottom = 3
	card_clip.add_theme_stylebox_override("panel", clip_style)
	card_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(card_clip)

	# 2. Illustration covers the ENTIRE card, full colour, nothing drawn over it.
	var art := TextureRect.new()
	art.texture = _get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_clip.add_child(art)

	# 3. A solid text box from the middle down, like a normal trading card's rules box —
	# a name/type bar over a dark, near-opaque description panel, not a floating translucent
	# island in the middle of the art.
	var info_box := PanelContainer.new()
	info_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info_box.anchor_left = 0.0
	info_box.anchor_right = 1.0
	info_box.anchor_top = 0.52
	info_box.anchor_bottom = 1.0
	info_box.offset_left = 0
	info_box.offset_right = 0
	info_box.offset_top = 0
	info_box.offset_bottom = 0
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := _panel(Color(0.05, 0.09, 0.11, 0.97), 0)
	info_style.corner_radius_top_left = 6; info_style.corner_radius_top_right = 6
	info_style.border_width_top = 2; info_style.border_color = border_col
	# ~8% of the card width, clearing the slender border overlay added below
	info_style.content_margin_left = 11; info_style.content_margin_right = 11
	info_style.content_margin_top = 3; info_style.content_margin_bottom = 3
	info_box.add_theme_stylebox_override("panel", info_style)
	card_clip.add_child(info_box)

	var card_rarity: String = str(card.get("rarity", "Common"))
	var hand_border := TextureRect.new()
	hand_border.texture = _get_card_frame_texture(card_rarity)
	hand_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand_border.stretch_mode = TextureRect.STRETCH_SCALE
	hand_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_clip.add_child(hand_border)

	var info_stack := VBoxContainer.new()
	info_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_stack.add_theme_constant_override("separation", 1)
	info_box.add_child(info_stack)

	var up_lvl: int = int(profile.upgrades.get(card.id, 0))
	var name_text: String = content.text(card.nameKey, lang) + (" +" if up_lvl > 0 else "")
	var name_lbl := _label(name_text, 10, Color("f3e8cf"), HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_stack.add_child(name_lbl)

	var kind_lbl := _label(_kind_element_line(card), 7, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	kind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_stack.add_child(kind_lbl)

	var desc_lbl := _label(_card_description(card), 8, Color("e4ede8"), HORIZONTAL_ALIGNMENT_CENTER, true)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_stack.add_child(desc_lbl)

	# 5. Top badges (cost & rune)
	var cost_badge := PanelContainer.new()
	cost_badge.custom_minimum_size = Vector2(26, 26)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.position = Vector2(-6, -6)
	cost_badge.add_theme_stylebox_override("panel", _panel(accent, 13, Color("2b1a10")))
	var cost_lbl := _label(str(int(card.cost)), 16, Color("160b06"), HORIZONTAL_ALIGNMENT_CENTER)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_lbl)
	tile.add_child(cost_badge)

	var rune_info: Dictionary = content.rune(rune_id)
	if not rune_info.is_empty():
		var rune_icon_path := "res://assets/icons/rune_%s.png" % rune_id
		if ResourceLoader.exists(rune_icon_path):
			var r_tr := TextureRect.new()
			r_tr.texture = load(rune_icon_path)
			r_tr.position = Vector2(116.0 - 26.0, -6.0)
			r_tr.custom_minimum_size = Vector2(24, 24)
			r_tr.size = r_tr.custom_minimum_size
			r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(r_tr)
		else:
			var r_lbl := _label(rune_info.icon, 16, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
			r_lbl.position = Vector2(116.0 - 24.0, -6.0)
			tile.add_child(r_lbl)

	var center_idx: float = (count - 1) / 2.0
	var distance: float = float(index) - center_idx
	var spacing: float = minf(64.0, 250.0 / maxf(1.0, float(count - 1)))
	var center_x: float = 366.0 / 2.0
	tile.home_rot = deg_to_rad(distance * 2.8)
	tile.home_pos = Vector2(center_x + distance * spacing - 58.0, 10.0 + absf(distance) * 4.2)
	tile.position = tile.home_pos
	tile.rotation = tile.home_rot
	tile.z_index = index

	# The armed card lifts clear of the fan so it is obvious which one is waiting on a target.
	if index == selected_card:
		card_clip.add_theme_stylebox_override("panel", _panel(Color("1d3a35"), 12, GOLD))
		tile.position = tile.home_pos - Vector2(0, 30)
		tile.rotation = 0.0
		tile.z_index = 80

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
	bonus += int(combat.state.player.get("strength", 0))
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
		if int(enemy.get("vulnerable", 0)) > 0: amount = int(round(amount * 1.5))
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
		var lethal_badge := _label("☠ " + t("ui.lethal"), 11, Color("ff4444"), HORIZONTAL_ALIGNMENT_CENTER)
		lethal_badge.name = "LethalBadge"
		holder.add_child(lethal_badge)
		var tw := holder.create_tween().set_loops()
		tw.tween_property(lethal_badge, "modulate:a", 0.45, 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lethal_badge, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	elif prediction.blocked > 0:
		holder.add_child(_label(tf("ui.preview_blocked", prediction.blocked), 10, Color("9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER))

func _clear_damage_preview() -> void:
	if overlay == null: return
	var existing := overlay.get_node_or_null("DamagePreview")
	if existing: existing.queue_free()

func _show_cancel_zone(active: bool) -> void:
	if overlay == null: return
	var zone: Control = overlay.get_node_or_null("CancelDropZone") as Control
	if not active:
		if zone: zone.queue_free()
		return
	if zone != null: return
	zone = Panel.new()
	zone.name = "CancelDropZone"
	zone.custom_minimum_size = Vector2(366.0, 140.0)
	zone.size = zone.custom_minimum_size
	zone.position = Vector2(12.0, 660.0)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(0.55, 0.12, 0.12, 0.45), 14, Color(1.0, 0.45, 0.45, 0.8))
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	zone.add_theme_stylebox_override("panel", style)
	var lbl := _label("✕ " + t("ui.cancel_drop"), 12, Color("ffd5d5"), HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone.add_child(lbl)
	overlay.add_child(zone)

func show_pile_inspector(title_key: String, pile: Array) -> void:
	if overlay == null: return
	_clear_pile_inspector()
	var backdrop := _modal_backdrop("PileInspector", _clear_pile_inspector)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(366, 560)
	panel.size = panel.custom_minimum_size
	panel.position = Vector2(12, 140)
	panel.add_theme_stylebox_override("panel", _panel(Color("091316"), 16, Color("2d4a52")))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(350, 44)
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(header)

	var spacer_l := Control.new()
	spacer_l.custom_minimum_size = Vector2(12, 0)
	header.add_child(spacer_l)

	var title_lbl := _label(t(title_key), 17, TEXT)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var count_lbl := _label(tf("ui.pile_count_desc", pile.size()), 11, MUTED)
	header.add_child(count_lbl)

	var close_btn := _button("✕", _clear_pile_inspector, Color("2a3f45"), Vector2(36, 32))
	close_btn.name = "PileCloseBtn"
	header.add_child(close_btn)

	var spacer_r := Control.new()
	spacer_r.custom_minimum_size = Vector2(8, 0)
	header.add_child(spacer_r)

	var scroll := TouchScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.allow_vertical = true
	vbox.add_child(scroll)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(pad)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	pad.add_child(grid)

	for item in pile:
		var c_id: String = item.card_id if (item is Dictionary and item.has("card_id")) else str(item)
		var c_data: Dictionary = content.card(c_id)
		if not c_data.is_empty():
			grid.add_child(_pile_card_tile(c_data))

func _clear_pile_inspector() -> void:
	if overlay == null: return
	var existing := overlay.get_node_or_null("PileInspector")
	if existing: existing.queue_free()

func _pile_card_tile(card: Dictionary) -> Control:
	var accent := _card_color(card)
	var rune_id: String = ""
	if combat and combat.state: rune_id = combat.state.runes.get(card.id, "")
	elif profile: rune_id = profile.card_runes.get(card.id, "")

	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(170, 225)
	tile.size = tile.custom_minimum_size
	tile.add_theme_stylebox_override("panel", _panel(Color("11242a"), 12, accent))
	tile.clip_contents = true

	var art := TextureRect.new()
	art.texture = _get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var up_lvl: int = int(combat.state.upgrades.get(card.id, 0)) if (combat and combat.state) else int(profile.upgrades.get(card.id, 0))
	_apply_card_foil(art, str(card.get("rarity", "Common")), up_lvl > 0)
	tile.add_child(art)

	_add_ornate_frame(tile, tile.custom_minimum_size, accent, str(card.get("rarity", "Common")))

	var badge := _cost_badge(int(card.cost), accent)
	badge.position = Vector2(8, 8)
	tile.add_child(badge)

	if not rune_id.is_empty():
		var rune_info := content.rune(rune_id)
		var rune_path := "res://assets/icons/rune_%s.png" % rune_id
		if ResourceLoader.exists(rune_path):
			var r_tr := TextureRect.new()
			r_tr.texture = load(rune_path)
			r_tr.position = Vector2(38, 8)
			r_tr.custom_minimum_size = Vector2(20, 20)
			r_tr.size = r_tr.custom_minimum_size
			r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(r_tr)
		else:
			var rune_lbl := _label(rune_info.icon, 14, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
			rune_lbl.position = Vector2(38, 8)
			rune_lbl.size = Vector2(20, 20)
			tile.add_child(rune_lbl)

	var rarity_row := _rarity_star_row(str(card.rarity), GOLD, BoxContainer.ALIGNMENT_END)
	rarity_row.position = Vector2(84, 10)
	rarity_row.size = Vector2(76, 16)
	tile.add_child(rarity_row)

	var info_box := PanelContainer.new()
	info_box.position = Vector2(8, 90)
	info_box.custom_minimum_size = Vector2(154, 126)
	info_box.size = info_box.custom_minimum_size
	var box_style := _panel(Color(0.06, 0.12, 0.16, 0.92), 8, accent)
	box_style.content_margin_left = 10; box_style.content_margin_right = 10
	box_style.content_margin_top = 4; box_style.content_margin_bottom = 4
	info_box.add_theme_stylebox_override("panel", box_style)
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(stack)

	stack.add_child(_label(content.text(card.nameKey, lang) + (" +" if up_lvl > 0 else ""), 12, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label(_kind_element_line(card), 8, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var desc := _label(_card_description(card), 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.custom_minimum_size.y = 48
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)

	return tile

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

func _target_ring(hot: bool) -> StyleBoxFlat:
	var ring := _panel(Color(1.0, 0.86, 0.42, 0.22 if hot else 0.08), 14, Color(1.0, 0.92, 0.55, 1.0) if hot else Color(1.0, 0.86, 0.42, 0.7))
	var width := 3 if hot else 2
	ring.border_width_left = width; ring.border_width_right = width
	ring.border_width_top = width; ring.border_width_bottom = width
	return ring

# Shows every legal target for the card currently in play, so you can see what you may aim
# at before you get there rather than discovering it by dragging over each enemy.
func _show_valid_targets(mode: String) -> void:
	for box in enemy_boxes:
		if box == null or not is_instance_valid(box): continue
		var glow: Control = box.get_node_or_null("TargetGlow")
		if glow == null: continue
		var alive: bool = combat != null and combat.state.enemies[int(box.get_meta("enemy_index"))].health > 0
		glow.visible = mode == "enemy" and alive
		glow.add_theme_stylebox_override("panel", _target_ring(false))
	var player_glow: Control = root.find_child("PlayerTargetGlow", true, false) as Control
	if player_glow: player_glow.visible = mode == "self"

func _clear_valid_targets() -> void:
	_show_valid_targets("")
	for box in enemy_boxes:
		if box and is_instance_valid(box):
			var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
			if sprite: sprite.modulate = Color.WHITE

func _set_enemy_targeted(enemy_index: int, targeted: bool) -> void:
	for box in enemy_boxes:
		if box and is_instance_valid(box) and int(box.get_meta("enemy_index")) == enemy_index:
			var glow: Control = box.get_node_or_null("TargetGlow")
			if glow and glow.visible: glow.add_theme_stylebox_override("panel", _target_ring(targeted))
			# Brighten rather than enlarge: the old 1.08x jump read as the model popping.
			var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
			if sprite: sprite.modulate = Color(1.35, 1.3, 1.15) if targeted else Color.WHITE

# Stays synchronous so callers get a real bool back; the animation runs in _resolve_play.
func _attempt_play_card(hand_index: int, target: int) -> bool:
	if combat == null or combat.state.phase != "player" or resolving: return false
	var before: Array = []
	for enemy in combat.state.enemies: before.append(int(enemy.health))
	if not combat.play(hand_index, target):
		_toast(t("ui.target_invalid"))
		return false
	selected_card = -1
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

# There is no End Turn button, so the turn has to hand itself over once nothing in hand is
# affordable any more (either the hand is empty or every card costs more than remaining energy).
func _maybe_end_turn() -> void:
	var guard := 0
	while combat != null and combat.state.phase == "player" and guard < 12:
		guard += 1
		if _has_playable_card(): return
		if combat.state.hand.size() > 0: _toast(t("ui.no_playable"))
		await get_tree().create_timer(_battle_delay(0.28)).timeout
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

	_haptic("heavy" if defeated else "hit")
	_shake_screen(9.0 if defeated else clampf(float(amount) * 0.45, 2.5, 7.0))

	var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
	var tween := create_tween().set_parallel(true)
	if sprite:
		_flash_hit(sprite, Color("ff5c4a"))
		_squash_impact(sprite, float(sprite.get_meta("base_scale", 1.0)), 0.28 if defeated else 0.18)
	tween.tween_property(popup, "position:y", popup.position.y - 45.0, 0.45)
	tween.tween_property(popup, "modulate:a", 0.0, 0.45)
	if defeated:
		tween.tween_property(box, "modulate:a", 0.0, 0.4)
		tween.tween_property(box, "scale", Vector2(0.4, 0.4), 0.4)
	await tween.finished
	popup.queue_free()
	if defeated and combat != null and combat.state.phase == "won":
		await _animate_finishing_blow(box, sprite)

func _animate_finishing_blow(box: Control, sprite: Node2D) -> void:
	if overlay == null: return
	_haptic("heavy")
	_shake_screen(14.0, 0.45)

	var top_bar := ColorRect.new()
	top_bar.color = Color("04090c")
	top_bar.custom_minimum_size = Vector2(390, 64)
	top_bar.size = top_bar.custom_minimum_size
	top_bar.position = Vector2(0, -64)
	top_bar.z_index = 450
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top_bar)

	var btm_bar := ColorRect.new()
	btm_bar.color = Color("04090c")
	btm_bar.custom_minimum_size = Vector2(390, 64)
	btm_bar.size = btm_bar.custom_minimum_size
	btm_bar.position = Vector2(0, 844)
	btm_bar.z_index = 450
	btm_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(btm_bar)

	var banner := PanelContainer.new()
	banner.name = "FinishingBlowBanner"
	banner.z_index = 460
	banner.custom_minimum_size = Vector2(260, 56)
	banner.position = Vector2(65, 340)
	banner.pivot_offset = Vector2(130, 28)
	banner.scale = Vector2(0.4, 0.4)
	banner.modulate.a = 0.0
	var b_style := _panel(Color(0.1, 0.03, 0.02, 0.95), 12, Color("ffd700"))
	b_style.border_width_left = 2; b_style.border_width_right = 2
	b_style.border_width_top = 2; b_style.border_width_bottom = 2
	b_style.content_margin_left = 12; b_style.content_margin_right = 12
	b_style.content_margin_top = 6; b_style.content_margin_bottom = 6
	banner.add_theme_stylebox_override("panel", b_style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var b_stack := VBoxContainer.new()
	b_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	b_stack.add_theme_constant_override("separation", -2)
	b_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(b_stack)

	var b_title := _label("✦ " + t("ui.finishing_blow") + " ✦", 20, Color("ffd700"), HORIZONTAL_ALIGNMENT_CENTER)
	var b_sub := _label(t("ui.finishing_sub"), 9, Color("ffb09c"), HORIZONTAL_ALIGNMENT_CENTER)
	b_stack.add_child(b_title)
	b_stack.add_child(b_sub)
	overlay.add_child(banner)

	if sprite:
		_flash_hit(sprite, Color(2.5, 2.5, 2.5))

	var tw := create_tween().set_parallel(true)
	tw.tween_property(top_bar, "position:y", 0.0, _battle_delay(0.2)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(btm_bar, "position:y", 780.0, _battle_delay(0.2)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "scale", Vector2.ONE, _battle_delay(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, _battle_delay(0.15))
	if sprite:
		var base_scale: float = float(sprite.get_meta("base_scale", 1.0))
		tw.tween_property(sprite, "scale", Vector2.ONE * (base_scale * 1.3), _battle_delay(0.25))

	await tw.finished
	await get_tree().create_timer(_battle_delay(0.4)).timeout

	var out_tw := create_tween().set_parallel(true)
	out_tw.tween_property(banner, "modulate:a", 0.0, _battle_delay(0.25))
	out_tw.tween_property(banner, "scale", Vector2(1.2, 1.2), _battle_delay(0.25))
	out_tw.tween_property(top_bar, "position:y", -64.0, _battle_delay(0.25))
	out_tw.tween_property(btm_bar, "position:y", 844.0, _battle_delay(0.25))
	if sprite:
		out_tw.tween_property(sprite, "modulate:a", 0.0, _battle_delay(0.25))

	await out_tw.finished
	top_bar.queue_free()
	btm_bar.queue_free()
	banner.queue_free()

func _advance_to_reward() -> void:
	# show_battle can run several times while the win is on screen; only one hand-off.
	if advancing_to_reward: return
	advancing_to_reward = true
	await get_tree().create_timer(_battle_delay(0.8)).timeout
	advancing_to_reward = false
	if combat != null and combat.state.phase == "won": show_reward()

func _enemy_turn() -> void:
	selected_card = -1
	# Snapshot the telegraphed intents before end_turn consumes them, so each enemy can play
	# the animation for what it actually promised.
	var planned: Array = []
	for enemy in combat.state.enemies:
		planned.append(str(enemy.get("intent", {}).get("kind", "attack")) if enemy.health > 0 else "")
	for box in enemy_boxes:
		if box == null or not is_instance_valid(box): continue
		var index := int(box.get_meta("enemy_index"))
		if index >= planned.size() or str(planned[index]).is_empty(): continue
		await _animate_enemy_action(box, str(planned[index]), combat.state.enemies[index])

	var before_health: int = combat.state.player.health
	combat.end_turn()
	if combat.state.player.health < before_health:
		_haptic("heavy")
		await _animate_player_hit(before_health - combat.state.player.health)
	show_battle()

# The tint a sprite should rest at once its action animation finishes — plain white unless
# a persistent status (currently just Weak) is dulling it, in which case resetting to pure
# white would erase that status's own visual cue.
func _resting_modulate(state: Dictionary) -> Color:
	return Color(0.72, 0.72, 0.78, 1.0) if int(state.get("weak", 0)) > 0 else Color.WHITE

func _animate_enemy_action(box: Control, kind: String, enemy_state: Dictionary) -> void:
	var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
	if sprite == null: return
	var origin: Vector2 = sprite.position
	var base_scale: float = float(sprite.get_meta("base_scale", 1.0))
	var rest_tint := _resting_modulate(enemy_state)
	var tween := sprite.create_tween()
	match kind:
		"defend":
			# Anticipation (crouch/squash) then a small rise, like drawing a shield up.
			tween.tween_property(sprite, "modulate", Color(0.75, 0.95, 1.6), 0.1)
			tween.tween_property(sprite, "scale", Vector2(base_scale * 1.14, base_scale * 0.88), 0.12).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(sprite, "position:y", origin.y - 10.0, 0.12).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, 0.16).set_trans(Tween.TRANS_BACK)
			tween.tween_property(sprite, "position:y", origin.y, 0.14)
			tween.tween_property(sprite, "modulate", rest_tint, 0.14)
		"empower":
			# A single decisive stretch-up "power surge" rather than a repeated wobble.
			tween.tween_property(sprite, "modulate", Color(1.6, 0.9, 1.8), 0.1)
			tween.tween_property(sprite, "scale", Vector2(base_scale * 0.9, base_scale * 1.22), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", Vector2.ONE * base_scale * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", Vector2.ONE * base_scale, 0.14).set_trans(Tween.TRANS_ELASTIC)
			tween.parallel().tween_property(sprite, "modulate", rest_tint, 0.2)
		"curse":
			tween.tween_property(sprite, "modulate", Color(0.9, 1.6, 0.7), 0.12)
			tween.tween_property(sprite, "position:x", origin.x + 7.0, 0.06)
			tween.tween_property(sprite, "position:x", origin.x - 7.0, 0.06)
			tween.tween_property(sprite, "position:x", origin.x, 0.06)
			tween.tween_property(sprite, "modulate", rest_tint, 0.14)
		_:
			# Anticipation (rise + squash back), action (fast lunge down + stretch), impact
			# (squash flat + hit-flash + screen shake), recovery (elastic settle).
			tween.tween_property(sprite, "position:y", origin.y - 16.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.12, base_scale * 0.86), 0.16).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(sprite, "position:y", origin.y + 48.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 0.82, base_scale * 1.28), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(sprite, "modulate", Color(1.9, 1.1, 0.9), 0.09)
			tween.tween_callback(func():
				_flash_hit(sprite, Color(1.0, 0.75, 0.55), 0.14)
				_shake_screen(4.0)
				_haptic("tap"))
			tween.tween_property(sprite, "scale", Vector2(base_scale * 1.1, base_scale * 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(sprite, "position:y", origin.y, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(sprite, "modulate", rest_tint, 0.22)
	await tween.finished
	sprite.position = origin
	sprite.scale = Vector2.ONE * base_scale
	sprite.modulate = rest_tint

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

	# Red wash over the screen so a hit registers even if you were looking at your hand.
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.15, 0.12, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(flash)
	var wash := flash.create_tween()
	wash.tween_property(flash, "color:a", 0.28, 0.07)
	wash.tween_property(flash, "color:a", 0.0, 0.32)
	wash.tween_callback(flash.queue_free)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 60.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	
	var player_node: Sprite2D = get_tree().root.find_child("PlayerSprite", true, false) as Sprite2D
	if player_node:
		_flash_hit(player_node, Color("ff5c4a"))
		_squash_impact(player_node, float(player_node.get_meta("base_scale", 1.0)), 0.24)

	await tween.finished
	popup.queue_free()

func _combat_event(kind: String, payload: Dictionary) -> void:
	if kind == "intent":
		var style := _intent_style({"kind": payload.kind, "amount": payload.amount})
		var tip: String = {"defend": "ui.intent_tip_defend", "empower": "ui.intent_tip_empower", "curse": "ui.intent_tip_curse"}.get(str(payload.kind), "")
		if not tip.is_empty(): _toast("%s %s" % [t(tip), style.text], style.border)
	elif kind == "player_burn": _toast("♨ −%d" % payload.amount, Color("ff9868"))
	elif kind == "thorns": _toast(tf("ui.thorns_toast", payload.amount), Color("ff8a8a"))
	elif kind == "revive": _toast(tf("ui.revive_toast", payload.amount),Color("9bffd3"))
	elif kind == "equipment":
		var item := content.equipment(payload.id); if not item.is_empty(): _toast("%s %s" % [item.icon, _equip_name(item)],GOLD)
	elif kind == "card":
		if int(payload.get("damage", 0)) > 0: _advance_quest("deal_damage", int(payload.damage))
		if not str(payload.rune).is_empty():
			_advance_quest("play_runed_cards", 1)
			var rune := content.rune(payload.rune); _toast("%s %s" % [rune.icon, _rune_name(rune)],Color(rune.color))
	elif kind == "boss_phase":
		var p_name: String = payload.get("name_en", "") if lang == "en" else payload.get("name", "")
		var p_desc: String = payload.get("desc_en", "") if lang == "en" else payload.get("desc", "")
		_show_boss_phase_banner(p_name, p_desc)

func _show_boss_phase_banner(title: String, subtitle: String) -> void:
	if overlay == null: return
	_haptic("heavy")
	var banner := PanelContainer.new()
	banner.name = "BossPhaseBanner"
	banner.z_index = 460
	banner.custom_minimum_size = Vector2(300, 64)
	banner.position = Vector2(45, 280)
	banner.pivot_offset = Vector2(150, 32)
	banner.scale = Vector2(0.6, 0.6)
	banner.modulate.a = 0.0
	var b_style := _panel(Color(0.14, 0.03, 0.05, 0.95), 14, Color("ff5959"))
	b_style.border_width_left = 2; b_style.border_width_right = 2
	b_style.border_width_top = 2; b_style.border_width_bottom = 2
	banner.add_theme_stylebox_override("panel", b_style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var b_stack := VBoxContainer.new()
	b_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	b_stack.add_theme_constant_override("separation", 2)
	b_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(b_stack)

	var b_title := _label("⚔ PHASE II · " + title + " ⚔", 16, Color("ffd700"), HORIZONTAL_ALIGNMENT_CENTER)
	var b_sub := _label(subtitle, 10, Color("ffc9c9"), HORIZONTAL_ALIGNMENT_CENTER, true)
	b_stack.add_child(b_title)
	b_stack.add_child(b_sub)
	overlay.add_child(banner)

	var tw := banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "scale", Vector2.ONE, _battle_delay(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, _battle_delay(0.2))
	var seq := banner.create_tween()
	seq.tween_interval(_battle_delay(1.5))
	seq.tween_property(banner, "modulate:a", 0.0, _battle_delay(0.3))
	seq.tween_callback(banner.queue_free)

func _toast(message: String, color := TEXT) -> void:
	if overlay == null: return
	var toast := _label(message, 14, color, HORIZONTAL_ALIGNMENT_CENTER)
	toast.position = Vector2(65, 110); toast.size = Vector2(260, 40)
	toast.add_theme_stylebox_override("normal", _panel(Color("153d42"), 14, color))
	overlay.add_child(toast)
	var tween := create_tween(); tween.tween_property(toast,"position:y",86,.22); tween.tween_interval(.55); tween.tween_property(toast,"modulate:a",0.0,.25); tween.tween_callback(toast.queue_free)

func _leave_battle() -> void:
	selected_card = -1
	if in_abyss:
		in_abyss = false
		profile.health = maxi(1, pre_battle_health)
		SpiritSave.write(profile)
		show_camp()
		return
	if in_daily_trial:
		# A loss (or an early retreat) costs the attempt, not the run: the stage you were on
		# stays un-cleared so today's next try re-fights it, same "attempt vs. run" split the
		# comment above already uses for Abyss.
		in_daily_trial = false
		profile.health = maxi(1, pre_battle_health)
		SpiritSave.write(profile)
		show_camp()
		return
	if combat != null:
		# A defeat costs you the attempt, not the run: health returns to what you entered with.
		# Retreating mid-battle still keeps the damage you took.
		if combat.state.phase == "lost": profile.health = maxi(1, pre_battle_health)
		else: profile.health = maxi(1, int(combat.state.player.health))
	SpiritSave.write(profile)
	show_map()

func show_reward() -> void:
	_clear(); _play_music(false)
	var page := _create_page(10)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_label(t("ui.battle_won"), 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	var chest := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture("chest-atlas-v1.png")
	atlas.region = Rect2(0, 0, atlas.atlas.get_width() / 2.0, atlas.atlas.get_height())
	chest.texture = atlas
	chest.custom_minimum_size = Vector2(200, 180)
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest.pivot_offset = Vector2(100, 90)
	page.add_child(chest)

	var open := _button(t("ui.open_chest"), Callable(), EMBER, Vector2(220, 52))
	open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open.pressed.connect(func(): _open_chest(chest, atlas, open))
	page.add_child(open)

func _open_chest(chest: TextureRect, atlas: AtlasTexture, button: Button) -> void:
	button.disabled = true
	_haptic("heavy")
	var shake := chest.create_tween()
	shake.tween_property(chest, "rotation", -0.05, 0.08)
	shake.tween_property(chest, "rotation", 0.05, 0.08)
	shake.tween_property(chest, "rotation", -0.03, 0.07)
	shake.tween_property(chest, "rotation", 0.0, 0.07)
	await shake.finished

	atlas.region.position.x = atlas.atlas.get_width() / 2.0
	chest.texture = atlas
	_shake_screen(6.0)
	var pop := chest.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(chest, "scale", Vector2(1.12, 1.12), 0.16)
	pop.tween_property(chest, "scale", Vector2.ONE, 0.12)
	await pop.finished
	await get_tree().create_timer(_battle_delay(0.25)).timeout

	_grant_stage_rewards()
	_advance_quest("open_chest", 1)
	if pending_boon_draft:
		pending_boon_draft = false
		show_abyss_boon_draft()
		return
	# The chest and its button have done their job; rebuild the page so only the
	# rewards and the card choice remain on screen.
	show_reward_details()

# A stage below the unlock frontier has been cleared before. Stages cannot be skipped, so
# this is a reliable "have I already beaten it" test without tracking a separate set.
func _is_replay(index: int) -> bool:
	return index < int(profile.unlocked)

func _is_stage_event_claimed(index: int) -> bool:
	if _is_replay(index): return true
	return profile.get("claimed_stage_events", []).has(index)

func _mark_stage_event_claimed(index: int) -> void:
	if not profile.has("claimed_stage_events") or not profile.claimed_stage_events is Array:
		profile.claimed_stage_events = []
	if not profile.claimed_stage_events.has(index):
		profile.claimed_stage_events.append(index)
		SpiritSave.write(profile)

# Compendium discovery is a permanent log, not a live inventory: a card/relic/rune/equipment
# never un-discovers even in a hypothetical future where it could be lost, and a Bestiary
# entry has no other tracking array to fall back on. The _x_discovered() helpers below still
# OR in the existing inventory arrays as a fallback so saves from before this milestone show
# their already-owned items as discovered without needing a migration pass.
func _compendium_dict(category: String) -> Dictionary:
	if not profile.get("compendium_discovered") is Dictionary: profile.compendium_discovered = {}
	if not profile.compendium_discovered.get(category) is Dictionary: profile.compendium_discovered[category] = {}
	return profile.compendium_discovered[category]

func _mark_discovered(category: String, key: String) -> void:
	var dict := _compendium_dict(category)
	if not bool(dict.get(key, false)):
		dict[key] = true
		SpiritSave.write(profile)

func _card_discovered(id: String) -> bool:
	return bool(_compendium_dict("cards").get(id, false)) or int(profile.collection.get(id, 0)) > 0

func _equip_discovered(id: String) -> bool:
	return bool(_compendium_dict("equipment").get(id, false)) or profile.equipment_owned.has(id)

func _rune_discovered(id: String) -> bool:
	return bool(_compendium_dict("runes").get(id, false)) or int(profile.rune_inventory.get(id, 0)) > 0 or profile.card_runes.values().has(id)

func _relic_discovered(id: String) -> bool:
	return bool(_compendium_dict("relics").get(id, false)) or profile.relics.has(id)

func _bestiary_discovered(enemy_name: String) -> bool:
	return bool(_compendium_dict("bestiary").get(enemy_name, false))

func _compendium_totals() -> Vector2i:
	var discovered := 0
	var total := 0
	for c in content.cards:
		if c.get("rarity", "") == "Curse": continue
		total += 1
		if _card_discovered(c.id): discovered += 1
	for e in SpiritContent.EQUIPMENT:
		total += 1
		if _equip_discovered(e.id): discovered += 1
	for r in SpiritContent.RUNES:
		total += 1
		if _rune_discovered(r.id): discovered += 1
	for r in SpiritContent.RELICS:
		total += 1
		if _relic_discovered(r.id): discovered += 1
	for e in SpiritContent.ENEMIES:
		total += 1
		if _bestiary_discovered(str(e.name)): discovered += 1
	return Vector2i(discovered, total)

# Every battle win feeds mastery XP to whichever hero is currently equipped — a boss kill is
# worth double a regular fight, halved again on a campaign replay, same discount campaign
# gold already takes. Abyss and Daily Trial wins call this with their own flat amounts since
# neither has a "kind"/"replay" concept to scale off of.
func _grant_mastery_xp(amount: int) -> void:
	if amount <= 0: return
	var hero_id: String = str(profile.hero_class)
	if not profile.get("hero_masteries") is Dictionary: profile.hero_masteries = {}
	var entry: Dictionary = profile.hero_masteries.get(hero_id, {"xp": 0})
	var before_level: int = content.mastery_level_for_xp(int(entry.get("xp", 0)))
	entry.xp = int(entry.get("xp", 0)) + amount
	profile.hero_masteries[hero_id] = entry
	var after_level: int = content.mastery_level_for_xp(int(entry.xp))
	if after_level > before_level:
		_toast(tf("ui.mastery_levelup_toast", [content.hero_name(content.hero_class(hero_id), lang), after_level]), GOLD)

func _current_hero_mastery_bonuses() -> Dictionary:
	var hero_id: String = str(profile.hero_class)
	var xp: int = int(profile.get("hero_masteries", {}).get(hero_id, {}).get("xp", 0))
	return content.mastery_bonuses(hero_id, content.mastery_level_for_xp(xp))

# Battle screen header/background source of truth: campaign battles index straight into
# content.encounters, while Abyss and the Daily Trial are their own procedural tracks that
# don't live in that array (current_stage is left at 0 for both, same placeholder abyss
# already used before this existed).
func _current_encounter() -> Dictionary:
	if in_abyss: return content.abyss_encounter(int(profile.get("abyss_floor", 1)))
	if in_daily_trial: return content.daily_trial_encounter(int(profile.daily_trial_record.get("stage", 0)) + 1)
	return content.encounters[current_stage]

func _current_stage_label() -> String:
	if in_abyss: return tf("ui.abyss_stage_label_fmt", int(profile.get("abyss_floor", 1)))
	if in_daily_trial: return tf("ui.daily_trial_stage_label_fmt", [int(profile.daily_trial_record.get("stage", 0)) + 1, SpiritContent.DAILY_TRIAL_STAGES])
	return content.stage_name(current_stage, lang)

func _grant_stage_rewards() -> void:
	if in_abyss:
		in_abyss = false
		var floor_num: int = int(profile.get("abyss_floor", 1))
		var bonus_mult: float = 1.5 if profile.get("abyss_boons", []).has("boon_golden_fortune") else 1.0
		var gold_gain: int = int(round((25 + floor_num * 5) * bonus_mult))
		profile.gold += gold_gain
		profile.abyss_floor = floor_num + 1
		profile.abyss_record = maxi(int(profile.get("abyss_record", 0)), floor_num)
		profile.health = mini(60, int(combat.state.player.health) + 15)
		pending_rewards = {"gold": gold_gain, "equipment": "", "rune": "", "relic": "", "replay": false}
		SpiritSave.write(profile)
		_advance_quest("win_battles", 1)
		_advance_quest("earn_gold", gold_gain)
		_grant_mastery_xp(20)
		if floor_num % 5 == 0:
			pending_boon_draft = true
		return
	if in_daily_trial:
		in_daily_trial = false
		var stage_num: int = int(profile.daily_trial_record.stage) + 1
		var gold_gain: int = int(content.daily_trial_encounter(stage_num).reward)
		profile.gold += gold_gain
		profile.daily_trial_record.stage = stage_num
		profile.daily_trial_record.best_stage = maxi(int(profile.daily_trial_record.get("best_stage", 0)), stage_num)
		profile.health = mini(60, int(combat.state.player.health) + 8)
		var completed: bool = stage_num >= SpiritContent.DAILY_TRIAL_STAGES
		if completed:
			profile.daily_trial_record.badges = int(profile.daily_trial_record.get("badges", 0)) + 1
			var streak: int = int(profile.daily_trial_record.get("streak", 0)) + 1
			profile.daily_trial_record.streak = streak
			var streak_claimed: Array = profile.daily_trial_record.get("streak_claimed", []).duplicate()
			for target in [3, 7, 14]:
				if streak >= target and not streak_claimed.has(target):
					streak_claimed.append(target)
					var bonus_gold: int = 100 if target == 3 else (250 if target == 7 else 500)
					profile.gold += bonus_gold
					_toast(tf("ui.trial_streak_reward_toast", [target, bonus_gold]), GOLD)
			profile.daily_trial_record.streak_claimed = streak_claimed
		pending_rewards = {"gold": gold_gain, "equipment": "", "rune": "", "relic": "", "replay": false, "daily_trial": true, "daily_trial_stage": stage_num, "daily_trial_completed": completed}
		SpiritSave.write(profile)
		_advance_quest("win_battles", 1)
		_advance_quest("earn_gold", gold_gain)
		_grant_mastery_xp(12 + stage_num)
		return
	var encounter: Dictionary = content.encounters[current_stage]
	var multiplier: float = active_modifier.get("reward_scale", 1.0)
	if profile.equipment_slots.values().has("fortuneSeal"): multiplier *= 1.15
	var replay := _is_replay(current_stage) and not is_hard_replay
	# Farming an old stage pays half and drops no items, so grinding gold stays possible
	# while re-collecting cards and gear does not.
	if replay: multiplier *= 0.5
	pending_rewards = {"gold": int(round(encounter.reward * multiplier)), "equipment": "", "rune": "", "relic": "", "replay": replay, "is_hard_replay": is_hard_replay}
	profile.gold += int(pending_rewards.gold)
	if not replay:
		profile.health = mini(60, int(combat.state.player.health) + 10)
	else:
		profile.health = int(combat.state.player.health)
	profile.unlocked = maxi(int(profile.unlocked), mini(content.encounters.size() - 1, current_stage + 1))
	profile.position = current_stage
	_mark_stage_event_claimed(current_stage)

	var kind := content.node_kind(current_stage)
	_advance_quest("win_battles", 1)
	_advance_quest("earn_gold", int(pending_rewards.gold))
	if content.is_boss_kind(kind) or kind == "elite": _advance_quest("clear_elite_or_boss", 1)
	if kind == "greatboss": _advance_quest("defeat_great_boss", 1)
	var mastery_xp: int = 24 if content.is_boss_kind(kind) else 12
	if replay: mastery_xp = int(mastery_xp / 2)
	_grant_mastery_xp(mastery_xp)
	if replay:
		is_hard_replay = false
		SpiritSave.write(profile)
		return

	if content.is_boss_kind(kind):
		var order := ["emberBlade","jadePlate","soulPendant","moonStaff","thornArmor","tideCharm","stoneSpear","mistCloak","fortuneSeal","stormBow","phoenixMail","focusCharm"]
		var id: String = order[(current_stage / 5 + int(profile.difficulty) * 2) % order.size()]
		if not profile.equipment_owned.has(id): profile.equipment_owned.append(id)
		pending_rewards.equipment = id
		_mark_discovered("equipment", id)
		# Great Bosses draw exclusively from the high-stakes boss relic pool (cursedTome,
		# titanBell, chaosPrism) so those stay rare and mean something; regular bosses draw
		# from everything else, same rotation as before.
		var relic_pool: Array = SpiritContent.RELICS
		if kind == "greatboss":
			relic_pool = SpiritContent.RELICS.filter(func(r): return SpiritContent.BOSS_RELIC_IDS.has(r.id))
		else:
			relic_pool = SpiritContent.RELICS.filter(func(r): return not SpiritContent.BOSS_RELIC_IDS.has(r.id))
		var relic: Dictionary = relic_pool[(current_stage / 5) % relic_pool.size()]
		if not profile.relics.has(relic.id):
			profile.relics.append(relic.id)
			pending_rewards.relic = relic.id
		_mark_discovered("relics", relic.id)
	elif kind == "elite":
		var rune: Dictionary = SpiritContent.RUNES[(current_stage / 5 + int(profile.difficulty)) % SpiritContent.RUNES.size()]
		profile.rune_inventory[rune.id] = profile.rune_inventory.get(rune.id, 0) + 1
		pending_rewards.rune = rune.id
		_mark_discovered("runes", rune.id)
	is_hard_replay = false
	SpiritSave.write(profile)

func show_reward_details() -> void:
	_clear(); _play_music(false)
	var page := _create_page(8)
	page.add_child(_label(t("ui.battle_won"), 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	if current_stage < 3 or int(profile.unlocked) <= 3:
		var stats: Dictionary = combat.state.get("stats", {}) if combat and combat.state else {}
		if not stats.is_empty():
			page.add_child(_build_victory_recap_card(stats))

	var spoils := HBoxContainer.new()
	spoils.alignment = BoxContainer.ALIGNMENT_CENTER
	spoils.add_theme_constant_override("separation", 14)
	page.add_child(spoils)
	spoils.add_child(_label(tf("ui.reward_gold_line", int(pending_rewards.get("gold", 0))), 15, GOLD))
	if not pending_rewards.get("replay", false):
		spoils.add_child(_label(t("ui.reward_heal_line"), 13, JADE))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var equip_id := str(pending_rewards.get("equipment", ""))
	if not equip_id.is_empty():
		var item := content.equipment(equip_id)
		list.add_child(_reward_item(tf("ui.boss_equip_title", [item.icon, _equip_name(item)]), _equip_detail(item), GOLD))
	var relic_id := str(pending_rewards.get("relic", ""))
	if not relic_id.is_empty():
		var relic := content.relic(relic_id)
		list.add_child(_reward_item(tf("ui.relic_reward_title", [relic.icon, _relic_name(relic)]), _relic_detail(relic), Color(relic.color)))
	var rune_id := str(pending_rewards.get("rune", ""))
	if not rune_id.is_empty():
		var rune := content.rune(rune_id)
		list.add_child(_reward_item(tf("ui.elite_rune_title", [rune.icon, _rune_name(rune)]), _rune_detail(rune), Color(rune.color)))

	if bool(pending_rewards.get("replay", false)):
		list.add_child(_label(t("ui.reward_replay_note"), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
		page.add_child(_button(t("ui.return_map"), _finish_reward, EMBER, Vector2(0, 50)))
		return

	if bool(pending_rewards.get("daily_trial", false)):
		if bool(pending_rewards.get("daily_trial_completed", false)):
			list.add_child(_label(t("ui.daily_trial_complete"), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
		list.add_child(_label(tf("ui.daily_trial_progress_reward_fmt", int(pending_rewards.get("daily_trial_stage", 0))), 12, JADE, HORIZONTAL_ALIGNMENT_CENTER))
		page.add_child(_button(t("ui.return_map"), _finish_reward, EMBER, Vector2(0, 50)))
		return

	list.add_child(_label(t("ui.reward_choose"), 13, JADE, HORIZONTAL_ALIGNMENT_CENTER))
	var options: Array = content.cards.filter(func(card): return card.rarity != "Starter" and card.get("rarity", "") != "Curse")
	for offset in 3:
		list.add_child(_reward_card_row(options[(current_stage + offset) % options.size()]))

func _reward_card_row(card: Dictionary) -> Control:
	var accent := _card_color(card)
	var owned: int = int(profile.collection.get(card.id, 0))
	var in_deck: int = profile.deck.count(card.id)

	var panel := Panel.new()
	panel.custom_minimum_size.y = 126
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("11242a"), 12, accent))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 8)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)

	var art_holder := Control.new()
	art_holder.custom_minimum_size = Vector2(76, 106)
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art_holder)
	art_holder.add_child(_card_art_panel(card.id, Vector2(76, 106)))
	var badge := _cost_badge(int(card.cost), accent, 24)
	badge.position = Vector2(3, 3)
	art_holder.add_child(badge)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 2)
	row.add_child(right)

	right.add_child(_label(content.text(card.nameKey, lang), 15, TEXT))
	right.add_child(_label("%s · %s · %s" % [t("kind.%s" % card.get("kind", "Skill")), t("element.%s" % card.get("element", "spirit")), card.rarity], 9, GOLD))
	var desc := _label(_card_description(card), 11, Color("cfe3e0"), HORIZONTAL_ALIGNMENT_LEFT, true)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(desc)
	right.add_child(_label("%s · %s" % [tf("ui.reward_owned", owned), tf("ui.reward_in_deck", in_deck)], 9, MUTED))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	right.add_child(actions)
	var collect := _button(t("ui.reward_collect"), func(): _collect_card(card), Color("24444b"), Vector2(0, 38))
	collect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(collect)
	var add := _button(t("ui.reward_smart_add"), func(): _smart_add_card(card), Color("2f5c3f"), Vector2(0, 38))
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(add)

	return panel

func _collect_card(card: Dictionary) -> void:
	if int(profile.collection.get(card.id, 0)) == 0: _advance_quest("collect_cards", 1)
	profile.collection[card.id] = profile.collection.get(card.id, 0) + 1
	_mark_discovered("cards", card.id)
	SpiritSave.write(profile)
	_toast(tf("ui.reward_collected", content.text(card.nameKey, lang)), JADE)
	_finish_reward()

# Adds the card to the deck, and when the deck is already at 25 drops the weakest card
# to make room — starters first, then whatever scores lowest.
func _smart_add_card(card: Dictionary) -> void:
	if int(profile.collection.get(card.id, 0)) == 0: _advance_quest("collect_cards", 1)
	profile.collection[card.id] = profile.collection.get(card.id, 0) + 1
	_mark_discovered("cards", card.id)
	if profile.deck.size() < 25:
		profile.deck.append(card.id)
		SpiritSave.write(profile)
		_toast(tf("ui.reward_added", content.text(card.nameKey, lang)), JADE)
		_finish_reward()
		return

	var worst := -1
	var worst_score := INF
	for i in profile.deck.size():
		var existing := content.card(profile.deck[i])
		if existing.is_empty(): continue
		var score := _card_build_score(existing)
		if str(existing.get("rarity", "")) == "Starter": score -= 100.0
		# Prefer not to cut a copy of the very card being added.
		if str(existing.id) == str(card.id): score += 60.0
		if score < worst_score:
			worst_score = score
			worst = i
	if worst < 0: worst = 0
	var replaced := content.card(profile.deck[worst])
	profile.deck[worst] = card.id
	SpiritSave.write(profile)
	_toast(tf("ui.reward_replaced", [content.text(card.nameKey, lang), content.text(replaced.nameKey, lang)]), JADE)
	_finish_reward()

func _reward_item(title: String, detail: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(340,54); panel.add_theme_stylebox_override("panel",_panel(Color("193839"),12,color)); var stack := VBoxContainer.new(); panel.add_child(stack); stack.add_child(_label(title, 12, color, HORIZONTAL_ALIGNMENT_CENTER)); stack.add_child(_label(detail, 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)); return panel

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
	elif kind == "rest": title = t("ui.rest_title")
	else: title = t("ui.event_default")
	page.add_child(_label("✦", 48, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(_label(title, 21, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(_label(t("ui.rest_prompt") if kind == "rest" else t("ui.event_prompt"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if kind == "event":
		page.add_child(_button(t("ui.event_blood_pact"), func():
			profile.health = maxi(1, profile.health - 15)
			profile.gold += 60
			_advance_quest("earn_gold", 60)
			_mark_stage_event_claimed(index)
			SpiritSave.write(profile)
			_haptic("heavy")
			begin_battle(index)
		, Color("591d1d"), Vector2(300, 48)))
		page.add_child(_button(t("ui.event_spirit_blessing"), func():
			profile.health = mini(60, profile.health + 18)
			_mark_stage_event_claimed(index)
			SpiritSave.write(profile)
			_haptic("tap")
			begin_battle(index)
		, Color("21594e"), Vector2(300, 48)))
		page.add_child(_button(t("ui.rest_smith_choice"), func():
			show_deck_upgrade(func(): show_event(index, "event"), func():
				_mark_stage_event_claimed(index)
				begin_battle(index)
			)
		, EMBER, Vector2(300, 48)))
	elif kind == "rest":
		page.add_child(_button(t("ui.rest_heal_choice"), func():
			profile.health = mini(60, profile.health + 20)
			_mark_stage_event_claimed(index)
			SpiritSave.write(profile)
			_haptic("tap")
			begin_battle(index)
		, Color("21594e"), Vector2(300, 48)))
		page.add_child(_button(t("ui.rest_purify_choice"), func():
			show_deck_purge(func(): show_event(index, "rest"), 0, func():
				_mark_stage_event_claimed(index)
				begin_battle(index)
			)
		, Color("4a285d"), Vector2(300, 48)))
		page.add_child(_button(t("ui.rest_smith_choice"), func():
			show_deck_upgrade(func(): show_event(index, "rest"), func():
				_mark_stage_event_claimed(index)
				begin_battle(index)
			)
		, GOLD, Vector2(300, 48)))
	else:
		page.add_child(_button(t("ui.event_opt_potion"), func():
			if profile.gold >= 30:
				profile.gold -= 30
				profile.health = mini(60, profile.health + 25)
				_mark_stage_event_claimed(index)
				SpiritSave.write(profile)
				_haptic("tap")
			begin_battle(index)
		, EMBER, Vector2(300, 48)))
		page.add_child(_button(t("ui.shop_purge_service") + " · ◆50", func():
			if profile.gold >= 50:
				show_deck_purge(func(): show_event(index, "merchant"), 50, func():
					_mark_stage_event_claimed(index)
					begin_battle(index)
				)
			else:
				_toast(t("ui.shop_no_gold"))
		, Color("3d2154"), Vector2(300, 48)))
		page.add_child(_button(t("ui.event_opt_direct"), func(): begin_battle(index), Color("21594e"), Vector2(300, 48)))

	page.add_child(_button(t("ui.return_map"), show_map, Color("17363e"), Vector2(170, 42)))

func show_deck_purge(return_callback: Callable, cost := 0, on_done := Callable()) -> void:
	_clear(); _play_music(false)
	_back_action = return_callback
	var page := _create_page(12)

	var sub: String = t("ui.purge_sub") + (" · " + tf("ui.shop_gold", cost) if cost > 0 else "")
	var header := _header(t("ui.purge_title"), sub)
	var back_btn := _button("←", return_callback, Color("17363e"), Vector2(36, 34))
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back_btn)
	page.add_child(header)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var seen_ids: Array[String] = []
	for card_id in profile.deck:
		if card_id in seen_ids: continue
		seen_ids.append(card_id)
		var card: Dictionary = content.card(card_id)
		if card.is_empty(): continue
		var count: int = profile.deck.count(card_id)

		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(340, 56)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent := _card_color(card)
		row.add_theme_stylebox_override("panel", _panel(Color("10242b"), 10, accent))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var badge := _cost_badge(int(card.cost), accent)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(badge)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(texts)

		var name_lbl := _label("%s  ×%d" % [content.text(card.nameKey, lang), count], 13, TEXT)
		texts.add_child(name_lbl)
		var kind_lbl := _label("%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), t("rarity.%s" % card.get("rarity", "Common"))], 10, GOLD)
		texts.add_child(kind_lbl)

		var purge_btn := _button(t("ui.purge_confirm"), func():
			if cost > 0 and int(profile.gold) < cost:
				_toast(t("ui.shop_no_gold"))
				return
			if cost > 0: profile.gold -= cost
			var replacement_id := "foxfire" if card.id == "strike" else ("mirrorWard" if card.id == "ward" else "wildSpark")
			var idx: int = profile.deck.find(card.id)
			if idx >= 0: profile.deck[idx] = replacement_id
			if int(profile.collection.get(card.id, 0)) > 0:
				profile.collection[card.id] = maxi(0, int(profile.collection[card.id]) - 1)
			profile.collection[replacement_id] = int(profile.collection.get(replacement_id, 0)) + 1
			SpiritSave.write(profile)
			_haptic("heavy")
			_toast(tf("ui.purged_toast", [content.text(card.nameKey, lang), content.text(content.card(replacement_id).nameKey, lang)]), JADE)
			if on_done.is_valid(): on_done.call()
			else: return_callback.call()
		, EMBER, Vector2(88, 38))
		purge_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(purge_btn)

		list.add_child(row)

func show_deck_upgrade(return_callback: Callable, on_done := Callable()) -> void:
	_clear(); _play_music(false)
	_back_action = return_callback
	var page := _create_page(12)

	var header := _header(t("ui.upgrade_title"), t("ui.upgrade_sub"))
	var back_btn := _button("←", return_callback, Color("17363e"), Vector2(36, 34))
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back_btn)
	page.add_child(header)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var seen_ids: Array[String] = []
	for card_id in profile.deck:
		if card_id in seen_ids: continue
		seen_ids.append(card_id)
		var card: Dictionary = content.card(card_id)
		if card.is_empty(): continue
		var is_upgraded: bool = int(profile.upgrades.get(card_id, 0)) > 0

		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(340, 56)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent := _card_color(card)
		row.add_theme_stylebox_override("panel", _panel(Color("10242b"), 10, accent if not is_upgraded else GOLD))

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var badge := _cost_badge(int(card.cost), accent)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(badge)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(texts)

		var card_name: String = content.text(card.nameKey, lang)
		var name_lbl := _label("%s%s" % [card_name, " +1" if is_upgraded else ""], 13, TEXT)
		texts.add_child(name_lbl)
		var kind_lbl := _label("%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), t("rarity.%s" % card.get("rarity", "Common"))], 10, GOLD)
		texts.add_child(kind_lbl)

		if not is_upgraded:
			var up_btn := _button("+1", func():
				profile.upgrades[card_id] = 1
				SpiritSave.write(profile)
				_haptic("heavy")
				_toast(tf("ui.upgraded_toast", [card_name, card_name]), GOLD)
				if on_done.is_valid(): on_done.call()
				else: return_callback.call()
			, GOLD, Vector2(56, 38))
			up_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(up_btn)
		else:
			var done_lbl := _label("MAX", 11, JADE, HORIZONTAL_ALIGNMENT_CENTER)
			done_lbl.custom_minimum_size = Vector2(56, 38)
			done_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hbox.add_child(done_lbl)

		list.add_child(row)

const SHOP_STOCK_COUNT := 6

# Stock and the day's sale slot are derived from the day number rather than stored, so
# they need no save-file field and can't drift out of sync with the daily quest reset.
func _shop_period() -> Dictionary:
	var day: int = int(Time.get_unix_time_from_system()) / DAY_SECONDS
	return content.roll_shop_stock(day, SHOP_STOCK_COUNT)

func _shop_reset_at() -> int:
	var day: int = int(Time.get_unix_time_from_system()) / DAY_SECONDS
	return (day + 1) * DAY_SECONDS

# Escalating cost is the direct fix for "just buy the same card forever": each copy already
# owned raises the price of the next one, the same shape as Slay the Spire's card-removal
# cost climbing with each use, rather than a flat price with no friction on repeat buys.
func _shop_price(card: Dictionary, owned: int) -> int:
	var base := 90 if card.rarity == "Rare" else 60 if card.rarity == "Uncommon" else 40
	return int(round(float(base) * (1.0 + float(owned) * 0.35) / 5.0)) * 5

func show_shop() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var backdrop := _background("lantern-marsh-v1.jpg", .18); root.add_child(backdrop); root.move_child(backdrop, 0)
	var page := _create_page(8)
	page.add_child(_header(t("ui.shop_title"), t("ui.shop_sub"), show_map))
	page.add_child(_label(tf("ui.shop_refresh", _format_countdown(_shop_reset_at())), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var svc_row := HBoxContainer.new()
	svc_row.custom_minimum_size.y = 56
	svc_row.add_theme_constant_override("separation", 8)
	page.add_child(svc_row)

	var potion := Button.new()
	potion.custom_minimum_size.y = 56
	potion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion.focus_mode = Control.FOCUS_NONE
	var affordable: bool = int(profile.gold) >= 30
	potion.add_theme_stylebox_override("normal", _panel(Color("1d4a40"), 12, JADE if affordable else Color("2a3d42")))
	potion.add_theme_stylebox_override("hover", _panel(Color("245a4d"), 12, JADE))
	potion.add_theme_stylebox_override("pressed", _panel(Color("163a32"), 12, GOLD))
	potion.pressed.connect(_buy_potion)
	svc_row.add_child(potion)

	var potion_row := HBoxContainer.new()
	potion_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	potion_row.add_theme_constant_override("separation", 8)
	potion_row.alignment = BoxContainer.ALIGNMENT_CENTER
	potion_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion.add_child(potion_row)
	var potion_badge := CenterContainer.new()
	potion_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_badge.add_child(_icon_badge("✚", JADE, 32, 16))
	potion_row.add_child(potion_badge)
	var potion_texts := VBoxContainer.new()
	potion_texts.alignment = BoxContainer.ALIGNMENT_CENTER
	potion_texts.add_theme_constant_override("separation", 1)
	potion_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_row.add_child(potion_texts)
	potion_texts.add_child(_label(t("ui.shop_potion"), 11, TEXT))
	potion_texts.add_child(_label(tf("ui.shop_gold", 30), 10, GOLD))

	var purge_svc := Button.new()
	purge_svc.name = "ShopPurgeBtn"
	purge_svc.custom_minimum_size.y = 56
	purge_svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purge_svc.focus_mode = Control.FOCUS_NONE
	var can_purge: bool = int(profile.gold) >= 50
	purge_svc.add_theme_stylebox_override("normal", _panel(Color("261d36"), 12, Color("c79bff") if can_purge else Color("2a3d42")))
	purge_svc.add_theme_stylebox_override("hover", _panel(Color("37264f"), 12, Color("c79bff")))
	purge_svc.add_theme_stylebox_override("pressed", _panel(Color("1c142b"), 12, GOLD))
	purge_svc.pressed.connect(func(): show_deck_purge(show_shop, 50))
	svc_row.add_child(purge_svc)

	var purge_row := HBoxContainer.new()
	purge_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	purge_row.add_theme_constant_override("separation", 8)
	purge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	purge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purge_svc.add_child(purge_row)
	var purge_badge := CenterContainer.new()
	purge_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purge_badge.add_child(_icon_badge("✦", Color("c79bff"), 32, 16))
	purge_row.add_child(purge_badge)
	var purge_texts := VBoxContainer.new()
	purge_texts.alignment = BoxContainer.ALIGNMENT_CENTER
	purge_texts.add_theme_constant_override("separation", 1)
	purge_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purge_row.add_child(purge_texts)
	purge_texts.add_child(_label(t("ui.shop_purge_service"), 11, TEXT))
	purge_texts.add_child(_label(tf("ui.shop_gold", 50), 10, GOLD))

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

	var stock: Dictionary = _shop_period()
	var stock_cards: Array = stock.cards
	for i in stock_cards.size():
		var card: Dictionary = stock_cards[i]
		var owned: int = int(profile.collection.get(card.id, 0))
		var price := _shop_price(card, owned)
		var on_sale: bool = i == int(stock.sale_index)
		if on_sale: price = maxi(5, int(round(float(price) * 0.7 / 5.0)) * 5)
		grid.add_child(_shop_card_tile(card, price, on_sale))

func _shop_card_tile(card: Dictionary, price: int, on_sale := false) -> Control:
	var accent := _card_color(card)
	var can_afford: bool = int(profile.gold) >= price
	var owned: int = int(profile.collection.get(card.id, 0))

	# The tile is inert; only the price button below buys, so brushing a card cannot spend gold.
	var btn := Panel.new()
	btn.name = "ShopTile_%s" % card.id
	btn.custom_minimum_size = Vector2(176, 232)
	btn.size = btn.custom_minimum_size
	btn.pivot_offset = Vector2(88, 116)
	var border_color: Color = GOLD if on_sale else (accent if can_afford else Color("24373d"))
	var tile_style := _panel(Color("1d1a10") if on_sale else Color("11242a"), 12, border_color)
	if on_sale: tile_style.border_width_left = 2; tile_style.border_width_right = 2; tile_style.border_width_top = 2; tile_style.border_width_bottom = 2
	btn.add_theme_stylebox_override("panel", tile_style)
	btn.clip_contents = true

	# 1. Full-bleed card illustration covering the entire tile
	var art := TextureRect.new()
	art.texture = _get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_card_foil(art, str(card.get("rarity", "Common")), false)
	btn.add_child(art)

	# 2. Ornate frame around the entire card perimeter
	_add_ornate_frame(btn, btn.custom_minimum_size, border_color, str(card.get("rarity", "Common")))

	# 3. Top elements (Cost badge, Rarity stars, Sale tag)
	var badge := _cost_badge(int(card.cost), accent)
	badge.position = Vector2(8, 8)
	btn.add_child(badge)

	var rarity_row := _rarity_star_row(str(card.rarity), GOLD, BoxContainer.ALIGNMENT_END)
	rarity_row.position = Vector2(88, 10)
	rarity_row.size = Vector2(76, 16)
	btn.add_child(rarity_row)

	if on_sale:
		var sale_badge := PanelContainer.new()
		sale_badge.custom_minimum_size = Vector2(40, 16)
		sale_badge.position = Vector2(8, 40)
		sale_badge.add_theme_stylebox_override("panel", _panel(Color("a83232"), 8, Color("e06060")))
		var sale_lbl := _label(t("ui.shop_sale"), 8, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		sale_badge.add_child(sale_lbl)
		btn.add_child(sale_badge)

	# 4. Carved-out space in the lower-middle portion for card info
	var info_box := PanelContainer.new()
	info_box.position = Vector2(8, 86)
	info_box.custom_minimum_size = Vector2(160, 138)
	info_box.size = info_box.custom_minimum_size
	var box_style := _panel(Color(0.06, 0.12, 0.16, 0.90), 8, border_color)
	# Slender border overlay margin
	box_style.content_margin_left = 12; box_style.content_margin_right = 12
	box_style.content_margin_top = 4; box_style.content_margin_bottom = 4
	info_box.add_theme_stylebox_override("panel", box_style)
	info_box.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	info_box.add_child(stack)

	stack.add_child(_label(content.text(card.nameKey, lang), 12, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label(_kind_element_line(card), 8, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := _label(_card_description(card), 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.custom_minimum_size.y = 24
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)

	var owned_row := HBoxContainer.new()
	owned_row.alignment = BoxContainer.ALIGNMENT_CENTER
	owned_row.add_theme_constant_override("separation", 4)
	owned_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(owned_row)
	if owned > 0:
		var dots := HBoxContainer.new()
		dots.add_theme_constant_override("separation", 2)
		dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		owned_row.add_child(dots)
		for i in mini(owned, 6):
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(6, 6)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.add_theme_stylebox_override("panel", _panel(JADE, 3))
			dots.add_child(dot)
		if owned > 6: owned_row.add_child(_label("+%d" % (owned - 6), 8, JADE))
	else:
		owned_row.add_child(_label(t("ui.loadout_unobtained"), 9, MUTED))

	var price_row := VBoxContainer.new()
	price_row.add_theme_constant_override("separation", 1)
	stack.add_child(price_row)

	var buy := Button.new()
	buy.name = "BuyButton"
	buy.custom_minimum_size.y = 32
	buy.focus_mode = Control.FOCUS_NONE
	buy.text = "%s  ◆%d" % [t("ui.shop_buy"), price]
	if font_cjk: buy.add_theme_font_override("font", font_cjk)
	buy.add_theme_font_size_override("font_size", 12)
	buy.add_theme_color_override("font_color", Color("0f1d10") if can_afford else Color("c78b7f"))
	buy.add_theme_color_override("font_hover_color", Color("0f1d10"))
	buy.add_theme_stylebox_override("normal", _panel(GOLD if can_afford else Color("3a2723"), 8, GOLD if can_afford else Color("6b4038")))
	buy.add_theme_stylebox_override("hover", _panel(GOLD.lightened(0.15) if can_afford else Color("46302b"), 8, Color.WHITE))
	buy.add_theme_stylebox_override("pressed", _panel(GOLD.darkened(0.2), 8, EMBER))
	buy.add_theme_stylebox_override("disabled", _panel(Color("2a2320"), 8, Color("53403a")))
	buy.disabled = not can_afford
	buy.pressed.connect(func(): _buy_card_with_feedback(btn, card, price))
	price_row.add_child(buy)
	if owned > 0 and not on_sale:
		price_row.add_child(_label(tf("ui.shop_next_price", _shop_price(card, owned + 1)), 8, Color("5e7278"), HORIZONTAL_ALIGNMENT_CENTER))

	return btn

func _buy_potion() -> void:
	if int(profile.gold) < 30: _toast(t("ui.shop_no_gold")); return
	profile.gold -= 30
	profile.health = mini(60, int(profile.health) + 20)
	SpiritSave.write(profile)
	_advance_quest("shop_purchase", 1)
	show_shop()

func _buy_card(card: Dictionary, price: int) -> void:
	if profile.gold < price: _toast(t("ui.shop_no_gold")); return
	profile.gold -= price
	if int(profile.collection.get(card.id, 0)) == 0: _advance_quest("collect_cards", 1)
	profile.collection[card.id] = profile.collection.get(card.id, 0) + 1
	SpiritSave.write(profile)
	_advance_quest("shop_purchase", 1)
	show_shop()
	_toast(tf("ui.shop_bought", content.text(card.nameKey, lang)), JADE)

# A purchase is deliberate and infrequent, unlike a card tap in battle, so it earns a
# synced haptic + flash rather than the plain instant rebuild _buy_card used to do alone —
# haptic timing should land on the visual peak, not fire blind before anything is on screen.
func _buy_card_with_feedback(tile: Panel, card: Dictionary, price: int) -> void:
	if int(profile.gold) < price:
		_toast(t("ui.shop_no_gold"))
		return
	var buy_btn: Button = tile.get_node_or_null("BuyButton") as Button
	if buy_btn: buy_btn.disabled = true
	var pop := tile.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(tile, "scale", Vector2(1.06, 1.06), 0.09)
	pop.tween_property(tile, "scale", Vector2.ONE, 0.14)
	_haptic("tap")
	await pop.finished
	_buy_card(card, price)

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

	# No frame texture here on purpose: this panel is used at thumbnail sizes down to 34x46,
	# and the ornate filigree frame (native 896x1200) turns into a solid muddy smear at that
	# scale — the same "washed out" failure the full-size hand card had, just worse. A plain
	# border reads correctly at any size.
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

# A single rounded border reads as a plain panel; a thin inset accent line plus a small leaf
# ornament at each corner is what turns it into something that reads as a picture frame,
# matching the ornate-border reference for the shop and deck-building screens.
func _add_ornate_frame(tile: Control, size: Vector2, accent: Color, rarity: String = "Common") -> void:
	var inset := Panel.new()
	inset.position = Vector2(3, 3)
	inset.size = size - Vector2(6, 6)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset_style := StyleBoxFlat.new()
	inset_style.bg_color = Color.TRANSPARENT
	inset_style.corner_radius_top_left = 6; inset_style.corner_radius_top_right = 6
	inset_style.corner_radius_bottom_left = 6; inset_style.corner_radius_bottom_right = 6
	inset_style.border_width_left = 1; inset_style.border_width_right = 1
	inset_style.border_width_top = 1; inset_style.border_width_bottom = 1
	inset_style.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	inset.add_theme_stylebox_override("panel", inset_style)
	tile.add_child(inset)

	var frame_overlay := TextureRect.new()
	frame_overlay.texture = _get_card_frame_texture(rarity)
	frame_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(frame_overlay)

# Three tiers of the card's own rarity read as a row of small drawn stars instead of a raw
# English rarity word left untranslated in the Chinese UI.
func _rarity_star_row(rarity: String, color := GOLD, align := BoxContainer.ALIGNMENT_CENTER) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = align
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count: int = 3 if rarity == "Rare" else (2 if rarity == "Uncommon" else 1)
	for i in count:
		var star := GameIcon.new()
		star.kind = "star"
		star.icon_color = color
		star.custom_minimum_size = Vector2(11, 11)
		star.size = star.custom_minimum_size
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(star)
	return row

func show_deck() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(6)
	page.add_child(_header(t("ui.deck_title"), tf("ui.deck_sub", profile.deck.size()), show_map))

	# Search & Filter Chips (F3)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	var search_edit := LineEdit.new()
	search_edit.name = "DeckSearchInput"
	search_edit.placeholder_text = t("ui.deck_search_placeholder")
	search_edit.text = deck_search_query
	search_edit.custom_minimum_size = Vector2(0, 34)
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.text_submitted.connect(func(new_text: String):
		deck_search_query = new_text
		show_deck()
	)
	search_row.add_child(search_edit)
	if not deck_search_query.is_empty():
		var clear_btn := _button("✕", func():
			deck_search_query = ""
			show_deck()
		, Color("2d2218"), Vector2(34, 34))
		search_row.add_child(clear_btn)
	page.add_child(search_row)

	var kind_chips := HBoxContainer.new()
	kind_chips.name = "DeckKindChips"
	kind_chips.add_theme_constant_override("separation", 4)
	for item in [["all", t("ui.deck_filter_all")], ["Attack", t("ui.deck_filter_attack")], ["Skill", t("ui.deck_filter_skill")], ["Power", t("ui.deck_filter_power")], ["Tactic", t("ui.deck_filter_tactic")]]:
		var k_id: String = item[0]
		var k_name: String = item[1]
		var active: bool = deck_filter_kind == k_id
		var chip := _button(k_name, func(): deck_filter_kind = k_id; show_deck(), EMBER if active else Color("172a30"), Vector2(0, 28))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kind_chips.add_child(chip)
	page.add_child(kind_chips)

	var elem_chips := HBoxContainer.new()
	elem_chips.name = "DeckElementChips"
	elem_chips.add_theme_constant_override("separation", 3)
	for item in [["all", t("ui.deck_filter_elem_all")], ["", t("ui.deck_filter_elem_none")], ["fire", t("ui.deck_filter_elem_fire")], ["gale", t("ui.deck_filter_elem_gale")], ["stone", t("ui.deck_filter_elem_stone")], ["water", t("ui.deck_filter_elem_water")], ["poison", t("ui.deck_filter_elem_poison")]]:
		var e_id: String = item[0]
		var e_name: String = item[1]
		var active: bool = deck_filter_element == e_id
		var chip := _button(e_name, func(): deck_filter_element = e_id; show_deck(), JADE if active else Color("112226"), Vector2(0, 26))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elem_chips.add_child(chip)
	page.add_child(elem_chips)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 14)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sections)

	# Grouped by rarity, richest first — a roster of thirty-some cards read as one undivided
	# grid before; a section header with its own star row tells you what you're looking at.
	var shown := 0
	for rarity in ["Rare", "Uncommon", "Common", "Starter"]:
		var group: Array = []
		for card in content.cards:
			if str(card.rarity) != rarity: continue
			if int(profile.collection.get(card.id, 0)) == 0: continue
			if deck_filter_kind != "all" and str(card.get("kind", "")) != deck_filter_kind: continue
			if deck_filter_element != "all" and str(card.get("element", "")) != deck_filter_element: continue
			if not deck_search_query.strip_edges().is_empty():
				var q: String = deck_search_query.to_lower().strip_edges()
				var c_name: String = str(content.card_name(card, lang)).to_lower()
				var c_desc: String = str(content.card_desc(card, lang)).to_lower()
				if not (q in c_name or q in c_desc or q in str(card.id).to_lower()): continue
			group.append(card)
		if group.is_empty(): continue

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		header.add_child(_rarity_star_row(rarity))
		header.add_child(_label(t("rarity.%s" % rarity), 12, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		sections.add_child(header)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		sections.add_child(grid)
		for card in group:
			grid.add_child(_deck_card_tile(card, int(profile.collection.get(card.id, 0))))
			shown += 1
	if shown == 0:
		sections.add_child(_label(t("ui.deck_need_cards"), 12, MUTED))

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

	var border_color: Color = accent if in_deck > 0 else Color("24373d")
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(176, 232)
	tile.size = tile.custom_minimum_size
	tile.add_theme_stylebox_override("panel", _panel(Color("11242a"), 12, border_color))
	tile.clip_contents = true

	# 1. Full-bleed card illustration covering the entire tile
	var art := TextureRect.new()
	art.texture = _get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_card_foil(art, str(card.get("rarity", "Common")), int(profile.upgrades.get(card.id, 0)) > 0)
	tile.add_child(art)

	# 2. Ornate frame around the entire card perimeter
	_add_ornate_frame(tile, tile.custom_minimum_size, border_color, str(card.get("rarity", "Common")))

	# 3. Top elements (Cost badge, Rune icon, Rarity stars)
	var badge := _cost_badge(int(card.cost), accent)
	badge.position = Vector2(8, 8)
	tile.add_child(badge)

	if not rune_id.is_empty():
		var rune_info := content.rune(rune_id)
		var rune_path := "res://assets/icons/rune_%s.png" % rune_id
		if ResourceLoader.exists(rune_path):
			var r_tr := TextureRect.new()
			r_tr.texture = load(rune_path)
			r_tr.position = Vector2(38, 8)
			r_tr.custom_minimum_size = Vector2(22, 22)
			r_tr.size = r_tr.custom_minimum_size
			r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(r_tr)
		else:
			var rune_lbl := _label(rune_info.icon, 15, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
			rune_lbl.position = Vector2(40, 8)
			rune_lbl.size = Vector2(20, 20)
			tile.add_child(rune_lbl)

	var rarity_row := _rarity_star_row(str(card.rarity), GOLD, BoxContainer.ALIGNMENT_END)
	rarity_row.position = Vector2(88, 10)
	rarity_row.size = Vector2(76, 16)
	tile.add_child(rarity_row)

	# 4. Carved-out space in the lower-middle portion for card info
	var info_box := PanelContainer.new()
	info_box.position = Vector2(8, 86)
	info_box.custom_minimum_size = Vector2(160, 138)
	info_box.size = info_box.custom_minimum_size
	var box_style := _panel(Color(0.06, 0.12, 0.16, 0.90), 8, border_color)
	# Slender border overlay margin
	box_style.content_margin_left = 12; box_style.content_margin_right = 12
	box_style.content_margin_top = 4; box_style.content_margin_bottom = 4
	info_box.add_theme_stylebox_override("panel", box_style)
	info_box.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	info_box.add_child(stack)

	var up_lvl: int = int(profile.upgrades.get(card.id, 0))
	stack.add_child(_label(content.text(card.nameKey, lang) + (" +" if up_lvl > 0 else ""), 12, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(_label(_kind_element_line(card), 8, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var desc := _label(_card_description(card), 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.custom_minimum_size.y = 24
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)

	var counts := _label("%s %d · %s %d" % [t("ui.deck_in_deck"), in_deck, t("ui.deck_owned_short"), owned], 9, JADE if in_deck > 0 else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(counts)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(controls)
	var minus := _button("−", func(): _deck_change(card.id, -1), Color("593b32"), Vector2(50, 30))
	minus.disabled = in_deck <= 0
	controls.add_child(minus)
	var plus := _button("+", func(): _deck_change(card.id, 1), Color("245247"), Vector2(50, 30))
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

# This drives both auto-build and smart-add, so it has to judge what a card actually
# does. It used to be almost pure rarity (Rare +30 vs Common +12, minus a small cost
# penalty), which happily filled a deck with every Power/Tactic utility card the shop
# offered — foxBlessing, soulBrand, mountainSeal, titanForm — while starving it of the
# reliable single-target damage that closes out fights. On real content that deck lost
# repeatedly to a chapter-7 boss with two enemies, because nothing in hand ever finished
# the add before it added up. Rarity now nudges the score instead of dominating it.
func _card_build_score(card: Dictionary) -> float:
	var score := 0.0
	var attack_double: float = 2.0 if str(card.get("special", "")) == "critical" else 1.0
	for effect in card.effects:
		match effect.operation:
			"damage": score += float(effect.amount) * 2.2 * attack_double
			"shield": score += float(effect.amount) * 1.6
			"heal": score += float(effect.amount) * 1.0
			"draw": score += float(effect.amount) * 3.0
			"energy": score += float(effect.amount) * 4.0
			"status":
				match str(effect.get("status", "")):
					"burn": score += float(effect.amount) * 1.3
					"focus": score += float(effect.amount) * 2.0
					"strength": score += float(effect.amount) * 3.0
					"vulnerable", "weak": score += float(effect.amount) * 1.8
	match str(card.get("special", "")):
		"cleave": score *= 1.35
		"pierce": score += 3.0
		"stun": score += 5.0
		"recoverExhaust", "recycleDiscard": score += 4.0

	score += {"Rare": 4.0, "Uncommon": 2.0, "Common": 1.0}.get(card.get("rarity", "Common"), 0.0)
	score += float(int(profile.upgrades.get(card.id, 0))) * 6.0
	# With costs now up to 3, an expensive card has to earn a bigger share of a turn.
	score -= float(int(card.cost)) * 3.0
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
		badge_row.add_child(_equip_icon_badge(item, GOLD, 38) if filled else _icon_badge("＋", Color("3c5057"), 38, 18))
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
		badge_holder.add_child(_equip_icon_badge(item, accent, 44))
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
		var rune_badge := _rune_icon_badge(rune, color if available > 0 else Color("3c5057"), 34)
		var rune_badge_holder := CenterContainer.new()
		rune_badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rune_badge_holder.add_child(rune_badge)
		stack.add_child(rune_badge_holder)
		stack.add_child(_label(_rune_name(rune), 9, TEXT if available > 0 else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(_label("×%d" % maxi(0, available), 9, GOLD if available > 0 else MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if not selected_rune.is_empty():
		var chosen := content.rune(selected_rune)
		var hint := _label("%s %s · %s" % [chosen.icon, _rune_name(chosen), _rune_detail(chosen)], 10, Color(chosen.color), HORIZONTAL_ALIGNMENT_CENTER, true)
		list.add_child(hint)

	list.add_child(_label(t("ui.rune_resonance_title"), 13, JADE))
	var active_sets: Array = content.active_rune_sets(profile.card_runes)
	for rune_set in SpiritContent.RUNE_SETS:
		var is_active: bool = active_sets.has(rune_set.id)
		var set_color: Color = Color(rune_set.color)
		var row := Panel.new()
		row.custom_minimum_size.y = 58
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("panel", _panel(Color("173a2e") if is_active else Color("101f24"), 12, set_color if is_active else Color("28393e")))
		list.add_child(row)
		var set_pad := MarginContainer.new()
		set_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: set_pad.add_theme_constant_override("margin_%s" % side, 10)
		set_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(set_pad)
		var set_stack := VBoxContainer.new()
		set_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		set_stack.add_theme_constant_override("separation", 1)
		set_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_pad.add_child(set_stack)
		var set_head := HBoxContainer.new()
		set_head.alignment = BoxContainer.ALIGNMENT_CENTER
		set_head.add_theme_constant_override("separation", 6)
		set_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_stack.add_child(set_head)
		set_head.add_child(_label(t("set.%s.name" % str(rune_set.id).trim_prefix("set_")), 12, set_color if is_active else TEXT))
		set_head.add_child(_label(t("ui.rune_resonance_active") if is_active else t("ui.rune_resonance_inactive"), 9, JADE if is_active else MUTED))
		set_stack.add_child(_label(t("set.%s.desc" % str(rune_set.id).trim_prefix("set_")), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

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

func show_compendium() -> void:
	_clear(); _play_music(false)
	_back_action = show_camp
	var page := _create_page(6)
	page.add_child(_header(t("ui.compendium_title"), t("ui.compendium_sub"), show_camp))
	var totals := _compendium_totals()
	var pct: int = int(round(float(totals.x) / float(maxi(1, totals.y)) * 100.0))
	page.add_child(_build_compendium_milestones_bar(pct))
	page.add_child(_tab_bar([
		["cards", t("ui.compendium_tab_cards")],
		["gear", t("ui.compendium_tab_gear")],
		["runes", t("ui.tab_runes")],
		["relics", t("ui.relic_title")],
		["bestiary", t("ui.compendium_tab_bestiary")],
		["achievements", t("ui.compendium_tab_achievements")],
	], compendium_tab, func(id): compendium_tab = id; show_compendium()))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	match compendium_tab:
		"cards": _build_compendium_cards(list)
		"gear": _build_compendium_equipment(list)
		"runes": _build_compendium_runes(list)
		"relics": _build_compendium_relics(list)
		"bestiary": _build_compendium_bestiary(list)
		_: _build_compendium_achievements(list)

func _build_compendium_milestones_bar(pct: int) -> Control:
	var bar_panel := PanelContainer.new()
	bar_panel.name = "CompendiumMilestonesBar"
	bar_panel.custom_minimum_size = Vector2(340, 56)
	bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_panel.add_theme_stylebox_override("panel", _panel(Color("10221c"), 12, Color("356554")))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 6)
	bar_panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	pad.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.add_child(_label(t("ui.compendium_milestones_title"), 10, JADE))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_row.add_child(sp)
	title_row.add_child(_label("%d%%" % pct, 10, GOLD))
	stack.add_child(title_row)

	var btns_row := HBoxContainer.new()
	btns_row.add_theme_constant_override("separation", 6)
	stack.add_child(btns_row)

	var claimed: Array = profile.get("compendium_milestones_claimed", [])
	for target in [50, 80, 100]:
		var is_claimed: bool = claimed.has(target)
		var is_ready: bool = pct >= target and not is_claimed
		var text_str: String = "✓ %d%%" % target if is_claimed else (tf("ui.compendium_milestone_btn_fmt", target) if is_ready else "🔒 %d%%" % target)
		var btn := _button(text_str, func(): _claim_compendium_milestone(target), GOLD if is_ready else Color("1a352c"), Vector2(0, 26))
		btn.name = "MilestoneBtn_%d" % target
		btn.disabled = not is_ready
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns_row.add_child(btn)

	return bar_panel

func _claim_compendium_milestone(target: int) -> void:
	var claimed: Array = profile.get("compendium_milestones_claimed", []).duplicate()
	if claimed.has(target): return
	claimed.append(target)
	profile.compendium_milestones_claimed = claimed
	var gold_reward: int = 200 if target == 50 else (500 if target == 80 else 1000)
	profile.gold += gold_reward
	if target >= 50:
		_grant_mastery_xp(100)
	SpiritSave.write(profile)
	_toast(tf("ui.compendium_milestone_toast", target), GOLD)
	show_compendium()

# Shared row shell for every Compendium tab: an icon/art badge on the left, a title (or the
# generic "undiscovered" label) and one detail line on the right. Discovered items get their
# real color as the border accent; undiscovered ones fall back to a flat, uninformative gray
# so nothing about a locked entry's rarity or theme leaks through before it's actually found.
func _compendium_row(badge: Control, title: String, detail: String, discovered: bool, accent: Color) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size.y = 68
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border: Color = accent if discovered else Color("2a3d42")
	panel.add_theme_stylebox_override("panel", _panel(Color("13282e") if discovered else Color("0e191d"), 12, border))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pad.add_child(row)

	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(50, 60)
	holder.add_child(badge)
	row.add_child(holder)

	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	texts.add_child(_label(title if discovered else t("ui.compendium_locked"), 13, TEXT if discovered else MUTED))
	if discovered and not detail.is_empty():
		var detail_lbl := _label(detail, 9, JADE, HORIZONTAL_ALIGNMENT_LEFT, true)
		detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(detail_lbl)

	return panel

func _compendium_locked_badge() -> Control:
	return _icon_badge("?", Color("3c5057"), 46, 20)

func _build_compendium_cards(list: VBoxContainer) -> void:
	var totals := _compendium_totals()
	list.add_child(_label(tf("ui.compendium_progress", [totals.x, totals.y]), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	# Curse cards (decay_blight, void_curse) are enemy-inflicted battle hazards, never something
	# a player collects — showing them here would be a permanently "undiscovered" entry with no
	# way to ever complete it.
	for card in content.cards.filter(func(c): return c.get("rarity", "") != "Curse"):
		var discovered := _card_discovered(card.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = _card_art_panel(card.id, Vector2(44, 60))
		var detail := "%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), _card_description(card)]
		list.add_child(_compendium_row(badge, content.text(card.nameKey, lang), detail, discovered, _card_color(card)))

func _build_compendium_equipment(list: VBoxContainer) -> void:
	for item in SpiritContent.EQUIPMENT:
		var discovered := _equip_discovered(item.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = _equip_icon_badge(item, GOLD, 46)
		list.add_child(_compendium_row(badge, _equip_name(item), _equip_detail(item), discovered, GOLD))

func _build_compendium_runes(list: VBoxContainer) -> void:
	for rune in SpiritContent.RUNES:
		var discovered := _rune_discovered(rune.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = _rune_icon_badge(rune, Color(rune.color), 46)
		list.add_child(_compendium_row(badge, _rune_name(rune), _rune_detail(rune), discovered, Color(rune.color)))

func _build_compendium_relics(list: VBoxContainer) -> void:
	for relic in SpiritContent.RELICS:
		var discovered := _relic_discovered(relic.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = _sigil_icon_badge(str(relic.get("icon_mark", "sparkle")), Color(relic.color), 46)
		list.add_child(_compendium_row(badge, _relic_name(relic), _relic_detail(relic), discovered, Color(relic.color)))

func _build_compendium_bestiary(list: VBoxContainer) -> void:
	for enemy in SpiritContent.ENEMIES:
		var discovered := _bestiary_discovered(str(enemy.name))
		var name_str: String = str(enemy.name_en) if lang == "en" else str(enemy.name)
		var badge: Control
		if discovered:
			var tex := TextureRect.new()
			tex.texture = _get_character_texture(_art_key_for_enemy(enemy))
			tex.custom_minimum_size = Vector2(46, 46)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge = tex
		else:
			badge = _compendium_locked_badge()
		list.add_child(_compendium_row(badge, name_str, content.enemy_lore(enemy, lang), discovered, Color(enemy.get("tint", "83e4c1"))))

func _build_compendium_achievements(list: VBoxContainer) -> void:
	if not profile.get("achievements_unlocked") is Dictionary: profile.achievements_unlocked = {}
	var unlocked_n := 0
	for ach in SpiritContent.ACHIEVEMENTS:
		if bool(profile.achievements_unlocked.get(str(ach.id), false)): unlocked_n += 1
	list.add_child(_label(tf("ui.compendium_progress", [unlocked_n, SpiritContent.ACHIEVEMENTS.size()]), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	for ach in SpiritContent.ACHIEVEMENTS:
		var id: String = str(ach.id)
		var unlocked: bool = bool(profile.achievements_unlocked.get(id, false))
		var progress: int = mini(int(ach.target), _achievement_progress(ach))
		var accent: Color = GOLD if unlocked else Color("2a3d42")

		var panel := Panel.new()
		panel.custom_minimum_size.y = 90
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel(Color("13282e") if unlocked else Color("0e191d"), 12, accent))
		list.add_child(panel)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 12)
		panel.add_child(pad)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", 4)
		pad.add_child(texts)

		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		texts.add_child(title_row)
		title_row.add_child(_label(content.ui(ach.nameKey, lang), 13, TEXT if unlocked else MUTED))
		if unlocked:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title_row.add_child(spacer)
			title_row.add_child(_label("✦", 13, GOLD))

		texts.add_child(_label(content.ui(ach.descKey, lang), 10, JADE if unlocked else MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		if not unlocked:
			var bar := _stat_bar(120.0, 14.0, progress, int(ach.target), GOLD, "%d / %d" % [progress, int(ach.target)], 9)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texts.add_child(bar)

func _equip(item: Dictionary) -> void:
	if profile.equipment_slots.get(item.slot,"") == item.id: profile.equipment_slots.erase(item.slot)
	else: profile.equipment_slots[item.slot] = item.id
	SpiritSave.write(profile); show_loadout()

func _socket(card_id: String) -> void:
	if selected_rune.is_empty(): _toast(t("ui.loadout_select_first")); return
	var available: int = int(profile.rune_inventory.get(selected_rune,0)) - profile.card_runes.values().count(selected_rune)
	if available <= 0: return
	profile.card_runes[card_id] = selected_rune; SpiritSave.write(profile); selected_rune=""; show_loadout()

func _format_countdown(target_unix: int) -> String:
	var remaining: int = maxi(0, target_unix - int(Time.get_unix_time_from_system()))
	var hours := remaining / 3600
	if hours >= 24:
		var days := hours / 24
		return "%dd" % days if lang == "en" else "%d天" % days
	var minutes := (remaining % 3600) / 60
	return "%dh%02dm" % [hours, minutes] if lang == "en" else "%d时%02d分" % [hours, minutes]

func _quest_section(title: String, list_name: String, reset_at: int) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	section.add_child(head)
	head.add_child(_label(title, 14, JADE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label(tf("ui.quests_daily_reset", _format_countdown(reset_at)), 9, MUTED))

	var quests: Array = profile.get(list_name, [])
	for entry in quests:
		var quest := content.quest_by_id(str(entry.get("id", "")))
		if quest.is_empty(): continue
		var progress := int(entry.get("progress", 0))
		var target := int(entry.get("target", 1))
		var claimed := bool(entry.get("claimed", false))
		var done := progress >= target

		var row := Panel.new()
		row.custom_minimum_size.y = 60
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, JADE if done and not claimed else Color("28393e")))
		section.add_child(row)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
		row.add_child(pad)

		var hrow := HBoxContainer.new()
		hrow.add_theme_constant_override("separation", 10)
		pad.add_child(hrow)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 3)
		hrow.add_child(texts)
		texts.add_child(_label(content.quest_name(quest, lang), 12, TEXT))
		# _stat_bar sizes itself fixed-width (like the health bars it was built for); give it
		# a sane floor and let size_flags stretch it across the row, or it renders at 0 width.
		var bar := _stat_bar(120.0, 16.0, progress, target, JADE if done else GOLD, "%d / %d" % [progress, target], 9)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(bar)

		var action := VBoxContainer.new()
		action.alignment = BoxContainer.ALIGNMENT_CENTER
		hrow.add_child(action)
		if claimed:
			action.add_child(_label(t("ui.quest_claimed"), 10, MUTED))
		else:
			var claim_btn := _button(t("ui.quest_claim") if done else tf("ui.quest_reward_fmt", int(quest.reward)), func(): _claim_quest(list_name, quest.id), EMBER if done else Color("1a2f36"), Vector2(64, 40))
			claim_btn.disabled = not done
			action.add_child(claim_btn)
	return section

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

func show_quests() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(8)
	page.add_child(_header(t("ui.quests_title"), t("ui.quests_sub"), show_map))
	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	_ensure_login_reward_current()
	list.add_child(_login_reward_section())
	_ensure_quests_current()
	list.add_child(_quest_section(t("ui.quests_daily"), "daily_quests", int(profile.get("daily_reset_at", 0))))
	list.add_child(_quest_section(t("ui.quests_weekly"), "weekly_quests", int(profile.get("weekly_reset_at", 0))))
	list.add_child(_label(t("ui.quests_hint"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

func _login_reward_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(_label(t("ui.login_reward_title"), 14, JADE))

	var record: Dictionary = profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	var claimed: Array = record.get("claimed", [])

	var bar := _stat_bar(120.0, 16.0, days_logged, 7, JADE, tf("ui.login_reward_progress_fmt", days_logged), 9)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(bar)

	var tiers_row := HBoxContainer.new()
	tiers_row.add_theme_constant_override("separation", 8)
	section.add_child(tiers_row)
	for i in SpiritContent.LOGIN_REWARD_TIERS.size():
		var tier: Dictionary = SpiritContent.LOGIN_REWARD_TIERS[i]
		var tier_days: int = int(tier.days)
		var is_claimed: bool = claimed.has(tier_days)
		var is_ready: bool = days_logged >= tier_days and not is_claimed

		var tile := Panel.new()
		tile.custom_minimum_size = Vector2(0, 74)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, JADE if is_ready else Color("28393e")))
		tiers_row.add_child(tile)

		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 4)
		tile.add_child(stack)
		stack.add_child(_label(tf("ui.login_reward_tier_fmt", tier_days), 10, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(_label(tf("ui.quest_reward_fmt", int(tier.reward)), 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

		if is_claimed:
			stack.add_child(_label(t("ui.quest_claimed"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			var claim_btn := _button(t("ui.quest_claim"), func(): _claim_login_reward(i), EMBER if is_ready else Color("1a2f36"), Vector2(0, 32))
			claim_btn.disabled = not is_ready
			claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stack.add_child(claim_btn)
	return section

func show_camp() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(6)
	page.add_child(_header(t("ui.camp_title"), t("ui.camp_sub"), show_map))
	page.add_child(_tab_bar([
		["character", t("ui.camp_tab_character")],
		["challenges", t("ui.camp_tab_challenges")],
		["collection", t("ui.camp_tab_collection")],
	], camp_tab, func(id): camp_tab = id; show_camp()))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	match camp_tab:
		"challenges": _build_camp_challenges(list)
		"collection": _build_camp_collection(list)
		_: _build_camp_character(list)

# "Who you are": account identity plus the hero archetype you're actually playing. Split out
# of what used to be one long show_camp() scroll (account, compendium, hero mastery, daily
# trial, abyss, difficulty, relics — 7 sections stacked vertically) once Milestone 4 pushed it
# past the point of being scannable in one screen.
func _build_camp_character(list: VBoxContainer) -> void:
	list.add_child(_account_panel())
	list.add_child(_hero_archetypes_section())

# "Modes you enter": the two challenge tracks (Daily Trial, Endless Abyss) plus the campaign's
# own difficulty ladder — all three answer "what am I about to go fight," not "who am I" or
# "what have I collected."
func _build_camp_challenges(list: VBoxContainer) -> void:
	list.add_child(_daily_trial_section())
	list.add_child(_abyss_section())
	list.add_child(_difficulty_tier_section())

# "What you've earned": the Compendium entry point plus the actual relics owned right now —
# the Compendium already covers cards/gear/runes/bestiary/achievements, so relics-in-hand
# stays here as the one collection view that's about current loadout, not lifetime discovery.
func _build_camp_collection(list: VBoxContainer) -> void:
	list.add_child(_compendium_section())
	list.add_child(_relics_section())

func _difficulty_tier_section() -> Control:
	var unlocked := int(profile.unlocked) >= 25
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(_label(tf("ui.camp_tier", profile.difficulty), 17, JADE if unlocked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		section.add_child(_label("🔒 " + t("ui.lock_clears_ch5"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		return section
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	for value in 6:
		var button := _button("A%d"%value, func(): profile.difficulty=value; SpiritSave.write(profile); show_camp(), Color("245247") if value==profile.difficulty else Color("17363e"), Vector2(0,40))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(button)
	section.add_child(row)
	section.add_child(_label(t("ui.camp_desc"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	return section

func _relics_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(_label(tf("ui.camp_relics", profile.relics.size()), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if profile.relics.is_empty():
		section.add_child(_label(t("ui.relic_none"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return section
	for id in profile.relics:
		var relic := content.relic(id)
		if relic.is_empty(): continue
		var color := Color(relic.color)
		var row_panel := Panel.new()
		row_panel.custom_minimum_size.y = 56
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, color))
		section.add_child(row_panel)
		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
		row_panel.add_child(pad)
		var relic_row := HBoxContainer.new()
		relic_row.add_theme_constant_override("separation", 10)
		pad.add_child(relic_row)
		var holder := CenterContainer.new()
		holder.add_child(_sigil_icon_badge(str(relic.get("icon_mark", "sparkle")), color, 38))
		relic_row.add_child(holder)
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 1)
		relic_row.add_child(texts)
		texts.add_child(_label(_relic_name(relic), 12, TEXT))
		texts.add_child(_label(_relic_detail(relic), 9, color, HORIZONTAL_ALIGNMENT_LEFT, true))
	return section

func _compendium_section() -> Control:
	var unlocked := int(profile.unlocked) >= 5
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 64)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col := Color("8ff5cf") if unlocked else Color("2a3d42")
	panel.add_theme_stylebox_override("panel", _panel(Color("142418") if unlocked else Color("101a1c"), 14, border_col))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	texts.add_child(_label(t("ui.compendium_title"), 15, Color("8ff5cf") if unlocked else MUTED))
	if unlocked:
		var totals := _compendium_totals()
		texts.add_child(_label(tf("ui.compendium_progress", [totals.x, totals.y]), 10, MUTED))
	else:
		texts.add_child(_label("🔒 " + t("ui.lock_clears_ch1"), 10, Color("ff9868")))

	var open_btn := _button(t("ui.compendium_open_btn") if unlocked else ("🔒 " + t("ui.locked")), show_compendium, Color("1e4a35") if unlocked else Color("162428"), Vector2(0, 40))
	open_btn.name = "CompendiumOpenBtn"
	open_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open_btn.disabled = not unlocked
	row.add_child(open_btn)

	return panel

func _daily_trial_section() -> Control:
	_ensure_daily_trial_current()
	var unlocked := int(profile.unlocked) >= 5
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 130)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("241a10") if unlocked else Color("181412"), 14, Color("ffb765") if unlocked else Color("2a3d42")))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	pad.add_child(stack)

	stack.add_child(_label(t("ui.daily_trial_title"), 16, Color("ffb765") if unlocked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		stack.add_child(_label("🔒 " + t("ui.lock_clears_ch1"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var enter_btn := _button("🔒 " + t("ui.locked"), begin_daily_trial, Color("2d2218"), Vector2(240, 40))
		enter_btn.name = "DailyTrialEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)
		return panel

	stack.add_child(_label(t("ui.daily_trial_sub"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var tags: Array = content.daily_trial_tags(int(profile.daily_trial_record.day))
	var tag_names: Array = []
	for tag in tags: tag_names.append(content.ui(tag.nameKey, lang))
	var sep: String = ", " if lang == "en" else "、"
	stack.add_child(_label("%s: %s" % [t("ui.daily_trial_modifiers_title"), sep.join(tag_names)], 9, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_CENTER, true))

	var stage_num: int = int(profile.daily_trial_record.stage)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 10)
	stats.add_child(_label(tf("ui.daily_trial_progress_fmt", stage_num), 11, GOLD))
	stats.add_child(_label(tf("ui.daily_trial_best_fmt", int(profile.daily_trial_record.get("best_stage", 0))), 11, JADE))
	stats.add_child(_label(tf("ui.daily_trial_badges_fmt", int(profile.daily_trial_record.get("badges", 0))), 11, Color("ffd8a8")))
	stats.add_child(_label(tf("ui.daily_trial_streak_fmt", int(profile.daily_trial_record.get("streak", 0))), 11, Color("ff9868")))
	stack.add_child(stats)

	if stage_num >= SpiritContent.DAILY_TRIAL_STAGES:
		stack.add_child(_label(t("ui.daily_trial_done"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		var enter_btn := _button(t("ui.daily_trial_enter"), begin_daily_trial, Color("6b4420"), Vector2(240, 40))
		enter_btn.name = "DailyTrialEnterBtn"
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)

	return panel

func _hero_archetypes_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label(t("ui.hero_classes_title"), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var current_class_id: String = str(profile.get("hero_class", "fox_spirit"))
	for h in content.HERO_CLASSES:
		var is_selected: bool = h.id == current_class_id
		var art_pending: bool = bool(h.get("art_pending", false))
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(340, 116 if art_pending else 104)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border_col: Color = GOLD if is_selected else Color("1a3d44")
		panel.add_theme_stylebox_override("panel", _panel(Color("10242b") if not is_selected else Color("153038"), 12, border_col))

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 8)
		panel.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		pad.add_child(row)

		var portrait := CenterContainer.new()
		portrait.custom_minimum_size = Vector2(48, 48)
		var spr := TextureRect.new()
		spr.texture = _get_character_texture(str(h.sprite))
		spr.custom_minimum_size = Vector2(44, 44)
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# A borrowed portrait (see art_pending below) is deliberately desaturated/dimmed so it
		# never reads as "this new hero secretly looks like Stone Sentinel" — it reads as
		# "placeholder," which is what it is.
		if art_pending: spr.modulate = Color(0.6, 0.6, 0.6, 0.55)
		portrait.add_child(spr)
		row.add_child(portrait)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", 2)
		row.add_child(texts)

		var name_str: String = content.hero_name(h, lang)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		name_row.add_child(_label(name_str + ("  ✓" if is_selected else ""), 13, JADE if is_selected else TEXT))
		if h.id == "fox_spirit":
			var rec_badge := PanelContainer.new()
			rec_badge.name = "BeginnerRecBadge"
			rec_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rec_badge.add_theme_stylebox_override("panel", _panel(Color("2d2208"), 6, Color("ffd700")))
			var rec_pad := MarginContainer.new()
			rec_pad.add_theme_constant_override("margin_left", 6)
			rec_pad.add_theme_constant_override("margin_right", 6)
			rec_pad.add_theme_constant_override("margin_top", 1)
			rec_pad.add_theme_constant_override("margin_bottom", 1)
			rec_pad.add_child(_label(t("ui.hero_rec_badge"), 8, Color("ffd700"), HORIZONTAL_ALIGNMENT_CENTER))
			rec_badge.add_child(rec_pad)
			name_row.add_child(rec_badge)
		texts.add_child(name_row)
		if h.id == "fox_spirit":
			texts.add_child(_label(t("ui.hero_rec_desc"), 8, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_LEFT, true))
		texts.add_child(_label(content.hero_desc(h, lang), 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		# This hero's mechanics and deck are fully implemented; only a unique painted portrait
		# is missing (the character atlas is a fixed 3x3 grid and all 9 cells are already
		# spoken for by the other 3 heroes and their shared enemy pool — see
		# Docs/GROWTH_ROADMAP.md's D3 note for what a real fix needs). Surfacing that honestly
		# in the UI beats silently reusing another hero's face and hoping nobody notices.
		if art_pending:
			texts.add_child(_label(t("ui.hero_art_pending"), 8, Color("ff9868")))

		var hero_xp: int = int(profile.get("hero_masteries", {}).get(h.id, {}).get("xp", 0))
		var hero_level: int = content.mastery_level_for_xp(hero_xp)
		var mastery_line: String = tf("ui.mastery_level_fmt", hero_level)
		mastery_line += "  " + (t("ui.mastery_maxed") if hero_level >= 5 else tf("ui.mastery_progress_fmt", [hero_xp, content.mastery_xp_for_level(hero_level + 1)]))
		texts.add_child(_label(mastery_line, 9, GOLD))
		var perk: Dictionary = content.mastery_perk(h.id, hero_level)
		if not perk.is_empty():
			texts.add_child(_label("%s · %s" % [content.ui(perk.nameKey, lang), content.ui(perk.descKey, lang)], 8, Color("9fd8c9"), HORIZONTAL_ALIGNMENT_LEFT, true))

		var sel_btn := _button("✓" if is_selected else t("ui.hero_class_select"), func():
			profile.hero_class = h.id
			profile.deck = h.deck.duplicate()
			for cid in h.deck:
				profile.collection[cid] = maxi(int(profile.collection.get(cid, 0)), h.deck.count(cid))
			var relic_id: String = str(h.get("relic", ""))
			if not relic_id.is_empty() and not profile.relics.has(relic_id):
				profile.relics.append(relic_id)
			SpiritSave.write(profile)
			_haptic("heavy")
			_toast(tf("ui.hero_selected_toast", name_str), GOLD)
			show_camp()
		, GOLD if is_selected else Color("1a3d44"), Vector2(68, 38))
		sel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sel_btn)

		box.add_child(panel)

	return box

func _abyss_section() -> Control:
	var unlocked := int(profile.unlocked) >= 10
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 110)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col := Color("c79bff") if unlocked else Color("2a3d42")
	panel.add_theme_stylebox_override("panel", _panel(Color("1b1024") if unlocked else Color("141018"), 14, border_col))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	pad.add_child(stack)

	stack.add_child(_label(t("ui.abyss_title"), 16, Color("e0b8ff") if unlocked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		stack.add_child(_label("🔒 " + t("ui.lock_clears_ch2"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var enter_btn := _button("🔒 " + t("ui.locked"), begin_abyss_battle, Color("2d1b33"), Vector2(240, 40))
		enter_btn.name = "AbyssEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)
		return panel

	stack.add_child(_label(t("ui.abyss_sub"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var floor_num: int = int(profile.get("abyss_floor", 1))
	var record_num: int = int(profile.get("abyss_record", 0))

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 16)
	stats.add_child(_label(tf("ui.abyss_floor_fmt", floor_num), 11, GOLD))
	stats.add_child(_label(tf("ui.abyss_record_fmt", record_num), 11, JADE))
	stack.add_child(stats)

	var enter_btn := _button(t("ui.abyss_enter"), begin_abyss_battle, Color("4a285d"), Vector2(240, 40))
	enter_btn.name = "AbyssEnterBtn"
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(enter_btn)

	return panel

func begin_abyss_battle() -> void:
	in_abyss = true
	var floor_num: int = int(profile.get("abyss_floor", 1))
	var enc: Dictionary = content.abyss_encounter(floor_num)
	current_stage = 0
	var seed := int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	active_modifier = _modifier(seed, floor_num)
	active_modifier["boons"] = profile.get("abyss_boons", []).duplicate()
	combat = SpiritCombat.new(content)
	var equipped: Array = profile.equipment_slots.values()
	combat.create(seed, enc, profile.deck, int(profile.health), profile.upgrades, equipped, profile.card_runes, active_modifier, profile.relics, _current_hero_mastery_bonuses())
	combat.event.connect(_combat_event)
	_mark_discovered("bestiary", str(enc.name))
	pre_battle_health = int(profile.health)
	advancing_to_reward = false
	selected_card = -1
	show_battle()
	_maybe_end_turn()

func begin_daily_trial() -> void:
	_ensure_daily_trial_current()
	if int(profile.daily_trial_record.stage) >= SpiritContent.DAILY_TRIAL_STAGES: return
	in_daily_trial = true
	var day: int = int(profile.daily_trial_record.day)
	var stage_num: int = int(profile.daily_trial_record.stage) + 1
	var enc: Dictionary = content.daily_trial_encounter(stage_num)
	current_stage = 0
	# Seeded by the day index (not wall-clock time like campaign/abyss battles), so every
	# device attempting today's trial fights the exact same encounter — the "deterministic
	# seed" the daily challenge is named for.
	active_modifier = content.daily_trial_modifier(day)
	combat = SpiritCombat.new(content)
	var equipped: Array = profile.equipment_slots.values()
	combat.create(day * 1000 + stage_num, enc, profile.deck, int(profile.health), profile.upgrades, equipped, profile.card_runes, active_modifier, profile.relics, _current_hero_mastery_bonuses())
	combat.event.connect(_combat_event)
	_mark_discovered("bestiary", str(enc.name))
	pre_battle_health = int(profile.health)
	advancing_to_reward = false
	selected_card = -1
	show_battle()
	_maybe_end_turn()

func show_abyss_boon_draft() -> void:
	_clear()
	var page := _create_page(12)
	page.add_child(_header(t("ui.boon_draft_title"), t("ui.boon_draft_sub"), show_reward_details))

	var current_boons: Array = profile.get("abyss_boons", [])
	var pool: Array = []
	for boon in content.ABYSS_BOONS:
		if not current_boons.has(boon.id):
			pool.append(boon)
	if pool.is_empty(): pool = content.ABYSS_BOONS.duplicate()
	pool.shuffle()
	var offered: Array = pool.slice(0, mini(3, pool.size()))

	var card_list := VBoxContainer.new()
	card_list.name = "BoonDraftList"
	card_list.add_theme_constant_override("separation", 14)
	card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_list.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(card_list)

	for boon in offered:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(350, 96)
		var p_style := _panel(Color("101d24"), 12, Color(boon.color))
		p_style.content_margin_left = 16; p_style.content_margin_right = 16
		p_style.content_margin_top = 12; p_style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", p_style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)

		var icon_lbl := _label(boon.icon, 28, Color(boon.color), HORIZONTAL_ALIGNMENT_CENTER)
		icon_lbl.custom_minimum_size = Vector2(40, 40)
		row.add_child(icon_lbl)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_str: String = content.ui(boon.nameKey, lang)
		info.add_child(_label(name_str, 15, TEXT))
		info.add_child(_label(content.ui(boon.descKey, lang), 10, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

		var choose_btn := _button(t("ui.claim"), func(): _select_abyss_boon(boon), Color("244a56"), Vector2(68, 40))
		choose_btn.name = "ChooseBoon_" + boon.id
		row.add_child(choose_btn)

		card_list.add_child(panel)

func _select_abyss_boon(boon: Dictionary) -> void:
	if not profile.has("abyss_boons") or not profile.abyss_boons is Array: profile.abyss_boons = []
	profile.abyss_boons.append(boon.id)
	SpiritSave.write(profile)
	_toast(tf("ui.boon_acquired_toast", content.ui(boon.nameKey, lang)))
	show_reward_details()

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
	return {"Attack":Color("d95d37"),"Skill":Color("50b99b"),"Power":Color("a75bd6"),"Tactic":Color("4d9dd6"),"Curse":Color("6b3fa0")}.get(card.get("kind","Skill"),JADE)

# Small icon glyphs hinting at deck-building synergy (growth roadmap D1) — Flame/Gale
# Resonance, hero mastery perks, and enemy-count considerations all key off a card doing one
# of these things, and remembering which of 39 cards qualifies is exactly the "recognize
# synergy while building a deck" gap the growth report called out. Derived fresh from the
# card's own effects/special every call rather than stored as separate data, so it can never
# drift out of sync with what the card actually does — only status/special tags that map to a
# real existing system are included; plain damage/shield/heal aren't "synergy," they're just
# what most cards do.
func _card_synergy_tags(card: Dictionary) -> String:
	var tags: Array = []
	for effect in card.get("effects", []):
		var op: String = str(effect.get("operation", ""))
		if op == "status":
			var glyph: String = {"burn":"🔥","poison":"☣","vulnerable":"💢","weak":"🌀","strength":"💪"}.get(str(effect.get("status", "")), "")
			if not glyph.is_empty() and not tags.has(glyph): tags.append(glyph)
		elif op == "draw" and not tags.has("🃏"):
			tags.append("🃏")
	var special: String = str(card.get("special", ""))
	var special_glyph: String = {"cleave":"⚔","critical":"✹"}.get(special, "")
	if not special_glyph.is_empty() and not tags.has(special_glyph): tags.append(special_glyph)
	return " ".join(tags)

# Appends the synergy-tag glyphs to an existing "Kind · Element" line, with no trailing
# separator when a card has none — used by every card-face render site that shows that line.
func _kind_element_line(card: Dictionary) -> String:
	var base := "%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), t("element.%s" % card.get("element", "spirit"))]
	var tags := _card_synergy_tags(card)
	return base if tags.is_empty() else "%s  %s" % [base, tags]

func _rune_color(id: String, fallback: Color) -> Color:
	var rune := content.rune(id); return fallback if rune.is_empty() else Color(rune.color)

func _card_description(card: Dictionary) -> String:
	# Curse cards (decay_blight, void_curse) carry no effects array at all — their rules text
	# is a hazard description (damage on draw, damage if left in hand, unplayable, ...) that
	# doesn't map to any generic "operation", so it gets its own desc.<card_id> string instead.
	if card.get("kind", "") == "Curse": return content.ui("desc.%s" % card.id, lang)
	var parts := []
	for effect in card.effects:
		match effect.operation:
			"damage": parts.append(content.ui("desc.damage", lang) % effect.amount)
			"shield": parts.append(content.ui("desc.shield", lang) % effect.amount)
			"heal": parts.append(content.ui("desc.heal", lang) % effect.amount)
			"draw": parts.append(content.ui("desc.draw", lang) % effect.amount)
			"energy": parts.append(content.ui("desc.energy", lang) % effect.amount)
			"status":
				# Any status name works here — the effect just needs a matching desc.<status> key.
				var key := "desc.%s" % str(effect.get("status", ""))
				parts.append(content.ui(key, lang) % int(effect.amount))
	var special := str(card.get("special", ""))
	if not special.is_empty(): parts.append(content.ui("desc.special.%s" % special, lang))
	var sep := " · " if lang == "en" else "，"
	return sep.join(parts)

func show_settings() -> void:
	var existing: Node = overlay.get_node_or_null("SettingsModal")
	if existing: existing.queue_free(); return

	var modal := _modal_backdrop("SettingsModal", func(): _close_settings())

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340, 420)
	panel.size = panel.custom_minimum_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _panel(Color("0e1d22"), 14, GOLD))
	modal.add_child(panel)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(pad)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	pad.add_child(list)

	# Header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	list.add_child(head)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(_label(t("ui.settings_title"), 16, GOLD))
	title_box.add_child(_label(t("ui.settings_sub"), 9, MUTED))
	head.add_child(title_box)

	var close_btn := _button("✕", func(): _close_settings(), Color("1c333a"), Vector2(36, 36))
	close_btn.name = "SettingsCloseBtn"
	head.add_child(close_btn)

	# 1. Language Option
	var lang_box := VBoxContainer.new()
	lang_box.add_theme_constant_override("separation", 6)
	lang_box.add_child(_label(t("ui.settings_lang"), 12, TEXT))
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	var is_zh: bool = lang == "zh-Hans"
	var zh_btn := _button("简体中文", func(): _change_language("zh-Hans"), JADE if is_zh else Color("1c333a"), Vector2(0, 36))
	zh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var en_btn := _button("English", func(): _change_language("en"), JADE if not is_zh else Color("1c333a"), Vector2(0, 36))
	en_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(zh_btn)
	lang_row.add_child(en_btn)
	lang_box.add_child(lang_row)
	list.add_child(lang_box)

	# 2. Battle Speed Option
	var speed_box := VBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 6)
	speed_box.add_child(_label(t("ui.settings_speed"), 12, TEXT))
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	for sp in [1.0, 1.5, 2.0]:
		var is_active := is_equal_approx(battle_speed, sp)
		var sp_btn := _button("%.1fx" % sp, func(): _change_battle_speed(sp), Color("d95d37") if is_active else Color("1c333a"), Vector2(0, 36))
		sp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speed_row.add_child(sp_btn)
	speed_box.add_child(speed_row)
	list.add_child(speed_box)

	# 3. Audio / Music Option
	var audio_box := VBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 6)
	audio_box.add_child(_label(t("ui.settings_audio"), 12, TEXT))
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 8)
	var music_btn := _button(t("ui.settings_audio_on") if not muted else t("ui.settings_audio_off"), func(): _toggle_music_settings(), JADE if not muted else Color("2c333a"), Vector2(0, 36))
	music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_child(music_btn)
	audio_box.add_child(audio_row)
	list.add_child(audio_box)

	# 4. Reduce Motion Option
	var motion_box := VBoxContainer.new()
	motion_box.add_theme_constant_override("separation", 4)
	motion_box.add_child(_label(t("ui.settings_reduce_motion"), 12, TEXT))
	motion_box.add_child(_label(t("ui.settings_reduce_motion_desc"), 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var motion_active: bool = bool(profile.get("reduce_motion", false))
	var motion_btn := _button(t("ui.settings_on") if motion_active else t("ui.settings_off"), func(): _toggle_reduce_motion(), EMBER if motion_active else Color("1c333a"), Vector2(0, 36))
	motion_btn.name = "ReduceMotionToggleBtn"
	motion_box.add_child(motion_btn)
	list.add_child(motion_box)

func _close_settings() -> void:
	var existing: Node = overlay.get_node_or_null("SettingsModal")
	if existing: existing.queue_free()

func _change_language(new_lang: String) -> void:
	lang = new_lang
	profile.language = lang
	SpiritSave.write(profile)
	_close_settings()
	show_settings()

func _change_battle_speed(new_speed: float) -> void:
	battle_speed = new_speed
	profile.battle_speed = battle_speed
	SpiritSave.write(profile)
	_close_settings()
	show_settings()

func _toggle_music_settings() -> void:
	muted = not muted
	if muted: map_music.stop(); battle_music.stop()
	else: _play_music(false)
	_close_settings()
	show_settings()

func _toggle_reduce_motion() -> void:
	var current: bool = bool(profile.get("reduce_motion", false))
	profile.reduce_motion = not current
	SpiritSave.write(profile)
	_close_settings()
	show_settings()

func _on_pin_pressed(index: int) -> void:
	if _is_replay(index) and content.node_kind(index) in ["battle", "elite", "boss", "greatboss"]:
		_show_replay_mode_prompt(index)
	else:
		is_hard_replay = false
		_travel_to(index)

func _show_replay_mode_prompt(index: int) -> void:
	var existing: Node = overlay.get_node_or_null("ReplayModal")
	if existing: existing.queue_free()

	var modal := _modal_backdrop("ReplayModal", func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex: ex.queue_free()
	)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340, 240)
	panel.size = panel.custom_minimum_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _panel(Color("0f1e23"), 14, Color("34626d")))
	modal.add_child(panel)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 14)
	panel.add_child(pad)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	pad.add_child(list)

	list.add_child(_label(t("ui.replay_modal_title"), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var normal_btn := _button(t("ui.replay_normal_title"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex: ex.queue_free()
		is_hard_replay = false
		_travel_to(index)
	, Color("17363e"), Vector2(0, 44))
	normal_btn.name = "ReplayNormalBtn"
	list.add_child(normal_btn)
	list.add_child(_label(t("ui.replay_normal_desc"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var hard_btn := _button(t("ui.replay_hard_title"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex: ex.queue_free()
		is_hard_replay = true
		_travel_to(index)
	, EMBER, Vector2(0, 44))
	hard_btn.name = "ReplayHardBtn"
	list.add_child(hard_btn)
	list.add_child(_label(t("ui.replay_hard_desc"), 9, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_CENTER, true))

func begin_hard_replay(index: int) -> void:
	is_hard_replay = true
	begin_battle(index)

func _build_victory_recap_card(stats: Dictionary) -> Control:
	var panel := Panel.new()
	panel.name = "VictoryRecapCard"
	panel.custom_minimum_size = Vector2(0, 54)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("122228"), 10, Color("34626d")))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 12)
	for side in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 6)
	panel.add_child(pad)

	var vstack := VBoxContainer.new()
	vstack.add_theme_constant_override("separation", 3)
	pad.add_child(vstack)

	vstack.add_child(_label(t("ui.recap_title"), 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_label(tf("ui.recap_damage", int(stats.get("damage_dealt", 0))), 10, Color("ff8a8a")))
	row.add_child(_label(tf("ui.recap_cards", int(stats.get("cards_played", 0))), 10, Color("a8dcff")))
	row.add_child(_label(tf("ui.recap_shield", int(stats.get("shield_gained", 0))), 10, Color("9fd8ff")))
	vstack.add_child(row)
	return panel
