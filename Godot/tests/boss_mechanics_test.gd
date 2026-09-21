extends SceneTree

# Focused suite for the ten authored boss mechanics (see content.gd's ENEMIES `mechanics`
# dicts) and combat.gd's handlers for them.
#
# Deliberately separate from test_runner.gd: these are content-data-driven behaviours keyed to
# specific stage indices, so they need the *real* encounters rather than a synthetic one. The
# first check below is the important one — it fails if ENEMIES' mechanics stop being merged into
# the encounter dict, which is the exact way this whole feature could ship as dead data.

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

# Builds a fight against a real campaign stage, optionally trimming it to a single enemy so add
# spawns can't make an assertion nondeterministic.
func fight(stage_index: int, solo := false) -> SpiritCombat:
	var combat := SpiritCombat.new(content)
	combat.create(7, content.encounters[stage_index], content.raw.startingDeck, 60)
	if solo: combat.state.enemies = [combat.state.enemies[0]]
	return combat

func run() -> void:
	content = SpiritContent.new()

	# --- The merge, and the guard against it silently regressing ---
	# stage = (chapter-1)*5 + (level-1); all ten authored bosses sit on a level-5 node.
	var authored := {
		24: "mark_hand_penalty", 49: "absorb_burn_every", 74: "starting_shield",
		99: "soul_tide_curse", 124: "counterspell_threshold", 149: "revive_hp_pct",
		174: "heal_on_attack", 199: "exhaust_hand_every", 224: "enrage_on_block_threshold",
		249: "summon_every",
	}
	var merged := 0
	for stage in authored:
		if content.encounters[stage].mechanics.has(authored[stage]): merged += 1
	check(content.encounters.size() == 250, "250 campaign stages present")
	check(merged == authored.size(),
		"all ten authored boss mechanics reach the encounter dict (got %d/%d)" % [merged, authored.size()])

	# The band's generic scaling must survive the merge, or authored bosses would lose the
	# shield/crit/enrage curve every other boss in their chapter still has.
	check(content.encounters[49].mechanics.has("shield_per_turn"),
		"chapter-band mechanics are still present after merging authored ones")
	# Authored keys win where they overlap (m_s075 overrides the band's shield_per_turn with 5).
	check(int(content.encounters[74].mechanics.get("shield_per_turn", 0)) == 5,
		"an authored key overrides the chapter band's value for the same key")

	# --- Chapter 5: Hunter's Mark ---
	var mark := fight(24, true)
	mark.state.hand = [{"uid": 1, "card_id": "strike"}, {"uid": 2, "card_id": "strike"},
		{"uid": 3, "card_id": "strike"}, {"uid": 4, "card_id": "strike"}]
	var mark_hp: int = int(mark.state.player.health)
	mark._apply_boss_player_turn_end()
	check(int(mark.state.player.health) == mark_hp - 6, "Hunter's Mark deals 6 when the turn ends with 4 cards held")
	var mark2 := fight(24, true)
	mark2.state.hand = [{"uid": 1, "card_id": "strike"}]
	var mark2_hp: int = int(mark2.state.player.health)
	mark2._apply_boss_player_turn_end()
	check(int(mark2.state.player.health) == mark2_hp, "Hunter's Mark stays silent at or below the 3-card threshold")

	# --- Chapter 10: Burn absorb, and the phase-2 burn-on-hit ---
	var absorb := fight(49, true)
	absorb.state.player.burn = 5
	absorb.state.turn = 3
	var shield_before: int = int(absorb.state.enemies[0].shield)
	absorb._apply_boss_player_turn_end()
	check(int(absorb.state.enemies[0].shield) == shield_before + 15,
		"the Worldforge boss converts 5 Burn into 15 Shield on its absorb turn")
	check(int(absorb.state.player.burn) == 0, "the absorbed Burn is consumed, not left ticking")
	var absorb_off := fight(49, true)
	absorb_off.state.player.burn = 5
	absorb_off.state.turn = 2
	absorb_off._apply_boss_player_turn_end()
	check(int(absorb_off.state.player.burn) == 5, "Burn is left alone on non-absorb turns")

	var burn_phase := fight(49, true)
	burn_phase.state.enemies[0]["phase"] = 2
	burn_phase.state.enemies[0].intent = {"kind": "attack", "amount": 1}
	burn_phase.state.player.shield = 999
	burn_phase._execute_intent(0)
	check(int(burn_phase.state.player.burn) == 2, "phase 2 laces each attack with 2 Burn")

	var boost := fight(49, true)
	var base_damage: int = int(boost.state.enemies[0].damage)
	var b1: Dictionary = boost.state.enemies[0]
	# Duplicate before tweaking: enemy.mechanics is the encounter's own dict, which is the
	# *content* table's dict — mutating it in place would leak into every later fight and into
	# the other assertions in this file.
	b1["mechanics"] = b1.mechanics.duplicate()
	b1.mechanics["phase2_threshold"] = 0.9
	b1.health = int(round(float(b1.max_health) * 0.85))
	boost._damage_enemy(0, 1, false)
	check(bool(b1.get("mech_phase2", false)), "dropping below the threshold flags phase 2")
	check(int(b1.damage) == base_damage + 8,
		"the authored phase-2 boost applies where the hardcoded great-boss path doesn't own the transition (base %d, now %d)"
			% [base_damage, int(b1.damage)])

	# ...and where the hardcoded great-boss path *does* own the transition, the boost must land
	# exactly once — this is the assertion that catches the two phase-2 code paths
	# double-counting the same HP threshold.
	#
	# This used to be forced by hand, because _build_encounters() never wrote is_great_boss onto
	# the encounter dict — so state.is_great_boss was always false and the five hardcoded
	# ultimates were unreachable in the campaign. That is fixed at the source now, so the fight
	# below is a plain chapter-10 fight with no test-side nudging; the check right after it is
	# what keeps the field from silently disappearing again.
	var boost_hard := fight(49, true)
	check(bool(boost_hard.state.get("is_great_boss", false)),
		"the campaign's chapter-10 encounter carries is_great_boss — without it the hardcoded ultimates are dead code")
	var b2: Dictionary = boost_hard.state.enemies[0]
	check(bool(b2.get("is_great_boss", false)), "the flag also reaches enemy 0, which is where the phase gate reads it")
	var base_damage_2: int = int(b2.damage)
	b2.health = int(round(float(b2.max_health) * 0.45))
	boost_hard._damage_enemy(0, 1, false)
	check(bool(b2.get("phase_triggered", false)), "the great-boss hardcoded phase 2 fires at half HP when the flag is set")
	check(int(b2.damage) == base_damage_2 + 4,
		"chapter 10's phase-2 boost is applied once, not once per code path (base %d, now %d)"
			% [base_damage_2, int(b2.damage)])

	# --- Chapter 15: permanent opening Shield ---
	var shield_start := fight(74, true)
	check(int(shield_start.state.enemies[0].shield) == 20, "the Bonerot boss opens with 20 Shield")

	# --- Chapter 20: Soul Tide ---
	var tide := fight(99, true)
	tide.state.hand = []
	tide.state.turn = 1
	tide._apply_boss_player_turn_start()
	var curses := 0
	for card in tide.state.hand:
		if str(card.card_id) == "void_curse": curses += 1
	check(curses == 1, "Soul Tide injects one void_curse on turn 1 (got %d)" % curses)
	tide.state.enemies[0]["phase"] = 2
	tide.state.hand = []
	tide._apply_boss_player_turn_start()
	curses = 0
	for card in tide.state.hand:
		if str(card.card_id) == "void_curse": curses += 1
	check(curses == 2, "phase 2 doubles Soul Tide (got %d)" % curses)

	# --- Chapter 25: Counterspell ---
	var counter := fight(124, true)
	counter.state.cards_played_this_turn = 3
	counter._apply_boss_player_turn_end()
	check(int(counter.state.player.burn) == 1, "Counterspell adds 1 Burn after a 3-card turn")
	var counter2 := fight(124, true)
	counter2.state.cards_played_this_turn = 2
	counter2._apply_boss_player_turn_end()
	check(int(counter2.state.player.burn) == 0, "Counterspell stays silent below its threshold")

	# --- Chapter 30: Undying + the piercing revive attack ---
	var undying := fight(149, true)
	undying.state.player.shield = 100
	var boss: Dictionary = undying.state.enemies[0]
	boss.health = 1
	undying._damage_enemy(0, 999, false)
	check(int(boss.health) == int(ceil(int(boss.max_health) * 0.3)),
		"the Undying boss revives at 30%% HP (got %d of %d)" % [int(boss.health), int(boss.max_health)])
	check(bool(boss.get("mech_revived", false)), "the revive is recorded so it happens only once")
	check(int(undying.state.player.health) == 45,
		"the revive attack pierces Shield (100 Shield ignored, 15 taken, got %d HP)"
			% int(undying.state.player.health))
	check(int(undying.state.player.shield) == 100, "piercing damage leaves Shield untouched")
	var hp_after_revive: int = int(boss.health)
	undying._damage_enemy(0, 999, false)
	check(int(boss.health) <= 0, "the second death is permanent (was %d HP)" % hp_after_revive)

	# --- Chapter 35: Blood Price ---
	var heal := fight(174, true)
	var healer: Dictionary = heal.state.enemies[0]
	healer.health = int(healer.max_health) - 20
	healer.intent = {"kind": "attack", "amount": 1}
	heal.state.player.shield = 999
	var heal_before: int = int(healer.health)
	heal._execute_intent(0)
	check(int(healer.health) == heal_before + 5, "Blood Price heals the boss 5 on each attack")
	healer.health = int(healer.max_health)
	heal._execute_intent(0)
	check(int(healer.health) == int(healer.max_health), "Blood Price cannot overheal past max HP")

	# --- Chapter 40: Memory Erase ---
	var erase := fight(199, true)
	erase.state.hand = [{"uid": 1, "card_id": "strike"}, {"uid": 2, "card_id": "spiritLance"}]
	erase.state.turn = 3
	erase._apply_boss_player_turn_start()
	check(erase.state.hand.size() == 1, "Memory Erase removes one card from hand")
	check(str(erase.state.exhaust[0].card_id) == "spiritLance",
		"Memory Erase takes the priciest card (got %s)" % str(erase.state.exhaust[0].card_id))
	var erase_off := fight(199, true)
	erase_off.state.hand = [{"uid": 1, "card_id": "strike"}, {"uid": 2, "card_id": "spiritLance"}]
	erase_off.state.turn = 2
	erase_off._apply_boss_player_turn_start()
	check(erase_off.state.hand.size() == 2, "Memory Erase only fires on its interval")

	# --- Chapter 45: Enrage Stack ---
	var enrage := fight(224, true)
	var enrage_base: int = int(enrage.state.enemies[0].damage)
	enrage.state.player_blocked_this_turn = 11
	enrage._apply_boss_player_turn_end()
	check(int(enrage.state.enemies[0].damage) == enrage_base + 3, "blocking more than 10 adds +3 permanent attack")
	var enrage_low := fight(224, true)
	enrage_low.state.player_blocked_this_turn = 10
	enrage_low._apply_boss_player_turn_end()
	check(int(enrage_low.state.enemies[0].damage) == enrage_base,
		"exactly 10 blocked is not 'more than 10' — no free enrage")

	# --- Chapter 50: Mirror Shield, summon cadence, third-phase double attack ---
	var mirror := fight(249, true)
	mirror.state.enemies[0]["phase"] = 2
	mirror.state.mirror_shield_active = true
	mirror.state.mirror_shield_consumed = false
	mirror.state.hand = [{"uid": 1, "card_id": "strike"}, {"uid": 2, "card_id": "strike"}]
	var energy_before: int = int(mirror.state.energy)
	check(mirror.play(0, 0), "a Mirror-Shielded play reports as handled rather than rejected")
	check(int(mirror.state.energy) == energy_before, "the negated card costs no energy")
	check(mirror.state.hand.size() == 2, "the negated card stays in hand")
	check(mirror.play(0, 0), "the next card resolves normally")
	check(mirror.state.hand.size() == 1, "the second card is actually played")
	check(int(mirror.state.energy) == energy_before - 1, "the second card does spend energy")

	var summon := fight(249, true)
	summon.state.turn = 4
	summon._apply_boss_player_turn_start()
	check(summon.state.enemies.size() == 2, "the final boss summons an add on its cadence")
	check(summon.state.enemies[1].health > 0, "the summoned add arrives alive")

	var dbl := fight(249, true)
	var final_boss: Dictionary = dbl.state.enemies[0]
	final_boss["phase"] = 3
	final_boss.damage = 5
	final_boss.intent = {"kind": "attack", "amount": 5}
	dbl.state.player.shield = 0
	var hp_before: int = int(dbl.state.player.health)
	dbl.end_turn()
	check(int(dbl.state.player.health) == hp_before - 10,
		"phase 3 attacks twice per turn (took %d, expected 10)" % (hp_before - int(dbl.state.player.health)))
	check(dbl._attacks_twice(final_boss), "the double-attack gate reads phase 3")

	var dbl_off := fight(249, true)
	dbl_off.state.enemies[0]["phase"] = 1
	check(not dbl_off._attacks_twice(dbl_off.state.enemies[0]), "no double attack before phase 3")

	# --- Every one of the 50 chapter bosses has a signature, and no signature is dead data ---
	# This is the check that matters most in this file. It is deliberately shaped as an allowlist
	# of keys combat.gd actually reads: a key nothing consults parses, type-checks, and then
	# silently never happens at runtime, which is a bug this repo has already shipped twice.
	var engine_read_keys := [
		"absorb_burn_every", "shield_per_absorbed_burn", "starting_shield", "shield_per_turn",
		"regeneration", "frost_armor", "thorns", "dodge_every", "heal_on_attack", "critical_every",
		"below_half", "enrage", "mark_hand_penalty", "mark_hand_threshold",
		"counterspell_threshold", "counterspell_burn", "enrage_on_block_threshold",
		"enrage_attack_boost", "soul_tide_curse", "soul_tide_count", "phase2_soul_tide",
		"exhaust_hand_every", "phase2_exhaust_every", "summon_every", "phase2_mirror_shield",
		"phase2_threshold", "phase2_damage_boost", "phase2_burn_on_hit", "phase3_threshold",
		"phase3_damage_boost", "phase3_double_attack", "revive_hp_pct", "revive_attack_pierce",
		"burn_immune",
	]
	var missing_signature: Array = []
	var no_phase2: Array = []
	var dead_keys: Array = []
	for chapter in range(1, 51):
		var boss_index: int = (chapter - 1) * 5 + 4
		var enc: Dictionary = content.encounters[boss_index]
		check(enc.level == 5, "stage %d is the chapter %d boss node" % [boss_index, chapter])
		var m: Dictionary = enc.mechanics
		if m.is_empty(): missing_signature.append(chapter)
		if not m.has("phase2_threshold"): no_phase2.append(chapter)
		for key in m:
			if not (key in engine_read_keys): dead_keys.append("ch%d:%s" % [chapter, key])
	check(missing_signature.is_empty(),
		"all 50 chapter bosses carry mechanics (missing: %s)" % str(missing_signature))
	check(no_phase2.is_empty(),
		"all 50 chapter bosses have a phase-2 transition (missing: %s)" % str(no_phase2))
	check(dead_keys.is_empty(),
		"every boss mechanic key is one combat.gd actually reads (unread: %s)" % str(dead_keys))

	# The signatures must actually differ per chapter, or "all 50 have one" would be true while
	# every fight still played the same.
	var shapes := {}
	for chapter in range(1, 51):
		var m: Dictionary = content.encounters[(chapter - 1) * 5 + 4].mechanics
		var own: Array = []
		for key in m:
			if key != "phase2_threshold": own.append(key)
		own.sort()
		shapes[",".join(own)] = true
	check(shapes.size() >= 10,
		"chapter bosses fall into at least 10 distinct mechanic shapes (got %d)" % shapes.size())

	# And the numbers scale across the five realms rather than repeating verbatim.
	var early: int = int(content.encounters[4].mechanics.get("shield_per_absorbed_burn", 0))
	var late: int = int(content.encounters[204].mechanics.get("shield_per_absorbed_burn", 0))
	check(late > early,
		"chapter 41's signature scales past chapter 1's (ch1 %d, ch41 %d)" % [early, late])

	# is_great_boss is true on exactly the five every-tenth chapters, and nowhere else.
	var great: Array = []
	for i in content.encounters.size():
		if bool(content.encounters[i].get("is_great_boss", false)): great.append(i)
	check(great == [49, 99, 149, 199, 249],
		"is_great_boss is set on exactly the five great-boss stages (got %s)" % str(great))

	# --- Signature mechanics on a non-authored boss actually run ---
	# Chapter 8 (stage 39) is one of the forty chapters that had no mechanics before this table
	# existed; its archetype is Blood Price (heal on attack), so the same funnel that tests
	# chapter 35 can be pointed at it.
	var sig := fight(39, true)
	var sig_boss: Dictionary = sig.state.enemies[0]
	check(sig_boss.mechanics.has("heal_on_attack"),
		"a previously-plain chapter boss now has its signature mechanic")
	sig_boss.health = int(sig_boss.max_health) - 30
	sig_boss.intent = {"kind": "attack", "amount": 1}
	sig.state.player.shield = 999
	var sig_before: int = int(sig_boss.health)
	sig._execute_intent(0)
	check(int(sig_boss.health) > sig_before,
		"the signature mechanic is live in combat, not just present in the data (was %d, now %d)"
			% [sig_before, int(sig_boss.health)])

	# The chapter band's own scaling must survive the signature merge, same as with authored ones.
	check(content.encounters[39].mechanics.has("shield_per_turn")
		or content.encounters[39].mechanics.has("critical_every"),
		"the chapter band still contributes after the signature merge")

	# --- Per-turn trackers must not leak across turns ---
	var reset := fight(124, true)
	reset.state.cards_played_this_turn = 2
	reset.state.player_blocked_this_turn = 9
	reset.end_turn()
	check(int(reset.state.cards_played_this_turn) == 0, "cards_played_this_turn resets each turn")
	check(int(reset.state.player_blocked_this_turn) == 0, "player_blocked_this_turn resets each turn")

	# --- Blocked damage is actually accumulated by the damage funnel ---
	var block := fight(24, true)
	block.state.player.shield = 30
	block._damage_player(12)
	check(int(block.state.player_blocked_this_turn) == 12,
		"the damage funnel records blocked damage without a call site instrumenting it")

	if failures == 0:
		print("BOSS MECHANICS: all checks passed (%d checks)" % checks)
	else:
		print("BOSS MECHANICS: %d FAILURES out of %d checks" % [failures, checks])
	quit(1 if failures > 0 else 0)
