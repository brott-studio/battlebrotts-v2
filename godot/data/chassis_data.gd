## Static chassis definitions — Sprint 4: 1.5x HP for pacing (v3)
class_name ChassisData
extends RefCounted

enum ChassisType { SCOUT, BRAWLER, FORTRESS }

const CHASSIS := {
	ChassisType.SCOUT: {
		"name": "Scout",
		"hp": 150,
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
		"hp": 225,
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
		"hp": 270,
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

static func get_chassis(type: ChassisType) -> Dictionary:
	return CHASSIS[type]
