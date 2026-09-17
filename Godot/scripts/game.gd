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
var selected_rune := ""
var muted := false
var lang := "zh-Hans"
var resolving := false
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
var in_sandbox := false
var sandbox_stage := 0
var compendium_tab := "cards"
var camp_tab := "character"
var battle_speed := 1.0
const BATTLE_SPEED_OPTIONS: Array[float] = [1.0, 1.5, 2.0]
# Kept deliberately conservative (vs. e.g. iOS Dynamic Type's much wider range) — every screen
# in this game was laid out and hand-verified assuming a fixed font size, so a large jump risks
# clipping text against a tightly-sized badge or card tile that nothing here re-flows for.
const TEXT_SCALE_OPTIONS: Array[float] = [0.9, 1.0, 1.1, 1.2]
var deck_filter_kind: String = "all"
var deck_filter_element: String = "all"
var deck_search_query: String = ""
var is_hard_replay: bool = false
var in_phantom_arena: bool = false
var clipboard_cache: String = ""
var _back_action := Callable()
var _swipe_origin := Vector2.ZERO
var _swipe_tracking := false
var map_music: AudioStreamPlayer
var battle_music: AudioStreamPlayer
var battle_music_streams: Array[AudioStream] = []
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
const BAND_HEIGHT = 520.0
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
# at the five fixed stage heights below — a seeded random walk drew a nice-looking curve
# before there was real art to match, but it wandered wherever it liked, so pins and the
# drawn road sat over rocks and treetops instead of the actual path in the image. One entry
# per biome, indexed by chapter % 6 to match _get_chapter_map_texture's own cycling.
const BIOME_PATH_WAYPOINTS = [
	[Vector2(210, 112), Vector2(185, 208), Vector2(145, 304), Vector2(85, 396), Vector2(140, 480)],  # forest
	[Vector2(250, 112), Vector2(240, 208), Vector2(255, 304), Vector2(250, 396), Vector2(275, 480)],  # autumn plains
	[Vector2(200, 112), Vector2(190, 208), Vector2(185, 304), Vector2(180, 396), Vector2(165, 480)],  # glacier
	[Vector2(210, 112), Vector2(195, 208), Vector2(205, 304), Vector2(210, 396), Vector2(225, 480)],  # ember canyon
	[Vector2(200, 112), Vector2(190, 208), Vector2(220, 304), Vector2(205, 396), Vector2(240, 480)],  # mystic swamp
	[Vector2(200, 112), Vector2(180, 208), Vector2(210, 304), Vector2(190, 396), Vector2(200, 480)],  # sunlit ruins
]

# One entry per chapter (0-49), each hand-traced to the specific painted trail in that
# chapter's own unique background (assets/chapters/chapter_N.png — every chapter has had its
# own bespoke art since long after BIOME_PATH_WAYPOINTS above was written for the old 6-image
# fallback, so reusing those 6 sets via chapter%6 put the road and every stage pin over rocks,
# buildings and treetops instead of the actual path for 44 of 50 chapters).
# Derived by segmenting each PNG for its brightest, least-saturated, most path-shaped
# connected region at 5 fixed heights (112/208/304/396/480, i.e. one per stage in the chapter)
# and tracking it row to row so the fit follows one continuous route rather than jumping to
# whatever's brightest in an unrelated part of the frame — a handful of chapters (7, 8, 18, 26)
# needed a manual eyeballed correction afterward: a few "abstract flowing dune" compositions
# have no single distinguishable road at all, and a couple of lava chapters invert the usual
# rule (there the path is the DARKEST feature against glowing lava, not the brightest, which
# the general detector isn't tuned for). See Docs/GROWTH_ROADMAP.md for the detection script.
const CHAPTER_PATH_WAYPOINTS = [
	[Vector2(179, 112), Vector2(200, 208), Vector2(191, 304), Vector2(151, 396), Vector2(176, 480)],  # chapter_0.png
	[Vector2(200, 112), Vector2(160, 208), Vector2(149, 304), Vector2(153, 396), Vector2(157, 480)],  # chapter_1.png
	[Vector2(186, 112), Vector2(219, 208), Vector2(248, 304), Vector2(223, 396), Vector2(209, 480)],  # chapter_2.png
	[Vector2(256, 112), Vector2(217, 208), Vector2(165, 304), Vector2(152, 396), Vector2(188, 480)],  # chapter_3.png
	[Vector2(160, 112), Vector2(222, 208), Vector2(188, 304), Vector2(213, 396), Vector2(168, 480)],  # chapter_4.png
	[Vector2(303, 112), Vector2(260, 208), Vector2(224, 304), Vector2(246, 396), Vector2(156, 480)],  # chapter_5.png
	[Vector2(325, 112), Vector2(250, 208), Vector2(190, 304), Vector2(260, 396), Vector2(135, 480)],  # chapter_6.png
	[Vector2(236, 112), Vector2(250, 208), Vector2(295, 304), Vector2(298, 396), Vector2(341, 480)],  # chapter_7.png
	[Vector2(74, 112), Vector2(101, 208), Vector2(48, 304), Vector2(65, 396), Vector2(48, 480)],  # chapter_8.png
	[Vector2(92, 112), Vector2(96, 208), Vector2(70, 304), Vector2(81, 396), Vector2(83, 480)],  # chapter_9.png
	[Vector2(284, 112), Vector2(275, 208), Vector2(240, 304), Vector2(233, 396), Vector2(239, 480)],  # chapter_10.png
	[Vector2(86, 112), Vector2(129, 208), Vector2(167, 304), Vector2(143, 396), Vector2(233, 480)],  # chapter_11.png
	[Vector2(160, 112), Vector2(222, 208), Vector2(188, 304), Vector2(213, 396), Vector2(168, 480)],  # chapter_12.png
	[Vector2(189, 112), Vector2(229, 208), Vector2(240, 304), Vector2(227, 396), Vector2(223, 480)],  # chapter_13.png
	[Vector2(246, 112), Vector2(233, 208), Vector2(215, 304), Vector2(248, 396), Vector2(257, 480)],  # chapter_14.png
	[Vector2(133, 112), Vector2(172, 208), Vector2(224, 304), Vector2(237, 396), Vector2(201, 480)],  # chapter_15.png
	[Vector2(186, 112), Vector2(219, 208), Vector2(248, 304), Vector2(223, 396), Vector2(209, 480)],  # chapter_16.png
	[Vector2(125, 112), Vector2(103, 208), Vector2(119, 304), Vector2(89, 396), Vector2(134, 480)],  # chapter_17.png
	[Vector2(238, 112), Vector2(250, 208), Vector2(295, 304), Vector2(297, 396), Vector2(341, 480)],  # chapter_18.png
	[Vector2(152, 112), Vector2(189, 208), Vector2(190, 304), Vector2(193, 396), Vector2(189, 480)],  # chapter_19.png
	[Vector2(203, 112), Vector2(170, 208), Vector2(141, 304), Vector2(166, 396), Vector2(180, 480)],  # chapter_20.png
	[Vector2(186, 112), Vector2(219, 208), Vector2(248, 304), Vector2(223, 396), Vector2(209, 480)],  # chapter_21.png
	[Vector2(107, 112), Vector2(107, 208), Vector2(94, 304), Vector2(91, 396), Vector2(48, 480)],  # chapter_22.png
	[Vector2(237, 112), Vector2(249, 208), Vector2(295, 304), Vector2(297, 396), Vector2(341, 480)],  # chapter_23.png
	[Vector2(282, 112), Vector2(282, 208), Vector2(285, 304), Vector2(285, 396), Vector2(266, 480)],  # chapter_24.png
	[Vector2(256, 112), Vector2(217, 208), Vector2(165, 304), Vector2(152, 396), Vector2(188, 480)],  # chapter_25.png
	[Vector2(193, 112), Vector2(213, 208), Vector2(231, 304), Vector2(197, 396), Vector2(180, 480)],  # chapter_26.png
	[Vector2(267, 112), Vector2(188, 208), Vector2(177, 304), Vector2(170, 396), Vector2(140, 480)],  # chapter_27.png
	[Vector2(96, 112), Vector2(106, 208), Vector2(135, 304), Vector2(158, 396), Vector2(153, 480)],  # chapter_28.png
	[Vector2(194, 112), Vector2(186, 208), Vector2(190, 304), Vector2(180, 396), Vector2(189, 480)],  # chapter_29.png
	[Vector2(206, 112), Vector2(189, 208), Vector2(198, 304), Vector2(238, 396), Vector2(213, 480)],  # chapter_30.png
	[Vector2(178, 112), Vector2(259, 208), Vector2(233, 304), Vector2(246, 396), Vector2(156, 480)],  # chapter_31.png
	[Vector2(256, 112), Vector2(217, 208), Vector2(165, 304), Vector2(152, 396), Vector2(188, 480)],  # chapter_32.png
	[Vector2(107, 112), Vector2(107, 208), Vector2(103, 304), Vector2(104, 396), Vector2(123, 480)],  # chapter_33.png
	[Vector2(86, 112), Vector2(130, 208), Vector2(162, 304), Vector2(143, 396), Vector2(233, 480)],  # chapter_34.png
	[Vector2(229, 112), Vector2(170, 208), Vector2(141, 304), Vector2(166, 396), Vector2(180, 480)],  # chapter_35.png
	[Vector2(122, 112), Vector2(195, 208), Vector2(207, 304), Vector2(219, 396), Vector2(248, 480)],  # chapter_36.png
	[Vector2(229, 112), Vector2(166, 208), Vector2(201, 304), Vector2(177, 396), Vector2(221, 480)],  # chapter_37.png
	[Vector2(192, 112), Vector2(213, 208), Vector2(218, 304), Vector2(192, 396), Vector2(211, 480)],  # chapter_38.png
	[Vector2(237, 112), Vector2(200, 208), Vector2(199, 304), Vector2(196, 396), Vector2(200, 480)],  # chapter_39.png
	[Vector2(200, 112), Vector2(157, 208), Vector2(149, 304), Vector2(162, 396), Vector2(166, 480)],  # chapter_40.png
	[Vector2(133, 112), Vector2(172, 208), Vector2(224, 304), Vector2(237, 396), Vector2(201, 480)],  # chapter_41.png
	[Vector2(125, 112), Vector2(103, 208), Vector2(119, 304), Vector2(90, 396), Vector2(134, 480)],  # chapter_42.png
	[Vector2(186, 112), Vector2(219, 208), Vector2(248, 304), Vector2(223, 396), Vector2(209, 480)],  # chapter_43.png
	[Vector2(278, 112), Vector2(283, 208), Vector2(295, 304), Vector2(297, 396), Vector2(341, 480)],  # chapter_44.png
	[Vector2(303, 112), Vector2(259, 208), Vector2(227, 304), Vector2(246, 396), Vector2(156, 480)],  # chapter_45.png
	[Vector2(267, 112), Vector2(188, 208), Vector2(178, 304), Vector2(170, 396), Vector2(141, 480)],  # chapter_46.png
	[Vector2(183, 112), Vector2(200, 208), Vector2(191, 304), Vector2(151, 396), Vector2(176, 480)],  # chapter_47.png
	[Vector2(237, 112), Vector2(200, 208), Vector2(199, 304), Vector2(196, 396), Vector2(200, 480)],  # chapter_48.png
	[Vector2(194, 112), Vector2(189, 208), Vector2(190, 304), Vector2(187, 396), Vector2(189, 480)],  # chapter_49.png
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
	# Standalone portraits (a hero that doesn't fit the fixed 3x3 atlas, e.g. miasma_witch)
	# take priority over the atlas — checked by exact key match so every existing atlas key
	# ("fox", "sentinel", ...) falls through unchanged since none of them name a real file here.
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
	var art_str: String = str(enemy.get("art", ""))
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
	_build_audio()
	_ensure_quests_current()
	_ensure_daily_trial_current()
	_ensure_weekly_challenge_current()
	_ensure_login_reward_current()
	if SpiritSave.has_account_name(profile): show_map()
	else: show_account_setup()

const DAY_SECONDS := 86400
const WEEK_SECONDS := 604800

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
	show_battle()

func _pass_turn() -> void:
	if combat == null or combat.state.phase != "player" or resolving: return
	_toast(t("ui.no_playable"))
	await get_tree().create_timer(_battle_delay(0.28)).timeout
	if combat == null or combat.state.phase != "player": return
	await _enemy_turn()

# Keywords that may appear on cards and warrant a tap-to-explain tooltip.
const KEYWORD_KEYS: Array[String] = [
	"damage", "shield", "heal", "draw", "burn", "focus", "vulnerable",
	"weak", "strength", "pierce", "cleave", "critical", "stun", "energy",
	"echo", "siphon", "resonance", "poison",
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

func _clear() -> void:
	for child in get_children():
		if child != map_music and child != battle_music: child.queue_free()
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

func _play_music(battle := false, stage_level: int = 0) -> void:
	if muted: return
	if battle:
		map_music.stop()
		var stream_idx: int = clampi(stage_level, 0, battle_music_streams.size() - 1)
		if battle_music_streams.size() > stream_idx and battle_music_streams[stream_idx] != null:
			var target_stream: AudioStream = battle_music_streams[stream_idx]
			if battle_music.stream != target_stream or not battle_music.playing:
				battle_music.stream = target_stream
				battle_music.play()
		else:
			if not battle_music.playing: battle_music.play()
	else:
		battle_music.stop()
		if not map_music.playing: map_music.play()

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

	# Logo sits at the far left on the map header
	if title == "SPIRITBOUND":
		var logo := TextureRect.new()
		logo.name = "SpiritboundLogo"
		var logo_tex: Texture2D = load("res://assets/ui/spiritbound_logo.png")
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(168.0, 52.0)
		logo.size = logo.custom_minimum_size
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left_box.add_child(logo)

	if back.is_valid():
		var back_btn := _button("‹", back, Color("17363e"), Vector2(34, 34))
		back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		left_box.add_child(back_btn)

	var stats_box := HBoxContainer.new()
	stats_box.name = "HeaderStatsBox"
	stats_box.add_theme_constant_override("separation", 3)
	stats_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var hp_icon := TextureRect.new()
	hp_icon.texture = load("res://assets/icons/hud_heart.png")
	hp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hp_icon.custom_minimum_size = Vector2(15, 15)
	hp_icon.size = hp_icon.custom_minimum_size
	hp_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.add_child(hp_icon)

	var hp_label := _label("%d/60" % int(profile.health), 11, TEXT)
	hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_box.add_child(hp_label)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(3, 1)
	stats_box.add_child(sep)

	var gold_icon := TextureRect.new()
	gold_icon.texture = load("res://assets/icons/hud_gold.png")
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.custom_minimum_size = Vector2(15, 15)
	gold_icon.size = gold_icon.custom_minimum_size
	gold_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.add_child(gold_icon)

	var gold_label := _label("%d" % int(profile.gold), 11, GOLD)
	gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_box.add_child(gold_label)

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
			copy.add_child(_label(subtitle, 10, JADE, HORIZONTAL_ALIGNMENT_CENTER))
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
func show_map() -> void: await _map_screen.show_map()
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
	var tween := create_tween(); tween.tween_property(toast,"position:y",86,.22); tween.tween_interval(.55); tween.tween_property(toast,"modulate:a",0.0,.25); tween.tween_callback(toast.queue_free)

# Thin delegators onto BattleScreen (scripts/game_battle_screen.gd) — see MapScreen's header
# comment (game_map_screen.gd) for why composition rather than inheritance, and game.gd's own
# MapScreen delegator block above for why these keep their original bare names.
func _modifier(seed: int, stage: int) -> Dictionary: return _battle_screen._modifier(seed, stage)
func begin_battle(index: int) -> void: _battle_screen.begin_battle(index)
func show_battle() -> void: _battle_screen.show_battle()
func _apply_card_foil(node: CanvasItem, rarity: String, upgraded: bool) -> void: _battle_screen._apply_card_foil(node, rarity, upgraded)
func _flash_hit(sprite: CanvasItem, color := Color.WHITE, duration := 0.22) -> void: _battle_screen._flash_hit(sprite, color, duration)
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
func show_reward_details() -> void: _rewards_screen.show_reward_details()
func show_battle_log() -> void: _rewards_screen.show_battle_log()
func show_run_recap() -> void: _rewards_screen.show_run_recap()
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
func show_shop() -> void: _shop_deck_screen.show_shop()
func _card_art_panel(card_id: String, art_size: Vector2, radius := 8) -> Control: return _shop_deck_screen._card_art_panel(card_id, art_size, radius)
func _cost_badge(cost: int, accent: Color, diameter := 26) -> Panel: return _shop_deck_screen._cost_badge(cost, accent, diameter)
func _add_ornate_frame(tile: Control, size: Vector2, accent: Color, rarity: String = "Common") -> void: _shop_deck_screen._add_ornate_frame(tile, size, accent, rarity)
func _rarity_star_row(rarity: String, color := GOLD, align := BoxContainer.ALIGNMENT_CENTER) -> HBoxContainer: return _shop_deck_screen._rarity_star_row(rarity, color, align)
func show_deck() -> void: _shop_deck_screen.show_deck()
func _card_build_score(card: Dictionary) -> float: return _shop_deck_screen._card_build_score(card)
func _auto_build_deck() -> void: _shop_deck_screen._auto_build_deck()
func _tab_bar(tabs: Array, active: String, on_pick: Callable) -> Control: return _shop_deck_screen._tab_bar(tabs, active, on_pick)
func show_loadout() -> void: _shop_deck_screen.show_loadout()
var SHOP_STOCK_COUNT: int:
	get: return _shop_deck_screen.SHOP_STOCK_COUNT

# Thin delegators onto CampScreen (scripts/game_camp_screen.gd) — see MapScreen's header
# comment (game_map_screen.gd) for why composition rather than inheritance.
func show_compendium() -> void: _camp_screen.show_compendium()
func _claim_compendium_milestone(target: int) -> void: _camp_screen._claim_compendium_milestone(target)
func _equip(item: Dictionary) -> void: _camp_screen._equip(item)
func _socket(card_id: String) -> void: _camp_screen._socket(card_id)
func _format_countdown(target_unix: int) -> String: return _camp_screen._format_countdown(target_unix)
func show_quests() -> void: _camp_screen.show_quests()
func show_camp() -> void: _camp_screen.show_camp()
func show_challenges() -> void: _camp_screen.show_challenges()
func begin_daily_trial() -> void: _camp_screen.begin_daily_trial()
func begin_weekly_challenge() -> void: _camp_screen.begin_weekly_challenge()
func begin_boss_rush_battle() -> void: _camp_screen.begin_boss_rush_battle()
func begin_sandbox_battle(stage: int) -> void: _camp_screen.begin_sandbox_battle(stage)
func show_abyss_boon_draft() -> void: _camp_screen.show_abyss_boon_draft()
func show_season_pass() -> void: _camp_screen.show_season_pass()
func show_spirit_draft() -> void: _camp_screen.show_spirit_draft()
func begin_phantom_arena() -> void: _camp_screen.begin_phantom_arena()

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
		else:
			linked_text = tf("ui.auth_linked_google", display_id)

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

	list.add_child(account_box)

func _close_settings() -> void:
	if overlay == null: return
	var existing: Node = overlay.get_node_or_null("SettingsModal")
	if existing:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

func _change_language(new_lang: String) -> void:
	lang = new_lang
	profile.language = lang
	SpiritSave.write(profile)
	_close_settings()
	show_settings()

func _change_battle_speed(new_speed: float) -> void:
	battle_speed = new_speed
	profile.battle_speed = battle_speed
	SpiritSave.write(profile)
	_close_settings()
	show_settings()

func _toggle_music_settings() -> void:
	muted = not muted
	if muted: map_music.stop(); battle_music.stop()
	else: _play_music(false)
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
			if str(eff.get("op", "")) == "shield":
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
		is_hard_replay = false
		_travel_to(index)

func _show_replay_mode_prompt(index: int) -> void:
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

	var nav_box := HBoxContainer.new()
	nav_box.add_theme_constant_override("separation", 8)
	var cult_btn := _button(t("ui.stage_purified_goto_cultivate"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		show_idle_harvest_modal()
	, GOLD, Vector2(0, 36))
	cult_btn.name = "PurifiedCultivateBtn"
	cult_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_box.add_child(cult_btn)

	var deck_btn := _button(t("ui.stage_purified_goto_deck"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		show_deck()
	, JADE, Vector2(0, 36))
	deck_btn.name = "PurifiedDeckBtn"
	deck_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_box.add_child(deck_btn)
	list.add_child(nav_box)

	var normal_btn := _button(t("ui.replay_normal_title"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		is_hard_replay = false
		_travel_to(index)
	, Color("17363e"), Vector2(0, 36))
	normal_btn.name = "ReplayNormalBtn"
	list.add_child(normal_btn)

	var hard_btn := _button(t("ui.replay_hard_title"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex:
			if ex.get_parent(): ex.get_parent().remove_child(ex)
			ex.queue_free()
		is_hard_replay = true
		_travel_to(index)
	, EMBER, Vector2(0, 36))
	hard_btn.name = "ReplayHardBtn"
	list.add_child(hard_btn)

func begin_hard_replay(index: int) -> void:
	is_hard_replay = true
	begin_battle(index)

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
	var sep := " · " if lang == "en" else "，"
	return sep.join(parts)
