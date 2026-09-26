extends GutTest

# Test suite for Masterpiece Enhancements:
# 1. Apple Store Review & Legal Compliance (Privacy Policy, TOS, Restore Purchases)
# 2. Nine Heavens Tribulation / Ascension Mode (1-20 Tiers Combat Scaling & Backlash)
# 3. Global Daily Seeded Challenge Run (Deterministic Seed, Hero, Weather, Relic)
# 4. Combat Hitstop, Heavy Hit & Lethal Detection
# 5. Offline Cloud Sync Queue (Weak network resilience queue)

var content: SpiritContent

func before_all():
	content = SpiritContent.new()

func test_apple_store_legal_compliance_strings():
	var keys := [
		"ui.privacy_policy_title",
		"ui.privacy_policy_content",
		"ui.terms_of_service_title",
		"ui.terms_of_service_content",
		"ui.restore_purchases",
		"ui.restore_purchases_success",
		"ui.restore_purchases_empty",
		"ui.legal_links"
	]
	for k in keys:
		var zh: String = content.ui(k, "zh-Hans")
		var en: String = content.ui(k, "en")
		assert_true(zh.length() > 0 and zh != k, "Key %s exists in zh-Hans" % k)
		assert_true(en.length() > 0 and en != k, "Key %s exists in en" % k)

func test_ascension_tiers_data_and_strings():
	var tiers := ["ui.ascension_t0", "ui.ascension_t1", "ui.ascension_t5", "ui.ascension_t10", "ui.ascension_t15", "ui.ascension_t20", "ui.ascension_title", "ui.ascension_unlocked", "ui.ascension_highest"]
	for k in tiers:
		var zh: String = content.ui(k, "zh-Hans")
		var en: String = content.ui(k, "en")
		assert_true(zh.length() > 0 and zh != k, "Key %s exists in zh-Hans" % k)
		assert_true(en.length() > 0 and en != k, "Key %s exists in en" % k)

func test_ascension_combat_scaling():
	# Tier 0 base elite encounter
	var enc: Dictionary = content.encounters[1].duplicate(true)
	enc["is_elite"] = true
	var base_hp: int = int(enc.health)
	var base_dmg: int = int(enc.damage)

	var c_t0 := SpiritCombat.new(content)
	c_t0.create(100, enc, ["strike"], 60, {}, [], {}, {"ascension_level": 0}, [], {}, {}, {}, {})
	assert_eq(c_t0.state.enemies[0].shield, 0, "Tier 0 elite has 0 starting shield")

	# Tier 1: +10 elite shield
	var c_t1 := SpiritCombat.new(content)
	c_t1.create(100, enc, ["strike"], 60, {}, [], {}, {"ascension_level": 1}, [], {}, {}, {}, {})
	assert_eq(c_t1.state.enemies[0].shield, 10, "Tier 1 elite has 10 starting shield")

	# Tier 10: +15% enemy attack damage
	var c_t10 := SpiritCombat.new(content)
	c_t10.create(100, enc, ["strike"], 60, {}, [], {}, {"ascension_level": 10}, [], {}, {}, {}, {})
	var expected_t10_dmg: int = int(round(base_dmg * 1.15))
	assert_eq(c_t10.state.enemies[0].damage, expected_t10_dmg, "Tier 10 scales enemy damage by 1.15x")

	# Tier 15: +25% boss HP
	var boss_enc: Dictionary = content.encounters[4].duplicate(true)
	boss_enc["is_boss"] = true
	var boss_base_hp: int = int(boss_enc.health)
	var c_t15 := SpiritCombat.new(content)
	c_t15.create(100, boss_enc, ["strike"], 60, {}, [], {}, {"ascension_level": 15}, [], {}, {}, {}, {})
	var expected_t15_hp: int = int(round(boss_base_hp * 1.25))
	assert_eq(c_t15.state.enemies[0].max_health, expected_t15_hp, "Tier 15 scales boss HP by 1.25x")

	# Tier 20: celestial backlash on end_turn
	var c_t20 := SpiritCombat.new(content)
	c_t20.create(100, enc, ["strike"], 60, {}, [], {}, {"ascension_level": 20}, [], {}, {}, {}, {})
	c_t20.state.player.shield = 0
	var hp_before: int = c_t20.state.player.health
	c_t20.end_turn()
	assert_true(c_t20.state.player.health < hp_before, "Tier 20 applies turn-end celestial backlash")

func test_daily_challenge_info_generation():
	var info1 := SpiritContent.get_daily_challenge_info("2026-09-25")
	var info2 := SpiritContent.get_daily_challenge_info("2026-09-25")
	assert_eq(info1.seed, info2.seed, "Same date produces deterministic seed")
	assert_eq(info1.hero, info2.hero, "Same date produces deterministic hero")
	assert_eq(info1.weather, info2.weather, "Same date produces deterministic weather")
	assert_eq(info1.relic, info2.relic, "Same date produces deterministic relic")

	var info_diff := SpiritContent.get_daily_challenge_info("2026-09-26")
	assert_true(info1.seed != info_diff.seed, "Different dates produce different seeds")

func test_damage_dealt_event_heavy_and_lethal_flags():
	var enc: Dictionary = content.encounters[0].duplicate(true)
	enc.health = 20
	var combat := SpiritCombat.new(content)
	combat.create(1234, enc, ["strike"], 60, {}, [], {}, {}, [], {}, {}, {}, {})

	var received_event := {}
	combat.event.connect(func(kind: String, payload: Dictionary):
		if kind == "damage_dealt":
			received_event.merge(payload)
	)

	# Dealing 25+ damage or reducing to 0 hp should mark lethal/heavy
	combat.state.hand.append({"uid": 888, "card_id": "strike"})
	combat._damage_enemy(0, 25, true)

	assert_true(received_event.has("lethal"), "damage_dealt event has lethal key")
	assert_true(received_event.has("heavy"), "damage_dealt event has heavy key")
	assert_true(bool(received_event.get("lethal", false)), "Enemy reduced to 0 hp is marked lethal")
	assert_true(bool(received_event.get("heavy", false)), "25+ dmg dealt is marked heavy")

func test_offline_sync_queue():
	var prof: Dictionary = SpiritSave.defaults(content)
	assert_true(prof.has("pending_sync_queue"), "Profile has pending_sync_queue initialized")

	SupabaseClient.queue_sync_action(prof, "test_action", {"key": "val"})
	assert_eq(prof.pending_sync_queue.size(), 1, "Action enqueued successfully")
	assert_eq(prof.pending_sync_queue[0].action, "test_action", "Action name preserved")
	assert_eq(prof.pending_sync_queue[0].payload.key, "val", "Payload preserved")
