extends RefCounted
class_name SpiritCombat

signal event(kind: String, payload: Dictionary)

var content: SpiritContent
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init(game_content: SpiritContent) -> void:
	content = game_content

func create(seed: int, encounter: Dictionary, deck: Array, player_health: int, upgrades := {}, equipment := [], card_runes := {}, modifier := {}, relics := [], hero_bonuses := {}) -> Dictionary:
	rng.seed = seed
	var health_scale: float = modifier.get("health_scale", 1.0)
	var damage_bonus: int = modifier.get("damage_bonus", 0)
	# Only the Daily Trial's "double damage" tag ever sets this — a straight multiplier applied
	# after the flat bonus above, to the boss and its adds alike.
	var damage_mult: float = modifier.get("damage_mult", 1.0)
	var enemies: Array = [_enemy("boss", encounter.name, str(encounter.get("name_en", encounter.name)), encounter.art, int(round(encounter.health * health_scale)), int(round((encounter.damage + damage_bonus) * damage_mult)), encounter.mechanics)]
	for add_index in encounter.adds + modifier.get("extra_enemy", 0):
		enemies.append(_enemy("add-%d" % add_index, "灵迹随从", "Spirit Minion", "ash-raven-v2.jpg" if add_index % 2 == 0 else "rune-shard-v2.jpg", int(round((9 + encounter.chapter) * health_scale)), int(round((2 + encounter.chapter / 3 + damage_bonus) * damage_mult)), {}))
	var draw_pile: Array = []
	for i in deck.size(): draw_pile.append({"uid":i,"card_id":deck[i]})
	_shuffle(draw_pile)
	state = {
		"player":{"health":player_health,"max_health":60,"shield":0,"burn":0,"focus":0,"strength":0}, "enemies":enemies,
		"draw":draw_pile,"hand":[],"discard":[],"exhaust":[],"energy":2,"turn":1,"phase":"player",
		"upgrades":upgrades.duplicate(true),"equipment":equipment.duplicate(),"runes":card_runes.duplicate(true),
		"relics":relics.duplicate(),
		"boons":modifier.get("boons",[]).duplicate(),
		"rune_sets":content.active_rune_sets(card_runes),
		"gale_used":false,
		"swift_used":false,"first_attack":false,"moon_used":false,"tide_used":false,"elements":{},"mist_hits":0,"soul_heals":0,"phoenix_used":false,
		"revive_chance":modifier.get("revive",0.0),"revives":1 if modifier.get("revive",0.0) > 0 else 0,"modifier":modifier,
		"hero_bonuses":hero_bonuses.duplicate(true),
		"encounter":encounter.duplicate(true),
		"is_great_boss":bool(encounter.get("is_great_boss", false)),
		"chapter":int(encounter.get("chapter", 1)),
		"last_element":"",
		"stats":{"damage_dealt":0,"cards_played":0,"shield_gained":0}
	}
	if not enemies.is_empty():
		enemies[0]["is_great_boss"] = state.is_great_boss
		enemies[0]["phase"] = 1
		enemies[0]["phase_triggered"] = false
	if equipment.has("jadePlate"): state.player.shield += 8
	if equipment.has("focusCharm"): state.player.focus += 1
	if _has_relic("titanBell"):
		state.player.max_health += 20
		state.player.health += 20
		state.player.shield += 15
	if _has_relic("chaosPrism"):
		for enemy in state.enemies:
			enemy.shield += 6
	# Hero Mastery: small always-on bonuses from the active hero's permanent Lv1-5 perks —
	# the same battle-start/first-attack/per-turn hooks relics and equipment already use
	# (see _resolve_effects, play(), end_turn()), just keyed off save-file progression
	# (content.gd's mastery_bonuses()) instead of an item the player is carrying.
	var mastery_max_hp: int = int(hero_bonuses.get("max_hp", 0))
	if mastery_max_hp > 0:
		state.player.max_health += mastery_max_hp
		state.player.health += mastery_max_hp
	state.player.shield += int(hero_bonuses.get("shield_start", 0))
	state.player.strength += int(hero_bonuses.get("strength_start", 0))
	state.player.focus += int(hero_bonuses.get("focus_start", 0))
	state.energy += int(hero_bonuses.get("energy_turn1", 0))
	for enemy in state.enemies:
		if int(hero_bonuses.get("burn_start", 0)) > 0: enemy.burn += int(hero_bonuses.burn_start)
		if int(hero_bonuses.get("vulnerable_start", 0)) > 0: enemy.vulnerable += int(hero_bonuses.vulnerable_start)
		if int(hero_bonuses.get("poison_start", 0)) > 0: enemy.poison = int(enemy.get("poison", 0)) + int(hero_bonuses.poison_start)
	# Turn 1 is strictly 2 energy and 5 cards under all conditions, except cursedTome's own
	# explicit "+1 draw / -2 HP every turn" and optional draw_turn1 elixir bonus.
	var draw_bonus: int = int(hero_bonuses.get("draw_turn1", 0))
	_draw(5 + draw_bonus + (1 if _has_relic("cursedTome") else 0))
	if _has_relic("cursedTome"): _damage_player(2)
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
			var curse_id := "decay_blight" if rng.randf() < 0.5 else "void_curse"
			state.discard.append({"card_id": curse_id})
			emit_signal("event","intent",{"enemy":enemy_index,"kind":kind,"amount":int(intent.amount),"curse":curse_id})
		_:
			var amount := int(intent.amount)
			if kind == "attack_defend": enemy.shield += int(intent.get("shield", 0))
			# Weak is the counterplay to enrage/damage-scaling mechanics: without it a late
			# stage's damage growth is unstoppable, no matter how good the deck is.
			if int(enemy.get("weak", 0)) > 0: amount = maxi(1, int(round(amount * 0.75)))
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
	if card.is_empty() or card.cost > state.energy: return false
	# harmful drives the damage bonuses; needs_enemy drives targeting. A pure debuff needs a
	# target but must not burn Focus or the first-attack bonuses.
	var harmful := _is_attack(card)
	if _targets_opponent(card):
		target_index = _smart_target() if target_index < 0 else target_index
		if target_index < 0 or target_index >= state.enemies.size() or state.enemies[target_index].health <= 0: return false
	else: target_index = -1
	var rune: String = state.runes.get(card.id, "")
	state.energy -= card.cost
	if state.has("stats"): state.stats.cards_played = int(state.stats.get("cards_played", 0)) + 1
	# Plays are gated by energy alone now, so Swift's "first play is free" reads as refunding
	# that play's own cost rather than an action slot that no longer exists.
	if rune == "swift" and not state.swift_used: state.energy += card.cost; state.swift_used = true
	if card.get("kind","") == "Tactic" and state.equipment.has("moonStaff") and not state.moon_used: state.energy += 1; state.moon_used = true
	if state.get("rune_sets", []).has("set_gale") and not state.gale_used and (rune == "cycle" or _has_draw_effect(card)):
		state.energy += 1
		state.gale_used = true
	state.hand.remove_at(hand_index)
	if rune == "cycle" and not card.exhaust: state.draw.push_front(instance)
	elif card.exhaust: state.exhaust.append(instance)
	else: state.discard.append(instance)
	var bonus := int(state.upgrades.get(card.id,0))
	# Strength is the permanent counterpart to Focus's one-shot burst: it never resets, so
	# a Power card that grants it pays off over the whole fight rather than a single hit.
	if harmful: bonus += int(state.player.get("strength", 0))
	if harmful and state.player.focus > 0: bonus += 3 * state.player.focus; state.player.focus = 0
	if harmful and not state.first_attack:
		if state.equipment.has("emberBlade"): bonus += 3
		if _has_relic("starShard"): bonus += 2
		if state.get("boons", []).has("boon_spirit_surge"): bonus += 4
		bonus += int(state.get("hero_bonuses", {}).get("first_attack_bonus", 0))
	if harmful: state.first_attack = true
	var resonance := int(state.elements.get(card.get("element",""),0)) if rune == "resonance" else 0
	var dealt := _resolve_effects(card, target_index, bonus + resonance, 1.0)
	if rune == "echo" and state.phase == "player": dealt += _resolve_effects(card, target_index, bonus + resonance, .5)
	if rune == "chain" and harmful:
		var other := _other_target(target_index)
		if other >= 0: dealt += _damage_enemy(other, maxi(1, int(round(_base_damage(card, bonus + resonance) * .4))), false)
	if rune == "siphon" and dealt > 0:
		var siphoned: int = maxi(1, int(dealt * .25))
		state.player.shield += siphoned
		if state.has("stats"): state.stats.shield_gained = int(state.stats.get("shield_gained", 0)) + siphoned
	if rune == "burning" and harmful and state.enemies[target_index].health > 0 and not state.enemies[target_index].mechanics.get("burn_immune", false): state.enemies[target_index].burn += 2
	if rune == "guardian":
		state.player.shield += 4
		if state.has("stats"): state.stats.shield_gained = int(state.stats.get("shield_gained", 0)) + 4
	if rune == "cleanse": state.player.burn = 0
	var element: String = card.get("element","")
	if not element.is_empty():
		state.elements[element] = state.elements.get(element,0) + 1
		var prev_element: String = str(state.get("last_element", ""))
		if not prev_element.is_empty():
			if (prev_element == "fire" and element in ["spirit", "gale"]) or (prev_element in ["spirit", "gale"] and element == "fire"):
				# Combustion: deals 3 splash damage to other living enemies
				for enemy_idx in state.enemies.size():
					if enemy_idx != target_index and state.enemies[enemy_idx].health > 0:
						_damage_enemy(enemy_idx, 3, false)
				emit_signal("event", "resonance", {"type": "combustion", "amount": 3})
			elif (prev_element == "water" and element in ["stone", "poison"]) or (prev_element in ["stone", "poison"] and element == "water"):
				# Sunder: strips up to 5 shield and inflicts 1 vulnerable on target
				if target_index >= 0 and state.enemies[target_index].health > 0:
					var stripped: int = mini(5, int(state.enemies[target_index].shield))
					state.enemies[target_index].shield = maxi(0, int(state.enemies[target_index].shield) - stripped)
					state.enemies[target_index].vulnerable = int(state.enemies[target_index].get("vulnerable", 0)) + 1
					emit_signal("event", "resonance", {"type": "sunder", "target": target_index})
			elif (prev_element == "stone" and element in ["spirit", "stone"]) or (prev_element == "spirit" and element == "stone"):
				# Fortify: grants player +4 shield
				state.player.shield += 4
				if state.has("stats"): state.stats.shield_gained = int(state.stats.get("shield_gained", 0)) + 4
				emit_signal("event", "resonance", {"type": "fortify", "amount": 4})
		state.last_element = element
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
		# Poison is Burn's non-decaying counterpart — Miasma Witch's whole identity is that it
		# keeps ticking every turn until the target is healed or dies, not worn down by 1 each
		# turn the way Burn is. Deliberately no "poison = maxi(0, poison - 1)" line here.
		if int(enemy.get("poison", 0)) > 0 and enemy.health > 0:
			_damage_enemy(enemy_index, int(enemy.poison), false)
		if int(enemy.get("vulnerable",0)) > 0: enemy.vulnerable = maxi(0, int(enemy.vulnerable) - 1)
		if int(enemy.get("weak",0)) > 0: enemy.weak = maxi(0, int(enemy.weak) - 1)
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

	# Curse cards punish holding onto them rather than resolving on their own: decay_blight
	# pokes for 3 every turn it survives in hand (deliberately does NOT clear itself — playing
	# it for its own exhaust, or a Purify Altar/Shop Purge, is the actual way to get rid of
	# it), while void_curse is already unplayable at 99 cost and just clears itself out.
	for instance in state.hand:
		if str(instance.card_id) == "decay_blight":
			_damage_player(3)
			if state.phase != "player": return
	var kept_hand: Array = []
	for instance in state.hand:
		if str(instance.card_id) == "void_curse": state.exhaust.append(instance)
		else: kept_hand.append(instance)
	state.hand = kept_hand

	state.turn += 1
	# Energy opens at 2 and climbs by 1 every two turns (turns 1-2 -> 2, 3-4 -> 3, 5-6 -> 4, ...)
	# instead of a flat amount, so a long fight gradually loosens up rather than staying as
	# tight on turn 20 as it was on turn 1. titanBell trades that growth away entirely (its
	# own "-1 energy cap every 2 turns" exactly cancels the climb, floored at the opening 2
	# rather than actually going negative) in exchange for the big battle-start HP/shield
	# it already grants in create().
	var energy_growth: int = int((state.turn - 1) / 2)
	if _has_relic("titanBell"): energy_growth = 0
	state.energy = 2 + energy_growth
	if _has_relic("foxCharm") and state.turn == 2: state.energy += 1
	state.player.shield = int(state.player.shield / 2) if _has_relic("mirrorScale") else 0
	if state.get("boons", []).has("boon_iron_core"): state.player.shield += 5
	if _has_relic("ancientSeed"): state.player.health = mini(state.player.max_health, state.player.health + 2)
	var mastery_heal: int = int(state.get("hero_bonuses", {}).get("heal_per_turn", 0))
	if mastery_heal > 0: state.player.health = mini(state.player.max_health, state.player.health + mastery_heal)
	if _has_relic("thunderSeal") and state.turn % 3 == 0: state.energy += 2
	state.swift_used = false; state.first_attack = false; state.moon_used = false; state.tide_used = false; state.gale_used = false; state.elements = {}; state.last_element = ""
	# A fixed 2-card draw each turn (+1 if wind stride boon active, +1 again if cursedTome —
	# its own -2 HP cost applies every turn it is held, same as the turn-1 setup above).
	_draw(2 + (1 if state.get("boons", []).has("boon_wind_stride") else 0) + (1 if _has_relic("cursedTome") else 0))
	if _has_relic("cursedTome"):
		_damage_player(2)
		if state.phase != "player": return
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
					# Flame Resonance rewards hitting a target that is already burning, rather
					# than boosting burn's own damage tick — it only applies to a card actually
					# landing a hit, checked per target since cleave can hit a mix of burning
					# and non-burning enemies in the same swing.
					var flame_bonus := 3 if state.get("rune_sets", []).has("set_flame") and int(state.enemies[index].get("burn", 0)) > 0 else 0
					var hit := _damage_enemy(index,int(round(amount * execute * critical)) + flame_bonus,card.get("special","") == "pierce" or state.equipment.has("stoneSpear"))
					dealt += hit
					# chaosPrism's payoff for the +6 enemy shield it hands out at battle start:
					# every attack that actually lands stacks Vulnerable, snowballing the rest
					# of the fight once that opening shield is chewed through.
					if hit > 0 and _has_relic("chaosPrism") and state.enemies[index].health > 0:
						state.enemies[index].vulnerable = int(state.enemies[index].get("vulnerable", 0)) + 1
			"shield":
				var shield_gain := amount
				if state.get("rune_sets", []).has("set_stone") and rng.randf() < 0.25:
					shield_gain = int(round(shield_gain * 1.5))
					emit_signal("event","rune_set",{"id":"set_stone"})
				state.player.shield += shield_gain
				if state.has("stats"): state.stats.shield_gained = int(state.stats.get("shield_gained", 0)) + shield_gain
				if state.equipment.has("tideCharm") and not state.tide_used:
					state.tide_used = true
					_draw(1)
			"heal": state.player.health = mini(state.player.max_health,state.player.health + amount)
			"draw": _draw(amount)
			"energy": state.energy += amount
			"status":
				var final_amt: int = amount
				if effect.status == "burn" and target_index >= 0 and bool(state.enemies[target_index].mechanics.get("burn_immune", false)):
					final_amt = 0
				elif effect.status == "burn" and state.get("boons", []).has("boon_flame_affinity"): final_amt += 2
				if final_amt > 0:
					if effect.target == "actor": state.player[effect.status] = state.player.get(effect.status,0) + final_amt
					elif target_index >= 0: state.enemies[target_index][effect.status] = state.enemies[target_index].get(effect.status,0) + final_amt
	return dealt

func _damage_enemy(index: int, amount: int, pierce: bool) -> int:
	if index < 0 or index >= state.enemies.size(): return 0
	var enemy: Dictionary = state.enemies[index]
	if enemy.health <= 0: return 0
	enemy.hits += 1
	if enemy.mechanics.get("dodge_every",0) > 0 and enemy.hits % enemy.mechanics.dodge_every == 0: emit_signal("event","dodge",{"enemy":index}); return 0
	if int(enemy.mechanics.get("frost_armor", 0)) > 0:
		amount = maxi(1, amount - int(enemy.mechanics.frost_armor))
	# Vulnerable is the counterplay to armor-heavy late enemies: raw damage scales up before
	# shield absorption, same slot in the pipeline pierce and Stone Spear already use.
	if int(enemy.get("vulnerable", 0)) > 0: amount = int(round(amount * 1.5))
	var absorbed := 0 if pierce else mini(enemy.shield,amount)
	enemy.shield -= absorbed
	var dealt := mini(enemy.health,amount - absorbed)
	enemy.health -= dealt
	if state.has("stats"): state.stats.damage_dealt = int(state.stats.get("damage_dealt", 0)) + (dealt + absorbed)
	if index == 0 and bool(state.get("is_great_boss", false)) and not bool(enemy.get("phase_triggered", false)) and enemy.health > 0 and enemy.health <= enemy.max_health / 2:
		_trigger_great_boss_phase_2(enemy)
	# Thorns was carried as encounter data since the 50-stage version but never actually
	# consulted anywhere — every "thorns" enemy fought identically to one with no mechanic.
	if dealt > 0 and int(enemy.mechanics.get("thorns", 0)) > 0:
		_damage_player(int(enemy.mechanics.thorns))
		emit_signal("event","thorns",{"enemy":index,"amount":int(enemy.mechanics.thorns)})
	if enemy.health <= 0:
		if not enemy.revived and state.revives > 0 and rng.randf() < state.revive_chance:
			enemy.health = maxi(1,int(ceil(enemy.max_health * .35))); enemy.revived = true; state.revives -= 1
			emit_signal("event","revive",{"enemy":index,"amount":enemy.health}); return dealt
		emit_signal("event","death",{"enemy":index})
		if state.equipment.has("soulPendant") and state.soul_heals < 3: state.player.health = mini(state.player.max_health,state.player.health + 2); state.soul_heals += 1
		if state.equipment.has("stormBow"): _draw(1)
		if _has_relic("bloodJade"): state.player.health = mini(state.player.max_health, state.player.health + 3)
		if state.get("boons", []).has("boon_blood_lust"): state.player.health = mini(state.player.max_health, state.player.health + 8)
		if _living_count() == 0: state.phase = "won"
	else: emit_signal("event","hit",{"enemy":index,"amount":dealt})
	return dealt

func _trigger_great_boss_phase_2(enemy: Dictionary) -> void:
	enemy.phase = 2
	enemy.phase_triggered = true
	var chapter: int = int(state.get("chapter", 1))
	match chapter:
		10:
			enemy.damage += 4
			enemy.burn = 0
			enemy.mechanics.burn_immune = true
			state.player.burn = int(state.player.get("burn", 0)) + 3
			emit_signal("event", "boss_phase", {"chapter": 10, "phase": 2, "name": "烬火狂怒", "name_en": "Ember Berserk", "desc": "攻击力提升4点，获得灼烧免疫，点燃玩家！", "desc_en": "+4 Damage, Burn Immunity, inflicts 3 Burn on player!"})
		20:
			enemy.shield += 25
			enemy.mechanics.frost_armor = 2
			emit_signal("event", "boss_phase", {"chapter": 20, "phase": 2, "name": "寒霜要塞", "name_en": "Glacial Bastion", "desc": "获得25点坚冰护盾，受到攻击伤害减少2点！", "desc_en": "Gains 25 Frost Shield, reduces all incoming damage by 2!"})
		30:
			state.player.vulnerable = int(state.player.get("vulnerable", 0)) + 2
			if state.enemies.size() < 3:
				var clone: Dictionary = _enemy("boss_clone", "暗影化身", "Shadow Avatar", "void-fiend-v2.jpg", maxi(10, int(round(enemy.max_health * 0.35))), maxi(2, int(round(enemy.damage * 0.5))), {})
				state.enemies.append(clone)
			emit_signal("event", "boss_phase", {"chapter": 30, "phase": 2, "name": "暗影分身", "name_en": "Shadow Legion", "desc": "召唤暗影化身协助作战，使玩家获得2层易伤！", "desc_en": "Summons a Shadow Clone, inflicts 2 Vulnerable on player!"})
		40:
			enemy.mechanics.dodge_every = 2
			state.player.weak = int(state.player.get("weak", 0)) + 2
			emit_signal("event", "boss_phase", {"chapter": 40, "phase": 2, "name": "风暴领域", "name_en": "Cyclone Domain", "desc": "开启风暴护体每2次受击闪避1次，使玩家陷入2层虚弱！", "desc_en": "Gains Dodge every 2 hits, inflicts 2 Weak on player!"})
		50:
			enemy.burn = 0
			enemy.poison = 0
			enemy.vulnerable = 0
			enemy.weak = 0
			var drained := _damage_player(6)
			enemy.health = mini(enemy.max_health, enemy.health + drained)
			state.draw.push_front({"uid": 9999, "card_id": "void_curse"})
			emit_signal("event", "boss_phase", {"chapter": 50, "phase": 2, "name": "深渊觉醒", "name_en": "Abyssal Awakening", "desc": "净化全部弱化状态，汲取玩家6点生命，注入虚空诅咒！", "desc_en": "Cleanses all debuffs, drains 6 HP from player, injects Void Curse!"})
		_:
			enemy.damage += 3
			enemy.shield += 15
			emit_signal("event", "boss_phase", {"chapter": chapter, "phase": 2, "name": "首领狂怒", "name_en": "Boss Enrage", "desc": "首领生命过半，进入二阶段狂暴！", "desc_en": "Boss health below half, enters Phase 2 Enrage!"})

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
			if _has_relic("windChime") and state.hand.size() < 10 and not state.draw.is_empty():
				_draw_one()
		_draw_one()

# Pulled out of _draw's loop body so both the normal draw and windChime's bonus draw run the
# same "a curse card punishes you the moment it's drawn" check exactly once per card, instead
# of duplicating it at both call sites.
func _draw_one() -> void:
	var instance: Dictionary = state.draw.pop_back()
	state.hand.append(instance)
	if str(instance.card_id) == "void_curse": _damage_player(2)

func _shuffle(cards: Array) -> void:
	for i in range(cards.size() - 1,0,-1):
		var j := rng.randi_range(0,i)
		var value = cards[i]; cards[i] = cards[j]; cards[j] = value

func _enemy(id: String, title: String, title_en: String, art: String, health: int, damage: int, mechanics: Dictionary) -> Dictionary:
	return {"id":id,"name":title,"name_en":title_en,"art":art,"health":health,"max_health":health,"shield":mechanics.get("shield_per_turn",0),"damage":damage,"burn":0,"poison":0,"stun":0,"vulnerable":0,"weak":0,"attacks":0,"hits":0,"revived":false,"intent":{},"mechanics":mechanics.duplicate(true)}

func _is_attack(card: Dictionary) -> bool:
	for effect in card.effects:
		if effect.operation == "damage" and effect.target == "opponent": return true
	return false

# Whether the card needs an enemy at all. Wider than _is_attack, which only counts damage:
# a card that only applies Burn was being played with no target, and _resolve_effects drops
# opponent statuses when target_index is -1, so those cards silently did nothing.
func _targets_opponent(card: Dictionary) -> bool:
	for effect in card.effects:
		if effect.get("target", "") == "opponent": return true
	return false

# Gale Resonance's "first cycle/draw each turn" bonus needs to recognize plain draw cards
# (spiritCurrent, etc.), not just the "cycle" rune — a card can have a draw effect without
# being socketed with cycle at all.
func _has_draw_effect(card: Dictionary) -> bool:
	for effect in card.effects:
		if effect.operation == "draw": return true
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

func preview_card_damage(hand_index: int, target_index: int) -> int:
	if state.phase != "player" or hand_index < 0 or hand_index >= state.hand.size(): return 0
	if target_index < 0 or target_index >= state.enemies.size(): return 0
	var enemy: Dictionary = state.enemies[target_index]
	if enemy.health <= 0: return 0
	var instance: Dictionary = state.hand[hand_index]
	var card: Dictionary = content.card(instance.card_id)
	if card.is_empty() or not _is_attack(card): return 0
	var rune: String = state.runes.get(card.id, "")
	var bonus := int(state.upgrades.get(card.id, 0))
	bonus += int(state.player.get("strength", 0))
	if state.player.focus > 0: bonus += 3 * state.player.focus
	if not state.first_attack:
		if state.equipment.has("emberBlade"): bonus += 3
		if _has_relic("starShard"): bonus += 2
		if state.get("boons", []).has("boon_spirit_surge"): bonus += 4
		bonus += int(state.get("hero_bonuses", {}).get("first_attack_bonus", 0))
	var resonance := int(state.elements.get(card.get("element", ""), 0)) if rune == "resonance" else 0
	var total_dealt := 0
	var temp_shield: int = enemy.shield
	var temp_hp: int = enemy.health
	var pierce: bool = card.get("special", "") == "pierce" or state.equipment.has("stoneSpear")

	for effect in card.effects:
		if effect.operation != "damage": continue
		var amount := maxi(1, int(round((effect.amount + bonus + resonance) * 1.0)))
		var execute := 1.5 if rune == "execute" and temp_hp <= enemy.max_health * 0.25 else 1.0
		var critical := 2 if card.get("special", "") == "critical" else 1
		var hit_amount := int(round(amount * execute * critical))
		if int(enemy.get("vulnerable", 0)) > 0: hit_amount = int(round(hit_amount * 1.5))
		if int(enemy.mechanics.get("frost_armor", 0)) > 0: hit_amount = maxi(1, hit_amount - int(enemy.mechanics.frost_armor))
		var absorbed := 0 if pierce else mini(temp_shield, hit_amount)
		temp_shield -= absorbed
		var dealt := mini(temp_hp, hit_amount - absorbed)
		temp_hp -= dealt
		total_dealt += dealt

	if rune == "echo":
		for effect in card.effects:
			if effect.operation != "damage": continue
			var amount := maxi(1, int(round((effect.amount + bonus + resonance) * 0.5)))
			var execute := 1.5 if rune == "execute" and temp_hp <= enemy.max_health * 0.25 else 1.0
			var critical := 2 if card.get("special", "") == "critical" else 1
			var hit_amount := int(round(amount * execute * critical))
			if int(enemy.get("vulnerable", 0)) > 0: hit_amount = int(round(hit_amount * 1.5))
			if int(enemy.mechanics.get("frost_armor", 0)) > 0: hit_amount = maxi(1, hit_amount - int(enemy.mechanics.frost_armor))
			var absorbed := 0 if pierce else mini(temp_shield, hit_amount)
			temp_shield -= absorbed
			var dealt := mini(temp_hp, hit_amount - absorbed)
			temp_hp -= dealt
			total_dealt += dealt

	return total_dealt

func is_lethal(hand_index: int, target_index: int) -> bool:
	if target_index < 0 or target_index >= state.enemies.size(): return false
	var enemy: Dictionary = state.enemies[target_index]
	if enemy.health <= 0: return false
	return preview_card_damage(hand_index, target_index) >= enemy.health

func total_incoming_damage() -> int:
	var total := 0
	for enemy in state.enemies:
		if enemy.health <= 0: continue
		var intent: Dictionary = enemy.get("intent", {})
		var kind: String = str(intent.get("kind", ""))
		var amount: int = int(intent.get("amount", 0))
		if kind in ["attack", "attack_defend", "critical"]:
			if int(enemy.get("weak", 0)) > 0: amount = int(round(amount * 0.75))
			if int(state.player.get("vulnerable", 0)) > 0: amount = int(round(amount * 1.5))
			total += amount
	return total

func ai_best_play() -> Dictionary:
	if state.phase != "player" or state.hand.is_empty():
		return {"hand_index": -1, "target_index": -1}

	var incoming := total_incoming_damage()
	var player_shield: int = int(state.player.shield)
	var player_hp: int = int(state.player.health)
	var shield_deficit: int = maxi(0, incoming - player_shield)

	var best_idx := -1
	var best_target := -1
	var best_score := -99999.0

	for i in state.hand.size():
		var instance: Dictionary = state.hand[i]
		var card: Dictionary = content.card(instance.card_id)
		if card.is_empty() or int(card.cost) > state.energy: continue

		var score: float = 0.0
		var target := -1
		var is_atk: bool = _is_attack(card)
		var targets_opp: bool = _targets_opponent(card)

		if targets_opp:
			target = _smart_target()
			if target < 0: continue

		var card_shield := 0
		var card_heal := 0
		for effect in card.effects:
			if effect.operation == "shield": card_shield += int(effect.amount)
			elif effect.operation == "heal": card_heal += int(effect.amount)

		# 1. Survival defense when incoming damage exceeds current shield
		if shield_deficit > 0 and card_shield > 0:
			score += minf(float(card_shield), float(shield_deficit)) * 4.5
		if player_hp < 40 and card_heal > 0:
			score += float(card_heal) * 3.5

		# 2. Attack and lethal elimination
		if is_atk and target >= 0:
			var enemy_hp: int = state.enemies[target].health + state.enemies[target].shield
			var est_damage: int = preview_card_damage(i, target)
			score += float(est_damage) * 2.0
			if est_damage >= enemy_hp:
				score += 60.0 # Huge bonus for removing an active enemy

		# 3. Powers / Stuns / Buffs
		if card.get("kind", "") == "Power": score += 25.0
		if card.get("special", "") == "stun": score += 30.0
		if int(card.cost) == 0: score += 15.0
		if _has_draw_effect(card): score += 12.0

		# 4. Elemental resonance bonus
		var el: String = card.get("element", "")
		var prev_el: String = str(state.get("last_element", ""))
		if not el.is_empty() and not prev_el.is_empty():
			if (prev_el == "fire" and el in ["spirit", "gale"]) or (prev_el in ["spirit", "gale"] and el == "fire"):
				score += 15.0
			elif (prev_el == "water" and el in ["stone", "poison"]) or (prev_el in ["stone", "poison"] and el == "water"):
				score += 12.0
			elif (prev_el == "stone" and el in ["spirit", "stone"]) or (prev_el == "spirit" and el == "stone"):
				score += 10.0

		# Cost efficiency penalty
		score -= float(card.cost) * 2.5

		if score > best_score:
			best_score = score
			best_idx = i
			best_target = target

	return {"hand_index": best_idx, "target_index": best_target}
