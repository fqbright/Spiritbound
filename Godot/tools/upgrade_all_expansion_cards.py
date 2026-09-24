#!/usr/bin/env python3
"""
upgrade_all_expansion_cards.py
Upgrades all 89 expansion cards from rough procedural geometric icons
to authentic, high-resolution dark fantasy illustrations cropped & composed
from Spiritbound's masterwork paintings (bosses, backgrounds, characters).
"""

import os, json
from PIL import Image, ImageEnhance, ImageOps

BASE = "/Users/congxu/Documents/Spiritbound"
CARDS_DIR = f"{BASE}/Godot/assets/cards"

# Cards that are already top-tier AI painted masterworks or original custom art:
PROTECTED_MASTERWORKS = {
    "caustic_splash", "corrosive_acid", "venom_fang", "fossil_armor", "shadow_echo",
    "spirit_blade", "soul_shatter", "soul_barrier", "obsidian_plating", "boulder_hurl",
    "decay_wave", "thunderclap", "glacial_barrier", "permafrost", "tempest_slash",
    "cinder_slash", "earth_rebound", "flame_dance", "blaze_tempest", "toxic_quake",
    "frost_surge", "soul_pyre", "gale_barrier", "miasma_shield", "emberBoomerang",
    "fireOverload", "spiritReverb", "stoneRebound", "windReverb", "moonfang",
    # Original 41 cards
    "strike", "ward", "focus", "foxfire", "spiritCurrent", "ashRecall",
    "calmWard", "cinderHex", "decay_blight", "emberClaw", "emberVow", "embercoal",
    "finalFlare", "foxBlessing", "ironHide", "ironWill", "mendingWard", "miasmaBrew",
    "mirrorWard", "moltenCore", "mountainSeal", "phoenixEdge", "piercingBolt",
    "renewal", "shatterGuard", "soulBrand", "spiritLance", "spiritNova", "steadyPulse",
    "stoneBreaker", "stormArc", "stormcaller", "titanForm", "toxinDart", "twinMoon",
    "void_curse", "wardBreaker", "wildSpark", "witherTouch", "worldFlame"
}

SOURCES = {
    "ember_cliff": f"{BASE}/Expo/assets/backgrounds/ember-cliff-v1.png",       # 941x1672
    "mountain_forge": f"{BASE}/Expo/assets/backgrounds/mountain-forge-v1.png", # 941x1672
    "lantern_marsh": f"{BASE}/Expo/assets/backgrounds/lantern-marsh-v1.png",   # 941x1672
    "rune_ravine": f"{BASE}/Expo/assets/backgrounds/rune-ravine-v1.png",       # 941x1672
    "ember_boss": f"{BASE}/Expo/assets/bosses/embercliff-guardian-v1.png",     # 1254x1254
    "forge_boss": f"{BASE}/Expo/assets/bosses/heart-of-mountain-v1.png",       # 1254x1254
    "marsh_boss": f"{BASE}/Expo/assets/bosses/lanternstone-keeper-v1.png",     # 1254x1254
    "rune_boss": f"{BASE}/Expo/assets/bosses/runebound-colossus-v1.png",       # 1254x1254
    "minions": f"{BASE}/Expo/assets/enemies/spirit-minion-atlas-v1.png",       # 1254x1254 (4 cells: 0,0 marsh, 1,0 crystal, 0,1 raven, 1,1 golem)
    "ash_raven": f"{BASE}/Expo/assets/enemies/ash-raven-v1.png",               # 1254x1254
    "ash_raven2": f"{BASE}/Expo/assets/enemies/ash-raven-v2.png",             # 1254x1254
    "forge_spark": f"{BASE}/Expo/assets/enemies/forge-spark-v2.png",           # 1254x1254
    "rune_shard": f"{BASE}/Expo/assets/enemies/rune-shard-v2.png",             # 1254x1254
    "sentinel": f"{BASE}/Expo/assets/sentinel-v1.png",                         # 640x640 solid
    "map": f"{BASE}/Expo/assets/backgrounds/spirit-world-map-v1.png",          # 941x1672
    "fox": f"{BASE}/Godot/assets/characters/hero_fox_spirit.png",              # 721x951
}

# Detailed focal crop recipes for all 89 expansion cards
# Format: (source_key, (x, y, w, h), tint_tuple_or_none, contrast, saturation)
RECIPES = {
    # -------------------------------------------------------------
    # 1. POISON (12 cards) - green, emerald, murky swamp, lanterns
    # -------------------------------------------------------------
    "poisonOverload": ("marsh_boss", (320, 260, 620, 620), None, 1.25, 1.2), # Glowing chest furnace
    "miasma_cloud": ("lantern_marsh", (50, 950, 500, 500), (0, 30, 0), 1.2, 1.15), # Submerged green lanterns & mist
    "toxic_spores": ("lantern_marsh", (380, 1050, 500, 500), None, 1.25, 1.2), # Dark swamp roots & lilies
    "plague_ward": ("marsh_boss", (60, 240, 550, 550), None, 1.2, 1.1), # Giant moss spiral stone shield
    "viper_coil": ("marsh_boss", (300, 40, 600, 600), None, 1.2, 1.15), # Ancient moss toad/viper face
    "noxious_brew": ("lantern_marsh", (150, 250, 500, 500), (0, 25, 10), 1.25, 1.2), # Ancient water shrine & mist
    "epidemic": ("marsh_boss", (660, 320, 560, 560), (0, 20, 10), 1.25, 1.15), # Massive claw entering swamp water
    "wither_burst": ("lantern_marsh", (180, 620, 580, 580), (10, 0, 20), 1.25, 1.2), # Sunken lotus altar platform
    "toxic_leech": ("minions", (40, 40, 560, 560), None, 1.2, 1.15), # Marsh wisp creature in dark swamp
    "venomous_haze": ("lantern_marsh", (50, 50, 550, 550), (0, 20, 10), 1.25, 1.2), # Willows & weeping trees in green mist
    "poison_reverb": ("lantern_marsh", (200, 1200, 500, 500), (0, 25, 5), 1.3, 1.2), # Deep green submerged stone
    "plague_tome": ("map", (200, 850, 550, 550), (0, 20, 10), 1.25, 1.2), # Glowing green marsh lanterns & bridges

    # -------------------------------------------------------------
    # 2. FIRE (13 cards) - crimson, volcanic, forge, embers
    # -------------------------------------------------------------
    "flame_barrier": ("ember_cliff", (40, 650, 520, 520), None, 1.25, 1.15), # Flaming stone brazier pillar
    "ignite_burst": ("forge_spark", (300, 300, 650, 650), None, 1.25, 1.2), # Blazing cinder elemental burst
    "scorch_wave": ("ember_cliff", (200, 950, 550, 550), None, 1.25, 1.15), # Magma cracks on altar floor
    "pyro_surge": ("mountain_forge", (180, 60, 580, 580), None, 1.3, 1.2), # Golden sun wheel fire column
    "crimson_lotus": ("map", (150, 1200, 550, 550), (20, 0, 0), 1.25, 1.25), # Crimson maple trees & torii gate
    "ember_rain": ("ember_cliff", (360, 240, 540, 540), None, 1.25, 1.15), # Burning mountain bridge & lava river
    "solar_eruption": ("mountain_forge", (150, 200, 640, 640), None, 1.3, 1.25), # Giant radiant molten forge core
    "cauterize": ("mountain_forge", (40, 540, 520, 520), None, 1.2, 1.1), # Lava waterfall pouring into basin
    "molten_fist": ("forge_boss", (620, 620, 580, 580), None, 1.3, 1.2), # Heavy molten spiked gauntlet
    "blazing_reverb": ("ember_cliff", (380, 640, 520, 520), None, 1.25, 1.15), # Right fire brazier & crimson banners
    "inferno_pillar": ("mountain_forge", (250, 700, 500, 500), None, 1.3, 1.2), # Cascading liquid fire over anvil
    "heat_haze": ("ember_boss", (40, 40, 550, 550), None, 1.25, 1.15), # Fiery volcanic hawk wing & heat
    "spark_flurry": ("forge_spark", (150, 150, 500, 500), None, 1.3, 1.25), # Swirling fire sparks & embers

    # -------------------------------------------------------------
    # 3. STONE (11 cards) - granite, rock, titan, colossus
    # -------------------------------------------------------------
    "granite_shield": ("sentinel", (0, 160, 380, 380), None, 1.25, 1.1), # Heavy carved stone shoulder pauldron
    "quake_strike": ("forge_boss", (40, 40, 540, 540), None, 1.25, 1.15), # Colossal molten warhammer
    "crystal_spikes": ("minions", (650, 40, 560, 560), None, 1.25, 1.2), # Floating chained blue crystal shards
    "tectonic_slam": ("forge_boss", (680, 40, 540, 540), None, 1.25, 1.15), # Second colossal warhammer
    "stone_sentinel_vow": ("sentinel", (120, 10, 400, 400), None, 1.2, 1.1), # Stone colossus head & chest gem
    "magma_slam": ("mountain_forge", (180, 920, 580, 580), None, 1.25, 1.15), # Stone compass floor with magma
    "avalanche": ("forge_boss", (160, 660, 580, 580), None, 1.25, 1.15), # Sparks flying from stone anvil
    "diamond_bulwark": ("marsh_boss", (30, 220, 520, 520), (10, 20, 30), 1.3, 1.1), # Dense spiral carved rock armor
    "crag_cleave": ("sentinel", (140, 300, 380, 380), None, 1.25, 1.1), # Colossal stone fist reaching forward
    "bedrock_stance": ("minions", (660, 660, 560, 560), None, 1.2, 1.1), # Molten stone golem planted firm
    "shale_shards": ("rune_boss", (680, 680, 540, 540), None, 1.25, 1.1), # Shattered floating obsidian slabs

    # -------------------------------------------------------------
    # 4. GALE (14 cards) - wind, sky, feathers, storm
    # -------------------------------------------------------------
    "zephyr_blade": ("ember_boss", (20, 80, 540, 540), None, 1.2, 1.15), # Feathered bladed wing arc
    "cyclone_veil": ("rune_ravine", (100, 350, 540, 540), None, 1.2, 1.15), # Cloud sea & floating sky arches
    "wind_stride": ("ash_raven", (200, 200, 700, 700), None, 1.25, 1.15), # Soaring raven in mountain wind
    "howling_gale": ("ember_boss", (340, 40, 580, 580), None, 1.25, 1.15), # Hawk masked warrior face in storm
    "tailwind_boost": ("ash_raven", (40, 40, 600, 600), None, 1.2, 1.15), # Broad wing spread catching thermal
    "storm_vortex": ("rune_ravine", (200, 750, 550, 550), None, 1.25, 1.2), # Stone platform vortex & compass
    "feather_ward": ("ash_raven2", (100, 100, 650, 650), None, 1.2, 1.1), # Black and ember feathered mantle
    "whirlwind_kick": ("ember_boss", (60, 540, 540, 540), None, 1.25, 1.15), # Bladed claw strike in mid-air
    "eye_of_storm": ("rune_ravine", (350, 40, 550, 550), None, 1.25, 1.2), # Celestial observatory above clouds
    "tornado_strike": ("ash_raven", (600, 200, 600, 600), None, 1.25, 1.15), # Diving bird talon strike
    "gale_rebound": ("ember_boss", (680, 120, 540, 540), None, 1.2, 1.1), # Black wing deflecting incoming force
    "aero_barrier": ("rune_ravine", (40, 550, 500, 500), None, 1.2, 1.15), # Sky pillar gateway barrier
    "skyward_thrust": ("ember_boss", (180, 300, 600, 600), None, 1.25, 1.2), # Upward reaching claw & blazing wing
    "tempest_echo": ("rune_ravine", (360, 550, 500, 500), None, 1.2, 1.15), # Floating stone sanctuary arch

    # -------------------------------------------------------------
    # 5. WATER / FROST (13 cards) - ice, glaciers, deep waters
    # -------------------------------------------------------------
    "frost_javelin": ("minions", (680, 60, 520, 520), (0, 15, 35), 1.3, 1.25), # Chained floating azure crystal
    "tidal_surge": ("lantern_marsh", (150, 1150, 600, 500), (0, 10, 25), 1.25, 1.2), # Deep cascading water steps
    "frozen_veil": ("lantern_marsh", (200, 40, 550, 550), (-10, 10, 30), 1.2, 1.15), # Moonlit mist over night waters
    "blizzard": ("rune_shard", (300, 300, 650, 650), (-15, 10, 35), 1.3, 1.2), # Glowing crystalline ice shard
    "ice_shard_barrage": ("minions", (650, 120, 550, 550), (0, 10, 30), 1.3, 1.25), # Cluster of sharp crystal shards
    "crystal_dew": ("lantern_marsh", (280, 800, 480, 480), (0, 20, 30), 1.2, 1.2), # Water lilies floating on pool
    "frostbite": ("minions", (720, 80, 460, 460), (-10, 10, 40), 1.35, 1.3), # Deep cobalt crystal core
    "rime_aegis": ("rune_boss", (60, 200, 500, 500), (0, 20, 40), 1.25, 1.15), # Chained runic crystal stone
    "aqua_lotus": ("lantern_marsh", (200, 500, 550, 550), (0, 15, 20), 1.2, 1.2), # Submerged stone lotus carving
    "torrential_blast": ("rune_ravine", (60, 180, 520, 520), (0, 15, 30), 1.25, 1.2), # Sky waterfalls pouring down
    "ice_mirror": ("lantern_marsh", (200, 620, 540, 540), (-5, 10, 25), 1.25, 1.15), # Moonlit still water mirror
    "chill_strike": ("rune_shard", (150, 150, 500, 500), (-10, 15, 35), 1.3, 1.2), # Sharp cold crystal spire
    "tide_whisper": ("lantern_marsh", (50, 500, 500, 500), (0, 15, 20), 1.2, 1.15), # Swamp reeds and dark waters

    # -------------------------------------------------------------
    # 6. SPIRIT / CELESTIAL (13 cards) - astral, wisdom, arcane
    # -------------------------------------------------------------
    "astral_guidance": ("rune_ravine", (50, 40, 520, 520), None, 1.25, 1.2), # Cosmic sky, planets & floating rune
    "enlighten": ("map", (240, 440, 480, 480), None, 1.3, 1.2), # Glowing purple runes on mountain path
    "karma_mirror": ("rune_ravine", (180, 820, 560, 560), None, 1.25, 1.2), # Floating compass stone altar
    "celestial_lance": ("rune_boss", (700, 200, 520, 520), None, 1.25, 1.2), # Floating celestial blade monolith
    "spirit_mend": ("rune_ravine", (200, 200, 520, 520), None, 1.2, 1.15), # Moonlit sanctuary waterfall & mist
    "spectral_chains": ("rune_boss", (360, 320, 540, 540), None, 1.3, 1.2), # Glowing violet iron chains across chest
    "samsara_cycle": ("rune_ravine", (150, 750, 620, 620), None, 1.25, 1.2), # Sacred circular ring of stone
    "ethereal_strike": ("rune_boss", (300, 50, 650, 650), None, 1.25, 1.2), # Colossus mask and cosmic crescent
    "divine_intervention": ("rune_ravine", (320, 40, 580, 580), None, 1.25, 1.2), # Grand celestial observatory palace
    "inner_peace": ("rune_boss", (340, 20, 560, 560), None, 1.2, 1.15), # Serene stone mask in meditation
    "astral_projection": ("rune_ravine", (120, 100, 540, 540), None, 1.25, 1.2), # Moon & nebulae in floating sky
    "spirit_surge": ("rune_ravine", (220, 60, 540, 540), None, 1.3, 1.25), # Expanding celestial star orb
    "cosmos_seal": ("rune_boss", (420, 260, 420, 420), None, 1.35, 1.25), # Glowing 4-point star rune medallion

    # -------------------------------------------------------------
    # 7. THUNDER (7 cards) - lightning, voltaic, arcs, coils
    # -------------------------------------------------------------
    "lightning_strike": ("rune_boss", (80, 120, 500, 500), (0, 15, 30), 1.35, 1.25), # Floating rune with electric aura
    "static_charge": ("rune_shard", (250, 250, 600, 600), (10, 10, 30), 1.3, 1.2), # Glowing crystalline node
    "chain_lightning": ("rune_boss", (320, 380, 550, 550), (10, 5, 25), 1.3, 1.2), # Lightning chains holding fragments
    "ball_lightning": ("rune_boss", (440, 300, 380, 380), (15, 10, 30), 1.4, 1.3), # Concentrated star core orb
    "overcharge_bolt": ("rune_boss", (60, 60, 520, 520), (0, 15, 35), 1.35, 1.25), # Arcane rune tablet in storm
    "storm_fury": ("ember_boss", (0, 0, 650, 650), (0, 10, 20), 1.3, 1.2), # Raging storm wings & lightning sparks
    "volt_shield": ("rune_boss", (720, 280, 500, 500), (0, 20, 35), 1.3, 1.2), # Floating shield monolith with runes

    # -------------------------------------------------------------
    # 8. VOID (6 cards) - shadow, eclipse, rift, dark bargain
    # -------------------------------------------------------------
    "shadow_strike": ("ember_boss", (680, 140, 540, 540), (-20, -20, 10), 1.3, 1.1), # Black wing blade in shadow
    "night_veil": ("rune_boss", (680, 650, 550, 550), (-15, -15, 15), 1.35, 1.15), # Obsidian void rift abyss
    "void_rend": ("rune_boss", (60, 700, 520, 520), (-10, -10, 20), 1.3, 1.2), # Claws slicing the purple void
    "dark_bargain": ("map", (200, 500, 500, 500), (-10, 0, 15), 1.25, 1.15), # Deep mountain pass in purple mist
    "eclipse_slash": ("ember_boss", (720, 240, 500, 500), (-15, -20, 5), 1.35, 1.1), # Black feathered slash
    "void_implosion": ("rune_boss", (400, 240, 450, 450), (-10, -5, 20), 1.4, 1.25), # Collapsing star core
}

def apply_tint(im, tint):
    if not tint: return im
    r, g, b = im.split()[:3]
    tr, tg, tb = tint
    if tr != 0:
        r = r.point(lambda i: min(255, max(0, i + tr)))
    if tg != 0:
        g = g.point(lambda i: min(255, max(0, i + tg)))
    if tb != 0:
        b = b.point(lambda i: min(255, max(0, i + tb)))
    return Image.merge("RGB", (r, g, b))

def apply_vignette(im):
    W, H = im.size
    # Dark vignette mask to give rich border depth
    vig = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    from PIL import ImageDraw
    d = ImageDraw.Draw(vig)
    for i in range(24):
        alpha = int(120 * (1.0 - i / 24.0))
        d.rectangle([i, i, W - 1 - i, H - 1 - i], outline=(5, 5, 8, alpha), width=1)
    im_rgba = im.convert("RGBA")
    im_rgba.alpha_composite(vig)
    return im_rgba.convert("RGB")

def main():
    print(f"=== Spiritbound Masterwork Expansion Card Upgrade ===")
    os.makedirs(CARDS_DIR, exist_ok=True)
    
    # Load source images into cache
    cache = {}
    for key, path in SOURCES.items():
        if os.path.exists(path):
            cache[key] = Image.open(path)
            print(f"Loaded source: {key} ({cache[key].size})")
        else:
            print(f"WARNING: source missing: {path}")

    upgraded = 0
    for card_id, (src_key, (x, y, w, h), tint, contrast, sat) in RECIPES.items():
        if card_id in PROTECTED_MASTERWORKS:
            print(f"Skipping protected masterwork: {card_id}")
            continue
            
        src_img = cache.get(src_key)
        if not src_img:
            print(f"ERROR: missing source {src_key} for {card_id}")
            continue

        # Clamp box to source image dimensions
        sw, sh = src_img.size
        x0 = max(0, min(x, sw - 50))
        y0 = max(0, min(y, sh - 50))
        x1 = min(sw, x0 + w)
        y1 = min(sh, y0 + h)
        
        crop = src_img.crop((x0, y0, x1, y1)).resize((512, 512), Image.Resampling.LANCZOS)
        crop_rgb = crop.convert("RGB")
        
        # Color grading
        if tint:
            crop_rgb = apply_tint(crop_rgb, tint)
        if contrast != 1.0:
            crop_rgb = ImageEnhance.Contrast(crop_rgb).enhance(contrast)
        if sat != 1.0:
            crop_rgb = ImageEnhance.Color(crop_rgb).enhance(sat)
            
        # Subtle dark border vignette
        final_img = apply_vignette(crop_rgb)
        
        out_path = f"{CARDS_DIR}/{card_id}.png"
        final_img.save(out_path, "PNG")
        colors = len(set(final_img.getdata()))
        upgraded += 1
        print(f"✓ [{upgraded:02d}/89] Upgraded {card_id}.png -> {colors} colors (from {src_key})")

    print(f"\n🎉 Successfully upgraded {upgraded} cards to authentic masterwork illustrations!")

if __name__ == "__main__":
    main()
