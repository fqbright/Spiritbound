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

	section("== map ==")
	game.show_map()
	await process_frame
	check(game.map_canvas != null, "map canvas built")
	check(game.map_canvas.custom_minimum_size.y > 4000.0, "map canvas spans all chapters")

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

	section("== deck ==")
	game.show_deck()
	await process_frame
	check(game.root.get_child_count() > 0, "deck page built")

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

	section("== shop ==")
	game.show_shop()
	await process_frame
	check(game.root.get_child_count() > 0, "shop page built")

	section("== camp ==")
	game.show_camp()
	await process_frame
	check(game.root.get_child_count() > 0, "camp page built")

	section("== battle ==")
	game.begin_battle(0)
	await process_frame
	check(game.combat != null, "combat created")
	check(game.combat.state.phase == "player", "battle starts on player phase")
	check(int(game.combat.state.actions) == 2, "two plays available")

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
	game._attempt_play_card(0, -1)
	await process_frame
	check(int(game.combat.state.actions) == 1, "first play consumed one action, left %d" % int(game.combat.state.actions))
	# Give the resolve coroutine (animations + enemy turn) time to finish.
	var waited := 0.0
	while game.resolving and waited < 8.0:
		await create_timer(0.1).timeout
		waited += 0.1
	game._attempt_play_card(0, -1)
	waited = 0.0
	while game.resolving and waited < 12.0:
		await create_timer(0.1).timeout
		waited += 0.1
	check(not game.resolving, "resolve finished")
	if game.combat.state.phase == "player":
		check(int(game.combat.state.turn) > turn_before, "turn advanced automatically after two plays (turn %d -> %d)" % [turn_before, int(game.combat.state.turn)])
		check(int(game.combat.state.actions) == 2, "plays refilled for the new turn")
	else:
		print("  note: battle ended during the test (phase %s), turn handoff not observable" % game.combat.state.phase)

	section("== no End Turn button ==")
	var found_end_turn := _find_text(game.root, game.content.ui("ui.end_turn", game.lang))
	check(not found_end_turn, "End Turn button is gone")

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
		check(game.selected_card == attack_slot, "tapping an attack card arms targeting instead of playing")
		check(game.combat.state.hand.size() == hand_before, "no card was played yet")
		game._tap_card(attack_slot)
		await process_frame
		check(game.selected_card == -1, "tapping the same card again cancels")

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
		check(game.combat.state.hand.size() == before_hand - 1, "non-targeted cards still play on a single tap")
		var w := 0.0
		while game.resolving and w < 10.0:
			await create_timer(0.1).timeout
			w += 0.1

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
	var chimed := SpiritCombat.new(game.content)
	chimed.create(11, game.content.encounters[0], game.content.raw.startingDeck, 60, {}, [], {}, {}, ["windChime"])
	check(chimed.state.hand.size() == plain.state.hand.size() + 2, "windChime draws 2 extra (%d vs %d)" % [chimed.state.hand.size(), plain.state.hand.size()])
	var charmed := SpiritCombat.new(game.content)
	charmed.create(11, game.content.encounters[0], game.content.raw.startingDeck, 60, {}, [], {}, {}, ["foxCharm"])
	check(int(charmed.state.actions) == 3, "foxCharm grants a third opening play, got %d" % int(charmed.state.actions))

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
