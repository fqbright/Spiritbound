#!/usr/bin/env python3
"""
Spiritbound 20-Second Cinematic Intro Video Generator
Composites game card art, mystical backgrounds, hero spirit sprites, and cinematic VFX
into a 20-second (600 frames @ 30fps) 720x1280 video matching the xianxia card art style.
Encodes directly to Ogg Theora (.ogv) for Godot 4 native VideoStreamTheora playback.
"""

import math
import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

WIDTH = 720
HEIGHT = 1280
FPS = 30
DURATION = 20.0
TOTAL_FRAMES = int(FPS * DURATION) # 600 frames

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT_DIR, "assets")
OUTPUT_OGV = os.path.join(ASSETS_DIR, "video", "intro_cutscene.ogv")
TEMP_MP4 = "/tmp/intro_cutscene_raw.mp4"
AUDIO_PATH = os.path.join(ASSETS_DIR, "audio", "spirit-path-mobile.wav")

def load_img(rel_path, size=None):
    full = os.path.join(ASSETS_DIR, rel_path)
    if not os.path.exists(full):
        full = os.path.join(ROOT_DIR, rel_path)
    if os.path.exists(full):
        im = Image.open(full).convert("RGBA")
        if size:
            im = im.resize(size, Image.Resampling.LANCZOS)
        return im
    return None

def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)

print("--- Preloading Spiritbound Assets for 20s Intro Video ---")
# Backgrounds
bg_space = load_img("backgrounds/spirit-world-map-v1.png", (WIDTH, HEIGHT))
bg_ember = load_img("backgrounds/ember-cliff-v1.png", (WIDTH, HEIGHT))
bg_battle = load_img("backgrounds/battlefield-v1.png", (WIDTH, HEIGHT))

# Key Card Arts
card_cosmos = load_img("cards/cosmos_seal.png")
card_samsara = load_img("cards/samsara_cycle.png")
card_fire = load_img("cards/blaze_tempest.png")
card_water = load_img("cards/aqua_lotus.png")
card_thunder = load_img("cards/celestial_lance.png")
card_void = load_img("cards/spiritNova.png")
card_divine = load_img("cards/divine_intervention.png")
card_moon = load_img("cards/moonfang.png")

# Hero
hero_fox = load_img("characters/hero_fox_spirit.png")

# Fonts
font_cjk_path = os.path.join(ASSETS_DIR, "fonts", "LXGWWenKai-Medium.ttf")
font_cinzel_path = os.path.join(ASSETS_DIR, "fonts", "Cinzel-SemiBold.ttf")

font_title_en = ImageFont.truetype(font_cinzel_path, 60) if os.path.exists(font_cinzel_path) else ImageFont.load_default()
font_title_zh = ImageFont.truetype(font_cjk_path, 46) if os.path.exists(font_cjk_path) else ImageFont.load_default()
font_sub = ImageFont.truetype(font_cjk_path, 22) if os.path.exists(font_cjk_path) else ImageFont.load_default()

# Precompute floating particle seeds (60 celestial motes)
particles = []
for i in range(70):
    particles.append({
        "seed_x": (i * 79 + 31) % WIDTH,
        "seed_y": (i * 113 + 47) % HEIGHT,
        "speed": 0.8 + ((i * 17) % 15) * 0.15,
        "size": 2 + (i % 4),
        "phase": (i * 0.35)
    })

def render_frame(frame_idx):
    t = frame_idx / float(FPS) # 0.0 to 20.0
    frame = Image.new("RGBA", (WIDTH, HEIGHT), (6, 10, 16, 255))
    
    # Global time markers
    # Act 1: 0.0s - 5.0s (Cosmos / Primordial awakening)
    # Act 2: 5.0s - 10.0s (Five Elements / Card Art showcase)
    # Act 3: 10.0s - 15.0s (Spirit Fox arrival & Awakening)
    # Act 4: 15.0s - 20.0s (Climax Title & Spiritbound Seal)

    if t < 5.2:
        # Act 1: Primordial Cosmos & Samsara
        prog = t / 5.0
        # Slow zoom on cosmic space background
        scale = 1.0 + prog * 0.08
        sw, sh = int(WIDTH * scale), int(HEIGHT * scale)
        bg = bg_space.resize((sw, sh), Image.Resampling.BILINEAR)
        crop_x = (sw - WIDTH) // 2
        crop_y = (sh - HEIGHT) // 2
        frame.paste(bg.crop((crop_x, crop_y, crop_x + WIDTH, crop_y + HEIGHT)), (0, 0))

        # Cosmic dark tint
        dark = Image.new("RGBA", (WIDTH, HEIGHT), (0, 4, 10, int(160 * (1.0 - prog * 0.3))))
        frame = Image.alpha_composite(frame, dark)

        # Center Cosmic Seal rotating slowly
        card_size = int(380 + prog * 40)
        c_im = card_cosmos.resize((card_size, card_size), Image.Resampling.LANCZOS)
        # Circular soft vignette mask on card
        mask = Image.new("L", (card_size, card_size), 0)
        d_mask = ImageDraw.Draw(mask)
        d_mask.ellipse((20, 20, card_size - 20, card_size - 20), fill=230)
        mask = mask.filter(ImageFilter.GaussianBlur(28))
        
        # Fade in card
        alpha = smoothstep(0.4, 2.0, t) * (1.0 - smoothstep(4.2, 5.2, t))
        c_im.putalpha(mask)
        enh = ImageEnhance.Color(c_im).enhance(1.3)
        c_alpha = Image.new("RGBA", (card_size, card_size), (0, 0, 0, 0))
        c_alpha.paste(enh, (0, 0))
        # Apply alpha
        r, g, b, a = c_alpha.split()
        a = a.point(lambda p: int(p * alpha))
        c_alpha.putalpha(a)
        
        rot_ang = t * 12.0
        c_rot = c_alpha.rotate(rot_ang, resample=Image.Resampling.BICUBIC)
        cx = (WIDTH - card_size) // 2
        cy = (HEIGHT - card_size) // 2 - 40
        frame.paste(c_rot, (cx, cy), c_rot)

    elif t < 10.2:
        # Act 2: Elemental Surge & Card Spell Art
        prog = (t - 5.0) / 5.0
        # Background: Ember Cliff blending into ethereal mist
        scale = 1.05 + prog * 0.06
        sw, sh = int(WIDTH * scale), int(HEIGHT * scale)
        bg = bg_ember.resize((sw, sh), Image.Resampling.BILINEAR)
        crop_x = (sw - WIDTH) // 2
        crop_y = (sh - HEIGHT) // 2
        frame.paste(bg.crop((crop_x, crop_y, crop_x + WIDTH, crop_y + HEIGHT)), (0, 0))

        # Four elemental cards shifting dynamically across the screen
        # Sub-act A (5.0s - 7.5s): Fire & Water (Blaze Tempest & Aqua Lotus)
        # Sub-act B (7.5s - 10.0s): Thunder & Void (Celestial Lance & Spirit Nova)
        elem_t = (t - 5.0)
        if elem_t < 2.5:
            # Fire & Water clash
            sub_p = elem_t / 2.5
            cs = int(320 + sub_p * 30)
            
            # Fire card on top-left drifting
            cf = card_fire.resize((cs, cs), Image.Resampling.LANCZOS)
            mf = Image.new("L", (cs, cs), 0)
            ImageDraw.Draw(mf).ellipse((15, 15, cs - 15, cs - 15), fill=240)
            mf = mf.filter(ImageFilter.GaussianBlur(22))
            cf.putalpha(mf)
            
            f_alpha = smoothstep(0.0, 0.6, elem_t) * (1.0 - smoothstep(2.0, 2.6, elem_t))
            r, g, b, a = cf.split()
            cf.putalpha(a.point(lambda p: int(p * f_alpha)))
            fx = int(WIDTH * 0.15 - sub_p * 30)
            fy = int(HEIGHT * 0.28 + math.sin(sub_p * 3.0) * 20)
            frame.paste(cf, (fx, fy), cf)
            
            # Water card on bottom-right drifting
            cw = card_water.resize((cs, cs), Image.Resampling.LANCZOS)
            mw = Image.new("L", (cs, cs), 0)
            ImageDraw.Draw(mw).ellipse((15, 15, cs - 15, cs - 15), fill=240)
            mw = mw.filter(ImageFilter.GaussianBlur(22))
            cw.putalpha(mw)
            r, g, b, a = cw.split()
            cw.putalpha(a.point(lambda p: int(p * f_alpha)))
            wx = int(WIDTH * 0.42 + sub_p * 30)
            wy = int(HEIGHT * 0.48 - math.cos(sub_p * 3.0) * 20)
            frame.paste(cw, (wx, wy), cw)
        else:
            # Thunder & Spirit Nova clash
            sub_p = (elem_t - 2.5) / 2.5
            cs = int(330 + sub_p * 30)
            
            ct = card_thunder.resize((cs, cs), Image.Resampling.LANCZOS)
            mt = Image.new("L", (cs, cs), 0)
            ImageDraw.Draw(mt).ellipse((15, 15, cs - 15, cs - 15), fill=240)
            mt = mt.filter(ImageFilter.GaussianBlur(22))
            ct.putalpha(mt)
            t_alpha = smoothstep(0.0, 0.6, sub_p * 2.5) * (1.0 - smoothstep(2.0, 2.6, sub_p * 2.5))
            r, g, b, a = ct.split()
            ct.putalpha(a.point(lambda p: int(p * t_alpha)))
            tx = int(WIDTH * 0.40 + sub_p * 25)
            ty = int(HEIGHT * 0.26 + math.sin(sub_p * 3.0) * 20)
            frame.paste(ct, (tx, ty), ct)
            
            cv = card_void.resize((cs, cs), Image.Resampling.LANCZOS)
            mv = Image.new("L", (cs, cs), 0)
            ImageDraw.Draw(mv).ellipse((15, 15, cs - 15, cs - 15), fill=240)
            mv = mv.filter(ImageFilter.GaussianBlur(22))
            cv.putalpha(mv)
            r, g, b, a = cv.split()
            cv.putalpha(a.point(lambda p: int(p * t_alpha)))
            vx = int(WIDTH * 0.16 - sub_p * 25)
            vy = int(HEIGHT * 0.50 - math.cos(sub_p * 3.0) * 20)
            frame.paste(cv, (vx, vy), cv)

    elif t < 15.2:
        # Act 3: The Spirit Fox Awakens
        prog = (t - 10.0) / 5.0
        # Background: Majestic Spirit Battlefield
        scale = 1.08 - prog * 0.04
        sw, sh = int(WIDTH * scale), int(HEIGHT * scale)
        bg = bg_battle.resize((sw, sh), Image.Resampling.BILINEAR)
        crop_x = (sw - WIDTH) // 2
        crop_y = (sh - HEIGHT) // 2
        frame.paste(bg.crop((crop_x, crop_y, crop_x + WIDTH, crop_y + HEIGHT)), (0, 0))

        # Soft ethereal battlefield mist overlay
        mist = Image.new("RGBA", (WIDTH, HEIGHT), (10, 30, 45, int(110 * (1.0 - prog * 0.4))))
        frame = Image.alpha_composite(frame, mist)

        # Flanking floating cards: Divine Intervention & Moonfang
        card_p = smoothstep(0.4, 2.5, t - 10.0) * (1.0 - smoothstep(4.0, 5.2, t - 10.0))
        if card_p > 0.01:
            c_sz = 260
            cd = card_divine.resize((c_sz, c_sz), Image.Resampling.LANCZOS)
            md = Image.new("L", (c_sz, c_sz), 0)
            ImageDraw.Draw(md).ellipse((12, 12, c_sz - 12, c_sz - 12), fill=230)
            md = md.filter(ImageFilter.GaussianBlur(20))
            cd.putalpha(md)
            r, g, b, a = cd.split()
            cd.putalpha(a.point(lambda p: int(p * card_p * 0.85)))
            frame.paste(cd, (int(WIDTH * 0.06), int(HEIGHT * 0.48 + math.sin(prog * 4.0) * 15)), cd)

            cm = card_moon.resize((c_sz, c_sz), Image.Resampling.LANCZOS)
            mm = Image.new("L", (c_sz, c_sz), 0)
            ImageDraw.Draw(mm).ellipse((12, 12, c_sz - 12, c_sz - 12), fill=230)
            mm = mm.filter(ImageFilter.GaussianBlur(20))
            cm.putalpha(mm)
            r, g, b, a = cm.split()
            cm.putalpha(a.point(lambda p: int(p * card_p * 0.85)))
            frame.paste(cm, (int(WIDTH * 0.58), int(HEIGHT * 0.46 - math.sin(prog * 4.0) * 15)), cm)

        # The Spirit Fox rising majestically in center
        fox_scale = 0.52 + prog * 0.04
        fw = int(hero_fox.width * fox_scale)
        fh = int(hero_fox.height * fox_scale)
        fox = hero_fox.resize((fw, fh), Image.Resampling.LANCZOS)
        
        fox_alpha = smoothstep(0.2, 1.8, t - 10.0)
        r, g, b, a = fox.split()
        fox.putalpha(a.point(lambda p: int(p * fox_alpha)))

        fx = (WIDTH - fw) // 2
        fy = int(HEIGHT * 0.32 - prog * 25 + math.sin(prog * 5.0) * 8)
        frame.paste(fox, (fx, fy), fox)

    else:
        # Act 4: Climax Title & Spiritbound Seal
        prog = (t - 15.0) / 5.0
        # Deep cosmic twilight background with golden radiance
        sw, sh = int(WIDTH * 1.04), int(HEIGHT * 1.04)
        bg = bg_space.resize((sw, sh), Image.Resampling.BILINEAR)
        crop_x = (sw - WIDTH) // 2
        crop_y = (sh - HEIGHT) // 2
        frame.paste(bg.crop((crop_x, crop_y, crop_x + WIDTH, crop_y + HEIGHT)), (0, 0))

        # Center Samsara Cycle runic backdrop radiating outward
        seal_sz = int(460 + prog * 60)
        c_sam = card_samsara.resize((seal_sz, seal_sz), Image.Resampling.LANCZOS)
        sm = Image.new("L", (seal_sz, seal_sz), 0)
        ImageDraw.Draw(sm).ellipse((20, 20, seal_sz - 20, seal_sz - 20), fill=220)
        sm = sm.filter(ImageFilter.GaussianBlur(32))
        c_sam.putalpha(sm)
        
        seal_alpha = smoothstep(0.0, 1.2, t - 15.0) * (1.0 - smoothstep(4.0, 5.0, t - 15.0) * 0.6)
        r, g, b, a = c_sam.split()
        c_sam.putalpha(a.point(lambda p: int(p * seal_alpha * 0.7)))
        
        sam_rot = c_sam.rotate(t * 8.0, resample=Image.Resampling.BICUBIC)
        sx = (WIDTH - seal_sz) // 2
        sy = (HEIGHT - seal_sz) // 2 - 70
        frame.paste(sam_rot, (sx, sy), sam_rot)

        # Title Card Typography (Baked directly into video for supreme crispness)
        title_alpha = smoothstep(0.6, 2.0, t - 15.0) * (1.0 - smoothstep(4.2, 5.0, t - 15.0))
        if title_alpha > 0.01:
            overlay_txt = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
            d_txt = ImageDraw.Draw(overlay_txt)

            # English Title "SPIRITBOUND"
            en_text = "SPIRITBOUND"
            en_bbox = font_title_en.getbbox(en_text)
            en_w = en_bbox[2] - en_bbox[0]
            en_x = (WIDTH - en_w) // 2
            en_y = int(HEIGHT * 0.44)
            # Gold shadow & glow
            d_txt.text((en_x + 2, en_y + 3), en_text, font=font_title_en, fill=(20, 10, 4, int(180 * title_alpha)))
            d_txt.text((en_x, en_y), en_text, font=font_title_en, fill=(232, 192, 118, int(255 * title_alpha)))

            # Chinese Title "灵界之契"
            zh_text = "灵 界 之 契"
            zh_bbox = font_title_zh.getbbox(zh_text)
            zh_w = zh_bbox[2] - zh_bbox[0]
            zh_x = (WIDTH - zh_w) // 2
            zh_y = en_y + 80
            d_txt.text((zh_x + 2, zh_y + 2), zh_text, font=font_title_zh, fill=(10, 20, 25, int(180 * title_alpha)))
            d_txt.text((zh_x, zh_y), zh_text, font=font_title_zh, fill=(245, 245, 240, int(255 * title_alpha)))

            # Subtitle "踏破轮回 · 重铸仙途"
            sub_text = "✦  踏 破 轮 回  ·  重 铸 仙 途  ✦"
            sub_bbox = font_sub.getbbox(sub_text)
            sub_w = sub_bbox[2] - sub_bbox[0]
            sub_x = (WIDTH - sub_w) // 2
            sub_y = zh_y + 68
            d_txt.text((sub_x, sub_y), sub_text, font=font_sub, fill=(131, 228, 193, int(230 * title_alpha)))

            frame = Image.alpha_composite(frame, overlay_txt)

    # Ambient Floating Celestial Spirit Particles across all acts
    overlay_p = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    d_p = ImageDraw.Draw(overlay_p)
    for p in particles:
        py = int(p["seed_y"] - t * 45 * p["speed"]) % HEIGHT
        px = int(p["seed_x"] + math.sin(t * 1.5 + p["phase"]) * 35) % WIDTH
        sz = p["size"]
        glow_col = (131, 228, 193, int(160 + math.sin(t * 3.0 + p["phase"]) * 70))
        d_p.ellipse((px - sz, py - sz, px + sz, py + sz), fill=glow_col)
    frame = Image.alpha_composite(frame, overlay_p)

    # Master Fade In (first 0.8s) and Fade Out (last 1.0s)
    fade_alpha = 1.0
    if t < 0.8:
        fade_alpha = smoothstep(0.0, 0.8, t)
    elif t > 19.0:
        fade_alpha = 1.0 - smoothstep(19.0, 20.0, t)

    if fade_alpha < 0.999:
        black = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, int(255 * (1.0 - fade_alpha))))
        frame = Image.alpha_composite(frame, black)

    return frame.convert("RGB")

print(f"--- Generating {TOTAL_FRAMES} frames and encoding to {TEMP_MP4} via FFmpeg ---")
ffmpeg_cmd = [
    "ffmpeg", "-y",
    "-f", "rawvideo",
    "-vcodec", "rawvideo",
    "-s", f"{WIDTH}x{HEIGHT}",
    "-pix_fmt", "rgb24",
    "-r", str(FPS),
    "-i", "-", # stdin
    "-i", AUDIO_PATH, # audio source
    "-c:v", "libx264",
    "-preset", "fast",
    "-crf", "18",
    "-c:a", "aac",
    "-b:a", "192k",
    "-t", "20.0",
    "-pix_fmt", "yuv420p",
    TEMP_MP4
]

proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE)

for f in range(TOTAL_FRAMES):
    img = render_frame(f)
    proc.stdin.write(img.tobytes())
    if f % 60 == 0:
        print(f"Rendered {f}/{TOTAL_FRAMES} frames ({f/FPS:.1f}s / 20.0s)...")

proc.stdin.close()
proc.wait()

if proc.returncode != 0:
    print(f"FFmpeg MP4 rendering failed with exit code {proc.returncode}")
    sys.exit(1)

print(f"Successfully generated intermediate MP4: {TEMP_MP4} ({os.path.getsize(TEMP_MP4)/1024/1024:.2f} MB)")

# Now convert MP4 to Ogg Theora (.ogv) via ffmpeg2theora
print(f"--- Converting {TEMP_MP4} to {OUTPUT_OGV} via ffmpeg2theora ---")
conv_cmd = [
    "ffmpeg2theora",
    "--videoquality", "7",
    "--audioquality", "5",
    "-o", OUTPUT_OGV,
    TEMP_MP4
]

res = subprocess.run(conv_cmd)
if res.returncode != 0:
    print(f"ffmpeg2theora failed with code {res.returncode}")
    sys.exit(1)

ogv_size_mb = os.path.getsize(OUTPUT_OGV) / 1024.0 / 1024.0
print(f"Successfully produced Godot native Theora video: {OUTPUT_OGV} ({ogv_size_mb:.2f} MB)")
