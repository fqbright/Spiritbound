extends RefCounted
class_name RewardsScreen

# Composition, not inheritance — see MapScreen's header comment (game_map_screen.gd) for
# why. `g` is the live SpiritGame instance; every reference to shared state or another
# screen's function goes through it.
var g: SpiritGame

func _init(game: SpiritGame) -> void:
	g = game

func show_reward() -> void:
	g._clear(); g._play_music(false)
	var page := g._create_page(10)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(g._label(g.t("ui.battle_won"), 26, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	var chest := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = g._texture("chest-atlas-v1.png")
	atlas.region = Rect2(0, 0, atlas.atlas.get_width() / 2.0, atlas.atlas.get_height())
	chest.texture = atlas
	chest.custom_minimum_size = Vector2(200, 180)
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest.pivot_offset = Vector2(100, 90)
	page.add_child(chest)

	var open := g._button(g.t("ui.open_chest"), Callable(), g.EMBER, Vector2(220, 52))
	open.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open.pressed.connect(func(): _open_chest(chest, atlas, open))
	page.add_child(open)
	if g.auto_battle_active:
		_auto_handle_chest(chest, atlas, open)

func _auto_handle_chest(chest: TextureRect, atlas: AtlasTexture, button: Button) -> void:
	await g.get_tree().create_timer(g._battle_delay(0.3)).timeout
	if not g.auto_battle_active or button == null or not is_instance_valid(button): return
	_open_chest(chest, atlas, button)

func _open_chest(chest: TextureRect, atlas: AtlasTexture, button: Button) -> void:
	button.disabled = true
	g._haptic("heavy")
	var shake := chest.create_tween()
	shake.tween_property(chest, "rotation", -0.05, 0.08)
	shake.tween_property(chest, "rotation", 0.05, 0.08)
	shake.tween_property(chest, "rotation", -0.03, 0.07)
	shake.tween_property(chest, "rotation", 0.0, 0.07)
	await shake.finished

	atlas.region.position.x = atlas.atlas.get_width() / 2.0
	chest.texture = atlas
	g._shake_screen(6.0)
	g.play_sfx("chest_open")
	g.play_sfx("coin")
	var pop := chest.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(chest, "scale", Vector2(1.12, 1.12), 0.16)
	pop.tween_property(chest, "scale", Vector2.ONE, 0.12)
	await pop.finished
	await g.get_tree().create_timer(g._battle_delay(0.25)).timeout

	_grant_stage_rewards()
	g._advance_quest("open_chest", 1)
	if g.pending_boon_draft:
		g.pending_boon_draft = false
		g.show_abyss_boon_draft()
		return
	# The chest and its button have done their job; rebuild the page so only the
	# rewards and the card choice remain on screen.
	show_reward_details()

# A stage below the unlock frontier has been cleared before. Stages cannot be skipped, so
# this is a reliable "have I already beaten it" test without tracking a separate set.
func _is_replay(index: int) -> bool:
	return index < int(g.profile.unlocked)

func _is_stage_event_claimed(index: int) -> bool:
	if _is_replay(index): return true
	return g.profile.get("claimed_stage_events", []).has(index)

func _mark_stage_event_claimed(index: int) -> void:
	if not g.profile.has("claimed_stage_events") or not g.profile.claimed_stage_events is Array:
		g.profile.claimed_stage_events = []
	if not g.profile.claimed_stage_events.has(index):
		g.profile.claimed_stage_events.append(index)
		SpiritSave.write(g.profile)

# Compendium discovery is a permanent log, not a live inventory: a card/relic/rune/equipment
# never un-discovers even in a hypothetical future where it could be lost, and a Bestiary
# entry has no other tracking array to fall back on. The _x_discovered() helpers below still
# OR in the existing inventory arrays as a fallback so saves from before this milestone show
# their already-owned items as discovered without needing a migration pass.
func _compendium_dict(category: String) -> Dictionary:
	if not g.profile.get("compendium_discovered") is Dictionary: g.profile.compendium_discovered = {}
	if not g.profile.compendium_discovered.get(category) is Dictionary: g.profile.compendium_discovered[category] = {}
	return g.profile.compendium_discovered[category]

func _mark_discovered(category: String, key: String) -> bool:
	var dict := _compendium_dict(category)
	if bool(dict.get(key, false)): return false
	dict[key] = true
	SpiritSave.write(g.profile)
	return true

# C4: a small one-time reward the instant a bestiary entry is newly discovered, so filling out
# the Compendium has immediate in-battle feedback instead of only a percentage on a Camp
# screen. Fires from every _mark_discovered("bestiary", ...) call site (campaign, Abyss, Daily
# Trial, and Weekly Challenge battles) — all of which call it right as a battle begins, so this
# reads to the player as "first time facing this foe," not literally "first kill."
func _grant_bestiary_discovery_bonus(encounter: Dictionary) -> void:
	var bonus_gold := 20
	g.profile.gold += bonus_gold
	SpiritSave.write(g.profile)
	_grant_mastery_xp(6)
	var display_name: String = str(encounter.get("name_en", encounter.get("name", ""))) if g.lang == "en" else str(encounter.get("name", ""))
	g._toast(g.tf("ui.bestiary_discovery_toast", [display_name, bonus_gold]), Color("9fd8c9"))

func _card_discovered(id: String) -> bool:
	return bool(_compendium_dict("cards").get(id, false)) or int(g.profile.collection.get(id, 0)) > 0

func _equip_discovered(id: String) -> bool:
	return bool(_compendium_dict("equipment").get(id, false)) or g.profile.equipment_owned.has(id)

func _rune_discovered(id: String) -> bool:
	return bool(_compendium_dict("runes").get(id, false)) or int(g.profile.rune_inventory.get(id, 0)) > 0 or g.profile.card_runes.values().has(id)

func _relic_discovered(id: String) -> bool:
	return bool(_compendium_dict("relics").get(id, false)) or g.profile.relics.has(id)

func _bestiary_discovered(enemy_name: String) -> bool:
	return bool(_compendium_dict("bestiary").get(enemy_name, false))

func _compendium_totals() -> Vector2i:
	var discovered := 0
	var total := 0
	for c in g.content.cards:
		if c.get("rarity", "") == "Curse": continue
		total += 1
		if _card_discovered(c.id): discovered += 1
	for e in SpiritContent.EQUIPMENT:
		total += 1
		if _equip_discovered(e.id): discovered += 1
	for r in SpiritContent.RUNES:
		total += 1
		if _rune_discovered(r.id): discovered += 1
	for r in SpiritContent.RELICS:
		total += 1
		if _relic_discovered(r.id): discovered += 1
	for e in SpiritContent.ENEMIES:
		total += 1
		if _bestiary_discovered(str(e.name)): discovered += 1
	return Vector2i(discovered, total)

# Every battle win feeds mastery XP to whichever hero is currently equipped — a boss kill is
# worth double a regular fight. Abyss and Daily Trial wins call this with their own flat
# amounts since neither has a "kind" to scale off of.
func _grant_mastery_xp(amount: int) -> void:
	if amount <= 0: return
	var hero_id: String = str(g.profile.hero_class)
	if not g.profile.get("hero_masteries") is Dictionary: g.profile.hero_masteries = {}
	var entry: Dictionary = g.profile.hero_masteries.get(hero_id, {"xp": 0})
	var before_level: int = g.content.mastery_level_for_xp(int(entry.get("xp", 0)))
	entry.xp = int(entry.get("xp", 0)) + amount
	g.profile.hero_masteries[hero_id] = entry
	var after_level: int = g.content.mastery_level_for_xp(int(entry.xp))
	if after_level > before_level:
		g._toast(g.tf("ui.mastery_levelup_toast", [g.content.hero_name(g.content.hero_class(hero_id), g.lang), after_level]), g.GOLD)

func _current_hero_mastery_bonuses() -> Dictionary:
	var hero_id: String = str(g.profile.hero_class)
	var xp: int = int(g.profile.get("hero_masteries", {}).get(hero_id, {}).get("xp", 0))
	var bonuses: Dictionary = g.content.mastery_bonuses(hero_id, g.content.mastery_level_for_xp(xp)).duplicate()
	var consumables: Dictionary = g.profile.get("combat_consumables", {})
	if int(consumables.get("strength", 0)) > 0:
		bonuses.strength_start = int(bonuses.get("strength_start", 0)) + int(consumables.strength)
	if int(consumables.get("focus", 0)) > 0:
		bonuses.focus_start = int(bonuses.get("focus_start", 0)) + int(consumables.focus)
	if int(consumables.get("energy", 0)) > 0:
		bonuses.energy_turn1 = int(bonuses.get("energy_turn1", 0)) + int(consumables.energy)
		bonuses.draw_turn1 = int(bonuses.get("draw_turn1", 0)) + 2
	if int(consumables.get("strength", 0)) > 0 or int(consumables.get("focus", 0)) > 0 or int(consumables.get("energy", 0)) > 0:
		g.profile.combat_consumables = {"strength": 0, "focus": 0, "energy": 0}
		SpiritSave.write(g.profile)
	var samsara_cnt: int = int(g.profile.get("samsara_count", 0))
	if samsara_cnt > 0:
		var s_bonuses: Dictionary = g.content.samsara_bonuses(samsara_cnt)
		bonuses.max_hp = int(bonuses.get("max_hp", 0)) + int(s_bonuses.get("max_hp", 0))
		bonuses.shield_start = int(bonuses.get("shield_start", 0)) + int(s_bonuses.get("starting_shield", 0))
		bonuses.draw_turn1 = int(bonuses.get("draw_turn1", 0)) + int(s_bonuses.get("turn1_draw", 0))
	var m_bonuses: Dictionary = g.content.meridian_bonuses(g.profile.get("meridians", {}))
	bonuses.max_hp = int(bonuses.get("max_hp", 0)) + int(m_bonuses.get("max_hp", 0))
	bonuses.shield_start = int(bonuses.get("shield_start", 0)) + int(m_bonuses.get("shield_start", 0))
	bonuses.heal_per_turn = int(bonuses.get("heal_per_turn", 0)) + int(m_bonuses.get("heal_per_turn", 0))
	bonuses.first_attack_bonus = int(bonuses.get("first_attack_bonus", 0)) + int(m_bonuses.get("first_attack_bonus", 0))
	bonuses.burn_start = int(bonuses.get("burn_start", 0)) + int(m_bonuses.get("burn_start", 0))
	bonuses.strength_start = int(bonuses.get("strength_start", 0)) + int(m_bonuses.get("strength_start", 0))
	bonuses.draw_turn1 = int(bonuses.get("draw_turn1", 0)) + int(m_bonuses.get("draw_turn1", 0))
	bonuses.energy_turn1 = int(bonuses.get("energy_turn1", 0)) + int(m_bonuses.get("energy_turn1", 0))
	return bonuses

# Battle screen header/background source of truth: campaign battles index straight into
# g.content.encounters, while Abyss and the Daily Trial are their own procedural tracks that
# don't live in that array (g.current_stage is left at 0 for both, same placeholder abyss
# already used before this existed).
func _current_encounter() -> Dictionary:
	if g.in_abyss: return g.content.abyss_encounter(int(g.profile.get("abyss_floor", 1)))
	if g.in_curse_run:
		var cr: Dictionary = g.profile.get("curse_run", {})
		return g.content.abyss_encounter(int(cr.get("floors", {}).get(str(cr.get("selected", "")), 1)))
	if g.in_world_event: return g.content.world_event_encounter(int(g.profile.world_event_record.get("period", 0)), int(g.profile.unlocked))
	if g.in_daily_trial: return g.content.daily_trial_encounter(int(g.profile.daily_trial_record.get("stage", 0)) + 1)
	if g.in_weekly_challenge: return g.content.weekly_challenge_encounter(int(g.profile.weekly_challenge_record.get("stage", 0)) + 1)
	return g.content.encounters[g.current_stage]

func _current_stage_label() -> String:
	if g.in_sandbox: return g.tf("ui.sandbox_stage_label_fmt", g.content.stage_name(g.current_stage, g.lang))
	if g.in_boss_rush: return g.tf("ui.boss_rush_stage_label_fmt", int(g.profile.get("boss_rush_floor", 1)))
	if g.in_curse_run:
		var cr: Dictionary = g.profile.get("curse_run", {})
		return g.tf("ui.curse_run_stage_label_fmt", int(cr.get("floors", {}).get(str(cr.get("selected", "")), 1)))
	if g.in_world_event:
		var ev: Dictionary = g.content.world_event_for_period(int(g.profile.world_event_record.get("period", 0)))
		return g.tf("ui.world_event_stage_label_fmt", g.content.ui(str(ev.get("nameKey", "")), g.lang))
	if g.in_abyss: return g.tf("ui.abyss_stage_label_fmt", int(g.profile.get("abyss_floor", 1)))
	if g.in_daily_trial: return g.tf("ui.daily_trial_stage_label_fmt", [int(g.profile.daily_trial_record.get("stage", 0)) + 1, SpiritContent.DAILY_TRIAL_STAGES])
	if g.in_weekly_challenge: return g.tf("ui.weekly_challenge_stage_label_fmt", [int(g.profile.weekly_challenge_record.get("stage", 0)) + 1, SpiritContent.WEEKLY_CHALLENGE_STAGES])
	return g.content.stage_name(g.current_stage, g.lang)

func _grant_stage_rewards() -> void:
	g._track_career_win()
	if g.in_phantom_arena:
		g.in_phantom_arena = false
		g._ensure_phantom_arena_current()
		var arena: Dictionary = g.profile.get("phantom_arena", {})
		var wins: int = int(arena.get("wins_today", 0)) + 1
		arena.wins_today = wins
		g.profile.phantom_arena = arena
		var gold_gain: int = 50 + int(g.profile.unlocked) * 4
		g.profile.gold += gold_gain
		g._add_season_xp(50)
		g.profile.health = 60
		g._toast(g.tf("ui.phantom_arena_chest_toast", gold_gain), g.GOLD)
		g.pending_rewards = {"gold": gold_gain, "equipment": "", "rune": "", "relic": "", "phantom_arena": true}
		SpiritSave.write(g.profile)
		return
	if g.in_draft_battle:
		g.in_draft_battle = false
		var draft: Dictionary = g.profile.get("draft_arena", {})
		var wins: int = int(draft.get("wins", 0)) + 1
		draft.wins = wins
		var gold_gain: int = 60 + wins * 30
		g.profile.gold += gold_gain
		g._add_season_xp(75)
		g.profile.health = 60
		if wins >= SpiritContent.DRAFT_WIN_CAP:
			g._toast(g.t("ui.draft_grand_champion"), g.GOLD)
			g.profile.gold += 500
			g._add_season_xp(200)
			g._reset_draft_run()
		else:
			g._toast(g.tf("ui.draft_victory_toast", [wins, gold_gain]), g.GOLD)
		g.pending_rewards = {"gold": gold_gain, "equipment": "", "rune": "", "relic": ""}
		SpiritSave.write(g.profile)
		return
	if g.in_boss_rush:
		g.in_boss_rush = false
		var br_floor: int = int(g.profile.get("boss_rush_floor", 1))
		var br_gold: int = int(round(float(g.content.encounters[g.current_stage].reward) * 1.5))
		g.profile.gold += br_gold
		g.profile.boss_rush_floor = br_floor + 1
		g.profile.boss_rush_record = maxi(int(g.profile.get("boss_rush_record", 0)), br_floor)
		g.profile.health = 60
		g.pending_rewards = {"gold": br_gold, "equipment": "", "rune": "", "relic": "", "boss_rush": true, "boss_rush_floor": br_floor}
		SpiritSave.write(g.profile)
		g._advance_quest("win_battles", 1)
		g._advance_quest("earn_gold", br_gold)
		g._advance_quest("clear_elite_or_boss", 1)
		g.profile.career_stats.bosses_slain = int(g.profile.career_stats.get("bosses_slain", 0)) + 1
		_grant_mastery_xp(24)
		g._add_season_xp(60)
		return
	if g.in_curse_run:
		g.in_curse_run = false
		var curse_run: Dictionary = g.profile.get("curse_run", {})
		var selected: String = str(curse_run.get("selected", ""))
		var m: Dictionary = g.content.mutator(selected)
		var floors: Dictionary = curse_run.get("floors", {})
		var records: Dictionary = curse_run.get("records", {})
		var cleared: Array = curse_run.get("cleared", [])
		var floor_num: int = int(floors.get(selected, 1))
		# Barren Harvest is the one mutator that touches reward-granting rather than combat.gd.
		var reward_mult: float = float(m.get("reward_mult", 1.0))
		var gold_gain: int = int(round((25 + floor_num * 5) * reward_mult))
		g.profile.gold += gold_gain
		floors[selected] = floor_num + 1
		records[selected] = maxi(int(records.get(selected, 0)), floor_num)
		curse_run.floors = floors
		curse_run.records = records
		# Badge floor reached: a permanent, one-time cosmetic unlock per mutator (shown as a
		# checkmark on its picker badge) — not score-ranked or repeatable, just "did you ever
		# clear this one," same spirit as Career Codex's Hall of Fame being about the moment,
		# not a leaderboard.
		if floor_num >= SpiritContent.CURSE_RUN_BADGE_FLOOR and not cleared.has(selected):
			cleared.append(selected)
			curse_run.cleared = cleared
			g._toast(g.tf("ui.curse_run_badge_toast_fmt", g.content.ui(str(m.get("nameKey", "")), g.lang)), Color(str(m.get("color", "ffffff"))))
		g.profile.curse_run = curse_run
		g.profile.health = 60
		g.pending_rewards = {"gold": gold_gain, "equipment": "", "rune": "", "relic": ""}
		SpiritSave.write(g.profile)
		g._advance_quest("win_battles", 1)
		g._advance_quest("earn_gold", gold_gain)
		_grant_mastery_xp(20)
		g._add_season_xp(50)
		return
	if g.in_world_event:
		g.in_world_event = false
		g._ensure_world_event_current()
		var period: int = int(g.profile.world_event_record.get("period", 0))
		var ev: Dictionary = g.content.world_event_for_period(period)
		var we_gold: int = 40 + int(g.profile.unlocked) * 5
		g.profile.gold += we_gold
		# First win of this 4-week period grants a permanent cosmetic badge for that event —
		# same "did you ever do this" spirit as Curse Run's badge (Phase 8), not score-ranked.
		if not bool(g.profile.world_event_record.get("claimed", false)):
			g.profile.world_event_record.claimed = true
			var badges: Array = g.profile.world_event_record.get("badges", [])
			if not badges.has(str(ev.id)):
				badges.append(str(ev.id))
				g.profile.world_event_record.badges = badges
				g._toast(g.tf("ui.world_event_badge_toast_fmt", g.content.ui(str(ev.get("nameKey", "")), g.lang)), Color(str(ev.get("color", "ffffff"))))
		g.profile.health = 60
		g.pending_rewards = {"gold": we_gold, "equipment": "", "rune": "", "relic": ""}
		SpiritSave.write(g.profile)
		g._advance_quest("win_battles", 1)
		g._advance_quest("earn_gold", we_gold)
		_grant_mastery_xp(18)
		g._add_season_xp(40)
		return
	if g.in_abyss:
		g.in_abyss = false
		var floor_num: int = int(g.profile.get("abyss_floor", 1))
		var bonus_mult: float = 1.5 if g.profile.get("abyss_boons", []).has("boon_golden_fortune") else 1.0
		var gold_gain: int = int(round((25 + floor_num * 5) * bonus_mult))
		g.profile.gold += gold_gain
		g.profile.abyss_floor = floor_num + 1
		g.profile.abyss_record = maxi(int(g.profile.get("abyss_record", 0)), floor_num)
		g._submit_abyss_record(g.profile.abyss_record)
		g.profile.health = 60
		g.pending_rewards = {"gold": gold_gain, "equipment": "", "rune": "", "relic": ""}
		SpiritSave.write(g.profile)
		g._advance_quest("win_battles", 1)
		g._advance_quest("earn_gold", gold_gain)
		_grant_mastery_xp(20)
		g._add_season_xp(50)
		if floor_num % 5 == 0:
			g.pending_boon_draft = true
		return
	if g.in_daily_trial:
		g.in_daily_trial = false
		var stage_num: int = int(g.profile.daily_trial_record.stage) + 1
		var gold_gain: int = int(g.content.daily_trial_encounter(stage_num).reward)
		g.profile.gold += gold_gain
		g.profile.daily_trial_record.stage = stage_num
		g.profile.daily_trial_record.best_stage = maxi(int(g.profile.daily_trial_record.get("best_stage", 0)), stage_num)
		g._submit_daily_trial_record(stage_num)
		g.profile.health = 60
		var completed: bool = stage_num >= SpiritContent.DAILY_TRIAL_STAGES
		if completed:
			g.profile.daily_trial_record.badges = int(g.profile.daily_trial_record.get("badges", 0)) + 1
			var streak: int = int(g.profile.daily_trial_record.get("streak", 0)) + 1
			g.profile.daily_trial_record.streak = streak
			var streak_claimed: Array = g.profile.daily_trial_record.get("streak_claimed", []).duplicate()
			for target in [3, 7, 14]:
				if streak >= target and not streak_claimed.has(target):
					streak_claimed.append(target)
					var bonus_gold: int = 100 if target == 3 else (250 if target == 7 else 500)
					g.profile.gold += bonus_gold
					g._toast(g.tf("ui.trial_streak_reward_toast", [target, bonus_gold]), g.GOLD)
			g.profile.daily_trial_record.streak_claimed = streak_claimed
		g.pending_rewards = {"gold": gold_gain, "equipment": "", "rune": "", "relic": "", "daily_trial": true, "daily_trial_stage": stage_num, "daily_trial_completed": completed}
		SpiritSave.write(g.profile)
		g._advance_quest("win_battles", 1)
		g._advance_quest("earn_gold", gold_gain)
		_grant_mastery_xp(12 + stage_num)
		g._add_season_xp(50)
		return
	if g.in_weekly_challenge:
		g.in_weekly_challenge = false
		var w_stage_num: int = int(g.profile.weekly_challenge_record.stage) + 1
		var reward_mult: float = float(g.active_modifier.get("reward_mult", 1.0))
		var w_gold_gain: int = int(round(g.content.weekly_challenge_encounter(w_stage_num).reward * reward_mult))
		g.profile.gold += w_gold_gain
		g.profile.weekly_challenge_record.stage = w_stage_num
		g.profile.weekly_challenge_record.best_stage = maxi(int(g.profile.weekly_challenge_record.get("best_stage", 0)), w_stage_num)
		g.profile.health = 60
		var w_completed: bool = w_stage_num >= SpiritContent.WEEKLY_CHALLENGE_STAGES
		if w_completed:
			g.profile.weekly_challenge_record.badges = int(g.profile.weekly_challenge_record.get("badges", 0)) + 1
		g.pending_rewards = {"gold": w_gold_gain, "equipment": "", "rune": "", "relic": "", "weekly_challenge": true, "weekly_challenge_stage": w_stage_num, "weekly_challenge_completed": w_completed}
		SpiritSave.write(g.profile)
		g._advance_quest("win_battles", 1)
		g._advance_quest("earn_gold", w_gold_gain)
		_grant_mastery_xp(14 + w_stage_num)
		g._add_season_xp(75)
		return
	var encounter: Dictionary = g.content.encounters[g.current_stage]
	var multiplier: float = g.active_modifier.get("reward_scale", 1.0)
	if g.profile.equipment_slots.values().has("fortuneSeal"):
		var fs_tier: int = int(g.profile.get("equipment_tiers", {}).get("fortuneSeal", 0))
		var fs_mult: float = [1.15, 1.25, 1.35, 1.50][clampi(fs_tier, 0, 3)]
		multiplier *= fs_mult
	var inscr_rewards: Dictionary = g.content.aggregate_inscriptions(g.profile.equipment_slots.values(), g.profile.get("equipment_inscriptions", {}))
	if int(inscr_rewards.get("gold", 0)) > 0:
		multiplier *= (1.0 + float(inscr_rewards.gold) / 100.0)
	if int(inscr_rewards.get("dust", 0)) > 0:
		g.profile.spirit_dust = int(g.profile.get("spirit_dust", 0)) + int(inscr_rewards.dust)
	var m_bonuses: Dictionary = g.content.meridian_bonuses(g.profile.get("meridians", {}))
	if float(m_bonuses.get("gold_mult", 1.0)) > 1.0: multiplier *= float(m_bonuses.gold_mult)
	# A cleared stage can no longer be re-entered at all (see _show_replay_mode_prompt), so
	# every campaign win reaching here is a genuine first clear — no more halved "replay"
	# rewards to compute.
	g.pending_rewards = {"gold": int(round(encounter.reward * multiplier)), "equipment": "", "rune": "", "relic": ""}
	g.profile.gold += int(g.pending_rewards.gold)
	g.profile.health = 60
	g.profile.unlocked = maxi(int(g.profile.unlocked), mini(g.content.encounters.size() - 1, g.current_stage + 1))
	g.profile.position = g.current_stage
	_mark_stage_event_claimed(g.current_stage)

	var kind := g.content.node_kind(g.current_stage)
	g._advance_quest("win_battles", 1)
	g._advance_quest("earn_gold", int(g.pending_rewards.gold))
	if g.content.is_boss_kind(kind) or kind == "elite": g._advance_quest("clear_elite_or_boss", 1)
	if kind == "greatboss": g._advance_quest("defeat_great_boss", 1)
	if kind == "elite":
		g.profile.career_stats.elites_slain = int(g.profile.career_stats.get("elites_slain", 0)) + 1
	elif g.content.is_boss_kind(kind):
		g.profile.career_stats.bosses_slain = int(g.profile.career_stats.get("bosses_slain", 0)) + 1
	# Hall of Fame: a snapshot of the deck that just felled a Great Boss, the game's own
	# highest-signal "this was a real run" milestone. Keeps only the most recent 3 rather than
	# ranking by some invented quality score — simplest thing that's still worth showing off.
	if kind == "greatboss":
		var hof: Array = g.profile.career_stats.get("hall_of_fame", [])
		hof.append({
			"stage": g.current_stage, "chapter": g.content.encounters[g.current_stage].chapter,
			"hero_class": g.profile.hero_class, "deck": g.profile.deck.duplicate(),
			"relics": g.profile.relics.duplicate(), "turns": int(g.combat.state.get("turn", 0)),
			"timestamp": int(Time.get_unix_time_from_system()),
		})
		if hof.size() > 3: hof = hof.slice(hof.size() - 3, hof.size())
		g.profile.career_stats.hall_of_fame = hof
	var mastery_xp: int = 24 if g.content.is_boss_kind(kind) else 12
	_grant_mastery_xp(mastery_xp)
	g._add_season_xp(35)

	# Daily First Win bonus
	var today_day: int = int(Time.get_unix_time_from_system() / 86400.0)
	var dfw: Dictionary = g.profile.get("daily_first_win", {})
	if int(dfw.get("day", -1)) != today_day:
		dfw.day = today_day
		dfw.claimed = true
		g.profile.daily_first_win = dfw
		g.profile.gold += 50
		g.profile.spirit_jade = int(g.profile.get("spirit_jade", 0)) + 5
		g._toast(g.t("ui.daily_first_win_title") + " " + g.t("ui.daily_first_win_desc"), g.GOLD)

	if g.content.is_boss_kind(kind):
		var boss_jade: int = 20 if kind == "greatboss" else 10
		g.profile.spirit_jade = int(g.profile.get("spirit_jade", 0)) + boss_jade
		var order := ["emberBlade","jadePlate","soulPendant","moonStaff","thornArmor","tideCharm","stoneSpear","mistCloak","fortuneSeal","stormBow","phoenixMail","focusCharm"]
		var id: String = order[(g.current_stage / 5 + int(g.profile.difficulty) * 2) % order.size()]
		if not g.profile.equipment_owned.has(id): g.profile.equipment_owned.append(id)
		g.pending_rewards.equipment = id
		_mark_discovered("equipment", id)
		# Great Bosses draw exclusively from the high-stakes boss relic pool (cursedTome,
		# titanBell, chaosPrism) so those stay rare and mean something; regular bosses draw
		# from everything else, same rotation as before.
		var relic_pool: Array = SpiritContent.RELICS
		if kind == "greatboss":
			# E2: flags this specific win as recap-worthy — checked by show_reward_details() to
			# offer the shareable Run Recap card. A great boss can only ever be fought once
			# (a cleared stage can't be re-entered), so every kill reaching here is fresh.
			g.pending_rewards.great_boss_kill = true
			relic_pool = SpiritContent.RELICS.filter(func(r): return SpiritContent.BOSS_RELIC_IDS.has(r.id))
		else:
			relic_pool = SpiritContent.RELICS.filter(func(r): return not SpiritContent.BOSS_RELIC_IDS.has(r.id))
		var relic: Dictionary = relic_pool[(g.current_stage / 5) % relic_pool.size()]
		if not g.profile.relics.has(relic.id):
			g.profile.relics.append(relic.id)
			g.pending_rewards.relic = relic.id
		_mark_discovered("relics", relic.id)
	elif kind == "elite":
		var rune: Dictionary = SpiritContent.RUNES[(g.current_stage / 5 + int(g.profile.difficulty)) % SpiritContent.RUNES.size()]
		g.profile.rune_inventory[rune.id] = g.profile.rune_inventory.get(rune.id, 0) + 1
		g.pending_rewards.rune = rune.id
		_mark_discovered("runes", rune.id)
	SpiritSave.write(g.profile)

func show_reward_details() -> void:
	g._clear(); g._play_music(false)
	var page := g._create_page(8)
	page.add_child(g._label(g.t("ui.battle_won"), 24, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	if g.battle_log and not g.battle_log.entries.is_empty():
		var log_btn := g._button(g.t("ui.battle_log_view_btn"), show_battle_log, Color("17363e"), Vector2(0, 36))
		log_btn.name = "ViewBattleLogBtn"
		page.add_child(log_btn)

	if bool(g.pending_rewards.get("great_boss_kill", false)):
		var recap_btn := g._button(g.t("ui.run_recap_view_btn"), show_run_recap, g.GOLD, Vector2(0, 36))
		recap_btn.name = "ViewRunRecapBtn"
		page.add_child(recap_btn)

	if g.current_stage < 3 or int(g.profile.unlocked) <= 3:
		var stats: Dictionary = g.combat.state.get("stats", {}) if g.combat and g.combat.state else {}
		if not stats.is_empty():
			page.add_child(g._build_victory_recap_card(stats))

	var spoils := HBoxContainer.new()
	spoils.alignment = BoxContainer.ALIGNMENT_CENTER
	spoils.add_theme_constant_override("separation", 14)
	page.add_child(spoils)
	spoils.add_child(g._label(g.tf("ui.reward_gold_line", int(g.pending_rewards.get("gold", 0))), 15, g.GOLD))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	var equip_id := str(g.pending_rewards.get("equipment", ""))
	if not equip_id.is_empty():
		var item := g.content.equipment(equip_id)
		list.add_child(_reward_item(g.tf("ui.boss_equip_title", [item.icon, g._equip_name(item)]), g._equip_detail(item), g.GOLD))
	var relic_id := str(g.pending_rewards.get("relic", ""))
	if not relic_id.is_empty():
		var relic := g.content.relic(relic_id)
		list.add_child(_reward_item(g.tf("ui.relic_reward_title", [relic.icon, g._relic_name(relic)]), g._relic_detail(relic), Color(relic.color)))
	var rune_id := str(g.pending_rewards.get("rune", ""))
	if not rune_id.is_empty():
		var rune := g.content.rune(rune_id)
		list.add_child(_reward_item(g.tf("ui.elite_rune_title", [rune.icon, g._rune_name(rune)]), g._rune_detail(rune), Color(rune.color)))

	if bool(g.pending_rewards.get("daily_trial", false)):
		if bool(g.pending_rewards.get("daily_trial_completed", false)):
			list.add_child(g._label(g.t("ui.daily_trial_complete"), 14, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
		list.add_child(g._label(g.tf("ui.daily_trial_progress_reward_fmt", int(g.pending_rewards.get("daily_trial_stage", 0))), 12, g.JADE, HORIZONTAL_ALIGNMENT_CENTER))
		page.add_child(g._button(g.t("ui.return_map"), _finish_reward, g.EMBER, Vector2(0, 50)))
		return

	if bool(g.pending_rewards.get("weekly_challenge", false)):
		if bool(g.pending_rewards.get("weekly_challenge_completed", false)):
			list.add_child(g._label(g.t("ui.weekly_challenge_complete"), 14, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
		list.add_child(g._label(g.tf("ui.weekly_challenge_progress_reward_fmt", int(g.pending_rewards.get("weekly_challenge_stage", 0))), 12, g.JADE, HORIZONTAL_ALIGNMENT_CENTER))
		page.add_child(g._button(g.t("ui.return_map"), _finish_reward, g.EMBER, Vector2(0, 50)))
		return

	if bool(g.pending_rewards.get("boss_rush", false)):
		list.add_child(g._label(g.tf("ui.boss_rush_progress_reward_fmt", int(g.pending_rewards.get("boss_rush_floor", 0))), 12, g.JADE, HORIZONTAL_ALIGNMENT_CENTER))
		page.add_child(g._button(g.t("ui.return_map"), _finish_reward, g.EMBER, Vector2(0, 50)))
		return

	list.add_child(g._label(g.t("ui.reward_choose"), 13, g.JADE, HORIZONTAL_ALIGNMENT_CENTER))
	var options: Array = g.content.cards.filter(func(card): return card.rarity != "Starter" and card.get("rarity", "") != "Curse")
	for offset in 3:
		list.add_child(_reward_card_row(options[(g.current_stage + offset) % options.size()]))
	if g.auto_battle_active:
		_auto_handle_card_reward()

func _auto_handle_card_reward() -> void:
	await g.get_tree().create_timer(g._battle_delay(0.35)).timeout
	if not g.auto_battle_active: return
	var options: Array = g.content.cards.filter(func(card): return card.rarity != "Starter" and card.get("rarity", "") != "Curse")
	var chosen: Dictionary = {}
	var best_score: float = -99999.0
	for offset in 3:
		var candidate: Dictionary = options[(g.current_stage + offset) % options.size()]
		var sc: float = g._card_build_score(candidate)
		if sc > best_score:
			best_score = sc
			chosen = candidate
	if not chosen.is_empty():
		_smart_add_card(chosen)
	else:
		_finish_reward()

func _reward_card_row(card: Dictionary) -> Control:
	var accent := g._card_color(card)
	var owned: int = int(g.profile.collection.get(card.id, 0))
	var in_deck: int = g.profile.deck.count(card.id)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 126
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", g._panel(Color("11242a"), 12, accent))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 8)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)

	var art_holder := Control.new()
	art_holder.custom_minimum_size = Vector2(76, 106)
	art_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art_holder)
	art_holder.add_child(g._card_art_panel(card.id, Vector2(76, 106)))
	var badge := g._cost_badge(int(card.cost), accent, 24)
	badge.position = Vector2(3, 3)
	art_holder.add_child(badge)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)

	right.add_child(g._label(g.content.text(card.nameKey, g.lang), 14, g.TEXT))
	right.add_child(g._label("%s · %s · %s" % [g.t("kind.%s" % card.get("kind", "Skill")), g.t("element.%s" % card.get("element", "spirit")), card.rarity], 9, g.GOLD))
	var desc := g._label(g._card_description(card), 10, Color("cfe3e0"), HORIZONTAL_ALIGNMENT_LEFT, true)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(desc)
	right.add_child(g._label("%s · %s" % [g.tf("ui.reward_owned", owned), g.tf("ui.reward_in_deck", in_deck)], 9, g.MUTED))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	right.add_child(actions)
	var collect := g._button(g.t("ui.reward_collect"), func(): _collect_card(card), Color("24444b"), Vector2(0, 32))
	collect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(collect)
	var add := g._button(g.t("ui.reward_smart_add"), func(): _smart_add_card(card), Color("2f5c3f"), Vector2(0, 32))
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(add)

	return panel

func _collect_card(card: Dictionary) -> void:
	if int(g.profile.collection.get(card.id, 0)) == 0: g._advance_quest("collect_cards", 1)
	g.profile.collection[card.id] = g.profile.collection.get(card.id, 0) + 1
	_mark_discovered("cards", card.id)
	SpiritSave.write(g.profile)
	g._toast(g.tf("ui.reward_collected", g.content.text(card.nameKey, g.lang)), g.JADE)
	_finish_reward()

# Adds the card to the deck, and when the deck is already at 25 drops the weakest card
# to make room — starters first, then whatever scores lowest.
func _smart_add_card(card: Dictionary) -> void:
	if int(g.profile.collection.get(card.id, 0)) == 0: g._advance_quest("collect_cards", 1)
	g.profile.collection[card.id] = g.profile.collection.get(card.id, 0) + 1
	_mark_discovered("cards", card.id)
	if g.profile.deck.size() < 25:
		g.profile.deck.append(card.id)
		SpiritSave.write(g.profile)
		g._toast(g.tf("ui.reward_added", g.content.text(card.nameKey, g.lang)), g.JADE)
		_finish_reward()
		return

	var worst := -1
	var worst_score := INF
	for i in g.profile.deck.size():
		var existing := g.content.card(g.profile.deck[i])
		if existing.is_empty(): continue
		var score := g._card_build_score(existing)
		if str(existing.get("rarity", "")) == "Starter": score -= 100.0
		# Prefer not to cut a copy of the very card being added.
		if str(existing.id) == str(card.id): score += 60.0
		if score < worst_score:
			worst_score = score
			worst = i
	if worst < 0: worst = 0
	var replaced := g.content.card(g.profile.deck[worst])
	g.profile.deck[worst] = card.id
	SpiritSave.write(g.profile)
	g._toast(g.tf("ui.reward_replaced", [g.content.text(card.nameKey, g.lang), g.content.text(replaced.nameKey, g.lang)]), g.JADE)
	_finish_reward()

func _reward_item(title: String, detail: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(340,54); panel.add_theme_stylebox_override("panel",g._panel(Color("193839"),12,color)); var stack := VBoxContainer.new(); panel.add_child(stack); stack.add_child(g._label(title, 12, color, HORIZONTAL_ALIGNMENT_CENTER)); stack.add_child(g._label(detail, 9, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)); return panel

func _finish_reward() -> void:
	SpiritSave.write(g.profile)
	if g.auto_battle_active:
		var next_idx: int = int(g.profile.unlocked)
		if next_idx >= g.content.encounters.size() - 1 and g.current_stage >= g.content.encounters.size() - 1:
			g.stop_auto_battle()
			g.show_map()
			return
		if not g.can_spend_stamina(5):
			g.stop_auto_battle("stamina")
			g.show_map()
			return
		g.spend_stamina(5)
		g.auto_battle_stats.stages_cleared = int(g.auto_battle_stats.get("stages_cleared", 0)) + 1
		g.auto_battle_stats.gold_earned = int(g.auto_battle_stats.get("gold_earned", 0)) + int(g.pending_rewards.get("gold", 0))
		await g.get_tree().create_timer(g._battle_delay(0.35)).timeout
		var kind := g.content.node_kind(next_idx)
		if kind in ["event","merchant","rest"] and not _is_stage_event_claimed(next_idx) and not _is_replay(next_idx):
			show_event(next_idx, kind)
		else:
			g.begin_battle(next_idx)
		return
	g.show_map()

func show_event(index: int, kind: String) -> void:
	g._clear(); g._play_music(false)
	g._back_action = g.show_map
	var page := g._create_page(12)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: String
	if kind == "event": title = g.t("ui.event_traveler")
	elif kind == "merchant": title = g.t("ui.event_merchant")
	elif kind == "rest": title = g.t("ui.rest_title")
	else: title = g.t("ui.event_default")
	page.add_child(g._label("✦", 48, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(g._label(title, 21, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(g._label(g.t("ui.rest_prompt") if kind == "rest" else g.t("ui.event_prompt"), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	if kind == "event":
		page.add_child(g._button(g.t("ui.event_blood_pact"), func():
			g.profile.gold += 50
			g._advance_quest("earn_gold", 50)
			_mark_stage_event_claimed(index)
			SpiritSave.write(g.profile)
			g._haptic("heavy")
			g.begin_battle(index)
		, Color("591d1d"), Vector2(300, 48)))
		page.add_child(g._button(g.t("ui.event_spirit_blessing"), func():
			g.show_deck_purge(func(): show_event(index, "event"), 0, func():
				_mark_stage_event_claimed(index)
				g.begin_battle(index)
			)
		, Color("21594e"), Vector2(300, 48)))
		page.add_child(g._button(g.t("ui.rest_smith_choice"), func():
			g.show_deck_upgrade(func(): show_event(index, "event"), func():
				_mark_stage_event_claimed(index)
				g.begin_battle(index)
			)
		, g.EMBER, Vector2(300, 48)))
	elif kind == "rest":
		g._maybe_show_tutorial("rest_purify")
		page.add_child(g._button(g.t("ui.rest_heal_choice"), func():
			g.profile.gold += 35
			g._advance_quest("earn_gold", 35)
			_mark_stage_event_claimed(index)
			SpiritSave.write(g.profile)
			g._haptic("tap")
			g.begin_battle(index)
		, Color("21594e"), Vector2(300, 48)))
		page.add_child(g._button(g.t("ui.rest_purify_choice"), func():
			g.show_deck_purge(func(): show_event(index, "rest"), 0, func():
				_mark_stage_event_claimed(index)
				g.begin_battle(index)
			)
		, Color("4a285d"), Vector2(300, 48)))
		page.add_child(g._button(g.t("ui.rest_smith_choice"), func():
			g.show_deck_upgrade(func(): show_event(index, "rest"), func():
				_mark_stage_event_claimed(index)
				g.begin_battle(index)
			)
		, g.GOLD, Vector2(300, 48)))
	else:
		page.add_child(g._button(g.t("ui.event_opt_potion"), func():
			g.profile.gold += 25
			g._advance_quest("earn_gold", 25)
			_mark_stage_event_claimed(index)
			SpiritSave.write(g.profile)
			g._haptic("tap")
			g.begin_battle(index)
		, g.EMBER, Vector2(300, 48)))
		page.add_child(g._button(g.t("ui.shop_purge_service") + " · ◆50", func():
			if g.profile.gold >= 50:
				g.show_deck_purge(func(): show_event(index, "merchant"), 50, func():
					_mark_stage_event_claimed(index)
					g.begin_battle(index)
				)
			else:
				g._toast(g.t("ui.shop_no_gold"))
		, Color("3d2154"), Vector2(300, 48)))
		page.add_child(g._button(g.t("ui.event_opt_direct"), func(): g.begin_battle(index), Color("21594e"), Vector2(300, 48)))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	var ret_btn := g._button(g.t("ui.return_map"), g.show_map, Color("17363e"), Vector2(170, 42))
	btn_row.add_child(ret_btn)
	var auto_label: String = g.t("ui.auto_battle_active") if g.auto_battle_active else g.t("ui.auto_battle")
	var auto_btn := g._button(auto_label, func():
		g.toggle_auto_battle()
		show_event(index, kind)
	, Color("205944") if g.auto_battle_active else Color("1a3a42"), Vector2(90, 42))
	auto_btn.name = "EventAutoBattleToggle"
	btn_row.add_child(auto_btn)
	page.add_child(btn_row)

	if g.auto_battle_active:
		_auto_handle_stage_event(index, kind)

func _auto_handle_stage_event(index: int, kind: String) -> void:
	await g.get_tree().create_timer(g._battle_delay(0.55)).timeout
	if not g.auto_battle_active or _is_stage_event_claimed(index): return
	if kind == "event":
		g.profile.gold += 50
		g._advance_quest("earn_gold", 50)
		_mark_stage_event_claimed(index)
		SpiritSave.write(g.profile)
		g._haptic("heavy")
		g._toast(g.t("ui.event_blood_pact") + " +50", g.GOLD)
		g.begin_battle(index)
	elif kind == "rest":
		g.profile.gold += 35
		g._advance_quest("earn_gold", 35)
		_mark_stage_event_claimed(index)
		SpiritSave.write(g.profile)
		g._haptic("tap")
		g._toast(g.t("ui.rest_heal_choice") + " +35", g.GOLD)
		g.begin_battle(index)
	else:
		g.profile.gold += 25
		g._advance_quest("earn_gold", 25)
		_mark_stage_event_claimed(index)
		SpiritSave.write(g.profile)
		g._haptic("tap")
		g._toast(g.t("ui.event_opt_potion") + " +25", g.GOLD)
		g.begin_battle(index)

# A turn-by-turn readout of everything combat.gd's `event` signal fired during the just-
# finished fight (BattleLog just records kind/payload/turn as they happen — see battle_log.gd —
# so this is purely a rendering pass over that structured history, correct in whichever
# language is active now regardless of what was active during the fight). Reachable from
# show_reward_details()'s "View Battle Log" button, which only appears when there's anything
# to show.
func show_battle_log() -> void:
	g._clear(); g._play_music(false)
	var page := g._create_page(8)
	page.add_child(g._header(g.t("ui.battle_log_title"), "", show_reward_details))

	var scroll := TouchScrollContainer.new()
	scroll.allow_vertical = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "BattleLogList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)

	if not g.battle_log or g.battle_log.entries.is_empty():
		list.add_child(g._label(g.t("ui.battle_log_empty"), 12, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return

	var last_turn := -1
	for entry in g.battle_log.entries:
		var turn: int = int(entry.get("turn", 0))
		if turn != last_turn:
			list.add_child(g._label(g.tf("ui.log_turn_fmt", turn), 11, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
			last_turn = turn
		var line := _format_battle_log_entry(entry)
		if not line.is_empty():
			list.add_child(g._label(line, 10, g.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))

# E2: a composed, screenshot-friendly recap card for a Great Boss kill — pure client-side
# rendering (no share-sheet API, no server), matching how this game already treats a
# well-designed screen as "shareable": the player screenshots it themselves. Reuses
# combat.state.stats exactly like _build_victory_recap_card() does for early stages, since a
# Great Boss kill happens well past the early-game window that function is gated to.
func show_run_recap() -> void:
	g._clear(); g._play_music(false)
	var page := g._create_page(10)
	page.add_child(g._header(g.t("ui.run_recap_title"), "", show_reward_details))

	var card := PanelContainer.new()
	card.name = "RunRecapCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", g._panel(Color("140f08"), 18, g.GOLD))
	page.add_child(card)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: pad.add_theme_constant_override("margin_%s" % side, 18)
	card.add_child(pad)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	pad.add_child(stack)

	var hero: Dictionary = g.content.hero_class(str(g.profile.hero_class))
	var portrait := TextureRect.new()
	portrait.name = "RunRecapPortrait"
	portrait.texture = g._get_character_texture(str(hero.get("sprite", "fox")))
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(portrait)

	stack.add_child(g._label(g.content.hero_name(hero, g.lang), 18, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var encounter: Dictionary = g.content.encounters[g.current_stage]
	var boss_name: String = str(encounter.get("name_en", encounter.name)) if g.lang == "en" else str(encounter.name)
	stack.add_child(g._label(g.tf("ui.run_recap_defeated_fmt", boss_name), 14, g.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	stack.add_child(g._label(g.content.chapter_name(g.current_stage / 5, g.lang), 11, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var stats: Dictionary = g.combat.state.get("stats", {}) if g.combat and g.combat.state else {}
	var stat_row := HBoxContainer.new()
	stat_row.name = "RunRecapStats"
	stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stat_row.add_theme_constant_override("separation", 16)
	stat_row.add_child(g._label(g.tf("ui.recap_damage", int(stats.get("damage_dealt", 0))), 12, Color("ff8a8a")))
	stat_row.add_child(g._label(g.tf("ui.recap_cards", int(stats.get("cards_played", 0))), 12, Color("a8dcff")))
	stat_row.add_child(g._label(g.tf("ui.recap_shield", int(stats.get("shield_gained", 0))), 12, Color("9fd8ff")))
	stack.add_child(stat_row)

	# Deck highlights: pick up to 3 highest rarity / cost cards from player's deck
	var highlight_panel := VBoxContainer.new()
	highlight_panel.name = "RunRecapDeckHighlights"
	highlight_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	highlight_panel.add_theme_constant_override("separation", 6)
	highlight_panel.add_child(g._label(g.t("ui.run_recap_deck_highlights"), 11, g.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var highlight_row := HBoxContainer.new()
	highlight_row.alignment = BoxContainer.ALIGNMENT_CENTER
	highlight_row.add_theme_constant_override("separation", 8)
	highlight_panel.add_child(highlight_row)

	var unique_cards: Array = []
	for cid in g.profile.deck:
		if not unique_cards.has(str(cid)): unique_cards.append(str(cid))
	unique_cards.sort_custom(func(a, b):
		var ca: Dictionary = g.content.card(a)
		var cb: Dictionary = g.content.card(b)
		var r_score := {"Rare": 3, "Uncommon": 2, "Common": 1, "Starter": 0}
		var sa: int = int(r_score.get(str(ca.get("rarity", "Starter")), 0)) * 10 + int(ca.get("cost", 1))
		var sb: int = int(r_score.get(str(cb.get("rarity", "Starter")), 0)) * 10 + int(cb.get("cost", 1))
		return sa > sb
	)
	var shown_cards: Array = unique_cards.slice(0, mini(3, unique_cards.size()))
	for cid in shown_cards:
		var c_data: Dictionary = g.content.card(cid)
		var c_badge := PanelContainer.new()
		var c_col: Color = g._card_color(c_data)
		c_badge.add_theme_stylebox_override("panel", g._panel(Color("16242a"), 8, c_col))
		var c_pad := MarginContainer.new()
		for s in ["left", "right"]: c_pad.add_theme_constant_override("margin_%s" % s, 8)
		for s in ["top", "bottom"]: c_pad.add_theme_constant_override("margin_%s" % s, 4)
		c_badge.add_child(c_pad)
		var c_lbl := g._label(g.content.text(c_data.nameKey, g.lang), 10, c_col)
		c_pad.add_child(c_lbl)
		highlight_row.add_child(c_badge)
	stack.add_child(highlight_panel)

	var share_btn := g._button(g.t("ui.run_recap_share_btn"), func():
		g._toast(g.t("ui.run_recap_saved_toast"), g.GOLD)
	, g.GOLD, Vector2(200, 40))
	share_btn.name = "RunRecapShareBtn"
	share_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(share_btn)

	stack.add_child(g._label(g.t("ui.run_recap_share_hint"), 10, g.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))

	var done_btn := g._button(g.t("ui.run_recap_done"), show_reward_details, g.EMBER, Vector2(200, 46))
	done_btn.name = "RunRecapDoneBtn"
	done_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(done_btn)

# One line of human-readable text per recorded event kind, or "" for kinds not worth a line
# (e.g. "turn" itself, already rendered as the section header above, and "intent" telegraphs,
# already shown live as the actual outcome events — "hit"/"player_hit" — that follow them).
func _format_battle_log_entry(entry: Dictionary) -> String:
	var kind: String = str(entry.get("kind", ""))
	var payload: Dictionary = entry.get("payload", {})
	match kind:
		"card":
			var card: Dictionary = g.content.card(str(payload.get("card", "")))
			var card_name: String = g.content.text(card.nameKey, g.lang) if not card.is_empty() else str(payload.get("card", ""))
			var damage: int = int(payload.get("damage", 0))
			return g.tf("ui.log_card_damage_fmt", [card_name, damage]) if damage > 0 else g.tf("ui.log_card_play_fmt", card_name)
		"hit": return g.tf("ui.log_hit_fmt", int(payload.get("amount", 0)))
		"death": return g.t("ui.log_death")
		"player_hit": return g.tf("ui.log_player_hit_fmt", int(payload.get("amount", 0)))
		"player_burn": return g.tf("ui.log_player_burn_fmt", int(payload.get("amount", 0)))
		"equipment":
			var item: Dictionary = g.content.equipment(str(payload.get("id", "")))
			return g.tf("ui.log_equipment_fmt", g._equip_name(item)) if not item.is_empty() else ""
		"thorns": return g.tf("ui.log_thorns_fmt", int(payload.get("amount", 0)))
		"revive": return g.tf("ui.log_revive_fmt", int(payload.get("amount", 0)))
		"dodge": return g.t("ui.log_dodge")
		"rune_set": return g.t("ui.log_rune_set")
		"boss_phase":
			return "✦ %s" % (str(payload.get("name_en", "")) if g.lang == "en" else str(payload.get("name", "")))
		_: return ""

