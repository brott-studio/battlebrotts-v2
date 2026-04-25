## item_pool.gd — S25.5: Full item pool for roguelike reward picks
## Used by reward_pick_screen.gd and testable in isolation.
class_name ItemPool
extends RefCounted

## Full 16-item roguelike reward pool.
## Weapons 0-6 (all), Armors 1-3 (NONE=0 excluded), Modules 0-5 (all).
const FULL_ITEM_POOL: Array[Dictionary] = [
	## Weapons
	{"category": "weapon", "type": 0, "display_name": "Minigun"},
	{"category": "weapon", "type": 1, "display_name": "Railgun"},
	{"category": "weapon", "type": 2, "display_name": "Shotgun"},
	{"category": "weapon", "type": 3, "display_name": "Missile Pod"},
	{"category": "weapon", "type": 4, "display_name": "Plasma Cutter"},
	{"category": "weapon", "type": 5, "display_name": "Arc Emitter"},
	{"category": "weapon", "type": 6, "display_name": "Flak Cannon"},
	## Armors (NONE=0 excluded — can't pick "no armor" as reward)
	{"category": "armor", "type": 1, "display_name": "Plating"},
	{"category": "armor", "type": 2, "display_name": "Reactive Mesh"},
	{"category": "armor", "type": 3, "display_name": "Ablative Shell"},
	## Modules
	{"category": "module", "type": 0, "display_name": "Overclock"},
	{"category": "module", "type": 1, "display_name": "Repair Nanites"},
	{"category": "module", "type": 2, "display_name": "Shield Projector"},
	{"category": "module", "type": 3, "display_name": "Sensor Array"},
	{"category": "module", "type": 4, "display_name": "Afterburner"},
	{"category": "module", "type": 5, "display_name": "EMP Charge"},
]
