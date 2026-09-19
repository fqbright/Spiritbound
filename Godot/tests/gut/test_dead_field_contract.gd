extends GutTest
# Automates AGENTS.md's documented recurring bug class: "a mechanic/field is written somewhere
# but never read anywhere." `thorns` sat in content.gd doing nothing for a whole milestone
# before anyone noticed; `profile.difficulty` was purely cosmetic for the game's entire life
# before one session found it; most recently, a parallel branch's `enemy.strength` field was set
# but never read anywhere in combat.gd. AGENTS.md tells every future agent to "grep for the key
# in combat.gd before trusting that an encounter modifier does what its name implies" — this
# test automates exactly that grep instead of relying on it being remembered by hand.
#
# Deliberately a plain substring search over combat.gd's own source text (mirroring the manual
# grep AGENTS.md already asks for), not a real static analyzer — good enough to catch a key that
# is completely unreferenced, which is the actual shape every real bug in this class has been.

var combat_source: String

func before_all():
	var file := FileAccess.open("res://scripts/combat.gd", FileAccess.READ)
	assert_not_null(file, "res://scripts/combat.gd must exist and be readable for this contract test to mean anything")
	combat_source = file.get_as_text()

# Every encounter mechanic key content.gd's encounter/boss/phantom-cultivator data can carry —
# see AGENTS.md's "Game rules worth knowing" section for the authoritative list. Update this
# list whenever content.gd gains a new one.
const ENCOUNTER_MECHANIC_KEYS := [
	"shield_per_turn", "regeneration", "dodge_every", "enrage", "critical_every", "below_half", "thorns",
]

func test_every_encounter_mechanic_key_has_a_read_site_in_combat_gd():
	for key in ENCOUNTER_MECHANIC_KEYS:
		assert_true(combat_source.contains(key), "encounter mechanic key '%s' appears in content.gd's encounter data but combat.gd never references it — it would silently do nothing (see AGENTS.md's 'thorns' precedent)" % key)

# hero_bonuses is the one channel Hero Mastery, Samsara blessings, and combat consumables all
# funnel through into combat.create() — every "kind" a mastery perk can be must have a matching
# hero_bonuses.get(...) read site in combat.gd, or that perk level grants nothing.
func test_every_hero_mastery_perk_kind_has_a_read_site_in_combat_gd():
	var seen_kinds := {}
	for hero_id in SpiritContent.HERO_MASTERY_PERKS:
		for perk in SpiritContent.HERO_MASTERY_PERKS[hero_id]:
			seen_kinds[str(perk.kind)] = true
	assert_true(seen_kinds.size() > 0, "sanity check: HERO_MASTERY_PERKS should have entries to verify")
	for kind in seen_kinds:
		assert_true(combat_source.contains(kind), "hero mastery perk kind '%s' is defined in content.gd's HERO_MASTERY_PERKS but combat.gd never reads hero_bonuses for that key — every perk level using it would silently grant nothing" % kind)

# The fixed vocabulary of `modifier` keys difficulty tiers and Daily Trial tags are documented
# to produce (AGENTS.md: "each tag maps to exactly one existing combat.gd modifier key"). Does
# NOT include reward_scale, which is real but deliberately consumed by game_rewards_screen.gd's
# payout logic instead of combat.gd's rules engine — asserting it here would be wrong, not thorough.
const MODIFIER_KEYS := ["damage_mult", "health_scale", "extra_enemy", "revive", "damage_bonus"]

func test_every_modifier_key_has_a_read_site_in_combat_gd():
	for key in MODIFIER_KEYS:
		assert_true(combat_source.contains(key), "modifier key '%s' is part of the documented difficulty/Daily-Trial modifier vocabulary but combat.gd never reads it" % key)
