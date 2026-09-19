extends GutTest
# Smoke test for the GUT (Godot Unit Test) framework integration itself, added alongside
# addons/gut/ — proves the framework is wired up correctly (loads, asserts, and can reach the
# game's own classes) independent of whatever real test coverage tests/gut/test_*.gd files add
# over time. If this ever fails, the problem is the GUT install/wiring, not game logic.

func test_basic_assertions_work():
	assert_eq(1 + 1, 2, "sanity: integer math")
	assert_true(true, "sanity: assert_true")
	assert_false(false, "sanity: assert_false")

func test_can_reach_spirit_content():
	var content := SpiritContent.new()
	assert_not_null(content, "SpiritContent instantiates from a GUT test")
	assert_true(content.encounters.size() > 0, "SpiritContent loads real encounter data (%d encounters)" % content.encounters.size())

func test_can_reach_spirit_combat():
	var content := SpiritContent.new()
	var combat := SpiritCombat.new(content)
	assert_not_null(combat, "SpiritCombat instantiates from a GUT test")
