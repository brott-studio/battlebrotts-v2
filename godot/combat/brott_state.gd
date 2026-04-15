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
var dodge_chance: float = 0.0

# Runtime combat state
var hp: float = 0.0
var energy: float = 100.0
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
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

# BrottBrain
var brain: RefCounted = null  # BrottBrain instance
var _pending_gadget: String = ""  # Set by brain, consumed by combat_sim
var overtime: bool = false  # Set by CombatSim when overtime triggers

# Target
var target: BrottState = null

# Visual state
var flash_timer: float = 0.0
var death_timer: float = 0.0

func setup() -> void:
	var ch := ChassisData.get_chassis(chassis_type)
	max_hp = ch["hp"]
	hp = max_hp
	base_speed = ch["speed"]
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
