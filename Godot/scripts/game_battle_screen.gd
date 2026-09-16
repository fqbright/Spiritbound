extends RefCounted
class_name BattleScreen

# Composition, not inheritance — see MapScreen's header comment (game_map_screen.gd) for
# why. `g` is the live SpiritGame instance; every reference to shared state or another
# screen's function goes through it.
var g: SpiritGame

func _init(game: SpiritGame) -> void:
	g = game

func _modifier(seed: int, stage: int) -> Dictionary:
	var options := [
		{"id":"reinforced","name":"重甲军势","name_en":"Reinforced Army","detail":"敌人生命 +30%，金币 +35%","detail_en":"Enemy HP +30%, Gold +35%","health_scale":1.3,"reward_scale":1.35},
		{"id":"frenzy","name":"血月狂怒","name_en":"Blood Frenzy","detail":"敌人攻击 +3，金币 +30%","detail_en":"Enemy ATK +3, Gold +30%","damage_bonus":3,"reward_scale":1.3},
		{"id":"swarm","name":"狩猎群落","name_en":"Hunting Swarm","detail":"增加一名敌人，金币 +40%","detail_en":"+1 Enemy, Gold +40%","extra_enemy":1,"health_scale":1.08,"reward_scale":1.4},
		{"id":"rebirth","name":"不灭余烬","name_en":"Undying Embers","detail":"敌人可能复活，金币 +50%","detail_en":"Enemies may revive, Gold +50%","revive":.45,"health_scale":1.1,"damage_bonus":1,"reward_scale":1.5},
		{"id":"eclipse","name":"灵蚀天象","name_en":"Spirit Eclipse","detail":"生命与攻击提升，金币 +45%","detail_en":"Enemy HP & ATK boosted, Gold +45%","health_scale":1.18,"damage_bonus":2,"reward_scale":1.45},
	]
	var value: int = absi(seed ^ ((stage + 1) * 2654435761))
	return {} if value % 100 < 48 else options[(value / 100) % options.size()]

func begin_battle(index: int) -> void:
	g.current_stage = index
	var seed := int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	if g.is_hard_replay:
		g.active_modifier = {
			"id": "trial_hard",
			"name": "试炼强化",
			"name_en": "Trial Hard",
			"detail": "敌人生命 +25%，攻击 +2，恢复全额掉落",
			"detail_en": "Enemy HP +25%, ATK +2, Full Drops",
			"health_scale": 1.25,
			"damage_bonus": 2,
			"reward_scale": 1.0
		}
	else:
		g.active_modifier = _modifier(seed, index)
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	var battle_deck: Array = g.profile.deck
	if g.in_draft_battle and g.profile.get("draft_arena", {}).get("deck", []).size() >= 15:
		battle_deck = g.profile.draft_arena.deck
	g.combat.create(seed,g.content.encounters[index],battle_deck,int(g.profile.health),g.profile.upgrades,equipped,g.profile.card_runes,g.active_modifier,g.profile.relics,g._current_hero_mastery_bonuses())
	g.combat.event.connect(_combat_event)
	if g._mark_discovered("bestiary", str(g.content.encounters[index].name)):
		g._grant_bestiary_discovery_bonus(g.content.encounters[index])
	g.pre_battle_health = int(g.profile.health)
	g.advancing_to_reward = false
	g.selected_card = -1
	show_battle()
	if index == 0 and not bool(g.profile.get("tutorial_seen", false)): _show_battle_tutorial()
	_maybe_end_turn()

func show_battle() -> void:
	var encounter: Dictionary = g._current_encounter()
	var stage_lvl: int = int(encounter.get("level", 1)) - 1
	g._clear(); g._play_music(true, stage_lvl); g.enemy_boxes.clear()
	# Keyed by within-chapter level (Trailhead..Crown), the same index _play_music() uses for
	# the matching battle theme, rather than the old per-encounter "background" rotation index
	# — that tied visual variety to chapter/stage number with no relationship to the music
	# playing over it. Clamped the same way _play_music() clamps stream_idx, since Daily
	# Trial/Weekly Challenge stages run past level 5 with no matching array entry.
	var bg_index: int = clampi(stage_lvl, 0, g.BATTLE_BACKGROUNDS.size() - 1)
	var bg := g._background(g.BATTLE_BACKGROUNDS[bg_index],.28); g.root.add_child(bg); g.root.move_child(bg,0)
	var page := g._create_page(4)

	var top := HBoxContainer.new(); top.custom_minimum_size.y = 44
	top.add_child(g._label("%d-%d  %s" % [encounter.chapter,encounter.level,g._current_stage_label()], 13, g.JADE))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer)
	top.add_child(g._label(g.tf("ui.turn_n", g.combat.state.turn), 11, g.GOLD))
	var speed_label: String = (str(int(g.battle_speed)) if g.battle_speed == float(int(g.battle_speed)) else str(g.battle_speed)) + "x"
	var speed_btn := g._button(speed_label, g._cycle_speed, Color("1a3a42"), Vector2(44, 28))
	speed_btn.name = "SpeedToggle"
	speed_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(speed_btn)
	var leave_btn := g._button("⌂", _leave_battle, Color("17363e"), Vector2(36,34))
	leave_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(leave_btn); page.add_child(top)

	if not g.active_modifier.is_empty() or not g.combat.state.equipment.is_empty() or not g.profile.relics.is_empty():
		var badge_row := HBoxContainer.new()
		badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
		badge_row.add_theme_constant_override("separation", 8)
		page.add_child(badge_row)

		if not g.active_modifier.is_empty():
			var m_name: String = g.active_modifier.name_en if g.lang == "en" else g.active_modifier.name
			var m_det: String = g.active_modifier.detail_en if g.lang == "en" else g.active_modifier.detail
			var mod_badge := g._icon_badge("✥", Color("ffe2b0"), 34, 16)
			badge_row.add_child(_tap_wrap(mod_badge, func(): _show_info_popup(g._icon_badge("✥", Color("ffe2b0"), 60, 26), m_name, m_det, g.EMBER)))

		for id in g.combat.state.equipment:
			var item := g.content.equipment(id)
			if item.is_empty(): continue
			var e_name: String = g._equip_name(item)
			var e_det: String = g._equip_detail(item)
			var e_badge := g._equip_icon_badge(item, g.GOLD, 34)
			badge_row.add_child(_tap_wrap(e_badge, func(): _show_info_popup(g._equip_icon_badge(item, g.GOLD, 60), e_name, e_det, g.GOLD)))

		for id in g.profile.relics:
			var relic := g.content.relic(id)
			if relic.is_empty(): continue
			var r_color := Color(relic.color)
			var r_name: String = g._relic_name(relic)
			var r_det: String = g._relic_detail(relic)
			var r_badge := g._relic_icon_badge(relic, r_color, 34)
			badge_row.add_child(_tap_wrap(r_badge, func(): _show_info_popup(g._relic_icon_badge(relic, r_color, 60), r_name, r_det, r_color)))

	var enemy_area := Control.new()
	enemy_area.custom_minimum_size = Vector2(366.0, 205.0)
	enemy_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_area.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(enemy_area)

	# A flat row reads fine for one or two enemies, but three or more in a straight line
	# looks like a spreadsheet. Fan them out around the centre instead: the middle slot is
	# "front" (full size, lowest), and slots further from centre step back and up, like a
	# loose wedge formation instead of a queue.
	var living_indices: Array = []
	for index in g.combat.state.enemies.size():
		if g.combat.state.enemies[index].health > 0: living_indices.append(index)
	var slot_count: int = maxi(1, g.combat.state.enemies.size())
	var u_width: float = minf(112.0, (366.0 - 10.0 * float(slot_count - 1)) / float(slot_count))
	var gap := 10.0
	var living_n := living_indices.size()
	var total_w: float = float(living_n) * u_width + float(maxi(0, living_n - 1)) * gap
	var start_x: float = (366.0 - total_w) / 2.0
	var center_slot: float = float(living_n - 1) / 2.0
	for order in living_n:
		var enemy_index: int = living_indices[order]
		var dist: float = absf(float(order) - center_slot)
		var depth_t: float = 0.0 if center_slot <= 0.0 else dist / center_slot
		var box := _enemy_view(enemy_index, depth_t)
		box.position = Vector2(start_x + float(order) * (u_width + gap), -depth_t * 26.0)
		box.z_index = 20 - int(round(depth_t * 8.0))
		enemy_area.add_child(box)
		g.enemy_boxes.append(box)

	var push_down := Control.new()
	push_down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(push_down)

	page.add_child(_build_player_stage())

	if g.combat.state.phase == "player":
		_add_hand(page)
	else:
		var won: bool = g.combat.state.phase == "won"
		var outcome := g._label(g.t("ui.battle_won") if won else g.t("ui.battle_lost"), 26, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		outcome.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page.add_child(outcome)
		if won:
			# Straight through to the chest. This used to be a button labelled "open chest"
			# that led to a screen with another button labelled "open chest".
			_advance_to_reward()
		else:
			page.add_child(g._button(g.t("ui.return_map"), _leave_battle, g.EMBER, Vector2(0, 50)))

func _intent_style(intent: Dictionary) -> Dictionary:
	var kind := str(intent.get("kind", "attack"))
	var amount := int(intent.get("amount", 0))
	# "text" (with its symbol) still goes into toasts, which have no room for a drawn icon;
	# "amount_text" is the plain number the banner shows next to the icon instead.
	match kind:
		"critical":
			return {"text": g.tf("ui.intent_critical", amount), "amount_text": str(amount), "bg": Color("8c2f19"), "border": Color("ff8d5c"), "text_color": Color("ffe1c9")}
		"defend":
			return {"text": g.tf("ui.intent_defend", amount), "amount_text": str(amount), "bg": Color("15364f"), "border": Color("7fb8e8"), "text_color": Color("d6ecff")}
		"empower":
			return {"text": g.tf("ui.intent_empower", amount), "amount_text": "+%d" % amount, "bg": Color("3a1f52"), "border": Color("c79bff"), "text_color": Color("ecdcff")}
		"curse":
			return {"text": g.tf("ui.intent_curse", amount), "amount_text": str(amount), "bg": Color("2f4420"), "border": Color("a8dd6c"), "text_color": Color("e2f7c6")}
		"attack_defend":
			return {"text": g.tf("ui.intent_attack_defend", [amount, int(intent.get("shield", 0))]), "amount_text": "%d/%d" % [amount, int(intent.get("shield", 0))], "bg": Color("4a2a1c"), "border": Color("e0a878"), "text_color": Color("ffe7d2")}
		_:
			return {"text": g.tf("ui.intent_attack", amount), "amount_text": str(amount), "bg": Color(0.29, 0.11, 0.07, 0.92), "border": Color("e39761"), "text_color": Color("ffe1c9")}

func _get_hit_flash_shader() -> Shader:
	if g._hit_flash_shader == null: g._hit_flash_shader = load("res://assets/shaders/hit_flash.gdshader")
	return g._hit_flash_shader

func _get_card_foil_shader() -> Shader:
	if g._card_foil_shader == null and ResourceLoader.exists("res://assets/shaders/card_foil.gdshader"):
		g._card_foil_shader = load("res://assets/shaders/card_foil.gdshader")
	return g._card_foil_shader

func _apply_card_foil(node: CanvasItem, rarity: String, upgraded: bool) -> void:
	if rarity == "Rare" or upgraded:
		var s := _get_card_foil_shader()
		if s:
			var mat := ShaderMaterial.new()
			mat.shader = s
			node.material = mat

# One shader material per sprite so a mid-flash overlap on one enemy never disturbs another.
func _install_hit_flash(sprite: CanvasItem) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_hit_flash_shader()
	sprite.material = mat
	return mat

func _flash_hit(sprite: CanvasItem, color := Color.WHITE, duration := 0.22) -> void:
	if sprite.material == null or not (sprite.material is ShaderMaterial): _install_hit_flash(sprite)
	var mat: ShaderMaterial = sprite.material
	mat.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("flash_amount", 1.0)
	var tween := sprite.create_tween()
	tween.tween_method(func(v): mat.set_shader_parameter("flash_amount", v), 1.0, 0.0, duration).set_trans(Tween.TRANS_QUAD)

# Squash-and-stretch impact: a fast non-uniform scale punch (wide+short) rather than a
# uniform scale bump — this is the single technique animation references cite most often
# for making a static sprite read as reacting to a hit instead of just wobbling.
func _squash_impact(sprite: Node2D, base_scale: float, strength := 0.22, duration := 0.22) -> void:
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(base_scale * (1.0 + strength), base_scale * (1.0 - strength)), duration * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(base_scale * (1.0 - strength * 0.4), base_scale * (1.0 + strength * 0.4)), duration * 0.32).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "scale", Vector2.ONE * base_scale, duration * 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# A soft halo behind a sprite for a status that has no natural "shape" of its own — shield
# and vulnerable both read as an aura, just in different colours and animation.
func _status_halo(size: Vector2, color: Color, pulsing: bool) -> Panel:
	var halo := Panel.new()
	halo.custom_minimum_size = size
	halo.size = size
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := g._panel(Color(color.r, color.g, color.b, 0.16), int(size.y / 2.0), Color(color, 0.75))
	style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
	halo.add_theme_stylebox_override("panel", style)
	if pulsing:
		var pulse := halo.create_tween().set_loops()
		pulse.tween_property(halo, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(halo, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	return halo

func _get_ember_texture() -> GradientTexture2D:
	if g._ember_texture != null: return g._ember_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.85, 0.4, 0.95))
	gradient.set_color(1, Color(1, 0.3, 0.1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 16
	tex.height = 16
	g._ember_texture = tex
	return tex

func _burn_embers(size: Vector2) -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.name = "BurnFx"
	embers.texture = _get_ember_texture()
	embers.position = size / 2.0
	embers.amount = 8
	embers.lifetime = 1.1
	embers.emitting = true
	embers.local_coords = true
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(size.x * 0.35, size.y * 0.15)
	embers.direction = Vector2(0, -1)
	embers.spread = 20.0
	embers.gravity = Vector2(0, -18)
	embers.initial_velocity_min = 14.0
	embers.initial_velocity_max = 26.0
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.0
	return embers

# Reads the current status values straight off the enemy/player dict and attaches whichever
# visual effects apply — called once per rebuild, so no state to track between frames.
func _apply_status_fx(unit: Control, sprite: Node2D, sprite_center: Vector2, sprite_radius: float, state: Dictionary) -> void:
	if int(state.get("shield", 0)) > 0:
		var halo := _status_halo(Vector2.ONE * sprite_radius * 2.3, Color("6fc7ff"), false)
		halo.position = sprite_center - Vector2.ONE * sprite_radius * 1.15
		unit.add_child(halo)
		unit.move_child(halo, 0)
	if int(state.get("vulnerable", 0)) > 0:
		var halo := _status_halo(Vector2.ONE * sprite_radius * 2.2, Color("ff6a5c"), true)
		halo.position = sprite_center - Vector2.ONE * sprite_radius * 1.1
		unit.add_child(halo)
		unit.move_child(halo, 0)
	if int(state.get("burn", 0)) > 0:
		var embers := _burn_embers(Vector2.ONE * sprite_radius * 2.0)
		embers.position = sprite_center
		unit.add_child(embers)
	if int(state.get("weak", 0)) > 0:
		sprite.modulate = Color(0.72, 0.72, 0.78, 1.0)
	if int(state.get("stun", 0)) > 0:
		var stars := DizzyStars.new()
		stars.custom_minimum_size = Vector2.ONE * sprite_radius * 1.6
		stars.size = stars.custom_minimum_size
		stars.position = sprite_center - Vector2(stars.size.x / 2.0, sprite_radius * 1.9)
		unit.add_child(stars)

func _enemy_view(index: int, depth_t := 0.0) -> Control:
	var enemy: Dictionary = g.combat.state.enemies[index]
	var unit := Control.new()
	unit.name = "Enemy_%d" % index
	var enemy_count := maxi(1, g.combat.state.enemies.size())
	var u_width: float = minf(112.0, (366.0 - 10.0 * float(enemy_count - 1)) / float(enemy_count))
	unit.custom_minimum_size = Vector2(u_width, 205.0)
	unit.size = unit.custom_minimum_size
	unit.set_meta("enemy_index", index)
	unit.mouse_filter = Control.MOUSE_FILTER_PASS

	var center_x := u_width / 2.0

	# A ring around the whole unit reads as "selectable" far better than scaling the sprite.
	# It is shown whenever a card that needs an enemy is in hand-play, not only on hover.
	var glow := Panel.new()
	glow.name = "TargetGlow"
	glow.custom_minimum_size = Vector2(u_width - 4.0, 150.0)
	glow.size = glow.custom_minimum_size
	glow.position = Vector2(2.0, 16.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _target_ring(false))
	glow.visible = g.selected_card >= 0 and enemy.health > 0
	unit.add_child(glow)

	var art_key := g._art_key_for_enemy(enemy)
	var sprite := Sprite2D.new()
	sprite.name = "MonsterSprite"
	sprite.texture = g._get_character_texture(art_key)
	# Depth reads through scale and tone, not through the hit box: the unit's own size/position
	# (used for taps and drag-targeting) stays exactly what _enemy_view always computed, only
	# the sprite drawn inside it shrinks and dims a touch for the "further back" slots.
	var sprite_side := clampf(u_width - 16.0, 70.0, 96.0) * lerpf(1.0, 0.82, depth_t)
	var spr_size := Vector2(sprite_side, sprite_side)
	var cell_w := float(g._char_atlas_tex.get_width()) / 3.0
	var scale_factor: float = minf(spr_size.x / cell_w, spr_size.y / cell_w)
	sprite.scale = Vector2(scale_factor, scale_factor)
	# Animations restore scale from this meta. Without it they fell back to 1.0 and left the
	# enemy roughly three times its intended size after any action.
	sprite.set_meta("base_scale", scale_factor)
	sprite.position = Vector2(center_x, 26.0 + spr_size.y / 2.0)
	_install_hit_flash(sprite)
	unit.add_child(sprite)

	var weakened: bool = int(enemy.get("weak", 0)) > 0
	var idle := sprite.create_tween().set_loops()
	# Weak visibly saps the enemy's energy: a slower, shallower bob instead of the usual bounce.
	if weakened:
		idle.tween_property(sprite, "position:y", sprite.position.y - 2.0, 1.6).set_trans(Tween.TRANS_SINE)
		idle.tween_property(sprite, "position:y", sprite.position.y + 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	else:
		idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
		idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)
	_apply_status_fx(unit, sprite, sprite.position, spr_size.x / 2.0, enemy)

	# Intent banner: just the drawn icon (already distinct per intent kind — shield for
	# defend, crossed blades for attack, etc.) plus the number it promises. It used to also
	# spell the intent out in a caption line ("Attack"), which was redundant once the icon
	# actually reads on its own, and the extra line pushed the banner tall enough to crowd
	# whatever sits above the enemy row (the equipment/relic badges).
	var intent: Dictionary = enemy.get("intent", {})
	var intent_style := _intent_style(intent)
	var intent_w: float = minf(u_width, 104.0)
	var intent_bg := Panel.new()
	intent_bg.name = "IntentBanner"
	intent_bg.custom_minimum_size = Vector2(intent_w, 26.0)
	intent_bg.size = intent_bg.custom_minimum_size
	# Depth-staggered (flanking) enemies have their whole unit shifted up by depth_t*26 for
	# the wedge formation; add that back here so every enemy's banner lands at the same
	# screen height regardless of which row it is in, instead of a back-row banner drifting
	# higher and overlapping the row above the whole enemy area.
	intent_bg.position = Vector2(center_x - intent_w / 2.0, depth_t * 26.0)
	intent_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var intent_box := g._panel(intent_style.bg, 11, intent_style.border)
	intent_box.border_width_left = 2; intent_box.border_width_right = 2
	intent_box.border_width_top = 2; intent_box.border_width_bottom = 2
	intent_bg.add_theme_stylebox_override("panel", intent_box)
	unit.add_child(intent_bg)

	var intent_row := HBoxContainer.new()
	intent_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	intent_row.add_theme_constant_override("separation", 4)
	intent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_bg.add_child(intent_row)
	var icon := IntentIcon.new()
	icon.kind = str(intent.get("kind", "attack"))
	icon.icon_color = intent_style.text_color
	icon.custom_minimum_size = Vector2(20, 20)
	icon.size = icon.custom_minimum_size
	intent_row.add_child(icon)
	intent_row.add_child(g._label(intent_style.amount_text, 15, intent_style.text_color, HORIZONTAL_ALIGNMENT_CENTER))

	var telegraph := intent_bg.create_tween().set_loops()
	telegraph.tween_property(intent_bg, "modulate", Color(1.18, 1.18, 1.18), 0.9).set_trans(Tween.TRANS_SINE)
	telegraph.tween_property(intent_bg, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)

	var element: String = enemy.get("element", "")
	if not element.is_empty():
		var el_lbl := g._label(g.t("element.%s" % element), 8, Color("8de7e0") if element == "water" else Color("ff9a6d"), HORIZONTAL_ALIGNMENT_CENTER)
		el_lbl.position = Vector2(4, 4)
		unit.add_child(el_lbl)

	var name_lbl := g._label(g._enemy_name(enemy), 10, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.position = Vector2(0, 128.0)
	name_lbl.size = Vector2(u_width, 18.0)
	unit.add_child(name_lbl)

	var hp_bar_w := u_width - 12.0
	var hp_bar := g._stat_bar(hp_bar_w, 16.0, int(enemy.health), int(enemy.max_health), Color(enemy.get("tint", "83e4c1")), "%d/%d" % [enemy.health, enemy.max_health], 9)
	hp_bar.name = "HealthBar"
	hp_bar.position = Vector2(6.0, 148.0)
	unit.add_child(hp_bar)

	var badges := HBoxContainer.new()
	badges.position = Vector2(0.0, 167.0)
	badges.size = Vector2(u_width, 18.0)
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 5)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit.add_child(badges)
	if int(enemy.shield) > 0: badges.add_child(g._status_chip("⬢", int(enemy.shield), Color("9fd8ff")))
	if int(enemy.burn) > 0: badges.add_child(g._status_chip("▲", int(enemy.burn), Color("ff9868")))
	if int(enemy.get("poison", 0)) > 0: badges.add_child(g._status_chip("◆", int(enemy.poison), Color("a75bd6")))
	if int(enemy.stun) > 0: badges.add_child(g._status_chip("✸", int(enemy.stun), Color("ffe08a")))
	if int(enemy.get("vulnerable", 0)) > 0: badges.add_child(g._status_chip("▼", int(enemy.vulnerable), Color("ff6b6b")))
	if int(enemy.get("weak", 0)) > 0: badges.add_child(g._status_chip("●", int(enemy.weak), Color("b8c4c8")))

	return unit

func _build_player_stage() -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(366.0, 118.0)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var center_x := 366.0 / 2.0

	# Mirror of the enemy ring, lit when a card that acts on you is in play.
	var glow := Panel.new()
	glow.name = "PlayerTargetGlow"
	glow.custom_minimum_size = Vector2(200.0, 112.0)
	glow.size = glow.custom_minimum_size
	glow.position = Vector2(center_x - 100.0, 2.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _target_ring(false))
	glow.visible = false
	stage.add_child(glow)

	var sprite := Sprite2D.new()
	sprite.name = "PlayerSprite"
	sprite.texture = g._get_character_texture("fox")
	var spr_size := Vector2(74.0, 74.0)
	var cell_w := float(g._char_atlas_tex.get_width()) / 3.0
	var scale_factor: float = minf(spr_size.x / cell_w, spr_size.y / cell_w)
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.set_meta("base_scale", scale_factor)
	sprite.position = Vector2(center_x, 37.0)
	_install_hit_flash(sprite)
	stage.add_child(sprite)

	var idle := sprite.create_tween().set_loops()
	idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
	idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)
	_apply_status_fx(stage, sprite, sprite.position, spr_size.x / 2.0, g.combat.state.player)

	var max_hp: int = int(g.combat.state.player.get("max_health", 60))
	var hp_bar := g._stat_bar(168.0, 18.0, int(g.combat.state.player.health), max_hp, g.EMBER, "%s  ♥ %d/%d" % [g.t("ui.spirit_name"), g.combat.state.player.health, max_hp], 10)
	hp_bar.position = Vector2(center_x - 84.0, 78.0)
	stage.add_child(hp_bar)

	var incoming: int = g.combat.total_incoming_damage()
	var effective_hp: int = int(g.combat.state.player.health) + int(g.combat.state.player.shield)
	if incoming >= effective_hp and incoming > 0:
		var danger_badge := Panel.new()
		danger_badge.name = "DangerWarningBadge"
		danger_badge.custom_minimum_size = Vector2(96.0, 18.0)
		danger_badge.size = danger_badge.custom_minimum_size
		danger_badge.position = Vector2(center_x - 48.0, 58.0)
		danger_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d_style := g._panel(Color(0.85, 0.15, 0.15, 0.95), 9, Color("ffc2c2"))
		d_style.border_width_left = 1; d_style.border_width_right = 1
		d_style.border_width_top = 1; d_style.border_width_bottom = 1
		danger_badge.add_theme_stylebox_override("panel", d_style)
		var d_label := g._label("⚠ %s: %d" % [g.t("ui.danger"), incoming], 9, Color("ffffff"), HORIZONTAL_ALIGNMENT_CENTER)
		d_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		danger_badge.add_child(d_label)
		stage.add_child(danger_badge)
		var d_tw := danger_badge.create_tween().set_loops()
		d_tw.tween_property(danger_badge, "modulate:a", 0.55, 0.4).set_trans(Tween.TRANS_SINE)
		d_tw.tween_property(danger_badge, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

	var badges := HBoxContainer.new()
	badges.position = Vector2(center_x - 84.0, 98.0)
	badges.size = Vector2(168.0, 18.0)
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 8)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(badges)
	if int(g.combat.state.player.shield) > 0: badges.add_child(g._status_chip("⬢", int(g.combat.state.player.shield), Color("9fd8ff"), 22.0))
	if int(g.combat.state.player.focus) > 0: badges.add_child(g._status_chip("◉", int(g.combat.state.player.focus), Color("ffe08a"), 22.0))
	if int(g.combat.state.player.burn) > 0: badges.add_child(g._status_chip("▲", int(g.combat.state.player.burn), Color("ff9868"), 22.0))
	if int(g.combat.state.player.get("poison", 0)) > 0: badges.add_child(g._status_chip("◆", int(g.combat.state.player.poison), Color("a75bd6"), 22.0))
	if int(g.combat.state.player.get("strength", 0)) > 0: badges.add_child(g._status_chip("★", int(g.combat.state.player.strength), Color("ffd700"), 22.0))
	if int(g.combat.state.player.get("vulnerable", 0)) > 0: badges.add_child(g._status_chip("▼", int(g.combat.state.player.vulnerable), Color("ff6b6b"), 22.0))
	if int(g.combat.state.player.get("weak", 0)) > 0: badges.add_child(g._status_chip("●", int(g.combat.state.player.weak), Color("b8c4c8"), 22.0))

	return stage

func _pile_chip(count: int, caption: String, number_color: Color, on_tap: Callable = Callable()) -> Panel:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(52.0, 46.0)
	chip.size = chip.custom_minimum_size
	chip.mouse_filter = Control.MOUSE_FILTER_PASS if on_tap.is_valid() else Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", g._panel(Color("0c1a1f"), 10, Color("1f404d")))
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(stack)
	stack.add_child(g._label(str(count), 17, number_color, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(g._label(caption, 8, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if on_tap.is_valid():
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		btn.add_theme_stylebox_override("focus", empty)
		btn.pressed.connect(on_tap)
		chip.add_child(btn)
	return chip

func _add_hand(page: VBoxContainer) -> void:
	if g.selected_card >= 0:
		var hint := g._label("%s · %s" % [g.t("ui.target_pick"), g.t("ui.target_cancel")], 11, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		page.add_child(hint)

	# Resource row sits on its own line; previously these floated over the fanned cards.
	var status := HBoxContainer.new()
	status.custom_minimum_size.y = 48
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 10)
	page.add_child(status)

	var draw_chip := _pile_chip(g.combat.state.draw.size(), g.t("ui.draw_pile"), Color("f3e8cf"), func(): show_pile_inspector("ui.pile_draw_title", g.combat.state.draw))
	draw_chip.name = "DrawPileChip"
	status.add_child(draw_chip)

	# Energy is the only thing that gates a play now — there is no play-count limit, so this
	# orb (not a row of used-up pips) is the one number that actually matters each turn.
	var orb := Panel.new()
	orb.custom_minimum_size = Vector2(52, 52)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var orb_style := g._panel(Color("0d3a4a"), 26, Color("6fd8ff"))
	orb_style.border_width_left = 2; orb_style.border_width_right = 2; orb_style.border_width_top = 2; orb_style.border_width_bottom = 2
	orb.add_theme_stylebox_override("panel", orb_style)
	var orb_stack := VBoxContainer.new()
	orb_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orb_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	orb_stack.add_theme_constant_override("separation", -3)
	orb_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(orb_stack)
	orb_stack.add_child(g._label(str(int(g.combat.state.energy)), 20, Color("cdf1ff"), HORIZONTAL_ALIGNMENT_CENTER))
	orb_stack.add_child(g._label(g.t("ui.energy_label"), 8, Color("8fd9f2"), HORIZONTAL_ALIGNMENT_CENTER))
	status.add_child(orb)

	var discard_chip := _pile_chip(g.combat.state.discard.size(), g.t("ui.discard_pile"), Color("a8b2b5"), func(): show_pile_inspector("ui.pile_discard_title", g.combat.state.discard))
	discard_chip.name = "DiscardPileChip"
	status.add_child(discard_chip)

	var pass_btn := g._button(g.t("ui.pass_turn"), g._pass_turn, Color("1c2a30"), Vector2(48, 44))
	pass_btn.name = "PassTurnBtn"
	status.add_child(pass_btn)

	var hand_zone := Control.new()
	hand_zone.custom_minimum_size = Vector2(366.0, 186.0)
	hand_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(hand_zone)

	var count: int = g.combat.state.hand.size()
	for index in count:
		var card_tile := _card_view(g.combat.state.hand[index], index, count)
		hand_zone.add_child(card_tile)

func _card_is_attack(card: Dictionary) -> bool:
	for effect in card.effects:
		if effect.operation == "damage" and effect.target == "opponent": return true
	return false

# A card either acts on an enemy or on you — never both, and never a choice between them.
# Anything with an opponent-facing effect aims at enemies; everything else aims at you.
func _card_target_mode(card: Dictionary) -> String:
	for effect in card.effects:
		if effect.get("target", "") == "opponent": return "enemy"
	return "self"

func _living_enemies() -> Array:
	var living: Array = []
	if g.combat == null: return living
	for i in g.combat.state.enemies.size():
		if g.combat.state.enemies[i].health > 0: living.append(i)
	return living

# Tapping an attack card with more than one enemy alive arms a target choice rather than
# guessing; everything else still plays on the first tap.
func _tap_card(hand_index: int) -> void:
	if g.combat == null or g.combat.state.phase != "player" or g.resolving: return
	if hand_index < 0 or hand_index >= g.combat.state.hand.size(): return
	if g.selected_card == hand_index:
		g.selected_card = -1
		show_battle()
		return
	var card := g.content.card(g.combat.state.hand[hand_index].card_id)
	if _card_is_attack(card) and _living_enemies().size() > 1:
		g.selected_card = hand_index
		show_battle()
		return
	g.selected_card = -1
	_attempt_play_card(hand_index, -1)

# Shared dim, tap-outside-to-dismiss backdrop for any full-screen modal (card preview,
# equipment/relic/modifier info) — one node name per caller so only that caller's _clear_*
# needs to know about it, and two modals can never stack on top of each other by accident.
func _modal_backdrop(node_name: String, on_dismiss: Callable) -> Button:
	var dim := Color("040a0c"); dim.a = 0.72
	var backdrop := Button.new()
	backdrop.name = node_name
	backdrop.flat = true
	backdrop.focus_mode = Control.FOCUS_NONE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.z_index = 300
	backdrop.add_theme_stylebox_override("normal", g._panel(dim, 0))
	backdrop.add_theme_stylebox_override("hover", g._panel(dim, 0))
	backdrop.add_theme_stylebox_override("pressed", g._panel(dim, 0))
	backdrop.add_theme_stylebox_override("focus", g._panel(dim, 0))
	if on_dismiss.is_valid(): backdrop.pressed.connect(on_dismiss)
	g.overlay.add_child(backdrop)
	return backdrop

# Wraps a non-interactive badge/icon Control (built with MOUSE_FILTER_IGNORE) in an
# invisible button so a whole row of small icons can each be tapped for detail, without
# every icon-drawing call site needing to know about buttons.
func _tap_wrap(control: Control, on_tap: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = control.custom_minimum_size
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(control)
	if on_tap.is_valid(): btn.pressed.connect(on_tap)
	return btn

# A small centered card (icon + name + full detail text) for anything that used to be an
# inline text label — the modifier banner and the equipment/relic row both used to spell
# their full description out on screen; now they're a badge you tap for the same information.
func _show_info_popup(icon: Control, title: String, detail: String, accent: Color) -> void:
	if g.overlay == null: return
	_clear_info_popup()
	var backdrop := _modal_backdrop("InfoPopup", _clear_info_popup)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 10)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card_style := g._panel(Color("15262b"), 14, accent)
	card_style.content_margin_left = 18; card_style.content_margin_right = 18
	card_style.content_margin_top = 18; card_style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(icon)
	inner.add_child(g._label(title, 15, Color("f3e8cf"), HORIZONTAL_ALIGNMENT_CENTER))
	var det_lbl := g._label(detail, 12, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	det_lbl.custom_minimum_size.x = 200
	inner.add_child(det_lbl)

	center.add_child(g._label(g.t("ui.tap_to_dismiss"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

func _clear_info_popup() -> void:
	if g.overlay == null: return
	var existing := g.overlay.get_node_or_null("InfoPopup")
	if existing: existing.queue_free()

# First-battle tutorial: a short dismissible slide carousel shown once per g.profile, right
# before the very first fight. Deliberately NOT gated on the player actually performing each
# action (dragging a card, letting a turn auto-end) — hooking every one of those reliably
# across drag/tap/target code paths is real engine surface for marginal gain over just
# explaining them up front. Tapping the backdrop, "跳过教程", or reaching the last step's
# "开始战斗" all do the same thing: mark tutorial_seen and get out of the way.
const TUTORIAL_STEPS: Array[String] = ["tutorial.1", "tutorial.2", "tutorial.3", "tutorial.4"]
var tutorial_step := 0

func _show_battle_tutorial() -> void:
	if g.overlay == null: return
	tutorial_step = 0
	_modal_backdrop("BattleTutorial", _finish_tutorial)
	_render_tutorial_step()

func _render_tutorial_step() -> void:
	var backdrop := g.overlay.get_node_or_null("BattleTutorial") as Control
	if backdrop == null: return
	for child in backdrop.get_children(): child.queue_free()

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 12)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)

	var card := PanelContainer.new()
	card.name = "TutorialCard"
	card.custom_minimum_size = Vector2(290, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var card_style := g._panel(Color("15262b"), 16, g.GOLD)
	card_style.content_margin_left = 20; card_style.content_margin_right = 20
	card_style.content_margin_top = 20; card_style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	card.add_child(inner)

	var key: String = TUTORIAL_STEPS[tutorial_step]
	inner.add_child(g._label(g.tf("ui.tutorial_step_fmt", [tutorial_step + 1, TUTORIAL_STEPS.size()]), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	inner.add_child(g._label(g.content.ui("%s.title" % key, g.lang), 17, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var desc_lbl := g._label(g.content.ui("%s.desc" % key, g.lang), 12, Color("cfe3e0"), HORIZONTAL_ALIGNMENT_CENTER, true)
	desc_lbl.custom_minimum_size.x = 250
	inner.add_child(desc_lbl)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(actions)
	if tutorial_step > 0:
		var back_btn := g._button(g.t("ui.tutorial_prev"), _tutorial_prev_step, Color("1a3d44"), Vector2(84, 40))
		actions.add_child(back_btn)
	var is_last: bool = tutorial_step >= TUTORIAL_STEPS.size() - 1
	var next_callback: Callable = _finish_tutorial if is_last else _tutorial_next_step
	var next_btn := g._button(g.t("ui.tutorial_start") if is_last else g.t("ui.tutorial_next"), next_callback, g.EMBER, Vector2(120, 40))
	next_btn.name = "TutorialNextBtn"
	actions.add_child(next_btn)

	var skip_btn := g._button(g.t("ui.tutorial_skip"), _finish_tutorial, Color.TRANSPARENT, Vector2(0, 30))
	skip_btn.name = "TutorialSkipBtn"
	skip_btn.add_theme_color_override("font_color", g.MUTED)
	center.add_child(skip_btn)

func _tutorial_next_step() -> void:
	tutorial_step += 1
	_render_tutorial_step()

func _tutorial_prev_step() -> void:
	tutorial_step -= 1
	_render_tutorial_step()

func _finish_tutorial() -> void:
	g.profile.tutorial_seen = true
	SpiritSave.write(g.profile)
	if g.overlay == null: return
	var existing := g.overlay.get_node_or_null("BattleTutorial")
	if existing: existing.queue_free()

# MTG Arena's hold-to-peek: press and hold a card in hand and an enlarged copy floats up so
# you can actually read it; the moment you drag (HandCard._on_drag) or lift your finger
# (HandCard._on_touch_up), it drops away again — never a modal, never a button, never a
# stop that has to be dismissed on its own. See HandCard.PREVIEW_HOLD_DELAY for the hold time.
func _show_hold_preview(card: Dictionary) -> void:
	if g.overlay == null: return
	_clear_hold_preview()

	# A held touch's own release is not reliably delivered after a long-enough hold — iOS's
	# own long-press/haptic-touch gesture recognition can swallow it before Godot ever sees a
	# touch-up, no matter how quickly Godot itself reacts to the press. HandCard still tries
	# the direct route (its own touch-up, a raw _input() watcher, dragging away, a flat
	# timeout), but this dimmed tap-anywhere backdrop — Godot's own proven Button.pressed,
	# not raw touch-sequence tracking — is what actually guarantees the peek can be closed.
	var backdrop := _modal_backdrop("HoldPreview", _clear_hold_preview)
	backdrop.z_index = 400

	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(holder)

	var rune_id: String = g.profile.card_runes.get(card.id, "")
	var face := _big_card_face(card, rune_id)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(face)

	face.pivot_offset = face.custom_minimum_size / 2.0
	face.scale = Vector2(0.7, 0.7)
	face.modulate.a = 0.0
	var tw := g.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "scale", Vector2(1.2, 1.2), 0.16)
	tw.tween_property(face, "modulate:a", 1.0, 0.12)

func _clear_hold_preview() -> void:
	if g.overlay == null: return
	var existing := g.overlay.get_node_or_null("HoldPreview")
	if existing: existing.queue_free()

# A bigger, static twin of the HandCard face in _card_view: same frame/art/cost/rune
# language, scaled up with room for the full effect text instead of a 7pt sliver of it.
func _big_card_face(card: Dictionary, rune_id: String) -> Panel:
	var accent: Color = g._card_color(card)
	var border_col: Color = g._rune_color(rune_id, accent)
	var size := Vector2(230.0, 320.0)

	# Same full-bleed-art-plus-rules-box language as _card_view's hand cards, just at a size
	# where the description reads comfortably — this is what a held-down peek shows enlarged,
	# so it should look like a bigger version of the same card, not a different template.
	# Plain Panel, not PanelContainer: a Container force-fits EVERY direct child to its own
	# rect, which is exactly what turned this into a solid block showing only the last child
	# added (the cost badge) — art, the info box, and the badges all need to keep their own
	# size and position instead of being fought over by auto-layout.
	var frame := Panel.new()
	frame.clip_contents = true
	frame.custom_minimum_size = size
	frame.size = size
	var frame_style := g._panel(Color("0a171b"), 16, border_col)
	frame_style.border_width_left = 4; frame_style.border_width_right = 4
	frame_style.border_width_top = 4; frame_style.border_width_bottom = 4
	frame.add_theme_stylebox_override("panel", frame_style)

	var art := TextureRect.new()
	art.texture = g._get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_rarity: String = str(card.get("rarity", "Common"))
	var up_lvl: int = int(g.profile.upgrades.get(card.id, 0))
	_apply_card_foil(art, card_rarity, up_lvl > 0)
	frame.add_child(art)

	var info_box := PanelContainer.new()
	info_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info_box.anchor_left = 0.0; info_box.anchor_right = 1.0
	info_box.anchor_top = 0.52; info_box.anchor_bottom = 1.0
	info_box.offset_left = 0; info_box.offset_right = 0
	info_box.offset_top = 0; info_box.offset_bottom = 0
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := g._panel(Color(0.05, 0.09, 0.11, 0.97), 0)
	info_style.corner_radius_top_left = 8; info_style.corner_radius_top_right = 8
	info_style.border_width_top = 3; info_style.border_color = border_col
	# ~8% of the card width, clearing the slender border g.overlay added below
	info_style.content_margin_left = 20; info_style.content_margin_right = 20
	info_style.content_margin_top = 8; info_style.content_margin_bottom = 8
	info_box.add_theme_stylebox_override("panel", info_style)
	frame.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	info_box.add_child(stack)

	var name_text: String = g.content.text(card.nameKey, g.lang) + (" +" if up_lvl > 0 else "")
	var name_lbl := g._label(name_text, 16, Color("f3e8cf"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(name_lbl)

	var kind_lbl := g._label(g._kind_element_line(card), 11, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(kind_lbl)

	var desc_lbl := g._label(g._card_description(card), 13, Color("e4ede8"), HORIZONTAL_ALIGNMENT_CENTER, true)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc_lbl)

	# Ornate slim card frame selected according to card rarity (Starter, Common, Uncommon, Rare)
	var border_overlay := TextureRect.new()
	border_overlay.texture = g._get_card_frame_texture(card_rarity)
	border_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	border_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(border_overlay)

	var cost_badge := PanelContainer.new()
	cost_badge.custom_minimum_size = Vector2(38, 38)
	cost_badge.position = Vector2(-10, -10)
	cost_badge.add_theme_stylebox_override("panel", g._panel(accent, 19, Color("2b1a10")))
	var cost_lbl := g._label(str(int(card.cost)), 22, Color("160b06"), HORIZONTAL_ALIGNMENT_CENTER)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_lbl)
	frame.add_child(cost_badge)

	var rune_info: Dictionary = g.content.rune(rune_id)
	if not rune_info.is_empty():
		var rune_icon_path := "res://assets/icons/rune_%s.png" % rune_id
		if ResourceLoader.exists(rune_icon_path):
			var r_tr := TextureRect.new()
			r_tr.texture = load(rune_icon_path)
			r_tr.position = Vector2(size.x - 36.0, -8.0)
			r_tr.custom_minimum_size = Vector2(34, 34)
			r_tr.size = r_tr.custom_minimum_size
			r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(r_tr)
		else:
			var r_lbl := g._label(rune_info.icon, 22, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
			r_lbl.position = Vector2(size.x - 34.0, -8.0)
			frame.add_child(r_lbl)

	# Keyword tooltip badges — small tappable pills at the bottom of the enlarged card peek,
	# so a player can tap any mechanic name to see what it does without leaving the card.
	var kw_set: Dictionary = {}
	for effect in card.effects:
		var op: String = str(effect.get("operation", ""))
		if op in g.KEYWORD_KEYS: kw_set[op] = true
		var status_key: String = str(effect.get("status", ""))
		if status_key in g.KEYWORD_KEYS: kw_set[status_key] = true
		for special in effect.get("special", []):
			var sp: String = str(special)
			if sp in g.KEYWORD_KEYS: kw_set[sp] = true
	if not rune_id.is_empty() and rune_id in g.KEYWORD_KEYS: kw_set[rune_id] = true
	if not kw_set.is_empty():
		var kw_flow := HBoxContainer.new()
		kw_flow.position = Vector2(8.0, size.y - 28.0)
		kw_flow.size = Vector2(size.x - 16.0, 24.0)
		kw_flow.alignment = BoxContainer.ALIGNMENT_CENTER
		kw_flow.add_theme_constant_override("separation", 4)
		kw_flow.mouse_filter = Control.MOUSE_FILTER_PASS
		frame.add_child(kw_flow)
		for kw_key in kw_set:
			var kw_name: String = str(kw_key).capitalize()
			var pill := Button.new()
			pill.text = kw_name
			pill.custom_minimum_size = Vector2(0, 22)
			pill.add_theme_font_size_override("font_size", 9)
			pill.add_theme_color_override("font_color", Color("cce8e0"))
			pill.add_theme_stylebox_override("normal", g._panel(Color("1a3d44"), 6, g.JADE))
			pill.add_theme_stylebox_override("hover", g._panel(Color("1a3d44"), 6, g.JADE))
			pill.add_theme_stylebox_override("pressed", g._panel(Color("1a3d44"), 6, g.JADE))
			var kw_text: String = g.t("kw." + str(kw_key))
			pill.pressed.connect(func(): _show_info_popup(g._label(kw_name, 18, g.JADE, HORIZONTAL_ALIGNMENT_CENTER), kw_name, kw_text, g.JADE))
			kw_flow.add_child(pill)

	return frame

func _handle_targeting(event: InputEvent) -> bool:
	if g.selected_card < 0 or g.combat == null or g.combat.state.phase != "player" or g.resolving: return false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and not event.pressed: pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: pos = event.position
	else: return false

	for box in g.enemy_boxes:
		if box == null or not is_instance_valid(box): continue
		if not box.get_global_rect().has_point(pos): continue
		var enemy_index := int(box.get_meta("enemy_index"))
		if g.combat.state.enemies[enemy_index].health <= 0: continue
		var card_index := g.selected_card
		g.selected_card = -1
		g.get_viewport().set_input_as_handled()
		_attempt_play_card(card_index, enemy_index)
		return true
	return false

func _has_playable_card() -> bool:
	if g.combat == null: return false
	for instance in g.combat.state.hand:
		var card := g.content.card(instance.card_id)
		if not card.is_empty() and int(card.cost) <= int(g.combat.state.energy): return true
	return false

func _card_view(instance: Dictionary, index: int, count: int) -> HandCard:
	var card := g.content.card(instance.card_id)
	var tile := HandCard.new()
	tile.hand_index = index
	tile.card_data = card
	tile.game = g
	tile.custom_minimum_size = Vector2(116.0, 168.0)
	tile.size = tile.custom_minimum_size

	var accent: Color = g._card_color(card)
	var rune_id: String = g.profile.card_runes.get(card.id, "")
	var border_col: Color = g._rune_color(rune_id, accent)

	# 1. Base card container with clipping. Plain Panel, not PanelContainer — a Container
	# force-fits every direct child (art, the bottom info box, badges) to its own full rect,
	# which is what silently turned the whole card into a solid block showing only whichever
	# child got laid out last. A Panel just paints its stylebox and leaves children alone.
	# Note: the FULL ornate filigree texture (card_frame_golden.png) turns to a translucent
	# gold haze over the art when shrunk ~7.7x onto this 116x168 tile (fine scrollwork + lots
	# of transparent gaps average out under minification) — card_frame_golden_border.png (the
	# thin outer-ring derivative added below) keeps enough of that detail concentrated in a
	# narrower band to stay legible even at this size.
	var card_clip := Panel.new()
	card_clip.name = "CardFrame"
	card_clip.clip_contents = true
	card_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var clip_style := g._panel(Color("0a171b"), 10, border_col)
	clip_style.border_width_left = 3; clip_style.border_width_right = 3
	clip_style.border_width_top = 3; clip_style.border_width_bottom = 3
	card_clip.add_theme_stylebox_override("panel", clip_style)
	card_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(card_clip)

	# 2. Illustration covers the ENTIRE card, full colour, nothing drawn over it.
	var art := TextureRect.new()
	art.texture = g._get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_clip.add_child(art)

	# 3. A solid text box from the middle down, like a normal trading card's rules box —
	# a name/type bar over a dark, near-opaque description panel, not a floating translucent
	# island in the middle of the art.
	var info_box := PanelContainer.new()
	info_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info_box.anchor_left = 0.0
	info_box.anchor_right = 1.0
	info_box.anchor_top = 0.52
	info_box.anchor_bottom = 1.0
	info_box.offset_left = 0
	info_box.offset_right = 0
	info_box.offset_top = 0
	info_box.offset_bottom = 0
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := g._panel(Color(0.05, 0.09, 0.11, 0.97), 0)
	info_style.corner_radius_top_left = 6; info_style.corner_radius_top_right = 6
	info_style.border_width_top = 2; info_style.border_color = border_col
	# ~8% of the card width, clearing the slender border g.overlay added below
	info_style.content_margin_left = 11; info_style.content_margin_right = 11
	info_style.content_margin_top = 3; info_style.content_margin_bottom = 3
	info_box.add_theme_stylebox_override("panel", info_style)
	card_clip.add_child(info_box)

	var card_rarity: String = str(card.get("rarity", "Common"))
	var hand_border := TextureRect.new()
	hand_border.texture = g._get_card_frame_texture(card_rarity)
	hand_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand_border.stretch_mode = TextureRect.STRETCH_SCALE
	hand_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_clip.add_child(hand_border)

	var info_stack := VBoxContainer.new()
	info_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_stack.add_theme_constant_override("separation", 1)
	info_box.add_child(info_stack)

	var up_lvl: int = int(g.profile.upgrades.get(card.id, 0))
	var name_text: String = g.content.text(card.nameKey, g.lang) + (" +" if up_lvl > 0 else "")
	var name_lbl := g._label(name_text, 10, Color("f3e8cf"), HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_stack.add_child(name_lbl)

	var kind_lbl := g._label(g._kind_element_line(card), 7, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	kind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_stack.add_child(kind_lbl)

	var desc_lbl := g._label(g._card_description(card), 8, Color("e4ede8"), HORIZONTAL_ALIGNMENT_CENTER, true)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_stack.add_child(desc_lbl)

	# 5. Top badges (cost & rune)
	var cost_badge := PanelContainer.new()
	cost_badge.custom_minimum_size = Vector2(26, 26)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.position = Vector2(-6, -6)
	cost_badge.add_theme_stylebox_override("panel", g._panel(accent, 13, Color("2b1a10")))
	var cost_lbl := g._label(str(int(card.cost)), 16, Color("160b06"), HORIZONTAL_ALIGNMENT_CENTER)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_badge.add_child(cost_lbl)
	tile.add_child(cost_badge)

	var rune_info: Dictionary = g.content.rune(rune_id)
	if not rune_info.is_empty():
		var rune_icon_path := "res://assets/icons/rune_%s.png" % rune_id
		if ResourceLoader.exists(rune_icon_path):
			var r_tr := TextureRect.new()
			r_tr.texture = load(rune_icon_path)
			r_tr.position = Vector2(116.0 - 26.0, -6.0)
			r_tr.custom_minimum_size = Vector2(24, 24)
			r_tr.size = r_tr.custom_minimum_size
			r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(r_tr)
		else:
			var r_lbl := g._label(rune_info.icon, 16, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
			r_lbl.position = Vector2(116.0 - 24.0, -6.0)
			tile.add_child(r_lbl)

	var center_idx: float = (count - 1) / 2.0
	var distance: float = float(index) - center_idx
	var spacing: float = minf(64.0, 250.0 / maxf(1.0, float(count - 1)))
	var center_x: float = 366.0 / 2.0
	tile.home_rot = deg_to_rad(distance * 2.8)
	tile.home_pos = Vector2(center_x + distance * spacing - 58.0, 10.0 + absf(distance) * 4.2)
	tile.position = tile.home_pos
	tile.rotation = tile.home_rot
	tile.z_index = index

	# The armed card lifts clear of the fan so it is obvious which one is waiting on a target.
	if index == g.selected_card:
		card_clip.add_theme_stylebox_override("panel", g._panel(Color("1d3a35"), 12, g.GOLD))
		tile.position = tile.home_pos - Vector2(0, 30)
		tile.rotation = 0.0
		tile.z_index = 80

	return tile

# Mirrors the bonuses g.combat.play() applies, so the number on screen matches what lands.
func _predict_damage(card: Dictionary, enemy_index: int) -> Dictionary:
	var result := {"damage": 0, "blocked": 0, "lethal": false, "is_attack": false}
	if g.combat == null or enemy_index < 0 or enemy_index >= g.combat.state.enemies.size(): return result
	var base := 0
	for effect in card.effects:
		if effect.operation == "damage" and effect.target == "opponent": base += int(effect.amount)
	if base <= 0: return result
	result.is_attack = true

	var bonus := int(g.combat.state.upgrades.get(card.id, 0))
	bonus += int(g.combat.state.player.get("strength", 0))
	if int(g.combat.state.player.focus) > 0: bonus += 3 * int(g.combat.state.player.focus)
	if not bool(g.combat.state.first_attack):
		if g.combat.state.equipment.has("emberBlade"): bonus += 3
		if g.combat.state.get("relics", []).has("starShard"): bonus += 2
	var rune: String = g.combat.state.runes.get(card.id, "")
	if rune == "resonance": bonus += int(g.combat.state.elements.get(card.get("element", ""), 0))

	var enemy: Dictionary = g.combat.state.enemies[enemy_index]
	var total := 0
	for effect in card.effects:
		if effect.operation != "damage" or effect.target != "opponent": continue
		var amount: int = maxi(1, int(effect.amount) + bonus)
		if rune == "execute" and enemy.health <= enemy.max_health * 0.25: amount = int(round(amount * 1.5))
		if card.get("special", "") == "critical": amount *= 2
		if int(enemy.get("vulnerable", 0)) > 0: amount = int(round(amount * 1.5))
		total += amount
	if rune == "echo": total += int(round(total * 0.5))

	var pierce: bool = card.get("special", "") == "pierce" or g.combat.state.equipment.has("stoneSpear")
	var blocked: int = 0 if pierce else mini(int(enemy.shield), total)
	result.blocked = blocked
	result.damage = maxi(0, total - blocked)
	result.lethal = result.damage >= int(enemy.health)
	return result

func _show_damage_preview(card: Dictionary, enemy_index: int) -> void:
	_clear_damage_preview()
	if g.overlay == null: return
	var prediction := _predict_damage(card, enemy_index)
	if not prediction.is_attack: return
	var box: Control = null
	for candidate in g.enemy_boxes:
		if candidate and is_instance_valid(candidate) and int(candidate.get_meta("enemy_index")) == enemy_index:
			box = candidate
			break
	if box == null: return

	var holder := VBoxContainer.new()
	holder.name = "DamagePreview"
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 0)
	holder.position = box.global_position + Vector2(box.size.x / 2.0 - 40.0, -34.0)
	holder.size = Vector2(80, 42)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.overlay.add_child(holder)

	var tone: Color = Color("ff6f5e") if prediction.lethal else Color("ffe6b8")
	holder.add_child(g._label("−%d" % prediction.damage, 26, tone, HORIZONTAL_ALIGNMENT_CENTER))
	if prediction.lethal:
		var lethal_badge := g._label("☠ " + g.t("ui.lethal"), 11, Color("ff4444"), HORIZONTAL_ALIGNMENT_CENTER)
		lethal_badge.name = "LethalBadge"
		holder.add_child(lethal_badge)
		var tw := holder.create_tween().set_loops()
		tw.tween_property(lethal_badge, "modulate:a", 0.45, 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lethal_badge, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	elif prediction.blocked > 0:
		holder.add_child(g._label(g.tf("ui.preview_blocked", prediction.blocked), 10, Color("9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER))

func _clear_damage_preview() -> void:
	if g.overlay == null: return
	var existing := g.overlay.get_node_or_null("DamagePreview")
	if existing: existing.queue_free()

func _show_cancel_zone(active: bool) -> void:
	if g.overlay == null: return
	var zone: Control = g.overlay.get_node_or_null("CancelDropZone") as Control
	if not active:
		if zone: zone.queue_free()
		return
	if zone != null: return
	zone = Panel.new()
	zone.name = "CancelDropZone"
	zone.custom_minimum_size = Vector2(366.0, 140.0)
	zone.size = zone.custom_minimum_size
	zone.position = Vector2(12.0, 660.0)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := g._panel(Color(0.55, 0.12, 0.12, 0.45), 14, Color(1.0, 0.45, 0.45, 0.8))
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	zone.add_theme_stylebox_override("panel", style)
	var lbl := g._label("✕ " + g.t("ui.cancel_drop"), 12, Color("ffd5d5"), HORIZONTAL_ALIGNMENT_CENTER)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone.add_child(lbl)
	g.overlay.add_child(zone)

func show_pile_inspector(title_key: String, pile: Array) -> void:
	if g.overlay == null: return
	_clear_pile_inspector()
	var backdrop := _modal_backdrop("PileInspector", _clear_pile_inspector)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(366, 560)
	panel.size = panel.custom_minimum_size
	panel.position = Vector2(12, 140)
	panel.add_theme_stylebox_override("panel", g._panel(Color("091316"), 16, Color("2d4a52")))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(350, 44)
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(header)

	var spacer_l := Control.new()
	spacer_l.custom_minimum_size = Vector2(12, 0)
	header.add_child(spacer_l)

	var title_lbl := g._label(g.t(title_key), 17, g.TEXT)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var count_lbl := g._label(g.tf("ui.pile_count_desc", pile.size()), 11, g.MUTED)
	header.add_child(count_lbl)

	var close_btn := g._button("✕", _clear_pile_inspector, Color("2a3f45"), Vector2(36, 32))
	close_btn.name = "PileCloseBtn"
	header.add_child(close_btn)

	var spacer_r := Control.new()
	spacer_r.custom_minimum_size = Vector2(8, 0)
	header.add_child(spacer_r)

	var scroll := TouchScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.allow_vertical = true
	vbox.add_child(scroll)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(pad)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	pad.add_child(grid)

	for item in pile:
		var c_id: String = item.card_id if (item is Dictionary and item.has("card_id")) else str(item)
		var c_data: Dictionary = g.content.card(c_id)
		if not c_data.is_empty():
			grid.add_child(_pile_card_tile(c_data))

func _clear_pile_inspector() -> void:
	if g.overlay == null: return
	var existing := g.overlay.get_node_or_null("PileInspector")
	if existing: existing.queue_free()

func _pile_card_tile(card: Dictionary) -> Control:
	var accent := g._card_color(card)
	var rune_id: String = ""
	if g.combat and g.combat.state: rune_id = g.combat.state.runes.get(card.id, "")
	elif g.profile: rune_id = g.profile.card_runes.get(card.id, "")

	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(170, 225)
	tile.size = tile.custom_minimum_size
	tile.add_theme_stylebox_override("panel", g._panel(Color("11242a"), 12, accent))
	tile.clip_contents = true

	var art := TextureRect.new()
	art.texture = g._get_card_texture(card.id)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var up_lvl: int = int(g.combat.state.upgrades.get(card.id, 0)) if (g.combat and g.combat.state) else int(g.profile.upgrades.get(card.id, 0))
	_apply_card_foil(art, str(card.get("rarity", "Common")), up_lvl > 0)
	tile.add_child(art)

	g._add_ornate_frame(tile, tile.custom_minimum_size, accent, str(card.get("rarity", "Common")))

	var badge := g._cost_badge(int(card.cost), accent)
	badge.position = Vector2(8, 8)
	tile.add_child(badge)

	if not rune_id.is_empty():
		var rune_info := g.content.rune(rune_id)
		var rune_path := "res://assets/icons/rune_%s.png" % rune_id
		if ResourceLoader.exists(rune_path):
			var r_tr := TextureRect.new()
			r_tr.texture = load(rune_path)
			r_tr.position = Vector2(38, 8)
			r_tr.custom_minimum_size = Vector2(20, 20)
			r_tr.size = r_tr.custom_minimum_size
			r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(r_tr)
		else:
			var rune_lbl := g._label(rune_info.icon, 14, Color(rune_info.color), HORIZONTAL_ALIGNMENT_CENTER)
			rune_lbl.position = Vector2(38, 8)
			rune_lbl.size = Vector2(20, 20)
			tile.add_child(rune_lbl)

	var rarity_row := g._rarity_star_row(str(card.rarity), g.GOLD, BoxContainer.ALIGNMENT_END)
	rarity_row.position = Vector2(84, 10)
	rarity_row.size = Vector2(76, 16)
	tile.add_child(rarity_row)

	var info_box := PanelContainer.new()
	info_box.position = Vector2(8, 90)
	info_box.custom_minimum_size = Vector2(154, 126)
	info_box.size = info_box.custom_minimum_size
	var box_style := g._panel(Color(0.06, 0.12, 0.16, 0.92), 8, accent)
	box_style.content_margin_left = 10; box_style.content_margin_right = 10
	box_style.content_margin_top = 4; box_style.content_margin_bottom = 4
	info_box.add_theme_stylebox_override("panel", box_style)
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(info_box)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(stack)

	stack.add_child(g._label(g.content.text(card.nameKey, g.lang) + (" +" if up_lvl > 0 else ""), 12, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(g._label(g._kind_element_line(card), 8, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var desc := g._label(g._card_description(card), 8, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	desc.custom_minimum_size.y = 48
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)

	return tile

func _shake_screen(intensity: float, duration := 0.24) -> void:
	if g.root == null: return
	var origin := g.root.position
	var shake := g.root.create_tween()
	var steps := 5
	for i in steps:
		var falloff: float = intensity * (1.0 - float(i) / float(steps))
		var offset := Vector2(randf_range(-falloff, falloff), randf_range(-falloff, falloff))
		shake.tween_property(g.root, "position", origin + offset, duration / float(steps))
	shake.tween_property(g.root, "position", origin, duration / float(steps))

func _target_ring(hot: bool) -> StyleBoxFlat:
	var ring := g._panel(Color(1.0, 0.86, 0.42, 0.22 if hot else 0.08), 14, Color(1.0, 0.92, 0.55, 1.0) if hot else Color(1.0, 0.86, 0.42, 0.7))
	var width := 3 if hot else 2
	ring.border_width_left = width; ring.border_width_right = width
	ring.border_width_top = width; ring.border_width_bottom = width
	return ring

# Shows every legal target for the card currently in play, so you can see what you may aim
# at before you get there rather than discovering it by dragging over each enemy.
func _show_valid_targets(mode: String) -> void:
	for box in g.enemy_boxes:
		if box == null or not is_instance_valid(box): continue
		var glow: Control = box.get_node_or_null("TargetGlow")
		if glow == null: continue
		var alive: bool = g.combat != null and g.combat.state.enemies[int(box.get_meta("enemy_index"))].health > 0
		glow.visible = mode == "enemy" and alive
		glow.add_theme_stylebox_override("panel", _target_ring(false))
	var player_glow: Control = g.root.find_child("PlayerTargetGlow", true, false) as Control
	if player_glow: player_glow.visible = mode == "self"

func _clear_valid_targets() -> void:
	_show_valid_targets("")
	for box in g.enemy_boxes:
		if box and is_instance_valid(box):
			var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
			if sprite: sprite.modulate = Color.WHITE

func _set_enemy_targeted(enemy_index: int, targeted: bool) -> void:
	for box in g.enemy_boxes:
		if box and is_instance_valid(box) and int(box.get_meta("enemy_index")) == enemy_index:
			var glow: Control = box.get_node_or_null("TargetGlow")
			if glow and glow.visible: glow.add_theme_stylebox_override("panel", _target_ring(targeted))
			# Brighten rather than enlarge: the old 1.08x jump read as the model popping.
			var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
			if sprite: sprite.modulate = Color(1.35, 1.3, 1.15) if targeted else Color.WHITE

# Stays synchronous so callers get a real bool back; the animation runs in _resolve_play.
func _attempt_play_card(hand_index: int, target: int) -> bool:
	if g.combat == null or g.combat.state.phase != "player" or g.resolving: return false
	var before: Array = []
	for enemy in g.combat.state.enemies: before.append(int(enemy.health))
	if not g.combat.play(hand_index, target):
		g._toast(g.t("ui.target_invalid"))
		return false
	g.selected_card = -1
	g.resolving = true
	_resolve_play(before)
	return true

func _resolve_play(before: Array) -> void:
	for i in g.combat.state.enemies.size():
		if i < before.size() and before[i] > g.combat.state.enemies[i].health:
			await _animate_enemy_hit(i, before[i] - g.combat.state.enemies[i].health, g.combat.state.enemies[i].health <= 0)
	show_battle()
	await _maybe_end_turn()
	g.resolving = false

# There is no End Turn button, so the turn has to hand itself over once nothing in hand is
# affordable any more (either the hand is empty or every card costs more than remaining energy).
func _maybe_end_turn() -> void:
	var guard := 0
	while g.combat != null and g.combat.state.phase == "player" and guard < 12:
		guard += 1
		if _has_playable_card(): return
		if g.combat.state.hand.size() > 0: g._toast(g.t("ui.no_playable"))
		await g.get_tree().create_timer(g._battle_delay(0.28)).timeout
		if g.combat == null or g.combat.state.phase != "player": return
		await _enemy_turn()

func _animate_enemy_hit(enemy_index: int, amount: int, defeated: bool) -> void:
	var box: Control = null
	for candidate in g.enemy_boxes:
		if candidate and is_instance_valid(candidate) and int(candidate.get_meta("enemy_index")) == enemy_index:
			box = candidate
			break
	if box == null: return

	var popup := g._label("−%d" % amount, 34, Color("ff6f5e") if defeated else Color("fff4d3"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = box.global_position + Vector2(box.size.x / 2.0 - 40.0, 34.0)
	popup.size = Vector2(80, 40)
	popup.z_index = 200
	popup.pivot_offset = Vector2(40, 20)
	popup.scale = Vector2(0.5, 0.5)
	g.overlay.add_child(popup)
	var punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(popup, "scale", Vector2(1.2, 1.2), 0.14)
	punch.tween_property(popup, "scale", Vector2.ONE, 0.1)

	g._haptic("heavy" if defeated else "hit")
	_shake_screen(9.0 if defeated else clampf(float(amount) * 0.45, 2.5, 7.0))

	var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
	var tween := g.create_tween().set_parallel(true)
	if sprite:
		_flash_hit(sprite, Color("ff5c4a"))
		_squash_impact(sprite, float(sprite.get_meta("base_scale", 1.0)), 0.28 if defeated else 0.18)
	tween.tween_property(popup, "position:y", popup.position.y - 45.0, 0.45)
	tween.tween_property(popup, "modulate:a", 0.0, 0.45)
	if defeated:
		tween.tween_property(box, "modulate:a", 0.0, 0.4)
		tween.tween_property(box, "scale", Vector2(0.4, 0.4), 0.4)
	await tween.finished
	popup.queue_free()
	if defeated and g.combat != null and g.combat.state.phase == "won":
		await _animate_finishing_blow(box, sprite)

func _animate_finishing_blow(box: Control, sprite: Node2D) -> void:
	if g.overlay == null: return
	g._haptic("heavy")
	_shake_screen(14.0, 0.45)

	var top_bar := ColorRect.new()
	top_bar.color = Color("04090c")
	top_bar.custom_minimum_size = Vector2(390, 64)
	top_bar.size = top_bar.custom_minimum_size
	top_bar.position = Vector2(0, -64)
	top_bar.z_index = 450
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.overlay.add_child(top_bar)

	var btm_bar := ColorRect.new()
	btm_bar.color = Color("04090c")
	btm_bar.custom_minimum_size = Vector2(390, 64)
	btm_bar.size = btm_bar.custom_minimum_size
	btm_bar.position = Vector2(0, 844)
	btm_bar.z_index = 450
	btm_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.overlay.add_child(btm_bar)

	var banner := PanelContainer.new()
	banner.name = "FinishingBlowBanner"
	banner.z_index = 460
	banner.custom_minimum_size = Vector2(260, 56)
	banner.position = Vector2(65, 340)
	banner.pivot_offset = Vector2(130, 28)
	banner.scale = Vector2(0.4, 0.4)
	banner.modulate.a = 0.0
	var b_style := g._panel(Color(0.1, 0.03, 0.02, 0.95), 12, Color("ffd700"))
	b_style.border_width_left = 2; b_style.border_width_right = 2
	b_style.border_width_top = 2; b_style.border_width_bottom = 2
	b_style.content_margin_left = 12; b_style.content_margin_right = 12
	b_style.content_margin_top = 6; b_style.content_margin_bottom = 6
	banner.add_theme_stylebox_override("panel", b_style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var b_stack := VBoxContainer.new()
	b_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	b_stack.add_theme_constant_override("separation", -2)
	b_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(b_stack)

	var b_title := g._label("✦ " + g.t("ui.finishing_blow") + " ✦", 20, Color("ffd700"), HORIZONTAL_ALIGNMENT_CENTER)
	var b_sub := g._label(g.t("ui.finishing_sub"), 9, Color("ffb09c"), HORIZONTAL_ALIGNMENT_CENTER)
	b_stack.add_child(b_title)
	b_stack.add_child(b_sub)
	g.overlay.add_child(banner)

	if sprite:
		_flash_hit(sprite, Color(2.5, 2.5, 2.5))

	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(top_bar, "position:y", 0.0, g._battle_delay(0.2)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(btm_bar, "position:y", 780.0, g._battle_delay(0.2)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "scale", Vector2.ONE, g._battle_delay(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, g._battle_delay(0.15))
	if sprite:
		var base_scale: float = float(sprite.get_meta("base_scale", 1.0))
		tw.tween_property(sprite, "scale", Vector2.ONE * (base_scale * 1.3), g._battle_delay(0.25))

	await tw.finished
	await g.get_tree().create_timer(g._battle_delay(0.4)).timeout

	var out_tw := g.create_tween().set_parallel(true)
	out_tw.tween_property(banner, "modulate:a", 0.0, g._battle_delay(0.25))
	out_tw.tween_property(banner, "scale", Vector2(1.2, 1.2), g._battle_delay(0.25))
	out_tw.tween_property(top_bar, "position:y", -64.0, g._battle_delay(0.25))
	out_tw.tween_property(btm_bar, "position:y", 844.0, g._battle_delay(0.25))
	if sprite:
		out_tw.tween_property(sprite, "modulate:a", 0.0, g._battle_delay(0.25))

	await out_tw.finished
	top_bar.queue_free()
	btm_bar.queue_free()
	banner.queue_free()

func _advance_to_reward() -> void:
	# show_battle can run several times while the win is on screen; only one hand-off.
	if g.advancing_to_reward: return
	g.advancing_to_reward = true
	await g.get_tree().create_timer(g._battle_delay(0.8)).timeout
	g.advancing_to_reward = false
	if g.combat != null and g.combat.state.phase == "won": g.show_reward()

func _enemy_turn() -> void:
	g.selected_card = -1
	# Snapshot the telegraphed intents before end_turn consumes them, so each enemy can play
	# the animation for what it actually promised.
	var planned: Array = []
	for enemy in g.combat.state.enemies:
		planned.append(str(enemy.get("intent", {}).get("kind", "attack")) if enemy.health > 0 else "")
	for box in g.enemy_boxes:
		if box == null or not is_instance_valid(box): continue
		var index := int(box.get_meta("enemy_index"))
		if index >= planned.size() or str(planned[index]).is_empty(): continue
		await _animate_enemy_action(box, str(planned[index]), g.combat.state.enemies[index])

	var before_health: int = g.combat.state.player.health
	g.combat.end_turn()
	if g.combat.state.player.health < before_health:
		g._haptic("heavy")
		await _animate_player_hit(before_health - g.combat.state.player.health)
	show_battle()

# The tint a sprite should rest at once its action animation finishes — plain white unless
# a persistent status (currently just Weak) is dulling it, in which case resetting to pure
# white would erase that status's own visual cue.
func _resting_modulate(state: Dictionary) -> Color:
	return Color(0.72, 0.72, 0.78, 1.0) if int(state.get("weak", 0)) > 0 else Color.WHITE

func _animate_enemy_action(box: Control, kind: String, enemy_state: Dictionary) -> void:
	var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
	if sprite == null: return
	var origin: Vector2 = sprite.position
	var base_scale: float = float(sprite.get_meta("base_scale", 1.0))
	var rest_tint := _resting_modulate(enemy_state)
	var tween := sprite.create_tween()
	match kind:
		"defend":
			# Anticipation (crouch/squash) then a small rise, like drawing a shield up.
			tween.tween_property(sprite, "modulate", Color(0.75, 0.95, 1.6), 0.1)
			tween.tween_property(sprite, "scale", Vector2(base_scale * 1.14, base_scale * 0.88), 0.12).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(sprite, "position:y", origin.y - 10.0, 0.12).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, 0.16).set_trans(Tween.TRANS_BACK)
			tween.tween_property(sprite, "position:y", origin.y, 0.14)
			tween.tween_property(sprite, "modulate", rest_tint, 0.14)
		"empower":
			# A single decisive stretch-up "power surge" rather than a repeated wobble.
			tween.tween_property(sprite, "modulate", Color(1.6, 0.9, 1.8), 0.1)
			tween.tween_property(sprite, "scale", Vector2(base_scale * 0.9, base_scale * 1.22), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", Vector2.ONE * base_scale * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", Vector2.ONE * base_scale, 0.14).set_trans(Tween.TRANS_ELASTIC)
			tween.parallel().tween_property(sprite, "modulate", rest_tint, 0.2)
		"curse":
			tween.tween_property(sprite, "modulate", Color(0.9, 1.6, 0.7), 0.12)
			tween.tween_property(sprite, "position:x", origin.x + 7.0, 0.06)
			tween.tween_property(sprite, "position:x", origin.x - 7.0, 0.06)
			tween.tween_property(sprite, "position:x", origin.x, 0.06)
			tween.tween_property(sprite, "modulate", rest_tint, 0.14)
		_:
			# Anticipation (rise + squash back), action (fast lunge down + stretch), impact
			# (squash flat + hit-flash + screen shake), recovery (elastic settle).
			tween.tween_property(sprite, "position:y", origin.y - 16.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.12, base_scale * 0.86), 0.16).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(sprite, "position:y", origin.y + 48.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 0.82, base_scale * 1.28), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(sprite, "modulate", Color(1.9, 1.1, 0.9), 0.09)
			tween.tween_callback(func():
				_flash_hit(sprite, Color(1.0, 0.75, 0.55), 0.14)
				_shake_screen(4.0)
				g._haptic("tap"))
			tween.tween_property(sprite, "scale", Vector2(base_scale * 1.1, base_scale * 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(sprite, "position:y", origin.y, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(sprite, "modulate", rest_tint, 0.22)
	await tween.finished
	sprite.position = origin
	sprite.scale = Vector2.ONE * base_scale
	sprite.modulate = rest_tint

func _animate_player_hit(amount: int) -> void:
	var popup := g._label("−%d" % amount, 38, Color("ff786a"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = Vector2(155, 480)
	popup.size = Vector2(80, 44)
	popup.z_index = 200
	popup.pivot_offset = Vector2(40, 22)
	popup.scale = Vector2(0.5, 0.5)
	g.overlay.add_child(popup)
	var punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(popup, "scale", Vector2(1.25, 1.25), 0.14)
	punch.tween_property(popup, "scale", Vector2.ONE, 0.1)
	_shake_screen(clampf(float(amount) * 0.7, 4.0, 12.0), 0.3)

	# Red wash over the screen so a hit registers even if you were looking at your hand.
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.15, 0.12, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.overlay.add_child(flash)
	var wash := flash.create_tween()
	wash.tween_property(flash, "color:a", 0.28, 0.07)
	wash.tween_property(flash, "color:a", 0.0, 0.32)
	wash.tween_callback(flash.queue_free)

	var tween := g.create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 60.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	
	var player_node: Sprite2D = g.get_tree().root.find_child("PlayerSprite", true, false) as Sprite2D
	if player_node:
		_flash_hit(player_node, Color("ff5c4a"))
		_squash_impact(player_node, float(player_node.get_meta("base_scale", 1.0)), 0.24)

	await tween.finished
	popup.queue_free()

func _combat_event(kind: String, payload: Dictionary) -> void:
	if kind == "intent":
		var style := _intent_style({"kind": payload.kind, "amount": payload.amount})
		var tip: String = {"defend": "ui.intent_tip_defend", "empower": "ui.intent_tip_empower", "curse": "ui.intent_tip_curse"}.get(str(payload.kind), "")
		if not tip.is_empty(): g._toast("%s %s" % [g.t(tip), style.text], style.border)
	elif kind == "player_burn": g._toast("♨ −%d" % payload.amount, Color("ff9868"))
	elif kind == "thorns": g._toast(g.tf("ui.thorns_toast", payload.amount), Color("ff8a8a"))
	elif kind == "revive": g._toast(g.tf("ui.revive_toast", payload.amount),Color("9bffd3"))
	elif kind == "equipment":
		var item := g.content.equipment(payload.id); if not item.is_empty(): g._toast("%s %s" % [item.icon, g._equip_name(item)],g.GOLD)
	elif kind == "card":
		if int(payload.get("damage", 0)) > 0: g._advance_quest("deal_damage", int(payload.damage))
		if not str(payload.rune).is_empty():
			g._advance_quest("play_runed_cards", 1)
			var rune := g.content.rune(payload.rune); g._toast("%s %s" % [rune.icon, g._rune_name(rune)],Color(rune.color))
	elif kind == "boss_phase":
		var p_name: String = payload.get("name_en", "") if g.lang == "en" else payload.get("name", "")
		var p_desc: String = payload.get("desc_en", "") if g.lang == "en" else payload.get("desc", "")
		_show_boss_phase_banner(p_name, p_desc)

func _show_boss_phase_banner(title: String, subtitle: String) -> void:
	if g.overlay == null: return
	g._haptic("heavy")
	var banner := PanelContainer.new()
	banner.name = "BossPhaseBanner"
	banner.z_index = 460
	banner.custom_minimum_size = Vector2(300, 64)
	banner.position = Vector2(45, 280)
	banner.pivot_offset = Vector2(150, 32)
	banner.scale = Vector2(0.6, 0.6)
	banner.modulate.a = 0.0
	var b_style := g._panel(Color(0.14, 0.03, 0.05, 0.95), 14, Color("ff5959"))
	b_style.border_width_left = 2; b_style.border_width_right = 2
	b_style.border_width_top = 2; b_style.border_width_bottom = 2
	banner.add_theme_stylebox_override("panel", b_style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var b_stack := VBoxContainer.new()
	b_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	b_stack.add_theme_constant_override("separation", 2)
	b_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(b_stack)

	var b_title := g._label("⚔ PHASE II · " + title + " ⚔", 16, Color("ffd700"), HORIZONTAL_ALIGNMENT_CENTER)
	var b_sub := g._label(subtitle, 10, Color("ffc9c9"), HORIZONTAL_ALIGNMENT_CENTER, true)
	b_stack.add_child(b_title)
	b_stack.add_child(b_sub)
	g.overlay.add_child(banner)

	var tw := banner.create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "scale", Vector2.ONE, g._battle_delay(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, g._battle_delay(0.2))
	var seq := banner.create_tween()
	seq.tween_interval(g._battle_delay(1.5))
	seq.tween_property(banner, "modulate:a", 0.0, g._battle_delay(0.3))
	seq.tween_callback(banner.queue_free)

func _leave_battle() -> void:
	g.selected_card = -1
	if g.in_abyss:
		g.in_abyss = false
		g.profile.health = maxi(1, g.pre_battle_health)
		SpiritSave.write(g.profile)
		g.show_camp()
		return
	if g.in_daily_trial:
		# A loss (or an early retreat) costs the attempt, not the run: the stage you were on
		# stays un-cleared so today's next try re-fights it, same "attempt vs. run" split the
		# comment above already uses for Abyss.
		g.in_daily_trial = false
		g.profile.health = maxi(1, g.pre_battle_health)
		SpiritSave.write(g.profile)
		g.show_camp()
		return
	if g.combat != null:
		# A defeat costs you the attempt, not the run: health returns to what you entered with.
		# Retreating mid-battle still keeps the damage you took.
		if g.combat.state.phase == "lost": g.profile.health = maxi(1, g.pre_battle_health)
		else: g.profile.health = maxi(1, int(g.combat.state.player.health))
	SpiritSave.write(g.profile)
	g.show_map()

