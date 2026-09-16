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
	game.lang = "zh-Hans"
	await process_frame

	section("== account ==")
	check(game.profile.has("account") and game.profile.account.has("id"), "profile carries an account id")
	check(int(game.profile.get("schema_version", 0)) >= 2, "save declares a schema version")
	game.show_account_setup()
	await process_frame
	check(game.root.get_child_count() > 0, "account setup screen builds")
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
	check(game.map_canvas.custom_minimum_size.y > 4000.0, "map canvas spans all chapters")

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

	# The road used to be a seeded random walk with no idea what the background looked like;
	# now every chapter has a real painted trail baked into its background, so the waypoints
	# must trace BIOME_PATH_WAYPOINTS's hand-picked points for that biome exactly — mirrored
	# when _add_map_chapter flips that background horizontally for this cycle through it.
	var biome_count: int = game.BIOME_PATH_WAYPOINTS.size()
	var expected_ch0: Array = game.BIOME_PATH_WAYPOINTS[0]
	var matches_biome := true
	for i in 5:
		if not (wp0[i] as Vector2).is_equal_approx(expected_ch0[i]): matches_biome = false
	check(matches_biome, "chapter 0's road traces its background's own hand-picked path, not a random walk")
	var wp_flipped: Array = game._chapter_waypoints(biome_count)
	var mirrors := true
	for i in 5:
		var expected_x: float = game.MAP_WIDTH - (expected_ch0[i] as Vector2).x
		if absf((wp_flipped[i] as Vector2).x - expected_x) > 0.01: mirrors = false
	check(mirrors, "the road mirrors horizontally on chapter %d, matching its horizontally-flipped background" % biome_count)

	var raw_points := PackedVector2Array()
	for i in 5: raw_points.append(wp0[i])
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
	_find_all_by_script(band0, game.GameIcon, band0_decos)
	var terrain_decos: Array = []
	for d in band0_decos:
		if str(d.kind) in ["pine", "boulder", "hill"]: terrain_decos.append(d)
	check(terrain_decos.size() > 0, "chapter 0's background is dressed with procedural terrain silhouettes (%d placed)" % terrain_decos.size())
	var all_clear := true
	for d in terrain_decos:
		var center: Vector2 = d.position + d.size / 2.0
		for bp in baked:
			var v: Vector2 = bp
			if center.distance_to(v) < 30.0: all_clear = false
	check(all_clear, "terrain decorations stay clear of the actual road curve, not just visually near it")

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
	var lang_btn := _find_button_containing(game.root, game.content.ui("ui.lang_toggle", game.lang))
	check(lang_btn != null and lang_btn.size.y > 20.0, "map header is laid out too")

	# Map pins set their own z_index, which beats tree order, so the floating bars have to
	# outrank them or the dock draws underneath the stages it is supposed to sit over.
	if dock_btn != null:
		var dock_z := _effective_z(dock_btn)
		var pin_z := _max_z(game.map_canvas)
		check(dock_z > pin_z, "dock draws above the map (dock z=%d, highest map z=%d)" % [dock_z, pin_z])
		var dock_icon := _find_by_script(dock_btn, game.GameIcon)
		check(dock_icon != null, "dock button carries a drawn GameIcon, not just a text glyph")

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
		var quest_icon := _find_by_script(quest_btn, game.GameIcon)
		check(quest_icon != null and str(quest_icon.kind) == "quest", "the quest entry point uses a quest icon")
	var camp_btn: Node = game.root.find_child("CampButton", true, false)
	check(camp_btn != null, "the camp entry point button exists")
	if camp_btn != null:
		var camp_icon := _find_by_script(camp_btn, game.GameIcon)
		check(camp_icon != null and str(camp_icon.kind) == "profile", "the camp entry point uses a profile icon")
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

	game.profile.daily_quests = saved_daily
	game.profile.weekly_quests = saved_weekly
	game.profile.deck = saved_deck
	game.profile.collection = saved_collection
	game.show_map()
	await process_frame

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
	_find_all_by_script(game.root, game.GameIcon, deck_stars)
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
	check(_find_button_containing(game.root, game.content.ui("ui.camp_tab_challenges", game.lang)) != null, "camp's challenges tab button exists")
	check(_find_button_containing(game.root, game.content.ui("ui.camp_tab_collection", game.lang)) != null, "camp's collection tab button exists")
	game.camp_tab = "challenges"
	game.show_camp()
	await process_frame
	check(not _find_label_text(game.root, game.content.ui("ui.hero_classes_title", game.lang)), "switching to the challenges tab hides the character tab's content")
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
	var layout_card: Node = _find_by_script(game.root, game.HandCard)
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
	var peek_card: Node = _find_by_script(game.root, game.HandCard)
	if peek_card != null:
		peek_card._on_touch_down(Vector2(58, 84))
		check(bool(peek_card.is_previewing), "pressing a card shows the enlarged peek immediately, no delay")
		await process_frame
		check(game.overlay.get_node_or_null("HoldPreview") != null, "the peek overlay is actually in the tree")
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
		_find_all_by_script(game.root, game.HandCard, all_hand_cards)
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

	var hold_card: Node = _find_by_script(game.root, game.HandCard)
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

	var peek_card_2: Node = _find_by_script(game.root, game.HandCard)
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
	var peek_card_3: Node = _find_by_script(game.root, game.HandCard)
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
	var peek_card_4: Node = _find_by_script(game.root, game.HandCard)
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
			var probe: Control = game.GameIcon.new()
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
		var probe: Control = game.GameIcon.new()
		probe.kind = str(item.get("icon_kind", "sword"))
		probe.flourish = str(item.get("icon_flourish", ""))
		probe.icon_color = Color("dab56e")
		probe.size = Vector2(32, 32)
		data_holder.add_child(probe)
	for rune in SpiritContent.RUNES:
		var probe: Control = game.GameIcon.new()
		probe.kind = "sigil"
		probe.flourish = str(rune.get("icon_mark", ""))
		probe.icon_color = Color(rune.color)
		probe.size = Vector2(32, 32)
		data_holder.add_child(probe)
	for relic in SpiritContent.RELICS:
		var probe: Control = game.GameIcon.new()
		probe.kind = "sigil"
		probe.flourish = str(relic.get("icon_mark", ""))
		probe.icon_color = Color(relic.color)
		probe.size = Vector2(32, 32)
		data_holder.add_child(probe)
	var dizzy: Control = game.DizzyStars.new()
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
		if child.get_script() == game.DizzyStars: found_dizzy = true
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

	game.profile.unlocked = saved_unlocked
	game.profile.position = saved_position
	game.profile.claimed_stage_events = saved_claimed_events
	game.profile.relics = saved_relics

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
		_find_all_by_script(tile, game.GameIcon, frame_marks)
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
	check(game.battle_speed == 1.0, "initial battle_speed is 1.0")
	# Simulate clicking speed toggle to cycle 1.0 -> 1.5 -> 2.0 -> 1.0
	game._cycle_speed()
	check(game.battle_speed == 1.5, "after first click speed is 1.5")
	game._cycle_speed()
	check(game.battle_speed == 2.0, "after second click speed is 2.0")
	game._cycle_speed()
	check(game.battle_speed == 1.0, "after third click speed wraps to 1.0")
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
	check(_find_label_text(game.root, game.content.ui("ui.hero_art_pending", game.lang)), "the art-pending badge renders for the hero borrowing a placeholder sprite")
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
	check(game._is_replay(2), "stage 2 is detected as replay")
	check(game._is_stage_event_claimed(2), "replay stage 2 event is treated as claimed")
	game.current_stage = 2
	var test_replay_combat := SpiritCombat.new(game.content)
	test_replay_combat.create(1, game.content.encounters[2], game.content.raw.startingDeck, 60)
	test_replay_combat.state.player.health = 35
	game.combat = test_replay_combat
	game._grant_stage_rewards()
	check(game.profile.health == 35, "replaying stage 2 does not grant extra +10 HP healing")
	check(game.pending_rewards.get("replay", false) == true, "stage replay is flagged in pending_rewards")
	check(str(game.pending_rewards.get("equipment", "")) == "", "stage replay does not drop equipment")

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

	section("== milestone 4: compendium, hero mastery & daily trial ==")
	game.compendium_tab = "cards"
	game.show_compendium()
	await process_frame
	check(_find_label_text(game.root, game.content.ui("ui.compendium_title", game.lang)), "Compendium title renders")
	check(_find_button_containing(game.root, game.content.ui("ui.compendium_tab_bestiary", game.lang)) != null, "Bestiary tab button exists")
	game.compendium_tab = "bestiary"
	game.show_compendium()
	await process_frame
	check(game.root.get_child_count() > 0, "Bestiary tab renders")

	# A synthetic key is used here (rather than a real card/equipment id) so the check doesn't
	# depend on what earlier sections in this same long-running suite already collected or
	# fought — this suite shares one profile across every section.
	check(not game._bestiary_discovered("_smoke_test_enemy"), "an unmarked bestiary key starts undiscovered")
	game._mark_discovered("bestiary", "_smoke_test_enemy")
	check(game._bestiary_discovered("_smoke_test_enemy"), "marking a bestiary key discovers it permanently")
	game._mark_discovered("relics", "starShard")
	check(game._relic_discovered("starShard"), "marking a relic id discovers it")
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

	_restore_save()
	print("")
	if failures == 0: print("UI SMOKE: all checks passed")
	else: print("UI SMOKE: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)

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
