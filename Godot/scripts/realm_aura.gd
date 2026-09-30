extends Control

var realm_tier: int = 0
var rot: float = 0.0

const REALM_COLORS := [
	Color("5eead4"), # 炼气
	Color("60a5fa"), # 筑基
	Color("fbbf24"), # 金丹
	Color("c084fc"), # 元婴
	Color("f43f5e"), # 化神
	Color("ffd700"), # 渡劫
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 48)
	size = custom_minimum_size
	pivot_offset = size * 0.5

func _process(delta: float) -> void:
	rot += delta * (0.8 + float(realm_tier) * 0.2)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var tier := clampi(realm_tier, 0, 5)
	var col: Color = REALM_COLORS[tier]
	var rx := size.x * 0.44
	var ry := size.y * 0.38

	# Elliptical ground perspective aura
	var base_ring_col := Color(col.r, col.g, col.b, 0.35)
	draw_arc(center, rx, 0.0, TAU, 32, base_ring_col, 2.0)

	# Tier-specific orbital formations
	var points := 4 + tier * 2
	for i in range(points):
		var a := rot + float(i) * (TAU / float(points))
		var pt := center + Vector2(cos(a) * rx, sin(a) * ry)
		var orb_r := 2.5 + float(tier) * 0.5
		draw_circle(pt, orb_r, Color(col.r, col.g, col.b, 0.85))

	if tier >= 3:
		# Inner rotating sacred ring for Nascent Soul and above
		var inner_col := Color(col.r, col.g, col.b, 0.5)
		draw_arc(center, rx * 0.65, 0.0, TAU, 24, inner_col, 1.5)

	if tier == 5:
		# Tribulation Taiji Core
		var taiji_col := Color(1.0, 0.95, 0.6, 0.75)
		draw_circle(center, 4.0, taiji_col)
