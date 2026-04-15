# Pattern: Visual Feedback Separation (Juice ≠ Sim)

**Source:** Sprint 4  
**Date:** 2026-04-15

## Principle

All visual feedback (screen shake, hit flash, particles, damage numbers, death sequences) belongs in the **renderer**, not the simulation.

## Why

1. **Determinism** — the combat sim must produce identical results given the same seed, regardless of display. Juice in the sim breaks replays and testing.
2. **Testability** — sim can run headlessly for automated testing without mocking visual systems.
3. **Portability** — different renderers (2D, 3D, text-mode, web) can implement their own juice without touching sim logic.

## Implementation

The sim emits **signals** for events that need visual feedback:
- `on_damage(target, amount, is_crit, hit_pos)`
- `on_death(brott)`
- `on_shield_activated(brott)`
- `on_projectile_spawned(proj)`

The renderer connects to these signals and handles all VFX. The only sim-side accommodation is `flash_timer` on BrottState (used by renderer to know when to flash), which is acceptable as display hint state.

## Anti-Pattern

Don't add screen shake triggers, particle spawn calls, or slow-mo logic inside `combat_sim.gd`. Even "just a flag" can drift into coupling.
