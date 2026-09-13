extends RefCounted
class_name SpiritCombat

signal event(kind: String, payload: Dictionary)

var content: SpiritContent
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init(game_content: SpiritContent) -> void:
	content = game_content

func create(seed: int, encounter: Dictionary, deck: Array, player_health: int, upgrades := {}, equipment := [], card_runes := {}, modifier := {}, relics := []) -> Dictionary:
	rng.seed = seed
	var health_scale: float = modifier.get("health_scale", 1.0)
	var damage_bonus: int = modifier.get("damage_bonus", 0)
	var enemies: Array = [_enemy("boss", encounter.name, str(encounter.get("name_en", encounter.name)), encounter.art, int(round(encounter.health * health_scale)), encounter.damage + damage_bonus, encounter.mechanics)]
	for add_index in encounter.adds + modifier.get("extra_enemy", 0):
		enemies.append(_enemy("add-%d" % add_index, "灵迹随从", "Spirit Minion", "ash-raven-v2.jpg" if add_index % 2 == 0 else "rune-shard-v2.jpg", int(round((9 + encounter.chapter) * health_scale)), 2 + encounter.chapter / 3 + damage_bonus, {}))
	var draw_pile: Array = []
	for i in deck.size(): draw_pile.append({"uid":i,"card_id":deck[i]})
	_shuffle(draw_pile)
	state = {
		"player":{"health":player_health,"max_health":60,"shield":0,"burn":0,"focus":0}, "enemies":enemies,
		"draw":draw_pile,"hand":[],"discard":[],"exhaust":[],"energy":3,"actions":2,"turn":1,"phase":"player",
		"upgrades":upgrades.duplicate(true),"equipment":equipment.duplicate(),"runes":card_runes.duplicate(true),
		"relics":relics.duplicate(),
		"swift_used":false,"first_attack":false,"moon_used":false,"elements":{},"mist_hits":0,"soul_heals":0,"phoenix_used":false,
		"revive_chance":modifier.get("revive",0.0),"revives":1 if modifier.get("revive",0.0) > 0 else 0,"modifier":modifier
	}
	if equipment.has("jadePlate"): state.player.shield += 8
	if equipment.has("focusCharm"): state.player.focus += 1
	if _has_relic("foxCharm"): state.actions += 1
	_draw(5 + (1 if equipment.has("tideCharm") else 0) + (2 if _has_relic("windChime") else 0))
	_plan_intents()
	return state

func _has_relic(id: String) -> bool:
	return state.get("relics", []).has(id)

# Intents are planned a turn ahead and executed exactly as telegraphed, so the icon the
# player reacts to always matches what actually lands.
func _plan_intents() -> void:
	for enemy in state.enemies:
		if enemy.health <= 0: continue
		enemy.intent = _roll_intent(enemy)

func _roll_intent(enemy: Dictionary) -> Dictionary:
	var damage: int = enemy.damage + (enemy.mechanics.get("below_half", 0) if enemy.health <= enemy.max_health / 2 else 0)
	if enemy.mechanics.get("critical_every", 0) > 0 and (enemy.attacks + 1) % enemy.mechanics.critical_every == 0:
		return {"kind":"critical","amount":damage * 2}

	var previous: String = str(enemy.get("intent", {}).get("kind", ""))
	var options: Array = [{"kind":"attack","amount":damage,"weight":12}]
	if enemy.mechanics.get("shield_per_turn", 0) > 0 or enemy.max_health >= 38:
		options.append({"kind":"defend","amount":maxi(4, int(enemy.max_health * 0.12)),"weight":4})
	if enemy.mechanics.get("enrage", 0) > 0 or enemy.max_health >= 52:
		options.append({"kind":"empower","amount":2,"weight":3})
	if enemy.max_health >= 30:
		options.append({"kind":"curse","amount":2,"weight":3})
	if enemy.max_health >= 46:
		options.append({"kind":"attack_defend","amount":maxi(1, int(round(damage * 0.65))),"shield":5,"weight":4})

	var total := 0
	for option in options:
		# Never telegraph the same non-attack intent twice running; it reads as the enemy stalling.
		if option.kind == previous and option.kind != "attack": option.weight = 1
		total += int(option.weight)
	var roll := rng.randi_range(0, maxi(0, total - 1))
	for option in options:
		roll -= int(option.weight)
		if roll < 0: return option
	return options[0]

func _execute_intent(enemy_index: int) -> void:
	var enemy: Dictionary = state.enemies[enemy_index]
	var intent: Dictionary = enemy.get("intent", {"kind":"attack","amount":enemy.damage})
	var kind := str(intent.get("kind", "attack"))
	match kind:
		"defend":
			enemy.shield += int(intent.amount)
			emit_signal("event","intent",{"enemy":enemy_index,"kind":kind,"amount":int(intent.amount)})
		"empower":
			enemy.damage += int(intent.amount)
			emit_signal("event","intent",{"enemy":enemy_index,"kind":kind,"amount":int(intent.amount)})
		"curse":
			state.player.burn += int(intent.amount)
			emit_signal("event","intent",{"enemy":enemy_index,"kind":kind,"amount":int(intent.amount)})
		_:
			var amount := int(intent.amount)
			if kind == "attack_defend": enemy.shield += int(intent.get("shield", 0))
			state.mist_hits += 1
			if state.equipment.has("mistCloak") and state.mist_hits % 3 == 0:
				amount = 0
				emit_signal("event","equipment",{"id":"mistCloak"})
			var taken := _damage_player(amount)
			enemy.attacks += 1
			if taken > 0 and state.equipment.has("thornArmor"):
				_damage_enemy(enemy_index, 2, false)
				emit_signal("event","equipment",{"id":"thornArmor"})

func play(hand_index: int, target_index := -1) -> bool:
	if state.phase != "player" or hand_index < 0 or hand_index >= state.hand.size(): return false
	var instance: Dictionary = state.hand[hand_index]
	var card := content.card(instance.card_id)
	if card.is_empty() or card.cost > state.energy or state.actions <= 0: return false
	var harmful := _is_attack(card)
	if harmful:
		target_index = _smart_target() if target_index < 0 else target_index
		if target_index < 0 or target_index >= state.enemies.size() or state.enemies[target_index].health <= 0: return false
	else: target_index = -1
	var rune: String = state.runes.get(card.id, "")
	state.energy -= card.cost
	state.actions -= 1
	if rune == "swift" and not state.swift_used: state.actions += 1; state.swift_used = true
	if card.get("kind","") == "Tactic" and state.equipment.has("moonStaff") and not state.moon_used: state.energy += 1; state.moon_used = true
	state.hand.remove_at(hand_index)
	if rune == "cycle" and not card.exhaust: state.draw.push_front(instance)
	elif card.exhaust: state.exhaust.append(instance)
	else: state.discard.append(instance)
	var bonus := int(state.upgrades.get(card.id,0))
	if harmful and state.player.focus > 0: bonus += 3 * state.player.focus; state.player.focus = 0
	if harmful and not state.first_attack:
		if state.equipment.has("emberBlade"): bonus += 3
		if _has_relic("starShard"): bonus += 2
	if harmful: state.first_attack = true
	var resonance := int(state.elements.get(card.get("element",""),0)) if rune == "resonance" else 0
	var dealt := _resolve_effects(card, target_index, bonus + resonance, 1.0)
	if rune == "echo" and state.phase == "player": dealt += _resolve_effects(card, target_index, bonus + resonance, .5)
	if rune == "chain" and harmful:
		var other := _other_target(target_index)
		if other >= 0: dealt += _damage_enemy(other, maxi(1, int(round(_base_damage(card, bonus + resonance) * .4))), false)
	if rune == "siphon" and dealt > 0: state.player.shield += maxi(1, int(dealt * .25))
	if rune == "burning" and harmful and state.enemies[target_index].health > 0: state.enemies[target_index].burn += 2
	if rune == "guardian": state.player.shield += 4
	if rune == "cleanse": state.player.burn = 0
	var element: String = card.get("element","")
	if not element.is_empty(): state.elements[element] = state.elements.get(element,0) + 1
	if card.get("special","") == "stun" and target_index >= 0: state.enemies[target_index].stun += 1
	if card.get("special","") == "recoverExhaust" and not state.exhaust.is_empty() and state.hand.size() < 10: state.hand.append(state.exhaust.pop_back())
	if card.get("special","") == "recycleDiscard":
		for i in mini(2,state.discard.size()): state.draw.push_front(state.discard.pop_back())
	emit_signal("event","card",{"card":card.id,"rune":rune,"target":target_index,"damage":dealt})
	return true

func end_turn() -> void:
	if state.phase != "player": return
	for enemy_index in state.enemies.size():
		var enemy: Dictionary = state.enemies[enemy_index]
		if enemy.health <= 0: continue
		enemy.shield = enemy.mechanics.get("shield_per_turn",0)
		enemy.health = mini(enemy.max_health, enemy.health + enemy.mechanics.get("regeneration",0))
		if enemy.stun > 0: enemy.stun -= 1
		else: _execute_intent(enemy_index)
		if enemy.burn > 0 and enemy.health > 0:
			var burn_damage: int = enemy.burn + (1 if _has_relic("emberCore") else 0)
			_damage_enemy(enemy_index,burn_damage,false)
			enemy.burn = maxi(0,enemy.burn - 1)
		if state.phase != "player": return
		enemy.damage += enemy.mechanics.get("enrage",0)

	if state.player.burn > 0:
		var self_burn: int = state.player.burn
		state.player.health = maxi(0, state.player.health - self_burn)
		state.player.burn = maxi(0, self_burn - 1)
		emit_signal("event","player_burn",{"amount":self_burn})
		if state.player.health <= 0:
			state.phase = "lost"
			return

	state.turn += 1
	state.energy = 3
	state.actions = 2
	state.player.shield = int(state.player.shield / 2) if _has_relic("mirrorScale") else 0
	if _has_relic("ancientSeed"): state.player.health = mini(state.player.max_health, state.player.health + 2)
	if _has_relic("thunderSeal") and state.turn % 3 == 0: state.energy += 2
	state.swift_used = false; state.first_attack = false; state.moon_used = false; state.elements = {}
	_draw(maxi(0,5 - state.hand.size()))
	_plan_intents()
	emit_signal("event","turn",{"turn":state.turn})

func _resolve_effects(card: Dictionary, target_index: int, bonus: int, scale: float) -> int:
	var dealt := 0
	for effect in card.effects:
		var amount := maxi(1,int(round((effect.amount + bonus if effect.operation == "damage" else effect.amount + int(state.upgrades.get(card.id,0))) * scale)))
		match effect.operation:
			"damage":
				var targets := range(state.enemies.size()) if card.get("special","") == "cleave" else [target_index]
				for index in targets:
					if state.enemies[index].health <= 0: continue
					var execute := 1.5 if state.runes.get(card.id,"") == "execute" and state.enemies[index].health <= state.enemies[index].max_health * .25 else 1.0
					var critical := 2 if card.get("special","") == "critical" else 1
					dealt += _damage_enemy(index,int(round(amount * execute * critical)),card.get("special","") == "pierce" or state.equipment.has("stoneSpear"))
			"shield": state.player.shield += amount
			"heal": state.player.health = mini(state.player.max_health,state.player.health + amount)
			"draw": _draw(amount)
			"energy": state.energy += amount
			"status":
				if effect.target == "actor": state.player[effect.status] = state.player.get(effect.status,0) + amount
				elif target_index >= 0: state.enemies[target_index][effect.status] = state.enemies[target_index].get(effect.status,0) + amount
	return dealt

func _damage_enemy(index: int, amount: int, pierce: bool) -> int:
	if index < 0 or index >= state.enemies.size(): return 0
	var enemy: Dictionary = state.enemies[index]
	if enemy.health <= 0: return 0
	enemy.hits += 1
	if enemy.mechanics.get("dodge_every",0) > 0 and enemy.hits % enemy.mechanics.dodge_every == 0: emit_signal("event","dodge",{"enemy":index}); return 0
	var absorbed := 0 if pierce else mini(enemy.shield,amount)
	enemy.shield -= absorbed
	var dealt := mini(enemy.health,amount - absorbed)
	enemy.health -= dealt
	if enemy.health <= 0:
		if not enemy.revived and state.revives > 0 and rng.randf() < state.revive_chance:
			enemy.health = maxi(1,int(ceil(enemy.max_health * .35))); enemy.revived = true; state.revives -= 1
			emit_signal("event","revive",{"enemy":index,"amount":enemy.health}); return dealt
		emit_signal("event","death",{"enemy":index})
		if state.equipment.has("soulPendant") and state.soul_heals < 3: state.player.health = mini(state.player.max_health,state.player.health + 2); state.soul_heals += 1
		if state.equipment.has("stormBow"): _draw(1)
		if _has_relic("bloodJade"): state.player.health = mini(state.player.max_health, state.player.health + 3)
		if _living_count() == 0: state.phase = "won"
	else: emit_signal("event","hit",{"enemy":index,"amount":dealt})
	return dealt

func _damage_player(amount: int) -> int:
	var absorbed := mini(state.player.shield,amount)
	state.player.shield -= absorbed
	var dealt := mini(state.player.health,amount - absorbed)
	state.player.health -= dealt
	if state.player.health <= 0:
		if state.equipment.has("phoenixMail") and not state.phoenix_used: state.player.health = 15; state.phoenix_used = true; emit_signal("event","equipment",{"id":"phoenixMail"})
		else: state.phase = "lost"
	emit_signal("event","player_hit",{"amount":dealt})
	return dealt

func _draw(count: int) -> void:
	for i in count:
		if state.hand.size() >= 10: return
		if state.draw.is_empty():
			if state.discard.is_empty(): return
			state.draw = state.discard.duplicate()
			state.discard.clear()
			_shuffle(state.draw)
		state.hand.append(state.draw.pop_back())

func _shuffle(cards: Array) -> void:
	for i in range(cards.size() - 1,0,-1):
		var j := rng.randi_range(0,i)
		var value = cards[i]; cards[i] = cards[j]; cards[j] = value

func _enemy(id: String, title: String, title_en: String, art: String, health: int, damage: int, mechanics: Dictionary) -> Dictionary:
	return {"id":id,"name":title,"name_en":title_en,"art":art,"health":health,"max_health":health,"shield":mechanics.get("shield_per_turn",0),"damage":damage,"burn":0,"stun":0,"attacks":0,"hits":0,"revived":false,"intent":{},"mechanics":mechanics.duplicate(true)}

func _is_attack(card: Dictionary) -> bool:
	for effect in card.effects:
		if effect.operation == "damage" and effect.target == "opponent": return true
	return false

func _base_damage(card: Dictionary, bonus: int) -> int:
	var total := 0
	for effect in card.effects:
		if effect.operation == "damage": total += effect.amount + bonus
	return total

func _smart_target() -> int:
	var result := -1
	for i in state.enemies.size():
		if state.enemies[i].health > 0 and (result < 0 or state.enemies[i].health < state.enemies[result].health): result = i
	return result

func _other_target(excluded: int) -> int:
	for i in state.enemies.size():
		if i != excluded and state.enemies[i].health > 0: return i
	return -1

func _living_count() -> int:
	var result := 0
	for enemy in state.enemies:
		if enemy.health > 0: result += 1
	return result
