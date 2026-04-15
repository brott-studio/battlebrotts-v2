## Static module definitions — Sprint 4: archetypes + descriptions added
class_name ModuleData
extends RefCounted

enum ModuleType { OVERCLOCK, REPAIR_NANITES, SHIELD_PROJECTOR, SENSOR_ARRAY, AFTERBURNER, EMP_CHARGE }

const MODULES := {
	ModuleType.OVERCLOCK: {
		"name": "Overclock",
		"archetype": "⚡ Adrenaline",
		"description": "Burst of fire rate, then a hangover. Time it right or pay the price.",
		"weight": 5,
		"activated": true,
		"passive_effect": "",
		"duration": 4.0,      # sec active
		"cooldown": 3.0,      # 3s recovery after 4s active
		"fire_rate_bonus": 0.30,
		"fire_rate_penalty": -0.20,  # during cooldown after use
	},
	ModuleType.REPAIR_NANITES: {
		"name": "Repair Nanites",
		"archetype": "💚 Passive Heal",
		"description": "Slow, steady regeneration. Wins long fights by outlasting everyone.",
		"weight": 7,
		"activated": false,
		"passive_effect": "heal",
		"heal_per_sec": 3.0,
	},
	ModuleType.SHIELD_PROJECTOR: {
		"name": "Shield Projector",
		"archetype": "🔵 Panic Button",
		"description": "Pop it when things go south. One-time damage sponge on a long cooldown.",
		"weight": 10,
		"activated": true,
		"passive_effect": "",
		"absorb": 40,
		"duration": 5.0,
		"cooldown": 20.0,
	},
	ModuleType.SENSOR_ARRAY: {
		"name": "Sensor Array",
		"archetype": "👁️ Wallhack",
		"description": "See farther, see through cover. Knowledge is power.",
		"weight": 4,
		"activated": false,
		"passive_effect": "vision",
		"extra_sight_tiles": 3,
	},
	ModuleType.AFTERBURNER: {
		"name": "Afterburner",
		"archetype": "🏃 Nitro Boost",
		"description": "2 seconds of blazing speed. Escape, reposition, or close the gap.",
		"weight": 6,
		"activated": true,
		"passive_effect": "",
		"speed_bonus": 0.80,
		"duration": 2.0,
		"cooldown": 12.0,
	},
	ModuleType.EMP_CHARGE: {
		"name": "EMP Charge",
		"archetype": "🔇 Shutdown",
		"description": "Turn off their toys for 3 seconds. Devastating against module-heavy builds.",
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
