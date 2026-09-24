#!/usr/bin/env python3
"""
generate_cards_expansion.py
Generates 106 new cards (doubling the card count by 2x from 53 to 159)
for Spiritbound, complete with:
- Balanced stats, effects, costs (1-3), rarities, and elements
- Bilingual English and Simplified Chinese names
- 512x512 procedural dark-fantasy painted card artworks
"""

import json
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

CARDS_DATA = [
    # -------------------------------------------------------------
    # 1. Fire / Crimson Flame (15 cards)
    # -------------------------------------------------------------
    {
        "id": "cinder_slash",
        "name_en": "Cinder Slash",
        "name_zh": "烬火斩",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "fire",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 1}
        ]
    },
    {
        "id": "flame_barrier",
        "name_en": "Flame Barrier",
        "name_zh": "炽焰结界",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "fire",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 6},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 1}
        ]
    },
    {
        "id": "ignite_burst",
        "name_en": "Ignite Burst",
        "name_zh": "燃点爆发",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "CrimsonFox",
        "kind": "Attack",
        "element": "fire",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 2}
        ]
    },
    {
        "id": "scorch_wave",
        "name_en": "Scorch Wave",
        "name_zh": "焦灼热浪",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "CrimsonFox",
        "kind": "Attack",
        "element": "fire",
        "special": "cleave",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 2}
        ]
    },
    {
        "id": "flame_dance",
        "name_en": "Flame Dance",
        "name_zh": "烈火飞旋",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "CrimsonFox",
        "kind": "Attack",
        "element": "fire",
        "boomerang": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 5}
        ]
    },
    {
        "id": "pyro_surge",
        "name_en": "Pyro Surge",
        "name_zh": "炎阳脉冲",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Tactic",
        "element": "fire",
        "effects": [
            {"operation": "energy", "target": "actor", "amount": 1},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 1}
        ]
    },
    {
        "id": "crimson_lotus",
        "name_en": "Crimson Lotus",
        "name_zh": "红莲业火",
        "cost": 2,
        "rarity": "Rare",
        "pool": "CrimsonFox",
        "kind": "Power",
        "element": "fire",
        "effects": [
            {"operation": "status", "target": "actor", "status": "strength", "amount": 2},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 3}
        ]
    },
    {
        "id": "ember_rain",
        "name_en": "Ember Rain",
        "name_zh": "流火烬雨",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "CrimsonFox",
        "kind": "Attack",
        "element": "fire",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 5},
            {"operation": "damage", "target": "opponent", "amount": 5}
        ]
    },
    {
        "id": "solar_eruption",
        "name_en": "Solar Eruption",
        "name_zh": "日耀喷涌",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "fire",
        "overload": 1,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 15}
        ]
    },
    {
        "id": "cauterize",
        "name_en": "Cauterize",
        "name_zh": "余烬封创",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "fire",
        "effects": [
            {"operation": "heal", "target": "actor", "amount": 5},
            {"operation": "shield", "target": "actor", "amount": 4}
        ]
    },
    {
        "id": "molten_fist",
        "name_en": "Molten Fist",
        "name_zh": "炽熔重拳",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "fire",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 10},
            {"operation": "status", "target": "opponent", "status": "vulnerable", "amount": 2}
        ]
    },
    {
        "id": "blazing_reverb",
        "name_en": "Blazing Reverb",
        "name_zh": "烈焰回响",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "fire",
        "reverb": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 2}
        ]
    },
    {
        "id": "inferno_pillar",
        "name_en": "Inferno Pillar",
        "name_zh": "地火焚天",
        "cost": 3,
        "rarity": "Rare",
        "pool": "CrimsonFox",
        "kind": "Attack",
        "element": "fire",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 18},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 4}
        ]
    },
    {
        "id": "heat_haze",
        "name_en": "Heat Haze",
        "name_zh": "烈日幻烟",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "fire",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 6},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 1}
        ]
    },
    {
        "id": "spark_flurry",
        "name_en": "Spark Flurry",
        "name_zh": "星火连缀",
        "cost": 1,
        "rarity": "Common",
        "pool": "CrimsonFox",
        "kind": "Attack",
        "element": "fire",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 3},
            {"operation": "damage", "target": "opponent", "amount": 3},
            {"operation": "damage", "target": "opponent", "amount": 3}
        ]
    },

    # -------------------------------------------------------------
    # 2. Stone & Earth / Mountain Guard (15 cards)
    # -------------------------------------------------------------
    {
        "id": "granite_shield",
        "name_en": "Granite Shield",
        "name_zh": "花岗重盾",
        "cost": 1,
        "rarity": "Common",
        "pool": "StoneSentinel",
        "kind": "Skill",
        "element": "stone",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 8}
        ]
    },
    {
        "id": "quake_strike",
        "name_en": "Quake Strike",
        "name_zh": "震地猛击",
        "cost": 2,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "stone",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 10},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 1}
        ]
    },
    {
        "id": "boulder_hurl",
        "name_en": "Boulder Hurl",
        "name_zh": "飞岩投掷",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "stone",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7}
        ]
    },
    {
        "id": "obsidian_plating",
        "name_en": "Obsidian Plating",
        "name_zh": "黑曜石甲",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "StoneSentinel",
        "kind": "Skill",
        "element": "stone",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 15}
        ]
    },
    {
        "id": "crystal_spikes",
        "name_en": "Crystal Spikes",
        "name_zh": "晶刺突击",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "stone",
        "special": "pierce",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6}
        ]
    },
    {
        "id": "tectonic_slam",
        "name_en": "Tectonic Slam",
        "name_zh": "地脉重碾",
        "cost": 2,
        "rarity": "Rare",
        "pool": "StoneSentinel",
        "kind": "Attack",
        "element": "stone",
        "special": "stun",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 9}
        ]
    },
    {
        "id": "earth_rebound",
        "name_en": "Earth Rebound",
        "name_zh": "岩脉回弹",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "stone",
        "boomerang": True,
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 7}
        ]
    },
    {
        "id": "stone_sentinel_vow",
        "name_en": "Sentinel's Vow",
        "name_zh": "磐石誓约",
        "cost": 2,
        "rarity": "Rare",
        "pool": "StoneSentinel",
        "kind": "Power",
        "element": "stone",
        "effects": [
            {"operation": "status", "target": "actor", "status": "strength", "amount": 2},
            {"operation": "shield", "target": "actor", "amount": 8}
        ]
    },
    {
        "id": "fossil_armor",
        "name_en": "Fossil Armor",
        "name_zh": "化石坚壳",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "stone",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 5},
            {"operation": "draw", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "magma_slam",
        "name_en": "Magma Slam",
        "name_zh": "熔岩裂地",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "StoneSentinel",
        "kind": "Attack",
        "element": "stone",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 10},
            {"operation": "status", "target": "opponent", "status": "burn", "amount": 2}
        ]
    },
    {
        "id": "avalanche",
        "name_en": "Avalanche",
        "name_zh": "山崩巨石",
        "cost": 3,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "stone",
        "special": "cleave",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 14}
        ]
    },
    {
        "id": "diamond_bulwark",
        "name_en": "Diamond Bulwark",
        "name_zh": "金刚壁垒",
        "cost": 2,
        "rarity": "Rare",
        "pool": "StoneSentinel",
        "kind": "Skill",
        "element": "stone",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 18}
        ]
    },
    {
        "id": "crag_cleave",
        "name_en": "Crag Cleave",
        "name_zh": "断崖崩斩",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "stone",
        "special": "cleave",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8}
        ]
    },
    {
        "id": "bedrock_stance",
        "name_en": "Bedrock Stance",
        "name_zh": "基岩沉势",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "StoneSentinel",
        "kind": "Skill",
        "element": "stone",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 6},
            {"operation": "status", "target": "actor", "status": "strength", "amount": 1}
        ]
    },
    {
        "id": "shale_shards",
        "name_en": "Shale Shards",
        "name_zh": "页岩破片",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "stone",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 4},
            {"operation": "damage", "target": "opponent", "amount": 4}
        ]
    },

    # -------------------------------------------------------------
    # 3. Gale & Tempest / Sky Arts (15 cards)
    # -------------------------------------------------------------
    {
        "id": "zephyr_blade",
        "name_en": "Zephyr Blade",
        "name_zh": "微风轻刃",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "gale",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6},
            {"operation": "draw", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "cyclone_veil",
        "name_en": "Cyclone Veil",
        "name_zh": "旋风纱幕",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "gale",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 7}
        ]
    },
    {
        "id": "tempest_slash",
        "name_en": "Tempest Slash",
        "name_zh": "风暴迅斩",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "gale",
        "boomerang": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7}
        ]
    },
    {
        "id": "wind_stride",
        "name_en": "Wind Stride",
        "name_zh": "御风踏步",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "gale",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 5},
            {"operation": "energy", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "howling_gale",
        "name_en": "Howling Gale",
        "name_zh": "呼啸狂风",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "gale",
        "special": "cleave",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 1}
        ]
    },
    {
        "id": "tailwind_boost",
        "name_en": "Tailwind Boost",
        "name_zh": "顺风乘势",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Tactic",
        "element": "gale",
        "effects": [
            {"operation": "draw", "target": "actor", "amount": 2}
        ]
    },
    {
        "id": "storm_vortex",
        "name_en": "Storm Vortex",
        "name_zh": "暴风涡流",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "gale",
        "reverb": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8}
        ]
    },
    {
        "id": "feather_ward",
        "name_en": "Feather Ward",
        "name_zh": "轻羽护身",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "gale",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 5},
            {"operation": "draw", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "whirlwind_kick",
        "name_en": "Whirlwind Kick",
        "name_zh": "旋岚疾踢",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "gale",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 4},
            {"operation": "damage", "target": "opponent", "amount": 4}
        ]
    },
    {
        "id": "eye_of_storm",
        "name_en": "Eye of the Storm",
        "name_zh": "风眼寂静",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Power",
        "element": "gale",
        "effects": [
            {"operation": "status", "target": "actor", "status": "strength", "amount": 1},
            {"operation": "draw", "target": "actor", "amount": 2}
        ]
    },
    {
        "id": "tornado_strike",
        "name_en": "Tornado Strike",
        "name_zh": "龙卷破击",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "gale",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 10},
            {"operation": "status", "target": "opponent", "status": "vulnerable", "amount": 1}
        ]
    },
    {
        "id": "gale_rebound",
        "name_en": "Rebounding Gale",
        "name_zh": "回旋罡风",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "gale",
        "boomerang": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6}
        ]
    },
    {
        "id": "aero_barrier",
        "name_en": "Aero Barrier",
        "name_zh": "气流屏障",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "gale",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 12},
            {"operation": "draw", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "skyward_thrust",
        "name_en": "Skyward Thrust",
        "name_zh": "破空冲宵",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "gale",
        "special": "pierce",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 13}
        ]
    },
    {
        "id": "tempest_echo",
        "name_en": "Tempest Echo",
        "name_zh": "风啸回音",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Skill",
        "element": "gale",
        "reverb": True,
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 9}
        ]
    },

    # -------------------------------------------------------------
    # 4. Frost & Water / Tide & Ice (15 cards)
    # -------------------------------------------------------------
    {
        "id": "frost_javelin",
        "name_en": "Frost Javelin",
        "name_zh": "冰霜标枪",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "water",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 1}
        ]
    },
    {
        "id": "glacial_barrier",
        "name_en": "Glacial Barrier",
        "name_zh": "冰川壁障",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "water",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 7}
        ]
    },
    {
        "id": "tidal_surge",
        "name_en": "Tidal Surge",
        "name_zh": "潮汐奔涌",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "water",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 10},
            {"operation": "draw", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "frozen_veil",
        "name_en": "Frozen Veil",
        "name_zh": "凝霜灵纱",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "water",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 11},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 1}
        ]
    },
    {
        "id": "blizzard",
        "name_en": "Blizzard",
        "name_zh": "极寒暴雪",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "water",
        "special": "cleave",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 2}
        ]
    },
    {
        "id": "ice_shard_barrage",
        "name_en": "Ice Shard Barrage",
        "name_zh": "碎冰连弹",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "water",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 3},
            {"operation": "damage", "target": "opponent", "amount": 3},
            {"operation": "damage", "target": "opponent", "amount": 3}
        ]
    },
    {
        "id": "crystal_dew",
        "name_en": "Crystal Dew",
        "name_zh": "玉露涤灵",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "water",
        "effects": [
            {"operation": "heal", "target": "actor", "amount": 6},
            {"operation": "draw", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "frostbite",
        "name_en": "Frostbite",
        "name_zh": "深寒入骨",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "water",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 5},
            {"operation": "status", "target": "opponent", "status": "vulnerable", "amount": 2}
        ]
    },
    {
        "id": "rime_aegis",
        "name_en": "Rime Aegis",
        "name_zh": "白霜坚壁",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Skill",
        "element": "water",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 15},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 1}
        ]
    },
    {
        "id": "aqua_lotus",
        "name_en": "Aqua Lotus",
        "name_zh": "碧水幽莲",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "water",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 5},
            {"operation": "heal", "target": "actor", "amount": 5}
        ]
    },
    {
        "id": "torrential_blast",
        "name_en": "Torrential Blast",
        "name_zh": "激流爆破",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "water",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 12}
        ]
    },
    {
        "id": "ice_mirror",
        "name_en": "Ice Mirror",
        "name_zh": "玄冰明镜",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "water",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 10},
            {"operation": "draw", "target": "actor", "amount": 2}
        ]
    },
    {
        "id": "permafrost",
        "name_en": "Permafrost",
        "name_zh": "万年永冻",
        "cost": 3,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Skill",
        "element": "water",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 16},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 2},
            {"operation": "energy", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "chill_strike",
        "name_en": "Chill Strike",
        "name_zh": "凛寒突袭",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "water",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6},
            {"operation": "shield", "target": "actor", "amount": 3}
        ]
    },
    {
        "id": "tide_whisper",
        "name_en": "Tide Whisper",
        "name_zh": "听潮寻灵",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Tactic",
        "element": "water",
        "special": "recycleDiscard",
        "effects": [
            {"operation": "draw", "target": "actor", "amount": 2}
        ]
    },

    # -------------------------------------------------------------
    # 5. Poison & Miasma / Noxious Arts (15 cards)
    # -------------------------------------------------------------
    {
        "id": "venom_fang",
        "name_en": "Venom Fang",
        "name_zh": "毒液尖牙",
        "cost": 1,
        "rarity": "Common",
        "pool": "MiasmaWitch",
        "kind": "Attack",
        "element": "poison",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 2}
        ]
    },
    {
        "id": "miasma_cloud",
        "name_en": "Miasma Cloud",
        "name_zh": "瘴气浓雾",
        "cost": 1,
        "rarity": "Common",
        "pool": "MiasmaWitch",
        "kind": "Skill",
        "element": "poison",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 5},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 3}
        ]
    },
    {
        "id": "toxic_spores",
        "name_en": "Toxic Spores",
        "name_zh": "剧毒孢子",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "MiasmaWitch",
        "kind": "Attack",
        "element": "poison",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 4},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 3}
        ]
    },
    {
        "id": "corrosive_acid",
        "name_en": "Corrosive Acid",
        "name_zh": "腐蚀毒酸",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "MiasmaWitch",
        "kind": "Attack",
        "element": "poison",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 3},
            {"operation": "status", "target": "opponent", "status": "vulnerable", "amount": 1}
        ]
    },
    {
        "id": "plague_ward",
        "name_en": "Plague Ward",
        "name_zh": "瘟疫护身",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "poison",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 7},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 1}
        ]
    },
    {
        "id": "viper_coil",
        "name_en": "Viper's Coil",
        "name_zh": "巨蝰绞缠",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "MiasmaWitch",
        "kind": "Attack",
        "element": "poison",
        "special": "stun",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8}
        ]
    },
    {
        "id": "noxious_brew",
        "name_en": "Noxious Brew",
        "name_zh": "烈毒佳酿",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "MiasmaWitch",
        "kind": "Tactic",
        "element": "poison",
        "special": "recycleDiscard",
        "effects": [
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 4}
        ]
    },
    {
        "id": "epidemic",
        "name_en": "Epidemic",
        "name_zh": "疫毒蔓延",
        "cost": 2,
        "rarity": "Rare",
        "pool": "MiasmaWitch",
        "kind": "Attack",
        "element": "poison",
        "special": "cleave",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 3}
        ]
    },
    {
        "id": "wither_burst",
        "name_en": "Wither Burst",
        "name_zh": "凋零爆发",
        "cost": 1,
        "rarity": "Rare",
        "pool": "MiasmaWitch",
        "kind": "Attack",
        "element": "poison",
        "overload": 1,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 4}
        ]
    },
    {
        "id": "decay_wave",
        "name_en": "Wave of Decay",
        "name_zh": "腐朽浪潮",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "poison",
        "effects": [
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 4},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 2}
        ]
    },
    {
        "id": "toxic_leech",
        "name_en": "Toxic Leech",
        "name_zh": "噬血毒蛭",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "poison",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 5},
            {"operation": "heal", "target": "actor", "amount": 4}
        ]
    },
    {
        "id": "venomous_haze",
        "name_en": "Venomous Haze",
        "name_zh": "毒瘴迷魂",
        "cost": 2,
        "rarity": "Rare",
        "pool": "MiasmaWitch",
        "kind": "Skill",
        "element": "poison",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 10},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 4}
        ]
    },
    {
        "id": "caustic_splash",
        "name_en": "Caustic Splash",
        "name_zh": "强酸飞溅",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "poison",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 3},
            {"operation": "damage", "target": "opponent", "amount": 3},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 2}
        ]
    },
    {
        "id": "poison_reverb",
        "name_en": "Poison Reverb",
        "name_zh": "剧毒回荡",
        "cost": 2,
        "rarity": "Rare",
        "pool": "MiasmaWitch",
        "kind": "Attack",
        "element": "poison",
        "reverb": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 5},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 3}
        ]
    },
    {
        "id": "plague_tome",
        "name_en": "Tome of Pestilence",
        "name_zh": "万毒秘典",
        "cost": 2,
        "rarity": "Rare",
        "pool": "MiasmaWitch",
        "kind": "Power",
        "element": "poison",
        "effects": [
            {"operation": "status", "target": "actor", "status": "strength", "amount": 1},
            {"operation": "status", "target": "opponent", "status": "poison", "amount": 3}
        ]
    },

    # -------------------------------------------------------------
    # 6. Spirit & Arcane / Celestial & Soul (16 cards)
    # -------------------------------------------------------------
    {
        "id": "astral_guidance",
        "name_en": "Astral Guidance",
        "name_zh": "星灵指引",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Tactic",
        "element": "spirit",
        "effects": [
            {"operation": "energy", "target": "actor", "amount": 1},
            {"operation": "draw", "target": "actor", "amount": 1}
        ]
    },
    {
        "id": "spirit_blade",
        "name_en": "Spirit Blade",
        "name_zh": "灵光化刃",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "spirit",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8}
        ]
    },
    {
        "id": "soul_barrier",
        "name_en": "Soul Barrier",
        "name_zh": "魂光屏障",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "spirit",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 7}
        ]
    },
    {
        "id": "enlighten",
        "name_en": "Enlighten",
        "name_zh": "灵光顿悟",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Power",
        "element": "spirit",
        "effects": [
            {"operation": "status", "target": "actor", "status": "focus", "amount": 2}
        ]
    },
    {
        "id": "karma_mirror",
        "name_en": "Karma Mirror",
        "name_zh": "业火明镜",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "spirit",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 10},
            {"operation": "status", "target": "actor", "status": "strength", "amount": 1}
        ]
    },
    {
        "id": "celestial_lance",
        "name_en": "Celestial Lance",
        "name_zh": "天界圣枪",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "spirit",
        "special": "pierce",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 11}
        ]
    },
    {
        "id": "spirit_mend",
        "name_en": "Spirit Mend",
        "name_zh": "灵魄愈合",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "spirit",
        "effects": [
            {"operation": "heal", "target": "actor", "amount": 8}
        ]
    },
    {
        "id": "soul_shatter",
        "name_en": "Soul Shatter",
        "name_zh": "裂魂断魄",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "spirit",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 9},
            {"operation": "status", "target": "opponent", "status": "vulnerable", "amount": 2},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 1}
        ]
    },
    {
        "id": "spectral_chains",
        "name_en": "Spectral Chains",
        "name_zh": "幽灵锁链",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "spirit",
        "special": "stun",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8}
        ]
    },
    {
        "id": "samsara_cycle",
        "name_en": "Samsara Cycle",
        "name_zh": "轮回流转",
        "cost": 1,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Tactic",
        "element": "spirit",
        "special": "recoverExhaust",
        "effects": [
            {"operation": "draw", "target": "actor", "amount": 2}
        ]
    },
    {
        "id": "ethereal_strike",
        "name_en": "Ethereal Strike",
        "name_zh": "虚灵绝影斩",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "spirit",
        "boomerang": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6}
        ]
    },
    {
        "id": "divine_intervention",
        "name_en": "Divine Intervention",
        "name_zh": "神圣降临",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Skill",
        "element": "spirit",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 13},
            {"operation": "heal", "target": "actor", "amount": 6}
        ]
    },
    {
        "id": "inner_peace",
        "name_en": "Inner Peace",
        "name_zh": "澄心明意",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "spirit",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 5},
            {"operation": "heal", "target": "actor", "amount": 4}
        ]
    },
    {
        "id": "astral_projection",
        "name_en": "Astral Projection",
        "name_zh": "星宿投影",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "spirit",
        "reverb": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8}
        ]
    },
    {
        "id": "spirit_surge",
        "name_en": "Spirit Surge",
        "name_zh": "灵力澎湃",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "spirit",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 5},
            {"operation": "status", "target": "actor", "status": "focus", "amount": 1}
        ]
    },
    {
        "id": "cosmos_seal",
        "name_en": "Cosmos Seal",
        "name_zh": "寰宇天印",
        "cost": 3,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "spirit",
        "special": "pierce",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 16},
            {"operation": "status", "target": "opponent", "status": "vulnerable", "amount": 2}
        ]
    },

    # -------------------------------------------------------------
    # 7. Thunder & Storm (8 cards)
    # -------------------------------------------------------------
    {
        "id": "lightning_strike",
        "name_en": "Lightning Strike",
        "name_zh": "雷霆击顶",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "thunder",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8}
        ]
    },
    {
        "id": "static_charge",
        "name_en": "Static Charge",
        "name_zh": "静电充能",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Skill",
        "element": "thunder",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 6},
            {"operation": "status", "target": "actor", "status": "focus", "amount": 1}
        ]
    },
    {
        "id": "chain_lightning",
        "name_en": "Chain Lightning",
        "name_zh": "连锁闪电",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "thunder",
        "special": "cleave",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7}
        ]
    },
    {
        "id": "thunderclap",
        "name_en": "Thunderclap",
        "name_zh": "霹雳震空",
        "cost": 1,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Attack",
        "element": "thunder",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 6},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 2}
        ]
    },
    {
        "id": "ball_lightning",
        "name_en": "Ball Lightning",
        "name_zh": "雷球闪现",
        "cost": 1,
        "rarity": "Common",
        "pool": "Universal",
        "kind": "Attack",
        "element": "thunder",
        "boomerang": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 5}
        ]
    },
    {
        "id": "overcharge_bolt",
        "name_en": "Overcharge Bolt",
        "name_zh": "过载雷矢",
        "cost": 1,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "thunder",
        "overload": 2,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 12}
        ]
    },
    {
        "id": "storm_fury",
        "name_en": "Storm Fury",
        "name_zh": "风雷狂暴",
        "cost": 2,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "thunder",
        "special": "cleave",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 9},
            {"operation": "status", "target": "opponent", "status": "vulnerable", "amount": 2}
        ]
    },
    {
        "id": "volt_shield",
        "name_en": "Volt Shield",
        "name_zh": "电弧雷盾",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "Universal",
        "kind": "Skill",
        "element": "thunder",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 11},
            {"operation": "energy", "target": "actor", "amount": 1}
        ]
    },

    # -------------------------------------------------------------
    # 8. Shadow, Void & Master Combos (7 cards)
    # -------------------------------------------------------------
    {
        "id": "shadow_strike",
        "name_en": "Shadow Strike",
        "name_zh": "暗影突袭",
        "cost": 1,
        "rarity": "Common",
        "pool": "ShadowStalker",
        "kind": "Attack",
        "element": "void",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 8}
        ]
    },
    {
        "id": "night_veil",
        "name_en": "Night Veil",
        "name_zh": "幽夜面纱",
        "cost": 1,
        "rarity": "Common",
        "pool": "ShadowStalker",
        "kind": "Skill",
        "element": "void",
        "effects": [
            {"operation": "shield", "target": "actor", "amount": 6},
            {"operation": "status", "target": "opponent", "status": "weak", "amount": 1}
        ]
    },
    {
        "id": "void_rend",
        "name_en": "Void Rend",
        "name_zh": "虚空撕裂",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "ShadowStalker",
        "kind": "Attack",
        "element": "void",
        "special": "pierce",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 11}
        ]
    },
    {
        "id": "dark_bargain",
        "name_en": "Dark Bargain",
        "name_zh": "暗黑盟约",
        "cost": 1,
        "rarity": "Rare",
        "pool": "ShadowStalker",
        "kind": "Tactic",
        "element": "void",
        "overload": 1,
        "effects": [
            {"operation": "energy", "target": "actor", "amount": 2}
        ]
    },
    {
        "id": "eclipse_slash",
        "name_en": "Eclipse Slash",
        "name_zh": "日食黯月斩",
        "cost": 2,
        "rarity": "Rare",
        "pool": "ShadowStalker",
        "kind": "Attack",
        "element": "void",
        "special": "critical",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 9}
        ]
    },
    {
        "id": "shadow_echo",
        "name_en": "Shadow Echo",
        "name_zh": "暗影残响",
        "cost": 2,
        "rarity": "Uncommon",
        "pool": "ShadowStalker",
        "kind": "Attack",
        "element": "void",
        "reverb": True,
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 7}
        ]
    },
    {
        "id": "void_implosion",
        "name_en": "Void Implosion",
        "name_zh": "虚无坍缩",
        "cost": 3,
        "rarity": "Rare",
        "pool": "Universal",
        "kind": "Attack",
        "element": "void",
        "effects": [
            {"operation": "damage", "target": "opponent", "amount": 17},
            {"operation": "status", "target": "opponent", "status": "vulnerable", "amount": 2}
        ]
    }
]

# Elemental theme colors for card art generation
PALETTES = {
    "fire": {
        "bg_dark": (16, 8, 8),
        "bg_mid": (48, 14, 10),
        "bg_glow": (140, 36, 12),
        "primary": (255, 120, 30),
        "secondary": (255, 200, 60),
        "accent": (255, 245, 180),
        "shadow": (28, 6, 4)
    },
    "stone": {
        "bg_dark": (12, 14, 14),
        "bg_mid": (28, 36, 32),
        "bg_glow": (54, 76, 62),
        "primary": (180, 160, 110),
        "secondary": (110, 180, 140),
        "accent": (230, 240, 210),
        "shadow": (10, 16, 12)
    },
    "gale": {
        "bg_dark": (10, 18, 22),
        "bg_mid": (20, 44, 52),
        "bg_glow": (40, 96, 110),
        "primary": (90, 200, 210),
        "secondary": (170, 240, 245),
        "accent": (240, 255, 255),
        "shadow": (8, 20, 26)
    },
    "water": {
        "bg_dark": (8, 14, 26),
        "bg_mid": (16, 32, 64),
        "bg_glow": (32, 72, 140),
        "primary": (70, 150, 245),
        "secondary": (140, 210, 255),
        "accent": (220, 245, 255),
        "shadow": (6, 12, 30)
    },
    "poison": {
        "bg_dark": (14, 8, 20),
        "bg_mid": (32, 14, 46),
        "bg_glow": (68, 28, 96),
        "primary": (130, 215, 60),
        "secondary": (180, 90, 235),
        "accent": (220, 255, 170),
        "shadow": (16, 6, 24)
    },
    "spirit": {
        "bg_dark": (14, 10, 24),
        "bg_mid": (34, 20, 56),
        "bg_glow": (84, 46, 130),
        "primary": (210, 150, 255),
        "secondary": (255, 215, 100),
        "accent": (255, 250, 220),
        "shadow": (18, 10, 32)
    },
    "thunder": {
        "bg_dark": (14, 12, 28),
        "bg_mid": (28, 24, 62),
        "bg_glow": (60, 52, 145),
        "primary": (245, 220, 50),
        "secondary": (120, 180, 255),
        "accent": (255, 255, 240),
        "shadow": (12, 10, 34)
    },
    "void": {
        "bg_dark": (8, 6, 14),
        "bg_mid": (20, 12, 34),
        "bg_glow": (52, 24, 88),
        "primary": (165, 80, 240),
        "secondary": (240, 110, 190),
        "accent": (245, 220, 255),
        "shadow": (8, 4, 16)
    }
}

def generate_artwork(card, out_path):
    random.seed(card["id"])
    elem = card.get("element", "spirit")
    palette = PALETTES.get(elem, PALETTES["spirit"])
    kind = card.get("kind", "Attack")
    special = card.get("special", "")

    W, H = 512, 512
    img = Image.new("RGB", (W, H), palette["bg_dark"])
    draw = ImageDraw.Draw(img)

    # 1. Background radial gradient
    cx, cy = W // 2, int(H * 0.45)
    max_r = int(math.hypot(cx, cy))
    bg_dark = palette["bg_dark"]
    bg_mid = palette["bg_mid"]
    bg_glow = palette["bg_glow"]

    for r in range(max_r, 0, -4):
        t = r / max_r
        if t > 0.5:
            factor = (t - 0.5) / 0.5
            col = (
                int(bg_dark[0] * factor + bg_mid[0] * (1 - factor)),
                int(bg_dark[1] * factor + bg_mid[1] * (1 - factor)),
                int(bg_dark[2] * factor + bg_mid[2] * (1 - factor)),
            )
        else:
            factor = t / 0.5
            col = (
                int(bg_mid[0] * factor + bg_glow[0] * (1 - factor)),
                int(bg_mid[1] * factor + bg_glow[1] * (1 - factor)),
                int(bg_mid[2] * factor + bg_glow[2] * (1 - factor)),
            )
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)

    # 2. Mystical outer rings and celestial geometry
    rings = [180, 140, 100]
    for idx, r in enumerate(rings):
        line_w = 2 if idx > 0 else 3
        c = palette["primary"] if idx == 0 else palette["secondary"]
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=line_w)

    # 3. Ray starbursts / runic spokes
    spokes = 8 if elem in ["fire", "thunder", "spirit"] else 6
    for i in range(spokes):
        angle = (i * 2 * math.pi / spokes) + (random.random() * 0.1)
        r_inner = 90
        r_outer = 175
        x1 = cx + int(math.cos(angle) * r_inner)
        y1 = cy + int(math.sin(angle) * r_inner)
        x2 = cx + int(math.cos(angle) * r_outer)
        y2 = cy + int(math.sin(angle) * r_outer)
        draw.line([x1, y1, x2, y2], fill=palette["secondary"], width=2)
        # Small node at outer tip
        draw.ellipse([x2 - 3, y2 - 3, x2 + 3, y2 + 3], fill=palette["accent"])

    # 4. Central Emblem / Iconography based on kind and element
    if kind == "Attack":
        # Draw dynamic blade, spear or strike energy
        blade_len = 110
        top_y = cy - blade_len
        bot_y = cy + int(blade_len * 0.7)
        blade_w = 18 if elem != "stone" else 28
        
        # Blade body
        poly = [
            (cx, top_y),
            (cx + blade_w, cy - 20),
            (cx + blade_w // 2, bot_y),
            (cx - blade_w // 2, bot_y),
            (cx - blade_w, cy - 20),
        ]
        draw.polygon(poly, fill=palette["primary"], outline=palette["accent"])
        # Inner energy spine
        draw.line([cx, top_y + 10, cx, bot_y - 10], fill=palette["accent"], width=3)
        # Crossguard / jewel
        draw.ellipse([cx - 16, cy + 20, cx + 16, cy + 52], fill=palette["secondary"], outline=palette["accent"], width=2)

    elif kind == "Skill":
        # Draw protective shield or ward mandala
        shield_h = 100
        shield_w = 80
        poly = [
            (cx, cy - shield_h),
            (cx + shield_w, cy - int(shield_h * 0.5)),
            (cx + int(shield_w * 0.7), cy + int(shield_h * 0.6)),
            (cx, cy + shield_h),
            (cx - int(shield_w * 0.7), cy + int(shield_h * 0.6)),
            (cx - shield_w, cy - int(shield_h * 0.5)),
        ]
        draw.polygon(poly, fill=palette["primary"], outline=palette["accent"])
        # Inner shield crest
        inner_poly = [
            (cx, cy - shield_h + 20),
            (cx + shield_w - 18, cy - int(shield_h * 0.5) + 10),
            (cx + int(shield_w * 0.5), cy + int(shield_h * 0.5)),
            (cx, cy + shield_h - 20),
            (cx - int(shield_w * 0.5), cy + int(shield_h * 0.5)),
            (cx - shield_w + 18, cy - int(shield_h * 0.5) + 10),
        ]
        draw.polygon(inner_poly, fill=palette["secondary"], outline=palette["accent"], width=2)
        # Center crest
        draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=palette["accent"])

    elif kind == "Power":
        # Draw cosmic lotus / ascending flame crown
        petals = 7
        for p in range(petals):
            p_ang = (p - petals // 2) * 0.35 - (math.pi / 2)
            p_len = 95 - abs(p - petals // 2) * 12
            px = cx + int(math.cos(p_ang) * p_len)
            py = cy + int(math.sin(p_ang) * p_len)
            draw.line([cx, cy + 30, px, py], fill=palette["primary"], width=6)
            draw.ellipse([px - 6, py - 6, px + 6, py + 6], fill=palette["accent"])
        # Lotus base
        draw.arc([cx - 60, cy - 20, cx + 60, cy + 60], 0, 180, fill=palette["secondary"], width=4)
        draw.ellipse([cx - 18, cy - 10, cx + 18, cy + 26], fill=palette["accent"])

    else:  # Tactic or other
        # Draw runic diamond and spiral compass
        d_size = 75
        poly = [
            (cx, cy - d_size),
            (cx + d_size, cy),
            (cx, cy + d_size),
            (cx - d_size, cy)
        ]
        draw.polygon(poly, fill=palette["primary"], outline=palette["accent"])
        inner_poly = [
            (cx, cy - int(d_size * 0.6)),
            (cx + int(d_size * 0.6), cy),
            (cx, cy + int(d_size * 0.6)),
            (cx - int(d_size * 0.6), cy)
        ]
        draw.polygon(inner_poly, fill=palette["secondary"], outline=palette["accent"], width=2)
        draw.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=palette["accent"])

    # 5. Ambient glowing particle flecks
    for _ in range(40):
        px = random.randint(30, W - 30)
        py = random.randint(30, H - 30)
        pr = random.randint(1, 3)
        p_col = palette["accent"] if random.random() < 0.4 else palette["secondary"]
        draw.ellipse([px - pr, py - pr, px + pr, py + pr], fill=p_col)

    # 6. Smooth atmospheric filter & vignette
    img = img.filter(ImageFilter.GaussianBlur(radius=0.7))
    # Apply vignette to outer borders
    vignette = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    v_draw = ImageDraw.Draw(vignette)
    for vi in range(0, 50, 4):
        alpha = int(140 * (1.0 - vi / 50.0))
        v_draw.rectangle([vi, vi, W - vi, H - vi], outline=(0, 0, 0, alpha), width=4)
    img.paste(vignette, (0, 0), vignette)

    img.save(out_path, "PNG")

def main():
    print(f"Total new cards to add: {len(CARDS_DATA)}")
    assert len(CARDS_DATA) == 106, f"Expected 106 cards, got {len(CARDS_DATA)}"

    core_path = "Godot/data/core.json"
    with open(core_path, "r", encoding="utf-8") as f:
        core = json.load(f)

    existing_ids = {c["id"] for c in core["cards"]}
    print(f"Existing cards count: {len(core['cards'])}")

    # Check for duplicate IDs
    for c in CARDS_DATA:
        cid = c["id"]
        if cid in existing_ids:
            raise ValueError(f"Duplicate card id: {cid}")

    # Add cards to core.json
    for c in CARDS_DATA:
        card_entry = {
            "id": c["id"],
            "nameKey": f"card.{c['id']}",
            "rarity": c["rarity"],
            "pool": c["pool"],
            "cost": c["cost"],
            "exhaust": c.get("exhaust", False),
            "effects": c["effects"],
            "kind": c["kind"],
            "element": c["element"]
        }
        if "special" in c:
            card_entry["special"] = c["special"]
        if c.get("boomerang", False):
            card_entry["boomerang"] = True
        if c.get("reverb", False):
            card_entry["reverb"] = True
        if c.get("overload", 0) > 0:
            card_entry["overload"] = c["overload"]

        core["cards"].append(card_entry)
        core["translations"]["en"][f"card.{c['id']}"] = c["name_en"]
        core["translations"]["zh-Hans"][f"card.{c['id']}"] = c["name_zh"]

    # Rebalance existing underpowered cards as requested
    for c in core["cards"]:
        if c["id"] == "phoenixEdge":
            # Buff phoenixEdge damage from 10 to 12
            for eff in c["effects"]:
                if eff["operation"] == "damage": eff["amount"] = 12
        elif c["id"] == "worldFlame":
            # Buff worldFlame damage from 8 to 11
            for eff in c["effects"]:
                if eff["operation"] == "damage": eff["amount"] = 11

    with open(core_path, "w", encoding="utf-8") as f:
        json.dump(core, f, ensure_ascii=False, indent=2)
    print(f"Updated {core_path} successfully. Total cards now: {len(core['cards'])}")

    # Generate 512x512 PNG artwork for all new cards
    cards_dir = "Godot/assets/cards"
    os.makedirs(cards_dir, exist_ok=True)
    for c in CARDS_DATA:
        out_path = os.path.join(cards_dir, f"{c['id']}.png")
        generate_artwork(c, out_path)
    print(f"Generated 106 card art files in {cards_dir}")

if __name__ == "__main__":
    main()
