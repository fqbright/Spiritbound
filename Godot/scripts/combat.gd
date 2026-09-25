extends RefCounted
class_name SpiritCombat

signal event(kind: String, payload: Dictionary)

var content: SpiritContent
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init(game_content: SpiritContent) -> void:
	content = game_content

func create(seed: int, encounter: Dictionary, deck: Array, player_health: int, upgrades := {}, equipment := [], card_runes := {}, modifier := {}, relics := [], hero_bonuses := {}, equipment_tiers := {}, equipment_inscriptions := {}, card_branches := {}) -> Dictionary:
	rng.seed = seed
	var health_scale: float = modifier.get("health_scale", 1.0)
	var damage_bonus: int = modifier.get("damage_bonus", 0)
	# Only the Daily Trial's "double damage" tag ever sets this — a straight multiplier applied
	# after the flat bonus above, to the boss and its adds alike.
	var damage_mult: float = modifier.get("damage_mult", 1.0)
	var boss_art: String = str(encounter.get("art_key", encounter.get("art", "m_s001")))
	var enemies: Array = [_enemy("boss", encounter.name, str(encounter.get("name_en", encounter.name)), boss_art, int(round(encounter.health * health_scale)), int(round((encounter.damage + damage_bonus) * damage_mult)), encounter.mechanics)]
	var add_art: String = str(encounter.get("add_art_key", encounter.get("art_key", boss_art)))
	var add_name: String = str(encounter.get("add_name", "灵迹随从"))
	var add_name_en: String = str(encounter.get("add_name_en", "Spirit Minion"))
	for add_index in encounter.adds + modifier.get("extra_enemy", 0):
		enemies.append(_enemy("add-%d" % add_index, add_name, add_name_en, add_art, int(round((9 + encounter.chapter) * health_scale)), int(round((2 + encounter.chapter / 3 + damage_bonus) * damage_mult)), {}))
	var draw_pile: Array = []
	for i in deck.size(): draw_pile.append({"uid":i,"card_id":deck[i]})
	_shuffle(draw_pile)
	var active_resonances: Array[Dictionary] = content.active_relic_resonances(relics)
	var resonance_ids: Array[String] = []
	for r in active_resonances:
		resonance_ids.append(str(r.get("id", "")))
	state = {
		"player":{"health":player_health,"max_health":60,"shield":0,"burn":0,"focus":0,"strength":0}, "enemies":enemies,
		"draw":draw_pile,"hand":[],"discard":[],"exhaust":[],"energy":2,"turn":1,"phase":"player",
		"boomerang_queue":[],"reverb_queue":[],"overload_pending":0,
		"upgrades":upgrades.duplicate(true),"card_branches":card_branches.duplicate(true),"equipment":equipment.duplicate(),"runes":card_runes.duplicate(true),
		"relics":relics.duplicate(),
		"relic_resonances":resonance_ids,
		"pact_cleansed_turns":0,
		"boons":modifier.get("boons",[]).duplicate(),
		"rune_sets":content.active_rune_sets(card_runes),
		"gale_used":false,
		"spirit_surge_active":false,
		"bastion_form_active":false,
		"shadow_clone_active":false,
		"swift_used":false,"first_attack":false,"moon_used":false,"tide_used":false,"elements":{},"mist_hits":0,"soul_heals":0,"phoenix_used":false,
		"revive_chance":modifier.get("revive",0.0),"revives":1 if modifier.get("revive",0.0) > 0 else 0,"modifier":modifier,
		"hero_bonuses":hero_bonuses.duplicate(true),
		"equipment_tiers":equipment_tiers.duplicate(true),
		"equipment_inscriptions":equipment_inscriptions.duplicate(true),
		"inscr_bonuses":content.aggregate_inscriptions(equipment, equipment_inscriptions),
		"encounter":encounter.duplicate(true),
		"is_great_boss":bool(encounter.get("is_great_boss", false)),
		"chapter":int(encounter.get("chapter", 1)),
		"last_element":"",
		"stats":{"damage_dealt":0,"cards_played":0,"shield_gained":0,"cards_tally":{}},
		"cards_played_this_turn":0,
		"player_blocked_this_turn":0,
		"mirror_shield_active":false,
		# Consumed flag is per-turn (reset in end_turn) so Mirror Shield negates exactly the
		# first card of each player turn, not every card that turn.
		"mirror_shield_consumed":false,
	}
	if not enemies.is_empty():
		enemies[0]["is_great_boss"] = state.is_great_boss
		enemies[0]["phase"] = 1
		enemies[0]["phase_triggered"] = false
	# Phase bookkeeping for every enemy, not just the lead one: authored bosses can be fielded
	# anywhere, and a missing key would read as `false` on every check anyway — initialising it
	# explicitly keeps _check_boss_phases() a single lookup rather than a has()-then-get() pair.
	for enemy in state.enemies:
		enemy["phase3_triggered"] = false
	# Apply starting_shield mechanic (separate from shield_per_turn which is applied each enemy turn)
	for enemy in state.enemies:
		var s_shield: int = int(enemy.mechanics.get("starting_shield", 0))
		if s_shield > 0: enemy.shield = s_shield
	if equipment.has("jadePlate"):
		var jp_shield: int = [8, 14, 20, 28][clampi(_equip_tier("jadePlate"), 0, 3)]
		state.player.shield += jp_shield
	if equipment.has("focusCharm"):
		var fc_tier: int = clampi(_equip_tier("focusCharm"), 0, 3)
		state.player.focus += [1, 2, 2, 3][fc_tier]
		state.player.strength = int(state.player.get("strength", 0)) + [0, 0, 1, 1][fc_tier]
	var inscr_hp: int = int(state.inscr_bonuses.get("hp", 0))
	if inscr_hp > 0:
		state.player.max_health += inscr_hp
		state.player.health += inscr_hp
	var inscr_shield: int = int(state.inscr_bonuses.get("shield", 0))
	if inscr_shield > 0:
		state.player.shield += inscr_shield
	if _has_relic("titanBell"):
		state.player.max_health += 20
		state.player.health += 20
		state.player.shield += 15
	if _has_resonance("res_chaos_titan"):
		state.player.max_health += 15
		state.player.health += 15
	if _has_relic("chaosPrism"):
		for enemy in state.enemies:
			enemy.shield += 6
	var op_shield: int = int(modifier.get("enemy_opening_shield", 0))
	var elite_shield: int = int(modifier.get("elite_shield_start", 0)) if bool(encounter.get("is_elite", false)) else 0
	if op_shield > 0 or elite_shield > 0:
		for enemy in state.enemies:
			enemy.shield += op_shield + elite_shield
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
	# Curse Run mutators (Phase 8): applied last, after every other battle-start HP source, so
	# Glass Cannon's cap and Mirror World's swap always reflect the final numbers rather than
	# being clobbered by a relic/mastery bonus that happens to run afterward.
	var mutator_max_hp: int = int(modifier.get("player_max_hp", 0))
	if mutator_max_hp > 0:
		state.player.max_health = mutator_max_hp
		state.player.health = mini(state.player.health, mutator_max_hp)
	if modifier.get("mirror_hp", false) and not state.enemies.is_empty():
		var boss_max: int = int(state.enemies[0].max_health)
		var player_max: int = int(state.player.max_health)
		state.enemies[0].max_health = player_max
		state.enemies[0].health = player_max
		state.player.max_health = boss_max
		state.player.health = boss_max
	var draw_bonus: int = int(hero_bonuses.get("draw_turn1", 0))
	if _has_relic("voidHourglass"):
		for enemy in state.enemies:
			enemy.weak += 1
			enemy.vulnerable += 1
	if _has_relic("shadowCloak"):
		state.player.shield += 12
	if _has_relic("harmoniousBell"):
		var unique_elems := {}
		for c_id in deck:
			var dc := content.card(str(c_id))
			var el: String = str(dc.get("element", ""))
			if el != "": unique_elems[el] = true
		if unique_elems.size() >= 4:
			draw_bonus += 1
	_draw(5 + draw_bonus + (1 if _has_relic("cursedTome") else 0))
	if _has_relic("mysticScroll") and state.hand.size() < 10:
		for i in range(state.draw.size() - 1, -1, -1):
			var c_card := content.card(str(state.draw[i].card_id))
			if c_card.get("cost", 1) == 0:
				var pulled: Dictionary = state.draw[i]
				state.draw.remove_at(i)
				state.hand.append(pulled)
				break
	if _has_relic("prismaticRune") and not state.hand.is_empty():
		var pick_idx := rng.randi_range(0, state.hand.size() - 1)
		state.runes[state.hand[pick_idx].card_id] = "echo"
	if _has_relic("cursedTome"): _damage_player(2)
	_plan_intents()
	return state

func _has_relic(id: String) -> bool:
	return state.get("relics", []).has(id)

func _has_resonance(id: String) -> bool:
	return state.get("relic_resonances", []).has(id)

func _equip_tier(id: String) -> int:
	return int(state.get("equipment_tiers", {}).get(id, 0))

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
				var mc_shield: int = [0, 3, 6, 10][clampi(_equip_tier("mistCloak"), 0, 3)]
				if mc_shield > 0: state.player.shield += mc_shield
				emit_signal("event","equipment",{"id":"mistCloak"})
			var taken := _damage_player(amount)
			enemy.attacks += 1
			if taken > 0 and bool(state.get("modifier", {}).get("inflict_debuffs", false)):
				if rng.randf() < 0.25:
					if rng.randf() < 0.5: state.player.weak = int(state.player.get("weak", 0)) + 1
					else: state.player.vulnerable = int(state.player.get("vulnerable", 0)) + 1
			# Chapter 10 phase 2 laces its swings with Burn — read as a flag each attack rather
			# than latched on the transition, so a reload can't drop the boss's phase-2 identity.
			if _mech_phase(enemy) >= 2:
				var burn_hit: int = int(enemy.mechanics.get("phase2_burn_on_hit", 0))
				if burn_hit > 0:
					state.player.burn = int(state.player.get("burn", 0)) + burn_hit
					emit_signal("event","boss_mechanic",{"enemy":enemy_index,"kind":"burn_on_hit","amount":burn_hit})
			# Blood Price (Chapter 35): heals off its own swings. Applied whenever it attacks at
			# all — including a swing the player fully blocked — because the mechanic is "every
			# attack", not "every point of damage that got through".
			var heal_on_attack: int = int(enemy.mechanics.get("heal_on_attack", 0))
			if heal_on_attack > 0 and enemy.health > 0 and enemy.health < enemy.max_health:
				enemy.health = mini(enemy.max_health, enemy.health + heal_on_attack)
				emit_signal("event","boss_mechanic",{"enemy":enemy_index,"kind":"heal_on_attack","amount":heal_on_attack})
			if taken > 0 and state.equipment.has("thornArmor"):
				var ta_dmg: int = [2, 4, 6, 9][clampi(_equip_tier("thornArmor"), 0, 3)]
				ta_dmg += int(state.inscr_bonuses.get("thorns", 0))
				_damage_enemy(enemy_index, ta_dmg, false)
				emit_signal("event","equipment",{"id":"thornArmor"})
			elif taken > 0 and int(state.inscr_bonuses.get("thorns", 0)) > 0:
				_damage_enemy(enemy_index, int(state.inscr_bonuses.get("thorns", 0)), false)

func play(hand_index: int, target_index := -1) -> bool:
	if state.phase != "player" or hand_index < 0 or hand_index >= state.hand.size(): return false
	var instance: Dictionary = state.hand[hand_index]
	var card := content.card(instance.card_id)
	if card.is_empty(): return false
	var actual_cost: int = int(card.cost)
	if state.get("card_branches", {}).get(card.id, "") == "flow":
		actual_cost = maxi(0, actual_cost - 1)
	if actual_cost > state.energy: return false
	# Mirror Shield (Chapter 50, phase 2): the first card played each turn is negated outright.
	# The card stays in hand and nothing is spent, so the tax is tempo rather than card
	# advantage — the player still has the card, they just lose the turn's best first play to it.
	if bool(state.get("mirror_shield_active", false)) and not bool(state.get("mirror_shield_consumed", false)):
		state.mirror_shield_consumed = true
		emit_signal("event","mirror_shield_blocked",{"card":card.id})
		return true
	# harmful drives the damage bonuses; needs_enemy drives targeting. A pure debuff needs a
	# target but must not burn Focus or the first-attack bonuses.
	var harmful := _is_attack(card)
	if _targets_opponent(card):
		target_index = _smart_target() if target_index < 0 else target_index
		if target_index < 0 or target_index >= state.enemies.size() or state.enemies[target_index].health <= 0: return false
	else: target_index = -1
	var rune: String = state.runes.get(card.id, "")
	state.energy -= actual_cost
	if state.has("stats"):
		state.stats.cards_played = int(state.stats.get("cards_played", 0)) + 1
		if not state.stats.has("cards_tally"): state.stats.cards_tally = {}
		state.stats.cards_tally[card.id] = int(state.stats.cards_tally.get(card.id, 0)) + 1
	# Counted separately from the career tally above because Chapter 25's Counterspell reads it
	# per-turn and it must reset every turn — the two have the same name but different lifetimes.
	state.cards_played_this_turn = int(state.get("cards_played_this_turn", 0)) + 1
	# Plays are gated by energy alone now, so Swift's "first play is free" reads as refunding
	# that play's own cost rather than an action slot that no longer exists.
	if rune == "swift" and not state.swift_used: state.energy += actual_cost; state.swift_used = true
	if card.get("kind","") == "Tactic" and state.equipment.has("moonStaff") and not state.moon_used:
		state.energy += 1
		state.moon_used = true
		var ms_shield: int = [0, 2, 4, 7][clampi(_equip_tier("moonStaff"), 0, 3)]
		if ms_shield > 0: state.player.shield += ms_shield
	if state.get("rune_sets", []).has("set_gale") and not state.gale_used and (rune == "cycle" or _has_draw_effect(card)):
		state.energy += 1
		state.gale_used = true
	state.hand.remove_at(hand_index)
	# Boomerang (回旋) takes priority over the normal discard/exhaust placement — the card isn't
	# gone, it comes back to hand at the start of next turn (see end_turn()'s drain of
	# boomerang_queue). No shipped card combines this with exhaust:true; a card marking both
	# would be a content error, not something this needs to arbitrate.
	if card.get("boomerang", false) and not card.exhaust: state.boomerang_queue.append(instance)
	elif rune == "cycle" and not card.exhaust: state.draw.push_front(instance)
	elif card.exhaust: state.exhaust.append(instance)
	else: state.discard.append(instance)
	if card.cost >= 2 and _has_relic("swiftBoots") and not bool(state.get("swift_boots_used", false)):
		state.energy += 1
		state.swift_boots_used = true
	if card.exhaust and _has_relic("soulLantern"):
		state.soul_lantern_pending = int(state.get("soul_lantern_pending", 0)) + 1
	if _has_relic("jadePendant"):
		var el: String = str(card.get("element", ""))
		if el != "":
			if el == str(state.get("last_played_element", "")):
				state.same_element_counter = int(state.get("same_element_counter", 0)) + 1
				if int(state.same_element_counter) >= 3:
					state.same_element_counter = 0
					_draw(1)
			else:
				state.last_played_element = el
				state.same_element_counter = 1
	if harmful and _has_relic("stormOrb"):
		state.storm_orb_counter = int(state.get("storm_orb_counter", 0)) + 1
		if int(state.storm_orb_counter) >= 4:
			state.storm_orb_counter = 0
			for e in state.enemies:
				if e.health > 0: e.vulnerable = int(e.get("vulnerable", 0)) + 1
	var bonus := int(state.upgrades.get(card.id,0))
	# Strength is the permanent counterpart to Focus's one-shot burst: it never resets, so
	# a Power card that grants it pays off over the whole fight rather than a single hit.
	if harmful: bonus += int(state.player.get("strength", 0))
	if harmful and int(state.player.get("burn", 0)) > 0 and _has_relic("cinderBand"): bonus += 3
	if harmful and state.player.focus > 0: bonus += 3 * state.player.focus; state.player.focus = 0
	if harmful and not state.first_attack:
		if state.equipment.has("emberBlade"):
			bonus += [3, 5, 7, 10][clampi(_equip_tier("emberBlade"), 0, 3)]
		if _has_relic("starShard"): bonus += 2
		if _has_resonance("res_star_flame") and target_index >= 0 and target_index < state.enemies.size() and state.enemies[target_index].health > 0 and not bool(state.enemies[target_index].mechanics.get("burn_immune", false)):
			state.enemies[target_index].burn += 2
		if state.get("boons", []).has("boon_spirit_surge"): bonus += 4
		bonus += int(state.get("hero_bonuses", {}).get("first_attack_bonus", 0))
		bonus += int(state.inscr_bonuses.get("atk", 0))
	if harmful and state.equipment.has("stoneSpear"):
		bonus += [0, 1, 2, 4][clampi(_equip_tier("stoneSpear"), 0, 3)]
	if harmful: state.first_attack = true
	var resonance := int(state.elements.get(card.get("element",""),0)) if rune == "resonance" else 0
	var dealt := _resolve_effects(card, target_index, bonus + resonance, 1.0)
	if not harmful and _has_relic("echoMirror") and not bool(state.get("echo_mirror_used", false)):
		state.echo_mirror_used = true
		_resolve_effects(card, target_index, bonus + resonance, 1.0)
	if rune == "echo" and state.phase == "player": dealt += _resolve_effects(card, target_index, bonus + resonance, .5)
	# Reverb (余韵): a full free re-cast queued for the START of next turn, not this same turn —
	# unlike the "echo" rune above (immediate, same turn, half value), so the two don't stack
	# into one card doing the exact same thing twice under different names. Captures bonus+
	# resonance now (this cast's own values) since the queued re-cast should hit exactly as hard
	# as the original did, not be recomputed against next turn's (possibly different) state.
	if card.get("reverb", false): state.reverb_queue.append({"card_id": card.id, "bonus": bonus + resonance})
	# Overload (过载): the drawback is a next-turn energy debt, not anything paid now — see
	# end_turn()'s drain of overload_pending, floored at 1 energy the same way titanBell's own
	# growth-cancelling discount never goes negative.
	var overload_amount: int = int(card.get("overload", 0))
	if overload_amount > 0: state.overload_pending = int(state.get("overload_pending", 0)) + overload_amount
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
	var sp := str(card.get("special", ""))
	if sp == "stun" and target_index >= 0: state.enemies[target_index].stun += 1
	elif sp == "recoverExhaust" and not state.exhaust.is_empty() and state.hand.size() < 10: state.hand.append(state.exhaust.pop_back())
	elif sp == "recycleDiscard":
		for i in mini(2,state.discard.size()): state.draw.push_front(state.discard.pop_back())
	elif sp == "samadhi_burst" and target_index >= 0:
		var e: Dictionary = state.enemies[target_index]
		if int(e.get("burn", 0)) > 0:
			var burst_dmg: int = int(e.burn) * 2
			var b_hit := _damage_enemy(target_index, burst_dmg, true)
			dealt += b_hit
			e.burn = int(e.burn) * 2
			emit_signal("event", "samadhi_burst", {"target": target_index, "damage": burst_dmg})
	elif sp == "spirit_surge":
		state.spirit_surge_active = true
		emit_signal("event", "spirit_surge", {})
	elif sp == "shield_slam" and target_index >= 0:
		var slam_dmg: int = maxi(1, int(state.player.shield))
		var hit := _damage_enemy(target_index, slam_dmg, true)
		dealt += hit
		emit_signal("event", "shield_slam", {"target": target_index, "damage": slam_dmg})
	elif sp == "bastion_form":
		state.bastion_form_active = true
		emit_signal("event", "bastion_form", {})
	elif sp == "thousand_blades" and target_index >= 0:
		var hand_bonus: int = state.hand.size() * 4
		var hit := _damage_enemy(target_index, hand_bonus, false)
		dealt += hit
		emit_signal("event", "thousand_blades", {"target": target_index, "bonus": hand_bonus})
	elif sp == "shadow_clone":
		state.shadow_clone_active = true
		emit_signal("event", "shadow_clone", {})
	elif sp == "catalyst_poison" and target_index >= 0:
		var cur_p: int = int(state.enemies[target_index].get("poison", 0))
		if cur_p > 0:
			state.enemies[target_index].poison = cur_p * 2
			emit_signal("event", "catalyst", {"target": target_index, "poison": cur_p * 2})
	elif sp == "blood_pact":
		state.player.health = maxi(1, int(state.player.health) - 5)
		state.energy = mini(10, state.energy + 2)
		_draw(2)
		emit_signal("event", "blood_pact", {"energy": 2, "cards": 3, "health_cost": 5})

	if bool(state.get("shadow_clone_active", false)) and sp != "shadow_clone":
		state.shadow_clone_active = false
		emit_signal("event", "shadow_clone_proc", {"card": card.id})
		dealt += _resolve_effects(card, target_index, bonus + resonance, 1.0)

	if bool(state.get("spirit_surge_active", false)):
		_draw(1)
		state.player.shield += 2
		emit_signal("event", "spirit_surge_proc", {"draw": 1, "shield": 2})

	emit_signal("event","card",{"card":card.id,"rune":rune,"target":target_index,"damage":dealt})
	return true

func end_turn() -> void:
	if state.phase != "player": return
	# Authored boss mechanics that read the player's just-finished turn (hand size, cards
	# played, damage blocked) — resolved here, before those trackers are reset below and
	# before any enemy acts.
	_apply_boss_player_turn_end()
	if state.phase != "player": return
	for enemy_index in state.enemies.size():
		var enemy: Dictionary = state.enemies[enemy_index]
		if enemy.health <= 0: continue
		# Chapter 50 phase 3 attacks twice per turn: the second swing reuses the same telegraphed
		# intent rather than rolling a fresh one, so the icon the player planned around stays true.
		if _attacks_twice(enemy) and enemy.stun <= 0:
			_execute_intent(enemy_index)
			if state.phase != "player": return
		enemy.shield = enemy.mechanics.get("shield_per_turn",0)
		enemy.health = mini(enemy.max_health, enemy.health + enemy.mechanics.get("regeneration",0))
		if enemy.stun > 0: enemy.stun -= 1
		else: _execute_intent(enemy_index)
		if enemy.burn > 0 and enemy.health > 0:
			var burn_damage: int = enemy.burn + (1 if _has_relic("emberCore") else 0) + (1 if _has_resonance("res_star_flame") else 0)
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
	state.empty_hand_at_end = state.hand.is_empty()
	var kept_hand: Array = []
	for instance in state.hand:
		if str(instance.card_id) == "void_curse": state.exhaust.append(instance)
		else: kept_hand.append(instance)
	state.hand = kept_hand

	state.turn += 1
	var energy_growth: int = int((state.turn - 1) / 2)
	if _has_relic("titanBell"): energy_growth = 0
	state.energy = 2 + energy_growth
	if _has_relic("foxCharm") and state.turn == 2: state.energy += 1
	var sl_pending: int = int(state.get("soul_lantern_pending", 0))
	if sl_pending > 0:
		state.energy += sl_pending
		state.soul_lantern_pending = 0
	var overload_due: int = int(state.get("overload_pending", 0))
	if overload_due > 0:
		state.energy = maxi(1, state.energy - overload_due)
		state.overload_pending = 0
	var kept_shield: int = 0
	if _has_resonance("res_sun_moon"):
		kept_shield = state.player.shield
	elif _has_relic("spiritArmor"):
		kept_shield = mini(30, state.player.shield)
	elif bool(state.get("bastion_form_active", false)):
		kept_shield = mini(35, state.player.shield)
	elif _has_relic("mirrorScale"):
		kept_shield = int(state.player.shield / 2)
	state.player.shield = kept_shield
	state.spirit_surge_active = false
	state.shadow_clone_active = false
	if state.get("boons", []).has("boon_iron_core"): state.player.shield += 5
	if _has_relic("venomFlask"):
		for vi in state.enemies.size():
			var ven_e: Dictionary = state.enemies[vi]
			if ven_e.health > 0 and int(ven_e.get("poison", 0)) > 0:
				var v_dmg := maxi(1, int(round(float(ven_e.poison) * 0.5)))
				_damage_enemy(vi, v_dmg, true)
	if _has_resonance("res_blood_seed"):
		var target_hp: int = state.player.health + 4
		if target_hp > state.player.max_health:
			var overheal: int = target_hp - state.player.max_health
			state.player.health = state.player.max_health
			state.player.shield += overheal
			if state.has("stats"): state.stats.shield_gained = int(state.stats.get("shield_gained", 0)) + overheal
		else:
			state.player.health = target_hp
	elif _has_relic("ancientSeed"):
		state.player.health = mini(state.player.max_health, state.player.health + 2)
	var mastery_heal: int = int(state.get("hero_bonuses", {}).get("heal_per_turn", 0))
	if mastery_heal > 0: state.player.health = mini(state.player.max_health, state.player.health + mastery_heal)
	var inscr_heal: int = int(state.inscr_bonuses.get("heal", 0))
	if inscr_heal > 0 and state.player.health > 0:
		state.player.health = mini(state.player.max_health, state.player.health + inscr_heal)
	if _has_relic("thunderSeal") and state.turn % 3 == 0:
		state.energy += 2 + (2 if _has_resonance("res_sun_moon") else 0)
	var energy_cap: int = int(state.get("modifier", {}).get("energy_cap", 0))
	if energy_cap > 0: state.energy = mini(state.energy, energy_cap)
	state.swift_used = false; state.first_attack = false; state.moon_used = false; state.tide_used = false; state.gale_used = false; state.elements = {}; state.last_element = ""; state.swift_boots_used = false; state.echo_mirror_used = false
	var turn_draw: int = 2 + (1 if state.get("boons", []).has("boon_wind_stride") else 0) + (1 if _has_relic("cursedTome") else 0) + (1 if (_has_resonance("res_fox_wind") and state.turn == 2) else 0)
	if _has_relic("moonstone"):
		if state.turn % 2 == 1: turn_draw += 1
		else: state.player.shield += 6
	if _has_relic("lotusIncense") and bool(state.get("empty_hand_at_end", false)):
		turn_draw += 2
	# Fewer Draws (Phase 8 Curse Run mutator): floored at 1 so a long fight can never fully
	# stall the hand from growing at all.
	turn_draw = maxi(1, turn_draw - int(state.get("modifier", {}).get("draw_penalty", 0)))
	_draw(turn_draw)
	# Boomerang (回旋): cards played last turn with this tag return straight to hand now,
	# instead of having gone to discard/exhaust when they were played (see play()'s own branch).
	if not state.boomerang_queue.is_empty():
		for instance in state.boomerang_queue: state.hand.append(instance)
		state.boomerang_queue = []
	# Reverb (余韵): a free, full-value re-cast of what was played last turn, queued in play().
	# Re-targets fresh rather than reusing the original target_index — that enemy may already
	# be dead by the time this actually fires, same reasoning _smart_target() exists for at all.
	if not state.reverb_queue.is_empty():
		for entry in state.reverb_queue:
			var rv_card: Dictionary = content.card(str(entry.get("card_id", "")))
			if rv_card.is_empty(): continue
			var rv_needs_target: bool = _targets_opponent(rv_card)
			var rv_target: int = _smart_target() if rv_needs_target else -1
			if rv_needs_target and rv_target < 0: continue
			_resolve_effects(rv_card, rv_target, int(entry.get("bonus", 0)), 1.0)
		state.reverb_queue = []
	if _has_relic("cursedTome"):
		if _has_resonance("res_nether_pact") and int(state.get("pact_cleansed_turns", 0)) > 0:
			state.pact_cleansed_turns = int(state.pact_cleansed_turns) - 1
		else:
			_damage_player(2)
			if state.phase != "player": return
	# Per-turn trackers reset *after* the boss mechanics above have read them and *before* the
	# player's new turn starts, so each turn's counts are independent.
	state.cards_played_this_turn = 0
	state.player_blocked_this_turn = 0
	state.mirror_shield_consumed = false
	state.mirror_shield_active = false
	_apply_boss_player_turn_start()
	if state.phase != "player": return
	_plan_intents()
	emit_signal("event","turn",{"turn":state.turn})

func _resolve_effects(card: Dictionary, target_index: int, bonus: int, scale: float) -> int:
	var dealt := 0
	var surge_bonus: int = 3 if state.get("card_branches", {}).get(card.id, "") == "surge" else 0
	for effect in card.effects:
		var amount := maxi(1,int(round((effect.amount + bonus + surge_bonus if effect.operation == "damage" else effect.amount + int(state.upgrades.get(card.id,0)) + surge_bonus) * scale)))
		match effect.operation:
			"damage":
				var targets := range(state.enemies.size()) if card.get("special","") == "cleave" else [target_index]
				# Curse Run's Glass Cannon/Berserker's Pact mutators (Phase 8) boost outgoing
				# damage; read once per effect rather than per target since it never changes mid-swing.
				var dmg_mult: float = float(state.get("modifier", {}).get("player_dmg_mult", 1.0))
				for index in targets:
					if state.enemies[index].health <= 0: continue
					var execute := 1.5 if state.runes.get(card.id,"") == "execute" and state.enemies[index].health <= state.enemies[index].max_health * .25 else 1.0
					var has_inscr_crit: bool = not state.first_attack and int(state.inscr_bonuses.get("crit", 0)) > 0 and rng.randi_range(1, 100) <= int(state.inscr_bonuses.get("crit", 0))
					var critical := 2 if (card.get("special","") == "critical" or has_inscr_crit) else 1
					# Flame Resonance rewards hitting a target that is already burning, rather
					# than boosting burn's own damage tick — it only applies to a card actually
					# landing a hit, checked per target since cleave can hit a mix of burning
					# and non-burning enemies in the same swing.
					var flame_bonus := 3 if state.get("rune_sets", []).has("set_flame") and int(state.enemies[index].get("burn", 0)) > 0 else 0
					if state.turn == 1 and _has_relic("celestialBell"): dmg_mult *= 1.25
					if int(state.enemies[index].get("poison", 0)) > 0 and _has_relic("serpentFang"): dmg_mult *= 1.35
					var hit := _damage_enemy(index,int(round(amount * execute * critical * dmg_mult)) + flame_bonus,card.get("special","") == "pierce" or state.equipment.has("stoneSpear"))
					dealt += hit
					if hit > 0 and _has_relic("chaosPrism") and state.enemies[index].health > 0:
						state.enemies[index].vulnerable = int(state.enemies[index].get("vulnerable", 0)) + 1
			"shield":
				var shield_gain := amount
				if state.get("rune_sets", []).has("set_stone") and rng.randf() < 0.25:
					shield_gain = int(round(shield_gain * 1.5))
					emit_signal("event","rune_set",{"id":"set_stone"})
				state.player.shield += shield_gain
				if _has_relic("heavyAnchor") and shield_gain >= 15:
					var anchor_target := _smart_target()
					if anchor_target >= 0:
						_damage_enemy(anchor_target, 6, false)
				if state.has("stats"): state.stats.shield_gained = int(state.stats.get("shield_gained", 0)) + shield_gain
				if state.equipment.has("tideCharm") and not state.tide_used:
					state.tide_used = true
					_draw(1)
					var tc_shield: int = [0, 2, 4, 6][clampi(_equip_tier("tideCharm"), 0, 3)]
					if tc_shield > 0: state.player.shield += tc_shield
			"heal":
				if not state.get("modifier", {}).get("no_heal", false):
					state.player.health = mini(state.player.max_health,state.player.health + amount)
			"draw": _draw(amount)
			"energy": state.energy += amount
			"status":
				var final_amt: int = amount
				if effect.status == "burn" and target_index >= 0 and bool(state.enemies[target_index].mechanics.get("burn_immune", false)):
					final_amt = 0
				elif effect.status == "burn" and state.get("boons", []).has("boon_flame_affinity"): final_amt += 2
				elif effect.status == "burn" and _has_relic("blazingBrazier") and rng.randf() < 0.5: final_amt += 2
				if final_amt > 0:
					if effect.target == "actor": state.player[effect.status] = state.player.get(effect.status,0) + final_amt
					elif target_index >= 0:
						state.enemies[target_index][effect.status] = state.enemies[target_index].get(effect.status,0) + final_amt
						if _has_relic("frostNeedle"):
							state.enemies[target_index].shield = maxi(0, int(state.enemies[target_index].get("shield", 0)) - 2)
	return dealt

func _damage_enemy(index: int, amount: int, pierce: bool) -> int:
	if index < 0 or index >= state.enemies.size(): return 0
	var enemy: Dictionary = state.enemies[index]
	if enemy.health <= 0: return 0
	enemy.hits += 1
	if enemy.mechanics.get("dodge_every",0) > 0 and enemy.hits % enemy.mechanics.dodge_every == 0: emit_signal("event","dodge",{"enemy":index}); return 0
	if int(enemy.mechanics.get("frost_armor", 0)) > 0:
		amount = maxi(1, amount - int(enemy.mechanics.frost_armor))
	if int(enemy.get("vulnerable", 0)) > 0:
		amount = int(round(amount * 1.5)) + (2 if _has_resonance("res_chaos_titan") else 0)
	var old_shield: int = int(enemy.shield)
	var absorbed := 0 if pierce else mini(enemy.shield,amount)
	enemy.shield -= absorbed
	if _has_relic("obsidianIdol") and old_shield > 0 and enemy.shield == 0 and not pierce:
		enemy.health -= 8
		emit_signal("event","shatter",{"enemy":index,"amount":8})
	var dealt := mini(enemy.health,amount - absorbed)
	enemy.health -= dealt
	emit_signal("event", "damage_dealt", {"enemy": index, "damage": dealt, "absorbed": absorbed, "pierce": pierce, "vulnerable": int(enemy.get("vulnerable", 0)) > 0})
	if state.has("stats"): state.stats.damage_dealt = int(state.stats.get("damage_dealt", 0)) + (dealt + absorbed)
	if index == 0 and bool(state.get("is_great_boss", false)) and not bool(enemy.get("phase_triggered", false)) and enemy.health > 0 and enemy.health <= enemy.max_health / 2:
		_trigger_great_boss_phase_2(enemy)
	_check_mechanics_phases(index, enemy)
	# Thorns was carried as encounter data since the 50-stage version but never actually
	# consulted anywhere — every "thorns" enemy fought identically to one with no mechanic.
	if dealt > 0 and int(enemy.mechanics.get("thorns", 0)) > 0:
		_damage_player(int(enemy.mechanics.thorns))
		emit_signal("event","thorns",{"enemy":index,"amount":int(enemy.mechanics.thorns)})
	if enemy.health <= 0:
		# Authored Undying (Chapter 30): unconditional, unlike the player-facing revive_chance
		# roll below — the whole point of the mechanic is that the player *knows* it will come
		# back, so a dice roll here would make the fight's most memorable beat a coin flip.
		if float(enemy.mechanics.get("revive_hp_pct", 0.0)) > 0.0 and not bool(enemy.get("mech_revived", false)):
			enemy["mech_revived"] = true
			enemy.health = maxi(1, int(ceil(enemy.max_health * float(enemy.mechanics.revive_hp_pct))))
			enemy.shield = 0; enemy.burn = 0; enemy.poison = 0; enemy.vulnerable = 0; enemy.weak = 0
			emit_signal("event","boss_mechanic",{"enemy":index,"kind":"undying","amount":enemy.health})
			var pierce_amt: int = int(enemy.mechanics.get("revive_attack_pierce", 0))
			if pierce_amt > 0:
				_damage_player(pierce_amt, true)
			return dealt
		if not enemy.revived and state.revives > 0 and rng.randf() < state.revive_chance:
			enemy.health = maxi(1,int(ceil(enemy.max_health * .35))); enemy.revived = true; state.revives -= 1
			emit_signal("event","revive",{"enemy":index,"amount":enemy.health}); return dealt
		emit_signal("event","death",{"enemy":index})
		if state.equipment.has("soulPendant"):
			var sp_max_heals: int = [3, 3, 4, 4][clampi(_equip_tier("soulPendant"), 0, 3)]
			var sp_heal_amt: int = [2, 3, 4, 6][clampi(_equip_tier("soulPendant"), 0, 3)]
			if state.soul_heals < sp_max_heals:
				state.player.health = mini(state.player.max_health, state.player.health + sp_heal_amt)
				state.soul_heals += 1
		if state.equipment.has("stormBow"):
			var sb_draw: int = [1, 1, 1, 2][clampi(_equip_tier("stormBow"), 0, 3)]
			var sb_shield: int = [0, 2, 4, 5][clampi(_equip_tier("stormBow"), 0, 3)]
			_draw(sb_draw)
			if sb_shield > 0: state.player.shield += sb_shield
		if _has_relic("bloodJade"): state.player.health = mini(state.player.max_health, state.player.health + 3)
		if _has_relic("bloodChalice"):
			for h_inst in state.hand:
				var h_c: Dictionary = content.card(str(h_inst.get("card_id", "")))
				if _is_attack(h_c):
					state.upgrades[h_c.id] = int(state.upgrades.get(h_c.id, 0)) + 2
		if _has_relic("spiritBanner") and index > 0 and not state.enemies.is_empty() and state.enemies[0].health > 0:
			_damage_enemy(0, 12, true)
		if _has_resonance("res_nether_pact"):
			state.pact_cleansed_turns = int(state.get("pact_cleansed_turns", 0)) + 1
			_draw(1)
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
				var clone: Dictionary = _enemy("boss_clone", "暗影化身", "Shadow Avatar", "m_s150", maxi(10, int(round(enemy.max_health * 0.35))), maxi(2, int(round(enemy.damage * 0.5))), {})
				state.enemies.append(clone)
			emit_signal("event", "boss_phase", {"chapter": 30, "phase": 2, "name": "暗影分身", "name_en": "Shadow Legion", "desc": "召唤暗影化身协助作战，使玩家获得2层易伤！", "desc_en": "Summons a Shadow Clone, inflicts 2 Vulnerable on player!"})
		40:
			enemy.mechanics.dodge_every = 2
			state.player.weak = int(state.player.get("weak", 0)) + 2
			emit_signal("event", "boss_phase", {"chapter": 40, "phase": 2, "name": "风暴领域", "name_en": "Cyclone Domain", "desc": "开启风暴护体每2次受击闪避1次，使玩家陷入2层虚弱！", "desc_en": "Gains Dodge every 2 hits, inflicts 2 Weak on player!"})
		50:
			enemy.damage += 8
			enemy.shield += 30
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

# ---------------------------------------------------------------------------------------------
# Authored boss mechanics (see content.gd's ENEMIES `mechanics` dicts).
#
# These are read as *flags at their use site* rather than as one-off mutations applied when a
# phase flips, so a boss can't be "caught" mid-phase by a save/reload or a resumed auto-battle
# and silently lose its identity — e.g. phase2_mirror_shield is consulted in play() every card,
# not latched once on the transition.
#
# The hardcoded chapter-matched _trigger_great_boss_phase_2() above is kept as-is for the five
# great-boss chapters that shipped with it; the mechanics-driven path below is what the
# remaining authored bosses use. Both can coexist on one enemy without double-applying damage
# boosts, because each guards on its own flag (phase_triggered vs mech_phase2).
# ---------------------------------------------------------------------------------------------

func _hp_ratio(enemy: Dictionary) -> float:
	return float(enemy.health) / float(maxi(1, int(enemy.max_health)))

# Phase 2 / Phase 3 detection for mechanics-authored bosses. Guarded by its own flags so it's
# idempotent — _damage_enemy can call this on every single hit.
func _check_mechanics_phases(enemy_index: int, enemy: Dictionary) -> void:
	if enemy.health <= 0: return
	var m: Dictionary = enemy.mechanics
	var ratio := _hp_ratio(enemy)
	var p2: float = float(m.get("phase2_threshold", 0.0))
	if p2 > 0.0 and ratio <= p2 and not bool(enemy.get("mech_phase2", false)):
		enemy["mech_phase2"] = true
		enemy["phase"] = maxi(2, int(enemy.get("phase", 1)))
		var boost2: int = int(m.get("phase2_damage_boost", 0))
		# The five great-boss chapters already apply their own hardcoded phase-2 boost inside
		# _trigger_great_boss_phase_2(), which runs off the same HP threshold. Applying the
		# authored boost as well would double-count it, so the authored path yields to the
		# hardcoded one when both describe the same transition.
		if boost2 > 0 and not bool(enemy.get("phase_triggered", false)): enemy.damage += boost2
		emit_signal("event", "boss_phase_change", {"enemy": enemy_index, "phase": 2})
	var p3: float = float(m.get("phase3_threshold", 0.0))
	if p3 > 0.0 and ratio <= p3 and not bool(enemy.get("mech_phase3", false)):
		enemy["mech_phase3"] = true
		enemy["phase"] = 3
		var boost3: int = int(m.get("phase3_damage_boost", 0))
		if boost3 > 0: enemy.damage += boost3
		emit_signal("event", "boss_phase_change", {"enemy": enemy_index, "phase": 3})

# Helper for mechanics that behave differently per phase (e.g. phase-2 Summon shuts off).
func _mech_phase(enemy: Dictionary) -> int:
	return int(enemy.get("phase", 1))

func _attacks_twice(enemy: Dictionary) -> bool:
	return bool(enemy.mechanics.get("phase3_double_attack", false)) and _mech_phase(enemy) >= 3

# Runs at the *end of the player's turn* — inside end_turn(), before any enemy executes its
# intent, so the player's choices (how many cards they kept, how many they played, whether they
# stacked burn) determine what happens.
func _apply_boss_player_turn_end() -> void:
	for enemy_index in state.enemies.size():
		var enemy: Dictionary = state.enemies[enemy_index]
		if enemy.health <= 0: continue
		var m: Dictionary = enemy.mechanics
		# Hunter's Mark (Chapter 5): punishes ending the turn holding cards.
		if m.has("mark_hand_penalty") and state.hand.size() > int(m.get("mark_hand_threshold", 0)):
			var mark: int = int(m.mark_hand_penalty)
			_damage_player(mark)
			emit_signal("event","boss_mechanic",{"enemy":enemy_index,"kind":"mark","amount":mark})
			if state.phase != "player": return
		# Counterspell (Chapter 25): punishes playing a long chain of cards in one turn.
		if m.has("counterspell_threshold") and int(state.get("cards_played_this_turn", 0)) >= int(m.counterspell_threshold):
			var cb: int = int(m.get("counterspell_burn", 1))
			state.player.burn = int(state.player.get("burn", 0)) + cb
			emit_signal("event","boss_mechanic",{"enemy":enemy_index,"kind":"counterspell","amount":cb})
		# Absorb Burn (Chapter 10, phase-1 identity): converts the player's Burn into its own
		# Shield, which makes stacking Burn on it actively counterproductive — the intended
		# counterplay is to hold Burn until after the absorb turn rather than to stop using it.
		if m.has("absorb_burn_every") and int(m.absorb_burn_every) > 0 and state.turn % int(m.absorb_burn_every) == 0:
			var burn_stacks: int = int(state.player.get("burn", 0))
			if burn_stacks > 0:
				var gained: int = burn_stacks * int(m.get("shield_per_absorbed_burn", 0))
				enemy.shield += gained
				state.player.burn = 0
				emit_signal("event","boss_mechanic",{"enemy":enemy_index,"kind":"absorb_burn","amount":gained})
		# Enrage Stack (Chapter 45): rewards the player for *not* over-blocking.
		if m.has("enrage_on_block_threshold") and int(state.get("player_blocked_this_turn", 0)) > int(m.enrage_on_block_threshold):
			var atk_boost: int = int(m.get("enrage_attack_boost", 0))
			if atk_boost > 0:
				enemy.damage += atk_boost
				emit_signal("event","boss_mechanic",{"enemy":enemy_index,"kind":"enrage","amount":atk_boost})

# Runs at the *start of the player's turn* — the tail of end_turn(), alongside the boomerang and
# reverb drains, so these land after the energy/draw reset and before the player can act.
func _apply_boss_player_turn_start() -> void:
	for enemy_index in state.enemies.size():
		var enemy: Dictionary = state.enemies[enemy_index]
		if enemy.health <= 0: continue
		var m: Dictionary = enemy.mechanics
		# Soul Tide (Chapter 20): clogs the hand with unplayable curses. Removed at the end of
		# the player's turn by end_turn()'s existing void_curse sweep, so the hand isn't
		# permanently bricked — only that turn's draw is taxed.
		if m.has("soul_tide_curse"):
			var curses_due: int = int(m.get("phase2_soul_tide", 2)) if _mech_phase(enemy) >= 2 else int(m.get("soul_tide_count", 1))
			for c in curses_due:
				if state.hand.size() < 10:
					state.hand.append({"uid": 9000 + c, "card_id": str(m.soul_tide_curse)})
			emit_signal("event","boss_mechanic",{"enemy":enemy_index,"kind":"soul_tide","count":curses_due})
		# Memory Erase (Chapter 40): permanently exhausts the player's most expensive card.
		if m.has("exhaust_hand_every") and int(m.exhaust_hand_every) > 0:
			var interval: int = int(m.get("phase2_exhaust_every", 2)) if _mech_phase(enemy) >= 2 else int(m.exhaust_hand_every)
			if state.turn % interval == 0 and not state.hand.is_empty():
				var idx := _most_expensive_hand_index()
				if idx >= 0:
					var erased: Dictionary = state.hand[idx]
					state.hand.remove_at(idx)
					state.exhaust.append(erased)
		# Mirror Shield (Chapter 50, phase 2): arms the negate, consumed by play().
		var mirror: bool = bool(m.get("phase2_mirror_shield", false)) and _mech_phase(enemy) >= 2
		state.mirror_shield_active = mirror
		if mirror: emit_signal("event","boss_mechanic",{"enemy":enemy_index,"kind":"mirror_shield"})
		# Summon (Chapter 50, phase 1): adds reinforcements on a fixed cadence, capped so a long
		# fight can't drown the player in bodies the engine never intended to hold.
		if m.has("summon_every") and int(m.summon_every) > 0 and _mech_phase(enemy) < 2 and state.turn % int(m.summon_every) == 0:
			_summon_boss_add(enemy_index, enemy)

func _most_expensive_hand_index() -> int:
	var best := -1
	var best_cost := -1
	for i in state.hand.size():
		var card := content.card(str(state.hand[i].card_id))
		if card.is_empty(): continue
		var cost: int = int(card.get("cost", 0))
		# Ties go to the earlier card, so the same hand always erases the same card — makes the
		# mechanic reproducible in a test rather than a coin flip between equal-cost cards.
		if cost > best_cost:
			best_cost = cost
			best = i
	return best

func _summon_boss_add(owner_index: int, owner: Dictionary) -> void:
	if state.enemies.size() >= 3: return
	var chapter: int = int(state.get("chapter", 1))
	var add_health: int = maxi(8, int(round(owner.max_health * 0.12)))
	var add_damage: int = maxi(2, int(round(owner.damage * 0.4)))
	var add: Dictionary = _enemy("boss_add", "天道余烬", "Cosmic Ember", "m_s246", add_health, add_damage, {"shield_per_turn": 2})
	add["chapter"] = chapter
	add["phase"] = 1
	add["phase3_triggered"] = false
	state.enemies.append(add)
	emit_signal("event","boss_mechanic",{"enemy":owner_index,"kind":"summon","count":1})

# `pierce` bypasses the player's Shield entirely (the readable counterpart to _damage_enemy's
# own pierce flag) — Chapter 30's revive attack is authored as unavoidable, so it can't be
# absorbed or it would just be a normal swing.
func _damage_player(amount: int, pierce := false) -> int:
	var absorbed := 0 if pierce else mini(state.player.shield, amount)
	state.player.shield -= absorbed
	# Tracks how much Shield actually ate this turn — the input to Chapter 45's enrage-on-block.
	# Accumulated in the damage funnel rather than at each call site so every source (enemy
	# swings, Burn, curses) counts, not just the one path someone remembered to instrument.
	if state.has("player_blocked_this_turn"):
		state.player_blocked_this_turn = int(state.player_blocked_this_turn) + absorbed
	var dealt := mini(state.player.health, amount - absorbed)
	state.player.health -= dealt
	if state.player.health <= 0:
		if state.equipment.has("phoenixMail") and not state.phoenix_used:
			var pm_hp: int = [15, 22, 30, 40][clampi(_equip_tier("phoenixMail"), 0, 3)]
			state.player.health = pm_hp
			state.phoenix_used = true
			emit_signal("event","equipment",{"id":"phoenixMail"})
		elif _has_relic("phoenixFeather") and not bool(state.get("phoenix_used", false)):
			state.player.health = maxi(1, int(state.player.max_health * 0.2))
			state.phoenix_used = true
			emit_signal("event","relic",{"id":"phoenixFeather"})
		else: state.phase = "lost"
	if dealt > 0:
		if _has_relic("dragonScale"):
			_draw(1)
		if _has_relic("ironThorns"):
			var thorn_target := _smart_target()
			if thorn_target >= 0:
				_damage_enemy(thorn_target, 3, true)
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
			if _has_resonance("res_fox_wind"):
				state.energy += 1
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
	return {"id":id,"name":title,"name_en":title_en,"art":art,"art_key":art,"health":health,"max_health":health,"shield":mechanics.get("shield_per_turn",0),"damage":damage,"burn":0,"poison":0,"stun":0,"vulnerable":0,"weak":0,"attacks":0,"hits":0,"revived":false,"intent":{},"mechanics":mechanics.duplicate(true)}

func _is_attack(card: Dictionary) -> bool:
	for effect in card.effects:
		if effect.operation == "damage" and effect.target == "opponent": return true
	return false

# Whether the card needs an enemy at all. Wider than _is_attack, which only counts damage:
# a card that only applies Burn was being played with no target, and _resolve_effects drops
# opponent statuses when target_index is -1, so those cards silently did nothing.
func _targets_opponent(card: Dictionary) -> bool:
	if card.get("special", "") in ["shield_slam", "catalyst_poison"]: return true
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
		if state.equipment.has("emberBlade"):
			bonus += [3, 5, 7, 10][clampi(_equip_tier("emberBlade"), 0, 3)]
		if _has_relic("starShard"): bonus += 2
		if state.get("boons", []).has("boon_spirit_surge"): bonus += 4
		bonus += int(state.get("hero_bonuses", {}).get("first_attack_bonus", 0))
		bonus += int(state.inscr_bonuses.get("atk", 0))
	if state.equipment.has("stoneSpear"):
		bonus += [0, 1, 2, 4][clampi(_equip_tier("stoneSpear"), 0, 3)]
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
		if int(enemy.get("vulnerable", 0)) > 0:
			hit_amount = int(round(hit_amount * 1.5)) + (2 if _has_resonance("res_chaos_titan") else 0)
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
			if int(enemy.get("vulnerable", 0)) > 0:
				hit_amount = int(round(hit_amount * 1.5)) + (2 if _has_resonance("res_chaos_titan") else 0)
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
		# Overload (Phase 7): the burst damage above already counted in full, so the AI needs
		# an explicit counterweight for the next-turn energy debt it's about to take on — same
		# per-point weight as a normal energy cost, since it's the same resource paid later.
		var overload_cost: int = int(card.get("overload", 0))
		if overload_cost > 0: score -= float(overload_cost) * 2.5

		if score > best_score:
			best_score = score
			best_idx = i
			best_target = target

	return {"hand_index": best_idx, "target_index": best_target}
