# Default Starter State Pattern

**Source:** Arc F.5 (S26.1 P0) — 2026-04-27
**Audit:** `studio-audits/audits/battlebrotts-v2/v2-sprint-26.1.md`

## Pattern

Any state field whose default `[]` / `{}` / `null` would put the player in an
**unrecoverable** state at the next state-transition needs a non-empty seed
applied at run/match/state creation time.

The canonical Arc F.5 instance: `RunState.equipped_weapons` defaulted to
`[]`. The next state-transition (battle 1 start) assumed the array was
non-empty and dispatched the player into combat unarmed. Enemies destroyed
the empty player ship before the arena rendered meaningfully → "blank
screen" P0.

## Rule of thumb

For each field on a state object, ask: *"If a player starts a fresh run /
fresh save / fresh state with this field at its zero-value, does the next
state-transition do the right thing?"*

- ✅ Yes (e.g. `current_battle: int = 1` — zero is fine, gets incremented) → leave it.
- ❌ No (e.g. `equipped_weapons: Array[int] = []` — empty means unarmed-into-battle) → **seed a non-empty default in `_init()` or the run-creation factory**.

## Reference implementation (S26.1)

`godot/game/run_state.gd`:

```gdscript
var equipped_weapons: Array[int] = []
# ...
func _init() -> void:
    equipped_weapons = []
    # ...
    ## [S26.1-003] Battle-start fix: every new run must enter battle 1 with at
    ## least one weapon. Pre-S26.1 the player had `equipped_weapons = []`, which
    ## meant enemies killed the empty player ship before render → blank screen.
    ## GDD never specified a starter weapon, so we fill the gap here with
    ## Plasma Cutter (WeaponData.WeaponType.PLASMA_CUTTER == 4).
    if equipped_weapons.is_empty():
        equipped_weapons.append(4)  # WeaponData.WeaponType.PLASMA_CUTTER
```

## Cross-references

- **GDD §13.2 RunState** documents the canonical starter-weapon contract.
- **kb/decisions/gdd-code-parity.md** explains why §13 was missing in the
  first place — the structural rule that prevents the *next* Arc F.5.
- **kb/troubleshooting/blank-screen-godot-html5.md** is the diagnostic
  flow for the symptom this pattern prevents.

## Belt-and-suspenders companion

In `godot/game_main.gd`, S26.1 also added `_show_run_error(msg)` plus a
defensive guard around `_start_roguelike_match`. If any future regression
produces a `null` or invalid run_state, the user sees an error screen
instead of a blank canvas. **The seed-default pattern prevents the bad
state; the error-surface ensures graceful failure if prevention slips.**
Pair both for any P0-class state contract.
