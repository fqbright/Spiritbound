extends SceneTree

var failures := 0
var saved_profile := ""
var had_profile := false

func section(name: String) -> void:
	print(name)
	printerr("[section] " + name)

func fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)

func check(condition: bool, message: String) -> void:
	if condition: print("  ok: %s" % message)
	else: fail(message)

func _initialize() -> void:
	_run()

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn")
	var game: Control = scene.instantiate()
	# A parse error in game.gd leaves Main.tscn as a bare Control. Without this guard the
	# first call below dies inside the coroutine and the process hangs instead of failing.
	if not game.has_method("show_map"):
		printerr("game.gd did not attach — check for a parse error")
		print("UI SMOKE: game.gd failed to parse")
		quit(1)
		return
	# This walk grants relics and buys cards, and the game writes those through to the real
	# save. Borrow the file and start from a clean profile, or a previous run's rewards leak
	# into this one — a run that had collected foxCharm reported three opening plays, not two.
	had_profile = FileAccess.file_exists(SpiritSave.PATH)
	if had_profile: saved_profile = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()

	root.add_child(game)
	await process_frame
	game.profile = SpiritSave.defaults(game.content)
	game.battle_speed = 1.0
	game.lang = "zh-Hans"
	await process_frame

	section("== account ==")
	check(game.profile.has("account") and game.profile.account.has("id"), "profile carries an account id")
	check(int(game.profile.get("schema_version", 0)) >= 2, "save declares a schema version")
	game.show_account_setup()
	await process_frame
	check(game.root.get_child_count() > 0, "account setup screen builds")
	check(game.root.find_child("SignInWithAppleBtn", true, false) != null, "SignInWithAppleBtn exists in account setup")
	check(game.root.find_child("SignInWithGoogleBtn", true, false) != null, "SignInWithGoogleBtn exists in account setup")
	game._create_account("测试驭灵者")
	await process_frame
	check(str(game.profile.account.name) == "测试驭灵者", "account name persists")
	check(int(game.profile.get("updated_at", 0)) > 0, "write stamps updated_at for cloud sync")

	section("== quests ==")
	game.profile.daily_reset_at = 0
	game.profile.weekly_reset_at = 0
	game._ensure_quests_current()
	check(game.profile.daily_quests.size() == 3, "three daily quests roll on reset, got %d" % game.profile.daily_quests.size())
	check(game.profile.weekly_quests.size() == 3, "three weekly quests roll on reset, got %d" % game.profile.weekly_quests.size())
	var reset_at_before: int = int(game.profile.daily_reset_at)
	game._ensure_quests_current()
	check(int(game.profile.daily_reset_at) == reset_at_before, "calling ensure_quests_current again this period does not reroll")

	var win_quest: Dictionary = game.profile.daily_quests[0]
	win_quest.type = "win_battles"
	win_quest.progress = 0
	win_quest.target = 2
	win_quest.claimed = false
	game._advance_quest("win_battles", 1)
	check(int(win_quest.progress) == 1, "advance_quest bumps matching quests")
	game._advance_quest("shop_purchase", 5)
	check(int(win_quest.progress) == 1, "advance_quest leaves non-matching quests alone")
	game._advance_quest("win_battles", 1)
	check(int(win_quest.progress) == 2, "quest reaches its target")

	var gold_before: int = int(game.profile.gold)
	game._claim_quest("daily_quests", str(win_quest.id))
	check(bool(win_quest.claimed), "claiming marks the quest claimed")
	check(int(game.profile.gold) == gold_before + int(win_quest.reward), "claiming grants its gold reward (%d)" % int(win_quest.reward))
	var gold_after_claim: int = int(game.profile.gold)
	game._claim_quest("daily_quests", str(win_quest.id))
	check(int(game.profile.gold) == gold_after_claim, "claiming an already-claimed quest does not pay out twice")

	section("== rolling weekly login reward ==")
	game.profile.login_reward = {"week": -1, "days": [], "claimed": []}
	game._ensure_login_reward_current()
	check(int(game.profile.login_reward.days.size()) == 1, "the first _ensure_login_reward_current call of a new week logs exactly one day")
	game._ensure_login_reward_current()
	check(int(game.profile.login_reward.days.size()) == 1, "calling it again the same day does not double-log")
	# Simulate having visited on 3 distinct days this week without waiting three real days.
	game.profile.login_reward.days = [game.profile.login_reward.days[0] - 2, game.profile.login_reward.days[0] - 1, game.profile.login_reward.days[0]]
	check(game._has_claimable_quest(), "3 days logged makes the first login-reward tier claimable")
	game.show_quests()
	await process_frame
	var login_gold_before: int = int(game.profile.gold)
	game._claim_login_reward(0)
	check(int(game.profile.gold) == login_gold_before + int(SpiritContent.LOGIN_REWARD_TIERS[0].reward), "claiming the 3-day login tier grants its gold")
	check(game.profile.login_reward.claimed.has(3), "the 3-day tier is recorded as claimed")
	var gold_after_login_claim: int = int(game.profile.gold)
	game._claim_login_reward(0)
	check(int(game.profile.gold) == gold_after_login_claim, "claiming an already-claimed login tier does not pay out twice")
	game._claim_login_reward(1)
	check(int(game.profile.gold) == gold_after_login_claim, "the 5-day tier cannot be claimed with only 3 days logged")
	var new_week_record: Dictionary = game.profile.login_reward
	new_week_record.week = int(new_week_record.week) - 1
	game.profile.login_reward = new_week_record
	game._ensure_login_reward_current()
	check(int(game.profile.login_reward.days.size()) == 1 and game.profile.login_reward.claimed.is_empty(), "a new week resets the login tally and claimed tiers")

	game.show_quests()
	await process_frame
	check(game.root.get_child_count() > 0, "quests screen builds with quest sections")
	var quest_bar := _find_progress_bar(game.root)
	check(quest_bar != null and quest_bar.size.x > 20.0, "quest progress bar has real width, not collapsed to zero")

	game.show_camp()
	await process_frame
	check(game.root.get_child_count() > 0, "camp screen builds with profile & relics")

	section("== map ==")
	game.show_map()
	await process_frame
	check(game.map_canvas != null, "map canvas built")
	check(game.map_canvas.custom_minimum_size.y == game.BAND_HEIGHT, "map canvas displays single chapter height (BAND_HEIGHT)")
	var plaque_node: Control = game.root.find_child("ChapterPlaque", true, false) as Control
	check(plaque_node != null, "chapter plaque exists on single-chapter map")
	check(plaque_node != null and not (plaque_node is Panel), "chapter plaque has no panel/frame background, just floating text")
	check(game.root.find_child("ChapterPrevBtn", true, false) == null and game.root.find_child("ChapterNextBtn", true, false) == null, "chapter prev/next buttons were removed in favor of swipe-to-switch")
	var saved_ch_swipe: int = int(game.current_map_chapter)
	var saved_unlocked_swipe: int = int(game.profile.unlocked)
	game.profile.unlocked = 5 # unlock chapter 1 so the "swipe to next chapter" case is reachable
	game.current_map_chapter = 0
	game.show_map()
	await process_frame
	game.map_scroll.swipe_released.emit(Vector2(-90.0, -10.0))
	await process_frame
	check(game.root.find_child("ChapterSlideWrapper", true, false) != null, "a swipe rolls the map across instead of cutting instantly")
	check(game.current_map_chapter == 0, "the browsed chapter does not change until the roll finishes")
	var swipe_wait := 0.0
	while game._map_screen._chapter_slide_active and swipe_wait < 2.0:
		await create_timer(0.05).timeout
		swipe_wait += 0.05
	check(game.current_map_chapter == 1, "a left swipe on the map advances to the next chapter once the roll finishes")
	game.map_scroll.swipe_released.emit(Vector2(90.0, 10.0))
	swipe_wait = 0.0
	while game._map_screen._chapter_slide_active and swipe_wait < 2.0:
		await create_timer(0.05).timeout
		swipe_wait += 0.05
	check(game.current_map_chapter == 0, "a right swipe on the map goes back to the previous chapter")
	game.map_scroll.swipe_released.emit(Vector2(90.0, 10.0))
	swipe_wait = 0.0
	while game._map_screen._chapter_slide_active and swipe_wait < 2.0:
		await create_timer(0.05).timeout
		swipe_wait += 0.05
	check(game.current_map_chapter == 0, "a right swipe does not go below chapter 0")
	game.profile.unlocked = saved_unlocked_swipe
	game.current_map_chapter = saved_ch_swipe
	game.show_map()
	await process_frame

	section("== map branching (level 2/3/4 forks) ==")
	# The map used to be strictly linear (fixed kind per level), so these checks pin the new
	# contract: levels 2/3/4 offer exactly two forks, levels 1/5 stay fixed, and a player's
	# choice is what get_node_kind() reports from then on.
	for lvl_index in [1, 2, 3]:
		check(game.content.node_branch_options(lvl_index).size() == 2,
			"level %d offers exactly two fork options" % (lvl_index % 5 + 1))
	for fixed_index in [0, 4]:
		check(game.content.node_branch_options(fixed_index).is_empty(),
			"level %d stays fixed (no fork)" % (fixed_index % 5 + 1))
	# Every advertised option must be a kind the map can actually render and enter — an
	# invented string here would render a fallback pin and then dead-end on travel.
	var known_kinds := ["event", "merchant", "elite", "battle", "rest", "bonus", "boss", "greatboss"]
	var all_known := true
	for i in 10:
		for opt in game.content.node_branch_options(i):
			if not known_kinds.has(opt): all_known = false
	check(all_known, "every fork option is a real node kind the map can render and enter")

	var saved_map_choices: Dictionary = game.profile.get("map_choices", {}).duplicate(true)
	var saved_branch_position: int = int(game.profile.position)

	# No choice recorded yet -> the deterministic default still answers, so a fresh profile's map
	# renders identically to the pre-branching game.
	game.profile.map_choices = {}
	check(game.get_node_kind(1) == game.content.node_kind(1),
		"before any choice is made, get_node_kind() falls back to the deterministic default")

	# A recorded choice wins over the default...
	game.make_map_choice(1, "merchant")
	check(game.get_node_kind(1) == "merchant", "a recorded fork choice overrides the default kind")
	check(game.get_node_kind(0) == game.content.node_kind(0),
		"choosing on one node does not disturb a fixed node")
	# ...but only if it's one of that node's own legal options, so a corrupt/hand-edited save
	# can't steer the player into a kind this node was never allowed to be.
	game.make_map_choice(1, "greatboss")
	check(game.get_node_kind(1) == game.content.node_kind(1),
		"an illegal stored kind is rejected in favour of the default, not trusted")
	game.make_map_choice(1, "merchant")

	# The picker's two options must each build a real, tappable card.
	game.show_map()
	await process_frame
	game._map_screen._show_branch_picker(1, game.content.node_branch_options(1))
	await process_frame
	var picker: Node = game.overlay.get_node_or_null("BranchPicker")
	check(picker != null, "arriving at an unchosen fork node shows the branch picker")
	var picker_buttons: Array = []
	if picker != null:
		for b in _all_controls(picker):
			if b is Button and (b as Button).custom_minimum_size.x > 100: picker_buttons.append(b)
	check(picker_buttons.size() == 2, "the branch picker offers exactly two choices (got %d)" % picker_buttons.size())
	# Both option names must be rendered distinctly, or the player is choosing blind. Checked
	# language-agnostically (two non-empty, different labels) rather than by hardcoding one
	# language's strings, since the picker picks its wording from the profile's language.
	if picker != null:
		var option_names: Array = []
		for l in _all_controls(picker):
			if l is Label and not (l as Label).text.strip_edges().is_empty():
				option_names.append((l as Label).text)
		var distinct_names := {}
		for n in option_names: distinct_names[n] = true
		check(option_names.size() >= 2 and distinct_names.size() >= 2,
			"both fork options are labelled, and differently (found %d labels, %d distinct)"
				% [option_names.size(), distinct_names.size()])
	# Choosing persists *before* the node is entered, so an app kill during the transition
	# can't lose the pick and re-offer the fork.
	game.profile.map_choices = {}
	if picker_buttons.size() == 2:
		(picker_buttons[1] as Button).pressed.emit()
		await process_frame
		check(str(game.profile.get("map_choices", {}).get("1", "")) == "merchant",
			"tapping an option records the choice (%s)" % str(game.profile.get("map_choices", {}).get("1", "")))
		check(game.get_node_kind(1) == "merchant", "the recorded pick is what the map now resolves to")
		var dismissed: Node = game.overlay.get_node_or_null("BranchPicker")
		check(dismissed == null or not dismissed.is_inside_tree(), "the picker dismisses itself once a choice is made")
		await create_timer(0.3).timeout

	# make_map_choice must survive a profile that predates the field entirely (the upgrade path
	# for an existing install), rather than erroring on a missing key.
	game.profile.erase("map_choices")
	game.make_map_choice(1, "event")
	check(game.profile.get("map_choices") is Dictionary, "make_map_choice creates the field on a pre-branching profile")
	check(str(game.profile.map_choices.get("1", "")) == "event", "and the choice lands in it")
	# The real upgrade path for an existing install: a profile written *before* branching has no
	# map_choices key at all, and must still load with the field present. Exercised against a
	# throwaway save file and restored immediately — ui_smoke's own teardown (_restore_save)
	# holds the same text, so an early failure here still can't lose the player's profile.
	var pre_branch_text := ""
	if FileAccess.file_exists(SpiritSave.PATH):
		pre_branch_text = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()
	var pre_write := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
	if pre_write != null:
		pre_write.store_string('{"schema_version":1,"gold":1,"deck":[]}')
		pre_write.close()
	var migrated: Dictionary = SpiritSave.load_profile(game.content)
	check(migrated.get("map_choices") is Dictionary,
		"a profile saved before branching loads with map_choices added")
	check(migrated.get("map_choices").is_empty(), "the migrated field starts empty, not pre-filled")
	var pre_restore := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
	if pre_restore != null:
		pre_restore.store_string(pre_branch_text)
		pre_restore.close()
	check(FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text() == pre_branch_text,
		"the pre-branching migration test restores the save file it borrowed")

	# Turning down a fork must let the player walk the default path instead of being stuck.
	game.profile.map_choices = {}
	game.show_map()
	await process_frame
	check(game.get_node_kind(1) == game.content.node_kind(1),
		"declining to choose leaves the node on its default kind (no dead end)")

	# The level-4 alternative kind must render an event page rather than falling through.
	game.show_event(3, "bonus")
	await process_frame
	check(_find_label_containing(game.root, game.content.ui("ui.bonus_title", game.lang)),
		"the level-4 'bonus' branch renders its own event screen")

	game.profile.map_choices = saved_map_choices
	game.profile.position = saved_branch_position
	game.show_map()
	await process_frame

	section("== organic map path ==")
	var wp0: Array = game._chapter_waypoints(0)
	var wp1: Array = game._chapter_waypoints(1)
	check(wp0.size() == 5 and wp1.size() == 5, "each chapter still has exactly 5 stage slots")
	var differs := false
	for i in 5:
		if not (wp0[i] as Vector2).is_equal_approx(wp1[i]): differs = true
	check(differs, "chapters no longer reuse the exact same five pixel offsets")
	var wp0_again: Array = game._chapter_waypoints(0)
	check(wp0[0].is_equal_approx(wp0_again[0]), "the same chapter's waypoints are deterministic across calls (cached)")
	for p in wp0:
		var v: Vector2 = p
		check(v.x >= game.ROAD_MARGIN_X - 0.01 and v.x <= game.MAP_WIDTH - game.ROAD_MARGIN_X + 0.01, "waypoint stays clear of the screen edge (x=%.1f)" % v.x)

	# Every chapter now has its own unique painted background (not 6 reused biome images), so
	# each one gets its own pixel-traced entry in CHAPTER_PATH_WAYPOINTS instead of cycling
	# through BIOME_PATH_WAYPOINTS by chapter%6 — reusing only 6 hand-picked shapes across 50
	# distinct paintings is exactly what put pins and the drawn road over rocks/rooftops on
	# most chapters. BIOME_PATH_WAYPOINTS (and the mirroring that went with it) now applies
	# only to the fallback case where a chapter's own art file is missing.
	check(game._chapter_has_unique_art(0) and game._chapter_has_unique_art(6), "chapters 0 and 6 both have their own unique background art")
	var expected_ch0: Array = game.CHAPTER_PATH_WAYPOINTS[0]
	var matches_own_chapter := true
	for i in 5:
		if not (wp0[i] as Vector2).is_equal_approx(expected_ch0[i]): matches_own_chapter = false
	check(matches_own_chapter, "chapter 0's road traces its OWN pixel-traced CHAPTER_PATH_WAYPOINTS entry")
	var wp6: Array = game._chapter_waypoints(6)
	var expected_ch6: Array = game.CHAPTER_PATH_WAYPOINTS[6]
	var matches_ch6 := true
	for i in 5:
		if not (wp6[i] as Vector2).is_equal_approx(expected_ch6[i]): matches_ch6 = false
	check(matches_ch6, "chapter 6 traces its own distinct waypoints too, not a mirrored copy of chapter 0's (unique art needs no mirroring)")
	check(not (wp0[0] as Vector2).is_equal_approx(wp6[0]), "chapters 0 and 6 have genuinely different paths, not the same 6-biome shape cycling back around")

	# _build_road_curve()'s smoothing behavior is a general property of the function, not of
	# any one chapter's specific (now pixel-traced, not hand-picked-for-visual-variety) shape
	# — test it against a synthetic sharp zigzag built for exactly this, rather than whatever
	# chapter 0's real path happens to look like.
	var raw_points := PackedVector2Array([Vector2(120, 0), Vector2(260, 100), Vector2(100, 200), Vector2(260, 300), Vector2(120, 400)])
	var baked: PackedVector2Array = game._build_road_curve(raw_points).get_baked_points()
	check(baked.size() > raw_points.size() * 3, "the curve is densely tessellated, not just the five raw waypoints (%d points)" % baked.size())
	check(baked[0].is_equal_approx(raw_points[0]) and baked[baked.size() - 1].is_equal_approx(raw_points[raw_points.size() - 1]), "the curve still starts and ends exactly on the first and last stage")
	var any_off_segment := false
	for bp in baked:
		var v: Vector2 = bp
		var nearest_seg_dist := INF
		for i in raw_points.size() - 1:
			var a: Vector2 = raw_points[i]; var b: Vector2 = raw_points[i + 1]
			var ab: Vector2 = b - a
			var t: float = clampf((v - a).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
			nearest_seg_dist = minf(nearest_seg_dist, v.distance_to(a + ab * t))
		if nearest_seg_dist > 4.0: any_off_segment = true
	check(any_off_segment, "the baked path curves away from the straight-line zigzag, not just following it")

	var road_tex: NoiseTexture2D = game._get_road_texture()
	check(road_tex is NoiseTexture2D and road_tex.seamless, "the road uses a seamless procedural texture")

	# The map background used to be a stretched stock photo per chapter, independent of where
	# the road actually ran — "forced in", per feedback. It is now a procedural gradient wash
	# with vector terrain dressing that is generated FROM the same curve as the road, so it
	# cannot help but stay clear of it.
	var wash_tex: GradientTexture2D = game._get_terrain_wash_texture(0)
	check(wash_tex is GradientTexture2D, "the map terrain is a procedural gradient wash, not a stock photo")
	check(not _find_jpg_texture_rect(game.map_canvas), "no stock JPG art remains anywhere on the map")

	var band0: Node = game.map_canvas.get_child(0)
	var band0_decos: Array = []
	_find_all_by_script(band0, GameIcon, band0_decos)
	var terrain_decos: Array = []
	for d in band0_decos:
		if str(d.kind) in ["pine", "boulder", "hill"]: terrain_decos.append(d)
	check(terrain_decos.size() > 0, "chapter 0's background is dressed with procedural terrain silhouettes (%d placed)" % terrain_decos.size())
	# Decorations are placed relative to chapter 0's OWN real curve, not the synthetic zigzag
	# above (that one only exists to test _build_road_curve()'s general smoothing behavior).
	var raw_points_ch0 := PackedVector2Array()
	for i in 5: raw_points_ch0.append(wp0[i])
	var baked_ch0: PackedVector2Array = game._build_road_curve(raw_points_ch0).get_baked_points()
	var all_clear := true
	for d in terrain_decos:
		var center: Vector2 = d.position + d.size / 2.0
		for bp in baked_ch0:
			var v: Vector2 = bp
			if center.distance_to(v) < 30.0: all_clear = false
	check(all_clear, "terrain decorations stay clear of the actual road curve, not just visually near it")

	# The generic dirt-road overlay used to be the only visible "path" on the map; now that
	# pins and CHAPTER_PATH_WAYPOINTS trace the real painted trail, that overlay would just be
	# a mismatched line drawn on top of it, so it stays hidden (see _add_routes()).
	var found_road_bed := false
	var found_visible_road := false
	for child in game.map_canvas.get_children():
		if child is Line2D:
			var line := child as Line2D
			if is_equal_approx(line.width, 22.0) or is_equal_approx(line.width, 10.0):
				found_road_bed = true
				if line.visible: found_visible_road = true
	check(found_road_bed, "the road_bed/trail Line2D nodes still exist (their geometry backs the travel path)")
	check(not found_visible_road, "the generic dirt-road overlay stays invisible now that it would just mismatch the real painted trail")

	# growth-roadmap: travel time is a fixed 2 seconds per stage hop, not one fixed-duration
	# tween regardless of distance — chained hops mean an N-stage journey takes N x 2 seconds
	# and the traveler visits every intermediate stage's real point along the way.
	var saved_unlocked_travel: int = int(game.profile.unlocked)
	var saved_position_travel: int = int(game.profile.position)
	game.profile.unlocked = 2
	game.profile.position = 0
	game.traveler.position = game._map_point(0) - Vector2(0, 26)
	var travel_start_ms := Time.get_ticks_msec()
	game._travel_to(2)
	await process_frame
	var hop_count := 0
	while game.profile.position != 2 and hop_count < 100:
		await create_timer(0.1).timeout
		hop_count += 1
	var elapsed_sec: float = float(Time.get_ticks_msec() - travel_start_ms) / 1000.0
	check(int(game.profile.position) == 2, "traveling 2 stages ends at the correct final stage")
	check(elapsed_sec > 1.5 and elapsed_sec < 2.8, "a 2-stage journey takes ~TOTAL_TRAVEL_SECONDS (%.1fs elapsed, expected ~2s)" % elapsed_sec)
	# Not checking game.traveler.position here: arriving at stage 2 (an elite battle)
	# immediately calls begin_battle() -> show_battle() -> _clear(), which frees the whole map
	# scene graph (traveler included) in the same synchronous step that sets profile.position
	# — by the time this line runs, `traveler` already points at a freed node. profile.position
	# == 2 above already confirms the journey ended at the right stage.
	game.profile.unlocked = saved_unlocked_travel
	game.profile.position = saved_position_travel
	# _travel_to() always ends by either opening an event or beginning a battle for the stage
	# it arrives at (stage 2 is an elite battle), which itself kicks off _maybe_end_turn()'s
	# own resolution — let that settle before tearing the screen down, or show_map()'s _clear()
	# could free nodes out from under an in-flight coroutine.
	var settle_wait := 0.0
	while game.resolving and settle_wait < 5.0:
		await create_timer(0.1).timeout
		settle_wait += 0.1
	game.show_map()
	await process_frame

	# Regression check for a real race found this session: _travel_to() is invoked fire-and-
	# forget (no await) from _on_pin_pressed(), with no input lock during its up-to-2-second hop
	# animation — tapping Camp/Quests/another pin mid-travel used to leave the interrupted
	# coroutine to unconditionally call show_event()/begin_battle() on whatever screen the
	# player had already moved to once its tween finished, silently yanking them into a battle
	# they didn't ask for at that moment. Fixed with g.screen_generation (bumped by g._clear(),
	# the one shared choke point every screen transition goes through) — same shape as
	# _resolve_play()'s battle_session fix, see AGENTS.md's "fire-and-forget coroutine" trap.
	var saved_unlocked_race: int = int(game.profile.unlocked)
	var saved_position_race: int = int(game.profile.position)
	game.profile.unlocked = 2
	game.profile.position = 0
	game.current_map_chapter = 0
	game.traveler.position = game._map_point(0) - Vector2(0, 26)
	game._travel_to(2)
	await process_frame
	game.camp_tab = "character"
	game.show_camp()
	await process_frame
	check(game.root.find_child("BeginnerRecBadge", true, false) != null, "navigating to Camp mid-travel actually shows Camp")
	Engine.time_scale = 20.0
	await create_timer(2.2).timeout
	Engine.time_scale = 1.0
	await process_frame
	check(int(game.profile.position) == 0, "an abandoned mid-flight travel does not silently advance profile.position once its tween finishes")
	check(game.root.find_child("PlayerSprite", true, false) == null, "an abandoned mid-flight travel does not start a battle over whatever screen the player navigated to")
	check(game.root.find_child("BeginnerRecBadge", true, false) != null, "Camp is still the screen showing after the abandoned travel's tween finishes")
	game.profile.unlocked = saved_unlocked_race
	game.profile.position = saved_position_race
	game.show_map()
	await process_frame

	section("== next-stage travel snaps the map back to the player's real chapter first ==")
	var saved_pos_travel_sync: int = int(game.profile.position)
	var saved_unlocked_travel_sync: int = int(game.profile.unlocked)
	var saved_ch_travel_sync: int = int(game.current_map_chapter)
	game.profile.position = 1
	game.profile.unlocked = 2
	game.current_map_chapter = 3 # simulate having swiped away to browse an unrelated chapter
	game._travel_to(2)
	check(game.current_map_chapter == 0, "tapping next-stage while browsing an unrelated chapter snaps the map back to the chapter the player is actually in before the walk starts")
	await process_frame
	var sync_wait := 0.0
	while (game.resolving or int(game.profile.position) != 2) and sync_wait < 6.0:
		await create_timer(0.1).timeout
		sync_wait += 0.1
	check(int(game.profile.position) == 2, "the walk still lands on the correct stage after snapping the map back")
	game.profile.position = saved_pos_travel_sync
	game.profile.unlocked = saved_unlocked_travel_sync
	game.current_map_chapter = saved_ch_travel_sync
	game.show_map()
	await process_frame

	# Chapter transition cutscene verification
	var saved_unlocked_trans: int = int(game.profile.unlocked)
	var saved_position_trans: int = int(game.profile.position)
	var saved_ch_trans: int = int(game.current_map_chapter)
	game.show_chapter_transition(0, 1)
	await process_frame
	var trans_layer: Node = game.root.find_child("ChapterTransitionLayer", true, false)
	check(trans_layer != null, "chapter transition cutscene builds transition layer")
	var skip_btn: Button = game.root.find_child("ChapterTransitionSkipBtn", true, false) as Button
	check(skip_btn != null, "chapter transition cutscene has skip button")
	if skip_btn != null:
		skip_btn.pressed.emit()
		await process_frame
		check(game.current_map_chapter == 1, "transition sets current_map_chapter to next chapter (1)")
		check(int(game.profile.position) == 5, "transition sets profile.position to first stage of new chapter (5)")

	# show_chapter_transition() is fire-and-forget (_travel_to(), its caller when the player
	# asks to move into a new chapter, never awaits it) — skipping immediately (above) frees
	# transition_layer/pin_container via
	# show_map()'s _clear() long before the ~2.2s walk tween the coroutine is still suspended
	# on actually finishes. Engine.time_scale sped way up lets that background tween genuinely
	# finish here instead of skipping the wait, without burning ~2.6 real seconds every run.
	# NOTE: the bug this targets — a SCRIPT ERROR ("Cannot call method 'create_tween' on a
	# previously freed instance") logged when the coroutine resumes and touches its own
	# already-freed nodes — does not, by itself, fail any check() here or corrupt state the
	# game can't recover from; it was invisible until a screen elsewhere happened to break
	# because of it. Confirmed by temporarily reverting the is_instance_valid() guard in
	# show_chapter_transition() and re-running this suite: the error reappears in the log, but
	# every check() below still passes regardless. The real verification for this class of fix
	# is "no SCRIPT ERROR line appears in a full run's output", not a specific assertion — this
	# block is the closest a check() gets, confirming the game is at least left in a working
	# state rather than a silent hang or a cascading failure.
	Engine.time_scale = 20.0
	await create_timer(2.6).timeout
	Engine.time_scale = 1.0
	game.show_map()
	await process_frame
	check(game.root.find_child("SettingsButton", true, false) != null, "the map still renders normally well after a skipped chapter transition's background tween would have finished")

	game.profile.unlocked = saved_unlocked_trans
	game.profile.position = saved_position_trans
	game.current_map_chapter = saved_ch_trans
	game.show_map()
	await process_frame

	var found_particles := false
	for child in game.root.get_children():
		if child is CPUParticles2D:
			found_particles = true
			check(bool(child.emitting) and int(child.amount) > 0, "map ambience particles are emitting")
	check(found_particles, "map ambience (CPUParticles2D) is present")

	# The map's bar and dock float over a full-screen scroller, so they are positioned by
	# hand. Getting that wrong collapses them to zero height: invisible, but not an error.
	await process_frame
	await process_frame
	var dock_btn := _find_button_containing(game.root, game.content.ui("ui.deck_btn", game.lang))
	check(dock_btn != null, "map dock buttons exist")
	if dock_btn != null:
		check(dock_btn.size.y > 20.0, "dock button has real height (%.1f)" % dock_btn.size.y)
		check(dock_btn.size.x > 40.0, "dock button has real width (%.1f)" % dock_btn.size.x)
		check(dock_btn.global_position.y > 400.0, "dock sits at the bottom of the screen (y=%.0f)" % dock_btn.global_position.y)
	# Language/music toggles moved into show_settings() and no longer live in the map header
	# itself (see the growth-roadmap note on decluttering it) — SettingsButton is the header
	# element that's always present now, so it's what verifies the header row actually laid
	# out with real height rather than collapsing to zero.
	var settings_header_btn: Control = game.root.find_child("SettingsButton", true, false) as Control
	check(settings_header_btn != null and settings_header_btn.size.y > 20.0, "map header is laid out too")
	check(_find_button_containing(game.root, game.content.ui("ui.lang_toggle", game.lang)) == null, "the redundant lang toggle no longer clutters the map header (moved into Settings)")

	section("== map trial button in dock ==")
	# Unified Trial / Challenges shortcut: now consolidated as a dedicated button in the bottom dock
	var trial_shortcut: Control = game.root.find_child("MapTrialShortcutBtn", true, false) as Control
	check(trial_shortcut != null and trial_shortcut.size.x > 20.0, "the consolidated Trial dock shortcut exists with real size")
	check(game.root.find_child("MapChallengeRail", true, false) == null, "the redundant challenge rail is removed from screen edge")
	check(game.root.find_child("MapAbyssShortcutBtn", true, false) == null, "duplicate abyss button is removed")
	game.camp_tab = "character"
	trial_shortcut.emit_signal("pressed")
	await process_frame
	check(game.camp_tab == "challenges", "tapping the trial dock shortcut opens Challenges")
	check(_find_label_text(game.root, game.content.ui("ui.challenges_title", game.lang)), "dedicated trial challenges screen renders")
	game.camp_tab = "character"  # restore: a later section asserts Camp's own default tab

	# Map pins set their own z_index, which beats tree order, so the floating bars have to
	# outrank them or the dock draws underneath the stages it is supposed to sit over.
	if dock_btn != null:
		var dock_z := _effective_z(dock_btn)
		var pin_z := _max_z(game.map_canvas)
		check(dock_z > pin_z, "dock draws above the map (dock z=%d, highest map z=%d)" % [dock_z, pin_z])
		var dock_icon := _find_texture_rect(dock_btn)
		check(dock_icon != null and dock_icon.texture != null, "dock button carries a fancy textured icon, not just a text glyph")

	section("== notification dots ==")
	# Standard mobile-game language: a small red dot on an entry point means there is
	# something inside worth checking, rather than making the player guess or stumble onto
	# it. Force both trigger conditions and confirm the dot actually appears, then force the
	# cleared conditions and confirm it goes away again.
	var saved_daily: Array = game.profile.daily_quests.duplicate(true)
	var saved_weekly: Array = game.profile.weekly_quests.duplicate(true)
	var saved_deck: Array = game.profile.deck.duplicate()
	var saved_collection: Dictionary = game.profile.collection.duplicate(true)

	game.profile.daily_quests = [{"id": "test_claimable", "progress": 1, "target": 1, "claimed": false}]
	game.profile.collection["strike"] = game.profile.deck.count("strike") + 3
	game.show_map()
	await process_frame
	var quest_btn: Node = game.root.find_child("QuestButton", true, false)
	check(quest_btn != null, "the quest entry point button exists")
	if quest_btn != null:
		check(quest_btn.get_node_or_null("NotificationDot") != null, "a claimable quest shows a red dot on the quest entry point")
		var quest_icon := _find_texture_rect(quest_btn)
		check(quest_icon != null and quest_icon.texture != null, "the quest entry point uses a painted quest icon")
	var camp_btn: Node = game.root.find_child("CampButton", true, false)
	check(camp_btn != null, "the camp entry point button exists")
	if camp_btn != null:
		var camp_icon := _find_texture_rect(camp_btn)
		check(camp_icon != null and camp_icon.texture != null, "the camp entry point uses a painted camp icon")

	# Compendium milestones (50/80/100% discovery) are the one claimable Camp reward — force
	# full discovery directly rather than relying on whatever % this long-running suite's
	# ambient collection/relic state happens to sit at by this point.
	var saved_compendium_discovered: Dictionary = game.profile.compendium_discovered.duplicate(true)
	var saved_milestones_claimed: Array = game.profile.get("compendium_milestones_claimed", []).duplicate()
	for c in game.content.cards:
		if str(c.get("rarity", "")) != "Curse": game._compendium_dict("cards")[c.id] = true
	for e in SpiritContent.EQUIPMENT: game._compendium_dict("equipment")[e.id] = true
	for r in SpiritContent.RUNES: game._compendium_dict("runes")[r.id] = true
	for r in SpiritContent.RELICS: game._compendium_dict("relics")[r.id] = true
	for e in SpiritContent.ENEMIES: game._compendium_dict("bestiary")[e.name] = true
	game.profile.compendium_milestones_claimed = []
	check(game._has_claimable_camp_reward(), "a reached-but-unclaimed Compendium milestone is claimable")
	game.show_map()
	await process_frame
	var camp_btn_ready: Node = game.root.find_child("CampButton", true, false)
	check(camp_btn_ready != null and camp_btn_ready.get_node_or_null("NotificationDot") != null, "the camp entry point shows a red dot when a Compendium milestone is claimable")
	game.profile.compendium_milestones_claimed = [50, 80, 100]
	check(not game._has_claimable_camp_reward(), "once every milestone is claimed there is nothing left to flag")
	game.show_map()
	await process_frame
	var camp_btn_done: Node = game.root.find_child("CampButton", true, false)
	check(camp_btn_done != null and camp_btn_done.get_node_or_null("NotificationDot") == null, "the camp dot goes away once every milestone is claimed")
	game.profile.compendium_discovered = saved_compendium_discovered
	game.profile.compendium_milestones_claimed = saved_milestones_claimed
	var deck_dock_btn := _find_button_containing(game.root, game.content.ui("ui.deck_btn", game.lang))
	check(deck_dock_btn != null and deck_dock_btn.get_node_or_null("NotificationDot") != null, "an owned-but-unused card shows a red dot on the deck dock button")

	game.profile.daily_quests = [{"id": "test_not_claimable", "progress": 0, "target": 1, "claimed": false}]
	game.profile.weekly_quests = [{"id": "test_not_claimable_2", "progress": 0, "target": 1, "claimed": false}]
	game.profile.collection = {}
	game.profile.deck = []
	game.show_map()
	await process_frame
	var quest_btn2: Node = game.root.find_child("QuestButton", true, false)
	check(quest_btn2 != null and quest_btn2.get_node_or_null("NotificationDot") == null, "the quest dot goes away once nothing is claimable")
	var deck_dock_btn2 := _find_button_containing(game.root, game.content.ui("ui.deck_btn", game.lang))
	check(deck_dock_btn2 != null and deck_dock_btn2.get_node_or_null("NotificationDot") == null, "the deck dot goes away once the collection matches the deck")
	check(game.battle_music_streams.size() == 5, "there are 5 distinct sub-stage battle music tracks")
	check(game.map_music != null and game.map_music.stream != null, "world map has symphonic music loaded")

	# "Today digest" card: the same underlying claimable state as the dots above, spelled out
	# as an actual count on the map itself rather than making the player open two screens to
	# find out what's waiting. Force every category to a known state so the count is exact.
	var saved_milestones_for_digest: Array = game.profile.get("compendium_milestones_claimed", []).duplicate()
	var saved_login_reward: Dictionary = game.profile.get("login_reward", {}).duplicate(true)
	game.profile.daily_quests = [{"id": "digest_test", "progress": 1, "target": 1, "claimed": false}]
	game.profile.weekly_quests = []
	game.profile.login_reward = {}
	game.profile.compendium_milestones_claimed = [50, 80, 100]
	check(game._claimable_reward_count() == 1, "claimable reward count reflects exactly the one ready quest")
	game.show_map()
	await process_frame
	check(game.root.find_child("MapDigestBanner", true, false) != null, "the today-digest banner appears on the map when something is claimable")
	check(game.root.find_child("MapDigestButton", true, false) != null, "the today-digest banner has a tappable button")

	game.profile.daily_quests = [{"id": "digest_test", "progress": 1, "target": 1, "claimed": true}]
	check(game._claimable_reward_count() == 0, "claimable reward count drops to zero once everything is claimed")
	game.show_map()
	await process_frame
	check(game.root.find_child("MapDigestBanner", true, false) == null, "the today-digest banner disappears once nothing is claimable")

	game.profile.daily_quests = saved_daily
	game.profile.weekly_quests = saved_weekly
	game.profile.deck = saved_deck
	game.profile.collection = saved_collection
	game.profile.compendium_milestones_claimed = saved_milestones_for_digest
	game.profile.login_reward = saved_login_reward
	game.show_map()
	await process_frame

	check(game.root.find_child("MapRightActionRail", true, false) != null, "MapRightActionRail exists on the map")
	check(game.root.find_child("MapIdleHarvestBtn", true, false) != null, "MapIdleHarvestBtn exists on the right rail")

	# Reward card row is a PanelContainer (not plain Panel) to dynamically fit long text without overflowing
	var sample_card: Dictionary = game.content.cards[0]
	var reward_row: Control = game._reward_card_row(sample_card)
	check(reward_row is PanelContainer, "reward card row uses PanelContainer to prevent button overflow")

	# Standing on same stage does not deadlock in _travel_to
	var pos_before: int = int(game.profile.position)
	await game._travel_to(pos_before)
	check(game.combat != null, "traveling to current stage enters battle immediately without tween deadlock")
	game.show_map()
	await process_frame

	# Touch slop drag cancellation test
	var clicked := [false]
	var test_btn: Button = game._button("Test", func(): clicked[0] = true)
	var ev_touch := InputEventScreenTouch.new()
	ev_touch.pressed = true
	ev_touch.position = Vector2(10, 10)
	test_btn.gui_input.emit(ev_touch)
	var ev_drag := InputEventScreenDrag.new()
	ev_drag.position = Vector2(10, 30)
	test_btn.gui_input.emit(ev_drag)
	test_btn.pressed.emit()
	check(not clicked[0], "button tap is cancelled when finger dragged > 14px")
	ev_touch.position = Vector2(10, 10)
	test_btn.gui_input.emit(ev_touch)
	test_btn.pressed.emit()
	check(clicked[0], "button tap succeeds without drag")

	section("== map pin markers ==")
	# A pin used to just be a badge centred on its road point. It is now a badge floating
	# above the point with a tail pointing straight down at it and a shadow cast on the
	# ground there — check the tail's tip and the shadow are both exactly at that point,
	# not just "somewhere near" it.
	var stage0_point: Vector2 = game._map_point(0)
	var found_tail := false
	for child in game.map_canvas.get_children():
		if child is Polygon2D:
			var poly: PackedVector2Array = (child as Polygon2D).polygon
			if poly.size() == 3 and poly[2].is_equal_approx(stage0_point):
				found_tail = true
				break
	check(found_tail, "stage 0's pin has a tail pointing exactly at its road point")
	var found_shadow := false
	for child in game.map_canvas.get_children():
		if child is Panel:
			var pnl := child as Panel
			if pnl.size.x > 20.0 and pnl.size.x < 40.0 and pnl.size.y < 12.0:
				var shadow_center: Vector2 = pnl.position + pnl.size / 2.0
				if shadow_center.is_equal_approx(stage0_point):
					found_shadow = true
					break
	check(found_shadow, "stage 0's pin casts a ground shadow at its road point")

	# Each node kind now shows its own painted marker (pin_<kind>.png) instead of a flat-color
	# badge with a generic rune overlay — check the two ends of the kind spectrum actually pick
	# different art rather than both silently falling back to the same texture.
	check(game.content.node_kind(0) == "battle", "stage 0 is a plain battle node")
	check(_find_texture_rect_ending_with(game.root, "pin_normal.png"), "stage 0's pin uses the plain-battle painted marker")
	check(game.content.node_kind(4) == "boss", "stage 4 (chapter 0, level 5) is a boss node")
	check(_find_texture_rect_ending_with(game.root, "pin_boss.png"), "a boss stage's pin uses the boss-specific painted marker")

	section("== deck ==")
	game.show_deck()
	await process_frame
	check(game.root.get_child_count() > 0, "deck page built")
	# Cards used to sit in one undivided grid; they are now grouped under a rarity header
	# with its own star row, whichever rarities the starting collection actually contains.
	var found_rarity_header := false
	for r in ["Rare", "Uncommon", "Common", "Starter"]:
		if _find_label_text(game.root, game.content.ui("rarity.%s" % r, game.lang)):
			found_rarity_header = true
			break
	check(found_rarity_header, "the deck screen groups cards under a rarity section header")
	var deck_stars: Array = []
	_find_all_by_script(game.root, GameIcon, deck_stars)
	var deck_star_kind_found := false
	for s in deck_stars:
		if str(s.kind) == "star": deck_star_kind_found = true; break
	check(deck_star_kind_found, "deck card tiles show a drawn rarity star row")
	check(_find_texture_rect_ending_with(game.root, "card_frame_golden_border.png"), "deck card tiles show the ornate frame asset as hand cards and the peek")
	var starter_frame: Texture2D = game._get_card_frame_texture("Starter")
	var common_frame: Texture2D = game._get_card_frame_texture("Common")
	var uncommon_frame: Texture2D = game._get_card_frame_texture("Uncommon")
	var rare_frame: Texture2D = game._get_card_frame_texture("Rare")
	check(starter_frame != null and common_frame != null and uncommon_frame != null and rare_frame != null, "all 4 rarity card frames exist and load")
	check(starter_frame != common_frame and common_frame != uncommon_frame and uncommon_frame != rare_frame, "card frames vary distinctly by rarity")
	var deck_tile := _find_shop_tile(game.root)
	if deck_tile != null:
		var deck_frame_rect: TextureRect = _get_texture_rect_ending_with(deck_tile, "card_frame_golden_border.png")
		if deck_frame_rect != null:
			check(deck_frame_rect.size.is_equal_approx(deck_tile.size), "the deck tile's frame overlay is sized to the tile, not the texture's own 728x1006 (got %s, tile is %s)" % [deck_frame_rect.size, deck_tile.size])

	section("== auto build ==")
	game.profile.deck = []
	game._auto_build_deck()
	await process_frame
	check(game.profile.deck.size() == 25, "auto-build filled 25 cards, got %d" % game.profile.deck.size())
	var overdrawn := false
	for id in game.profile.deck:
		if game.profile.deck.count(id) > int(game.profile.collection.get(id, 0)): overdrawn = true
	check(not overdrawn, "auto-build respects owned copies")

	section("== loadout tabs ==")
	game.loadout_tab = "equipment"
	game.show_loadout()
	await process_frame
	check(game.root.get_child_count() > 0, "equipment tab built")

	var prev_equips: Array = game.profile.equipment_owned.duplicate()
	if not game.profile.equipment_owned.has("emberBlade"):
		game.profile.equipment_owned.append("emberBlade")
	game.show_loadout()
	await process_frame
	var reforge_btn := game.root.find_child("ReforgeBtn_emberBlade", true, false) as Button
	check(reforge_btn != null, "reforge button for emberBlade exists in loadout")

	# Test opening Reforge Modal
	game.show_reforge_modal("emberBlade")
	await process_frame
	var reforge_modal: Node = game.overlay.get_node_or_null("ReforgeModal")
	check(reforge_modal != null, "ReforgeModal opened in overlay")
	var reforge_up_btn := reforge_modal.find_child("ReforgeUpgradeBtn", true, false) as Button
	check(reforge_up_btn != null, "ReforgeUpgradeBtn exists in modal")
	var reforge_insc_btn := reforge_modal.find_child("InscribeRollBtn", true, false) as Button
	check(reforge_insc_btn != null, "InscribeRollBtn exists in modal")
	var reforge_close_btn := reforge_modal.find_child("ReforgeCloseBtn", true, false) as Button
	check(reforge_close_btn != null, "ReforgeCloseBtn exists in modal")

	# Dismiss modal
	reforge_close_btn.pressed.emit()
	await process_frame
	check(game.overlay.get_node_or_null("ReforgeModal") == null, "ReforgeModal dismissed cleanly")
	game.profile.equipment_owned = prev_equips
	game.loadout_tab = "runes"
	game.show_loadout()
	await process_frame
	check(game.root.get_child_count() > 0, "rune tab built")
	check(ResourceLoader.exists("res://assets/icons/equip_emberBlade.png"), "equipment icon assets exist")
	check(ResourceLoader.exists("res://assets/icons/rune_swift.png"), "rune icon assets exist")

	# Rune Resonance banner: shows all 3 sets, and flips to "active" the moment the player's
	# actually socketed the matching pair of runes on cards in their deck.
	check(_find_label_text(game.root, game.content.ui("ui.rune_resonance_title", game.lang)), "the rune tab shows the Rune Resonance section")
	check(_find_label_text(game.root, game.content.ui("set.gale.name", game.lang)), "Gale Resonance is listed")
	check(_find_label_text(game.root, game.content.ui("ui.rune_resonance_inactive", game.lang)), "an unsocketed resonance set shows as inactive")
	var saved_card_runes: Dictionary = game.profile.card_runes.duplicate(true)
	game.profile.card_runes = {"strike": "swift", "ward": "cycle"}
	game.show_loadout()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.rune_resonance_active", game.lang)), "socketing swift+cycle flips Gale Resonance to active in the loadout screen")
	game.profile.card_runes = saved_card_runes
	game.show_loadout()
	await process_frame
	check(load("res://assets/icons/equip_emberBlade.png") != null, "equipment icon loads as texture")
	check(load("res://assets/icons/rune_swift.png") != null, "rune icon loads as texture")

	section("== shop ==")
	game.show_shop()
	await process_frame
	check(game.root.get_child_count() > 0, "shop page built")

	section("== camp ==")
	game.show_camp()
	await process_frame
	check(game.root.get_child_count() > 0, "camp page built")
	check(game.camp_tab == "character", "camp defaults to the character tab")
	check(_find_button_containing(game.root, game.content.ui("ui.camp_tab_collection", game.lang)) != null, "camp's collection tab button exists")
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(not _find_label_text(game.root, game.content.ui("ui.hero_classes_title", game.lang)), "switching to the challenges tab hides the character tab's content")
	check(_find_label_text(game.root, game.content.ui("ui.challenges_title", game.lang)), "dedicated trial challenges screen renders")
	game.camp_tab = "character"

	section("== battle ==")
	check(not bool(game.profile.get("tutorial_seen", false)), "a fresh profile has not seen the tutorial yet")
	game.begin_battle(0)
	await process_frame
	check(game.combat != null, "combat created")
	check(game.combat.state.phase == "player", "battle starts on player phase")
	check(int(game.combat.state.energy) == 2, "battle starts with two energy")

	section("== first-battle tutorial ==")
	var tutorial_backdrop := game.overlay.get_node_or_null("BattleTutorial") as Control
	check(tutorial_backdrop != null, "tutorial carousel opens on a fresh profile's first battle (stage 0)")
	var tutorial_card := tutorial_backdrop.find_child("TutorialCard", true, false) as Control
	check(tutorial_card != null, "tutorial card renders")
	check(game.tutorial_step == 0, "tutorial starts on step 0")
	game._tutorial_next_step()
	await process_frame
	check(game.tutorial_step == 1, "TutorialNextBtn advances to the next step")
	game._tutorial_prev_step()
	await process_frame
	check(game.tutorial_step == 0, "TutorialPrevBtn (back) returns to the previous step")
	for i in game.TUTORIAL_STEPS.size() - 1: game._tutorial_next_step()
	await process_frame
	var next_btn := tutorial_backdrop.find_child("TutorialNextBtn", true, false) as Button
	check(next_btn != null and next_btn.text == game.content.ui("ui.tutorial_start", game.lang), "the last step's button reads Start Battle instead of Next")
	game._finish_tutorial()
	await process_frame
	check(bool(game.profile.get("tutorial_seen", false)), "finishing the tutorial marks tutorial_seen so it never shows again")
	check(game.overlay.get_node_or_null("BattleTutorial") == null, "tutorial carousel is gone after finishing")
	game.begin_battle(4)
	await process_frame
	check(game.overlay.get_node_or_null("BattleTutorial") == null, "a later battle does not re-show the tutorial once seen")
	# Battle backgrounds are now keyed by within-chapter level (matching the battle music's own
	# per-level theme) rather than the old per-encounter variety-rotation index — stage 4 is
	# chapter 0's boss (level 5, stage_lvl 4) and should show the "Crown" background.
	check(_find_texture_rect_ending_with(game.root, "battle_stage_4.png"), "a level-5 boss battle shows the Crown-themed background")
	check(_find_texture_rect_ending_with(game.root, "chapter_0.png") or _find_texture_rect_ending_with(game.root, "biome_0_forest.png"), "combat background aligns with the main map chapter artwork")
	game.begin_battle(0)
	await process_frame
	check(_find_texture_rect_ending_with(game.root, "battle_stage_0.png"), "a level-1 battle shows the Trailhead-themed background")
	check(_find_texture_rect_ending_with(game.root, "chapter_0.png") or _find_texture_rect_ending_with(game.root, "biome_0_forest.png"), "stage 0 combat background aligns with chapter 0 map")
	game.begin_battle(5)
	await process_frame
	check(_find_texture_rect_ending_with(game.root, "chapter_1.png") or _find_texture_rect_ending_with(game.root, "biome_1_autumn.png"), "chapter 1 combat background aligns with chapter 1 map artwork")
	game.begin_battle(0)
	await process_frame

	# Health bar must actually shrink with the enemy's health.
	var enemy_box: Control = game.enemy_boxes[0]
	var bar: ProgressBar = enemy_box.get_node_or_null("HealthBar") as ProgressBar
	check(bar != null, "enemy health bar is a ProgressBar")
	if bar != null:
		var full_ratio: float = bar.value / bar.max_value
		check(is_equal_approx(full_ratio, 1.0), "bar starts full, ratio %f" % full_ratio)
		game.combat.state.enemies[0].health = int(game.combat.state.enemies[0].max_health / 2)
		game.show_battle()
		await process_frame
		var bar2: ProgressBar = game.enemy_boxes[0].get_node_or_null("HealthBar") as ProgressBar
		var half_ratio: float = bar2.value / bar2.max_value
		check(half_ratio < 0.6 and half_ratio > 0.4, "bar tracks damage, ratio %f" % half_ratio)

	section("== auto end turn ==")
	var turn_before: int = int(game.combat.state.turn)
	var start_energy: int = int(game.combat.state.energy)
	var play_cost: int = int(game.content.card(game.combat.state.hand[0].card_id).cost)
	game._attempt_play_card(0, -1)
	await process_frame
	check(int(game.combat.state.energy) == start_energy - play_cost, "playing a card spends its energy cost, left %d" % int(game.combat.state.energy))
	# Give the resolve coroutine (animations + enemy turn) time to finish.
	var waited := 0.0
	while game.resolving and waited < 8.0:
		await create_timer(0.1).timeout
		waited += 0.1
	# Drain energy directly so nothing in hand is affordable any more, then let the turn
	# hand itself over — there is no play-count cap left to exhaust instead.
	if game.combat.state.phase == "player":
		game.combat.state.energy = 0
		await game._maybe_end_turn()
	check(not game.resolving, "resolve finished")
	if game.combat.state.phase == "player":
		check(int(game.combat.state.turn) > turn_before, "turn advanced automatically once nothing was affordable (turn %d -> %d)" % [turn_before, int(game.combat.state.turn)])
		# Energy opens at 2 and climbs by 1 every two turns (see combat.gd end_turn), not a
		# flat refill — compute the expected value from the actual turn rather than a magic 3.
		var expected_energy: int = 2 + int((int(game.combat.state.turn) - 1) / 2)
		check(int(game.combat.state.energy) == expected_energy, "energy set for the new turn (turn %d -> expected %d, got %d)" % [int(game.combat.state.turn), expected_energy, int(game.combat.state.energy)])
	else:
		print("  note: battle ended during the test (phase %s), turn handoff not observable" % game.combat.state.phase)

	section("== no End Turn button ==")
	var found_end_turn := _find_text(game.root, game.content.ui("ui.end_turn", game.lang))
	check(not found_end_turn, "End Turn button is gone")

	section("== enemy depth formation ==")
	# Three or more enemies used to sit in a flat row (HBoxContainer). Force a synthetic
	# 3-enemy fight and check they now form a wedge: the middle slot stays at full scale
	# and lowest position, the two flanking slots sit higher up and a touch smaller.
	var template: Dictionary = game.combat.state.enemies[0].duplicate(true)
	template.health = template.max_health
	game.combat.state.enemies = [template.duplicate(true), template.duplicate(true), template.duplicate(true)]
	game.show_battle()
	await process_frame
	check(game.enemy_boxes.size() == 3, "all three synthetic enemies rendered")
	if game.enemy_boxes.size() == 3:
		var front: Control = game.enemy_boxes[1]
		var left: Control = game.enemy_boxes[0]
		var right: Control = game.enemy_boxes[2]
		check(is_equal_approx(front.position.y, 0.0), "the middle enemy stays at the front (y=%f)" % front.position.y)
		check(left.position.y < -0.01 and right.position.y < -0.01, "the flanking enemies are pushed back (y=%f, %f)" % [left.position.y, right.position.y])
		check(is_equal_approx(left.position.y, right.position.y), "the two flanks sit at the same depth (symmetric wedge)")
		var front_sprite: Sprite2D = front.get_node_or_null("MonsterSprite") as Sprite2D
		var left_sprite: Sprite2D = left.get_node_or_null("MonsterSprite") as Sprite2D
		check(front_sprite != null and left_sprite != null and float(front_sprite.get_meta("base_scale")) > float(left_sprite.get_meta("base_scale")), "the front enemy's sprite is drawn larger than a flanking one")

		# The intent banner used to sit at a fixed local y=0 inside each enemy's own unit, so
		# a flanked (staggered-back) enemy's banner drifted up along with its whole box and
		# could crowd whatever sits above the enemy row. It now compensates for that shift so
		# every banner lands at the same absolute height regardless of which row it is in.
		var front_banner: Control = front.get_node_or_null("IntentBanner")
		var left_banner: Control = left.get_node_or_null("IntentBanner")
		check(front_banner != null and left_banner != null, "both a front and a flanking enemy have an intent banner")
		if front_banner != null and left_banner != null:
			check(is_equal_approx(front_banner.global_position.y, left_banner.global_position.y), "a flanking enemy's banner lands at the same screen height as the front enemy's (got %.1f vs %.1f)" % [front_banner.global_position.y, left_banner.global_position.y])
			# The banner used to also spell the intent out in a caption line under the
			# icon+number row ("Attack"/"Defend"/...); that line is gone now that the icon
			# alone is meant to carry that information, so the banner has exactly one row.
			var label_count := 0
			for child in front_banner.get_children():
				if child is HBoxContainer:
					for grandchild in (child as HBoxContainer).get_children():
						if grandchild is Label: label_count += 1
			check(label_count == 1, "the intent banner shows only the amount, not a redundant caption line (found %d labels)" % label_count)

	section("== compact info popup ==")
	# The modifier banner and equipment/relic row used to spell their full text out on
	# screen; now they're a tap target that opens this shared popup instead.
	check(game.overlay.get_node_or_null("InfoPopup") == null, "no info popup up front")
	game._show_info_popup(game._icon_badge("✥", Color("ffe2b0"), 60, 26), "Test Modifier", "Some detail text.", Color("c0392b"))
	await process_frame
	check(game.overlay.get_node_or_null("InfoPopup") != null, "tapping a compact badge opens the info popup")
	game._clear_info_popup()
	await process_frame
	check(game.overlay.get_node_or_null("InfoPopup") == null, "tapping outside the popup dismisses it")

	section("== tap targeting ==")
	game.selected_card = -1
	game.begin_battle(29)   # a stage with adds, so more than one enemy is alive
	await process_frame
	var waited_t := 0.0
	while game.resolving and waited_t < 8.0:
		await create_timer(0.1).timeout
		waited_t += 0.1
	var many: bool = game._living_enemies().size() > 1
	check(many, "picked a stage with multiple enemies (%d)" % game._living_enemies().size())
	var attack_slot := -1
	for i in game.combat.state.hand.size():
		if game._card_is_attack(game.content.card(game.combat.state.hand[i].card_id)):
			attack_slot = i
			break
	if attack_slot >= 0 and many:
		var hand_before: int = game.combat.state.hand.size()
		game._tap_card(attack_slot)
		await process_frame
		check(game.selected_card == attack_slot, "tapping an attack card with multiple enemies arms targeting directly")
		check(game.combat.state.hand.size() == hand_before, "no card was played yet")
		game._tap_card(attack_slot)
		await process_frame
		check(game.selected_card == -1, "tapping the same armed card again cancels")

	var skill_slot := -1
	for i in game.combat.state.hand.size():
		var c: Dictionary = game.content.card(game.combat.state.hand[i].card_id)
		if not game._card_is_attack(c) and int(c.cost) <= int(game.combat.state.energy):
			skill_slot = i
			break
	if skill_slot >= 0:
		var before_hand: int = game.combat.state.hand.size()
		game._tap_card(skill_slot)
		await process_frame
		check(game.combat.state.hand.size() == before_hand - 1, "tapping a non-targeted card plays it directly")
		var w := 0.0
		while game.resolving and w < 10.0:
			await create_timer(0.1).timeout
			w += 0.1

	section("== hand card art and layout ==")
	# CardFrame used to be a PanelContainer with the illustration, the info box, and a badge
	# all added as direct children — a Container force-fits every direct child to its own
	# full rect, so the last one added (the cost badge) silently painted over the whole card
	# and the art never showed at all. Pin both children to their real, distinct sizes.
	var layout_card: Node = _find_by_script(game.root, HandCard)
	if layout_card != null:
		var frame_node: Node = layout_card.get_node_or_null("CardFrame")
		check(frame_node != null, "hand card has its CardFrame node")
		check(frame_node is Panel and not frame_node is PanelContainer, "CardFrame is a plain Panel, not a layout Container that would fight its children's sizes")
		if frame_node != null:
			var art_node: TextureRect = null
			var info_node: Control = null
			for child in frame_node.get_children():
				if child is TextureRect and art_node == null: art_node = child
				elif child is PanelContainer and info_node == null: info_node = child
			check(art_node != null, "hand card still has an art TextureRect")
			check(info_node != null, "hand card still has an info box")
			if art_node != null and info_node != null:
				check(art_node.size.y > frame_node.size.y * 0.9, "the art covers essentially the whole card (got %.1f of %.1f), not squeezed by a sibling" % [art_node.size.y, frame_node.size.y])
				check(info_node.size.y < frame_node.size.y * 0.6, "the info box only covers its bottom portion (got %.1f of %.1f), not the entire card" % [info_node.size.y, frame_node.size.y])
			check(_find_texture_rect_ending_with(frame_node, "card_frame_golden_border.png"), "hand cards show the ornate frame too, not just the enlarged peek")
			var border_rect: TextureRect = _get_texture_rect_ending_with(frame_node, "card_frame_golden_border.png")
			if border_rect != null:
				check(border_rect.position.is_equal_approx(Vector2.ZERO), "the border overlay's own rect starts at the card's top-left corner (got %s)" % border_rect.position)
				check(border_rect.size.is_equal_approx(frame_node.size), "the border overlay's own rect fills the whole card (got %s, card is %s)" % [border_rect.size, frame_node.size])
	else:
		check(false, "found a hand card to check its art/layout on")

	section("== hold-to-peek card preview ==")
	# MTG Arena style: pressing a card shows it enlarged immediately (no mid-gesture delay —
	# see HandCard.TAP_THRESHOLD_MS for why); a real drag drops the peek right away, and
	# _on_touch_up decides afterwards, from how long the touch actually lasted, whether it
	# was a tap (plays the card) or a hold (just closes the peek without playing).
	var peek_card: Node = _find_by_script(game.root, HandCard)
	if peek_card != null:
		peek_card._on_touch_down(Vector2(58, 84))
		check(bool(peek_card.is_previewing), "pressing a card shows the enlarged peek immediately, no delay")
		await process_frame
		check(game.overlay.get_node_or_null("HoldPreview") != null, "the peek overlay is actually in the tree")
		# _modal_backdrop() (the hold-to-peek backdrop) carries the identical overlay-reordering
		# fix _modal_dialog() does, and independently — this asserts its own call site directly
		# rather than relying on _modal_dialog()'s coverage elsewhere to imply it also works here.
		check(game.overlay.get_index() == game.root.get_child_count() - 1, "opening the hold-preview backdrop also moves overlay to be root's last child")
		var peek_holder: Node = game.overlay.get_node_or_null("HoldPreview")
		check(peek_holder != null and _find_texture_rect_ending_with(peek_holder, "card_frame_golden_border.png"), "the enlarged peek actually shows the generated ornate frame asset")
		peek_card.is_held = false
		peek_card.is_previewing = false
		game._clear_hold_preview()
	else:
		check(false, "found a hand card to test the hold-to-peek preview on")

	# An attack card taps into arming a target instead of playing directly whenever more than
	# one enemy is alive (see _tap_card) — pick a non-attack slot so this test's outcome
	# isn't at the mercy of whatever card and enemy count happen to be live at this point.
	var safe_slot := -1
	for i in game.combat.state.hand.size():
		if not game._card_is_attack(game.content.card(game.combat.state.hand[i].card_id)):
			safe_slot = i
			break
	var tap_card: Node = null
	if safe_slot >= 0:
		var all_hand_cards: Array = []
		_find_all_by_script(game.root, HandCard, all_hand_cards)
		for c in all_hand_cards:
			if int(c.hand_index) == safe_slot: tap_card = c; break
	if tap_card != null:
		var hand_before_tap: int = game.combat.state.hand.size()
		tap_card._on_touch_down(Vector2(58, 84))
		tap_card._on_touch_up()
		# _end_preview() runs synchronously inside _on_touch_up, but the actual play is
		# deferred (playing a card rebuilds the battle screen and frees this HandCard) — check
		# the preview flag before awaiting a frame gives that deferred call a chance to run
		# and free tap_card out from under this check. queue_free() itself needs that same
		# frame to actually remove the overlay node, so that check has to wait for it instead.
		check(not bool(tap_card.is_previewing), "a quick tap closes its own peek again")
		await process_frame
		check(game.overlay.get_node_or_null("HoldPreview") == null, "the peek overlay is gone after a quick tap")
		check(game.combat.state.hand.size() == hand_before_tap - 1, "a quick tap (well under the hold threshold) still plays the card")
		var w := 0.0
		while game.resolving and w < 10.0:
			await create_timer(0.1).timeout
			w += 0.1

	var hold_card: Node = _find_by_script(game.root, HandCard)
	if hold_card != null:
		var hand_before_hold: int = game.combat.state.hand.size()
		hold_card._on_touch_down(Vector2(58, 84))
		await create_timer(0.28).timeout
		check(bool(hold_card.is_previewing), "the peek is still showing partway through a hold")
		hold_card._on_touch_up()
		await process_frame
		check(not bool(hold_card.is_previewing), "releasing after a genuine hold closes the peek")
		check(game.overlay.get_node_or_null("HoldPreview") == null, "the peek overlay is removed on release")
		check(game.combat.state.hand.size() == hand_before_hold, "releasing after a hold (over the tap threshold) does not play the card")
	else:
		check(false, "found a hand card to test the hold-then-release behaviour on")

	var peek_card_2: Node = _find_by_script(game.root, HandCard)
	if peek_card_2 != null:
		peek_card_2._on_touch_down(Vector2(58, 84))
		check(bool(peek_card_2.is_previewing), "a second card also peeks on press")
		peek_card_2._on_drag(Vector2(90, 84))
		check(not bool(peek_card_2.is_previewing), "starting a real drag drops the peek immediately")
		await process_frame
		check(game.overlay.get_node_or_null("HoldPreview") == null, "the peek overlay is gone the instant dragging starts")
		peek_card_2._on_touch_up()
		await process_frame

	# A long hold is exactly the gesture iOS's own long-press recognizer watches for, and it
	# can swallow the matching release before Godot's per-Control _gui_input ever sees a
	# touch-up — which used to leave the enlarged card stuck on screen forever. _input()
	# watches the raw event stream instead, so it should notice the release even though
	# _on_touch_up() is never called at all here.
	var peek_card_3: Node = _find_by_script(game.root, HandCard)
	if peek_card_3 != null:
		peek_card_3._on_touch_down(Vector2(58, 84))
		check(bool(peek_card_3.is_previewing), "a third card also peeks on press")
		var fake_release := InputEventScreenTouch.new()
		fake_release.pressed = false
		peek_card_3._input(fake_release)
		await process_frame
		check(not bool(peek_card_3.is_previewing), "a raw release event closes the peek even without _on_touch_up firing")
		check(game.overlay.get_node_or_null("HoldPreview") == null, "the peek overlay is gone once the raw release is observed")
		peek_card_3.is_held = false

	# A real hold's own release is not reliably delivered on-device at all (iOS's long-press
	# gesture recognition can swallow it outright, independent of anything HandCard itself
	# does) — the dimmed tap-anywhere backdrop is the actual guarantee that the peek can
	# always be closed, via Godot's own Button.pressed rather than raw touch tracking.
	var peek_card_4: Node = _find_by_script(game.root, HandCard)
	if peek_card_4 != null:
		peek_card_4._on_touch_down(Vector2(58, 84))
		check(bool(peek_card_4.is_previewing), "a fourth card also peeks on press")
		var backdrop: Node = game.overlay.get_node_or_null("HoldPreview")
		check(backdrop is Button, "the peek is shown behind a dismissible backdrop button")
		if backdrop is Button: (backdrop as Button).pressed.emit()
		await process_frame
		check(game.overlay.get_node_or_null("HoldPreview") == null, "tapping the backdrop closes the peek regardless of the original touch's own state")
		peek_card_4.is_held = false
		peek_card_4.is_previewing = false

	section("== drawn icons render without crashing ==")
	# _draw() only runs through Godot's own dispatch (add to the tree, queue_redraw, let a
	# frame pass) — calling it directly raises "Drawing is only allowed inside _draw()",
	# since draw_* calls check that flag. Route every combination through a real frame so a
	# bad polygon index or div-by-zero in the vector math surfaces here, not just as a
	# warped icon discovered later on a real screen.
	var icon_kinds := ["sword", "shield", "pendant", "staff", "spear", "bow", "sigil",
		"crossed_swords", "crown", "grand_crown", "orb", "coin_stack", "campfire",
		"card_stack", "arrow", "pine", "boulder", "hill", "star", "scroll", "none"]
	var icon_marks := ["", "flame", "drop", "wave", "spike", "wing", "eye", "coin", "spiral",
		"crescent", "rings", "shield_mark", "cycle_arrows", "sparkle", "cross_blade", "bolt", "leaf"]
	var sweep_holder := Control.new()
	game.root.add_child(sweep_holder)
	var drawn := 0
	for k in icon_kinds:
		for m in icon_marks:
			var probe: Control = GameIcon.new()
			probe.kind = k
			probe.flourish = m
			probe.icon_color = Color("83e4c1")
			probe.frame_color = Color("dab56e")
			probe.size = Vector2(32, 32)
			sweep_holder.add_child(probe)
			drawn += 1
	await process_frame
	check(drawn == icon_kinds.size() * icon_marks.size(), "every icon kind/flourish combination is in the tree to draw (%d combinations)" % drawn)
	sweep_holder.queue_free()

	# Every equipment/rune/relic's actual configured kind+flourish/mark — catches a typo'd
	# kind string in content.gd that the generic sweep above cannot.
	var data_holder := Control.new()
	game.root.add_child(data_holder)
	for item in SpiritContent.EQUIPMENT:
		var probe: Control = GameIcon.new()
		probe.kind = str(item.get("icon_kind", "sword"))
		probe.flourish = str(item.get("icon_flourish", ""))
		probe.icon_color = Color("dab56e")
		probe.size = Vector2(32, 32)
		data_holder.add_child(probe)
	for rune in SpiritContent.RUNES:
		var probe: Control = GameIcon.new()
		probe.kind = "sigil"
		probe.flourish = str(rune.get("icon_mark", ""))
		probe.icon_color = Color(rune.color)
		probe.size = Vector2(32, 32)
		data_holder.add_child(probe)
	for relic in SpiritContent.RELICS:
		var probe: Control = GameIcon.new()
		probe.kind = "sigil"
		probe.flourish = str(relic.get("icon_mark", ""))
		probe.icon_color = Color(relic.color)
		probe.size = Vector2(32, 32)
		data_holder.add_child(probe)
	var dizzy: Control = DizzyStars.new()
	dizzy.size = Vector2(24, 24)
	data_holder.add_child(dizzy)
	await process_frame
	check(true, "every equipment/rune/relic's configured icon, and the dizzy-stun stars, drew without raising")
	data_holder.queue_free()

	section("== hit-flash shader and status effects ==")
	game.begin_battle(0)
	await process_frame
	var wm := 0.0
	while game.resolving and wm < 8.0:
		await create_timer(0.1).timeout
		wm += 0.1
	var monster_sprite: CanvasItem = game.enemy_boxes[0].get_node("MonsterSprite") as CanvasItem
	check(monster_sprite.material is ShaderMaterial, "enemy sprite has the hit-flash shader installed")
	game._flash_hit(monster_sprite, Color.WHITE, 0.2)
	var mat: ShaderMaterial = monster_sprite.material
	check(is_equal_approx(float(mat.get_shader_parameter("flash_amount")), 1.0), "flashing sets the shader to fully white immediately")
	await create_timer(0.35).timeout
	check(float(mat.get_shader_parameter("flash_amount")) < 0.1, "the flash fades back out on its own")

	var player_sprite: CanvasItem = game.root.find_child("PlayerSprite", true, false) as CanvasItem
	check(player_sprite != null and player_sprite.material is ShaderMaterial, "player sprite also carries the hit-flash shader")

	# Fox Spirit's layered rig (_build_player_stage(), gated on hero_sprite_key == "fox" and
	# the rig files existing) had zero test coverage before this — one of several visually
	# significant pieces of this batch that shipped with no new assertions.
	check(game.profile.hero_class == "fox_spirit", "sanity-checking the fixture: this battle is still Fox Spirit's own")
	check(game.root.find_child("PlayerGroundAura", true, false) != null, "the fox rig's ground aura layer renders")
	var rig_tail: Node = game.root.find_child("PlayerTail", true, false)
	check(rig_tail != null, "the fox rig's tail layer renders")
	check(rig_tail != null and player_sprite.get_meta("rig_tail", null) == rig_tail, "PlayerSprite tracks its own tail via meta, for the tail-follow tween logic")
	var rig_orb: Node = game.root.find_child("PlayerSpiritOrb", true, false)
	check(rig_orb != null, "the fox rig's floating spirit orb layer renders")
	check(rig_orb != null and player_sprite.get_meta("rig_orb", null) == rig_orb, "PlayerSprite tracks its own orb via meta")

	# Regression coverage for a real bug: downscaling fox_body/fox_tail/fox_orb.png (they
	# shipped at 1024px rendering at ~40-95px) without also updating the flat scale constants
	# calibrated for that original resolution silently shrank all three to a quarter (or an
	# eighth, for the orb) of their intended on-screen size — every dimension check above
	# still passed throughout that regression, since "does the node exist" doesn't catch
	# "is it the right size". Checking effective size (texture width * scale) directly closes
	# that gap; a wide tolerance since the exact px target is a design choice, not a contract.
	var body_sprite := player_sprite as Sprite2D
	if body_sprite != null and body_sprite.texture != null:
		var body_effective_px: float = float(body_sprite.texture.get_width()) * body_sprite.scale.x
		check(body_effective_px > 80.0 and body_effective_px < 140.0, "the fox rig's body renders at roughly its intended ~114px, got %.1fpx (texture %dpx x scale %.4f)" % [body_effective_px, body_sprite.texture.get_width(), body_sprite.scale.x])
	if rig_tail is Sprite2D and (rig_tail as Sprite2D).texture != null:
		var tail_effective_px: float = float((rig_tail as Sprite2D).texture.get_width()) * (rig_tail as Sprite2D).scale.x
		check(tail_effective_px > 90.0 and tail_effective_px < 160.0, "the fox rig's tail renders at roughly its intended ~132px, got %.1fpx" % tail_effective_px)
	if rig_orb is Sprite2D and (rig_orb as Sprite2D).texture != null:
		var orb_effective_px: float = float((rig_orb as Sprite2D).texture.get_width()) * (rig_orb as Sprite2D).scale.x
		check(orb_effective_px > 35.0 and orb_effective_px < 70.0, "the fox rig's spirit orb renders at roughly its intended ~52px, got %.1fpx" % orb_effective_px)

	# Same regression class, same fix pattern (crest_scale_fix): spirit_shield_crest.png was
	# also downscaled from 1024px without correcting the 4 flat scale keyframes calibrated
	# against that resolution (0.01/0.09/0.068/0.095), across 3 separate tween steps in
	# _animate_player_shield_gain(). Checked partway through the unfold (not at its exact
	# final frame, to avoid a flaky exact-timing dependency) — still comfortably inside the
	# ~10-90px band this shrinks to versus the ~2-20px band the bug produced.
	game._animate_player_shield_gain(5)
	await create_timer(0.5).timeout
	var shield_crest: Sprite2D = game.overlay.find_child("AnimShieldCrest", true, false) as Sprite2D
	check(shield_crest != null, "AnimShieldCrest exists mid-animation")
	if shield_crest != null and shield_crest.texture != null:
		var crest_effective_px: float = float(shield_crest.texture.get_width()) * shield_crest.scale.x
		# Lower bound of 40px is deliberately above the ~17-23px this exact bug produced
		# (the same 4 keyframes uncorrected against a texture downscaled 4x) — a narrower
		# floor here would pass either way and defeat the point of this check.
		check(crest_effective_px > 40.0 and crest_effective_px < 130.0, "the shield-gain crest is mid-unfold at a plausible size for its intended ~92px target, got %.1fpx" % crest_effective_px)

	# Every hero has its own dedicated standalone sprite, not borrowing from the shared mob atlas.
	var hero_sprite_checks: Array = [
		{"hero": "stone_sentinel", "file": "hero_stone_sentinel.png"},
		{"hero": "shadow_stalker", "file": "hero_shadow_stalker.png"},
		{"hero": "miasma_witch", "file": "hero_miasma_witch.png"},
	]
	for hc in hero_sprite_checks:
		game.profile.hero_class = str(hc.hero)
		game.begin_battle(0)
		await process_frame
		var hw := 0.0
		while game.resolving and hw < 8.0:
			await create_timer(0.1).timeout
			hw += 0.1
		var hero_sprite: Sprite2D = game.root.find_child("PlayerSprite", true, false) as Sprite2D
		check(hero_sprite != null and not (hero_sprite.texture is AtlasTexture), "%s's battle sprite is a dedicated standalone portrait, not a shared mob atlas cell" % str(hc.hero))
		check(hero_sprite != null and hero_sprite.texture != null and str(hero_sprite.texture.resource_path).ends_with(str(hc.file)), "%s's battle sprite loads its own %s portrait" % [str(hc.hero), str(hc.file)])
	game.profile.hero_class = "fox_spirit"

	var fx_holder := Control.new()
	game.root.add_child(fx_holder)
	var fx_sprite := Sprite2D.new()
	fx_holder.add_child(fx_sprite)
	var buffed_state := {"shield": 5, "burn": 2, "vulnerable": 2, "weak": 2, "stun": 1}
	game._apply_status_fx(fx_holder, fx_sprite, Vector2(40, 40), 30.0, buffed_state)
	await process_frame
	var found_ember := false
	var found_dizzy := false
	var halo_count := 0
	for child in fx_holder.get_children():
		if child is CPUParticles2D: found_ember = true
		if child.get_script() == DizzyStars: found_dizzy = true
		if child is Panel and child != fx_sprite: halo_count += 1
	check(found_ember, "burn attaches an ember particle effect to the sprite")
	check(found_dizzy, "stun attaches the dizzy-stars spinner")
	check(halo_count >= 2, "shield and vulnerable each attach a halo (found %d)" % halo_count)
	check(fx_sprite.modulate.r < 0.9, "weak visibly desaturates the sprite")
	fx_holder.queue_free()

	section("== card polarity and target rings ==")
	var harmful_card: Dictionary = game.content.card("strike")
	var helpful_card: Dictionary = game.content.card("ward")
	var debuff_card: Dictionary = game.content.card("cinderHex")
	check(game._card_target_mode(harmful_card) == "enemy", "damage cards aim at enemies")
	check(game._card_target_mode(helpful_card) == "self", "defensive cards aim at you")
	check(game._card_target_mode(debuff_card) == "enemy", "pure debuffs aim at enemies too")

	# A burn-only card has no damage effect. It used to be played with no target at all, and
	# opponent statuses are dropped when the target index is -1, so the card did nothing.
	var hex := SpiritCombat.new(game.content)
	hex.create(77, game.content.encounters[3], game.content.raw.startingDeck, 60)
	hex.state.hand = [{"uid": 901, "card_id": "cinderHex"}]
	var burn_before: int = int(hex.state.enemies[0].burn)
	check(hex.play(0, -1), "a burn-only card can be played")
	check(int(hex.state.enemies[0].burn) > burn_before, "burn-only card actually applies burn (%d -> %d)" % [burn_before, int(hex.state.enemies[0].burn)])

	game.begin_battle(29)
	await process_frame
	var pw := 0.0
	while game.resolving and pw < 8.0:
		await create_timer(0.1).timeout
		pw += 0.1
	var enemy_ring: Control = game.enemy_boxes[0].get_node_or_null("TargetGlow") as Control
	var player_ring: Control = game.root.find_child("PlayerTargetGlow", true, false) as Control
	check(enemy_ring != null and player_ring != null, "both target rings exist")
	if enemy_ring != null and player_ring != null:
		check(not enemy_ring.visible and not player_ring.visible, "no rings before a card is picked up")
		game._show_valid_targets("enemy")
		check(enemy_ring.visible and not player_ring.visible, "an attack lights enemies only")
		game._show_valid_targets("self")
		check(player_ring.visible and not enemy_ring.visible, "a defensive card lights you only")
		game._clear_valid_targets()
		check(not enemy_ring.visible and not player_ring.visible, "rings clear when the card is released")

	# Enemy sprites restore their scale from a meta; without it they reset to 1.0, which is
	# roughly three times their real size.
	var monster: Node2D = game.enemy_boxes[0].get_node_or_null("MonsterSprite") as Node2D
	check(monster != null and monster.has_meta("base_scale"), "enemy sprite records its base scale")
	if monster != null and monster.has_meta("base_scale"):
		var recorded: float = float(monster.get_meta("base_scale"))
		check(is_equal_approx(recorded, monster.scale.x), "recorded scale matches the sprite (%.3f)" % recorded)
		check(recorded < 1.0, "base scale is the real shrunk value, not the 1.0 fallback")
		await game._animate_enemy_action(game.enemy_boxes[0], "empower", game.combat.state.enemies[0])
		check(is_equal_approx(game.enemy_boxes[0].get_node("MonsterSprite").scale.x, recorded), "enemy returns to its own size after acting")

	section("== victory goes straight to the chest ==")
	game.begin_battle(0)
	await process_frame
	var vw := 0.0
	while game.resolving and vw < 8.0:
		await create_timer(0.1).timeout
		vw += 0.1
	for enemy in game.combat.state.enemies: enemy.health = 0
	game.combat.state.phase = "won"
	game.show_battle()
	await process_frame
	var open_label: String = game.content.ui("ui.open_chest", game.lang)
	check(_find_button_containing(game.root, open_label) == null, "the victory screen no longer repeats the open-chest button")
	var vwait := 0.0
	while vwait < 3.0 and _find_button_containing(game.root, open_label) == null:
		await create_timer(0.1).timeout
		vwait += 0.1
	check(_find_button_containing(game.root, open_label) != null, "victory hands off to the chest screen on its own")

	section("== reward flow ==")
	game.current_stage = 4
	game.begin_battle(4)
	await process_frame
	var w2 := 0.0
	while game.resolving and w2 < 8.0:
		await create_timer(0.1).timeout
		w2 += 0.1
	game._grant_stage_rewards()
	game.show_reward_details()
	await process_frame
	check(game.root.get_child_count() > 0, "reward details page builds")
	var has_skip := _find_text(game.root, game.content.ui("ui.skip_card", game.lang))
	check(not has_skip, "the skip-card option is gone")

	section("== a chapter boss win no longer auto-advances into the new chapter ==")
	var saved_unlocked_boss: int = int(game.profile.unlocked)
	var saved_position_boss: int = int(game.profile.position)
	var saved_ch_boss: int = int(game.current_map_chapter)
	game.profile.unlocked = 4 # stage 4 (chapter 0's boss) not yet a replay
	game.profile.position = 4
	game.current_map_chapter = 0
	game.current_stage = 4
	game.begin_battle(4)
	await process_frame
	var bw := 0.0
	while game.resolving and bw < 8.0:
		await create_timer(0.1).timeout
		bw += 0.1
	game._grant_stage_rewards()
	game._rewards_screen._finish_reward()
	await process_frame
	check(game.root.find_child("ChapterTransitionLayer", true, false) == null, "winning a chapter boss does not auto-launch the chapter transition cutscene")
	check(game.current_map_chapter == 0, "the map still shows the just-cleared chapter, not the new one, until the player asks to move on")
	check(int(game.profile.position) == 4, "profile.position stays on the cleared boss stage until the player taps next stage")
	check(int(game.profile.unlocked) == 5, "the new chapter's first stage is unlocked immediately, just not entered yet")

	# Tapping "next stage" (the same _travel_to() call the dock's next-stage button makes) is
	# what plays the walk-in cutscene now, and finishing it leads straight into the new
	# chapter's first battle.
	game._travel_to(int(game.profile.position) + 1)
	await process_frame
	check(game.root.find_child("ChapterTransitionLayer", true, false) != null, "tapping next stage across a chapter boundary plays the chapter transition cutscene")
	var skip_btn_boss: Button = game.root.find_child("ChapterTransitionSkipBtn", true, false) as Button
	check(skip_btn_boss != null, "the cutscene triggered by next-stage still has its skip button")
	if skip_btn_boss != null:
		skip_btn_boss.pressed.emit()
		await process_frame
	check(game.current_map_chapter == 1, "finishing the cutscene lands the map on the new chapter")
	check(int(game.profile.position) == 5, "finishing the cutscene advances profile.position to the new chapter's first stage")
	check(game.combat != null and int(game.current_stage) == 5, "finishing the cutscene begins battle for the new chapter's first stage")

	game.profile.unlocked = saved_unlocked_boss
	game.profile.position = saved_position_boss
	game.current_map_chapter = saved_ch_boss
	game.show_map()
	await process_frame

	# Milestone 3: Great Bosses draw exclusively from the high-stakes boss relic pool
	# (cursedTome/titanBell/chaosPrism); a regular boss must never hand one out, so those
	# three stay rare and mean something. Save/restore unlocked/position/claimed-events
	# around this — granting a stage-49 reward jumps `unlocked` straight to 50, which would
	# otherwise make every stage in between look like an already-visited replay (no new
	# items granted) to every test that runs after this one.
	check(game.content.node_kind(4) == "boss", "stage 4 (chapter 1) is a regular boss, sanity-checking the fixture")
	check(game.content.node_kind(49) == "greatboss", "stage 49 (chapter 10) is a great boss, sanity-checking the fixture")
	var saved_unlocked: int = int(game.profile.unlocked)
	var saved_position: int = int(game.profile.position)
	var saved_claimed_events: Array = game.profile.get("claimed_stage_events", []).duplicate()
	var saved_relics: Array = game.profile.relics.duplicate()

	game.profile.relics = []
	game.profile.unlocked = 4  # stage 4 not yet a replay
	game.current_stage = 4
	game.begin_battle(4)
	await process_frame
	var rw := 0.0
	while game.resolving and rw < 8.0:
		await create_timer(0.1).timeout
		rw += 0.1
	game._grant_stage_rewards()
	check(not str(game.pending_rewards.relic).is_empty() and not SpiritContent.BOSS_RELIC_IDS.has(str(game.pending_rewards.relic)), "a regular boss kill never grants a high-stakes boss relic, got '%s'" % str(game.pending_rewards.relic))

	game.profile.relics = []
	game.profile.unlocked = 49  # stage 49 not yet a replay
	game.current_stage = 49
	game.begin_battle(49)
	await process_frame
	var gw := 0.0
	while game.resolving and gw < 8.0:
		await create_timer(0.1).timeout
		gw += 0.1
	game._grant_stage_rewards()
	check(SpiritContent.BOSS_RELIC_IDS.has(str(game.pending_rewards.relic)), "a great boss kill grants one of the high-stakes boss relics, got '%s'" % str(game.pending_rewards.relic))

	# E2: a fresh Great Boss kill flags a shareable Run Recap card in the reward flow.
	check(bool(game.pending_rewards.get("great_boss_kill", false)), "a fresh (non-replay) great boss kill sets pending_rewards.great_boss_kill")
	game.show_reward_details()
	await process_frame
	var recap_entry_btn: Button = game.root.find_child("ViewRunRecapBtn", true, false) as Button
	check(recap_entry_btn != null, "ViewRunRecapBtn renders in the reward details screen after a great boss kill")
	recap_entry_btn.pressed.emit()
	await process_frame
	check(game.root.find_child("RunRecapCard", true, false) != null, "show_run_recap() renders the recap card")
	check(_find_label_text(game.root, game.content.hero_name(game.content.hero_class(str(game.profile.hero_class)), game.lang)), "the recap card shows the current hero's name")
	var recap_boss_encounter: Dictionary = game.content.encounters[49]
	var recap_boss_name: String = str(recap_boss_encounter.get("name_en", recap_boss_encounter.name)) if game.lang == "en" else str(recap_boss_encounter.name)
	check(_find_label_text(game.root, game.tf("ui.run_recap_defeated_fmt", recap_boss_name)), "the recap card names the boss actually defeated")
	check(game.root.find_child("RunRecapStats", true, false) != null, "the recap card shows the battle-performance stat row")
	check(_find_label_text(game.root, game.tf("ui.recap_turns", int(game.combat.state.turn))), "the recap card's stat row shows turns taken (Phase 10)")
	check(game.root.find_child("RunRecapDeckHighlights", true, false) != null, "the recap card shows deck highlights")

	# Phase 10: the Share button now actually renders and captures a poster via an off-screen
	# SubViewport, rather than the previous stub that just toasted "saved" without saving
	# anything. ViewportTexture.get_image() reads back null under this suite's own
	# `godot --headless` dummy renderer (confirmed empirically — no real framebuffer to read
	# back from), so this is the one place the graceful-degradation path is exercised for
	# real, not just reasoned about; a real device with a real GPU takes the success path.
	var recap_share_btn: Button = game.root.find_child("RunRecapShareBtn", true, false) as Button
	check(recap_share_btn != null, "RunRecapShareBtn exists to share run recap")
	recap_share_btn.pressed.emit()
	# _capture_recap_image() awaits exactly 2 process_frame calls internally before the toast
	# fires; wait a couple extra to be safely past that.
	for _wait_frame in 4: await process_frame
	check(_find_label_containing(game.overlay, game.t("ui.run_recap_save_unavailable")), "tapping Share under headless's dummy renderer surfaces the 'capture unavailable' toast instead of silently failing or crashing")
	var recap_done_btn: Button = game.root.find_child("RunRecapDoneBtn", true, false) as Button
	check(recap_done_btn != null, "RunRecapDoneBtn exists to return to the reward flow")
	recap_done_btn.pressed.emit()
	await process_frame
	check(game.root.find_child("RunRecapCard", true, false) == null, "RunRecapDoneBtn returns to show_reward_details, leaving the recap screen")

	# A regular (non-great-boss) win must never offer the recap.
	game.profile.relics = []
	game.profile.unlocked = 4
	game.current_stage = 4
	game.begin_battle(4)
	await process_frame
	var rw2 := 0.0
	while game.resolving and rw2 < 8.0:
		await create_timer(0.1).timeout
		rw2 += 0.1
	game._grant_stage_rewards()
	check(not bool(game.pending_rewards.get("great_boss_kill", false)), "a regular boss kill never sets great_boss_kill")
	game.show_reward_details()
	await process_frame
	check(game.root.find_child("ViewRunRecapBtn", true, false) == null, "ViewRunRecapBtn does not render after a regular boss kill")

	game.profile.unlocked = saved_unlocked
	game.profile.position = saved_position
	game.profile.claimed_stage_events = saved_claimed_events
	game.profile.relics = saved_relics

	# Phase 10: Abyss milestones (floor % 5 == 0) are recap-worthy too, per the plan's literal
	# spec ("after Great Boss defeats and Abyss milestones") — same show_run_recap() screen,
	# but reading recap_encounter baked into pending_rewards rather than g.current_stage, which
	# begin_abyss_battle() leaves at its Abyss placeholder of 0 (resolving straight to
	# g.content.encounters[0], the wrong chapter-1 stage, is exactly the bug baking the
	# encounter into pending_rewards at grant-time avoids).
	var saved_abyss_floor: int = int(game.profile.get("abyss_floor", 1))
	var saved_abyss_record: int = int(game.profile.get("abyss_record", 0))
	var saved_boon_draft: bool = game.pending_boon_draft
	game.profile.abyss_floor = 5
	game.begin_abyss_battle()
	await process_frame

	# Regression test for a real, pre-existing bug found while making begin_abyss_battle()
	# callable directly (it had no game.gd delegator at all until this phase — see game.gd's
	# own comment there): _modifier()'s ~48%-of-the-time empty {} result gets a "boons" key
	# added unconditionally right after, turning it non-empty with no name/detail fields at
	# all. Confirmed this crashed _build_player_stage() (a bare Dictionary "name"/"detail" key
	# access, then a null child handed to add_child()) on roughly every other real Abyss
	# battle — timing-dependent on the exact millisecond seed, which is exactly why no prior
	# test had ever reproduced it. Fixed by checking "has a name" there rather than "isn't
	# empty"; verified deterministically here instead of trusting a random seed to hit it.
	game.active_modifier = {"boons": []}
	# _build_player_stage() empirically returns null on this exact bug (a runtime Dictionary
	# key-access error aborts it mid-function despite its declared "-> Control" return type,
	# confirmed by reproducing it directly before writing this fix) — show_battle() then
	# hands that null to add_child(), a second, louder error. Checking the direct return value
	# catches the bug precisely; game.root.get_child_count() > 0 does not, since show_battle()
	# adds plenty of other, unrelated children both before and after this one call.
	check(game._build_player_stage() != null, "an active_modifier with bookkeeping keys but no name/detail (the exact shape begin_abyss_battle() can produce) does not crash _build_player_stage() into returning null")

	var abyss_recap_encounter: Dictionary = game.content.abyss_encounter(5)
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(bool(game.pending_rewards.get("abyss_milestone", false)), "reaching Abyss floor 5 (a multiple of 5) flags the win as recap-worthy")
	check(game.pending_boon_draft, "floor 5 still also offers the pre-existing boon draft, unaffected by the new recap flag alongside it")
	game.pending_boon_draft = false
	game.show_reward_details()
	await process_frame
	var abyss_recap_btn: Button = game.root.find_child("ViewRunRecapBtn", true, false) as Button
	check(abyss_recap_btn != null, "ViewRunRecapBtn also renders after an Abyss milestone win")
	abyss_recap_btn.pressed.emit()
	await process_frame
	check(_find_label_text(game.root, game.tf("ui.run_recap_defeated_fmt", str(abyss_recap_encounter.name))), "the Abyss-triggered recap names the actual Abyss floor boss, not stage 0's campaign encounter")
	check(_find_label_text(game.root, game.tf("ui.recap_turns", int(game.combat.state.turn))), "the Abyss-triggered recap also shows turns taken")
	game.show_reward_details()
	await process_frame

	game.profile.abyss_floor = saved_abyss_floor
	game.profile.abyss_record = saved_abyss_record
	game.pending_boon_draft = saved_boon_draft

	# All 11 relics now have painted icons (relic_<id>.png), same treatment equipment/runes
	# already had — _relic_icon_badge() should use the real art, not its drawn-sigil fallback.
	for relic_id in ["foxCharm", "starShard", "ancientSeed", "windChime", "bloodJade", "thunderSeal", "mirrorScale", "emberCore", "cursedTome", "titanBell", "chaosPrism"]:
		check(ResourceLoader.exists("res://assets/icons/relic_%s.png" % relic_id), "%s has a painted relic icon asset" % relic_id)
	var fox_charm_badge: Panel = game._relic_icon_badge(game.content.relic("foxCharm"), Color.WHITE)
	check(_find_texture_rect_ending_with(fox_charm_badge, "relic_foxCharm.png"), "_relic_icon_badge renders the painted icon for a relic that has one")

	# Relic Resonance UI testing
	var res_badge: Panel = game._relic_resonance_badge(SpiritContent.RELIC_RESONANCES[0], Color.GOLD, 40)
	check(res_badge != null, "_relic_resonance_badge builds successfully")

	# Camp screen active resonance rendering
	var pre_camp_tab: String = game.camp_tab
	var pre_camp_relics: Array = game.profile.relics.duplicate()
	game.profile.relics = ["thunderSeal", "mirrorScale"]
	game.camp_tab = "collection"
	game.show_camp()
	await process_frame
	var res_row: Node = game.root.find_child("ResonanceRow_res_sun_moon", true, false)
	check(res_row != null, "active resonance row rendered in Camp screen for thunderSeal + mirrorScale")
	game.profile.relics = pre_camp_relics
	game.camp_tab = pre_camp_tab

	# Battle screen active resonance HUD test
	var saved_combat: SpiritCombat = game.combat
	game.combat = SpiritCombat.new(game.content)
	game.combat.create(777, game.content.encounters[0], game.profile.deck, 60, {}, [], {}, {}, ["thunderSeal", "mirrorScale"])
	game.show_battle()
	await process_frame
	check(game.root.get_child_count() > 0, "battle screen renders with active relic resonance")
	check(game.combat.state.relic_resonances.has("res_sun_moon"), "combat state tracks active resonance in battle screen")
	game.combat = saved_combat

	var target_card: Dictionary = game.content.card("moonfang")
	game.profile.deck = []
	for i in 25: game.profile.deck.append("strike")
	game.profile.collection["strike"] = 25
	var owned_before: int = int(game.profile.collection.get("moonfang", 0))
	game._smart_add_card(target_card)
	await process_frame
	check(game.profile.deck.size() == 25, "smart add keeps the deck at 25, got %d" % game.profile.deck.size())
	check(game.profile.deck.has("moonfang"), "smart add put the new card in the deck")
	check(int(game.profile.collection.get("moonfang", 0)) == owned_before + 1, "smart add also records the copy owned")

	game.profile.deck = []
	for i in 24: game.profile.deck.append("strike")
	game._collect_card(target_card)
	await process_frame
	check(game.profile.deck.size() == 24, "collect-only leaves the deck untouched")

	section("== shop buy button ==")
	game.profile.gold = 500
	game.show_shop()
	await process_frame
	var tile: Control = _find_shop_tile(game.root)
	check(tile != null, "shop renders card tiles")
	if tile != null:
		check(not (tile is Button), "shop tile itself is not a button, so touching a card cannot buy it")
		check(_find_button_containing(tile, game.content.ui("ui.shop_buy", game.lang)) != null, "each tile carries an explicit buy button")
		# The tile border used to be a single rounded rectangle, then four procedural leaf
		# corner marks; it now carries the same card_frame_golden_border.png overlay as hand
		# cards and the enlarged peek, plus a drawn rarity star row.
		check(_find_texture_rect_ending_with(tile, "card_frame_golden_border.png"), "the shop tile shows the ornate frame asset")
		var shop_frame_rect: TextureRect = _get_texture_rect_ending_with(tile, "card_frame_golden_border.png")
		if shop_frame_rect != null:
			check(shop_frame_rect.size.is_equal_approx(tile.size), "the shop tile's frame overlay is sized to the tile, not the texture's own 728x1006 (got %s, tile is %s)" % [shop_frame_rect.size, tile.size])
		var frame_marks: Array = []
		_find_all_by_script(tile, GameIcon, frame_marks)
		var star_count := 0
		for m in frame_marks:
			if str(m.kind) == "star": star_count += 1
		check(star_count >= 1 and star_count <= 3, "the shop tile shows a rarity star row (%d stars)" % star_count)

	section("== shop rotation and escalating price ==")
	var stock_a: Dictionary = game._shop_period()
	var stock_b: Dictionary = game._shop_period()
	check(stock_a.cards.size() == game.SHOP_STOCK_COUNT, "shop offers a limited daily selection (%d), not the whole catalog" % stock_a.cards.size())
	check(stock_a.cards.size() < game.content.cards.size(), "the daily stock is smaller than the full card pool")
	var ids_a: Array = stock_a.cards.map(func(c): return c.id)
	var ids_b: Array = stock_b.cards.map(func(c): return c.id)
	check(ids_a == ids_b, "stock is deterministic within the same day, not reshuffled every visit")
	check(int(stock_a.sale_index) >= 0 and int(stock_a.sale_index) < stock_a.cards.size(), "exactly one stock slot is marked as today's sale")

	# This is the reported issue: buying the same card over and over cost the same every
	# time, so gold alone could stack unlimited copies of one card with no friction.
	var probe_card: Dictionary = game.content.card("moonfang")
	var price0: int = game._shop_price(probe_card, 0)
	var price1: int = game._shop_price(probe_card, 1)
	var price2: int = game._shop_price(probe_card, 2)
	check(price0 < price1 and price1 < price2, "each owned copy raises the price of the next (%d -> %d -> %d)" % [price0, price1, price2])

	section("== enemy intents ==")
	var fresh := SpiritCombat.new(game.content)
	fresh.create(7, game.content.encounters[24], game.content.raw.startingDeck, 60)
	var intent: Dictionary = fresh.state.enemies[0].intent
	check(not intent.is_empty(), "enemy telegraphs an intent up front")
	check(intent.has("kind") and intent.has("amount"), "intent carries kind and amount")

	var kinds := {}
	for s in 40:
		var probe := SpiritCombat.new(game.content)
		probe.create(s * 31 + 5, game.content.encounters[45], game.content.raw.startingDeck, 60)
		for turn in 4:
			kinds[str(probe.state.enemies[0].intent.get("kind", "?"))] = true
			probe.end_turn()
			if probe.state.phase != "player": break
	check(kinds.size() >= 3, "late-game enemies use several intent kinds: %s" % ", ".join(kinds.keys()))

	section("== intent is honoured exactly ==")
	var honoured := 0
	var checked := 0
	for s in 30:
		var probe := SpiritCombat.new(game.content)
		probe.create(s * 17 + 3, game.content.encounters[12], game.content.raw.startingDeck, 60)
		var enemy: Dictionary = probe.state.enemies[0]
		var planned: Dictionary = enemy.intent.duplicate()
		if str(planned.get("kind", "")) != "defend": continue
		var shield_before: int = int(enemy.shield)
		probe.end_turn()
		checked += 1
		# shield_per_turn resets the pool first, so compare against that baseline.
		var baseline: int = int(enemy.mechanics.get("shield_per_turn", 0))
		if int(enemy.shield) == baseline + int(planned.amount): honoured += 1
	if checked > 0: check(honoured == checked, "defend intents grant exactly the telegraphed shield (%d/%d)" % [honoured, checked])
	else: print("  note: no defend intent rolled in sample")

	section("== relics ==")
	var plain := SpiritCombat.new(game.content)
	plain.create(11, game.content.encounters[0], game.content.raw.startingDeck, 60)
	check(plain.state.hand.size() == 5, "plain opening hand is 5 cards")
	check(int(plain.state.energy) == 2, "plain opening energy is 2")
	# Verify turn 2 draw with 3 cards remaining on turn 1:
	var turn2_combat := SpiritCombat.new(game.content)
	turn2_combat.create(11, game.content.encounters[0], game.content.raw.startingDeck, 60)
	turn2_combat.state.hand.pop_back()
	turn2_combat.state.hand.pop_back()
	check(turn2_combat.state.hand.size() == 3, "turn 1 remaining hand is 3 cards")
	turn2_combat.end_turn()
	check(turn2_combat.state.hand.size() == 5, "turn 2 draws flat 2 cards (3 remaining -> exactly 5 cards, not 7)")

	var chimed := SpiritCombat.new(game.content)
	chimed.create(11, game.content.encounters[0], game.content.raw.startingDeck, 60, {}, [], {}, {}, ["windChime"])
	check(chimed.state.hand.size() == 5, "windChime keeps turn 1 hand at 5 cards")
	chimed.state.discard = [chimed.state.draw.pop_back(), chimed.state.draw.pop_back()]
	chimed.state.draw.clear()
	var h_before: int = chimed.state.hand.size()
	chimed._draw(1)
	check(chimed.state.hand.size() == h_before + 2, "windChime draws 1 extra card when draw pile reshuffles")

	var charmed := SpiritCombat.new(game.content)
	charmed.create(11, game.content.encounters[0], game.content.raw.startingDeck, 60, {}, [], {}, {}, ["foxCharm"])
	check(int(charmed.state.energy) == 2, "foxCharm keeps turn 1 energy at 2")
	charmed.end_turn()
	check(int(charmed.state.energy) == 3, "foxCharm grants 1 extra energy on turn 2, got %d" % int(charmed.state.energy))

	section("== damage preview matches reality ==")
	var matched := 0
	var compared := 0
	for s in 25:
		var probe := SpiritCombat.new(game.content)
		probe.create(s * 13 + 9, game.content.encounters[6], game.content.raw.startingDeck, 60)
		game.combat = probe
		var hand_index := -1
		for i in probe.state.hand.size():
			var card: Dictionary = game.content.card(probe.state.hand[i].card_id)
			if game._predict_damage(card, 0).is_attack and int(card.cost) <= int(probe.state.energy):
				hand_index = i
				break
		if hand_index < 0: continue
		var chosen: Dictionary = game.content.card(probe.state.hand[hand_index].card_id)
		var predicted: Dictionary = game._predict_damage(chosen, 0)
		var hp_before: int = int(probe.state.enemies[0].health)
		probe.play(hand_index, 0)
		var actual: int = hp_before - int(probe.state.enemies[0].health)
		compared += 1
		if actual == int(predicted.damage): matched += 1
		else: print("    mismatch: predicted %d, actual %d (card %s)" % [int(predicted.damage), actual, chosen.id])
	check(compared > 0 and matched == compared, "preview equals dealt damage (%d/%d)" % [matched, compared])

	section("== asset completeness ==")
	var all_chapters_exist := true
	for c in 50:
		var path := "res://assets/chapters/chapter_%d.png" % c
		if not ResourceLoader.exists(path) or not (load(path) is Texture2D):
			all_chapters_exist = false
			fail("Chapter background missing or invalid: %s" % path)
	check(all_chapters_exist, "all 50 chapter background textures exist and load")

	var all_equips_exist := true
	for eq in SpiritContent.EQUIPMENT:
		var path := "res://assets/icons/equip_%s.png" % str(eq.id)
		if not ResourceLoader.exists(path) or not (load(path) is Texture2D):
			all_equips_exist = false
			fail("Equipment icon missing or invalid: %s" % path)
	check(all_equips_exist, "all 12 equipment icon textures exist and load")

	var all_runes_exist := true
	for r in SpiritContent.RUNES:
		var path := "res://assets/icons/rune_%s.png" % str(r.id)
		if not ResourceLoader.exists(path) or not (load(path) is Texture2D):
			all_runes_exist = false
			fail("Rune icon missing or invalid: %s" % path)
	check(all_runes_exist, "all 10 rune icon textures exist and load")

	var frames := ["starter", "common", "uncommon", "rare"]
	var all_frames_exist := true
	for f in frames:
		var path := "res://assets/card_frame_%s.png" % f
		if not ResourceLoader.exists(path) or not (load(path) is Texture2D):
			all_frames_exist = false
			fail("Card frame missing or invalid: %s" % path)
	check(all_frames_exist, "all 4 rarity card frames exist and load")

	check(ResourceLoader.exists("res://assets/icons/quest.png") and load("res://assets/icons/quest.png") is Texture2D, "quest icon exists and loads")
	check(ResourceLoader.exists("res://assets/icons/profile.png") and load("res://assets/icons/profile.png") is Texture2D, "profile icon exists and loads")
	check(ResourceLoader.exists("res://assets/map_pin_rune.png") and load("res://assets/map_pin_rune.png") is Texture2D, "map pin rune texture exists and loads")

	var audio_tracks := [
		"res://assets/audio/map_symphony.wav",
		"res://assets/audio/battle_stage_0.wav",
		"res://assets/audio/battle_stage_1.wav",
		"res://assets/audio/battle_stage_2.wav",
		"res://assets/audio/battle_stage_3.wav",
		"res://assets/audio/battle_stage_4.wav"
	]
	var all_audio_exist := true
	for aud in audio_tracks:
		if not ResourceLoader.exists(aud) or not (load(aud) is AudioStream):
			all_audio_exist = false
			fail("Audio track missing or invalid: %s" % aud)
	check(all_audio_exist, "all 6 symphonic music audio files exist and load as AudioStream")

	section("== quest notification dot and loadout ==")
	game.show_map()
	await process_frame
	var q_btn: Node = game.root.find_child("QuestButton", true, false)
	check(q_btn != null, "QuestButton exists in top header of map")

	var test_q: Dictionary = game.profile.daily_quests[0]
	test_q.progress = test_q.target
	test_q.claimed = false
	check(game._has_claimable_quest(), "has_claimable_quest detects claimable quest")
	game.show_map()
	await process_frame
	q_btn = game.root.find_child("QuestButton", true, false)
	check(q_btn != null and q_btn.get_node_or_null("NotificationDot") != null, "QuestButton shows NotificationDot when quest is ready to claim")

	test_q.claimed = true
	for q in game.profile.daily_quests: q.claimed = true
	for q in game.profile.weekly_quests: q.claimed = true
	check(not game._has_claimable_quest(), "has_claimable_quest is false when all quests claimed")
	game.show_map()
	await process_frame
	q_btn = game.root.find_child("QuestButton", true, false)
	check(q_btn != null and q_btn.get_node_or_null("NotificationDot") == null, "NotificationDot clears once all quests are claimed")

	game.profile.card_runes["strike"] = "swift"
	check(game.profile.card_runes.get("strike") == "swift", "Rune sockets to card in profile")
	game.profile.card_runes.erase("strike")
	check(not game.profile.card_runes.has("strike"), "Rune unsockets from card cleanly")

	game.profile.equipment_slots["weapon"] = "emberBlade"
	check(game.profile.equipment_slots.get("weapon") == "emberBlade", "Equipment slots into weapon slot")
	game.profile.equipment_slots.erase("weapon")
	check(not game.profile.equipment_slots.has("weapon"), "Equipment unequips cleanly")

	# ── Phase 1 feature tests ──
	section("== battle speed toggle ==")
	game.begin_battle(0)
	game.show_battle()
	var speed_btn: Button = game.root.find_child("SpeedToggle", true, false) as Button
	check(speed_btn != null, "SpeedToggle button exists in battle HUD")
	# Simulate clicking speed toggle to cycle 1.0 -> 1.5 -> 2.0 -> 3.0 -> 4.0 -> 1.0
	game._cycle_speed()
	check(game.battle_speed == 1.5, "after first click speed is 1.5")
	game._cycle_speed()
	check(game.battle_speed == 2.0, "after second click speed is 2.0")
	game._cycle_speed()
	check(game.battle_speed == 3.0, "after third click speed is 3.0")
	game._cycle_speed()
	check(game.battle_speed == 4.0, "after fourth click speed is 4.0")
	game._cycle_speed()
	check(game.battle_speed == 1.0, "after fifth click speed wraps to 1.0")
	check(float(game.profile.get("battle_speed", 0.0)) == 1.0, "battle_speed persists to profile")

	section("== manual pass turn button ==")
	game.begin_battle(0)
	game.show_battle()
	var pass_btn: Button = game.root.find_child("PassTurnBtn", true, false) as Button
	check(pass_btn != null, "PassTurnBtn exists in combat status row")

	section("== keyword tooltip badges ==")
	# Show a card peek and verify keyword pills are present
	var test_card_inst: Dictionary = game.combat.state.hand[0]
	var test_card: Dictionary = game.content.card(str(test_card_inst.get("card_id", "strike")))
	var rune_for_card: String = str(game.profile.card_runes.get(test_card.id, ""))
	var big_face: Panel = game._big_card_face(test_card, rune_for_card)
	game.root.add_child(big_face)
	# The card should have at least one keyword pill (all cards have at least damage/shield/etc)
	var found_keyword_pill := false
	for child in big_face.get_children():
		if child is HBoxContainer:
			for btn in child.get_children():
				if btn is Button and btn.custom_minimum_size.y == 22:
					found_keyword_pill = true
					break
	check(found_keyword_pill, "keyword tooltip pills exist in enlarged card face")
	big_face.queue_free()

	section("== Phase 7 keyword pills: boomerang/reverb/overload ==")
	for entry in [["emberBoomerang", "Boomerang"], ["windReverb", "Reverb"], ["fireOverload", "Overload"]]:
		var kw_card_id: String = str(entry[0])
		var kw_pill_text: String = str(entry[1])
		var kw_card: Dictionary = game.content.card(kw_card_id)
		var kw_face: Panel = game._big_card_face(kw_card, "")
		game.root.add_child(kw_face)
		var kw_btn := _find_button_containing(kw_face, kw_pill_text)
		check(kw_btn != null, "%s shows a %s keyword pill in the enlarged card face" % [kw_card_id, kw_pill_text])
		kw_face.queue_free()

	# ── Phase 2 feature tests ──
	section("== shop card purge service ==")
	game.show_shop()
	var shop_purge_btn: Button = game.root.find_child("ShopPurgeBtn", true, false) as Button
	check(shop_purge_btn != null, "ShopPurgeBtn exists in shop screen")

	section("== campfire rest site screen ==")
	game.show_event(3, "rest")
	var found_rest_heal := _find_text(game.root, game.content.ui("ui.rest_heal_choice", game.lang))
	var found_rest_purify := _find_text(game.root, game.content.ui("ui.rest_purify_choice", game.lang))
	var found_rest_smith := _find_text(game.root, game.content.ui("ui.rest_smith_choice", game.lang))
	check(found_rest_heal, "Campfire has rest heal choice")
	check(found_rest_purify, "Campfire has purify altar choice")
	check(found_rest_smith, "Campfire has smith upgrade choice")

	section("== deck purge screen ==")
	game.show_deck_purge(game.show_map, 0)
	var found_purge_title := _find_label_text(game.root, game.content.ui("ui.purge_title", game.lang))
	check(found_purge_title, "Deck purge screen renders with title")
	var found_purge_btn := _find_text(game.root, game.content.ui("ui.purge_confirm", game.lang))
	check(found_purge_btn, "Deck purge screen displays purge confirmation button")

	section("== deck upgrade screen ==")
	game.show_deck_upgrade(game.show_map)
	var found_upgrade_title := _find_label_text(game.root, game.content.ui("ui.upgrade_title", game.lang))
	check(found_upgrade_title, "Deck upgrade screen renders with title")

	section("== card awakening (+2) upgrade ==")
	# Force every other deck card to the max upgrade level (which shows no button at all) so
	# the "+1"/"Awaken" buttons found below are unambiguously strike's, regardless of whatever
	# upgrade levels the real borrowed save already had on other cards.
	var strike_name: String = game.content.text(game.content.card("strike").nameKey, game.lang)
	var prior_upgrades: Dictionary = game.profile.upgrades.duplicate(true)
	var awaken_deck_ids: Array[String] = []
	for card_id in game.profile.deck:
		if not (card_id in awaken_deck_ids): awaken_deck_ids.append(card_id)
	for card_id in awaken_deck_ids: game.profile.upgrades[card_id] = SpiritContent.MAX_CARD_UPGRADE
	game.profile.upgrades["strike"] = 0

	game.show_deck_upgrade(game.show_map)
	check(not _find_label_containing(game.root, strike_name + " +"), "an unupgraded card's name carries no + suffix")
	var plus1_btn := _find_button_containing(game.root, "+1")
	check(plus1_btn != null, "an unupgraded card offers a +1 button in the Spirit Smith screen")
	plus1_btn.pressed.emit()
	check(int(game.profile.upgrades.get("strike", 0)) == 1, "pressing +1 upgrades the card to level 1")

	game.show_deck_upgrade(game.show_map)
	check(_find_label_containing(game.root, strike_name + " +1"), "a +1 card's name shows the +1 suffix in the Spirit Smith screen")
	var awaken_btn := _find_button_containing(game.root, game.content.ui("ui.awaken_btn", game.lang))
	check(awaken_btn != null, "a +1 card offers an Awaken button on a later Spirit Smith visit")
	awaken_btn.pressed.emit()
	check(int(game.profile.upgrades.get("strike", 0)) == 2, "pressing Awaken upgrades the card to Awakened (+2)")

	game.show_deck_upgrade(game.show_map)
	check(_find_label_containing(game.root, strike_name + " +2"), "an Awakened card's name shows the +2 suffix")
	check(_find_label_text(game.root, game.content.ui("ui.awakened_label", game.lang)), "an Awakened card shows the Awakened label instead of a button")
	check(_find_button_containing(game.root, game.content.ui("ui.awaken_btn", game.lang)) == null, "an Awakened card can no longer be upgraded further, so no Awaken button remains anywhere")
	game.profile.upgrades = prior_upgrades

	section("== card foil shader application ==")
	var rare_card: Dictionary = game.content.card("phoenixEdge")
	var rare_face: Panel = game._big_card_face(rare_card, "")
	game.root.add_child(rare_face)
	var rare_art: TextureRect = rare_face.find_child("TextureRect", true, false) as TextureRect
	# Find art child which has material
	var has_foil := false
	for child in rare_face.get_children():
		if child is TextureRect and (child as TextureRect).material is ShaderMaterial:
			has_foil = true
			break
	check(has_foil, "Rare card face carries foil ShaderMaterial")
	rare_face.queue_free()

	# ── Phase 3 feature tests ──
	section("== hero archetypes & endless abyss ==")
	game.camp_tab = "character"
	game.show_camp()
	var found_hero_title := _find_label_text(game.root, game.content.ui("ui.hero_classes_title", game.lang))
	check(found_hero_title, "Hero archetypes section renders in camp's character tab")
	check(game.root.find_child("BeginnerRecBadge", true, false) != null, "BeginnerRecBadge exists on fox_spirit hero panel")
	game.camp_tab = "challenges"
	game.show_camp()
	var found_abyss_title := _find_label_text(game.root, game.content.ui("ui.abyss_title", game.lang))
	check(found_abyss_title, "Endless abyss section renders in camp's challenges tab")
	var abyss_btn: Button = game.root.find_child("AbyssEnterBtn", true, false) as Button
	check(abyss_btn != null, "AbyssEnterBtn exists in camp's challenges tab")

	# Test switching class
	check(game.profile.get("hero_class", "") == "fox_spirit", "initial hero class is fox_spirit")
	var sentinel: Dictionary = game.content.hero_class("stone_sentinel")
	game.profile.hero_class = "stone_sentinel"
	game.profile.deck = sentinel.deck.duplicate()
	SpiritSave.write(game.profile)
	check(game.profile.hero_class == "stone_sentinel", "switched hero class to stone_sentinel")
	check(game.profile.deck.size() == 25, "stone_sentinel deck has 25 cards")
	game.show_map()
	check(game.traveler != null, "traveler exists on map with new hero class")

	section("== growth roadmap D3: miasma witch (4th hero) ==")
	game.camp_tab = "character"
	game.show_camp()
	await process_frame
	check(_find_label_text(game.root, game.content.hero_name(game.content.hero_class("miasma_witch"), game.lang)), "Miasma Witch's name renders in the hero archetypes list")
	# Shipped with her own standalone portrait (assets/characters/miasma_witch.png) rather than
	# the 3x3 atlas everyone else uses (all 9 cells were already spoken for) — the art-pending
	# placeholder this used to check for is gone now that she has real art, and her sprite key
	# should resolve to that standalone file, not fall back to a borrowed atlas cell.
	check(not _find_label_text(game.root, game.content.ui("ui.hero_art_pending", game.lang)), "the art-pending badge no longer renders now that Miasma Witch has her own portrait")
	check(not bool(game.content.hero_class("miasma_witch").get("art_pending", false)), "miasma_witch's data no longer carries art_pending")
	check(ResourceLoader.exists("res://assets/characters/miasma_witch.png"), "miasma_witch's standalone portrait file exists")
	check(game._get_character_texture("miasma_witch") is Texture2D and not (game._get_character_texture("miasma_witch") is AtlasTexture), "miasma_witch's sprite key resolves to her standalone portrait, not an atlas slice")
	var miasma: Dictionary = game.content.hero_class("miasma_witch")
	game.profile.hero_class = "miasma_witch"
	game.profile.deck = miasma.deck.duplicate()
	for cid in miasma.deck:
		game.profile.collection[cid] = maxi(int(game.profile.collection.get(cid, 0)), miasma.deck.count(cid))
	SpiritSave.write(game.profile)
	check(game.profile.hero_class == "miasma_witch", "switched hero class to miasma_witch")
	game.begin_battle(0)
	await process_frame
	check(game.combat.state.energy == 2, "a fresh battle with miasma_witch at mastery level 0 still starts with two energy (no free perks)")
	game._grant_mastery_xp(800)
	check(game.content.mastery_level_for_xp(int(game.profile.hero_masteries.miasma_witch.xp)) == 5, "miasma_witch can reach mastery level 5 like any other hero")

	section("== growth roadmap D1: on-card synergy tags ==")
	check(game._card_synergy_tags(game.content.card("foxfire")) == "🔥", "foxfire's synergy tag is exactly the burn glyph")
	check(game._card_synergy_tags(game.content.card("toxinDart")) == "☣", "toxinDart's synergy tag is the poison glyph, not a second one for its plain damage")
	check(game._card_synergy_tags(game.content.card("strike")) == "", "strike (plain damage only) has no synergy tags")
	check(game._card_synergy_tags(game.content.card("spiritNova")) == "🌀 ⚔", "spiritNova gets both its weak and cleave tags")
	check("🔥" in game._kind_element_line(game.content.card("foxfire")), "the kind/element line used across every card face appends the synergy tags")

	section("== repeated stage rewards & event claiming ==")
	check(not game._is_stage_event_claimed(42), "unvisited stage 42 event is not claimed")
	game._mark_stage_event_claimed(42)
	check(game._is_stage_event_claimed(42), "stage 42 event is marked as claimed")
	game.profile.unlocked = 5
	check(game._is_replay(2), "stage 2, below the unlock frontier, is detected as already cleared")
	check(game._is_stage_event_claimed(2), "an already-cleared stage's one-time event is treated as claimed")
	# A battle-type stage's own _grant_stage_rewards() no longer has a "replay" case to test
	# here at all — a cleared stage can never be re-entered in the first place, see the D2
	# section ("stage purified") and _on_pin_pressed()/_show_replay_mode_prompt().
	game.current_stage = 2
	var test_win_combat := SpiritCombat.new(game.content)
	test_win_combat.create(1, game.content.encounters[2], game.content.raw.startingDeck, 60)
	test_win_combat.state.player.health = 35
	game.combat = test_win_combat
	game._grant_stage_rewards()
	check(game.profile.health == 60, "stage victory sets profile health to full 60")
	check(int(game.pending_rewards.get("gold", 0)) > 0, "a stage win still grants gold with no replay-halving logic left to zero it out")

	section("== milestone 1: combat transparency & mobile controls ==")
	game.begin_battle(0)
	await process_frame
	var draw_chip := game.root.find_child("DrawPileChip", true, false) as Control
	var discard_chip := game.root.find_child("DiscardPileChip", true, false) as Control
	check(draw_chip != null, "DrawPileChip exists in combat HUD")
	check(discard_chip != null, "DiscardPileChip exists in combat HUD")

	# Test Pile Inspector
	game.show_pile_inspector("ui.pile_draw_title", game.combat.state.draw)
	await process_frame
	var inspector := game.overlay.get_node_or_null("PileInspector") as Control
	check(inspector != null, "PileInspector opens on overlay")
	var close_btn := inspector.find_child("PileCloseBtn", true, false) as Button
	check(close_btn != null, "PileCloseBtn exists inside inspector")
	if close_btn:
		close_btn.emit_signal("pressed")
		await process_frame
		check(game.overlay.get_node_or_null("PileInspector") == null, "closing PileInspector frees it from overlay")

	# Test Cancel Drop Zone
	game._show_cancel_zone(true)
	await process_frame
	var cancel_zone := game.overlay.get_node_or_null("CancelDropZone") as Control
	check(cancel_zone != null, "CancelDropZone appears when card is dragged")
	game._show_cancel_zone(false)
	await process_frame
	check(game.overlay.get_node_or_null("CancelDropZone") == null, "CancelDropZone cleans up after drag ends")

	# Test Lethal Forecast Badge
	game.combat.state.enemies[0].health = 4
	game._show_damage_preview(game.content.card("strike"), 0)
	await process_frame
	var dmg_preview := game.overlay.get_node_or_null("DamagePreview") as Control
	check(dmg_preview != null, "DamagePreview displays on enemy")
	var lethal_badge := dmg_preview.find_child("LethalBadge", true, false) as Control
	check(lethal_badge != null, "LethalBadge displays when attack will finish target")
	game._clear_damage_preview()
	await process_frame
	check(game.overlay.get_node_or_null("DamagePreview") == null, "DamagePreview clears cleanly")

	# Test Danger Warning Badge on player
	game.combat.state.player.health = 10
	game.combat.state.player.shield = 0
	game.combat.state.enemies[0].intent = {"kind":"attack", "amount": 15}
	game.show_battle()
	await process_frame
	var danger_badge := game.root.find_child("DangerWarningBadge", true, false) as Control
	check(danger_badge != null, "DangerWarningBadge displays when incoming damage exceeds player HP+shield")

	section("== curse intent visual effect ==")
	# spirit_curse_seal.png shipped with the card-play VFX batch but was never wired to
	# anything — the enemy "curse" intent (and the decay_blight/void_curse cards it deals
	# out) had no visual treatment at all before this.
	game._animate_player_curse()
	await process_frame
	check(game.overlay.find_child("AnimCurseSeal", true, false) != null, "AnimCurseSeal VFX sprite appears on the player when a curse intent resolves")

	section("== milestone 2: visual punch, finishing blow & abyss boons ==")
	# Test map ambience particles
	game.show_map()
	await process_frame
	var ambience_particles := game.root.find_child("MapAmbienceParticles", true, false) as CPUParticles2D
	check(ambience_particles != null, "MapAmbienceParticles exists with biome dynamic theming")

	# Test finishing blow animation
	game.begin_battle(0)
	await process_frame
	var fb_box: Control = game.enemy_boxes[0]
	await game._animate_finishing_blow(fb_box, null)
	await process_frame
	check(game.overlay.get_node_or_null("FinishingBlowBanner") == null, "FinishingBlowBanner completes and cleans up cleanly")

	# Test Abyss boons draft
	game.profile.abyss_boons = []
	game.show_abyss_boon_draft()
	await process_frame
	var boon_list := game.root.find_child("BoonDraftList", true, false) as Control
	check(boon_list != null, "BoonDraftList renders on screen")
	check(boon_list.get_child_count() >= 1, "boon choices are offered")
	var first_boon_panel: Node = boon_list.get_child(0)
	var claim_btn: Button = null
	for child in first_boon_panel.find_children("", "Button", true, false):
		if str(child.name).begins_with("ChooseBoon_"):
			claim_btn = child as Button
			break
	check(claim_btn != null, "ChooseBoon button exists")
	if claim_btn:
		claim_btn.emit_signal("pressed")
		await process_frame
		check(game.profile.abyss_boons.size() == 1, "selecting boon adds it to profile.abyss_boons")

	section("== growth roadmap D4: great boss phase 2 banner ==")
	game.begin_battle(0)
	await process_frame
	game._show_boss_phase_banner("烬火狂怒", "攻击力提升4点，免疫灼烧！")
	await process_frame
	var phase_banner := game.overlay.get_node_or_null("BossPhaseBanner") as Control
	check(phase_banner != null, "BossPhaseBanner appears on boss phase transition")
	phase_banner.queue_free()
	await process_frame

	section("== milestone 4: compendium, hero mastery & daily trial ==")
	game.compendium_tab = "cards"
	game.show_compendium()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.compendium_title", game.lang)), "Compendium title renders")
	check(game.root.find_child("CompendiumMilestonesBar", true, false) != null, "CompendiumMilestonesBar exists in compendium")
	check(not game.profile.compendium_milestones_claimed.has(50), "compendium 50% milestone starts unclaimed")
	game._claim_compendium_milestone(50)
	check(game.profile.compendium_milestones_claimed.has(50), "compendium 50% milestone is claimed")
	check(_find_button_containing(game.root, game.content.ui("ui.compendium_tab_bestiary", game.lang)) != null, "Bestiary tab button exists")
	game.compendium_tab = "bestiary"
	game.show_compendium()
	await process_frame
	check(game.root.get_child_count() > 0, "Bestiary tab renders")

	section("== world lore: chronicle compendium tab ==")
	check(_find_button_containing(game.root, game.content.ui("ui.compendium_tab_chronicle", game.lang)) != null, "Chronicle tab button exists")
	var prior_unlocked: int = int(game.profile.unlocked)
	game.profile.unlocked = 0
	game.compendium_tab = "chronicle"
	game.show_compendium()
	await process_frame
	check(_find_label_containing(game.root, game.content.chapter_name(0, game.lang)), "chapter 1, always reached, shows its real name in the Chronicle")
	check(_find_label_text(game.root, game.content.chapter_lore(0, game.lang)), "chapter 1's chronicle entry text renders")
	check(_find_label_text(game.root, game.t("ui.chronicle_locked")), "an unreached chapter shows the chronicle-specific locked label")
	check(not _find_label_text(game.root, game.content.chapter_lore(49, game.lang)), "chapter 50's lore stays hidden before it's reached")

	game.profile.unlocked = 49 * 5
	game.show_compendium()
	await process_frame
	check(_find_label_containing(game.root, game.content.chapter_name(49, game.lang)), "reaching chapter 50 reveals its real name in the Chronicle")
	game.profile.unlocked = prior_unlocked

	section("== career codex: compendium tab ==")
	check(_find_button_containing(game.root, game.content.ui("ui.compendium_tab_codex", game.lang)) != null, "Codex tab button exists")
	game.compendium_tab = "codex"
	game.show_compendium()
	await process_frame
	check(game.root.find_child("CodexOverviewPanel", true, false) != null, "CodexOverviewPanel renders in Codex tab")
	check(game.root.find_child("CodexMasteryPanel", true, false) != null, "CodexMasteryPanel renders in Codex tab")
	check(_find_label_text(game.root, game.t("ui.codex_overview")), "Codex overview title renders")
	check(_find_label_text(game.root, game.t("ui.codex_mastery")), "Codex mastery title renders")
	check(_find_label_text(game.root, game.t("ui.codex_hall_of_fame")), "Codex hall of fame title renders")

	# A synthetic key is used here (rather than a real card/equipment id) so the check doesn't
	# depend on what earlier sections in this same long-running suite already collected or
	# fought — this suite shares one profile across every section.
	check(not game._bestiary_discovered("_smoke_test_enemy"), "an unmarked bestiary key starts undiscovered")
	game._mark_discovered("bestiary", "_smoke_test_enemy")
	check(game._bestiary_discovered("_smoke_test_enemy"), "marking a bestiary key discovers it permanently")
	game._mark_discovered("relics", "starShard")
	check(game._relic_discovered("starShard"), "marking a relic id discovers it")

	# C4: bestiary first-discovery bonus fires the instant begin_battle() newly marks that
	# stage's enemy discovered, but not again on a repeat encounter with the same foe.
	var stage0_enemy: String = str(game.content.encounters[0].name)
	game._compendium_dict("bestiary").erase(stage0_enemy)
	check(not game._bestiary_discovered(stage0_enemy), "stage 0's enemy starts undiscovered for the bonus test")
	var gold_before_discovery: int = int(game.profile.gold)
	game.begin_battle(0)
	await process_frame
	check(int(game.profile.gold) == gold_before_discovery + 20, "first sighting of a bestiary enemy grants a one-time 20 gold bonus")
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	var gold_before_repeat: int = int(game.profile.gold)
	game.begin_battle(0)
	await process_frame
	check(int(game.profile.gold) == gold_before_repeat, "re-encountering an already-discovered bestiary enemy grants no repeat bonus")

	var totals: Vector2i = game._compendium_totals()
	check(totals.y > 0, "compendium totals count a nonzero catalog of collectibles")
	check(totals.x >= 0 and totals.x <= totals.y, "discovered count never exceeds the total")

	game.camp_tab = "collection"
	game.show_camp()
	await process_frame
	check(game.root.find_child("CompendiumOpenBtn", true, false) != null, "CompendiumOpenBtn exists in camp's collection tab")

	# Hero Mastery: a fresh hero sits at level 0 (see test_runner.gd for why — combat.gd's
	# "turn 1 is strictly 2 energy" invariant must hold with zero mastery investment), and
	# crossing a threshold raises the level.
	game.profile.hero_class = "fox_spirit"
	game.profile.hero_masteries = {}
	check(game.content.mastery_level_for_xp(0) == 0, "a fresh hero mastery starts at level 0")
	game._grant_mastery_xp(60)
	check(int(game.profile.hero_masteries.fox_spirit.xp) == 60, "mastery XP accumulates on the currently active hero")
	check(game.content.mastery_level_for_xp(int(game.profile.hero_masteries.fox_spirit.xp)) == 1, "60 xp reaches mastery level 1")
	game.camp_tab = "character"
	game.show_camp()
	await process_frame
	check(_find_label_containing(game.root, "Lv.1"), "hero archetypes section shows the reached mastery level")

	# C2: 轮回 (Samsara / Reincarnation) — this block mutates a chunk of profile state (unlocked,
	# position, difficulty, samsara_count, health, gold, claimed_stage_events) to exercise the
	# locked path, the eligible path, and a real end-to-end reset, so every touched field is
	# saved before and restored straight after — the same shared-profile discipline this suite's
	# F1/digest entries already established. This design (see AGENTS.md/GROWTH_ROADMAP.md for the
	# merge history behind it — two independently-built prestige systems landed on the same
	# roadmap item) deliberately does NOT reset deck/collection/relics/equipment/runes, unlike
	# the alternate implementation it replaced, so this block also proves those survive a cycle
	# untouched rather than saving/restoring them purely defensively.
	var saved_unlocked_sm: int = int(game.profile.unlocked)
	var saved_position_sm: int = int(game.profile.position)
	var saved_difficulty_sm: int = int(game.profile.difficulty)
	var saved_samsara_count_sm: int = int(game.profile.get("samsara_count", 0))
	var saved_health_sm: int = int(game.profile.health)
	var saved_gold_sm: int = int(game.profile.gold)
	var saved_events_sm: Array = game.profile.claimed_stage_events.duplicate()

	# SamsaraSection lives in the "challenges" tab (DifficultyTierRow's neighbor), not "character".
	game.camp_tab = "challenges"
	game.profile.samsara_count = 0
	game.profile.unlocked = 249
	game.profile.difficulty = 0
	game.show_camp()
	await process_frame
	check(game.root.find_child("SamsaraSection", true, false) != null, "SamsaraSection renders in the challenges tab even before eligibility")
	check(game.root.find_child("SamsaraEnterBtn", true, false) == null, "SamsaraEnterBtn does NOT appear at unlocked=249/difficulty=0 — the discarded OR-based rule would have allowed this; the merged rule requires unlocked>=250 AND difficulty>=5")

	game.profile.unlocked = 250
	game.show_camp()
	await process_frame
	check(game.root.find_child("SamsaraEnterBtn", true, false) == null, "SamsaraEnterBtn still locked at unlocked=250 alone — difficulty must also reach the required tier")

	game.profile.difficulty = 5
	game.show_camp()
	await process_frame
	var samsara_enter_btn: Button = game.root.find_child("SamsaraEnterBtn", true, false) as Button
	check(samsara_enter_btn != null, "SamsaraEnterBtn appears once BOTH unlocked>=250 AND difficulty>=5 hold")

	# Mutate deck/collection/relics/equipment/runes away from the starting shape so the
	# survives-untouched assertions below actually prove something, then restore them regardless
	# of what the checks find.
	var saved_deck_sm: Array = game.profile.deck.duplicate()
	var saved_collection_sm: Dictionary = game.profile.collection.duplicate(true)
	var saved_relics_sm: Array = game.profile.relics.duplicate()
	var saved_equip_owned_sm: Array = game.profile.equipment_owned.duplicate()
	var saved_equip_slots_sm: Dictionary = game.profile.equipment_slots.duplicate(true)
	var saved_rune_inv_sm: Dictionary = game.profile.rune_inventory.duplicate(true)
	game.profile.deck = ["strike", "strike"]
	game.profile.collection = {"strike": 2}
	game.profile.relics = ["cursedTome"]
	game.profile.equipment_owned = ["emberBlade"]
	game.profile.equipment_slots = {"weapon": "emberBlade"}
	game.profile.rune_inventory = {"swift": 1}
	game.profile.position = 123
	game.profile.claimed_stage_events = [1, 2, 3]

	game.enter_samsara()
	await process_frame
	check(int(game.profile.samsara_count) == 1, "enter_samsara increments samsara_count")
	check(int(game.profile.unlocked) == 0, "enter_samsara resets unlocked back to stage 0")
	check(int(game.profile.position) == 0, "enter_samsara resets position back to stage 0")
	check(game.profile.claimed_stage_events.is_empty(), "enter_samsara clears claimed_stage_events")
	check(int(game.profile.health) == 60, "enter_samsara resets health to a flat 60, matching every other battle-end reset site")
	check(game.profile.deck == ["strike", "strike"], "enter_samsara does NOT reset the deck (narrower reset scope than the discarded design)")
	check(game.profile.collection == {"strike": 2}, "enter_samsara does NOT reset the card collection")
	check(game.profile.relics == ["cursedTome"], "enter_samsara does NOT reset relics")
	check(game.profile.equipment_owned == ["emberBlade"], "enter_samsara does NOT reset owned equipment")
	check(game.profile.equipment_slots == {"weapon": "emberBlade"}, "enter_samsara does NOT reset equipped slots")
	check(game.profile.rune_inventory == {"swift": 1}, "enter_samsara does NOT reset the rune inventory")
	check(int(game.profile.difficulty) == 5, "enter_samsara leaves the selected challenge tier untouched so the next cycle doesn't re-climb it")

	game.profile.deck = saved_deck_sm
	game.profile.collection = saved_collection_sm
	game.profile.relics = saved_relics_sm
	game.profile.equipment_owned = saved_equip_owned_sm
	game.profile.equipment_slots = saved_equip_slots_sm
	game.profile.rune_inventory = saved_rune_inv_sm

	# enter_samsara() also guards its own eligibility (mirrors _samsara_section()'s gate) rather
	# than trusting only the UI button's visibility — confirm calling it again immediately (now
	# ineligible, since unlocked just reset to 0) is a safe no-op, not a second free cycle.
	game.enter_samsara()
	await process_frame
	check(int(game.profile.samsara_count) == 1, "enter_samsara is a no-op when called while ineligible (guards itself, not just the UI button)")

	# Each samsara cycle raises the difficulty ladder's ceiling by one tier past A5, uncapped —
	# and the NEXT cycle's eligibility now requires that raised ceiling, not a flat A5, or a
	# player could cycle indefinitely by re-tapping the same A5 button forever.
	game.profile.unlocked = 250
	game.show_camp()
	await process_frame
	var tier_row: Control = game.root.find_child("DifficultyTierRow", true, false) as Control
	check(tier_row != null and tier_row.get_child_count() == 7, "one samsara cycle raises the tier ladder to A0-A6 (7 buttons), not just the original A0-A5")

	game.profile.difficulty = 5
	game.show_camp()
	await process_frame
	check(game.root.find_child("SamsaraEnterBtn", true, false) == null, "after one cycle, being at A5 is no longer enough for the next cycle — the requirement escalated to A6")
	game.profile.difficulty = 6
	game.show_camp()
	await process_frame
	check(game.root.find_child("SamsaraEnterBtn", true, false) != null, "moving up to the newly-required A6 makes the next cycle available again")

	# The tier ladder used to be purely cosmetic (see content.difficulty_modifier()'s header
	# comment) — a real player tapping A5 got zero actual extra challenge. Confirm a selected
	# tier now actually reaches combat: begin_battle() merges it into active_modifier, which
	# combat.create() reads as health_scale/damage_bonus. A per-stage random flavor modifier can
	# also contribute to the same fields, so assert the tier's own floor rather than an exact
	# value (flavor can only add on top, never reduce below the tier's contribution). Bumped
	# directly to samsara_count=2 (past the shield-blessing milestone, content.samsara_bonuses())
	# to also confirm that blessing reaches a real battle through the same hero_bonuses hook Hero
	# Mastery uses, not just the pure content.samsara_bonuses() dict in isolation.
	game.profile.samsara_count = 2
	game.begin_battle(0)
	await process_frame
	check(float(game.active_modifier.get("health_scale", 1.0)) >= 1.72 - 0.001, "difficulty A6 contributes at least its own health_scale (1.0 + 6*0.12) to the battle's active_modifier (got %.2f)" % float(game.active_modifier.get("health_scale", 1.0)))
	check(int(game.active_modifier.get("damage_bonus", 0)) >= 6, "difficulty A6 contributes at least its own damage_bonus to the battle's active_modifier (got %d)" % int(game.active_modifier.get("damage_bonus", 0)))
	check(int(game.combat.state.player.shield) >= 4, "samsara level 2's +4 starting shield blessing reaches a real battle")
	game._leave_battle()
	await process_frame

	var merged_bonuses_sm: Dictionary = game._current_hero_mastery_bonuses()
	check(int(merged_bonuses_sm.get("max_hp", 0)) >= 6, "samsara's max_hp blessing is merged into the hero_bonuses dict combat.create() receives")

	game.profile.unlocked = saved_unlocked_sm
	game.profile.position = saved_position_sm
	game.profile.difficulty = saved_difficulty_sm
	game.profile.samsara_count = saved_samsara_count_sm
	game.profile.health = saved_health_sm
	game.profile.gold = saved_gold_sm
	game.profile.claimed_stage_events = saved_events_sm

	# Daily Trial: force a fresh day so the run starts at stage 0, then drive it through to
	# completion via the same "force phase to won, then grant rewards" shortcut the pre-existing
	# replay test above uses, rather than actually playing out 15 full battles.
	game.profile.daily_trial_record = {"day": -1, "stage": 0, "badges": 0, "best_stage": 0}
	game._ensure_daily_trial_current()
	check(int(game.profile.daily_trial_record.stage) == 0, "daily trial record starts a new day at stage 0")
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(game.root.find_child("DailyTrialEnterBtn", true, false) != null, "DailyTrialEnterBtn exists in camp's challenges tab")
	check(_find_label_containing(game.root, "连胜"), "daily trial shows streak stat")

	# E1: the trend chart renders empty-state text before any day has ever been completed.
	check(game.root.find_child("DailyTrialTrendChart", true, false) != null, "DailyTrialTrendChart renders in the daily trial section")
	check(_find_label_text(game.root, game.content.ui("ui.daily_trial_trend_empty", game.lang)), "the trend chart shows its empty-state message before any day has a recorded result")
	check(game.root.find_child("DailyTrialTrendRow", true, false) == null, "no bar row renders while history is still empty")

	game.begin_daily_trial()
	await process_frame
	check(game.in_daily_trial, "begin_daily_trial enters trial mode")
	# health_scale depends on today's deterministically-rolled tag trio (the "juggernaut" tag
	# sets it), so the expected value is derived from the same active_modifier begin_daily_trial
	# just built rather than assumed to be 1.0.
	var expected_health: int = int(round(int(game.content.daily_trial_encounter(1).health) * float(game.active_modifier.get("health_scale", 1.0))))
	check(int(game.combat.state.enemies[0].max_health) == expected_health, "daily trial stage 1 uses the trial's own encounter curve (with today's modifier), not the campaign's")
	var trial_gold_before: int = int(game.profile.gold)
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(int(game.profile.daily_trial_record.stage) == 1, "winning a trial stage advances daily_trial_record.stage")
	check(int(game.profile.gold) > trial_gold_before, "winning a trial stage grants gold")
	check(not game.in_daily_trial, "_grant_stage_rewards clears in_daily_trial after granting")

	for i in range(2, SpiritContent.DAILY_TRIAL_STAGES + 1):
		game.begin_daily_trial()
		game.combat.state.phase = "won"
		game._grant_stage_rewards()
	check(int(game.profile.daily_trial_record.stage) == SpiritContent.DAILY_TRIAL_STAGES, "completing all 15 stages fills daily_trial_record.stage")
	check(int(game.profile.daily_trial_record.badges) == 1, "clearing the full 15-stage trial awards exactly 1 badge")
	check(int(game.profile.daily_trial_record.best_stage) == SpiritContent.DAILY_TRIAL_STAGES, "best_stage tracks the deepest run reached")
	game.show_camp()
	await process_frame
	check(game.root.find_child("DailyTrialEnterBtn", true, false) == null, "the enter button is hidden once today's trial is fully cleared")

	# E1: rolling over to the next day should record today's (full-clear) result into history
	# and render it as a bar in the trend chart.
	game.profile.daily_trial_record.day -= 1
	game._ensure_daily_trial_current()
	check(game.profile.daily_trial_record.history.size() == 1, "rolling over to a new day records the just-finished day's result")
	game.show_camp()
	await process_frame
	check(game.root.find_child("DailyTrialTrendRow", true, false) != null, "the trend chart renders a bar row once history has at least one entry")
	check(game.root.find_child("TrendBar_%d" % int(game.profile.daily_trial_record.history[0].day), true, false) != null, "a bar exists for the recorded day")

	# B3: Weekly Theme Challenge — same shape as the Daily Trial above (force a fresh week,
	# drive every stage via the same "force phase to won" shortcut), but on a WEEK_SECONDS
	# boundary and with exactly one themed tag instead of a combined trio.
	game.profile.weekly_challenge_record = {"week": -1, "stage": 0, "badges": 0, "best_stage": 0}
	game._ensure_weekly_challenge_current()
	check(int(game.profile.weekly_challenge_record.stage) == 0, "weekly challenge record starts a new week at stage 0")
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(game.root.find_child("WeeklyChallengeEnterBtn", true, false) != null, "WeeklyChallengeEnterBtn exists in camp's challenges tab")
	check(_find_label_containing(game.root, game.content.ui("ui.weekly_challenge_modifier_title", game.lang)), "weekly challenge shows this week's theme")

	game.begin_weekly_challenge()
	await process_frame
	check(game.in_weekly_challenge, "begin_weekly_challenge enters challenge mode")
	var expected_w_health: int = int(round(int(game.content.weekly_challenge_encounter(1).health) * float(game.active_modifier.get("health_scale", 1.0))))
	check(int(game.combat.state.enemies[0].max_health) == expected_w_health, "weekly challenge stage 1 uses the challenge's own encounter curve (with this week's modifier), not the campaign's")
	var w_gold_before: int = int(game.profile.gold)
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(int(game.profile.weekly_challenge_record.stage) == 1, "winning a challenge stage advances weekly_challenge_record.stage")
	check(int(game.profile.gold) > w_gold_before, "winning a challenge stage grants gold")
	check(not game.in_weekly_challenge, "_grant_stage_rewards clears in_weekly_challenge after granting")

	# The exact same "stuck true forever" bug this session found and fixed for Draft Arena
	# below also existed here — _leave_battle() had no in_weekly_challenge branch at all, so a
	# loss or retreat left the flag stuck true, silently misrouting every later battle's
	# rewards (any mode, win or lose) through this challenge's reward branch in
	# _grant_stage_rewards() instead of the real one, for the rest of the session.
	game.begin_weekly_challenge()
	await process_frame
	check(game.in_weekly_challenge, "re-entering weekly challenge works for the next stage")
	game.combat.state.phase = "lost"
	game._leave_battle()
	check(not game.in_weekly_challenge, "_leave_battle clears in_weekly_challenge on a loss")
	check(int(game.profile.weekly_challenge_record.stage) == 1, "a loss keeps the current stage instead of resetting the streak")

	for i in range(2, SpiritContent.WEEKLY_CHALLENGE_STAGES + 1):
		game.begin_weekly_challenge()
		game.combat.state.phase = "won"
		game._grant_stage_rewards()
	check(int(game.profile.weekly_challenge_record.stage) == SpiritContent.WEEKLY_CHALLENGE_STAGES, "completing all 8 stages fills weekly_challenge_record.stage")
	check(int(game.profile.weekly_challenge_record.badges) == 1, "clearing the full 8-stage challenge awards exactly 1 badge")
	check(int(game.profile.weekly_challenge_record.best_stage) == SpiritContent.WEEKLY_CHALLENGE_STAGES, "best_stage tracks the deepest weekly run reached")
	game.show_camp()
	await process_frame
	check(game.root.find_child("WeeklyChallengeEnterBtn", true, false) == null, "the enter button is hidden once this week's challenge is fully cleared")

	# Boss Rush: refights real, already-cleared boss encounters back-to-back (not a synthetic
	# stat block like Abyss/Daily Trial/Weekly Challenge), escalating each full loop back
	# through the same pool of bosses.
	game.profile.unlocked = 5
	game.profile.boss_rush_floor = 1
	game.profile.boss_rush_record = 0
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.boss_rush_title", game.lang)), "Boss Rush section renders in the challenges screen")
	check(game.root.find_child("BossRushEnterBtn", true, false) != null, "BossRushEnterBtn exists in the challenges screen")

	var boss_indices: Array = game.content.boss_rush_boss_indices(int(game.profile.unlocked))
	check(not boss_indices.is_empty(), "at least one boss is reachable at unlocked=5 (chapter 0's boss)")
	check(int(boss_indices[0]) == 4, "stage 4 (chapter 0's boss) is the first entry in the boss rush pool")

	game.begin_boss_rush_battle()
	await process_frame
	check(game.in_boss_rush, "begin_boss_rush_battle() enters boss rush mode")
	check(game.current_stage == int(boss_indices[0]), "the first bout fights the first reachable boss stage")
	var expected_br_health: int = int(round(int(game.content.encounters[game.current_stage].health) * float(game.active_modifier.get("health_scale", 1.0))))
	check(int(game.combat.state.enemies[0].max_health) == expected_br_health, "bout 1 uses the real boss encounter's own stats, unscaled on the very first loop")
	var br_gold_before: int = int(game.profile.gold)
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(int(game.profile.boss_rush_floor) == 2, "winning a bout advances boss_rush_floor")
	check(int(game.profile.boss_rush_record) == 1, "boss_rush_record tracks the deepest bout reached")
	check(int(game.profile.gold) > br_gold_before, "winning a bout grants gold")
	check(not game.in_boss_rush, "_grant_stage_rewards clears in_boss_rush after granting")

	# Looping back through the same (single-boss) pool a second time should scale the fight up.
	game.begin_boss_rush_battle()
	await process_frame
	check(game.current_stage == int(boss_indices[0]), "cycling back through a one-boss pool refights the same boss")
	check(float(game.active_modifier.get("health_scale", 1.0)) > 1.0, "a second loop through the same boss pool escalates enemy health")
	game.combat.state.phase = "lost"
	game._leave_battle()
	check(not game.in_boss_rush, "_leave_battle clears in_boss_rush on a loss")
	check(int(game.profile.boss_rush_floor) == 2, "a loss keeps the current bout number instead of resetting the streak")

	section("== growth roadmap: Phase 8 curse run mutator challenge ==")
	game.profile.difficulty = 0
	game.profile.unlocked = 5
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.curse_run_title", game.lang)), "Curse Run section renders in the challenges screen")
	var curse_locked_btn: Button = game.root.find_child("CurseRunEnterBtn", true, false) as Button
	check(curse_locked_btn != null and curse_locked_btn.disabled, "CurseRunEnterBtn is disabled before reaching Ascension Tier A2")

	game.profile.difficulty = 2
	game.show_camp()
	await process_frame
	var glass_btn: Button = game.root.find_child("CurseMutatorBtn_glass_cannon", true, false) as Button
	check(glass_btn != null, "CurseMutatorBtn_glass_cannon exists once Curse Run unlocks")
	glass_btn.pressed.emit()
	await process_frame
	check(str(game.profile.curse_run.selected) == "glass_cannon", "tapping a mutator badge selects it")
	var curse_enter_btn: Button = game.root.find_child("CurseRunEnterBtn", true, false) as Button
	check(curse_enter_btn != null and not curse_enter_btn.disabled, "CurseRunEnterBtn becomes enabled once a mutator is selected")

	game.begin_curse_run_battle()
	await process_frame
	check(game.in_curse_run, "begin_curse_run_battle() enters curse run mode")
	check(int(game.combat.state.player.max_health) == 30, "Glass Cannon's player_max_hp reaches a real battle (30)")
	var curse_gold_before: int = int(game.profile.gold)
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(int(game.profile.curse_run.floors.get("glass_cannon", 1)) == 2, "winning advances glass_cannon's own floor")
	check(int(game.profile.curse_run.records.get("glass_cannon", 0)) == 1, "winning records the deepest floor reached for that mutator")
	check(int(game.profile.gold) > curse_gold_before, "winning a curse run floor grants gold")
	check(not game.in_curse_run, "_grant_stage_rewards clears in_curse_run after granting")

	# Badge floor: reaching SpiritContent.CURSE_RUN_BADGE_FLOOR unlocks a permanent per-mutator
	# badge, shown as a checkmark on that mutator's own picker badge from then on.
	game.profile.curse_run.floors["glass_cannon"] = SpiritContent.CURSE_RUN_BADGE_FLOOR
	game.begin_curse_run_battle()
	await process_frame
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(game.profile.curse_run.cleared.has("glass_cannon"), "reaching the badge floor unlocks glass_cannon's permanent badge")

	# The exact same stuck-flag shape AGENTS.md documents for every other side mode: a loss
	# must clear in_curse_run without resetting that mutator's own floor.
	game.begin_curse_run_battle()
	await process_frame
	var floor_before_loss: int = int(game.profile.curse_run.floors.get("glass_cannon", 1))
	game.combat.state.phase = "lost"
	game._leave_battle()
	check(not game.in_curse_run, "_leave_battle clears in_curse_run on a loss")
	check(int(game.profile.curse_run.floors.get("glass_cannon", 1)) == floor_before_loss, "a loss keeps the current floor instead of resetting it")

	section("== growth roadmap: sandbox / practice mode ==")
	game.profile.unlocked = 20
	game.profile.health = 10
	game.sandbox_stage = 0
	# Neutralize anything an earlier section in this long-running suite left on the profile
	# (a relic reward, hero mastery XP) that would push starting HP above the flat 60 baseline
	# combat.create() itself would otherwise apply — the "always 60" assertion below needs a
	# clean slate to be meaningful.
	game.profile.relics = []
	game.profile.hero_masteries = {}
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.sandbox_title", game.lang)), "Sandbox section renders in the challenges screen")
	check(game.root.find_child("SandboxEnterBtn", true, false) != null, "SandboxEnterBtn exists in the challenges screen")
	var sandbox_prev_btn := game.root.find_child("SandboxPrevBtn", true, false) as Button
	check(sandbox_prev_btn != null and sandbox_prev_btn.disabled, "the stage picker's prev button is disabled at stage 0")
	var sandbox_next_btn := game.root.find_child("SandboxNextBtn", true, false) as Button
	check(sandbox_next_btn != null, "SandboxNextBtn exists in the challenges screen")
	sandbox_next_btn.pressed.emit()
	check(int(game.sandbox_stage) == 1, "pressing the next stepper advances the picked sandbox stage")

	game.begin_sandbox_battle(int(game.sandbox_stage))
	await process_frame
	check(game.in_sandbox, "begin_sandbox_battle() enters sandbox mode")
	check(game.current_stage == 1, "sandbox fights the exact stage picked in the stepper")
	check(int(game.combat.state.player.health) == 60, "sandbox always starts at a full 60 HP, ignoring the real (low) campaign health")
	check(_find_label_containing(game.root, game.tf("ui.sandbox_stage_label_fmt", game.content.stage_name(1, game.lang))), "the battle HUD shows the Sandbox-prefixed stage label")

	# A win skips the chest/reward flow entirely and returns straight to Camp with no state change.
	var sandbox_gold_before: int = int(game.profile.gold)
	for enemy in game.combat.state.enemies: enemy.health = 0
	game.combat.state.phase = "won"
	game.show_battle()
	await process_frame
	var sandbox_wait := 0.0
	while sandbox_wait < 3.0 and game.in_sandbox:
		await create_timer(0.1).timeout
		sandbox_wait += 0.1
	check(not game.in_sandbox, "winning a sandbox bout clears in_sandbox on its own, without a chest screen")
	check(int(game.profile.gold) == sandbox_gold_before, "a sandbox win grants no gold")
	check(int(game.profile.health) == 10, "a sandbox win leaves the real campaign health completely untouched")

	# A loss (via the retreat/leave path) is equally inert.
	game.begin_sandbox_battle(2)
	await process_frame
	check(game.in_sandbox, "re-entering sandbox mode works for a different stage")
	game.combat.state.phase = "lost"
	game._leave_battle()
	check(not game.in_sandbox, "_leave_battle clears in_sandbox on a loss")
	check(int(game.profile.health) == 10, "a sandbox loss also leaves the real campaign health completely untouched")

	section("== growth batch: Phantom Arena camp section ==")
	# _phantom_arena_section() (Camp's Challenges tab) had zero test coverage before this —
	# one of several visually-significant screens in the same batch that shipped with no
	# new assertions at all.
	game.profile.phantom_arena = {"day": -1, "wins_today": 0, "claimed_today": false}
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(_find_label_containing(game.root, game.content.ui("ui.phantom_arena_title", game.lang)), "Phantom Arena section renders in the challenges tab")
	check(game.root.find_child("PhantomArenaEnterBtn", true, false) != null, "PhantomArenaEnterBtn exists")
	check(game.root.find_child("PhantomArenaClaimBtn", true, false) == null, "PhantomArenaClaimBtn does not render before the first win of the day")

	var phantom_gold_before: int = int(game.profile.gold)
	game.begin_phantom_arena()
	await process_frame
	check(game.in_phantom_arena, "PhantomArenaEnterBtn's begin_phantom_arena() starts a phantom arena battle")
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(not game.in_phantom_arena, "_grant_stage_rewards clears in_phantom_arena after granting")
	check(int(game.profile.phantom_arena.wins_today) == 1, "winning a phantom arena bout increments wins_today")
	check(int(game.profile.gold) > phantom_gold_before, "winning a phantom arena bout grants gold")

	game.show_camp()
	await process_frame
	var phantom_claim_btn: Button = game.root.find_child("PhantomArenaClaimBtn", true, false) as Button
	check(phantom_claim_btn != null, "PhantomArenaClaimBtn appears once wins_today >= 1")
	check(not phantom_claim_btn.disabled, "the daily chest is claimable, not yet claimed")
	var phantom_gold_before_claim: int = int(game.profile.gold)
	phantom_claim_btn.pressed.emit()
	await process_frame
	check(int(game.profile.gold) > phantom_gold_before_claim, "claiming the daily phantom arena chest grants a gold bonus")
	check(bool(game.profile.phantom_arena.claimed_today), "claiming the chest marks it claimed for today")
	var phantom_claim_btn_after: Button = game.root.find_child("PhantomArenaClaimBtn", true, false) as Button
	check(phantom_claim_btn_after != null and phantom_claim_btn_after.disabled, "the chest button is disabled once already claimed today")

	section("== growth roadmap: Phase 9 rotating world event ==")
	game.profile.world_event_record = {"period": -1, "claimed": false, "badges": []}
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(game.root.find_child("WorldEventSection", true, false) != null, "World Event section renders in the challenges tab")
	var we_enter_btn: Button = game.root.find_child("WorldEventEnterBtn", true, false) as Button
	check(we_enter_btn != null, "WorldEventEnterBtn exists in the challenges tab")
	var current_ev: Dictionary = game.content.world_event_for_period(int(game.profile.world_event_record.period))
	check(_find_label_containing(game.root, game.content.ui(str(current_ev.nameKey), game.lang)), "the currently active event's own theme name renders in its section")

	var we_gold_before: int = int(game.profile.gold)
	we_enter_btn.pressed.emit()
	await process_frame
	check(game.in_world_event, "WorldEventEnterBtn's begin_world_event_battle() starts a world event battle")
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(not game.in_world_event, "_grant_stage_rewards clears in_world_event after granting")
	check(int(game.profile.gold) > we_gold_before, "winning a world event battle grants gold")
	check(bool(game.profile.world_event_record.claimed), "the first win of this period marks its bonus as claimed")
	check(game.profile.world_event_record.badges.has(str(current_ev.id)), "the first win of this period unlocks that event's permanent badge")

	# A second win the same period must not re-toast or double-append the same badge id.
	game.begin_world_event_battle()
	await process_frame
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(game.profile.world_event_record.badges.count(str(current_ev.id)) == 1, "winning again the same period does not duplicate the already-earned badge")

	# World Event has no floor/streak state at all, so a loss just needs to clear the flag —
	# same stuck-flag shape AGENTS.md documents for every other side mode.
	game.begin_world_event_battle()
	await process_frame
	game.combat.state.phase = "lost"
	game._leave_battle()
	check(not game.in_world_event, "_leave_battle clears in_world_event on a loss")

	section("== defeat diagnosis: recommended action is visually distinguished ==")
	# diagnose_battle_defeat()'s "action" field used to be computed and never read by the
	# screen that displays its tip — both buttons rendered in the same color regardless of
	# which one was actually recommended. A deck this thin on shield cards (2, under the
	# threshold of 3) with a low average cost (all 1-cost) deterministically recommends
	# "deck" over the generic "cultivate" fallback. Uses "ward" (the real starter shield
	# card) rather than a made-up id — a fictitious "defend" id here used to silently crash
	# _card_view() with "Invalid access to property or key 'id'" the moment the hand
	# rendered (content.card() returns {} for an unknown id), invisibly, since nothing here
	# asserts on the absence of a SCRIPT ERROR.
	var saved_deck_for_diagnosis: Array = game.profile.deck.duplicate()
	game.profile.deck = ["strike", "strike", "ward", "ward"]
	game.current_stage = 0
	game.begin_battle(0)
	await process_frame
	var defeat_wait := 0.0
	while game.resolving and defeat_wait < 8.0:
		await create_timer(0.1).timeout
		defeat_wait += 0.1
	game.combat.state.phase = "lost"
	game.show_battle()
	await process_frame
	check(game.root.find_child("DefeatDiagnosisCard", true, false) != null, "DefeatDiagnosisCard renders on a loss")
	var tune_btn: Button = game.root.find_child("DefeatTuneDeckBtn", true, false) as Button
	var cult_btn: Button = game.root.find_child("DefeatCultivateBtn", true, false) as Button
	check(tune_btn != null and cult_btn != null, "both DefeatTuneDeckBtn and DefeatCultivateBtn exist")
	var diag_check: Dictionary = game.diagnose_battle_defeat()
	check(str(diag_check.get("action", "")) == "deck", "this thin-on-shields, low-cost deck is diagnosed as needing deck tuning, sanity-checking the fixture")
	if tune_btn != null and cult_btn != null:
		var tune_style: StyleBox = tune_btn.get_theme_stylebox("normal")
		var cult_style: StyleBox = cult_btn.get_theme_stylebox("normal")
		check(tune_style is StyleBoxFlat and cult_style is StyleBoxFlat and (tune_style as StyleBoxFlat).bg_color != (cult_style as StyleBoxFlat).bg_color, "the recommended action's button is visually distinguished from the other one, not identically colored")
		check((tune_style as StyleBoxFlat).bg_color == game.GOLD, "the recommended action (Tune Deck) specifically gets the emphasized gold color")
	game._leave_battle()

	# Regression check for a real bug found while touching this section: diagnose_battle_defeat()
	# was reading each effect's "op" key, but every card's effects actually use "operation" (see
	# combat.gd's _resolve_effects) — so shield_cards silently counted 0 for every deck in the
	# game, always, for every player, making the "you lack shield cards" tip fire regardless of
	# the deck's real shield count. A deck with 3 real shield cards (at the "not thin" threshold)
	# must fall through to the generic tip instead of the low-shield one.
	game.profile.deck = ["ward", "ward", "ward", "strike"]
	var diag_with_shields: Dictionary = game.diagnose_battle_defeat()
	check(str(diag_with_shields.get("action", "")) == "cultivate", "a deck with 3 real shield cards is no longer misdiagnosed as shield-poor (op vs operation key-name regression)")

	game.profile.deck = saved_deck_for_diagnosis

	section("== achievements ==")
	game.profile.achievements_unlocked = {}
	game.profile.lifetime_stats = {}
	game._advance_quest("win_battles", 10)
	check(int(game.profile.lifetime_stats.get("win_battles", 0)) == 10, "_advance_quest maintains a permanent lifetime_stats counter alongside period-scoped quest progress")
	check(bool(game.profile.achievements_unlocked.get("win10", false)), "reaching a stat achievement's target unlocks it automatically")
	check(not bool(game.profile.achievements_unlocked.get("win50", false)), "a higher threshold on the same stat stays locked")

	game.profile.abyss_record = 15
	game._refresh_achievements()
	check(bool(game.profile.achievements_unlocked.get("abyss10", false)), "an abyss_floor achievement reads profile.abyss_record directly, no separate counter needed")
	check(not bool(game.profile.achievements_unlocked.get("abyss30", false)), "abyss30 stays locked below its own threshold")

	game.profile.hero_class = "stone_sentinel"
	game.profile.hero_masteries = {"stone_sentinel": {"xp": 800}}
	game._refresh_achievements()
	check(bool(game.profile.achievements_unlocked.get("mastery5", false)), "a mastery_level achievement checks every hero's mastery, not just the active one's stat key")

	var win10_progress_before: int = game._achievement_progress({"kind": "stat", "stat": "win_battles"})
	game._advance_quest("win_battles", 1)
	check(bool(game.profile.achievements_unlocked.get("win10", false)) and game._achievement_progress({"kind": "stat", "stat": "win_battles"}) == win10_progress_before + 1, "an already-unlocked achievement stays unlocked while its underlying stat keeps counting")

	game.compendium_tab = "achievements"
	game.show_compendium()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ach.win10.name", game.lang)), "an unlocked achievement's name renders in the Achievements tab")
	check(_find_label_text(game.root, game.content.ui("ach.win200.name", game.lang)), "a locked achievement still renders (with progress, not hidden)")
	for ach in SpiritContent.ACHIEVEMENTS:
		check(SpiritContent.ACHIEVEMENT_TIERS.has(str(ach.get("tier", ""))), "%s has a valid medal tier" % str(ach.id))
		check(ResourceLoader.exists("res://assets/icons/badge_%s.png" % str(ach.get("tier", ""))), "%s's tier has a matching badge_*.png asset" % str(ach.id))
	var found_locked_badge_dim := false
	var found_unlocked_badge_bright := false
	for child in _find_all_texture_rects(game.root):
		if child.texture == null: continue
		var tex_path: String = child.texture.resource_path
		if not tex_path.contains("badge_"): continue
		if child.modulate.a < 0.9: found_locked_badge_dim = true
		else: found_unlocked_badge_bright = true
	check(found_locked_badge_dim, "a locked achievement's medal badge renders dimmed")
	check(found_unlocked_badge_bright, "an unlocked achievement's medal badge renders at full brightness")

	section("== feature-unlock discoverability toasts ==")
	# game._check_feature_unlocks() fires a one-time "New!" toast the moment profile.unlocked or
	# profile.difficulty first crosses a gated feature's threshold (SpiritContent.FEATURE_UNLOCKS),
	# so a player discovers Compendium/Daily Trial/Abyss/Curse Run/etc. instead of only noticing a
	# new tab appeared. Save/restore every field it reads or writes.
	var saved_unlocked_fu: int = int(game.profile.unlocked)
	var saved_difficulty_fu: int = int(game.profile.difficulty)
	var saved_seen_fu: Array = game.profile.get("feature_unlocks_seen", []).duplicate()

	game.profile.feature_unlocks_seen = []
	game.profile.unlocked = 5
	game.profile.difficulty = 0
	game._check_feature_unlocks()
	check(_find_label_containing(game.overlay, game.t("ui.unlock_ch1_toast")), "crossing unlocked=5 the first time surfaces the chapter-1-features unlock toast")
	check(game.profile.feature_unlocks_seen.has("ch1_features"), "crossing unlocked=5 marks ch1_features as seen")
	check(not game.profile.feature_unlocks_seen.has("abyss"), "unlocked=5 has not yet crossed abyss's own threshold of 10")

	# A second call at the same progress must not re-append an already-seen id or crash.
	var seen_count_after_first: int = game.profile.feature_unlocks_seen.size()
	game._check_feature_unlocks()
	check(game.profile.feature_unlocks_seen.size() == seen_count_after_first, "re-checking at the same progress does not re-append an already-seen id")

	# The "kind":"difficulty" branch reads profile.difficulty instead, independent of unlocked.
	game.profile.difficulty = 2
	game._check_feature_unlocks()
	check(game.profile.feature_unlocks_seen.has("curse_run"), "crossing difficulty=2 marks curse_run as seen, independent of the unlocked-stage thresholds")

	game.profile.unlocked = saved_unlocked_fu
	game.profile.difficulty = saved_difficulty_fu
	game.profile.feature_unlocks_seen = saved_seen_fu

	section("== progressive difficulty tier unlocking ==")
	# A0-A5 (and any samsara-extended tiers) used to all become selectable the instant the
	# section's own overall gate (unlocked>=25) opened, with zero further guardrail — A5 alone
	# is +60% enemy HP and +5 flat damage (content.difficulty_modifier()). Each tier now needs
	# its own campaign-progress threshold (content.difficulty_tier_unlock_stage()) to appear at
	# all, grandfathering in whatever a player already had selected.
	var saved_unlocked_dt: int = int(game.profile.unlocked)
	var saved_difficulty_dt: int = int(game.profile.difficulty)
	var saved_samsara_dt: int = int(game.profile.get("samsara_count", 0))
	game.camp_tab = "challenges"

	game.profile.unlocked = 25
	game.profile.difficulty = 0
	game.profile.samsara_count = 0
	game.show_camp()
	await process_frame
	check(game.root.find_child("DifficultyTierBtn_A0", true, false) != null, "A0 is always shown")
	check(game.root.find_child("DifficultyTierBtn_A1", true, false) != null, "A1 is shown once unlocked reaches its own threshold (25)")
	check(game.root.find_child("DifficultyTierBtn_A2", true, false) == null, "A2 is hidden entirely (not just disabled) before unlocked reaches its threshold (50)")
	var a0_btn: Node = game.root.find_child("DifficultyTierBtn_A0", true, false)
	check(a0_btn != null and a0_btn.find_child("NotificationDot", true, false) == null, "the currently-active default tier (A0) never shows a 'new, untried' marker")
	var a1_btn: Node = game.root.find_child("DifficultyTierBtn_A1", true, false)
	check(a1_btn != null and a1_btn.find_child("NotificationDot", true, false) != null, "a newly-eligible, not-yet-selected tier (A1) is visibly marked so it doesn't blend in")
	check(_find_label_containing(game.root, game.tf("ui.camp_tier_next_unlock", 50)), "a hint names the stage that unlocks the next tier")

	game.profile.unlocked = 50
	game.show_camp()
	await process_frame
	check(game.root.find_child("DifficultyTierBtn_A2", true, false) != null, "A2 appears once unlocked reaches 50")
	check(game.root.find_child("DifficultyTierBtn_A3", true, false) == null, "A3 stays hidden until unlocked reaches 100")

	var a1_select_btn: Button = game.root.find_child("DifficultyTierBtn_A1", true, false) as Button
	if a1_select_btn != null:
		tap_button(a1_select_btn, "DifficultyTierBtn_A1")
		await process_frame
		check(int(game.profile.difficulty) == 1, "tapping a tier button selects it")
		var a1_btn_after: Node = game.root.find_child("DifficultyTierBtn_A1", true, false)
		check(a1_btn_after != null and a1_btn_after.find_child("NotificationDot", true, false) == null, "selecting a tier clears its own 'new, untried' marker")
		var a2_btn_after: Node = game.root.find_child("DifficultyTierBtn_A2", true, false)
		check(a2_btn_after != null and a2_btn_after.find_child("NotificationDot", true, false) != null, "a higher, still-untried tier keeps its marker after a lower one is selected")

	# Grandfathering: a save that already has difficulty=4 selected (from before this system
	# existed, or from a later point in the same playthrough) must keep seeing A4 even if
	# unlocked alone no longer would have unlocked it on its own — this can only ever reveal
	# tiers going forward, never retroactively hide one a player already has active.
	game.profile.unlocked = 30
	game.profile.difficulty = 4
	game.show_camp()
	await process_frame
	check(game.root.find_child("DifficultyTierBtn_A4", true, false) != null, "an already-selected tier (A4) stays visible even below its own threshold (150) — no regression for existing players")
	check(game.root.find_child("DifficultyTierBtn_A5", true, false) == null, "grandfathering only preserves the tier actually selected, it does not also reveal the next one above it")

	game.profile.unlocked = saved_unlocked_dt
	game.profile.difficulty = saved_difficulty_dt
	game.profile.samsara_count = saved_samsara_dt
	game.show_map()
	await process_frame

	section("== phase 3: settings, deck filters, colorblind glyphs, victory recap & hard replays ==")
	# F2: Settings modal
	game.show_map()
	await process_frame
	check(game.root.find_child("SettingsButton", true, false) != null, "SettingsButton exists in map top bar")
	game.show_settings()
	await process_frame
	var settings_modal: Node = game.overlay.get_node_or_null("SettingsModal")
	check(settings_modal != null, "SettingsModal opens on overlay")
	var motion_btn := settings_modal.find_child("ReduceMotionToggleBtn", true, false) as Button
	check(motion_btn != null, "ReduceMotionToggleBtn exists in settings")
	var initial_motion: bool = bool(game.profile.get("reduce_motion", false))
	motion_btn.emit_signal("pressed")
	check(bool(game.profile.get("reduce_motion", false)) != initial_motion, "toggling reduce motion updates profile")

	# Accessibility: Text Size control. The motion toggle above rebuilt SettingsModal (it's a
	# fresh node each time show_settings() reopens it), so this re-fetches rather than reusing
	# the stale settings_modal reference.
	settings_modal = game.overlay.get_node_or_null("SettingsModal")
	check(is_equal_approx(float(game.profile.get("text_scale", 1.0)), 1.0), "text scale starts at the default (Standard)")
	var text_scale_normal_btn := settings_modal.find_child("TextScaleBtn_1_0", true, false) as Button
	check(text_scale_normal_btn != null, "TextScaleBtn_1_0 (Standard) exists in settings")
	var text_scale_xlarge_btn := settings_modal.find_child("TextScaleBtn_1_2", true, false) as Button
	check(text_scale_xlarge_btn != null, "TextScaleBtn_1_2 (Extra Large) exists in settings")
	text_scale_xlarge_btn.emit_signal("pressed")
	check(is_equal_approx(float(game.profile.get("text_scale", 1.0)), 1.2), "pressing the Extra Large button updates profile.text_scale")
	check(int(game._label("sample", 14).get_theme_font_size("font_size")) == 17, "a freshly-built label reflects the new text_scale immediately")
	game.profile.text_scale = 1.0

	# The Extra Large press above rebuilt SettingsModal again — re-fetch once more before
	# continuing on to the account-linking checks below.
	settings_modal = game.overlay.get_node_or_null("SettingsModal")
	var apple_btn := settings_modal.find_child("SignInWithAppleBtn", true, false) as Button
	check(apple_btn != null, "SignInWithAppleBtn exists in settings")
	var google_btn := settings_modal.find_child("SignInWithGoogleBtn", true, false) as Button
	check(google_btn != null, "SignInWithGoogleBtn exists in settings")

	# Test Apple sign in linking
	SpiritAuth.simulate_mode = true
	apple_btn.emit_signal("pressed")
	await process_frame
	check(SpiritSave.is_cloud_linked(game.profile), "account is cloud linked after pressing SignInWithAppleBtn")
	check(SpiritSave.account_provider(game.profile) == "apple", "account provider is apple")

	# Verify settings modal refreshed with CloudSyncBtn and SignOutBtn
	settings_modal = game.overlay.get_node_or_null("SettingsModal")
	check(settings_modal != null, "SettingsModal is open after account link")
	var cloud_sync_btn := settings_modal.find_child("CloudSyncBtn", true, false) as Button
	check(cloud_sync_btn != null, "CloudSyncBtn exists when linked")
	var sign_out_btn := settings_modal.find_child("SignOutBtn", true, false) as Button
	check(sign_out_btn != null, "SignOutBtn exists when linked")

	# Test Cloud Sync
	if cloud_sync_btn != null:
		cloud_sync_btn.emit_signal("pressed")
		await process_frame
		check(int(game.profile.account.cloud_synced_at) > 0, "cloud_synced_at timestamp updated")

	# Test Sign Out reverting to guest
	if sign_out_btn != null:
		sign_out_btn.emit_signal("pressed")
		await process_frame
		check(not SpiritSave.is_cloud_linked(game.profile), "account unlinks back to guest on SignOut")
		settings_modal = game.overlay.get_node_or_null("SettingsModal")
		check(settings_modal.find_child("SignInWithAppleBtn", true, false) != null, "SignInWithAppleBtn returns after sign out")
	SpiritAuth.simulate_mode = false

	# Account deletion (Docs/LAUNCH_READINESS.md Section 1). The guest full-profile-wipe branch
	# is deliberately NOT exercised here — it would wipe gold/unlocked/deck/relics on this
	# shared `game` instance that every later section in this file depends on; see its own
	# isolated test in test_runner.gd instead. This only covers UI wiring and the safe
	# (no-op-on-failure) cloud-linked path.
	check(settings_modal.find_child("DeleteAccountBtn", true, false) == null, "a guest sees no Delete Account option — nothing was created to delete")
	SupabaseClient.clear_session()
	game.profile.account.provider = "apple"
	game.profile.account.user_id = "test_delete_uid_do_not_have_real_session"
	# show_settings() toggles closed if a SettingsModal is already open (it still is, from
	# sign_out's own _close_settings()+show_settings() reopen above) — close it first so this
	# actually reopens fresh with the new account state instead of just closing it.
	game._close_settings()
	game.show_settings()
	await process_frame
	settings_modal = game.overlay.get_node_or_null("SettingsModal")
	var delete_account_btn := settings_modal.find_child("DeleteAccountBtn", true, false) as Button
	check(delete_account_btn != null, "a cloud-linked account sees the Delete Account option")
	if delete_account_btn != null:
		tap_button(delete_account_btn, "DeleteAccountBtn")
		await process_frame
		check(game.overlay.find_child("SettingsModal", true, false) == null, "opening the delete confirmation closes Settings first rather than stacking modals")
		var delete_modal: Node = game.overlay.find_child("DeleteAccountModal", true, false)
		check(delete_modal != null, "DeleteAccountModal opens on tap")
		if delete_modal != null:
			var delete_cancel_btn := delete_modal.find_child("DeleteAccountCancelBtn", true, false) as Button
			check(delete_cancel_btn != null, "DeleteAccountCancelBtn exists")
			if delete_cancel_btn != null:
				tap_button(delete_cancel_btn, "DeleteAccountCancelBtn")
				await process_frame
				check(game.overlay.find_child("DeleteAccountModal", true, false) == null, "cancelling closes the confirmation modal")
				check(str(game.profile.account.user_id) == "test_delete_uid_do_not_have_real_session", "cancelling the confirmation leaves the account untouched")

	game.show_delete_account_modal()
	await process_frame
	var delete_confirm_btn := game.overlay.find_child("DeleteAccountConfirmBtn", true, false) as Button
	check(delete_confirm_btn != null, "DeleteAccountConfirmBtn exists")
	if delete_confirm_btn != null:
		tap_button(delete_confirm_btn, "DeleteAccountConfirmBtn")
		await process_frame
		check(str(game.profile.account.user_id) == "test_delete_uid_do_not_have_real_session", "confirming with no real auth session (this headless test never has one) fails gracefully and leaves the account intact rather than signing out or wiping the shared profile")

	game.profile.account.provider = "guest"
	game.profile.account.user_id = ""
	# Same toggle concern as above: the failed-deletion callback (delete_account's on_done)
	# already reopened SettingsModal on failure, so close before reopening fresh here too.
	game._close_settings()
	game.show_settings()
	await process_frame
	settings_modal = game.overlay.get_node_or_null("SettingsModal")

	var settings_close := settings_modal.find_child("SettingsCloseBtn", true, false) as Button
	check(settings_close != null, "SettingsCloseBtn exists")
	var open_auth_btn := settings_modal.find_child("OpenAuthModalBtn", true, false) as Button
	check(open_auth_btn != null, "OpenAuthModalBtn exists in settings for unlinked account")
	var replay_intro_setting_btn := settings_modal.find_child("ReplayIntroBtn", true, false) as Button
	check(replay_intro_setting_btn != null, "ReplayIntroBtn exists in settings")
	settings_close.emit_signal("pressed")
	await process_frame
	check(game.overlay.get_node_or_null("SettingsModal") == null, "closing SettingsModal frees it")

	# Auth Modal Interaction & Tab Switching Smoke Tests
	game.show_auth_modal()
	await process_frame
	var auth_modal: Node = game.overlay.get_node_or_null("AuthModal")
	check(auth_modal != null, "show_auth_modal opens AuthModal on overlay")
	var auth_close := auth_modal.find_child("AuthCloseBtn", true, false) as Button
	check(auth_close != null, "AuthCloseBtn exists in AuthModal")
	var auth_tab_login := auth_modal.find_child("AuthTabLogin", true, false) as Button
	check(auth_tab_login != null, "AuthTabLogin exists in AuthModal")
	var auth_tab_signup := auth_modal.find_child("AuthTabSignup", true, false) as Button
	check(auth_tab_signup != null, "AuthTabSignup exists in AuthModal")
	var auth_email := auth_modal.find_child("AuthEmailInput", true, false) as LineEdit
	check(auth_email != null, "AuthEmailInput exists in AuthModal")
	var auth_pass := auth_modal.find_child("AuthPasswordInput", true, false) as LineEdit
	check(auth_pass != null, "AuthPasswordInput exists in AuthModal")
	var auth_name := auth_modal.find_child("AuthNameInput", true, false) as LineEdit
	check(auth_name != null, "AuthNameInput exists in AuthModal")
	check(not auth_name.visible, "AuthNameInput is hidden initially in login tab")
	var auth_submit := auth_modal.find_child("AuthSubmitBtn", true, false) as Button
	check(auth_submit != null, "AuthSubmitBtn exists in AuthModal")
	check(auth_modal.find_child("AuthAppleBtn", true, false) != null, "AuthAppleBtn exists in AuthModal")
	check(auth_modal.find_child("AuthGoogleBtn", true, false) != null, "AuthGoogleBtn exists in AuthModal")
	check(auth_modal.find_child("AuthForgotBtn", true, false) != null, "AuthForgotBtn exists in AuthModal")

	# Switch to signup tab
	auth_tab_signup.emit_signal("pressed")
	await process_frame
	check(auth_name.visible, "AuthNameInput becomes visible in signup mode")

	# Switch back to login tab
	auth_tab_login.emit_signal("pressed")
	await process_frame
	check(not auth_name.visible, "AuthNameInput hides when switched back to login mode")

	# Test Apple and Google OAuth button presses in AuthModal (using simulate_mode for test harness)
	SpiritAuth.simulate_mode = true
	var auth_apple_btn := auth_modal.find_child("AuthAppleBtn", true, false) as Button
	check(auth_apple_btn != null, "AuthAppleBtn exists in AuthModal")
	if auth_apple_btn != null:
		auth_apple_btn.emit_signal("pressed")
		await process_frame
		check(game.profile.account.provider == "apple", "pressing AuthAppleBtn links profile to apple")
		check(SpiritSave.is_cloud_linked(game.profile), "pressing AuthAppleBtn sets is_cloud_linked to true")
		check(game.overlay.get_node_or_null("AuthModal") == null, "pressing AuthAppleBtn closes AuthModal")

	# Re-open AuthModal to test AuthGoogleBtn
	game.show_auth_modal()
	await process_frame
	var auth_modal2: Node = game.overlay.get_node_or_null("AuthModal")
	check(auth_modal2 != null, "show_auth_modal re-opens AuthModal")
	var auth_google_btn := auth_modal2.find_child("AuthGoogleBtn", true, false) as Button
	check(auth_google_btn != null, "AuthGoogleBtn exists in AuthModal")
	if auth_google_btn != null:
		auth_google_btn.emit_signal("pressed")
		await process_frame
		check(game.profile.account.provider == "google", "pressing AuthGoogleBtn links profile to google")
		check(SpiritSave.is_cloud_linked(game.profile), "pressing AuthGoogleBtn sets is_cloud_linked to true")
		check(game.overlay.get_node_or_null("AuthModal") == null, "pressing AuthGoogleBtn closes AuthModal")
	SpiritAuth.simulate_mode = false

	# Reset account to guest for subsequent smoke tests
	game.profile.account.provider = "guest"
	game.profile.account.user_id = ""

	# Intro Cutscene & Skip Button Smoke Tests
	var intro_done := [false]
	var cutscene: IntroCutscene = game.play_intro_cutscene(func(): intro_done[0] = true)
	await process_frame
	check(cutscene != null and game.get_node_or_null("IntroCutscene") != null, "play_intro_cutscene adds IntroCutscene to scene")
	var intro_skip_btn := cutscene.find_child("IntroSkipBtn", true, false) as Button
	check(intro_skip_btn != null, "IntroSkipBtn exists on IntroCutscene")
	intro_skip_btn.emit_signal("pressed")
	var wait_steps := 0
	while wait_steps < 35 and not intro_done[0]:
		await process_frame
		wait_steps += 1
	await process_frame
	check(intro_done[0], "pressing IntroSkipBtn completes intro and triggers callback")
	check(game.get_node_or_null("IntroCutscene") == null, "IntroCutscene is freed after completion")

	# F3: Deck builder filter chips and search
	game.show_deck()
	await process_frame
	check(game.root.find_child("DeckSearchInput", true, false) != null, "DeckSearchInput exists in deck screen")
	check(game.root.find_child("DeckKindChips", true, false) != null, "DeckKindChips exists in deck screen")
	check(game.root.find_child("DeckElementChips", true, false) != null, "DeckElementChips exists in deck screen")

	# F4: Colorblind status glyphs
	game.begin_battle(0)
	game.combat.state.enemies[0].burn = 3
	game.combat.state.enemies[0].poison = 2
	game.combat.state.enemies[0].vulnerable = 1
	game.combat.state.enemies[0].weak = 1
	game.show_battle()
	await process_frame
	check(_find_label_containing(game.root, "▲"), "Burn status chip renders with upward triangle glyph")
	check(_find_label_containing(game.root, "◆"), "Poison status chip renders with diamond glyph")
	check(_find_label_containing(game.root, "▼"), "Vulnerable status chip renders with downward triangle glyph")
	check(_find_label_containing(game.root, "●"), "Weak status chip renders with circle glyph")

	# A3: Victory performance recap card
	game.current_stage = 1
	game.combat.state.phase = "won"
	game.combat.state.stats = {"damage_dealt": 48, "cards_played": 6, "shield_gained": 12}
	game.show_reward_details()
	await process_frame
	check(game.root.find_child("VictoryRecapCard", true, false) != null, "VictoryRecapCard renders for early victory stages")

	# Battle Log: a structured, replayable record of everything combat.gd's `event` signal
	# fired during the fight, recorded by a separate listener (battle_log.gd) alongside
	# game_battle_screen.gd's own animation dispatcher — reachable via the reward screen's
	# "View Battle Log" button.
	game.begin_battle(0)
	await process_frame
	check(game.battle_log != null, "begin_battle() creates a fresh battle_log")
	check(game.battle_log.entries.is_empty(), "a fresh battle_log starts empty before any event fires")
	game._attempt_play_card(0, -1)
	await process_frame
	check(not game.battle_log.entries.is_empty(), "playing a card records at least one battle_log entry")
	var found_card_entry := false
	for entry in game.battle_log.entries:
		if str(entry.get("kind", "")) == "card": found_card_entry = true
	check(found_card_entry, "a played card is recorded with kind 'card'")
	# Let any in-flight hit/impact animation the card triggered finish before _clear()ing the
	# battle scene out from under it — same "previously freed" race this suite's own earlier
	# sections already documented for exactly this reason.
	var log_wait := 0.0
	while game.resolving and log_wait < 8.0:
		await create_timer(0.1).timeout
		log_wait += 0.1
	game.combat.state.phase = "won"
	game.show_reward_details()
	await process_frame
	check(game.root.find_child("ViewBattleLogBtn", true, false) != null, "View Battle Log button appears once the log has entries")
	game.show_battle_log()
	await process_frame
	check(game.root.find_child("BattleLogList", true, false) != null, "battle log screen renders its entry list")
	check(_find_label_containing(game.root, game.content.ui("ui.battle_log_title", game.lang)), "battle log screen shows its title")

	# D2 (revised): a cleared stage can never be re-entered at all — tapping its pin shows a
	# purely informational prompt (Cultivate/Tune Deck/Phantom Arena shortcuts), with no button
	# anywhere that actually starts a battle against it.
	game.profile.unlocked = 5
	check(game._is_replay(2), "stage 2, below the unlock frontier, is recognized as already cleared")
	game._show_replay_mode_prompt(2)
	await process_frame
	var purified_modal: Node = game.overlay.get_node_or_null("ReplayModal")
	check(purified_modal != null, "the cleared-stage prompt opens")
	check(purified_modal.find_child("ReplayNormalBtn", true, false) == null, "no way to re-fight a cleared stage at standard rewards")
	check(purified_modal.find_child("ReplayHardBtn", true, false) == null, "no way to re-fight a cleared stage at hard difficulty either")
	check(purified_modal.find_child("PurifiedCultivateBtn", true, false) != null, "PurifiedCultivateBtn shortcut exists in the cleared-stage prompt")
	check(purified_modal.find_child("PurifiedDeckBtn", true, false) != null, "PurifiedDeckBtn shortcut exists in the cleared-stage prompt")
	var phantom_shortcut: Button = purified_modal.find_child("PurifiedPhantomBtn", true, false) as Button
	check(phantom_shortcut != null, "PurifiedPhantomBtn shortcut exists in the cleared-stage prompt")
	phantom_shortcut.pressed.emit()
	await process_frame
	check(game.in_phantom_arena, "the Phantom Arena shortcut actually starts a phantom arena battle instead of re-fighting the cleared stage")
	game.combat.state.phase = "lost"
	game._leave_battle()
	check(not game.in_phantom_arena, "leaving the phantom arena battle cleans up its state")

	section("== visual assets: logo, removed subtitle & card illustrations ==")
	game.show_map()
	await process_frame
	var logo_node: Node = game.root.find_child("SpiritboundLogo", true, false)
	check(logo_node != null and (logo_node as TextureRect).texture != null, "map header renders SpiritboundLogo texture")
	check(not _find_text(game.root, game.content.ui("ui.choose_dest", game.lang)), "map header does not display removed choose_dest subtitle")
	check(game.root.find_child("HeaderStatsBox", true, false) == null, "map header does not show the HP stats box")
	var gold_row_node: Node = game.root.find_child("HeaderGoldRow", true, false)
	check(gold_row_node != null, "map header renders a gold row")
	var logo_stack_node: Node = game.root.find_child("HeaderLogoStack", true, false)
	check(logo_stack_node != null and logo_stack_node.get_child_count() == 2 and logo_stack_node.get_child(0) == logo_node and logo_stack_node.get_child(1) == gold_row_node, "gold sits directly below the logo, left-aligned")
	var all_cards_have_art := true
	for card in game.content.cards:
		var tex: Texture2D = game._get_card_texture(card.id)
		if tex == null:
			all_cards_have_art = false
			print("  Missing art for card: %s" % card.id)
	check(all_cards_have_art, "every single card in core.json has dedicated non-null art")

	section("== researched features: season pass, deck codes & spirit draft arena ==")
	# 1. Season Pass in Quests
	game.show_quests()
	await process_frame
	var sp_banner: Node = game.root.find_child("SeasonPassBanner", true, false)
	check(sp_banner != null, "SeasonPassBanner renders in quests screen")
	var sp_view_btn: Node = game.root.find_child("SeasonPassViewBtn", true, false)
	check(sp_view_btn != null, "SeasonPassViewBtn exists on banner")
	game.show_season_pass()
	await process_frame
	var claim_all_btn: Node = game.root.find_child("SeasonPassClaimAllBtn", true, false)
	check(claim_all_btn != null, "SeasonPassClaimAllBtn renders in season pass screen")
	# LAUNCH_READINESS Section 2: the premium track must not be free. A brand-new profile gets
	# is_premium == false, so the premium rows are locked until a verified purchase / restore.
	# Assert against the schema default, not game.profile: this harness reuses a persisted
	# on-disk save, so game.profile can legitimately still carry an old is_premium:true.
	var fresh_prof: Dictionary = SpiritSave.defaults(game.content)
	var fresh_sp: Dictionary = fresh_prof.get("season_pass", {})
	check(not bool(fresh_sp.get("is_premium", false)), "a fresh profile's premium track is not pre-unlocked")
	# LAUNCH_READINESS Section 3: first_seen_day must be stamped at launch or the day2/day7
	# return funnel can never compute an offset.
	check(fresh_prof.has("first_seen_day"), "save schema carries first_seen_day for the return funnel")
	check(game.root.find_child("SeasonPassTier_1", true, false) != null, "SeasonPassTier_1 renders")
	check(game.root.find_child("SeasonPassTier_20", true, false) != null, "SeasonPassTier_20 renders")

	# LAUNCH_READINESS Section 2: while the premium track is locked the player must have both a
	# way to buy it and a way to restore a previous purchase (Apple checks for Restore Purchases
	# on any app with non-consumable purchases). Force the locked state first — this harness
	# reuses a persisted on-disk save, so game.profile may still carry a pre-Section-2
	# is_premium:true — then re-render and assert. The buttons are deliberately NOT clicked here:
	# with a billing provider wired a click could open a real platform purchase sheet, which a
	# headless suite must never do. The gate's actual behavior (an absent or unverified purchase
	# grants nothing, restore re-derives, a refund revokes) is asserted in test_runner.gd.
	var prev_premium: bool = bool(game.profile.season_pass.get("is_premium", false))
	game.profile.season_pass.is_premium = false
	game.show_season_pass()
	await process_frame
	check(game.root.find_child("SeasonPassBuyBtn", true, false) != null, "SeasonPassBuyBtn renders while the premium track is locked")
	check(game.root.find_child("SeasonPassRestoreBtn", true, false) != null, "SeasonPassRestoreBtn renders (Restore Purchases entry point)")
	var premium_rows_locked := true
	for tier_idx in range(1, 21):
		if game.root.find_child("ClaimPremTierBtn_%d" % tier_idx, true, false) != null:
			premium_rows_locked = false
	check(premium_rows_locked, "no premium-tier Claim button renders while the account has not bought the pass")
	game.profile.season_pass.is_premium = prev_premium
	game.show_season_pass()
	await process_frame

	# 2. Deck Code Export & Import
	game.show_deck()
	await process_frame
	var export_btn: Node = game.root.find_child("DeckExportBtn", true, false)
	var import_btn: Node = game.root.find_child("DeckImportBtn", true, false)
	check(export_btn != null and import_btn != null, "DeckExportBtn and DeckImportBtn exist in deck screen")
	(export_btn as Button).pressed.emit()
	await process_frame
	var clip_deck: String = game._clipboard_get()
	check(clip_deck.begins_with("SPB1:"), "export deck code copies SPB1: prefixed code to clipboard")
	(import_btn as Button).pressed.emit()
	await process_frame
	var import_modal: Node = game.overlay.find_child("DeckImportModal", true, false)
	check(import_modal != null, "DeckImportModal dialog opens on overlay")
	var code_input: LineEdit = game.overlay.find_child("DeckCodeInput", true, false)
	if code_input and code_input.text.is_empty():
		code_input.text = clip_deck
	var confirm_import_btn: Node = game.overlay.find_child("DeckImportConfirmBtn", true, false)
	check(confirm_import_btn != null, "DeckImportConfirmBtn exists in import dialog")
	(confirm_import_btn as Button).pressed.emit()
	await process_frame
	check(game.overlay.find_child("DeckImportModal", true, false) == null, "DeckImportModal closes after successful import")

	# Regression check for a real validation gap found this session: the size check on import
	# only required >= 15 cards, not exactly 25 — the same screen's own manual _confirm_deck()
	# refuses anything but exactly 25 (deck.size() != 25), so a hand-crafted or malformed
	# shared deck code (codes are unsigned base64 JSON, trivial to edit) could silently install
	# a 15-24 or 26+ card deck, bypassing that invariant entirely since import writes
	# profile.deck directly without ever going through _confirm_deck()'s own gate.
	game.profile.collection["strike"] = 100
	var deck_before_bad_size: Array = game.profile.deck.duplicate()
	var bad_size_deck_20: Array = []
	for i in 20: bad_size_deck_20.append("strike")
	var short_code: String = "SPB1:%s" % Marshalls.utf8_to_base64(JSON.stringify(bad_size_deck_20))
	game.show_deck()
	await process_frame
	(game.root.find_child("DeckImportBtn", true, false) as Button).pressed.emit()
	await process_frame
	(game.overlay.find_child("DeckCodeInput", true, false) as LineEdit).text = short_code
	(game.overlay.find_child("DeckImportConfirmBtn", true, false) as Button).pressed.emit()
	await process_frame
	check(game.overlay.find_child("DeckImportModal", true, false) != null, "a 20-card deck code is rejected (wrong size), import modal stays open")
	check(game.profile.deck == deck_before_bad_size, "a rejected undersized deck code does not change profile.deck")

	var bad_size_deck_30: Array = []
	for i in 30: bad_size_deck_30.append("strike")
	var long_code: String = "SPB1:%s" % Marshalls.utf8_to_base64(JSON.stringify(bad_size_deck_30))
	(game.overlay.find_child("DeckCodeInput", true, false) as LineEdit).text = long_code
	(game.overlay.find_child("DeckImportConfirmBtn", true, false) as Button).pressed.emit()
	await process_frame
	check(game.overlay.find_child("DeckImportModal", true, false) != null, "a 30-card deck code is rejected (wrong size), import modal stays open")
	check(game.profile.deck == deck_before_bad_size, "a rejected oversized deck code does not change profile.deck")
	var stale_import_modal: Node = game.overlay.get_node_or_null("DeckImportModal")
	if stale_import_modal: stale_import_modal.queue_free()
	await process_frame

	# 3. Spirit Draft Arena
	game.show_challenges()
	await process_frame
	var draft_sec: Node = game.root.find_child("DraftArenaSection", true, false)
	check(draft_sec != null, "DraftArenaSection renders in challenges screen")
	var draft_enter_btn: Node = game.root.find_child("DraftArenaEnterBtn", true, false)
	check(draft_enter_btn != null, "DraftArenaEnterBtn exists in draft section")
	game.show_spirit_draft()
	await process_frame
	var current_pool: Array = game.profile.get("draft_arena", {}).get("current_pool", [])
	check(current_pool.size() == 3, "spirit draft presents 3 card choices in pick phase")
	var first_card_id: String = str(current_pool[0])
	var pick_btn: Node = game.root.find_child("DraftPickBtn_" + first_card_id, true, false)
	check(pick_btn != null, "DraftPickBtn exists for first offered card choice")
	(pick_btn as Button).pressed.emit()
	await process_frame
	var draft_deck: Array = game.profile.get("draft_arena", {}).get("deck", [])
	check(draft_deck.has(first_card_id), "picked card is added to arena draft deck")
	check(int(game.profile.draft_arena.round) == 2, "draft round advances to 2 after pick")

	# Fast-forward past the remaining picks (one real pick already proved above) to a
	# battle-ready 15-card deck, the same shape _pick_draft_card() leaves after round 7.
	while draft_deck.size() < 15:
		draft_deck.append(first_card_id)
	game.profile.draft_arena.deck = draft_deck
	game.profile.draft_arena.round = 8
	game.profile.draft_arena.active = true
	game.profile.draft_arena.current_pool = []
	game.show_spirit_draft()
	await process_frame
	var draft_start_btn: Node = game.root.find_child("DraftStartBattleBtn", true, false)
	check(draft_start_btn != null, "a battle-ready draft run shows DraftStartBattleBtn")
	(draft_start_btn as Button).pressed.emit()
	await process_frame
	check(game.in_draft_battle, "DraftStartBattleBtn starts a draft battle")
	var draft_battle_cards: int = game.combat.state.draw.size() + game.combat.state.hand.size() + game.combat.state.discard.size() + game.combat.state.exhaust.size()
	check(draft_battle_cards == 15, "a draft battle is built from the 15-card draft deck, not the real campaign deck")

	# The bug this session found: _leave_battle() had no in_draft_battle branch at all, so a
	# loss or retreat left the flag stuck true forever, silently swapping every later battle's
	# deck (campaign battles included) for this stale 15-card draft deck. Confirm a loss
	# clears the flag and increments losses, and that a subsequent ordinary campaign battle
	# is unaffected.
	game.combat.state.phase = "lost"
	game._leave_battle()
	check(not game.in_draft_battle, "_leave_battle clears in_draft_battle on a loss")
	check(int(game.profile.draft_arena.losses) == 1, "a loss increments the draft run's loss count")
	game.begin_battle(0)
	await process_frame
	var normal_battle_cards: int = game.combat.state.draw.size() + game.combat.state.hand.size() + game.combat.state.discard.size() + game.combat.state.exhaust.size()
	check(normal_battle_cards == game.profile.deck.size(), "a stuck in_draft_battle flag no longer corrupts an ordinary campaign battle's deck after a draft loss")
	game._leave_battle()

	# Losing SpiritContent.DRAFT_LOSS_CAP times in a row ends the run and resets it exactly
	# like _abandon_draft() does (round/deck/current_pool/wins/losses all back to their fresh
	# shape) via the shared g._reset_draft_run() helper, so the next run starts clean instead
	# of inheriting a "round 8, deck already has 15 cards" leftover from the run that just
	# ended — the second corruption bug this session found and fixed.
	game.profile.draft_arena.deck = draft_deck.duplicate()
	game.profile.draft_arena.round = 8
	game.profile.draft_arena.active = true
	game.profile.draft_arena.losses = 0
	SpiritSave.write(game.profile)
	for i in range(SpiritContent.DRAFT_LOSS_CAP):
		game.in_draft_battle = true
		game.begin_battle(0)
		game.combat.state.phase = "lost"
		game._leave_battle()
	check(not game.in_draft_battle, "in_draft_battle is clear after the run-ending loss")
	check(int(game.profile.draft_arena.losses) == 0, "reaching DRAFT_LOSS_CAP resets losses back to 0 for the next run")
	check(not bool(game.profile.draft_arena.active), "reaching DRAFT_LOSS_CAP ends the run (active resets to false)")
	check(int(game.profile.draft_arena.round) == 1, "reaching DRAFT_LOSS_CAP resets round back to 1 for the next run")
	check(game.profile.draft_arena.deck.is_empty(), "reaching DRAFT_LOSS_CAP resets the deck so the next run starts from the 8-card starter shape")

	# Winning SpiritContent.DRAFT_WIN_CAP times must reset the same fields — before this
	# session's fix, the Grand Champion ending only set active=false and left round/deck/
	# current_pool stale, corrupting the next run started right after a win.
	game.profile.draft_arena.deck = draft_deck.duplicate()
	game.profile.draft_arena.round = 8
	game.profile.draft_arena.active = true
	game.profile.draft_arena.wins = SpiritContent.DRAFT_WIN_CAP - 1
	game.profile.draft_arena.losses = 0
	SpiritSave.write(game.profile)
	game.in_draft_battle = true
	game.begin_battle(0)
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(not game.in_draft_battle, "_grant_stage_rewards clears in_draft_battle after the win that hits DRAFT_WIN_CAP")
	check(not bool(game.profile.draft_arena.active), "reaching DRAFT_WIN_CAP ends the run (active resets to false)")
	check(int(game.profile.draft_arena.wins) == 0, "reaching DRAFT_WIN_CAP resets wins back to 0 for the next run")
	check(int(game.profile.draft_arena.round) == 1, "reaching DRAFT_WIN_CAP resets round back to 1 for the next run")
	check(game.profile.draft_arena.deck.is_empty(), "reaching DRAFT_WIN_CAP resets the deck for the next run")

	# Regression check for a separate, smaller bug found in the same audit: 4 labels in the
	# draft pick/battle-ready screens were hardcoded Chinese-only literals (AGENTS.md rule 2
	# violation) instead of going through UI_TEXT — silently un-translated for an English
	# player. Moved to ui.draft_card_cost_fmt/draft_deck_progress_fmt/draft_deck_label/
	# draft_next_opponent_fmt; confirm the English text actually renders now.
	game._change_language("en")
	game.profile.draft_arena.deck = draft_deck.duplicate()
	game.profile.draft_arena.round = 1
	game.profile.draft_arena.active = false
	game.profile.draft_arena.current_pool = []
	SpiritSave.write(game.profile)
	game.show_spirit_draft()
	await process_frame
	var en_pool: Array = game.profile.draft_arena.current_pool
	var en_card: Dictionary = game.content.card(str(en_pool[0]))
	var en_cost_label: String = game.content.ui("ui.draft_card_cost_fmt", "en") % [game.content.text(en_card.nameKey, "en"), int(en_card.cost)]
	check(_find_label_text(game.root, en_cost_label), "draft pick tile's cost label is in English, not hardcoded Chinese")
	var en_deck: Array = game.profile.draft_arena.deck
	var en_progress_label: String = game.content.ui("ui.draft_deck_progress_fmt", "en") % [en_deck.size(), ", ".join(en_deck)]
	check(_find_label_text(game.root, en_progress_label), "draft deck-progress label is in English")
	game.profile.draft_arena.round = 8
	game.profile.draft_arena.active = true
	SpiritSave.write(game.profile)
	game.show_spirit_draft()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.draft_deck_label", "en")), "draft battle-ready deck label is in English")
	var en_start_btn: Button = game.root.find_child("DraftStartBattleBtn", true, false) as Button
	check(en_start_btn != null and "Face Spirit Opponent" in en_start_btn.text, "draft next-opponent button is in English")
	game._change_language("zh-Hans")
	await process_frame

	section("== visual assets: painted challenge banners & card back ==")
	game.show_quests()
	await process_frame
	var sp_banner_node: Node = game.root.find_child("SeasonPassBanner", true, false)
	check(sp_banner_node != null, "SeasonPassBanner renders in quests screen")
	var sp_bg: TextureRect = sp_banner_node.find_child("BannerBg", true, false) as TextureRect
	check(sp_bg != null and sp_bg.texture != null, "SeasonPassBanner has BannerBg with valid texture")
	check(sp_bg != null and sp_bg.mouse_filter == Control.MOUSE_FILTER_IGNORE, "SeasonPassBanner BannerBg ignores mouse events")
	check(sp_bg != null and str(sp_bg.texture.resource_path).ends_with("banner_season_pass.png"), "SeasonPassBanner uses banner_season_pass.png")

	game.profile.unlocked = 15
	game.profile.daily_trial_record.stage = 0
	game.profile.weekly_challenge_record.stage = 0
	game.show_challenges()
	await process_frame
	var banner_checks: Array = [
		{"btn": "DraftArenaEnterBtn", "tex": "banner_draft_arena.png", "desc": "Draft Arena"},
		{"btn": "DailyTrialEnterBtn", "tex": "banner_daily_trial.png", "desc": "Daily Trial"},
		{"btn": "WeeklyChallengeEnterBtn", "tex": "banner_weekly_challenge.png", "desc": "Weekly Challenge"},
		{"btn": "BossRushEnterBtn", "tex": "banner_boss_rush.png", "desc": "Boss Rush"},
		{"btn": "SandboxEnterBtn", "tex": "banner_sandbox.png", "desc": "Sandbox"},
		{"btn": "AbyssEnterBtn", "tex": "banner_abyss.png", "desc": "Abyss"},
	]
	for bc in banner_checks:
		var btn: Control = game.root.find_child(bc.btn, true, false) as Control
		check(btn != null, "%s enter button exists" % bc.desc)
		if btn != null:
			var p: Node = btn.get_parent()
			var card_bg: TextureRect = null
			while p != null and card_bg == null:
				card_bg = p.find_child("BannerBg", false, false) as TextureRect
				p = p.get_parent()
			check(card_bg != null and card_bg.texture != null, "%s card has BannerBg texture" % bc.desc)
			check(card_bg != null and card_bg.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s BannerBg ignores mouse filter" % bc.desc)
			check(card_bg != null and str(card_bg.texture.resource_path).ends_with(bc.tex), "%s BannerBg uses %s" % [bc.desc, bc.tex])
			var scroll: ScrollContainer = _find_by_script(game.root, TouchScrollContainer) as ScrollContainer
			if scroll != null:
				scroll.ensure_control_visible(btn)
				await process_frame
			check_clickable(btn, "%s enter button" % bc.desc)

	var card_back: Texture2D = game._get_card_back_texture()
	check(card_back != null, "default card back texture is available via _get_card_back_texture")

	section("== occlusion detection mechanism (synthetic, controlled) ==")
	# The real-screen checks below only ever exercise whatever overlap happens to exist in
	# today's layout — if a future redesign removes that incidental overlap, those checks
	# would go on passing without actually testing anything. This constructs the exact
	# geometry of the original bug directly (two fully-overlapping STOP-filtered buttons,
	# added in a controlled order) so the detection mechanism itself — and the fix
	# (move_child to reorder) — stay proven regardless of what any real screen looks like.
	var victim := Button.new()
	victim.name = "SyntheticVictim"
	victim.position = Vector2(20, 20)
	victim.size = Vector2(40, 40)
	victim.mouse_filter = Control.MOUSE_FILTER_STOP
	game.root.add_child(victim)
	var occluder := Button.new()
	occluder.name = "SyntheticOccluder"
	occluder.position = Vector2(20, 20)
	occluder.size = Vector2(40, 40)
	occluder.mouse_filter = Control.MOUSE_FILTER_STOP
	game.root.add_child(occluder)
	await process_frame

	check(_wins_input_over(occluder, victim), "a later-added sibling wins input priority with no z_index difference (plain tree order)")
	victim.z_index = 600
	check(_wins_input_over(occluder, victim), "a later-added sibling STILL wins input priority even against a much higher z_index — this is the exact assumption the original buggy occlusion check got backwards")
	check(not find_occlusion(victim).is_empty(), "find_occlusion correctly flags the high-z_index victim as blocked by the later, input-priority-winning sibling")

	game.root.move_child(victim, game.root.get_child_count() - 1)
	check(find_occlusion(victim).is_empty(), "moving the victim to be root's last child (the actual production fix) resolves the occlusion, proving the fix mechanism itself, not just the detection")

	victim.queue_free()
	occluder.queue_free()
	await process_frame

	section("== UI Clickability & Occlusion Suite ==")
	# 1. Map Header Buttons (Quest, Camp, Settings)
	game.show_map()
	await process_frame
	await process_frame
	var chk_quest_btn: Control = game.root.find_child("QuestButton", true, false) as Control
	check_clickable(chk_quest_btn, "Map QuestButton")
	var chk_camp_btn: Control = game.root.find_child("CampButton", true, false) as Control
	check_clickable(chk_camp_btn, "Map CampButton")
	var chk_settings_btn: Control = game.root.find_child("SettingsButton", true, false) as Control
	check_clickable(chk_settings_btn, "Map SettingsButton")

	# Test tapping QuestButton
	tap_button(chk_quest_btn, "Map QuestButton")
	await process_frame
	check(game.root.find_child("SeasonPassBanner", true, false) != null, "QuestButton click opens Quests screen")

	# Test tapping CampButton
	game.camp_tab = "character"
	game.show_map()
	await process_frame
	chk_camp_btn = game.root.find_child("CampButton", true, false) as Control
	tap_button(chk_camp_btn, "Map CampButton")
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.camp_title", game.lang)), "CampButton click opens Camp screen")

	# Test tapping SettingsButton
	game.show_map()
	await process_frame
	chk_settings_btn = game.root.find_child("SettingsButton", true, false) as Control
	tap_button(chk_settings_btn, "Map SettingsButton")
	await process_frame
	check(game.overlay.find_child("SettingsModal", true, false) != null, "SettingsButton click opens SettingsModal")
	# The actual mechanism the occlusion checks below depend on: z_index never affects Godot's
	# GUI input dispatch, only scene-tree sibling order does, so overlay has to be root's LAST
	# child for a modal inside it to win input priority over the screen underneath — a modal
	# opening on any screen where overlay isn't already last (which is every screen, since
	# _clear() adds overlay before that screen's own content) must move it there itself.
	check(game.overlay.get_index() == game.root.get_child_count() - 1, "opening a modal moves overlay to be root's last child, so it wins input priority over the screen underneath")

	# Inside SettingsModal: check all interactive buttons
	var chk_settings_modal: Node = game.overlay.find_child("SettingsModal", true, false)
	if chk_settings_modal != null:
		_sweep_buttons_clickable(chk_settings_modal, "SettingsModal")
		var chk_close_btn: Control = chk_settings_modal.find_child("SettingsCloseBtn", true, false) as Control
		check_clickable(chk_close_btn, "SettingsCloseBtn")
		var chk_motion_toggle: Control = chk_settings_modal.find_child("ReduceMotionToggleBtn", true, false) as Control
		check_clickable(chk_motion_toggle, "ReduceMotionToggleBtn")
		var chk_apple_login: Control = chk_settings_modal.find_child("SignInWithAppleBtn", true, false) as Control
		check_clickable(chk_apple_login, "SignInWithAppleBtn in Settings")
		tap_button(chk_close_btn, "SettingsCloseBtn")
		await process_frame
		check(game.overlay.find_child("SettingsModal", true, false) == null, "SettingsCloseBtn click dismisses modal")

	# 2. Cleared-Stage Prompt Clickability (no ReplayNormalBtn/ReplayHardBtn — a cleared stage
	# can no longer be re-fought at all, see the D2 section above)
	game._show_replay_mode_prompt(0)
	await process_frame
	var chk_replay_modal: Node = game.overlay.find_child("ReplayModal", true, false)
	check(chk_replay_modal != null, "ReplayModal opens on stage replay prompt")
	if chk_replay_modal != null:
		_sweep_buttons_clickable(chk_replay_modal, "ReplayModal")
		var chk_replay_cultivate: Control = chk_replay_modal.find_child("PurifiedCultivateBtn", true, false) as Control
		check_clickable(chk_replay_cultivate, "PurifiedCultivateBtn")
		var chk_replay_deck: Control = chk_replay_modal.find_child("PurifiedDeckBtn", true, false) as Control
		check_clickable(chk_replay_deck, "PurifiedDeckBtn")
		var chk_replay_phantom: Control = chk_replay_modal.find_child("PurifiedPhantomBtn", true, false) as Control
		check_clickable(chk_replay_phantom, "PurifiedPhantomBtn")
		var chk_replay_close: Control = chk_replay_modal.find_child("ReplayCloseBtn", true, false) as Control
		check_clickable(chk_replay_close, "ReplayCloseBtn")
		tap_button(chk_replay_close, "ReplayCloseBtn")
		await process_frame
		check(game.overlay.find_child("ReplayModal", true, false) == null, "ReplayCloseBtn click dismisses ReplayModal")

	# Idle Harvest Modal Clickability
	game.show_idle_harvest_modal()
	await process_frame
	var chk_harvest_modal: Node = game.overlay.find_child("IdleHarvestModal", true, false)
	check(chk_harvest_modal != null, "IdleHarvestModal opens on call")
	if chk_harvest_modal != null:
		_sweep_buttons_clickable(chk_harvest_modal, "IdleHarvestModal")
		var chk_harvest_close: Control = chk_harvest_modal.find_child("IdleHarvestCloseBtn", true, false) as Control
		check_clickable(chk_harvest_close, "IdleHarvestCloseBtn")
		tap_button(chk_harvest_close, "IdleHarvestCloseBtn")
		await process_frame
		check(game.overlay.find_child("IdleHarvestModal", true, false) == null, "IdleHarvestCloseBtn click dismisses IdleHarvestModal")

	# 3. Deck Import Modal Clickability
	game.show_deck()
	await process_frame
	var chk_export_btn: Control = game.root.find_child("DeckExportBtn", true, false) as Control
	check_clickable(chk_export_btn, "DeckExportBtn")
	var chk_import_btn: Control = game.root.find_child("DeckImportBtn", true, false) as Control
	check_clickable(chk_import_btn, "DeckImportBtn")
	tap_button(chk_import_btn, "DeckImportBtn")
	await process_frame
	var chk_import_modal: Node = game.overlay.find_child("DeckImportModal", true, false)
	check(chk_import_modal != null, "DeckImportModal opens on import button tap")
	if chk_import_modal != null:
		_sweep_buttons_clickable(chk_import_modal, "DeckImportModal")
		var chk_import_confirm: Control = chk_import_modal.find_child("DeckImportConfirmBtn", true, false) as Control
		check_clickable(chk_import_confirm, "DeckImportConfirmBtn")
		var chk_import_close: Control = chk_import_modal.find_child("DeckImportCloseBtn", true, false) as Control
		check_clickable(chk_import_close, "DeckImportCloseBtn")
		tap_button(chk_import_close, "DeckImportCloseBtn")
		await process_frame
		check(game.overlay.find_child("DeckImportModal", true, false) == null, "DeckImportCloseBtn click dismisses modal")

	section("== battle entry/exit syncs the map's browsed chapter ==")
	var saved_ch_battle_sync: int = int(game.current_map_chapter)
	var saved_unlocked_battle_sync: int = int(game.profile.unlocked)
	game.profile.unlocked = maxi(saved_unlocked_battle_sync, 29)
	game.current_map_chapter = 0
	game.begin_battle(29) # stage 29 is chapter 5 (29 / 5 == 5)
	await process_frame
	check(game.current_map_chapter == 5, "entering a battle switches the map to that stage's chapter even if a different one was being browsed")
	game.combat.state.phase = "lost"
	game._leave_battle()
	await process_frame
	check(game.current_map_chapter == 5, "returning from the battle leaves the map on the stage's chapter")
	game.profile.unlocked = saved_unlocked_battle_sync
	game.current_map_chapter = saved_ch_battle_sync
	game.show_map()
	await process_frame

	section("== card draw and discard animations ==")
	game.begin_battle(0)
	await process_frame
	check(game.hand_zone != null and is_instance_valid(game.hand_zone), "hand_zone is tracked so animations can find tiles by hand_index")
	var opening_tiles: Array = game.hand_zone.get_children()
	check(opening_tiles.size() == 5, "opening hand deals 5 cards, sanity-checking the fixture")
	var last_dealt: HandCard = null
	for child in opening_tiles:
		if child is HandCard and int((child as HandCard).hand_index) == 4: last_dealt = child as HandCard
	check(last_dealt != null, "found the 5th (last-dealt) opening hand card")
	if last_dealt != null:
		check(not last_dealt.position.is_equal_approx(last_dealt.home_pos), "the last-dealt card starts away from its resting spot, mid draw-in animation")
		check(last_dealt.modulate.a < 0.9, "the last-dealt card starts faded in rather than fully opaque")
	# The 5th card is also the most staggered (stagger_index 4), so it needs the longest wait
	# of the batch to finish settling — comfortably covers every other card's shorter one too.
	await create_timer(0.75).timeout
	if last_dealt != null and is_instance_valid(last_dealt):
		check(last_dealt.position.is_equal_approx(last_dealt.home_pos), "the draw-in animation settles into the card's resting position")
		check(is_equal_approx(last_dealt.modulate.a, 1.0), "the draw-in animation fully fades the card back in")

	var play_index := 0
	var play_card: Dictionary = game.content.card(str(game.combat.state.hand[play_index].card_id))
	var play_target := -1
	if game._card_target_mode(play_card) == "enemy":
		var living: Array = game._living_enemies()
		play_target = living[0] if living.size() > 0 else -1
	game._attempt_play_card(play_index, play_target)
	var discard_tile: HandCard = null
	for child in game.hand_zone.get_children():
		if child is HandCard and int((child as HandCard).hand_index) == play_index: discard_tile = child as HandCard
	check(discard_tile != null and is_instance_valid(discard_tile), "the played card's tile is still around right after playing, ready to fly to the discard pile")
	if discard_tile != null:
		check(discard_tile.current_tween != null and discard_tile.current_tween.is_valid(), "playing a card starts a discard-fly tween on its tile")
	await create_timer(0.4).timeout
	if discard_tile != null and is_instance_valid(discard_tile):
		check(discard_tile.modulate.a < 0.5, "the discard-fly animation fades the played card out")
	var discard_resolve_wait := 0.0
	while game.resolving and discard_resolve_wait < 8.0:
		await create_timer(0.1).timeout
		discard_resolve_wait += 0.1
	check(not game.resolving, "the play resolves cleanly after the discard-fly animation")

	# A broad, name-agnostic safety net across the game's busiest screens: every visible,
	# enabled button anywhere in each of these has to be occlusion-clean, not just the
	# specific buttons other checks above remembered to name. This is what would have caught
	# the modal-tap bug even if none of the specific modals above had been individually
	# hardcoded — and is what protects any screen this suite doesn't otherwise enumerate.
	section("== multi-currency pills, immediate language switch, shop exchange, plaque & tutorials ==")
	# 1. Multi-currency pills in Header
	game.profile.gold = 350
	game.profile.spirit_jade = 25
	game.profile.spirit_dust = 80
	game.show_map()
	await process_frame
	var gold_row: BoxContainer = game.root.find_child("HeaderGoldRow", true, false) as BoxContainer
	check(gold_row != null, "HeaderGoldRow exists in header")
	if gold_row != null:
		check(gold_row.get_child_count() >= 3, "HeaderGoldRow contains pills for Gold, Jade, and Dust")
		check(_find_label_containing(gold_row, "350") != null, "Gold pill shows 350")
		check(_find_label_containing(gold_row, "25") != null, "Jade pill shows 25")
		check(_find_label_containing(gold_row, "80") != null, "Dust pill shows 80")

	# 1b. Treasury Inspector modal
	game.show_treasury_inspector()
	await process_frame
	var t_modal: Node = game.overlay.find_child("TreasuryInspectorModal", true, false)
	check(t_modal != null, "TreasuryInspectorModal opens on request")
	if t_modal != null:
		check(t_modal.find_child("TreasuryConvertDustBtn", true, false) != null, "TreasuryConvertDustBtn present")
		check(t_modal.find_child("TreasuryConvertGoldBtn", true, false) != null, "TreasuryConvertGoldBtn present")
		var t_close: Control = t_modal.find_child("TreasuryCloseBtn", true, false) as Control
		check(t_close != null, "TreasuryCloseBtn present in treasury modal")
		if t_close != null:
			tap_button(t_close, "TreasuryCloseBtn")
			await process_frame
			check(game.overlay.find_child("TreasuryInspectorModal", true, false) == null, "Treasury modal closed on close tap")

	# 1c. Celestial Leaderboard Modal
	game.show_challenges()
	await process_frame
	var lb_sec: Node = game.root.find_child("LeaderboardSection", true, false)
	check(lb_sec != null, "LeaderboardSection exists in challenges list")
	var lb_open_btn: Control = game.root.find_child("LeaderboardOpenBtn", true, false) as Control
	check(lb_open_btn != null, "LeaderboardOpenBtn exists in LeaderboardSection")
	if lb_open_btn != null:
		tap_button(lb_open_btn, "LeaderboardOpenBtn")
		await process_frame
		var lb_modal: Node = game.overlay.find_child("LeaderboardModal", true, false)
		check(lb_modal != null, "LeaderboardModal opened on tap")
		if lb_modal != null:
			var tab_daily: Control = lb_modal.find_child("LeaderboardTab_daily_trial", true, false) as Control
			var tab_samsara: Control = lb_modal.find_child("LeaderboardTab_samsara", true, false) as Control
			var tab_abyss: Control = lb_modal.find_child("LeaderboardTab_abyss", true, false) as Control
			var refresh_btn: Control = lb_modal.find_child("LeaderboardRefreshBtn", true, false) as Control
			var lb_close: Control = lb_modal.find_child("LeaderboardCloseBtn", true, false) as Control
			check(tab_daily != null, "LeaderboardTab_daily_trial exists")
			check(tab_samsara != null, "LeaderboardTab_samsara exists")
			check(tab_abyss != null, "LeaderboardTab_abyss exists")
			check(refresh_btn != null, "LeaderboardRefreshBtn exists")
			check(lb_close != null, "LeaderboardCloseBtn exists")
			if tab_daily != null:
				tap_button(tab_daily, "LeaderboardTab_daily_trial")
				await process_frame
			# E3 Part 2: Global/Friends scope toggle. Switching scope kicks off a real
			# SupabaseClient network fetch inside show_leaderboard()'s update_view closure (same
			# fire-and-forget shape the existing category tabs above already exercise without
			# awaiting the fetch itself) — only structural existence and that tapping it doesn't
			# crash are asserted here, not fetched content, since that content depends on network
			# reachability this suite can't rely on.
			var scope_global: Control = lb_modal.find_child("LeaderboardScope_global", true, false) as Control
			var scope_friends: Control = lb_modal.find_child("LeaderboardScope_friends", true, false) as Control
			check(scope_global != null, "LeaderboardScope_global toggle exists")
			check(scope_friends != null, "LeaderboardScope_friends toggle exists")
			if scope_friends != null:
				tap_button(scope_friends, "LeaderboardScope_friends")
				await process_frame
				check(lb_modal.is_inside_tree(), "switching to the Friends scope does not close or crash the leaderboard modal")
			if lb_close != null:
				tap_button(lb_close, "LeaderboardCloseBtn")
				await process_frame
				check(game.overlay.find_child("LeaderboardModal", true, false) == null, "LeaderboardModal closed on close tap")
		game.show_map()
		await process_frame

	section("== friends leaderboard management (E3 Part 2) ==")
	# All of _add_friend()/_remove_friend()/_rebuild_friends_list() (game_camp_screen.gd) are
	# purely local — no network call — unlike the leaderboard fetch above, so this can assert on
	# actual behavior deterministically instead of just structural existence.
	var saved_account_friends: Dictionary = game.profile.account.duplicate(true)
	var saved_friends_list: Array = game.profile.get("friends", []).duplicate(true)

	game.profile.account.provider = "guest"
	game.profile.account.user_id = ""
	game.profile.friends = []
	game.show_challenges()
	await process_frame
	var friends_sec: Node = game.root.find_child("FriendsSection", true, false)
	check(friends_sec != null, "FriendsSection exists in challenges list")
	var friends_open_btn: Control = game.root.find_child("FriendsManageBtn", true, false) as Control
	check(friends_open_btn != null, "FriendsManageBtn exists in FriendsSection")
	if friends_open_btn != null:
		tap_button(friends_open_btn, "FriendsManageBtn")
		await process_frame
		var f_modal: Node = game.overlay.find_child("FriendsModal", true, false)
		check(f_modal != null, "FriendsModal opened on tap")
		if f_modal != null:
			check(f_modal.find_child("FriendsLinkAccountBtn", true, false) != null, "a guest (not cloud-linked) sees a prompt to sign in instead of their own code")
			check(f_modal.find_child("FriendsCopyCodeBtn", true, false) == null, "a guest has no code to copy")
			check(_find_label_containing(f_modal, game.t("ui.friends_empty_list")), "an empty friends list shows its own empty-state message")
			var f_close: Control = f_modal.find_child("FriendsCloseBtn", true, false) as Control
			if f_close != null:
				tap_button(f_close, "FriendsCloseBtn")
				await process_frame
				check(game.overlay.find_child("FriendsModal", true, false) == null, "FriendsModal closed on close tap")

	# Now a cloud-linked account with a stable, shareable code.
	game.profile.account.provider = "apple"
	game.profile.account.user_id = "owner_code_123456"
	game.show_friends_modal()
	await process_frame
	var f_modal2: Node = game.overlay.find_child("FriendsModal", true, false)
	check(f_modal2 != null, "FriendsModal reopens via the game.gd delegator")
	if f_modal2 != null:
		check(f_modal2.find_child("FriendsLinkAccountBtn", true, false) == null, "a cloud-linked account has no sign-in prompt")
		var copy_btn: Control = f_modal2.find_child("FriendsCopyCodeBtn", true, false) as Control
		check(copy_btn != null, "a cloud-linked account can copy its own code")
		if copy_btn != null:
			tap_button(copy_btn, "FriendsCopyCodeBtn")
			check(game._clipboard_get() == "owner_code_123456", "copying the code puts the account's real user_id on the clipboard")

		var friend_code_input: LineEdit = f_modal2.find_child("FriendsCodeInput", true, false) as LineEdit
		var nick_input: LineEdit = f_modal2.find_child("FriendsNicknameInput", true, false) as LineEdit
		var add_btn: Control = f_modal2.find_child("FriendsAddBtn", true, false) as Control
		check(friend_code_input != null and nick_input != null and add_btn != null, "the add-friend inputs and button exist")
		if friend_code_input != null and nick_input != null and add_btn != null:
			friend_code_input.text = ""
			tap_button(add_btn, "FriendsAddBtn")
			check(_find_label_containing(game.overlay, game.t("ui.friends_add_err_empty")), "submitting an empty code surfaces an error toast")
			check(game.profile.friends.is_empty(), "an empty-code submission adds nothing")

			friend_code_input.text = "bad code!"
			tap_button(add_btn, "FriendsAddBtn")
			check(_find_label_containing(game.overlay, game.t("ui.friends_add_err_invalid")), "a code with disallowed characters is rejected")
			check(game.profile.friends.is_empty(), "an invalid-format code adds nothing")

			friend_code_input.text = "owner_code_123456"
			tap_button(add_btn, "FriendsAddBtn")
			check(_find_label_containing(game.overlay, game.t("ui.friends_add_err_self")), "a player cannot add their own code as a friend")
			check(game.profile.friends.is_empty(), "adding one's own code adds nothing")

			friend_code_input.text = "friend_code_abcdef"
			nick_input.text = "TestFriend"
			tap_button(add_btn, "FriendsAddBtn")
			check(_find_label_containing(game.overlay, game.t("ui.friends_added_toast")), "a valid new code is accepted")
			check(game.profile.friends.size() == 1 and str(game.profile.friends[0].get("user_id","")) == "friend_code_abcdef", "the accepted friend is stored with its code")
			check(friend_code_input.text.is_empty(), "the code input clears itself after a successful add")
			var remove_btn: Control = f_modal2.find_child("FriendsRemoveBtn_friend_code_abcdef", true, false) as Control
			check(remove_btn != null, "the newly added friend appears in the list with a remove button")

			friend_code_input.text = "friend_code_abcdef"
			tap_button(add_btn, "FriendsAddBtn")
			check(_find_label_containing(game.overlay, game.t("ui.friends_add_err_duplicate")), "adding the same code twice is rejected")
			check(game.profile.friends.size() == 1, "a duplicate submission does not add a second entry")

			if remove_btn != null:
				tap_button(remove_btn, "FriendsRemoveBtn_friend_code_abcdef")
				check(_find_label_containing(game.overlay, game.t("ui.friends_removed_toast")), "removing a friend surfaces a confirmation toast")
				check(game.profile.friends.is_empty(), "removing the only friend empties the list")
				check(_find_label_containing(f_modal2, game.t("ui.friends_empty_list")), "the list shows its empty-state message again after the last friend is removed")

		var f_close2: Control = f_modal2.find_child("FriendsCloseBtn", true, false) as Control
		if f_close2 != null:
			tap_button(f_close2, "FriendsCloseBtn")
			await process_frame

	game.profile.account = saved_account_friends
	game.profile.friends = saved_friends_list
	game.show_map()
	await process_frame

	section("== ghost arena: duel a leaderboard entry (E4) ==")
	# combat.gd only models deck-vs-encounter, not deck-vs-deck (see content.ghost_arena_
	# encounter()'s own comment), so this doesn't wait on show_leaderboard()'s real, async
	# SupabaseClient fetch to render a row's duel button — the same reason the leaderboard
	# section above never asserts on fetched row content either — and instead calls
	# _start_ghost_duel()/begin_ghost_arena_battle() directly, exactly like begin_phantom_arena()
	# is tested directly rather than through a tapped button.
	game.show_challenges()
	await process_frame
	var ghost_gold_before: int = int(game.profile.gold)
	game.show_leaderboard("abyss")
	await process_frame
	var ghost_lb_modal: Node = game.overlay.find_child("LeaderboardModal", true, false)
	check(ghost_lb_modal != null, "LeaderboardModal opens ahead of the ghost-duel check")
	game._start_ghost_duel("TestGhost", "sentinel", "abyss", 20)
	await process_frame
	check(game.overlay.find_child("LeaderboardModal", true, false) == null, "starting a ghost duel closes the leaderboard modal")
	check(game.in_ghost_arena, "_start_ghost_duel begins a ghost arena battle")
	check(game.ghost_arena_target.get("name","") == "TestGhost", "ghost_arena_target records the duelled entry's identity")
	check(game.combat != null and game.combat.state.enemies.size() > 0 and int(game.combat.state.enemies[0].get("max_health", 0)) > 0, "the ghost battle has a real, scaled enemy")
	check(str(game.combat.state.enemies[0].get("name","")) == "TestGhost", "the ghost battle's enemy is named after the duelled entry")
	game.combat.state.phase = "won"
	game._grant_stage_rewards()
	check(not game.in_ghost_arena, "_grant_stage_rewards clears in_ghost_arena after granting")
	check(int(game.profile.gold) > ghost_gold_before, "winning a ghost duel grants gold")

	# Loss path, mirroring the phantom-arena shortcut test's own shape (ghost_arena_target is
	# still set from the win test above, so this reuses the same synthesized ghost).
	game.begin_ghost_arena_battle()
	await process_frame
	check(game.in_ghost_arena, "begin_ghost_arena_battle() starts a ghost arena battle directly")
	game.combat.state.phase = "lost"
	game._leave_battle()
	check(not game.in_ghost_arena, "leaving the ghost arena battle cleans up its state")

	# 1d. Cultivation Meridian Modal
	game.show_camp()
	await process_frame
	var m_sec: Node = game.root.find_child("MeridianSection", true, false)
	check(m_sec != null, "MeridianSection renders in camp character tab")
	var m_open: Control = game.root.find_child("MeridianOpenBtn", true, false) as Control
	check(m_open != null, "MeridianOpenBtn exists in MeridianSection")
	if m_open != null:
		tap_button(m_open, "MeridianOpenBtn")
		await process_frame
		var m_modal: Node = game.overlay.find_child("MeridianModal", true, false)
		check(m_modal != null, "MeridianModal opened on tap")
		if m_modal != null:
			var m_tab_ren: Control = m_modal.find_child("MeridianTab_ren", true, false) as Control
			var m_tab_du: Control = m_modal.find_child("MeridianTab_du", true, false) as Control
			var m_tab_chong: Control = m_modal.find_child("MeridianTab_chong", true, false) as Control
			var m_reset: Control = m_modal.find_child("MeridianResetBtn", true, false) as Control
			var m_close: Control = m_modal.find_child("MeridianCloseBtn", true, false) as Control
			check(m_tab_ren != null, "MeridianTab_ren exists")
			check(m_tab_du != null, "MeridianTab_du exists")
			check(m_tab_chong != null, "MeridianTab_chong exists")
			check(m_reset != null, "MeridianResetBtn exists")
			check(m_close != null, "MeridianCloseBtn exists")
			if m_tab_du != null:
				tap_button(m_tab_du, "MeridianTab_du")
				await process_frame
			if m_close != null:
				tap_button(m_close, "MeridianCloseBtn")
				await process_frame
				check(game.overlay.find_child("MeridianModal", true, false) == null, "MeridianModal closed on close tap")
		game.show_map()
		await process_frame

	# 2. Lowered Chapter Plaque
	var plaque: Control = game.root.find_child("ChapterPlaque", true, false) as Control
	check(plaque != null, "ChapterPlaque exists on map")
	if plaque != null:
		check(plaque.position.y >= 70.0, "ChapterPlaque is lowered (y=%f >= 70)" % plaque.position.y)

	# 3. Immediate Language Switching
	game.lang = "zh-Hans"
	game.show_shop()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.shop_title", "zh-Hans")), "shop title starts in Chinese")
	game._change_language("en")
	await process_frame
	check(game.lang == "en", "language state switched to English")
	check(_find_label_text(game.root, game.content.ui("ui.shop_title", "en")), "shop title immediately updated to English")
	var s_modal: Node = game.overlay.find_child("SettingsModal", true, false)
	if s_modal != null:
		game._close_settings()
		await process_frame
	game._change_language("zh-Hans")
	await process_frame
	var s_modal2: Node = game.overlay.find_child("SettingsModal", true, false)
	if s_modal2 != null:
		game._close_settings()
		await process_frame

	# 4. Shop Tabs, Exchange, Specialties & Tutorial Dismissal
	game.shop_tab = "curated"
	game.show_shop()
	await process_frame
	check(game.root.find_child("ShopPurgeBtn", true, false) != null, "ShopPurgeBtn present in curated shop")
	check(game.root.find_child("ShopPackBtn", true, false) != null, "ShopPackBtn present in curated shop")
	check(game.root.find_child("ShopSpecialtiesShelf", true, false) != null, "ShopSpecialtiesShelf present in curated shop")

	# Currency icons: the shop's prices must use the same designed hud_gold artwork as the HUD, not
	# the ◆/✧/◈ characters that were standing in for them. A Label can't embed a texture, so any
	# price still rendered as a glyph means a label never got converted to an icon row.
	section("== shop currency icons are real art, not substitute glyphs ==")
	var shop_tile_for_icons: Control = _find_shop_tile(game.root)
	check(shop_tile_for_icons != null, "a shop card tile is present to inspect")
	if shop_tile_for_icons != null:
		check(_find_texture_rect_ending_with(shop_tile_for_icons, "hud_gold.png") != null, "the shop card tile's price shows the designed gold icon")
		var glyph_labels: Array = []
		_collect_labels_containing(shop_tile_for_icons, ["◆", "✧", "◈"], glyph_labels)
		check(glyph_labels.is_empty(), "no currency glyph stands in for the art on a shop tile (found %s)" % str(glyph_labels))

	section("== shop purchase confirmation names the wallet it charges ==")
	game.profile.gold = 0
	game.profile.spirit_jade = 100
	var pay_line_route: Dictionary = game._shop_deck_screen._resolve_payment(150, 15)
	check(str(pay_line_route.kind) == "jade", "with no gold, a gold/jade purchase routes to Spirit Jade (got %s)" % str(pay_line_route.kind))
	check(int(pay_line_route.amount) == 15, "the jade fallback charges the jade price, not the gold one")
	game.profile.gold = 500
	var pay_line_gold: Dictionary = game._shop_deck_screen._resolve_payment(150, 15)
	check(str(pay_line_gold.kind) == "gold", "with enough gold, the same purchase routes to gold (got %s)" % str(pay_line_gold.kind))
	check(game._shop_deck_screen._can_pay(150, 15), "a purchase is affordable when either wallet covers it")
	game.profile.spirit_jade = 0
	game.profile.gold = 10
	check(not game._shop_deck_screen._can_pay(150, 15), "a purchase is unaffordable when neither wallet covers it")
	game.profile.gold = 500
	game.profile.spirit_jade = 10

	section("== challenge screen is grouped into labelled bands ==")
	game.profile.unlocked = 20
	game.show_challenges()
	await process_frame
	for band in ["daily", "competitive", "endgame", "practice"]:
		check(game.root.find_child("ChallengeBand_%s" % band, true, false) != null, "challenges screen renders the '%s' band header" % band)
		check(game.root.find_child("ChallengeDock_%s" % band, true, false) != null, "the band dock offers a jump button for '%s'" % band)
	var band_texts: Array = [
		game.content.ui("ui.challenges_group_daily", game.lang),
		game.content.ui("ui.challenges_group_competitive", game.lang),
		game.content.ui("ui.challenges_group_endgame", game.lang),
		game.content.ui("ui.challenges_group_practice", game.lang),
	]
	for bt in band_texts:
		check(_find_label_text(game.root, bt), "the band title '%s' renders" % bt)
	# Every mode must still be reachable from the grouped layout — the regrouping moved children
	# around, and a section silently dropped in the process would be invisible to a check that only
	# looked at band headers.
	for btn_name in ["DailyTrialEnterBtn", "WeeklyChallengeEnterBtn", "LeaderboardOpenBtn", "FriendsManageBtn",
			"WorldEventEnterBtn", "PhantomArenaEnterBtn", "DraftArenaEnterBtn", "BossRushEnterBtn",
			"SandboxEnterBtn", "AbyssEnterBtn"]:
		check(game.root.find_child(btn_name, true, false) != null, "%s survived the challenges-screen regrouping" % btn_name)
	check(game.root.find_child("SamsaraSection", true, false) != null, "SamsaraSection survived the challenges-screen regrouping")
	# Two challenge cards reference banner art that is not in the repo at all, so they used to render
	# as flat empty rectangles next to seven painted ones. Every BannerBg must carry *some* texture,
	# and no two cards may draw the same *file* — the duplicate-banner complaint is what this guards.
	# Scans every BannerBg on the screen rather than a hardcoded list of section names: the section
	# node names aren't uniform (some panels are named, some aren't), and a name typo here would
	# silently shrink this check to nothing.
	var banner_files: Array = []
	var banner_untextured: Array = []
	for bg_tex in _all_texture_rects(game.root):
		if bg_tex.name != "BannerBg": continue
		if bg_tex.texture == null:
			banner_untextured.append(str(bg_tex.get_path()))
			continue
		banner_files.append(str(bg_tex.texture.resource_path))
	check(banner_files.size() >= 6, "the challenges screen's banner cards were actually inspected (%d found)" % banner_files.size())
	check(banner_untextured.is_empty(), "every banner card has a texture, even where the art file is absent (untextured: %s)" % str(banner_untextured))
	var dupes: Array = []
	for p in banner_files:
		if p != "" and banner_files.count(p) > 1 and p not in dupes: dupes.append(p.get_file())
	check(dupes.is_empty(), "no two challenge cards draw the same banner file (duplicated: %s)" % str(dupes))
	# The two artless cards must be exactly the two whose files are missing from the repo, and their
	# fallback must be distinct per section (procedural textures report no resource_path).
	var procedural: int = 0
	for p in banner_files:
		if p == "": procedural += 1
	check(procedural == 2, "exactly the two artless challenge cards fall back to a procedural backdrop (got %d)" % procedural)
	# A regrouping that stacks or overflows is the classic mobile-layout regression, and both are
	# invisible to a "does this button exist" check. Assert the bands actually appear in the order
	# the dock lists them, on one column, inside the 390pt viewport.
	var band_ys: Array = []
	for band in ["daily", "competitive", "endgame", "practice"]:
		var band_node: Control = game.root.find_child("ChallengeBand_%s" % band, true, false) as Control
		band_ys.append(band_node.global_position.y if band_node != null else -1.0)
	var ordered := true
	for i in range(1, band_ys.size()):
		if band_ys[i] <= band_ys[i - 1]: ordered = false
	check(ordered, "the four bands stack top-to-bottom in dock order, not interleaved (y = %s)" % str(band_ys))
	check(band_ys[0] > 0.0, "the first band has a real on-screen position (y = %.1f)" % band_ys[0])
	var widest: float = 0.0
	var widest_name := ""
	for ctrl_v in _all_controls(game.root):
		var ctrl: Control = ctrl_v
		if not ctrl.is_visible_in_tree(): continue
		if ctrl.size.x > widest:
			var p: Node = ctrl.get_parent()
			# The scrollable list is deliberately as tall/wide as its content; the check is about
			# content wider than the phone, which clips off-screen edge-to-edge.
			if p != null and (p is ScrollContainer or ctrl is ScrollContainer): continue
			widest = ctrl.size.x
			widest_name = str(ctrl.name)
	check(widest <= game.MAP_WIDTH + 1.0, "nothing on the challenges screen is wider than the viewport (%.1f pt, %s)" % [widest, widest_name])

	section("== the leaderboard entry no longer borrows the Phantom Arena's banner ==")
	# It was a _split_card_frame() on banner_phantom_arena.png, so the two neighbouring cards showed
	# the same painting. Compact panels now, with the designed nav icon doing the identifying.
	var lb_node: Node = game.root.find_child("LeaderboardSection", true, false)
	check(lb_node != null, "LeaderboardSection still renders")
	if lb_node != null:
		check(lb_node.find_child("BannerBg", true, false) == null, "the leaderboard entry no longer draws a banner background")
		check(_find_texture_rect_ending_with(lb_node, "nav_quest.png") != null, "the leaderboard entry identifies itself with the designed nav_quest icon")
	var friends_node: Node = game.root.find_child("FriendsSection", true, false)
	check(friends_node != null, "FriendsSection still renders")
	if friends_node != null:
		check(friends_node.find_child("BannerBg", true, false) == null, "the friends entry no longer draws a banner background")
		check(_find_texture_rect_ending_with(friends_node, "profile.png") != null, "the friends entry identifies itself with the designed profile icon")
	# A duplicate banner is what the report was about; Phantom Arena must now be the only card
	# loading it.
	var phantom_banner_users: int = 0
	for tex in _all_texture_rects(game.root):
		if str(tex.texture.resource_path).ends_with("banner_phantom_arena.png"): phantom_banner_users += 1
	check(phantom_banner_users == 1, "banner_phantom_arena.png is drawn by exactly one card now (got %d)" % phantom_banner_users)

	game.shop_tab = "exchange"
	game.show_shop()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.shop_recycle_card", game.lang)), "Recycle section renders in exchange tab")
	check(_find_label_text(game.root, game.content.ui("ui.shop_craft_card", game.lang)), "Craft section renders in exchange tab")
	var tut_modal: Node = game.overlay.find_child("FeatureTutorial_card_exchange", true, false)
	check(tut_modal != null, "FeatureTutorial_card_exchange modal opens when visiting exchange")
	check(bool(game.profile.tutorials_seen.get("card_exchange", false)), "card_exchange marked as seen in profile")
	var tut_ok: Control = tut_modal.find_child("TutorialUnderstoodBtn", true, false) as Control if tut_modal else null
	check(tut_ok != null, "TutorialUnderstoodBtn exists in tutorial dialog")
	if tut_ok != null:
		tap_button(tut_ok, "TutorialUnderstoodBtn")
		await process_frame
		check(game.overlay.find_child("FeatureTutorial_card_exchange", true, false) == null, "Tutorial dialog dismissed on Understood tap")

	section("== shop actions need a second tap (no one-tap spend or destroy) ==")
	# Recycling used to destroy a copy on the first clean tap. Confirm the first tap only opens a
	# dialog, that the dialog names what is at stake, and that cancelling leaves the collection
	# byte-identical — the whole point is that a mis-tap costs nothing.
	var recycle_owned_before: int = int(game.profile.collection.get("moonfang", 0))
	if recycle_owned_before == 0:
		game.profile.collection["moonfang"] = 1
		recycle_owned_before = 1
	game.profile.spirit_dust = 0
	game.shop_tab = "exchange"
	game.show_shop()
	await process_frame
	var recycle_btn: Button = game.root.find_child("RecycleBtn_moonfang", true, false) as Button
	check(recycle_btn != null, "the moonfang recycle button is reachable")
	if recycle_btn != null:
		check(_find_texture_rect_ending_with(recycle_btn, "hud_dust.png") != null, "the recycle price shows the designed dust icon, not a ✧ glyph")
		recycle_btn.emit_signal("pressed")
		await process_frame
		var rc_modal: Node = game.overlay.find_child("ShopConfirmRecycle", true, false)
		check(rc_modal != null, "tapping recycle opens a confirmation instead of recycling outright")
		check(int(game.profile.collection.get("moonfang", 0)) == recycle_owned_before, "the card copy is untouched while the confirmation is open")
		check(int(game.profile.get("spirit_dust", 0)) == 0, "no dust is credited while the confirmation is open")
		var rc_cancel: Button = rc_modal.find_child("ShopConfirmRecycleCancelBtn", true, false) as Button if rc_modal else null
		check(rc_cancel != null, "the recycle confirmation offers a cancel button")
		if rc_cancel != null:
			tap_button(rc_cancel, "ShopConfirmRecycleCancelBtn")
			await process_frame
			check(game.overlay.find_child("ShopConfirmRecycle", true, false) == null, "cancelling closes the recycle confirmation")
			check(int(game.profile.collection.get("moonfang", 0)) == recycle_owned_before, "cancelling left the collection unchanged")
			check(int(game.profile.get("spirit_dust", 0)) == 0, "cancelling credited no dust")
		if rc_modal != null and is_instance_valid(rc_modal): rc_modal.queue_free()

	# 5. Novice Journey in Quests
	game.show_quests()
	await process_frame
	check(game.root.find_child("NoviceJourneySection", true, false) != null, "NoviceJourneySection present in quests")

	game.shop_tab = "curated"
	for c in game.overlay.get_children():
		c.queue_free()
	game.show_map()
	await process_frame
	section("== stamina modal and auto-battle toggle ==")
	# 1. Stamina Pill and Modal
	var stam_pill: Control = game.root.find_child("HeaderStaminaPill", true, false) as Control
	check(stam_pill != null, "HeaderStaminaPill present in header")
	game.show_stamina_modal()
	await process_frame
	var stam_modal: Node = game.overlay.find_child("StaminaModal", true, false)
	check(stam_modal != null, "StaminaModal opens on request")
	if stam_modal != null:
		check(stam_modal.find_child("StaminaRechargeBtn", true, false) != null, "StaminaRechargeBtn present in StaminaModal")
		stam_modal.queue_free()
		await process_frame

	# 2. Battle Auto Toggle Button and Multi-Card Chaining
	game.battle_speed = 10.0
	game.begin_battle(0)
	await process_frame
	var auto_btn: Button = game.root.find_child("AutoBattleToggle", true, false) as Button
	check(auto_btn != null, "AutoBattleToggle present on battle screen")
	if auto_btn != null:
		check(game.auto_battle_active == false, "auto battle initially inactive")
		tap_button(auto_btn, "AutoBattleToggle")
		await process_frame
		check(game.auto_battle_active == true, "AutoBattleToggle enables auto-battle")
		var starting_hand: int = game.combat.state.hand.size()
		for _step in 30:
			await create_timer(0.08).timeout
			if game.combat == null or game.combat.state.hand.size() < starting_hand:
				break
		check(game.combat != null and game.combat.state.hand.size() < starting_hand, "auto-battle played cards in combat")
		game.stop_auto_battle("manual")
		check(game.auto_battle_active == false, "stop_auto_battle disables auto-battle")
	game._leave_battle()
	game.battle_speed = 1.0
	await process_frame

	# 2b. Auto-Battle actually plays more than one card (user-reported bug: auto-battle only
	# ever auto-played the very first card of the battle, then silently stopped). Root cause
	# was _resolve_play() calling show_battle() (whose own internal "if auto_battle_active:
	# _maybe_step_auto_battle()" branch is the only re-trigger point) while g.resolving was
	# still true — _maybe_step_auto_battle()'s guard clause always bailed, and nothing else
	# ever re-invoked it, so the chain died after card 1. Fixed by re-checking only after
	# g.resolving is genuinely reset back to false. Uses the real starting deck (guaranteed
	# all 1-cost, per AGENTS.md, so turn 1's energy affords at least 2 plays) rather than
	# whatever the shared profile's deck has drifted to by this point in the suite, and a
	# sped-up battle_speed so a full auto-played battle doesn't slow this suite down.
	var saved_deck_autobattle: Array = game.profile.deck.duplicate()
	var saved_speed_autobattle: float = game.battle_speed
	game.profile.deck = game.content.raw.startingDeck.duplicate()
	game.battle_speed = 50.0
	game.toggle_auto_battle(true)
	game.begin_battle(0)
	await process_frame

	var second_card_guard := 0
	while game.combat != null and game.combat.state.phase == "player" and int(game.combat.state.stats.get("cards_played", 0)) < 2 and second_card_guard < 200:
		await create_timer(0.05).timeout
		second_card_guard += 1
	check(game.combat != null and int(game.combat.state.stats.get("cards_played", 0)) >= 2, "auto-battle plays a second card once the first one resolves, not just the first (regression check: was stuck at exactly 1)")

	# Let the fully-automated battle run to completion with zero manual card plays, proving
	# the re-trigger chain carries the whole fight rather than just squeezing out one extra card.
	var win_guard := 0
	while game.combat != null and game.combat.state.phase == "player" and win_guard < 400:
		await create_timer(0.05).timeout
		win_guard += 1
	var pre_stop_cards_played: int = int(game.combat.state.stats.get("cards_played", 0)) if game.combat != null else -1
	check(game.combat != null and game.combat.state.phase == "won", "auto-battle alone (no manual card plays) carries the battle all the way to a win (%d cards played)" % pre_stop_cards_played)

	# DIAGNOSTIC: does auto-battle's "Auto Push" cross-stage chain (_finish_reward()'s own
	# "if auto_battle_active: begin_battle(next_idx)" branch, reached via the chest-opening
	# flow after a win) actually continue into the next stage's battle with no manual tap?
	# Never previously verified here — the check below this comment used to call
	# stop_auto_battle() immediately after the win, before the chest-opening chain even had a
	# chance to run, so this exact continuation was untested.
	var first_stage_cleared: int = int(game.current_stage)
	var stage2_guard := 0
	while game.auto_battle_active and int(game.current_stage) == first_stage_cleared and stage2_guard < 200:
		await create_timer(0.05).timeout
		stage2_guard += 1
	check(int(game.current_stage) != first_stage_cleared, "auto-battle's Auto Push chain advances to the next stage automatically after a win, with no manual tap")
	if int(game.current_stage) != first_stage_cleared:
		var stage2_card_guard := 0
		while game.combat != null and game.combat.state.phase == "player" and int(game.combat.state.stats.get("cards_played", 0)) < 1 and stage2_card_guard < 200:
			await create_timer(0.05).timeout
			stage2_card_guard += 1
		check(game.combat != null and int(game.combat.state.stats.get("cards_played", 0)) >= 1, "auto-battle plays at least one card in the automatically-advanced next stage too")

	game.stop_auto_battle("manual")
	# combat.state.phase flips to "won" synchronously the instant the killing blow lands —
	# well before _resolve_play()'s own animation chain for that card (still holding
	# g.resolving true) actually finishes, including the finishing-blow banner sequence.
	# Leaving immediately here would free the battle screen while that coroutine is still
	# suspended mid-tween — same settle-before-leaving idiom e2e_playthrough.gd's
	# _simulate_battle() already uses after its own win/loss loop, for the same reason.
	var autobattle_settle_wait := 0.0
	while game.resolving and autobattle_settle_wait < 5.0:
		await create_timer(0.1).timeout
		autobattle_settle_wait += 0.1

	game.profile.deck = saved_deck_autobattle
	game.battle_speed = saved_speed_autobattle
	game._leave_battle()
	await process_frame

	# 2c. Regression check for a second bug the fix above surfaced: leaving battle (tapping
	# "⌂") immediately after a killing blow. combat.state.phase flips to "won" synchronously
	# the instant the hit lands, well before _resolve_play()'s finishing-blow banner sequence
	# actually finishes — and the win/loss outcome screen (the only place the "⌂" button goes
	# away) doesn't replace the battle screen until that whole chain completes, so a real
	# player really can tap leave while it's still animating. This used to free g.overlay's
	# children out from under the still-suspended _animate_finishing_blow() coroutine,
	# crashing with "Cannot call method 'queue_free' on a previously freed instance." Fixed
	# with is_instance_valid() guards there (game_battle_screen.gd), the same pattern
	# show_chapter_transition()'s fix already uses. As with that fix, the real proof is "no
	# SCRIPT ERROR in a full run's log" (confirmed by temporarily reverting the guards and
	# re-running) — this check() is the closest a check() gets, confirming the game is at
	# least left in a working state.
	# Deliberately left at normal (1.0) battle_speed for this one check, not sped up like the
	# tests above: _animate_finishing_blow()'s whole sequence is a fixed ~1.2s of real tween
	# time, and the point of this test is to land inside that window, not race past it — a
	# sped-up sequence can finish faster than a single process_frame, making the window too
	# narrow to reliably hit rather than just making the test faster.
	game.begin_battle(0)
	await process_frame
	# Force a guaranteed-lethal, guaranteed-attack card into hand[0] rather than trusting
	# whatever the opening draw happens to contain (the draw shuffle is seeded from wall-clock
	# time in begin_battle(), so it isn't deterministic run to run) — "strike" is a plain
	# 1-cost, 6-damage hit to the opponent (core.json), always affordable on turn 1.
	game.combat.state.hand[0] = {"uid": 90001, "card_id": "strike"}
	# begin_battle()'s per-battle flavor modifier is seeded from wall-clock time (see its own
	# comment in game_battle_screen.gd), so every single call — this one included — has a real,
	# non-deterministic chance of rolling one of two options that stop a single lethal hit from
	# ending the battle: "swarm" (+1 enemy — killing only enemies[0] leaves a second one alive)
	# and "rebirth" (each defeated enemy has a 45% chance to revive at 35% health instead of
	# actually dying — see combat.gd's `if not enemy.revived and state.revives > 0 and
	# rng.randf() < state.revive_chance` branch). Either way _living_count() never reaches 0,
	# combat.state.phase never reaches "won", and _animate_enemy_hit() correctly (by its own
	# documented condition) never calls _animate_finishing_blow() at all — so the banner this
	# test is waiting for simply never gets created. That is not a bug in the animation code; it
	# was this test's own unstated assumption that a single hit always ends the battle, which
	# these rolls violate often enough in combination to matter (~9.6% swarm + ~4.3% rebirth
	# revive, confirmed by instrumenting and reproducing each independently). Neutralize both:
	# force every other enemy already dead so the one hit this test lands is always the last
	# living one, and zero out the revive mechanic so that hit's death always sticks.
	for i in game.combat.state.enemies.size():
		game.combat.state.enemies[i].health = 1 if i == 0 else 0
	game.combat.state.revive_chance = 0.0
	game.combat.state.revives = 0
	game._attempt_play_card(0, 0)
	# Wait for _animate_finishing_blow() to actually be mid-sequence (its banner node exists)
	# rather than guessing a delay — the banner is created right at the top of that function,
	# well before any of its awaits, so its presence confirms the coroutine is now suspended
	# somewhere in the vulnerable window this test means to hit.
	var banner_guard := 0
	while game.overlay.get_node_or_null("FinishingBlowBanner") == null and game.resolving and banner_guard < 1800:
		await process_frame
		banner_guard += 1
	check(game.overlay.get_node_or_null("FinishingBlowBanner") != null, "finishing-blow banner appears mid-sequence, confirming this test actually reaches the vulnerable window")
	game._leave_battle()
	await process_frame
	check(game.root != null and game.root.get_child_count() > 0, "leaving battle mid-finishing-blow-animation does not crash or leave a broken screen")
	# _leave_battle() now bumps g.battle_session and resets g.resolving itself (see game.gd's
	# comment on battle_session) rather than leaving both for the interrupted _resolve_play()'s
	# own tail to eventually clear — so resolving is already false immediately, synchronously,
	# not just eventually once that stale coroutine happens to finish.
	check(not game.resolving, "_leave_battle() clears g.resolving immediately, not just once the interrupted coroutine's own tail eventually runs")
	game.show_map()
	await process_frame
	check(game.root.find_child("MapAutoPushBtn", true, false) != null, "navigating to the map right after leaving mid-animation actually shows the map")
	# The interrupted _resolve_play() still has its own tail to run (a couple more delays, then
	# its own show_battle()/_maybe_end_turn() calls) even though the guards above make its
	# nested _animate_finishing_blow() return early — this used to redraw a stale battle screen
	# over the map a moment later, since that tail called show_battle() unconditionally with no
	# way to tell "the player already left". Fixed by _resolve_play() capturing g.battle_session
	# at entry and checking it again right before show_battle(): _leave_battle()'s bump above
	# means the captured value no longer matches, so the stale tail now returns instead of
	# calling show_battle(). Give that tail's remaining real-time delays a generous window to
	# actually fire (rather than just not crashing within one frame) before checking the map is
	# still intact — this is the regression check for that fix.
	var post_leave_wait := 0.0
	while post_leave_wait < 3.0:
		await create_timer(0.1).timeout
		post_leave_wait += 0.1
	check(game.root.find_child("MapAutoPushBtn", true, false) != null, "the stale _resolve_play() tail does not redraw the battle screen over the map once it finishes")
	check(game.root.find_child("PlayerSprite", true, false) == null, "no battle-only PlayerSprite reappears on the map from the stale coroutine's tail")
	check(not game.resolving, "g.resolving stays false through the stale coroutine's whole remaining tail")

	# 2d. Event Auto-Selection
	game.battle_speed = 10.0
	game.toggle_auto_battle(true)
	game.show_event(3, "rest")
	await process_frame
	var event_auto_btn := game.root.find_child("EventAutoBattleToggle", true, false) as Button
	check(event_auto_btn != null, "EventAutoBattleToggle present on event screen")
	for _wait in 10:
		await create_timer(0.08).timeout
		if game.combat != null:
			break
	check(game.combat != null, "auto-battle automatically selected event choice and started battle")
	game.stop_auto_battle("manual")
	game._leave_battle()
	game.battle_speed = 1.0
	await process_frame

	# 2e. Auto battle speed cycling continuity and restart verification
	game.begin_battle(0)
	await process_frame
	var auto_btn2: Button = game.root.find_child("AutoBattleToggle", true, false) as Button
	var speed_btn2: Button = game.root.find_child("SpeedToggle", true, false) as Button
	check(auto_btn2 != null, "AutoBattleToggle present for speed cycle test")
	check(speed_btn2 != null, "SpeedToggle present for speed cycle test")
	if auto_btn2 != null and speed_btn2 != null:
		tap_button(auto_btn2, "AutoBattleToggle")
		await process_frame
		check(game.auto_battle_active == true, "auto battle active before speed change")
		# Change speed to 1.5x during auto-play
		game._cycle_speed()
		await process_frame
		check(game.battle_speed == 1.5, "speed changed to 1.5x")
		check(game.auto_battle_active == true, "auto battle remains active after changing to 1.5x")
		check(speed_btn2.text == "1.5x", "speed toggle button text updated to 1.5x in-place")
		# Change speed to 2.0x during auto-play
		game._cycle_speed()
		await process_frame
		check(game.battle_speed == 2.0, "speed changed to 2.0x")
		check(game.auto_battle_active == true, "auto battle remains active after changing to 2.0x")
		check(speed_btn2.text == "2x", "speed toggle button text updated to 2x in-place")
		# Change speed to 3.0x during auto-play
		game._cycle_speed()
		await process_frame
		check(game.battle_speed == 3.0, "speed changed to 3.0x")
		check(game.auto_battle_active == true, "auto battle remains active after changing to 3.0x")
		check(speed_btn2.text == "3x", "speed toggle button text updated to 3x in-place")
		# Change speed to 4.0x during auto-play
		game._cycle_speed()
		await process_frame
		check(game.battle_speed == 4.0, "speed changed to 4.0x")
		check(game.auto_battle_active == true, "auto battle remains active after changing to 4.0x")
		check(speed_btn2.text == "4x", "speed toggle button text updated to 4x in-place")
		# Change speed to 1.0x during auto-play
		game._cycle_speed()
		await process_frame
		check(game.battle_speed == 1.0, "speed cycled back to 1.0x")
		check(game.auto_battle_active == true, "auto battle remains active after cycling to 1.0x")
		check(speed_btn2.text == "1x", "speed toggle button text updated to 1x in-place")
		var wait_res := 0.0
		while game.resolving and wait_res < 4.0:
			await create_timer(0.08).timeout
			wait_res += 0.08
		check(not game.resolving, "resolving is false after speed cycles")
		game.stop_auto_battle("manual")
	game._leave_battle()
	await process_frame
	check(not game.resolving, "resolving is cleanly reset to false after leaving battle")

	# Restart combat and verify auto-play can start without being blocked
	game.begin_battle(0)
	await process_frame
	check(not game.resolving, "resolving is false at start of restarted combat")
	var auto_btn_restart: Button = game.root.find_child("AutoBattleToggle", true, false) as Button
	check(auto_btn_restart != null, "AutoBattleToggle present on restarted combat")
	if auto_btn_restart != null:
		tap_button(auto_btn_restart, "AutoBattleToggle")
		await process_frame
		check(game.auto_battle_active == true, "auto-battle can successfully start on restarted combat")
		game.stop_auto_battle("manual")
	game._leave_battle()
	await process_frame

	# 3. Map Auto Push Button
	game.show_map()
	await process_frame
	var map_auto_btn: Control = game.root.find_child("MapAutoPushBtn", true, false) as Control
	check(map_auto_btn != null, "MapAutoPushBtn present on map rail")

	# 4. Samsara / Reincarnation Section and Modal (C2)
	section("== samsara reincarnation section and modal ==")
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	var samsara_sec: Node = game.root.find_child("SamsaraSection", true, false)
	check(samsara_sec != null, "SamsaraSection renders in Camp challenges tab")

	game.profile.unlocked = 250
	game.profile.difficulty = 5
	game.show_camp()
	await process_frame
	var samsara_enter := game.root.find_child("SamsaraEnterBtn", true, false) as Button
	check(samsara_enter != null, "SamsaraEnterBtn appears when unlocked >= 250 AND difficulty >= 5")
	game.show_samsara_modal()
	await process_frame
	var samsara_dialog: Node = game.overlay.find_child("SamsaraModal", true, false)
	check(samsara_dialog != null, "SamsaraModal opens on show_samsara_modal")
	var s_confirm := game.overlay.find_child("SamsaraConfirmBtn", true, false) as Button
	check(s_confirm != null, "SamsaraConfirmBtn is present in modal")
	var s_cancel := game.overlay.find_child("SamsaraCancelBtn", true, false) as Button
	check(s_cancel != null, "SamsaraCancelBtn is present in modal")
	tap_button(s_cancel, "SamsaraCancelBtn")
	await process_frame
	check(game.overlay.find_child("SamsaraModal", true, false) == null, "SamsaraModal closes on cancel")

	game.profile.samsara_count = 1
	game.show_camp()
	await process_frame
	check(game.root.find_child("DifficultyTierBtn_A6", true, false) != null, "DifficultyTierBtn_A6 appears when samsara_count >= 1")

	game.show_map()
	await process_frame
	_sweep_buttons_clickable(game.root, "Map screen")
	for tab in ["character", "challenges", "collection"]:
		game.camp_tab = tab
		game.show_camp()
		await process_frame
		_sweep_buttons_clickable(game.root, "Camp (%s tab)" % tab)
	game.show_shop()
	await process_frame
	_sweep_buttons_clickable(game.root, "Shop screen")
	game.show_deck()
	await process_frame
	_sweep_buttons_clickable(game.root, "Deck screen")
	game.compendium_tab = "cards"
	game.show_compendium()
	await process_frame
	_sweep_buttons_clickable(game.root, "Compendium screen")
	# === 250 UNIQUE ENEMY MONSTER ARTS & HERO SEPARATION INTEGRITY ===
	print("== 250 unique enemy monster arts & hero separation ==")
	var all_stage_arts: Dictionary = {}
	var hero_keys := ["fox", "sentinel", "hero_fox_spirit", "hero_stone_sentinel", "hero_shadow_stalker", "hero_miasma_witch"]
	for s_idx in range(game.content.encounters.size()):
		var enc: Dictionary = game.content.encounters[s_idx]
		var a_key: String = game._art_key_for_enemy(enc)
		check(not hero_keys.has(a_key), "stage %d enemy art_key '%s' must not be a hero art" % [s_idx, a_key])
		check(not all_stage_arts.has(a_key), "stage %d main enemy art_key '%s' is strictly unique across all stages" % [s_idx, a_key])
		all_stage_arts[a_key] = s_idx
		
		var chapter: int = enc.chapter
		var expected_minion_idx := (chapter - 1) * 5
		var expected_minion_art: String = str(game.content.encounters[expected_minion_idx].art_key)
		var expected_minion_name: String = str(game.content.encounters[expected_minion_idx].name)
		check(str(enc.get("add_art_key", "")) == expected_minion_art, "stage %d adds share chapter %d minion art '%s'" % [s_idx, chapter, expected_minion_art])
		check(str(enc.get("add_name", "")) == expected_minion_name, "stage %d adds share chapter %d minion name '%s'" % [s_idx, chapter, expected_minion_name])
	check(all_stage_arts.size() == 250, "all 250 small stages have 100% unique main enemy arts")

	_ui_readability_checks(game)

	_restore_save()
	print("")
	if failures == 0: print("UI SMOKE: all checks passed")
	else: print("UI SMOKE: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------------------------
# UI readability — the invariants behind the fixes in tools/ui_audit.gd, in a form that fails CI.
#
# ui_audit.gd MEASURES rendered pixels, which is the right way to *find* these problems (it found
# the 1.62:1 deck chips and the 2.19:1 HP readout) but the wrong way to *gate* them: it needs a
# real renderer, its numbers move with the GPU driver, and a threshold on "average local contrast"
# would go red on a font-weight change that nobody can see. So the gate here asserts the
# decisions instead — the five things that were actually wrong and can only be wrong again by
# someone re-inventing them:
#   1. `_ink_for` picks dark ink on a light fill (the rule that 24 deck chips broke)
#   2. bar text carries an outline (the HP readout)
#   3. map captions carry an outline (text over terrain)
#   4. the leftmost hand card's cost badge stays inside the hand's clip (it was half cut off)
#   5. no repeated glyph stands in for a currency icon (the ◆/✧/◈ regression, kept from the
#      shop rework so the two guards live together)
func _ui_readability_checks(game: Control) -> void:
	section("== ui readability ==")

	# 1. Contrast-aware ink. Light fills must get dark text; dark fills keep the light text.
	var light_fill := Color("ff9a4c")   # g.EMBER — the active-filter-chip fill that measured 1.90:1
	var dark_fill := Color("10242b")    # g.PANEL
	var dark_fill_ratio: float = game.contrast_ratio(game._ink_for(dark_fill), dark_fill)
	check(game.contrast_ratio(game._ink_for(light_fill), light_fill) >= 4.5,
		"_ink_for() picks >=4.5:1 text on a light EMBER fill (was 1.90:1 with hardcoded TEXT)")
	check(dark_fill_ratio >= 4.5,
		"_ink_for() keeps >=4.5:1 text on a dark PANEL fill (%.2f:1)" % dark_fill_ratio)
	# The rule has to hold for whatever colour a future caller passes, not just these two.
	var worst_fill := 99.0
	for fill: Color in [Color("83e4c1"), Color("ff9a4c"), Color("dab56e"), Color("f7f3e8"),
			Color("10242b"), Color("172a30"), Color("1e4a35"), Color("a663bc"), Color("c35736")]:
		worst_fill = minf(worst_fill, game.contrast_ratio(game._ink_for(fill), fill))
	check(worst_fill >= 4.5,
		"_ink_for() clears 4.5:1 on every palette fill a button actually uses (worst %.2f:1)" % worst_fill)

	# 2/3. Outlines on text that sits on a variable background.
	game.profile.unlocked = 12
	game.begin_battle(0)
	await process_frame
	var bar := _find_stat_bar_with_text(game, "♥")
	check(bar != null, "battle screen has an HP stat bar")
	if bar != null:
		var inner := _find_label_with_text(bar, "♥")
		check(inner != null and inner.get_theme_constant("outline_size") > 0,
			"the HP readout has a text outline — it renders white over the orange fill and measured 2.19:1 without one")

	game.show_map()
	await process_frame
	var caption := _find_label_with_text(game, game.t("ui.locked"))
	check(caption != null, "map screen shows a locked-pin caption")
	if caption != null:
		check(caption.get_theme_constant("outline_size") > 0,
			"map pin captions have an outline — they sit on terrain that ranges from water to sand within one label")

	# 4. Hand-fan clipping. A full five-card hand is the only case that overflows, so it is the
	# only case worth asserting; the fan is mathematically narrower below that.
	game.begin_battle(0)
	await process_frame
	var hand: Array = game.combat.state.hand
	while hand.size() < 5:
		hand.append({"uid": 70000 + hand.size(), "card_id": "strike"})
	hand.resize(5)
	game.show_battle()
	await process_frame
	var tiles := _find_hand_cards(game)
	var clipped := 0
	var leftmost := 999.0
	for t: Control in tiles:
		leftmost = minf(leftmost, t.position.x)
		if t.position.x + t.size.x < 0.0 or t.position.x > 366.0:
			clipped += 1
	check(tiles.size() == 5, "a full hand renders all five cards (%d)" % tiles.size())
	check(clipped == 0, "no card in a full five-card hand is laid out fully outside the hand area")
	check(leftmost >= 9.0,
		"the leftmost hand card keeps its 10px cost-badge offset on screen (leftmost x=%.1f)" % leftmost)

	# 5. Currency must be the designed icon art, never a lookalike glyph.
	var glyphs := ["◆", "✧", "◈", "◇", "✦"]
	var offenders: Array[String] = []
	for n: Node in game.find_children("", "Control", true, false):
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		if not (c is Label or c is Button):
			continue
		var txt: String = (c as Label).text if c is Label else (c as Button).text
		for gl: String in glyphs:
			if gl in txt:
				offenders.append("%s \"%s\"" % [c.name, txt.substr(0, 24)])
				break
	check(offenders.is_empty(),
		"no currency amount is drawn with a substitute glyph instead of the designed icon (%s)" % str(offenders))

func _find_stat_bar_with_text(node: Node, needle: String) -> ProgressBar:
	if node is ProgressBar:
		if _find_label_with_text(node, needle) != null:
			return node as ProgressBar
	for child in node.get_children():
		var found := _find_stat_bar_with_text(child, needle)
		if found != null: return found
	return null

func _find_label_with_text(node: Node, needle: String) -> Label:
	if node is Label and needle in (node as Label).text:
		return node as Label
	for child in node.get_children():
		var found := _find_label_with_text(child, needle)
		if found != null: return found
	return null

func _find_hand_cards(node: Node) -> Array:
	var out: Array = []
	if node is HandCard:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_hand_cards(child))
	return out

func _restore_save() -> void:
	if had_profile: FileAccess.open(SpiritSave.PATH, FileAccess.WRITE).store_string(saved_profile)
	else: SpiritSave.reset()

# Walks up summing z_index, since z_as_relative makes a node's depth depend on its parents.
func _effective_z(node: Node) -> int:
	var total := 0
	var current := node
	while current != null:
		if current is CanvasItem: total += (current as CanvasItem).z_index
		current = current.get_parent()
	return total

# Determines if node_a wins GUI input priority over node_b — i.e. a tap landing on both would
# be delivered to node_a, not node_b. This is deliberately NOT the same question as "which one
# renders on top": Godot's z_index affects render order only and is never consulted for input
# dispatch, which follows scene-tree sibling order alone (last-added child of the lowest common
# ancestor wins). A version of this check that fell back to comparing z_index first reported
# every button inside an overlay-hosted modal as unoccluded, since the modal's z_index made it
# LOOK like it was on top — while Godot's real input dispatch was silently handing every tap to
# whatever interactive element in the screen underneath happened to share that position,
# because the modal's `overlay` container is added to the page before the page's own content
# and so loses on tree order despite winning on z_index. See game.gd's _modal_dialog() for the
# production-code half of this same bug.
func _wins_input_over(node_a: Control, node_b: Control) -> bool:
	var path_a: Array = []
	var curr: Node = node_a
	while curr != null:
		path_a.append(curr)
		curr = curr.get_parent()
	var path_b: Array = []
	curr = node_b
	while curr != null:
		path_b.append(curr)
		curr = curr.get_parent()
	var lca: Node = null
	for na in path_a:
		if na in path_b:
			lca = na
			break
	if lca == null:
		return false
	var idx_a := path_a.find(lca)
	var idx_b := path_b.find(lca)
	if idx_a > 0 and idx_b > 0:
		var branch_a: Node = path_a[idx_a - 1]
		var branch_b: Node = path_b[idx_b - 1]
		return branch_a.get_index() > branch_b.get_index()
	return false

# Physical hit-test & occlusion checker: verifies a Control can genuinely receive
# touch/click input on a mobile screen without being obscured, zero-sized, or blocked.
func find_occlusion(target: Control) -> String:
	if target == null:
		return "target node is null"
	if not target.is_inside_tree():
		return "target is not inside scene tree"
	if not target.is_visible_in_tree():
		return "target is not visible in tree"
	if target is BaseButton and (target as BaseButton).disabled:
		return "button is disabled"
	if target.size.x < 4.0 or target.size.y < 4.0:
		return "button size is too small or collapsed (%s)" % str(target.size)
	# A full-screen dismiss-anywhere backdrop (_modal_dialog()/_modal_backdrop()'s
	# ModalBackdropDim/HoldPreview) is *always* partially covered at its own center by the
	# dialog or peek content stacked on top of it — that's the intended design, not an
	# accident, and Godot's normal sibling-order dispatch already routes a tap on the dialog
	# to the dialog and a tap on the surrounding dimmed area to the backdrop. Center-point
	# testing can't distinguish "covered everywhere" from "covered only at the center where
	# its own content sits", so this class of node is exempted rather than producing a
	# structurally-guaranteed false positive on every single modal.
	if target.name == "ModalBackdropDim" or target.name == "HoldPreview":
		return ""

	var rect := target.get_global_rect()
	var center := rect.get_center()

	# A ScrollContainer descendant legitimately lives outside the currently-visible window —
	# that's what scrolling is for. Skip the absolute-viewport check for it; the sibling/
	# ancestor MOUSE_FILTER_STOP checks below still catch a genuine occlusion regardless of
	# scroll position, since occluder and target are compared at the same current rect either
	# way.
	var target_scroll_container: Node = null
	var ancestor: Node = target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: target_scroll_container = ancestor; break
		ancestor = ancestor.get_parent()
	if target_scroll_container == null and (center.x < 0.0 or center.x > 390.0 or center.y < 0.0 or center.y > 844.0):
		return "button center %s is outside viewport bounds (390x844)" % str(center)

	# 1. Check all descendants of target for MOUSE_FILTER_STOP that cover center
	var stack: Array = [target]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr != target and curr is Control:
			var c := curr as Control
			if c.is_visible_in_tree() and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				if c.get_global_rect().has_point(center):
					return "decorative child '%s' (%s) has MOUSE_FILTER_STOP, swallowing tap" % [c.name, c.get_class()]
		for child in curr.get_children():
			stack.append(child)

	# 2. Check all other controls in scene tree that draw above target and cover its center.
	# A fixed-chrome element (a persistent header/footer/dock outside the target's own
	# ScrollContainer) overlapping a scrolled target at its *current* scroll offset isn't a
	# real bug — the target moves out from under fixed chrome as the page scrolls, the same
	# way content flows behind any app's fixed bottom nav bar at a scroll extreme. Only an
	# occluder that scrolls together with the target (inside that same ScrollContainer, so
	# the overlap can never be resolved by scrolling) counts as a genuine occlusion.
	var root_node := target.get_tree().root
	stack = [root_node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is Control:
			var c := curr as Control
			if c.is_visible_in_tree() and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				if c != target and not c.is_ancestor_of(target) and not target.is_ancestor_of(c):
					var occluder_shares_scroll: bool = target_scroll_container != null and target_scroll_container.is_ancestor_of(c)
					if target_scroll_container == null or occluder_shares_scroll:
						if c.get_global_rect().has_point(center):
							if _wins_input_over(c, target):
								return "occluded by '%s' (%s) with MOUSE_FILTER_STOP, which wins input priority by tree order regardless of z_index" % [c.name, c.get_class()]
		for child in curr.get_children():
			stack.append(child)
	
	return ""

func check_clickable(target: Control, desc: String) -> bool:
	if target == null:
		check(false, "%s exists and is clickable" % desc)
		return false
	var err := find_occlusion(target)
	var ok := err.is_empty()
	check(ok, "%s is physically clickable (unblocked): %s" % [desc, "OK" if ok else err])
	return ok

func tap_button(target: Control, desc: String) -> void:
	if check_clickable(target, desc):
		if target.has_signal("pressed"):
			target.emit_signal("pressed")

# A generic, name-agnostic sweep: every visible enabled BaseButton found anywhere under
# `root` must be occlusion-clean. This is the broad net the hardcoded per-button
# check_clickable() calls above can't be — a hardcoded list only protects the specific
# buttons someone remembered to name, while this catches a regression on ANY button, on any
# screen this is called against, including ones added after this test was written. `context`
# is just a label prefix so a failure says which screen state it was found in.
func _sweep_buttons_clickable(root_node: Node, context: String) -> void:
	var stack: Array = [root_node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is BaseButton and (curr as Control).is_visible_in_tree() and not (curr as BaseButton).disabled:
			check_clickable(curr as Control, "%s: %s" % [context, str(curr.name)])
		for child in curr.get_children():
			stack.append(child)

func _max_z(node: Node) -> int:
	var best := _effective_z(node)
	for child in node.get_children():
		best = maxi(best, _max_z(child))
	return best

func _find_progress_bar(node: Node) -> Control:
	if node is ProgressBar: return node as Control
	for child in node.get_children():
		var found := _find_progress_bar(child)
		if found != null: return found
	return null

func _find_shop_tile(node: Node) -> Control:
	# Shop tiles are the fixed-width panels the grid lays out.
	if node is Control and (node as Control).custom_minimum_size.x == 176.0 and (node as Control).custom_minimum_size.y >= 200.0:
		return node as Control
	for child in node.get_children():
		var found := _find_shop_tile(child)
		if found != null: return found
	return null

func _find_button_containing(node: Node, needle: String) -> Button:
	if node is Button and needle in (node as Button).text: return node as Button
	for child in node.get_children():
		var found := _find_button_containing(child, needle)
		if found != null: return found
	return null

# Used to prove a currency price is no longer rendered as a substitute glyph (◆/✧/◈) — a Label
# cannot embed a texture, so a glyph anywhere in an amount is evidence a label escaped conversion
# to the icon-row helper.
func _collect_labels_containing(node: Node, needles: Array, out: Array) -> void:
	if node is Label:
		for needle in needles:
			if str(needle) in (node as Label).text:
				out.append((node as Label).text)
				break
	for child in node.get_children():
		_collect_labels_containing(child, needles, out)

func _all_texture_rects(node: Node, out: Array = []) -> Array:
	if node is TextureRect and (node as TextureRect).texture != null: out.append(node)
	for child in node.get_children():
		_all_texture_rects(child, out)
	return out

func _all_controls(node: Node, out: Array = []) -> Array:
	if node is Control: out.append(node)
	for child in node.get_children():
		_all_controls(child, out)
	return out

func _find_text(node: Node, needle: String) -> bool:
	if node is Button and (node as Button).text == needle: return true
	for child in node.get_children():
		if _find_text(child, needle): return true
	return false

func _find_label_text(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text == needle: return true
	for child in node.get_children():
		if _find_label_text(child, needle): return true
	return false

# Substring variant of the above, for labels built from a runtime-formatted string (a mastery
# level, an xp count) where reproducing the exact text would just re-implement the format call.
func _find_label_containing(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text: return true
	for child in node.get_children():
		if _find_label_containing(child, needle): return true
	return false

# `is GameIcon` doesn't work through a base-typed `game: Control` reference (GDScript needs
# a compile-time type expression), so identity is checked via the script resource instead.
func _find_by_script(node: Node, script: Script) -> Node:
	if node.get_script() == script: return node
	for child in node.get_children():
		var found := _find_by_script(child, script)
		if found != null: return found
	return null

func _find_all_by_script(node: Node, script: Script, out: Array) -> void:
	if node.get_script() == script: out.append(node)
	for child in node.get_children():
		_find_all_by_script(child, script, out)

func _find_jpg_texture_rect(node: Node) -> bool:
	if node is TextureRect:
		var tex: Texture2D = (node as TextureRect).texture
		if tex != null and str(tex.resource_path).ends_with(".jpg"): return true
	for child in node.get_children():
		if _find_jpg_texture_rect(child): return true
	return false

func _find_texture_rect_ending_with(node: Node, suffix: String) -> bool:
	return _get_texture_rect_ending_with(node, suffix) != null

func _get_texture_rect_ending_with(node: Node, suffix: String) -> TextureRect:
	if node is TextureRect:
		var tex: Texture2D = (node as TextureRect).texture
		if tex != null and (str(tex.resource_path).ends_with(suffix) or (suffix.begins_with("card_frame") and str(tex.resource_path).contains("card_frame"))): return node
	for child in node.get_children():
		var found := _get_texture_rect_ending_with(child, suffix)
		if found != null: return found
	return null

func _find_texture_rect(node: Node) -> TextureRect:
	if node is TextureRect: return node as TextureRect
	for child in node.get_children():
		var found := _find_texture_rect(child)
		if found != null: return found
	return null

func _find_all_texture_rects(node: Node) -> Array:
	var out: Array = []
	if node is TextureRect: out.append(node)
	for child in node.get_children():
		out.append_array(_find_all_texture_rects(child))
	return out
