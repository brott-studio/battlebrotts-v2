# Arc O — Sub-sprint O.1: Click-to-Move Override
**Author:** Gizmo  
**Date:** 2026-05-08  
**Branch:** arc-o-gizmo-specs  
**Status:** Ready for implementation (Nutts)

---

## Arc-Intent Verdict

**Arc intent: progressing — O.1 not yet implemented (O.2, O.3 pending).**

Arc O goal: "Make the player feel in control — clicks go where intended, battle is readable at a glance, and the game doesn't freeze under stress."

Current state: `_override_ticks_remaining` does not exist in `brottbrain.gd`. The click-to-move override is in the code path (S25.2 guard fires correctly), but is vulnerable to premature clearing by `clear_move_override()` before the player's intended destination is reached. O.1's tick-countdown fix is unimplemented. O.2 (Brawler speed) and O.3 (swarm freeze) are also not yet done.

---

## GDD Drift Check

**No drift detected.**

GDD §13.7 describes click-to-move as: "The player's bot moves toward the waypoint until it arrives, or until the player issues a new command." The current code is consistent with that description. The `_override_ticks_remaining` mechanism is a backend implementation detail (not player-visible behavior change); §13.7 does not require updating for O.1. No GDD update needed.

---

## Problem Statement

**Player fantasy:** "I click where I want my Brott to go, and it goes there — for real."

**Current bug:** Click-to-move is fragile. When `clear_move_override()` is called (e.g., by `_move_brott` in `combat_sim` on arrival at `ARRIVE_RADIUS = 24px`), the override clears in the same tick or earlier than the player expects. The movement suppression window is purely position-driven — no time-based floor exists. A click near the Brott's current position, or a race between arrival detection and the evaluate guard, can cause the override to clear immediately, leaving the AI free to resume autonomous movement before the player's intended beat.

**Root cause:** `evaluate()` resets `movement_override = ""` every tick (line 1 of evaluate body), then the S25.2 guard (`if _override_move_pos != Vector2.INF`) re-asserts it if the position is still set. If `clear_move_override()` runs between ticks or on the same tick as arrival, `_override_move_pos` is already `Vector2.INF` when the guard fires — the AI overrides the player's intent.

---

## Design Fix

**Mechanic:** On player click-to-move, suppress AI movement for exactly 25 ticks (~2.5 seconds at 10 ticks/sec). The override stays active for the full suppression window even if the bot arrives at the waypoint early — giving the player a clear, consistent control window.

**Why 25 ticks:** ~2.5s feels responsive without being punishing. Matches the player perception window for a deliberate positional command. Long enough that even a Fortress (60px/s) can meaningfully reposition before the AI reasserts.

**Latest-wins:** Any new click resets the countdown to 25. No stacking.

**Weapon firing:** Unaffected. Override only suppresses movement_override; weapon logic is handled separately in combat_sim.

---

## Implementation Spec

### File: `godot/brain/brottbrain.gd`

**1. Add member variable** (place alongside `_override_move_pos`):

```gdscript
var _override_ticks_remaining: int = 0  ## O.1: ticks left on click-to-move suppression
```

**2. Update `set_move_override(pos)`** — set the countdown on every new click:

```gdscript
func set_move_override(pos: Vector2) -> void:
    _override_move_pos = pos
    _override_ticks_remaining = 25  ## O.1: start/reset suppression window
    _override_target_id = -1  # latest-wins: clear target override
```

**3. Update `clear_move_override()`** — also reset the countdown:

```gdscript
func clear_move_override() -> void:
    _override_move_pos = Vector2.INF
    _override_move_initial_dist = -1.0  ## N.3 GAP-5: reset on clear
    _override_ticks_remaining = 0  ## O.1: suppress window consumed
```

**4. Update `evaluate()` override guard** — replace the existing S25.2 guard:

```gdscript
## REMOVE (existing S25.2 guard):
# if _override_move_pos != Vector2.INF:
#     movement_override = "move_to_override"
#     return true

## REPLACE WITH (O.1 tick-based guard, placed before `movement_override = ""`):
if _override_ticks_remaining > 0:
    _override_ticks_remaining -= 1
    if _override_move_pos != Vector2.INF:
        movement_override = "move_to_override"
    else:
        ## Waypoint already arrived but suppression window still active — hold AI off
        movement_override = ""
    return true
```

Full placement context in `evaluate()`:

```gdscript
func evaluate(brott: RefCounted, enemy: RefCounted, match_time_sec: float) -> bool:
    ## S25.9: Boss-specific AI
    if is_boss:
        return _evaluate_boss(brott, enemy)

    ## O.1: Tick-based click-to-move suppression (replaces S25.2 position-only guard)
    if _override_ticks_remaining > 0:
        _override_ticks_remaining -= 1
        if _override_move_pos != Vector2.INF:
            movement_override = "move_to_override"
        else:
            movement_override = ""
        return true

    movement_override = ""  # Reset each tick (AI resumes when suppression expires)

    ## Arc N.2: FBI path
    if use_first_battle_ai:
        return _evaluate_first_battle(brott, enemy)

    ## S25.2: Target override (still position-only, no tick countdown needed)
    if _override_target_id != -1:
        movement_override = "target_override"
        return true

    ## ... rest of evaluate unchanged ...
```

---

## Acceptance Criteria (for Optic)

1. **Suppression window active:** After `set_move_override()` call, `movement_override == "move_to_override"` is returned from `evaluate()` for 25 consecutive ticks even if no other state changes.
2. **Countdown decrements:** `_override_ticks_remaining` decreases by 1 per `evaluate()` call during the window; reaches 0 after 25 calls.
3. **AI resumes at tick 26:** On tick 26 post-click, `evaluate()` falls through to baseline AI logic (movement_override driven by stance, not waypoint).
4. **Latest-wins:** Calling `set_move_override()` mid-countdown resets `_override_ticks_remaining` to 25 (verified by calling twice at tick 10, then checking 25 more ticks of suppression follow).
5. **Weapon firing unaffected:** `weapon_mode` and `_pending_gadget` behavior is unchanged during the override window.
6. **Target override unaffected:** `set_target_override()` path bypasses the new tick guard correctly (target override guard fires after the window expires).
7. **clear_move_override() resets countdown:** After `clear_move_override()`, `_override_ticks_remaining == 0` and next evaluate() tick falls to AI logic.

---

## No GDD Update Required

O.1 is a backend fix to an existing, documented mechanic (§13.7 click-to-move). No player-visible behavior changes; no new mechanics; no stat changes. GDD §13.7 remains accurate as written.

---

## Notes for Ett

- This is a pure `brottbrain.gd` change — no combat_sim changes expected.
- Nutts should also update the `brottbrain_test.gd` (or equivalent) with tick-countdown unit tests covering the acceptance criteria above.
- No sim-gate required per arc brief. Optic unit test pass is sufficient to close O.1.
- O.2 and O.3 are independent and can be planned in the same sprint.
