#!/usr/bin/env python3
import os, json, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

cards_dir = "/Users/congxu/Documents/Spiritbound/Godot/assets/cards"
core_path = "/Users/congxu/Documents/Spiritbound/Godot/data/core.json"

with open(core_path, "r", encoding="utf-8") as f:
    core = json.load(f)

# Masterworks that MUST NOT be touched
masterworks = {
    "caustic_splash", "corrosive_acid", "venom_fang", "soul_barrier", "obsidian_plating",
    "boulder_hurl", "decay_wave", "thunderclap", "glacial_barrier", "permafrost",
    "tempest_slash", "cinder_slash", "earth_rebound", "flame_dance", "blaze_tempest",
    "toxic_quake", "frost_surge", "soul_pyre", "gale_barrier", "miasma_shield",
    # Original core cards with established custom art
    "calmWard", "cinderHex", "decay_blight", "emberClaw", "emberVow", "embercoal",
    "finalFlare", "foxBlessing", "ironHide", "ironWill", "mendingWard", "miasmaBrew",
    "mirrorWard", "moltenCore", "mountainSeal", "phoenixEdge", "piercingBolt",
    "renewal", "shatterGuard", "soulBrand", "spiritLance", "spiritNova", "steadyPulse",
    "stoneBreaker", "stormArc", "stormcaller", "titanForm", "toxinDart", "twinMoon",
    "void_curse", "wardBreaker", "wildSpark", "witherTouch", "worldFlame",
    "focus", "foxfire", "spiritCurrent", "strike", "ward", "ashRecall"
}

PALETTES = {
    "fire": {
        "deep": (10, 4, 6),
        "mid": (48, 14, 10),
        "bright": (120, 32, 12),
        "glow": (255, 110, 20),
        "core": (255, 245, 190),
        "spark": (255, 190, 60),
        "accent": (255, 60, 40)
    },
    "water": {
        "deep": (4, 10, 18),
        "mid": (12, 30, 54),
        "bright": (24, 72, 120),
        "glow": (40, 180, 245),
        "core": (220, 250, 255),
        "spark": (140, 230, 255),
        "accent": (80, 220, 255)
    },
    "thunder": {
        "deep": (10, 8, 22),
        "mid": (26, 20, 60),
        "bright": (60, 44, 135),
        "glow": (125, 165, 255),
        "core": (250, 252, 255),
        "spark": (190, 225, 255),
        "accent": (210, 150, 255)
    },
    "stone": {
        "deep": (14, 12, 10),
        "mid": (42, 30, 20),
        "bright": (85, 62, 38),
        "glow": (220, 150, 55),
        "core": (255, 235, 185),
        "spark": (230, 180, 95),
        "accent": (255, 195, 110)
    },
    "gale": {
        "deep": (6, 16, 14),
        "mid": (16, 44, 38),
        "bright": (30, 95, 78),
        "glow": (55, 225, 165),
        "core": (225, 255, 245),
        "spark": (145, 250, 210),
        "accent": (90, 240, 190)
    },
    "poison": {
        "deep": (14, 8, 20),
        "mid": (36, 16, 50),
        "bright": (70, 26, 90),
        "glow": (95, 230, 65),
        "core": (235, 255, 185),
        "spark": (160, 245, 110),
        "accent": (140, 255, 80)
    },
    "spirit": {
        "deep": (8, 14, 26),
        "mid": (22, 38, 70),
        "bright": (45, 82, 140),
        "glow": (75, 195, 240),
        "core": (245, 252, 255),
        "spark": (170, 235, 255),
        "accent": (120, 220, 255)
    },
    "void": {
        "deep": (8, 6, 16),
        "mid": (24, 12, 42),
        "bright": (65, 24, 105),
        "glow": (175, 85, 245),
        "core": (245, 225, 255),
        "spark": (210, 150, 255),
        "accent": (255, 110, 210)
    }
}

def render_deluxe_fantasy_card(card_id, element, kind):
    random.seed(card_id)
    W, H = 512, 512
    pal = PALETTES.get(element, PALETTES["spirit"])
    
    # Layer 1: Atmospheric Depth Gradient
    base = Image.new("RGBA", (W, H), pal["deep"] + (255,))
    grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grad)
    cx, cy = W // 2, int(H * 0.46)
    
    # Volumetric cloud puffs for painting texture
    for _ in range(35):
        px = cx + random.randint(-200, 200)
        py = cy + random.randint(-180, 180)
        pr = random.randint(80, 220)
        c = random.choice([pal["mid"], pal["bright"], pal["deep"]])
        a = random.randint(50, 110)
        g_draw.ellipse([px - pr, py - pr, px + pr, py + pr], fill=c + (a,))
    grad = grad.filter(ImageFilter.GaussianBlur(radius=40))
    base = Image.alpha_composite(base, grad)
    
    # Layer 2: Deep Ambient Glow
    bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bloom)
    for rad, alpha in [(240, 20), (180, 45), (120, 75), (80, 125), (45, 190)]:
        b_draw.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=pal["glow"] + (alpha,))
    bloom = bloom.filter(ImageFilter.GaussianBlur(radius=30))
    base = Image.alpha_composite(base, bloom)
    
    # Layer 3: Dynamic Painterly Subject
    subj = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(subj)
    
    is_attack = "strike" in card_id or "slash" in card_id or "blade" in card_id or "cleave" in card_id or "lance" in card_id or kind == "Attack"
    is_barrier = "barrier" in card_id or "shield" in card_id or "ward" in card_id or "veil" in card_id or "armor" in card_id or "wall" in card_id or kind == "Skill"
    
    if element == "thunder":
        # Multi-tiered branched lightning trees
        def bolt(x1, y1, x2, y2, d=0, w=4):
            if d > 4 or math.hypot(x2-x1, y2-y1) < 14:
                s_draw.line([(x1, y1), (x2, y2)], fill=pal["core"] + (255,), width=w)
                return
            mx = (x1 + x2) / 2 + random.randint(-38, 38) / (d + 1)
            my = (y1 + y2) / 2 + random.randint(-38, 38) / (d + 1)
            bolt(x1, y1, mx, my, d+1, w)
            bolt(mx, my, x2, y2, d+1, w)
            if random.random() < 0.5:
                bx = mx + random.randint(-50, 50)
                by = my + random.randint(25, 75)
                bolt(mx, my, bx, by, d+2, max(1, w-1))
                
        for _ in range(7):
            ang = random.uniform(0, 2 * math.pi)
            dist = random.randint(140, 230)
            bolt(cx, cy, cx + int(math.cos(ang)*dist), cy + int(math.sin(ang)*dist), w=random.randint(2, 4))
            
    elif is_attack:
        # Sweeping dynamic weapon slash trails with energy crests
        slash_angle = random.uniform(-0.6, 0.6) - 0.78 # diagonal slash
        for strand in range(5):
            offset_y = (strand - 2) * 16
            pts = []
            for t in range(25):
                progress = (t / 24.0) - 0.5 # -0.5 to 0.5
                x = cx + progress * 340
                curve = math.sin((progress + 0.5) * math.pi) * 60
                y = cy + progress * 260 * math.tan(slash_angle) + curve + offset_y
                pts.append((x, y))
            for i in range(len(pts) - 1):
                prog = i / float(len(pts))
                w = max(1, int(18 * math.sin(prog * math.pi)))
                col = pal["core"] if strand == 2 and 0.3 < prog < 0.7 else pal["glow"]
                alpha = int(240 * math.sin(prog * math.pi))
                s_draw.line([pts[i], pts[i+1]], fill=col + (alpha,), width=w)
                
    elif is_barrier:
        # Luminous magical protective crest / layered runic mandala
        petals = 8
        for p in range(petals):
            a1 = p * (2 * math.pi / petals)
            a2 = a1 + (math.pi / petals)
            r_outer = 150 + random.randint(-10, 10)
            r_mid = 85
            poly = [
                (cx, cy),
                (cx + int(math.cos(a1) * r_mid), cy + int(math.sin(a1) * r_mid)),
                (cx + int(math.cos(a2) * r_outer), cy + int(math.sin(a2) * r_outer)),
                (cx + int(math.cos(a1 + 2*math.pi/petals) * r_mid), cy + int(math.sin(a1 + 2*math.pi/petals) * r_mid)),
            ]
            s_draw.polygon(poly, fill=pal["bright"] + (110,))
            s_draw.line(poly + [poly[0]], fill=pal["glow"] + (200,), width=2)
            
    else:
        # Swirling elemental vortex / flame ribbon whirlpool
        ribbons = 6
        for r_idx in range(ribbons):
            base_rot = r_idx * (2 * math.pi / ribbons)
            pts = []
            for step in range(22):
                a = base_rot + step * 0.28
                r = 18 + step * 9.5
                pts.append((cx + int(math.cos(a) * r), cy + int(math.sin(a) * r)))
            for i in range(len(pts) - 1):
                ratio = 1.0 - i / float(len(pts))
                w = max(1, int(14 * ratio))
                col = pal["core"] if i < 4 else (pal["glow"] if i < 14 else pal["bright"])
                s_draw.line([pts[i], pts[i+1]], fill=col + (int(220 * ratio),), width=w)

    subj = subj.filter(ImageFilter.GaussianBlur(radius=1.2))
    base = Image.alpha_composite(base, subj)

    # Layer 4: Hot White-Hot Incandescent Center Core
    core_glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cg_draw = ImageDraw.Draw(core_glow)
    cg_draw.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=pal["core"] + (255,))
    core_glow = core_glow.filter(ImageFilter.GaussianBlur(radius=8))
    base = Image.alpha_composite(base, core_glow)

    # Layer 5: Floating Bokeh & Spark Field
    sparks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sp_draw = ImageDraw.Draw(sparks)
    # Background fine embers
    for _ in range(120):
        ang = random.uniform(0, 2 * math.pi)
        dist = random.uniform(15, 230)
        sx = cx + int(math.cos(ang) * dist)
        sy = cy + int(math.sin(ang) * dist)
        if 0 <= sx < W and 0 <= sy < H:
            s_rad = random.randint(1, 2)
            s_col = pal["spark"] if random.random() < 0.65 else pal["core"]
            s_a = random.randint(140, 255)
            sp_draw.ellipse([sx - s_rad, sy - s_rad, sx + s_rad, sy + s_rad], fill=s_col + (s_a,))
            
    # Foreground soft bokeh orbs
    for _ in range(8):
        bx = random.randint(40, W - 40)
        by = random.randint(40, H - 40)
        br = random.randint(14, 28)
        sp_draw.ellipse([bx - br, by - br, bx + br, by + br], fill=pal["glow"] + (35,))
    sparks = sparks.filter(ImageFilter.GaussianBlur(radius=0.6))
    base = Image.alpha_composite(base, sparks)

    # Layer 6: Filmic Vignette & Atmosphere Frame
    vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    v_draw = ImageDraw.Draw(vig)
    for step in range(55):
        alpha = int(200 * (step / 55.0)**1.9)
        v_draw.rectangle([step, step, W - step, H - step], outline=(4, 4, 8, alpha), width=3)
    base = Image.alpha_composite(base, vig)

    return base.convert("RGB")

upgraded = 0
for card in core["cards"]:
    cid = card["id"]
    if cid in masterworks:
        continue
    out_path = os.path.join(cards_dir, f"{cid}.png")
    elem = card.get("element", "spirit")
    kind = card.get("kind", "Attack")
    art = render_deluxe_fantasy_card(cid, elem, kind)
    art.save(out_path, "PNG", optimize=True)
    upgraded += 1

print(f"✓ Rendered deluxe painterly art for {upgraded} cards!")
