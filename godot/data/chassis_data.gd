## Static chassis definitions — Sprint 4: HP tripled for pacing
class_name ChassisData
extends RefCounted

enum ChassisType { SCOUT, BRAWLER, FORTRESS }

const CHASSIS := {
	ChassisType.SCOUT: {
		"name": "Scout",
		"hp": 300,
		"speed": 220.0, # px/s
		"weight_cap": 30,
		"weapon_slots": 2,
		"module_slots": 3,
		"passive": "dodge",
		"dodge_chance": 0.15,
	},
	ChassisType.BRAWLER: {
		"name": "Brawler",
		"hp": 450,
		"speed": 120.0,
		"weight_cap": 55,
		"weapon_slots": 2,
		"module_slots": 2,
		"passive": "",
		"dodge_chance": 0.0,
	},
	ChassisType.FORTRESS: {
		"name": "Fortress",
		"hp": 540,
		"speed": 60.0,
		"weight_cap": 80,
		"weapon_slots": 2,
		"module_slots": 1,
		"passive": "",
		"dodge_chance": 0.0,
	},
}

static func get_chassis(type: ChassisType) -> Dictionary:
	return CHASSIS[type]
