## Sprint 13.9 — Opponent loadout templates + variety-preserving picker.
## See docs/design/sprint13.9-fortress-loadout-pass.md §3, §4.
class_name OpponentLoadouts
extends RefCounted

enum Archetype { TANK, GLASS_CANNON, SKIRMISHER, BRUISER, CONTROLLER }

# Template schema (§3.1): id, name, archetype, tier, chassis, weapons, armor, modules, stance.
const TEMPLATES: Array[Dictionary] = [
	{
		"id": "tank_ironclad",
		"name": "Ironclad",
		"archetype": Archetype.TANK,
		"tier": 2,
		"chassis": ChassisData.ChassisType.FORTRESS,
		"weapons": [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.FLAK_CANNON],
		"armor": ArmorData.ArmorType.ABLATIVE_SHELL,
		"modules": [ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 1,
	},
	{
		"id": "glass_sniper",
		"name": "Pinprick",
		"archetype": Archetype.GLASS_CANNON,
		"tier": 2,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.RAILGUN, WeaponData.WeaponType.PLASMA_CUTTER],
		"armor": ArmorData.ArmorType.NONE,
		"modules": [ModuleData.ModuleType.OVERCLOCK, ModuleData.ModuleType.SENSOR_ARRAY, ModuleData.ModuleType.AFTERBURNER],
		"stance": 2,
	},
	{
		"id": "skirmish_wasp",
		"name": "Wasp",
		"archetype": Archetype.SKIRMISHER,
		"tier": 1,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.FLAK_CANNON, WeaponData.WeaponType.PLASMA_CUTTER],
		"armor": ArmorData.ArmorType.PLATING,
		"modules": [ModuleData.ModuleType.AFTERBURNER, ModuleData.ModuleType.SENSOR_ARRAY, ModuleData.ModuleType.OVERCLOCK],
		"stance": 2,
	},
	{
		"id": "bruiser_crusher",
		"name": "Crusher-II",
		"archetype": Archetype.BRUISER,
		"tier": 2,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.MINIGUN],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.OVERCLOCK, ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 0,
	},
	{
		"id": "controller_jammer",
		"name": "Jammer",
		"archetype": Archetype.CONTROLLER,
		"tier": 3,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.ARC_EMITTER, WeaponData.WeaponType.MISSILE_POD],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.EMP_CHARGE, ModuleData.ModuleType.SHIELD_PROJECTOR],
		"stance": 1,
	},
	{
		"id": "tank_tincan",
		"name": "Tincan",
		"archetype": Archetype.TANK,
		"tier": 1,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.PLASMA_CUTTER],
		"armor": ArmorData.ArmorType.PLATING,
		"modules": [],
		"stance": 1,
	},
]

## §4.1 — maps (league, index) to a difficulty tier.
static func difficulty_for(league: String, index: int) -> int:
	match league:
		"scrapyard":
			var tiers := [1, 1, 2]
			return tiers[index] if index >= 0 and index < tiers.size() else 1
		"bronze":
			var tiers := [2, 2, 3]
			return tiers[index] if index >= 0 and index < tiers.size() else 2
		_:
			return 1

## §4 — tier filter + weaker-tier fallback + variety strip.
## player_archetype_hint unused; reserved for Sprint 13.10 counter-play.
static func pick_opponent_loadout(difficulty_tier: int, last_archetype: int = -1, _player_archetype_hint: int = -1) -> Dictionary:
	var pool: Array = TEMPLATES.filter(func(t): return t.tier == difficulty_tier)
	if pool.size() < 2:
		pool += TEMPLATES.filter(func(t): return t.tier == difficulty_tier - 1)
	if last_archetype != -1:
		var varied: Array = pool.filter(func(t): return t.archetype != last_archetype)
		if not varied.is_empty():
			pool = varied
	if pool.is_empty():
		return {}
	return pool.pick_random()
