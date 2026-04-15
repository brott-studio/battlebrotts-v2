## Static module definitions
class_name ModuleData
extends RefCounted

enum ModuleType { OVERCLOCK, REPAIR_NANITES, SHIELD_PROJECTOR, SENSOR_ARRAY, AFTERBURNER, EMP_CHARGE }

const MODULES := {
	ModuleType.OVERCLOCK: {
		"name": "Overclock",
		"weight": 5,
		"activated": true,
		"passive_effect": "",
		"duration": 4.0,      # sec active
		"cooldown": 7.0,      # 4s active + 3s recovery
		"fire_rate_bonus": 0.30,
		"fire_rate_penalty": -0.20,  # during cooldown after use
	},
	ModuleType.REPAIR_NANITES: {
		"name": "Repair Nanites",
		"weight": 7,
		"activated": false,
		"passive_effect": "heal",
		"heal_per_sec": 3.0,
	},
	ModuleType.SHIELD_PROJECTOR: {
		"name": "Shield Projector",
		"weight": 10,
		"activated": true,
		"passive_effect": "",
		"absorb": 40,
		"duration": 5.0,
		"cooldown": 20.0,
	},
	ModuleType.SENSOR_ARRAY: {
		"name": "Sensor Array",
		"weight": 4,
		"activated": false,
		"passive_effect": "vision",
		"extra_sight_tiles": 3,
	},
	ModuleType.AFTERBURNER: {
		"name": "Afterburner",
		"weight": 6,
		"activated": true,
		"passive_effect": "",
		"speed_bonus": 0.80,
		"duration": 2.0,
		"cooldown": 12.0,
	},
	ModuleType.EMP_CHARGE: {
		"name": "EMP Charge",
		"weight": 9,
		"activated": true,
		"passive_effect": "",
		"disable_duration": 3.0,
		"range_tiles": 4,
		"cooldown": 25.0,
	},
}

static func get_module(type: ModuleType) -> Dictionary:
	return MODULES[type]
