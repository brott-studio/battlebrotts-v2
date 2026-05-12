# KB: Additive FirstRunState Schema Extension Pattern

**Source:** S24.2 (Arc E — Audio Depth)
**Owner:** battlebrotts-v2

---

## Pattern

When extending `FirstRunState` with new persistent settings, follow the **additive-only** schema extension pattern:

1. **Add new keys to `[settings]` section only.** Never add keys to `[seen]`, never rename or remove existing keys.
2. **Use `_cfg.get_value(SETTINGS_SECTION, "key", <safe_default>)` for reads.** The safe default is silently applied when the key is absent (old saves load the default — no migration required).
3. **Provide both `get_` and `set_` helpers** following the existing `get_audio_muted()` / `set_audio_muted()` naming pattern.
4. **Save on every write.** Each `set_*` method calls `_cfg.save(STORE_PATH)` immediately.
5. **Log save errors with `push_warning`, do not assert or crash.**

## Example — S24.2 Volume Helpers

```gdscript
func get_master_db() -> float:
    _ensure_loaded()
    return float(_cfg.get_value(SETTINGS_SECTION, "master_db", 0.0))

func set_master_db(value: float) -> void:
    _ensure_loaded()
    _cfg.set_value(SETTINGS_SECTION, "master_db", value)
    var err := _cfg.save(STORE_PATH)
    if err != OK:
        push_warning("[FirstRunState] save error %s for master_db" % err)
```

## Schema after S24.2

```ini
[settings]
audio_muted=false     ; S21.5 — do NOT rename
master_db=0.0         ; S24.2 — safe default 0.0
sfx_db=0.0            ; S24.2 — safe default 0.0
music_db=-6.0         ; S24.2 — safe default -6.0 (matches default_bus_layout.tres)
```

## Enforcement

- Never co-mingle `[seen]` and `[settings]` keys.
- Music default must match `default_bus_layout.tres` (-6.0 dB).
- Old saves are forward-compatible by construction via the safe-default pattern.

## Anti-patterns

- Renaming `"audio_muted"` — silently breaks old saves.
- Storing volume as linear amplitude instead of dB.
- Omitting `_ensure_loaded()` from getters.

## References

- `godot/ui/first_run_state.gd`
- `audits/battlebrotts-v2/v2-sprint-24.2.md`
