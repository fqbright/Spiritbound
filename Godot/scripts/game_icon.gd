extends Control
class_name GameIcon

# Every equipment/rune/relic/stage badge used to be one Unicode glyph in a coloured circle —
# readable, but flat, and no two items looked like they belonged to the same visual system.
# This draws an actual small icon instead: a base silhouette (sword/shield/pendant/staff/
# spear/bow for gear, a hexagon sigil frame for runes and relics) plus an optional flourish
# that carries the item's specific flavour, all vector shapes so no bitmap art is needed.
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


