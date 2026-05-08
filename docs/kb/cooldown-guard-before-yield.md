# Pattern: Cooldown Guard Before Yield — Mass-Event SFX Suppression

**KB category:** Audio / Signal Handling  
**Introduced:** S24.4 — Combat SFX: critical + death  
**Applies to:** Any `AudioStreamPlayer` handler wired to a signal that may fire N times per tick for N simultaneous entities

---

## Problem

GDScript signals fire once per emitting call. When multiple entities (e.g., brotts) die in the same simulation tick or adjacent ticks, a signal like `on_death` fires once per brott. Without a guard, the audio handler plays the same sound N times simultaneously, creating muddy overlap instead of a single impactful audio event.

**Concrete scenario:** A 4-bot match ends with 2 brotts dying within the same tick. `on_death.emit(b)` fires twice in sequence. Without a guard, `death.ogg` plays twice within milliseconds — overlap destroys the intended pathos of the sound.

This pattern is distinct from the **amount-threshold guard** in `combat-sfx-spam-guard.md`, which filters by damage magnitude. The cooldown guard is for *identical events fired in rapid succession* by multiple independent emitters.

---

## Solution: Cooldown-Active Flag + Async Reset

```gdscript
# In game_main.gd (or equivalent game controller)
var _death_sfx_cooldown_active: bool = false  # guard: prevent mass-death frame spam

func _on_brott_death(_brott) -> void:
    # Cooldown guard: on_death fires per-brott; in mass-death scenarios multiple
    # brotts die in the same tick. Guard prevents overlapping playback — only
    # the first death in a 600ms window plays. First death fires; subsequent
    # deaths in the window are suppressed.
    if _death_sfx_cooldown_active:
        return
    if _death_sfx_player != null and is_instance_valid(_death_sfx_player):
        _death_sfx_cooldown_active = true
        _death_sfx_player.play()
        # Reset cooldown after 600ms to allow future matches to play death SFX.
        await get_tree().create_timer(0.6).timeout
        _death_sfx_cooldown_active = false
```

**Key properties:**
1. **Guard fires before null check** — fast early exit for suppressed events (O(1), no allocations).
2. **Flag set before `.play()`** — if `on_death` fires twice synchronously (same frame, same tick), the flag is already `true` when the second call arrives, even before `await` yields.
3. **`await` yields control to the event loop** — the timer reset happens asynchronously; other death events arriving during the 0.6s window hit the `if _death_sfx_cooldown_active: return` check correctly.
4. **Per-match correctness** — the flag resets after 600ms, so a second match starting immediately gets a clean state.

---

## Cooldown Window Sizing

The 600ms window was chosen to cover the worst-case mass-death scenario for a 2v2–4-bot match (up to 4 brotts dying in 2–3 adjacent ticks at ~60fps, ~50ms window), with headroom for `death.ogg`'s 0.42s playback duration.

**Rule of thumb:** `cooldown_ms ≥ asset_duration_ms + (N-1 ticks × tick_duration_ms)`.

For `death.ogg` (420ms) + 3 ticks (50ms):  
→ 420 + 50 = 470ms minimum. 600ms gives comfortable headroom.

**Calibration note (issue #290):** The 600ms constant is a starting point. Post-playtest adjustment may be needed based on match pacing — see `docs/kb/` issue link.

---

## When to Use This Pattern

| Signal characteristic | Use cooldown guard? |
|---|---|
| Fires once per game event (e.g., `on_projectile_spawned` per projectile) | ❌ No — each event is distinct; no suppression needed |
| Fires N times when N entities trigger the same event (e.g., death, level-complete) | ✅ Yes — suppress duplicates in the window |
| Fires continuously during hold (e.g., drag) | ❌ No — use debounce, not cooldown |
| Fires at variable rate (e.g., on_damage with amount < threshold) | ❌ No — use amount threshold guard (see `combat-sfx-spam-guard.md`) |

---

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| `AudioStreamPlayer.playing` check instead of flag | `playing` can be `false` between play calls if the asset is very short (sub-frame). Flag is more reliable for same-tick events. |
| Cooldown flag reset in `_process()` | `_process()` runs every frame; a frame-based reset would clear the flag too quickly. Use `create_timer()` for wall-clock precision. |
| Setting flag AFTER `.play()` | If `on_death` fires twice in the same synchronous call stack, the second call arrives before the coroutine yields. Flag must be set BEFORE `.play()`. |
| Resetting flag in match-start without clearing pending timers | If a match restarts quickly, a pending timer from the previous match can reset the flag mid-match. Reset flag eagerly at match start and let running timers expire harmlessly. |

---

## Composability with Amount-Threshold Guard

Both guards can coexist in the same handler. The cooldown guard acts on *which events* pass through (suppressing duplicates); the amount threshold acts on *which events are significant enough to warrant a sound*. They are orthogonal.

Example with both:
```gdscript
func _on_combat_damage(_target, amount: float, is_crit: bool, _pos: Vector2) -> void:
    if is_crit:
        # Crit branch: always plays, no amount threshold.
        if _critical_hit_sfx_player != null and is_instance_valid(_critical_hit_sfx_player):
            _critical_hit_sfx_player.play()
    elif amount >= HIT_SFX_MIN_AMOUNT:
        # Hit branch: threshold guard prevents boundary-tick spam.
        if _hit_sfx_player != null and is_instance_valid(_hit_sfx_player):
            _hit_sfx_player.play()
    # (death is handled in _on_brott_death with cooldown guard — separate handler)
```

---

## References

- `game_main.gd` — `_on_brott_death()` (S24.4 implementation, canonical reference)
- `docs/kb/combat-sfx-spam-guard.md` — amount-threshold pattern for high-frequency damage events
- Issue [#290](https://github.com/brott-studio/battlebrotts-v2/issues/290) — cooldown duration calibration (post-playtest)
- Arc E brief §2 Pillar 3 — combat SFX tone constraints and multi-death risk register
