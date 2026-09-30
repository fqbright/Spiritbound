extends Control

var is_lethal := false
var rot := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	rot += delta * 2.2
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	var col := Color("ff3b30") if is_lethal else Color("ffd700")
	var ring_col := Color(col.r, col.g, col.b, 0.4)

	# Outer rotating brackets (4 corner tick arcs)
	var segs := 4
	for i in range(segs):
		var angle := rot + float(i) * (PI * 0.5)
		var p1 := center + Vector2(cos(angle), sin(angle)) * r
		var p2 := center + Vector2(cos(angle + 0.35), sin(angle + 0.35)) * r
		draw_line(p1, p2, col, 2.5)

	# Inner dashed circle
	draw_arc(center, r * 0.72, 0.0, TAU, 32, ring_col, 1.5)

	# Crosshair tick marks
	var tick_len := 6.0
	for i in range(4):
		var a := float(i) * (PI * 0.5)
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (r * 0.55), center + dir * (r * 0.55 + tick_len), col, 2.0)
