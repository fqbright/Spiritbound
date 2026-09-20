#!/usr/bin/env python3
"""One place that decides which texture sources ship Lossy, and the only thing that edits them.

Why a tool rather than 400 hand-edited sidecars: the decision is a *policy* ("large illustrated
art becomes Lossy q=0.95; UI icons, sprites, frames stay Lossless"), and a policy that lives in
400 individual files is one nobody can review, re-measure, or undo. Here it is four lists and a
size rule, so the next person can change one line and re-run.

Commands
--------
    python3 Godot/tools/tex_policy.py                      # dry run: print the plan, change nothing
    python3 Godot/tools/tex_policy.py --pck build/x.pck    # ...and join it with a real pack
    python3 Godot/tools/tex_policy.py --apply              # rewrite the .import sidecars
    python3 Godot/tools/tex_policy.py --restore            # put every sidecar back to Lossless

`--restore` exists because this is otherwise a one-way door: it is the difference between "we can
re-measure and back out" and "we cannot tell what the originals were". After --apply or --restore
run `godot --headless --path Godot/ --import` and re-export; the sidecar alone changes nothing
about what is already in Godot/.godot/imported/.

Reading the output
------------------
`pck` columns are the only size numbers that mean anything for shipping, and they are only shown
when --pck is passed. Source-directory bytes are NOT a proxy for pack bytes (Docs/ASSET_COMPRESSION.md
§'Current state'): Godot packs its own imported containers, so the two differ by ~5x here. Measure,
do not extrapolate.
"""
import argparse
import os
import re
import struct
import sys
from collections import defaultdict

GODOT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS_DIR = os.path.join(GODOT_DIR, "assets")

# ---------------------------------------------------------------------------------------------
# The policy. First match wins, so order matters: a specific directory is listed before the
# general size rule, and anything not named here still has to clear the size rule to be touched.
# ---------------------------------------------------------------------------------------------

# Small, high-contrast, or alpha-edge art. A block/transform codec rings on exactly these edges,
# and the files are tiny, so compressing them buys a rounding error and risks the most visible
# artifact class. Mirrors the recommendation recorded in Docs/ASSET_COMPRESSION.md.
KEEP_LOSSLESS_DIRS = (
    "assets/icons/",          # 82 files, 64-128 px: currency, nav, equipment glyphs
    "assets/badges/",         # 128 px rank badges
    "assets/pins/",           # 128 px map pins
    "assets/vfx/",            # 256-512 px effect sprites: thin, bright, hard alpha edges
    "assets/characters/fox_rig/",  # rig parts, 128-512 px, the fox is scaled and rotated at runtime
)
KEEP_LOSSLESS_PREFIXES = (
    "card_frame_",            # card borders: pure high-contrast overlay geometry
    "chest-atlas",            # sprite atlas, sliced into frames at runtime
    "map_tile_",
    "map_pin_",
)
# The title logo is the one asset a player stares at while it is the only thing on screen, and it
# is letterforms. Kept lossless deliberately, not by oversight.
KEEP_LOSSLESS_EXACT = ("assets/ui/spiritbound_logo.png",)

# The size rule. Both tests must pass: a big-but-already-tiny file (a flat 512x512 icon) is not
# worth touching, and a small-but-heavy file is a contradiction.
MIN_PIXELS = 384 * 384
MIN_BYTES = 48 * 1024

LOSSY_MODE = 1
LOSSLESS_MODE = 0
LOSSY_QUALITY = "0.95"


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(33)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def jpeg_size(path):
    with open(path, "rb") as fh:
        data = fh.read()
    i = 2
    while i < len(data) - 9:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3):
            h, w = struct.unpack(">HH", data[i + 5:i + 9])
            return (w, h)
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            i += 2
            continue
        i += 2 + struct.unpack(">H", data[i + 2:i + 4])[0]
    return None


def image_size(path):
    if path.endswith(".png"):
        return png_size(path)
    if path.endswith(".jpg") or path.endswith(".jpeg"):
        return jpeg_size(path)
    return None


def decide(rel, size, w, h):
    """Return (mode, quality, group, reason). `rel` is relative to Godot/, e.g. assets/cards/x.png"""
    if rel in KEEP_LOSSLESS_EXACT:
        return LOSSLESS_MODE, "0.7", "lossless: title logo", "letterforms on the splash screen"
    for d in KEEP_LOSSLESS_DIRS:
        if rel.startswith(d):
            return LOSSLESS_MODE, "0.7", "lossless: " + d.rstrip("/"), "UI/sprite art, hard alpha edges"
    base = os.path.basename(rel)
    for p in KEEP_LOSSLESS_PREFIXES:
        if base.startswith(p):
            return LOSSLESS_MODE, "0.7", "lossless: " + p.rstrip("_"), "UI frame/atlas overlay"
    if w * h < MIN_PIXELS:
        return LOSSLESS_MODE, "0.7", "lossless: under %d px" % MIN_PIXELS, "too small to matter"
    if size < MIN_BYTES:
        return LOSSLESS_MODE, "0.7", "lossless: under %d KiB" % (MIN_BYTES // 1024), "already light"
    return LOSSY_MODE, LOSSY_QUALITY, "lossy: large illustrated art", "large pixels, art/gradient content"


def sample_group(rel):
    """Group label used for the per-category quality measurement.

    Deliberately not the policy group: all 519 policy targets share one policy group
    ("large illustrated art"), which would collapse the PSNR table into a single row and hide the
    question that actually matters -- whether sprite art (characters/monsters) behaves differently
    from soft-gradient art (banners/backgrounds).
    """
    parts = rel.split("/")          # assets / <dir> / [<subdir>] / file
    if len(parts) >= 4 and parts[1] == "characters":
        return "assets/%s/%s" % (parts[1], parts[2])
    return "assets/%s" % parts[1] if len(parts) >= 3 else rel


def read_sidecar(path):
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def sidecar_param(text, key):
    m = re.search(r"^%s=([^\n]*)$" % re.escape(key), text, re.M)
    return m.group(1) if m else None


def sidecar_dest(text):
    m = re.search(r'^path="res://\.godot/imported/([^"]+)"$', text, re.M)
    return m.group(1) if m else None


def pck_entries(pck_path):
    """name -> byte size, for a Godot 4.4+ .pck (same footer walk as tools/pck_audit.py).

    The directory record's path field is NUL-padded to a 4-byte boundary, and an earlier version
    of pck_audit.py decoded that padding as part of the name, which is why its by-extension table
    used to read `ctex`, `ctex `, `ctex  ` as three different extensions. Stripped here.
    """
    with open(pck_path, "rb") as fh:
        data = fh.read()
    assert data[:4] == b"GDPC", "not a Godot .pck"
    end = len(data)
    out = {}
    while True:
        start = None
        for p in range(end - 4, max(end - 400, 0), -1):
            ln = struct.unpack("<I", data[p:p + 4])[0]
            if ln == 0 or ln > 300:
                continue
            if p + 4 + ln != end - 36:
                continue
            chunk = data[p + 4:p + 4 + ln]
            if b"." in chunk and all(c == 0 or 32 <= c < 127 for c in chunk):
                start = p
                break
        if start is None:
            break
        ln = struct.unpack("<I", data[start:start + 4])[0]
        name = data[start + 4:start + 4 + ln].decode().rstrip("\x00")
        _, size = struct.unpack("<QQ", data[start + 4 + ln:start + 4 + ln + 16])
        out[os.path.basename(name)] = size
        end = start
    return out


def collect():
    rows = []
    for root, _dirs, files in os.walk(ASSETS_DIR):
        for fn in files:
            if not fn.endswith((".png", ".jpg", ".jpeg")):
                continue
            src = os.path.join(root, fn)
            side = src + ".import"
            if not os.path.exists(side):
                continue
            rel = os.path.relpath(src, GODOT_DIR).replace(os.sep, "/")
            dims = image_size(src)
            if not dims:
                continue
            w, h = dims
            size = os.path.getsize(src)
            text = read_sidecar(side)
            mode, quality, group, reason = decide(rel, size, w, h)
            rows.append({
                "rel": rel, "side": side, "size": size, "w": w, "h": h,
                "cur_mode": int(sidecar_param(text, "compress/mode") or 0),
                "new_mode": mode, "new_quality": quality,
                "group": group, "reason": reason,
                "dest": sidecar_dest(text),
            })
    rows.sort(key=lambda r: (-r["size"], r["rel"]))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="rewrite the .import sidecars")
    ap.add_argument("--restore", action="store_true", help="put every sidecar back to Lossless")
    ap.add_argument("--pck", help="an exported .pck to join the plan against")
    ap.add_argument("--files", action="store_true", help="also print every file, not just group totals")
    ap.add_argument("--samples", metavar="OUT",
                    help="write the per-group sample list that tools/tex_probe.gd measures "
                         "(lines of `<group>|<res://path>`)")
    ap.add_argument("--per-group", type=int, default=8,
                    help="how many files per group --samples writes; 0 means every file (default 8)")
    args = ap.parse_args()

    rows = collect()
    packed = pck_entries(args.pck) if args.pck else None

    for r in rows:
        if packed is not None:
            r["pack"] = packed.get(r["dest"], 0) if r["dest"] else 0
        else:
            r["pack"] = 0

    groups = defaultdict(lambda: {"n": 0, "src": 0, "pack": 0, "px": 0, "worst": None,
                                 "to_lossy": 0, "cur_lossy": 0})
    for r in rows:
        g = groups[r["group"]]
        g["n"] += 1
        g["src"] += r["size"]
        g["pack"] += r["pack"]
        g["px"] += r["w"] * r["h"]
        if g["worst"] is None or r["size"] > g["worst"]["size"]:
            g["worst"] = r
        if r["new_mode"] == LOSSY_MODE:
            g["to_lossy"] += 1
        if r["cur_mode"] == LOSSY_MODE:
            g["cur_lossy"] += 1

    print("texture sources with sidecars: %d   source bytes: %.1f MiB" % (
        len(rows), sum(r["size"] for r in rows) / 1048576))
    if packed is None:
        print("(no --pck given: pack columns are blank. Source bytes are NOT pack bytes.)")
    print()
    hdr = "%-38s %5s %10s %10s %7s" % ("group", "files", "src MiB", "pack MiB", "pack %")
    print(hdr)
    print("-" * len(hdr))
    total_pack = sum(r["pack"] for r in rows) or 1
    for name in sorted(groups, key=lambda k: -groups[k]["pack"]):
        g = groups[name]
        print("%-38s %5d %10.1f %10.1f %6.1f%%" % (
            name, g["n"], g["src"] / 1048576, g["pack"] / 1048576, 100 * g["pack"] / total_pack))
    print()

    to_lossy = [r for r in rows if r["new_mode"] == LOSSY_MODE and r["cur_mode"] != LOSSY_MODE]
    print("would switch Lossless -> Lossy q=%s: %d files, %.1f MiB source, %.1f MiB packed" % (
        LOSSY_QUALITY, len(to_lossy),
        sum(r["size"] for r in to_lossy) / 1048576,
        sum(r["pack"] for r in to_lossy) / 1048576))
    stay = [r for r in rows if r["new_mode"] == LOSSLESS_MODE]
    print("stay Lossless:                       %d files, %.1f MiB source, %.1f MiB packed" % (
        len(stay), sum(r["size"] for r in stay) / 1048576, sum(r["pack"] for r in stay) / 1048576))
    if packed is not None:
        print("pack total (all entries): %.1f MiB" % (sum(packed.values()) / 1048576))

    # Pack bytes by source directory. Needed to price an exclusion: "does lossy hurt this art?" and
    # "what does leaving it out cost?" are two different questions, and a policy that only answers
    # the first can end up protecting 0.1 MiB of sprites and letting 40 MiB of something else past.
    print("\n=== pack bytes by source directory ===")
    print("%-34s %5s %10s %10s %7s %8s" % ("dir", "files", "src MiB", "pack MiB", "pack %", "policy"))
    dirs = defaultdict(lambda: {"n": 0, "src": 0, "pack": 0, "lossy": 0, "keep": 0})
    for r in rows:
        d = os.path.dirname(r["rel"])
        e = dirs[d]
        e["n"] += 1
        e["src"] += r["size"]
        e["pack"] += r["pack"]
        if r["new_mode"] == LOSSY_MODE:
            e["lossy"] += 1
        else:
            e["keep"] += 1
    for d in sorted(dirs, key=lambda k: -dirs[k]["pack"]):
        e = dirs[d]
        label = "%d lossy / %d keep" % (e["lossy"], e["keep"])
        print("%-34s %5d %10.1f %10.1f %6.1f%% %8s" % (
            d, e["n"], e["src"] / 1048576, e["pack"] / 1048576,
            100 * e["pack"] / total_pack, label))

    if args.files:
        print("\n=== per file (source MiB, px, current mode -> new) ===")
        for r in rows:
            print("%7.2f MiB %5dx%-5d mode %d -> %d  %s" % (
                r["size"] / 1048576, r["w"], r["h"], r["cur_mode"], r["new_mode"], r["rel"]))
        print()

    if args.samples:
        # Only the files the policy actually intends to touch: measuring lossless files would
        # answer a question nobody asked.
        picked = []
        by_group = defaultdict(list)
        for r in rows:
            if r["new_mode"] == LOSSY_MODE:
                by_group[sample_group(r["rel"])].append(r)
        for group in sorted(by_group):
            files = sorted(by_group[group], key=lambda r: -r["size"])
            if args.per_group:
                files = files[:args.per_group]
            for r in files:
                picked.append("%s|res://%s" % (group, r["rel"]))
        with open(args.samples, "w", encoding="utf-8") as fh:
            fh.write("# generated by tools/tex_policy.py --samples -- do not hand-edit\n")
            fh.write("# read by tools/tex_probe.gd; one `<group>|<res://path>` per line\n")
            fh.write("\n".join(picked) + "\n")
        print("wrote %d samples (%s) to %s" % (
            len(picked), "every policy file" if not args.per_group else "top %d per group" % args.per_group,
            args.samples))

    if args.apply or args.restore:
        changed = 0
        for r in rows:
            mode = LOSSLESS_MODE if args.restore else r["new_mode"]
            quality = "0.7" if args.restore else r["new_quality"]
            text = read_sidecar(r["side"])
            new = re.sub(r"^compress/mode=.*$", "compress/mode=%d" % mode, text, count=1, flags=re.M)
            new = re.sub(r"^compress/lossy_quality=.*$", "compress/lossy_quality=%s" % quality,
                         new, count=1, flags=re.M)
            if new != text:
                with open(r["side"], "w", encoding="utf-8") as fh:
                    fh.write(new)
                changed += 1
        verb = "restored to Lossless" if args.restore else "applied"
        print("%s: %d sidecars rewritten" % (verb, changed))
        print("next: godot --headless --path Godot/ --import   (the sidecar alone changes nothing)")
    else:
        print("\n(dry run: nothing written. Use --apply to rewrite the sidecars.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
