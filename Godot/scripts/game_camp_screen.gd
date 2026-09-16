extends RefCounted
class_name CampScreen

# Composition, not inheritance — see MapScreen's header comment (game_map_screen.gd) for
# why. `g` is the live SpiritGame instance; every reference to shared state or another
# screen's function goes through it.
var g: SpiritGame

func _init(game: SpiritGame) -> void:
	g = game

func show_compendium() -> void:
	g._clear(); g._play_music(false)
	g._back_action = show_camp
	var page := g._create_page(6)
	page.add_child(g._header(g.t("ui.compendium_title"), g.t("ui.compendium_sub"), show_camp))
	var totals := g._compendium_totals()
	var pct: int = int(round(float(totals.x) / float(maxi(1, totals.y)) * 100.0))
	page.add_child(_build_compendium_milestones_bar(pct))
	page.add_child(g._tab_bar([
		["cards", g.t("ui.compendium_tab_cards")],
		["gear", g.t("ui.compendium_tab_gear")],
		["runes", g.t("ui.tab_runes")],
		["relics", g.t("ui.relic_title")],
		["bestiary", g.t("ui.compendium_tab_bestiary")],
		["achievements", g.t("ui.compendium_tab_achievements")],
	], g.compendium_tab, func(id): g.compendium_tab = id; show_compendium()))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	match g.compendium_tab:
		"cards": _build_compendium_cards(list)
		"gear": _build_compendium_equipment(list)
		"runes": _build_compendium_runes(list)
		"relics": _build_compendium_relics(list)
		"bestiary": _build_compendium_bestiary(list)
		_: _build_compendium_achievements(list)

func _build_compendium_milestones_bar(pct: int) -> Control:
	var bar_panel := PanelContainer.new()
	bar_panel.name = "CompendiumMilestonesBar"
	bar_panel.custom_minimum_size = Vector2(0, 56)
	bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_panel.add_theme_stylebox_override("panel", g._panel(Color("10221c"), 12, Color("356554")))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 6)
	bar_panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	pad.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.add_child(g._label(g.t("ui.compendium_milestones_title"), 10, g.JADE))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title_row.add_child(sp)
	title_row.add_child(g._label("%d%%" % pct, 10, g.GOLD))
	stack.add_child(title_row)

	var btns_row := HBoxContainer.new()
	btns_row.add_theme_constant_override("separation", 6)
	stack.add_child(btns_row)

	var claimed: Array = g.profile.get("compendium_milestones_claimed", [])
	for target in [50, 80, 100]:
		var is_claimed: bool = claimed.has(target)
		var is_ready: bool = pct >= target and not is_claimed
		var text_str: String = "✓ %d%%" % target if is_claimed else (g.tf("ui.compendium_milestone_btn_fmt", target) if is_ready else "🔒 %d%%" % target)
		var btn := g._button(text_str, func(): _claim_compendium_milestone(target), g.GOLD if is_ready else Color("1a352c"), Vector2(0, 26))
		btn.name = "MilestoneBtn_%d" % target
		btn.disabled = not is_ready
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns_row.add_child(btn)

	return bar_panel

func _claim_compendium_milestone(target: int) -> void:
	var claimed: Array = g.profile.get("compendium_milestones_claimed", []).duplicate()
	if claimed.has(target): return
	claimed.append(target)
	g.profile.compendium_milestones_claimed = claimed
	var gold_reward: int = 200 if target == 50 else (500 if target == 80 else 1000)
	g.profile.gold += gold_reward
	if target >= 50:
		g._grant_mastery_xp(100)
	SpiritSave.write(g.profile)
	g._toast(g.tf("ui.compendium_milestone_toast", target), g.GOLD)
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
	panel.add_theme_stylebox_override("panel", g._panel(Color("13282e") if discovered else Color("0e191d"), 12, border))

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
	texts.add_child(g._label(title if discovered else g.t("ui.compendium_locked"), 13, g.TEXT if discovered else g.MUTED))
	if discovered and not detail.is_empty():
		var detail_lbl := g._label(detail, 9, g.JADE, HORIZONTAL_ALIGNMENT_LEFT, true)
		detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(detail_lbl)

	return panel

func _compendium_locked_badge() -> Control:
	return g._icon_badge("?", Color("3c5057"), 46, 20)

func _build_compendium_cards(list: VBoxContainer) -> void:
	var totals := g._compendium_totals()
	list.add_child(g._label(g.tf("ui.compendium_progress", [totals.x, totals.y]), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	# Curse cards (decay_blight, void_curse) are enemy-inflicted battle hazards, never something
	# a player collects — showing them here would be a permanently "undiscovered" entry with no
	# way to ever complete it.
	for card in g.content.cards.filter(func(c): return c.get("rarity", "") != "Curse"):
		var discovered := g._card_discovered(card.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = g._card_art_panel(card.id, Vector2(44, 60))
		var detail := "%s · %s" % [g.t("kind.%s" % card.get("kind", "Skill")), g._card_description(card)]
		list.add_child(_compendium_row(badge, g.content.text(card.nameKey, g.lang), detail, discovered, g._card_color(card)))

func _build_compendium_equipment(list: VBoxContainer) -> void:
	for item in SpiritContent.EQUIPMENT:
		var discovered := g._equip_discovered(item.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = g._equip_icon_badge(item, g.GOLD, 46)
		list.add_child(_compendium_row(badge, g._equip_name(item), g._equip_detail(item), discovered, g.GOLD))

func _build_compendium_runes(list: VBoxContainer) -> void:
	for rune in SpiritContent.RUNES:
		var discovered := g._rune_discovered(rune.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = g._rune_icon_badge(rune, Color(rune.color), 46)
		list.add_child(_compendium_row(badge, g._rune_name(rune), g._rune_detail(rune), discovered, Color(rune.color)))

func _build_compendium_relics(list: VBoxContainer) -> void:
	for relic in SpiritContent.RELICS:
		var discovered := g._relic_discovered(relic.id)
		var badge: Control = _compendium_locked_badge()
		if discovered: badge = g._relic_icon_badge(relic, Color(relic.color), 46)
		list.add_child(_compendium_row(badge, g._relic_name(relic), g._relic_detail(relic), discovered, Color(relic.color)))

func _build_compendium_bestiary(list: VBoxContainer) -> void:
	for enemy in SpiritContent.ENEMIES:
		var discovered := g._bestiary_discovered(str(enemy.name))
		var name_str: String = str(enemy.name_en) if g.lang == "en" else str(enemy.name)
		var badge: Control
		if discovered:
			var tex := TextureRect.new()
			tex.texture = g._get_character_texture(g._art_key_for_enemy(enemy))
			tex.custom_minimum_size = Vector2(46, 46)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			badge = tex
		else:
			badge = _compendium_locked_badge()
		list.add_child(_compendium_row(badge, name_str, g.content.enemy_lore(enemy, g.lang), discovered, Color(enemy.get("tint", "83e4c1"))))

func _build_compendium_achievements(list: VBoxContainer) -> void:
	if not g.profile.get("achievements_unlocked") is Dictionary: g.profile.achievements_unlocked = {}
	var unlocked_n := 0
	for ach in SpiritContent.ACHIEVEMENTS:
		if bool(g.profile.achievements_unlocked.get(str(ach.id), false)): unlocked_n += 1
	list.add_child(g._label(g.tf("ui.compendium_progress", [unlocked_n, SpiritContent.ACHIEVEMENTS.size()]), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	for ach in SpiritContent.ACHIEVEMENTS:
		var id: String = str(ach.id)
		var unlocked: bool = bool(g.profile.achievements_unlocked.get(id, false))
		var progress: int = mini(int(ach.target), g._achievement_progress(ach))
		var accent: Color = g.GOLD if unlocked else Color("2a3d42")

		var panel := Panel.new()
		panel.custom_minimum_size.y = 90
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", g._panel(Color("13282e") if unlocked else Color("0e191d"), 12, accent))
		list.add_child(panel)

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 12)
		panel.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		pad.add_child(row)

		var badge_holder := CenterContainer.new()
		badge_holder.custom_minimum_size = Vector2(44, 44)
		var badge_tex := TextureRect.new()
		badge_tex.texture = load("res://assets/icons/badge_%s.png" % str(ach.get("tier", "bronze")))
		badge_tex.custom_minimum_size = Vector2(40, 40)
		badge_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked: badge_tex.modulate = Color(0.5, 0.5, 0.5, 0.5)
		badge_holder.add_child(badge_tex)
		row.add_child(badge_holder)

		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 4)
		row.add_child(texts)

		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		texts.add_child(title_row)
		title_row.add_child(g._label(g.content.ui(ach.nameKey, g.lang), 13, g.TEXT if unlocked else g.MUTED))
		if unlocked:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title_row.add_child(spacer)
			title_row.add_child(g._label("✦", 13, g.GOLD))

		texts.add_child(g._label(g.content.ui(ach.descKey, g.lang), 10, g.JADE if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		if not unlocked:
			var bar := g._stat_bar(120.0, 14.0, progress, int(ach.target), g.GOLD, "%d / %d" % [progress, int(ach.target)], 9)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texts.add_child(bar)

func _equip(item: Dictionary) -> void:
	if g.profile.equipment_slots.get(item.slot,"") == item.id: g.profile.equipment_slots.erase(item.slot)
	else: g.profile.equipment_slots[item.slot] = item.id
	SpiritSave.write(g.profile); g.show_loadout()

func _socket(card_id: String) -> void:
	if g.selected_rune.is_empty(): g._toast(g.t("ui.loadout_select_first")); return
	var available: int = int(g.profile.rune_inventory.get(g.selected_rune,0)) - g.profile.card_runes.values().count(g.selected_rune)
	if available <= 0: return
	g.profile.card_runes[card_id] = g.selected_rune; SpiritSave.write(g.profile); g.selected_rune=""; g.show_loadout()

func _format_countdown(target_unix: int) -> String:
	var remaining: int = maxi(0, target_unix - int(Time.get_unix_time_from_system()))
	var hours := remaining / 3600
	if hours >= 24:
		var days := hours / 24
		return "%dd" % days if g.lang == "en" else "%d天" % days
	var minutes := (remaining % 3600) / 60
	return "%dh%02dm" % [hours, minutes] if g.lang == "en" else "%d时%02d分" % [hours, minutes]

func _quest_section(title: String, list_name: String, reset_at: int) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	section.add_child(head)
	head.add_child(g._label(title, 14, g.JADE))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(g._label(g.tf("ui.quests_daily_reset", _format_countdown(reset_at)), 9, g.MUTED))

	var quests: Array = g.profile.get(list_name, [])
	for entry in quests:
		var quest := g.content.quest_by_id(str(entry.get("id", "")))
		if quest.is_empty(): continue
		var progress := int(entry.get("progress", 0))
		var target := int(entry.get("target", 1))
		var claimed := bool(entry.get("claimed", false))
		var done := progress >= target

		var row := Panel.new()
		row.custom_minimum_size.y = 60
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("panel", g._panel(Color("12262b"), 12, g.JADE if done and not claimed else Color("28393e")))
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
		texts.add_child(g._label(g.content.quest_name(quest, g.lang), 12, g.TEXT))
		# g._stat_bar sizes itself fixed-width (like the health bars it was built for); give it
		# a sane floor and let size_flags stretch it across the row, or it renders at 0 width.
		var bar := g._stat_bar(120.0, 16.0, progress, target, g.JADE if done else g.GOLD, "%d / %d" % [progress, target], 9)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(bar)

		var action := VBoxContainer.new()
		action.alignment = BoxContainer.ALIGNMENT_CENTER
		hrow.add_child(action)
		if claimed:
			action.add_child(g._label(g.t("ui.quest_claimed"), 10, g.MUTED))
		else:
			var claim_btn := g._button(g.t("ui.quest_claim") if done else g.tf("ui.quest_reward_fmt", int(quest.reward)), func(): g._claim_quest(list_name, quest.id), g.EMBER if done else Color("1a2f36"), Vector2(64, 40))
			claim_btn.disabled = not done
			action.add_child(claim_btn)
	return section

func _account_panel() -> Control:
	var account: Dictionary = g.profile.get("account", {})
	var panel := Panel.new()
	panel.custom_minimum_size.y = 128
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", g._panel(Color("12262b"), 12, g.GOLD))

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
	holder.add_child(g._icon_badge("☰", g.GOLD, 40, 18))
	head.add_child(holder)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 1)
	head.add_child(names)
	names.add_child(g._label(str(account.get("name", "—")), 15, g.TEXT))
	var is_linked := SpiritSave.is_cloud_linked(g.profile)
	var provider := SpiritSave.account_provider(g.profile)
	var status_text := g.t("ui.auth_status_guest")
	if is_linked:
		status_text = g.tf("ui.auth_status_linked", "Apple" if provider == "apple" else "Google")
	names.add_child(g._label(status_text, 9, g.JADE if is_linked else Color("e09c48")))
	var rename_btn := g._button(g.t("ui.account_rename"), g.show_account_setup, Color("17363e"), Vector2(52, 34))
	rename_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rename_btn)

	var created: int = int(account.get("created_at", 0))
	var created_text := Time.get_datetime_string_from_unix_time(created).split("T")[0] if created > 0 else "—"
	stack.add_child(g._label(g.tf("ui.account_created", created_text), 9, g.MUTED))
	stack.add_child(g._label("%s · %s" % [g.t("ui.account_id"), str(account.get("id", "—")).substr(0, 13)], 9, g.MUTED))

	if is_linked:
		var cloud := g._button(g.t("ui.auth_cloud_sync_now"), func():
			SpiritAuth.sync_cloud_save(g)
		, Color("1a3d34"), Vector2(0, 38))
		cloud.name = "CampCloudSyncBtn"
		stack.add_child(cloud)
		stack.add_child(g._label(g.t("ui.auth_cloud_synced"), 8, g.JADE, HORIZONTAL_ALIGNMENT_LEFT, true))
	else:
		var cloud := g._button(g.t("ui.settings_account"), func():
			g.show_settings()
		, Color("1a2f36"), Vector2(0, 38))
		cloud.name = "CampCloudLinkBtn"
		stack.add_child(cloud)
		stack.add_child(g._label(g.t("ui.settings_account_desc"), 8, Color("5e7278"), HORIZONTAL_ALIGNMENT_LEFT, true))
	return panel

func show_quests() -> void:
	g._clear(); g._play_music(false)
	g._back_action = g.show_map
	var page := g._create_page(8)
	page.add_child(g._header(g.t("ui.quests_title"), g.t("ui.quests_sub"), g.show_map))
	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	g._ensure_login_reward_current()
	list.add_child(_season_pass_banner())
	list.add_child(_login_reward_section())
	g._ensure_quests_current()
	list.add_child(_quest_section(g.t("ui.quests_daily"), "daily_quests", int(g.profile.get("daily_reset_at", 0))))
	list.add_child(_quest_section(g.t("ui.quests_weekly"), "weekly_quests", int(g.profile.get("weekly_reset_at", 0))))
	list.add_child(g._label(g.t("ui.quests_hint"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

func _login_reward_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(g._label(g.t("ui.login_reward_title"), 14, g.JADE))

	var record: Dictionary = g.profile.get("login_reward", {"days": [], "claimed": []})
	var days_logged: int = record.get("days", []).size()
	var claimed: Array = record.get("claimed", [])

	var bar := g._stat_bar(120.0, 16.0, days_logged, 7, g.JADE, g.tf("ui.login_reward_progress_fmt", days_logged), 9)
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
		tile.add_theme_stylebox_override("panel", g._panel(Color("12262b"), 12, g.JADE if is_ready else Color("28393e")))
		tiers_row.add_child(tile)

		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 4)
		tile.add_child(stack)
		stack.add_child(g._label(g.tf("ui.login_reward_tier_fmt", tier_days), 10, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		stack.add_child(g._label(g.tf("ui.quest_reward_fmt", int(tier.reward)), 10, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

		if is_claimed:
			stack.add_child(g._label(g.t("ui.quest_claimed"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			var claim_btn := g._button(g.t("ui.quest_claim"), func(): g._claim_login_reward(i), g.EMBER if is_ready else Color("1a2f36"), Vector2(0, 32))
			claim_btn.disabled = not is_ready
			claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stack.add_child(claim_btn)
	return section

func show_camp() -> void:
	if g.camp_tab == "challenges":
		show_challenges()
		return
	g._clear(); g._play_music(false)
	g._back_action = g.show_map
	var page := g._create_page(6)
	page.add_child(g._header(g.t("ui.camp_title"), g.t("ui.camp_sub"), g.show_map))
	var active_tab := g.camp_tab if g.camp_tab in ["character", "collection"] else "character"
	page.add_child(g._tab_bar([
		["character", g.t("ui.camp_tab_character")],
		["collection", g.t("ui.camp_tab_collection")],
	], active_tab, func(id): g.camp_tab = id; show_camp()))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	match g.camp_tab:
		"collection": _build_camp_collection(list)
		_: _build_camp_character(list)

func show_challenges() -> void:
	g._clear(); g._play_music(false)
	g._back_action = g.show_map
	var page := g._create_page(6)
	page.add_child(g._header(g.t("ui.challenges_title"), g.t("ui.challenges_sub"), g.show_map))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	_build_camp_challenges(list)

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
	list.add_child(_draft_arena_section())
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
	var unlocked := int(g.profile.unlocked) >= 25
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(g._label(g.tf("ui.camp_tier", g.profile.difficulty), 17, g.JADE if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		section.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch5"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		return section
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	for value in 6:
		var button := g._button("A%d"%value, func(): g.profile.difficulty=value; SpiritSave.write(g.profile); show_camp(), Color("245247") if value==g.profile.difficulty else Color("17363e"), Vector2(0,40))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(button)
	section.add_child(row)
	section.add_child(g._label(g.t("ui.camp_desc"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	return section

func _relics_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(g._label(g.tf("ui.camp_relics", g.profile.relics.size()), 14, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if g.profile.relics.is_empty():
		section.add_child(g._label(g.t("ui.relic_none"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return section
	for id in g.profile.relics:
		var relic := g.content.relic(id)
		if relic.is_empty(): continue
		var color := Color(relic.color)
		var row_panel := Panel.new()
		row_panel.custom_minimum_size.y = 56
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.add_theme_stylebox_override("panel", g._panel(Color("12262b"), 12, color))
		section.add_child(row_panel)
		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % side, 10)
		row_panel.add_child(pad)
		var relic_row := HBoxContainer.new()
		relic_row.add_theme_constant_override("separation", 10)
		pad.add_child(relic_row)
		var holder := CenterContainer.new()
		holder.add_child(g._relic_icon_badge(relic, color, 38))
		relic_row.add_child(holder)
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 1)
		relic_row.add_child(texts)
		texts.add_child(g._label(g._relic_name(relic), 12, g.TEXT))
		texts.add_child(g._label(g._relic_detail(relic), 9, color, HORIZONTAL_ALIGNMENT_LEFT, true))
	return section

func _compendium_section() -> Control:
	var unlocked := int(g.profile.unlocked) >= 5
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col := Color("8ff5cf") if unlocked else Color("2a3d42")
	panel.add_theme_stylebox_override("panel", g._panel(Color("142418") if unlocked else Color("101a1c"), 14, border_col))

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
	texts.add_child(g._label(g.t("ui.compendium_title"), 15, Color("8ff5cf") if unlocked else g.MUTED))
	if unlocked:
		var totals := g._compendium_totals()
		texts.add_child(g._label(g.tf("ui.compendium_progress", [totals.x, totals.y]), 10, g.MUTED))
	else:
		texts.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch1"), 10, Color("ff9868")))

	var open_btn := g._button(g.t("ui.compendium_open_btn") if unlocked else ("🔒 " + g.t("ui.locked")), show_compendium, Color("1e4a35") if unlocked else Color("162428"), Vector2(0, 40))
	open_btn.name = "CompendiumOpenBtn"
	open_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open_btn.disabled = not unlocked
	row.add_child(open_btn)

	return panel

func _daily_trial_section() -> Control:
	g._ensure_daily_trial_current()
	var unlocked := int(g.profile.unlocked) >= 5
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 130)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", g._panel(Color("241a10") if unlocked else Color("181412"), 14, Color("ffb765") if unlocked else Color("2a3d42")))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	pad.add_child(stack)

	stack.add_child(g._label(g.t("ui.daily_trial_title"), 16, Color("ffb765") if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		stack.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch1"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var enter_btn := g._button("🔒 " + g.t("ui.locked"), begin_daily_trial, Color("2d2218"), Vector2(240, 40))
		enter_btn.name = "DailyTrialEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)
		return panel

	stack.add_child(g._label(g.t("ui.daily_trial_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var tags: Array = g.content.daily_trial_tags(int(g.profile.daily_trial_record.day))
	var tag_names: Array = []
	for tag in tags: tag_names.append(g.content.ui(tag.nameKey, g.lang))
	var sep: String = ", " if g.lang == "en" else "、"
	stack.add_child(g._label("%s: %s" % [g.t("ui.daily_trial_modifiers_title"), sep.join(tag_names)], 9, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_CENTER, true))

	var stage_num: int = int(g.profile.daily_trial_record.stage)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 10)
	stats.add_child(g._label(g.tf("ui.daily_trial_progress_fmt", stage_num), 11, g.GOLD))
	stats.add_child(g._label(g.tf("ui.daily_trial_best_fmt", int(g.profile.daily_trial_record.get("best_stage", 0))), 11, g.JADE))
	stats.add_child(g._label(g.tf("ui.daily_trial_badges_fmt", int(g.profile.daily_trial_record.get("badges", 0))), 11, Color("ffd8a8")))
	stats.add_child(g._label(g.tf("ui.daily_trial_streak_fmt", int(g.profile.daily_trial_record.get("streak", 0))), 11, Color("ff9868")))
	stack.add_child(stats)

	if stage_num >= SpiritContent.DAILY_TRIAL_STAGES:
		stack.add_child(g._label(g.t("ui.daily_trial_done"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		var enter_btn := g._button(g.t("ui.daily_trial_enter"), begin_daily_trial, Color("6b4420"), Vector2(240, 40))
		enter_btn.name = "DailyTrialEnterBtn"
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)

	return panel

func _weekly_challenge_section() -> Control:
	g._ensure_weekly_challenge_current()
	var unlocked := int(g.profile.unlocked) >= 5
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 130)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", g._panel(Color("1a2410") if unlocked else Color("181412"), 14, Color("c8e065") if unlocked else Color("2a3d42")))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 5)
	pad.add_child(stack)

	stack.add_child(g._label(g.t("ui.weekly_challenge_title"), 16, Color("c8e065") if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		stack.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch1"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var enter_btn := g._button("🔒 " + g.t("ui.locked"), begin_weekly_challenge, Color("2d2218"), Vector2(240, 40))
		enter_btn.name = "WeeklyChallengeEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)
		return panel

	stack.add_child(g._label(g.t("ui.weekly_challenge_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var week: int = int(g.profile.weekly_challenge_record.week)
	var tag: Dictionary = g.content.weekly_challenge_tag(week)
	stack.add_child(g._label("%s: %s" % [g.t("ui.weekly_challenge_modifier_title"), g.content.ui(tag.nameKey, g.lang)], 9, Color("e0f0a8"), HORIZONTAL_ALIGNMENT_CENTER, true))

	var stage_num: int = int(g.profile.weekly_challenge_record.stage)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 10)
	stats.add_child(g._label(g.tf("ui.weekly_challenge_progress_fmt", stage_num), 11, g.GOLD))
	stats.add_child(g._label(g.tf("ui.weekly_challenge_best_fmt", int(g.profile.weekly_challenge_record.get("best_stage", 0))), 11, g.JADE))
	stats.add_child(g._label(g.tf("ui.weekly_challenge_badges_fmt", int(g.profile.weekly_challenge_record.get("badges", 0))), 11, Color("e0f0a8")))
	stack.add_child(stats)

	if stage_num >= SpiritContent.WEEKLY_CHALLENGE_STAGES:
		stack.add_child(g._label(g.t("ui.weekly_challenge_done"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		var enter_btn := g._button(g.t("ui.weekly_challenge_enter"), begin_weekly_challenge, Color("4a5a20"), Vector2(240, 40))
		enter_btn.name = "WeeklyChallengeEnterBtn"
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)

	return panel

func _hero_archetypes_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(g._label(g.t("ui.hero_classes_title"), 15, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var current_class_id: String = str(g.profile.get("hero_class", "fox_spirit"))
	for h in g.content.HERO_CLASSES:
		var is_selected: bool = h.id == current_class_id
		var art_pending: bool = bool(h.get("art_pending", false))
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 116 if art_pending else 104)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border_col: Color = g.GOLD if is_selected else Color("1a3d44")
		panel.add_theme_stylebox_override("panel", g._panel(Color("10242b") if not is_selected else Color("153038"), 12, border_col))

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
		spr.texture = g._get_character_texture(str(h.sprite))
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

		var name_str: String = g.content.hero_name(h, g.lang)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		name_row.add_child(g._label(name_str + ("  ✓" if is_selected else ""), 13, g.JADE if is_selected else g.TEXT))
		if h.id == "fox_spirit":
			var rec_badge := PanelContainer.new()
			rec_badge.name = "BeginnerRecBadge"
			rec_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rec_badge.add_theme_stylebox_override("panel", g._panel(Color("2d2208"), 6, Color("ffd700")))
			var rec_pad := MarginContainer.new()
			rec_pad.add_theme_constant_override("margin_left", 6)
			rec_pad.add_theme_constant_override("margin_right", 6)
			rec_pad.add_theme_constant_override("margin_top", 1)
			rec_pad.add_theme_constant_override("margin_bottom", 1)
			rec_pad.add_child(g._label(g.t("ui.hero_rec_badge"), 8, Color("ffd700"), HORIZONTAL_ALIGNMENT_CENTER))
			rec_badge.add_child(rec_pad)
			name_row.add_child(rec_badge)
		texts.add_child(name_row)
		if h.id == "fox_spirit":
			texts.add_child(g._label(g.t("ui.hero_rec_desc"), 8, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_LEFT, true))
		texts.add_child(g._label(g.content.hero_desc(h, g.lang), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		# This hero's mechanics and deck are fully implemented; only a unique painted portrait
		# is missing (the character atlas is a fixed 3x3 grid and all 9 cells are already
		# spoken for by the other 3 heroes and their shared enemy pool — see
		# Docs/GROWTH_ROADMAP.md's D3 note for what a real fix needs). Surfacing that honestly
		# in the UI beats silently reusing another hero's face and hoping nobody notices.
		if art_pending:
			texts.add_child(g._label(g.t("ui.hero_art_pending"), 8, Color("ff9868")))

		var hero_xp: int = int(g.profile.get("hero_masteries", {}).get(h.id, {}).get("xp", 0))
		var hero_level: int = g.content.mastery_level_for_xp(hero_xp)
		var mastery_line: String = g.tf("ui.mastery_level_fmt", hero_level)
		mastery_line += "  " + (g.t("ui.mastery_maxed") if hero_level >= 5 else g.tf("ui.mastery_progress_fmt", [hero_xp, g.content.mastery_xp_for_level(hero_level + 1)]))
		texts.add_child(g._label(mastery_line, 9, g.GOLD))
		var perk: Dictionary = g.content.mastery_perk(h.id, hero_level)
		if not perk.is_empty():
			texts.add_child(g._label("%s · %s" % [g.content.ui(perk.nameKey, g.lang), g.content.ui(perk.descKey, g.lang)], 8, Color("9fd8c9"), HORIZONTAL_ALIGNMENT_LEFT, true))

		var sel_btn := g._button("✓" if is_selected else g.t("ui.hero_class_select"), func():
			g.profile.hero_class = h.id
			g.profile.deck = h.deck.duplicate()
			for cid in h.deck:
				g.profile.collection[cid] = maxi(int(g.profile.collection.get(cid, 0)), h.deck.count(cid))
			var relic_id: String = str(h.get("relic", ""))
			if not relic_id.is_empty() and not g.profile.relics.has(relic_id):
				g.profile.relics.append(relic_id)
			SpiritSave.write(g.profile)
			g._haptic("heavy")
			g._toast(g.tf("ui.hero_selected_toast", name_str), g.GOLD)
			show_camp()
		, g.GOLD if is_selected else Color("1a3d44"), Vector2(68, 38))
		sel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sel_btn)

		box.add_child(panel)

	return box

func _abyss_section() -> Control:
	var unlocked := int(g.profile.unlocked) >= 10
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 110)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border_col := Color("c79bff") if unlocked else Color("2a3d42")
	panel.add_theme_stylebox_override("panel", g._panel(Color("1b1024") if unlocked else Color("141018"), 14, border_col))

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 10)
	panel.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	pad.add_child(stack)

	stack.add_child(g._label(g.t("ui.abyss_title"), 16, Color("e0b8ff") if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		stack.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch2"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		var enter_btn := g._button("🔒 " + g.t("ui.locked"), begin_abyss_battle, Color("2d1b33"), Vector2(240, 40))
		enter_btn.name = "AbyssEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(enter_btn)
		return panel

	stack.add_child(g._label(g.t("ui.abyss_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var floor_num: int = int(g.profile.get("abyss_floor", 1))
	var record_num: int = int(g.profile.get("abyss_record", 0))

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 16)
	stats.add_child(g._label(g.tf("ui.abyss_floor_fmt", floor_num), 11, g.GOLD))
	stats.add_child(g._label(g.tf("ui.abyss_record_fmt", record_num), 11, g.JADE))
	stack.add_child(stats)

	var enter_btn := g._button(g.t("ui.abyss_enter"), begin_abyss_battle, Color("4a285d"), Vector2(240, 40))
	enter_btn.name = "AbyssEnterBtn"
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(enter_btn)

	return panel

func begin_abyss_battle() -> void:
	g.in_abyss = true
	var floor_num: int = int(g.profile.get("abyss_floor", 1))
	var enc: Dictionary = g.content.abyss_encounter(floor_num)
	g.current_stage = 0
	var seed := int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	g.active_modifier = g._modifier(seed, floor_num)
	g.active_modifier["boons"] = g.profile.get("abyss_boons", []).duplicate()
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	g.combat.create(seed, enc, g.profile.deck, int(g.profile.health), g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses())
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = int(g.profile.health)
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

func begin_daily_trial() -> void:
	g._ensure_daily_trial_current()
	if int(g.profile.daily_trial_record.stage) >= SpiritContent.DAILY_TRIAL_STAGES: return
	g.in_daily_trial = true
	var day: int = int(g.profile.daily_trial_record.day)
	var stage_num: int = int(g.profile.daily_trial_record.stage) + 1
	var enc: Dictionary = g.content.daily_trial_encounter(stage_num)
	g.current_stage = 0
	# Seeded by the day index (not wall-clock time like campaign/abyss battles), so every
	# device attempting today's trial fights the exact same encounter — the "deterministic
	# seed" the daily challenge is named for.
	g.active_modifier = g.content.daily_trial_modifier(day)
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	g.combat.create(day * 1000 + stage_num, enc, g.profile.deck, int(g.profile.health), g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses())
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = int(g.profile.health)
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

func begin_weekly_challenge() -> void:
	g._ensure_weekly_challenge_current()
	if int(g.profile.weekly_challenge_record.stage) >= SpiritContent.WEEKLY_CHALLENGE_STAGES: return
	g.in_weekly_challenge = true
	var week: int = int(g.profile.weekly_challenge_record.week)
	var stage_num: int = int(g.profile.weekly_challenge_record.stage) + 1
	var enc: Dictionary = g.content.weekly_challenge_encounter(stage_num)
	g.current_stage = 0
	# Seeded by the week index, same deterministic-per-period approach as the Daily Trial —
	# every device attempting this week's challenge fights the exact same encounter.
	g.active_modifier = g.content.weekly_challenge_modifier(week)
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	g.combat.create(week * 1000 + stage_num, enc, g.profile.deck, int(g.profile.health), g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses())
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = int(g.profile.health)
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

func show_abyss_boon_draft() -> void:
	g._clear()
	var page := g._create_page(12)
	page.add_child(g._header(g.t("ui.boon_draft_title"), g.t("ui.boon_draft_sub"), g.show_reward_details))

	var current_boons: Array = g.profile.get("abyss_boons", [])
	var pool: Array = []
	for boon in g.content.ABYSS_BOONS:
		if not current_boons.has(boon.id):
			pool.append(boon)
	if pool.is_empty(): pool = g.content.ABYSS_BOONS.duplicate()
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
		var p_style := g._panel(Color("101d24"), 12, Color(boon.color))
		p_style.content_margin_left = 16; p_style.content_margin_right = 16
		p_style.content_margin_top = 12; p_style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", p_style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)

		var icon_lbl := g._label(boon.icon, 28, Color(boon.color), HORIZONTAL_ALIGNMENT_CENTER)
		icon_lbl.custom_minimum_size = Vector2(40, 40)
		row.add_child(icon_lbl)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var name_str: String = g.content.ui(boon.nameKey, g.lang)
		info.add_child(g._label(name_str, 15, g.TEXT))
		info.add_child(g._label(g.content.ui(boon.descKey, g.lang), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

		var choose_btn := g._button(g.t("ui.claim"), func(): _select_abyss_boon(boon), Color("244a56"), Vector2(68, 40))
		choose_btn.name = "ChooseBoon_" + boon.id
		row.add_child(choose_btn)

		card_list.add_child(panel)

func _select_abyss_boon(boon: Dictionary) -> void:
	if not g.profile.has("abyss_boons") or not g.profile.abyss_boons is Array: g.profile.abyss_boons = []
	g.profile.abyss_boons.append(boon.id)
	SpiritSave.write(g.profile)
	g._toast(g.tf("ui.boon_acquired_toast", g.content.ui(boon.nameKey, g.lang)))
	g.show_reward_details()

# =========================================================================
# 灵界通行证 · 季节远征 (Spirit Pass)
# =========================================================================

func _has_claimable_season_pass_reward() -> bool:
	var sp: Dictionary = g.profile.get("season_pass", {})
	var xp: int = int(sp.get("xp", 0))
	var current_lvl: int = clampi(1 + int(xp / 200), 1, 20)
	var claimed_free: Array = sp.get("claimed_free", [])
	var claimed_premium: Array = sp.get("claimed_premium", [])
	var is_premium: bool = bool(sp.get("is_premium", true))
	for l in range(1, current_lvl + 1):
		if not claimed_free.has(l): return true
		if is_premium and not claimed_premium.has(l): return true
	return false

func _season_pass_banner() -> Control:
	var sp: Dictionary = g.profile.get("season_pass", {})
	var xp: int = int(sp.get("xp", 0))
	var lvl: int = clampi(1 + int(xp / 200), 1, 20)
	var xp_in_level: int = xp % 200 if lvl < 20 else 200
	var xp_req: int = 200

	var panel := PanelContainer.new()
	panel.name = "SeasonPassBanner"
	var pstyle := g._panel(Color("10242b"), 12, g.GOLD)
	pstyle.content_margin_left = 12
	pstyle.content_margin_right = 12
	pstyle.content_margin_top = 10
	pstyle.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", pstyle)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	var title_lbl := g._label(g.t("ui.season_pass_banner_title"), 13, g.GOLD)
	info.add_child(title_lbl)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	var lvl_lbl := g._label(g.tf("ui.season_pass_level_fmt", lvl), 11, g.TEXT)
	progress_row.add_child(lvl_lbl)
	var xp_lbl := g._label("%d / %d XP" % [xp_in_level, xp_req], 10, g.JADE)
	progress_row.add_child(xp_lbl)
	info.add_child(progress_row)

	var bar := g._stat_bar(140.0, 10.0, xp_in_level, xp_req, g.GOLD, "", 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(bar)

	var btn_view := g._button(g.t("ui.season_pass_view"), show_season_pass, g.EMBER, Vector2(80, 36))
	btn_view.name = "SeasonPassViewBtn"
	btn_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _has_claimable_season_pass_reward():
		g._add_notification_dot(btn_view, Vector2(80, 36))
	row.add_child(btn_view)

	return panel

func _get_season_pass_rewards(tier: int) -> Dictionary:
	var free_gold: int = 40 + tier * 15
	var free_reward: Dictionary = {"type": "gold", "amount": free_gold, "desc": "%d %s" % [free_gold, g.t("ui.gold")]}
	if tier == 5: free_reward = {"type": "rune", "id": "rune_swift", "desc": "符文·迅捷"}
	elif tier == 10: free_reward = {"type": "rune", "id": "rune_burning", "desc": "符文·灼热"}
	elif tier == 15: free_reward = {"type": "rune", "id": "rune_chain", "desc": "符文·连锁"}
	elif tier == 20: free_reward = {"type": "rune", "id": "rune_vampiric", "desc": "符文·吸血"}

	var prem_gold: int = 80 + tier * 30
	var prem_reward: Dictionary = {"type": "gold", "amount": prem_gold, "desc": "%d %s" % [prem_gold, g.t("ui.gold")]}
	if tier == 3: prem_reward = {"type": "equip", "id": "emberBlade", "desc": "烬火长刀"}
	elif tier == 7: prem_reward = {"type": "equip", "id": "jadePlate", "desc": "翠玉战甲"}
	elif tier == 10: prem_reward = {"type": "equip", "id": "stormBow", "desc": "逐电长弓"}
	elif tier == 14: prem_reward = {"type": "equip", "id": "thornArmor", "desc": "荆棘铠甲"}
	elif tier == 18: prem_reward = {"type": "equip", "id": "focusCharm", "desc": "凝神灵镜"}
	elif tier == 20: prem_reward = {"type": "equip", "id": "phoenixMail", "desc": "涅槃羽衣"}

	return {"free": free_reward, "premium": prem_reward}

func _apply_pass_reward(reward: Dictionary) -> void:
	var rtype: String = str(reward.get("type", "gold"))
	if rtype == "gold":
		g.profile.gold += int(reward.get("amount", 0))
	elif rtype == "rune":
		var rid: String = str(reward.get("id", ""))
		if not g.profile.runes.has(rid):
			g.profile.runes.append(rid)
	elif rtype == "equip":
		var eid: String = str(reward.get("id", ""))
		if not g.profile.equipment_owned.has(eid):
			g.profile.equipment_owned.append(eid)

func _claim_season_pass_tier(tier: int, is_premium: bool) -> void:
	var sp: Dictionary = g.profile.get("season_pass", {})
	var r := _get_season_pass_rewards(tier)
	if not is_premium:
		var claimed_free: Array = sp.get("claimed_free", [])
		if not claimed_free.has(tier):
			claimed_free.append(tier)
			sp.claimed_free = claimed_free
			_apply_pass_reward(r.free)
	else:
		var claimed_premium: Array = sp.get("claimed_premium", [])
		if not claimed_premium.has(tier):
			claimed_premium.append(tier)
			sp.claimed_premium = claimed_premium
			_apply_pass_reward(r.premium)
	SpiritSave.write(g.profile)
	g._toast(g.t("ui.quest_claimed"), g.GOLD)
	show_season_pass()

func _claim_all_season_pass() -> void:
	var sp: Dictionary = g.profile.get("season_pass", {})
	var xp: int = int(sp.get("xp", 0))
	var current_lvl: int = clampi(1 + int(xp / 200), 1, 20)
	var claimed_free: Array = sp.get("claimed_free", []).duplicate()
	var claimed_premium: Array = sp.get("claimed_premium", []).duplicate()
	var is_premium: bool = bool(sp.get("is_premium", true))
	for l in range(1, current_lvl + 1):
		var r := _get_season_pass_rewards(l)
		if not claimed_free.has(l):
			claimed_free.append(l)
			_apply_pass_reward(r.free)
		if is_premium and not claimed_premium.has(l):
			claimed_premium.append(l)
			_apply_pass_reward(r.premium)
	sp.claimed_free = claimed_free
	sp.claimed_premium = claimed_premium
	SpiritSave.write(g.profile)
	g._toast(g.t("ui.season_pass_all_claimed_toast"), g.GOLD)
	show_season_pass()

func show_season_pass() -> void:
	g._clear(); g._play_music(false)
	g._back_action = show_quests
	var page := g._create_page(8)
	page.add_child(g._header(g.t("ui.season_pass_title"), g.t("ui.season_pass_sub"), show_quests))

	var sp: Dictionary = g.profile.get("season_pass", {})
	var xp: int = int(sp.get("xp", 0))
	var current_lvl: int = clampi(1 + int(xp / 200), 1, 20)
	var claimed_free: Array = sp.get("claimed_free", [])
	var claimed_premium: Array = sp.get("claimed_premium", [])
	var is_premium: bool = bool(sp.get("is_premium", true))

	# Top summary card: Level + XP + Claim All button
	var top_card := PanelContainer.new()
	var top_style := g._panel(Color("10242b"), 12, g.GOLD)
	top_style.content_margin_left = 12
	top_style.content_margin_right = 12
	top_style.content_margin_top = 8
	top_style.content_margin_bottom = 8
	top_card.add_theme_stylebox_override("panel", top_style)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_card.add_child(top_row)

	var top_info := VBoxContainer.new()
	top_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_info.add_theme_constant_override("separation", 2)
	top_row.add_child(top_info)

	top_info.add_child(g._label(g.tf("ui.season_pass_level_fmt", current_lvl), 14, g.GOLD))
	var xp_in_level: int = xp % 200 if current_lvl < 20 else 200
	top_info.add_child(g._label(g.tf("ui.season_pass_xp_fmt", [xp_in_level, 200]), 10, g.JADE))

	var claim_all_btn := g._button(g.t("ui.season_pass_claim_all"), _claim_all_season_pass, g.EMBER, Vector2(100, 36))
	claim_all_btn.name = "SeasonPassClaimAllBtn"
	claim_all_btn.disabled = not _has_claimable_season_pass_reward()
	claim_all_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(claim_all_btn)
	page.add_child(top_card)

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for tier in range(1, 21):
		list.add_child(_season_pass_tier_row(tier, current_lvl, claimed_free, claimed_premium, is_premium))

func _season_pass_tier_row(tier: int, current_lvl: int, claimed_free: Array, claimed_premium: Array, is_premium: bool) -> Control:
	var unlocked: bool = tier <= current_lvl
	var r := _get_season_pass_rewards(tier)

	var card := PanelContainer.new()
	card.name = "SeasonPassTier_%d" % tier
	var cstyle := g._panel(Color("0d1e24"), 10, g.GOLD if unlocked else Color("1e3137"))
	cstyle.content_margin_left = 10; cstyle.content_margin_right = 10
	cstyle.content_margin_top = 8; cstyle.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", cstyle)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	# Tier Badge
	var badge_box := VBoxContainer.new()
	badge_box.custom_minimum_size = Vector2(46, 0)
	badge_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var tlbl := g._label("Lv.%d" % tier, 13, g.GOLD if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	badge_box.add_child(tlbl)
	row.add_child(badge_box)

	# Free Track Reward
	var free_box := VBoxContainer.new()
	free_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	free_box.add_theme_constant_override("separation", 2)
	free_box.add_child(g._label(g.t("ui.season_pass_free"), 9, g.MUTED))
	free_box.add_child(g._label(str(r.free.desc), 11, g.TEXT))
	var free_claimed: bool = claimed_free.has(tier)
	if free_claimed:
		free_box.add_child(g._label("✓ " + g.t("ui.season_pass_claimed"), 9, g.JADE))
	elif unlocked:
		var btn_f := g._button(g.t("ui.season_pass_claim"), func(): _claim_season_pass_tier(tier, false), g.EMBER, Vector2(0, 28))
		btn_f.name = "ClaimFreeTierBtn_%d" % tier
		free_box.add_child(btn_f)
	else:
		free_box.add_child(g._label("🔒 " + g.t("ui.season_pass_locked"), 9, g.MUTED))
	row.add_child(free_box)

	# Premium Track Reward
	var prem_box := VBoxContainer.new()
	prem_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prem_box.add_theme_constant_override("separation", 2)
	prem_box.add_child(g._label(g.t("ui.season_pass_premium"), 9, g.GOLD))
	prem_box.add_child(g._label(str(r.premium.desc), 11, Color("ffd794")))
	var prem_claimed: bool = claimed_premium.has(tier)
	if prem_claimed:
		prem_box.add_child(g._label("✓ " + g.t("ui.season_pass_claimed"), 9, g.JADE))
	elif unlocked and is_premium:
		var btn_p := g._button(g.t("ui.season_pass_claim"), func(): _claim_season_pass_tier(tier, true), Color("9e6b28"), Vector2(0, 28))
		btn_p.name = "ClaimPremTierBtn_%d" % tier
		prem_box.add_child(btn_p)
	else:
		prem_box.add_child(g._label("🔒 " + g.t("ui.season_pass_locked"), 9, g.MUTED))
	row.add_child(prem_box)

	return card

# =========================================================================
# 三选一竞技场轮抽构筑模式 (Spirit Draft Mode)
# =========================================================================

func _draft_arena_section() -> Control:
	var draft_data: Dictionary = g.profile.get("draft_arena", {})
	var is_active: bool = bool(draft_data.get("active", false))
	var wins: int = int(draft_data.get("wins", 0))
	var losses: int = int(draft_data.get("losses", 0))

	var section := VBoxContainer.new()
	section.name = "DraftArenaSection"
	section.add_theme_constant_override("separation", 6)

	var panel := PanelContainer.new()
	var pstyle := g._panel(Color("16242c"), 12, g.GOLD)
	pstyle.content_margin_left = 12; pstyle.content_margin_right = 12
	pstyle.content_margin_top = 10; pstyle.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", pstyle)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	info.add_child(g._label(g.t("ui.draft_arena_title"), 14, g.GOLD))
	info.add_child(g._label(g.t("ui.draft_arena_sub"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	if is_active:
		info.add_child(g._label(g.tf("ui.draft_win_fmt", [wins, losses]), 11, g.JADE))

	var action_btn_text: String = g.tf("ui.draft_continue_btn", wins) if is_active else g.t("ui.draft_start_btn")
	var btn := g._button(action_btn_text, show_spirit_draft, g.EMBER, Vector2(100, 42))
	btn.name = "DraftArenaEnterBtn"
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)

	section.add_child(panel)
	return section

func show_spirit_draft() -> void:
	g._clear(); g._play_music(false)
	g._back_action = show_challenges

	var draft: Dictionary = g.profile.get("draft_arena", {})
	if draft.is_empty():
		draft = {"active": false, "wins": 0, "losses": 0, "round": 1, "deck": [], "current_pool": []}
		g.profile.draft_arena = draft

	var round_num: int = int(draft.get("round", 1))
	var is_active: bool = bool(draft.get("active", false))

	if is_active and round_num > 7:
		_show_draft_battle_ready()
		return

	_show_draft_pick_phase()

func _show_draft_pick_phase() -> void:
	var draft: Dictionary = g.profile.draft_arena
	var round_num: int = int(draft.get("round", 1))
	if round_num == 1 and draft.get("deck", []).is_empty():
		draft.deck = ["strike", "strike", "strike", "strike", "ward", "ward", "ward", "ward"]

	var current_pool: Array = draft.get("current_pool", [])
	if current_pool.size() < 3:
		var non_starter_cards: Array = []
		for card in g.content.cards:
			if str(card.rarity) != "Starter" and str(card.get("kind", "")) != "Curse":
				non_starter_cards.append(card.id)
		non_starter_cards.shuffle()
		current_pool = [non_starter_cards[0], non_starter_cards[1], non_starter_cards[2]]
		draft.current_pool = current_pool
		SpiritSave.write(g.profile)

	var page := g._create_page(8)
	page.add_child(g._header(g.t("ui.draft_arena_title"), g.tf("ui.draft_round_fmt", round_num), show_challenges))
	page.add_child(g._label(g.t("ui.draft_pick_card"), 13, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var content_col := VBoxContainer.new()
	content_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_col.add_theme_constant_override("separation", 10)
	scroll.add_child(content_col)

	# 3 Card Choices
	for cid in current_pool:
		var card_id := str(cid)
		var card: Dictionary = g.content.card(card_id)
		if card.is_empty(): continue

		var tile := PanelContainer.new()
		tile.name = "DraftOption_" + card_id
		var tstyle := g._panel(Color("10242a"), 12, g._card_color(card))
		tstyle.content_margin_left = 12; tstyle.content_margin_right = 12
		tstyle.content_margin_top = 10; tstyle.content_margin_bottom = 10
		tile.add_theme_stylebox_override("panel", tstyle)

		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 12)
		tile.add_child(trow)

		# Small art preview
		var art := TextureRect.new()
		art.texture = g._get_card_texture(card_id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(54, 72)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trow.add_child(art)

		var tinfo := VBoxContainer.new()
		tinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tinfo.add_theme_constant_override("separation", 3)
		trow.add_child(tinfo)

		var cname := g.content.text(card.nameKey, g.lang)
		tinfo.add_child(g._label("%s (%d 费)" % [cname, int(card.cost)], 13, g.TEXT))
		tinfo.add_child(g._label(g._card_description(card), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

		var pick_btn := g._button(g.t("ui.claim"), func(): _pick_draft_card(card_id), g.EMBER, Vector2(74, 38))
		pick_btn.name = "DraftPickBtn_" + card_id
		pick_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		trow.add_child(pick_btn)

		content_col.add_child(tile)

	# Current Deck summary at bottom
	var current_deck: Array = draft.get("deck", [])
	content_col.add_child(g._label("当前牌组 (%d/15 张): %s" % [current_deck.size(), ", ".join(current_deck)], 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

func _pick_draft_card(card_id: String) -> void:
	var draft: Dictionary = g.profile.draft_arena
	var deck: Array = draft.get("deck", [])
	deck.append(card_id)
	draft.deck = deck
	draft.current_pool = []
	var next_round: int = int(draft.get("round", 1)) + 1
	draft.round = next_round
	if next_round > 7:
		draft.active = true
		SpiritSave.write(g.profile)
		g._toast(g.t("ui.draft_deck_ready"), g.GOLD)
		_show_draft_battle_ready()
	else:
		SpiritSave.write(g.profile)
		show_spirit_draft()

func _show_draft_battle_ready() -> void:
	g._clear(); g._play_music(false)
	g._back_action = show_challenges

	var draft: Dictionary = g.profile.draft_arena
	var wins: int = int(draft.get("wins", 0))
	var losses: int = int(draft.get("losses", 0))

	var page := g._create_page(10)
	page.add_child(g._header(g.t("ui.draft_arena_title"), g.t("ui.draft_arena_sub"), show_challenges))

	var card := PanelContainer.new()
	var cstyle := g._panel(Color("10242a"), 14, g.GOLD)
	cstyle.content_margin_left = 16; cstyle.content_margin_right = 16
	cstyle.content_margin_top = 14; cstyle.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", cstyle)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	col.add_child(g._label(g.tf("ui.draft_win_fmt", [wins, losses]), 15, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(g._label("竞技场牌组 (15张):", 12, g.TEXT))

	var deck: Array = draft.get("deck", [])
	col.add_child(g._label(", ".join(deck), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var start_battle_btn := g._button("迎战第 %d 位灵界对手" % (wins + 1), _start_draft_battle, g.EMBER, Vector2(0, 44))
	start_battle_btn.name = "DraftStartBattleBtn"
	col.add_child(start_battle_btn)

	var abandon_btn := g._button(g.t("ui.draft_abandon_btn"), _abandon_draft, Color("3a1c22"), Vector2(0, 36))
	abandon_btn.name = "DraftAbandonBtn"
	col.add_child(abandon_btn)

	page.add_child(card)

func _start_draft_battle() -> void:
	var draft: Dictionary = g.profile.draft_arena
	var wins: int = int(draft.get("wins", 0))
	g.in_draft_battle = true
	var stage_idx: int = mini(g.content.encounters.size() - 1, wins * 2)
	g.begin_battle(stage_idx)

func _abandon_draft() -> void:
	var draft: Dictionary = g.profile.draft_arena
	draft.active = false
	draft.round = 1
	draft.deck = []
	draft.current_pool = []
	draft.wins = 0
	draft.losses = 0
	SpiritSave.write(g.profile)
	show_challenges()


