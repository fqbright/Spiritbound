# GitHub Copilot & Agent Instructions for Spiritbound

Refer to `AGENTS.md` for full project guidelines.

## Mandatory Rules for All Contributions
1. **Always add tests for every feature or bugfix**:
   - Rules, mechanics, economy, cards: `Godot/tests/test_runner.gd`
   - Screens, UI, modals, buttons: `Godot/tests/ui_smoke.gd`
   - Playthrough flows, transitions: `Godot/tests/e2e_playthrough.gd`
2. **Execute tests before completing any task**:
   - Execute `./run_tests.sh` and ensure 0 failures.
   - For UI changes, execute `./run_tests.sh --snapshots` to inspect 390x844 mobile renders.
3. **Keep `combat.gd` UI-free**, and localize all strings in `content.gd` (`zh-Hans` and `en`).
