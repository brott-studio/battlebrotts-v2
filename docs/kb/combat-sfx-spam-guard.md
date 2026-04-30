# Combat SFX Boundary-Spam Guard Pattern

**Established:** S24.3 (Combat SFX — hit + projectile)
**Applies to:** Signal handlers that may fire at high frequency during combat simulation
**Reference implementation:** `game_main.gd` `_on_combat_damage()` with `HIT_SFX_MIN_AMOUNT`

---

## Problem Statement

`CombatSim.on_damage` fires for every damage event in the simulation — this includes:
- Direct projectile hits (desired: play SFX)
- Boundary overtime damage (undesired: ~1–3 DPS, fires continuously)
- Splash damage sub-hits (sometimes desired, sometimes not)
- Reflect damage ticks (usually undesired at low amounts)

Without a guard, `hit.ogg` plays 10–30 times per second during boundary overtime phases, producing an audio-spam artifact that drowns out other SFX and is perceptually unpleasant.

---

## Approach 1: Amount Threshold (Used in S24.3)

Gate playback on the damage amount exceeding a minimum threshold.

```gdscript
const HIT_SFX_MIN_AMOUNT: float = 5.0  # Suppress sub-threshold damage events

func _on_combat_damage(_target, amount: float, _is_crit: bool, _pos: Vector2) -> void:
    if amount >= HIT_SFX_MIN_AMOUNT and _hit_sfx_player != null and is_instance_valid(_hit_sfx_player):
        _hit_sfx_player.play()
```

**How to choose the threshold:**
- Boundary overtime DPS: typically 1–3 per tick
- Minimum weapon damage: depends on weapon type (minigun pellets ~3–5, plasma ~10+)
- Target threshold: slightly above the max expected spam damage, well below the min real-hit damage
- `5.0` was chosen for S24.3 as the midpoint; may need calibration after playtest (see issue #285)

**Pros:**
- Semantically meaningful: "only play for real hits"
- Preserves `is_crit` for future differentiation (S24.4: crit hits have `is_crit=true`, separate handler)
- Simple, no state

**Cons:**
- Suppresses low-damage real hits (e.g., spread shotgun pellets at 4.0 damage each)
- Threshold is a magic number requiring playtest calibration
- Does not prevent burst spam from a very fast weapon dealing >5.0 per tick

---

## Approach 2: Cooldown Guard (Not used in S24.3 — documented for future use)

Gate playback on a minimum time interval between plays.

```gdscript
const HIT_SFX_COOLDOWN_MS: float = 100.0  # Min ms between hit sounds

var _last_hit_sfx_time_ms: float = 0.0

func _on_combat_damage(_target, amount: float, _is_crit: bool, _pos: Vector2) -> void:
    var now := Time.get_ticks_msec()
    if now - _last_hit_sfx_time_ms >= HIT_SFX_COOLDOWN_MS:
        _last_hit_sfx_time_ms = now
        if _hit_sfx_player != null and is_instance_valid(_hit_sfx_player):
            _hit_sfx_player.play()
```

**Pros:**
- Catches all hit amounts including low-damage pellets
- Produces a predictable, rate-limited audio cadence (~10 sounds/second max at 100ms cooldown)
- No magic-number threshold calibration on damage values

**Cons:**
- Plays for boundary spam if the cooldown is long enough between boundary ticks
- Adds mutable state (`_last_hit_sfx_time_ms`)
- Rate-limiting may feel like SFX "skipping" on rapid combat exchanges

---

## Approach 3: Combo Guard (Threshold + Cooldown — for future consideration)

```gdscript
const HIT_SFX_MIN_AMOUNT: float = 3.0
const HIT_SFX_COOLDOWN_MS: float = 50.0
var _last_hit_sfx_time_ms: float = 0.0

func _on_combat_damage(_target, amount: float, _is_crit: bool, _pos: Vector2) -> void:
    if amount < HIT_SFX_MIN_AMOUNT:
        return
    var now := Time.get_ticks_msec()
    if now - _last_hit_sfx_time_ms < HIT_SFX_COOLDOWN_MS:
        return
    _last_hit_sfx_time_ms = now
    if _hit_sfx_player != null and is_instance_valid(_hit_sfx_player):
        _hit_sfx_player.play()
```

**Pros:**
- Handles both spam sources (low-amount ticks + high-frequency weapons)
- Lower amount threshold (3.0 instead of 5.0) catches more real pellet hits

**Cons:**
- Two parameters to calibrate
- Slightly more state

---

## Decision Guidance

| Combat scenario | Recommended approach |
|---|---|
| Simple combat with clear hit/boundary distinction | Amount threshold (Approach 1) — simpler, less state |
| Spread weapons with low per-pellet damage | Cooldown guard (Approach 2) — catches pellets that fall below amount threshold |
| Complex combat with both issues | Combo guard (Approach 3) |
| Post-playtest if SFX feels too sparse or too busy | Re-tune threshold/cooldown values; see issue #285 |

---

## S24.4 Note

S24.4 adds `crit_hit.ogg` wired to `_on_combat_damage` with `is_crit=true`. The S24.3 handler will need to be extended to differentiate:

```gdscript
func _on_combat_damage(_target, amount: float, is_crit: bool, _pos: Vector2) -> void:
    if amount >= HIT_SFX_MIN_AMOUNT:
        if is_crit:
            # Play crit SFX (S24.4)
        else:
            # Play normal hit SFX (S24.3)
```

The spam guard applies to both paths (amount threshold before the crit branch).

---

*Added in S24.3. See issue #285 for threshold calibration tracking.*
