---
name: godot-game-dev
description: >-
  CRITICAL RULE: You MUST use this specialist skill whenever modifying GDScript code,
  adding or debugging UI nodes, handling cross-screen delegators, or verifying
  changes with test_runner.gd and ui_smoke.gd in the Spiritbound project.
---

# Godot 4.7.2 & Spiritbound Architecture Skill

This skill provides procedures, best practices, and guardrails for developing in
Spiritbound, a portrait mobile card-battler built in Godot 4.7.2.

## Verification Workflow

Always verify every change before finishing. Spiritbound runs completely headlessly.
The iOS Simulator CANNOT run this project (official Godot 4.7.2 templates only link x86_64).

Run the automated verification helper:
```bash
.agents/skills/godot-game-dev/scripts/verify.sh
```
Or run individually:
```bash
godot --headless --path Godot/ --script res://tests/test_runner.gd   # rules
godot --headless --path Godot/ --script res://tests/ui_smoke.gd      # screens + combat turn
```
Both MUST pass. If either fails, fix the regression before proceeding.

## Core Architectural Boundaries

1. **`combat.gd` never references a Node, Scene, or Control.**
   Keep the rules engine pure and headless. All card effects, intents, statuses, and
   relics resolve here without any UI dependency.
2. **Screen Split is Composition, not Inheritance.**
   Screens are composed into `game.gd`: `MapScreen`, `BattleScreen`, `RewardsScreen`,
   `ShopDeckScreen`, `CampScreen`. Each has a `var g: SpiritGame` back-reference.
   - Any cross-screen or shared helper call requires `g.` (e.g. `g._toast(...)`, `g._modal_dialog(...)`).
   - `self` refers to the screen composition object, not the game instance.
   - If a screen function is called externally, add a thin delegator in `game.gd`.
   - If a delegator wraps an `await` function, the delegator MUST also `await` it.
3. **Strict Typing in GDScript.**
   GDScript warnings are treated as errors. Annotate all variables and returns explicitly:
   `var x: String = dict.get("key", "")` instead of `var x := dict.get("key")`.

## Common UI Traps & Rules

- **Containers resize their children**: A `ColorRect` or child inside `PanelContainer`
  is stretched to fill it. Use `ProgressBar` for bars, and parent custom-sized elements
  to a plain `Control` or `Panel`.
- **Decorative children swallow input**: `PanelContainer` and `Panel` default to
  `MOUSE_FILTER_STOP`. Always set `MOUSE_FILTER_IGNORE` on decorative backgrounds and icons.
- **Z-Index beats tree order**:
  - Map pins: `z_index = 10`
  - Traveller: `z_index = 25`
  - Floating bars / HUD: `z_index = 100`
  - Modal Dialogs (`_modal_dialog`): `z_index = 600`
  - Toasts: `z_index = 500`
- **Modal Dialog Pattern**: Never wrap a dialog in a full-screen `Button` backdrop
  that dismisses on press, as touch events can swallow child button taps.
  Use `_modal_dialog(name, on_dismiss)` which places a backdrop `Button` as a sibling
  behind a centered `PanelContainer` (`MOUSE_FILTER_STOP`).
- **Anchors vs Sizes**: Calling `set_anchors_and_offsets_preset` before adding children
  bakes in zero size. Use anchors (`PRESET_FULL_RECT`) for overlays and manual offsets
  for floating headers.

## Localizing Strings

All user-facing strings MUST be defined in `Godot/scripts/content.gd` under `UI_TEXT`
with both `zh-Hans` and `en` keys. Never hardcode user strings in `game.gd` or screen files.
