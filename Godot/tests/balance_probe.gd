extends SceneTree
# Docs/ARCHITECTURE.md's "250-stage difficulty curve" section: the original balance_probe.gd
# was deleted after its one-time use and didn't survive in this repo's history, and the curve
# was never re-validated after "every battle resets HP to a flat 60" replaced inter-battle HP
# attrition as the resource-pressure model this curve was originally tuned against. This is
# that re-validation, rebuilt from scratch.
#
# Not a pass/fail test — a diagnostic report. Drives combat.gd directly (SpiritContent/
# SpiritCombat only, no Main.tscn/node instantiation at all — matching combat.gd's own "never
# references a node" boundary), so all 250 stages simulate in well under a second instead of
# minutes of animated UI playthrough.
#
# Simplifications, all in the conservative direction (a real diligent player would do at least
# this well, usually better): no merchant purchases (event/merchant/rest nodes are skipped —
# rest's heal is moot now that HP resets every battle anyway), no deliberate rune-set
# socketing (card_runes stays empty, so the swift/cycle/burning/execute/guardian/siphon set
# bonuses never activate), and a single fixed hero (fox_spirit, the beginner-recommended
# class) with no Rebirth bonuses. Equipment/relic/rune drops follow the same deterministic
# rotation _grant_stage_rewards() uses at difficulty A0; card rewards use the same
# _card_build_score formula and smart-add replacement rule show_reward_details()'s "smart add"
# button uses (duplicated here rather than calling into game_shop_deck_screen.gd, the same
# reason combat.gd's own duplicated-formula precedent exists — see _score_card()).

var content: SpiritContent
const HERO_ID := "fox_spirit"
const MAX_STEPS_PER_BATTLE := 60
const MAX_ATTEMPTS_PER_STAGE := 3
# Diagnostic-only: keep simulating stages after an unbeaten one instead of stopping, to see
# the curve's shape beyond the first wall. Real players cannot do this — see the print site
# for why it's still a useful signal. Toggle off for the "how far does a straight run actually
# get" report.
const CONTINUE_PAST_WALLS := false

var deck: Array = []
var collection: Dictionary = {}
var upgrades: Dictionary = {}
var card_runes: Dictionary = {}
var relics: Array = []
var equipment_owned: Array = []
var equipment_slots: Dictionary = {"weapon": "", "armor": "", "charm": ""}
var rune_inventory: Dictionary = {}
var hero_xp: int = 0
var gold: int = 0

func _init() -> void:
	call_deferred("run")

func _band_key(chapter: int) -> String:
	if chapter <= 4: return "Band1 Ch1-4   (trivial / autopilot)"
	if chapter <= 10: return "Band2 Ch5-10  (sequencing matters)"
	if chapter <= 20: return "Band3 Ch11-20 (needs a built deck)"
	return "Band4 Ch21-50 (needs farmed gear)"

# Mirrors game_shop_deck_screen.gd's _card_build_score() exactly, over this script's local
# upgrades/card_runes instead of g.profile.* — see the file header for why it's duplicated
# rather than shared. Keep this in sync if the real one changes.
func _score_card(card: Dictionary) -> float:
	var score := 0.0
	var attack_double: float = 2.0 if str(card.get("special", "")) == "critical" else 1.0
	for effect in card.get("effects", []):
		match str(effect.get("operation", "")):
			"damage": score += float(effect.amount) * 2.2 * attack_double
			"shield": score += float(effect.amount) * 1.6
			"heal": score += float(effect.amount) * 1.0
			"draw": score += float(effect.amount) * 3.0
			"energy": score += float(effect.amount) * 4.0
			"status":
				match str(effect.get("status", "")):
					"burn": score += float(effect.amount) * 1.3
					"poison": score += float(effect.amount) * 1.5
					"focus": score += float(effect.amount) * 2.0
					"strength": score += float(effect.amount) * 3.0
					"vulnerable", "weak": score += float(effect.amount) * 1.8
	match str(card.get("special", "")):
		"cleave": score *= 1.35
		"pierce": score += 3.0
		"stun": score += 5.0
		"recoverExhaust", "recycleDiscard": score += 4.0
	score += {"Rare": 4.0, "Uncommon": 2.0, "Common": 1.0}.get(card.get("rarity", "Common"), 0.0)
	score += float(int(upgrades.get(card.id, 0))) * 6.0
	score -= float(int(card.cost)) * 3.0
	if not str(card_runes.get(card.id, "")).is_empty(): score += 8.0
	return score

# Mirrors game_rewards_screen.gd's _smart_add_card(): append while under 25, otherwise
# replace the lowest-scoring non-Starter card (a slight bonus against cutting a duplicate of
# the card just being added, matching the real logic).
func _smart_add(card: Dictionary) -> void:
	collection[card.id] = int(collection.get(card.id, 0)) + 1
	if deck.size() < 25:
		deck.append(card.id)
		return
	var worst := -1
	var worst_score := INF
	for i in deck.size():
		var existing: Dictionary = content.card(deck[i])
		if existing.is_empty(): continue
		var score: float = _score_card(existing)
		if str(existing.get("rarity", "")) == "Starter": score -= 100.0
		if str(existing.id) == str(card.id): score += 60.0
		if score < worst_score:
			worst_score = score
			worst = i
	if worst < 0: worst = 0
	deck[worst] = card.id

func _grant_rewards(index: int, kind: String) -> void:
	var encounter: Dictionary = content.encounters[index]
	gold += int(round(encounter.reward))
	hero_xp += 24 if content.is_boss_kind(kind) else 12

	var options: Array = content.cards.filter(func(c): return c.get("rarity", "") != "Starter" and c.get("rarity", "") != "Curse")
	var chosen: Dictionary = {}
	var best_score: float = -99999.0
	for offset in 3:
		var candidate: Dictionary = options[(index + offset) % options.size()]
		var sc: float = _score_card(candidate)
		if sc > best_score:
			best_score = sc
			chosen = candidate
	if not chosen.is_empty(): _smart_add(chosen)

	if content.is_boss_kind(kind):
		var order := ["emberBlade", "jadePlate", "soulPendant", "moonStaff", "thornArmor", "tideCharm", "stoneSpear", "mistCloak", "fortuneSeal", "stormBow", "phoenixMail", "focusCharm"]
		var eq_id: String = order[(index / 5) % order.size()]
		if not equipment_owned.has(eq_id): equipment_owned.append(eq_id)
		for e in SpiritContent.EQUIPMENT:
			if str(e.id) == eq_id:
				equipment_slots[str(e.slot)] = eq_id
				break

		var relic_pool: Array = SpiritContent.RELICS
		if kind == "greatboss":
			relic_pool = SpiritContent.RELICS.filter(func(r): return SpiritContent.BOSS_RELIC_IDS.has(r.id))
		else:
			relic_pool = SpiritContent.RELICS.filter(func(r): return not SpiritContent.BOSS_RELIC_IDS.has(r.id))
		var relic: Dictionary = relic_pool[(index / 5) % relic_pool.size()]
		if not relics.has(relic.id): relics.append(relic.id)
	elif kind == "elite":
		var rune: Dictionary = SpiritContent.RUNES[(index / 5) % SpiritContent.RUNES.size()]
		rune_inventory[rune.id] = int(rune_inventory.get(rune.id, 0)) + 1

func _simulate(index: int, attempt: int) -> Dictionary:
	var combat := SpiritCombat.new(content)
	var equipped: Array = equipment_slots.values().filter(func(v): return not str(v).is_empty())
	var hero_bonuses: Dictionary = content.mastery_bonuses(HERO_ID, content.mastery_level_for_xp(hero_xp))
	combat.create(index * 97 + attempt, content.encounters[index], deck, 60, upgrades, equipped, card_runes, {}, relics, hero_bonuses)
	var steps := 0
	while combat.state.phase == "player" and steps < MAX_STEPS_PER_BATTLE:
		steps += 1
		var decision: Dictionary = combat.ai_best_play()
		var hand_idx: int = int(decision.get("hand_index", -1))
		if hand_idx >= 0:
			combat.play(hand_idx, int(decision.get("target_index", -1)))
		else:
			combat.end_turn()
	return {"won": combat.state.phase == "won", "turns": int(combat.state.turn), "steps": steps}

func run() -> void:
	content = SpiritContent.new()
	deck = content.raw.startingDeck.duplicate()
	for id in deck: collection[id] = int(collection.get(id, 0)) + 1

	var band_order: Array = []
	var bands: Dictionary = {}
	var stuck_at := -1

	print("\n========================================================")
	print("  SPIRITBOUND BALANCE PROBE — 250-stage difficulty curve")
	print("========================================================\n")

	for index in content.encounters.size():
		var kind: String = content.node_kind(index)
		if kind in ["event", "merchant", "rest"]: continue
		var chapter: int = index / 5 + 1
		var band_key: String = _band_key(chapter)
		if not bands.has(band_key):
			bands[band_key] = {"stages": 0, "first_try": 0, "cleared": 0, "attempts": 0, "turns": []}
			band_order.append(band_key)
		bands[band_key].stages += 1

		var attempts := 0
		var won := false
		var result: Dictionary = {}
		while attempts < MAX_ATTEMPTS_PER_STAGE and not won:
			attempts += 1
			result = _simulate(index, attempts)
			won = bool(result.won)
		bands[band_key].attempts += attempts

		if won:
			bands[band_key].cleared += 1
			if attempts == 1: bands[band_key].first_try += 1
			bands[band_key].turns.append(int(result.turns))
			_grant_rewards(index, kind)
		else:
			if stuck_at < 0: stuck_at = index
			print("  🧱 STUCK at stage %d (chapter %d, %s) after %d attempts — last try: %d turns, %d steps (hit the step cap without winning: %s)" % [index + 1, chapter, kind, attempts, int(result.get("turns", 0)), int(result.get("steps", 0)), result.get("steps", 0) >= MAX_STEPS_PER_BATTLE])
			if not CONTINUE_PAST_WALLS: break
			# Diagnostic-only: a real player can't skip a stage they can't beat, but continuing
			# to probe past one wall (without granting that stage's own rewards, so the build
			# doesn't get credit for a stage it didn't actually clear) shows whether the curve
			# past this point is independently reasonable or compounds into more walls.

	for band_key in band_order:
		var b: Dictionary = bands[band_key]
		var first_pct: float = 100.0 * float(b.first_try) / maxf(1.0, float(b.stages))
		var clear_pct: float = 100.0 * float(b.cleared) / maxf(1.0, float(b.stages))
		var avg_attempts: float = float(b.attempts) / maxf(1.0, float(b.cleared if b.cleared > 0 else b.stages))
		var avg_turns: float = 0.0
		if not b.turns.is_empty():
			var sum := 0
			for t in b.turns: sum += t
			avg_turns = float(sum) / float(b.turns.size())
		print("%s: %d/%d cleared (%.0f%%), %.0f%% first-try, avg %.1f attempts/stage, avg %.1f turns/win" % [band_key, b.cleared, b.stages, clear_pct, first_pct, avg_attempts, avg_turns])

	print("\n--------------------------------------------------------")
	print("Final build: %d gold, %d cards in collection, deck=%s" % [gold, collection.size(), str(deck.size()) + " cards"])
	print("Equipment: %s | Relics: %s | Runes: %s" % [equipment_slots, relics, rune_inventory])
	if stuck_at >= 0:
		print("Progress halted at stage %d / %d (chapter %d of %d)." % [stuck_at + 1, content.encounters.size(), stuck_at / 5 + 1, content.encounters.size() / 5])
	else:
		print("Cleared all %d stages." % content.encounters.size())
	print("--------------------------------------------------------\n")
	quit(0)
