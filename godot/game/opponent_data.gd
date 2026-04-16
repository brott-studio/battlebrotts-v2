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
					"stance": 1,  # Defensive
					"brain": null,
				},
				{
					"id": "scrapyard_2",
					"name": "Crusher",
					"chassis": ChassisData.ChassisType.BRAWLER,
					"weapons": [WeaponData.WeaponType.PLASMA_CUTTER, WeaponData.WeaponType.SHOTGUN],
					"armor": ArmorData.ArmorType.NONE,
					"modules": [],
					"stance": 2,  # Kiting
					"brain": null,
				},
			]
		_:
			return []

## S13.9: Uses OpponentLoadouts picker (archetype templates + variety).
## Legacy get_opponent() retained for UI preview / back-compat reads.
## game_state is optional; when provided, variety tracking via
## _last_opponent_archetype prevents back-to-back archetype repeats.
static func build_opponent_brott(league: String, index: int, game_state: GameState = null) -> BrottState:
	var tier: int = OpponentLoadouts.difficulty_for(league, index)
	var last_arch: int = -1
	if game_state != null:
		last_arch = game_state._last_opponent_archetype
	var template: Dictionary = OpponentLoadouts.pick_opponent_loadout(tier, last_arch)
	if template.is_empty():
		push_warning("OpponentLoadouts: empty pool for tier=%d league=%s index=%d; retrying without variety" % [tier, league, index])
		template = OpponentLoadouts.pick_opponent_loadout(tier, -1)
	if template.is_empty():
		push_warning("OpponentLoadouts: still empty after variety skip for tier=%d; falling back to tier 1" % tier)
		template = OpponentLoadouts.pick_opponent_loadout(1, -1)
	if template.is_empty():
		return null

	var b := BrottState.new()
	b.team = 1
	b.bot_name = template["name"]
	b.chassis_type = template["chassis"]
	for wt in template["weapons"]:
		b.weapon_types.append(wt)
	b.armor_type = template["armor"]
	for mt in template["modules"]:
		b.module_types.append(mt)
	b.stance = template["stance"]
	b.setup()
	b.brain = BrottBrain.default_for_chassis(template["chassis"])

	if game_state != null:
		game_state._last_opponent_archetype = template["archetype"]
	return b

static func get_league_size(league: String) -> int:
	return get_league_opponents(league).size()
