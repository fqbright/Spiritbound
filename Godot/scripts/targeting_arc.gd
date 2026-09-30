extends Control

var start_pos := Vector2.ZERO
var target_pos := Vector2.ZERO
var is_locked := false
var pulse_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 350

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func set_points(p_start: Vector2, p_target: Vector2, locked: bool) -> void:
	start_pos = p_start
	target_pos = p_target
	is_locked = locked
	queue_redraw()

func _draw() -> void:
	if start_pos == Vector2.ZERO and target_pos == Vector2.ZERO: return
	var p0 := start_pos
	var p3 := target_pos
	var mid_y := minf(p0.y, p3.y) - 70.0
	var p1 := Vector2(p0.x, p0.y - 100.0)
	var p2 := Vector2(p3.x, mid_y)
	var num_pts := 22
	var pts: Array[Vector2] = []
	for i in range(num_pts + 1):
		var t := float(i) / float(num_pts)
		pts.append(p0.bezier_interpolate(p1, p2, p3, t))

	var base_col: Color = Color(1.0, 0.85, 0.25, 0.95) if is_locked else Color(0.35, 0.88, 0.98, 0.85)
	var glow_col: Color = Color(1.0, 0.45, 0.1, 0.5) if is_locked else Color(0.1, 0.4, 0.8, 0.35)

	for i in range(pts.size() - 1):
		var t := float(i) / float(pts.size() - 1)
		var w := lerpf(4.5, 2.0, t)
		draw_line(pts[i], pts[i+1], glow_col, w + 4.0)
		draw_line(pts[i], pts[i+1], base_col, w)

	var pulse: float = sin(pulse_time * 8.0) * 0.2 + 0.85
	for i in range(2, pts.size() - 1, 2):
		var t := float(i) / float(pts.size() - 1)
		var r := lerpf(6.5, 3.5, t) * pulse
		draw_circle(pts[i], r + 2.0, glow_col)
		draw_circle(pts[i], r, Color.WHITE.lerp(base_col, 0.4))

	if pts.size() >= 2:
		var tip: Vector2 = pts[-1]
		var dir: Vector2 = (tip - pts[-2]).normalized()
		if dir == Vector2.ZERO: dir = Vector2.UP
		var norm := Vector2(-dir.y, dir.x)
		var sz := 16.0 if is_locked else 12.0
		var p_left := tip - dir * sz + norm * (sz * 0.6)
		var p_right := tip - dir * sz - norm * (sz * 0.6)
		var arrow := PackedVector2Array([tip, p_left, tip - dir * (sz * 0.4), p_right])
		draw_colored_polygon(arrow, base_col)
		draw_polyline(arrow, Color.WHITE if is_locked else glow_col, 2.0)
