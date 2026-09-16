extends ScrollContainer
class_name TouchScrollContainer

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


