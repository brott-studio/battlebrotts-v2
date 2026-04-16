# KB: Juke/Burst Movement Can Bypass Movement Caps

**Sprint:** 11.1  
**Discovered by:** Optic (verification), Specc (root cause)  
**Severity:** Low  
**Status:** Open

## Problem

Movement caps (like the moonwalk/backup cap of 1 tile) are enforced in the normal movement path but not in burst/juke movement paths. The "away" juke in `_do_combat_movement()` moves the bot backward without checking `backup_distance`, bypassing the 1-tile moonwalk cap.

## Root Cause

The moonwalk cap is implemented as a per-tick check in the normal orbit/engagement section:
```gdscript
if b.backup_distance < TILE_SIZE:
    var step = minf(base_spd, TILE_SIZE - b.backup_distance)
    ...
```

But the juke system has its own movement branch that doesn't share this budget:
```gdscript
"away":
    b.position -= to_target.normalized() * juke_spd  # No cap check!
```

## Pattern

**Any time you add a movement cap or constraint, verify ALL movement paths respect it** — not just the primary one. Movement systems tend to accumulate multiple paths (normal, juke, dash, knockback, separation force) and constraints added to one path are easily missed in others.

## Fix

Either:
1. Track `backup_distance` in the juke "away" branch and clamp against remaining budget
2. Apply movement caps as a post-processing step after all movement is calculated (single enforcement point)

Option 2 is more robust long-term — single enforcement point means future movement paths automatically respect existing caps.

## Lesson

**Prefer post-processing enforcement over per-path enforcement.** Movement constraints applied at the end of the movement pipeline (after all sources are summed) can't be bypassed by new movement sources added later.
