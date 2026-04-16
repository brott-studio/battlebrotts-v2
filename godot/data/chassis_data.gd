## Static chassis definitions
## Sprint 13.3: Align HP with GDD §3.1 (Scout 110, Brawler 150, Fortress 220 — post-S13.3 balance pass)
## Sprint 13.3: Per-chassis TCR phase durations for combat rhythm identity
class_name ChassisData
extends RefCounted

enum ChassisType { SCOUT, BRAWLER, FORTRESS }

const CHASSIS := {
	ChassisType.SCOUT: {
		"name": "Scout",
		"hp": 165,  # S13.3: base 110 × 1.5 pacing multiplier (GDD spec is 110; engine uses 1.5× since S4 pacing pass)
		"speed": 220.0, # px/s
		"accel": 660.0, # px/s²
		"decel": 880.0, # px/s²
		"turn_speed": 360.0, # °/s (visual only)
		"weight_cap": 30,
		"weapon_slots": 2,
		"module_slots": 3,
		"passive": "dodge",
		"dodge_chance": 0.15,
	},
	ChassisType.BRAWLER: {
		"name": "Brawler",
		"hp": 225,  # S13.3: base 150 × 1.5 pacing multiplier (unchanged ratio, was already 225)
		"speed": 120.0,
		"accel": 240.0,
		"decel": 360.0,
		"turn_speed": 240.0,
		"weight_cap": 55,
		"weapon_slots": 2,
		"module_slots": 2,
		"passive": "",
		"dodge_chance": 0.0,
	},
	ChassisType.FORTRESS: {
		"name": "Fortress",
		"hp": 330,  # S13.3: base 220 × 1.5 pacing multiplier (GDD spec is 220; engine uses 1.5×)
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
