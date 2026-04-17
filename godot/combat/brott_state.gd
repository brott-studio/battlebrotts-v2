## Runtime state for a single Brott in combat
class_name BrottState
extends RefCounted

# Identity
var team: int = 0  # 0 = player, 1 = enemy
var bot_name: String = ""

# Loadout (set once before match)
var chassis_type: ChassisData.ChassisType
var weapon_types: Array[WeaponData.WeaponType] = []
var armor_type: ArmorData.ArmorType = ArmorData.ArmorType.NONE
var module_types: Array[ModuleData.ModuleType] = []

# Cached stats
var max_hp: int = 0
var base_speed: float = 0.0
var base_accel: float = 0.0
var base_decel: float = 0.0
var turn_speed: float = 0.0  # visual only (°/s)
var dodge_chance: float = 0.0

# Runtime combat state
var hp: float = 0.0
var energy: float = 100.0
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var current_speed: float = 0.0  # current movement speed (px/s)
var facing_angle: float = 0.0  # visual sprite rotation (degrees)
var alive: bool = true

# Weapon cooldowns (ticks until next fire)
var weapon_cooldowns: Array[float] = []

# Module runtime
var module_cooldowns: Array[float] = []  # 0 = ready, >0 = on cooldown (ticks)
var module_active_timers: Array[float] = []  # >0 = currently active (ticks)

# Shield state
var shield_hp: float = 0.0
var shield_active: bool = false

# Overclock state
var overclock_active: bool = false
var overclock_recovery: bool = false

# Afterburner
var afterburner_active: bool = false

# EMP (modules disabled)
var emp_disabled_timer: float = 0.0

# Stance
var stance: int = 0  # 0=aggressive, 1=defensive, 2=kiting, 3=ambush

# S13.6: Per-match pellet modifier (additive, applied per-weapon at fire time).
# Populated by GameState.build_brott() from _next_fight_pellet_mod and consumed
# inside CombatSim._fire_weapon(); floor-clamped to 1 pellet per shot.
var pellet_mod: int = 0

# BrottBrain
var brain: RefCounted = null  # BrottBrain instance
var _pending_gadget: String = ""  # Set by brain, consumed by combat_sim
var overtime: bool = false  # Set by CombatSim when overtime triggers

# Target
var target: BrottState = null

# Combat movement state
var in_combat_movement: bool = false
var orbit_direction: int = 1  # 1 = CW, -1 = CCW

# S14.1-B: Wall-stuck detection. Rolling history of last N positions sampled each
# tick. If total displacement over the window is <STUCK_MIN_PX while alive+has
# target, bot is considered stuck and gets an unstick nudge.
var _stuck_history: Array[Vector2] = []  # oldest first; capped to STUCK_WINDOW_TICKS
var _unstick_timer: float = 0.0  # ticks remaining in active unstick maneuver
var juke_timer: float = 0.0  # ticks until next juke (legacy, kept for compat)
var juke_active_timer: float = 0.0  # ticks remaining in current juke (legacy)
var juke_type: String = ""  # "lateral", "toward", "away" (legacy)
var backup_distance: float = 0.0  # tracks straight-line backup to enforce 1-tile max

# TCR (Tension→Commit→Recovery) combat rhythm state (S13.2)
var combat_phase: int = 0  # 0=TENSION, 1=COMMIT, 2=RECOVERY
var combat_phase_timer: int = 0  # ticks remaining in current phase
var tension_drift_timer: int = 0  # ticks until next lateral drift
var commit_start_distance: float = 0.0  # distance to target when commit began
var combat_exit_grace_timer: float = 0.0  # ticks remaining before TCR state resets (S13.2 fix)

# Visual state
var flash_timer: float = 0.0
var death_timer: float = 0.0

# S12.4: Charm pass — render-layer only, no gameplay effect
var idle_timer: float = 0.0  # continuous timer for idle animation
var last_direction: Vector2 = Vector2.ZERO  # for detecting direction changes
var was_moving: bool = false  # for detecting standstill→move transition
var spin_anim_timer: float = 0.0  # Scout 360° spin on direction change
var smoke_particles: Array = []  # trailing smoke below 25% HP
var recoil_offset: Vector2 = Vector2.ZERO  # visual recoil from crits
var module_ring_timer: float = 0.0  # colored ring on module activation
var module_ring_color: Color = Color.WHITE
var victory_anim_timer: float = 0.0  # win/loss reaction
var victory_anim_type: String = ""  # "win", "perfect", "close", "loss"
var charm_y_offset: float = 0.0  # vertical offset from idle/victory anims
var charm_rotation: float = 0.0  # rotation from spin anims

func setup() -> void:
	var ch := ChassisData.get_chassis(chassis_type)
	max_hp = ch["hp"]
	hp = max_hp
	base_speed = ch["speed"]
	base_accel = ch["accel"]
	base_decel = ch["decel"]
	turn_speed = ch["turn_speed"]
	dodge_chance = ch["dodge_chance"]
	energy = 100.0
	alive = true
	
	weapon_cooldowns.clear()
	for _w in weapon_types:
		weapon_cooldowns.append(0.0)
	
	module_cooldowns.clear()
	module_active_timers.clear()
	for _m in module_types:
		module_cooldowns.append(0.0)
		module_active_timers.append(0.0)

func get_effective_speed() -> float:
	var spd := base_speed
	if afterburner_active:
		spd *= 1.80
	return spd

func get_effective_accel() -> float:
	var accel := base_accel
	if afterburner_active:
		accel *= 1.80
	return accel

func get_effective_decel() -> float:
	# Decel unchanged by afterburner per spec
	return base_decel

func accelerate_toward_speed(target_speed: float, dt: float) -> void:
	## Ramps current_speed toward target_speed using accel/decel curves
	if current_speed < target_speed:
		current_speed = minf(current_speed + get_effective_accel() * dt, target_speed)
	elif current_speed > target_speed:
		current_speed = maxf(current_speed - get_effective_decel() * dt, target_speed)

func get_fire_rate_multiplier() -> float:
	if overclock_active:
		return 1.30
	if overclock_recovery:
		return 0.80
	return 1.0

func get_armor_reduction() -> float:
	var hp_pct := hp / float(max_hp)
	return ArmorData.effective_reduction(armor_type, hp_pct)

func get_total_weight() -> int:
	var w := 0
	for wt in weapon_types:
		w += WeaponData.get_weapon(wt)["weight"]
	w += ArmorData.get_armor(armor_type)["weight"]
	for mt in module_types:
		w += ModuleData.get_module(mt)["weight"]
	return w
