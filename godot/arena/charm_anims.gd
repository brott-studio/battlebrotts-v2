## Sprint 12.4: Charm pass — personality animations (render-layer only)
## Idle anims, movement quirks, victory/defeat reactions, combat flavor
## NONE of these affect gameplay logic or sim positions.
class_name CharmAnims
extends RefCounted

const TICK_DELTA := 1.0 / 60.0  # visual frame rate

# --- Idle animation parameters per chassis ---
static func get_idle_offset(chassis_type: int, timer: float) -> float:
	match chassis_type:
		ChassisData.ChassisType.SCOUT:
			# hover-bob: 1px up/down, 0.8s cycle
			return sin(timer * TAU / 0.8) * 1.0
		ChassisData.ChassisType.BRAWLER:
			# side-to-side rock: 1px, 1.2s cycle (returned as Y=0, caller uses as X)
			return sin(timer * TAU / 1.2) * 1.0
		ChassisData.ChassisType.FORTRESS:
			# mechanical breathing: 0.5px up/down, 2.0s cycle
			return sin(timer * TAU / 2.0) * 0.5
	return 0.0

static func get_idle_is_horizontal(chassis_type: int) -> bool:
	return chassis_type == ChassisData.ChassisType.BRAWLER

# --- Movement quirk checks ---
static func should_scout_spin(rng: RandomNumberGenerator) -> bool:
	## 10% chance on direction change
	return rng.randf() < 0.1

static func create_dust_puff(pos: Vector2) -> Array:
	## Brawler dust puff particles when starting from standstill
	var puffs := []
	for i in range(4):
		var angle := randf() * TAU
		var speed := randf_range(15.0, 30.0)
		puffs.append({
			"pos": pos + Vector2(0, 10),  # at feet
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0, -10),
			"lifetime": 18.0,  # 0.3s
			"max_lifetime": 18.0,
			"color": Color(0.6, 0.55, 0.45, 0.6),
			"size": randf_range(2.0, 4.0),
		})
	return puffs

static func create_gear_particle(pos: Vector2, vel_dir: Vector2) -> Dictionary:
	## Fortress gear-grinding particle on deceleration
	return {
		"pos": pos,
		"vel": vel_dir.normalized() * -20.0 + Vector2(randf_range(-5, 5), randf_range(-10, 0)),
		"lifetime": 12.0,
		"max_lifetime": 12.0,
		"color": Color(0.7, 0.65, 0.5, 0.7),
		"size": 1.5,
	}

# --- Victory/defeat animation tick ---
static func tick_victory_anim(b: BrottState, delta: float) -> void:
	if b.victory_anim_timer <= 0:
		return
	b.victory_anim_timer -= delta

	var t: float  # 0→1 progress
	match b.victory_anim_type:
		"win":
			# small spin + jump (4px up, 0.3s)
			t = 1.0 - (b.victory_anim_timer / 0.3)
			t = clampf(t, 0.0, 1.0)
			b.charm_rotation = t * 360.0
			b.charm_y_offset = -sin(t * PI) * 4.0
		"perfect":
			# double spin + bigger jump (6px, ~0.5s)
			t = 1.0 - (b.victory_anim_timer / 0.5)
			t = clampf(t, 0.0, 1.0)
			b.charm_rotation = t * 720.0
			b.charm_y_offset = -sin(t * PI) * 6.0
		"close":
			# single wobbly spin (shaking)
			t = 1.0 - (b.victory_anim_timer / 0.4)
			t = clampf(t, 0.0, 1.0)
			b.charm_rotation = t * 360.0
			# wobble via rapid small offset
			b.charm_y_offset = sin(t * PI * 8.0) * 1.5
		"loss":
			# slump down (2px, 0.5s) + sparks handled externally
			t = 1.0 - (b.victory_anim_timer / 0.5)
			t = clampf(t, 0.0, 1.0)
			b.charm_y_offset = t * 2.0  # sink down
			b.charm_rotation = 0.0

	if b.victory_anim_timer <= 0:
		b.victory_anim_timer = 0.0
		b.charm_y_offset = 0.0
		b.charm_rotation = 0.0

static func start_victory_anim(b: BrottState, anim_type: String) -> void:
	b.victory_anim_type = anim_type
	match anim_type:
		"win": b.victory_anim_timer = 0.3
		"perfect": b.victory_anim_timer = 0.5
		"close": b.victory_anim_timer = 0.4
		"loss": b.victory_anim_timer = 0.5
		_: b.victory_anim_timer = 0.3

# --- Combat flavor: smoke trail for low HP ---
static func create_smoke_particle(pos: Vector2) -> Dictionary:
	return {
		"pos": pos + Vector2(randf_range(-4, 4), randf_range(-2, 2)),
		"vel": Vector2(randf_range(-8, 8), randf_range(-20, -10)),
		"lifetime": 24.0,
		"max_lifetime": 24.0,
		"color": Color(0.3, 0.3, 0.3, 0.5),
		"size": randf_range(2.0, 3.5),
	}

# --- Combat flavor: module activation ring ---
static func get_module_ring_color(module_type: int) -> Color:
	match module_type:
		ModuleData.ModuleType.OVERCLOCK: return Color(1.0, 0.6, 0.0)
		ModuleData.ModuleType.REPAIR_NANITES: return Color(0.2, 0.8, 0.2)
		ModuleData.ModuleType.SHIELD_PROJECTOR: return Color(0.3, 0.5, 1.0)
		ModuleData.ModuleType.SENSOR_ARRAY: return Color(1.0, 0.9, 0.2)
		ModuleData.ModuleType.AFTERBURNER: return Color(1.0, 0.2, 0.2)
		ModuleData.ModuleType.EMP_CHARGE: return Color(0.6, 0.2, 0.9)
	return Color.WHITE
