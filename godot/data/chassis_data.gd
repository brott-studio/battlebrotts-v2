## Static chassis definitions
## Sprint 13.3: Align HP with GDD §3.1 (Scout 110, Brawler 150, Fortress 220 — post-S13.3 balance pass)
## Sprint 13.3: Per-chassis TCR phase durations for combat rhythm identity
class_name ChassisData
extends RefCounted

enum ChassisType { SCOUT, BRAWLER, FORTRESS }

const CHASSIS := {
	ChassisType.SCOUT: {
		"name": "Scout",
		"hp": 215,  # J.5: +30% HP to lift T1 survivability (was 165)
		"speed": 220.0, # px/s
		"accel": 660.0, # px/s²
		"decel": 880.0, # px/s²
		"turn_speed": 360.0, # °/s (visual only)
		"weight_cap": 30,
		"weapon_slots": 2,
		"module_slots": 3,
		"passive": "dodge",
		"dodge_chance": 0.25,  # J.5: +10pp dodge — amplify Scout's slippery identity (was 0.15)
	},
	ChassisType.BRAWLER: {
		"name": "Brawler",
		"hp": 360,  # K.3: +22% HP buff to lift T1 battle win-rate ≥30% (was 295, #314)
		"speed": 60.0,    # O.2: 120→60 px/s (too fast to follow visually)
		"accel": 120.0,   # O.2: halved proportionally (was 240.0)
		"decel": 180.0,   # O.2: halved proportionally (was 360.0)
		"turn_speed": 240.0,
		"weight_cap": 55,
		"weapon_slots": 2,
		"module_slots": 2,
		"passive": "",
		"dodge_chance": 0.0,
	},
	ChassisType.FORTRESS: {
		"name": "Fortress",
		"hp": 450,  # J.5.2: +36% HP buff for T1 survivability (was 330). Fortress is slowest chassis (60 px/s), 0 dodge, Defensive stance — cannot outrun T1 glass_cannon_blitz kite encounter. Scout/Brawler got +30-31% in J.5.1 (#314).
		"speed": 60.0,
		"accel": 90.0,
		"decel": 150.0,
		"turn_speed": 150.0,
		"weight_cap": 80,
		"weapon_slots": 2,
		"module_slots": 1,
		"passive": "",
		"dodge_chance": 0.0,
	},
}

# --- S13.3: Per-chassis TCR timings (ticks, 10 ticks/sec) ---
# Each chassis has its own combat rhythm, giving distinct fantasy:
#   Scout   — slippery: long TENSION, short COMMIT, long RECOVERY
#   Brawler — baseline: matches previous single-constant TCR values
#   Fortress— relentless: short TENSION, long COMMIT, short RECOVERY
# See docs/gdd.md §5.3.1 for rationale.
const TCR_TIMINGS := {
	ChassisType.SCOUT: {
		"tension_min": 25,   # 2.5s
		"tension_max": 40,   # 4.0s
		"commit": 6,         # 0.6s
		"recovery": 15,      # 1.5s
	},
	ChassisType.BRAWLER: {
		"tension_min": 20,   # 2.0s (baseline, unchanged from S13.2)
		"tension_max": 35,   # 3.5s
		"commit": 8,         # 0.8s
		"recovery": 12,      # 1.2s
	},
	ChassisType.FORTRESS: {
		"tension_min": 15,   # 1.5s
		"tension_max": 25,   # 2.5s
		"commit": 12,        # 1.2s
		"recovery": 9,       # 0.9s
	},
}

static func get_chassis(type: ChassisType) -> Dictionary:
	return CHASSIS[type]

static func get_tcr_timings(type: ChassisType) -> Dictionary:
	return TCR_TIMINGS[type]
