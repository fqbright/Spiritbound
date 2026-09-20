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
		["chronicle", g.t("ui.compendium_tab_chronicle")],
		["codex", g.t("ui.compendium_tab_codex")],
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
		"achievements": _build_compendium_achievements(list)
		"codex": _build_compendium_codex(list)
		_: _build_compendium_chronicle(list)

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
func _compendium_row(badge: Control, title: String, detail: String, discovered: bool, accent: Color, locked_label := "") -> Control:
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
	texts.add_child(g._label(title if discovered else (locked_label if not locked_label.is_empty() else g.t("ui.compendium_locked")), 13, g.TEXT if discovered else g.MUTED))
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
	list.add_child(g._spacer(8))
	list.add_child(g._label(g.t("ui.relic_resonance_codex"), 13, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	for res in SpiritContent.RELIC_RESONANCES:
		var res_color := Color(res.color)
		var badge: Panel = g._relic_resonance_badge(res, res_color, 46)
		var req_names: Array[String] = []
		var all_discovered := true
		for req_id in res.relics:
			var r := g.content.relic(req_id)
			var r_name: String = g._relic_name(r) if not r.is_empty() else req_id
			var is_disc := g._relic_discovered(req_id)
			if not is_disc: all_discovered = false
			req_names.append(r_name if is_disc else "???")
		var req_str: String = " · ".join(req_names)
		var desc: String = g._relic_resonance_detail(res) + "\n" + (g.tf("ui.relic_resonance_req", req_str))
		list.add_child(_compendium_row(badge, g._relic_resonance_name(res), desc, all_discovered, res_color))

func _build_compendium_bestiary(list: VBoxContainer) -> void:
	var total_count: int = SpiritContent.ENEMIES.size()
	var disc_count := 0
	for enemy in SpiritContent.ENEMIES:
		if g._bestiary_discovered(str(enemy.name)): disc_count += 1
	list.add_child(g._label(g.tf("ui.compendium_progress", [disc_count, total_count]), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var realm_names := {
		1: {"zh": "第一域 · 灵木与熔炉", "en": "Realm 1: Mistwood & Ancient Forge"},
		2: {"zh": "第二域 · 幽泽与沉沦古都", "en": "Realm 2: Nether Marsh & Sunken Dynasty"},
		3: {"zh": "第三域 · 云海与苍穹神域", "en": "Realm 3: Cloudsea Heights & Storm Domain"},
		4: {"zh": "第四域 · 虚空深渊与归墟裂痕", "en": "Realm 4: Void Rift & Oblivion Trench"},
		5: {"zh": "第五域 · 创世烘炉与万象终焉", "en": "Realm 5: Genesis Hearth & Primordial Origin"}
	}
	var current_realm := 0
	for enemy in SpiritContent.ENEMIES:
		var r: int = int(enemy.get("realm", 1))
		if r != current_realm:
			current_realm = r
			var r_info: Dictionary = realm_names.get(r, {})
			var r_title: String = str(r_info.get("en" if g.lang == "en" else "zh", "Realm %d" % r))
			var r_hdr := MarginContainer.new()
			r_hdr.add_theme_constant_override("margin_top", 10)
			r_hdr.add_theme_constant_override("margin_bottom", 2)
			var r_lbl := g._label(r_title, 11, g.GOLD)
			r_hdr.add_child(r_lbl)
			list.add_child(r_hdr)

		var discovered := g._bestiary_discovered(str(enemy.name))
		var tier: int = int(enemy.get("tier", 1))
		var tier_prefix := ""
		match tier:
			1: tier_prefix = "[凡灵] " if g.lang != "en" else "[Minion] "
			2: tier_prefix = "[精锐] " if g.lang != "en" else "[Elite] "
			3: tier_prefix = "[霸主] " if g.lang != "en" else "[Boss] "
			4: tier_prefix = "[天灾] " if g.lang != "en" else "[Cataclysm] "
		var name_str: String = tier_prefix + (str(enemy.name_en) if g.lang == "en" else str(enemy.name))
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

# Unlocked in lockstep with the map's own chapter-lock rule (chapter * 5 <= profile.unlocked,
# same check game_map_screen.gd's _add_map_chapter uses) rather than a separate discovery
# flag, so a fresh save's Chronicle tab fills in exactly as fast as the player actually travels
# — no migration needed for existing saves either, since it reads progress already there.
func _career_stat_panel(border: Color, title: String, title_color: Color, rows: Array[String]) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", g._panel(Color("10221c"), 12, border))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(pad)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	pad.add_child(stack)
	stack.add_child(g._label(title, 14, title_color))
	for row in rows: stack.add_child(g._label(row, 11, g.TEXT))
	return panel

# Career Codex (旅者典籍 / Phase 6): lifetime playstyle stats independent of any single run.
# Deliberately reads victories/damage/gold straight from lifetime_stats and the highest Abyss
# floor from profile.abyss_record rather than duplicating them into career_stats — see
# _track_career_battle_stats()'s own comment in game.gd for why. Everything here only ever
# grows; there's no reset path, matching the "lifetime" framing.
func _build_compendium_career(list: VBoxContainer) -> void:
	var cs: Dictionary = g.profile.get("career_stats", {})
	var lifetime: Dictionary = g.profile.get("lifetime_stats", {})
	var victories: int = int(lifetime.get("win_battles", 0))
	var defeats: int = int(cs.get("defeats", 0))
	var total_runs: int = victories + defeats
	var win_rate: int = int(round(100.0 * float(victories) / float(maxi(1, total_runs)))) if total_runs > 0 else 0

	list.add_child(_career_stat_panel(g.JADE, g.t("ui.career_overview_title"), g.GOLD, [
		g.tf("ui.career_total_battles_fmt", total_runs),
		g.tf("ui.career_win_rate_fmt", win_rate),
		g.tf("ui.career_longest_streak_fmt", int(cs.get("longest_win_streak", 0))),
		g.tf("ui.career_abyss_floor_fmt", int(g.profile.get("abyss_record", 0))),
	]))

	var style_rows: Array[String] = [
		g.tf("ui.career_total_damage_fmt", int(lifetime.get("deal_damage", 0))),
		g.tf("ui.career_cards_played_fmt", int(cs.get("total_cards_played", 0))),
		g.tf("ui.career_shield_gained_fmt", int(cs.get("total_shield_gained", 0))),
	]
	var fav_hero: Dictionary = cs.get("favorite_hero", {})
	if not fav_hero.is_empty():
		var best_hero_id := ""
		var best_hero_wins := -1
		for hero_id in fav_hero:
			if int(fav_hero[hero_id]) > best_hero_wins:
				best_hero_wins = int(fav_hero[hero_id])
				best_hero_id = str(hero_id)
		style_rows.append(g.tf("ui.career_favorite_hero_fmt", [g.content.hero_name(g.content.hero_class(best_hero_id), g.lang), best_hero_wins]))
	var fav_cards: Dictionary = cs.get("favorite_cards", {})
	if not fav_cards.is_empty():
		var best_card_id := ""
		var best_card_count := -1
		for card_id in fav_cards:
			if int(fav_cards[card_id]) > best_card_count:
				best_card_count = int(fav_cards[card_id])
				best_card_id = str(card_id)
		var best_card: Dictionary = g.content.card(best_card_id)
		if not best_card.is_empty():
			style_rows.append(g.tf("ui.career_favorite_card_fmt", [g.content.text(best_card.nameKey, g.lang), best_card_count]))
	list.add_child(_career_stat_panel(Color("6a8fbd"), g.t("ui.career_style_title"), Color("8fb8ff"), style_rows))

	var hof_panel := PanelContainer.new()
	hof_panel.name = "CareerHallOfFame"
	hof_panel.add_theme_stylebox_override("panel", g._panel(Color("10221c"), 12, g.GOLD))
	var hof_pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: hof_pad.add_theme_constant_override("margin_%s" % side, 12)
	hof_panel.add_child(hof_pad)
	var hof_stack := VBoxContainer.new()
	hof_stack.add_theme_constant_override("separation", 6)
	hof_pad.add_child(hof_stack)
	hof_stack.add_child(g._label(g.t("ui.career_hof_title"), 14, g.GOLD))
	var hof: Array = cs.get("hall_of_fame", [])
	if hof.is_empty():
		hof_stack.add_child(g._label(g.t("ui.career_hof_empty"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	else:
		for i in range(hof.size() - 1, -1, -1):
			var entry: Dictionary = hof[i]
			var hero_display: String = g.content.hero_name(g.content.hero_class(str(entry.get("hero_class", ""))), g.lang)
			var relic_count: int = int(entry.get("relics", []).size())
			hof_stack.add_child(g._label(g.tf("ui.career_hof_entry_fmt", [int(entry.get("chapter", 0)), hero_display, int(entry.get("turns", 0)), relic_count]), 10, g.JADE))
	list.add_child(hof_panel)

func _build_compendium_chronicle(list: VBoxContainer) -> void:
	var chapter_count: int = SpiritContent.CHAPTER_NAMES_ZH.size()
	var unlocked_n: int = clampi(int(g.profile.unlocked) / 5 + 1, 0, chapter_count)
	list.add_child(g._label(g.tf("ui.compendium_progress", [unlocked_n, chapter_count]), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for chapter in range(chapter_count):
		var discovered: bool = chapter * 5 <= int(g.profile.unlocked)
		var badge: Control
		if discovered:
			var tex := TextureRect.new()
			tex.texture = g._get_chapter_map_texture(chapter)
			tex.custom_minimum_size = Vector2(46, 60)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex.clip_contents = true
			badge = tex
		else:
			badge = _compendium_locked_badge()
		var title: String = "%d · %s" % [chapter + 1, g.content.chapter_name(chapter, g.lang)]
		list.add_child(_compendium_row(badge, title, g.content.chapter_lore(chapter, g.lang), discovered, g.JADE, g.t("ui.chronicle_locked")))

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

func _fmt_codex_num(n: int) -> String:
	var s: String = str(n)
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

func _build_compendium_codex(list: VBoxContainer) -> void:
	var cs: Dictionary = g.profile.get("career_stats", {})
	var total_battles: int = int(cs.get("total_battles", 0))
	var victories: int = int(cs.get("victories", 0))
	var defeats: int = int(cs.get("defeats", 0))
	var win_rate: int = int(round(float(victories * 100) / float(maxi(1, total_battles)))) if total_battles > 0 else 0
	var longest_streak: int = int(cs.get("longest_win_streak", 0))
	var current_streak: int = int(cs.get("current_win_streak", 0))
	var total_dmg: int = int(cs.get("total_damage_dealt", 0))
	var total_shd: int = int(cs.get("total_shield_gained", 0))
	var total_cards: int = int(cs.get("total_cards_played", 0))
	var elites: int = int(cs.get("elites_slain", 0))
	var bosses: int = int(cs.get("bosses_slain", 0))

	# Section 1: Overview
	list.add_child(g._label(g.t("ui.codex_overview"), 13, g.JADE))
	var ov_panel := PanelContainer.new()
	ov_panel.name = "CodexOverviewPanel"
	ov_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_panel.add_theme_stylebox_override("panel", g._panel(Color("10242b"), 12, Color("1f404d")))
	list.add_child(ov_panel)

	var ov_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: ov_pad.add_theme_constant_override("margin_%s" % s, 10)
	ov_panel.add_child(ov_pad)

	var ov_grid := GridContainer.new()
	ov_grid.columns = 3
	ov_grid.add_theme_constant_override("h_separation", 8)
	ov_grid.add_theme_constant_override("v_separation", 10)
	ov_pad.add_child(ov_grid)

	var metrics: Array = [
		[g.t("ui.codex_total_battles"), str(total_battles), g.TEXT],
		[g.t("ui.codex_victories"), str(victories), g.JADE],
		[g.t("ui.codex_defeats"), str(defeats), Color("e06c75") if defeats > 0 else g.MUTED],
		[g.t("ui.codex_win_rate"), "%d%%" % win_rate, g.GOLD],
		[g.t("ui.codex_best_streak"), str(longest_streak), g.GOLD],
		[g.t("ui.codex_current_streak"), str(current_streak), g.JADE if current_streak > 0 else g.MUTED],
	]
	for m in metrics:
		var m_box := VBoxContainer.new()
		m_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_box.alignment = BoxContainer.ALIGNMENT_CENTER
		m_box.add_theme_constant_override("separation", 2)
		m_box.add_child(g._label(str(m[0]), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		m_box.add_child(g._label(str(m[1]), 16, m[2] as Color, HORIZONTAL_ALIGNMENT_CENTER))
		ov_grid.add_child(m_box)

	# Section 2: Combat Mastery
	list.add_child(g._label(g.t("ui.codex_mastery"), 13, g.JADE))
	var m_panel := PanelContainer.new()
	m_panel.name = "CodexMasteryPanel"
	m_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_panel.add_theme_stylebox_override("panel", g._panel(Color("10242b"), 12, Color("1f404d")))
	list.add_child(m_panel)

	var m_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: m_pad.add_theme_constant_override("margin_%s" % s, 10)
	m_panel.add_child(m_pad)

	var m_vbox := VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 8)
	m_pad.add_child(m_vbox)

	var m_stats_row := HBoxContainer.new()
	m_stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_vbox.add_child(m_stats_row)

	var mastery_items: Array = [
		[g.t("ui.codex_total_damage"), _fmt_codex_num(total_dmg), Color("ff8755")],
		[g.t("ui.codex_total_shield"), _fmt_codex_num(total_shd), Color("61afef")],
		[g.t("ui.codex_cards_played"), _fmt_codex_num(total_cards), g.TEXT],
	]
	for mi in mastery_items:
		var mi_box := VBoxContainer.new()
		mi_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mi_box.alignment = BoxContainer.ALIGNMENT_CENTER
		mi_box.add_theme_constant_override("separation", 2)
		mi_box.add_child(g._label(str(mi[0]), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		mi_box.add_child(g._label(str(mi[1]), 14, mi[2] as Color, HORIZONTAL_ALIGNMENT_CENTER))
		m_stats_row.add_child(mi_box)

	var sep_line := ColorRect.new()
	sep_line.custom_minimum_size = Vector2(0, 1)
	sep_line.color = Color("1a3840")
	m_vbox.add_child(sep_line)

	var bosses_row := HBoxContainer.new()
	bosses_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_vbox.add_child(bosses_row)

	var slay_items: Array = [
		[g.t("ui.codex_elites_slain"), str(elites), g.GOLD],
		[g.t("ui.codex_bosses_slain"), str(bosses), Color("e5c07b")],
	]
	for si in slay_items:
		var si_box := VBoxContainer.new()
		si_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		si_box.alignment = BoxContainer.ALIGNMENT_CENTER
		si_box.add_theme_constant_override("separation", 2)
		si_box.add_child(g._label(str(si[0]), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		si_box.add_child(g._label(str(si[1]), 14, si[2] as Color, HORIZONTAL_ALIGNMENT_CENTER))
		bosses_row.add_child(si_box)

	# Signature Hero & Signature Card row
	var sig_row := HBoxContainer.new()
	sig_row.add_theme_constant_override("separation", 10)
	m_vbox.add_child(sig_row)

	# Find signature hero
	var hero_id: String = str(cs.get("favorite_hero", g.profile.get("hero_class", "fox_spirit")))
	var hero_data: Dictionary = {}
	for hc in g.content.HERO_CLASSES:
		if hc.id == hero_id:
			hero_data = hc
			break
	var hero_name: String = g.content.hero_name(hero_data, g.lang) if not hero_data.is_empty() else hero_id

	var hero_box := PanelContainer.new()
	hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_box.add_theme_stylebox_override("panel", g._panel(Color("0e1d22"), 8, Color("1b3a42")))
	sig_row.add_child(hero_box)
	var hb_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: hb_pad.add_theme_constant_override("margin_%s" % s, 6)
	hero_box.add_child(hb_pad)
	var hb_row := HBoxContainer.new()
	hb_row.add_theme_constant_override("separation", 8)
	hb_pad.add_child(hb_row)

	var h_spr := TextureRect.new()
	if not hero_data.is_empty():
		h_spr.texture = g._get_character_texture(str(hero_data.sprite))
	h_spr.custom_minimum_size = Vector2(36, 36)
	h_spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h_spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb_row.add_child(h_spr)

	var h_txts := VBoxContainer.new()
	h_txts.alignment = BoxContainer.ALIGNMENT_CENTER
	h_txts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_txts.add_child(g._label(g.t("ui.codex_fav_hero"), 9, g.MUTED))
	h_txts.add_child(g._label(hero_name, 11, g.GOLD))
	hb_row.add_child(h_txts)

	# Find signature card
	var fav_cards: Dictionary = cs.get("favorite_cards", {})
	var top_cid: String = ""
	var top_count: int = 0
	for cid in fav_cards:
		var cnt: int = int(fav_cards[cid])
		if cnt > top_count:
			top_count = cnt
			top_cid = str(cid)
	var top_card: Dictionary = g.content.card(top_cid) if not top_cid.is_empty() else {}
	var card_name_str: String = g.content.text(str(top_card.get("nameKey", "")), g.lang) if not top_card.is_empty() else (top_cid if not top_cid.is_empty() else g.t("ui.loadout_empty"))

	var card_box := PanelContainer.new()
	card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_box.add_theme_stylebox_override("panel", g._panel(Color("0e1d22"), 8, Color("1b3a42")))
	sig_row.add_child(card_box)
	var cb_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: cb_pad.add_theme_constant_override("margin_%s" % s, 6)
	card_box.add_child(cb_pad)
	var cb_row := HBoxContainer.new()
	cb_row.add_theme_constant_override("separation", 8)
	cb_pad.add_child(cb_row)

	var c_badge: Control = g._icon_badge("✦" if not top_card.is_empty() else "—", g._card_color(top_card) if not top_card.is_empty() else Color("3c5057"), 36, 16)
	cb_row.add_child(c_badge)

	var c_txts := VBoxContainer.new()
	c_txts.alignment = BoxContainer.ALIGNMENT_CENTER
	c_txts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_txts.add_child(g._label(g.t("ui.codex_fav_card"), 9, g.MUTED))
	var c_label_str: String = ("%s (%d)" % [card_name_str, top_count]) if top_count > 0 else card_name_str
	c_txts.add_child(g._label(c_label_str, 11, g.JADE if not top_card.is_empty() else g.MUTED))
	cb_row.add_child(c_txts)

	# Section 3: Hall of Fame
	list.add_child(g._label(g.t("ui.codex_hall_of_fame"), 13, g.JADE))
	var hof: Array = cs.get("hall_of_fame", [])
	if hof.is_empty():
		var empty_panel := PanelContainer.new()
		empty_panel.name = "CodexHofEmpty"
		empty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_panel.add_theme_stylebox_override("panel", g._panel(Color("0e191d"), 10, Color("162e35")))
		var ep_pad := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]: ep_pad.add_theme_constant_override("margin_%s" % s, 16)
		empty_panel.add_child(ep_pad)
		ep_pad.add_child(g._label(g.t("ui.codex_no_records"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
		list.add_child(empty_panel)
	else:
		for rec in hof:
			var r_panel := PanelContainer.new()
			r_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_panel.add_theme_stylebox_override("panel", g._panel(Color("10242b"), 10, g.GOLD))
			list.add_child(r_panel)

			var r_pad := MarginContainer.new()
			for s in ["left", "right", "top", "bottom"]: r_pad.add_theme_constant_override("margin_%s" % s, 10)
			r_panel.add_child(r_pad)

			var r_vbox := VBoxContainer.new()
			r_vbox.add_theme_constant_override("separation", 6)
			r_pad.add_child(r_vbox)

			var r_head := HBoxContainer.new()
			r_vbox.add_child(r_head)

			var stage_idx: int = int(rec.get("stage", 0))
			var mode_str: String = str(rec.get("mode", "campaign"))
			var st_name: String = ""
			if mode_str == "abyss":
				st_name = g.tf("ui.abyss_stage_label_fmt", stage_idx)
			elif mode_str == "trial":
				st_name = g.t("tutorial.daily_trial.title")
			else:
				st_name = g.content.stage_name(stage_idx, g.lang) if (stage_idx >= 0 and stage_idx < g.content.encounters.size()) else ("Stage %d" % (stage_idx + 1))
			var r_title := g._label("👑 " + st_name, 12, g.GOLD)
			r_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_head.add_child(r_title)

			var rec_hero_id: String = str(rec.get("hero", "fox_spirit"))
			var rec_hero_data: Dictionary = {}
			for hc in g.content.HERO_CLASSES:
				if hc.id == rec_hero_id: rec_hero_data = hc; break
			var rec_hero_name: String = g.content.hero_name(rec_hero_data, g.lang) if not rec_hero_data.is_empty() else rec_hero_id
			r_head.add_child(g._label(rec_hero_name, 11, g.JADE))

			var r_detail := HBoxContainer.new()
			r_detail.add_theme_constant_override("separation", 12)
			r_vbox.add_child(r_detail)

			var turns_lbl := g._label(g.tf("ui.codex_hof_turns_fmt", int(rec.get("turns", 1))), 10, g.MUTED)
			r_detail.add_child(turns_lbl)

			var hp_lbl := g._label(g.tf("ui.codex_hof_hp_fmt", int(rec.get("hp_left", 60))), 10, Color("e06c75"))
			r_detail.add_child(hp_lbl)

			var deck_arr: Array = rec.get("deck", [])
			var deck_lbl := g._label(g.tf("ui.codex_hof_deck_fmt", deck_arr.size()), 10, g.TEXT)
			r_detail.add_child(deck_lbl)


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
	list.add_child(_novice_journey_section())
	list.add_child(_season_pass_banner())
	list.add_child(_login_reward_section())
	g._ensure_quests_current()
	list.add_child(_quest_section(g.t("ui.quests_daily"), "daily_quests", int(g.profile.get("daily_reset_at", 0))))
	list.add_child(_quest_section(g.t("ui.quests_weekly"), "weekly_quests", int(g.profile.get("weekly_reset_at", 0))))
	list.add_child(g._label(g.t("ui.quests_hint"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

func _novice_journey_section() -> Control:
	var claimed: Array = g.profile.get("novice_journey", {}).get("claimed", [])
	if claimed.size() >= SpiritContent.NOVICE_JOURNEY_TASKS.size():
		return Control.new()

	var box := VBoxContainer.new()
	box.name = "NoviceJourneySection"
	box.add_theme_constant_override("separation", 6)

	var hdr := VBoxContainer.new()
	hdr.add_theme_constant_override("separation", 1)
	hdr.add_child(g._label(g.t("ui.novice_journey_title"), 14, Color("ffd700")))
	hdr.add_child(g._label(g.t("ui.novice_journey_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(hdr)

	# Progress bar
	var bar := g._stat_bar(120.0, 14.0, claimed.size(), SpiritContent.NOVICE_JOURNEY_TASKS.size(), Color("ffd700"), "%d / %d" % [claimed.size(), SpiritContent.NOVICE_JOURNEY_TASKS.size()], 9)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(bar)

	var scroll := TouchScrollContainer.new()
	scroll.custom_minimum_size.y = 88
	scroll.allow_horizontal = true
	scroll.allow_vertical = false
	box.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)

	for task in SpiritContent.NOVICE_JOURNEY_TASKS:
		var day_num: int = int(task.day)
		var is_claimed: bool = claimed.has(day_num)
		var target_stage: int = int(task.target_stage)
		var is_completed: bool = int(g.profile.unlocked) >= target_stage or int(g.profile.position) >= target_stage
		var is_ready: bool = is_completed and not is_claimed

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(152, 82)
		card.add_theme_stylebox_override("panel", g._panel(Color("10222a") if not is_ready else Color("193836"), 10, Color("ffd700") if is_ready else (g.JADE if is_claimed else Color("2a3c42"))))
		row.add_child(card)

		var pad := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 6)
		card.add_child(pad)

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 2)
		pad.add_child(inner)

		var t_row := HBoxContainer.new()
		t_row.add_child(g._label(g.tf("ui.novice_day_fmt", day_num), 10, g.GOLD))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t_row.add_child(sp)
		var status_text: String = g.t("ui.novice_claimed") if is_claimed else (g.t("ui.novice_completed") if is_ready else g.t("ui.novice_locked"))
		t_row.add_child(g._label(status_text, 9, g.JADE if (is_claimed or is_ready) else g.MUTED))
		inner.add_child(t_row)

		var task_title: String = task.get("title_en" if g.lang == "en" else "title_zh", "")
		inner.add_child(g._label(task_title, 10, g.TEXT))

		var rew_row := HBoxContainer.new()
		rew_row.add_theme_constant_override("separation", 4)
		rew_row.add_child(g._label("◆%d" % int(task.gold), 9, g.GOLD))
		rew_row.add_child(g._label("✧%d" % int(task.jade), 9, Color("78e9c0")))
		rew_row.add_child(g._label("❖%d" % int(task.dust), 9, Color("c79bff")))
		inner.add_child(rew_row)

		if is_ready:
			var claim_btn := g._button(g.t("ui.novice_claim"), func():
				if not g.profile.has("novice_journey"): g.profile.novice_journey = {"claimed":[]}
				var c_arr: Array = g.profile.novice_journey.get("claimed", []).duplicate()
				c_arr.append(day_num)
				g.profile.novice_journey.claimed = c_arr
				g.profile.gold += int(task.gold)
				g.profile.spirit_jade = int(g.profile.get("spirit_jade", 0)) + int(task.jade)
				g.profile.spirit_dust = int(g.profile.get("spirit_dust", 0)) + int(task.dust)
				SpiritSave.write(g.profile)
				g._haptic("heavy")
				g._toast(g.tf("ui.novice_reward_toast", day_num), g.GOLD)
				show_quests()
			, Color("204a3f"), Vector2(0, 22))
			claim_btn.name = "NoviceClaimBtn_%d" % day_num
			claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inner.add_child(claim_btn)

	return box

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
	list.add_child(_meridian_cultivation_section())
	list.add_child(_hero_archetypes_section())

# "Modes you enter": the two challenge tracks (Daily Trial, Endless Abyss) plus the campaign's
# own difficulty ladder — all three answer "what am I about to go fight," not "who am I" or
# "what have I collected."
func _build_camp_challenges(list: VBoxContainer) -> void:
	list.add_child(_leaderboard_entry_section())
	list.add_child(_friends_section())
	list.add_child(_world_event_section())
	list.add_child(_phantom_arena_section())
	list.add_child(_draft_arena_section())
	list.add_child(_daily_trial_section())
	list.add_child(_weekly_challenge_section())
	list.add_child(_boss_rush_section())
	list.add_child(_curse_run_section())
	list.add_child(_sandbox_section())
	list.add_child(_abyss_section())
	list.add_child(_difficulty_tier_section())
	list.add_child(_samsara_section())

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
	var tier_label := g.t("ui.camp_tier_a6_name") if int(g.profile.difficulty) == 6 else g.tf("ui.camp_tier", g.profile.difficulty)
	section.add_child(g._label(tier_label, 17, g.JADE if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if not unlocked:
		section.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch5"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_CENTER, true))
		return section
	# C2: each Samsara cycle raises the max selectable tier by one past the original A0-A5
	# ceiling (see content.difficulty_modifier() for why tier now actually matters — it used
	# to be purely cosmetic). HFlowContainer instead of HBoxContainer so an arbitrary number
	# of tiers (a player who cycles through samsara many times) wraps onto more rows instead of
	# squeezing ever-thinner on a fixed 390px-wide screen. Uncapped rather than a flat "A6 once
	# and never again" ceiling, so a later samsara cycle keeps raising the stakes instead of
	# repeating the same A6 tier forever.
	var max_tier: int = 5 + int(g.profile.get("samsara_count", 0))
	# Only reveal tiers the player has actually earned instead of opening all of A0-A5 (and any
	# samsara-extended tiers) the instant this section's own overall gate unlocks — A5 alone is
	# +60% enemy HP and +5 flat damage (see content.difficulty_modifier()), a real risk to hand a
	# player only 25 stages in with no guardrail at all. maxi() against profile.difficulty
	# grandfathers in whatever a player already selected under the old all-at-once behavior (or
	# any samsara-extended tier past 5, which is its own much stronger gate) — this can only ever
	# reveal tiers going forward, never retroactively hide one a player already has active.
	var eligible_max_tier: int = int(g.profile.difficulty)
	for t in range(1, max_tier + 1):
		if int(g.profile.unlocked) >= g.content.difficulty_tier_unlock_stage(t):
			eligible_max_tier = maxi(eligible_max_tier, t)
	eligible_max_tier = mini(eligible_max_tier, max_tier)
	var row := HFlowContainer.new()
	row.name = "DifficultyTierRow"
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	for value in eligible_max_tier + 1:
		var button := g._button("A%d"%value, func(): g.profile.difficulty=value; g._check_feature_unlocks(); SpiritSave.write(g.profile); show_camp(), Color("245247") if value==g.profile.difficulty else Color("17363e"), Vector2(46,40))
		button.name = "DifficultyTierBtn_A%d" % value
		# A tier the player hasn't actually selected yet gets a small marker so a newly-earned
		# option doesn't just silently blend in among the others — the one-time toast from
		# _check_feature_unlocks() covers the moment it unlocks, this covers every visit after
		# until they actually try it.
		if value > int(g.profile.difficulty):
			g._add_notification_dot(button, Vector2(46, 40))
		row.add_child(button)
	section.add_child(row)
	# Capped at 5: a tier past 5 is samsara-gated (full 250-stage clear, not a stage threshold at
	# all — see ui.camp_tier_samsara_unlocked/ui.samsara_locked_desc below), and
	# difficulty_tier_unlock_stage() clamps any tier past the table's end to its last real entry
	# (200), so without this cap a player already at eligible_max_tier=5 with one samsara cycle
	# done (max_tier=6) would see a stale "clear stage 200" hint for a tier that stage progress
	# alone can never actually unlock.
	if eligible_max_tier < mini(5, max_tier):
		section.add_child(g._label(g.tf("ui.camp_tier_next_unlock", g.content.difficulty_tier_unlock_stage(eligible_max_tier + 1)), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	if max_tier > 5:
		section.add_child(g._label(g.tf("ui.camp_tier_samsara_unlocked", max_tier), 10, Color("ff6b9d"), HORIZONTAL_ALIGNMENT_CENTER, true))
	section.add_child(g._label(g.t("ui.camp_desc"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	return section

# C2: Samsara (轮回) — eligibility is deliberately just these two already-tracked signals (full
# 250-stage clear + challenge tier currently at the max tier this many samsara cycles have
# unlocked) rather than also gating on hero mastery level: mastery is per-hero, so gating on it
# would arbitrarily punish a player who tried multiple archetypes. profile.difficulty is a
# freely-switchable "what am I fighting at right now" setting rather than a per-tier clear
# ladder, so this reads as "cleared the whole campaign, and currently set to the hardest tier
# samsara has unlocked so far" rather than a literal historical proof of having beaten every
# stage specifically at that tier — the closest verifiable signal this save shape already has.
# The required tier itself escalates with samsara_count (content.difficulty_modifier() is what
# makes that requirement mean something now, rather than a free re-tap of the same button) —
# this replaces an earlier OR-based check (unlocked >= 249 OR difficulty >= 5) that became
# trivially true forever after the first cycle, letting every later one repeat off the same
# button with no re-escalation.
func _samsara_section() -> Control:
	var samsara_cnt: int = int(g.profile.get("samsara_count", 0))
	var required_tier: int = 5 + samsara_cnt
	var can_samsara: bool = int(g.profile.unlocked) >= 250 and int(g.profile.difficulty) >= required_tier
	var panel := PanelContainer.new()
	panel.name = "SamsaraSection"
	panel.add_theme_stylebox_override("panel", g._panel(Color("0f1922"), 10, g.JADE if can_samsara else Color("22363e")))

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 10)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pad.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_child(g._label(g.t("ui.samsara_title"), 14, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var realm_str: String = g.content.samsara_title(samsara_cnt, g.lang)
	var realm_lbl := g._label(g.tf("ui.samsara_realm_fmt", realm_str), 11, g.JADE, HORIZONTAL_ALIGNMENT_RIGHT)
	realm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(realm_lbl)
	vbox.add_child(title_row)

	if samsara_cnt > 0:
		var bonus_box := VBoxContainer.new()
		bonus_box.name = "SamsaraBonusBox"
		bonus_box.add_theme_constant_override("separation", 2)
		bonus_box.add_child(g._label(g.tf("ui.samsara_count_fmt", samsara_cnt), 10, Color("80d4ff"), HORIZONTAL_ALIGNMENT_LEFT))
		var active_bonuses: Dictionary = g.content.samsara_bonuses(samsara_cnt)
		if active_bonuses.max_hp > 0:
			bonus_box.add_child(g._label(g.tf("ui.samsara_blessing_hp", active_bonuses.max_hp), 9, Color("76e59b")))
		if active_bonuses.starting_shield > 0:
			bonus_box.add_child(g._label(g.tf("ui.samsara_blessing_shield", active_bonuses.starting_shield), 9, Color("68c5ff")))
		if active_bonuses.turn1_draw > 0:
			bonus_box.add_child(g._label(g.tf("ui.samsara_blessing_draw", active_bonuses.turn1_draw), 9, Color("ffd860")))
		vbox.add_child(bonus_box)
	else:
		vbox.add_child(g._label(g.t("ui.samsara_none"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	if can_samsara:
		var enter_btn := g._button(g.t("ui.samsara_enter_btn"), func(): g.show_samsara_modal(), Color("225046"), Vector2(140, 36))
		enter_btn.name = "SamsaraEnterBtn"
		btn_row.add_child(enter_btn)
	else:
		vbox.add_child(g._label(g.tf("ui.samsara_locked_desc", required_tier), 9, Color("ff9868"), HORIZONTAL_ALIGNMENT_LEFT, true))

	var lb_btn := g._button(g.t("ui.leaderboard_open"), func(): show_leaderboard("samsara"), Color("1a3c48"), Vector2(100, 36))
	lb_btn.name = "SamsaraLeaderboardBtn"
	btn_row.add_child(lb_btn)
	vbox.add_child(btn_row)

	return panel

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
	var active_resonances: Array[Dictionary] = g.content.active_relic_resonances(g.profile.relics)
	if not active_resonances.is_empty():
		section.add_child(g._spacer(4))
		section.add_child(g._label(g.t("ui.relic_resonance_active"), 13, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		for res in active_resonances:
			var res_color := Color(res.color)
			var res_panel := Panel.new()
			res_panel.name = "ResonanceRow_%s" % str(res.get("id", ""))
			res_panel.custom_minimum_size.y = 56
			res_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var res_style := g._panel(Color("162024"), 12, res_color)
			res_style.border_width_left = 2; res_style.border_width_right = 2; res_style.border_width_top = 2; res_style.border_width_bottom = 2
			res_panel.add_theme_stylebox_override("panel", res_style)
			section.add_child(res_panel)

			var res_pad := MarginContainer.new()
			res_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for side in ["left", "right"]: res_pad.add_theme_constant_override("margin_%s" % side, 10)
			res_panel.add_child(res_pad)

			var res_row := HBoxContainer.new()
			res_row.add_theme_constant_override("separation", 10)
			res_pad.add_child(res_row)

			var res_holder := CenterContainer.new()
			res_holder.add_child(g._relic_resonance_badge(res, res_color, 38))
			res_row.add_child(res_holder)

			var res_texts := VBoxContainer.new()
			res_texts.alignment = BoxContainer.ALIGNMENT_CENTER
			res_texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			res_texts.add_theme_constant_override("separation", 1)
			res_row.add_child(res_texts)

			res_texts.add_child(g._label(g._relic_resonance_name(res) + "  ✦", 12, g.GOLD))
			res_texts.add_child(g._label(g._relic_resonance_detail(res), 9, res_color, HORIZONTAL_ALIGNMENT_LEFT, true))
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

func _split_horizontal_gradient(bg_color: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([bg_color, bg_color, Color(bg_color.r, bg_color.g, bg_color.b, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.46, 0.74])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 0.0)
	tex.width = 256
	tex.height = 16
	return tex

func _split_card_frame(banner_path: String, unlocked: bool, bg_color: Color, border_color: Color, min_height: float = 126.0) -> Dictionary:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(0, min_height)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", g._panel(bg_color, 14, border_color))

	# 1. Art Background (Full rect, STRETCH_KEEP_ASPECT_COVERED)
	var banner := TextureRect.new()
	banner.name = "BannerBg"
	if ResourceLoader.exists(banner_path):
		banner.texture = load(banner_path)
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate = Color(1.0, 1.0, 1.0, 0.95) if unlocked else Color(0.45, 0.45, 0.5, 0.35)
	panel.add_child(banner)

	# 2. Left-to-Right Horizontal Fade Scrim (Dark solid on left 46%, soft fade 46%-74%, transparent 74%-100%)
	var scrim := TextureRect.new()
	scrim.name = "SplitScrim"
	scrim.texture = _split_horizontal_gradient(bg_color)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(scrim)

	# 3. Content Pad: Left info column + Right spacer
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(pad)

	var hsplit := HBoxContainer.new()
	hsplit.add_theme_constant_override("separation", 8)
	pad.add_child(hsplit)

	var left_stack := VBoxContainer.new()
	left_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_stack.size_flags_stretch_ratio = 1.35
	left_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	left_stack.add_theme_constant_override("separation", 4)
	hsplit.add_child(left_stack)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.size_flags_stretch_ratio = 0.95
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hsplit.add_child(right_spacer)

	return {"panel": panel, "left": left_stack, "bg": banner}

func _phantom_arena_section() -> Control:
	g._ensure_phantom_arena_current()
	var arena: Dictionary = g.profile.get("phantom_arena", {})
	var wins: int = int(arena.get("wins_today", 0))
	var claimed: bool = bool(arena.get("claimed_today", false))
	var bg_col := Color("142226")
	var border_col := g.JADE
	var frame := _split_card_frame("res://assets/banners/banner_phantom_arena.png", true, bg_col, border_col, 120.0)
	var panel: PanelContainer = frame.panel
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.phantom_arena_title"), 15, g.JADE, HORIZONTAL_ALIGNMENT_LEFT))
	left.add_child(g._label(g.t("ui.phantom_arena_sub"), 9, Color("bde8df"), HORIZONTAL_ALIGNMENT_LEFT, true))

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	stats.add_theme_constant_override("separation", 10)
	stats.add_child(g._label(g.tf("ui.phantom_arena_daily_won", wins), 10, g.GOLD))
	left.add_child(stats)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	var enter_btn := g._button(g.t("ui.phantom_arena_challenge"), begin_phantom_arena, Color("1e4a42"), Vector2(130, 36))
	enter_btn.name = "PhantomArenaEnterBtn"
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn_row.add_child(enter_btn)

	if wins >= 1:
		var claim_btn := g._button(g.t("ui.phantom_arena_claimed") if claimed else g.t("ui.phantom_arena_claim_box"), func():
			if not claimed:
				arena.claimed_today = true
				g.profile.phantom_arena = arena
				var reward_gold := 100 + int(g.profile.unlocked) * 5
				g.profile.gold += reward_gold
				SpiritSave.write(g.profile)
				g._toast(g.tf("ui.phantom_arena_chest_toast", reward_gold), g.GOLD)
				show_challenges()
		, g.GOLD, Vector2(130, 36))
		claim_btn.name = "PhantomArenaClaimBtn"
		claim_btn.disabled = claimed
		btn_row.add_child(claim_btn)

	left.add_child(btn_row)
	return panel

# Phase 9 — World Events: unlike every other side mode's `enter → win/lose → gold` shape, which
# is active is a pure function of a rotating 4-week period (content.world_event_for_period()),
# not a choice or a daily/weekly reset roll. Repeatable at any time, like Phantom Arena/Sandbox,
# with a permanent per-event cosmetic badge (profile.world_event_record.badges) auto-granted on
# the first win of each period, mirroring Curse Run's own badge shape (Phase 8) rather than
# Phantom Arena's separate manual chest-claim button — one fewer button, and this file already
# has that exact "auto-grant on win" pattern proven out.
func _world_event_section() -> Control:
	g._ensure_world_event_current()
	var period: int = int(g.profile.world_event_record.get("period", 0))
	var ev: Dictionary = g.content.world_event_for_period(period)
	var badges: Array = g.profile.world_event_record.get("badges", [])
	var ev_color: Color = Color(str(ev.get("color", "ffffff")))
	var bg_col := Color("1a1420")
	var frame := _split_card_frame("res://assets/banners/banner_world_event.png", true, bg_col, ev_color, 132.0)
	var panel: PanelContainer = frame.panel
	panel.name = "WorldEventSection"
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.content.ui(str(ev.get("nameKey", "")), g.lang), 15, ev_color, HORIZONTAL_ALIGNMENT_LEFT))
	left.add_child(g._label(g.t("ui.world_event_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	left.add_child(g._label(g.content.ui(str(ev.get("descKey", "")), g.lang), 9, Color("d8c8ff"), HORIZONTAL_ALIGNMENT_LEFT, true))
	left.add_child(g._label(g.tf("ui.world_event_badges_fmt", badges.size()), 9, Color("ff6b9d")))

	var enter_btn := g._button(g.t("ui.world_event_enter"), begin_world_event_battle, ev_color.darkened(0.5), Vector2(140, 36))
	enter_btn.name = "WorldEventEnterBtn"
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(enter_btn)

	return panel

func begin_world_event_battle() -> void:
	g._ensure_world_event_current()
	var period: int = int(g.profile.world_event_record.get("period", 0))
	g.in_world_event = true
	var enc: Dictionary = g.content.world_event_encounter(period, int(g.profile.unlocked))
	g.current_stage = 0
	g.active_modifier = g.content.world_event_modifier(period)
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	var seed_val := g._battle_seed()
	g.combat.create(seed_val, enc, g.profile.deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = 60
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

func _daily_trial_section() -> Control:
	g._ensure_daily_trial_current()
	var unlocked := int(g.profile.unlocked) >= 5
	var bg_col := Color("1e1710") if unlocked else Color("141210")
	var border_col := Color("ffb765") if unlocked else Color("2a3d42")
	var frame := _split_card_frame("res://assets/banners/banner_daily_trial.png", unlocked, bg_col, border_col, 130.0)
	var panel: PanelContainer = frame.panel
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.daily_trial_title"), 15, Color("ffb765") if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if not unlocked:
		left.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch1"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_LEFT, true))
		var enter_btn := g._button("🔒 " + g.t("ui.locked"), begin_daily_trial, Color("2d2218"), Vector2(160, 36))
		enter_btn.name = "DailyTrialEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(enter_btn)
		return panel

	var tags: Array = g.content.daily_trial_tags(int(g.profile.daily_trial_record.day))
	var tag_names: Array = []
	for tag in tags: tag_names.append(g.content.ui(tag.nameKey, g.lang))
	var sep: String = ", " if g.lang == "en" else "、"
	left.add_child(g._label("%s: %s" % [g.t("ui.daily_trial_modifiers_title"), sep.join(tag_names)], 9, Color("ffd8a8"), HORIZONTAL_ALIGNMENT_LEFT, true))

	var stage_num: int = int(g.profile.daily_trial_record.stage)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	stats.add_theme_constant_override("separation", 8)
	stats.add_child(g._label(g.tf("ui.daily_trial_progress_fmt", stage_num), 10, g.GOLD))
	stats.add_child(g._label(g.tf("ui.daily_trial_best_fmt", int(g.profile.daily_trial_record.get("best_stage", 0))), 10, g.JADE))
	stats.add_child(g._label(g.tf("ui.daily_trial_streak_fmt", int(g.profile.daily_trial_record.get("streak", 0))), 10, Color("ff9868")))
	left.add_child(stats)
	left.add_child(_daily_trial_trend_chart())

	if stage_num >= SpiritContent.DAILY_TRIAL_STAGES:
		left.add_child(g._label(g.t("ui.daily_trial_done"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		var lb_btn := g._button(g.t("ui.leaderboard_open"), func(): show_leaderboard("daily_trial"), Color("3d4b2e"), Vector2(160, 36))
		lb_btn.name = "DailyTrialLeaderboardBtn"
		lb_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(lb_btn)
	else:
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		var enter_btn := g._button(g.t("ui.daily_trial_enter"), begin_daily_trial, Color("6b4420"), Vector2(130, 36))
		enter_btn.name = "DailyTrialEnterBtn"
		btn_row.add_child(enter_btn)
		var lb_btn := g._button(g.t("ui.leaderboard_open"), func(): show_leaderboard("daily_trial"), Color("3d4b2e"), Vector2(100, 36))
		lb_btn.name = "DailyTrialLeaderboardBtn"
		btn_row.add_child(lb_btn)
		left.add_child(btn_row)

	return panel

# E1: a small bar-per-day trend chart over daily_trial_record.history (bounded to
# SpiritContent.DAILY_TRIAL_HISTORY_LIMIT entries — see _ensure_daily_trial_current()).
# Purely local data, no backend involved. Reuses the ProgressBar-as-a-styled-rect trick
# _stat_bar() already uses, just oriented vertically (FILL_BOTTOM_TO_TOP) instead of
# horizontally, since nothing in this codebase draws a real chart primitive yet.
func _daily_trial_trend_chart() -> Control:
	var box := VBoxContainer.new()
	box.name = "DailyTrialTrendChart"
	box.add_theme_constant_override("separation", 4)
	box.add_child(g._label(g.t("ui.daily_trial_trend_title"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var history: Array = g.profile.daily_trial_record.get("history", [])
	if history.is_empty():
		box.add_child(g._label(g.t("ui.daily_trial_trend_empty"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
		return box

	var recent: Array = history.slice(maxi(0, history.size() - 14))
	var row := HBoxContainer.new()
	row.name = "DailyTrialTrendRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	var chart_height := 28.0
	for entry in recent:
		var day_stage: int = int(entry.get("stage", 0))
		var full_clear: bool = day_stage >= SpiritContent.DAILY_TRIAL_STAGES
		var bar := ProgressBar.new()
		bar.name = "TrendBar_%d" % int(entry.get("day", 0))
		bar.custom_minimum_size = Vector2(10, chart_height)
		bar.max_value = float(SpiritContent.DAILY_TRIAL_STAGES)
		bar.value = clampf(float(day_stage), 0.0, float(SpiritContent.DAILY_TRIAL_STAGES))
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", g._panel(Color(0.02, 0.06, 0.08, 0.85), 2, Color(0, 0, 0, 0.35)))
		bar.add_theme_stylebox_override("fill", g._panel(g.GOLD if full_clear else Color("ffb765"), 2))
		row.add_child(bar)
	box.add_child(row)
	return box

func _weekly_challenge_section() -> Control:
	g._ensure_weekly_challenge_current()
	var unlocked := int(g.profile.unlocked) >= 5
	var bg_col := Color("141c10") if unlocked else Color("141210")
	var border_col := Color("c8e065") if unlocked else Color("2a3d42")
	var frame := _split_card_frame("res://assets/banners/banner_weekly_challenge.png", unlocked, bg_col, border_col, 130.0)
	var panel: PanelContainer = frame.panel
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.weekly_challenge_title"), 15, Color("c8e065") if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if not unlocked:
		left.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch1"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_LEFT, true))
		var enter_btn := g._button("🔒 " + g.t("ui.locked"), begin_weekly_challenge, Color("2d2218"), Vector2(160, 36))
		enter_btn.name = "WeeklyChallengeEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(enter_btn)
		return panel

	var week: int = int(g.profile.weekly_challenge_record.week)
	var tag: Dictionary = g.content.weekly_challenge_tag(week)
	left.add_child(g._label("%s: %s" % [g.t("ui.weekly_challenge_modifier_title"), g.content.ui(tag.nameKey, g.lang)], 9, Color("e0f0a8"), HORIZONTAL_ALIGNMENT_LEFT, true))

	var stage_num: int = int(g.profile.weekly_challenge_record.stage)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	stats.add_theme_constant_override("separation", 8)
	stats.add_child(g._label(g.tf("ui.weekly_challenge_progress_fmt", stage_num), 10, g.GOLD))
	stats.add_child(g._label(g.tf("ui.weekly_challenge_best_fmt", int(g.profile.weekly_challenge_record.get("best_stage", 0))), 10, g.JADE))
	left.add_child(stats)

	if stage_num >= SpiritContent.WEEKLY_CHALLENGE_STAGES:
		left.add_child(g._label(g.t("ui.weekly_challenge_done"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	else:
		var enter_btn := g._button(g.t("ui.weekly_challenge_enter"), begin_weekly_challenge, Color("4a5c18"), Vector2(160, 36))
		enter_btn.name = "WeeklyChallengeEnterBtn"
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(enter_btn)

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
	var bg_col := Color("1b1024") if unlocked else Color("141018")
	var border_col := Color("c79bff") if unlocked else Color("2a3d42")
	var frame := _split_card_frame("res://assets/banners/banner_abyss.png", unlocked, bg_col, border_col, 116.0)
	var panel: PanelContainer = frame.panel
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.abyss_title"), 15, Color("e0b8ff") if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if not unlocked:
		left.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch2"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_LEFT, true))
		var enter_btn := g._button("🔒 " + g.t("ui.locked"), begin_abyss_battle, Color("2d1b33"), Vector2(160, 36))
		enter_btn.name = "AbyssEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(enter_btn)
		return panel

	left.add_child(g._label(g.t("ui.abyss_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var floor_num: int = int(g.profile.get("abyss_floor", 1))
	var record_num: int = int(g.profile.get("abyss_record", 0))

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	stats.add_theme_constant_override("separation", 12)
	stats.add_child(g._label(g.tf("ui.abyss_floor_fmt", floor_num), 10, g.GOLD))
	stats.add_child(g._label(g.tf("ui.abyss_record_fmt", record_num), 10, g.JADE))
	left.add_child(stats)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	var enter_btn := g._button(g.t("ui.abyss_enter"), begin_abyss_battle, Color("4a285d"), Vector2(130, 36))
	enter_btn.name = "AbyssEnterBtn"
	btn_row.add_child(enter_btn)
	var lb_btn := g._button(g.t("ui.leaderboard_open"), func(): show_leaderboard("abyss"), Color("38294a"), Vector2(100, 36))
	lb_btn.name = "AbyssLeaderboardBtn"
	btn_row.add_child(lb_btn)
	left.add_child(btn_row)

	return panel

# Refights real, already-cleared boss encounters back-to-back with no restore between fights
# beyond a small partial heal (same shape as Abyss), escalating each time the player cycles
# back through the same boss again — a genuine "how far can my current build carry me" test
# using the actual bosses fought in campaign, not a synthetic stat block like Abyss/Daily
# Trial/Weekly Challenge use.
func _boss_rush_section() -> Control:
	var unlocked := int(g.profile.unlocked) >= 5
	var bg_col := Color("241407") if unlocked else Color("181210")
	var border_col := Color("ff9a4c") if unlocked else Color("2a3d42")
	var frame := _split_card_frame("res://assets/banners/banner_boss_rush.png", unlocked, bg_col, border_col, 116.0)
	var panel: PanelContainer = frame.panel
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.boss_rush_title"), 15, g.EMBER if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if not unlocked:
		left.add_child(g._label("🔒 " + g.t("ui.lock_clears_ch1"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_LEFT, true))
		var enter_btn := g._button("🔒 " + g.t("ui.locked"), begin_boss_rush_battle, Color("2d1f14"), Vector2(160, 36))
		enter_btn.name = "BossRushEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(enter_btn)
		return panel

	left.add_child(g._label(g.t("ui.boss_rush_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var floor_num: int = int(g.profile.get("boss_rush_floor", 1))
	var record_num: int = int(g.profile.get("boss_rush_record", 0))

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	stats.add_theme_constant_override("separation", 12)
	stats.add_child(g._label(g.tf("ui.boss_rush_floor_fmt", floor_num), 10, g.GOLD))
	stats.add_child(g._label(g.tf("ui.boss_rush_record_fmt", record_num), 10, g.JADE))
	left.add_child(stats)

	var enter_btn := g._button(g.t("ui.boss_rush_enter"), begin_boss_rush_battle, Color("6b3410"), Vector2(160, 36))
	enter_btn.name = "BossRushEnterBtn"
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(enter_btn)

	return panel

func begin_boss_rush_battle() -> void:
	var boss_indices: Array = g.content.boss_rush_boss_indices(int(g.profile.unlocked))
	if boss_indices.is_empty():
		g._toast(g.t("ui.boss_rush_no_boss"))
		return
	var floor_num: int = int(g.profile.get("boss_rush_floor", 1))
	var idx: int = int(boss_indices[(floor_num - 1) % boss_indices.size()])
	# Every full cycle back through the same set of bosses ramps health/damage further, so the
	# mode stays a real test instead of a static loop once a player has beaten every boss once.
	var loop: int = (floor_num - 1) / boss_indices.size()
	g.in_boss_rush = true
	g.current_stage = idx
	var seed := g._battle_seed()
	g.active_modifier = {
		"id": "boss_rush", "name": "连战淬炼", "name_en": "Gauntlet Tempering",
		"detail": "敌人生命 +%d%%，攻击 +%d" % [int(loop * 25), loop], "detail_en": "Enemy HP +%d%%, ATK +%d" % [int(loop * 25), loop],
		"health_scale": 1.0 + float(loop) * 0.25, "damage_bonus": loop, "reward_scale": 1.5,
	}
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	g.combat.create(seed, g.content.encounters[idx], g.profile.deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(g.content.encounters[idx].name)):
		g._grant_bestiary_discovery_bonus(g.content.encounters[idx])
	g.pre_battle_health = 60
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

# Phase 8: Curse Run — an opt-in, self-selected handicap (SpiritContent.MUTATORS) fought as an
# escalating floor gauntlet, reusing content.abyss_encounter()'s own scaling rather than a new
# formula. Progress (floor/record) is tracked per mutator id, not shared, since switching from
# an easy mutator to e.g. Glass Cannon at a high floor would otherwise dump a fragile 30-max-HP
# build straight into a floor scaled for a full-HP one. A loss costs only the attempt, same
# "attempt vs. run" split every other side mode here already uses (see _leave_battle()).
func _curse_run_section() -> Control:
	var unlocked: bool = int(g.profile.difficulty) >= 2
	var bg_col := Color("1a1020") if unlocked else Color("181210")
	var border_col := Color("c9a6ff") if unlocked else Color("2a3d42")
	var frame := _split_card_frame("res://assets/banners/banner_curse_run.png", unlocked, bg_col, border_col, 196.0)
	var panel: PanelContainer = frame.panel
	panel.name = "CurseRunSection"
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.curse_run_title"), 15, Color("c9a6ff") if unlocked else g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if not unlocked:
		left.add_child(g._label("🔒 " + g.t("ui.curse_run_locked"), 10, Color("ff9868"), HORIZONTAL_ALIGNMENT_LEFT, true))
		var enter_btn := g._button("🔒 " + g.t("ui.locked"), begin_curse_run_battle, Color("221a2a"), Vector2(160, 36))
		enter_btn.name = "CurseRunEnterBtn"
		enter_btn.disabled = true
		enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(enter_btn)
		return panel

	left.add_child(g._label(g.t("ui.curse_run_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var curse_run: Dictionary = g.profile.get("curse_run", {})
	var selected_id: String = str(curse_run.get("selected", ""))
	var cleared: Array = curse_run.get("cleared", [])

	var picker := HFlowContainer.new()
	picker.name = "CurseRunPicker"
	picker.add_theme_constant_override("h_separation", 6)
	picker.add_theme_constant_override("v_separation", 6)
	for m in SpiritContent.MUTATORS:
		var mid: String = str(m.id)
		var is_sel: bool = mid == selected_id
		var badge_text: String = ("✓ " if cleared.has(mid) else "") + g.content.ui(str(m.nameKey), g.lang)
		var mbtn := g._button(badge_text, func(): _select_curse_mutator(mid), Color(str(m.color)).darkened(0.15 if is_sel else 0.7), Vector2(0, 32))
		mbtn.name = "CurseMutatorBtn_%s" % mid
		if is_sel: mbtn.add_theme_color_override("font_color", Color.BLACK)
		picker.add_child(mbtn)
	left.add_child(picker)

	if selected_id.is_empty():
		left.add_child(g._label(g.t("ui.curse_run_choose"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	else:
		var sel: Dictionary = g.content.mutator(selected_id)
		left.add_child(g._label(g.content.ui(str(sel.get("descKey", "")), g.lang), 9, Color("d8c8ff"), HORIZONTAL_ALIGNMENT_LEFT, true))
		var floor_num: int = int(curse_run.get("floors", {}).get(selected_id, 1))
		var record_num: int = int(curse_run.get("records", {}).get(selected_id, 0))
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 12)
		stats.add_child(g._label(g.tf("ui.curse_run_floor_fmt", floor_num), 10, g.GOLD))
		stats.add_child(g._label(g.tf("ui.curse_run_record_fmt", record_num), 10, g.JADE))
		left.add_child(stats)

	left.add_child(g._label(g.tf("ui.curse_run_cleared_fmt", cleared.size()), 9, Color("ff6b9d")))

	var enter_btn := g._button(g.t("ui.curse_run_enter"), begin_curse_run_battle, Color("4a285d"), Vector2(160, 36))
	enter_btn.name = "CurseRunEnterBtn"
	enter_btn.disabled = selected_id.is_empty()
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(enter_btn)

	return panel

func _select_curse_mutator(id: String) -> void:
	var curse_run: Dictionary = g.profile.get("curse_run", {})
	curse_run.selected = id
	g.profile.curse_run = curse_run
	SpiritSave.write(g.profile)
	show_challenges()

func begin_curse_run_battle() -> void:
	var curse_run: Dictionary = g.profile.get("curse_run", {})
	var selected: String = str(curse_run.get("selected", ""))
	var m: Dictionary = g.content.mutator(selected)
	if m.is_empty():
		g._toast(g.t("ui.curse_run_choose"))
		return
	g.in_curse_run = true
	var floor_num: int = int(curse_run.get("floors", {}).get(selected, 1))
	g.current_stage = 0
	var enc: Dictionary = g.content.abyss_encounter(floor_num)
	var seed := g._battle_seed()
	# active_modifier doubles as the modifier dict combat.create() reads (player_max_hp,
	# player_dmg_mult, energy_cap, mirror_hp, extra_enemy, damage_mult, no_heal, draw_penalty —
	# whichever the selected mutator carries) and the battle screen's modifier badge, which
	# reads name/name_en/detail/detail_en unconditionally (see content.daily_trial_modifier()'s
	# own trap note on this exact requirement).
	g.active_modifier = m.duplicate(true)
	g.active_modifier["name"] = g.content.ui(str(m.get("nameKey", "")), "zh-Hans")
	g.active_modifier["name_en"] = g.content.ui(str(m.get("nameKey", "")), "en")
	g.active_modifier["detail"] = g.content.ui(str(m.get("descKey", "")), "zh-Hans")
	g.active_modifier["detail_en"] = g.content.ui(str(m.get("descKey", "")), "en")
	# Haunted Deck/Ironclad Will are deliberately handled here rather than as combat.gd modifier
	# keys — one is a deck-composition change, the other an equipment-list change, neither of
	# which combat.gd needs its own generic hook for when the call site can just build the right
	# input in the first place.
	var deck: Array = g.profile.deck.duplicate()
	if m.get("haunted_deck", false): deck.append("decay_blight")
	var relics_for_run: Array = [] if m.get("no_relics", false) else g.profile.relics
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	g.combat.create(seed, enc, deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, relics_for_run, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = 60
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

# A zero-stakes practice bout against any stage the player has genuinely already reached
# (chapter*5 <= unlocked, the same frontier the map itself gates on) — always full health so a
# rough campaign run never carries into the test, no rewards so a repeated loss/win here can't
# be farmed, and profile.health is left completely untouched on the way out (_leave_battle and
# _advance_to_reward both special-case in_sandbox before either would write to it).
func _sandbox_section() -> Control:
	var bg_col := Color("0b181c")
	var border_col := Color("5ec9d6")
	var frame := _split_card_frame("res://assets/banners/banner_sandbox.png", true, bg_col, border_col, 130.0)
	var panel: PanelContainer = frame.panel
	panel.name = "SandboxSection"
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.sandbox_title"), 15, Color("7fe3ee"), HORIZONTAL_ALIGNMENT_LEFT))
	left.add_child(g._label(g.t("ui.sandbox_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var max_stage: int = int(g.profile.unlocked)
	g.sandbox_stage = clampi(g.sandbox_stage, 0, max_stage)

	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_BEGIN
	picker.add_theme_constant_override("separation", 8)
	var prev_btn := g._button("◀", func(): g.sandbox_stage = maxi(0, g.sandbox_stage - 1); show_camp(), Color("17363e"), Vector2(32, 32))
	prev_btn.name = "SandboxPrevBtn"
	prev_btn.disabled = g.sandbox_stage <= 0
	picker.add_child(prev_btn)
	var stage_lbl := g._label(g.content.stage_name(g.sandbox_stage, g.lang), 11, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	stage_lbl.name = "SandboxStageLabel"
	stage_lbl.custom_minimum_size = Vector2(110, 0)
	picker.add_child(stage_lbl)
	var next_btn := g._button("▶", func(): g.sandbox_stage = mini(max_stage, g.sandbox_stage + 1); show_camp(), Color("17363e"), Vector2(32, 32))
	next_btn.name = "SandboxNextBtn"
	next_btn.disabled = g.sandbox_stage >= max_stage
	picker.add_child(next_btn)
	left.add_child(picker)

	var enter_btn := g._button(g.t("ui.sandbox_enter"), func(): begin_sandbox_battle(g.sandbox_stage), Color("0f4a52"), Vector2(160, 36))
	enter_btn.name = "SandboxEnterBtn"
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(enter_btn)

	return panel

func begin_sandbox_battle(stage: int) -> void:
	g.in_sandbox = true
	g.current_stage = clampi(stage, 0, int(g.profile.unlocked))
	var seed := g._battle_seed()
	g.active_modifier = {}
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	# Always a fresh 60 HP (SpiritCombat.create's own baseline before relic/mastery bonuses),
	# never the player's real current health — a practice bout should never be handicapped by
	# whatever state the live campaign run happens to be in.
	g.combat.create(seed, g.content.encounters[g.current_stage], g.profile.deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

func begin_abyss_battle() -> void:
	g._maybe_show_tutorial("abyss")
	g.in_abyss = true
	var floor_num: int = int(g.profile.get("abyss_floor", 1))
	var enc: Dictionary = g.content.abyss_encounter(floor_num)
	g.current_stage = 0
	var seed := g._battle_seed()
	g.active_modifier = g._modifier(seed, floor_num)
	g.active_modifier["boons"] = g.profile.get("abyss_boons", []).duplicate()
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	g.combat.create(seed, enc, g.profile.deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = 60
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

func begin_phantom_arena() -> void:
	g._ensure_phantom_arena_current()
	var arena: Dictionary = g.profile.get("phantom_arena", {})
	g.in_phantom_arena = true
	var enc: Dictionary = g.content.phantom_arena_encounter(int(g.profile.unlocked), int(arena.get("wins_today", 0)))
	g.current_stage = 0
	g.active_modifier = {}
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	var seed_val := g._battle_seed()
	g.combat.create(seed_val, enc, g.profile.deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = 60
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

# E4 "async ghost battle": g.ghost_arena_target is set by a leaderboard row's duel button
# (_start_ghost_duel below) right before this is called — see content.ghost_arena_encounter()'s
# own comment for the full design rationale. Otherwise identical to begin_phantom_arena() above:
# the player's own real deck/relics/equipment/mastery, only the opponent Encounter differs.
func begin_ghost_arena_battle() -> void:
	g.in_ghost_arena = true
	var ghost: Dictionary = g.ghost_arena_target
	var enc: Dictionary = g.content.ghost_arena_encounter(str(ghost.get("name", "无名修士")), str(ghost.get("character_id", "fox")), str(ghost.get("category", "abyss")), int(ghost.get("score", 1)))
	# Carried onto ghost_arena_target (rather than recomputed from category+score again) so
	# _grant_stage_rewards()'s win branch can scale gold off the exact same resolved difficulty
	# this encounter actually used, without reaching back into content.gd's normalization helper.
	g.ghost_arena_target.level = int(enc.level)
	g.current_stage = 0
	g.active_modifier = {}
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	var seed_val := g._battle_seed()
	g.combat.create(seed_val, enc, g.profile.deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	# Deliberately skips _mark_discovered("bestiary", ...)/_grant_bestiary_discovery_bonus():
	# enc.name here is an arbitrary, unbounded real player name (not one of a finite, completable
	# set of real monsters or Phantom Arena's 4 fixed NPCs), so treating each newly-seen name as a
	# "new bestiary discovery" would hand out its one-time 20-gold/6-mastery-XP bonus over and
	# over — once per unique leaderboard name ever duelled, with no cap. Found before this shipped
	# by checking what that call actually does, the same way AGENTS.md's own economy traps got
	# caught: read the function before assuming its name matches its safety.
	g.pre_battle_health = 60
	g.advancing_to_reward = false
	g.selected_card = -1
	g.show_battle()
	g._maybe_end_turn()

# Bound via .bind() from show_leaderboard()'s per-row duel button rather than captured directly
# in a per-iteration button lambda — same reasoning as _set_leaderboard_scope's own comment.
func _start_ghost_duel(ghost_name: String, char_id: String, category: String, score: int) -> void:
	g.ghost_arena_target = {"name": ghost_name, "character_id": char_id, "category": category, "score": score}
	_close_leaderboard_modal()
	begin_ghost_arena_battle()

func begin_daily_trial() -> void:
	g._maybe_show_tutorial("daily_trial")
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
	g.combat.create(day * 1000 + stage_num, enc, g.profile.deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = 60
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
	g.combat.create(week * 1000 + stage_num, enc, g.profile.deck, 60, g.profile.upgrades, equipped, g.profile.card_runes, g.active_modifier, g.profile.relics, g._current_hero_mastery_bonuses(), g.profile.equipment_tiers, g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(g._combat_event)
	if g._mark_discovered("bestiary", str(enc.name)):
		g._grant_bestiary_discovery_bonus(enc)
	g.pre_battle_health = 60
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

	var frame := _split_card_frame("res://assets/banners/banner_season_pass.png", true, Color("0e1c22"), g.GOLD, 106.0)
	var panel: PanelContainer = frame.panel
	panel.name = "SeasonPassBanner"
	var left: VBoxContainer = frame.left

	var title_lbl := g._label(g.t("ui.season_pass_banner_title"), 13, g.GOLD)
	left.add_child(title_lbl)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	var lvl_lbl := g._label(g.tf("ui.season_pass_level_fmt", lvl), 11, g.TEXT)
	progress_row.add_child(lvl_lbl)
	var xp_lbl := g._label("%d / %d XP" % [xp_in_level, xp_req], 10, g.JADE)
	progress_row.add_child(xp_lbl)
	left.add_child(progress_row)

	var bar := g._stat_bar(130.0, 10.0, xp_in_level, xp_req, g.GOLD, "", 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(bar)

	var btn_view := g._button(g.t("ui.season_pass_view"), show_season_pass, g.EMBER, Vector2(100, 32))
	btn_view.name = "SeasonPassViewBtn"
	btn_view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if _has_claimable_season_pass_reward():
		g._add_notification_dot(btn_view, Vector2(100, 32))
	left.add_child(btn_view)

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

	var frame := _split_card_frame("res://assets/banners/banner_draft_arena.png", true, Color("101b22"), g.GOLD, 116.0)
	var panel: PanelContainer = frame.panel
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.draft_arena_title"), 14, g.GOLD))
	left.add_child(g._label(g.t("ui.draft_arena_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	if is_active:
		left.add_child(g._label(g.tf("ui.draft_win_fmt", [wins, losses]), 11, g.JADE))

	var action_btn_text: String = g.tf("ui.draft_continue_btn", wins) if is_active else g.t("ui.draft_start_btn")
	var btn := g._button(action_btn_text, show_spirit_draft, g.EMBER, Vector2(130, 36))
	btn.name = "DraftArenaEnterBtn"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(btn)

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
		tinfo.add_child(g._label(g.tf("ui.draft_card_cost_fmt", [cname, int(card.cost)]), 13, g.TEXT))
		tinfo.add_child(g._label(g._card_description(card), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

		var pick_btn := g._button(g.t("ui.claim"), func(): _pick_draft_card(card_id), g.EMBER, Vector2(74, 38))
		pick_btn.name = "DraftPickBtn_" + card_id
		pick_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		trow.add_child(pick_btn)

		content_col.add_child(tile)

	# Current Deck summary at bottom
	var current_deck: Array = draft.get("deck", [])
	content_col.add_child(g._label(g.tf("ui.draft_deck_progress_fmt", [current_deck.size(), ", ".join(current_deck)]), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

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
	col.add_child(g._label(g.t("ui.draft_deck_label"), 12, g.TEXT))

	var deck: Array = draft.get("deck", [])
	col.add_child(g._label(", ".join(deck), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var start_battle_btn := g._button(g.tf("ui.draft_next_opponent_fmt", wins + 1), _start_draft_battle, g.EMBER, Vector2(0, 44))
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
	g._reset_draft_run()
	show_challenges()

func _leaderboard_entry_section() -> Control:
	var bg_col := Color("101d25")
	var border_col := g.GOLD
	var frame := _split_card_frame("res://assets/banners/banner_phantom_arena.png", true, bg_col, border_col, 110.0)
	var panel: PanelContainer = frame.panel
	panel.name = "LeaderboardSection"
	var left: VBoxContainer = frame.left

	left.add_child(g._label(g.t("ui.leaderboard_title") + " 🏆", 15, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	left.add_child(g._label(g.t("ui.leaderboard_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var open_btn := g._button(g.t("ui.leaderboard_open"), func(): show_leaderboard("abyss"), Color("225046"), Vector2(140, 36))
	open_btn.name = "LeaderboardOpenBtn"
	open_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(open_btn)

	return panel

func _friends_section() -> Control:
	var panel := PanelContainer.new()
	panel.name = "FriendsSection"
	panel.custom_minimum_size = Vector2(0, 96)
	panel.add_theme_stylebox_override("panel", g._panel(Color("101d25"), 12, g.JADE))

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 10)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pad.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	title_box.add_child(g._label(g.t("ui.friends_title") + " 👥", 14, g.JADE, HORIZONTAL_ALIGNMENT_LEFT))
	title_box.add_child(g._label(g.t("ui.friends_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	top_row.add_child(title_box)

	var open_btn := g._button(g.t("ui.friends_manage_btn"), func(): show_friends_modal(), Color("225046"), Vector2(100, 34))
	open_btn.name = "FriendsManageBtn"
	open_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(open_btn)
	vbox.add_child(top_row)

	var friend_list: Array = g.profile.get("friends", [])
	vbox.add_child(g._label(g.tf("ui.friends_count", [friend_list.size(), SpiritContent.FRIEND_LIST_MAX]), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))

	return panel

# Only letters/digits/underscore/hyphen: covers a real Supabase auth UUID and the
# "apple_"/"google_"-prefixed sandbox ids alike, while rejecting anything that could smuggle
# extra characters into the user_id=in.(...) filter this code is pasted into (see
# SupabaseClient.fetch_leaderboard_for_users) — belt-and-suspenders alongside that function's
# own uri_encode() on every id.
func _is_valid_friend_code(code: String) -> bool:
	if code.length() < 6 or code.length() > 64: return false
	for i in code.length():
		var c := code.unicode_at(i)
		var is_upper := c >= 65 and c <= 90
		var is_lower := c >= 97 and c <= 122
		var is_digit := c >= 48 and c <= 57
		var is_symbol := c == 95 or c == 45 # '_' or '-'
		if not (is_upper or is_lower or is_digit or is_symbol): return false
	return true

func _remove_friend(fid: String, list: VBoxContainer) -> void:
	var current: Array = g.profile.get("friends", [])
	for j in current.size():
		if str(current[j].get("user_id", "")) == fid:
			current.remove_at(j)
			break
	g.profile.friends = current
	SpiritSave.write(g.profile)
	g._toast(g.t("ui.friends_removed_toast"), g.MUTED)
	_rebuild_friends_list(list)

func _add_friend(code_input: LineEdit, nickname_input: LineEdit, list: VBoxContainer) -> void:
	var raw_code := code_input.text.strip_edges()
	var nickname := nickname_input.text.strip_edges()
	if raw_code.is_empty():
		g._toast(g.t("ui.friends_add_err_empty"), g.EMBER)
		return
	if not _is_valid_friend_code(raw_code):
		g._toast(g.t("ui.friends_add_err_invalid"), g.EMBER)
		return
	var my_id: String = str(g.profile.get("account", {}).get("user_id", ""))
	if not my_id.is_empty() and raw_code == my_id:
		g._toast(g.t("ui.friends_add_err_self"), g.EMBER)
		return
	var current: Array = g.profile.get("friends", [])
	for f in current:
		if str(f.get("user_id", "")) == raw_code:
			g._toast(g.t("ui.friends_add_err_duplicate"), g.EMBER)
			return
	if current.size() >= SpiritContent.FRIEND_LIST_MAX:
		g._toast(g.t("ui.friends_add_err_full"), g.EMBER)
		return
	current.append({"user_id": raw_code, "name": nickname})
	g.profile.friends = current
	SpiritSave.write(g.profile)
	code_input.text = ""
	nickname_input.text = ""
	g._toast(g.t("ui.friends_added_toast"), g.GOLD)
	_rebuild_friends_list(list)

func _rebuild_friends_list(list: VBoxContainer) -> void:
	for ch in list.get_children():
		list.remove_child(ch)
		ch.queue_free()
	var friends: Array = g.profile.get("friends", [])
	if friends.is_empty():
		list.add_child(g._label(g.t("ui.friends_empty_list"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	for i in friends.size():
		var f: Dictionary = friends[i]
		var fid: String = str(f.get("user_id", ""))
		var fname: String = str(f.get("name", ""))
		if fname.is_empty(): fname = fid.substr(0, mini(10, fid.length()))

		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", g._panel(Color("14242e") if i % 2 == 0 else Color("0f1c24"), 6, Color("1a3543")))
		var row_h := HBoxContainer.new()
		row_h.add_theme_constant_override("separation", 6)
		var n_lbl := g._label(fname, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n_lbl.clip_text = true
		row_h.add_child(n_lbl)
		var remove_btn := g._button("✕", _remove_friend.bind(fid, list), Color("3a1c1c"), Vector2(30, 30))
		remove_btn.name = "FriendsRemoveBtn_" + fid
		row_h.add_child(remove_btn)
		row.add_child(row_h)
		list.add_child(row)

func _close_friends_modal() -> void:
	if g.overlay == null: return
	var existing: Node = g.overlay.get_node_or_null("FriendsModal")
	if existing != null:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

func show_friends_modal() -> void:
	_close_friends_modal()

	var modal := g._modal_dialog("FriendsModal", func(): _close_friends_modal())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "FriendsModalPanel"
	var vp_w: int = int(g.get_viewport_rect().size.x)
	panel.custom_minimum_size = Vector2(mini(340, vp_w - 24), 480)
	panel.add_theme_stylebox_override("panel", g._panel(Color("0a1419"), 14, g.JADE))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(g._label(g.t("ui.friends_modal_title") + " 👥", 15, g.JADE, HORIZONTAL_ALIGNMENT_LEFT))
	header_row.add_child(title_box)
	var close_btn := g._button("✕", func(): _close_friends_modal(), Color("223640"), Vector2(32, 32))
	close_btn.name = "FriendsCloseBtn"
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(close_btn)
	vbox.add_child(header_row)

	# My Code panel
	var code_panel := PanelContainer.new()
	code_panel.add_theme_stylebox_override("panel", g._panel(Color("0f222b"), 8, g.GOLD))
	var code_pad := MarginContainer.new()
	for s in ["left", "right"]: code_pad.add_theme_constant_override("margin_%s" % s, 8)
	for s in ["top", "bottom"]: code_pad.add_theme_constant_override("margin_%s" % s, 6)
	code_panel.add_child(code_pad)
	vbox.add_child(code_panel)

	if SpiritSave.is_cloud_linked(g.profile):
		var code_row := HBoxContainer.new()
		code_row.add_theme_constant_override("separation", 6)
		code_pad.add_child(code_row)
		var my_code: String = str(g.profile.get("account", {}).get("user_id", ""))
		var code_box := VBoxContainer.new()
		code_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code_box.add_theme_constant_override("separation", 2)
		code_box.add_child(g._label(g.t("ui.friends_my_code_label"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		var code_lbl := g._label(my_code, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		code_lbl.clip_text = true
		code_box.add_child(code_lbl)
		code_row.add_child(code_box)
		var copy_btn := g._button(g.t("ui.friends_copy_btn"), func():
			g._clipboard_set(my_code)
			g._toast(g.t("ui.friends_code_copied"), g.GOLD)
		, Color("17363e"), Vector2(64, 34))
		copy_btn.name = "FriendsCopyCodeBtn"
		code_row.add_child(copy_btn)
	else:
		var link_col := VBoxContainer.new()
		link_col.add_theme_constant_override("separation", 6)
		code_pad.add_child(link_col)
		link_col.add_child(g._label(g.t("ui.friends_need_link"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
		var link_btn := g._button(g.t("ui.settings_account"), func():
			_close_friends_modal()
			g.show_settings()
		, Color("1a2f36"), Vector2(0, 34))
		link_btn.name = "FriendsLinkAccountBtn"
		link_col.add_child(link_btn)

	# Add Friend row
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)

	var code_input := LineEdit.new()
	code_input.name = "FriendsCodeInput"
	code_input.placeholder_text = g.t("ui.friends_code_placeholder")
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_input.custom_minimum_size = Vector2(0, 36)
	add_row.add_child(code_input)

	var nickname_input := LineEdit.new()
	nickname_input.name = "FriendsNicknameInput"
	nickname_input.placeholder_text = g.t("ui.friends_nickname_placeholder")
	nickname_input.custom_minimum_size = Vector2(90, 36)
	add_row.add_child(nickname_input)
	vbox.add_child(add_row)

	# Friends list
	var scroll := TouchScrollContainer.new()
	scroll.name = "FriendsScroll"
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 220
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "FriendsList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var add_btn := g._button(g.t("ui.friends_add_btn"), _add_friend.bind(code_input, nickname_input, list), g.EMBER, Vector2(0, 38))
	add_btn.name = "FriendsAddBtn"
	vbox.add_child(add_btn)

	_rebuild_friends_list(list)

func _close_leaderboard_modal() -> void:
	if g.overlay == null: return
	var existing: Node = g.overlay.get_node_or_null("LeaderboardModal")
	if existing != null:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

# Bound via .bind() from show_leaderboard()'s scope-toggle buttons rather than captured
# directly in a per-iteration button lambda — matches the same .bind(cat_id) convention the
# category tabs just below it already use, since .bind() evaluates scope_id immediately as a
# normal argument instead of relying on lambda-closure-over-loop-variable semantics.
func _set_leaderboard_scope(scope_id: String, current_scope: Array, update_view: Callable, current_category: Array) -> void:
	current_scope[0] = scope_id
	update_view.call(current_category[0])

func show_leaderboard(default_category: String = "abyss") -> void:
	_close_leaderboard_modal()

	var modal := g._modal_dialog("LeaderboardModal", func(): _close_leaderboard_modal())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "LeaderboardModalPanel"
	var vp_w: int = int(g.get_viewport_rect().size.x)
	panel.custom_minimum_size = Vector2(mini(350, vp_w - 24), 520)
	panel.add_theme_stylebox_override("panel", g._panel(Color("0a1419"), 14, g.GOLD))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	title_box.add_child(g._label(g.t("ui.leaderboard_title") + " 🏆", 15, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	title_box.add_child(g._label(g.t("ui.leaderboard_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	header_row.add_child(title_box)

	var close_btn := g._button("✕", func(): _close_leaderboard_modal(), Color("223640"), Vector2(32, 32))
	close_btn.name = "LeaderboardCloseBtn"
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(close_btn)
	vbox.add_child(header_row)

	# Scope Toggle: Global vs Friends (E3 Part 2) — friends scope filters the same table to
	# just the player's own id plus profile.friends via SupabaseClient.fetch_leaderboard_for_users.
	var scope_row := HBoxContainer.new()
	scope_row.name = "LeaderboardScopeRow"
	scope_row.add_theme_constant_override("separation", 6)
	vbox.add_child(scope_row)
	var scope_buttons: Dictionary = {}
	var current_scope: Array = ["global"]

	# Category Tabs
	var tab_row := HBoxContainer.new()
	tab_row.name = "LeaderboardTabRow"
	tab_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tab_row)

	var categories := ["abyss", "daily_trial", "samsara"]
	var tab_buttons: Dictionary = {}
	var current_category: Array = [default_category]

	# Table Column Subheader & Refresh
	var col_header := HBoxContainer.new()
	col_header.add_theme_constant_override("separation", 8)
	var rank_title := g._label(g.t("ui.leaderboard_rank"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	rank_title.custom_minimum_size.x = 42
	col_header.add_child(rank_title)
	var player_title := g._label(g.t("ui.leaderboard_player"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	player_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_header.add_child(player_title)
	var score_title := g._label(g.t("ui.leaderboard_score"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	score_title.custom_minimum_size.x = 75
	col_header.add_child(score_title)
	var refresh_btn := g._button(g.t("ui.leaderboard_refresh"), Callable(), Color("17363e"), Vector2(64, 24))
	refresh_btn.name = "LeaderboardRefreshBtn"
	col_header.add_child(refresh_btn)
	vbox.add_child(col_header)

	# Scroll Container for Rankings
	var scroll := TouchScrollContainer.new()
	scroll.name = "LeaderboardScroll"
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 250
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "LeaderboardList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	# My Standing Panel
	var my_panel := PanelContainer.new()
	my_panel.name = "MyStandingPanel"
	my_panel.add_theme_stylebox_override("panel", g._panel(Color("0f222b"), 8, g.JADE))
	var my_pad := MarginContainer.new()
	for s in ["left", "right"]: my_pad.add_theme_constant_override("margin_%s" % s, 8)
	for s in ["top", "bottom"]: my_pad.add_theme_constant_override("margin_%s" % s, 6)
	my_panel.add_child(my_pad)
	vbox.add_child(my_panel)

	# Update function
	var update_view = func(cat: String) -> void:
		current_category[0] = cat
		for c in categories:
			var b: Button = tab_buttons.get(c)
			if b != null:
				b.add_theme_stylebox_override("normal", g._panel(Color("225046") if c == cat else Color("122228"), 6, g.GOLD if c == cat else Color("2a434d")))
		for sc in ["global", "friends"]:
			var sb: Button = scope_buttons.get(sc)
			if sb != null:
				sb.add_theme_stylebox_override("normal", g._panel(Color("225046") if sc == current_scope[0] else Color("122228"), 6, g.GOLD if sc == current_scope[0] else Color("2a434d")))
		for ch in list.get_children():
			list.remove_child(ch)
			ch.queue_free()
		var loading_lbl := g._label(g.t("ui.leaderboard_loading"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		list.add_child(loading_lbl)

		for ch in my_pad.get_children():
			my_pad.remove_child(ch)
			ch.queue_free()

		var res: Dictionary
		if current_scope[0] == "friends":
			var my_id: String = str(g.profile.get("account", {}).get("user_id", ""))
			var friend_ids: Array = []
			if not my_id.is_empty(): friend_ids.append(my_id)
			for f in g.profile.get("friends", []):
				var fid: String = str(f.get("user_id", ""))
				if not fid.is_empty() and not friend_ids.has(fid): friend_ids.append(fid)
			res = await SupabaseClient.fetch_leaderboard_for_users(cat, friend_ids, g)
		else:
			res = await SupabaseClient.fetch_leaderboard(cat, 50, g)
		if not is_instance_valid(list) or not list.is_inside_tree(): return

		for ch in list.get_children():
			list.remove_child(ch)
			ch.queue_free()

		var entries: Array = res.get("entries", [])
		if entries.is_empty():
			var empty_key := "ui.leaderboard_friends_empty" if current_scope[0] == "friends" else "ui.leaderboard_empty"
			list.add_child(g._label(g.t(empty_key), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		else:
			for i in entries.size():
				var entry: Dictionary = entries[i]
				var rank: int = int(entry.get("rank", i + 1))
				var name_str: String = str(entry.get("player_name", "无名修士"))
				var char_id: String = str(entry.get("character_id", "fox"))
				var score_num: int = int(entry.get("score", 0))

				var row := PanelContainer.new()
				var bg_col: Color = Color("14242e") if i % 2 == 0 else Color("0f1c24")
				var bdr_col: Color = Color("ffd700") if rank == 1 else (Color("d8e2ec") if rank == 2 else (Color("cd7f32") if rank == 3 else Color("1a3543")))
				row.add_theme_stylebox_override("panel", g._panel(bg_col, 6, bdr_col))
				row.custom_minimum_size.y = 34

				var row_h := HBoxContainer.new()
				row_h.add_theme_constant_override("separation", 6)

				var rank_str := "🥇 1" if rank == 1 else ("🥈 2" if rank == 2 else ("🥉 3" if rank == 3 else "#%d" % rank))
				var rank_col := Color("ffd700") if rank == 1 else (Color("d8e2ec") if rank == 2 else (Color("cd7f32") if rank == 3 else Color("859ba6")))
				var r_lbl := g._label(rank_str, 11, rank_col, HORIZONTAL_ALIGNMENT_CENTER)
				r_lbl.custom_minimum_size.x = 42
				row_h.add_child(r_lbl)

				var icon := TextureRect.new()
				icon.custom_minimum_size = Vector2(24, 24)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.texture = g._get_character_texture(char_id)
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row_h.add_child(icon)

				var n_lbl := g._label(name_str, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
				n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				n_lbl.clip_text = true
				row_h.add_child(n_lbl)

				var score_str := ""
				if cat == "abyss":
					score_str = g.tf("ui.leaderboard_score_floor", score_num)
				elif cat == "daily_trial":
					score_str = g.tf("ui.leaderboard_score_pts", score_num)
				elif cat == "samsara":
					if score_num >= 10:
						score_str = g.tf("ui.leaderboard_score_asc", [int(score_num / 10), int(score_num % 10)])
					else:
						score_str = g.tf("ui.leaderboard_score_pts", score_num)
				var s_lbl := g._label(score_str, 11, g.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
				s_lbl.custom_minimum_size.x = 90
				row_h.add_child(s_lbl)

				# E4: duel this entry as a synthesized encounter (see content.ghost_arena_encounter()).
				var duel_btn := g._button("⚔", _start_ghost_duel.bind(name_str, char_id, cat, score_num), Color("3a1c1c"), Vector2(26, 26))
				duel_btn.name = "GhostDuelBtn_%d" % i
				row_h.add_child(duel_btn)

				row.add_child(row_h)
				list.add_child(row)

		# Build My Standing
		var my_h := HBoxContainer.new()
		my_h.add_theme_constant_override("separation", 6)

		var my_p_name: String = str(g.profile.get("name", ""))
		if my_p_name.is_empty(): my_p_name = str(g.profile.get("account", {}).get("username", ""))
		if my_p_name.is_empty(): my_p_name = "驭灵者"

		var my_hero_class: String = str(g.profile.get("hero_class", "fox_spirit"))
		var my_char_id := "fox"
		if my_hero_class.begins_with("sentinel"): my_char_id = "sentinel"
		elif my_hero_class.begins_with("ironclad"): my_char_id = "ironclad"
		elif my_hero_class.begins_with("miasma"): my_char_id = "miasma_witch"
		elif my_hero_class.begins_with("crane"): my_char_id = "crane"
		elif my_hero_class.begins_with("phoenix"): my_char_id = "phoenix"

		var my_score: int = 0
		if cat == "abyss":
			my_score = int(g.profile.get("abyss_record", 0))
		elif cat == "daily_trial":
			var best_s: int = int(g.profile.daily_trial_record.get("best_stage", 0))
			var streak: int = int(g.profile.daily_trial_record.get("streak", 0))
			my_score = best_s * 1000 + streak * 100
		elif cat == "samsara":
			my_score = int(g.profile.get("samsara_count", 0)) * 10 + int(g.profile.get("difficulty", 0))

		var my_rank_str := g.t("ui.leaderboard_unranked")
		for i in entries.size():
			var entry: Dictionary = entries[i]
			if str(entry.get("player_name", "")) == my_p_name:
				my_rank_str = "#%d" % int(entry.get("rank", i + 1))
				break

		var my_rank_lbl := g._label(g.t("ui.leaderboard_my_rank") + ": " + my_rank_str, 10, g.JADE, HORIZONTAL_ALIGNMENT_LEFT)
		my_rank_lbl.custom_minimum_size.x = 90
		my_h.add_child(my_rank_lbl)

		var my_icon := TextureRect.new()
		my_icon.custom_minimum_size = Vector2(20, 20)
		my_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		my_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		my_icon.texture = g._get_character_texture(my_char_id)
		my_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		my_h.add_child(my_icon)

		var my_name_lbl := g._label(my_p_name, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		my_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		my_name_lbl.clip_text = true
		my_h.add_child(my_name_lbl)

		var my_score_str := ""
		if cat == "abyss":
			my_score_str = g.tf("ui.leaderboard_score_floor", my_score)
		elif cat == "daily_trial":
			my_score_str = g.tf("ui.leaderboard_score_pts", my_score)
		elif cat == "samsara":
			if my_score >= 10:
				my_score_str = g.tf("ui.leaderboard_score_asc", [int(my_score / 10), int(my_score % 10)])
			else:
				my_score_str = g.tf("ui.leaderboard_score_pts", my_score)
		var my_s_lbl := g._label(my_score_str, 10, g.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		my_s_lbl.custom_minimum_size.x = 80
		my_h.add_child(my_s_lbl)

		my_pad.add_child(my_h)

	var tab_names := {
		"abyss": g.t("ui.leaderboard_tab_abyss"),
		"daily_trial": g.t("ui.leaderboard_tab_daily"),
		"samsara": g.t("ui.leaderboard_tab_samsara")
	}
	for cat_id in categories:
		var btn := g._button(tab_names[cat_id], Callable(), Color("122228"), Vector2(0, 32))
		btn.name = "LeaderboardTab_" + cat_id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(update_view.bind(cat_id))
		tab_buttons[cat_id] = btn
		tab_row.add_child(btn)

	refresh_btn.pressed.connect(func(): update_view.call(current_category[0]))

	var scope_names := {
		"global": g.t("ui.leaderboard_scope_global"),
		"friends": g.t("ui.leaderboard_scope_friends"),
	}
	for scope_id in ["global", "friends"]:
		var sbtn := g._button(scope_names[scope_id], Callable(), Color("122228"), Vector2(0, 28))
		sbtn.name = "LeaderboardScope_" + scope_id
		sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sbtn.pressed.connect(_set_leaderboard_scope.bind(scope_id, current_scope, update_view, current_category))
		scope_buttons[scope_id] = sbtn
		scope_row.add_child(sbtn)

	update_view.call(default_category)

func _meridian_cultivation_section() -> Control:
	var panel := PanelContainer.new()
	panel.name = "MeridianSection"
	panel.custom_minimum_size = Vector2(0, 96)
	panel.add_theme_stylebox_override("panel", g._panel(Color("0d1d1f"), 12, g.JADE))

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 10)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	pad.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	title_box.add_child(g._label(g.t("ui.meridian_title") + " 🎋", 14, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	title_box.add_child(g._label(g.t("ui.meridian_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	top_row.add_child(title_box)

	var open_btn := g._button(g.t("ui.meridian_summary_btn"), func(): show_meridian_modal(), Color("225046"), Vector2(100, 34))
	open_btn.name = "MeridianOpenBtn"
	open_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(open_btn)
	vbox.add_child(top_row)

	# Stat highlights / summary
	var cur_allocated: Dictionary = g.profile.get("meridians", {})
	var m_bonuses: Dictionary = g.content.meridian_bonuses(cur_allocated)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 10)

	var stat_parts: Array = []
	if int(m_bonuses.max_hp) > 0: stat_parts.append("+%d HP" % int(m_bonuses.max_hp))
	if int(m_bonuses.shield_start) > 0: stat_parts.append("+%d 盾" % int(m_bonuses.shield_start) if g.lang == "zh-Hans" else "+%d Shield" % int(m_bonuses.shield_start))
	if int(m_bonuses.first_attack_bonus) > 0: stat_parts.append("+%d 攻" % int(m_bonuses.first_attack_bonus) if g.lang == "zh-Hans" else "+%d Atk" % int(m_bonuses.first_attack_bonus))
	if int(m_bonuses.strength_start) > 0: stat_parts.append("+%d 力" % int(m_bonuses.strength_start) if g.lang == "zh-Hans" else "+%d Str" % int(m_bonuses.strength_start))
	if int(m_bonuses.draw_turn1) > 0: stat_parts.append("+%d 抽" % int(m_bonuses.draw_turn1) if g.lang == "zh-Hans" else "+%d Draw" % int(m_bonuses.draw_turn1))
	if int(m_bonuses.energy_turn1) > 0: stat_parts.append("+%d 灵" % int(m_bonuses.energy_turn1) if g.lang == "zh-Hans" else "+%d Energy" % int(m_bonuses.energy_turn1))

	var summary_text := ""
	if stat_parts.is_empty():
		summary_text = g.t("ui.meridian_summary_none")
	else:
		var sep_sym: String = " · "
		var parts_str: Array[String] = []
		for p in stat_parts: parts_str.append(str(p))
		summary_text = "✦ " + sep_sym.join(parts_str)

	var sum_lbl := g._label(summary_text, 10, g.JADE if not stat_parts.is_empty() else g.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	sum_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_lbl.clip_text = true
	summary_row.add_child(sum_lbl)

	var dust_count: int = int(g.profile.get("spirit_dust", 0))
	var dust_lbl := g._label(g.tf("ui.meridian_dust_cost", dust_count), 10, Color("d4aeff"), HORIZONTAL_ALIGNMENT_RIGHT)
	summary_row.add_child(dust_lbl)

	vbox.add_child(summary_row)
	return panel

func _close_meridian_modal() -> void:
	if g.overlay == null: return
	var existing: Node = g.overlay.get_node_or_null("MeridianModal")
	if existing != null:
		if existing.get_parent(): existing.get_parent().remove_child(existing)
		existing.queue_free()

func show_meridian_modal() -> void:
	_close_meridian_modal()

	var modal := g._modal_dialog("MeridianModal", func(): _close_meridian_modal())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "MeridianModalPanel"
	var vp_w: int = int(g.get_viewport_rect().size.x)
	panel.custom_minimum_size = Vector2(mini(360, vp_w - 20), 540)
	panel.add_theme_stylebox_override("panel", g._panel(Color("091316"), 14, g.JADE))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	for s in ["top", "bottom"]: pad.add_theme_constant_override("margin_%s" % s, 12)
	panel.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pad.add_child(vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	title_box.add_child(g._label(g.t("ui.meridian_title") + " 🎋", 16, g.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	title_box.add_child(g._label(g.t("ui.meridian_sub"), 9, g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	header_row.add_child(title_box)

	var close_btn := g._button("✕", func(): _close_meridian_modal(), Color("223640"), Vector2(32, 32))
	close_btn.name = "MeridianCloseBtn"
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(close_btn)
	vbox.add_child(header_row)

	# Dust & Respec status bar
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)

	var dust_icon := TextureRect.new()
	dust_icon.custom_minimum_size = Vector2(20, 20)
	dust_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dust_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dust_icon.texture = load("res://assets/icons/hud_dust.png")
	dust_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(dust_icon)

	var cur_dust_lbl := g._label(g.tf("ui.meridian_dust_cost", int(g.profile.get("spirit_dust", 0))), 11, Color("d4aeff"), HORIZONTAL_ALIGNMENT_LEFT)
	cur_dust_lbl.name = "MeridianDustLabel"
	cur_dust_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(cur_dust_lbl)

	var reset_btn := g._button(g.t("ui.meridian_reset"), Callable(), Color("3a1c22"), Vector2(80, 26))
	reset_btn.name = "MeridianResetBtn"
	status_row.add_child(reset_btn)
	vbox.add_child(status_row)

	# Branch Tabs: 任脉 / 督脉 / 冲脉
	var tab_row := HBoxContainer.new()
	tab_row.name = "MeridianTabRow"
	tab_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tab_row)

	var branches := ["ren", "du", "chong"]
	var tab_names := {
		"ren": g.t("ui.meridian_ren"),
		"du": g.t("ui.meridian_du"),
		"chong": g.t("ui.meridian_chong")
	}
	var current_branch: Array = ["ren"]
	var tab_buttons: Dictionary = {}

	# Scrollable Node Container
	var scroll := TouchScrollContainer.new()
	scroll.name = "MeridianScroll"
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 260
	vbox.add_child(scroll)

	var nodes_list := VBoxContainer.new()
	nodes_list.name = "MeridianNodesList"
	nodes_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nodes_list.add_theme_constant_override("separation", 8)
	scroll.add_child(nodes_list)

	# Refresh function for node tree and labels
	var refresh_meridian_ui: Array = [Callable()]
	refresh_meridian_ui[0] = func(branch: String) -> void:
		current_branch[0] = branch
		cur_dust_lbl.text = g.tf("ui.meridian_dust_cost", int(g.profile.get("spirit_dust", 0)))
		for b in branches:
			var btn_obj: Button = tab_buttons.get(b)
			if btn_obj != null:
				var active: bool = (b == branch)
				var b_col: Color = g.JADE if b == "ren" else (g.EMBER if b == "du" else g.GOLD)
				btn_obj.add_theme_stylebox_override("normal", g._panel(Color("162a2d") if active else Color("0f191b"), 6, b_col if active else Color("233c42")))

		for ch in nodes_list.get_children():
			nodes_list.remove_child(ch)
			ch.queue_free()

		var allocated: Dictionary = g.profile.get("meridians", {})
		var branch_nodes: Array[String] = []
		if branch == "ren": branch_nodes = ["ren_1", "ren_2", "ren_3"]
		elif branch == "du": branch_nodes = ["du_1", "du_2", "du_3"]
		elif branch == "chong": branch_nodes = ["chong_1", "chong_2", "chong_3"]

		for node_id in branch_nodes:
			var node_data: Dictionary = g.content.meridian_node(node_id)
			if node_data.is_empty(): continue
			var max_rank: int = int(node_data.get("max_rank", 5))
			var cur_rank: int = int(allocated.get(node_id, 0))
			var is_max: bool = (cur_rank >= max_rank)
			var cost: int = g.content.meridian_cost(node_id, cur_rank)
			var cur_dust: int = int(g.profile.get("spirit_dust", 0))

			var card := PanelContainer.new()
			card.name = "MeridianCard_" + node_id
			var branch_col: Color = g.JADE if branch == "ren" else (g.EMBER if branch == "du" else g.GOLD)
			card.add_theme_stylebox_override("panel", g._panel(Color("0f1d22"), 8, branch_col if cur_rank > 0 else Color("1a353c")))

			var card_pad := MarginContainer.new()
			for s in ["left", "right"]: card_pad.add_theme_constant_override("margin_%s" % s, 10)
			for s in ["top", "bottom"]: card_pad.add_theme_constant_override("margin_%s" % s, 8)
			card.add_child(card_pad)

			var card_v := VBoxContainer.new()
			card_v.add_theme_constant_override("separation", 6)
			card_pad.add_child(card_v)

			# Title row
			var c_top := HBoxContainer.new()
			c_top.add_theme_constant_override("separation", 6)
			var name_lbl := g._label(g.content.meridian_name(node_id, g.lang), 12, g.GOLD if cur_rank > 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c_top.add_child(name_lbl)

			var rank_lbl := g._label(g.tf("ui.meridian_rank_fmt", [cur_rank, max_rank]), 10, branch_col if cur_rank > 0 else g.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
			c_top.add_child(rank_lbl)
			card_v.add_child(c_top)

			# Desc & Action row
			var c_bot := HBoxContainer.new()
			c_bot.add_theme_constant_override("separation", 8)

			var desc_text := g.content.meridian_desc(node_id, cur_rank if cur_rank > 0 else 1, g.lang)
			var desc_lbl := g._label(desc_text, 9, g.TEXT if cur_rank > 0 else g.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c_bot.add_child(desc_lbl)

			var btn_text := g.t("ui.meridian_maxed") if is_max else (g.t("ui.meridian_upgrade") + (" (%d)" % cost))
			var up_btn := g._button(btn_text, Callable(), Color("225046") if not is_max else Color("1c2b2e"), Vector2(95, 32))
			up_btn.name = "MeridianUpgradeBtn_" + node_id
			up_btn.disabled = is_max or (cur_dust < cost)
			var target_id: String = node_id
			up_btn.pressed.connect(func():
				var ok: bool = g.upgrade_meridian_node(target_id)
				if ok:
					refresh_meridian_ui[0].call(current_branch[0])
			)
			c_bot.add_child(up_btn)
			card_v.add_child(c_bot)

			nodes_list.add_child(card)

	reset_btn.pressed.connect(func():
		var total_refunded: int = g.reset_meridians()
		refresh_meridian_ui[0].call(current_branch[0])
	)

	for b in branches:
		var branch_key: String = b
		var tab_b := g._button(tab_names[branch_key], Callable(), Color("0f191b"), Vector2(0, 32))
		tab_b.name = "MeridianTab_" + branch_key
		tab_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_b.pressed.connect(func(): refresh_meridian_ui[0].call(branch_key))
		tab_buttons[branch_key] = tab_b
		tab_row.add_child(tab_b)

	refresh_meridian_ui[0].call("ren")




