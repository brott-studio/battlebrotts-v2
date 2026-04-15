## Opponent definitions for each league
class_name OpponentData
extends RefCounted

## Returns opponent config for a given league and index
static func get_opponent(league: String, index: int) -> Dictionary:
	var opponents := get_league_opponents(league)
	if index < 0 or index >= opponents.size():
		return {}
	return opponents[index]

static func get_league_opponents(league: String) -> Array:
	match league:
		"scrapyard":
			return [
				{
					"id": "scrapyard_0",
					"name": "Rusty",
					"chassis": ChassisData.ChassisType.SCOUT,
					"weapons": [WeaponData.WeaponType.PLASMA_CUTTER],
					"armor": ArmorData.ArmorType.NONE,
					"modules": [],
					"stance": 0,  # Aggressive
					"brain": null,  # No brain in scrapyard
				},
				{
					"id": "scrapyard_1",
					"name": "Tincan",
					"chassis": ChassisData.ChassisType.SCOUT,
					"weapons": [WeaponData.WeaponType.PLASMA_CUTTER],
					"armor": ArmorData.ArmorType.PLATING,
					"modules": [],
					"stance": 0,
					"brain": null,
				},
				{
					"id": "scrapyard_2",
					"name": "Crusher",
					"chassis": ChassisData.ChassisType.BRAWLER,
					"weapons": [WeaponData.WeaponType.PLASMA_CUTTER, WeaponData.WeaponType.SHOTGUN],
					"armor": ArmorData.ArmorType.NONE,
					"modules": [],
					"stance": 0,
					"brain": null,
				},
			]
		_:
			return []

static func build_opponent_brott(league: String, index: int) -> BrottState:
	var data := get_opponent(league, index)
	if data.is_empty():
		return null
	
	var b := BrottState.new()
	b.team = 1
	b.bot_name = data["name"]
	b.chassis_type = data["chassis"]
	for wt in data["weapons"]:
		b.weapon_types.append(wt)
	b.armor_type = data["armor"]
	for mt in data["modules"]:
		b.module_types.append(mt)
	b.stance = data["stance"]
	b.setup()
	
	# Use default brain if no custom one specified
	if data["brain"] == null:
		b.brain = BrottBrain.default_for_chassis(data["chassis"])
	
	return b

static func get_league_size(league: String) -> int:
	return get_league_opponents(league).size()
