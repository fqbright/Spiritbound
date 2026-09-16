extends Control
class_name SpiritGame

var content := SpiritContent.new()
var profile: Dictionary
var combat: SpiritCombat
var current_stage := 0
var active_modifier: Dictionary = {}
var root: Control
var overlay: Control
var map_canvas: Control
var map_scroll: TouchScrollContainer
var traveler: Sprite2D
var _map_screen: MapScreen
var _battle_screen: BattleScreen
var _rewards_screen: RewardsScreen
var _shop_deck_screen: ShopDeckScreen
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
var compendium_tab := "cards"
var camp_tab := "character"
var battle_speed := 1.0
const BATTLE_SPEED_OPTIONS: Array[float] = [1.0, 1.5, 2.0]
var deck_filter_kind: String = "all"
var deck_filter_element: String = "all"
var deck_search_query: String = ""
var is_hard_replay: bool = false
var _back_action := Callable()
var _swipe_origin := Vector2.ZERO
var _swipe_tracking := false
var map_music: AudioStreamPlayer
var battle_music: AudioStreamPlayer
var battle_music_streams: Array[AudioStream] = []
var font_cjk: Font = load("res://assets/fonts/NotoSansSC.ttf")

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
const BATTLE_BACKGROUNDS = ["battlefield-v1.jpg","lantern-marsh-v1.jpg","rune-ravine-v1.jpg","ember-cliff-v1.jpg","mountain-forge-v1.jpg"]

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
	[Vector2(173, 112), Vector2(211, 208), Vector2(249, 304), Vector2(254, 396), Vector2(249, 480)],  # chapter_0.png
	[Vector2(207, 112), Vector2(182, 208), Vector2(207, 304), Vector2(218, 396), Vector2(264, 480)],  # chapter_1.png
	[Vector2(163, 112), Vector2(162, 208), Vector2(211, 304), Vector2(188, 396), Vector2(191, 480)],  # chapter_2.png
	[Vector2(196, 112), Vector2(178, 208), Vector2(193, 304), Vector2(199, 396), Vector2(156, 480)],  # chapter_3.png
	[Vector2(159, 112), Vector2(211, 208), Vector2(162, 304), Vector2(165, 396), Vector2(186, 480)],  # chapter_4.png
	[Vector2(148, 112), Vector2(268, 208), Vector2(203, 304), Vector2(282, 396), Vector2(228, 480)],  # chapter_5.png
	[Vector2(116, 112), Vector2(144, 208), Vector2(94, 304), Vector2(136, 396), Vector2(144, 480)],  # chapter_6.png
	[Vector2(200, 112), Vector2(180, 208), Vector2(195, 304), Vector2(175, 396), Vector2(190, 480)],  # chapter_7.png
	[Vector2(195, 112), Vector2(165, 208), Vector2(175, 304), Vector2(210, 396), Vector2(180, 480)],  # chapter_8.png
	[Vector2(195, 112), Vector2(236, 208), Vector2(238, 304), Vector2(200, 396), Vector2(196, 480)],  # chapter_9.png
	[Vector2(224, 112), Vector2(237, 208), Vector2(240, 304), Vector2(250, 396), Vector2(328, 480)],  # chapter_10.png
	[Vector2(241, 112), Vector2(122, 208), Vector2(186, 304), Vector2(107, 396), Vector2(161, 480)],  # chapter_11.png
	[Vector2(163, 112), Vector2(208, 208), Vector2(232, 304), Vector2(264, 396), Vector2(238, 480)],  # chapter_12.png
	[Vector2(182, 112), Vector2(206, 208), Vector2(198, 304), Vector2(227, 396), Vector2(244, 480)],  # chapter_13.png
	[Vector2(272, 112), Vector2(264, 208), Vector2(278, 304), Vector2(295, 396), Vector2(299, 480)],  # chapter_14.png
	[Vector2(215, 112), Vector2(172, 208), Vector2(195, 304), Vector2(190, 396), Vector2(233, 480)],  # chapter_15.png
	[Vector2(163, 112), Vector2(162, 208), Vector2(211, 304), Vector2(182, 396), Vector2(176, 480)],  # chapter_16.png
	[Vector2(200, 112), Vector2(211, 208), Vector2(223, 304), Vector2(267, 396), Vector2(250, 480)],  # chapter_17.png
	[Vector2(190, 112), Vector2(205, 208), Vector2(180, 304), Vector2(200, 396), Vector2(175, 480)],  # chapter_18.png
	[Vector2(193, 112), Vector2(194, 208), Vector2(152, 304), Vector2(191, 396), Vector2(192, 480)],  # chapter_19.png
	[Vector2(219, 112), Vector2(226, 208), Vector2(177, 304), Vector2(212, 396), Vector2(184, 480)],  # chapter_20.png
	[Vector2(164, 112), Vector2(162, 208), Vector2(211, 304), Vector2(181, 396), Vector2(176, 480)],  # chapter_21.png
	[Vector2(267, 112), Vector2(229, 208), Vector2(301, 304), Vector2(290, 396), Vector2(290, 480)],  # chapter_22.png
	[Vector2(179, 112), Vector2(162, 208), Vector2(151, 304), Vector2(97, 396), Vector2(97, 480)],  # chapter_23.png
	[Vector2(276, 112), Vector2(294, 208), Vector2(273, 304), Vector2(285, 396), Vector2(278, 480)],  # chapter_24.png
	[Vector2(157, 112), Vector2(126, 208), Vector2(150, 304), Vector2(154, 396), Vector2(156, 480)],  # chapter_25.png
	[Vector2(200, 112), Vector2(175, 208), Vector2(190, 304), Vector2(165, 396), Vector2(185, 480)],  # chapter_26.png
	[Vector2(271, 112), Vector2(246, 208), Vector2(291, 304), Vector2(253, 396), Vector2(257, 480)],  # chapter_27.png
	[Vector2(196, 112), Vector2(196, 208), Vector2(239, 304), Vector2(197, 396), Vector2(206, 480)],  # chapter_28.png
	[Vector2(206, 112), Vector2(197, 208), Vector2(142, 304), Vector2(184, 396), Vector2(190, 480)],  # chapter_29.png
	[Vector2(224, 112), Vector2(265, 208), Vector2(209, 304), Vector2(260, 396), Vector2(305, 480)],  # chapter_30.png
	[Vector2(148, 112), Vector2(267, 208), Vector2(203, 304), Vector2(282, 396), Vector2(227, 480)],  # chapter_31.png
	[Vector2(194, 112), Vector2(216, 208), Vector2(194, 304), Vector2(199, 396), Vector2(156, 480)],  # chapter_32.png
	[Vector2(112, 112), Vector2(95, 208), Vector2(114, 304), Vector2(105, 396), Vector2(110, 480)],  # chapter_33.png
	[Vector2(241, 112), Vector2(122, 208), Vector2(186, 304), Vector2(107, 396), Vector2(161, 480)],  # chapter_34.png
	[Vector2(228, 112), Vector2(226, 208), Vector2(178, 304), Vector2(207, 396), Vector2(213, 480)],  # chapter_35.png
	[Vector2(118, 112), Vector2(143, 208), Vector2(98, 304), Vector2(136, 396), Vector2(131, 480)],  # chapter_36.png
	[Vector2(234, 112), Vector2(168, 208), Vector2(125, 304), Vector2(126, 396), Vector2(151, 480)],  # chapter_37.png
	[Vector2(136, 112), Vector2(201, 208), Vector2(271, 304), Vector2(313, 396), Vector2(281, 480)],  # chapter_38.png
	[Vector2(195, 112), Vector2(243, 208), Vector2(196, 304), Vector2(200, 396), Vector2(197, 480)],  # chapter_39.png
	[Vector2(208, 112), Vector2(207, 208), Vector2(219, 304), Vector2(220, 396), Vector2(265, 480)],  # chapter_40.png
	[Vector2(215, 112), Vector2(171, 208), Vector2(196, 304), Vector2(190, 396), Vector2(234, 480)],  # chapter_41.png
	[Vector2(253, 112), Vector2(211, 208), Vector2(222, 304), Vector2(269, 396), Vector2(249, 480)],  # chapter_42.png
	[Vector2(163, 112), Vector2(162, 208), Vector2(211, 304), Vector2(181, 396), Vector2(184, 480)],  # chapter_43.png
	[Vector2(177, 112), Vector2(162, 208), Vector2(225, 304), Vector2(296, 396), Vector2(328, 480)],  # chapter_44.png
	[Vector2(148, 112), Vector2(267, 208), Vector2(203, 304), Vector2(282, 396), Vector2(228, 480)],  # chapter_45.png
	[Vector2(272, 112), Vector2(246, 208), Vector2(291, 304), Vector2(253, 396), Vector2(258, 480)],  # chapter_46.png
	[Vector2(165, 112), Vector2(124, 208), Vector2(180, 304), Vector2(129, 396), Vector2(84, 480)],  # chapter_47.png
	[Vector2(196, 112), Vector2(195, 208), Vector2(236, 304), Vector2(198, 396), Vector2(197, 480)],  # chapter_48.png
	[Vector2(193, 112), Vector2(194, 208), Vector2(152, 304), Vector2(190, 396), Vector2(193, 480)],  # chapter_49.png
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
		profile.daily_trial_record = {
			"day": day,
			"stage": 0,
			"badges": int(previous.get("badges", 0)),
			"best_stage": int(previous.get("best_stage", 0)),
			"streak": streak,
			"streak_claimed": previous.get("streak_claimed", []).duplicate()
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
		SpiritSave.write(profile)
		_toast(tf("ui.quest_claimed_toast", int(q.get("reward", 0))), GOLD)
		show_quests()
		return

func show_account_setup() -> void:
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

	page.add_child(_button(t("ui.account_start"), func(): _create_account(field.text), EMBER, Vector2(0, 52)))
	var lang_btn := _button(t("ui.lang_toggle"), func(): lang = "en" if lang == "zh-Hans" else "zh-Hans"; profile.language = lang; show_account_setup(), Color("17363e"), Vector2(0, 42))
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
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = align
	if autowrap: value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else: value.autowrap_mode = TextServer.AUTOWRAP_OFF
	return value

func _button(text: String, callback: Callable, color := PANEL, min_size := Vector2(0,44)) -> Button:
	var value := Button.new(); value.text = text; value.custom_minimum_size = min_size
	if font_cjk: value.add_theme_font_override("font", font_cjk)
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", TEXT)
	value.add_theme_stylebox_override("normal", _panel(color, 10, GOLD))
	value.add_theme_stylebox_override("hover", _panel(color.lightened(.1), 10, JADE))
	value.add_theme_stylebox_override("pressed", _panel(color.darkened(.12), 10, EMBER))
	value.add_theme_stylebox_override("disabled", _panel(color.darkened(.3), 10, Color("3a4a50")))
	if callback.is_valid(): value.pressed.connect(callback)
	return value

func _texture(path: String) -> Texture2D:
	return load("res://assets/%s" % path)

func _background(file: String, opacity := .42) -> TextureRect:
	var image := TextureRect.new(); image.texture = _texture("backgrounds/%s" % file); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.modulate = Color(1,1,1,opacity); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _header(title: String, subtitle: String, back := Callable()) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 44
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	if back.is_valid():
		var back_btn := _button("‹", back, Color("17363e"), Vector2(36,34))
		back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(back_btn)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	if title == "SPIRITBOUND":
		var logo := TextureRect.new()
		logo.name = "SpiritboundLogo"
		var logo_tex: Texture2D = load("res://assets/ui/spiritbound_logo.png")
		logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(104.0, 36.0)
		logo.size = logo.custom_minimum_size
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(logo)
	else:
		if title != "":
			copy.add_child(_label(title, 16, TEXT))
	if subtitle != "":
		copy.add_child(_label(subtitle, 10, JADE))
	bar.add_child(copy)

	var stats_box := HBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 4)
	stats_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_box.alignment = BoxContainer.ALIGNMENT_END

	var hp_icon := TextureRect.new()
	hp_icon.texture = load("res://assets/icons/hud_heart.png")
	hp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hp_icon.custom_minimum_size = Vector2(16, 16)
	hp_icon.size = hp_icon.custom_minimum_size
	hp_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.add_child(hp_icon)

	var hp_label := _label("%d/60" % int(profile.health), 11, TEXT)
	hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_box.add_child(hp_label)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(4, 1)
	stats_box.add_child(sep)

	var gold_icon := TextureRect.new()
	gold_icon.texture = load("res://assets/icons/hud_gold.png")
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.custom_minimum_size = Vector2(16, 16)
	gold_icon.size = gold_icon.custom_minimum_size
	gold_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.add_child(gold_icon)

	var gold_label := _label("%d" % int(profile.gold), 11, GOLD)
	gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_box.add_child(gold_label)

	bar.add_child(stats_box)
	return bar

# Thin delegators onto MapScreen (scripts/game_map_screen.gd) — kept here under their
# original names because both other game.gd code and ui_smoke.gd call them directly on
# `game`/`self`, and because SpiritGame's screen transitions call each other by bare name
# (show_map() -> show_camp() -> show_quests() -> ...); see MapScreen's own header comment for
# why this is composition (a `g` back-reference) rather than inheritance.
func show_map() -> void: await _map_screen.show_map()
func _travel_to(index: int) -> void: await _map_screen._travel_to(index)
func _has_claimable_quest() -> bool: return _map_screen._has_claimable_quest()
func _has_claimable_camp_reward() -> bool: return _map_screen._has_claimable_camp_reward()
func _claimable_reward_count() -> int: return _map_screen._claimable_reward_count()
func _chapter_waypoints(chapter: int) -> Array: return _map_screen._chapter_waypoints(chapter)
func _chapter_has_unique_art(chapter: int) -> bool: return _map_screen._chapter_has_unique_art(chapter)
func _map_point(index: int) -> Vector2: return _map_screen._map_point(index)
func _build_road_curve(points: PackedVector2Array) -> Curve2D: return _map_screen._build_road_curve(points)
func _get_road_texture() -> NoiseTexture2D: return _map_screen._get_road_texture()
func _get_terrain_wash_texture(tint_index: int) -> GradientTexture2D: return _map_screen._get_terrain_wash_texture(tint_index)

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
func _collect_card(card: Dictionary) -> void: _rewards_screen._collect_card(card)
func _smart_add_card(card: Dictionary) -> void: _rewards_screen._smart_add_card(card)
func show_event(index: int, kind: String) -> void: _rewards_screen.show_event(index, kind)

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

func show_compendium() -> void:
	_clear(); _play_music(false)
	_back_action = show_camp
	var page := _create_page(6)
	page.add_child(_header(t("ui.compendium_title"), t("ui.compendium_sub"), show_camp))
	var totals := _compendium_totals()
	var pct: int = int(round(float(totals.x) / float(maxi(1, totals.y)) * 100.0))
	page.add_child(_build_compendium_milestones_bar(pct))
	page.add_child(_tab_bar([
		["cards", t("ui.compendium_tab_cards")],
		["gear", t("ui.compendium_tab_gear")],
		["runes", t("ui.tab_runes")],
		["relics", t("ui.relic_title")],
		["bestiary", t("ui.compendium_tab_bestiary")],
		["achievements", t("ui.compendium_tab_achievements")],
	], compendium_tab, func(id): compendium_tab = id; show_compendium()))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	match compendium_tab:
		"cards": _build_compendium_cards(list)
		"gear": _build_compendium_equipment(list)
		"runes": _build_compendium_runes(list)
		"relics": _build_compendium_relics(list)
		"bestiary": _build_compendium_bestiary(list)
		_: _build_compendium_achievements(list)

func _build_compendium_milestones_bar(pct: int) -> Control:
	var bar_panel := PanelContainer.new()
	bar_panel.name = "CompendiumMilestonesBar"
	bar_panel.custom_minimum_size = Vector2(340, 56)
	bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_panel.add_theme_stylebox_override("panel", _panel(Color("10221c"), 12, Color("356554")))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 6)
	bar_panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	pad.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.add_child(_label(t("ui.compendium_milestones_title"), 10, JADE))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_row.add_child(sp)
	title_row.add_child(_label("%d%%" % pct, 10, GOLD))
	stack.add_child(title_row)

	var btns_row := HBoxContainer.new()
	btns_row.add_theme_constant_override("separation", 6)
	stack.add_child(btns_row)

	var claimed: Array = profile.get("compendium_milestones_claimed", [])
	for target in [50, 80, 100]:
		var is_claimed: bool = claimed.has(target)
		var is_ready: bool = pct >= target and not is_claimed
		var text_str: String = "✓ %d%%" % target if is_claimed else (tf("ui.compendium_milestone_btn_fmt", target) if is_ready else "🔒 %d%%" % target)
		var btn := _button(text_str, func(): _claim_compendium_milestone(target), GOLD if is_ready else Color("1a352c"), Vector2(0, 26))
		btn.name = "MilestoneBtn_%d" % target
		btn.disabled = not is_ready
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns_row.add_child(btn)

	return bar_panel

func _claim_compendium_milestone(target: int) -> void:
	var claimed: Array = profile.get("compendium_milestones_claimed", []).duplicate()
	if claimed.has(target): return
	claimed.append(target)
	profile.compendium_milestones_claimed = claimed
	var gold_reward: int = 200 if target == 50 else (500 if target == 80 else 1000)
	profile.gold += gold_reward
	if target >= 50:
		_grant_mastery_xp(100)
	SpiritSave.write(profile)
	_toast(tf("ui.compendium_milestone_toast", target), GOLD)
	show_compendium()

# Shared row shell for every Compendium tab: an icon/art badge on the left, a title (or the
# generic "undiscovered" label) and one detail line on the right. Discovered items get their
# real color as the border accent; undiscovered ones fall back to a flat, uninformative gray
# so nothing about a locked entry's rarity or theme leaks through before it's actually found.
func _compendium_row(badge: Control, title: String, detail: String, discovered: bool, accent: Color) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size.y = 68
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border: Color = accent if discovered else Color("2a3d42")
	panel.add_theme_stylebox_override("panel", _panel(Color("13282e") if discovered else Color("0e191d"), 12, border))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pad.add_child(row)

	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(50, 60)
	holder.add_child(badge)
	row.add_child(holder)

	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	texts.add_child(_label(title if discovered else t("ui.compendium_locked"), 13, TEXT if discovered else MUTED))
	if discovered and not detail.is_empty():
		var detail_lbl := _label(detail, 9, JADE, HORIZONTAL_ALIGNMENT_LEFT, true)
		detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(detail_lbl)

	return panel

func _compendium_locked_badge() -> Control:
	return _icon_badge("?", Color("3c5057"), 46, 20)

func _build_compendium_cards(list: VBoxContainer) -> void:
	var totals := _compendium_totals()
	list.add_child(_label(tf("ui.compendium_progress", [totals.x, totals.y]), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	# Curse cards (decay_blight, void_curse) are enemy-inflicted battle hazards, never something
	# a player collects — showing them here would be a permanently "undiscovered" entry with no
	# way to ever complete it.
	for card in content.cards.filter(func(c): return c.get("rarity", "") != "Curse"):
		var discovered := _card_discovered(card.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = _card_art_panel(card.id, Vector2(44, 60))
		var detail := "%s · %s" % [t("kind.%s" % card.get("kind", "Skill")), _card_description(card)]
		list.add_child(_compendium_row(badge, content.text(card.nameKey, lang), detail, discovered, _card_color(card)))

func _build_compendium_equipment(list: VBoxContainer) -> void:
	for item in SpiritContent.EQUIPMENT:
		var discovered := _equip_discovered(item.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = _equip_icon_badge(item, GOLD, 46)
		list.add_child(_compendium_row(badge, _equip_name(item), _equip_detail(item), discovered, GOLD))

func _build_compendium_runes(list: VBoxContainer) -> void:
	for rune in SpiritContent.RUNES:
		var discovered := _rune_discovered(rune.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = _rune_icon_badge(rune, Color(rune.color), 46)
		list.add_child(_compendium_row(badge, _rune_name(rune), _rune_detail(rune), discovered, Color(rune.color)))

func _build_compendium_relics(list: VBoxContainer) -> void:
	for relic in SpiritContent.RELICS:
		var discovered := _relic_discovered(relic.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = _sigil_icon_badge(str(relic.get("icon_mark", "sparkle")), Color(relic.color), 46)
		list.add_child(_compendium_row(badge, _relic_name(relic), _relic_detail(relic), discovered, Color(relic.color)))

func _build_compendium_bestiary(list: VBoxContainer) -> void:
	for enemy in SpiritContent.ENEMIES:
		var discovered := _bestiary_discovered(str(enemy.name))
		var name_str: String = str(enemy.name_en) if lang == "en" else str(enemy.name)
		var badge: Control
		if discovered:
			var tex := TextureRect.new()
			tex.texture = _get_character_texture(_art_key_for_enemy(enemy))
			tex.custom_minimum_size = Vector2(46, 46)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge = tex
		else:
			badge = _compendium_locked_badge()
		list.add_child(_compendium_row(badge, name_str, content.enemy_lore(enemy, lang), discovered, Color(enemy.get("tint", "83e4c1"))))

func _build_compendium_achievements(list: VBoxContainer) -> void:
	if not profile.get("achievements_unlocked") is Dictionary: profile.achievements_unlocked = {}
	var unlocked_n := 0
	for ach in SpiritContent.ACHIEVEMENTS:
		if bool(profile.achievements_unlocked.get(str(ach.id), false)): unlocked_n += 1
	list.add_child(_label(tf("ui.compendium_progress", [unlocked_n, SpiritContent.ACHIEVEMENTS.size()]), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	for ach in SpiritContent.ACHIEVEMENTS:
		var id: String = str(ach.id)
		var unlocked: bool = bool(profile.achievements_unlocked.get(id, false))
		var progress: int = mini(int(ach.target), _achievement_progress(ach))
		var accent: Color = GOLD if unlocked else Color("2a3d42")

		var panel := Panel.new()
		panel.custom_minimum_size.y = 90
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _panel(Color("13282e") if unlocked else Color("0e191d"), 12, accent))
		list.add_child(panel)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 12)
		panel.add_child(pad)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", 4)
		pad.add_child(texts)

		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		texts.add_child(title_row)
		title_row.add_child(_label(content.ui(ach.nameKey, lang), 13, TEXT if unlocked else MUTED))
		if unlocked:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title_row.add_child(spacer)
			title_row.add_child(_label("✦", 13, GOLD))

		texts.add_child(_label(content.ui(ach.descKey, lang), 10, JADE if unlocked else MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		if not unlocked:
			var bar := _stat_bar(120.0, 14.0, progress, int(ach.target), GOLD, "%d / %d" % [progress, int(ach.target)], 9)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texts.add_child(bar)

func _equip(item: Dictionary) -> void:
	if profile.equipment_slots.get(item.slot,"") == item.id: profile.equipment_slots.erase(item.slot)
	else: profile.equipment_slots[item.slot] = item.id
	SpiritSave.write(profile); show_loadout()

func _socket(card_id: String) -> void:
	if selected_rune.is_empty(): _toast(t("ui.loadout_select_first")); return
	var available: int = int(profile.rune_inventory.get(selected_rune,0)) - profile.card_runes.values().count(selected_rune)
	if available <= 0: return
	profile.card_runes[card_id] = selected_rune; SpiritSave.write(profile); selected_rune=""; show_loadout()

func _format_countdown(target_unix: int) -> String:
	var remaining: int = maxi(0, target_unix - int(Time.get_unix_time_from_system()))
	var hours := remaining / 3600
	if hours >= 24:
		var days := hours / 24
		return "%dd" % days if lang == "en" else "%d天" % days
	var minutes := (remaining % 3600) / 60
	return "%dh%02dm" % [hours, minutes] if lang == "en" else "%d时%02d分" % [hours, minutes]

func _quest_section(title: String, list_name: String, reset_at: int) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	section.add_child(head)
	head.add_child(_label(title, 14, JADE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label(tf("ui.quests_daily_reset", _format_countdown(reset_at)), 9, MUTED))

	var quests: Array = profile.get(list_name, [])
	for entry in quests:
		var quest := content.quest_by_id(str(entry.get("id", "")))
		if quest.is_empty(): continue
		var progress := int(entry.get("progress", 0))
		var target := int(entry.get("target", 1))
		var claimed := bool(entry.get("claimed", false))
		var done := progress >= target

		var row := Panel.new()
		row.custom_minimum_size.y = 60
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, JADE if done and not claimed else Color("28393e")))
		section.add_child(row)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
		row.add_child(pad)

		var hrow := HBoxContainer.new()
		hrow.add_theme_constant_override("separation", 10)
		pad.add_child(hrow)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 3)
		hrow.add_child(texts)
		texts.add_child(_label(content.quest_name(quest, lang), 12, TEXT))
		# _stat_bar sizes itself fixed-width (like the health bars it was built for); give it
		# a sane floor and let size_flags stretch it across the row, or it renders at 0 width.
		var bar := _stat_bar(120.0, 16.0, progress, target, JADE if done else GOLD, "%d / %d" % [progress, target], 9)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(bar)

		var action := VBoxContainer.new()
		action.alignment = BoxContainer.ALIGNMENT_CENTER
		hrow.add_child(action)
		if claimed:
			action.add_child(_label(t("ui.quest_claimed"), 10, MUTED))
		else:
			var claim_btn := _button(t("ui.quest_claim") if done else tf("ui.quest_reward_fmt", int(quest.reward)), func(): _claim_quest(list_name, quest.id), EMBER if done else Color("1a2f36"), Vector2(64, 40))
			claim_btn.disabled = not done
			action.add_child(claim_btn)
	return section

func _account_panel() -> Control:
	var account: Dictionary = profile.get("account", {})
	var panel := Panel.new()
	panel.custom_minimum_size.y = 128
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, GOLD))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	pad.add_child(stack)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	stack.add_child(head)
	var holder := CenterContainer.new()
	holder.add_child(_icon_badge("☰", GOLD, 40, 18))
	head.add_child(holder)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 1)
	head.add_child(names)
	names.add_child(_label(str(account.get("name", "—")), 15, TEXT))
	names.add_child(_label(t("ui.account_local"), 9, JADE))
	var rename_btn := _button(t("ui.account_rename"), show_account_setup, Color("17363e"), Vector2(52, 34))
	rename_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rename_btn)

	var created: int = int(account.get("created_at", 0))
	var created_text := Time.get_datetime_string_from_unix_time(created).split("T")[0] if created > 0 else "—"
	stack.add_child(_label(tf("ui.account_created", created_text), 9, MUTED))
	stack.add_child(_label("%s · %s" % [t("ui.account_id"), str(account.get("id", "—")).substr(0, 13)], 9, MUTED))

	var cloud := _button(t("ui.account_cloud"), Callable(), Color("1a2f36"), Vector2(0, 38))
	cloud.disabled = true
	stack.add_child(cloud)
	stack.add_child(_label(t("ui.account_cloud_hint"), 8, Color("5e7278"), HORIZONTAL_ALIGNMENT_LEFT, true))
	return panel

func show_quests() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(8)
	page.add_child(_header(t("ui.quests_title"), t("ui.quests_sub"), show_map))
	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	_ensure_login_reward_current()
	list.add_child(_login_reward_section())
	_ensure_quests_current()
	list.add_child(_quest_section(t("ui.quests_daily"), "daily_quests", int(profile.get("daily_reset_at", 0))))
	list.add_child(_quest_section(t("ui.quests_weekly"), "weekly_quests", int(profile.get("weekly_reset_at", 0))))
	list.add_child(_label(t("ui.quests_hint"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

func _login_reward_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(_label(t("ui.login_reward_title"), 14, JADE))

	var record: Dictionary = profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	var claimed: Array = record.get("claimed", [])

	var bar := _stat_bar(120.0, 16.0, days_logged, 7, JADE, tf("ui.login_reward_progress_fmt", days_logged), 9)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(bar)

	var tiers_row := HBoxContainer.new()
	tiers_row.add_theme_constant_override("separation", 8)
	section.add_child(tiers_row)
	for i in SpiritContent.LOGIN_REWARD_TIERS.size():
		var tier: Dictionary = SpiritContent.LOGIN_REWARD_TIERS[i]
		var tier_days: int = int(tier.days)
		var is_claimed: bool = claimed.has(tier_days)
		var is_ready: bool = days_logged >= tier_days and not is_claimed

		var tile := Panel.new()
		tile.custom_minimum_size = Vector2(0, 74)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, JADE if is_ready else Color("28393e")))
		tiers_row.add_child(tile)

		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 4)
		tile.add_child(stack)
		stack.add_child(_label(tf("ui.login_reward_tier_fmt", tier_days), 10, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(_label(tf("ui.quest_reward_fmt", int(tier.reward)), 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

		if is_claimed:
			stack.add_child(_label(t("ui.quest_claimed"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			var claim_btn := _button(t("ui.quest_claim"), func(): _claim_login_reward(i), EMBER if is_ready else Color("1a2f36"), Vector2(0, 32))
			claim_btn.disabled = not is_ready
			claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stack.add_child(claim_btn)
	return section

func show_camp() -> void:
	_clear(); _play_music(false)
	_back_action = show_map
	var page := _create_page(6)
	page.add_child(_header(t("ui.camp_title"), t("ui.camp_sub"), show_map))
	page.add_child(_tab_bar([
		["character", t("ui.camp_tab_character")],
		["challenges", t("ui.camp_tab_challenges")],
		["collection", t("ui.camp_tab_collection")],
	], camp_tab, func(id): camp_tab = id; show_camp()))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	match camp_tab:
		"challenges": _build_camp_challenges(list)
		"collection": _build_camp_collection(list)
		_: _build_camp_character(list)

# "Who you are": account identity plus the hero archetype you're actually playing. Split out
# of what used to be one long show_camp() scroll (account, compendium, hero mastery, daily
# trial, abyss, difficulty, relics — 7 sections stacked vertically) once Milestone 4 pushed it
# past the point of being scannable in one screen.
func _build_camp_character(list: VBoxContainer) -> void:
	list.add_child(_account_panel())
	list.add_child(_hero_archetypes_section())

# "Modes you enter": the two challenge tracks (Daily Trial, Endless Abyss) plus the campaign's
# own difficulty ladder — all three answer "what am I about to go fight," not "who am I" or
# "what have I collected."
func _build_camp_challenges(list: VBoxContainer) -> void:
	list.add_child(_daily_trial_section())
	list.add_child(_weekly_challenge_section())
	list.add_child(_abyss_section())
	list.add_child(_difficulty_tier_section())

# "What you've earned": the Compendium entry point plus the actual relics owned right now —
# the Compendium already covers cards/gear/runes/bestiary/achievements, so relics-in-hand
# stays here as the one collection view that's about current loadout, not lifetime discovery.
func _build_camp_collection(list: VBoxContainer) -> void:
	list.add_child(_compendium_section())
	list.add_child(_relics_section())

func _difficulty_tier_section() -> Control:
	var unlocked := int(profile.unlocked) >= 25
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(_label(tf("ui.camp_tier", profile.difficulty), 17, JADE if unlocked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		section.add_child(_label("🔒 " + t("ui.lock_clears_ch5"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		return section
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	for value in 6:
		var button := _button("A%d"%value, func(): profile.difficulty=value; SpiritSave.write(profile); show_camp(), Color("245247") if value==profile.difficulty else Color("17363e"), Vector2(0,40))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(button)
	section.add_child(row)
	section.add_child(_label(t("ui.camp_desc"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	return section

func _relics_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(_label(tf("ui.camp_relics", profile.relics.size()), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if profile.relics.is_empty():
		section.add_child(_label(t("ui.relic_none"), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return section
	for id in profile.relics:
		var relic := content.relic(id)
		if relic.is_empty(): continue
		var color := Color(relic.color)
		var row_panel := Panel.new()
		row_panel.custom_minimum_size.y = 56
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.add_theme_stylebox_override("panel", _panel(Color("12262b"), 12, color))
		section.add_child(row_panel)
		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
		row_panel.add_child(pad)
		var relic_row := HBoxContainer.new()
		relic_row.add_theme_constant_override("separation", 10)
		pad.add_child(relic_row)
		var holder := CenterContainer.new()
		holder.add_child(_sigil_icon_badge(str(relic.get("icon_mark", "sparkle")), color, 38))
		relic_row.add_child(holder)
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 1)
		relic_row.add_child(texts)
		texts.add_child(_label(_relic_name(relic), 12, TEXT))
		texts.add_child(_label(_relic_detail(relic), 9, color, HORIZONTAL_ALIGNMENT_LEFT, true))
	return section

func _compendium_section() -> Control:
	var unlocked := int(profile.unlocked) >= 5
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 64)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col := Color("8ff5cf") if unlocked else Color("2a3d42")
	panel.add_theme_stylebox_override("panel", _panel(Color("142418") if unlocked else Color("101a1c"), 14, border_col))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	texts.add_child(_label(t("ui.compendium_title"), 15, Color("8ff5cf") if unlocked else MUTED))
	if unlocked:
		var totals := _compendium_totals()
		texts.add_child(_label(tf("ui.compendium_progress", [totals.x, totals.y]), 10, MUTED))
	else:
		texts.add_child(_label("🔒 " + t("ui.lock_clears_ch1"), 10, Color("ff9868")))

	var open_btn := _button(t("ui.compendium_open_btn") if unlocked else ("🔒 " + t("ui.locked")), show_compendium, Color("1e4a35") if unlocked else Color("162428"), Vector2(0, 40))
	open_btn.name = "CompendiumOpenBtn"
	open_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open_btn.disabled = not unlocked
	row.add_child(open_btn)

	return panel

func _daily_trial_section() -> Control:
	_ensure_daily_trial_current()
	var unlocked := int(profile.unlocked) >= 5
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 130)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("241a10") if unlocked else Color("181412"), 14, Color("ffb765") if unlocked else Color("2a3d42")))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	pad.add_child(stack)

	stack.add_child(_label(t("ui.daily_trial_title"), 16, Color("ffb765") if unlocked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		stack.add_child(_label("🔒 " + t("ui.lock_clears_ch1"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var enter_btn := _button("🔒 " + t("ui.locked"), begin_daily_trial, Color("2d2218"), Vector2(240, 40))
		enter_btn.name = "DailyTrialEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)
		return panel

	stack.add_child(_label(t("ui.daily_trial_sub"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var tags: Array = content.daily_trial_tags(int(profile.daily_trial_record.day))
	var tag_names: Array = []
	for tag in tags: tag_names.append(content.ui(tag.nameKey, lang))
	var sep: String = ", " if lang == "en" else "、"
	stack.add_child(_label("%s: %s" % [t("ui.daily_trial_modifiers_title"), sep.join(tag_names)], 9, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_CENTER, true))

	var stage_num: int = int(profile.daily_trial_record.stage)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 10)
	stats.add_child(_label(tf("ui.daily_trial_progress_fmt", stage_num), 11, GOLD))
	stats.add_child(_label(tf("ui.daily_trial_best_fmt", int(profile.daily_trial_record.get("best_stage", 0))), 11, JADE))
	stats.add_child(_label(tf("ui.daily_trial_badges_fmt", int(profile.daily_trial_record.get("badges", 0))), 11, Color("ffd8a8")))
	stats.add_child(_label(tf("ui.daily_trial_streak_fmt", int(profile.daily_trial_record.get("streak", 0))), 11, Color("ff9868")))
	stack.add_child(stats)

	if stage_num >= SpiritContent.DAILY_TRIAL_STAGES:
		stack.add_child(_label(t("ui.daily_trial_done"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		var enter_btn := _button(t("ui.daily_trial_enter"), begin_daily_trial, Color("6b4420"), Vector2(240, 40))
		enter_btn.name = "DailyTrialEnterBtn"
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)

	return panel

func _weekly_challenge_section() -> Control:
	_ensure_weekly_challenge_current()
	var unlocked := int(profile.unlocked) >= 5
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 130)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel(Color("1a2410") if unlocked else Color("181412"), 14, Color("c8e065") if unlocked else Color("2a3d42")))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	pad.add_child(stack)

	stack.add_child(_label(t("ui.weekly_challenge_title"), 16, Color("c8e065") if unlocked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		stack.add_child(_label("🔒 " + t("ui.lock_clears_ch1"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var enter_btn := _button("🔒 " + t("ui.locked"), begin_weekly_challenge, Color("2d2218"), Vector2(240, 40))
		enter_btn.name = "WeeklyChallengeEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)
		return panel

	stack.add_child(_label(t("ui.weekly_challenge_sub"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var week: int = int(profile.weekly_challenge_record.week)
	var tag: Dictionary = content.weekly_challenge_tag(week)
	stack.add_child(_label("%s: %s" % [t("ui.weekly_challenge_modifier_title"), content.ui(tag.nameKey, lang)], 9, Color("e0f0a8"), HORIZONTAL_ALIGNMENT_CENTER, true))

	var stage_num: int = int(profile.weekly_challenge_record.stage)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 10)
	stats.add_child(_label(tf("ui.weekly_challenge_progress_fmt", stage_num), 11, GOLD))
	stats.add_child(_label(tf("ui.weekly_challenge_best_fmt", int(profile.weekly_challenge_record.get("best_stage", 0))), 11, JADE))
	stats.add_child(_label(tf("ui.weekly_challenge_badges_fmt", int(profile.weekly_challenge_record.get("badges", 0))), 11, Color("e0f0a8")))
	stack.add_child(stats)

	if stage_num >= SpiritContent.WEEKLY_CHALLENGE_STAGES:
		stack.add_child(_label(t("ui.weekly_challenge_done"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		var enter_btn := _button(t("ui.weekly_challenge_enter"), begin_weekly_challenge, Color("4a5a20"), Vector2(240, 40))
		enter_btn.name = "WeeklyChallengeEnterBtn"
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)

	return panel

func _hero_archetypes_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label(t("ui.hero_classes_title"), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var current_class_id: String = str(profile.get("hero_class", "fox_spirit"))
	for h in content.HERO_CLASSES:
		var is_selected: bool = h.id == current_class_id
		var art_pending: bool = bool(h.get("art_pending", false))
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(340, 116 if art_pending else 104)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border_col: Color = GOLD if is_selected else Color("1a3d44")
		panel.add_theme_stylebox_override("panel", _panel(Color("10242b") if not is_selected else Color("153038"), 12, border_col))

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 8)
		panel.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		pad.add_child(row)

		var portrait := CenterContainer.new()
		portrait.custom_minimum_size = Vector2(48, 48)
		var spr := TextureRect.new()
		spr.texture = _get_character_texture(str(h.sprite))
		spr.custom_minimum_size = Vector2(44, 44)
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# A borrowed portrait (see art_pending below) is deliberately desaturated/dimmed so it
		# never reads as "this new hero secretly looks like Stone Sentinel" — it reads as
		# "placeholder," which is what it is.
		if art_pending: spr.modulate = Color(0.6, 0.6, 0.6, 0.55)
		portrait.add_child(spr)
		row.add_child(portrait)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", 2)
		row.add_child(texts)

		var name_str: String = content.hero_name(h, lang)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		name_row.add_child(_label(name_str + ("  ✓" if is_selected else ""), 13, JADE if is_selected else TEXT))
		if h.id == "fox_spirit":
			var rec_badge := PanelContainer.new()
			rec_badge.name = "BeginnerRecBadge"
			rec_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rec_badge.add_theme_stylebox_override("panel", _panel(Color("2d2208"), 6, Color("ffd700")))
			var rec_pad := MarginContainer.new()
			rec_pad.add_theme_constant_override("margin_left", 6)
			rec_pad.add_theme_constant_override("margin_right", 6)
			rec_pad.add_theme_constant_override("margin_top", 1)
			rec_pad.add_theme_constant_override("margin_bottom", 1)
			rec_pad.add_child(_label(t("ui.hero_rec_badge"), 8, Color("ffd700"), HORIZONTAL_ALIGNMENT_CENTER))
			rec_badge.add_child(rec_pad)
			name_row.add_child(rec_badge)
		texts.add_child(name_row)
		if h.id == "fox_spirit":
			texts.add_child(_label(t("ui.hero_rec_desc"), 8, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_LEFT, true))
		texts.add_child(_label(content.hero_desc(h, lang), 9, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		# This hero's mechanics and deck are fully implemented; only a unique painted portrait
		# is missing (the character atlas is a fixed 3x3 grid and all 9 cells are already
		# spoken for by the other 3 heroes and their shared enemy pool — see
		# Docs/GROWTH_ROADMAP.md's D3 note for what a real fix needs). Surfacing that honestly
		# in the UI beats silently reusing another hero's face and hoping nobody notices.
		if art_pending:
			texts.add_child(_label(t("ui.hero_art_pending"), 8, Color("ff9868")))

		var hero_xp: int = int(profile.get("hero_masteries", {}).get(h.id, {}).get("xp", 0))
		var hero_level: int = content.mastery_level_for_xp(hero_xp)
		var mastery_line: String = tf("ui.mastery_level_fmt", hero_level)
		mastery_line += "  " + (t("ui.mastery_maxed") if hero_level >= 5 else tf("ui.mastery_progress_fmt", [hero_xp, content.mastery_xp_for_level(hero_level + 1)]))
		texts.add_child(_label(mastery_line, 9, GOLD))
		var perk: Dictionary = content.mastery_perk(h.id, hero_level)
		if not perk.is_empty():
			texts.add_child(_label("%s · %s" % [content.ui(perk.nameKey, lang), content.ui(perk.descKey, lang)], 8, Color("9fd8c9"), HORIZONTAL_ALIGNMENT_LEFT, true))

		var sel_btn := _button("✓" if is_selected else t("ui.hero_class_select"), func():
			profile.hero_class = h.id
			profile.deck = h.deck.duplicate()
			for cid in h.deck:
				profile.collection[cid] = maxi(int(profile.collection.get(cid, 0)), h.deck.count(cid))
			var relic_id: String = str(h.get("relic", ""))
			if not relic_id.is_empty() and not profile.relics.has(relic_id):
				profile.relics.append(relic_id)
			SpiritSave.write(profile)
			_haptic("heavy")
			_toast(tf("ui.hero_selected_toast", name_str), GOLD)
			show_camp()
		, GOLD if is_selected else Color("1a3d44"), Vector2(68, 38))
		sel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sel_btn)

		box.add_child(panel)

	return box

func _abyss_section() -> Control:
	var unlocked := int(profile.unlocked) >= 10
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 110)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col := Color("c79bff") if unlocked else Color("2a3d42")
	panel.add_theme_stylebox_override("panel", _panel(Color("1b1024") if unlocked else Color("141018"), 14, border_col))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	pad.add_child(stack)

	stack.add_child(_label(t("ui.abyss_title"), 16, Color("e0b8ff") if unlocked else MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		stack.add_child(_label("🔒 " + t("ui.lock_clears_ch2"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var enter_btn := _button("🔒 " + t("ui.locked"), begin_abyss_battle, Color("2d1b33"), Vector2(240, 40))
		enter_btn.name = "AbyssEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)
		return panel

	stack.add_child(_label(t("ui.abyss_sub"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var floor_num: int = int(profile.get("abyss_floor", 1))
	var record_num: int = int(profile.get("abyss_record", 0))

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 16)
	stats.add_child(_label(tf("ui.abyss_floor_fmt", floor_num), 11, GOLD))
	stats.add_child(_label(tf("ui.abyss_record_fmt", record_num), 11, JADE))
	stack.add_child(stats)

	var enter_btn := _button(t("ui.abyss_enter"), begin_abyss_battle, Color("4a285d"), Vector2(240, 40))
	enter_btn.name = "AbyssEnterBtn"
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(enter_btn)

	return panel

func begin_abyss_battle() -> void:
	in_abyss = true
	var floor_num: int = int(profile.get("abyss_floor", 1))
	var enc: Dictionary = content.abyss_encounter(floor_num)
	current_stage = 0
	var seed := int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	active_modifier = _modifier(seed, floor_num)
	active_modifier["boons"] = profile.get("abyss_boons", []).duplicate()
	combat = SpiritCombat.new(content)
	var equipped: Array = profile.equipment_slots.values()
	combat.create(seed, enc, profile.deck, int(profile.health), profile.upgrades, equipped, profile.card_runes, active_modifier, profile.relics, _current_hero_mastery_bonuses())
	combat.event.connect(_combat_event)
	if _mark_discovered("bestiary", str(enc.name)):
		_grant_bestiary_discovery_bonus(enc)
	pre_battle_health = int(profile.health)
	advancing_to_reward = false
	selected_card = -1
	show_battle()
	_maybe_end_turn()

func begin_daily_trial() -> void:
	_ensure_daily_trial_current()
	if int(profile.daily_trial_record.stage) >= SpiritContent.DAILY_TRIAL_STAGES: return
	in_daily_trial = true
	var day: int = int(profile.daily_trial_record.day)
	var stage_num: int = int(profile.daily_trial_record.stage) + 1
	var enc: Dictionary = content.daily_trial_encounter(stage_num)
	current_stage = 0
	# Seeded by the day index (not wall-clock time like campaign/abyss battles), so every
	# device attempting today's trial fights the exact same encounter — the "deterministic
	# seed" the daily challenge is named for.
	active_modifier = content.daily_trial_modifier(day)
	combat = SpiritCombat.new(content)
	var equipped: Array = profile.equipment_slots.values()
	combat.create(day * 1000 + stage_num, enc, profile.deck, int(profile.health), profile.upgrades, equipped, profile.card_runes, active_modifier, profile.relics, _current_hero_mastery_bonuses())
	combat.event.connect(_combat_event)
	if _mark_discovered("bestiary", str(enc.name)):
		_grant_bestiary_discovery_bonus(enc)
	pre_battle_health = int(profile.health)
	advancing_to_reward = false
	selected_card = -1
	show_battle()
	_maybe_end_turn()

func begin_weekly_challenge() -> void:
	_ensure_weekly_challenge_current()
	if int(profile.weekly_challenge_record.stage) >= SpiritContent.WEEKLY_CHALLENGE_STAGES: return
	in_weekly_challenge = true
	var week: int = int(profile.weekly_challenge_record.week)
	var stage_num: int = int(profile.weekly_challenge_record.stage) + 1
	var enc: Dictionary = content.weekly_challenge_encounter(stage_num)
	current_stage = 0
	# Seeded by the week index, same deterministic-per-period approach as the Daily Trial —
	# every device attempting this week's challenge fights the exact same encounter.
	active_modifier = content.weekly_challenge_modifier(week)
	combat = SpiritCombat.new(content)
	var equipped: Array = profile.equipment_slots.values()
	combat.create(week * 1000 + stage_num, enc, profile.deck, int(profile.health), profile.upgrades, equipped, profile.card_runes, active_modifier, profile.relics, _current_hero_mastery_bonuses())
	combat.event.connect(_combat_event)
	if _mark_discovered("bestiary", str(enc.name)):
		_grant_bestiary_discovery_bonus(enc)
	pre_battle_health = int(profile.health)
	advancing_to_reward = false
	selected_card = -1
	show_battle()
	_maybe_end_turn()

func show_abyss_boon_draft() -> void:
	_clear()
	var page := _create_page(12)
	page.add_child(_header(t("ui.boon_draft_title"), t("ui.boon_draft_sub"), show_reward_details))

	var current_boons: Array = profile.get("abyss_boons", [])
	var pool: Array = []
	for boon in content.ABYSS_BOONS:
		if not current_boons.has(boon.id):
			pool.append(boon)
	if pool.is_empty(): pool = content.ABYSS_BOONS.duplicate()
	pool.shuffle()
	var offered: Array = pool.slice(0, mini(3, pool.size()))

	var card_list := VBoxContainer.new()
	card_list.name = "BoonDraftList"
	card_list.add_theme_constant_override("separation", 14)
	card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_list.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(card_list)

	for boon in offered:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(350, 96)
		var p_style := _panel(Color("101d24"), 12, Color(boon.color))
		p_style.content_margin_left = 16; p_style.content_margin_right = 16
		p_style.content_margin_top = 12; p_style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", p_style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)

		var icon_lbl := _label(boon.icon, 28, Color(boon.color), HORIZONTAL_ALIGNMENT_CENTER)
		icon_lbl.custom_minimum_size = Vector2(40, 40)
		row.add_child(icon_lbl)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_str: String = content.ui(boon.nameKey, lang)
		info.add_child(_label(name_str, 15, TEXT))
		info.add_child(_label(content.ui(boon.descKey, lang), 10, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

		var choose_btn := _button(t("ui.claim"), func(): _select_abyss_boon(boon), Color("244a56"), Vector2(68, 40))
		choose_btn.name = "ChooseBoon_" + boon.id
		row.add_child(choose_btn)

		card_list.add_child(panel)

func _select_abyss_boon(boon: Dictionary) -> void:
	if not profile.has("abyss_boons") or not profile.abyss_boons is Array: profile.abyss_boons = []
	profile.abyss_boons.append(boon.id)
	SpiritSave.write(profile)
	_toast(tf("ui.boon_acquired_toast", content.ui(boon.nameKey, lang)))
	show_reward_details()

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

func show_settings() -> void:
	var existing: Node = overlay.get_node_or_null("SettingsModal")
	if existing: existing.queue_free(); return

	var modal := _modal_backdrop("SettingsModal", func(): _close_settings())

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340, 420)
	panel.size = panel.custom_minimum_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _panel(Color("0e1d22"), 14, GOLD))
	modal.add_child(panel)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(pad)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	pad.add_child(list)

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

func _close_settings() -> void:
	var existing: Node = overlay.get_node_or_null("SettingsModal")
	if existing: existing.queue_free()

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

func _on_pin_pressed(index: int) -> void:
	if _is_replay(index) and content.node_kind(index) in ["battle", "elite", "boss", "greatboss"]:
		_show_replay_mode_prompt(index)
	else:
		is_hard_replay = false
		_travel_to(index)

func _show_replay_mode_prompt(index: int) -> void:
	var existing: Node = overlay.get_node_or_null("ReplayModal")
	if existing: existing.queue_free()

	var modal := _modal_backdrop("ReplayModal", func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex: ex.queue_free()
	)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340, 240)
	panel.size = panel.custom_minimum_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_theme_stylebox_override("panel", _panel(Color("0f1e23"), 14, Color("34626d")))
	modal.add_child(panel)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 14)
	panel.add_child(pad)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	pad.add_child(list)

	list.add_child(_label(t("ui.replay_modal_title"), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var normal_btn := _button(t("ui.replay_normal_title"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex: ex.queue_free()
		is_hard_replay = false
		_travel_to(index)
	, Color("17363e"), Vector2(0, 44))
	normal_btn.name = "ReplayNormalBtn"
	list.add_child(normal_btn)
	list.add_child(_label(t("ui.replay_normal_desc"), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var hard_btn := _button(t("ui.replay_hard_title"), func():
		var ex: Node = overlay.get_node_or_null("ReplayModal")
		if ex: ex.queue_free()
		is_hard_replay = true
		_travel_to(index)
	, EMBER, Vector2(0, 44))
	hard_btn.name = "ReplayHardBtn"
	list.add_child(hard_btn)
	list.add_child(_label(t("ui.replay_hard_desc"), 9, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_CENTER, true))

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
