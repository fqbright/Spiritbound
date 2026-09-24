extends SceneTree

# =============================================================================
# Balance Probe — permanent trajectory bot
# =============================================================================
# Docs/ARCHITECTURE.md's "250-stage difficulty curve" section has the full history: the
# original balance_probe.gd was deleted after its one-time use and didn't survive in this
# repo's history, and the curve was never re-validated after "every battle resets HP to a flat
# 60" replaced inter-battle HP attrition as the resource-pressure model the curve was
# originally tuned against. This is that re-validation, rebuilt from scratch as a permanent,
# CI-wired regression suite rather than a one-off diagnostic.
#
# WHAT IT MODELS (the way a diligent, deck-optimizing player would)
#   * The real SpiritCombat rules engine and the real ai_best_play() heuristic — no shortcuts
#     or simplified combat math.
#   * Real progression, driven through the actual game.gd entry points rather than a
#     hand-duplicated formula, so this can't quietly drift out of sync with the real game the
#     way a mirrored scorer can: the campaign branch of _grant_stage_rewards() runs for real
#     (unlocked/position, boss equipment, elite runes, boss/great-boss relics, Hero Mastery XP,
#     and quest/career tracking all accumulate exactly as they do in play), reward drafting
#     uses the real _card_build_score()/_smart_add_card() (25-card cap, Starter-first
#     eviction), and hero mastery bonuses come from the real _current_hero_mastery_bonuses().
#   * A farming loop layered on top of that real pipeline: rest nodes and (half of) event nodes
#     take the same free Purify-or-Smith deck upgrade a min-maxer would (see AGENTS.md's
#     "Campfire Rest Site Rituals"), merchant nodes spend gold on the Shop Purge Service when a
#     Starter filler card remains, one best-scoring affordable card is bought from the Shop
#     once per chapter, and any rune the real reward pipeline drops gets socketed into the deck
#     the instant a RUNE_SETS pair's second half arrives. A version of this probe that skips
#     every rest/event/merchant node outright is silently modeling a player who never spends a
#     single one of the dozens of free permanent upgrades available across a 250-stage run —
#     the likely reason Band 4 (chapters 21-50) kept reading as needing "farmed gear" nobody had
#     actually modeled taking. See FARMED_DEPTH_FLOOR_STAGE's own comment for how deep that
#     loop is actually measured to reach.
#
# WHAT IT DELIBERATELY DOES NOT DO
#   * It does not call begin_battle(). That path seeds the shuffle and the battle modifier from
#     Time.get_unix_time_from_system() (game_battle_screen.gd), which makes any run
#     non-reproducible — the one property a regression suite cannot do without. Instead it
#     builds SpiritCombat with a fixed per-(stage, attempt) seed and an empty modifier, so the
#     measurement reflects the authored chapter factor rather than a random +30% HP roll. This
#     is the identical rules engine begin_battle drives, minus animation.
#   * It does not drive battle-screen animations (irrelevant to balance) and does not touch the
#     camera/UI.
#   * By default it does not model the gold economy itself as a constraint — stamina and gold
#     are topped up every stage (the farming loop above does spend gold, but it's always
#     replenished by the very next stage's top-up), so this measures combat difficulty and
#     deck-building quality only, never "can a player afford this." --gold (Docs/
#     BALANCE_REVALIDATION.md's suggestion #1) switches that off: gold then starts at the real
#     default and is never topped up, so the same farming loop's shop/merchant spends are for
#     real. Diagnostic only for now (see gold_mode's own comment) — it reports depth and final
#     gold rather than gating CI, since there's no measured baseline yet to responsibly floor it
#     against.
#   * It does not reproduce the Shop's true once-per-wall-clock-day stock reset (only that its
#     roll is itself deterministic given a seed) — it approximates "checks the shop about once
#     per chapter" by feeding the chapter number in as the day-seed proxy instead of a real
#     epoch day; see _maybe_shop_visit()'s own comment.
#
# USAGE
#   godot --headless --path Godot -s tests/balance_probe.gd              # full
#   godot --headless --path Godot -s tests/balance_probe.gd -- --quick   # CI
#   godot --headless --path Godot -s tests/balance_probe.gd -- --gold    # gold-constrained (diagnostic)
#
# FULL vs QUICK
#   Full retries a lost stage up to MAX_RETRIES times before calling it a wall; quick caps
#   retries at QUICK_MAX_RETRIES so CI doesn't grind a wall repeatedly before reporting it. Both
#   stop the trajectory at the first stage that can't be won within its retry budget (a lost
#   stage grants no reward, so the deck cannot improve and every later stage would be repeated
#   against harder content with a weaker build than it should have). Both stay byte-reproducible
#   — every seed comes from _seed_for(), never from the clock. --gold combines with either.
# =============================================================================

const MAX_RETRIES := 8
const QUICK_MAX_RETRIES := 1
const TURN_GUARD := 300
# Set this to a printed digest to pin a regression baseline (see the telemetry report). Left
# disabled by default so the suite reports the live curve without failing CI the moment the
# deck-building heuristic or the content it scores is legitimately retuned — see
# Docs/BALANCE_REVALIDATION.md's suggestion #2 for the reasoning on when it's worth pinning.
const NO_DIGEST := -1
const EXPECTED_DIGEST := NO_DIGEST

# Mirrors game_shop_deck_screen.gd's own SHOP_STOCK_COUNT — duplicated because that constant
# lives on the ShopDeckScreen composition object, which needs a live SpiritGame plus its own
# _init() to construct, while this probe only reaches game.gd's public/delegator surface plus
# SpiritContent/SpiritCombat directly.
const SHOP_STOCK_COUNT := 10

# Regression floors for the farmed-depth guardrail in _report(), one per retry budget since
# quick mode's single retry is a meaningfully harsher policy than full mode's eight and reaches
# a different, shallower wall — using one shared floor left quick mode passing with exactly
# zero margin. Measured on the current content/balance: full mode reaches stage 199 (chapter
# 40) and quick mode reaches stage 99 (chapter 20); these floors sit ~15-20% below each,
# mirroring the margin the original single-mode probe kept below its own measured depth (192,
# floored at 170). Expect these to need lowering, not the game re-balancing to hit them, if a
# legitimate content change genuinely shortens the farmed trajectory.
const FARMED_DEPTH_FLOOR_STAGE_FULL := 170
const FARMED_DEPTH_FLOOR_STAGE_QUICK := 80

var quick_mode := false
# Docs/BALANCE_REVALIDATION.md suggestion #1: everything above this models combat difficulty
# only, topping gold up to 9999 every stage specifically to isolate the encounter curve from
# the economy. --gold disables that top-up so the farming loop's shop/merchant spends (which
# already check affordability against whatever game.profile.gold really is — see
# _maybe_shop_visit()/_handle_noncombat_node()) are for real. Diagnostic only for now: there is
# no measured baseline yet to responsibly floor a depth guardrail against, so this mode reports
# telemetry (final gold, depth reached) without failing the run on depth or losses. Expect a
# gold-constrained build to fall meaningfully short of the infinite-gold depth above — that gap
# is the signal this mode exists to measure, not a bug in it.
var gold_mode := false
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
		if flag == "--gold" or flag == "--balance-gold":
			gold_mode = true
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

# Every source of randomness in a run comes from here — stage index and attempt number only,
# never the clock — so the same trajectory is produced every time.
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

# One battle attempt against `stage`. Mirrors the argument list begin_battle() passes to
# combat.create() (including the literal 60 HP), but with a deterministic seed and no battle
# modifier.
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
			# ai_best_play chose something combat.play rejected (should not happen); end the
			# turn rather than spin on the same decision.
			combat.end_turn()
		else:
			combat.end_turn()
	var is_softlock: bool = guard >= TURN_GUARD and combat.state.phase == "player"
	return {
		"won": combat.state.phase == "won",
		"turns": int(combat.state.turn),
		"softlock": is_softlock,
	}

# Mirrors _auto_handle_card_reward() in game_rewards_screen.gd: the same filtered option pool,
# the same three deterministic picks keyed off current_stage, scored by the same
# _card_build_score, added by the same _smart_add_card.
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

# ---------------------------------------------------------------------------
# Farming loop — the only pieces of a diligent player's turn-to-turn behavior
# that _grant_stage_rewards()/_grant_best_reward() don't already cover for
# real: the free rest/event upgrade, the merchant's paid purge, one shop
# purchase a chapter, and socketing whatever rune the real reward pipeline
# just dropped. Everything else (gold/XP/equipment/relic/rune drops on a
# win) already happens for real inside _grant_stage_rewards() itself.
# ---------------------------------------------------------------------------

# Mirrors game_shop_deck_screen.gd's own _shop_price() exactly (see SHOP_STOCK_COUNT's comment
# for why it's duplicated rather than shared).
func _shop_price(card: Dictionary, owned: int) -> int:
	var base := 90 if card.rarity == "Rare" else 60 if card.rarity == "Uncommon" else 40
	return int(round(float(base) * (1.0 + float(owned) * 0.35) / 5.0)) * 5

# content.roll_shop_stock() is fully deterministic given a seed (a shuffled-indices pick plus
# one seeded RNG call for the sale slot) — no true randomness to reproduce — so unlike the
# Shop's real once-per-wall-clock-day reset, this is tractable to model. Approximates "checks
# the shop roughly once per chapter" by feeding the chapter number itself in as the day-seed
# proxy — roll_shop_stock() only needs its seed to be deterministic and to vary, not to
# correspond to a real epoch day — and buys at most the single best-scoring affordable card,
# ranked by the same real _card_build_score() _grant_best_reward() already uses. Conservative:
# a real min-maxer sitting on several thousand idle gold (nothing else spends it once every
# free Purify/Smith choice and every Shop Purge Service opportunity is already taken) could and
# would buy more than one card a day.
func _maybe_shop_visit(game: Control, chapter: int) -> void:
	var stock: Dictionary = game.content.roll_shop_stock(chapter, SHOP_STOCK_COUNT)
	var stock_cards: Array = stock.get("cards", [])
	var best_i := -1
	var best_score := -INF
	var best_price := 0
	for i in stock_cards.size():
		var card: Dictionary = stock_cards[i]
		if card.is_empty(): continue
		var owned: int = int(game.profile.collection.get(card.id, 0))
		var price: int = _shop_price(card, owned)
		if i == int(stock.get("sale_index", -1)): price = maxi(5, int(round(float(price) * 0.7 / 5.0)) * 5)
		if price > int(game.profile.gold): continue
		var score: float = game._card_build_score(card)
		if score > best_score:
			best_score = score
			best_i = i
			best_price = price
	if best_i >= 0:
		game.profile.gold -= best_price
		game._smart_add_card(stock_cards[best_i])

func _has_starter_card(game: Control) -> bool:
	for card_id in game.profile.deck:
		if str(game.content.card(card_id).get("rarity", "")) == "Starter": return true
	return false

# Mirrors show_deck_purge()'s button-handler mutation exactly (banish a basic starter card and
# transform it into an elite spirit card) while keeping the 25-card deck invariant, since it
# edits the slot in place rather than removing+adding. Data mutation only — the real handler
# also toasts/haptics/writes the save file, UI/persistence side effects this headless probe
# doesn't need (the trajectory only reads game.profile in memory, and _restore_save() fixes the
# save file at the end regardless of how many times _grant_stage_rewards() has already written
# to it mid-run).
func _purify_one_starter(game: Control) -> void:
	for i in game.profile.deck.size():
		var card: Dictionary = game.content.card(game.profile.deck[i])
		if str(card.get("rarity", "")) != "Starter": continue
		var old_id: String = str(card.id)
		var replacement_id: String = "foxfire" if old_id == "strike" else ("mirrorWard" if old_id == "ward" else "wildSpark")
		game.profile.deck[i] = replacement_id
		if int(game.profile.collection.get(old_id, 0)) > 0:
			game.profile.collection[old_id] = maxi(0, int(game.profile.collection[old_id]) - 1)
		game.profile.collection[replacement_id] = int(game.profile.collection.get(replacement_id, 0)) + 1
		return

# The free choice offered at every rest node and half of all event nodes (see game_rewards_
# screen.gd's show_event(): rest_purify/rest_smith, or an event's identical Spirit Blessing/
# Smith buttons) — Purify while a Starter filler card remains (a dead card becomes a real one,
# the bigger power jump), then Smith the current best-scoring un-maxed card, using the real
# _card_build_score() so this naturally concentrates upgrades on whichever card is already most
# worth playing rather than spreading them thin.
func _free_deck_investment(game: Control) -> void:
	if _has_starter_card(game):
		_purify_one_starter(game)
		return
	var best_id := ""
	var best_score := -INF
	for card_id in game.profile.deck:
		if int(game.profile.upgrades.get(card_id, 0)) >= SpiritContent.MAX_CARD_UPGRADE: continue
		var card: Dictionary = game.content.card(card_id)
		if card.is_empty() or str(card.get("rarity", "")) == "Starter": continue
		var score: float = game._card_build_score(card)
		if score > best_score:
			best_score = score
			best_id = card_id
	if not best_id.is_empty():
		game.profile.upgrades[best_id] = int(game.profile.upgrades.get(best_id, 0)) + 1

# Mirrors game_camp_screen.gd's loadout rule exactly (see its "available" computation): a rune
# can be socketed onto one card per copy owned (rune_inventory[id] minus however many cards
# already carry that exact rune id). Greedy and immediate — socket a rune's card slot the
# instant a copy drops (the real reward pipeline already adds elite drops to rune_inventory;
# this is just the equip step a real player would also take), rather than waiting for both
# halves of a set to land in hand at once; the resonance itself only activates once both are
# socketed (content.active_rune_sets() checks card_runes.values() for both ids), so socketing
# early costs nothing and this converges to full resonance the moment the second half drops.
func _maybe_socket_rune_sets(game: Control) -> void:
	for rune_set in SpiritContent.RUNE_SETS:
		for rune_id in rune_set.runes:
			var available: int = int(game.profile.rune_inventory.get(rune_id, 0)) - game.profile.card_runes.values().count(rune_id)
			if available <= 0: continue
			for card_id in game.profile.deck:
				if game.profile.card_runes.has(card_id): continue
				game.profile.card_runes[card_id] = rune_id
				break

# rest and (the "event" half of) the level-2 node both offer the same free Purify/Smith choice
# (show_event()'s "event" and "rest" branches render identical Spirit Blessing/Smith buttons
# alongside a gold option a diligent min-maxer would not prefer over a permanent upgrade); the
# "merchant" half of level-2 has no free option, only the paid Shop Purge Service (◆50, same
# Purify effect as the free one) or a flat +25 gold consolation.
func _handle_noncombat_node(game: Control, kind: String) -> void:
	match kind:
		"rest", "event":
			_free_deck_investment(game)
		"merchant":
			if int(game.profile.gold) >= 50 and _has_starter_card(game):
				game.profile.gold -= 50
				_purify_one_starter(game)
			else:
				game.profile.gold += 25

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
		# Isolate combat difficulty from the stamina economy (see the file header) — stamina is
		# always topped up. Gold is too, UNLESS --gold is set, in which case the farming loop's
		# shop/merchant spends below are constrained by whatever gold real stage rewards have
		# actually produced (see gold_mode's own comment).
		game.profile.stamina.current = int(game.profile.stamina.max)
		if not gold_mode:
			game.profile.gold = maxi(int(game.profile.gold), 9999)

		var chapter := _chapter_of(index)
		if index % 5 == 0: _maybe_shop_visit(game, chapter)

		var kind: String = game.content.node_kind(index)
		if not _is_combat_kind(kind):
			_handle_noncombat_node(game, kind)
			# Event / merchant / rest nodes carry no encounter a player actually fights; mark
			# them traversed so the frontier advances as it would in play.
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
			_maybe_socket_rune_sets(game)
		else:
			if first_wall_stage < 0: first_wall_stage = index
			# A loss grants no reward, so the deck cannot improve and every later stage would be
			# repeated against harder content. Record the wall and stop.
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
	if gold_mode: mode += ", gold-constrained"

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

	# Fold the final deck into the digest so a change to the drafted deck is caught even when it
	# happens to leave the win/loss pattern identical.
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

	var active_set_names: Array = []
	for rune_set in SpiritContent.RUNE_SETS:
		if game.content.active_rune_sets(game.profile.card_runes).has(rune_set.id): active_set_names.append(rune_set.name_en)
	var upgrade_total := 0
	for lvl in game.profile.upgrades.values(): upgrade_total += int(lvl)
	var starters_left: int = game.profile.deck.filter(func(cid): return str(game.content.card(cid).get("rarity", "")) == "Starter").size()
	print("  🔥 Farming:                %d starter(s) left, %d upgrade level(s), active rune sets: %s" % [starters_left, upgrade_total, active_set_names])
	if gold_mode: print("  💰 Final gold:             %d" % int(game.profile.gold))
	print("--------------------------------------------------------")

	section("Curve Guardrails")
	var loss_ch1_4 := _losses_in_chapters(1, 4)
	var loss_ch1_10 := _losses_in_chapters(1, 10)
	check(loss_ch1_4 == 0, "chapters 1-4 clearable on autopilot (losses=%d)" % loss_ch1_4)
	check(loss_ch1_10 == 0, "chapters 1-10 clearable without a single loss (losses=%d)" % loss_ch1_10)
	if gold_mode:
		# Docs/BALANCE_REVALIDATION.md suggestion #1: diagnostic only for now — report the
		# gold-constrained depth rather than failing on it, since there's no measured baseline
		# yet to responsibly floor it against (see gold_mode's own comment at the top).
		print("  ℹ️  gold-constrained depth: stage %d / chapter %d (informational — not gated yet)" % [depth_stage, _chapter_of(mini(depth_stage, total_stages - 1))])
	else:
		var depth_floor: int = FARMED_DEPTH_FLOOR_STAGE_QUICK if quick_mode else FARMED_DEPTH_FLOOR_STAGE_FULL
		check(depth_stage >= depth_floor, "farmed build reaches at least stage %d / chapter %d before a wall (deepest stage=%d, chapter %d)" % [depth_floor, _chapter_of(depth_floor), depth_stage, _chapter_of(mini(depth_stage, total_stages - 1))])
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

	# Fresh campaign profile. Stamina is topped up again every stage regardless of mode. Gold
	# starts at the same ample 9999 unless --gold is set, in which case it keeps
	# SpiritSave.defaults()'s real starting amount and is never topped up again (see gold_mode's
	# own comment) — everything the farming loop spends from here on is real.
	game.profile = SpiritSave.defaults(game.content)
	if not gold_mode:
		game.profile.gold = 9999
	game.profile.spirit_jade = 100
	game.profile.stamina = {
		"current": 100,
		"max": 100,
		"last_regen_time": Time.get_unix_time_from_system()
	}
	game.lang = "zh-Hans"
	game.battle_speed = 50.0
	await process_frame

	var mode_label := "quick" if quick_mode else "full"
	if gold_mode: mode_label += ", gold-constrained"
	section("Trajectory (%s)" % mode_label)
	_run_trajectory(game)
	_report(game, start_ms)

	_restore_save()

	if failures == 0:
		print("\n🏆 BALANCE PROBE: CURVE HOLDS (0 FAILURES)\n")
		quit(0)
	else:
		print("\n💥 BALANCE PROBE: CURVE DRIFTED (%d FAILURES)\n" % failures)
		quit(1)
