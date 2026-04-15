## Static weapon definitions — Balance Changes v3 applied
class_name WeaponData
extends RefCounted

enum WeaponType { MINIGUN, RAILGUN, SHOTGUN, MISSILE_POD, PLASMA_CUTTER, ARC_EMITTER, FLAK_CANNON }

const WEAPONS := {
	WeaponType.MINIGUN: {
		"name": "Minigun",
		"damage": 3,
		"range_tiles": 5,
		"fire_rate": 6.0, # shots/s
		"spread_deg": 15.0,
		"energy_cost": 2,
		"weight": 10,
		"pellets": 1,
		"splash_radius": 0,
		"chain_targets": 0,
	},
	WeaponType.RAILGUN: {
		"name": "Railgun",
		"damage": 45,
		"range_tiles": 12,
		"fire_rate": 0.6,
		"spread_deg": 0.0,
		"energy_cost": 16,
		"weight": 15,
		"pellets": 1,
		"splash_radius": 0,
		"chain_targets": 0,
	},
	WeaponType.SHOTGUN: {
		"name": "Shotgun",
		"damage": 6,
		"range_tiles": 3,
		"fire_rate": 1.5,
		"spread_deg": 30.0,
		"energy_cost": 8,
		"weight": 12,
		"pellets": 5,
		"splash_radius": 0,
		"chain_targets": 0,
	},
	WeaponType.MISSILE_POD: {
		"name": "Missile Pod",
		"damage": 30,
		"range_tiles": 8,
		"fire_rate": 0.8,
		"spread_deg": 5.0,
		"energy_cost": 12,
		"weight": 18,
		"pellets": 1,
		"splash_radius": 1, # tiles
		"chain_targets": 0,
	},
	WeaponType.PLASMA_CUTTER: {
		"name": "Plasma Cutter",
		"damage": 14,
		"range_tiles": 1.5,
		"fire_rate": 3.0,
		"spread_deg": 0.0,
		"energy_cost": 4,
		"weight": 8,
		"pellets": 1,
		"splash_radius": 0,
		"chain_targets": 0,
	},
	WeaponType.ARC_EMITTER: {
		"name": "Arc Emitter",
		"damage": 8,
		"range_tiles": 4,
		"fire_rate": 2.0,
		"spread_deg": 10.0,
		"energy_cost": 6,
		"weight": 11,
		"pellets": 1,
		"splash_radius": 0,
		"chain_targets": 1,
	},
	WeaponType.FLAK_CANNON: {
		"name": "Flak Cannon",
		"damage": 15,
		"range_tiles": 6,
		"fire_rate": 1.2,
		"spread_deg": 20.0,
		"energy_cost": 7,
		"weight": 13,
		"pellets": 1,
		"splash_radius": 0,
		"chain_targets": 0,
	},
}

static func get_weapon(type: WeaponType) -> Dictionary:
	return WEAPONS[type]
