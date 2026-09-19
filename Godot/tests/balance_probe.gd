extends SceneTree

# =============================================================================
# Balance Probe — permanent trajectory bot
# =============================================================================
# See Docs/ARCHITECTURE.md, section "The 250-stage difficulty curve". This is the
# restored, permanent version of the one-off balance_probe.gd that was deleted
# after its original use. It plays a full, unassisted trajectory through the
# campaign, measures the four-band curve, and fails the run (non-zero exit) if
# the measured curve no longer matches what content.gd's bands are supposed to
# deliver.
#
# WHAT IT MODELS (the way a real, non-optimizing player would)
#   * The real SpiritCombat rules engine and the real ai_best_play() heuristic.
#   * Real progression: the campaign branch of _grant_stage_rewards() runs, so
#     unlocked/position, boss equipment, elite runes, boss/great-boss relics and
#     Hero Mastery XP all accumulate exactly as they do in play.
#   * Real reward drafting: the best of the same three deterministic reward
#     options, scored by the same _card_build_score the auto-builder uses and
#     added through the real _smart_add_card() (25-card cap, Starter-first
#     eviction), so the deck evolves the way a real autopilot player's would.
#   * Combat difficulty only. Stamina and gold are topped up every stage to
#     isolate the encounter curve from the stamina/shop economy (the plan this
#     suite came from scopes it exactly that way).
#
# WHAT IT DELIBERATELY DOES NOT DO
#   * It does not call begin_battle(). That path seeds the shuffle and the battle
#     modifier from Time.get_unix_time_from_system() (game_battle_screen.gd),
#     which makes any run non-reproducible — the one property a regression suite
#     cannot do without. Instead it builds SpiritCombat with a fixed
#     per-(stage, attempt) seed and an empty modifier, so the measurement
#     reflects the authored chapter factor rather than a random +30% HP roll.
#     This is the identical rules engine begin_battle drives, minus animation.
#   * It does not drive the battle-screen animations (irrelevant to balance) and
#     does not touch the gold economy, shop, or camera/UI.
#
# USAGE
#   godot --headless --path Godot -s tests/balance_probe.gd              # full
#   godot --headless --path Godot -s tests/balance_probe.gd -- --quick   # CI
#
# FULL vs QUICK
#   Full runs the trajectory with the real 8-retry rule and full per-band
#   telemetry. Quick caps retries at 1 so CI does not grind a wall eight times
#   before reporting it. Both stop the trajectory at the first stage that can't
#   be won (a lost stage grants no reward, so the deck cannot improve and every
#   later stage would be repeated against harder content). Both therefore stay
#   byte-reproducible: every seed comes from _seed_for(), never from the clock.
# =============================================================================

const MAX_RETRIES := 8
const QUICK_MAX_RETRIES := 1
const TURN_GUARD := 300
# Set this to a printed digest to pin a regression baseline (see the telemetry
# report). Left disabled by default so the suite reports the live curve without
# failing CI the moment the deck-building heuristic is legitimately retuned.
const NO_DIGEST := -1
const EXPECTED_DIGEST := NO_DIGEST

var quick_mode := false
var failures := 0
var saved_profile := ""
var had_profile := false

# Per-stage telemetry, indexed by campaign stage (0..total_stages-1).
var total_stages := 0
var stage_is_combat: Array[bool] = []
var stage_attempts: Array[int] = []
var stage_losses: Array[int] = []
var stage_turns: Array[int] = []
var stage_won: Array[bool] = []
var stage_softlock: Array[bool] = []

var first_wall_stage := -1
var softlocked := false
var digest := 5381

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var flag := str(arg)
		if flag == "--quick" or flag == "--balance-quick":
			quick_mode = true
	_run()

func section(name: String) -> void:
	print("\n========================================================")
	print("  BALANCE PROBE: %s" % name)
	print("========================================================")
	printerr("[BALANCE] " + name)

func fail(message: String) -> void:
	failures += 1
	print("  ❌ FAIL: %s" % message)
	printerr("  ❌ FAIL: %s" % message)

func check(condition: bool, message: String) -> void:
	if condition:
		print("  ✅ ok: %s" % message)
	else:
		fail(message)

# Every source of randomness in a run comes from here — stage index and attempt
# number only, never the clock — so the same trajectory is produced every time.
func _seed_for(stage: int, attempt: int) -> int:
	return int((1337 + stage * 7919 + attempt * 104729) & 0x7fffffff)

func _is_combat_kind(kind: String) -> bool:
	return kind in ["battle", "elite", "boss", "greatboss"]

func _chapter_of(stage: int) -> int:
	return stage / 5 + 1

func _band_index(chapter: int) -> int:
	if chapter <= 4: return 0
	if chapter <= 10: return 1
	if chapter <= 20: return 2
	return 3

func _band_name(index: int) -> String:
	return ["Chapters 1-4", "Chapters 5-10", "Chapters 11-20", "Chapters 21-50"][index]

# One battle attempt against `stage`. Mirrors the argument list begin_battle()
# passes to combat.create() (including the literal 60 HP), but with a
# deterministic seed and no battle modifier.
func _simulate_stage(game: Control, stage: int, attempt: int) -> Dictionary:
	var seed := _seed_for(stage, attempt)
	game.current_stage = stage
	game.current_map_chapter = stage / 5
	game.active_modifier = {}
	game.resolving = false
	var combat := SpiritCombat.new(game.content)
	combat.create(
		seed,
		game.content.encounters[stage],
		game.profile.deck.duplicate(),
		60,
		game.profile.upgrades,
		game.profile.equipment_slots.values(),
		game.profile.card_runes,
		{},
		game.profile.relics.duplicate(),
		game._current_hero_mastery_bonuses()
	)
	game.combat = combat

	var guard := 0
	while combat.state.phase == "player" and guard < TURN_GUARD:
		guard += 1
		var decision: Dictionary = combat.ai_best_play()
		var hand_idx: int = int(decision.get("hand_index", -1))
		var target_idx: int = int(decision.get("target_index", -1))
		if hand_idx >= 0 and hand_idx < combat.state.hand.size():
			if target_idx < 0: target_idx = 0
			if combat.play(hand_idx, target_idx):
				continue
			# ai_best_play chose something combat.play rejected (should not happen);
			# end the turn rather than spin on the same decision.
			combat.end_turn()
		else:
			combat.end_turn()
	var is_softlock: bool = guard >= TURN_GUARD and combat.state.phase == "player"
	return {
		"won": combat.state.phase == "won",
		"turns": int(combat.state.turn),
		"softlock": is_softlock,
	}

# Mirrors _auto_handle_card_reward() in game_rewards_screen.gd: the same filtered
# option pool, the same three deterministic picks keyed off current_stage, scored
# by the same _card_build_score, added by the same _smart_add_card.
func _grant_best_reward(game: Control) -> void:
	var options: Array = game.content.cards.filter(func(card): return card.rarity != "Starter" and card.get("rarity", "") != "Curse")
	if options.is_empty(): return
	var chosen: Dictionary = {}
	var best_score: float = -99999.0
	for offset in 3:
		var candidate: Dictionary = options[(game.current_stage + offset) % options.size()]
		var score: float = game._card_build_score(candidate)
		if score > best_score:
			best_score = score
			chosen = candidate
	if not chosen.is_empty():
		game._smart_add_card(chosen)

func _run_trajectory(game: Control) -> void:
	total_stages = game.content.encounters.size()
	stage_is_combat.clear()
	stage_attempts.clear()
	stage_losses.clear()
	stage_turns.clear()
	stage_won.clear()
	stage_softlock.clear()
	for _i in total_stages:
		stage_is_combat.append(false)
		stage_attempts.append(0)
		stage_losses.append(0)
		stage_turns.append(0)
		stage_won.append(false)
		stage_softlock.append(false)

	var max_retries: int = QUICK_MAX_RETRIES if quick_mode else MAX_RETRIES
	var index := 0
	while index < total_stages:
		# Isolate combat difficulty from the economy (see the file header).
		game.profile.stamina.current = int(game.profile.stamina.max)
		game.profile.gold = maxi(int(game.profile.gold), 9999)

		var kind: String = game.content.node_kind(index)
		if not _is_combat_kind(kind):
			# Event / merchant / rest nodes carry no encounter a player actually fights;
			# mark them traversed so the frontier advances as it would in play.
			game.profile.unlocked = maxi(int(game.profile.unlocked), mini(total_stages - 1, index + 1))
			game.profile.position = index
			index += 1
			continue

		stage_is_combat[index] = true
		var attempt := 0
		var won := false
		var turns := 0
		while attempt < max_retries and not won:
			attempt += 1
			var result: Dictionary = _simulate_stage(game, index, attempt)
			if bool(result.get("softlock", false)):
				softlocked = true
				stage_softlock[index] = true
			if bool(result.get("won", false)):
				won = true
				turns = int(result.get("turns", 0))
			else:
				stage_losses[index] += 1
		stage_attempts[index] = attempt
		stage_won[index] = won
		stage_turns[index] = turns
		digest = (digest * 33 + index + attempt * 131 + (1 if won else 0)) & 0x7fffffff

		if won:
			game._grant_stage_rewards()
			_grant_best_reward(game)
		else:
			if first_wall_stage < 0: first_wall_stage = index
			# A loss grants no reward, so the deck cannot improve and every later stage
			# would be repeated against harder content. Record the wall and stop.
			break
		index += 1

func _losses_in_chapters(low: int, high: int) -> int:
	var total := 0
	for stage in total_stages:
		var chapter := _chapter_of(stage)
		if chapter >= low and chapter <= high:
			total += stage_losses[stage]
	return total

func _report(game: Control, start_ms: int) -> void:
	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	var mode := "quick" if quick_mode else "full"

	var band_battles := [0, 0, 0, 0]
	var band_wins := [0, 0, 0, 0]
	var band_losses := [0, 0, 0, 0]
	var band_attempts := [0, 0, 0, 0]
	var band_turns := [0, 0, 0, 0]
	for stage in total_stages:
		if not stage_is_combat[stage]: continue
		var band := _band_index(_chapter_of(stage))
		band_battles[band] += 1
		band_attempts[band] += stage_attempts[stage]
		band_losses[band] += stage_losses[stage]
		if stage_won[stage]:
			band_wins[band] += 1
			band_turns[band] += stage_turns[stage]

	# Fold the final deck into the digest so a change to the drafted deck is caught
	# even when it happens to leave the win/loss pattern identical.
	for id in game.profile.deck:
		var card_id := str(id)
		for i in card_id.length():
			digest = (digest * 33 + card_id.unicode_at(i)) & 0x7fffffff

	section("Trajectory Telemetry (%s mode)" % mode)
	print("--------------------------------------------------------")
	print("  ⏱️  Duration:              %.2f seconds" % elapsed)
	print("  🗺️  Mode:                  %s (max %d retries/stage)" % [mode, QUICK_MAX_RETRIES if quick_mode else MAX_RETRIES])
	print("  🎴 Final deck size:        %d" % game.profile.deck.size())
	var depth_stage: int = first_wall_stage if first_wall_stage >= 0 else total_stages
	print("  🧱 First wall:             %s" % ("none (cleared every stage)" if first_wall_stage < 0 else "stage %d (chapter %d)" % [first_wall_stage, _chapter_of(first_wall_stage)]))
	print("  📈 Deepest chapter:        %d of 50" % _chapter_of(maxi(0, mini(depth_stage, total_stages - 1))))
	print("  🔒 Trajectory digest:      %d" % digest)
	print("--------------------------------------------------------")
	print("  Band             Battles  Wins  Losses  Retries  AvgTurns")
	for i in 4:
		var avg_turns := 0.0
		if band_wins[i] > 0:
			avg_turns = float(band_turns[i]) / float(band_wins[i])
		var retries: int = band_attempts[i] - band_battles[i]
		print("  %-16s %7d %5d %7d %8d %9.1f" % [_band_name(i), band_battles[i], band_wins[i], band_losses[i], retries, avg_turns])
	print("--------------------------------------------------------")

	section("Curve Guardrails")
	var loss_ch1_4 := _losses_in_chapters(1, 4)
	var loss_ch1_10 := _losses_in_chapters(1, 10)
	check(loss_ch1_4 == 0, "chapters 1-4 clearable on autopilot (losses=%d)" % loss_ch1_4)
	check(loss_ch1_10 == 0, "chapters 1-10 clearable without a single loss (losses=%d)" % loss_ch1_10)
	check(depth_stage >= 50, "bot reaches chapter 11 before a wall (deepest stage=%d, chapter %d)" % [depth_stage, _chapter_of(mini(depth_stage, total_stages - 1))])
	check(not softlocked, "no stage exceeded the %d-turn guard (softlock)" % TURN_GUARD)
	if EXPECTED_DIGEST != NO_DIGEST:
		check(digest == EXPECTED_DIGEST, "trajectory digest matches pinned baseline (%d)" % digest)

func _restore_save() -> void:
	if had_profile and not saved_profile.is_empty():
		var file := FileAccess.open(SpiritSave.PATH, FileAccess.WRITE)
		file.store_string(saved_profile)
	elif FileAccess.file_exists(SpiritSave.PATH):
		DirAccess.remove_absolute(SpiritSave.PATH)

func _run() -> void:
	var start_ms := Time.get_ticks_msec()
	had_profile = FileAccess.file_exists(SpiritSave.PATH)
	if had_profile:
		saved_profile = FileAccess.open(SpiritSave.PATH, FileAccess.READ).get_as_text()

	var scene: PackedScene = load("res://Main.tscn")
	var game: Control = scene.instantiate()
	if not game.has_method("show_map"):
		fail("game.gd did not attach or failed to parse")
		_restore_save()
		quit(1)
		return

	root.add_child(game)
	await process_frame

	# Fresh campaign profile, ample resources: stamina/gold are topped up again
	# every stage, so these only need to be valid at the start.
	game.profile = SpiritSave.defaults(game.content)
	game.profile.gold = 9999
	game.profile.spirit_jade = 100
	game.profile.currencies = {
		"gold": 9999,
		"spirit_jade": 100,
		"trial_token": 50,
		"abyss_shard": 10
	}
	game.profile.stamina = {
		"current": 100,
		"max": 100,
		"last_regen_time": Time.get_unix_time_from_system()
	}
	game.lang = "zh-Hans"
	game.battle_speed = 50.0
	await process_frame

	section("Trajectory (%s)" % ("quick" if quick_mode else "full"))
	_run_trajectory(game)
	_report(game, start_ms)

	_restore_save()

	if failures == 0:
		print("\n🏆 BALANCE PROBE: CURVE HOLDS (0 FAILURES)\n")
		quit(0)
	else:
		print("\n💥 BALANCE PROBE: CURVE DRIFTED (%d FAILURES)\n" % failures)
		quit(1)
