# Arc O — Sub-sprint O.3: Swarm Death Freeze Fix
**Author:** Gizmo  
**Date:** 2026-05-08  
**Branch:** arc-o-gizmo-o3  
**Status:** Ready for implementation (Nutts)

---

## Arc-Intent Verdict

**Arc intent: satisfied.**

Arc O goal: "Make the player feel in control — clicks go where intended, battle is readable at a glance, and the game doesn't freeze under stress."

- O.1 ✅ Click-to-move override reliability (tick-countdown suppression window)
- O.2 ✅ Brawler speed correction
- O.3 (this spec): swarm death freeze — the last "under stress" blocker

With O.3 merged, all three Arc O pillars are addressed. No remaining gap in the arc brief.

---

## GDD Drift Check

**No drift detected.**

Bug #361 is a rendering stability bug — no game mechanics, balance numbers, or player-facing design surfaces are changing. The fix is pure renderer internals (`arena_renderer.gd`). GDD §7 (visual feedback) describes the death explosion sequence as "hit-stop, screen flash, shake, debris, particle burst" — this spec preserves that behavior exactly, it just makes it survivable under multi-death conditions.

No GDD update required.

---

## Problem Statement

**Player fantasy:** "The game doesn't stutter, even in the chaos of a swarm fight."

**Bug #361:** Full game freeze when 3+ enemies die in rapid succession.

---

## Code Analysis — What the Code Actually Does

### `_init_particle_pool()`
Pre-allocates 200 Dictionary slots at setup time. Each slot has an `"active"` flag. `active_particle_count` tracks live slots. This is good — no GC pressure on spawn.

### `_claim_particle()`
**Linear O(N) scan** across all 200 slots searching for `active == false`. Returns the slot dict or `null` if pool exhausted. No guard on existing active count before returning.

### `_on_death()` — the actual call path
Runs **synchronously** on the `on_death` signal. Per death:
1. Sets `death_freeze_timer = 6.0` (resets, doesn't stack)
2. Sets `death_slow_mo_timer = 18.0`
3. Triggers shake, zoom, flash
4. Spawns 4–6 **debris** (append to `death_debris` array — NOT pooled, unbounded)
5. Claims **20–30 pooled particles** via a tight `for` loop

### `tick_visuals()` — freeze interaction
When `death_freeze_timer > 0`, `tick_visuals()` returns **early** after decrementing the timer. This means:
- Particle `lifetime` is NOT decremented during freeze
- Active particles accumulate without expiring
- `death_freeze_timer` is reset to 6.0 by every new death, chaining the freeze window

### The actual spike mechanism (3 deaths in 2–3 frames)

| Frame | Event |
|---|---|
| F1 | Death A: 20–30 `_claim_particle()` calls, each O(200) scan. `death_freeze_timer = 6.0`. |
| F1 tick | `tick_visuals()` returns early — zero particle cleanup. |
| F2 | Death B: another 20–30 claims × O(200). `death_freeze_timer` RESET to 6.0 (extends freeze). |
| F2 tick | Early return again. All particles from both deaths still live. |
| F3 | Death C: same. Up to 90 claims × O(200) = 18,000 dict iterations this burst. |
| F3 draw | `_draw()` loops all 200 pool slots + up to 18 debris + damage texts. `draw_circle()` × ~90. |

The stall is a compound of:
1. **O(N) linear scan overhead** in `_claim_particle()` called 60–90 times synchronously
2. **Extended hit-stop freeze** — each death resets the 6-frame window, preventing any particle cleanup from running
3. **Debris array is unbounded** — `death_debris.append()` N times with no cap (separate from pool)
4. **No burst guard** — `_on_death()` never checks `active_particle_count` before spawning

### Does current code have any per-death particle cap?
**No.** `_on_death()` always spawns 20–30 particles unconditionally.

### Any deferred cleanup?
**No.** `_on_death()` is fully synchronous.

---

## Fix Recommendation: Both 2A and 2B

Both are required. They address distinct root causes that compound each other.

### 2A — Global active-particle burst cap (not just pool exhaustion)

**Problem:** `_claim_particle()` returns null only when all 200 slots are active. With 3 deaths × 30 particles = 90, the pool isn't exhausted (null never fires), so the existing guard doesn't help. The scan overhead and draw overhead grow proportionally with `active_particle_count`.

**Fix:** Add a pre-check in `_on_death()` before the burst loop:

```gdscript
# O.3: cap total active particles before a death burst
const DEATH_BURST_MAX := 120  # leave 80 slots for ambient sparks
if active_particle_count >= DEATH_BURST_MAX:
    # drain oldest N particles to make room
    var freed := 0
    for p in particle_pool:
        if freed >= 20:
            break
        if p["active"]:
            p["active"] = false
            active_particle_count -= 1
            freed += 1
```

**Why 120:** Leaves 80 slots for in-combat spark VFX (minigun, railgun hits) that may still be live when a death fires. 3 deaths × 30 = 90 < 120, so one burst fits; a second burst triggers drain, keeping draw cost bounded.

**Why drain oldest (linear pass) rather than skip:** Skipping leaves visual gaps — the explosion looks cheap if particles just don't spawn. Draining the oldest (which are nearly expired anyway) is imperceptible at normal play speed and keeps the burst looking full.

### 2B — Defer particle spawning out of `_on_death()` signal call

**Problem:** `_on_death()` fires synchronously on the `on_death` signal, blocking the render thread. With 3 deaths in 2–3 frames, 60–90 `_claim_particle()` calls happen inside signal dispatch before `tick_visuals()` can run. The freeze timer compound also means particles never age during the spike window.

**Fix:** Extract the particle burst into a deferred helper. Keep timers (freeze, flash, shake) synchronous — they must fire immediately for the feel to be correct. Only defer the allocation-heavy particle/debris loops:

```gdscript
func _on_death(brott: BrottState) -> void:
    # Timers and shake fire immediately (feel-critical)
    death_freeze_timer = 6.0
    death_flash_timer = 2.0
    _trigger_shake(randf_range(10.0, 12.0), 12, "ease_out")
    death_zoom_target = brott.position + arena_offset
    death_zoom_timer = 30.0
    death_slow_mo_timer = 18.0
    brott.death_timer = 30.0

    # Particle/debris burst deferred to end-of-frame — prevents multi-death pileup
    call_deferred("_spawn_death_burst", brott.position.duplicate())

func _spawn_death_burst(pos: Vector2) -> void:
    # O.3 cap check (2A) runs here, not in _on_death
    if active_particle_count >= DEATH_BURST_MAX:
        _drain_oldest_particles(20)

    # Debris (4–6)
    for _i in range(randi_range(4, 6)):
        var angle := randf() * TAU
        var speed := randf_range(100.0, 150.0)
        death_debris.append({
            "pos": pos + arena_offset,
            "vel": Vector2(cos(angle), sin(angle)) * speed,
            "rotation": randf() * TAU,
            "rot_speed": randf_range(-5.0, 5.0),
            "lifetime": 48.0,
            "max_lifetime": 48.0,
            "size": 4.0,
            "color": [Color.ORANGE, Color.GRAY, Color.WHITE][randi() % 3],
        })

    # Particle burst (20–30)
    for _i in range(randi_range(20, 30)):
        var p: Dictionary = _claim_particle()
        if p == null:
            continue
        var angle := randf() * TAU
        var speed := randf_range(80.0, 150.0)
        var col: Color = [Color.ORANGE, Color.GRAY, Color.WHITE][randi() % 3]
        p["pos"] = pos + arena_offset
        p["vel"] = Vector2(cos(angle), sin(angle)) * speed
        p["lifetime"] = randf_range(300.0, 600.0) / (1000.0 / 60.0)
        p["max_lifetime"] = randf_range(300.0, 600.0) / (1000.0 / 60.0)
        p["color"] = col
        p["size"] = randf_range(2.0, 4.0)
```

**Why `call_deferred` works here:** Godot defers the call to after the current physics/process step completes. Multiple deaths in the same frame queue multiple `_spawn_death_burst` calls, which execute sequentially in the same deferred batch — but each runs AFTER the frame's `tick_visuals()` has had a chance to age and retire existing particles. The freeze timer remains synchronous, so the hit-stop feel is unaffected.

### Optional cleanup: `_claim_particle()` O(1) optimization

The linear scan in `_claim_particle()` is a secondary contributor. A free-list (`particle_free_indices: Array[int]`) would make this O(1). **This is NOT required for O.3** — with 2A + 2B, the scan runs ≤30 times per burst at most and the pool is well-under-exhaustion at the cap check point. Nutts may implement this as a tidy-up if time allows, but it should not block O.3 merge.

---

## Implementation Summary

**File:** `godot/arena/arena_renderer.gd`

| Change | Where | What |
|---|---|---|
| Add constant | top of class | `const DEATH_BURST_MAX := 120` |
| Add helper | new func | `_drain_oldest_particles(count: int)` — linear pass, deactivate oldest N active slots |
| Refactor `_on_death()` | existing func | Keep timers synchronous; replace particle/debris loops with `call_deferred("_spawn_death_burst", brott.position.duplicate())` |
| Add `_spawn_death_burst()` | new func | Run 2A cap check + drain, then debris append + particle claim loops (moved from `_on_death`) |

**No changes to:** combat simulation, game state, GDD, any other files.

---

## Acceptance Criteria

Optic should verify:

1. **Baseline pass:** Single enemy death — explosion VFX (hit-stop, flash, shake, debris, sparks) plays identically to pre-fix. No visual regression.
2. **3-enemy burst:** Simulate 3 simultaneous enemy deaths (trigger via test harness or force-kill in headless). Frame time during the death burst does not exceed 2× the rolling average frame time (i.e., no >32ms spike at 60fps target). `active_particle_count` after the burst is ≤ 120.
3. **5-enemy burst:** 5 deaths in 3 frames. Game does not freeze (tick_visuals continues advancing `death_freeze_timer` normally). `active_particle_count` bounded.
4. **Debris unbounded guard:** Verify `death_debris` does not grow beyond 30 entries during a 5-enemy burst. (The drain applies to pooled particles; debris uses a separate array. Nutts should add a `death_debris.size() < 30` guard inside the deferred burst as well.)
5. **Hit-stop timing unchanged:** `death_freeze_timer` still fires at 6.0 frames (~100ms) per death — confirm via test that a death resets the timer to 6.0.

---

## Why Not 2B Alone

Deferral alone without a cap still allows `active_particle_count` to grow unchecked across many deferred bursts. If 10 enemies die across 10 frames, deferred bursts fire across 10 frames too — each spawning 30 particles. Cap (2A) is the budget floor; deferral (2B) is the scheduling fix. Both are needed.

---

## Why Not 2A Alone

The cap prevents over-claiming but `_on_death()` still runs synchronously. Three deaths in one frame still trigger three synchronous O(200) scan × 30 calls = 18,000 iterations inside signal dispatch. With deferral (2B), each burst runs in its own deferred slot — the scans are spread across frames, eliminating the per-frame CPU spike even when burst count is below the cap.
