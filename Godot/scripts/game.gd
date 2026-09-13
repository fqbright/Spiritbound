extends Control

class CardTile extends PanelContainer:
	var hand_index := 0
	var card_data: Dictionary
	var game: Control
	func _get_drag_data(_position: Vector2):
		var preview := duplicate()
		preview.custom_minimum_size = Vector2(126,186)
		preview.modulate = Color(1.08,1.08,1.08)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_drag_preview(preview)
		return {"hand_index":hand_index,"card":card_data}
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
		elif event is InputEventScreenTouch and event.pressed:
			accept_event()

var content := SpiritContent.new()
var profile: Dictionary
var combat: SpiritCombat
var current_stage := 0
var active_modifier: Dictionary = {}
var root: Control
var overlay: Control
var map_canvas: Control
var map_scroll: ScrollContainer
var traveler: Label
var enemy_boxes: Array[Control] = []
var selected_rune := ""
var muted := false
var map_music: AudioStreamPlayer
var battle_music: AudioStreamPlayer

const BG = Color("071116")
const PANEL = Color("10242b")
const JADE = Color("83e4c1")
const EMBER = Color("ff9a4c")
const GOLD = Color("dab56e")
const TEXT = Color("f7f3e8")
const MUTED = Color("bdd0d0")
const MAP_POINTS = [Vector2(64,70),Vector2(255,155),Vector2(120,247),Vector2(268,337),Vector2(164,430)]
const BATTLE_BACKGROUNDS = ["battlefield-v1.jpg","lantern-marsh-v1.jpg","rune-ravine-v1.jpg","ember-cliff-v1.jpg","mountain-forge-v1.jpg"]

func _ready() -> void:
	set_process_input(true)
	profile = SpiritSave.load_profile(content)
	_build_audio()
	show_map()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: SpiritSave.write(profile)

func _clear() -> void:
	for child in get_children():
		if child != map_music and child != battle_music: child.queue_free()
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	overlay = Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.z_index = 500; root.add_child(overlay)

func _build_audio() -> void:
	map_music = AudioStreamPlayer.new(); map_music.stream = load("res://assets/audio/spirit-symphony-mobile.wav"); map_music.volume_db = -12; add_child(map_music)
	battle_music = AudioStreamPlayer.new(); battle_music.stream = load("res://assets/audio/ember-battle-mobile.wav"); battle_music.volume_db = -13; add_child(battle_music)
	map_music.finished.connect(func(): if not muted: map_music.play())
	battle_music.finished.connect(func(): if not muted: battle_music.play())

func _play_music(battle := false) -> void:
	if muted: return
	if battle: map_music.stop(); battle_music.play()
	else: battle_music.stop(); if not map_music.playing: map_music.play()

func _panel(color: Color, radius := 14, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = color
	style.corner_radius_top_left = radius; style.corner_radius_top_right = radius; style.corner_radius_bottom_left = radius; style.corner_radius_bottom_right = radius
	if border.a > 0: style.border_width_left = 1; style.border_width_right = 1; style.border_width_top = 1; style.border_width_bottom = 1; style.border_color = border
	return style

func _label(text: String, size := 14, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var value := Label.new(); value.text = text; value.add_theme_font_size_override("font_size",size); value.add_theme_color_override("font_color",color); value.horizontal_alignment = align; value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return value

func _button(text: String, callback: Callable, color := PANEL, min_size := Vector2(0,46)) -> Button:
	var value := Button.new(); value.text = text; value.custom_minimum_size = min_size; value.add_theme_font_size_override("font_size",12); value.add_theme_color_override("font_color",TEXT); value.add_theme_stylebox_override("normal",_panel(color,14,GOLD)); value.add_theme_stylebox_override("hover",_panel(color.lightened(.1),14,JADE)); value.add_theme_stylebox_override("pressed",_panel(color.darkened(.12),14,EMBER));
	if callback.is_valid(): value.pressed.connect(callback)
	return value

func _texture(path: String) -> Texture2D:
	return load("res://assets/%s" % path)

func _background(file: String, opacity := .42) -> TextureRect:
	var image := TextureRect.new(); image.texture = _texture("backgrounds/%s" % file); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.modulate = Color(1,1,1,opacity); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _header(title: String, subtitle: String, back := Callable()) -> HBoxContainer:
	var bar := HBoxContainer.new(); bar.custom_minimum_size.y = 66; bar.add_theme_constant_override("separation",8)
	if back.is_valid(): bar.add_child(_button("‹",back,Color("17363e"),Vector2(42,42)))
	var copy := VBoxContainer.new(); copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; copy.add_child(_label(title,20,TEXT)); copy.add_child(_label(subtitle,9,JADE)); bar.add_child(copy)
	bar.add_child(_label("♥ %d/60   ◆ %d" % [profile.health,profile.gold],12,GOLD,HORIZONTAL_ALIGNMENT_RIGHT))
	return bar

func show_map() -> void:
	_clear(); _play_music(false)
	var backdrop := _background("spirit-world-map-v1.jpg",.3); root.add_child(backdrop); root.move_child(backdrop,0)
	var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page.add_theme_constant_override("separation",0); root.add_child(page)
	var header := _header("SPIRITBOUND","沿灵迹选择目的地")
	header.add_child(_button("✧%d" % profile.relics.size(),show_camp,Color("17363e"),Vector2(44,40)))
	header.add_child(_button("♫" if not muted else "♩",_toggle_music,Color("17363e"),Vector2(44,40))); page.add_child(header)
	map_scroll = ScrollContainer.new(); map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(map_scroll)
	map_canvas = Control.new(); map_canvas.custom_minimum_size = Vector2(390,5000); map_scroll.add_child(map_canvas)
	for chapter in 10: _add_map_chapter(chapter)
	_add_routes()
	for index in 50: _add_stage_pin(index)
	traveler = _label("◆",24,Color("fff0a6"),HORIZONTAL_ALIGNMENT_CENTER); traveler.custom_minimum_size = Vector2(38,38); traveler.position = _map_point(profile.position) - Vector2(6,32); traveler.z_index = 25; traveler.mouse_filter = Control.MOUSE_FILTER_IGNORE; map_canvas.add_child(traveler)
	var dock := HBoxContainer.new(); dock.custom_minimum_size.y = 70; dock.add_theme_constant_override("separation",5); page.add_child(dock)
	for item in [["▤\n牌组",show_deck],["⚔\n装备",show_loadout],["◆\n商店",show_shop],["➜\n下一关",_next_stage]]:
		var button := _button(item[0],item[1],Color("16353d"),Vector2(0,62)); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dock.add_child(button)
	await get_tree().process_frame
	map_scroll.scroll_vertical = maxi(0,int(_map_point(profile.position).y - 280))

func _add_map_chapter(chapter: int) -> void:
	var scene := TextureRect.new(); scene.texture = _texture("backgrounds/%s" % BATTLE_BACKGROUNDS[chapter % 5]); scene.position = Vector2(0,chapter * 500); scene.size = Vector2(390,500); scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; scene.modulate = Color(1,1,1,.55); scene.mouse_filter = Control.MOUSE_FILTER_IGNORE; map_canvas.add_child(scene)
	var wash := ColorRect.new(); wash.color = Color(0.02,.07,.09,.34); wash.position = scene.position; wash.size = scene.size; wash.mouse_filter = Control.MOUSE_FILTER_IGNORE; map_canvas.add_child(wash)
	var title := _label("第%d大关 · %s" % [chapter + 1,SpiritContent.CHAPTER_NAMES_ZH[chapter]],18,JADE); title.position = Vector2(14,chapter * 500 + 14); title.z_index = 4; map_canvas.add_child(title)

func _add_routes() -> void:
	var line := Line2D.new(); line.width = 7; line.default_color = Color(1,.84,.48,.7); line.z_index = 2
	for index in 50: line.add_point(_map_point(index) + Vector2(25,25))
	map_canvas.add_child(line)

func _add_stage_pin(index: int) -> void:
	var encounter: Dictionary = content.encounters[index]; var point := _map_point(index); var locked := index > int(profile.unlocked)
	var pin := _button("◇" if locked else "%d-%d" % [encounter.chapter,encounter.level],func(): _travel_to(index),Color("26393d") if locked else Color("23584d"),Vector2(54,54)); pin.position = point; pin.disabled = locked; pin.z_index = 10; map_canvas.add_child(pin)
	var name := _label(content.stage_name(index),10,TEXT); name.position = point + Vector2(60 if point.x < 190 else -126,8); name.size = Vector2(122,40); name.z_index = 9; map_canvas.add_child(name)

func _map_point(index: int) -> Vector2:
	return MAP_POINTS[index % 5] + Vector2(0,index / 5 * 500)

func _travel_to(index: int) -> void:
	if index > int(profile.unlocked): return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT); tween.tween_property(traveler,"position",_map_point(index)-Vector2(6,32),.65)
	for value in range(int(profile.position),index + 1): tween.parallel().tween_method(func(y): map_scroll.scroll_vertical = int(y),float(map_scroll.scroll_vertical),float(maxi(0,int(_map_point(index).y-280))),.65)
	await tween.finished; profile.position = index; SpiritSave.write(profile)
	var kind := content.node_kind(index)
	if kind in ["event","merchant","rest"] and index == int(profile.unlocked): show_event(index,kind)
	else: begin_battle(index)

func _next_stage() -> void:
	if int(profile.position) < int(profile.unlocked): _travel_to(int(profile.position)+1)

func _modifier(seed: int, stage: int) -> Dictionary:
	var options := [
		{"id":"reinforced","name":"重甲军势","detail":"敌人生命 +30%，金币 +35%","health_scale":1.3,"reward_scale":1.35},
		{"id":"frenzy","name":"血月狂怒","detail":"敌人攻击 +3，金币 +30%","damage_bonus":3,"reward_scale":1.3},
		{"id":"swarm","name":"狩猎群落","detail":"增加一名敌人，金币 +40%","extra_enemy":1,"health_scale":1.08,"reward_scale":1.4},
		{"id":"rebirth","name":"不灭余烬","detail":"敌人可能复活，金币 +50%","revive":.45,"health_scale":1.1,"damage_bonus":1,"reward_scale":1.5},
		{"id":"eclipse","name":"灵蚀天象","detail":"生命与攻击提升，金币 +45%","health_scale":1.18,"damage_bonus":2,"reward_scale":1.45},
	]
	var value: int = absi(seed ^ ((stage + 1) * 2654435761))
	return {} if value % 100 < 48 else options[(value / 100) % options.size()]

func begin_battle(index: int) -> void:
	current_stage = index
	var seed := int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	active_modifier = _modifier(seed,index)
	combat = SpiritCombat.new(content)
	var equipped: Array = profile.equipment_slots.values()
	combat.create(seed,content.encounters[index],profile.deck,int(profile.health),profile.upgrades,equipped,profile.card_runes,active_modifier)
	combat.event.connect(_combat_event)
	show_battle()

func show_battle() -> void:
	_clear(); _play_music(true); enemy_boxes.clear()
	var encounter: Dictionary = content.encounters[current_stage]
	var bg := _background(BATTLE_BACKGROUNDS[encounter.background],.28); root.add_child(bg); root.move_child(bg,0)
	var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page.add_theme_constant_override("separation",4); page.mouse_filter = Control.MOUSE_FILTER_PASS; root.add_child(page)
	var top := HBoxContainer.new(); top.custom_minimum_size.y = 50; top.add_child(_label("%d-%d  %s" % [encounter.chapter,encounter.level,content.stage_name(current_stage)],13,JADE)); var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer); top.add_child(_label("回合 %d" % combat.state.turn,11,GOLD)); top.add_child(_button("⌂",_leave_battle,Color("17363e"),Vector2(40,38))); page.add_child(top)
	if not active_modifier.is_empty():
		var modifier := _label("✥ %s  ·  %s" % [active_modifier.name,active_modifier.detail],10,Color("ffe2b0"),HORIZONTAL_ALIGNMENT_CENTER); modifier.custom_minimum_size.y = 36; modifier.add_theme_stylebox_override("normal",_panel(Color("54261f"),11,EMBER)); page.add_child(modifier)
	if not combat.state.equipment.is_empty():
		var gear := HBoxContainer.new(); gear.alignment = BoxContainer.ALIGNMENT_CENTER
		for id in combat.state.equipment:
			var item := content.equipment(id); gear.add_child(_label("%s %s" % [item.icon,item.zh],8,GOLD))
		page.add_child(gear)
	var enemy_area := HBoxContainer.new(); enemy_area.size_flags_vertical = Control.SIZE_EXPAND_FILL; enemy_area.alignment = BoxContainer.ALIGNMENT_CENTER; enemy_area.add_theme_constant_override("separation",4); page.add_child(enemy_area)
	for index in combat.state.enemies.size():
		if combat.state.enemies[index].health <= 0: continue
		var box := _enemy_view(index); enemy_area.add_child(box); enemy_boxes.append(box)
	var piles := HBoxContainer.new(); piles.alignment = BoxContainer.ALIGNMENT_CENTER
	for pile in [["抽牌",combat.state.draw.size()],["弃牌",combat.state.discard.size()],["消耗",combat.state.exhaust.size()]]: piles.add_child(_label("▣ %s %d" % pile,9,MUTED,HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(piles)
	var player := VBoxContainer.new(); player.custom_minimum_size.y = 92; player.alignment = BoxContainer.ALIGNMENT_CENTER
	player.add_child(_label("绯狐   ♥ %d/60   ◆ 护盾 %d" % [combat.state.player.health,combat.state.player.shield],13,TEXT,HORIZONTAL_ALIGNMENT_CENTER)); player.add_child(_label("能量 %d    本回合还可出牌 %d" % [combat.state.energy,combat.state.actions],11,GOLD,HORIZONTAL_ALIGNMENT_CENTER)); page.add_child(player)
	if combat.state.phase == "player": _add_hand(page)
	else:
		var outcome := _label("战斗胜利" if combat.state.phase == "won" else "远征失败",26,TEXT,HORIZONTAL_ALIGNMENT_CENTER); outcome.size_flags_vertical = Control.SIZE_EXPAND_FILL; outcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; page.add_child(outcome)
		page.add_child(_button("打开胜利宝箱" if combat.state.phase == "won" else "返回地图",show_reward if combat.state.phase == "won" else _leave_battle,EMBER,Vector2(0,54)))

func _enemy_view(index: int) -> Control:
	var enemy: Dictionary = combat.state.enemies[index]
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(116 if combat.state.enemies.size() < 3 else 94,230); box.set_meta("enemy_index",index); box.alignment = BoxContainer.ALIGNMENT_END
	var intent: int = int(enemy.damage) + (int(enemy.mechanics.get("below_half",0)) if enemy.health <= enemy.max_health / 2 else 0); var critical: bool = enemy.mechanics.get("critical_every",0) > 0 and (enemy.attacks + 1) % enemy.mechanics.critical_every == 0
	box.add_child(_label("✹ 暴击 %d" % (intent*2) if critical else "⚔ 攻击 %d" % intent,9,Color("ffb18c"),HORIZONTAL_ALIGNMENT_CENTER))
	var art := TextureRect.new(); art.texture = _texture("characters/%s" % enemy.art); art.custom_minimum_size = Vector2(100,140); art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.mouse_filter = Control.MOUSE_FILTER_IGNORE; box.add_child(art)
	var idle := create_tween().set_loops(); idle.tween_property(art,"position:y",-4,1.0).set_trans(Tween.TRANS_SINE); idle.tween_property(art,"position:y",2,1.1).set_trans(Tween.TRANS_SINE)
	box.add_child(_label(enemy.name,9,TEXT,HORIZONTAL_ALIGNMENT_CENTER)); box.add_child(_label("♥ %d/%d   ◆%d" % [enemy.health,enemy.max_health,enemy.shield],10,JADE,HORIZONTAL_ALIGNMENT_CENTER))
	return box

func _add_hand(page: VBoxContainer) -> void:
	var hint := _label("拖出卡牌使用 · 伤害牌拖到敌人，增益牌可拖到空白处",9,MUTED,HORIZONTAL_ALIGNMENT_CENTER); page.add_child(hint)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.y = 206; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; page.add_child(scroll)
	var hand := HBoxContainer.new(); hand.add_theme_constant_override("separation",-24); hand.mouse_filter = Control.MOUSE_FILTER_PASS; scroll.add_child(hand)
	for index in combat.state.hand.size(): hand.add_child(_card_view(combat.state.hand[index],index))

func _card_view(instance: Dictionary, index: int) -> CardTile:
	var card := content.card(instance.card_id); var tile := CardTile.new(); tile.hand_index = index; tile.card_data = card; tile.game = self; tile.custom_minimum_size = Vector2(126,190); tile.add_theme_stylebox_override("panel",_panel(Color("182d33"),14,_rune_color(profile.card_runes.get(card.id,""),_card_color(card))))
	var stack := VBoxContainer.new(); stack.mouse_filter = Control.MOUSE_FILTER_IGNORE; tile.add_child(stack)
	var title := HBoxContainer.new(); title.add_child(_label(str(card.cost),18,Color("241007"),HORIZONTAL_ALIGNMENT_CENTER)); var name := _label(content.text(card.nameKey),12,TEXT,HORIZONTAL_ALIGNMENT_CENTER); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.add_child(name)
	var rune := content.rune(profile.card_runes.get(card.id,"")); if not rune.is_empty(): title.add_child(_label(rune.icon,17,Color(rune.color),HORIZONTAL_ALIGNMENT_CENTER)); stack.add_child(title)
	var art := TextureRect.new(); art.texture = _texture("cards/%s" % _card_art(card.id)); art.custom_minimum_size.y = 91; art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; art.mouse_filter = Control.MOUSE_FILTER_IGNORE; stack.add_child(art)
	stack.add_child(_label(_card_description(card),8,Color("f1e5cb"),HORIZONTAL_ALIGNMENT_CENTER))
	return tile

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("hand_index") and combat != null and combat.state.phase == "player"

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var target := -1
	var global := global_position + at_position
	for box in enemy_boxes:
		if box.get_global_rect().has_point(global): target = int(box.get_meta("enemy_index")); break
	_play_card(int(data.hand_index),target)

func _play_card(hand_index: int, target: int) -> void:
	var before: Array = []
	for enemy in combat.state.enemies: before.append(enemy.health)
	if not combat.play(hand_index,target): _toast("目标无效或资源不足"); return
	for i in combat.state.enemies.size():
		if before[i] > combat.state.enemies[i].health: await _animate_enemy_hit(i,before[i]-combat.state.enemies[i].health,combat.state.enemies[i].health <= 0)
	show_battle()
	if combat.state.phase == "player" and combat.state.actions <= 0:
		await get_tree().create_timer(.3).timeout; await _enemy_turn()

func _animate_enemy_hit(enemy_index: int, amount: int, defeated: bool) -> void:
	var box: Control
	for candidate in enemy_boxes:
		if int(candidate.get_meta("enemy_index")) == enemy_index: box = candidate; break
	if box == null: return
	var popup := _label("−%d" % amount,34,Color("fff0c2"),HORIZONTAL_ALIGNMENT_CENTER); popup.position = box.global_position + Vector2(25,70); overlay.add_child(popup)
	var original := box.position; var tween := create_tween(); tween.tween_property(box,"position:x",original.x-9,.05); tween.tween_property(box,"position:x",original.x+8,.05); tween.tween_property(box,"position",original,.07); tween.parallel().tween_property(popup,"position:y",popup.position.y-38,.35); tween.parallel().tween_property(popup,"modulate:a",0.0,.35)
	if defeated: tween.parallel().tween_property(box,"modulate:a",0.0,.35); tween.parallel().tween_property(box,"scale",Vector2(.45,.45),.35)
	await tween.finished

func _enemy_turn() -> void:
	for box in enemy_boxes:
		var original := box.position; var tween := create_tween(); tween.tween_property(box,"position:y",original.y+24,.12); tween.tween_property(box,"position",original,.14); await tween.finished
	var before_health: int = combat.state.player.health
	combat.end_turn()
	if combat.state.player.health < before_health: _toast("−%d 生命" % (before_health-combat.state.player.health),Color("ff786a")); Input.vibrate_handheld(35)
	show_battle()

func _combat_event(kind: String, payload: Dictionary) -> void:
	if kind == "revive": _toast("✥ 敌人复活 +%d" % payload.amount,Color("9bffd3"))
	elif kind == "equipment":
		var item := content.equipment(payload.id); if not item.is_empty(): _toast("%s %s" % [item.icon,item.zh],GOLD)
	elif kind == "card" and not str(payload.rune).is_empty():
		var rune := content.rune(payload.rune); _toast("%s %s" % [rune.icon,rune.zh],Color(rune.color))

func _toast(message: String, color := TEXT) -> void:
	if overlay == null: return
	var toast := _label(message,15,color,HORIZONTAL_ALIGNMENT_CENTER); toast.position = Vector2(75,120); toast.size = Vector2(240,42); toast.add_theme_stylebox_override("normal",_panel(Color("153d42"),18,color)); overlay.add_child(toast)
	var tween := create_tween(); tween.tween_property(toast,"position:y",92,.22); tween.tween_interval(.55); tween.tween_property(toast,"modulate:a",0.0,.25); tween.tween_callback(toast.queue_free)

func _leave_battle() -> void:
	if combat != null: profile.health = maxi(1,int(combat.state.player.health))
	SpiritSave.write(profile); show_map()

func show_reward() -> void:
	_clear(); _play_music(false)
	var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page.alignment = BoxContainer.ALIGNMENT_CENTER; page.add_theme_constant_override("separation",9); root.add_child(page)
	page.add_child(_label("战斗胜利",27,TEXT,HORIZONTAL_ALIGNMENT_CENTER))
	var chest := TextureRect.new(); var atlas := AtlasTexture.new(); atlas.atlas = _texture("chest-atlas-v1.png"); atlas.region = Rect2(0,0,atlas.atlas.get_width()/2.0,atlas.atlas.get_height()); chest.texture = atlas; chest.custom_minimum_size = Vector2(210,170); chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; page.add_child(chest)
	var open := _button("打开胜利宝箱",Callable(),EMBER,Vector2(220,50)); open.pressed.connect(func(): _open_chest(chest,atlas,page,open)); page.add_child(open)

func _open_chest(chest: TextureRect, atlas: AtlasTexture, page: VBoxContainer, button: Button) -> void:
	button.disabled = true; Input.vibrate_handheld(35)
	var tween := create_tween(); tween.tween_property(chest,"rotation",-.04,.08); tween.tween_property(chest,"rotation",.04,.08); tween.tween_property(chest,"rotation",0.0,.08); await tween.finished
	atlas.region.position.x = atlas.atlas.get_width()/2.0; chest.texture = atlas
	var encounter: Dictionary = content.encounters[current_stage]; var multiplier: float = active_modifier.get("reward_scale",1.0); if profile.equipment_slots.values().has("fortuneSeal"): multiplier *= 1.15
	var gold := int(round(encounter.reward*multiplier)); profile.gold += gold; profile.health = mini(60,int(combat.state.player.health)+10); profile.unlocked = maxi(int(profile.unlocked),mini(49,current_stage+1)); profile.position = current_stage
	page.add_child(_label("◆ +%d 金币    ♥ 战后恢复 10" % gold,18,GOLD,HORIZONTAL_ALIGNMENT_CENTER))
	var kind := content.node_kind(current_stage)
	if kind == "boss":
		var order := ["emberBlade","jadePlate","soulPendant","moonStaff","thornArmor","tideCharm","stoneSpear","mistCloak","fortuneSeal","stormBow","phoenixMail","focusCharm"]
		var id: String = order[(current_stage/5+int(profile.difficulty)*2)%order.size()]; if not profile.equipment_owned.has(id): profile.equipment_owned.append(id)
		var item := content.equipment(id); page.add_child(_reward_item("%s 首领装备 · %s" % [item.icon,item.zh],item.detail,GOLD))
	if kind == "elite":
		var rune: Dictionary = SpiritContent.RUNES[(current_stage/5+int(profile.difficulty))%SpiritContent.RUNES.size()]; profile.rune_inventory[rune.id] = profile.rune_inventory.get(rune.id,0)+1
		page.add_child(_reward_item("%s 精英符文 · %s" % [rune.icon,rune.zh],rune.detail,Color(rune.color)))
	var options: Array = content.cards.filter(func(card): return card.rarity != "Starter")
	page.add_child(_label("选择一张新卡",12,MUTED,HORIZONTAL_ALIGNMENT_CENTER))
	var choices := HBoxContainer.new(); choices.alignment = BoxContainer.ALIGNMENT_CENTER
	for offset in 3:
		var card: Dictionary = options[(current_stage+offset)%options.size()]; choices.add_child(_button(content.text(card.nameKey),func(): _claim_card(card),Color("244a4a"),Vector2(118,58)))
	page.add_child(choices); page.add_child(_button("跳过卡牌并返回地图",_finish_reward,Color("19383f"),Vector2(240,45))); SpiritSave.write(profile)

func _reward_item(title: String, detail: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(350,58); panel.add_theme_stylebox_override("panel",_panel(Color("193839"),13,color)); var stack := VBoxContainer.new(); panel.add_child(stack); stack.add_child(_label(title,12,color,HORIZONTAL_ALIGNMENT_CENTER)); stack.add_child(_label(detail,9,MUTED,HORIZONTAL_ALIGNMENT_CENTER)); return panel

func _claim_card(card: Dictionary) -> void:
	profile.collection[card.id] = profile.collection.get(card.id,0)+1
	var replace := -1
	for i in profile.deck.size():
		if content.card(profile.deck[i]).rarity == "Starter": replace = i; break
	if replace >= 0: profile.deck[replace] = card.id
	_finish_reward()

func _finish_reward() -> void:
	SpiritSave.write(profile); show_map()

func show_event(index: int, kind: String) -> void:
	_clear(); _play_music(false); var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page.alignment = BoxContainer.ALIGNMENT_CENTER; page.add_theme_constant_override("separation",14); root.add_child(page)
	var title: String = str({"event":"迷雾中的旅者","merchant":"路边行商","rest":"灵火营地"}.get(kind,"旅途事件")); page.add_child(_label("✦",54,GOLD,HORIZONTAL_ALIGNMENT_CENTER)); page.add_child(_label(title,23,TEXT,HORIZONTAL_ALIGNMENT_CENTER)); page.add_child(_label("选择一项准备，然后进入本关战斗。",12,MUTED,HORIZONTAL_ALIGNMENT_CENTER))
	if kind == "event": page.add_child(_button("接受委托 · ◆ +25",func(): profile.gold += 25; SpiritSave.write(profile); begin_battle(index),EMBER,Vector2(300,52))); page.add_child(_button("灵泉祝福 · ♥ +15",func(): profile.health = mini(60,profile.health+15); SpiritSave.write(profile); begin_battle(index),Color("21594e"),Vector2(300,52)))
	elif kind == "rest": page.add_child(_button("休息 · ♥ +12",func(): profile.health = mini(60,profile.health+12); SpiritSave.write(profile); begin_battle(index),Color("21594e"),Vector2(300,52))); page.add_child(_button("强化一张牌",func(): profile.upgrades[profile.deck[0]]=1; SpiritSave.write(profile); begin_battle(index),EMBER,Vector2(300,52)))
	else: page.add_child(_button("购买药剂 · ◆30 / ♥+25",func(): if profile.gold>=30: profile.gold-=30; profile.health=mini(60,profile.health+25); SpiritSave.write(profile); begin_battle(index),EMBER,Vector2(300,52))); page.add_child(_button("直接进入战斗",func(): begin_battle(index),Color("21594e"),Vector2(300,52)))
	page.add_child(_button("返回地图",show_map,Color("17363e"),Vector2(180,44)))

func show_shop() -> void:
	_clear(); _play_music(false); var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(page); page.add_child(_header("灵契商店","购买卡牌与生命药剂",show_map)); var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(scroll); var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",7); scroll.add_child(list)
	list.add_child(_button("✚ 生命药剂 · 恢复20生命 · ◆30",func(): if profile.gold>=30: profile.gold-=30; profile.health=mini(60,profile.health+20); SpiritSave.write(profile); show_shop(),Color("245247"),Vector2(0,58)))
	for card in content.cards:
		if card.rarity == "Starter": continue
		var price := 90 if card.rarity == "Rare" else 60 if card.rarity == "Uncommon" else 40
		list.add_child(_button("%s   ◆%d   拥有%d" % [content.text(card.nameKey),price,profile.collection.get(card.id,0)],func(): _buy_card(card,price),Color("17363e"),Vector2(0,52)))

func _buy_card(card: Dictionary, price: int) -> void:
	if profile.gold < price: _toast("金币不足"); return
	profile.gold -= price; profile.collection[card.id] = profile.collection.get(card.id,0)+1; SpiritSave.write(profile); show_shop()

func show_deck() -> void:
	_clear(); var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(page); page.add_child(_header("牌组构筑","固定 25 张 · 当前 %d/25" % profile.deck.size(),show_map)); var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(scroll); var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(list)
	for card in content.cards:
		var owned := int(profile.collection.get(card.id,0)); if owned == 0: continue
		var used: int = profile.deck.count(card.id); var row := HBoxContainer.new(); var name := _label("%s  拥有%d" % [content.text(card.nameKey),owned],11,TEXT); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(name); row.add_child(_button("−",func(): _deck_change(card.id,-1),Color("593b32"),Vector2(38,38))); row.add_child(_label(str(used),12,GOLD,HORIZONTAL_ALIGNMENT_CENTER)); row.add_child(_button("+",func(): _deck_change(card.id,1),Color("245247"),Vector2(38,38))); list.add_child(row)
	page.add_child(_button("确认牌组 %d/25" % profile.deck.size(),func(): if profile.deck.size()==25: SpiritSave.write(profile); show_map(),EMBER,Vector2(0,52)))

func _deck_change(id: String, amount: int) -> void:
	if amount > 0 and profile.deck.size() < 25 and profile.deck.count(id) < int(profile.collection.get(id,0)): profile.deck.append(id)
	elif amount < 0 and profile.deck.has(id): profile.deck.erase(id)
	show_deck()

func show_loadout() -> void:
	_clear(); var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(page); page.add_child(_header("装备与符文","三个装备槽位 · 每种卡牌一个符文",show_map)); var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(scroll); var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",7); scroll.add_child(list)
	list.add_child(_label("当前装备",15,JADE)); var slots := HBoxContainer.new()
	for slot in ["weapon","armor","charm"]:
		var item := content.equipment(profile.equipment_slots.get(slot,"")); slots.add_child(_label("%s\n%s" % [slot, item.zh if not item.is_empty() else "空"],9,GOLD,HORIZONTAL_ALIGNMENT_CENTER))
	list.add_child(slots); list.add_child(_label("装备收藏",15,JADE))
	for item in SpiritContent.EQUIPMENT:
		var owned: bool = profile.equipment_owned.has(item.id); var equipped: bool = profile.equipment_slots.get(item.slot,"") == item.id
		var button := _button("%s %s · %s\n%s" % [item.icon,item.zh,"卸下" if equipped else "装备" if owned else "未获得",item.detail],func(): _equip(item),Color("245247") if equipped else Color("17363e"),Vector2(0,67)); button.disabled = not owned; list.add_child(button)
	list.add_child(_label("符文行囊 · 选择后镶嵌到卡牌",15,JADE)); var runes_row := HBoxContainer.new()
	for rune in SpiritContent.RUNES:
		var available: int = int(profile.rune_inventory.get(rune.id,0)) - profile.card_runes.values().count(rune.id); var button := _button("%s %s ×%d" % [rune.icon,rune.zh,maxi(0,available)],func(): selected_rune=rune.id; show_loadout(),Color("24444b") if selected_rune==rune.id else Color("17363e"),Vector2(0,48)); button.disabled=available<=0; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; runes_row.add_child(button)
	list.add_child(runes_row); list.add_child(_label("牌组符文",15,JADE))
	for id in _unique(profile.deck):
		var card := content.card(id); var installed: Dictionary = content.rune(profile.card_runes.get(id,"")); var row := HBoxContainer.new(); var copy := _label("%s\n%s" % [content.text(card.nameKey),installed.zh if not installed.is_empty() else "未镶嵌"],10,TEXT); copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(copy); row.add_child(_button("取下",func(): profile.card_runes.erase(id); SpiritSave.write(profile); show_loadout(),Color("593b32"),Vector2(52,38))); row.add_child(_button("镶嵌",func(): _socket(id),Color("245247"),Vector2(58,38))); list.add_child(row)

func _equip(item: Dictionary) -> void:
	if profile.equipment_slots.get(item.slot,"") == item.id: profile.equipment_slots.erase(item.slot)
	else: profile.equipment_slots[item.slot] = item.id
	SpiritSave.write(profile); show_loadout()

func _socket(card_id: String) -> void:
	if selected_rune.is_empty(): _toast("请先选择符文"); return
	var available: int = int(profile.rune_inventory.get(selected_rune,0)) - profile.card_runes.values().count(selected_rune)
	if available <= 0: return
	profile.card_runes[card_id] = selected_rune; SpiritSave.write(profile); selected_rune=""; show_loadout()

func show_camp() -> void:
	_clear(); var page:=VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(page); page.add_child(_header("远征营地","灵兽、遗物与挑战阶梯",show_map)); var list:=VBoxContainer.new(); list.size_flags_vertical=Control.SIZE_EXPAND_FILL; page.add_child(list); list.add_child(_label("挑战等级 A%d" % profile.difficulty,18,JADE,HORIZONTAL_ALIGNMENT_CENTER)); var row:=HBoxContainer.new()
	for value in 6: var button:=_button("A%d"%value,func(): profile.difficulty=value; SpiritSave.write(profile); show_camp(),Color("245247") if value==profile.difficulty else Color("17363e"),Vector2(0,44)); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(button)
	list.add_child(row); list.add_child(_label("已获得遗物 %d/5" % profile.relics.size(),15,GOLD,HORIZONTAL_ALIGNMENT_CENTER)); list.add_child(_label("更高挑战提高敌人生命与伤害；Boss装备奖励会轮换。",11,MUTED,HORIZONTAL_ALIGNMENT_CENTER))

func _toggle_music() -> void:
	muted = not muted
	if muted: map_music.stop(); battle_music.stop()
	else: _play_music(false)
	show_map()

func _unique(values: Array) -> Array:
	var result := []
	for value in values:
		if not result.has(value): result.append(value)
	return result

func _card_art(id: String) -> String:
	if id in ["strike","ward","foxfire","focus","moonfang","renewal","spiritCurrent","ashRecall"]: return "%s.jpg" % id
	return "new-cards-atlas-2.jpg"

func _card_color(card: Dictionary) -> Color:
	return {"Attack":Color("d95d37"),"Skill":Color("50b99b"),"Power":Color("a75bd6"),"Tactic":Color("4d9dd6")}.get(card.get("kind","Skill"),JADE)

func _rune_color(id: String, fallback: Color) -> Color:
	var rune := content.rune(id); return fallback if rune.is_empty() else Color(rune.color)

func _card_description(card: Dictionary) -> String:
	var parts := []
	for effect in card.effects:
		match effect.operation:
			"damage": parts.append("造成%d点伤害"%effect.amount)
			"shield": parts.append("获得%d点护盾"%effect.amount)
			"heal": parts.append("回复%d点生命"%effect.amount)
			"draw": parts.append("抽%d张牌"%effect.amount)
			"status": parts.append("施加%d层%s"%[effect.amount,"燃烧" if effect.status=="burn" else "凝神"])
	return "，".join(parts)
