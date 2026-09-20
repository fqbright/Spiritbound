extends SceneTree

# Measures what Godot's own "Lossy" texture import (compress/mode=1) would cost, using the very
# encoder that import path uses (Image.save_webp_to_buffer), rather than a third-party proxy.
# Run: godot --headless --path Godot/ -s tools/tex_probe.gd
#
# Reports per file: source bytes, the WebP byte count at two quality levels, and the PSNR between
# the original and the round-tripped encode. PSNR is the number that decides whether "smaller"
# also means "still looks the same": >40dB is essentially indistinguishable, 35-40dB is normally
# invisible on a phone, and below ~32dB is where soft gradients (these banners are gradients)
# start to show banding. Nothing here writes to the project or touches any .import sidecar.

const SAMPLES: Array = [
	"res://assets/banners/banner_boss_rush.png",
	"res://assets/backgrounds/battle_stage_4.png",
	"res://assets/cards/card_back_default.png",
]
const QUALITIES: Array = [0.85, 0.90, 0.95]

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

func _initialize() -> void:
	print("\n=== Godot native WebP (Lossy import, compress/mode=1) measurement ===")
	print("source bytes -> WebP bytes at each quality, plus round-trip PSNR\n")
	for path in SAMPLES:
		var abs_path: String = ProjectSettings.globalize_path(path)
		var img: Image = Image.load_from_file(abs_path)
		if img == null:
			print("  ⚠ cannot load %s" % path)
			continue
		var raw_size: int = FileAccess.get_file_as_bytes(abs_path).size()
		print("%s" % path.get_file())
		print("  %dx%d, source %.2f MiB" % [img.get_width(), img.get_height(), raw_size / 1048576.0])
		for q in QUALITIES:
			var buf: PackedByteArray = img.save_webp_to_buffer(true, q)
			var decoded := Image.new()
			var err: int = decoded.load_webp_from_buffer(buf)
			var psnr_text := "decode failed (%d)" % err
			if err == OK:
				psnr_text = "%.1f dB" % _psnr(img, decoded)
			var saved_pct: float = (1.0 - float(buf.size()) / float(raw_size)) * 100.0
			print("  q=%.2f: %8.2f MiB  (-%5.1f%%)  PSNR %s" % [
				q, buf.size() / 1048576.0, saved_pct, psnr_text
			])
		print("")
	print("PSNR guide: >40dB indistinguishable, 35-40dB normally invisible, <32dB banding on gradients")
	quit(0)
