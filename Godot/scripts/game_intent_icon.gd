extends Control
class_name IntentIcon

# Drawn rather than glyph text: no bitmap art exists for these, and a real icon reads
# faster than a character from a font at combat-banner size.
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


