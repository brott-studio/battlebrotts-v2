# Pattern: Tick Rate as Pacing Lever

**Source:** Sprint 4  
**Date:** 2026-04-15

## Problem

Matches ended in ~3 seconds. Weapon DPS was too high relative to HP pools. Needed 20-40 second matches for BrottBrain decisions to matter.

## Solution

Two-lever approach:
1. **Triple all chassis HP** — direct survivability increase
2. **Halve tick rate** (20→10 ticks/sec) — effectively halves all fire rates, cooldowns, and movement in wall-clock time

Combined effect: ~6× increase in time-to-kill.

## Why Not Just Adjust Damage?

Adjusting individual weapon damage requires rebalancing every weapon independently. The tick rate + HP approach scales uniformly — all weapons, modules, and cooldowns are affected proportionally, preserving relative balance.

## Key Implementation Detail

Use a `TICKS_PER_SEC` constant everywhere. Never hardcode the tick rate. Derived values (energy regen per tick, heal per tick) should be computed from this constant at the const level, not in runtime code.

## Derived Values Checklist

When changing tick rate, verify these all reference `TICKS_PER_SEC`:
- Energy regen per tick
- Weapon cooldowns (ticks between shots)
- Module durations (active time in ticks)
- Module cooldowns (in ticks)
- Heal per tick (passive healing)
- Match timeout (in ticks)
- Pathfinding recalc interval
- Any "window" timers (e.g., biggest threat targeting)
