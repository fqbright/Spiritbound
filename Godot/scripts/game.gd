extends Control
class_name SpiritGame

var content := SpiritContent.new()
var profile: Dictionary
var combat: SpiritCombat
var battle_log: BattleLog
var current_stage := 0
var active_modifier: Dictionary = {}
var root: Control
var overlay: Control
var map_canvas: Control
var map_scroll: TouchScrollContainer
var traveler: Sprite2D
var current_map_chapter: int = 0
var _map_screen: MapScreen
var _battle_screen: BattleScreen
var _rewards_screen: RewardsScreen
var _shop_deck_screen: ShopDeckScreen
var _camp_screen: CampScreen
var enemy_boxes: Array[Control] = []
var hand_zone: Control
var _last_hand_size := 0
var selected_rune := ""
var muted := false
var lang := "zh-Hans"
var resolving := false
# Bumped by begin_battle() (a new battle starts) and _leave_battle() (the current one ends) —
# a cancellation token for _resolve_play()'s long await chain (card-fly, buff/heal/shield
# animations, a per-enemy attack loop, then show_battle()/_maybe_end_turn()). Without it, a
# stale _resolve_play() coroutine that was still mid-animation when the player left (a loss, a
# manual retreat, anything reaching _leave_battle()) would resume once its timer/tween fires
# regardless, and its tail's show_battle() call unconditionally wipes whatever screen is
# current — silently replacing the map (or wherever _leave_battle() navigated to) with the old
# battle's UI. See _resolve_play()'s own guard for where this is checked.
var battle_session := 0
# Bumped by _clear() itself — the one shared choke point every screen transition goes through
# (show_map/show_camp/show_battle/show_shop/... all call it). A general-purpose cancellation
# token for any fire-and-forget coroutine that survives past a point where the player could
# plausibly navigate elsewhere before it finishes — see _travel_to()'s own guard (tapping a
# distant stage pin starts a multi-second hop animation with no input lock; tapping Camp/
# Quests/another pin mid-animation used to leave that stale coroutine to unconditionally call
# show_event()/begin_battle() on whatever screen the player had already moved to once its tween
# finished) for the shape of bug this exists to prevent. battle_session above solves the same
# problem for _resolve_play() specifically (and also resets g.resolving, which this doesn't) —
# this is the general version for everything else.
var screen_generation := 0
# -1 (the default) means "disabled" — every begin_*_battle() function seeds SpiritCombat from
# _battle_seed() below instead of inlining Time.get_unix_time_from_system() itself, the same
# formula duplicated across 7 call sites (begin_battle, begin_boss_rush_battle,
# begin_curse_run_battle, begin_sandbox_battle, begin_abyss_battle, begin_world_event_battle,
# begin_phantom_arena) until this was added. A real player's shuffle and flavor-modifier roll
# differing every battle is intended, not a bug — but that same non-determinism produced two
# separately-diagnosed flakiness bugs in one session before either was traced back to this
# exact line (ui_smoke.gd's finishing-blow banner check, and visual_snapshots.gd's battle-
# screen capture — see AGENTS.md's Traps section for both). Set this to a fixed value before
# calling any begin_*_battle() function to make its shuffle, flavor modifier, and enemy count
# fully reproducible instead of hand-patching combat state after the fact per-test; never
# touched by real gameplay.
var test_seed_override := -1
var loadout_tab := "equipment"
var pending_rewards: Dictionary = {}
var selected_card := -1
var advancing_to_reward := false
var pre_battle_health := 60
var in_abyss := false
var pending_boon_draft := false
var in_daily_trial := false
var in_weekly_challenge := false
var in_draft_battle := false
var in_boss_rush := false
var in_curse_run := false
var in_sandbox := false
var sandbox_stage := 0
var compendium_tab := "cards"
var camp_tab := "character"
var shop_tab := "curated"
var battle_speed := 1.0
const BATTLE_SPEED_OPTIONS: Array[float] = [1.0, 1.5, 2.0]
var auto_battle_active: bool = false
var auto_battle_stats: Dictionary = {"stages_cleared": 0, "gold_earned": 0}
# Kept deliberately conservative (vs. e.g. iOS Dynamic Type's much wider range) — every screen
# in this game was laid out and hand-verified assuming a fixed font size, so a large jump risks
# clipping text against a tightly-sized badge or card tile that nothing here re-flows for.
const TEXT_SCALE_OPTIONS: Array[float] = [0.9, 1.0, 1.1, 1.2]
var deck_filter_kind: String = "all"
var deck_filter_element: String = "all"
var deck_search_query: String = ""
var in_phantom_arena: bool = false
var in_world_event: bool = false
var current_screen_name: String = "map"
var clipboard_cache: String = ""
var _back_action := Callable()
var _swipe_origin := Vector2.ZERO
var _swipe_tracking := false
var map_music: AudioStreamPlayer
var battle_music: AudioStreamPlayer
var battle_music_streams: Array[AudioStream] = []
var sfx_muted := false
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _sfx_cache: Dictionary = {}
const SFX_POOL_SIZE := 8
static func _load_game_font() -> Font:
	var en_font: FontFile = load("res://assets/fonts/Cinzel-SemiBold.ttf")
	var cjk_font: FontFile = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	if en_font and cjk_font:
		var arr: Array[Font] = [cjk_font]
		en_font.fallbacks = arr
		return en_font
	elif cjk_font:
		return cjk_font
	elif en_font:
		return en_font
	return null

var font_cjk: Font = _load_game_font()

var _char_atlas_tex: Texture2D = null
var _card_atlas_1: Texture2D = null
var _card_atlas_2: Texture2D = null
var _road_texture: NoiseTexture2D = null
var _mote_texture: GradientTexture2D = null
var _hit_flash_shader: Shader = null
var _card_foil_shader: Shader = null
var _ember_texture: GradientTexture2D = null
var _terrain_grain_texture: NoiseTexture2D = null
var _terrain_wash_cache: Dictionary = {}
var _map_pin_rune_tex: Texture2D = null
var _card_frame_border_tex: Texture2D = null
var _card_frame_cache: Dictionary = {}

func _get_card_frame_texture(rarity: String = "Common") -> Texture2D:
	if _card_frame_cache.has(rarity):
		return _card_frame_cache[rarity]
	var path := ""
	match rarity:
		"Starter": path = "res://assets/card_frame_starter.png"
		"Uncommon": path = "res://assets/card_frame_uncommon.png"
		"Rare": path = "res://assets/card_frame_rare.png"
		_: path = "res://assets/card_frame_common.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex != null:
			_card_frame_cache[rarity] = tex
			return tex
	if _card_frame_border_tex == null:
		_card_frame_border_tex = load("res://assets/card_frame_golden_border.png")
	return _card_frame_border_tex

var _card_back_tex: Texture2D = null

func _get_card_back_texture() -> Texture2D:
	if _card_back_tex == null and ResourceLoader.exists("res://assets/cards/card_back_default.png"):
		_card_back_tex = load("res://assets/cards/card_back_default.png")
	return _card_back_tex

var _map_tile_forest_tex: Texture2D = null
var _biome_textures: Array = []
var _chapter_map_cache: Dictionary = {}
var _icon_textures: Dictionary = {}
# Chapter waypoints are deterministic but not cheap to compute (a seeded RNG walk); they
# never change once generated, so cache per chapter for the life of the app.
var _map_waypoint_cache: Dictionary = {}

const BG = Color("071116")
const PANEL = Color("10242b")
const JADE = Color("83e4c1")
const EMBER = Color("ff9a4c")
const GOLD = Color("dab56e")
const TEXT = Color("f7f3e8")
const MUTED = Color("bdd0d0")
const BATTLE_BACKGROUNDS = ["battle_stage_0.png","battle_stage_1.png","battle_stage_2.png","battle_stage_3.png","battle_stage_4.png"]

# The map is full-bleed: it spans the whole 390pt screen rather than sitting inside the
# page margins every other screen uses.
const MAP_WIDTH = 390.0
const BAND_HEIGHT = 844.0
# Keeps every stage pin clear of the screen edge and of the chapter plaque/fade at the top.
const ROAD_MARGIN_X = 62.0
const ROAD_TOP_CLEAR = 100.0
# Each chapter gets its own wash of colour so the terrain still reads as a distinct region.
const CHAPTER_TINTS = [
	Color(0.72,0.88,0.86), Color(0.95,0.78,0.55), Color(0.72,0.80,1.00), Color(0.80,0.86,0.92), Color(0.74,0.92,0.72),
	Color(0.68,0.90,0.95), Color(0.70,0.96,0.80), Color(0.88,0.82,0.98), Color(1.00,0.72,0.56), Color(0.98,0.86,0.62),
]

# Hand-picked to trace the actual painted trail/river/canyon-floor in each of the six
# chapter/biome backgrounds (assets/chapters/chapter_0..5.png, each exactly MAP_WIDTHxBAND_HEIGHT)
# at the five fixed stage heights below. One entry per biome, indexed by chapter % 6.
const BIOME_PATH_WAYPOINTS = [
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # forest
	[Vector2(195, 725), Vector2(235, 620), Vector2(175, 490), Vector2(205, 360), Vector2(240, 240)],  # ember canyon
	[Vector2(150, 775), Vector2(225, 710), Vector2(175, 560), Vector2(220, 445), Vector2(150, 305)],  # glacier
	[Vector2(195, 715), Vector2(215, 580), Vector2(220, 460), Vector2(180, 340), Vector2(240, 220)],  # celestial
	[Vector2(160, 810), Vector2(240, 710), Vector2(235, 570), Vector2(165, 440), Vector2(195, 260)],  # swamp
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # golden
]

# One entry per chapter (0-49), pixel-traced to the specific painted trail in each chapter's
# full-screen (390x844) background illustration, ascending from bottom (stage 1) to top (stage 5 / boss).
const CHAPTER_PATH_WAYPOINTS = [
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_0.png
	[Vector2(195, 725), Vector2(235, 620), Vector2(175, 490), Vector2(205, 360), Vector2(240, 240)],  # chapter_1.png
	[Vector2(150, 775), Vector2(225, 710), Vector2(175, 560), Vector2(220, 445), Vector2(150, 305)],  # chapter_2.png
	[Vector2(195, 715), Vector2(215, 580), Vector2(220, 460), Vector2(180, 340), Vector2(240, 220)],  # chapter_3.png
	[Vector2(160, 810), Vector2(240, 710), Vector2(235, 570), Vector2(165, 440), Vector2(195, 260)],  # chapter_4.png
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_5.png
	[Vector2(225, 715), Vector2(240, 580), Vector2(145, 470), Vector2(190, 350), Vector2(155, 230)],  # chapter_6.png
	[Vector2(195, 725), Vector2(155, 620), Vector2(215, 490), Vector2(185, 360), Vector2(150, 240)],  # chapter_7.png
	[Vector2(240, 775), Vector2(165, 710), Vector2(215, 560), Vector2(170, 445), Vector2(240, 305)],  # chapter_8.png
	[Vector2(195, 715), Vector2(175, 580), Vector2(170, 460), Vector2(210, 340), Vector2(150, 220)],  # chapter_9.png
	[Vector2(230, 810), Vector2(150, 710), Vector2(155, 570), Vector2(225, 440), Vector2(195, 260)],  # chapter_10.png
	[Vector2(225, 715), Vector2(240, 580), Vector2(145, 470), Vector2(190, 350), Vector2(155, 230)],  # chapter_11.png
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_12.png
	[Vector2(195, 725), Vector2(235, 620), Vector2(175, 490), Vector2(205, 360), Vector2(240, 240)],  # chapter_13.png
	[Vector2(150, 775), Vector2(225, 710), Vector2(175, 560), Vector2(220, 445), Vector2(150, 305)],  # chapter_14.png
	[Vector2(195, 715), Vector2(215, 580), Vector2(220, 460), Vector2(180, 340), Vector2(240, 220)],  # chapter_15.png
	[Vector2(160, 810), Vector2(240, 710), Vector2(235, 570), Vector2(165, 440), Vector2(195, 260)],  # chapter_16.png
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_17.png
	[Vector2(225, 715), Vector2(240, 580), Vector2(145, 470), Vector2(190, 350), Vector2(155, 230)],  # chapter_18.png
	[Vector2(195, 725), Vector2(155, 620), Vector2(215, 490), Vector2(185, 360), Vector2(150, 240)],  # chapter_19.png
	[Vector2(240, 775), Vector2(165, 710), Vector2(215, 560), Vector2(170, 445), Vector2(240, 305)],  # chapter_20.png
	[Vector2(195, 715), Vector2(175, 580), Vector2(170, 460), Vector2(210, 340), Vector2(150, 220)],  # chapter_21.png
	[Vector2(230, 810), Vector2(150, 710), Vector2(155, 570), Vector2(225, 440), Vector2(195, 260)],  # chapter_22.png
	[Vector2(225, 715), Vector2(240, 580), Vector2(145, 470), Vector2(190, 350), Vector2(155, 230)],  # chapter_23.png
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_24.png
	[Vector2(195, 725), Vector2(235, 620), Vector2(175, 490), Vector2(205, 360), Vector2(240, 240)],  # chapter_25.png
	[Vector2(150, 775), Vector2(225, 710), Vector2(175, 560), Vector2(220, 445), Vector2(150, 305)],  # chapter_26.png
	[Vector2(195, 715), Vector2(215, 580), Vector2(220, 460), Vector2(180, 340), Vector2(240, 220)],  # chapter_27.png
	[Vector2(160, 810), Vector2(240, 710), Vector2(235, 570), Vector2(165, 440), Vector2(195, 260)],  # chapter_28.png
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_29.png
	[Vector2(225, 715), Vector2(240, 580), Vector2(145, 470), Vector2(190, 350), Vector2(155, 230)],  # chapter_30.png
	[Vector2(150, 240), Vector2(185, 360), Vector2(215, 490), Vector2(155, 620), Vector2(195, 725)],  # chapter_31.png
	[Vector2(240, 775), Vector2(165, 710), Vector2(215, 560), Vector2(170, 445), Vector2(240, 305)],  # chapter_32.png
	[Vector2(195, 715), Vector2(175, 580), Vector2(170, 460), Vector2(210, 340), Vector2(150, 220)],  # chapter_33.png
	[Vector2(230, 810), Vector2(150, 710), Vector2(155, 570), Vector2(225, 440), Vector2(195, 260)],  # chapter_34.png
	[Vector2(225, 715), Vector2(240, 580), Vector2(145, 470), Vector2(190, 350), Vector2(155, 230)],  # chapter_35.png
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_36.png
	[Vector2(195, 725), Vector2(235, 620), Vector2(175, 490), Vector2(205, 360), Vector2(240, 240)],  # chapter_37.png
	[Vector2(150, 775), Vector2(225, 710), Vector2(175, 560), Vector2(220, 445), Vector2(150, 305)],  # chapter_38.png
	[Vector2(195, 715), Vector2(215, 580), Vector2(220, 460), Vector2(180, 340), Vector2(240, 220)],  # chapter_39.png
	[Vector2(160, 810), Vector2(240, 710), Vector2(235, 570), Vector2(165, 440), Vector2(195, 260)],  # chapter_40.png
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_41.png
	[Vector2(225, 715), Vector2(240, 580), Vector2(145, 470), Vector2(190, 350), Vector2(155, 230)],  # chapter_42.png
	[Vector2(195, 725), Vector2(155, 620), Vector2(215, 490), Vector2(185, 360), Vector2(150, 240)],  # chapter_43.png
	[Vector2(240, 775), Vector2(165, 710), Vector2(215, 560), Vector2(170, 445), Vector2(240, 305)],  # chapter_44.png
	[Vector2(195, 715), Vector2(175, 580), Vector2(170, 460), Vector2(210, 340), Vector2(150, 220)],  # chapter_45.png
	[Vector2(230, 810), Vector2(150, 710), Vector2(155, 570), Vector2(225, 440), Vector2(195, 260)],  # chapter_46.png
	[Vector2(225, 715), Vector2(240, 580), Vector2(145, 470), Vector2(190, 350), Vector2(155, 230)],  # chapter_47.png
	[Vector2(165, 715), Vector2(150, 580), Vector2(245, 470), Vector2(200, 350), Vector2(235, 230)],  # chapter_48.png
	[Vector2(195, 725), Vector2(235, 620), Vector2(175, 490), Vector2(205, 360), Vector2(240, 240)],  # chapter_49.png
]

const CHAR_KEYS = {
	"fox": Vector2i(0, 0),
	"sentinel": Vector2i(1, 0),
	"lanternstone": Vector2i(2, 0),
	"runebound": Vector2i(0, 1),
	"embercliff": Vector2i(1, 1),
	"mountainHeart": Vector2i(2, 1),
	"runeShard": Vector2i(0, 2),
	"ashRaven": Vector2i(1, 2),
	"forgeSpark": Vector2i(2, 2),
}

const CARD_ATLAS_1_POS = {
	"moonfang": Vector2i(0, 0),
	"renewal": Vector2i(1, 0),
	"spiritCurrent": Vector2i(0, 1),
	"ashRecall": Vector2i(1, 1),
	# No new bitmap art exists for these — reused slots follow the same pattern the rest
	# of the deck already uses (several cards already share one atlas cell).
	"ironHide": Vector2i(0, 0),
	"steadyPulse": Vector2i(1, 0),
	"shatterGuard": Vector2i(0, 1),
	"ironWill": Vector2i(1, 1),
	"wardBreaker": Vector2i(0, 0),
	"stormcaller": Vector2i(1, 0),
	"spiritNova": Vector2i(0, 1),
}

const CARD_ATLAS_2_POS = {
	"emberClaw": Vector2i(0, 0),
	"mirrorWard": Vector2i(1, 0),
	"wildSpark": Vector2i(0, 1),
	"foxBlessing": Vector2i(1, 1),
	"stoneBreaker": Vector2i(0, 0),
	"calmWard": Vector2i(1, 0),
	"spiritLance": Vector2i(0, 1),
	"cinderHex": Vector2i(1, 1),
	"stormArc": Vector2i(0, 1),
	"soulBrand": Vector2i(0, 0),
	"twinMoon": Vector2i(1, 0),
	"finalFlare": Vector2i(1, 1),
	"mountainSeal": Vector2i(1, 0),
	"worldFlame": Vector2i(0, 0),
	"embercoal": Vector2i(0, 0),
	"emberVow": Vector2i(1, 0),
	"mendingWard": Vector2i(0, 1),
	"piercingBolt": Vector2i(1, 1),
	"phoenixEdge": Vector2i(0, 0),
	"titanForm": Vector2i(1, 0),
	"moltenCore": Vector2i(0, 1),
}

func _get_character_texture(key: String) -> Texture2D:
	# Standalone portraits (monsters or heroes outside the 3x3 atlas) take priority
	var monster_path := "res://assets/characters/monsters/%s.png" % key
	if ResourceLoader.exists(monster_path):
		return load(monster_path)
	var standalone_path := "res://assets/characters/%s.png" % key
	if ResourceLoader.exists(standalone_path):
		return load(standalone_path)
	if _char_atlas_tex == null:
		_char_atlas_tex = load("res://assets/characters/character-atlas-v3.png")
	if not CHAR_KEYS.has(key):
		key = "sentinel"
	var coord: Vector2i = CHAR_KEYS[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = _char_atlas_tex
	var cell_w := float(_char_atlas_tex.get_width()) / 3.0
	var cell_h := float(_char_atlas_tex.get_height()) / 3.0
	atlas.region = Rect2(coord.x * cell_w, coord.y * cell_h, cell_w, cell_h)
	return atlas

func _art_key_for_enemy(enemy: Dictionary) -> String:
	if enemy.has("art_key") and not str(enemy.get("art_key", "")).is_empty():
		return str(enemy.get("art_key"))
	var art_str: String = str(enemy.get("art", ""))
	if not art_str.is_empty():
		var base_art := art_str.get_file().get_basename()
		if ResourceLoader.exists("res://assets/characters/monsters/%s.png" % base_art):
			return base_art
		if ResourceLoader.exists("res://assets/characters/%s.png" % base_art):
			return base_art
	if art_str.contains("sentinel"): return "sentinel"
	if art_str.contains("lanternstone"): return "lanternstone"
	if art_str.contains("runebound"): return "runebound"
	if art_str.contains("embercliff"): return "embercliff"
	if art_str.contains("mountain") or art_str.contains("heart"): return "mountainHeart"
	if art_str.contains("raven"): return "ashRaven"
	if art_str.contains("shard"): return "runeShard"
	if art_str.contains("spark"): return "forgeSpark"
	var name_str: String = str(enemy.get("name", ""))
	if name_str.contains("守卫"): return "sentinel"
	if name_str.contains("提灯"): return "lanternstone"
	if name_str.contains("巨像"): return "runebound"
	if name_str.contains("烬崖"): return "embercliff"
	if name_str.contains("山岳"): return "mountainHeart"
	if name_str.contains("随从"): return "ashRaven"
	return "sentinel"

func _get_card_texture(card_id: String) -> Texture2D:
	var direct_png := "res://assets/cards/%s.png" % card_id
	if ResourceLoader.exists(direct_png):
		return load(direct_png)
	var direct_jpg := "res://assets/cards/%s.jpg" % card_id
	if ResourceLoader.exists(direct_jpg):
		return load(direct_jpg)
	if CARD_ATLAS_1_POS.has(card_id):
		if _card_atlas_1 == null: _card_atlas_1 = load("res://assets/cards/new-cards-atlas.jpg")
		var coord: Vector2i = CARD_ATLAS_1_POS[card_id]
		var atlas := AtlasTexture.new()
		atlas.atlas = _card_atlas_1
		var cell_size := Vector2(_card_atlas_1.get_width(), _card_atlas_1.get_height()) / Vector2(2.0, 2.0)
		atlas.region = Rect2(Vector2(coord) * cell_size, cell_size)
		return atlas
	elif CARD_ATLAS_2_POS.has(card_id):
		if _card_atlas_2 == null: _card_atlas_2 = load("res://assets/cards/new-cards-atlas-2.jpg")
		var coord: Vector2i = CARD_ATLAS_2_POS[card_id]
		var atlas := AtlasTexture.new()
		atlas.atlas = _card_atlas_2
		var cell_size := Vector2(_card_atlas_2.get_width(), _card_atlas_2.get_height()) / Vector2(2.0, 2.0)
		atlas.region = Rect2(Vector2(coord) * cell_size, cell_size)
		return atlas
	else:
		if _card_atlas_1 == null: _card_atlas_1 = load("res://assets/cards/new-cards-atlas.jpg")
		var atlas := AtlasTexture.new()
		atlas.atlas = _card_atlas_1
		atlas.region = Rect2(0, 0, float(_card_atlas_1.get_width()) / 2.0, float(_card_atlas_1.get_height()) / 2.0)
		return atlas


func t(key: String) -> String:
	return content.ui(key, lang)

func tf(key: String, args) -> String:
	if args is Array:
		return content.ui(key, lang) % args
	return content.ui(key, lang) % [args]

func _enemy_name(enemy: Dictionary) -> String:
	if lang == "en":
		return str(enemy.get("name_en", enemy.name))
	return str(enemy.name)

func _equip_name(item: Dictionary) -> String:
	return content.equip_name(item, lang)

func _equip_detail(item: Dictionary) -> String:
	return content.equip_detail(item, lang)

func _rune_name(rune: Dictionary) -> String:
	return content.rune_name(rune, lang)

func _rune_detail(rune: Dictionary) -> String:
	return content.rune_detail(rune, lang)

func _relic_name(item: Dictionary) -> String:
	return content.relic_name(item, lang)

func _relic_detail(item: Dictionary) -> String:
	return content.relic_detail(item, lang)

func _relic_resonance_name(res: Dictionary) -> String:
	return content.relic_resonance_name(res, lang)

func _relic_resonance_detail(res: Dictionary) -> String:
	return content.relic_resonance_detail(res, lang)



# Composition objects are constructed here, not in _ready(), because test_runner.gd
# instantiates this script's scene directly (scn.instantiate()) without adding it to the
# tree to test pure functions like _card_build_score() in isolation — _ready() never fires
# for a node that's never added as a child, but _init() always runs at construction time.
func _init() -> void:
	_map_screen = MapScreen.new(self)
	_battle_screen = BattleScreen.new(self)
	_rewards_screen = RewardsScreen.new(self)
	_shop_deck_screen = ShopDeckScreen.new(self)
	_camp_screen = CampScreen.new(self)

func _ready() -> void:
	set_process_input(true)
	profile = SpiritSave.load_profile(content)
	lang = str(profile.get("language", "zh-Hans"))
	battle_speed = clampf(float(profile.get("battle_speed", 1.0)), 1.0, 2.0)
	muted = bool(profile.get("music_muted", false))
	sfx_muted = bool(profile.get("sfx_muted", false))
	_build_audio()
	_ensure_quests_current()
	_ensure_daily_trial_current()
	_ensure_weekly_challenge_current()
	_ensure_world_event_current()
	_ensure_login_reward_current()
	var should_play_intro := not bool(profile.get("intro_seen", false)) and DisplayServer.get_name() != "headless"
	if should_play_intro:
		play_intro_cutscene(func():
			profile.intro_seen = true
			SpiritSave.write(profile)
			if SpiritSave.has_account_name(profile): show_map()
			else: show_account_setup()
		)
	else:
		if SpiritSave.has_account_name(profile): show_map()
		else: show_account_setup()

const DAY_SECONDS := 86400
const WEEK_SECONDS := 604800
# Phase 9 — World Events: a 4-week rotation per the plan's own "Local Deterministic Calendar"
# spec, one period longer than WEEK_SECONDS for exactly the reason DAY_SECONDS/WEEK_SECONDS
# already exist separately — each mode's own natural cadence gets its own named constant.
const MONTH_SECONDS := 28 * DAY_SECONDS

# Rerolls whichever list has aged past its period. period_seed is the period index itself
# (today's day number, this week's week number) so every reroll for the same period is
# identical — rerolling never happens more than once per period no matter how often this
# is called, since the new reset_at always lands in the future until the period elapses.
func _ensure_quests_current() -> void:
	var now := int(Time.get_unix_time_from_system())
	var changed := false
	if now >= int(profile.get("daily_reset_at", 0)):
		var day: int = now / DAY_SECONDS
		profile.daily_quests = content.roll_quests(SpiritContent.DAILY_QUESTS, 3, day)
		profile.daily_reset_at = (day + 1) * DAY_SECONDS
		changed = true
	if now >= int(profile.get("weekly_reset_at", 0)):
		var week: int = now / WEEK_SECONDS
		profile.weekly_quests = content.roll_quests(SpiritContent.WEEKLY_QUESTS, 3, 1000000 + week)
		profile.weekly_reset_at = (week + 1) * WEEK_SECONDS
		changed = true
	if changed: SpiritSave.write(profile)

# Same day-boundary rule as quests above: whichever day index the trial record was rolled
# for, once "now" moves past it the run resets to stage 0 — lifetime badges/best_stage are
# untouched, only the in-progress run.
func _ensure_daily_trial_current() -> void:
	var day: int = int(Time.get_unix_time_from_system()) / DAY_SECONDS
	var previous: Dictionary = profile.get("daily_trial_record", {})
	if int(previous.get("day", -1)) != day:
		var prev_day: int = int(previous.get("day", -1))
		var prev_stage: int = int(previous.get("stage", 0))
		var streak: int = int(previous.get("streak", 0))
		if prev_day == day - 1:
			if prev_stage < SpiritContent.DAILY_TRIAL_STAGES: streak = 0
		elif prev_day != -1:
			streak = 0
		# E1: one history entry per day actually played (prev_day == -1 means there was no
		# real previous day to record — a brand-new save, not a completed trial), capped so
		# the trend chart's data can't grow without bound over months of play.
		var history: Array = previous.get("history", []).duplicate()
		if prev_day != -1:
			history.append({"day": prev_day, "stage": prev_stage})
			if history.size() > SpiritContent.DAILY_TRIAL_HISTORY_LIMIT:
				history = history.slice(history.size() - SpiritContent.DAILY_TRIAL_HISTORY_LIMIT)
		profile.daily_trial_record = {
			"day": day,
			"stage": 0,
			"badges": int(previous.get("badges", 0)),
			"best_stage": int(previous.get("best_stage", 0)),
			"streak": streak,
			"streak_claimed": previous.get("streak_claimed", []).duplicate(),
			"history": history
		}
		SpiritSave.write(profile)

# B3: same day-boundary-reset shape as the Daily Trial above, but keyed to WEEK_SECONDS so it
# resets once a week instead of once a day — lifetime badges/best_stage carry over, only the
# in-progress run resets.
func _ensure_weekly_challenge_current() -> void:
	var week: int = int(Time.get_unix_time_from_system()) / WEEK_SECONDS
	var previous: Dictionary = profile.get("weekly_challenge_record", {})
	if int(previous.get("week", -1)) != week:
		profile.weekly_challenge_record = {
			"week": week,
			"stage": 0,
			"badges": int(previous.get("badges", 0)),
			"best_stage": int(previous.get("best_stage", 0)),
		}
		SpiritSave.write(profile)

# Phase 9: unlike Daily Trial/Weekly Challenge, a World Event has nothing to "roll" — which
# event is active is a pure function of the period index (content.world_event_for_period()), so
# the only state this resets is "has this period's one-time badge bonus been claimed yet."
# Historical badges (profile.world_event_record.badges) always carry over across periods.
func _ensure_world_event_current() -> void:
	var period: int = int(Time.get_unix_time_from_system()) / MONTH_SECONDS
	var previous: Dictionary = profile.get("world_event_record", {})
	if int(previous.get("period", -1)) != period:
		profile.world_event_record = {
			"period": period,
			"claimed": false,
			"badges": previous.get("badges", []).duplicate(),
		}
		SpiritSave.write(profile)

# Rolling weekly login reward: a new week resets the tally, and today's day index is recorded
# at most once (calling this repeatedly in one session, e.g. once per _ready(), must not let a
# player "log in" more than once for the same calendar day). Deliberately never resets on a
# missed day mid-week — see content.gd's LOGIN_REWARD_TIERS comment for why a hard streak
# reset is the wrong shape here.
func _ensure_login_reward_current() -> void:
	var now := int(Time.get_unix_time_from_system())
	var week: int = now / WEEK_SECONDS
	var today: int = now / DAY_SECONDS
	var record: Dictionary = profile.get("login_reward", {})
	if int(record.get("week", -1)) != week:
		record = {"week": week, "days": [], "claimed": []}
	var days: Array = record.get("days", [])
	if not days.has(today):
		days.append(today)
		record.days = days
		profile.login_reward = record
		SpiritSave.write(profile)
	else:
		profile.login_reward = record

func _claim_login_reward(tier_index: int) -> void:
	if tier_index < 0 or tier_index >= SpiritContent.LOGIN_REWARD_TIERS.size(): return
	var tier: Dictionary = SpiritContent.LOGIN_REWARD_TIERS[tier_index]
	var record: Dictionary = profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	if days_logged < int(tier.days): return
	var claimed: Array = record.get("claimed", [])
	if claimed.has(int(tier.days)): return
	claimed.append(int(tier.days))
	record.claimed = claimed
	profile.login_reward = record
	profile.gold += int(tier.reward)
	SpiritSave.write(profile)
	_toast(tf("ui.login_reward_claimed_toast", int(tier.reward)), GOLD)
	show_quests()

# Drives the red notification dot on the camp/quest entry point — true the moment any daily
# or weekly quest, or a login reward tier, is complete and waiting on its reward, same as the
# claim buttons inside.
func _battle_delay(seconds: float) -> float:
	return seconds / battle_speed

func _haptic(kind: String) -> void:
	match kind:
		"tap": Input.vibrate_handheld(10)
		"shield": Input.vibrate_handheld(25)
		"hit": Input.vibrate_handheld(40)
		"heavy": Input.vibrate_handheld(75)
		_: Input.vibrate_handheld(15)

func _cycle_speed() -> void:
	var idx: int = BATTLE_SPEED_OPTIONS.find(battle_speed)
	idx = (idx + 1) % BATTLE_SPEED_OPTIONS.size()
	battle_speed = BATTLE_SPEED_OPTIONS[idx]
	profile.battle_speed = battle_speed
	SpiritSave.write(profile)
	var speed_label: String = (str(int(battle_speed)) if battle_speed == float(int(battle_speed)) else str(battle_speed)) + "x"
	var speed_btn: Button = root.find_child("SpeedToggle", true, false) as Button if root != null and is_instance_valid(root) else null
	if speed_btn != null and is_instance_valid(speed_btn):
		speed_btn.text = speed_label
	else:
		show_battle()
	if auto_battle_active and not resolving and combat != null and combat.state.phase == "player":
		_battle_screen._maybe_step_auto_battle()


func _pass_turn() -> void:
	if combat == null or combat.state.phase != "player" or resolving: return
	_toast(t("ui.no_playable"))
	await get_tree().create_timer(_battle_delay(0.65)).timeout
	if combat == null or combat.state.phase != "player": return
	await _enemy_turn()

# Keywords that may appear on cards and warrant a tap-to-explain tooltip.
const KEYWORD_KEYS: Array[String] = [
	"damage", "shield", "heal", "draw", "burn", "focus", "vulnerable",
	"weak", "strength", "pierce", "cleave", "critical", "stun", "energy",
	"echo", "siphon", "resonance", "poison",
	"boomerang", "reverb", "overload",
]

# Bumps progress on every not-yet-complete quest of this type in both lists. Called from
# the same real signals the rest of the game already fires — a card played, a chest
# opened, a purchase made — rather than anything invented just for quests.
func _advance_quest(quest_type: String, amount: int) -> void:
	if amount <= 0: return
	# A permanent running total alongside the period-scoped quest progress below — this is
	# the only hook lifetime achievement stats need, since every real gameplay signal that
	# matters (a win, damage dealt, a chest opened, a purchase) already flows through here.
	if not profile.get("lifetime_stats") is Dictionary: profile.lifetime_stats = {}
	profile.lifetime_stats[quest_type] = int(profile.lifetime_stats.get(quest_type, 0)) + amount
	var any_completed := false
	for list_name in ["daily_quests", "weekly_quests"]:
		var list: Array = profile.get(list_name, [])
		for q in list:
			if str(q.get("type", "")) != quest_type or bool(q.get("claimed", false)): continue
			var target := int(q.get("target", 0))
			var before := int(q.get("progress", 0))
			if before >= target: continue
			q.progress = mini(target, before + amount)
			if int(q.progress) >= target and before < target: any_completed = true
	SpiritSave.write(profile)
	if any_completed: _toast(t("ui.quest_ready_toast"), GOLD)
	_refresh_achievements()

# Career Codex (旅者典籍): permanent playstyle/lifetime stats independent of the period-scoped
# quest system above. Deliberately does NOT duplicate what lifetime_stats/abyss_record already
# track (victories == lifetime_stats.win_battles, total damage == lifetime_stats.deal_damage,
# total gold == lifetime_stats.earn_gold, highest Abyss floor == profile.abyss_record) — only
# what nothing else does: win/loss streaks, per-battle totals pulled from combat.state.stats,
# and which hero/cards actually get played.
func _track_career_battle_stats() -> void:
	if not profile.get("career_stats") is Dictionary: profile.career_stats = {}
	if combat == null: return
	var cs: Dictionary = profile.career_stats
	var stats: Dictionary = combat.state.get("stats", {})
	cs.total_shield_gained = int(cs.get("total_shield_gained", 0)) + int(stats.get("shield_gained", 0))
	cs.total_cards_played = int(cs.get("total_cards_played", 0)) + int(stats.get("cards_played", 0))
	if not cs.get("favorite_cards") is Dictionary: cs.favorite_cards = {}
	var play_counts: Dictionary = stats.get("card_play_counts", {})
	for card_id in play_counts:
		cs.favorite_cards[card_id] = int(cs.favorite_cards.get(card_id, 0)) + int(play_counts[card_id])

# Called once per win from the top of _grant_stage_rewards(), covering every win path
# (campaign, Abyss, Boss Rush, Daily/Weekly Trial, Draft Arena, Phantom Arena) uniformly —
# g.combat is still the just-finished battle's state at that point, before the next begin_battle().
func _track_career_win() -> void:
	_track_career_battle_stats()
	var cs: Dictionary = profile.career_stats
	cs.current_win_streak = int(cs.get("current_win_streak", 0)) + 1
	cs.longest_win_streak = maxi(int(cs.get("longest_win_streak", 0)), int(cs.current_win_streak))
	var hero_id: String = str(profile.hero_class)
	if not cs.get("favorite_hero") is Dictionary: cs.favorite_hero = {}
	cs.favorite_hero[hero_id] = int(cs.favorite_hero.get(hero_id, 0)) + 1
	SpiritSave.write(profile)

# Called from _leave_battle() when g.combat.state.phase == "lost" specifically — a voluntary
# retreat is not a defeat and must not break the streak (see _track_career_retreat() below).
func _track_career_defeat() -> void:
	_track_career_battle_stats()
	profile.career_stats.defeats = int(profile.career_stats.get("defeats", 0)) + 1
	profile.career_stats.current_win_streak = 0
	SpiritSave.write(profile)

# Called from _leave_battle() for every other way a battle ends (a manual retreat mid-fight) —
# still credits the shield/cards/favorite-card totals for what actually happened this battle,
# just without touching the win/loss streak either way.
func _track_career_retreat() -> void:
	_track_career_battle_stats()
	SpiritSave.write(profile)

# Achievement progress readers, one per ACHIEVEMENTS "kind" — most kinds just read an existing
# permanent profile field directly (nothing to duplicate), "stat" is the one kind backed by
# the lifetime_stats counter _advance_quest() maintains above.
func _achievement_progress(ach: Dictionary) -> int:
	match str(ach.get("kind", "stat")):
		"stat": return int(profile.get("lifetime_stats", {}).get(str(ach.get("stat", "")), 0))
		"mastery_level":
			var best := 0
			for hero_id in profile.get("hero_masteries", {}):
				var xp: int = int(profile.hero_masteries[hero_id].get("xp", 0))
				best = maxi(best, content.mastery_level_for_xp(xp))
			return best
		"abyss_floor": return int(profile.get("abyss_record", 0))
		"daily_trial_badges": return int(profile.get("daily_trial_record", {}).get("badges", 0))
		"compendium_percent":
			var totals: Vector2i = _compendium_totals()
			return int(round(100.0 * float(totals.x) / maxf(1.0, float(totals.y))))
		"relic_count": return profile.get("relics", []).size()
		"card_collection": return profile.get("collection", {}).size()
		"samsara_count": return int(profile.get("samsara_count", 0))
		_: return 0

# Unlocks are permanent and one-time: once achievements_unlocked[id] is true it never gets
# re-evaluated, so a stat that could ever regress (nothing currently does) can't un-toast.
func _refresh_achievements() -> void:
	if not profile.get("achievements_unlocked") is Dictionary: profile.achievements_unlocked = {}
	var changed := false
	for ach in SpiritContent.ACHIEVEMENTS:
		var id: String = str(ach.id)
		if bool(profile.achievements_unlocked.get(id, false)): continue
		if _achievement_progress(ach) >= int(ach.target):
			profile.achievements_unlocked[id] = true
			changed = true
			_toast(tf("ui.achievement_unlocked_toast", content.ui(ach.nameKey, lang)), GOLD)
	if changed: SpiritSave.write(profile)

func _claim_quest(list_name: String, quest_id: String) -> void:
	var list: Array = profile.get(list_name, [])
	for q in list:
		if str(q.get("id", "")) != quest_id: continue
		if bool(q.get("claimed", false)) or int(q.get("progress", 0)) < int(q.get("target", 0)): return
		q.claimed = true
		profile.gold += int(q.get("reward", 0))
		var pass_xp := 300 if list_name == "weekly_quests" else 100
		_add_season_xp(pass_xp)
		SpiritSave.write(profile)
		_toast(tf("ui.quest_claimed_toast", int(q.get("reward", 0))), GOLD)
		show_quests()
		return

func _add_season_xp(amount: int) -> void:
	if not profile.get("season_pass") is Dictionary:
		profile.season_pass = {"season_id":1, "season_name":"灵火初醒", "xp":0, "claimed_free":[], "claimed_premium":[], "is_premium":true}
	var sp: Dictionary = profile.season_pass
	var current_xp: int = int(sp.get("xp", 0))
	var old_lvl: int = clampi(1 + int(current_xp / 200), 1, 20)
	current_xp += amount
	sp.xp = current_xp
	var new_lvl: int = clampi(1 + int(current_xp / 200), 1, 20)
	sp.level = new_lvl
	if new_lvl > old_lvl:
		_toast(tf("ui.season_pass_levelup", new_lvl), GOLD)
	SpiritSave.write(profile)

# Shared by every place a Draft Arena run ends: _abandon_draft() (CampScreen), the
# DRAFT_WIN_CAP Grand Champion ending (RewardsScreen's _grant_stage_rewards()), and the
# DRAFT_LOSS_CAP ending (BattleScreen's _leave_battle()). All three must reset the same
# fields or the next run inherits a stale round/deck/current_pool from the run that just
# finished — see AGENTS.md's Draft Arena section for the corruption this used to cause.
func _reset_draft_run() -> void:
	var draft: Dictionary = profile.get("draft_arena", {})
	draft.active = false
	draft.round = 1
	draft.deck = []
	draft.current_pool = []
	draft.wins = 0
	draft.losses = 0
	profile.draft_arena = draft
	SpiritSave.write(profile)

func show_account_setup() -> void:
	_close_settings()
	_clear(); _play_music(false)
	var backdrop := _background("spirit-world-map-v1.jpg", .34); root.add_child(backdrop); root.move_child(backdrop, 0)
	var page := _create_page(10)
	page.alignment = BoxContainer.ALIGNMENT_CENTER

	var crest := TextureRect.new()
	crest.texture = _get_character_texture("fox")
	crest.custom_minimum_size = Vector2(0, 130)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	page.add_child(crest)

	page.add_child(_label("SPIRITBOUND", 26, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(_label(t("ui.account_welcome"), 15, JADE, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(_label(t("ui.account_prompt"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var field := LineEdit.new()
	field.placeholder_text = t("ui.account_placeholder")
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.max_length = 16
	field.custom_minimum_size = Vector2(0, 52)
	field.text = str(profile.get("account", {}).get("name", ""))
	if font_cjk: field.add_theme_font_override("font", font_cjk)
	field.add_theme_font_size_override("font_size", 16)
	field.add_theme_color_override("font_color", TEXT)
	field.add_theme_stylebox_override("normal", _panel(Color("10242b"), 12, Color("2a4d55")))
	field.add_theme_stylebox_override("focus", _panel(Color("14303a"), 12, JADE))
	page.add_child(field)

	page.add_child(_button(t("ui.account_start"), func(): _create_account(field.text), EMBER, Vector2(0, 50)))

	page.add_child(_label(t("ui.auth_or_continue"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var auth_row := HBoxContainer.new()
	auth_row.add_theme_constant_override("separation", 8)

	var apple_btn := _button("Apple", func():
		var chosen_name := field.text.strip_edges()
		if chosen_name.is_empty(): chosen_name = "灵界探险家"
		_create_account(chosen_name)
		SpiritAuth.sign_in_with_apple(self, func(_ok, _p): show_map())
	, Color("080808"), Vector2(0, 42))
	apple_btn.name = "SignInWithAppleBtn"
	apple_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apple_icon := TextureRect.new()
	apple_icon.texture = load("res://assets/icons/icon_apple.png")
	apple_icon.custom_minimum_size = Vector2(18, 18)
	apple_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	apple_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	apple_icon.position = Vector2(10, 12)
	apple_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apple_btn.add_child(apple_icon)
	auth_row.add_child(apple_btn)

	var google_btn := _button("Google", func():
		var chosen_name := field.text.strip_edges()
		if chosen_name.is_empty(): chosen_name = "灵界探险家"
		_create_account(chosen_name)
		SpiritAuth.sign_in_with_google(self, func(_ok, _p): show_map())
	, Color("f0f2f5"), Vector2(0, 42))
	google_btn.name = "SignInWithGoogleBtn"
	google_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	google_btn.add_theme_color_override("font_color", Color("1f1f1f"))
	google_btn.add_theme_color_override("font_hover_color", Color("111111"))
	google_btn.add_theme_color_override("font_pressed_color", Color("000000"))
	var google_icon := TextureRect.new()
	google_icon.texture = load("res://assets/icons/icon_google.png")
	google_icon.custom_minimum_size = Vector2(18, 18)
	google_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	google_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	google_icon.position = Vector2(10, 12)
	google_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	google_btn.add_child(google_icon)
	auth_row.add_child(google_btn)

	page.add_child(auth_row)

	var email_btn := _button(t("ui.auth_email_tab"), func():
		var chosen_name := field.text.strip_edges()
		if not chosen_name.is_empty():
			profile.account.name = chosen_name
		show_auth_modal(func(): show_map())
	, Color("17363e"), Vector2(0, 38))
	email_btn.name = "SignInWithEmailBtn"
	page.add_child(email_btn)

	var lang_btn := _button(t("ui.lang_toggle"), func(): lang = "en" if lang == "zh-Hans" else "zh-Hans"; profile.language = lang; show_account_setup(), Color("17363e"), Vector2(0, 38))
	page.add_child(lang_btn)
	field.grab_focus()

func _create_account(raw_name: String) -> void:
	var chosen := raw_name.strip_edges()
	if chosen.is_empty():
		_toast(t("ui.account_need_name"))
		return
	var account: Dictionary = profile.get("account", SpiritSave.new_account())
	account.name = chosen
	profile.account = account
	SpiritSave.write(profile)
	show_map()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: SpiritSave.write(profile)

func _safe_top() -> int:
	var safe := DisplayServer.get_display_safe_area()
	var win_h := DisplayServer.window_get_size().y
	if win_h > 0 and safe.position.y > 0:
		return int(round(float(safe.position.y) * 844.0 / float(win_h)))
	return 46

func _safe_bottom() -> int:
	var safe := DisplayServer.get_display_safe_area()
	var win_h := DisplayServer.window_get_size().y
	if win_h > 0 and safe.size.y > 0:
		var inset := win_h - (safe.position.y + safe.size.y)
		if inset > 0:
			return int(round(float(inset) * 844.0 / float(win_h)))
	return 22

# See test_seed_override's own comment for why this exists. Every begin_*_battle() function
# calls this instead of inlining Time.get_unix_time_from_system() itself.
func _battle_seed() -> int:
	if test_seed_override >= 0: return test_seed_override
	return int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff

func _clear() -> void:
	screen_generation += 1
	for child in get_children():
		if child is AudioStreamPlayer: continue
		child.queue_free()
	_back_action = Callable()
	_swipe_tracking = false
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	overlay = Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.z_index = 500; root.add_child(overlay)

# iOS-style interactive back: a drag that starts on the left screen edge pops the page.
func _input(event: InputEvent) -> void:
	if _handle_targeting(event): return
	if not _back_action.is_valid(): return
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed; released = not event.pressed; pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed; released = not event.pressed; pos = event.position
	else:
		return

	if pressed:
		_swipe_tracking = pos.x <= 26.0
		_swipe_origin = pos
	elif released and _swipe_tracking:
		_swipe_tracking = false
		var delta: Vector2 = pos - _swipe_origin
		if delta.x > 64.0 and absf(delta.y) < 70.0:
			get_viewport().set_input_as_handled()
			_haptic("tap")
			var action := _back_action
			_back_action = Callable()
			action.call()

func _stat_bar(bar_width: float, bar_height: float, value: int, max_value: int, fill_color: Color, text: String, font_size := 9) -> ProgressBar:
	# ProgressBar draws its own fill, so the ratio survives being laid out by a parent container.
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(bar_width, bar_height)
	bar.size = Vector2(bar_width, bar_height)
	bar.max_value = maxf(1.0, float(max_value))
	bar.value = clampf(float(value), 0.0, float(max_value))
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var radius := int(bar_height / 2.0)
	bar.add_theme_stylebox_override("background", _panel(Color(0.02, 0.06, 0.08, 0.85), radius, Color(0, 0, 0, 0.45)))
	bar.add_theme_stylebox_override("fill", _panel(fill_color, radius))
	if not text.is_empty():
		var lbl := _label(text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(lbl)
	return bar

# Status readout as a coloured chip rather than loose text, so shield/burn/focus are
# distinguishable at a glance during a turn instead of needing to be read.
func _status_chip(glyph: String, amount: int, color: Color, height := 19.0) -> Panel:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(38.0, height)
	chip.size = chip.custom_minimum_size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(color.r * 0.32, color.g * 0.32, color.b * 0.32, 0.94), int(height / 2.0), color)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	var lbl := _label("%s%d" % [glyph, amount], int(height * 0.58), color, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(lbl)
	return chip

func _icon_badge(glyph: String, color: Color, diameter := 42, glyph_size := 20) -> Panel:
	# Equipment and runes ship as glyphs rather than art, so give each one a coloured medallion.
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.size = badge.custom_minimum_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
	style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	var lbl := _label(glyph, glyph_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	return badge

# Same medallion frame as _icon_badge, but drawing a GameIcon (a real little sword/shield/
# pendant silhouette) instead of a Unicode glyph in a label.
func _drawn_icon_badge(kind: String, flourish: String, color: Color, diameter := 44, frame_color := Color.TRANSPARENT) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.size = badge.custom_minimum_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
	style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	var icon := GameIcon.new()
	icon.kind = kind
	icon.flourish = flourish
	icon.icon_color = color
	icon.frame_color = frame_color
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := diameter * 0.16
	icon.offset_left += inset; icon.offset_top += inset; icon.offset_right -= inset; icon.offset_bottom -= inset
	badge.add_child(icon)
	return badge

func _equip_icon_badge(item: Dictionary, color: Color, diameter := 44) -> Panel:
	var item_id: String = str(item.get("id", ""))
	var icon_path := "res://assets/icons/equip_%s.png" % item_id
	if not item_id.is_empty() and ResourceLoader.exists(icon_path):
		var badge := Panel.new()
		badge.custom_minimum_size = Vector2(diameter, diameter)
		badge.size = badge.custom_minimum_size
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
		style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
		badge.add_theme_stylebox_override("panel", style)
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(tr)
		return badge
	return _drawn_icon_badge(str(item.get("icon_kind", "sword")), str(item.get("icon_flourish", "")), color, diameter)

func _rune_icon_badge(rune: Dictionary, color: Color, diameter := 36) -> Panel:
	var rune_id: String = str(rune.get("id", ""))
	var icon_path := "res://assets/icons/rune_%s.png" % rune_id
	if not rune_id.is_empty() and ResourceLoader.exists(icon_path):
		var badge := Panel.new()
		badge.custom_minimum_size = Vector2(diameter, diameter)
		badge.size = badge.custom_minimum_size
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
		style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
		badge.add_theme_stylebox_override("panel", style)
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(tr)
		return badge
	return _sigil_icon_badge(str(rune.get("icon_mark", "sparkle")), color, diameter)

func _sigil_icon_badge(mark: String, color: Color, diameter := 44) -> Panel:
	return _drawn_icon_badge("sigil", mark, color, diameter, color)

func _relic_icon_badge(relic: Dictionary, color: Color, diameter := 44) -> Panel:
	var relic_id: String = str(relic.get("id", ""))
	var icon_path := "res://assets/icons/relic_%s.png" % relic_id
	if not relic_id.is_empty() and ResourceLoader.exists(icon_path):
		var badge := Panel.new()
		badge.custom_minimum_size = Vector2(diameter, diameter)
		badge.size = badge.custom_minimum_size
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := _panel(Color(color.r, color.g, color.b, 0.18), int(diameter / 2.0), color)
		style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
		badge.add_theme_stylebox_override("panel", style)
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(tr)
		return badge
	return _sigil_icon_badge(str(relic.get("icon_mark", "sparkle")), color, diameter)

func _relic_resonance_badge(res: Dictionary, color: Color, diameter := 44) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.size = badge.custom_minimum_size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel(Color(color.r, color.g, color.b, 0.22), int(diameter / 2.0), color)
	style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = str(res.get("icon", "☯"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font_cjk: lbl.add_theme_font_override("font", font_cjk)
	lbl.add_theme_font_size_override("font_size", int(diameter * 0.52))
	lbl.add_theme_color_override("font_color", color)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)
	return badge

func _spacer(h: float = 8.0) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size.y = h
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp

func _create_page(separation := 6) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", _safe_top())
	margin.add_theme_constant_override("margin_bottom", _safe_bottom())
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(margin)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", separation)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(page)
	return page

func _build_audio() -> void:
	map_music = AudioStreamPlayer.new(); map_music.stream = load("res://assets/audio/map_symphony.wav"); map_music.volume_db = -10; add_child(map_music)
	battle_music = AudioStreamPlayer.new(); battle_music.volume_db = -10; add_child(battle_music)
	battle_music_streams = [
		load("res://assets/audio/battle_stage_0.wav"),
		load("res://assets/audio/battle_stage_1.wav"),
		load("res://assets/audio/battle_stage_2.wav"),
		load("res://assets/audio/battle_stage_3.wav"),
		load("res://assets/audio/battle_stage_4.wav"),
	]
	map_music.finished.connect(func(): if not muted: map_music.play())
	battle_music.finished.connect(func(): if not muted: battle_music.play())
	_build_sfx()

func _build_sfx() -> void:
	_sfx_pool.clear()
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		_sfx_pool.append(player)
	
	var sfx_files := [
		"card_play", "card_draw", "attack_slash", "attack_heavy",
		"shield_gain", "heal", "buff", "resonance_combustion",
		"resonance_sunder", "resonance_fortify", "enemy_hit",
		"enemy_defeat", "boss_phase2", "battle_victory",
		"battle_defeat", "coin", "chest_open"
	]
	for sfx_name in sfx_files:
		var path := "res://assets/audio/sfx/sfx_%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			_sfx_cache[sfx_name] = load(path)

func play_sfx(sfx_name: String, pitch_range: float = 0.06, volume_db: float = 0.0) -> void:
	if muted or sfx_muted: return
	var stream: AudioStream = _sfx_cache.get(sfx_name, null)
	if stream == null:
		var path := "res://assets/audio/sfx/sfx_%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			stream = load(path)
			_sfx_cache[sfx_name] = stream
		else:
			return
	if _sfx_pool.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_pool.size()
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	if pitch_range > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	else:
		player.pitch_scale = 1.0
	player.play()

func _play_music(battle := false, stage_level: int = 0) -> void:
	if muted: return
	if battle:
		if map_music != null: map_music.stop()
		var stream_idx: int = clampi(stage_level, 0, battle_music_streams.size() - 1)
		if battle_music_streams.size() > stream_idx and battle_music_streams[stream_idx] != null:
			var target_stream: AudioStream = battle_music_streams[stream_idx]
			if battle_music != null and (battle_music.stream != target_stream or not battle_music.playing):
				battle_music.stream = target_stream
				battle_music.play()
		else:
			if battle_music != null and not battle_music.playing: battle_music.play()
	else:
		if battle_music != null: battle_music.stop()
		if map_music != null and not map_music.playing: map_music.play()

func _panel(color: Color, radius := 12, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = color
	style.corner_radius_top_left = radius; style.corner_radius_top_right = radius; style.corner_radius_bottom_left = radius; style.corner_radius_bottom_right = radius
	if border.a > 0: style.border_width_left = 1; style.border_width_right = 1; style.border_width_top = 1; style.border_width_bottom = 1; style.border_color = border
	return style

func _label(text: String, size := 14, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, autowrap := false) -> Label:
	var value := Label.new(); value.text = text
	if font_cjk: value.add_theme_font_override("font", font_cjk)
	# Godot has no first-party hook into the OS's own Dynamic Type setting, so this multiplier
	# (Settings' Text Size control, TEXT_SCALE_OPTIONS) is a self-contained approximation
	# instead — every label in the game is built through this one function, so scaling here
	# reaches every screen without a per-callsite change.
	value.add_theme_font_size_override("font_size", int(round(size * float(profile.get("text_scale", 1.0)))))
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = align
	if autowrap: value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else: value.autowrap_mode = TextServer.AUTOWRAP_OFF
	return value

func _bind_touch_guard(btn: Button, callback: Callable, slop: float = 14.0) -> void:
	if not callback.is_valid(): return
	var state := {
		"press_start": Vector2.ZERO,
		"drag_cancelled": false
	}
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventScreenTouch or (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
			if ev.pressed:
				state.press_start = ev.position
				state.drag_cancelled = false
		elif ev is InputEventScreenDrag or ev is InputEventMouseMotion:
			if not bool(state.drag_cancelled) and (ev.position - Vector2(state.press_start)).length() > slop:
				state.drag_cancelled = true
	)
	btn.pressed.connect(func():
		if bool(state.drag_cancelled):
			state.drag_cancelled = false
			return
		if TouchScrollContainer.is_any_dragging:
			return
		if TouchScrollContainer.last_drag_finish_msec > 0 and Time.get_ticks_msec() - TouchScrollContainer.last_drag_finish_msec < 220:
			return
		callback.call()
	)

func _button(text: String, callback: Callable, color := PANEL, min_size := Vector2(0,44)) -> Button:
	var value := Button.new(); value.text = text; value.custom_minimum_size = min_size
	if font_cjk: value.add_theme_font_override("font", font_cjk)
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", TEXT)
	value.add_theme_stylebox_override("normal", _panel(color, 10, GOLD))
	value.add_theme_stylebox_override("hover", _panel(color.lightened(.1), 10, JADE))
	value.add_theme_stylebox_override("pressed", _panel(color.darkened(.12), 10, EMBER))
	value.add_theme_stylebox_override("disabled", _panel(color.darkened(.3), 10, Color("3a4a50")))
	if callback.is_valid():
		_bind_touch_guard(value, callback)
	return value

func _texture(path: String) -> Texture2D:
	return load("res://assets/%s" % path)

func _background(file: String, opacity := .42) -> TextureRect:
	var image := TextureRect.new(); image.texture = _texture("backgrounds/%s" % file); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.modulate = Color(1,1,1,opacity); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _currency_pill(icon_tex: Texture2D, amount: int, color: Color, on_click := Callable()) -> Control:
	var pill := Button.new()
	pill.focus_mode = Control.FOCUS_NONE
	var normal_box := _panel(Color("0d1e23"), 10, Color(color.r, color.g, color.b, 0.45))
	normal_box.content_margin_left = 6; normal_box.content_margin_right = 8
	normal_box.content_margin_top = 2; normal_box.content_margin_bottom = 2
	var hover_box := _panel(Color("152c34"), 10, color)
	hover_box.content_margin_left = 6; hover_box.content_margin_right = 8
	hover_box.content_margin_top = 2; hover_box.content_margin_bottom = 2
	pill.add_theme_stylebox_override("normal", normal_box)
	pill.add_theme_stylebox_override("hover", hover_box)
	pill.add_theme_stylebox_override("pressed", _panel(Color("081316"), 10, color))
	pill.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	if icon_tex != null:
		var ico := TextureRect.new()
		ico.texture = icon_tex
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.custom_minimum_size = Vector2(14, 14)
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ico)
	var lbl := _label("%d" % amount, 11, color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	if on_click.is_valid():
		_bind_touch_guard(pill, on_click)
	else:
		_bind_touch_guard(pill, func(): show_treasury_inspector())
	return pill

func _header(title: String, subtitle: String, back := Callable()) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 56
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.add_theme_constant_override("separation", 0)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Left side: Logo (map only) + Back button (if present) + Stats box (HP & Gold)
	var left_box := HBoxContainer.new()
	left_box.name = "HeaderLeftBox"
	left_box.add_theme_constant_override("separation", 4)
	left_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if title == "SPIRITBOUND":
		# Map header: logo with currency capsules tucked underneath it, left-aligned.
		var logo_stack := VBoxContainer.new()
		logo_stack.name = "HeaderLogoStack"
		logo_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
		logo_stack.add_theme_constant_override("separation", 2)
		logo_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var logo := TextureRect.new()
		logo.name = "SpiritboundLogo"
		var logo_tex: Texture2D = load("res://assets/ui/spiritbound_logo.png")
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(168.0, 52.0)
		logo.size = logo.custom_minimum_size
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo_stack.add_child(logo)

		var gold_row := HBoxContainer.new()
		gold_row.name = "HeaderGoldRow"
		gold_row.add_theme_constant_override("separation", 5)
		gold_row.alignment = BoxContainer.ALIGNMENT_BEGIN

		var gold_pill := _currency_pill(load("res://assets/icons/hud_gold.png"), int(profile.gold), GOLD)
		gold_row.add_child(gold_pill)

		var jade_pill := _currency_pill(load("res://assets/icons/hud_jade.png"), int(profile.get("spirit_jade", 10)), Color("78e9c0"))
		gold_row.add_child(jade_pill)

		_ensure_stamina_current()
		var stamina_pill := _currency_pill(load("res://assets/icons/hud_stamina.png"), int(profile.get("stamina", {}).get("current", 100)), Color("5ec5ff"), func(): show_stamina_modal())
		stamina_pill.name = "HeaderStaminaPill"
		gold_row.add_child(stamina_pill)

		if int(profile.get("spirit_dust", 0)) > 0:
			var dust_pill := _currency_pill(load("res://assets/icons/hud_dust.png"), int(profile.get("spirit_dust", 0)), Color("c79bff"))
			gold_row.add_child(dust_pill)

		logo_stack.add_child(gold_row)

		left_box.add_child(logo_stack)
	else:
		if back.is_valid():
			var back_btn := _button("‹", back, Color("17363e"), Vector2(34, 34))
			back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			left_box.add_child(back_btn)

		var stats_box := HBoxContainer.new()
		stats_box.name = "HeaderStatsBox"
		stats_box.add_theme_constant_override("separation", 5)
		stats_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var hp_pill := _currency_pill(load("res://assets/icons/hud_heart.png"), int(profile.health), TEXT)
		stats_box.add_child(hp_pill)

		var gold_pill2 := _currency_pill(load("res://assets/icons/hud_gold.png"), int(profile.gold), GOLD)
		stats_box.add_child(gold_pill2)

		_ensure_stamina_current()
		var stamina_pill2 := _currency_pill(load("res://assets/icons/hud_stamina.png"), int(profile.get("stamina", {}).get("current", 100)), Color("5ec5ff"), func(): show_stamina_modal())
		stamina_pill2.name = "HeaderStaminaPill2"
		stats_box.add_child(stamina_pill2)

		left_box.add_child(stats_box)
	bar.add_child(left_box)

	# Center expand-fill spacer (title text for non-logo screens)
	var copy := VBoxContainer.new()
	copy.name = "HeaderCenterBox"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title != "SPIRITBOUND":
		if title != "":
			copy.add_child(_label(title, 16, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		if subtitle != "":
			copy.add_child(_label(subtitle, 10, JADE, HORIZONTAL_ALIGNMENT_CENTER, true))
	bar.add_child(copy)

	# Right spacer placeholder (replaced by map header buttons in game_map_screen.gd)
	var right_spacer := Control.new()
	right_spacer.name = "HeaderRightSpacer"
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(right_spacer)

	return bar

# Thin delegators onto MapScreen (scripts/game_map_screen.gd) — kept here under their
# original names because both other game.gd code and ui_smoke.gd call them directly on
# `game`/`self`, and because SpiritGame's screen transitions call each other by bare name
# (show_map() -> show_camp() -> show_quests() -> ...); see MapScreen's own header comment for
# why this is composition (a `g` back-reference) rather than inheritance.
func show_map() -> void:
	current_screen_name = "map"
	await _map_screen.show_map()
func show_chapter_transition(cleared_ch: int, next_ch: int, on_complete := Callable()) -> void: await _map_screen.show_chapter_transition(cleared_ch, next_ch, on_complete)
func _travel_to(index: int) -> void: await _map_screen._travel_to(index)
func _has_claimable_quest() -> bool: return _map_screen._has_claimable_quest()
func _has_claimable_camp_reward() -> bool: return _map_screen._has_claimable_camp_reward()
func _claimable_reward_count() -> int: return _map_screen._claimable_reward_count()
func _chapter_waypoints(chapter: int) -> Array: return _map_screen._chapter_waypoints(chapter)
func _chapter_has_unique_art(chapter: int) -> bool: return _map_screen._chapter_has_unique_art(chapter)
func _get_chapter_map_texture(chapter: int) -> Texture2D: return _map_screen._get_chapter_map_texture(chapter)
func _map_point(index: int) -> Vector2: return _map_screen._map_point(index)
func _build_road_curve(points: PackedVector2Array) -> Curve2D: return _map_screen._build_road_curve(points)
func _get_road_texture() -> NoiseTexture2D: return _map_screen._get_road_texture()
func _get_terrain_wash_texture(tint_index: int) -> GradientTexture2D: return _map_screen._get_terrain_wash_texture(tint_index)
func _add_notification_dot(anchor: Control, btn_size: Vector2) -> void: _map_screen._add_notification_dot(anchor, btn_size)
func _clipboard_set(text: String) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)
	clipboard_cache = text
func _clipboard_get() -> String:
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return DisplayServer.clipboard_get()
	return clipboard_cache

func _toast(message: String, color := TEXT) -> void:
	if overlay == null: return
	var toast := _label(message, 14, color, HORIZONTAL_ALIGNMENT_CENTER)
	toast.position = Vector2(65, 110); toast.size = Vector2(260, 40)
	toast.add_theme_stylebox_override("normal", _panel(Color("153d42"), 14, color))
	overlay.add_child(toast)
	var tween := create_tween(); tween.tween_property(toast,"position:y",86,.22); tween.tween_interval(.95); tween.tween_property(toast,"modulate:a",0.0,.35); tween.tween_callback(toast.queue_free)

# Thin delegators onto BattleScreen (scripts/game_battle_screen.gd) — see MapScreen's header
# comment (game_map_screen.gd) for why composition rather than inheritance, and game.gd's own
# MapScreen delegator block above for why these keep their original bare names.
func _modifier(seed: int, stage: int) -> Dictionary: return _battle_screen._modifier(seed, stage)
func begin_battle(index: int) -> void: _battle_screen.begin_battle(index)
func show_battle() -> void: _battle_screen.show_battle()
func _apply_card_foil(node: CanvasItem, rarity: String, upgraded: bool) -> void: _battle_screen._apply_card_foil(node, rarity, upgraded)
func _build_player_stage() -> Control: return _battle_screen._build_player_stage()
func _flash_hit(sprite: CanvasItem, color := Color.WHITE, duration := 0.22) -> void: _battle_screen._flash_hit(sprite, color, duration)
func _animate_player_curse() -> void: await _battle_screen._animate_player_curse()
func _animate_player_shield_gain(amount: int) -> void: await _battle_screen._animate_player_shield_gain(amount)
func _apply_status_fx(unit: Control, sprite: Node2D, sprite_center: Vector2, sprite_radius: float, state: Dictionary) -> void: _battle_screen._apply_status_fx(unit, sprite, sprite_center, sprite_radius, state)
func _card_is_attack(card: Dictionary) -> bool: return _battle_screen._card_is_attack(card)
func _card_target_mode(card: Dictionary) -> String: return _battle_screen._card_target_mode(card)
func _living_enemies() -> Array: return _battle_screen._living_enemies()
func _tap_card(hand_index: int) -> void: _battle_screen._tap_card(hand_index)
func _modal_backdrop(node_name: String, on_dismiss: Callable) -> Button: return _battle_screen._modal_backdrop(node_name, on_dismiss)
func _show_info_popup(icon: Control, title: String, detail: String, accent: Color) -> void: _battle_screen._show_info_popup(icon, title, detail, accent)
func _clear_info_popup() -> void: _battle_screen._clear_info_popup()
func _tutorial_next_step() -> void: _battle_screen._tutorial_next_step()
func _tutorial_prev_step() -> void: _battle_screen._tutorial_prev_step()
func _finish_tutorial() -> void: _battle_screen._finish_tutorial()
func _clear_hold_preview() -> void: _battle_screen._clear_hold_preview()
func _big_card_face(card: Dictionary, rune_id: String) -> Panel: return _battle_screen._big_card_face(card, rune_id)
func _handle_targeting(event: InputEvent) -> bool: return _battle_screen._handle_targeting(event)
func _predict_damage(card: Dictionary, enemy_index: int) -> Dictionary: return _battle_screen._predict_damage(card, enemy_index)
func _show_damage_preview(card: Dictionary, enemy_index: int) -> void: _battle_screen._show_damage_preview(card, enemy_index)
func _clear_damage_preview() -> void: _battle_screen._clear_damage_preview()
func _show_cancel_zone(active: bool) -> void: _battle_screen._show_cancel_zone(active)
func show_pile_inspector(title_key: String, pile: Array) -> void: _battle_screen.show_pile_inspector(title_key, pile)
func _shake_screen(intensity: float, duration := 0.24) -> void: _battle_screen._shake_screen(intensity, duration)
func _show_valid_targets(mode: String) -> void: _battle_screen._show_valid_targets(mode)
func _clear_valid_targets() -> void: _battle_screen._clear_valid_targets()
func _attempt_play_card(hand_index: int, target: int) -> bool: return _battle_screen._attempt_play_card(hand_index, target)
func _maybe_end_turn() -> void: await _battle_screen._maybe_end_turn()
func _animate_finishing_blow(box: Control, sprite: Node2D) -> void: await _battle_screen._animate_finishing_blow(box, sprite)
func _enemy_turn() -> void: await _battle_screen._enemy_turn()
func _animate_enemy_action(box: Control, kind: String, enemy_state: Dictionary) -> void: await _battle_screen._animate_enemy_action(box, kind, enemy_state)
func _combat_event(kind: String, payload: Dictionary) -> void: _battle_screen._combat_event(kind, payload)
func _show_boss_phase_banner(title: String, subtitle: String) -> void: _battle_screen._show_boss_phase_banner(title, subtitle)
func _leave_battle() -> void: _battle_screen._leave_battle()
func _show_hold_preview(card: Dictionary) -> void: _battle_screen._show_hold_preview(card)
func _set_enemy_targeted(enemy_index: int, targeted: bool) -> void: _battle_screen._set_enemy_targeted(enemy_index, targeted)
# Computed properties, not plain delegator functions, because ui_smoke.gd reads/advances
# these as data (game.tutorial_step, game.TUTORIAL_STEPS) rather than calling a method.
var tutorial_step: int:
	get: return _battle_screen.tutorial_step
	set(value): _battle_screen.tutorial_step = value
var TUTORIAL_STEPS: Array[String]:
	get: return _battle_screen.TUTORIAL_STEPS

# Thin delegators onto RewardsScreen (scripts/game_rewards_screen.gd) — see MapScreen's
# header comment (game_map_screen.gd) for why composition rather than inheritance.
func show_reward() -> void: _rewards_screen.show_reward()
func _is_replay(index: int) -> bool: return _rewards_screen._is_replay(index)
func _is_stage_event_claimed(index: int) -> bool: return _rewards_screen._is_stage_event_claimed(index)
func _mark_stage_event_claimed(index: int) -> void: _rewards_screen._mark_stage_event_claimed(index)
func _compendium_dict(category: String) -> Dictionary: return _rewards_screen._compendium_dict(category)
func _mark_discovered(category: String, key: String) -> bool: return _rewards_screen._mark_discovered(category, key)
func _grant_bestiary_discovery_bonus(encounter: Dictionary) -> void: _rewards_screen._grant_bestiary_discovery_bonus(encounter)
func _card_discovered(id: String) -> bool: return _rewards_screen._card_discovered(id)
func _equip_discovered(id: String) -> bool: return _rewards_screen._equip_discovered(id)
func _rune_discovered(id: String) -> bool: return _rewards_screen._rune_discovered(id)
func _relic_discovered(id: String) -> bool: return _rewards_screen._relic_discovered(id)
func _bestiary_discovered(enemy_name: String) -> bool: return _rewards_screen._bestiary_discovered(enemy_name)
func _compendium_totals() -> Vector2i: return _rewards_screen._compendium_totals()
func _grant_mastery_xp(amount: int) -> void: _rewards_screen._grant_mastery_xp(amount)
func _current_hero_mastery_bonuses() -> Dictionary: return _rewards_screen._current_hero_mastery_bonuses()
func _current_encounter() -> Dictionary: return _rewards_screen._current_encounter()
func _current_stage_label() -> String: return _rewards_screen._current_stage_label()
func _grant_stage_rewards() -> void: _rewards_screen._grant_stage_rewards()
func _finish_reward() -> void: _rewards_screen._finish_reward()
func show_reward_details() -> void: _rewards_screen.show_reward_details()
func show_battle_log() -> void: _rewards_screen.show_battle_log()
func show_run_recap() -> void: _rewards_screen.show_run_recap()
func _build_recap_poster_control(recap_data: Dictionary) -> Control: return _rewards_screen._build_recap_poster_control(recap_data)
func _capture_recap_image(recap_data: Dictionary) -> Image: return await _rewards_screen._capture_recap_image(recap_data)
func _export_recap_poster(recap_data: Dictionary) -> String: return await _rewards_screen._export_recap_poster(recap_data)
func _collect_card(card: Dictionary) -> void: _rewards_screen._collect_card(card)
func _smart_add_card(card: Dictionary) -> void: _rewards_screen._smart_add_card(card)
func show_event(index: int, kind: String) -> void: _rewards_screen.show_event(index, kind)
func _reward_card_row(card: Dictionary) -> Control: return _rewards_screen._reward_card_row(card)

# Thin delegators onto ShopDeckScreen (scripts/game_shop_deck_screen.gd) — see MapScreen's
# header comment (game_map_screen.gd) for why composition rather than inheritance.
func show_deck_purge(return_callback: Callable, cost := 0, on_done := Callable()) -> void: _shop_deck_screen.show_deck_purge(return_callback, cost, on_done)
func show_deck_upgrade(return_callback: Callable, on_done := Callable()) -> void: _shop_deck_screen.show_deck_upgrade(return_callback, on_done)
func _shop_period() -> Dictionary: return _shop_deck_screen._shop_period()
func _shop_price(card: Dictionary, owned: int) -> int: return _shop_deck_screen._shop_price(card, owned)
func show_shop() -> void:
	current_screen_name = "shop"
	_shop_deck_screen.show_shop()
func _card_art_panel(card_id: String, art_size: Vector2, radius := 8) -> Control: return _shop_deck_screen._card_art_panel(card_id, art_size, radius)
func _cost_badge(cost: int, accent: Color, diameter := 26) -> Panel: return _shop_deck_screen._cost_badge(cost, accent, diameter)
func _add_ornate_frame(tile: Control, size: Vector2, accent: Color, rarity: String = "Common") -> void: _shop_deck_screen._add_ornate_frame(tile, size, accent, rarity)
func _rarity_star_row(rarity: String, color := GOLD, align := BoxContainer.ALIGNMENT_CENTER) -> HBoxContainer: return _shop_deck_screen._rarity_star_row(rarity, color, align)
func show_deck() -> void:
	current_screen_name = "deck"
	_shop_deck_screen.show_deck()
func _card_build_score(card: Dictionary) -> float: return _shop_deck_screen._card_build_score(card)
func _auto_build_deck() -> void: _shop_deck_screen._auto_build_deck()
func _tab_bar(tabs: Array, active: String, on_pick: Callable) -> Control: return _shop_deck_screen._tab_bar(tabs, active, on_pick)
func show_loadout() -> void: _shop_deck_screen.show_loadout()
func show_reforge_modal(item_id: String) -> void: _shop_deck_screen.show_reforge_modal(item_id)
var SHOP_STOCK_COUNT: int:
	get: return _shop_deck_screen.SHOP_STOCK_COUNT

# Thin delegators onto CampScreen (scripts/game_camp_screen.gd) — see MapScreen's header
# comment (game_map_screen.gd) for why composition rather than inheritance.
func show_compendium() -> void:
	current_screen_name = "compendium"
	_camp_screen.show_compendium()
func _claim_compendium_milestone(target: int) -> void: _camp_screen._claim_compendium_milestone(target)
func _equip(item: Dictionary) -> void: _camp_screen._equip(item)
func _socket(card_id: String) -> void: _camp_screen._socket(card_id)
func _format_countdown(target_unix: int) -> String: return _camp_screen._format_countdown(target_unix)
func show_quests() -> void:
	current_screen_name = "quests"
	_camp_screen.show_quests()
func show_camp() -> void:
	current_screen_name = "camp"
	_camp_screen.show_camp()
func show_challenges() -> void: _camp_screen.show_challenges()
func begin_daily_trial() -> void: _camp_screen.begin_daily_trial()
func begin_weekly_challenge() -> void: _camp_screen.begin_weekly_challenge()
func begin_boss_rush_battle() -> void: _camp_screen.begin_boss_rush_battle()
# Pre-existing gap, not introduced by Phase 10: begin_abyss_battle() had no delegator at all,
# so it was only ever reachable via a button callback bound inside game_camp_screen.gd itself
# — uncallable as `game.begin_abyss_battle()` from any other file, tests included, until now.
func begin_abyss_battle() -> void: _camp_screen.begin_abyss_battle()
func begin_curse_run_battle() -> void: _camp_screen.begin_curse_run_battle()
func begin_world_event_battle() -> void: _camp_screen.begin_world_event_battle()
func begin_sandbox_battle(stage: int) -> void: _camp_screen.begin_sandbox_battle(stage)
func show_abyss_boon_draft() -> void: _camp_screen.show_abyss_boon_draft()
func show_season_pass() -> void: _camp_screen.show_season_pass()
func show_spirit_draft() -> void: _camp_screen.show_spirit_draft()
func begin_phantom_arena() -> void: _camp_screen.begin_phantom_arena()
func show_leaderboard(category: String = "abyss") -> void: _camp_screen.show_leaderboard(category)

func _submit_abyss_record(floor_num: int) -> void:
	if floor_num <= 0: return
	var p_name: String = str(profile.get("name", ""))
	if p_name.is_empty(): p_name = str(profile.get("account", {}).get("username", ""))
	var char_id: String = str(profile.get("hero_class", "fox_spirit"))
	if char_id.begins_with("fox"): char_id = "fox"
	elif char_id.begins_with("sentinel"): char_id = "sentinel"
	elif char_id.begins_with("ironclad"): char_id = "ironclad"
	elif char_id.begins_with("miasma"): char_id = "miasma_witch"
	elif char_id.begins_with("crane"): char_id = "crane"
	elif char_id.begins_with("phoenix"): char_id = "phoenix"
	SupabaseClient.submit_score("abyss", floor_num, p_name, char_id, {"boons": profile.get("abyss_boons", [])}, self)

func _submit_daily_trial_record(stage_num: int) -> void:
	if stage_num <= 0: return
	var p_name: String = str(profile.get("name", ""))
	if p_name.is_empty(): p_name = str(profile.get("account", {}).get("username", ""))
	var char_id: String = str(profile.get("hero_class", "fox_spirit"))
	if char_id.begins_with("fox"): char_id = "fox"
	elif char_id.begins_with("sentinel"): char_id = "sentinel"
	elif char_id.begins_with("ironclad"): char_id = "ironclad"
	elif char_id.begins_with("miasma"): char_id = "miasma_witch"
	elif char_id.begins_with("crane"): char_id = "crane"
	elif char_id.begins_with("phoenix"): char_id = "phoenix"
	var streak: int = int(profile.daily_trial_record.get("streak", 0))
	var score: int = stage_num * 1000 + streak * 100
	SupabaseClient.submit_score("daily_trial", score, p_name, char_id, {"stage": stage_num, "streak": streak}, self)

func _submit_samsara_record(samsara_count: int) -> void:
	if samsara_count <= 0: return
	var p_name: String = str(profile.get("name", ""))
	if p_name.is_empty(): p_name = str(profile.get("account", {}).get("username", ""))
	var char_id: String = str(profile.get("hero_class", "fox_spirit"))
	if char_id.begins_with("fox"): char_id = "fox"
	elif char_id.begins_with("sentinel"): char_id = "sentinel"
	elif char_id.begins_with("ironclad"): char_id = "ironclad"
	elif char_id.begins_with("miasma"): char_id = "miasma_witch"
	elif char_id.begins_with("crane"): char_id = "crane"
	elif char_id.begins_with("phoenix"): char_id = "phoenix"
	var score: int = samsara_count * 10 + int(profile.get("difficulty", 0))
	SupabaseClient.submit_score("samsara", score, p_name, char_id, {"cycles": samsara_count, "unlocked": int(profile.get("unlocked", 0))}, self)

func show_meridian_modal() -> void: _camp_screen.show_meridian_modal()

func upgrade_meridian_node(node_id: String) -> bool:
	var cur_allocated: Dictionary = profile.get("meridians", {}).duplicate()
	var cur_rank: int = int(cur_allocated.get(node_id, 0))
	var cost: int = content.meridian_cost(node_id, cur_rank)
	if cost < 0:
		return false
	var cur_dust: int = int(profile.get("spirit_dust", 0))
	if cur_dust < cost:
		_toast(t("ui.insufficient_dust"), Color("ff7070"))
		return false
	profile.spirit_dust = cur_dust - cost
	cur_allocated[node_id] = cur_rank + 1
	profile.meridians = cur_allocated
	SpiritSave.write(profile)
	var node_name := content.meridian_name(node_id, lang)
	_toast(tf("ui.meridian_upgrade_toast", [node_name, cur_rank + 1]), GOLD)
	return true

func reset_meridians() -> int:
	var cur_allocated: Dictionary = profile.get("meridians", {}).duplicate()
	var total_refund: int = content.meridian_total_spent(cur_allocated)
	if total_refund <= 0 and cur_allocated.is_empty():
		return 0
	profile.meridians = {}
	profile.spirit_dust = int(profile.get("spirit_dust", 0)) + total_refund
	SpiritSave.write(profile)
	_toast(tf("ui.meridian_reset_toast", total_refund), JADE)
	return total_refund

func _modal_dialog(node_name: String, on_dismiss: Callable = Callable()) -> Control:
	# z_index only ever affects render order in Godot — never GUI input dispatch order, which
	# follows scene-tree sibling order alone. `overlay` is added to `self.root` once, up front,
	# in _clear() (before any screen content exists), so every screen's own page content ends
	# up LATER in root's children than overlay — meaning it silently wins every tap over
	# whatever the overlay holds, even though overlay's z_index draws it on top. Moving overlay
	# to be root's last child right before opening a modal is what actually gives it input
	# priority; without this, any interactive element in the screen underneath a modal that
	# happens to sit at the same position (the map's stage pins and header buttons, in
	# particular) silently swallows every tap meant for the modal itself.
	self.root.move_child(overlay, self.root.get_child_count() - 1)
	var root := Control.new()
	root.name = node_name
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 600

	var dim := Color("040a0c"); dim.a = 0.72
	var dim_btn := Button.new()
	dim_btn.name = "ModalBackdropDim"
	dim_btn.flat = true
	dim_btn.focus_mode = Control.FOCUS_NONE
	dim_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_btn.add_theme_stylebox_override("normal", _panel(dim, 0))
	dim_btn.add_theme_stylebox_override("hover", _panel(dim, 0))
	dim_btn.add_theme_stylebox_override("pressed", _panel(dim, 0))
	dim_btn.add_theme_stylebox_override("focus", _panel(dim, 0))
	if on_dismiss.is_valid():
		dim_btn.pressed.connect(on_dismiss)
	root.add_child(dim_btn)
	overlay.add_child(root)
	return root

func _maybe_show_tutorial(tutorial_id: String) -> void:
	if profile.get("tutorials_seen", {}).get(tutorial_id, false): return
	if overlay == null or overlay.get_child_count() > 0: return
	var title_key := "tutorial.%s.title" % tutorial_id
	var desc_key := "tutorial.%s.desc" % tutorial_id
	var title_text: String = content.ui(title_key, lang)
	var desc_text: String = content.ui(desc_key, lang)
	if title_text == title_key: return
	if not profile.has("tutorials_seen") or not profile.tutorials_seen is Dictionary:
		profile.tutorials_seen = {}
	profile.tutorials_seen[tutorial_id] = true
	SpiritSave.write(profile)

	var modal_name := "FeatureTutorial_%s" % tutorial_id
	var modal := _modal_dialog(modal_name, func():
		var m: Node = overlay.get_node_or_null(modal_name)
		if m != null:
			if m.get_parent(): m.get_parent().remove_child(m)
			m.queue_free()
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 200)
	panel.add_theme_stylebox_override("panel", _panel(Color("0c1a20"), 14, GOLD))
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 16)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 14)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	pad.add_child(vbox)

	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/nav_quest.png")
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr.add_child(icon)
	var t_lbl := _label(title_text, 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	hdr.add_child(t_lbl)
	vbox.add_child(hdr)

	var d_lbl := _label(desc_text, 12, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_lbl.custom_minimum_size.x = 290
	vbox.add_child(d_lbl)

	var ok_btn := _button(content.ui("tutorial.understood", lang), func():
		if modal != null and modal.is_inside_tree():
			if modal.get_parent(): modal.get_parent().remove_child(modal)
			modal.queue_free()
	, Color("1d4a40"), Vector2(130, 38))
	ok_btn.name = "TutorialUnderstoodBtn"
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(ok_btn)

func _treasury_row(icon_name: String, title_str: String, balance: int, color: Color, desc_str: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("102128"), 10, color.darkened(0.4)))
	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 10)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 6)
	panel.add_child(pad)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	pad.add_child(hbox)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s" % icon_name)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	hbox.add_child(v)

	var tr := HBoxContainer.new()
	tr.add_child(_label(title_str, 12, color))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tr.add_child(sp)
	tr.add_child(_label("%d" % balance, 13, color))
	v.add_child(tr)
	v.add_child(_label(desc_str, 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	return panel

func show_treasury_inspector() -> void:
	var existing: Node = overlay.get_node_or_null("TreasuryInspectorModal")
	if existing:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()
		return

	var modal := _modal_dialog("TreasuryInspectorModal", func():
		var m: Node = overlay.get_node_or_null("TreasuryInspectorModal")
		if m != null:
			if m.get_parent(): m.get_parent().remove_child(m)
			m.queue_free()
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 420)
	panel.add_theme_stylebox_override("panel", _panel(Color("0c1a20"), 14, GOLD))
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 14)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	title_box.add_child(_label(t("ui.treasury_title"), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	title_box.add_child(_label(t("ui.treasury_sub"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(title_box)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	vbox.add_child(list)

	list.add_child(_treasury_row("hud_gold.png", t("ui.currency_gold"), int(profile.gold), GOLD, t("ui.treasury_gold_desc")))
	list.add_child(_treasury_row("hud_jade.png", t("ui.currency_jade"), int(profile.get("spirit_jade", 10)), Color("78e9c0"), t("ui.treasury_jade_desc")))
	list.add_child(_treasury_row("hud_dust.png", t("ui.currency_dust"), int(profile.get("spirit_dust", 0)), Color("c79bff"), t("ui.treasury_dust_desc")))
	_ensure_stamina_current()
	list.add_child(_treasury_row("hud_stamina.png", t("ui.stamina_name"), int(profile.get("stamina", {}).get("current", 100)), Color("5ec5ff"), t("ui.stamina_desc")))

	var conv_box := VBoxContainer.new()
	conv_box.add_theme_constant_override("separation", 6)
	vbox.add_child(conv_box)

	var can_dust: bool = int(profile.gold) >= 80
	var btn_gold_dust := _button(t("ui.treasury_convert_gold_dust"), func():
		if int(profile.gold) < 80:
			_toast(t("ui.convert_insufficient"))
			return
		profile.gold -= 80
		profile.spirit_dust = int(profile.get("spirit_dust", 0)) + 35
		SpiritSave.write(profile)
		_toast(t("ui.convert_success"), JADE)
		_haptic("tap")
		if modal != null and modal.is_inside_tree():
			if modal.get_parent(): modal.get_parent().remove_child(modal)
			modal.queue_free()
		show_treasury_inspector()
	, Color("1f3b39") if can_dust else Color("222a2e"), Vector2(0, 34))
	btn_gold_dust.name = "TreasuryConvertDustBtn"
	btn_gold_dust.disabled = not can_dust
	conv_box.add_child(btn_gold_dust)

	var can_gold: bool = int(profile.get("spirit_jade", 0)) >= 10
	var btn_jade_gold := _button(t("ui.treasury_convert_jade_gold"), func():
		if int(profile.get("spirit_jade", 0)) < 10:
			_toast(t("ui.convert_insufficient"))
			return
		profile.spirit_jade = int(profile.get("spirit_jade", 0)) - 10
		profile.gold = int(profile.gold) + 150
		SpiritSave.write(profile)
		_toast(t("ui.convert_success"), GOLD)
		_haptic("tap")
		if modal != null and modal.is_inside_tree():
			if modal.get_parent(): modal.get_parent().remove_child(modal)
			modal.queue_free()
		show_treasury_inspector()
	, Color("352d1c") if can_gold else Color("222a2e"), Vector2(0, 34))
	btn_jade_gold.name = "TreasuryConvertGoldBtn"
	btn_jade_gold.disabled = not can_gold
	conv_box.add_child(btn_jade_gold)

	var can_rech_stam: bool = int(profile.get("spirit_jade", 0)) >= 10
	var btn_rech_stam := _button(t("ui.stamina_recharge_btn"), func():
		if recharge_stamina_with_jade(10, 50):
			_toast(t("ui.stamina_recharge_success"), Color("5ec5ff"))
			_haptic("heavy")
			if modal != null and modal.is_inside_tree():
				if modal.get_parent(): modal.get_parent().remove_child(modal)
				modal.queue_free()
			show_treasury_inspector()
		else:
			_toast(t("ui.stamina_recharge_no_jade"), Color("ff7070"))
	, Color("1a3d4d") if can_rech_stam else Color("222a2e"), Vector2(0, 34))
	btn_rech_stam.name = "TreasuryRechargeStaminaBtn"
	btn_rech_stam.disabled = not can_rech_stam
	conv_box.add_child(btn_rech_stam)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 8)
	vbox.add_child(nav_row)

	var to_shop := _button(t("ui.treasury_goto_shop"), func():
		if modal != null and modal.is_inside_tree():
			if modal.get_parent(): modal.get_parent().remove_child(modal)
			modal.queue_free()
		shop_tab = "curated"
		show_shop()
	, Color("1d4a40"), Vector2(0, 34))
	to_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_row.add_child(to_shop)

	var to_exchange := _button(t("ui.treasury_goto_exchange"), func():
		if modal != null and modal.is_inside_tree():
			if modal.get_parent(): modal.get_parent().remove_child(modal)
			modal.queue_free()
		shop_tab = "exchange"
		show_shop()
	, Color("34204d"), Vector2(0, 34))
	to_exchange.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_row.add_child(to_exchange)

	var close_btn := _button(t("tutorial.understood"), func():
		if modal != null and modal.is_inside_tree():
			if modal.get_parent(): modal.get_parent().remove_child(modal)
			modal.queue_free()
	, Color("16282e"), Vector2(110, 32))
	close_btn.name = "TreasuryCloseBtn"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_btn)

func enter_samsara() -> void:
	var prev: int = int(profile.get("samsara_count", 0))
	# Mirrors _samsara_section()'s own gate (which controls whether SamsaraEnterBtn is even
	# reachable) so this stays correct even if something ever calls this directly without going
	# through that button — the required tier escalates with every cycle so a player can't just
	# repeat the same tier indefinitely once it stops being the hardest one unlocked.
	if not (int(profile.unlocked) >= 250 and int(profile.difficulty) >= (5 + prev)): return
	var new_count: int = prev + 1
	profile.samsara_count = new_count
	var s_bonuses: Dictionary = content.samsara_bonuses(new_count)
	profile.gold = int(profile.get("gold", 0)) + int(s_bonuses.get("starting_gold", 0))
	profile.unlocked = 0
	profile.position = 0
	profile.claimed_stage_events = []
	# Not bonus-adjusted: every other battle-end site in the game (win/loss/leave, across every
	# mode) flatly resets this same field to 60 regardless of hero mastery or samsara max_hp
	# bonuses (begin_battle() always passes a hardcoded 60 into combat.create() too — the real
	# bonus is layered on top there via hero_bonuses, never through this display-only field), so
	# a bonus-adjusted value here would just silently drop back to a plain 60 the moment the
	# player finished their very next battle of any kind.
	profile.health = 60
	SpiritSave.write(profile)
	_advance_quest("samsara", 1)
	_refresh_achievements()
	_submit_samsara_record(new_count)
	var realm_title := content.samsara_title(new_count, lang)
	_toast(tf("ui.samsara_toast_success", realm_title), GOLD)
	show_camp()

func show_samsara_modal() -> void:
	var existing: Node = overlay.get_node_or_null("SamsaraModal")
	if existing:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()
		return

	var modal := _modal_dialog("SamsaraModal", func():
		var m: Node = overlay.get_node_or_null("SamsaraModal")
		if m != null:
			if m.get_parent(): m.get_parent().remove_child(m)
			m.queue_free()
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "SamsaraModalPanel"
	panel.custom_minimum_size = Vector2(340, 440)
	panel.add_theme_stylebox_override("panel", _panel(Color("0d171d"), 14, JADE))
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 14)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pad.add_child(vbox)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 3)
	title_box.add_child(_label(t("ui.samsara_modal_title"), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var cur_count: int = int(profile.get("samsara_count", 0))
	var next_count: int = cur_count + 1
	var cur_realm := content.samsara_title(cur_count, lang)
	var next_realm := content.samsara_title(next_count, lang)
	title_box.add_child(_label("%s -> %s" % [cur_realm, next_realm], 11, JADE, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(title_box)

	var lore_panel := PanelContainer.new()
	lore_panel.add_theme_stylebox_override("panel", _panel(Color("13222a"), 8, Color("1f3944")))
	var lore_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: lore_pad.add_theme_constant_override("margin_%s" % s, 8)
	lore_panel.add_child(lore_pad)
	lore_pad.add_child(_label(t("ui.samsara_modal_lore"), 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	vbox.add_child(lore_panel)

	var details_box := VBoxContainer.new()
	details_box.add_theme_constant_override("separation", 6)
	details_box.add_child(_label(t("ui.samsara_modal_kept"), 9, Color("8af0a0"), HORIZONTAL_ALIGNMENT_LEFT, true))
	details_box.add_child(_label(t("ui.samsara_modal_reset"), 9, Color("ffd080"), HORIZONTAL_ALIGNMENT_LEFT, true))
	details_box.add_child(_label(t("ui.samsara_modal_gain"), 9, Color("70dcff"), HORIZONTAL_ALIGNMENT_LEFT, true))
	vbox.add_child(details_box)

	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 4)
	preview_box.add_child(_label(t("ui.samsara_active_blessings"), 10, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var next_bonuses: Dictionary = content.samsara_bonuses(next_count)
	if next_bonuses.max_hp > 0:
		preview_box.add_child(_label(tf("ui.samsara_blessing_hp", next_bonuses.max_hp), 9, JADE))
	if next_bonuses.starting_shield > 0:
		preview_box.add_child(_label(tf("ui.samsara_blessing_shield", next_bonuses.starting_shield), 9, Color("68c5ff")))
	if next_bonuses.turn1_draw > 0:
		preview_box.add_child(_label(tf("ui.samsara_blessing_draw", next_bonuses.turn1_draw), 9, Color("ffd860")))
	if next_bonuses.starting_gold > 0:
		preview_box.add_child(_label(tf("ui.samsara_blessing_gold", next_bonuses.starting_gold), 9, GOLD))
	vbox.add_child(preview_box)

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 8)
	var cancel_btn := _button(t("ui.cancel"), func():
		var m: Node = overlay.get_node_or_null("SamsaraModal")
		if m != null:
			if m.get_parent(): m.get_parent().remove_child(m)
			m.queue_free()
	, MUTED, Vector2(100, 38))
	cancel_btn.name = "SamsaraCancelBtn"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_box.add_child(cancel_btn)

	var confirm_btn := _button(t("ui.samsara_confirm_btn"), func():
		var m: Node = overlay.get_node_or_null("SamsaraModal")
		if m != null:
			if m.get_parent(): m.get_parent().remove_child(m)
			m.queue_free()
		enter_samsara()
	, Color("963228"), Vector2(180, 38))
	confirm_btn.name = "SamsaraConfirmBtn"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_box.add_child(confirm_btn)
	vbox.add_child(btn_box)

func show_settings() -> void:
	var existing: Node = overlay.get_node_or_null("SettingsModal")
	if existing:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()
		return

	var modal := _modal_dialog("SettingsModal", func(): _close_settings())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	var vp_w: int = int(get_viewport_rect().size.x)
	panel.custom_minimum_size = Vector2(mini(320, vp_w - 32), 0)
	var panel_style := _panel(Color("0e1d22"), 14, GOLD)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	var max_h: int = mini(520, int(get_viewport_rect().size.y) - 60)
	scroll.custom_minimum_size = Vector2(mini(288, vp_w - 64), max_h)
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	# Header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	list.add_child(head)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(_label(t("ui.settings_title"), 16, GOLD))
	title_box.add_child(_label(t("ui.settings_sub"), 9, MUTED))
	head.add_child(title_box)

	var close_btn := _button("✕", func(): _close_settings(), Color("1c333a"), Vector2(36, 36))
	close_btn.name = "SettingsCloseBtn"
	head.add_child(close_btn)

	# 1. Language Option
	var lang_box := VBoxContainer.new()
	lang_box.add_theme_constant_override("separation", 6)
	lang_box.add_child(_label(t("ui.settings_lang"), 12, TEXT))
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	var is_zh: bool = lang == "zh-Hans"
	var zh_btn := _button("简体中文", func(): _change_language("zh-Hans"), JADE if is_zh else Color("1c333a"), Vector2(0, 36))
	zh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var en_btn := _button("English", func(): _change_language("en"), JADE if not is_zh else Color("1c333a"), Vector2(0, 36))
	en_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(zh_btn)
	lang_row.add_child(en_btn)
	lang_box.add_child(lang_row)
	list.add_child(lang_box)

	# 2. Battle Speed Option
	var speed_box := VBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 6)
	speed_box.add_child(_label(t("ui.settings_speed"), 12, TEXT))
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	for sp in [1.0, 1.5, 2.0]:
		var is_active := is_equal_approx(battle_speed, sp)
		var sp_btn := _button("%.1fx" % sp, func(): _change_battle_speed(sp), Color("d95d37") if is_active else Color("1c333a"), Vector2(0, 36))
		sp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speed_row.add_child(sp_btn)
	speed_box.add_child(speed_row)
	list.add_child(speed_box)

	# 3. Audio / Music Option
	var audio_box := VBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 6)
	audio_box.add_child(_label(t("ui.settings_audio"), 12, TEXT))
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 8)
	var music_btn := _button(t("ui.settings_audio_on") if not muted else t("ui.settings_audio_off"), func(): _toggle_music_settings(), JADE if not muted else Color("2c333a"), Vector2(0, 36))
	music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_child(music_btn)
	var sfx_btn := _button(t("ui.settings_sfx_on") if not sfx_muted else t("ui.settings_sfx_off"), func(): _toggle_sfx_settings(), JADE if not sfx_muted else Color("2c333a"), Vector2(0, 36))
	sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_child(sfx_btn)
	audio_box.add_child(audio_row)
	list.add_child(audio_box)

	# 4. Reduce Motion Option
	var motion_box := VBoxContainer.new()
	motion_box.add_theme_constant_override("separation", 4)
	motion_box.add_child(_label(t("ui.settings_reduce_motion"), 12, TEXT))
	motion_box.add_child(_label(t("ui.settings_reduce_motion_desc"), 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var motion_active: bool = bool(profile.get("reduce_motion", false))
	var motion_btn := _button(t("ui.settings_on") if motion_active else t("ui.settings_off"), func(): _toggle_reduce_motion(), EMBER if motion_active else Color("1c333a"), Vector2(0, 36))
	motion_btn.name = "ReduceMotionToggleBtn"
	motion_box.add_child(motion_btn)
	list.add_child(motion_box)

	# 4b. Text Size Option (accessibility)
	var text_size_box := VBoxContainer.new()
	text_size_box.add_theme_constant_override("separation", 6)
	text_size_box.add_child(_label(t("ui.settings_text_size"), 12, TEXT))
	var text_size_row := HBoxContainer.new()
	text_size_row.add_theme_constant_override("separation", 8)
	var current_text_scale: float = float(profile.get("text_scale", 1.0))
	for ts in TEXT_SCALE_OPTIONS:
		var is_ts_active := is_equal_approx(current_text_scale, ts)
		var ts_btn := _button(_text_scale_label(ts), func(): _change_text_scale(ts), JADE if is_ts_active else Color("1c333a"), Vector2(0, 36))
		# Node names can't contain "." (Godot silently rewrites it to "_" anyway) — spelled out
		# explicitly here rather than relying on that silent rewrite.
		ts_btn.name = "TextScaleBtn_%s" % String.num(ts, 2).replace(".", "_")
		ts_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_size_row.add_child(ts_btn)
	text_size_box.add_child(text_size_row)
	list.add_child(text_size_box)

	# 5. Account & Cloud Save Option
	var account_box := VBoxContainer.new()
	account_box.add_theme_constant_override("separation", 6)
	account_box.add_child(_label(t("ui.settings_account"), 12, GOLD))
	account_box.add_child(_label(t("ui.settings_account_desc"), 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var is_linked := SpiritSave.is_cloud_linked(profile)
	var provider: String = SpiritSave.account_provider(profile)

	if not is_linked:
		var status_lbl := _label(t("ui.auth_status_guest"), 10, Color("e09c48"))
		account_box.add_child(status_lbl)

		var open_auth_btn := _button(t("ui.auth_modal_title"), func():
			_close_settings()
			show_auth_modal(func(): show_settings())
		, JADE, Vector2(0, 42))
		open_auth_btn.name = "OpenAuthModalBtn"
		account_box.add_child(open_auth_btn)

		# Apple Login Button (Authentic iOS dark style with Apple logo)
		var apple_btn := _button(t("ui.auth_apple"), func():
			SpiritAuth.sign_in_with_apple(self, func(_ok, _p):
				_close_settings()
				show_settings()
			)
		, Color("080808"), Vector2(0, 42))
		apple_btn.name = "SignInWithAppleBtn"
		var apple_icon := TextureRect.new()
		apple_icon.texture = load("res://assets/icons/icon_apple.png")
		apple_icon.custom_minimum_size = Vector2(20, 20)
		apple_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		apple_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		apple_icon.position = Vector2(14, 11)
		apple_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		apple_btn.add_child(apple_icon)
		account_box.add_child(apple_btn)

		# Google Login Button (Authentic light style with Google 4-color 'G')
		var google_btn := _button(t("ui.auth_google"), func():
			SpiritAuth.sign_in_with_google(self, func(_ok, _p):
				_close_settings()
				show_settings()
			)
		, Color("f0f2f5"), Vector2(0, 42))
		google_btn.name = "SignInWithGoogleBtn"
		google_btn.add_theme_color_override("font_color", Color("1f1f1f"))
		google_btn.add_theme_color_override("font_hover_color", Color("111111"))
		google_btn.add_theme_color_override("font_pressed_color", Color("000000"))
		var google_icon := TextureRect.new()
		google_icon.texture = load("res://assets/icons/icon_google.png")
		google_icon.custom_minimum_size = Vector2(20, 20)
		google_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		google_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		google_icon.position = Vector2(14, 11)
		google_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		google_btn.add_child(google_icon)
		account_box.add_child(google_btn)
	else:
		var account_info: Dictionary = profile.get("account", {})
		var email_str: String = str(account_info.get("email", ""))
		var uid_str: String = str(account_info.get("user_id", ""))
		var display_id: String = email_str if not email_str.is_empty() else uid_str.substr(0, 16)
		var linked_text: String = ""
		if provider == "apple":
			linked_text = tf("ui.auth_linked_apple", display_id)
		elif provider == "google":
			linked_text = tf("ui.auth_linked_google", display_id)
		else:
			linked_text = tf("ui.auth_linked_supabase", display_id)

		var linked_lbl := _label(linked_text, 10, JADE)
		account_box.add_child(linked_lbl)

		var sync_row := HBoxContainer.new()
		sync_row.add_theme_constant_override("separation", 8)

		var sync_btn := _button(t("ui.auth_cloud_sync_now"), func():
			SpiritAuth.sync_cloud_save(self)
		, Color("1a3d34"), Vector2(0, 38))
		sync_btn.name = "CloudSyncBtn"
		sync_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sync_row.add_child(sync_btn)

		var signout_btn := _button(t("ui.auth_sign_out"), func():
			SpiritAuth.sign_out(self, func(_ok):
				_close_settings()
				show_settings()
			)
		, Color("3d1f1f"), Vector2(0, 38))
		signout_btn.name = "SignOutBtn"
		signout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sync_row.add_child(signout_btn)

		account_box.add_child(sync_row)

	# 4c. Cinematic Intro Video Replay
	var intro_box := VBoxContainer.new()
	intro_box.add_theme_constant_override("separation", 6)
	intro_box.add_child(_label(t("ui.settings_replay_intro"), 12, TEXT))
	var replay_intro_btn := _button(t("ui.settings_replay_intro"), func():
		_close_settings()
		play_intro_cutscene(func():
			show_settings()
		)
	, Color("17363e"), Vector2(0, 36))
	replay_intro_btn.name = "ReplayIntroBtn"
	replay_intro_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_box.add_child(replay_intro_btn)
	list.add_child(intro_box)

	list.add_child(account_box)

func play_intro_cutscene(on_done: Callable = Callable()) -> IntroCutscene:
	var old_intro: Node = get_node_or_null("IntroCutscene")
	if old_intro != null:
		old_intro.queue_free()

	if map_music != null and map_music.playing:
		map_music.stop()

	var cutscene := IntroCutscene.new()
	cutscene.name = "IntroCutscene"
	cutscene.setup(lang, func():
		if on_done.is_valid():
			on_done.call()
	)
	add_child(cutscene)
	return cutscene

func _close_settings() -> void:
	if overlay == null: return
	var existing: Node = overlay.get_node_or_null("SettingsModal")
	if existing:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

func show_auth_modal(on_success: Callable = Callable()) -> void:
	if overlay == null: return
	var existing: Node = overlay.get_node_or_null("AuthModal")
	if existing != null:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

	var modal := _modal_dialog("AuthModal", func(): _close_auth_modal())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	var vp_w: int = int(get_viewport_rect().size.x)
	panel.custom_minimum_size = Vector2(mini(340, vp_w - 24), 0)
	var panel_style := _panel(Color("0c1a1e"), 14, GOLD)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header
	var head := HBoxContainer.new()
	var title_lbl := _label(t("ui.auth_modal_title"), 16, GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	var close_btn := _button("✕", func(): _close_auth_modal(), Color("1c333a"), Vector2(34, 34))
	close_btn.name = "AuthCloseBtn"
	head.add_child(close_btn)
	vbox.add_child(head)

	# Mode state: false = login, true = signup
	var is_signup_mode := {"value": false}

	# Tab switch row
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	var tab_login := _button(t("ui.auth_email_tab"), Callable(), JADE, Vector2(0, 36))
	tab_login.name = "AuthTabLogin"
	tab_login.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tab_signup := _button(t("ui.auth_signup_tab"), Callable(), Color("17363e"), Vector2(0, 36))
	tab_signup.name = "AuthTabSignup"
	tab_signup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(tab_login)
	tab_row.add_child(tab_signup)
	vbox.add_child(tab_row)

	# Input fields
	var email_input := LineEdit.new()
	email_input.name = "AuthEmailInput"
	email_input.placeholder_text = t("ui.auth_email_placeholder")
	email_input.custom_minimum_size = Vector2(0, 44)
	if font_cjk: email_input.add_theme_font_override("font", font_cjk)
	email_input.add_theme_font_size_override("font_size", 14)
	email_input.add_theme_color_override("font_color", TEXT)
	email_input.add_theme_stylebox_override("normal", _panel(Color("10242b"), 10, Color("2a4d55")))
	email_input.add_theme_stylebox_override("focus", _panel(Color("14303a"), 10, JADE))
	vbox.add_child(email_input)

	var pass_input := LineEdit.new()
	pass_input.name = "AuthPasswordInput"
	pass_input.placeholder_text = t("ui.auth_password_placeholder")
	pass_input.secret = true
	pass_input.custom_minimum_size = Vector2(0, 44)
	if font_cjk: pass_input.add_theme_font_override("font", font_cjk)
	pass_input.add_theme_font_size_override("font_size", 14)
	pass_input.add_theme_color_override("font_color", TEXT)
	pass_input.add_theme_stylebox_override("normal", _panel(Color("10242b"), 10, Color("2a4d55")))
	pass_input.add_theme_stylebox_override("focus", _panel(Color("14303a"), 10, JADE))
	vbox.add_child(pass_input)

	var name_input := LineEdit.new()
	name_input.name = "AuthNameInput"
	name_input.placeholder_text = t("ui.auth_name_placeholder")
	name_input.custom_minimum_size = Vector2(0, 44)
	if font_cjk: name_input.add_theme_font_override("font", font_cjk)
	name_input.add_theme_font_size_override("font_size", 14)
	name_input.add_theme_color_override("font_color", TEXT)
	name_input.add_theme_stylebox_override("normal", _panel(Color("10242b"), 10, Color("2a4d55")))
	name_input.add_theme_stylebox_override("focus", _panel(Color("14303a"), 10, JADE))
	name_input.visible = false
	name_input.text = str(profile.get("account", {}).get("name", ""))
	vbox.add_child(name_input)

	var hint_lbl := _label("", 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	hint_lbl.name = "AuthHintLabel"
	vbox.add_child(hint_lbl)

	# Submit button
	var submit_btn := _button(t("ui.auth_btn_login"), Callable(), EMBER, Vector2(0, 46))
	submit_btn.name = "AuthSubmitBtn"
	vbox.add_child(submit_btn)

	var update_mode = func(signup: bool):
		is_signup_mode["value"] = signup
		name_input.visible = signup
		tab_login.add_theme_stylebox_override("normal", _panel(JADE if not signup else Color("17363e"), 8))
		tab_signup.add_theme_stylebox_override("normal", _panel(JADE if signup else Color("17363e"), 8))
		submit_btn.text = t("ui.auth_btn_signup") if signup else t("ui.auth_btn_login")
		hint_lbl.text = ""

	tab_login.pressed.connect(func(): update_mode.call(false))
	tab_signup.pressed.connect(func(): update_mode.call(true))

	submit_btn.pressed.connect(func():
		var email_val := email_input.text.strip_edges()
		var pass_val := pass_input.text
		if email_val.is_empty() or not email_val.contains("@") or pass_val.length() < 6:
			hint_lbl.text = t("ui.auth_invalid_input")
			return
		hint_lbl.text = t("ui.auth_syncing")
		if is_signup_mode["value"]:
			var name_val := name_input.text.strip_edges()
			if name_val.is_empty(): name_val = "驭灵者"
			SpiritAuth.sign_up_with_supabase(self, email_val, pass_val, name_val, func(ok: bool, res_code: String):
				if ok:
					if res_code == "supabase":
						_close_auth_modal()
						if on_success.is_valid(): on_success.call()
					else:
						hint_lbl.text = t("ui.auth_signup_check_email")
				else:
					hint_lbl.text = t("ui.auth_rate_limited")
			)
		else:
			SpiritAuth.sign_in_with_supabase(self, email_val, pass_val, func(ok: bool, _prov: String):
				if ok:
					_close_auth_modal()
					if on_success.is_valid(): on_success.call()
				else:
					hint_lbl.text = t("ui.auth_invalid_input")
			)
	)

	# Quick OAuth divider
	vbox.add_child(_label(t("ui.auth_or_continue"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var oauth_row := HBoxContainer.new()
	oauth_row.add_theme_constant_override("separation", 8)

	var apple_btn := _button("Apple", func():
		SpiritAuth.sign_in_with_apple(self, func(ok, _p):
			if ok:
				_close_auth_modal()
				if on_success.is_valid(): on_success.call()
		)
	, Color("080808"), Vector2(0, 40))
	apple_btn.name = "AuthAppleBtn"
	apple_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var apple_icon := TextureRect.new()
	apple_icon.texture = load("res://assets/icons/icon_apple.png")
	apple_icon.custom_minimum_size = Vector2(16, 16)
	apple_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	apple_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	apple_icon.position = Vector2(8, 12)
	apple_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apple_btn.add_child(apple_icon)
	oauth_row.add_child(apple_btn)

	var google_btn := _button("Google", func():
		SpiritAuth.sign_in_with_google(self, func(ok, _p):
			if ok:
				_close_auth_modal()
				if on_success.is_valid(): on_success.call()
		)
	, Color("f0f2f5"), Vector2(0, 40))
	google_btn.name = "AuthGoogleBtn"
	google_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	google_btn.add_theme_color_override("font_color", Color("1f1f1f"))
	google_btn.add_theme_color_override("font_hover_color", Color("111111"))
	google_btn.add_theme_color_override("font_pressed_color", Color("000000"))
	var google_icon := TextureRect.new()
	google_icon.texture = load("res://assets/icons/icon_google.png")
	google_icon.custom_minimum_size = Vector2(16, 16)
	google_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	google_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	google_icon.position = Vector2(8, 12)
	google_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	google_btn.add_child(google_icon)
	oauth_row.add_child(google_btn)

	vbox.add_child(oauth_row)

	# Forgot password helper
	var forgot_btn := _button(t("ui.auth_btn_forgot"), func():
		var email_val := email_input.text.strip_edges()
		if email_val.is_empty() or not email_val.contains("@"):
			hint_lbl.text = t("ui.auth_email_placeholder")
			return
		SpiritAuth.reset_password(self, email_val, func(_ok):
			hint_lbl.text = t("ui.auth_reset_sent")
		)
	, Color("142226"), Vector2(0, 32))
	forgot_btn.name = "AuthForgotBtn"
	vbox.add_child(forgot_btn)

func _close_auth_modal() -> void:
	if overlay == null: return
	var existing: Node = overlay.get_node_or_null("AuthModal")
	if existing != null:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

func _change_language(new_lang: String) -> void:
	lang = new_lang
	profile.language = lang
	SpiritSave.write(profile)
	_close_settings()
	match current_screen_name:
		"camp": show_camp()
		"quests": show_quests()
		"shop": show_shop()
		"deck": show_deck()
		"compendium": show_compendium()
		_: await show_map()
	show_settings()

func _change_battle_speed(new_speed: float) -> void:
	battle_speed = new_speed
	profile.battle_speed = battle_speed
	SpiritSave.write(profile)
	if root != null and is_instance_valid(root):
		var speed_btn: Button = root.find_child("SpeedToggle", true, false) as Button
		if speed_btn != null and is_instance_valid(speed_btn):
			var speed_label: String = (str(int(battle_speed)) if battle_speed == float(int(battle_speed)) else str(battle_speed)) + "x"
			speed_btn.text = speed_label
	if auto_battle_active and not resolving and combat != null and combat.state.phase == "player":
		_battle_screen._maybe_step_auto_battle()
	_close_settings()
	show_settings()


func _toggle_music_settings() -> void:
	muted = not muted
	profile.music_muted = muted
	SpiritSave.write(profile)
	if muted: map_music.stop(); battle_music.stop()
	else: _play_music(false)
	_close_settings()
	show_settings()

func _toggle_sfx_settings() -> void:
	sfx_muted = not sfx_muted
	profile.sfx_muted = sfx_muted
	SpiritSave.write(profile)
	_close_settings()
	show_settings()

func _toggle_reduce_motion() -> void:
	var current: bool = bool(profile.get("reduce_motion", false))
	profile.reduce_motion = not current
	SpiritSave.write(profile)
	_close_settings()
	show_settings()

func _text_scale_label(scale_value: float) -> String:
	if is_equal_approx(scale_value, TEXT_SCALE_OPTIONS[0]): return t("ui.settings_text_size_small")
	if is_equal_approx(scale_value, TEXT_SCALE_OPTIONS[2]): return t("ui.settings_text_size_large")
	if is_equal_approx(scale_value, TEXT_SCALE_OPTIONS[3]): return t("ui.settings_text_size_xlarge")
	return t("ui.settings_text_size_normal")

func _change_text_scale(scale_value: float) -> void:
	profile.text_scale = scale_value
	SpiritSave.write(profile)
	_close_settings()
	show_settings()

func _ensure_phantom_arena_current() -> void:
	var today_idx: int = int(Time.get_unix_time_from_system()) / DAY_SECONDS
	if not profile.has("phantom_arena") or not (profile.phantom_arena is Dictionary):
		profile.phantom_arena = {"day": today_idx, "wins_today": 0, "claimed_today": false}
	elif int(profile.phantom_arena.get("day", -1)) != today_idx:
		profile.phantom_arena.day = today_idx
		profile.phantom_arena.wins_today = 0
		profile.phantom_arena.claimed_today = false

func get_idle_harvest_rate() -> int:
	return 10 + int(profile.unlocked) * 2

func get_idle_harvest_unclaimed_seconds() -> int:
	var harvest: Dictionary = profile.get("idle_harvest", {})
	var last_time: int = int(harvest.get("last_claim_time", 0))
	var now: int = int(Time.get_unix_time_from_system())
	if last_time <= 0:
		last_time = now
		harvest.last_claim_time = now
		profile.idle_harvest = harvest
	var diff: int = maxi(0, now - last_time)
	return mini(diff, 12 * 3600)

func get_idle_harvest_unclaimed_gold() -> int:
	var secs := get_idle_harvest_unclaimed_seconds()
	var rate := get_idle_harvest_rate()
	return int((float(secs) / 3600.0) * float(rate))

func claim_idle_harvest() -> int:
	var gold_gain := get_idle_harvest_unclaimed_gold()
	var harvest: Dictionary = profile.get("idle_harvest", {})
	harvest.last_claim_time = int(Time.get_unix_time_from_system())
	profile.idle_harvest = harvest
	if gold_gain > 0:
		profile.gold += gold_gain
		SpiritSave.write(profile)
		_toast(tf("ui.idle_harvest_toast", gold_gain), GOLD)
	return gold_gain

func fast_idle_harvest() -> int:
	var harvest: Dictionary = profile.get("idle_harvest", {})
	var today_idx: int = int(Time.get_unix_time_from_system()) / DAY_SECONDS
	var last_day: int = int(harvest.get("last_fast_claim_day", -1))
	if last_day == today_idx:
		_toast(t("ui.idle_harvest_fast_done"), MUTED)
		return 0
	harvest.last_fast_claim_day = today_idx
	profile.idle_harvest = harvest
	var burst_gold: int = get_idle_harvest_rate() * 2
	profile.gold += burst_gold
	SpiritSave.write(profile)
	_toast(tf("ui.idle_harvest_fast_toast", burst_gold), GOLD)
	return burst_gold

func _ensure_stamina_current() -> void:
	if not profile.has("stamina") or not profile.stamina is Dictionary:
		profile.stamina = {"current": 100, "max": 100, "last_regen_time": 0}
	var now: int = int(Time.get_unix_time_from_system())
	var cur: int = int(profile.stamina.get("current", 100))
	var max_val: int = int(profile.stamina.get("max", 100))
	var last_time: int = int(profile.stamina.get("last_regen_time", 0))
	if last_time <= 0:
		profile.stamina.last_regen_time = now
		return
	if cur < max_val:
		var elapsed: int = maxi(0, now - last_time)
		var added: int = elapsed / 300 # 1 point per 300 seconds (5 min)
		if added > 0:
			profile.stamina.current = mini(max_val, cur + added)
			profile.stamina.last_regen_time = now - (elapsed % 300)
			SpiritSave.write(profile)
	else:
		profile.stamina.last_regen_time = now

func can_spend_stamina(cost: int = 5) -> bool:
	_ensure_stamina_current()
	return int(profile.stamina.get("current", 100)) >= cost

func spend_stamina(cost: int = 5) -> bool:
	if not can_spend_stamina(cost): return false
	profile.stamina.current = int(profile.stamina.current) - cost
	SpiritSave.write(profile)
	return true

func recharge_stamina_with_jade(cost_jade: int = 10, gain_stamina: int = 50) -> bool:
	if int(profile.get("spirit_jade", 0)) < cost_jade: return false
	profile.spirit_jade = int(profile.get("spirit_jade", 0)) - cost_jade
	_ensure_stamina_current()
	profile.stamina.current = mini(150, int(profile.stamina.get("current", 100)) + gain_stamina)
	SpiritSave.write(profile)
	return true

func show_stamina_modal() -> void:
	_ensure_stamina_current()
	var existing: Node = overlay.get_node_or_null("StaminaModal")
	if existing:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()
		return

	var modal := _modal_dialog("StaminaModal", func():
		var m: Node = overlay.get_node_or_null("StaminaModal")
		if m != null:
			if m.get_parent(): m.get_parent().remove_child(m)
			m.queue_free()
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 260)
	panel.add_theme_stylebox_override("panel", _panel(Color("0b1820"), 14, Color("5ec5ff")))
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 16)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 14)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pad.add_child(vbox)

	vbox.add_child(_label(t("ui.stamina_title"), 16, Color("5ec5ff"), HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(_label(t("ui.stamina_desc"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var cur: int = int(profile.stamina.get("current", 100))
	var max_val: int = int(profile.stamina.get("max", 100))
	var val_lbl := _label("%d / %d" % [cur, max_val], 26, Color("76e5ff"), HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(val_lbl)

	var status_text := ""
	if cur >= max_val:
		status_text = t("ui.stamina_full")
	else:
		var last_time: int = int(profile.stamina.get("last_regen_time", 0))
		var now: int = int(Time.get_unix_time_from_system())
		var rem_sec: int = maxi(0, 300 - ((now - last_time) % 300))
		status_text = tf("ui.stamina_next_regen", "%02d:%02d" % [rem_sec / 60, rem_sec % 60])
	vbox.add_child(_label(status_text, 11, JADE, HORIZONTAL_ALIGNMENT_CENTER))

	var can_recharge: bool = int(profile.get("spirit_jade", 0)) >= 10
	var rech_btn := _button(t("ui.stamina_recharge_btn"), func():
		if recharge_stamina_with_jade(10, 50):
			_toast(t("ui.stamina_recharge_success"), Color("5ec5ff"))
			_haptic("heavy")
			if modal != null and modal.is_inside_tree():
				if modal.get_parent(): modal.get_parent().remove_child(modal)
				modal.queue_free()
			show_stamina_modal()
		else:
			_toast(t("ui.stamina_recharge_no_jade"), Color("ff7070"))
	, Color("1a3d4d") if can_recharge else Color("222a2e"), Vector2(0, 42))
	rech_btn.name = "StaminaRechargeBtn"
	rech_btn.disabled = not can_recharge
	vbox.add_child(rech_btn)

func toggle_auto_battle(enable: Variant = null) -> void:
	if enable == null:
		auto_battle_active = not auto_battle_active
	else:
		auto_battle_active = bool(enable)
	if auto_battle_active:
		_toast(t("ui.auto_battle_active"), GOLD)
	else:
		_toast(t("ui.auto_stop_manual"), MUTED)

func stop_auto_battle(reason: String = "") -> void:
	if not auto_battle_active: return
	auto_battle_active = false
	match reason:
		"defeat":
			_toast(t("ui.auto_stop_defeat"), Color("ff4d3d"))
		"stamina":
			_toast(t("ui.auto_stop_stamina"), Color("ffbb33"))
		_:
			_toast(t("ui.auto_stop_manual"), MUTED)
	if int(auto_battle_stats.get("stages_cleared", 0)) > 0:
		_toast(tf("ui.auto_summary_toast", [int(auto_battle_stats.stages_cleared), int(auto_battle_stats.gold_earned)]), JADE)
	auto_battle_stats = {"stages_cleared": 0, "gold_earned": 0}

func show_idle_harvest_modal() -> void:
	var existing: Node = overlay.get_node_or_null("IdleHarvestModal")
	if existing:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

	var modal := _modal_dialog("IdleHarvestModal", func():
		var ex: Node = overlay.get_node_or_null("IdleHarvestModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var panel_style := _panel(Color("0c1a1f"), 16, GOLD)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)

	var head := HBoxContainer.new()
	var title_lbl := _label(t("ui.idle_harvest_title"), 16, GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	var close_btn := _button("✕", func():
		var ex: Node = overlay.get_node_or_null("IdleHarvestModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
	, Color("1c333a"), Vector2(32, 32))
	close_btn.name = "IdleHarvestCloseBtn"
	head.add_child(close_btn)
	list.add_child(head)

	list.add_child(_label(t("ui.idle_harvest_sub"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var info_box := PanelContainer.new()
	info_box.add_theme_stylebox_override("panel", _panel(Color("132830"), 10, Color("2f5663")))
	var info_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: info_pad.add_theme_constant_override("margin_%s" % s, 10)
	info_box.add_child(info_pad)
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 6)
	info_pad.add_child(info_vbox)

	var rate_lbl := _label(tf("ui.idle_harvest_rate_fmt", get_idle_harvest_rate()), 13, JADE)
	info_vbox.add_child(rate_lbl)

	var acc_gold := get_idle_harvest_unclaimed_gold()
	var acc_lbl := _label(tf("ui.idle_harvest_acc_fmt", acc_gold), 14, Color("ffe17d"))
	acc_lbl.name = "IdleHarvestAccLabel"
	info_vbox.add_child(acc_lbl)

	var cap_lbl := _label(tf("ui.idle_harvest_cap_fmt", int(get_idle_harvest_unclaimed_seconds() / 3600)), 11, MUTED)
	info_vbox.add_child(cap_lbl)
	list.add_child(info_box)

	var claim_btn := _button(t("ui.idle_harvest_claim"), func():
		var ex: Node = overlay.get_node_or_null("IdleHarvestModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		claim_idle_harvest()
		show_idle_harvest_modal()
	, GOLD, Vector2(0, 42))
	claim_btn.name = "IdleHarvestClaimBtn"
	claim_btn.disabled = acc_gold <= 0
	list.add_child(claim_btn)

	var today_idx: int = int(Time.get_unix_time_from_system()) / DAY_SECONDS
	var harvest_dict: Dictionary = profile.get("idle_harvest", {})
	var fast_claimed: bool = int(harvest_dict.get("last_fast_claim_day", -1)) == today_idx
	var fast_btn := _button(t("ui.idle_harvest_fast_done") if fast_claimed else t("ui.idle_harvest_fast"), func():
		var ex: Node = overlay.get_node_or_null("IdleHarvestModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		fast_idle_harvest()
		show_idle_harvest_modal()
	, EMBER, Vector2(0, 40))
	fast_btn.name = "IdleHarvestFastBtn"
	fast_btn.disabled = fast_claimed
	list.add_child(fast_btn)

func diagnose_battle_defeat() -> Dictionary:
	var total_cost := 0
	var shield_cards := 0
	for card_id in profile.deck:
		var card: Dictionary = content.card(str(card_id))
		total_cost += int(card.get("cost", 1))
		var is_shield := false
		for eff in card.get("effects", []):
			if str(eff.get("operation", "")) == "shield":
				is_shield = true
				break
		if is_shield:
			shield_cards += 1
	var avg_cost: float = float(total_cost) / maxf(1.0, float(profile.deck.size()))
	var boss_encounter: Dictionary = content.encounters[current_stage] if current_stage < content.encounters.size() else {}
	var mechanics: Dictionary = boss_encounter.get("mechanics", {})
	if mechanics.has("thorns"):
		return {"tip": t("ui.defeat_diag_boss_thorns"), "action": "deck"}
	if mechanics.has("shield_per_turn") and int(mechanics.get("shield_per_turn", 0)) >= 5:
		return {"tip": t("ui.defeat_diag_boss_armor"), "action": "deck"}
	if avg_cost > 1.8:
		return {"tip": tf("ui.defeat_diag_high_cost", avg_cost), "action": "deck"}
	if shield_cards < 3:
		return {"tip": tf("ui.defeat_diag_low_shield", shield_cards), "action": "deck"}
	return {"tip": t("ui.defeat_diag_general"), "action": "cultivate"}

func _on_pin_pressed(index: int) -> void:
	if _is_replay(index) and content.node_kind(index) in ["battle", "elite", "boss", "greatboss"]:
		_show_replay_mode_prompt(index)
	else:
		_travel_to(index)

# Shown when tapping a pin for a stage already cleared (index < profile.unlocked) — a
# cleared stage can no longer be re-entered at all (see ui.stage_purified_desc), so this is
# purely informational plus three shortcuts to the places that actually grant more gold/
# progress once you're stuck: Cultivate (AFK harvest), Tune Deck, and Phantom Arena.
func _show_replay_mode_prompt(_index: int) -> void:
	var existing: Node = overlay.get_node_or_null("ReplayModal")
	if existing:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

	var modal := _modal_dialog("ReplayModal", func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var panel_style := _panel(Color("0f1e23"), 14, Color("34626d"))
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)

	# Header with title and close button
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title_lbl := _label(t("ui.stage_purified_title"), 15, JADE)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	var close_btn := _button("✕", func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
	, Color("1c333a"), Vector2(32, 32))
	close_btn.name = "ReplayCloseBtn"
	head.add_child(close_btn)
	list.add_child(head)

	list.add_child(_label(t("ui.stage_purified_desc"), 9.5, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var nav_box := VBoxContainer.new()
	nav_box.add_theme_constant_override("separation", 8)
	var cult_btn := _button(t("ui.stage_purified_goto_cultivate"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		show_idle_harvest_modal()
	, GOLD, Vector2(0, 36))
	cult_btn.name = "PurifiedCultivateBtn"
	nav_box.add_child(cult_btn)

	var deck_btn := _button(t("ui.stage_purified_goto_deck"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		show_deck()
	, JADE, Vector2(0, 36))
	deck_btn.name = "PurifiedDeckBtn"
	nav_box.add_child(deck_btn)

	var phantom_btn := _button(t("ui.stage_purified_goto_phantom"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		begin_phantom_arena()
	, Color("6b3410"), Vector2(0, 36))
	phantom_btn.name = "PurifiedPhantomBtn"
	nav_box.add_child(phantom_btn)
	list.add_child(nav_box)

func _build_victory_recap_card(stats: Dictionary) -> Control:
	var panel := Panel.new()
	panel.name = "VictoryRecapCard"
	panel.custom_minimum_size = Vector2(0, 54)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("122228"), 10, Color("34626d")))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 12)
	for side in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 6)
	panel.add_child(pad)

	var vstack := VBoxContainer.new()
	vstack.add_theme_constant_override("separation", 3)
	pad.add_child(vstack)

	vstack.add_child(_label(t("ui.recap_title"), 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_label(tf("ui.recap_damage", int(stats.get("damage_dealt", 0))), 10, Color("ff8a8a")))
	row.add_child(_label(tf("ui.recap_cards", int(stats.get("cards_played", 0))), 10, Color("a8dcff")))
	row.add_child(_label(tf("ui.recap_shield", int(stats.get("shield_gained", 0))), 10, Color("9fd8ff")))
	vstack.add_child(row)
	return panel

func _unique(values: Array) -> Array:
	var result := []
	for value in values:
		if not result.has(value): result.append(value)
	return result

func _card_color(card: Dictionary) -> Color:
	return {"Attack":Color("d95d37"),"Skill":Color("50b99b"),"Power":Color("a75bd6"),"Tactic":Color("4d9dd6"),"Curse":Color("6b3fa0")}.get(card.get("kind","Skill"),JADE)

# Small icon glyphs hinting at deck-building synergy (growth roadmap D1) — Flame/Gale
# Resonance, hero mastery perks, and enemy-count considerations all key off a card doing one
# of these things, and remembering which of 39 cards qualifies is exactly the "recognize
# synergy while building a deck" gap the growth report called out. Derived fresh from the
# card's own effects/special every call rather than stored as separate data, so it can never
# drift out of sync with what the card actually does — only status/special tags that map to a
# real existing system are included; plain damage/shield/heal aren't "synergy," they're just
# what most cards do.
func _card_synergy_tags(card: Dictionary) -> String:
	var tags: Array = []
	for effect in card.get("effects", []):
		var op: String = str(effect.get("operation", ""))
		if op == "status":
			var glyph: String = {"burn":"🔥","poison":"☣","vulnerable":"💢","weak":"🌀","strength":"💪"}.get(str(effect.get("status", "")), "")
			if not glyph.is_empty() and not tags.has(glyph): tags.append(glyph)
		elif op == "draw" and not tags.has("🃏"):
			tags.append("🃏")
	var special: String = str(card.get("special", ""))
	var special_glyph: String = {"cleave":"⚔","critical":"✹"}.get(special, "")
	if not special_glyph.is_empty() and not tags.has(special_glyph): tags.append(special_glyph)
	return " ".join(tags)

# Appends the synergy-tag glyphs to an existing "Kind · Element" line, with no trailing
# separator when a card has none — used by every card-face render site that shows that line.
func _kind_element_line(card: Dictionary) -> String:
	var base := "%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), t("element.%s" % card.get("element", "spirit"))]
	var tags := _card_synergy_tags(card)
	return base if tags.is_empty() else "%s  %s" % [base, tags]

func _rune_color(id: String, fallback: Color) -> Color:
	var rune := content.rune(id); return fallback if rune.is_empty() else Color(rune.color)

func _card_description(card: Dictionary) -> String:
	# Curse cards (decay_blight, void_curse) carry no effects array at all — their rules text
	# is a hazard description (damage on draw, damage if left in hand, unplayable, ...) that
	# doesn't map to any generic "operation", so it gets its own desc.<card_id> string instead.
	if card.get("kind", "") == "Curse": return content.ui("desc.%s" % card.id, lang)
	var parts := []
	for effect in card.effects:
		match effect.operation:
			"damage": parts.append(content.ui("desc.damage", lang) % effect.amount)
			"shield": parts.append(content.ui("desc.shield", lang) % effect.amount)
			"heal": parts.append(content.ui("desc.heal", lang) % effect.amount)
			"draw": parts.append(content.ui("desc.draw", lang) % effect.amount)
			"energy": parts.append(content.ui("desc.energy", lang) % effect.amount)
			"status":
				# Any status name works here — the effect just needs a matching desc.<status> key.
				var key := "desc.%s" % str(effect.get("status", ""))
				parts.append(content.ui(key, lang) % int(effect.amount))
	var special := str(card.get("special", ""))
	if not special.is_empty(): parts.append(content.ui("desc.special.%s" % special, lang))
	if card.get("boomerang", false): parts.append(content.ui("desc.boomerang", lang))
	if card.get("reverb", false): parts.append(content.ui("desc.reverb", lang))
	var overload_amt := int(card.get("overload", 0))
	if overload_amt > 0: parts.append(content.ui("desc.overload", lang) % overload_amt)
	var sep := " · " if lang == "en" else "，"
	return sep.join(parts)
