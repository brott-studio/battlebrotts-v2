# Pattern: Mutually-Exclusive SFX Branch — Crit vs. Normal Hit Routing

**KB category:** Audio / Signal Handling  
**Introduced:** S24.4 — Combat SFX: critical + death  
**Applies to:** Single-signal handlers that must route to different sounds based on event qualifier flags

---

## Problem

The `CombatSim.on_damage` signal fires for every damage event and carries an `is_crit: bool` parameter. S24.3 wired the handler for normal hit sounds only (ignoring `_is_crit`). S24.4 needs to:

1. Play a heavier `critical_hit.ogg` for crit events.
2. Continue playing `hit.ogg` for non-crit events (amount ≥ threshold).
3. **Never play both sounds for a single damage event.**

The third requirement is the non-obvious constraint: if the handler plays both unconditionally, every crit event plays two sounds simultaneously, creating an unintended layered thud rather than a distinct crit sound.

---

## Solution: `if/elif` Branch with Mutually-Exclusive Arms

```gdscript
# game_main.gd — S24.4 extension of S24.3 on_damage handler
func _on_combat_damage(_target, amount: float, is_crit: bool, _pos: Vector2) -> void:
    # [S24.4] Crit branch: critical hits always play critical_hit SFX;
    # normal hits guarded by threshold. Branches are mutually exclusive —
    # one damage event plays at most one sound.
    if is_crit:
        if _critical_hit_sfx_player != null and is_instance_valid(_critical_hit_sfx_player):
            _critical_hit_sfx_player.play()
    elif amount >= HIT_SFX_MIN_AMOUNT:
        if _hit_sfx_player != null and is_instance_valid(_hit_sfx_player):
            _hit_sfx_player.play()
```

**Branch semantics:**
| `is_crit` | `amount` | Sound played |
|---|---|---|
| `true` | any | `critical_hit.ogg` — always (crits are always significant) |
| `false` | ≥ 5.0 | `hit.ogg` — threshold guard still applies |
| `false` | < 5.0 | silence — boundary-tick suppression |

---

## Why Crits Skip the Amount Threshold

The `HIT_SFX_MIN_AMOUNT = 5.0` threshold exists to suppress boundary-tick, splash, and reflect damage events — all of which are `is_crit=false` by definition (critical hits require a direct hit on a target, not environmental damage). Therefore:

- **Crit arm (`if is_crit`):** No amount guard. A crit always fires the crit sound regardless of damage value. This is correct because: (1) the game can produce low-damage crits from status effects or weakened weapon state, and (2) a crit that makes no sound would be a gameplay clarity failure.
- **Hit arm (`elif amount >= HIT_SFX_MIN_AMOUNT`):** Threshold guard retained. Non-crit boundary-tick events (amount < 5.0) remain suppressed.

---

## Signal Parameter Naming Convention

GDScript uses leading underscores to indicate intentionally-unused parameters (suppresses compiler warnings for `-W unused_parameter`):

```gdscript
# Before S24.4 (is_crit unused — leading underscore):
func _on_combat_damage(_target, amount: float, _is_crit: bool, _pos: Vector2) -> void:

# After S24.4 (is_crit now used — underscore removed):
func _on_combat_damage(_target, amount: float, is_crit: bool, _pos: Vector2) -> void:
```

The rename `_is_crit` → `is_crit` in S24.4 is purely a naming fix, not a signature change. The signal emitter (`combat_sim.gd`) and all other connection sites are unaffected.

**Rule:** Remove the leading underscore from a parameter name when it becomes used. Keep `_` prefix on parameters that remain unused in that handler's scope.

---

## Extending to Additional Damage Qualifiers

The `if/elif` pattern scales naturally if additional qualifiers are added to `on_damage` (e.g., `is_shield_break: bool`, `is_reflect: bool`):

```gdscript
func _on_combat_damage(_target, amount: float, is_crit: bool, _pos: Vector2) -> void:
    if is_crit:
        # Critical: highest priority qualifier
        _play_if_valid(_critical_hit_sfx_player)
    elif is_shield_break:
        # Shield break: second-priority big moment (hypothetical S24.x)
        _play_if_valid(_shield_break_sfx_player)
    elif amount >= HIT_SFX_MIN_AMOUNT:
        # Normal hit: lowest priority, still threshold-guarded
        _play_if_valid(_hit_sfx_player)
    # else: silence (boundary tick, splash, reflect — suppressed)
```

Priority ordering: crit > shield_break > normal_hit > silence. This makes the sound selection deterministic and auditorially correct — the "most significant" qualifier wins.

---

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| `if is_crit: play_crit(); if amount >= threshold: play_hit()` | Both fire on crit events above threshold — unintended layered sound. |
| `if is_crit: play_crit(); else: play_hit()` | Plays hit sound on ALL non-crit events, including boundary-tick (amount < threshold). Removes the spam guard. |
| Separate signal handlers for crit vs. hit | `on_damage` doesn't distinguish — you'd need two different signals from `combat_sim.gd`, which isn't the architecture. Keep qualifier routing in one handler. |
| Checking `is_crit` after the amount threshold | `if amount >= threshold and is_crit: play_crit(); elif amount >= threshold: play_hit()` — fails for low-damage crits (which should always play). |

---

## Composability with Cooldown Guard

For events that might fire N times per tick (see `cooldown-guard-before-yield.md`), the cooldown guard wraps the entire handler before the branch logic:

```gdscript
func _on_some_event(qualifier: bool, amount: float) -> void:
    if _cooldown_active:
        return  # suppress duplicates FIRST
    if qualifier:
        _play_if_valid(_qualifier_player)
    elif amount >= THRESHOLD:
        _play_if_valid(_default_player)
```

The two patterns are composable: cooldown guard deduplicates same-tick events; branch logic routes the surviving events to the correct sound.

---

## Test Pattern

For test files covering this pattern, the key invariants are:

1. `is_crit=true` → crit player is target (not hit player)
2. `is_crit=true` → hit player is NOT target (mutual exclusion)
3. `is_crit=false, amount >= threshold` → hit player is target (not crit player)
4. `is_crit=false, amount < threshold` → neither player fires (silence)

All four cases must be covered. See `test_s24_4_001_crit_sfx_routing.gd` (T1d–T1g) for the canonical GDScript implementation of these invariants.

---

## References

- `game_main.gd` — `_on_combat_damage()` (S24.4 implementation, canonical reference)
- `docs/kb/combat-sfx-spam-guard.md` — amount-threshold pattern (S24.3)
- `docs/kb/cooldown-guard-before-yield.md` — mass-event cooldown pattern (S24.4)
- `docs/kb/signal-based-sfx-integration.md` — full SFX wiring pattern (S24.3)
- `godot/tests/test_s24_4_001_crit_sfx_routing.gd` — reference test implementation
