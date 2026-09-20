extends SceneTree

# Measures what Godot's own "Lossy" texture import (compress/mode=1) actually costs, using the
# very encoder that import path uses (Image.save_webp_to_buffer), rather than a third-party proxy.
#
# Run: godot --headless --path Godot/ -s tools/tex_probe.gd
#
# The file list comes from tools/tex_policy.py, which owns the decision about *which* sources ship
# Lossy -- one policy, one place. Generate it with:
#     python3 Godot/tools/tex_policy.py --samples Godot/tools/tex_probe_samples.txt
# Each line is "<group>|<res://path>". Without that file the probe falls back to a small built-in
# list, so it still runs in a fresh checkout.
#
# Reports per file: source bytes, WebP bytes at each quality, and the PSNR between the original and
# the round-tripped encode, then a per-group summary with the *worst* file named. PSNR is the
# number that decides whether "smaller" also means "still looks the same": >40 dB is essentially
# indistinguishable, 35-40 dB is normally invisible on a phone, and below ~32 dB is where soft
# gradients (these banners are gradients) start to show banding.
#
# Nothing here writes to the project or touches any .import sidecar: it is the measurement, not
# the change. `tex_policy.py --apply` is the change.

const SAMPLE_LIST := "res://tools/tex_probe_samples.txt"
const FALLBACK: Array = [
	"lossy: large illustrated art|res://assets/banners/banner_boss_rush.png",
	"lossy: large illustrated art|res://assets/backgrounds/battle_stage_4.png",
	"lossy: large illustrated art|res://assets/cards/card_back_default.png",
]
const QUALITIES: Array = [0.95, 0.98]

func _psnr(a: Image, b: Image) -> float:
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return -1.0
	var w: int = a.get_width()
	var h: int = a.get_height()
	# Strided sampling: a full 1376x768 sweep is ~1M pixels and GDScript's per-pixel get_pixel()
	# makes that take minutes for no extra information -- PSNR is an average, so ~60k evenly spread
	# samples converge to the same number. Stride 4 on the largest sample image still walks every
	# 4th row and column, which is far finer than any compression block.
	var stride: int = 4
	var se := 0.0
	var n := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			for d in [ca.r - cb.r, ca.g - cb.g, ca.b - cb.b]:
				se += d * d
				n += 1
			x += stride
		y += stride
	if se <= 0.0:
		return 99.0
	var mse: float = se / float(n)
	# PSNR in dB with a peak of 1.0 (Godot colors are normalised): 10 * log10(1 / MSE).
	return -10.0 * (log(mse) / log(10.0))

# `_psnr` above scores RGB over every pixel, which is the wrong question for art with
# transparency: a fully transparent pixel has no visible colour, and whatever RGB it happens to
# hold is not something a player can see, so counting its error as a quality loss is measuring the
# encoder's opinion about an invisible pixel. On the character and monster sprites this dominated
# the score completely -- their PSNR read ~17-23 dB, i.e. "severe banding", at *both* q=0.90 and
# q=0.95, with the two qualities differing by 0.0-0.1 dB. A number that does not move when the
# quality does was not measuring the quality.
#
# So measure the two channels separately and over the right population:
#   _psnr_rgb   -- RGB, but only over pixels that are actually visible (alpha above a floor)
#   _psnr_alpha -- the alpha plane over all pixels, which is where a lossy pass really can hurt
#                  sprite art (soft or faded edges turning into hard steps).
func _psnr_rgb(a: Image, b: Image, alpha_floor: float = 0.06) -> Array:
	var w: int = a.get_width()
	var h: int = b.get_height()
	var stride: int = 2
	var se := 0.0
	var n := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			# Visible per either image: a pixel opaque in the original and transparent in the
			# encode is a real artifact, so "either" rather than "both".
			if maxf(ca.a, cb.a) > alpha_floor:
				for d in [ca.r - cb.r, ca.g - cb.g, ca.b - cb.b]:
					se += d * d
					n += 1
			x += stride
		y += stride
	if n == 0:
		return [99.0, 0]      # fully transparent image: nothing visible to score
	return [(-10.0 * (log(se / float(n)) / log(10.0))) if se > 0.0 else 99.0, n]

func _psnr_alpha(a: Image, b: Image) -> float:
	var w: int = a.get_width()
	var h: int = b.get_height()
	var stride: int = 2
	var se := 0.0
	var n := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var d: float = a.get_pixel(x, y).a - b.get_pixel(x, y).a
			se += d * d
			n += 1
			x += stride
		y += stride
	if se <= 0.0:
		return 99.0
	return -10.0 * (log(se / float(n)) / log(10.0))

# The metric that matches what a player can actually see, and the one this tool should have used
# from the start: composite both images over the same opaque backdrop and compare the result.
#
# Straight (non-premultiplied) RGB is only defined where alpha is 1. On a sprite's anti-aliased rim
# the source RGB is whatever the authoring tool left in the near-transparent pixels, and a codec is
# free to change it: the composited pixel is identical because alpha multiplies it away, but a
# straight-RGB comparison counts the difference as error. That is why the monster sprites scored
# ~31 dB at q=0.90, q=0.95 *and* q=0.98 -- a number that does not respond to the quality setting is
# not measuring quality. Compositing removes the ambiguity: a pixel that is 4% opaque cannot
# contribute more than 4% of its colour error.
#
# Backdrop is mid-grey rather than the game's actual background so the number does not depend on
# which screen the art happens to appear on; for opaque art (every background and banner here) the
# backdrop cancels out and this equals the plain RGB comparison.
func _psnr_composited(a: Image, b: Image) -> Array:
	var w: int = a.get_width()
	var h: int = b.get_height()
	var stride: int = 2
	var backdrop := Color(0.5, 0.5, 0.5, 1.0)
	var se := 0.0
	var n := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var fa := Color(backdrop.r * (1.0 - ca.a) + ca.r * ca.a,
				backdrop.g * (1.0 - ca.a) + ca.g * ca.a,
				backdrop.b * (1.0 - ca.a) + ca.b * ca.a)
			var fb := Color(backdrop.r * (1.0 - cb.a) + cb.r * cb.a,
				backdrop.g * (1.0 - cb.a) + cb.g * cb.a,
				backdrop.b * (1.0 - cb.a) + cb.b * cb.a)
			for d in [fa.r - fb.r, fa.g - fb.g, fa.b - fb.b]:
				se += d * d
				n += 1
			x += stride
		y += stride
	if se <= 0.0:
		return [99.0, n]
	return [-10.0 * (log(se / float(n)) / log(10.0)), n]

func _samples() -> Array:
	if not FileAccess.file_exists(SAMPLE_LIST):
		print("(no %s: using the built-in 3-file list; the full policy list is generated by"
			% SAMPLE_LIST.get_file())
		print("`python3 Godot/tools/tex_policy.py --samples Godot/tools/tex_probe_samples.txt`)\n")
		return FALLBACK
	var f := FileAccess.open(SAMPLE_LIST, FileAccess.READ)
	if f == null:
		return FALLBACK
	var out: Array = []
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split("|", true, 1)
		if parts.size() == 2:
			out.append(line)
	return out

func _initialize() -> void:
	print("\n=== Godot native WebP (Lossy import, compress/mode=1) measurement ===")
	print("source bytes -> WebP bytes at each quality, plus round-trip PSNR\n")
	# group -> {n, src, q90, q95, psnr_min at the applied quality, worst file}
	var groups: Dictionary = {}
	var q_applied: float = QUALITIES[QUALITIES.size() - 1]
	for entry in _samples():
		var parts: Array = entry.split("|", true, 1)
		var group: String = parts[0]
		var path: String = parts[1]
		var abs_path: String = ProjectSettings.globalize_path(path)
		var img: Image = Image.load_from_file(abs_path)
		if img == null:
			print("  ⚠ cannot load %s" % path)
			continue
		var raw_size: int = FileAccess.get_file_as_bytes(abs_path).size()
		var is_opaque: bool = not img.detect_alpha()
		var sizes: Array = []
		var psnrs: Array = []
		print("%s  (%s)  %s" % [
			path.get_file(), group, "opaque" if is_opaque else "has alpha"
		])
		print("  %dx%d, source %.2f MiB" % [img.get_width(), img.get_height(), raw_size / 1048576.0])
		for i in QUALITIES.size():
			var q: float = QUALITIES[i]
			var buf: PackedByteArray = img.save_webp_to_buffer(true, q)
			var decoded := Image.new()
			var err: int = decoded.load_webp_from_buffer(buf)
			var rgb_text := "decode failed (%d)" % err
			var alpha_text := "n/a (opaque)"
			var comp_psnr := -1.0
			if err == OK:
				var comp: Array = _psnr_composited(img, decoded)
				comp_psnr = comp[0]
				rgb_text = "%.1f dB over %d px" % [comp_psnr, comp[1]]
				if not is_opaque:
					alpha_text = "alpha %.1f dB" % _psnr_alpha(img, decoded)
			var saved_pct: float = (1.0 - float(buf.size()) / float(raw_size)) * 100.0
			print("  q=%.2f: %8.2f MiB  (-%5.1f%%)  composited %s  %s" % [
				q, buf.size() / 1048576.0, saved_pct, rgb_text, alpha_text
			])
			sizes.append(buf.size())
			psnrs.append(comp_psnr)
		print("")
		if not groups.has(group):
			groups[group] = {
				"n": 0, "src": 0, "q90": 0, "q95": 0, "alpha": 0,
				"psnr_min": 999.0, "psnr_sum": 0.0, "psnr_n": 0, "worst": "", "worst_psnr": 999.0,
			}
		var g: Dictionary = groups[group]
		g.n += 1
		g.src += raw_size
		g.q90 += sizes[0]
		g.q95 += sizes[sizes.size() - 1]
		if not is_opaque:
			g.alpha += 1
		var ap: float = psnrs[psnrs.size() - 1]
		if ap > 0.0:
			g.psnr_sum += ap
			g.psnr_n += 1
			if ap < g.psnr_min:
				g.psnr_min = ap
				g.worst = path.get_file()
				g.worst_psnr = ap

	print("=== per-group summary (at the quality the policy applies, q=%.2f) ===" % q_applied)
	print("Composited = both images flattened over mid-grey, then compared; that is what a player sees. (see _psnr_rgb); PSNR over all pixels")
	print("Straight-RGB comparison is what made the sprites read as 17 dB at every quality.")
	print("%-30s %5s %4s %9s %9s %7s %8s  %s" % [
		"group", "files", "a", "src MiB", "webp MiB", "saved", "min PSNR", "worst file"])
	for group in groups:
		var g: Dictionary = groups[group]
		var mean_psnr: float = 99.0
		if g.psnr_n > 0:
			mean_psnr = g.psnr_sum / float(g.psnr_n)
		print("%-30s %5d %4d %9.2f %9.2f %6.1f%% %8s  %s" % [
			group, g.n, g.alpha, g.src / 1048576.0, g.q95 / 1048576.0,
			100.0 * (1.0 - float(g.q95) / float(g.src)),
			("%.1f" % g.psnr_min) if g.psnr_n > 0 else "n/a",
			("%s (mean %.1f dB)" % [g.worst, mean_psnr]) if g.psnr_n > 0 else "",
		])
	print("")
	print("PSNR guide: >40dB indistinguishable, 35-40dB normally invisible, <32dB banding on gradients")
	print("These are SOURCE-directory numbers. The pack stores Godot's own containers, so this table")
	print("does not predict the .pck delta -- measure that with pck_audit.py / tex_policy.py --pck.")
	quit(0)
