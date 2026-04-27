# Blank Screen on Godot HTML5 with Active Game State

**Source:** Arc F.5 (S26.1 P0) — 2026-04-27
**Audit:** `studio-audits/audits/battlebrotts-v2/v2-sprint-26.1.md`

## Symptoms

- Page loads cleanly.
- No console errors.
- Arena/game viewport renders briefly then appears blank.
- Run-end / match-end screen may flash by faster than human perception, or
  game state silently advances past the expected interactive moment.

## Most likely cause (Arc F.5 instance)

The player has **no offensive capability** at battle start (e.g. empty
`equipped_weapons` array). Enemies destroy the un-firing player before any
visible game-state change accumulates → arena renders momentarily, then
`match_end` fires with `winner != player`, and the run-end screen
overdraws or the canvas is cleared before the user sees anything.

This is **not** a render bug. It's a game-logic bug presenting as a render
symptom.

## Diagnostic

1. Check the player's offensive-capability array (`RunState.equipped_weapons`
   or analogous) at battle-start. Empty? You've found it.
2. Hook the URL-param fast path: `?screen=run_battle&chassis=N` (added in
   S26.3). Watch the console for `[S26.3] run_battle URL hook — chassis=N`
   followed shortly by `[S25.7] match_end`. If `match_end` fires within
   ~2s of the run_battle hook, the player almost certainly has no weapons.
3. Run the regression test: `godot/tests/test_s26_1_starter_weapon.gd`.
4. Run the Playwright smoke: `tests/gameplay-smoke.spec.js` — it asserts
   `MIN_BATTLE_MS = 2000` between run_battle entry and any `match_end`.

## Fix

Apply the [default-starter-state pattern](../patterns/default-starter-state.md):
seed the offensive-capability array with a non-empty default at state-creation.

## Why "blank screen" specifically

The HTML5 canvas in Godot does not always issue a redraw on rapid
state-transitions. When `_start_roguelike_match` → battle → `match_end`
→ `_show_run_end` happens in <2s, the arena render call may race against
the run-end overlay's draw call, leaving the canvas mid-state. To the user
this looks like a blank screen with no error.

## Defense in depth

- **Prevent:** seed-default starter state.
- **Detect (CI):** Playwright `gameplay-smoke.spec.js` asserts
  `MIN_BATTLE_MS = 2000` and fails on regression.
- **Survive:** `_show_run_error(msg)` in `game_main.gd` + a defensive guard
  around `_start_roguelike_match`. If a `null`/empty run_state slips through
  again, the user sees an error screen instead of a blank canvas.
