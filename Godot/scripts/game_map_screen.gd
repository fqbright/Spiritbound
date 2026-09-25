extends RefCounted
class_name MapScreen

# Composition, not inheritance: GDScript cannot statically resolve a parent script
# calling a method only defined in a child (verified experimentally — see the game.gd
# split's commit history), and the map/camp/quests/battle screens all call each other
# circularly, so no valid inheritance order exists. `g` is the live SpiritGame/game.gd
# instance; every reference to shared state or another screen's function goes through it.
var g: SpiritGame

# Guards against a second swipe firing mid-transition (see _slide_to_chapter) — the pins on
# both throwaway pages are real, tappable buttons, so a swipe alone isn't the only thing that
# needs blocking, but it's the only re-entrancy risk that isn't already covered by the
# fullscreen input blocker _slide_to_chapter adds for the duration of the tween.
var _chapter_slide_active := false

func _init(game: SpiritGame) -> void:
	g = game

func _get_chapter_map_texture(chapter: int) -> Texture2D:
	if g._chapter_map_cache.has(chapter):
		return g._chapter_map_cache[chapter]
	var specific_path := "res://assets/chapters/chapter_%d.png" % chapter
	if ResourceLoader.exists(specific_path):
		var tex: Texture2D = load(specific_path)
		if tex != null:
			g._chapter_map_cache[chapter] = tex
			return tex
	if g._biome_textures.is_empty():
		var biome_files := [
			"res://assets/biomes/biome_0_forest.png",
			"res://assets/biomes/biome_1_autumn.png",
			"res://assets/biomes/biome_2_glacier.png",
			"res://assets/biomes/biome_3_ember.png",
			"res://assets/biomes/biome_4_swamp.png",
			"res://assets/biomes/biome_5_ruins.png"
		]
		for f in biome_files:
			if ResourceLoader.exists(f):
				g._biome_textures.append(load(f))
	if not g._biome_textures.is_empty():
		var fallback_tex: Texture2D = g._biome_textures[chapter % g._biome_textures.size()]
		g._chapter_map_cache[chapter] = fallback_tex
		return fallback_tex
	return null
func _has_claimable_quest() -> bool:
	g._ensure_quests_current()
	g._ensure_login_reward_current()
	var record: Dictionary = g.profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	var claimed: Array = record.get("claimed", [])
	for tier in SpiritContent.LOGIN_REWARD_TIERS:
		if days_logged >= int(tier.days) and not claimed.has(int(tier.days)): return true
	for list_name in ["daily_quests", "weekly_quests"]:
		for entry in g.profile.get(list_name, []):
			if int(entry.get("progress", 0)) >= int(entry.get("target", 1)) and not bool(entry.get("claimed", false)):
				return true
	return false

# "Today digest" card: a one-glance rollup of everything currently claimable across daily/
# weekly quests, the rolling login reward, and Compendium milestones — the same underlying
# state that already drives the notification dots on the Quest and Camp buttons, but spelled
# out as an actual count instead of making the player open both screens to find out what's
# waiting. Deliberately not persisted/dismissible: like the dots it mirrors, it reads reactively
# off current g.profile state and disappears the instant everything is claimed.
func _claimable_reward_count() -> int:
	g._ensure_quests_current()
	g._ensure_login_reward_current()
	var count := 0
	for list_name in ["daily_quests", "weekly_quests"]:
		for entry in g.profile.get(list_name, []):
			if int(entry.get("progress", 0)) >= int(entry.get("target", 1)) and not bool(entry.get("claimed", false)):
				count += 1
	var record: Dictionary = g.profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	var claimed_days: Array = record.get("claimed", [])
	for tier in SpiritContent.LOGIN_REWARD_TIERS:
		if days_logged >= int(tier.days) and not claimed_days.has(int(tier.days)): count += 1
	var nj_claimed: Array = g.profile.get("novice_journey", {}).get("claimed", [])
	for task in SpiritContent.NOVICE_JOURNEY_TASKS:
		var target: int = int(task.target_stage)
		if (int(g.profile.unlocked) >= target or int(g.profile.position) >= target) and not nj_claimed.has(int(task.day)):
			count += 1
	var totals: Vector2i = g._compendium_totals()
	var pct: int = int(round(100.0 * float(totals.x) / maxf(1.0, float(totals.y))))
	var claimed_milestones: Array = g.profile.get("compendium_milestones_claimed", [])
	for target in [50, 80, 100]:
		if pct >= target and not claimed_milestones.has(target): count += 1
	return count

func _open_map_digest() -> void:
	g._ensure_quests_current()
	g._ensure_login_reward_current()
	var record: Dictionary = g.profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	var claimed_days: Array = record.get("claimed", [])
	var quest_or_login_ready := false
	for list_name in ["daily_quests", "weekly_quests"]:
		for entry in g.profile.get(list_name, []):
			if int(entry.get("progress", 0)) >= int(entry.get("target", 1)) and not bool(entry.get("claimed", false)):
				quest_or_login_ready = true
	for tier in SpiritContent.LOGIN_REWARD_TIERS:
		if days_logged >= int(tier.days) and not claimed_days.has(int(tier.days)): quest_or_login_ready = true
	if quest_or_login_ready: g.show_quests()
	else: g.camp_tab = "collection"; g.show_camp()

func _add_map_right_rail(parent: Control) -> void:
	var rail := VBoxContainer.new()
	rail.name = "MapRightActionRail"
	rail.anchor_left = 1.0
	rail.anchor_right = 1.0
	rail.anchor_top = 0.0
	rail.anchor_bottom = 0.0
	rail.offset_left = -58.0
	rail.offset_right = -12.0
	rail.offset_top = float(g._safe_top()) + 62.0
	rail.offset_bottom = float(g._safe_top()) + 220.0
	rail.add_theme_constant_override("separation", 10)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.z_index = 100
	parent.add_child(rail)

	# 1. 宗门灵修 (Idle Harvest)
	var unclaimed := g.get_idle_harvest_unclaimed_gold()
	var harvest_btn := g._button("", g.show_idle_harvest_modal, Color("142c33"), Vector2(46, 46))
	harvest_btn.name = "MapIdleHarvestBtn"
	harvest_btn.custom_minimum_size = Vector2(46, 46)
	harvest_btn.size = harvest_btn.custom_minimum_size
	var harvest_icon := TextureRect.new()
	harvest_icon.texture = load("res://assets/icons/pouch.png")
	harvest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	harvest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	harvest_icon.custom_minimum_size = Vector2(28, 28)
	harvest_icon.size = harvest_icon.custom_minimum_size
	harvest_icon.position = Vector2(9, 9)
	harvest_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	harvest_btn.add_child(harvest_icon)
	if unclaimed > 0:
		_add_notification_dot(harvest_btn, Vector2(46, 46))
	rail.add_child(harvest_btn)

	# 2. 待领取奖励 (Today's Digest / Quests / Login Rewards)
	var count := _claimable_reward_count()
	if count > 0:
		var banner_holder := Control.new()
		banner_holder.name = "MapDigestBanner"
		banner_holder.custom_minimum_size = Vector2(46, 46)
		banner_holder.size = banner_holder.custom_minimum_size
		banner_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var digest_btn := g._button("", _open_map_digest, Color(0.22, 0.16, 0.06, 0.95), Vector2(46, 46))
		digest_btn.name = "MapDigestButton"
		digest_btn.custom_minimum_size = Vector2(46, 46)
		digest_btn.size = digest_btn.custom_minimum_size
		var digest_icon := TextureRect.new()
		digest_icon.texture = load("res://assets/icons/quest.png")
		digest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		digest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		digest_icon.custom_minimum_size = Vector2(28, 28)
		digest_icon.size = digest_icon.custom_minimum_size
		digest_icon.position = Vector2(9, 9)
		digest_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		digest_btn.add_child(digest_icon)

		# Number badge on top right corner
		var badge := PanelContainer.new()
		badge.name = "NotificationCountBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", g._panel(g.EMBER, 8, Color("2b0a08")))
		badge.position = Vector2(26, -4)
		badge.z_index = 5
		var badge_pad := MarginContainer.new()
		badge_pad.add_theme_constant_override("margin_left", 4)
		badge_pad.add_theme_constant_override("margin_right", 4)
		badge_pad.add_theme_constant_override("margin_top", 1)
		badge_pad.add_theme_constant_override("margin_bottom", 1)
		badge.add_child(badge_pad)
		var num_lbl := g._label(str(count), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		badge_pad.add_child(num_lbl)
		digest_btn.add_child(badge)

		banner_holder.add_child(digest_btn)
		rail.add_child(banner_holder)

	var auto_push_btn := g._button("", func():
		if not g.can_spend_stamina(5):
			g._toast(g.t("ui.stamina_insufficient"))
			g.show_stamina_modal()
			return
		g.toggle_auto_battle(true)
		_next_stage()
	, Color("1d4d3a") if g.auto_battle_active else Color("142c33"), Vector2(46, 46))
	auto_push_btn.name = "MapAutoPushBtn"
	auto_push_btn.custom_minimum_size = Vector2(46, 46)
	auto_push_btn.size = auto_push_btn.custom_minimum_size
	var ap_icon := TextureRect.new()
	ap_icon.texture = load("res://assets/icons/arrow.png")
	ap_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ap_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ap_icon.custom_minimum_size = Vector2(24, 24)
	ap_icon.size = ap_icon.custom_minimum_size
	ap_icon.position = Vector2(11, 8)
	ap_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_push_btn.add_child(ap_icon)
	var ap_lbl := g._label(g.t("ui.auto_battle"), 9, g.GOLD if g.auto_battle_active else g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	ap_lbl.position = Vector2(0, 30)
	ap_lbl.size = Vector2(46, 14)
	ap_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto_push_btn.add_child(ap_lbl)
	rail.add_child(auto_push_btn)

# Drives the red notification dot on the Camp entry point — true the moment a Compendium
# collection-milestone reward (50/80/100%) is reached and not yet claimed. Camp itself never
# had a notification dot before this; the Compendium milestones bar existed with no way to
# tell from the map that a reward was sitting there unclaimed.
func _has_claimable_camp_reward() -> bool:
	var totals: Vector2i = g._compendium_totals()
	var pct: int = int(round(100.0 * float(totals.x) / maxf(1.0, float(totals.y))))
	var claimed: Array = g.profile.get("compendium_milestones_claimed", [])
	for target in [50, 80, 100]:
		if pct >= target and not claimed.has(target): return true
	var ach_unlocked: Dictionary = g.profile.get("achievements_unlocked", {})
	var ach_claimed: Dictionary = g.profile.get("achievements_claimed", {})
	for ach_id in ach_unlocked:
		if bool(ach_unlocked[ach_id]) and not bool(ach_claimed.get(ach_id, false)):
			return true
	return false

# Drives the deck dock button's red dot — true whenever a card sits in the collection with
# more owned copies than are actually placed in the 25-card deck (a shop buy or a chest
# reward that never made it in).
func _has_unused_cards() -> bool:
	for id in g.profile.collection:
		if int(g.profile.collection[id]) > g.profile.deck.count(str(id)): return true
	return false

# A small red dot for "there is something to check in here" — the same language most mobile
# games use for unclaimed rewards or unseen content, so tapping in isn't a guess.
func _add_notification_dot(anchor: Control, btn_size: Vector2) -> void:
	var dot := Panel.new()
	dot.name = "NotificationDot"
	dot.custom_minimum_size = Vector2(13, 13)
	dot.size = dot.custom_minimum_size
	dot.position = Vector2(btn_size.x - 10.0, -3.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.z_index = 5
	dot.add_theme_stylebox_override("panel", g._panel(g.EMBER, 7, Color("2b0a08")))
	anchor.add_child(dot)

# Speed-adjusted timer: combat delays are divided by battle_speed so 2x plays twice as fast.
func show_map() -> void:
	g._clear(); g._play_music(false)
	var backdrop := ColorRect.new(); backdrop.color = g.BG; backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.root.add_child(backdrop); g.root.move_child(backdrop,0)

	# The scroller fills the screen edge to edge; the bar and dock float over it, so the
	# artwork runs under the status bar and home indicator instead of being letterboxed.
	g.map_scroll = TouchScrollContainer.new()
	g.map_scroll.allow_vertical = true
	g.map_scroll.allow_horizontal = false
	g.map_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	g.map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	g.map_scroll.swipe_released.connect(_on_map_swipe)
	g.root.add_child(g.map_scroll)

	var overlay_page := Control.new()
	overlay_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Stage pins and the traveller carry their own z_index (10 and 25), which outranks tree
	# order, so the floating bars need to sit above that — but below the toast layer at 500.
	overlay_page.z_index = 100
	g.root.add_child(overlay_page)

	var top_shade := _fade_strip(float(g._safe_top()) + 155.0, false)
	top_shade.size = Vector2(g.MAP_WIDTH, float(g._safe_top()) + 155.0)
	top_shade.modulate.a = 0.9
	overlay_page.add_child(top_shade)

	# Anchored by hand rather than with a preset: a preset resolves its offsets from the
	# minimum size at call time, which is zero before the children exist, and the parent is
	# a plain Control so nothing ever recomputes it — the bar collapses to an invisible strip.
	var header_holder := MarginContainer.new()
	header_holder.anchor_left = 0.0
	header_holder.anchor_right = 1.0
	header_holder.anchor_top = 0.0
	header_holder.anchor_bottom = 0.0
	header_holder.offset_left = 0.0
	header_holder.offset_right = 0.0
	header_holder.offset_top = 0.0
	header_holder.offset_bottom = float(g._safe_top()) + 155.0
	header_holder.add_theme_constant_override("margin_top", g._safe_top())
	header_holder.add_theme_constant_override("margin_left", 2)
	header_holder.add_theme_constant_override("margin_right", 12)
	header_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_page.add_child(header_holder)

	var header := g._header("SPIRITBOUND", "")
	var existing_spacer: Node = header.get_node_or_null("HeaderRightSpacer")
	if existing_spacer:
		existing_spacer.queue_free()

	var btn_size := Vector2(34, 34)

	# Dedicated quest commissions entry point with painted quest icon and claimable notification dot
	var quest_unlocked: bool = int(g.profile.unlocked) >= 6
	var btn_quests := g._button("", g.show_quests, Color("17363e"), btn_size)
	btn_quests.name = "QuestButton"
	btn_quests.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var quest_icon := TextureRect.new()
	quest_icon.texture = load("res://assets/icons/nav_quest.png")
	quest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	quest_icon.custom_minimum_size = Vector2(24, 24)
	quest_icon.size = quest_icon.custom_minimum_size
	quest_icon.position = (btn_size - quest_icon.size) / 2.0
	quest_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not quest_unlocked:
		quest_icon.modulate = Color(0.4, 0.4, 0.4, 0.5)
	btn_quests.add_child(quest_icon)
	if _has_claimable_quest(): _add_notification_dot(btn_quests, btn_size)

	# Dedicated explorer camp entry point with painted camp icon
	var camp_unlocked: bool = int(g.profile.unlocked) >= 5
	var btn_camp := g._button("", g.show_camp, Color("17363e"), btn_size)
	btn_camp.name = "CampButton"
	btn_camp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var camp_icon := TextureRect.new()
	camp_icon.texture = load("res://assets/icons/nav_camp.png")
	camp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	camp_icon.custom_minimum_size = Vector2(24, 24)
	camp_icon.size = camp_icon.custom_minimum_size
	camp_icon.position = (btn_size - camp_icon.size) / 2.0
	camp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not camp_unlocked:
		camp_icon.modulate = Color(0.4, 0.4, 0.4, 0.5)
	btn_camp.add_child(camp_icon)
	if _has_claimable_camp_reward(): _add_notification_dot(btn_camp, btn_size)

	# Settings entry point with painted golden gear icon
	var btn_settings := g._button("", g.show_settings, Color("17363e"), btn_size)
	btn_settings.name = "SettingsButton"
	btn_settings.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var settings_icon := TextureRect.new()
	settings_icon.texture = load("res://assets/icons/nav_settings.png")
	settings_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	settings_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	settings_icon.custom_minimum_size = Vector2(24, 24)
	settings_icon.size = settings_icon.custom_minimum_size
	settings_icon.position = (btn_size - settings_icon.size) / 2.0
	settings_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_settings.add_child(settings_icon)

	var right_box := HBoxContainer.new()
	right_box.name = "HeaderRightBox"
	right_box.add_theme_constant_override("separation", 6)
	right_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right_box.alignment = BoxContainer.ALIGNMENT_END
	right_box.add_child(btn_quests)
	right_box.add_child(btn_camp)
	right_box.add_child(btn_settings)
	var lang_hdr: String = str(g.profile.get("language", "zh-Hans"))
	var is_cloud := SpiritSave.is_cloud_linked(g.profile)
	var login_text := ""
	var login_color: Color = g.JADE
	if not is_cloud:
		login_text = "登录" if lang_hdr.begins_with("zh") else "Login"
		login_color = Color("c4923e")
	else:
		var acc_name: String = str(g.profile.get("account", {}).get("name", "")).strip_edges()
		if acc_name.is_empty():
			acc_name = str(g.profile.get("account", {}).get("email", "")).split("@")[0]
		if acc_name.length() > 4:
			acc_name = acc_name.substr(0, 4)
		login_text = "☁️" + (acc_name if not acc_name.is_empty() else ("云端" if lang_hdr.begins_with("zh") else "Cloud"))
		login_color = g.JADE

	var btn_login := g._button(login_text, func():
		if is_cloud:
			g.show_settings()
		else:
			g.show_auth_modal(func(): g.show_map())
	, login_color, Vector2(56, btn_size.y))
	btn_login.name = "HeaderLoginBtn"
	btn_login.add_theme_font_size_override("font_size", 11)
	right_box.add_child(btn_login)
	header.add_child(right_box)
	header_holder.add_child(header)

	_add_map_right_rail(overlay_page)

	if g.current_map_chapter < 0 or g.current_map_chapter > int(g.profile.unlocked) / 5:
		g.current_map_chapter = int(g.profile.position) / 5

	var active_chapter: int = g.current_map_chapter
	g.map_canvas = Control.new()
	g.map_canvas.custom_minimum_size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
	g.map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	g.map_scroll.add_child(g.map_canvas)

	_add_map_chapter(active_chapter)
	_add_routes(active_chapter)
	for i in 5:
		_add_stage_pin(active_chapter * 5 + i)
	_add_map_ambience()

	g.traveler = Sprite2D.new()
	var current_hero: Dictionary = g.content.hero_class(str(g.profile.get("hero_class", "fox_spirit")))
	g.traveler.texture = g._get_character_texture(str(current_hero.get("sprite", "fox")))
	# Scaled off the actual loaded texture's width, not a hardcoded atlas-cell constant — a
	# standalone hero portrait (e.g. miasma_witch, 512px) isn't the same pixel size as an
	# atlas cell (341.33px) and would render at the wrong size against a fixed divisor.
	var traveler_tex_w: float = float(g.traveler.texture.get_width()) if g.traveler.texture else 341.33
	g.traveler.scale = Vector2(40.0 / traveler_tex_w, 40.0 / traveler_tex_w)
	if active_chapter == int(g.profile.position) / 5:
		g.traveler.position = _map_point(g.profile.position) - Vector2(0, 26)
		g.traveler.visible = true
	else:
		g.traveler.visible = false
	g.traveler.z_index = 25
	g.map_canvas.add_child(g.traveler)

	var t_idle := g.traveler.create_tween().set_loops()
	t_idle.tween_property(g.traveler, "position:y", g.traveler.position.y - 4.0, 0.75).set_trans(Tween.TRANS_SINE)
	t_idle.tween_property(g.traveler, "position:y", g.traveler.position.y + 2.0, 0.85).set_trans(Tween.TRANS_SINE)

	var dock_holder := MarginContainer.new()
	dock_holder.anchor_left = 0.0
	dock_holder.anchor_right = 1.0
	dock_holder.anchor_top = 1.0
	dock_holder.anchor_bottom = 1.0
	dock_holder.offset_left = 0.0
	dock_holder.offset_right = 0.0
	dock_holder.offset_top = -(float(g._safe_bottom()) + 60.0)
	dock_holder.offset_bottom = 0.0
	dock_holder.add_theme_constant_override("margin_bottom", g._safe_bottom())
	dock_holder.add_theme_constant_override("margin_left", 12)
	dock_holder.add_theme_constant_override("margin_right", 12)
	dock_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_page.add_child(dock_holder)

	var dock_bg := PanelContainer.new()
	dock_bg.add_theme_stylebox_override("panel", g._panel(Color(0.047, 0.102, 0.122, 0.94), 26, Color("1f404d")))
	dock_holder.add_child(dock_bg)

	var dock := HBoxContainer.new()
	dock.custom_minimum_size.y = 52
	dock.add_theme_constant_override("separation", 0)
	dock.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_bg.add_child(dock)

	# Each dock slot pairs a fancy rendered icon with the button's own text label pushed onto
	# a second line beneath it — the leading "\n" reserves that top line for the icon.
	var shop_unlocked: bool = int(g.profile.unlocked) >= 2
	var equip_unlocked: bool = int(g.profile.unlocked) >= 8 or g.profile.get("equipment_owned", []).size() > 0
	var trial_unlocked: bool = int(g.profile.unlocked) >= 6

	var items = [
		["nav_deck", "ui.deck_btn", g.show_deck, true, ""],
		["nav_equip", "ui.equip_btn", g.show_loadout, equip_unlocked, "ui.lock_equip_req"],
		["nav_trial", "ui.trial_btn", _open_camp_challenges, trial_unlocked, "ui.lock_trial_req"],
		["nav_shop", "ui.shop_btn", g.show_shop, shop_unlocked, "ui.lock_shop_req"],
		["nav_next", "ui.next_btn", _next_stage, true, ""]
	]

	for i in items.size():
		var item = items[i]
		var is_unlocked: bool = bool(item[3])
		var click_action: Callable = item[2]
		var lock_key: String = str(item[4])
		var btn := Button.new()
		if str(item[0]) == "nav_trial":
			btn.name = "MapTrialShortcutBtn"
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if g.font_cjk: btn.add_theme_font_override("font", g.font_cjk)
		btn.add_theme_font_size_override("font_size", 11)
		if is_unlocked:
			btn.text = "\n" + g.t(item[1])
			btn.add_theme_color_override("font_color", g.GOLD)
		else:
			btn.text = "🔒\n" + g.t(item[1])
			btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.7))
		var s := StyleBoxEmpty.new()
		var h := StyleBoxFlat.new(); h.bg_color = Color(1,1,1,0.05); h.corner_radius_bottom_left = 26 if i==0 else 0; h.corner_radius_top_left = 26 if i==0 else 0; h.corner_radius_bottom_right = 26 if i==items.size()-1 else 0; h.corner_radius_top_right = 26 if i==items.size()-1 else 0
		var p := h.duplicate(); p.bg_color = Color(1,1,1,0.1)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", h)
		btn.add_theme_stylebox_override("pressed", p)
		btn.add_theme_stylebox_override("focus", s)
		btn.pressed.connect(func():
			if is_unlocked or str(item[0]) == "nav_trial":
				click_action.call()
			else:
				g._toast("🔒 " + g.t(lock_key), g.MUTED)
		)

		var icon := TextureRect.new()
		var icon_tex: Texture2D = load("res://assets/icons/%s.png" % str(item[0]))
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.size = icon.custom_minimum_size
		icon.anchor_left = 0.5; icon.anchor_right = 0.5
		icon.offset_left = -12.0; icon.offset_right = 12.0
		icon.offset_top = 6.0; icon.offset_bottom = 30.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not is_unlocked:
			icon.modulate = Color(0.4, 0.4, 0.4, 0.5)
		btn.add_child(icon)

		# The deck slot gets the same "something to check in here" red dot whenever the
		# player owns a card copy that isn't in their current deck — cards obtained from a
		# reward chest or bought in the shop used to just sit in the collection unannounced.
		if str(item[0]) == "nav_deck" and _has_unused_cards():
			var dot := Panel.new()
			dot.name = "NotificationDot"
			dot.anchor_left = 1.0; dot.anchor_right = 1.0
			dot.anchor_top = 0.0; dot.anchor_bottom = 0.0
			dot.offset_left = -20.0; dot.offset_right = -7.0
			dot.offset_top = 6.0; dot.offset_bottom = 19.0
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.z_index = 5
			dot.add_theme_stylebox_override("panel", g._panel(g.EMBER, 7, Color("2b0a08")))
			btn.add_child(dot)

		dock.add_child(btn)

	if g.is_inside_tree() and g.get_tree():
		await g.get_tree().process_frame
	if g.map_scroll: g.map_scroll.scroll_vertical = 0

# Quick access to the two challenge modes (Daily Trial, Endless Abyss) — both already live as
# their own section in Camp's "挑战" tab, but reaching them meant Camp -> tab tap. The header
# row is already packed edge to edge (see the g.lang/music-toggle removal above), so this is a
# separate vertical rail on the right edge rather than more horizontal width at the top — the
# whole reason it's vertical is that it doesn't compete with the header for width at all.
# Icons dim (not hide) when the feature is still locked; tapping either one regardless of lock
# state goes straight to Camp's Challenges tab, which already renders the exact unlock
# requirement — no need to duplicate that text in a rail this narrow.
func _add_map_challenge_rail(parent: Control) -> void:
	var rail_holder := Control.new()
	rail_holder.anchor_left = 1.0
	rail_holder.anchor_right = 1.0
	rail_holder.anchor_top = 0.38
	rail_holder.anchor_bottom = 0.38
	rail_holder.offset_left = -50.0
	rail_holder.offset_right = -6.0
	rail_holder.offset_top = 0.0
	rail_holder.offset_bottom = 130.0
	rail_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_holder.z_index = 100
	parent.add_child(rail_holder)

	var rail := VBoxContainer.new()
	rail.name = "MapChallengeRail"
	rail.add_theme_constant_override("separation", 10)
	rail.mouse_filter = Control.MOUSE_FILTER_PASS
	rail_holder.add_child(rail)

	var rail_btn_size := Vector2(46, 46)
	var challenge_unlocked: bool = int(g.profile.unlocked) >= 6
	var challenge_btn := g._button("", _open_camp_challenges, Color("241a10"), rail_btn_size)
	challenge_btn.name = "MapTrialShortcutBtn"
	var challenge_icon := TextureRect.new()
	challenge_icon.texture = load("res://assets/icons/nav_trial.png")
	challenge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	challenge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	challenge_icon.custom_minimum_size = Vector2(34, 34)
	challenge_icon.size = challenge_icon.custom_minimum_size
	challenge_icon.position = (rail_btn_size - challenge_icon.size) / 2.0
	challenge_icon.modulate = Color.WHITE if challenge_unlocked else Color(0.4, 0.4, 0.4, 0.6)
	challenge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	challenge_btn.add_child(challenge_icon)
	rail.add_child(challenge_btn)

func _open_camp_challenges() -> void:
	g.camp_tab = "challenges"
	g.show_challenges()

# The road (and every stage pin — _map_point below places pins at these exact same points)
# has to trace the trail actually painted into this chapter's background, not an independent
# shape layered over it. Every chapter has its own unique background now, so CHAPTER_PATH_
# WAYPOINTS carries one hand-corrected, pixel-traced entry per chapter; g.BIOME_PATH_WAYPOINTS
# (with its old chapter%6-plus-mirroring scheme) only still applies to the theoretical case
# where a specific chapter's art file is missing and _get_chapter_map_texture() falls back to
# a reused biome texture — _add_map_chapter()'s own flip_h uses the identical condition below,
# so the two stay in lockstep.
func _chapter_waypoints(chapter: int) -> Array:
	if g._map_waypoint_cache.has(chapter): return g._map_waypoint_cache[chapter]
	var points: Array = []
	if _chapter_has_unique_art(chapter):
		for p in g.CHAPTER_PATH_WAYPOINTS[chapter]: points.append(p)
	else:
		var biome_idx: int = chapter % g.BIOME_PATH_WAYPOINTS.size()
		var flipped: bool = (chapter / g.BIOME_PATH_WAYPOINTS.size()) % 2 == 1
		for p in g.BIOME_PATH_WAYPOINTS[biome_idx]:
			var x: float = (g.MAP_WIDTH - p.x) if flipped else p.x
			points.append(Vector2(x, p.y))
	g._map_waypoint_cache[chapter] = points
	return points

func _chapter_has_unique_art(chapter: int) -> bool:
	return chapter >= 0 and chapter < g.CHAPTER_PATH_WAYPOINTS.size() and ResourceLoader.exists("res://assets/chapters/chapter_%d.png" % chapter)

func _map_point(index: int) -> Vector2:
	var waypoints: Array = _chapter_waypoints(index / 5)
	var node: Vector2 = waypoints[index % 5]
	return Vector2(node.x, node.y)

# Fits a smooth curve through exact waypoints (a Catmull-Rom-style spline expressed as
# per-point cubic Bezier handles) rather than the straight segments Line2D draws by default
# between raw points — this is what turns the trail from a zigzag into something that reads
# as a wandering path.
func _build_road_curve(points: PackedVector2Array) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = 6.0
	var n := points.size()
	for i in n:
		var prev: Vector2 = points[maxi(0, i - 1)]
		var next: Vector2 = points[mini(n - 1, i + 1)]
		var tangent: Vector2 = (next - prev) / 6.0
		var handle_in: Vector2 = Vector2.ZERO if i == 0 else -tangent
		var handle_out: Vector2 = Vector2.ZERO if i == n - 1 else tangent
		curve.add_point(points[i], handle_in, handle_out)
	return curve

# A small tileable dirt-road pattern generated at runtime — there is no bitmap art for a
# road, and FastNoiseLite's seamless output tiles along a Line2D's length for free.
func _get_road_texture() -> NoiseTexture2D:
	if g._road_texture != null: return g._road_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.12
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.generate_mipmaps = false
	tex.width = 64
	tex.height = 16
	tex.noise = noise
	g._road_texture = tex
	return tex

# A soft radial glow for the ambient particles — GradientTexture2D's radial fill gives a
# clean falloff with no bitmap asset.
func _get_mote_texture() -> GradientTexture2D:
	if g._mote_texture != null: return g._mote_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.9))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 24
	tex.height = 24
	g._mote_texture = tex
	return tex

# Fixed to the screen rather than the scrolling map canvas, so the atmosphere reads as
# weather over the whole view instead of specks pinned to particular map coordinates.
func _add_map_ambience() -> void:
	var current_chapter: int = g.current_map_chapter
	var biome_idx: int = current_chapter % 6

	var motes := CPUParticles2D.new()
	motes.name = "MapAmbienceParticles"
	motes.texture = _get_mote_texture()
	motes.position = Vector2(g.MAP_WIDTH / 2.0, 844.0 / 2.0)
	motes.amount = 24
	motes.lifetime = 6.5
	motes.preprocess = 6.5
	motes.emitting = not bool(g.profile.get("reduce_motion", false))
	motes.z_index = 90
	motes.local_coords = true
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(g.MAP_WIDTH / 2.0, 844.0 / 2.0)

	match biome_idx:
		0: # Mistwood: gentle green drifting spores
			motes.direction = Vector2(0.2, -1.0)
			motes.spread = 30.0
			motes.gravity = Vector2.ZERO
			motes.initial_velocity_min = 6.0
			motes.initial_velocity_max = 14.0
			motes.color = Color(0.70, 0.95, 0.80, 0.55)
		1: # Ashlands / Ember Canyon: warm rising fire sparks
			motes.direction = Vector2(0.1, -1.0)
			motes.spread = 20.0
			motes.gravity = Vector2(0, -10.0)
			motes.initial_velocity_min = 15.0
			motes.initial_velocity_max = 35.0
			motes.color = Color(1.0, 0.55, 0.22, 0.70)
		2: # Glacial Pass / Frost Peaks: falling snow crystals
			motes.direction = Vector2(0.15, 1.0)
			motes.spread = 40.0
			motes.gravity = Vector2(0, 14.0)
			motes.initial_velocity_min = 10.0
			motes.initial_velocity_max = 24.0
			motes.color = Color(0.85, 0.95, 1.0, 0.65)
		3: # Starfall Sanctuary: sparkling stardust
			motes.direction = Vector2(0.0, -0.5)
			motes.spread = 180.0
			motes.gravity = Vector2.ZERO
			motes.initial_velocity_min = 4.0
			motes.initial_velocity_max = 10.0
			motes.color = Color(0.95, 0.85, 1.0, 0.60)
		4: # Sunken Marsh: floating algae bubbles
			motes.direction = Vector2(-0.2, -1.0)
			motes.spread = 25.0
			motes.gravity = Vector2(0, -4.0)
			motes.initial_velocity_min = 5.0
			motes.initial_velocity_max = 12.0
			motes.color = Color(0.45, 0.92, 0.75, 0.55)
		5: # Abyssal Rift: void motes
			motes.direction = Vector2(0.0, -1.0)
			motes.spread = 35.0
			motes.gravity = Vector2(0, -8.0)
			motes.initial_velocity_min = 10.0
			motes.initial_velocity_max = 22.0
			motes.color = Color(0.75, 0.40, 1.0, 0.65)

	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.4

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.15, Color(1, 1, 1, 1.0))
	ramp.add_point(0.85, Color(1, 1, 1, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	motes.color_ramp = ramp
	g.root.add_child(motes)

func _fade_strip(height: float, flipped: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(g.BG.r, g.BG.g, g.BG.b, 1.0))
	gradient.set_color(1, Color(g.BG.r, g.BG.g, g.BG.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 4
	tex.height = 96
	tex.fill_from = Vector2(0, 1) if flipped else Vector2(0, 0)
	tex.fill_to = Vector2(0, 0) if flipped else Vector2(0, 1)
	var strip := TextureRect.new()
	strip.texture = tex
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.size = Vector2(g.MAP_WIDTH, height)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return strip

func _add_map_chapter(chapter: int) -> void:
	var tint: Color = g.CHAPTER_TINTS[chapter % g.CHAPTER_TINTS.size()]
	var band := Control.new()
	band.position = Vector2.ZERO
	band.size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
	band.custom_minimum_size = band.size
	band.clip_contents = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.map_canvas.add_child(band)

	# A painted gradient wash stands in for the old stock photography: it can never look
	# "pasted on" over the vector road, because it is built from the same vector language as
	# everything drawn on top of it, instead of a rectangle of unrelated pixels underneath it.
	var wash := TextureRect.new()
	wash.texture = _get_terrain_wash_texture(chapter % g.CHAPTER_TINTS.size())
	wash.size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(wash)

	var grain := TextureRect.new()
	grain.texture = _get_terrain_grain_texture()
	grain.size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
	grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode = TextureRect.STRETCH_TILE
	grain.modulate = Color(1, 1, 1, 0.14)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(grain)

	var biome_tex: Texture2D = _get_chapter_map_texture(chapter)
	if biome_tex != null:
		var painted_tile := TextureRect.new()
		painted_tile.texture = biome_tex
		painted_tile.size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
		painted_tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painted_tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		# Apply chapter-specific regional atmospheric tint. The alternating flip is only for
		# the old 6-image biome fallback (reusing one image across many chapters needed the
		# mirroring for visual variety); a chapter with its own unique art must never be
		# flipped, or g.CHAPTER_PATH_WAYPOINTS's pixel-traced points end up mirrored relative to
		# what's actually on screen — see _chapter_waypoints()'s matching condition.
		painted_tile.modulate = Color.WHITE.lerp(tint, 0.35)
		painted_tile.flip_h = false if _chapter_has_unique_art(chapter) else ((chapter / 6) % 2 == 1)
		painted_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(painted_tile)

	_add_terrain_dressing(band, chapter, tint)

	# Fade both seams into the page colour so consecutive chapters read as one continuous world.
	var top_fade := _fade_strip(84.0, false)
	band.add_child(top_fade)
	var bottom_fade := _fade_strip(84.0, true)
	bottom_fade.position = Vector2(0, g.BAND_HEIGHT - 84.0)
	band.add_child(bottom_fade)

	var locked: bool = chapter * 5 > int(g.profile.unlocked)
	# The chapter name used to sit inside a framed Panel with prev/next buttons either side;
	# both were dropped in favor of a left/right swipe to change chapters (see game.gd's
	# _input()), so the name now just floats over the painted art with a drop shadow for
	# legibility, matching the stage-pin captions' existing floating-text treatment.
	var plaque := Control.new()
	plaque.name = "ChapterPlaque"
	plaque.position = Vector2(g.MAP_WIDTH / 2.0 - 130.0, 78.0)
	plaque.size = Vector2(260, 52)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(plaque)

	var plaque_stack := VBoxContainer.new()
	plaque_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plaque_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	plaque_stack.add_theme_constant_override("separation", 0)
	plaque_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(plaque_stack)

	var plaque_eyebrow := g._label(g.tf("ui.chapter_title", chapter + 1), 11, tint if not locked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	plaque_eyebrow.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	plaque_eyebrow.add_theme_constant_override("shadow_offset_y", 1)
	plaque_stack.add_child(plaque_eyebrow)

	var plaque_name := g._label(g.content.chapter_name(chapter, g.lang), 15, g.TEXT if not locked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	plaque_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	plaque_name.add_theme_constant_override("shadow_offset_y", 1)
	plaque_stack.add_child(plaque_name)

	if g.current_map_chapter != int(g.profile.position) / 5:
		var back_curr_btn := g._button(g.t("ui.map_back_to_current"), func():
			g.current_map_chapter = int(g.profile.position) / 5
			show_map()
		, Color("1d4a40"), Vector2(100, 24))
		back_curr_btn.name = "MapBackToCurrentBtn"
		back_curr_btn.position = Vector2((g.MAP_WIDTH - 100.0) / 2.0, 134.0)
		band.add_child(back_curr_btn)

# Replaces the old ChapterPrevBtn/ChapterNextBtn pair: a left/right swipe anywhere on the map
# changes chapter instead. map_scroll tracks this drag regardless of allow_horizontal (see
# TouchScrollContainer.swipe_released), so this only has to read the delta and decide whether
# it crosses the same left/right-edge-swipe thresholds the interactive-back gesture uses. The
# bounds check below is also what stops a swipe from ever revealing a chapter that isn't
# unlocked yet — the same (chapter+1)*5 <= unlocked test the old ChapterNextBtn used, and
# swiping backward never needs a check at all, since chapters unlock in strict order so
# every chapter behind the current one is unlocked by definition.
func _on_map_swipe(delta: Vector2) -> void:
	if absf(delta.y) > 70.0 or _chapter_slide_active: return
	if delta.x <= -64.0 and (g.current_map_chapter + 1) * 5 <= int(g.profile.unlocked):
		_slide_to_chapter(g.current_map_chapter + 1, 1)
	elif delta.x >= 64.0 and g.current_map_chapter > 0:
		_slide_to_chapter(g.current_map_chapter - 1, -1)

# A swipe used to cut straight to show_map() for the new chapter. This instead builds both
# chapters' terrain+pins into two throwaway pages sitting side by side (dir=1 puts the target
# to the right, dir=-1 to the left) inside one wrapper, then pans the wrapper across so the
# old chapter rolls off screen as the new one rolls in. _add_map_chapter/_add_stage_pin only
# ever call g.map_canvas.add_child(...) — never read anything off it — so borrowing that one
# variable for two throwaway builds is enough to reuse them unmodified instead of threading a
# parent parameter through every call site. The transient wrapper is never explicitly freed:
# show_map()'s own _clear() (its first line) discards the entire old root, wrapper included,
# the same way it already discards everything else from the previous screen.
func _slide_to_chapter(target_chapter: int, dir: int) -> void:
	_chapter_slide_active = true
	var from_chapter: int = g.current_map_chapter
	var real_canvas: Control = g.map_canvas
	if g.map_scroll: g.map_scroll.visible = false

	var slide_wrapper := Control.new()
	slide_wrapper.name = "ChapterSlideWrapper"
	slide_wrapper.position = Vector2.ZERO
	slide_wrapper.size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
	slide_wrapper.clip_contents = true
	slide_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.root.add_child(slide_wrapper)

	var page_from := Control.new()
	page_from.size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
	page_from.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide_wrapper.add_child(page_from)

	var page_to := Control.new()
	page_to.position = Vector2(dir * g.MAP_WIDTH, 0)
	page_to.size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
	page_to.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide_wrapper.add_child(page_to)

	g.map_canvas = page_from
	_add_map_chapter(from_chapter)
	for i in 5:
		_add_stage_pin(from_chapter * 5 + i)

	g.map_canvas = page_to
	_add_map_chapter(target_chapter)
	for i in 5:
		_add_stage_pin(target_chapter * 5 + i)

	g.map_canvas = real_canvas

	# Both pages are full of real, tappable stage-pin buttons; block input for the ~0.3s the
	# slide takes so a tap mid-transition can't land on whichever page happens to be underneath.
	var blocker := Control.new()
	blocker.name = "ChapterSlideBlocker"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	g.root.add_child(blocker)

	var tween := g.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(slide_wrapper, "position:x", -dir * g.MAP_WIDTH, 0.32)
	await tween.finished

	_chapter_slide_active = false
	g.current_map_chapter = target_chapter
	show_map()

# A soft vertical gradient in the chapter's own tint, darker at the seams than in the middle —
# cached per tint index since there are only ten tints shared across fifty chapters.
func _get_terrain_wash_texture(tint_index: int) -> GradientTexture2D:
	if g._terrain_wash_cache.has(tint_index): return g._terrain_wash_cache[tint_index]
	var tint: Color = g.CHAPTER_TINTS[tint_index]
	var gradient := Gradient.new()
	gradient.set_color(0, tint.darkened(0.55))
	gradient.add_point(0.45, tint.darkened(0.2))
	gradient.add_point(0.55, tint.darkened(0.2))
	gradient.set_color(gradient.get_point_count() - 1, tint.darkened(0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 128
	g._terrain_wash_cache[tint_index] = tex
	return tex

# Low-frequency seamless noise, tiled at very low opacity over the wash so a band reads as
# painted terrain instead of a flat colour swatch. One instance is shared by every chapter.
func _get_terrain_grain_texture() -> NoiseTexture2D:
	if g._terrain_grain_texture != null: return g._terrain_grain_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.generate_mipmaps = false
	tex.width = 128
	tex.height = 128
	tex.noise = noise
	g._terrain_grain_texture = tex
	return tex

# Scatters a handful of small vector pine/boulder/hill silhouettes across the band, testing
# each candidate spot against the chapter's own baked road curve so nothing is ever placed on
# or overlapping the path — this is what makes the terrain read as belonging to the road
# instead of a picture that happens to have a line drawn over it.
func _add_terrain_dressing(band: Control, chapter: int, tint: Color) -> void:
	var waypoints: Array = _chapter_waypoints(chapter)
	var curve := _build_road_curve(PackedVector2Array(waypoints))
	var baked: PackedVector2Array = curve.get_baked_points()
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter * 51797 + 5
	var deco_color: Color = tint.darkened(0.1)
	var kinds := ["pine", "boulder", "hill"]
	var placed := 0
	var attempts := 0
	while placed < 9 and attempts < 60:
		attempts += 1
		var p := Vector2(rng.randf_range(20.0, g.MAP_WIDTH - 20.0), rng.randf_range(g.ROAD_TOP_CLEAR, g.BAND_HEIGHT - 40.0))
		var clear := true
		for bp in baked:
			if p.distance_to(bp) < 32.0: clear = false; break
		if not clear: continue
		var deco := GameIcon.new()
		deco.kind = kinds[rng.randi_range(0, kinds.size() - 1)]
		deco.icon_color = deco_color
		var deco_size: float = rng.randf_range(26.0, 46.0)
		deco.custom_minimum_size = Vector2(deco_size, deco_size)
		deco.size = deco.custom_minimum_size
		deco.pivot_offset = deco.size / 2.0
		deco.position = p - deco.size / 2.0
		deco.rotation = rng.randf_range(-0.12, 0.12)
		deco.modulate.a = rng.randf_range(0.2, 0.35)
		deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(deco)
		placed += 1

# A hand-drawn-looking jagged seam between every pair of consecutive chapters, on top of the
# soft fade already blending them — the reference art reads as distinct territories meeting
# at a border, not one image dissolving into the next.
func _add_region_borders(chapter_count: int) -> void:
	for chapter in chapter_count - 1:
		var y := float(chapter + 1) * g.BAND_HEIGHT
		var tint_a: Color = g.CHAPTER_TINTS[chapter % g.CHAPTER_TINTS.size()]
		var tint_b: Color = g.CHAPTER_TINTS[(chapter + 1) % g.CHAPTER_TINTS.size()]
		var rng := RandomNumberGenerator.new()
		rng.seed = chapter * 7307 + 3
		var pts := PackedVector2Array()
		var steps := 10
		for i in steps + 1:
			var x: float = g.MAP_WIDTH * float(i) / float(steps)
			var jitter: float = 0.0 if i == 0 or i == steps else rng.randf_range(-16.0, 16.0)
			pts.append(Vector2(x, y + jitter))
		var border := Line2D.new()
		border.points = pts
		border.width = 2.5
		border.default_color = tint_a.lerp(tint_b, 0.5).darkened(0.55)
		border.default_color.a = 0.6
		border.z_index = 0
		border.antialiased = true
		g.map_canvas.add_child(border)

# Straight segments between waypoints read as a mechanical zigzag; baking a Catmull-Rom
# curve through the exact same points gives a road that curves the way a real trail would,
# without moving where any stage pin actually sits.
func _add_routes(chapter: int = -1) -> void:
	if chapter < 0: chapter = g.current_map_chapter
	var all_points := PackedVector2Array()
	var walked_points := PackedVector2Array()
	var start_idx := chapter * 5
	for i in 5:
		var index := start_idx + i
		if index < g.content.encounters.size():
			var point := _map_point(index)
			all_points.append(point)
			if index <= int(g.profile.unlocked): walked_points.append(point)

	# road_bed/trail used to be the only visible "path" on the map — a generic dirt-textured
	# overlay that had no relationship to whatever was actually painted underneath it, which
	# is exactly what made pins and the drawn road alike sit over rocks/rooftops instead of
	# the real trail once unique per-chapter art existed. Now that g.CHAPTER_PATH_WAYPOINTS (see
	# _chapter_waypoints()) is pixel-traced to each chapter's real path, that overlay would
	# just be redundant at best and a mismatched line at worst — so both stay invisible. Their
	# geometry is kept (not skipped) since _travel_to()'s per-hop animation and any future
	# progress visualization still key off the same curve.
	var road_bed := Line2D.new()
	road_bed.width = 22.0
	road_bed.default_color = Color(0.16, 0.11, 0.07, 0.5)
	road_bed.z_index = 1
	road_bed.joint_mode = Line2D.LINE_JOINT_ROUND
	road_bed.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road_bed.end_cap_mode = Line2D.LINE_CAP_ROUND
	road_bed.points = _build_road_curve(all_points).get_baked_points()
	road_bed.visible = false
	g.map_canvas.add_child(road_bed)

	var trail := Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(0.62, 0.5, 0.34, 0.62)
	trail.texture = _get_road_texture()
	trail.texture_mode = Line2D.LINE_TEXTURE_TILE
	trail.z_index = 2
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.points = road_bed.points
	trail.visible = false
	g.map_canvas.add_child(trail)

	if walked_points.size() > 1:
		var walked := Line2D.new()
		walked.width = 6.0
		walked.default_color = Color(0.55, 0.93, 0.79, 0.85)
		walked.z_index = 3
		walked.joint_mode = Line2D.LINE_JOINT_ROUND
		walked.begin_cap_mode = Line2D.LINE_CAP_ROUND
		walked.end_cap_mode = Line2D.LINE_CAP_ROUND
		walked.points = _build_road_curve(walked_points).get_baked_points()
		walked.visible = false
		g.map_canvas.add_child(walked)

func _add_stage_pin(index: int) -> void:
	var encounter: Dictionary = g.content.encounters[index]
	var point := _map_point(index)
	var locked := index > int(g.profile.unlocked)
	var is_current := index == int(g.profile.position)
	var kind := g.get_node_kind(index)
	var is_boss := g.content.is_boss_kind(kind)
	var is_great: bool = kind == "greatboss"

	var pin_size := Vector2(62.0, 54.0)
	if is_boss: pin_size = Vector2(84.0, 72.0) if is_great else Vector2(72.0, 62.0)
	var bg_color := Color("18414a")
	var border_color := g.JADE
	match kind:
		"greatboss": bg_color = Color("6b1f1f"); border_color = Color("ff5a4a")
		"boss": bg_color = Color("5d2f1c"); border_color = g.GOLD
		"elite": bg_color = Color("46265c"); border_color = Color("c79bff")
		"merchant": bg_color = Color("21484f"); border_color = Color("7fd8e8")
		"rest": bg_color = Color("1f4a3c"); border_color = Color("8ff5cf")
		"event": bg_color = Color("2a4058"); border_color = Color("9fc2ff")
	if locked:
		bg_color = Color("16262a")
		border_color = Color("36474c")
	elif is_current:
		bg_color = Color("8c542a")
		border_color = g.EMBER

	# A map-marker reads as "planted at this exact spot" through a shadow on the ground and a
	# tail pointing down at it, not by centering a badge on the point — so the badge sits
	# above `point` and only the tail's tip actually touches it.
	var tail_height := 11.0
	var badge_bottom_y := point.y - tail_height

	var shadow := Panel.new()
	shadow.custom_minimum_size = Vector2(30.0, 9.0)
	shadow.size = shadow.custom_minimum_size
	shadow.position = point - shadow.size / 2.0
	shadow.z_index = 1
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", g._panel(Color(0, 0, 0, 0.4), 5))
	g.map_canvas.add_child(shadow)

	var tail := Polygon2D.new()
	var tail_half_w: float = pin_size.x * 0.15
	tail.polygon = PackedVector2Array([
		Vector2(point.x - tail_half_w, badge_bottom_y - 2.0),
		Vector2(point.x + tail_half_w, badge_bottom_y - 2.0),
		Vector2(point.x, point.y),
	])
	tail.color = bg_color
	tail.z_index = 9
	g.map_canvas.add_child(tail)

	var pin := Button.new()
	pin.custom_minimum_size = pin_size
	pin.size = pin_size
	pin.position = Vector2(point.x - pin_size.x / 2.0, badge_bottom_y - pin_size.y)
	pin.disabled = locked
	pin.z_index = 10
	pin.focus_mode = Control.FOCUS_NONE
	# Flat color styleboxes are gone now that the painted pin art below carries the kind's own
	# ring/color identity — kept as fully transparent fills (border still shows on hover/press
	# for touch feedback) rather than removed outright, so tapping still reads as responsive.
	pin.add_theme_stylebox_override("normal", g._panel(Color.TRANSPARENT, 16))
	pin.add_theme_stylebox_override("hover", g._panel(Color(1, 1, 1, 0.08), 16, g.EMBER))
	pin.add_theme_stylebox_override("pressed", g._panel(Color(1, 1, 1, 0.14), 16, g.GOLD))
	pin.add_theme_stylebox_override("disabled", g._panel(Color.TRANSPARENT, 16))
	g._bind_touch_guard(pin, func(): g._on_pin_pressed(index))
	g.map_canvas.add_child(pin)

	# Each node kind gets its own painted marker (pin_boss/pin_elite/pin_event/pin_greatboss/
	# pin_merchant/pin_normal/pin_rest.png — content.node_kind()'s own vocabulary, so no
	# separate mapping table) instead of the old flat badge + generic rune overlay + a
	# procedurally-drawn kind icon on top; the painted art already bakes in a kind-specific
	# ring and icon, so drawing the GameIcon shape over it would just double up. Falls back to
	# the generic map_pin_rune.png overlay on the old flat badge if a kind's art is missing.
	var pin_kind := "normal" if (kind == "battle" or kind == "normal" or kind == "") else kind
	var pin_art_path := "res://assets/icons/pin_%s.png" % pin_kind
	if not ResourceLoader.exists(pin_art_path): pin_art_path = "res://assets/icons/pin_normal.png"
	var pin_overlay := TextureRect.new()
	if ResourceLoader.exists(pin_art_path):
		pin_overlay.texture = load(pin_art_path)
		pin_overlay.modulate = Color(0.45, 0.45, 0.45, 0.7) if locked else Color.WHITE
	else:
		if g._map_pin_rune_tex == null: g._map_pin_rune_tex = load("res://assets/map_pin_rune.png")
		pin_overlay.texture = g._map_pin_rune_tex
		pin_overlay.modulate = Color(border_color.r, border_color.g, border_color.b, 0.75 if not locked else 0.35)
	pin_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pin_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(pin_overlay)

	var pin_stack := VBoxContainer.new()
	pin_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pin_stack.add_theme_constant_override("separation", -1)
	pin_stack.alignment = BoxContainer.ALIGNMENT_END
	pin_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(pin_stack)
	if locked:
		pin_stack.alignment = BoxContainer.ALIGNMENT_CENTER
		pin_stack.add_child(g._label("🔒", 12, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		# The number/rank labels sit in a small solid strip at the bottom of the badge — the
		# painted art behind them is busy enough that plain shadowed text (which is all this
		# used before) got hard to read once the flat single-color badge went away.
		var label_strip := PanelContainer.new()
		label_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_strip.add_theme_stylebox_override("panel", g._panel(Color(0, 0, 0, 0.4), 6))
		var label_pad := MarginContainer.new()
		for side in ["left", "right"]: label_pad.add_theme_constant_override("margin_%s" % side, 4)
		label_strip.add_child(label_pad)
		var label_stack := VBoxContainer.new()
		label_stack.add_theme_constant_override("separation", 0)
		label_pad.add_child(label_stack)
		label_stack.add_child(g._label("%d-%d" % [encounter.chapter, encounter.level], 13 if is_boss else 11, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		if is_boss:
			label_stack.add_child(g._label(g.t("ui.node_greatboss") if is_great else g.t("ui.node_boss"), 8, border_color, HORIZONTAL_ALIGNMENT_CENTER))
		pin_stack.add_child(label_strip)

	if is_current and not locked:
		var halo := pin.create_tween().set_loops()
		halo.tween_property(pin, "modulate", Color(1.25, 1.12, 0.95), 0.85).set_trans(Tween.TRANS_SINE)
		halo.tween_property(pin, "modulate", Color.WHITE, 0.85).set_trans(Tween.TRANS_SINE)

	var branch_options: Array[String] = g.content.node_branch_options(index)
	if branch_options.size() == 2 and not locked:
		var opt_meta := {
			"event":    {"icon": "📖", "name_zh": "奇遇", "name_en": "Story"},
			"merchant": {"icon": "🛒", "name_zh": "商人", "name_en": "Shop"},
			"elite":    {"icon": "⚔️", "name_zh": "精英", "name_en": "Elite"},
			"battle":   {"icon": "🗡️", "name_zh": "普通", "name_en": "Normal"},
			"rest":     {"icon": "🔥", "name_zh": "休憩", "name_en": "Rest"},
			"bonus":    {"icon": "✦",  "name_zh": "秘宝", "name_en": "Bonus"},
		}
		var is_zh: bool = str(g.profile.get("language", "zh-Hans")).begins_with("zh")
		var chosen_opt: String = str(g.profile.get("map_choices", {}).get(str(index), ""))

		var fork_pill := PanelContainer.new()
		fork_pill.name = "ForkPill_%d" % index
		fork_pill.z_index = 11
		var pill_style := g._panel(Color("0c1e24", 0.92), 10, g.GOLD if chosen_opt != "" else Color("2f6575"))
		pill_style.content_margin_left = 4
		pill_style.content_margin_right = 4
		pill_style.content_margin_top = 2
		pill_style.content_margin_bottom = 2
		fork_pill.add_theme_stylebox_override("panel", pill_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 3)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		fork_pill.add_child(hbox)

		for opt_idx in 2:
			var opt_key: String = branch_options[opt_idx]
			var m: Dictionary = opt_meta.get(opt_key, {"icon":"✦", "name_zh":opt_key, "name_en":opt_key})
			var is_selected := chosen_opt == opt_key
			var btn := Button.new()
			btn.text = "%s %s" % [m["icon"], m["name_zh"] if is_zh else m["name_en"]]
			btn.custom_minimum_size = Vector2(50, 18)
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 9)
			var btn_style := g._panel(Color("163b45") if is_selected else Color("0e2229"), 8, g.GOLD if is_selected else Color("22444e"))
			btn.add_theme_stylebox_override("normal", btn_style)
			btn.add_theme_stylebox_override("hover", g._panel(Color("225360"), 8, g.JADE))
			btn.add_theme_stylebox_override("pressed", g._panel(Color("2d6a7b"), 8, g.GOLD))
			btn.add_theme_color_override("font_color", g.GOLD if is_selected else Color(0.7, 0.82, 0.85))
			var captured_opt: String = opt_key
			g._bind_touch_guard(btn, func():
				g.make_map_choice(index, captured_opt)
				g.show_map()
				_travel_to(index)
			)
			hbox.add_child(btn)
			if opt_idx == 0:
				var fork_sym := Label.new()
				fork_sym.text = "⑂"
				fork_sym.add_theme_font_size_override("font_size", 10)
				fork_sym.add_theme_color_override("font_color", g.GOLD if chosen_opt != "" else g.JADE)
				fork_sym.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hbox.add_child(fork_sym)

		fork_pill.position = Vector2(point.x - 62.0, badge_bottom_y - pin_size.y - 23.0)
		g.map_canvas.add_child(fork_pill)

	var caption := g._label(g.content.waypoint_name(index % 5, g.lang) if not locked else g.t("ui.locked"), 10, g.TEXT if not locked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	# An outline, not a drop shadow: these captions sit directly on map terrain, which ranges from
	# near-black water to sunlit sand within a single 112px label, so there is no single ink that
	# works. Measured on the committed baseline, "未解锁" on locked pins read 2.07–2.98:1 against
	# the ground behind it (need 4.5:1). A 1px offset shadow only darkens below the glyph; an
	# outline darkens all of it, which is what a variable background needs.
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	caption.add_theme_constant_override("outline_size", 3)
	caption.size = Vector2(112.0, 16.0)
	caption.position = Vector2(point.x - 56.0, point.y + 6.0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.map_canvas.add_child(caption)

func _show_locked_node_intel(index: int) -> void:
	var modal := g._modal_dialog("MapNodeIntelModal", func():
		var ex: Node = g.overlay.get_node_or_null("MapNodeIntelModal")
		if ex: ex.queue_free()
	)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var pstyle := g._panel(Color("0c1a1f"), 14, g.GOLD)
	pstyle.content_margin_left = 16
	pstyle.content_margin_right = 16
	pstyle.content_margin_top = 14
	pstyle.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)

	var head := HBoxContainer.new()
	head.add_child(g._label(g.t("ui.map_intel_preview"), 14, g.GOLD))
	var close_btn := g._button("✕", func(): modal.queue_free(), Color("1c333a"), Vector2(30, 30))
	close_btn.name = "MapIntelCloseBtn"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	head.add_child(close_btn)
	list.add_child(head)

	var stage_num := "%d-%d" % [index / 5 + 1, index % 5 + 1]
	var stage_title := "%s (%s)" % [g.content.stage_name(index, g.lang), stage_num]
	list.add_child(g._label(stage_title, 12, Color("e3edf2"), HORIZONTAL_ALIGNMENT_CENTER))

	var encounter: Dictionary = g.content.encounters[index] if index < g.content.encounters.size() else {}
	if not encounter.is_empty():
		var enemy_name: String = str(encounter.get("name_en", encounter.name)) if g.lang == "en" else str(encounter.get("name", ""))
		var enemy_el: String = str(encounter.get("element", "wood"))
		var enemy_tier: int = int(encounter.get("tier", 1))

		var tier_name := "妖兽" if g.lang != "en" else "Monster"
		match enemy_tier:
			2: tier_name = "精英" if g.lang != "en" else "Elite"
			3: tier_name = "首领" if g.lang != "en" else "Boss"
			4: tier_name = "大境天灾" if g.lang != "en" else "World Calamity"

		var info_box := PanelContainer.new()
		var ib_style := g._panel(Color("071216"), 8, Color("20444c"))
		ib_style.content_margin_left = 10
		ib_style.content_margin_right = 10
		ib_style.content_margin_top = 8
		ib_style.content_margin_bottom = 8
		info_box.add_theme_stylebox_override("panel", ib_style)
		var ib_vbox := VBoxContainer.new()
		ib_vbox.add_theme_constant_override("separation", 4)
		info_box.add_child(ib_vbox)

		var el_name: String = g.t("element.%s" % enemy_el) if g.content.UI_TEXT.has("element.%s" % enemy_el) else enemy_el.capitalize()
		var enemy_line := "%s · %s [%s]" % [enemy_name, tier_name, el_name]
		ib_vbox.add_child(g._label(enemy_line, 11, g.EMBER, HORIZONTAL_ALIGNMENT_CENTER))

		var weakness: String = "water"
		match enemy_el:
			"fire": weakness = "water"
			"wood": weakness = "fire"
			"earth": weakness = "wood"
			"water": weakness = "thunder"
			"void": weakness = "spirit"
			"thunder", "gale", "wind": weakness = "stone"

		var rec_el_name: String = g.t("element.%s" % weakness) if g.content.UI_TEXT.has("element.%s" % weakness) else weakness.capitalize()
		var rec_line := "%s: %s" % [g.t("ui.map_intel_recommended"), rec_el_name]
		ib_vbox.add_child(g._label(rec_line, 10, Color("5ffbe2"), HORIZONTAL_ALIGNMENT_CENTER))

		var exp_reward := int(encounter.get("reward", 30))
		var rew_line := "预计收益: ~%d 金币 · 灵尘与卡牌机缘" % exp_reward if g.lang != "en" else "Rewards: ~%d Gold · Spirit Dust & Cards" % exp_reward
		ib_vbox.add_child(g._label(rew_line, 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		list.add_child(info_box)

	var locked_hint := g._label(g.t("ui.map_intel_locked"), 9, Color("e09252"), HORIZONTAL_ALIGNMENT_CENTER, true)
	list.add_child(locked_hint)

	var ok_btn := g._button(g.t("ui.confirm") if g.content.UI_TEXT.has("ui.confirm") else "OK", func(): modal.queue_free(), Color("1b3d45"), Vector2(0, 36))
	ok_btn.name = "MapIntelOkBtn"
	list.add_child(ok_btn)

const TOTAL_TRAVEL_SECONDS := 2.0
const TRAVEL_SECONDS_PER_STAGE := 2.0

# Walks the g.traveler stage by stage along the path's waypoints (_map_point).
# Total travel time is fixed to 2.0 seconds regardless of distance — so traveling across many
# stages covers intermediate waypoints quickly, and a single stage hop is slower and deliberate.
func _travel_to(index: int) -> void:
	if index > int(g.profile.unlocked):
		_show_locked_node_intel(index)
		return
	var start_index: int = int(g.profile.position)
	# The swipe gesture lets the player browse a chapter that has nothing to do with where
	# they actually stand — tapping the next-stage dock button (or a pin) while browsing one
	# of those doesn't mean "go from the chapter I'm looking at," it means "go from wherever
	# profile.position actually is." Snap the map back to that chapter and let it render before
	# the walk (hop-tween below, or show_chapter_transition() for a chapter crossing) starts,
	# or the walk plays out over whichever unrelated chapter's terrain/pins happened to be on
	# screen instead of the one the player is actually walking through.
	if g.current_map_chapter != start_index / 5:
		g.current_map_chapter = start_index / 5
		show_map()
		var pre_wait_generation: int = g.screen_generation
		await g.get_tree().create_timer(g._battle_delay(0.3)).timeout
		if g.screen_generation != pre_wait_generation: return
	# Captured here — after the resync snap-back above, whose own show_map() call is part of
	# this same travel, not an external navigation — so a mismatch from any point on below means
	# the player actually navigated elsewhere (tapped Camp/Quests/Settings/another pin) while
	# this coroutine was suspended, with no input lock preventing it during a 2-second (or,
	# across a chapter crossing, much longer) hop animation. Same shape as _resolve_play()'s
	# battle_session fix (see AGENTS.md's "fire-and-forget coroutine" trap) — this one guards
	# show_event()/begin_battle() from firing on whatever screen the player has moved to by the
	# time this resumes, since neither of those calls otherwise know the travel was abandoned.
	var generation: int = g.screen_generation
	if index == start_index:
		var kind := g.get_node_kind(index)
		# If this is a branch-able node and the player hasn't chosen yet, show the picker.
		var options: Array[String] = g.content.node_branch_options(index)
		if options.size() == 2 and not g.profile.get("map_choices", {}).has(str(index)):
			_show_branch_picker(index, options)
			return
		if kind in ["event","merchant","rest","bonus"] and not g._is_stage_event_claimed(index) and not g._is_replay(index):
			g.show_event(index, kind)
		else:
			if not g.can_spend_stamina(5):
				g._toast(g.t("ui.stamina_insufficient"))
				g.show_stamina_modal()
				return
			g.spend_stamina(5)
			g.begin_battle(index)
		return

	if start_index / 5 != index / 5:
		# Crossing into a new chapter only ever happens by winning the old chapter's boss
		# (_grant_stage_rewards() unlocks exactly the new chapter's stage 0, nothing further),
		# so index here is always that chapter's first stage and show_chapter_transition()'s
		# "walk onto next_ch's waypoint 0" animation always matches the real target. This used
		# to jump straight to show_map() + begin_battle with no animation at all; now the walk
		# only plays once the player actually asks to go there (tapping the next-stage dock
		# button or the new chapter's stage-0 pin), not automatically the instant the boss dies.
		# No screen_generation guard needed here (unlike the two branches below): show_chapter_
		# transition() already calls g._clear() itself as its very first line, which would make
		# a captured-before-the-call generation value stale even in the ordinary case — and it
		# already has its own, correct protection against exactly this race (is_instance_valid()
		# checks on transition_layer/pin_container right after its own animation await, added
		# for the freed-node crash this same gap used to cause — see that function's comment).
		# If those nodes were freed by an external _clear() mid-animation, it returns before
		# ever reaching _finish_chapter_transition(), so enter_next below never fires stale.
		var enter_next := func():
			var kind := g.get_node_kind(index)
			var opts: Array[String] = g.content.node_branch_options(index)
			if opts.size() == 2 and not g.profile.get("map_choices", {}).has(str(index)):
				_show_branch_picker(index, opts)
				return
			if kind in ["event","merchant","rest","bonus"] and not g._is_stage_event_claimed(index) and not g._is_replay(index):
				g.show_event(index, kind)
			else:
				if not g.can_spend_stamina(5):
					g._toast(g.t("ui.stamina_insufficient"))
					g.show_stamina_modal()
					return
				g.spend_stamina(5)
				g.begin_battle(index)
		show_chapter_transition(start_index / 5, index / 5, enter_next)
		return

	var hop_count: int = maxi(1, absi(index - start_index))
	var hop_duration: float = TOTAL_TRAVEL_SECONDS / float(hop_count)
	var step: int = 1 if index >= start_index else -1
	var tween := g.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var scroll_from: float = float(g.map_scroll.scroll_vertical) if g.map_scroll else 0.0
	var current_idx := start_index
	while current_idx != index:
		current_idx += step
		var hop_pos: Vector2 = _map_point(current_idx) - Vector2(0, 26)
		var scroll_to: float = float(maxi(0, int(_map_point(current_idx).y - 360)))
		if g.traveler:
			tween.tween_property(g.traveler, "position", hop_pos, hop_duration)
		if g.map_scroll:
			tween.parallel().tween_method(func(y): if g.map_scroll: g.map_scroll.scroll_vertical = int(y), scroll_from, scroll_to, hop_duration)
		scroll_from = scroll_to
	await tween.finished
	if g.screen_generation != generation: return
	g.profile.position = index; SpiritSave.write(g.profile)
	var kind := g.get_node_kind(index)
	var opts: Array[String] = g.content.node_branch_options(index)
	if opts.size() == 2 and not g.profile.get("map_choices", {}).has(str(index)):
		_show_branch_picker(index, opts)
		return
	if kind in ["event","merchant","rest","bonus"] and not g._is_stage_event_claimed(index) and not g._is_replay(index):
		g.show_event(index, kind)
	else:
		if not g.can_spend_stamina(5):
			g._toast(g.t("ui.stamina_insufficient"))
			g.show_stamina_modal()
			return
		g.spend_stamina(5)
		g.begin_battle(index)

func _next_stage() -> void:
	if int(g.profile.position) < int(g.profile.unlocked): _travel_to(int(g.profile.position)+1)
	else: _travel_to(int(g.profile.position))

# Shown when the player arrives at a branch-able node (levels 2, 3, 4) that has no saved
# choice yet.  Two side-by-side cards let the player pick a path; the choice is persisted
# immediately and the node is then entered normally.
func _show_branch_picker(index: int, options: Array[String]) -> void:
	# Remove any existing picker (safety guard against double-tap or re-entry).
	var existing: Node = g.overlay.get_node_or_null("BranchPicker")
	if existing: existing.queue_free()

	# Metadata for each option type.
	var meta := {
		"event":    {"icon": "📖", "name_zh": "奇遇事件", "name_en": "Story Event",    "desc_zh": "随机触发奇遇，获得意外收益或面对风险。", "desc_en": "A random story event — rewards or risks await."},
		"merchant": {"icon": "🛒", "name_zh": "灵石商人", "name_en": "Merchant",        "desc_zh": "用金币购买卡牌、遗物或符文。",             "desc_en": "Spend gold on cards, relics, or runes."},
		"elite":    {"icon": "⚔️", "name_zh": "精英战斗", "name_en": "Elite Battle",    "desc_zh": "更强大的敌人，但击败可得稀有奖励。",       "desc_en": "A tougher foe with rare rewards on victory."},
		"battle":   {"icon": "🗡️", "name_zh": "普通战斗", "name_en": "Normal Battle",   "desc_zh": "与普通敌人战斗，稳中求进。",               "desc_en": "A standard fight — steady progress."},
		"rest":     {"icon": "🔥", "name_zh": "篝火休憩", "name_en": "Campfire Rest",   "desc_zh": "点燃篝火，恢复 25 点生命值。",             "desc_en": "Rest at a campfire and restore 25 HP."},
		"bonus":    {"icon": "🎴", "name_zh": "额外奖励", "name_en": "Bonus Draft",     "desc_zh": "跳过休憩，从三张牌中再挑选一张加入牌组。", "desc_en": "Skip rest — draft one extra card instead."},
	}
	var lang := str(g.profile.get("language", "zh-Hans"))
	var is_zh := lang.begins_with("zh")

	# Bring overlay to top so modal receives all touches ahead of underlying map
	if g.root and g.overlay:
		g.root.move_child(g.overlay, g.root.get_child_count() - 1)

	# Semi-transparent backdrop.
	var backdrop := ColorRect.new()
	backdrop.name = "BranchPicker"
	backdrop.color = Color(0, 0, 0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	g.overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)

	# Centre column.
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(340, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	# Title.
	var title := Label.new()
	title.text = "选择路径" if is_zh else "Choose Your Path"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", g.GOLD)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "两条路只能走一条，一旦选择无法更改" if is_zh else "Choose once — you cannot change later"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	col.add_child(sub)

	# Two option cards side by side.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	for opt in options:
		var m: Dictionary = meta.get(opt, {"icon":"❓","name_zh":opt,"name_en":opt,"desc_zh":"","desc_en":""})
		var card := Button.new()
		card.custom_minimum_size = Vector2(154, 196)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal",  g._panel(Color("1a3a42"), 14, Color("3a7a8a")))
		card.add_theme_stylebox_override("hover",   g._panel(Color("1e4d58"), 14, g.JADE))
		card.add_theme_stylebox_override("pressed", g._panel(Color("2a5f6a"), 14, g.GOLD))
		row.add_child(card)

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vbox)

		var icon_lbl := Label.new()
		icon_lbl.text = m["icon"]
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 30)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = m["name_zh"] if is_zh else m["name_en"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", g.GOLD)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = m["desc_zh"] if is_zh else m["desc_en"]
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.85))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_lbl)

		# Capture opt by value — GDScript lambdas close over variables, not values.
		var chosen_kind: String = opt
		var select_option := func():
			# Persist choice, dismiss picker, re-render pin, then dispatch.
			g.make_map_choice(index, chosen_kind)
			if g.profile.get("relics", []).has("spiritCompass"):
				g.profile.gold = int(g.profile.get("gold", 0)) + 15
				g._toast("寻灵罗盘：获得 15 金币！" if is_zh else "Spirit Compass: +15 Gold!", g.GOLD)
			if backdrop.is_inside_tree(): backdrop.queue_free()
			# Re-render the map pin so it shows the resolved kind immediately.
			g.show_map()
			# Then dispatch into the chosen node kind.
			await g.get_tree().create_timer(0.1).timeout
			var resolved_kind := g.get_node_kind(index)
			if resolved_kind in ["event","merchant","rest","bonus"] and not g._is_stage_event_claimed(index):
				g.show_event(index, resolved_kind)
			else:
				if not g.can_spend_stamina(5):
					g._toast(g.t("ui.stamina_insufficient"))
					g.show_stamina_modal()
					return
				g.spend_stamina(5)
				g.begin_battle(index)

		card.pressed.connect(select_option)

func show_chapter_transition(cleared_ch: int, next_ch: int, on_complete := Callable()) -> void:
	g._clear(); g._play_music(false)
	g._back_action = Callable()

	var bg_black := ColorRect.new()
	bg_black.color = Color(0.02, 0.04, 0.06)
	bg_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_black.mouse_filter = Control.MOUSE_FILTER_PASS
	g.root.add_child(bg_black)

	var transition_layer := Control.new()
	transition_layer.name = "ChapterTransitionLayer"
	transition_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.root.add_child(transition_layer)

	var safe_next_ch: int = mini(next_ch, 49)

	# Next chapter map illustration preview
	var map_preview := TextureRect.new()
	map_preview.texture = _get_chapter_map_texture(safe_next_ch)
	map_preview.custom_minimum_size = Vector2(g.MAP_WIDTH, g.BAND_HEIGHT)
	map_preview.size = map_preview.custom_minimum_size
	map_preview.position = Vector2.ZERO
	map_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_preview.modulate.a = 0.0
	transition_layer.add_child(map_preview)

	# Chapter atmosphere motes
	var motes := CPUParticles2D.new()
	motes.texture = _get_mote_texture()
	motes.position = Vector2(g.MAP_WIDTH / 2.0, 844.0 / 2.0)
	motes.amount = 26
	motes.lifetime = 4.0
	motes.preprocess = 2.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(g.MAP_WIDTH / 2.0, 844.0 / 2.0)
	motes.direction = Vector2(0, -1)
	motes.spread = 45.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 12.0
	motes.initial_velocity_max = 30.0
	motes.color = Color(1.0, 0.88, 0.55, 0.6)
	transition_layer.add_child(motes)

	# Header plaque with chapter titles
	var title_box := VBoxContainer.new()
	title_box.position = Vector2(20.0, float(g._safe_top()) + 24.0)
	title_box.size = Vector2(g.MAP_WIDTH - 40.0, 110.0)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 6)
	transition_layer.add_child(title_box)

	var cleared_lbl := g._label(g.tf("ui.chapter_cleared_title", cleared_ch + 1), 13, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title_box.add_child(cleared_lbl)

	var next_ch_name: String = g.content.chapter_name(safe_next_ch, g.lang)
	var new_ch_lbl := g._label(g.tf("ui.chapter_title", safe_next_ch + 1) + " · " + next_ch_name, 22, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title_box.add_child(new_ch_lbl)

	var sub_lbl := g._label(g.t("ui.entering_new_realm"), 12, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	title_box.add_child(sub_lbl)

	# Target stage 1 waypoint of the new chapter
	var waypoints: Array = _chapter_waypoints(safe_next_ch)
	var wp0: Vector2 = waypoints[0]
	var target_pos: Vector2 = map_preview.position + wp0

	# Waypoint 0 Stage Pin
	var pin_container := Control.new()
	pin_container.position = target_pos
	transition_layer.add_child(pin_container)

	var pin_badge := TextureRect.new()
	pin_badge.custom_minimum_size = Vector2(62, 54)
	pin_badge.size = pin_badge.custom_minimum_size
	pin_badge.position = Vector2(-31, -54)
	var pin_art_path := "res://assets/icons/pin_normal.png"
	if ResourceLoader.exists(pin_art_path):
		pin_badge.texture = load(pin_art_path)
	pin_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pin_badge.modulate.a = 0.0
	pin_container.add_child(pin_badge)

	var pin_lbl := g._label("%d-1" % (safe_next_ch + 1), 11, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pin_lbl.position = Vector2(-31, -26)
	pin_lbl.size = Vector2(62, 18)
	pin_lbl.modulate.a = 0.0
	pin_container.add_child(pin_lbl)

	# Traveler (Hero sprite)
	var hero_data: Dictionary = g.content.hero_class(str(g.profile.get("hero_class", "fox_spirit")))
	var traveler_spr := Sprite2D.new()
	traveler_spr.texture = g._get_character_texture(str(hero_data.get("sprite", "fox")))
	var tex_w: float = float(traveler_spr.texture.get_width()) if traveler_spr.texture else 341.33
	traveler_spr.scale = Vector2(42.0 / tex_w, 42.0 / tex_w)
	traveler_spr.z_index = 30
	var start_offset := Vector2(-75, 80)
	if wp0.x < 120: start_offset = Vector2(75, 80)
	var start_pos: Vector2 = target_pos + start_offset
	traveler_spr.position = start_pos
	traveler_spr.modulate = Color(1.3, 1.3, 1.3, 0.0)
	transition_layer.add_child(traveler_spr)

	# Touch-to-skip backdrop button
	var is_finished := [false]
	var finish_cb := func():
		if is_finished[0]: return
		is_finished[0] = true
		_finish_chapter_transition(safe_next_ch, on_complete)

	var screen_btn := Button.new()
	screen_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_btn.flat = true
	screen_btn.focus_mode = Control.FOCUS_NONE
	screen_btn.pressed.connect(finish_cb)
	transition_layer.add_child(screen_btn)
	transition_layer.move_child(screen_btn, 0)

	# Skip button at top right
	var skip_btn := g._button(g.t("ui.transition_skip"), finish_cb, Color(0.15, 0.2, 0.25, 0.8), Vector2(80, 32))
	skip_btn.name = "ChapterTransitionSkipBtn"
	skip_btn.anchor_left = 1.0
	skip_btn.anchor_right = 1.0
	skip_btn.anchor_top = 0.0
	skip_btn.anchor_bottom = 0.0
	skip_btn.offset_left = -96.0
	skip_btn.offset_right = -16.0
	skip_btn.offset_top = float(g._safe_top()) + 16.0
	skip_btn.offset_bottom = float(g._safe_top()) + 48.0
	transition_layer.add_child(skip_btn)

	# Animate the cutscene sequence!
	var seq := g.create_tween()
	seq.tween_property(map_preview, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	seq.parallel().tween_property(pin_badge, "modulate:a", 1.0, 0.6)
	seq.parallel().tween_property(pin_lbl, "modulate:a", 1.0, 0.6)
	seq.parallel().tween_property(traveler_spr, "modulate:a", 1.0, 0.4)

	var walk_dest: Vector2 = target_pos - Vector2(0, 26)
	seq.tween_property(traveler_spr, "position", walk_dest, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var bob_tween := traveler_spr.create_tween().set_loops()
	bob_tween.tween_property(traveler_spr, "scale:y", 38.0 / tex_w, 0.18).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(traveler_spr, "scale:y", 44.0 / tex_w, 0.18).set_trans(Tween.TRANS_SINE)

	await seq.finished
	if bob_tween.is_valid(): bob_tween.kill()

	# show_chapter_transition() is deliberately fire-and-forget (its one caller,
	# _finish_reward(), doesn't await it — the cutscene is meant to play out in the
	# background, not block anything), so by the time this ~2.2s tween sequence actually
	# finishes, something completely unrelated may have already rebuilt the screen (a
	# different show_X() call elsewhere runs g._clear(), which frees transition_layer and
	# everything under it, including pin_container). is_finished[0] alone doesn't catch this
	# — it's only set by this function's own finish_cb, never by an external _clear() — so
	# this coroutine must also check its own nodes are still alive before touching them.
	if not is_instance_valid(transition_layer) or not is_instance_valid(pin_container):
		return

	if not is_finished[0]:
		g._haptic("heavy")
		var pop := pin_container.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(pin_container, "scale", Vector2(1.2, 1.2), 0.15)
		pop.tween_property(pin_container, "scale", Vector2.ONE, 0.15)
		g._toast(g.tf("ui.chapter_enter_toast", next_ch_name), g.GOLD)
		await g.get_tree().create_timer(g._battle_delay(0.8)).timeout
		finish_cb.call()

func _finish_chapter_transition(next_ch: int, on_complete: Callable) -> void:
	g.current_map_chapter = next_ch
	g.profile.position = next_ch * 5
	g.profile.unlocked = maxi(int(g.profile.unlocked), next_ch * 5)
	SpiritSave.write(g.profile)
	if on_complete.is_valid():
		on_complete.call()
	else:
		show_map()

