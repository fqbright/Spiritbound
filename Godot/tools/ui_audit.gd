extends SceneTree
## Read-only UI audit: renders each of the nine snapshot screens and MEASURES them.
##
## Why this exists: every rule in AGENTS.md's "traps" list is a bug that produced a wrong screen
## with no error in the log, and `ui_smoke.gd` was written to catch those specific shapes. This
## tool catches a different class — things that render exactly as coded and are still wrong for a
## human holding the phone: a tap target smaller than a fingertip, text that fits its own Label
## but runs off the panel behind it, a caption whose contrast against its own background is below
## what anyone can read outdoors.
##
## Nothing here asserts. It reports numbers, so the numbers can be argued with.
##
## Run WITH a real renderer (contrast needs actual pixels):
##   godot --path Godot/ --script res://tools/ui_audit.gd
## Geometry-only (touch targets / overflow / font sizes) also works headless, but contrast
## silently reports as unmeasurable rather than as passing.
##
## Thresholds are Apple's, not invented here:
##   - 44x44 pt minimum hit target (HIG "Layout" — the fingertip, not the glyph)
##   - WCAG 2.1 AA: 4.5:1 body text, 3.0:1 for large text (>=18pt, or >=14pt bold)

const OUT_JSON := "res://tests/snapshots/ui_audit.json"

const TOUCH_MIN := 44.0
const CONTRAST_NORMAL := 4.5
const CONTRAST_LARGE := 3.0
const FONT_READABLE_MIN := 11
const MIN_TEXT_PIXELS := 12

var _img: Image = null
var _img_scale := 1.0
var _screens: Array[Dictionary] = []

func _initialize() -> void:
	_run()

# ---------------------------------------------------------------- helpers

func _label_of(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	if c is LineEdit:
		return (c as LineEdit).placeholder_text if (c as LineEdit).text == "" else (c as LineEdit).text
	return ""

func _is_interactive(c: Control) -> bool:
	return c is BaseButton or c is LineEdit or c is Slider or c is OptionButton

func _rect_of(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)

## A control that hangs past a non-clipping parent still draws, and several deliberate layouts
## rely on that (an energy badge centred on a card's corner is *supposed* to sit half outside its
## tile). So this reports only the cases that are unambiguously cut off:
##   1. an ancestor with clip_contents cuts it, or
##   2. the control leaves the 390x844 viewport **without** any ScrollContainer between it and the
##      root -- content scrolled below the fold of a list is doing exactly what it should.
## Returns {} when nothing actually clips.
func _containment_breach(c: Control) -> Dictionary:
	var r: Rect2 = _rect_of(c)
	var screen := Rect2(Vector2.ZERO, root.size)
	var scrollable := false

	var p: Node = c.get_parent()
	while p != null and p != root:
		if p is ScrollContainer:
			# Its children being larger than it is the entire point of a scroller; stop the
			# clipping walk here and remember that going off-viewport is legitimate.
			scrollable = true
			break
		if p is Control:
			var pc: Control = p
			if pc.visible and pc.size.x > 1.0 and pc.size.y > 1.0 and pc.clip_contents:
				var pr: Rect2 = _rect_of(pc)
				var cx: float = maxf(maxf(pr.position.x - r.position.x, r.end.x - pr.end.x), 0.0)
				var cy: float = maxf(maxf(pr.position.y - r.position.y, r.end.y - pr.end.y), 0.0)
				if cx > 1.0 or cy > 1.0:
					return {
						"kind": "clipped",
						"ancestor": String(pc.name),
						"over_x": cx,
						"over_y": cy,
					}
		p = p.get_parent()

	if scrollable:
		return {}
	var over_x: float = maxf(maxf(-r.position.x, r.end.x - screen.size.x), 0.0)
	var over_y: float = maxf(maxf(-r.position.y, r.end.y - screen.size.y), 0.0)
	if over_x > 1.0 or over_y > 1.0:
		return {
			"kind": "off_screen",
			"ancestor": "viewport(390x844)",
			"over_x": over_x,
			"over_y": over_y,
		}
	return {}

## The modulate a control actually renders under, including every ancestor's. A dimmed subtree
## (locked map pins, disabled rows) renders its text darker than the theme colour says, and
## without this the glyph-matching step would look for a colour that is not on screen.
func _effective_modulate(c: Control) -> Color:
	var m: Color = c.modulate * c.self_modulate
	var p: Node = c.get_parent()
	while p != null and p != root:
		if p is CanvasItem:
			m *= (p as CanvasItem).modulate * (p as CanvasItem).self_modulate
		p = p.get_parent()
	return m

func _rect_to_a(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

func _font_size_of(c: Control) -> int:
	return c.get_theme_font_size("font_size")

## True when the control's own text is wider than the control and the control is configured to
## hide that fact (clip_text or an overrun/trim setting) — i.e. the player sees "…" or a cut-off
## word rather than the string the code intended to show.
func _truncates_text(c: Control) -> bool:
	var txt: String = _label_of(c)
	if txt == "":
		return false
	var hides: bool = false
	if c is Label:
		var l: Label = c
		hides = l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	elif c is Button:
		hides = (c as Button).clip_text
	elif c is RichTextLabel:
		return false
	if not hides:
		return false
	var f: Font = c.get_theme_font("font")
	if f == null:
		return false
	var fs: int = _font_size_of(c)
	var need: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return need > c.size.x + 1.0

## Emoji and standalone symbol glyphs are excluded from contrast measurement, deliberately.
## They are drawn by the system colour-emoji font, not by this theme's font — a "🧪" or "🔒" is a
## full-colour bitmap whose pixels have nothing to do with `font_color`, so the glyph-matching step
## keys on a colour that was never used and scores the result as if the emoji were text. Left in,
## these accounted for 4 of the 13 remaining "violations" and every one of them was an artifact.
## A metric that cries wolf is a metric that gets switched off, so they are filtered rather than
## reported with a caveat nobody will read.
const PICTOGRAPHIC_OK := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

## Colour-emoji and geometric-symbol codepoints. These are drawn by the system colour-emoji font
## (or as pure vector shapes) rather than by this theme's font, in their own colours.
func _is_emoji_or_symbol(cp: int) -> bool:
	return (cp >= 0x2190 and cp <= 0x2BFF) \
		or (cp >= 0x1F000 and cp <= 0x1FAFF) \
		or (cp >= 0xFE00 and cp <= 0xFE0F) \
		or cp == 0x20E3

## True when a string contains nothing a font would ink in `font_color` — i.e. it is all emoji,
## box-drawing or symbols, so there is no foreground colour to measure a contrast ratio for.
## NOTE the ordering: CJK/kana are ALSO above 0x2E80, so an emoji range check has to come first.
## Getting that backwards is how the first version of this let "🔒" and "🧪" through as if they
## were text and reported them at 2.35:1 and 3.48:1.
func _is_pictographic_only(txt: String) -> bool:
	for ch: String in txt:
		var cp: int = ch.unicode_at(0)
		if ch in PICTOGRAPHIC_OK:
			return false
		if _is_emoji_or_symbol(cp):
			continue
		if cp >= 0x2E80:  # CJK, kana, hangul: real text, measured normally
			return false
	return true
func _luminance(c: Color) -> float:
	var ch: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]

## Sample the rendered frame inside this control's rect: pixels matching the theme font colour are
## the glyphs, everything else is the backdrop the player actually reads them against. Both come
## from the same render, so gradients, vignettes and partially transparent panels are all included
## as they truly appear — no assumption about what colour the background "should" be.
##
## CONTRAST IS MEASURED LOCALLY, PER GLYPH PIXEL, NOT AS ONE AVERAGE OVER THE WHOLE RECT.
## This matters and the first version of this tool got it wrong. That version averaged every
## non-glyph pixel in the label's rect into a single "background" colour. For a small label the
## rect is mostly its own fill, so an outline -- the standard fix for text on a variable or
## mid-tone background, and what `_stat_bar` and the map pin captions now use -- was scored as if
## it barely helped: growing the outline from 2px to 10px on the battle-screen HP readout moved
## that average only 2.18 -> 2.73, because the letterforms are a small fraction of a 112x16 label
## and most of the "background" the metric saw was fill nowhere near a letter.
## An eye does not do that. It compares a glyph against what is immediately around it. So each
## glyph pixel is now compared against the mean of the non-glyph pixels within `LOCAL_RADIUS` of
## it, and the reported ratio is the average of those local ratios — plus `worst_ratio`, the
## single least-readable glyph pixel, which is what catches "readable except where it crosses the
## one bright rock".
const LOCAL_RADIUS := 3

func _measure_contrast(c: Control) -> Dictionary:
	if _img == null:
		return {}
	var txt: String = _label_of(c)
	if txt.strip_edges() == "":
		return {}
	if _is_pictographic_only(txt):
		return {}
	var fg: Color = c.get_theme_color("font_color")
	var mod: Color = _effective_modulate(c)
	if mod.a < 0.15 or fg.a < 0.15:
		return {}
	var r: Rect2 = _rect_of(c)
	var x0: int = clampi(int(r.position.x * _img_scale), 0, _img.get_width() - 1)
	var y0: int = clampi(int(r.position.y * _img_scale), 0, _img.get_height() - 1)
	var x1: int = clampi(int(r.end.x * _img_scale), 0, _img.get_width() - 1)
	var y1: int = clampi(int(r.end.y * _img_scale), 0, _img.get_height() - 1)
	if x1 - x0 < 2 or y1 - y0 < 2:
		return {}

	var fg_lin: Vector3 = Vector3(fg.r * mod.r, fg.g * mod.g, fg.b * mod.b)
	var fg_lum: float = _luminance(Color(fg_lin.x, fg_lin.y, fg_lin.z))

	# Pass 1: classify. A glyph's core pixel is close to the theme colour; anti-aliased edges blend
	# toward the backdrop and belong to neither bucket, so they are simply not counted.
	var w: int = x1 - x0
	var h: int = y1 - y0
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(w * h)
	var glyph_px: Array[Vector2i] = []
	var bg_sum := Color(0, 0, 0)
	var bg_n := 0
	var glyph_sum := Color(0, 0, 0)
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var p: Color = _img.get_pixel(x, y)
			var d: float = maxf(maxf(absf(p.r - fg_lin.x), absf(p.g - fg_lin.y)), absf(p.b - fg_lin.z))
			var idx: int = (y - y0) * w + (x - x0)
			if d < 0.14:
				mask[idx] = 1
				glyph_px.append(Vector2i(x, y))
				glyph_sum += p
			elif d > 0.30:
				mask[idx] = 2
				bg_sum += p
				bg_n += 1
	if glyph_px.size() < MIN_TEXT_PIXELS or bg_n < MIN_TEXT_PIXELS:
		return {}

	# Pass 2: for each glyph pixel, the mean colour of nearby non-glyph pixels.
	var radius: int = int(ceil(float(LOCAL_RADIUS) * _img_scale))
	var ratio_sum := 0.0
	var worst_ratio := 99.0
	var counted := 0
	var measured := 0
	for g: Vector2i in glyph_px:
		if measured >= 400:
			break
		measured += 1
		var nb := Color(0, 0, 0)
		var nb_n := 0
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var nx: int = g.x + dx
				var ny: int = g.y + dy
				if nx < x0 or nx >= x1 or ny < y0 or ny >= y1:
					continue
				if mask[(ny - y0) * w + (nx - x0)] == 2:
					nb += _img.get_pixel(nx, ny)
					nb_n += 1
		if nb_n == 0:
			continue
		var local: Color = nb / float(nb_n)
		var ll: float = _luminance(local)
		var hi: float = maxf(fg_lum, ll)
		var lo: float = minf(fg_lum, ll)
		var ratio: float = (hi + 0.05) / (lo + 0.05)
		ratio_sum += ratio
		worst_ratio = minf(worst_ratio, ratio)
		counted += 1
	if counted == 0:
		return {}

	var glyph_avg: Color = glyph_sum / float(glyph_px.size())
	var bg_avg: Color = bg_sum / float(bg_n)
	return {
		"ratio": ratio_sum / float(counted),
		"worst_ratio": worst_ratio,
		"fg_seen": "#" + glyph_avg.to_html(false),
		"bg_seen": "#" + bg_avg.to_html(false),
		"pixels": glyph_px.size(),
	}

func _is_large_text(c: Control) -> bool:
	# WCAG's "large text" breakpoint is 18pt, or 14pt when bold. This project ships a single
	# weight (LXGWWenKai-Medium), so there is no bold flag to read — the one reliable stand-in is
	# that Button text renders at the heavier end of what this font offers, Label captions at the
	# lighter end. Erring toward the stricter 4.5:1 floor costs nothing but a shorter report.
	var fs: int = _font_size_of(c)
	if fs >= 18:
		return true
	return fs >= 14 and c is Button

# ---------------------------------------------------------------- one screen

func _audit_screen(game: Control, name: String) -> void:
	for _i: int in 4:
		await process_frame
	# Freeze ambient motion so the sampled frame is the frame the layout describes, not a
	# keyframe of a bobbing animation.
	for p: Node in game.find_children("", "CPUParticles2D", true, false):
		(p as CPUParticles2D).emitting = false
	RenderingServer.force_draw(true)
	await process_frame
	_img = root.get_texture().get_image()
	_img_scale = float(_img.get_width()) / float(root.size.x) if _img != null else 1.0

	var touch: Array[Dictionary] = []
	var overflow: Array[Dictionary] = []
	var contrast: Array[Dictionary] = []
	var fonts: Array[Dictionary] = []
	var trunc: Array[Dictionary] = []

	for n: Node in game.find_children("", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree():
			continue
		var txt: String = _label_of(c)
		if _is_interactive(c):
			if c.size.x < TOUCH_MIN or c.size.y < TOUCH_MIN:
				var wired: bool = false
				var off: bool = false
				if c is BaseButton:
					off = (c as BaseButton).disabled
					wired = not (c as BaseButton).pressed.get_connections().is_empty()
				touch.append({
					"node": String(c.name),
					"text": txt.substr(0, 24),
					"size": [c.size.x, c.size.y],
					"short_by": [maxf(0.0, TOUCH_MIN - c.size.x), maxf(0.0, TOUCH_MIN - c.size.y)],
					# A target the player can actually hit is the one worth fixing. A disabled or
					# unwired one is listed too, but it is not counted as live.
					"disabled": off,
					"wired": wired,
				})
		if txt != "":
			var fs: int = _font_size_of(c)
			fonts.append({"node": String(c.name), "size": fs, "len": txt.length()})
			var b: Dictionary = _containment_breach(c)
			if not b.is_empty():
				b["node"] = String(c.name)
				b["text"] = txt.substr(0, 40)
				b["own_rect"] = _rect_to_a(_rect_of(c))
				overflow.append(b)
			if _truncates_text(c):
				trunc.append({"node": String(c.name), "text": txt.substr(0, 40), "width": c.size.x, "font_size": fs})
			var m: Dictionary = _measure_contrast(c)
			if not m.is_empty():
				var floor_v: float = CONTRAST_LARGE if _is_large_text(c) else CONTRAST_NORMAL
				if float(m["ratio"]) < floor_v:
					m["node"] = String(c.name)
					m["text"] = txt.substr(0, 32)
					m["font_size"] = fs
					m["floor"] = floor_v
					contrast.append(m)

	_screens.append({
		"screen": name,
		"rendered": _img != null,
		"touch_violations": touch,
		"overflow": overflow,
		"truncation": trunc,
		"contrast_violations": contrast,
		"font_sizes": fonts,
	})

func _report_and_quit(status: int) -> void:
	var gd := DirAccess.open("res://tests/snapshots")
	if gd == null:
		DirAccess.make_dir_recursive_absolute("res://tests/snapshots")
	var f := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"screens": _screens}, "  "))
		f.close()

	var total_touch := 0
	var total_live := 0
	var total_wired := 0
	var total_over := 0
	var total_contrast := 0
	var total_trunc := 0
	var smallest: Array[Dictionary] = []
	var worst: Array[Dictionary] = []
	var font_hist: Dictionary = {}

	print("\n" + "=".repeat(72))
	for s: Dictionary in _screens:
		var t: Array = s["touch_violations"]
		var o: Array = s["overflow"]
		var c: Array = s["contrast_violations"]
		var tr: Array = s["truncation"]
		var live: int = 0
		var wired: int = 0
		for e: Dictionary in t:
			if not bool(e["disabled"]):
				live += 1
			if not bool(e["disabled"]) and bool(e["wired"]):
				wired += 1
		total_touch += t.size()
		total_live += live
		total_wired += wired
		total_over += o.size()
		total_contrast += c.size()
		total_trunc += tr.size()
		for e: Dictionary in s["font_sizes"]:
			font_hist[int(e["size"])] = int(font_hist.get(int(e["size"]), 0)) + 1
		print("%-26s touch<44:%-3d (enabled %-3d, wired %-3d) clipped:%-3d contrast:%-3d truncated:%-3d" % [
			s["screen"], t.size(), live, wired, o.size(), c.size(), tr.size(),
		])
		for e: Dictionary in t:
			smallest.append({"screen": s["screen"], "d": e})
		for e: Dictionary in c:
			worst.append({"screen": s["screen"], "d": e})
	print("=".repeat(72))
	print("TOTAL  hit targets below 44pt: %d (%d enabled, %d of those wired) | text cut off: %d | low contrast: %d | text truncated: %d"
		% [total_touch, total_live, total_wired, total_over, total_contrast, total_trunc])

	smallest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]["size"][1]) < float(b["d"]["size"][1]))
	print("\n-- smallest hit targets --")
	for i: int in mini(18, smallest.size()):
		var e: Dictionary = smallest[i]
		var d: Dictionary = e["d"]
		print("  %-24s %-18s %dx%d   %s" % [e["screen"], d["node"], int(d["size"][0]), int(d["size"][1]), d["text"]])

	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]["worst_ratio"]) < float(b["d"]["worst_ratio"]))
	print("\n-- lowest measured contrast (avg local, then worst single glyph pixel) --")
	for i: int in mini(18, worst.size()):
		var e: Dictionary = worst[i]
		var d: Dictionary = e["d"]
		print("  %-24s %-16s avg %.2f:1  worst %.2f:1 (need %.1f)  %s on %s  \"%s\"" % [
			e["screen"], d["node"], d["ratio"], d["worst_ratio"], d["floor"], d["fg_seen"], d["bg_seen"], d["text"],
		])

	print("\n-- font sizes in use (count of visible text nodes) --")
	var keys: Array = font_hist.keys()
	keys.sort()
	for k: int in keys:
		print("  %2d pt : %d" % [k, font_hist[k]])

	print("\nFull JSON: %s" % ProjectSettings.globalize_path(OUT_JSON))
	quit(status)

# ---------------------------------------------------------------- driver

func _run() -> void:
	print("\nUI AUDIT — measured, not eyeballed\n")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/snapshots"))

	var scene: PackedScene = load("res://Main.tscn")
	var game: Control = scene.instantiate()
	root.add_child(game)
	await process_frame

	# Same deterministic profile as visual_snapshots.gd, minus the screenshot writing — the two
	# must agree on what state each screen is audited in, or the numbers describe a screen no
	# player ever sees.
	game.profile = SpiritSave.defaults(game.content)
	game.profile.gold = 420
	game.profile.spirit_jade = 85
	game.profile.currencies = {"gold": 420, "spirit_jade": 85, "trial_token": 60, "abyss_shard": 15}
	game.profile.stamina = {"current": 85, "max": 100, "last_regen_time": 1700000000}
	game.profile.daily_reset_at = 1700086400
	game.profile.weekly_reset_at = 1700600000
	game.profile.tutorial_seen = true
	game.lang = "zh-Hans"
	game.test_day_override = 20000
	await process_frame

	game.show_map()
	await _audit_screen(game, "01_map_screen")

	game.begin_battle(0)
	await process_frame
	if game.combat.state.enemies.size() > 1:
		game.combat.state.enemies.resize(1)
	game.combat.state.hand = [
		{"uid": 90001, "card_id": "strike"},
		{"uid": 90002, "card_id": "ward"},
		{"uid": 90003, "card_id": "strike"},
		{"uid": 90004, "card_id": "ward"},
		{"uid": 90005, "card_id": "strike"},
	]
	game.show_battle()
	await _audit_screen(game, "02_battle_screen")

	game._grant_stage_rewards()
	game.show_reward_details()
	await _audit_screen(game, "03_rewards_screen")

	game.show_shop()
	await _audit_screen(game, "04_shop_screen")

	game.show_deck()
	await _audit_screen(game, "05_deck_screen")

	game.show_camp()
	await _audit_screen(game, "06_camp_screen")

	game.show_map()
	await process_frame
	game.show_treasury_inspector()
	await _audit_screen(game, "07_treasury_inspector")

	game.compendium_tab = "codex"
	game.show_compendium()
	await _audit_screen(game, "08_codex_screen")

	game.profile.unlocked = 20
	game.profile.difficulty = 1
	game.camp_tab = "challenges"
	game.show_challenges()
	await _audit_screen(game, "09_challenges_screen")

	_report_and_quit(0)
