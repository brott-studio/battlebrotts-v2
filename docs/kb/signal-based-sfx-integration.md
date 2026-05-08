# Signal-Based SFX Integration Pattern

**Established:** S24.3 (Combat SFX — hit + projectile)
**Applies to:** Any event-driven AudioStreamPlayer wiring in `game_main.gd`
**Reference implementation:** `game_main.gd` `_init_combat_sfx_players()`, `_on_combat_damage()`, `_on_projectile_spawned()`

---

## Pattern Description

Wire one-shot `AudioStreamPlayer` nodes to GDScript signals for event-driven SFX playback. Each distinct sound event gets its own long-lived `AudioStreamPlayer` instance, initialized once at scene load, reused on each signal emit.

---

## Canonical Implementation

### 1. Declare constants and member vars at file top

```gdscript
# [Sprint tag] SFX preloads — one const per event type.
const HIT_SFX: AudioStream = preload("res://assets/audio/sfx/hit.ogg")
const PROJECTILE_LAUNCH_SFX: AudioStream = preload("res://assets/audio/sfx/projectile_launch.ogg")
var _hit_sfx_player: AudioStreamPlayer = null
var _projectile_launch_sfx_player: AudioStreamPlayer = null
```

### 2. Initialize players in a dedicated `_init_*_sfx_players()` function

Called from `_ready()` (or the equivalent scene init point).

```gdscript
func _init_combat_sfx_players() -> void:
    _hit_sfx_player = AudioStreamPlayer.new()
    _hit_sfx_player.name = "HitSfxPlayer"
    _hit_sfx_player.bus = "SFX"      # ← MUST be set BEFORE add_child
    _hit_sfx_player.stream = HIT_SFX
    add_child(_hit_sfx_player)

    _projectile_launch_sfx_player = AudioStreamPlayer.new()
    _projectile_launch_sfx_player.name = "ProjectileLaunchSfxPlayer"
    _projectile_launch_sfx_player.bus = "SFX"   # ← MUST be set BEFORE add_child
    _projectile_launch_sfx_player.stream = PROJECTILE_LAUNCH_SFX
    add_child(_projectile_launch_sfx_player)
```

**Critical ordering rule (S21.5 convention):** `.bus = "SFX"` must be set **before** `add_child()`. Setting it after `add_child` may not be picked up by the audio engine at play time in some Godot 4 builds. Boltz B4 gate enforces this in every PR review.

### 3. Connect signals at sim creation sites

Connect at every CombatSim instantiation site — both demo match and real match paths:

```gdscript
func _start_demo_match() -> void:
    # ... sim setup ...
    sim.on_damage.connect(_on_combat_damage)
    sim.on_projectile_spawned.connect(_on_projectile_spawned)

func _start_match(opponent_index: int) -> void:
    # ... sim setup ...
    sim.on_damage.connect(_on_combat_damage)
    sim.on_projectile_spawned.connect(_on_projectile_spawned)
```

If only one site is connected, SFX will be silent in the other path. Boltz B3 verifies both connection sites.

### 4. Signal handlers with null/validity guard

```gdscript
func _on_combat_damage(_target, amount: float, _is_crit: bool, _pos: Vector2) -> void:
    if amount >= HIT_SFX_MIN_AMOUNT and _hit_sfx_player != null and is_instance_valid(_hit_sfx_player):
        _hit_sfx_player.play()

func _on_projectile_spawned(_proj) -> void:
    if _projectile_launch_sfx_player != null and is_instance_valid(_projectile_launch_sfx_player):
        _projectile_launch_sfx_player.play()
```

The `is_instance_valid()` check prevents crashes if the player is freed during teardown while a signal fires.

---

## Spam Guard

For high-frequency events (damage ticks, spread weapon pellets, boundary damage), apply an amount-threshold guard:

```gdscript
const HIT_SFX_MIN_AMOUNT: float = 5.0   # Suppress sub-threshold damage (boundary ticks ~1–3)

func _on_combat_damage(_target, amount: float, _is_crit: bool, _pos: Vector2) -> void:
    if amount >= HIT_SFX_MIN_AMOUNT and ...:
        _hit_sfx_player.play()
```

For cooldown-based guards (not used in S24.3), see `docs/kb/combat-sfx-spam-guard.md`.

---

## SFX Bus Routing

All SFX players route to bus index 1 (`"SFX"`) in the 3-bus architecture (Master=0, SFX=1, Music=2). This ensures:
- Volume respects the SFX slider from S24.2's `MixerSettingsPanel`
- Per-bus mute works correctly
- SFX doesn't bypass the master limiter

Never set `.bus = "Master"` for gameplay sounds. The `"SFX"` bus (index 1) is the correct target.

---

## Player Naming Convention

Use `PascalCase + "Player"` suffix for `AudioStreamPlayer.name`:
- `HitSfxPlayer`
- `ProjectileLaunchSfxPlayer`
- `PopupWhooshPlayer` (S21.5)

Named nodes are easier to find in the scene tree during debugging and are referenced by name in tests.

---

## Test Coverage Pattern

Each new SFX player gets at minimum:
1. **Bus routing test** — instantiate the player, set `.bus = "SFX"` before `add_child`, assert `player.bus == "SFX"` and `player.bus != "Master"`.
2. **Asset existence test** — `FileAccess.file_exists("res://assets/audio/sfx/<file>.ogg")`.

Register all test files in `test_runner.gd SPRINT_TEST_FILES` in the same PR. Missing registration = silent-0-assertion failure (B7 catch).

---

## Anti-Patterns

| Anti-pattern | Why wrong | Correct approach |
|---|---|---|
| `.bus = "SFX"` after `add_child` | May not be applied at play time | Always set before `add_child` |
| New `AudioStreamPlayer` created on every signal emit | Memory leak; audio pop artifacts | Create once in `_init_*_sfx_players()`, reuse |
| Connecting signal in only one sim creation site | SFX silent in demo/real match path | Connect at all CombatSim instantiation sites |
| No null guard in handler | Crash during teardown | `_player != null and is_instance_valid(_player)` |
| `.bus = "Master"` | Bypasses SFX volume control | Use `"SFX"` (bus index 1) |

---

*Added in S24.3. Updated when pattern evolves.*
