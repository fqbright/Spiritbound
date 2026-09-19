extends GutTest
# test_seed_override / _battle_seed() (game.gd) centralize a formula that used to be duplicated
# across 7 begin_*_battle() call sites (begin_battle, begin_boss_rush_battle,
# begin_curse_run_battle, begin_sandbox_battle, begin_abyss_battle, begin_world_event_battle,
# begin_phantom_arena), each independently seeding SpiritCombat from
# Time.get_unix_time_from_system(). That non-determinism produced two separately-diagnosed
# flakiness bugs in one session (ui_smoke.gd's finishing-blow banner check, and
# visual_snapshots.gd's battle-screen capture) before either was traced back to it — see
# AGENTS.md's Traps section. This test covers the shared helper itself, not each of the 7 call
# sites individually (those are exercised by ui_smoke.gd/e2e_playthrough.gd already).

func test_battle_seed_defaults_to_wall_clock_when_override_disabled():
	var game := SpiritGame.new()
	assert_eq(game.test_seed_override, -1, "test_seed_override defaults to -1 (disabled) so real gameplay is unaffected")
	var seed: int = game._battle_seed()
	assert_true(seed >= 0 and seed <= 0x7fffffff, "wall-clock-derived seed stays within combat.gd's expected positive-int range (got %d)" % seed)

func test_battle_seed_returns_the_override_verbatim_when_set():
	var game := SpiritGame.new()
	game.test_seed_override = 12345
	assert_eq(game._battle_seed(), 12345, "a set override is returned exactly, bypassing the wall clock entirely")

func test_battle_seed_is_reproducible_across_calls_once_overridden():
	var game := SpiritGame.new()
	game.test_seed_override = 999
	var first: int = game._battle_seed()
	var second: int = game._battle_seed()
	assert_eq(first, second, "repeated calls with the same override must return the identical seed — this is the whole point")

func test_battle_seed_zero_is_a_valid_override_not_treated_as_disabled():
	var game := SpiritGame.new()
	game.test_seed_override = 0
	assert_eq(game._battle_seed(), 0, "0 is a legitimate seed value; only -1 means disabled, so this must not fall through to the wall clock")
