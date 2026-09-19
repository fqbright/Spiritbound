extends RefCounted
class_name BattleScreen

# Composition, not inheritance — see MapScreen's header comment (game_map_screen.gd) for
# why. `g` is the live SpiritGame instance; every reference to shared state or another
# screen's function goes through it.
var g: SpiritGame
var auto_stepping: bool = false

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

# Composes the per-stage random flavor modifier above with content.difficulty_modifier()'s
# player-selected tier scaling — both can independently carry health_scale/damage_bonus/
# reward_scale, so this multiplies (health_scale, reward_scale) and adds (damage_bonus)
# rather than one silently overwriting the other. Also combines display text (name/name_en/
# detail/detail_en) rather than dropping it: _build_player_stage()'s modifier badge reads
# those four fields unconditionally whenever active_modifier isn't empty — the exact same
# invariant content.daily_trial_modifier()'s own comment documents crashing on once already
# (an early version returned only raw combat.gd keys with no display text). A tier-only
# modifier (the common case — the flavor modifier above is empty 52% of the time) would hit
# that same crash if it came back non-empty with no name/detail, so difficulty_modifier()
# always carries its own.
func _apply_difficulty(base: Dictionary, tier_mod: Dictionary) -> Dictionary:
	if tier_mod.is_empty(): return base
	var merged: Dictionary = base.duplicate()
	merged["health_scale"] = float(base.get("health_scale", 1.0)) * float(tier_mod.get("health_scale", 1.0))
	merged["damage_bonus"] = int(base.get("damage_bonus", 0)) + int(tier_mod.get("damage_bonus", 0))
	merged["reward_scale"] = float(base.get("reward_scale", 1.0)) * float(tier_mod.get("reward_scale", 1.0))
	if base.has("name"):
		merged["name"] = "%s · %s" % [str(base.name), str(tier_mod.name)]
		merged["name_en"] = "%s · %s" % [str(base.name_en), str(tier_mod.name_en)]
		merged["detail"] = "%s；%s" % [str(base.detail), str(tier_mod.detail)]
		merged["detail_en"] = "%s; %s" % [str(base.detail_en), str(tier_mod.detail_en)]
	else:
		merged["name"] = tier_mod.name
		merged["name_en"] = tier_mod.name_en
		merged["detail"] = tier_mod.detail
		merged["detail_en"] = tier_mod.detail_en
	return merged

func begin_battle(index: int) -> void:
	g.resolving = false
	auto_stepping = false

	# Keep the map's browsed chapter in sync with whatever stage is actually being fought, so
	# a map shown before this call (the header hides during battle, but the state persists)
	# or after _leave_battle() returns to it (see its final else-branch) already lands on the
	# right chapter instead of wherever the player last happened to be browsing.
	g.current_map_chapter = index / 5
	g.current_stage = index
	# New battle invalidates any previous one's in-flight _resolve_play() coroutine (see
	# battle_session's own comment in game.gd) — and resolving is this battle's own fresh
	# start, never mid-card-resolution, regardless of what a stale coroutine from the last one
	# might still be about to do.
	g.battle_session += 1
	g.resolving = false
	var seed := int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	g.active_modifier = _apply_difficulty(_modifier(seed, index), g.content.difficulty_modifier(int(g.profile.difficulty)))
	g.combat = SpiritCombat.new(g.content)
	var equipped: Array = g.profile.equipment_slots.values()
	var battle_deck: Array = g.profile.deck
	if g.in_draft_battle and g.profile.get("draft_arena", {}).get("deck", []).size() >= 15:
		battle_deck = g.profile.draft_arena.deck
	g.combat.create(seed,g.content.encounters[index],battle_deck,60,g.profile.upgrades,equipped,g.profile.card_runes,g.active_modifier,g.profile.relics,g._current_hero_mastery_bonuses(),g.profile.equipment_tiers,g.profile.equipment_inscriptions)
	g.battle_log = BattleLog.new()
	g.combat.event.connect(_combat_event)
	if g._mark_discovered("bestiary", str(g.content.encounters[index].name)):
		g._grant_bestiary_discovery_bonus(g.content.encounters[index])
	g.pre_battle_health = 60
	g.advancing_to_reward = false
	g.selected_card = -1
	g._last_hand_size = 0
	show_battle()
	if index == 0 and not bool(g.profile.get("tutorial_seen", false)): _show_battle_tutorial()
	_maybe_end_turn()
	if g.auto_battle_active: _maybe_step_auto_battle()

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
	var auto_label: String = g.t("ui.auto_battle_active") if g.auto_battle_active else g.t("ui.auto_battle")
	var auto_btn: Button
	var on_toggle_auto = func():
		g.toggle_auto_battle()
		if auto_btn != null and is_instance_valid(auto_btn):
			auto_btn.text = g.t("ui.auto_battle_active") if g.auto_battle_active else g.t("ui.auto_battle")
			var btn_color := Color("205944") if g.auto_battle_active else Color("1a3a42")
			auto_btn.add_theme_stylebox_override("normal", g._panel(btn_color, 10, g.GOLD))
			auto_btn.add_theme_stylebox_override("hover", g._panel(btn_color.lightened(0.1), 10, g.JADE))
			auto_btn.add_theme_stylebox_override("pressed", g._panel(btn_color.darkened(0.12), 10, g.EMBER))
		if g.auto_battle_active and not g.resolving and g.combat != null and g.combat.state.phase == "player":
			_maybe_step_auto_battle()
	auto_btn = g._button(auto_label, on_toggle_auto, Color("205944") if g.auto_battle_active else Color("1a3a42"), Vector2(56, 28))
	auto_btn.name = "AutoBattleToggle"
	auto_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(auto_btn)
	var leave_btn := g._button("⌂", _leave_battle, Color("17363e"), Vector2(36,34))
	leave_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(leave_btn); page.add_child(top)
	if g.combat != null and g.combat.state.turn == 1 and not g.combat.state.get("relic_resonances", []).is_empty() and not bool(g.combat.state.get("resonance_toast_shown", false)):
		g.combat.state["resonance_toast_shown"] = true
		var first_res_id: String = str(g.combat.state.relic_resonances[0])
		var first_res: Dictionary = g.content.relic_resonance(first_res_id)
		if not first_res.is_empty():
			g._toast(g.tf("ui.relic_resonance_activated_toast", g._relic_resonance_name(first_res)))

	var enemy_area := Control.new()
	enemy_area.custom_minimum_size = Vector2(366.0, 205.0)
	enemy_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enemy_area.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(enemy_area)

	# A flat row reads fine for one or two enemies, but three or more in a straight line
	# looks like a spreadsheet. Fan them out around the centre instead: the middle slot is
	# "front" (full size, lowest), and slots further from centre step back and up, like a
	# loose wedge formation instead of a queue.
	# Asymmetric RPG battle diagonal: shift formation slightly right (top-right combat orientation).
	var living_indices: Array = []
	for index in g.combat.state.enemies.size():
		if g.combat.state.enemies[index].health > 0: living_indices.append(index)
	var slot_count: int = maxi(1, g.combat.state.enemies.size())
	var u_width: float = minf(112.0, (366.0 - 10.0 * float(slot_count - 1)) / float(slot_count))
	var gap := 10.0
	var living_n := living_indices.size()
	var total_w: float = float(living_n) * u_width + float(maxi(0, living_n - 1)) * gap
	var center_slot: float = float(living_n - 1) / 2.0
	var right_bias := 52.0 if living_n == 1 else (22.0 if living_n == 2 else 0.0)
	var start_x: float = clampf((366.0 - total_w) / 2.0 + right_bias, 0.0, 366.0 - total_w - 6.0)
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
		if g.auto_battle_active:
			_maybe_step_auto_battle()
	else:
		var won: bool = g.combat.state.phase == "won"
		if not won and g.auto_battle_active:
			g.stop_auto_battle("defeat")
		var outcome := g._label(g.t("ui.battle_won") if won else g.t("ui.battle_lost"), 26, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		outcome.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page.add_child(outcome)
		if won:
			# Straight through to the chest. This used to be a button labelled "open chest"
			# that led to a screen with another button labelled "open chest".
			_advance_to_reward()
		else:
			g.play_sfx("battle_defeat")
			var diag: Dictionary = g.diagnose_battle_defeat()
			var diag_card := PanelContainer.new()
			diag_card.name = "DefeatDiagnosisCard"
			diag_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			diag_card.add_theme_stylebox_override("panel", g._panel(Color("101d22"), 14, g.GOLD))
			var diag_pad := MarginContainer.new()
			for s in ["left", "right", "top", "bottom"]: diag_pad.add_theme_constant_override("margin_%s" % s, 12)
			diag_card.add_child(diag_pad)

			var diag_vbox := VBoxContainer.new()
			diag_vbox.add_theme_constant_override("separation", 8)
			diag_pad.add_child(diag_vbox)

			var diag_title := g._label(g.t("ui.defeat_diag_title"), 14, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			diag_vbox.add_child(diag_title)

			var diag_tip := g._label(str(diag.get("tip", "")), 11, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
			diag_vbox.add_child(diag_tip)

			# diagnose_battle_defeat()'s "action" field used to be computed and never read —
			# both buttons rendered identically regardless of which one it actually
			# recommended. Now the recommended one is visually emphasized (gold vs. muted),
			# so the diagnosis actually shows through instead of just picking a tip string.
			var recommended_action: String = str(diag.get("action", "cultivate"))
			var diag_btns := HBoxContainer.new()
			diag_btns.add_theme_constant_override("separation", 8)
			var tune_btn := g._button(g.t("ui.defeat_btn_tune_deck"), func(): _leave_battle(); g.show_deck(), g.GOLD if recommended_action == "deck" else Color("1c333a"), Vector2(0, 38))
			tune_btn.name = "DefeatTuneDeckBtn"
			tune_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			diag_btns.add_child(tune_btn)

			var cult_btn := g._button(g.t("ui.defeat_btn_cultivate"), func(): _leave_battle(); g.show_idle_harvest_modal(), g.GOLD if recommended_action == "cultivate" else Color("1c333a"), Vector2(0, 38))
			cult_btn.name = "DefeatCultivateBtn"
			cult_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			diag_btns.add_child(cult_btn)
			diag_vbox.add_child(diag_btns)

			page.add_child(diag_card)

			var ret_btn := g._button(g.t("ui.return_map"), _leave_battle, g.EMBER, Vector2(0, 46))
			ret_btn.name = "DefeatReturnBtn"
			page.add_child(ret_btn)

func _intent_style(intent: Dictionary) -> Dictionary:
	var kind := str(intent.get("kind", "attack"))
	var amount := int(intent.get("amount", 0))
	# "text" (with its symbol) still goes into toasts, which have no room for a drawn icon;
	# "amount_text" is the plain number the banner shows next to the icon instead.
	match kind:
		"critical":
			return {"text": g.tf("ui.intent_critical", amount), "amount_text": str(amount), "bg": Color(0.42, 0.10, 0.08, 0.72), "border": Color(1.0, 0.60, 0.36, 0.9), "text_color": Color("ffe1c9")}
		"defend":
			return {"text": g.tf("ui.intent_defend", amount), "amount_text": str(amount), "bg": Color(0.06, 0.18, 0.28, 0.72), "border": Color(0.48, 0.80, 1.0, 0.9), "text_color": Color("d6ecff")}
		"empower":
			return {"text": g.tf("ui.intent_empower", amount), "amount_text": "+%d" % amount, "bg": Color(0.22, 0.10, 0.32, 0.72), "border": Color(0.82, 0.58, 1.0, 0.9), "text_color": Color("ecdcff")}
		"curse":
			return {"text": g.tf("ui.intent_curse", amount), "amount_text": str(amount), "bg": Color(0.14, 0.24, 0.10, 0.72), "border": Color(0.68, 0.92, 0.44, 0.9), "text_color": Color("e2f7c6")}
		"attack_defend":
			return {"text": g.tf("ui.intent_attack_defend", [amount, int(intent.get("shield", 0))]), "amount_text": "%d/%d" % [amount, int(intent.get("shield", 0))], "bg": Color(0.28, 0.15, 0.10, 0.72), "border": Color(0.96, 0.70, 0.46, 0.9), "text_color": Color("ffe7d2")}
		_:
			return {"text": g.tf("ui.intent_attack", amount), "amount_text": str(amount), "bg": Color(0.32, 0.10, 0.07, 0.72), "border": Color(0.96, 0.60, 0.38, 0.9), "text_color": Color("ffe1c9")}

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

	if sprite.has_meta("rig_tail"):
		var tail: Node2D = sprite.get_meta("rig_tail") as Node2D
		if tail and is_instance_valid(tail):
			var t_tween := tail.create_tween()
			var base_t_scale: Vector2 = tail.get_meta("base_scale", tail.scale)
			t_tween.tween_property(tail, "rotation_degrees", tail.rotation_degrees + 12.0, duration * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t_tween.parallel().tween_property(tail, "scale", base_t_scale * 1.18, duration * 0.25).set_trans(Tween.TRANS_QUAD)
			t_tween.tween_property(tail, "rotation_degrees", tail.rotation_degrees - 6.0, duration * 0.35).set_trans(Tween.TRANS_QUAD)
			t_tween.parallel().tween_property(tail, "scale", base_t_scale, duration * 0.35).set_trans(Tween.TRANS_QUAD)
			t_tween.tween_property(tail, "rotation_degrees", 0.0, duration * 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	if sprite.has_meta("rig_orb"):
		var orb: Node2D = sprite.get_meta("rig_orb") as Node2D
		if orb and is_instance_valid(orb):
			var o_tween := orb.create_tween()
			var base_o_pos: Vector2 = orb.get_meta("base_pos", orb.position)
			o_tween.tween_property(orb, "position", base_o_pos + Vector2(10.0, -8.0), duration * 0.25).set_trans(Tween.TRANS_QUAD)
			o_tween.tween_property(orb, "position", base_o_pos, duration * 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

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
		if ResourceLoader.exists("res://assets/vfx/spirit_barrier_ring.png"):
			var barrier := Sprite2D.new()
			barrier.name = "SpiritBarrierRing"
			barrier.texture = load("res://assets/vfx/spirit_barrier_ring.png")
			var b_diameter := sprite_radius * 2.6
			var b_scale := b_diameter / 512.0
			barrier.scale = Vector2(b_scale, b_scale)
			barrier.position = sprite_center
			barrier.z_index = 2
			unit.add_child(barrier)
			var b_pulse := barrier.create_tween().set_loops()
			b_pulse.tween_property(barrier, "scale", Vector2(b_scale * 1.05, b_scale * 1.05), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			b_pulse.parallel().tween_property(barrier, "modulate:a", 0.95, 1.4).set_trans(Tween.TRANS_SINE)
			b_pulse.tween_property(barrier, "scale", Vector2(b_scale * 0.96, b_scale * 0.96), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			b_pulse.parallel().tween_property(barrier, "modulate:a", 0.70, 1.4).set_trans(Tween.TRANS_SINE)
			var b_rot := barrier.create_tween().set_loops()
			b_rot.tween_property(barrier, "rotation_degrees", 360.0, 20.0).as_relative()
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
	# Organic breathing: Y bobbing + thoracic squash & stretch
	if weakened:
		idle.tween_property(sprite, "position:y", sprite.position.y - 2.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.parallel().tween_property(sprite, "scale", Vector2(scale_factor * 0.99, scale_factor * 1.015), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.tween_property(sprite, "position:y", sprite.position.y + 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.parallel().tween_property(sprite, "scale", Vector2(scale_factor * 1.01, scale_factor * 0.985), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.parallel().tween_property(sprite, "scale", Vector2(scale_factor * 0.985, scale_factor * 1.025), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle.parallel().tween_property(sprite, "scale", Vector2(scale_factor * 1.015, scale_factor * 0.98), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_apply_status_fx(unit, sprite, sprite.position, spr_size.x / 2.0, enemy)

	# Intent banner: just the drawn icon (already distinct per intent kind — shield for
	# defend, crossed blades for attack, etc.) plus the number it promises. It used to also
	# spell the intent out in a caption line ("Attack"), which was redundant once the icon
	# actually reads on its own, and the extra line pushed the banner tall enough to crowd
	# whatever sits above the enemy row (the equipment/relic badges).
	var intent: Dictionary = enemy.get("intent", {})
	var intent_style := _intent_style(intent)
	var intent_w: float = minf(u_width - 8.0, 72.0)
	var intent_bg := Panel.new()
	intent_bg.name = "IntentBanner"
	intent_bg.custom_minimum_size = Vector2(intent_w, 22.0)
	intent_bg.size = intent_bg.custom_minimum_size
	# Depth-staggered (flanking) enemies have their whole unit shifted up by depth_t*26 for
	# the wedge formation; add that back here so every enemy's banner lands at the same
	# screen height regardless of which row it is in, instead of a back-row banner drifting
	# higher and overlapping the row above the whole enemy area.
	var base_intent_y: float = depth_t * 26.0 + 2.0
	intent_bg.position = Vector2(center_x - intent_w / 2.0, base_intent_y)
	intent_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Floating oriental runic seal: sleek translucent spirit pill with glowing border & soft shadow
	var intent_box := StyleBoxFlat.new()
	intent_box.bg_color = intent_style.bg
	intent_box.border_color = intent_style.border
	intent_box.set_border_width_all(1)
	intent_box.set_corner_radius_all(11)
	intent_box.shadow_color = Color(0, 0, 0, 0.45)
	intent_box.shadow_size = 2
	intent_box.content_margin_left = 6; intent_box.content_margin_right = 6
	intent_bg.add_theme_stylebox_override("panel", intent_box)
	unit.add_child(intent_bg)

	var intent_row := HBoxContainer.new()
	intent_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	intent_row.add_theme_constant_override("separation", 3)
	intent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_bg.add_child(intent_row)
	var icon := IntentIcon.new()
	icon.kind = str(intent.get("kind", "attack"))
	icon.icon_color = intent_style.text_color
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size = icon.custom_minimum_size
	intent_row.add_child(icon)
	intent_row.add_child(g._label(intent_style.amount_text, 13, intent_style.text_color, HORIZONTAL_ALIGNMENT_CENTER))

	var telegraph := intent_bg.create_tween().set_loops()
	telegraph.tween_property(intent_bg, "position:y", base_intent_y - 3.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	telegraph.parallel().tween_property(intent_bg, "modulate", Color(1.22, 1.22, 1.22), 1.0).set_trans(Tween.TRANS_SINE)
	telegraph.tween_property(intent_bg, "position:y", base_intent_y + 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	telegraph.parallel().tween_property(intent_bg, "modulate", Color.WHITE, 1.0).set_trans(Tween.TRANS_SINE)

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

	var player_x := 102.0

	# Mirror of the enemy ring, lit when a card that acts on you is in play.
	var glow := Panel.new()
	glow.name = "PlayerTargetGlow"
	glow.custom_minimum_size = Vector2(160.0, 112.0)
	glow.size = glow.custom_minimum_size
	glow.position = Vector2(player_x - 80.0, 2.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.add_theme_stylebox_override("panel", _target_ring(false))
	glow.visible = false
	stage.add_child(glow)

	# Player Multi-part Rig (Body + Fluffy Ethereal Tail + Floating Foxfire Orb + Ground Aura)
	# — Fox Spirit only, since the rig assets (fox_body/fox_tail/fox_orb/ground_aura) are
	# fox-specific art. Every other hero (and Fox Spirit itself if the rig files are ever
	# missing) falls back to its own real sprite via hero.sprite — this used to be hardcoded
	# to "fox" regardless of which hero was equipped, so Stone Sentinel/Shadow Stalker/
	# Miasma Witch players saw a fox in every battle no matter what they'd actually picked.
	var hero: Dictionary = g.content.hero_class(str(g.profile.hero_class))
	var hero_sprite_key: String = str(hero.get("sprite", "fox"))
	var rig_body_path := "res://assets/characters/fox_rig/fox_body.png"
	var use_fox_rig: bool = (hero_sprite_key == "fox" or hero_sprite_key == "hero_fox_spirit") and ResourceLoader.exists(rig_body_path)

	var sprite := Sprite2D.new()
	sprite.name = "PlayerSprite"
	var spr_size := Vector2(74.0, 74.0)

	if use_fox_rig:
		# 1. Ground Aura (soft jade qi formation under feet)
		var aura := Sprite2D.new()
		aura.name = "PlayerGroundAura"
		aura.texture = load("res://assets/characters/fox_rig/ground_aura.png")
		aura.position = Vector2(player_x, 74.0)
		var aura_base_scale := Vector2(0.18, 0.12)
		aura.scale = aura_base_scale
		aura.z_index = -2
		stage.add_child(aura)
		var aura_tween := aura.create_tween().set_loops()
		aura_tween.tween_property(aura, "scale", aura_base_scale * 1.08, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		aura_tween.parallel().tween_property(aura, "modulate:a", 0.9, 1.2).set_trans(Tween.TRANS_SINE)
		aura_tween.tween_property(aura, "scale", aura_base_scale * 0.94, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		aura_tween.parallel().tween_property(aura, "modulate:a", 0.55, 1.2).set_trans(Tween.TRANS_SINE)

		# 2. Majestic Spirit Fox Tails (Behind body with secondary lag sway)
		var tail := Sprite2D.new()
		tail.name = "PlayerTail"
		tail.texture = load("res://assets/characters/fox_rig/fox_tail.png")
		# Target on-screen size (~94px) computed from the texture's own current width, not a
		# flat scale baked in for one specific source resolution — this broke once already
		# when fox_tail.png was downscaled from 1024px without updating a hardcoded 0.092.
		var tail_scale_val: float = 94.2 / float(tail.texture.get_width())
		var tail_scale := Vector2(tail_scale_val, tail_scale_val)
		tail.scale = tail_scale
		tail.position = Vector2(player_x, 32.0)
		tail.z_index = -1
		tail.set_meta("base_scale", tail_scale)
		stage.add_child(tail)
		sprite.set_meta("rig_tail", tail)

		# Tail secondary swaying + lag bobbing
		var tail_rot := tail.create_tween().set_loops()
		tail_rot.tween_property(tail, "rotation_degrees", 5.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tail_rot.tween_property(tail, "rotation_degrees", -5.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		var tail_bob := tail.create_tween().set_loops()
		tail_bob.tween_property(tail, "position:y", 30.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tail_bob.parallel().tween_property(tail, "scale:x", tail_scale.x * 1.04, 1.2).set_trans(Tween.TRANS_SINE)
		tail_bob.tween_property(tail, "position:y", 34.5, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tail_bob.parallel().tween_property(tail, "scale:x", tail_scale.x * 0.96, 1.2).set_trans(Tween.TRANS_SINE)

		# 3. Main Body Sprite
		sprite.texture = load(rig_body_path)
		# Target on-screen size (80px) from the texture's own current width — see the matching
		# comment on tail_scale_val above for why this can't be a flat constant.
		var scale_factor: float = 80.0 / float(sprite.texture.get_width())
		sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.set_meta("base_scale", scale_factor)
		sprite.position = Vector2(player_x, 38.0)
		_install_hit_flash(sprite)
		stage.add_child(sprite)

		# Primary breathing cycle (vertical bobbing + thoracic squash & stretch)
		var body_tween := sprite.create_tween().set_loops()
		body_tween.tween_property(sprite, "position:y", 34.5, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		body_tween.parallel().tween_property(sprite, "scale", Vector2(scale_factor * 0.985, scale_factor * 1.025), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		body_tween.tween_property(sprite, "position:y", 39.5, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		body_tween.parallel().tween_property(sprite, "scale", Vector2(scale_factor * 1.015, scale_factor * 0.98), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# 4. Floating Foxfire Spirit Flame Orb (Forefront asymmetric Lissajous hover)
		var orb := Sprite2D.new()
		orb.name = "PlayerSpiritOrb"
		orb.texture = load("res://assets/characters/fox_rig/fox_orb.png")
		# Target on-screen size (~39px) from the texture's own current width — see the matching
		# comment on tail_scale_val above.
		var orb_scale_val: float = 38.9 / float(orb.texture.get_width())
		var orb_scale := Vector2(orb_scale_val, orb_scale_val)
		orb.scale = orb_scale
		var base_orb_pos := Vector2(player_x + 36.0, 18.0)
		orb.position = base_orb_pos
		orb.z_index = 1
		orb.set_meta("base_pos", base_orb_pos)
		stage.add_child(orb)
		sprite.set_meta("rig_orb", orb)

		var orb_x := orb.create_tween().set_loops()
		orb_x.tween_property(orb, "position:x", base_orb_pos.x + 5.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		orb_x.tween_property(orb, "position:x", base_orb_pos.x - 5.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		var orb_y := orb.create_tween().set_loops()
		orb_y.tween_property(orb, "position:y", base_orb_pos.y - 6.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		orb_y.tween_property(orb, "position:y", base_orb_pos.y + 4.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		var orb_rot := orb.create_tween().set_loops()
		orb_rot.tween_property(orb, "rotation_degrees", 360.0, 7.0).as_relative()

		var orb_glow := orb.create_tween().set_loops()
		orb_glow.tween_property(orb, "modulate:a", 1.0, 0.85).set_trans(Tween.TRANS_SINE)
		orb_glow.tween_property(orb, "modulate:a", 0.72, 0.85).set_trans(Tween.TRANS_SINE)
	else:
		sprite.texture = g._get_character_texture(hero_sprite_key)
		var tex_w: float = float(sprite.texture.get_width()) if sprite.texture else 341.33
		var tex_h: float = float(sprite.texture.get_height()) if sprite.texture else 341.33
		var scale_factor: float = minf(spr_size.x / tex_w, spr_size.y / tex_h) * 1.08
		sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.set_meta("base_scale", scale_factor)
		sprite.position = Vector2(player_x, 37.0)
		_install_hit_flash(sprite)
		stage.add_child(sprite)

		var idle := sprite.create_tween().set_loops()
		idle.tween_property(sprite, "position:y", sprite.position.y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
		idle.tween_property(sprite, "position:y", sprite.position.y + 2.0, 1.1).set_trans(Tween.TRANS_SINE)

	_apply_status_fx(stage, sprite, sprite.position, spr_size.x / 2.0, g.combat.state.player)

	var max_hp: int = int(g.combat.state.player.get("max_health", 60))
	var hp_bar_w := 148.0
	var hp_bar := g._stat_bar(hp_bar_w, 18.0, int(g.combat.state.player.health), max_hp, g.EMBER, "%s  ♥ %d/%d" % [g.t("ui.spirit_name"), g.combat.state.player.health, max_hp], 10)
	hp_bar.position = Vector2(player_x - hp_bar_w / 2.0, 78.0)
	stage.add_child(hp_bar)

	var incoming: int = g.combat.total_incoming_damage()
	var effective_hp: int = int(g.combat.state.player.health) + int(g.combat.state.player.shield)
	if incoming >= effective_hp and incoming > 0:
		var danger_badge := Panel.new()
		danger_badge.name = "DangerWarningBadge"
		danger_badge.custom_minimum_size = Vector2(96.0, 18.0)
		danger_badge.size = danger_badge.custom_minimum_size
		danger_badge.position = Vector2(player_x - 48.0, 58.0)
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

	# Player side panel for Equipment, Relics & Combat Statuses (arranged vertically in columns of up to 4 items each)
	var side_panel := HBoxContainer.new()
	side_panel.name = "PlayerSidePanel"
	side_panel.position = Vector2(184.0, 10.0)
	side_panel.custom_minimum_size = Vector2(176.0, 104.0)
	side_panel.size = side_panel.custom_minimum_size
	side_panel.add_theme_constant_override("separation", 6)
	side_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.add_child(side_panel)

	var all_items: Array = []
	# 1. Active combat statuses (Shield, Focus, Strength, Burn, Poison, Vulnerable, Weak)
	if int(g.combat.state.player.shield) > 0:
		all_items.append(g._status_chip("⬢", int(g.combat.state.player.shield), Color("9fd8ff"), 20.0))
	if int(g.combat.state.player.focus) > 0:
		all_items.append(g._status_chip("◉", int(g.combat.state.player.focus), Color("ffe08a"), 20.0))
	if int(g.combat.state.player.get("strength", 0)) > 0:
		all_items.append(g._status_chip("★", int(g.combat.state.player.strength), Color("ffd700"), 20.0))
	if int(g.combat.state.player.burn) > 0:
		all_items.append(g._status_chip("▲", int(g.combat.state.player.burn), Color("ff9868"), 20.0))
	if int(g.combat.state.player.get("poison", 0)) > 0:
		all_items.append(g._status_chip("◆", int(g.combat.state.player.poison), Color("a75bd6"), 20.0))
	if int(g.combat.state.player.get("vulnerable", 0)) > 0:
		all_items.append(g._status_chip("▼", int(g.combat.state.player.vulnerable), Color("ff6b6b"), 20.0))
	if int(g.combat.state.player.get("weak", 0)) > 0:
		all_items.append(g._status_chip("●", int(g.combat.state.player.weak), Color("b8c4c8"), 20.0))

	# 2. Stage Modifier, Equipment & Relic Badges
	if not g.active_modifier.is_empty():
		var m_name: String = g.active_modifier.name_en if g.lang == "en" else g.active_modifier.name
		var m_det: String = g.active_modifier.detail_en if g.lang == "en" else g.active_modifier.detail
		var mod_badge := g._icon_badge("✥", Color("ffe2b0"), 26, 13)
		all_items.append(_tap_wrap(mod_badge, func(): _show_info_popup(g._icon_badge("✥", Color("ffe2b0"), 60, 26), m_name, m_det, g.EMBER)))

	for id in g.combat.state.equipment:
		var item := g.content.equipment(id)
		if item.is_empty(): continue
		var e_name: String = g._equip_name(item)
		var e_det: String = g._equip_detail(item)
		var e_badge := g._equip_icon_badge(item, g.GOLD, 26)
		all_items.append(_tap_wrap(e_badge, func(): _show_info_popup(g._equip_icon_badge(item, g.GOLD, 60), e_name, e_det, g.GOLD)))

	for id in g.combat.state.get("relics", g.profile.relics):
		var relic := g.content.relic(id)
		if relic.is_empty(): continue
		var r_color := Color(relic.color)
		var r_name: String = g._relic_name(relic)
		var r_det: String = g._relic_detail(relic)
		var r_badge := g._relic_icon_badge(relic, r_color, 26)
		all_items.append(_tap_wrap(r_badge, func(): _show_info_popup(g._relic_icon_badge(relic, r_color, 60), r_name, r_det, r_color)))

	for res_id in g.combat.state.get("relic_resonances", []):
		var res := g.content.relic_resonance(str(res_id))
		if res.is_empty(): continue
		var res_color := Color(res.color)
		var res_name: String = g._relic_resonance_name(res)
		var res_det: String = g._relic_resonance_detail(res)
		var res_badge := g._relic_resonance_badge(res, res_color, 26)
		all_items.append(_tap_wrap(res_badge, func(): _show_info_popup(g._relic_resonance_badge(res, res_color, 60), res_name, res_det, res_color)))

	# Lay out items vertically in columns of up to 4 items each
	var cur_col: VBoxContainer = null
	for idx in all_items.size():
		if idx % 4 == 0:
			cur_col = VBoxContainer.new()
			cur_col.alignment = BoxContainer.ALIGNMENT_BEGIN
			cur_col.add_theme_constant_override("separation", 5)
			cur_col.mouse_filter = Control.MOUSE_FILTER_PASS
			side_panel.add_child(cur_col)
		cur_col.add_child(all_items[idx])

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
	g.hand_zone = hand_zone

	# show_battle() fully rebuilds the hand from scratch every time (fresh HandCard tiles,
	# not reused ones), so a card that was already in hand looks identical to one just
	# drawn — the only way to tell them apart is by comparing sizes across rebuilds, since
	# _draw_one() (combat.gd) always appends, so the newest cards are always the LAST
	# `new_count` entries. begin_battle() resets _last_hand_size to 0 so the opening deal
	# animates in the same way a mid-battle draw does.
	var count: int = g.combat.state.hand.size()
	var new_count: int = maxi(0, count - g._last_hand_size)
	g._last_hand_size = count
	for index in count:
		var card_tile := _card_view(g.combat.state.hand[index], index, count)
		# _card_view() can come back null if the hand holds an instance whose card_id no
		# longer resolves to real content (e.g. a deck too small to deal a full opening
		# hand) — pre-existing, unrelated to drawing, but the draw-in animation below is a
		# new reason something would actually dereference this result, so it needs the guard.
		if card_tile == null: continue
		hand_zone.add_child(card_tile)
		if index >= count - new_count:
			_animate_card_draw_in(card_tile, index - (count - new_count))

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
	# See the matching comment on game.gd's _modal_dialog(): z_index never affects GUI input
	# dispatch order, only render order — overlay has to be root's LAST child to actually win
	# taps over whatever's in the screen underneath, regardless of its z_index.
	g.root.move_child(g.overlay, g.root.get_child_count() - 1)
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

	var name_text: String = g.content.text(card.nameKey, g.lang) + (" +%d" % up_lvl if up_lvl > 0 else "")
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
	var name_text: String = g.content.text(card.nameKey, g.lang) + (" +%d" % up_lvl if up_lvl > 0 else "")
	var name_lbl := g._label(name_text, 10, Color("f3e8cf"), HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_stack.add_child(name_lbl)

	var kind_lbl := g._label(g._kind_element_line(card), 7, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	kind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_stack.add_child(kind_lbl)

	var desc_lbl := g._label(g._card_description(card), 8, Color("e4ede8"), HORIZONTAL_ALIGNMENT_CENTER, true)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.clip_text = true
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

# Plays as soon as a freshly-drawn tile is added to the hand (see _add_hand()'s new_count
# bookkeeping) — arrives from the draw pile's side of the status row, above and to the left
# of the fan, growing and fading into its resting spot. stagger_index is this card's position
# among just the newly-drawn ones (0-based), so a 2-card turn draw deals them one after another
# instead of both popping in at once.
func _animate_card_draw_in(tile: HandCard, stagger_index: int) -> void:
	g.play_sfx("card_draw", 0.08, -3.0)
	var final_pos: Vector2 = tile.position
	var final_rot: float = tile.rotation
	tile.position = final_pos + Vector2(-26.0, -92.0)
	tile.rotation = 0.0
	tile.scale = Vector2(0.42, 0.42)
	tile.modulate.a = 0.0
	var tw := tile.create_tween()
	tile.current_tween = tw
	tw.tween_interval(g._battle_delay(0.07) * float(stagger_index))
	tw.tween_property(tile, "position", final_pos, g._battle_delay(0.32)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(tile, "rotation", final_rot, g._battle_delay(0.32))
	tw.parallel().tween_property(tile, "scale", Vector2.ONE, g._battle_delay(0.28))
	tw.parallel().tween_property(tile, "modulate:a", 1.0, g._battle_delay(0.2))

# Fired the instant a card is played (see _resolve_play()), while its tile is still the one
# left over from the hand's last render — show_battle() at the end of that same resolve
# sequence is what actually removes it, so without this it would otherwise just sit there
# unchanged until it vanishes. Flies up toward the discard chip's side of the status row,
# shrinking and spinning away, so "played" reads as "gone to the discard pile" rather than a
# card simply blinking out of existence.
func _animate_card_to_discard(hand_index: int) -> void:
	if g.hand_zone == null or not is_instance_valid(g.hand_zone): return
	var tile: HandCard = null
	for child in g.hand_zone.get_children():
		if child is HandCard and int((child as HandCard).hand_index) == hand_index:
			tile = child as HandCard
			break
	if tile == null or not is_instance_valid(tile): return
	if tile.current_tween: tile.current_tween.kill()
	tile.z_index = 90
	var tw := tile.create_tween()
	tile.current_tween = tw
	tw.tween_property(tile, "position", tile.position + Vector2(96.0, -140.0), g._battle_delay(0.34)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tile, "rotation", tile.rotation + deg_to_rad(30.0), g._battle_delay(0.34))
	tw.parallel().tween_property(tile, "scale", Vector2(0.3, 0.3), g._battle_delay(0.34))
	tw.parallel().tween_property(tile, "modulate:a", 0.0, g._battle_delay(0.26))

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

	stack.add_child(g._label(g.content.text(card.nameKey, g.lang) + (" +%d" % up_lvl if up_lvl > 0 else ""), 12, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
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
	var card_id: String = str(g.combat.state.hand[hand_index].card_id) if hand_index < g.combat.state.hand.size() else ""
	var card: Dictionary = g.content.card(card_id)
	var before: Array = []
	for enemy in g.combat.state.enemies: before.append(int(enemy.health))
	var player_shield_before: int = int(g.combat.state.player.shield)
	var player_health_before: int = int(g.combat.state.player.health)
	var player_focus_before: int = int(g.combat.state.player.get("focus", 0))
	var player_strength_before: int = int(g.combat.state.player.get("strength", 0))
	if not g.combat.play(hand_index, target):
		g._toast(g.t("ui.target_invalid"))
		return false
	g.play_sfx("card_play")
	g.selected_card = -1
	g.resolving = true
	_resolve_play(hand_index, before, player_shield_before, player_health_before, player_focus_before, player_strength_before, card)
	return true

func _resolve_play(hand_index: int, before: Array, player_shield_before: int = 0, player_health_before: int = 0, player_focus_before: int = 0, player_strength_before: int = 0, card: Dictionary = {}) -> void:
	# Captured before any await below, so a battle_session bump from _leave_battle() (a loss or
	# a manual retreat reached while this coroutine is still mid-animation) or begin_battle() (a
	# new battle already started) can be told apart from "still the same battle" once this
	# resumes — see the guard right before show_battle() and battle_session's own comment in
	# game.gd for what this prevents.
	var session: int = g.battle_session

	# 0. The just-played card flies off to the discard pile — fire-and-forget, so it plays
	# out alongside everything below rather than delaying it.
	_animate_card_to_discard(hand_index)

	# 0.5. Hero Signature Action Animation (lunge charge / weapon swing / shadow dash / staff wave)
	if not card.is_empty():
		await _animate_player_action(card)

	# 1. Shield Gain Animation (Spirit Aegis Crest -> Character -> Barrier Ring)
	var player_shield_after: int = int(g.combat.state.player.shield)
	var shield_gained: int = player_shield_after - player_shield_before
	if shield_gained > 0:
		await _animate_player_shield_gain(shield_gained)

	# 2. Heal Animation (Jade Celestial Lotus)
	var player_health_after: int = int(g.combat.state.player.health)
	var health_gained: int = player_health_after - player_health_before
	if health_gained > 0:
		await _animate_player_heal(health_gained)

	# 3. Focus / Strength Buff Animation (Ascending Golden Qi Pillar)
	var focus_gained: int = int(g.combat.state.player.get("focus", 0)) - player_focus_before
	var strength_gained: int = int(g.combat.state.player.get("strength", 0)) - player_strength_before
	if focus_gained > 0:
		var focus_text: String = "+%d %s" % [focus_gained, g.t("desc.focus") if g.lang == "zh-Hans" else "Focus"]
		await _animate_player_buff(focus_text)
	elif strength_gained > 0:
		var str_text: String = "+%d %s" % [strength_gained, g.t("desc.strength") if g.lang == "zh-Hans" else "Strength"]
		await _animate_player_buff(str_text)

	# 4. Attack Slashes & Hits on Enemies (Curved Blade Arc / Beast Claws)
	var card_id: String = str(card.get("id", ""))
	for i in g.combat.state.enemies.size():
		if i < before.size() and before[i] > g.combat.state.enemies[i].health:
			_animate_attack_slash(i, card_id)
			await g.get_tree().create_timer(g._battle_delay(0.14)).timeout
			await _animate_enemy_hit(i, before[i] - g.combat.state.enemies[i].health, g.combat.state.enemies[i].health <= 0)
			await g.get_tree().create_timer(g._battle_delay(0.20)).timeout

	await g.get_tree().create_timer(g._battle_delay(0.25)).timeout
	# The battle this coroutine was resolving a card for is gone (a loss, a manual retreat, or
	# a new battle already started while we were mid-animation) — show_battle() unconditionally
	# wipes whatever screen is current, so calling it here would redraw this abandoned battle
	# over the player's new location. _leave_battle()/begin_battle() already reset g.resolving
	# themselves, so there is nothing left for this stale call to finish.
	if g.battle_session != session: return
	show_battle()
	await _maybe_end_turn()
	g.resolving = false
	# Auto-Battle's real re-trigger point. show_battle()'s own internal check (its
	# "if g.auto_battle_active: _maybe_step_auto_battle()" branch) fires from *inside* this
	# same _resolve_play() call (via the show_battle() call two lines up, and again from
	# within _maybe_end_turn()'s _enemy_turn() when a turn ends) — at both of those points
	# g.resolving is still true, so _maybe_step_auto_battle()'s own guard clause always bails
	# immediately. Nothing else ever called it again afterward, so auto-battle only ever
	# played the one card kicked off from begin_battle()'s initial call (made before resolving
	# is ever set true). This line is the fix: only once resolving is actually false again —
	# meaning the previous card's animation and any resulting turn-end/enemy-turn have fully
	# settled — do we check whether to play the next card. The combat/phase checks are
	# redundant with _maybe_step_auto_battle()'s own guard clause but cheap and explicit about
	# why this call site in particular needs them: this fires after a battle-ending animation,
	# so combat may already be null or past the player's turn by the time this line runs.
	if g.auto_battle_active and g.combat != null and g.combat.state.phase == "player":
		_maybe_step_auto_battle()

func _animate_player_action(card: Dictionary) -> void:
	if g.overlay == null or g.get_tree() == null: return
	var player_sprite: Node2D = g.root.find_child("PlayerSprite", true, false) as Node2D
	if player_sprite == null or not is_instance_valid(player_sprite): return

	var hero_id: String = str(g.profile.hero_class)
	var kind: String = str(card.get("kind", "Skill"))
	var origin: Vector2 = player_sprite.position
	var base_scale: float = float(player_sprite.get_meta("base_scale", 1.0))
	var dur: float = g._battle_delay(0.68)
	var tween := player_sprite.create_tween()

	if kind == "Attack":
		match hero_id:
			"fox_spirit":
				# Step forward, tail fan-out, and spirit orb missile strike!
				tween.tween_property(player_sprite, "position:x", origin.x + 38.0, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 8.0, dur * 0.35)
				var tail: Node2D = player_sprite.get_meta("rig_tail", null) as Node2D
				if tail and is_instance_valid(tail):
					var tail_tween := tail.create_tween()
					tail_tween.tween_property(tail, "rotation_degrees", 26.0, dur * 0.35).set_trans(Tween.TRANS_QUAD)
					tail_tween.tween_interval(dur * 0.16)
					tail_tween.tween_property(tail, "rotation_degrees", 0.0, dur * 0.49).set_trans(Tween.TRANS_ELASTIC)
				var orb: Node2D = player_sprite.get_meta("rig_orb", null) as Node2D
				if orb and is_instance_valid(orb):
					var orb_base: Vector2 = orb.get_meta("base_pos", orb.position)
					var orb_tween := orb.create_tween()
					orb_tween.tween_property(orb, "position", Vector2(orb_base.x + 105.0, orb_base.y - 10.0), dur * 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
					orb_tween.parallel().tween_property(orb, "modulate", Color(2.4, 1.8, 1.0), dur * 0.35)
					orb_tween.parallel().tween_property(orb, "rotation_degrees", orb.rotation_degrees + 180.0, dur * 0.35)
					# Apex hold for visible impact
					orb_tween.tween_interval(dur * 0.16)
					orb_tween.tween_property(orb, "position", orb_base, dur * 0.49).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					orb_tween.parallel().tween_property(orb, "modulate", Color.WHITE, dur * 0.49)
				# Hero strike apex hold
				tween.tween_interval(dur * 0.16)
				tween.tween_property(player_sprite, "position", origin, dur * 0.49).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 0.0, dur * 0.49)
			"stone_sentinel":
				# Heavy ancient shield/hammer charge & ground stomp
				tween.tween_property(player_sprite, "position:x", origin.x - 16.0, dur * 0.32).set_trans(Tween.TRANS_QUAD)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", -12.0, dur * 0.32)
				tween.parallel().tween_property(player_sprite, "scale", Vector2(base_scale * 1.10, base_scale * 0.90), dur * 0.32)
				tween.tween_property(player_sprite, "position:x", origin.x + 52.0, dur * 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 16.0, dur * 0.24)
				tween.parallel().tween_property(player_sprite, "scale", Vector2(base_scale * 0.90, base_scale * 1.18), dur * 0.24)
				tween.tween_callback(func():
					_shake_screen(3.8)
					g._haptic("heavy"))
				# Impact hold
				tween.tween_interval(dur * 0.16)
				tween.tween_property(player_sprite, "position", origin, dur * 0.44).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 0.0, dur * 0.44)
				tween.parallel().tween_property(player_sprite, "scale", Vector2.ONE * base_scale, dur * 0.44)
			"shadow_stalker":
				# Shadow Dash: phase forward, strike with twin shadow blades, shadow-step back!
				tween.tween_property(player_sprite, "modulate:a", 0.30, dur * 0.26)
				tween.parallel().tween_property(player_sprite, "position:x", origin.x + 65.0, dur * 0.26).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 14.0, dur * 0.26)
				tween.tween_callback(func(): g._haptic("tap"))
				# Apex strike hold
				tween.tween_interval(dur * 0.18)
				tween.tween_property(player_sprite, "modulate:a", 1.0, dur * 0.40)
				tween.parallel().tween_property(player_sprite, "position", origin, dur * 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 0.0, dur * 0.40)
			"miasma_witch":
				# Staff sweep & emerald poison surge!
				tween.tween_property(player_sprite, "rotation_degrees", -20.0, dur * 0.32).set_trans(Tween.TRANS_SINE)
				tween.parallel().tween_property(player_sprite, "modulate", Color(0.9, 1.8, 1.1), dur * 0.32)
				tween.tween_property(player_sprite, "position:x", origin.x + 38.0, dur * 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 22.0, dur * 0.26)
				tween.parallel().tween_property(player_sprite, "modulate", Color(1.3, 2.6, 1.5), dur * 0.26)
				# Mist dispersion hold
				tween.tween_interval(dur * 0.16)
				tween.tween_property(player_sprite, "position", origin, dur * 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 0.0, dur * 0.42)
				tween.parallel().tween_property(player_sprite, "modulate", Color.WHITE, dur * 0.42)
			_:
				tween.tween_property(player_sprite, "position:x", origin.x + 38.0, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 8.0, dur * 0.35)
				tween.tween_interval(dur * 0.16)
				tween.tween_property(player_sprite, "position", origin, dur * 0.49).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(player_sprite, "rotation_degrees", 0.0, dur * 0.49)
	else:
		# Non-attack cards (Defend / Skill / Power)
		var cid: String = str(card.get("id", ""))
		var is_defense := cid.contains("ward") or cid.contains("hide") or cid.contains("barrier") or cid.contains("guard")
		if is_defense:
			# Defensive turtle squash & barrier pulse
			tween.tween_property(player_sprite, "position:x", origin.x - 12.0, dur * 0.35).set_trans(Tween.TRANS_QUAD)
			tween.parallel().tween_property(player_sprite, "scale", Vector2(base_scale * 1.18, base_scale * 0.86), dur * 0.35)
			tween.parallel().tween_property(player_sprite, "modulate", Color(1.2, 1.8, 2.4), dur * 0.35)
			tween.tween_interval(dur * 0.18)
			tween.tween_property(player_sprite, "position", origin, dur * 0.47).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(player_sprite, "scale", Vector2.ONE * base_scale, dur * 0.47)
			tween.parallel().tween_property(player_sprite, "modulate", Color.WHITE, dur * 0.47)
		else:
			# Levitate & energy surge
			tween.tween_property(player_sprite, "position:y", origin.y - 20.0, dur * 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(player_sprite, "scale", Vector2(base_scale * 0.92, base_scale * 1.18), dur * 0.38)
			tween.parallel().tween_property(player_sprite, "modulate", Color(1.8, 1.5, 2.2), dur * 0.38)
			tween.tween_interval(dur * 0.18)
			tween.tween_property(player_sprite, "position", origin, dur * 0.44).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.parallel().tween_property(player_sprite, "scale", Vector2.ONE * base_scale, dur * 0.44)
			tween.parallel().tween_property(player_sprite, "modulate", Color.WHITE, dur * 0.44)

	await tween.finished
	player_sprite.position = origin
	player_sprite.scale = Vector2.ONE * base_scale
	player_sprite.rotation_degrees = 0.0
	player_sprite.modulate = Color.WHITE

func _animate_attack_slash(enemy_index: int, card_id: String) -> void:
	g.play_sfx("attack_slash")
	if g.overlay == null or g.get_tree() == null: return
	var box: Control = null
	for candidate in g.enemy_boxes:
		if candidate and is_instance_valid(candidate) and int(candidate.get_meta("enemy_index")) == enemy_index:
			box = candidate
			break
	if box == null: return

	var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
	# Hit point: target MonsterSprite chest directly
	var enemy_pos: Vector2 = sprite.global_position if (sprite and is_instance_valid(sprite)) else (box.global_position + Vector2(box.size.x / 2.0, 66.0))
	var is_claw: bool = card_id.contains("claw") or card_id.contains("ember") or card_id.contains("wild")
	var vfx_path := "res://assets/vfx/spirit_claw_scratch.png" if is_claw else "res://assets/vfx/spirit_slash_arc.png"
	if not ResourceLoader.exists(vfx_path): return

	var slash := Sprite2D.new()
	slash.name = "AnimSlashVFX"
	slash.texture = load(vfx_path)
	var start_offset := Vector2(-28.0, -22.0)
	var end_offset := Vector2(22.0, 16.0)
	slash.position = enemy_pos + start_offset
	slash.z_index = 380
	slash.scale = Vector2(0.06, 0.06)
	slash.rotation_degrees = -32.0 if not is_claw else -15.0
	slash.modulate = Color(2.0, 1.7, 1.2, 1.0) if not is_claw else Color(2.2, 0.8, 0.3, 1.0)
	g.overlay.add_child(slash)

	var dur_slash: float = g._battle_delay(0.55)
	var tween := slash.create_tween().set_parallel(true)
	var target_scale := 0.36 if is_claw else 0.32
	tween.tween_property(slash, "position", enemy_pos + end_offset, dur_slash).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(slash, "scale", Vector2(target_scale, target_scale), dur_slash).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slash, "rotation_degrees", slash.rotation_degrees + (24.0 if is_claw else 32.0), dur_slash)
	tween.tween_property(slash, "modulate:a", 0.0, dur_slash * 0.45).set_delay(dur_slash * 0.55)

	# Radial hit spark burst at chest impact
	if ResourceLoader.exists("res://assets/vfx/spirit_slash_arc.png"):
		var burst := Sprite2D.new()
		burst.name = "AnimHitBurst"
		burst.texture = load("res://assets/vfx/spirit_slash_arc.png")
		burst.position = enemy_pos
		burst.z_index = 385
		burst.scale = Vector2(0.04, 0.04)
		burst.rotation_degrees = 45.0
		burst.modulate = Color(2.5, 2.2, 1.5, 0.95)
		g.overlay.add_child(burst)
		var b_tween := burst.create_tween().set_parallel(true)
		b_tween.tween_property(burst, "scale", Vector2(0.22, 0.22), dur_slash * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		b_tween.tween_property(burst, "modulate:a", 0.0, dur_slash * 0.45).set_delay(dur_slash * 0.35)
		b_tween.chain().tween_callback(burst.queue_free)

	await tween.finished
	slash.queue_free()

func _animate_player_heal(amount: int) -> void:
	g.play_sfx("heal")
	if g.overlay == null or g.get_tree() == null: return
	var player_node: Sprite2D = g.get_tree().root.find_child("PlayerSprite", true, false) as Sprite2D
	if player_node == null or not is_instance_valid(player_node): return

	var target_pos: Vector2 = player_node.global_position
	g._haptic("light")

	if ResourceLoader.exists("res://assets/vfx/spirit_heal_lotus.png"):
		var lotus := Sprite2D.new()
		lotus.name = "AnimHealLotus"
		lotus.texture = load("res://assets/vfx/spirit_heal_lotus.png")
		lotus.position = target_pos
		lotus.scale = Vector2(0.02, 0.02)
		lotus.z_index = 360
		lotus.modulate = Color(1.2, 1.6, 1.3, 0.9)
		g.overlay.add_child(lotus)

		var dur: float = g._battle_delay(0.60)
		var tween := lotus.create_tween().set_parallel(true)
		tween.tween_property(lotus, "scale", Vector2(0.18, 0.18), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(lotus, "rotation_degrees", 75.0, dur)
		tween.tween_property(lotus, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
		tween.chain().tween_callback(lotus.queue_free)

	_flash_hit(player_node, Color("80ffc0"))
	var base_scale: float = float(player_node.get_meta("base_scale", 1.0))
	var swell := player_node.create_tween()
	swell.tween_property(player_node, "scale", Vector2(base_scale * 1.10, base_scale * 1.10), g._battle_delay(0.20)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swell.tween_property(player_node, "scale", Vector2.ONE * base_scale, g._battle_delay(0.28)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var popup := g._label("+%d ♥" % amount, 36, Color("80ffb0"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = target_pos - Vector2(60, 40)
	popup.size = Vector2(120, 40)
	popup.z_index = 380
	popup.scale = Vector2(0.4, 0.4)
	popup.pivot_offset = Vector2(60, 20)
	popup.add_theme_color_override("font_outline_color", Color(0.02, 0.14, 0.05, 0.95))
	popup.add_theme_constant_override("outline_size", 6)
	g.overlay.add_child(popup)
	var pop_punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_punch.tween_property(popup, "scale", Vector2(1.30, 1.30), g._battle_delay(0.16))
	pop_punch.tween_property(popup, "scale", Vector2(1.10, 1.10), g._battle_delay(0.10))
	var pop_fade := popup.create_tween()
	pop_fade.tween_interval(g._battle_delay(0.50))
	pop_fade.tween_property(popup, "position:y", target_pos.y - 65.0, g._battle_delay(0.45)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop_fade.parallel().tween_property(popup, "modulate:a", 0.0, g._battle_delay(0.45))
	pop_fade.tween_callback(popup.queue_free)
	await g.get_tree().create_timer(g._battle_delay(0.50)).timeout

func _animate_player_buff(text: String) -> void:
	g.play_sfx("buff")
	if g.overlay == null or g.get_tree() == null: return
	var player_node: Sprite2D = g.get_tree().root.find_child("PlayerSprite", true, false) as Sprite2D
	if player_node == null or not is_instance_valid(player_node): return

	var target_pos: Vector2 = player_node.global_position
	g._haptic("light")

	if ResourceLoader.exists("res://assets/vfx/spirit_buff_pillar.png"):
		var pillar := Sprite2D.new()
		pillar.name = "AnimBuffPillar"
		pillar.texture = load("res://assets/vfx/spirit_buff_pillar.png")
		pillar.position = target_pos + Vector2(0, -10)
		pillar.scale = Vector2(0.04, 0.01)
		pillar.z_index = 360
		pillar.modulate = Color(1.5, 1.3, 0.8, 0.95)
		g.overlay.add_child(pillar)

		var dur: float = g._battle_delay(0.65)
		var tween := pillar.create_tween().set_parallel(true)
		tween.tween_property(pillar, "scale", Vector2(0.15, 0.24), dur * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(pillar, "position:y", target_pos.y - 50.0, dur)
		tween.tween_property(pillar, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
		tween.chain().tween_callback(pillar.queue_free)

	_flash_hit(player_node, Color("ffe066"))
	var base_scale: float = float(player_node.get_meta("base_scale", 1.0))
	var swell := player_node.create_tween()
	swell.tween_property(player_node, "scale", Vector2(base_scale * 1.14, base_scale * 1.14), g._battle_delay(0.22)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swell.tween_property(player_node, "scale", Vector2.ONE * base_scale, g._battle_delay(0.30)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var popup := g._label(text, 32, Color("ffe066"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = target_pos - Vector2(70, 40)
	popup.size = Vector2(140, 40)
	popup.z_index = 380
	popup.scale = Vector2(0.4, 0.4)
	popup.pivot_offset = Vector2(70, 20)
	popup.add_theme_color_override("font_outline_color", Color(0.16, 0.12, 0.02, 0.95))
	popup.add_theme_constant_override("outline_size", 6)
	g.overlay.add_child(popup)
	var pop_punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_punch.tween_property(popup, "scale", Vector2(1.25, 1.25), g._battle_delay(0.16))
	pop_punch.tween_property(popup, "scale", Vector2(1.05, 1.05), g._battle_delay(0.10))
	var pop_fade := popup.create_tween()
	pop_fade.tween_interval(g._battle_delay(0.50))
	pop_fade.tween_property(popup, "position:y", target_pos.y - 65.0, g._battle_delay(0.45)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop_fade.parallel().tween_property(popup, "modulate:a", 0.0, g._battle_delay(0.45))
	pop_fade.tween_callback(popup.queue_free)
	await g.get_tree().create_timer(g._battle_delay(0.50)).timeout

# Plays when an enemy's "curse" intent actually resolves (combat.gd's _execute_intent,
# reached via _enemy_turn()'s end_turn() call) — a sigil settling onto the player to mark the
# burn+discard-poisoning curse.gd just applied. spirit_curse_seal.png shipped with this
# session's VFX batch but was never wired to anything; the curse cards it depicts
# (decay_blight/void_curse) and the enemy curse intent that deals them out had no visual
# treatment before this.
func _animate_player_curse() -> void:
	if g.overlay == null or g.get_tree() == null: return
	var player_node: Sprite2D = g.get_tree().root.find_child("PlayerSprite", true, false) as Sprite2D
	if player_node == null or not is_instance_valid(player_node): return

	var target_pos: Vector2 = player_node.global_position
	g._haptic("light")

	if ResourceLoader.exists("res://assets/vfx/spirit_curse_seal.png"):
		var seal := Sprite2D.new()
		seal.name = "AnimCurseSeal"
		seal.texture = load("res://assets/vfx/spirit_curse_seal.png")
		seal.position = target_pos
		seal.rotation_degrees = -20.0
		seal.scale = Vector2(0.02, 0.02)
		seal.z_index = 360
		seal.modulate = Color(0.72, 1.0, 0.5, 0.0)
		g.overlay.add_child(seal)

		var dur: float = g._battle_delay(0.85)
		var tween := seal.create_tween().set_parallel(true)
		tween.tween_property(seal, "scale", Vector2(0.15, 0.15), dur * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(seal, "modulate:a", 0.92, dur * 0.35)
		tween.tween_property(seal, "rotation_degrees", 25.0, dur).set_trans(Tween.TRANS_SINE)
		tween.tween_property(seal, "modulate:a", 0.0, dur * 0.35).set_delay(dur * 0.55)
		tween.chain().tween_callback(seal.queue_free)

	_flash_hit(player_node, Color("9fe066"))
	await g.get_tree().create_timer(g._battle_delay(0.40)).timeout

func _animate_player_shield_gain(amount: int) -> void:
	g.play_sfx("shield_gain")
	if g.overlay == null or g.get_tree() == null: return
	var player_node: Sprite2D = g.get_tree().root.find_child("PlayerSprite", true, false) as Sprite2D
	if player_node == null or not is_instance_valid(player_node): return

	var target_pos: Vector2 = player_node.global_position
	var origin_pos := Vector2(target_pos.x, target_pos.y + 220.0)

	g._haptic("light")

	# Step 1: 护甲展开 (Spirit Aegis Crest Manifests & Expands Open)
	var crest := Sprite2D.new()
	crest.name = "AnimShieldCrest"
	if ResourceLoader.exists("res://assets/vfx/spirit_shield_crest.png"):
		crest.texture = load("res://assets/vfx/spirit_shield_crest.png")
	crest.position = origin_pos
	var crest_tex_w: float = float(crest.texture.get_width()) if crest.texture else 1024.0
	var crest_scale_fix: float = 1024.0 / crest_tex_w
	crest.scale = Vector2(0.01, 0.01) * crest_scale_fix
	crest.modulate = Color(1.3, 1.3, 1.5, 0.0)
	crest.z_index = 350
	g.overlay.add_child(crest)

	var dur_open: float = g._battle_delay(0.42)
	var unfold := crest.create_tween().set_parallel(true)
	unfold.tween_property(crest, "scale", Vector2(0.09, 0.09) * crest_scale_fix, dur_open).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unfold.tween_property(crest, "modulate:a", 1.0, dur_open * 0.7)
	unfold.tween_property(crest, "rotation_degrees", -6.0, dur_open)
	await unfold.finished

	await g.get_tree().create_timer(g._battle_delay(0.12)).timeout
	if not is_instance_valid(crest): return

	# Step 2: 护甲加到人物 (Streaks to Character and Snaps onto Chest)
	var dur_fly: float = g._battle_delay(0.42)
	var fly := crest.create_tween().set_parallel(true)
	fly.tween_property(crest, "position", target_pos, dur_fly).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(crest, "rotation_degrees", 0.0, dur_fly)
	fly.tween_property(crest, "scale", Vector2(0.068, 0.068) * crest_scale_fix, dur_fly)
	await fly.finished

	# Impact snap onto player
	if not is_instance_valid(player_node): return
	_flash_hit(player_node, Color("9fd8ff"))
	var base_scale: float = float(player_node.get_meta("base_scale", 1.0))
	var swell := player_node.create_tween()
	swell.tween_property(player_node, "scale", Vector2(base_scale * 1.10, base_scale * 1.10), g._battle_delay(0.20)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swell.tween_property(player_node, "scale", Vector2.ONE * base_scale, g._battle_delay(0.28)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	g._haptic("impact")

	# Floating shield text popup: "+X 🛡"
	var popup := g._label("+%d 🛡" % amount, 36, Color("9fd8ff"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = target_pos - Vector2(60, 40)
	popup.size = Vector2(120, 40)
	popup.z_index = 380
	popup.scale = Vector2(0.4, 0.4)
	popup.pivot_offset = Vector2(60, 20)
	popup.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 0.95))
	popup.add_theme_constant_override("outline_size", 6)
	g.overlay.add_child(popup)
	var pop_punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_punch.tween_property(popup, "scale", Vector2(1.30, 1.30), g._battle_delay(0.16))
	pop_punch.tween_property(popup, "scale", Vector2(1.10, 1.10), g._battle_delay(0.10))
	var pop_fade := popup.create_tween()
	pop_fade.tween_interval(g._battle_delay(0.50))
	pop_fade.tween_property(popup, "position:y", target_pos.y - 65.0, g._battle_delay(0.45)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop_fade.parallel().tween_property(popup, "modulate:a", 0.0, g._battle_delay(0.45))
	pop_fade.tween_callback(popup.queue_free)

	var fade_crest := crest.create_tween()
	fade_crest.tween_property(crest, "scale", Vector2(0.095, 0.095) * crest_scale_fix, g._battle_delay(0.15))
	fade_crest.parallel().tween_property(crest, "modulate:a", 0.0, g._battle_delay(0.15))
	fade_crest.tween_callback(crest.queue_free)

	# Step 3: 灵光结界圈展开保护住人物 (Protective Barrier Ring Bursts Outward Encircling Character)
	var ring := Sprite2D.new()
	ring.name = "AnimBarrierDeploy"
	if ResourceLoader.exists("res://assets/vfx/spirit_barrier_ring.png"):
		ring.texture = load("res://assets/vfx/spirit_barrier_ring.png")
	ring.position = target_pos
	ring.z_index = 360
	ring.scale = Vector2(0.02, 0.02)
	ring.modulate = Color(1.3, 1.3, 1.6, 0.95)
	g.overlay.add_child(ring)

	var dur_deploy: float = g._battle_delay(0.28)
	var final_scale: float = 90.0 / 512.0
	var ring_deploy := ring.create_tween().set_parallel(true)
	ring_deploy.tween_property(ring, "scale", Vector2(final_scale * 1.3, final_scale * 1.3), dur_deploy).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ring_deploy.tween_property(ring, "rotation_degrees", 45.0, dur_deploy)
	await ring_deploy.finished

	var dur_settle: float = g._battle_delay(0.18)
	var ring_settle := ring.create_tween().set_parallel(true)
	ring_settle.tween_property(ring, "scale", Vector2(final_scale, final_scale), dur_settle).set_trans(Tween.TRANS_SINE)
	ring_settle.tween_property(ring, "modulate:a", 0.0, dur_settle)
	await ring_settle.finished
	ring.queue_free()

# There is no End Turn button, so the turn has to hand itself over once nothing in hand is
# affordable any more (either the hand is empty or every card costs more than remaining energy).
func _maybe_end_turn() -> void:
	var guard := 0
	while g.combat != null and g.combat.state.phase == "player" and guard < 12:
		guard += 1
		if _has_playable_card(): return
		if g.combat.state.hand.size() > 0: g._toast(g.t("ui.no_playable"))
		await g.get_tree().create_timer(g._battle_delay(0.65)).timeout
		if g.combat == null or g.combat.state.phase != "player": return
		await _enemy_turn()

func _maybe_step_auto_battle() -> void:
	if not g.auto_battle_active or g.combat == null or g.combat.state.phase != "player" or g.resolving or auto_stepping:
		return
	auto_stepping = true
	await g.get_tree().create_timer(g._battle_delay(0.20)).timeout
	auto_stepping = false
	if not g.auto_battle_active or g.combat == null or g.combat.state.phase != "player" or g.resolving:
		return
	var decision: Dictionary = g.combat.ai_best_play()
	var hand_idx: int = int(decision.get("hand_index", -1))
	var target_idx: int = int(decision.get("target_index", -1))
	if hand_idx >= 0:
		var played: bool = _attempt_play_card(hand_idx, target_idx)
		if not played:
			await _maybe_end_turn()
			if g.auto_battle_active and g.combat != null and g.combat.state.phase == "player" and not g.resolving:
				_maybe_step_auto_battle()
	else:
		await _maybe_end_turn()
		if g.auto_battle_active and g.combat != null and g.combat.state.phase == "player" and not g.resolving:
			_maybe_step_auto_battle()

func _animate_enemy_hit(enemy_index: int, amount: int, defeated: bool) -> void:
	if defeated:
		g.play_sfx("enemy_defeat")
	elif amount >= 15:
		g.play_sfx("attack_heavy")
	else:
		g.play_sfx("enemy_hit")
	var box: Control = null
	for candidate in g.enemy_boxes:
		if candidate and is_instance_valid(candidate) and int(candidate.get_meta("enemy_index")) == enemy_index:
			box = candidate
			break
	if box == null: return

	var popup := g._label("−%d" % amount, 38 if not defeated else 44, Color("ff4d3d") if defeated else Color("fff6cf"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = box.global_position + Vector2(box.size.x / 2.0 - 50.0, 26.0)
	popup.size = Vector2(100, 44)
	popup.z_index = 380
	popup.pivot_offset = Vector2(50, 22)
	popup.scale = Vector2(0.4, 0.4)
	popup.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.95))
	popup.add_theme_constant_override("outline_size", 6)
	g.overlay.add_child(popup)

	var punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(popup, "scale", Vector2(1.35, 1.35), g._battle_delay(0.16))
	punch.tween_property(popup, "scale", Vector2(1.10, 1.10), g._battle_delay(0.10))

	g._haptic("heavy" if defeated else "hit")
	_shake_screen(10.0 if defeated else clampf(float(amount) * 0.55, 3.5, 8.5))

	var sprite: Node2D = box.get_node_or_null("MonsterSprite") as Node2D
	if sprite:
		# Initial white hit-stop flash on impact, then red damage tint
		_flash_hit(sprite, Color(2.5, 2.5, 2.5), g._battle_delay(0.12))
		# Powerful knockback recoil along attack diagonal (towards top-right)
		var orig_pos: Vector2 = sprite.position
		var base_scale: float = float(sprite.get_meta("base_scale", 1.0))
		var kb_offset := Vector2(18.0, -10.0) if not defeated else Vector2(28.0, -16.0)
		var kb_dur: float = g._battle_delay(0.42 if defeated else 0.34)

		var kb_tween := sprite.create_tween()
		kb_tween.tween_property(sprite, "position", orig_pos + kb_offset, kb_dur * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		kb_tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.18, base_scale * 0.82), kb_dur * 0.28).set_trans(Tween.TRANS_QUAD)
		kb_tween.tween_interval(kb_dur * 0.12)
		kb_tween.tween_property(sprite, "position", orig_pos, kb_dur * 0.60).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		kb_tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, kb_dur * 0.60).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var float_tw := popup.create_tween()
	# Keep fully visible at 1.1 scale for comfortable reading!
	float_tw.tween_interval(g._battle_delay(0.50))
	# Then float up and fade out smoothly
	float_tw.tween_property(popup, "position:y", popup.position.y - 42.0, g._battle_delay(0.45)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	float_tw.parallel().tween_property(popup, "modulate:a", 0.0, g._battle_delay(0.45))

	if defeated:
		var def_tw := box.create_tween().set_parallel(true)
		def_tw.tween_interval(g._battle_delay(0.20))
		def_tw.chain().tween_property(box, "modulate:a", 0.0, g._battle_delay(0.45))
		def_tw.parallel().tween_property(box, "scale", Vector2(0.4, 0.4), g._battle_delay(0.45))

	await float_tw.finished
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
	await g.get_tree().create_timer(g._battle_delay(0.70)).timeout
	# This whole function is awaited all the way from _resolve_play(), so it normally only
	# ever runs while the battle screen it built these nodes onto is still current — but the
	# still-visible "⌂ leave battle" button from that same screen (show_battle() doesn't
	# redraw to the win/loss outcome screen until _resolve_play() finishes, well after this
	# function returns) means a player really can tap away mid-animation and free g.overlay's
	# children out from under this coroutine. Same class of bug as show_chapter_transition()'s
	# freed-instance race (game_map_screen.gd) — same fix, checked at every resume point that
	# still touches these nodes.
	if not is_instance_valid(top_bar) or not is_instance_valid(btm_bar) or not is_instance_valid(banner):
		return

	var out_tw := g.create_tween().set_parallel(true)
	out_tw.tween_property(banner, "modulate:a", 0.0, g._battle_delay(0.25))
	out_tw.tween_property(banner, "scale", Vector2(1.2, 1.2), g._battle_delay(0.25))
	out_tw.tween_property(top_bar, "position:y", -64.0, g._battle_delay(0.25))
	out_tw.tween_property(btm_bar, "position:y", 844.0, g._battle_delay(0.25))
	if sprite and is_instance_valid(sprite):
		out_tw.tween_property(sprite, "modulate:a", 0.0, g._battle_delay(0.25))

	await out_tw.finished
	if not is_instance_valid(top_bar) or not is_instance_valid(btm_bar) or not is_instance_valid(banner):
		return
	top_bar.queue_free()
	btm_bar.queue_free()
	banner.queue_free()

func _advance_to_reward() -> void:
	# show_battle can run several times while the win is on screen; only one hand-off.
	if g.advancing_to_reward: return
	g.advancing_to_reward = true
	g.play_sfx("battle_victory")
	await g.get_tree().create_timer(g._battle_delay(0.8)).timeout
	g.advancing_to_reward = false
	if g.combat == null or g.combat.state.phase != "won": return
	if g.in_sandbox:
		g.in_sandbox = false
		g._toast(g.t("ui.sandbox_complete_toast"), g.JADE)
		g.show_camp()
		return
	g.show_reward()

func _enemy_turn() -> void:
	g.resolving = true
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
		if str(planned[index]) == "curse": await _animate_player_curse()
		# Add a deliberate pause between multiple enemies' actions!
		await g.get_tree().create_timer(g._battle_delay(0.35)).timeout

	var before_health: int = g.combat.state.player.health
	g.combat.end_turn()
	if g.combat.state.player.health < before_health:
		g._haptic("heavy")
		await _animate_player_hit(before_health - g.combat.state.player.health)
		if g.combat.state.player.health <= 25 and g.combat.state.player.health > 0:
			g._maybe_show_tutorial("combat_survival")

	# Give a brief pause after all enemy actions and damage resolve before player can act
	await g.get_tree().create_timer(g._battle_delay(0.30)).timeout
	show_battle()
	g.resolving = false
	if g.auto_battle_active and g.combat != null and g.combat.state.phase == "player":
		_maybe_step_auto_battle()


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
			# Anticipation (crouch/squash) then small rise, shield aura
			tween.tween_property(sprite, "modulate", Color(0.75, 0.95, 1.6), g._battle_delay(0.18))
			tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.16, base_scale * 0.86), g._battle_delay(0.26)).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(sprite, "position:y", origin.y - 12.0, g._battle_delay(0.22)).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, g._battle_delay(0.22)).set_trans(Tween.TRANS_BACK)
			tween.tween_interval(g._battle_delay(0.18))
			tween.tween_property(sprite, "position:y", origin.y, g._battle_delay(0.24))
			tween.parallel().tween_property(sprite, "modulate", rest_tint, g._battle_delay(0.24))
		"empower":
			# Power surge & roar stretch
			tween.tween_property(sprite, "modulate", Color(1.8, 0.9, 2.0), g._battle_delay(0.18))
			tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 0.88, base_scale * 1.25), g._battle_delay(0.30)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_interval(g._battle_delay(0.20))
			tween.tween_property(sprite, "scale", Vector2.ONE * base_scale * 1.08, g._battle_delay(0.20)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", Vector2.ONE * base_scale, g._battle_delay(0.24)).set_trans(Tween.TRANS_ELASTIC)
			tween.parallel().tween_property(sprite, "modulate", rest_tint, g._battle_delay(0.24))
		"curse":
			tween.tween_property(sprite, "modulate", Color(0.9, 1.8, 0.7), g._battle_delay(0.20))
			tween.tween_property(sprite, "position:x", origin.x + 10.0, g._battle_delay(0.12))
			tween.tween_property(sprite, "position:x", origin.x - 10.0, g._battle_delay(0.12))
			tween.tween_property(sprite, "position:x", origin.x + 6.0, g._battle_delay(0.10))
			tween.tween_property(sprite, "position:x", origin.x, g._battle_delay(0.10))
			tween.tween_interval(g._battle_delay(0.16))
			tween.tween_property(sprite, "modulate", rest_tint, g._battle_delay(0.22))
		_:
			var art_key: String = g._art_key_for_enemy(enemy_state)
			match art_key:
				"ashRaven", "forgeSpark":
					# Winged dive / forward rush (往前冲)
					# Anticipation: rears back with wings/body tilted
					tween.tween_property(sprite, "position", Vector2(origin.x + 24.0, origin.y - 18.0), g._battle_delay(0.30)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "rotation_degrees", 18.0, g._battle_delay(0.30))
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 0.88, base_scale * 1.15), g._battle_delay(0.30))
					# Fast swooping lunge forward-down towards the player
					tween.tween_property(sprite, "position", Vector2(origin.x - 58.0, origin.y + 38.0), g._battle_delay(0.20)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tween.parallel().tween_property(sprite, "rotation_degrees", -24.0, g._battle_delay(0.20))
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.25, base_scale * 0.82), g._battle_delay(0.20))
					tween.parallel().tween_property(sprite, "modulate", Color(2.2, 1.2, 0.8), g._battle_delay(0.20))
					tween.tween_callback(func():
						_flash_hit(sprite, Color(1.0, 0.8, 0.5), g._battle_delay(0.18))
						_shake_screen(4.5)
						g._haptic("tap"))
					# Pause at strike apex
					tween.tween_interval(g._battle_delay(0.15))
					# Elastic recovery
					tween.tween_property(sprite, "position", origin, g._battle_delay(0.38)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "rotation_degrees", 0.0, g._battle_delay(0.38))
					tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, g._battle_delay(0.38))
					tween.parallel().tween_property(sprite, "modulate", rest_tint, g._battle_delay(0.38))
				"sentinel", "embercliff":
					# Heavy armed swing / arm slash (挥动武器/手臂)
					# Anticipation: raises arm/weapon high with reverse tilt
					tween.tween_property(sprite, "position", Vector2(origin.x + 16.0, origin.y - 28.0), g._battle_delay(0.34)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "rotation_degrees", 28.0, g._battle_delay(0.34))
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 0.90, base_scale * 1.20), g._battle_delay(0.34))
					# Fierce diagonal downward sweeping slash
					tween.tween_property(sprite, "position", Vector2(origin.x - 52.0, origin.y + 32.0), g._battle_delay(0.18)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
					tween.parallel().tween_property(sprite, "rotation_degrees", -34.0, g._battle_delay(0.18))
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.25, base_scale * 0.82), g._battle_delay(0.18))
					tween.parallel().tween_property(sprite, "modulate", Color(2.1, 1.3, 0.9), g._battle_delay(0.18))
					tween.tween_callback(func():
						_flash_hit(sprite, Color(1.0, 0.85, 0.6), g._battle_delay(0.18))
						_shake_screen(5.5)
						g._haptic("tap"))
					# Pause at strike apex
					tween.tween_interval(g._battle_delay(0.15))
					# Rotational recoil and settle
					tween.tween_property(sprite, "position", origin, g._battle_delay(0.40)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "rotation_degrees", 0.0, g._battle_delay(0.40))
					tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, g._battle_delay(0.40))
					tween.parallel().tween_property(sprite, "modulate", rest_tint, g._battle_delay(0.40))
				"runebound", "mountainHeart":
					# Colossal Ground Tremor Slam / Stomp (巨灵践踏)
					# Slow, heavy rear-up build up
					tween.tween_property(sprite, "position:y", origin.y - 34.0, g._battle_delay(0.42)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 0.86, base_scale * 1.35), g._battle_delay(0.42))
					tween.parallel().tween_property(sprite, "modulate", Color(1.7, 1.4, 2.3), g._battle_delay(0.42))
					# Cataclysmic downward crash
					tween.tween_property(sprite, "position:y", origin.y + 46.0, g._battle_delay(0.16)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.40, base_scale * 0.68), g._battle_delay(0.16))
					tween.tween_callback(func():
						_flash_hit(sprite, Color(1.2, 0.9, 1.4), g._battle_delay(0.22))
						_shake_screen(8.5, 0.38)
						g._haptic("heavy"))
					# Impact hold at ground
					tween.tween_interval(g._battle_delay(0.18))
					# Solid rebound back to earth
					tween.tween_property(sprite, "position", origin, g._battle_delay(0.42)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, g._battle_delay(0.42))
					tween.parallel().tween_property(sprite, "modulate", rest_tint, g._battle_delay(0.42))
				"lanternstone", "runeShard":
					# Magic Channeling & Shockwave Surge (聚气施法)
					# Floats up, runes flare
					tween.tween_property(sprite, "position:y", origin.y - 32.0, g._battle_delay(0.36)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale * 1.25, g._battle_delay(0.36))
					tween.parallel().tween_property(sprite, "modulate", Color(1.7, 2.3, 2.8), g._battle_delay(0.36))
					# Casts energy pulse towards player
					tween.tween_property(sprite, "position:x", origin.x - 40.0, g._battle_delay(0.18)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.18, base_scale * 0.92), g._battle_delay(0.18))
					tween.tween_callback(func():
						_flash_hit(sprite, Color(0.8, 1.5, 2.5), g._battle_delay(0.16))
						_shake_screen(4.0)
						g._haptic("tap"))
					# Hold beam/pulse apex
					tween.tween_interval(g._battle_delay(0.15))
					# Drifts back gracefully
					tween.tween_property(sprite, "position", origin, g._battle_delay(0.38)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, g._battle_delay(0.38))
					tween.parallel().tween_property(sprite, "modulate", rest_tint, g._battle_delay(0.38))
				_:
					# Generic lunging attack
					tween.tween_property(sprite, "position", Vector2(origin.x + 14.0, origin.y - 16.0), g._battle_delay(0.28)).set_trans(Tween.TRANS_SINE)
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 1.12, base_scale * 0.88), g._battle_delay(0.28))
					tween.tween_property(sprite, "position", Vector2(origin.x - 46.0, origin.y + 28.0), g._battle_delay(0.16)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tween.parallel().tween_property(sprite, "rotation_degrees", -16.0, g._battle_delay(0.16))
					tween.parallel().tween_property(sprite, "scale", Vector2(base_scale * 0.85, base_scale * 1.25), g._battle_delay(0.16))
					tween.parallel().tween_property(sprite, "modulate", Color(2.0, 1.1, 0.9), g._battle_delay(0.16))
					tween.tween_callback(func():
						_flash_hit(sprite, Color(1.0, 0.75, 0.55), g._battle_delay(0.16))
						_shake_screen(4.5)
						g._haptic("tap"))
					tween.tween_interval(g._battle_delay(0.14))
					tween.tween_property(sprite, "position", origin, g._battle_delay(0.36)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(sprite, "rotation_degrees", 0.0, g._battle_delay(0.36))
					tween.parallel().tween_property(sprite, "scale", Vector2.ONE * base_scale, g._battle_delay(0.36))
					tween.parallel().tween_property(sprite, "modulate", rest_tint, g._battle_delay(0.36))
	await tween.finished
	sprite.position = origin
	sprite.scale = Vector2.ONE * base_scale
	sprite.rotation_degrees = 0.0
	sprite.modulate = rest_tint

func _animate_player_hit(amount: int) -> void:
	g.play_sfx("attack_heavy", 0.08, 1.0)
	var popup := g._label("−%d" % amount, 42, Color("ff5242"), HORIZONTAL_ALIGNMENT_CENTER)
	popup.position = Vector2(145, 475)
	popup.size = Vector2(100, 48)
	popup.z_index = 380
	popup.pivot_offset = Vector2(50, 24)
	popup.scale = Vector2(0.4, 0.4)
	popup.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.95))
	popup.add_theme_constant_override("outline_size", 6)
	g.overlay.add_child(popup)
	var punch := popup.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(popup, "scale", Vector2(1.35, 1.35), g._battle_delay(0.16))
	punch.tween_property(popup, "scale", Vector2(1.10, 1.10), g._battle_delay(0.10))
	_shake_screen(clampf(float(amount) * 0.7, 4.0, 12.0), g._battle_delay(0.35))

	# Red wash over the screen so a hit registers even if you were looking at your hand.
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.15, 0.12, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.overlay.add_child(flash)
	var wash := flash.create_tween()
	wash.tween_property(flash, "color:a", 0.32, g._battle_delay(0.10))
	wash.tween_property(flash, "color:a", 0.0, g._battle_delay(0.40))
	wash.tween_callback(flash.queue_free)

	var player_node: Sprite2D = g.get_tree().root.find_child("PlayerSprite", true, false) as Sprite2D
	if player_node:
		_flash_hit(player_node, Color("ff5c4a"), g._battle_delay(0.15))
		_squash_impact(player_node, float(player_node.get_meta("base_scale", 1.0)), g._battle_delay(0.32))
		if ResourceLoader.exists("res://assets/vfx/spirit_slash_arc.png"):
			var slash := Sprite2D.new()
			slash.name = "AnimPlayerHitSlash"
			slash.texture = load("res://assets/vfx/spirit_slash_arc.png")
			slash.position = player_node.global_position
			slash.rotation_degrees = -35.0
			slash.scale = Vector2(0.05, 0.05)
			slash.z_index = 350
			slash.modulate = Color(1.8, 0.35, 0.25, 0.95)
			g.overlay.add_child(slash)

			var slash_tw := slash.create_tween().set_parallel(true)
			slash_tw.tween_property(slash, "scale", Vector2(0.24, 0.24), g._battle_delay(0.24)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			slash_tw.tween_property(slash, "rotation_degrees", -10.0, g._battle_delay(0.24))
			slash_tw.tween_property(slash, "modulate:a", 0.0, g._battle_delay(0.18)).set_delay(g._battle_delay(0.12))
			slash_tw.chain().tween_callback(slash.queue_free)

	var float_tw := popup.create_tween()
	# Hold at full opacity for reading!
	float_tw.tween_interval(g._battle_delay(0.60))
	float_tw.tween_property(popup, "position:y", popup.position.y - 50.0, g._battle_delay(0.45)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	float_tw.parallel().tween_property(popup, "modulate:a", 0.0, g._battle_delay(0.45))

	await float_tw.finished
	popup.queue_free()

func _combat_event(kind: String, payload: Dictionary) -> void:
	if g.battle_log: g.battle_log.record(kind, payload, int(g.combat.state.get("turn", 0)) if g.combat else 0)
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
		g.play_sfx("boss_phase2")
		_show_boss_phase_banner(p_name, p_desc)
	elif kind == "resonance":
		var r_type: String = str(payload.get("type", ""))
		if r_type == "combustion": g.play_sfx("resonance_combustion")
		elif r_type == "sunder": g.play_sfx("resonance_sunder")
		elif r_type == "fortify": g.play_sfx("resonance_fortify")

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
	# Invalidate any in-flight _resolve_play() coroutine still mid-animation from the battle
	# being left (see battle_session's own comment in game.gd) before it can resume later and
	# call show_battle(), which would wipe whatever screen we're about to navigate to and
	# redraw this now-abandoned battle over it. resolving is reset here too rather than left
	# for that coroutine's own tail to clear — the whole point is that tail may never reach its
	# own "g.resolving = false" line once battle_session no longer matches.
	g.battle_session += 1
	g.resolving = false
	if g.auto_battle_active: g.stop_auto_battle("manual")
	g.selected_card = -1
	g.resolving = false
	auto_stepping = false
	if g.in_sandbox:
		# Zero-stakes: profile.health was never touched on the way in, so there is nothing to
		# restore and nothing worth writing to disk on the way out either.
		g.in_sandbox = false
		g.show_camp()
		return
	if g.in_boss_rush:
		# Same "a loss costs the attempt, not the run" split as Abyss/Daily Trial: the current
		# bout number stays put so the next attempt re-fights the same boss at the same
		# escalation, rather than resetting the whole streak.
		g.in_boss_rush = false
		g.profile.health = 60
		SpiritSave.write(g.profile)
		g.show_camp()
		return
	if g.in_abyss:
		g.in_abyss = false
		g.profile.health = 60
		SpiritSave.write(g.profile)
		g.show_camp()
		return
	if g.in_daily_trial:
		# A loss (or an early retreat) costs the attempt, not the run: the stage you were on
		# stays un-cleared so today's next try re-fights it, same "attempt vs. run" split the
		# comment above already uses for Abyss.
		g.in_daily_trial = false
		g.profile.health = 60
		SpiritSave.write(g.profile)
		g.show_camp()
		return
	if g.in_phantom_arena:
		g.in_phantom_arena = false
		g.profile.health = 60
		SpiritSave.write(g.profile)
		g.show_camp()
		return
	if g.in_weekly_challenge:
		g.in_weekly_challenge = false
		g.profile.health = 60
		SpiritSave.write(g.profile)
		g.show_camp()
		return
	if g.in_draft_battle:
		# A loss counts against SpiritContent.DRAFT_LOSS_CAP rather than ending the run
		# outright — same "attempt vs. run" split as Abyss/Daily Trial above — except
		# reaching the cap does end the run, mirroring DRAFT_WIN_CAP's Grand Champion ending
		# in _grant_stage_rewards(). g._reset_draft_run() is the same helper _abandon_draft()
		# and that ending use, so every way a run can end leaves round/deck/current_pool/
		# wins/losses clean for the next one. Without this branch at all, in_draft_battle
		# stayed stuck true after any loss or retreat, silently swapping every later
		# battle's deck for the (by-then stale) draft deck — see begin_battle()'s
		# battle_deck check.
		g.in_draft_battle = false
		g.profile.health = 60
		var draft: Dictionary = g.profile.get("draft_arena", {})
		var losses: int = int(draft.get("losses", 0)) + 1
		draft.losses = losses
		if losses >= SpiritContent.DRAFT_LOSS_CAP:
			var final_wins: int = int(draft.get("wins", 0))
			g._reset_draft_run()
			g._toast(g.tf("ui.draft_run_ended", final_wins))
		else:
			SpiritSave.write(g.profile)
		g.show_challenges()
		return
	g.profile.health = 60
	SpiritSave.write(g.profile)
	g.show_map()

