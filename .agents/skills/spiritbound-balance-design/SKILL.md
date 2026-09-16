---
name: spiritbound-balance-design
description: >-
  CRITICAL RULE: You MUST use this game rules and balance design skill whenever
  adding or modifying cards, relics, runes, or status effects, tuning energy curves
  and hand sizes, adjusting encounter mechanics, or updating auto-build scoring.
---

# Spiritbound Mechanics & Balance Design Skill

This skill documents the rules engine invariants, energy curve formulas, and
card/relic design guidelines for Spiritbound.

## Core Rules & Invariants

1. **Opening Conditions**:
   - Opening hand: Strictly **5 cards**.
   - Opening energy: Strictly **2 energy**.
   - Starting deck (`startingDeck` in `core.json`): Strictly 1-cost cards.
2. **Energy Growth Formula**:
   - Turn energy is calculated in `combat.gd:end_turn()`:
     `state.energy = 2 + int((state.turn - 1) / 2)`
     - Turns 1–2: 2 energy
     - Turns 3–4: 3 energy
     - Turns 5–6: 4 energy, etc.
   - Long battles loosen up dynamically. Never revert this to a flat per-turn amount.
3. **Turn Draw & Hand Size Cap**:
   - Hand is NOT refilled to a target amount each turn.
   - `end_turn()` draws a **flat 2 cards** (`_draw(2)`).
   - Maximum hand size: **10 cards**.
   - Relics and runes must NEVER artificially blow up turn 2 hand size.
4. **No Manual End Turn Button**:
   - The turn ends automatically when the player has no affordable cards in hand
     (see `_maybe_end_turn()` in `game.gd`).
5. **Targeting Rule**:
   - Cards with ANY effect having `target: "opponent"` aim at opponents.
   - All other effects aim at the player.
   - Do NOT conflate `_is_attack` (pure damage) with `_targets_opponent` (targeting).
6. **Enemy Intentions**:
   - Enemies roll intentions one turn in advance.
   - `_execute_intent` spends the EXACT telegraphed amount. Never recalculate at execution time.

## Status Effects & Mechanics

- `vulnerable`: +50% damage taken (decays by 1 turn).
- `weak`: -25% damage dealt (decays by 1 turn).
- `poison`: Deals stack count as non-decaying damage every turn; clears only on heal or death.
- `burn`: Ticks damage each turn and decays.
- `strength`: Player-side permanent combat damage boost.
- `focus`: One-shot burst damage bonus (consumed on attack).
- `thorns`: Reflects damage back to the attacker.

## Card Build Scoring (`_card_build_score`)

`_card_build_score` in `game_shop_deck_screen.gd` drives "smart-build" and "smart-add".
- If you introduce a new card effect, operation, or status, you MUST add a corresponding
  evaluation case in `_card_build_score`.
- Any unhandled operation scores as zero, causing the deck builder to undervalue it.
