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
		# S22.1 §10.A: Bronze and Silver were previously scrapyard-only in the
		# match statement, causing get_league_opponents("bronze") and
		# get_league_opponents("silver") to return [] — an unreported latent bug
		# that blocks opponent-select screen rendering for Bronze/Silver players.
		# Fix: build a 5-entry stable preview from the template pool via a
		# deterministic per-(league, index) seed. Preview may differ from the
		# actual fight draw (build_opponent_brott re-rolls) — this is display-
		# only and consistent with the existing Bronze flow. See Gizmo spec §10.A.
		# Scope: ONLY this match case + _build_preview_opponents. Do NOT touch
		# result_screen.gd, opponent_select_screen.gd, or helper-text strings
		# (#260 / Arc F).
		"bronze", "silver":
			return _build_preview_opponents(league)
		_:
			return []

## Builds a 5-entry preview opponent list for league using the template pool.
## Uses deterministic per-(league, index) seeding so the preview is stable
## across loads within a run. Actual fight draw re-rolls via build_opponent_brott.
## Size = 5 per GDD §6.1 (Bronze and Silver are both 5-opponent leagues).
static func _build_preview_opponents(league: String) -> Array:
	var out: Array = []
	var size: int = 5  # GDD §6.1: Bronze and Silver are both 5-opponent leagues
	for i in size:
		var tier: int = OpponentLoadouts.difficulty_for(league, i)
		# Deterministic seed per (league, index) — preview is stable across loads.
		# Actual fight re-rolls via build_opponent_brott; this is display-only.
		seed(hash("%s_%d" % [league, i]))
		var template: Dictionary = OpponentLoadouts.pick_opponent_loadout(tier, league, -1)
		if template.is_empty():
			continue
		out.append({
			"id": "%s_%d" % [league, i],
			"name": template["name"],
			"chassis": template["chassis"],
			"weapons": template["weapons"],
			"armor": template["armor"],
			"modules": template["modules"],
			"stance": template["stance"],
			"brain": null,
		})
	return out

## S13.9: Uses OpponentLoadouts picker (archetype templates + variety).
## Legacy get_opponent() retained for UI preview / back-compat reads.
## game_state is optional; when provided, variety tracking via
## _last_opponent_archetype prevents back-to-back archetype repeats.
static func build_opponent_brott(league: String, index: int, game_state: GameState = null) -> BrottState:
	var tier: int = OpponentLoadouts.difficulty_for(league, index)
	var last_arch: int = -1
	if game_state != null:
		last_arch = game_state._last_opponent_archetype
	# S21.1 remediation (Gizmo §6.2b / Optic D4): league filter now applies to
	# scrapyard as well as bronze+. This correctly excludes Silver+ templates
	# (tank_ironclad, glass_sniper) from scrapyard pools, aligning runtime
	# behavior with the `unlock_league` schema. Scrapyard's effective pool is
	# now tank_tincan only; the build chain falls back to tier-1 via the
	# existing empty-pool guard when scrapyard tier-2 resolves empty.
	var filter_league: String = league
	var template: Dictionary = OpponentLoadouts.pick_opponent_loadout(tier, filter_league, last_arch)
	if template.is_empty():
		push_warning("OpponentLoadouts: empty pool for tier=%d league=%s index=%d; retrying without variety" % [tier, league, index])
		template = OpponentLoadouts.pick_opponent_loadout(tier, filter_league, -1)
	if template.is_empty():
		push_warning("OpponentLoadouts: still empty after variety skip for tier=%d; falling back to tier 1" % tier)
		template = OpponentLoadouts.pick_opponent_loadout(1, filter_league, -1)
	if template.is_empty():
		return null

	var b := BrottState.new()
	b.team = 1
	b.bot_name = template["name"]
	b.chassis_type = template["chassis"]
	# S22.2c: Set league so reflect-damage scales correctly per tier.
	b.current_league = league
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
