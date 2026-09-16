extends Control
class_name DizzyStars

# Three small sparks orbiting the head — the classic "seeing stars" stun read, drawn rather
# than requiring an animated sprite sheet.
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

