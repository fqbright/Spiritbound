extends SceneTree

var failures := 0
var checks := 0
var content: SpiritContent

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)

func encounter(health := 40, damage := 7, adds := 0) -> Dictionary:
	return {"chapter":1,"level":1,"health":health,"damage":damage,"reward":20,"name":"测试守卫","art":"sentinel-v1.jpg","mechanics":{},"adds":adds,"background":0}

func run() -> void:
	content = SpiritContent.new()
	check(content.cards.size() >= 20,"all card definitions load")
	check(content.raw.startingDeck.size() == 25,"starting deck contains 25 cards")
	check(content.encounters.size() == 50,"campaign contains 50 stages")
	check(SpiritContent.EQUIPMENT.size() == 12,"twelve equipment definitions")
	check(SpiritContent.RUNES.size() == 10,"ten rune definitions")

	var battle := SpiritCombat.new(content)
	battle.create(42,encounter(),content.raw.startingDeck,60)
	check(battle.state.hand.size() == 5,"opening hand has five cards")
	check(battle.state.draw.size() == 20,"twenty cards remain in draw pile")
	var first_actions: int = battle.state.actions
	battle.play(0)
	check(battle.state.actions == first_actions - 1,"playing a card spends one action")

	var swift := SpiritCombat.new(content)
	swift.create(2,encounter(100,0),Array(content.raw.startingDeck),60,{},[],{"strike":"swift"})
	_force_hand(swift,"strike")
	swift.play(0,0)
	check(swift.state.actions == 2,"Swift refunds its first action")

	var chain := SpiritCombat.new(content)
	chain.create(3,encounter(20,0,1),Array(content.raw.startingDeck),60,{},[],{"strike":"chain"})
	_force_hand(chain,"strike")
	chain.play(0,0)
	check(chain.state.enemies[0].health == 14,"Chain deals full damage on primary target")
	check(chain.state.enemies[1].health == chain.state.enemies[1].max_health - 2,"Chain splashes forty percent")

	var cycle := SpiritCombat.new(content)
	cycle.create(4,encounter(100,0),Array(content.raw.startingDeck),60,{},[],{"ward":"cycle"})
	_force_hand(cycle,"ward")
	var uid: int = cycle.state.hand[0].uid
	cycle.play(0)
	check(cycle.state.draw[0].uid == uid,"Cycle places played card at draw pile bottom")

	var gear := SpiritCombat.new(content)
	gear.create(5,encounter(100,5),content.raw.startingDeck,60,{},["jadePlate","mistCloak"])
	check(gear.state.player.shield == 8,"Jade Plate grants opening shield")
	gear.end_turn(); gear.end_turn(); gear.end_turn()
	check(gear.state.player.health == 55,"Jade shield absorbs the first hit and Mist Cloak negates the third")

	var phoenix := SpiritCombat.new(content)
	phoenix.create(6,encounter(100,100),content.raw.startingDeck,60,{},["phoenixMail"])
	phoenix.end_turn()
	check(phoenix.state.player.health == 15 and phoenix.state.phase == "player","Phoenix Mail prevents one defeat")

	var profile := SpiritSave.defaults(content)
	check(profile.deck.size() == 25 and profile.equipment_slots.is_empty(),"new save schema is valid")

	check(content.text("card.strike", "zh-Hans") == "击打" and content.text("card.strike", "en") == "Strike", "bilingual card names work")
	check(content.ui("ui.battle_won", "zh-Hans") == "战斗胜利" and content.ui("ui.battle_won", "en") == "Victory", "bilingual UI text works")
	check(content.stage_name(0, "zh-Hans") == "雾林·入口" and content.stage_name(0, "en") == "Mistwood · Trailhead", "bilingual stage names work")
	check(content.equip_name(content.equipment("emberBlade"), "en") == "Ember Blade", "bilingual equipment works")
	check(content.rune_name(content.rune("swift"), "en") == "Swift", "bilingual runes work")

	var scn: PackedScene = load("res://Main.tscn")
	check(scn != null, "Main.tscn scene loads successfully")
	var game_inst: Control = scn.instantiate()
	check(game_inst != null, "Main scene instantiates")
	check(game_inst._get_character_texture("fox") is AtlasTexture, "character atlas texture slicing works for fox")
	check(game_inst._get_character_texture("sentinel") is AtlasTexture, "character atlas texture slicing works for sentinel")
	check(game_inst._get_card_texture("moonfang") is AtlasTexture, "card atlas 1 texture slicing works for moonfang")
	check(game_inst._get_card_texture("emberClaw") is AtlasTexture, "card atlas 2 texture slicing works for emberClaw")
	check(game_inst._get_card_texture("strike") != null, "card texture strike loads")
	game_inst.free()

	print("SPIRITBOUND TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _force_hand(battle: SpiritCombat, card_id: String) -> void:
	battle.state.hand = [{"uid":900,"card_id":card_id}]
