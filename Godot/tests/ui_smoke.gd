extends SceneTree

var failures := 0

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
	root.add_child(game)
	await process_frame
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

	print("")
	if failures == 0: print("UI SMOKE: all checks passed")
	else: print("UI SMOKE: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)

func _find_text(node: Node, needle: String) -> bool:
	if node is Button and (node as Button).text == needle: return true
	for child in node.get_children():
		if _find_text(child, needle): return true
	return false
