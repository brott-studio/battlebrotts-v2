## Opponent loadout templates + variety-preserving picker.
##
## S13.9 — initial 6 templates + picker + tier hooks (Scrapyard populated; Bronze hooks only).
## S21.1 — Bronze league populated (5-opponent curve, tier-2 openers → tier-3 closers)
##          • 6 new Bronze-legal templates (4 tier-2 + 2 tier-3); existing `bruiser_crusher`
##            remains Bronze-legal → active Bronze pool = 7 templates.
##          • Tier mapping `difficulty_for("bronze", i)` = [2,2,2,3,3].
##          • Schema adds `unlock_league` (scrapyard | bronze | silver | gold | platinum)
##            + `behavior_cards` (data-only; engine wiring tracked as carry-forward).
##          • Picker takes optional `current_league`; when non-empty, filters out
##            templates whose `unlock_league` exceeds the league rank, so Bronze
##            players never face Silver+ gear.
##
## Spec refs: docs/design/sprint13.9-fortress-loadout-pass.md §3, §4;
##            memory/2026-04-23-s21.1-gizmo-bronze-loadout-spec.md §1–§5;
##            memory/2026-04-23-s21.1-ett-sprint-plan.md §1.1–§1.3.
class_name OpponentLoadouts
extends RefCounted

enum Archetype { TANK, GLASS_CANNON, SKIRMISHER, BRUISER, CONTROLLER }

## League rank for unlock_league gating (S21.1). Higher rank = later league.
## Unknown league strings passed via current_league → skip the league filter
## (treated as "no cap") by the picker for backward compatibility.
const LEAGUE_RANK: Dictionary = {
	"scrapyard": 0,
	"bronze": 1,
	"silver": 2,
	"gold": 3,
	"platinum": 4,
}

## CUT: Arc G — league-era opponent templates. Replaced by ARCHETYPE_TEMPLATES for roguelike.
## Retained for save-compat and batch test baseline. Do not delete before Arc G migration.
# Template schema (§3.1 + S21.1 additions):
#   id, name, archetype, tier, chassis, weapons, armor, modules, stance,
#   unlock_league (S21.1), behavior_cards (S21.1; data-only, engine-ignored).
const TEMPLATES: Array[Dictionary] = [
	{
		"id": "tank_ironclad",
		"name": "Office Manager Brott",
		"archetype": Archetype.TANK,
		"tier": 2,
		"chassis": ChassisData.ChassisType.FORTRESS,
		"weapons": [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.FLAK_CANNON],
		"armor": ArmorData.ArmorType.ABLATIVE_SHELL,
		"modules": [ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 1,
		"unlock_league": "silver",
		"behavior_cards": [],
	},
	{
		"id": "glass_sniper",
		"name": "Brott from IT",
		"archetype": Archetype.GLASS_CANNON,
		"tier": 2,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.RAILGUN, WeaponData.WeaponType.PLASMA_CUTTER],
		"armor": ArmorData.ArmorType.NONE,
		"modules": [ModuleData.ModuleType.OVERCLOCK, ModuleData.ModuleType.SENSOR_ARRAY, ModuleData.ModuleType.AFTERBURNER],
		"stance": 2,
		"unlock_league": "silver",
		"behavior_cards": [],
	},
	{
		"id": "skirmish_wasp",
		"name": "Junior Associate Brott",
		"archetype": Archetype.SKIRMISHER,
		"tier": 1,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.FLAK_CANNON, WeaponData.WeaponType.PLASMA_CUTTER],
		"armor": ArmorData.ArmorType.PLATING,
		"modules": [ModuleData.ModuleType.AFTERBURNER, ModuleData.ModuleType.SENSOR_ARRAY, ModuleData.ModuleType.OVERCLOCK],
		"stance": 2,
		"unlock_league": "silver",
		"behavior_cards": [],
	},
	{
		"id": "bruiser_crusher",
		"name": "District Sales Manager Brott",
		"archetype": Archetype.BRUISER,
		"tier": 2,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.MINIGUN],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.OVERCLOCK, ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 0,
		"unlock_league": "bronze",
		"behavior_cards": [],
	},
	{
		"id": "controller_jammer",
		"name": "VP of IT Security Brott",
		"archetype": Archetype.CONTROLLER,
		"tier": 3,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.ARC_EMITTER, WeaponData.WeaponType.MISSILE_POD],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.EMP_CHARGE, ModuleData.ModuleType.SHIELD_PROJECTOR],
		"stance": 1,
		"unlock_league": "gold",
		"behavior_cards": [],
	},
	{
		"id": "tank_tincan",
		"name": "Intern Brott",
		"archetype": Archetype.TANK,
		"tier": 1,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.PLASMA_CUTTER],
		"armor": ArmorData.ArmorType.PLATING,
		"modules": [],
		"stance": 1,
		"unlock_league": "scrapyard",
		"behavior_cards": [],
	},
	# ── S21.1 Bronze content drop (Gizmo spec §4) ───────────────────────────────
	{
		"id": "tank_rustwall",
		"name": "Senior Account Manager Brott",
		"archetype": Archetype.TANK,
		"tier": 2,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.MINIGUN],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 0,
		"unlock_league": "bronze",
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 3},
				"action": {"kind": "weapons_all_fire"},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 30},
				"action": {"kind": "switch_stance", "value": 1},
			},
		],
	},
	{
		"id": "glass_zap",
		"name": "Brott from Accounting",
		"archetype": Archetype.GLASS_CANNON,
		"tier": 2,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.ARC_EMITTER],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.OVERCLOCK],
		"stance": 2,
		"unlock_league": "bronze",
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 5},
				"action": {"kind": "switch_stance", "value": 0},
			},
			{
				"trigger": {"kind": "self_energy_above_pct", "value": 70},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.OVERCLOCK},
			},
		],
	},
	{
		"id": "skirmish_scrapper",
		"name": "Temp Brott",
		"archetype": Archetype.SKIRMISHER,
		"tier": 2,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.SHOTGUN],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.OVERCLOCK],
		"stance": 2,
		"unlock_league": "bronze",
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 3},
				"action": {"kind": "weapons_all_fire"},
			},
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 5},
				"action": {"kind": "switch_stance", "value": 0},
			},
		],
	},
	{
		"id": "bruiser_clanker",
		"name": "Brott from Compliance",
		"archetype": Archetype.BRUISER,
		"tier": 2,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.ARC_EMITTER, WeaponData.WeaponType.SHOTGUN],
		"armor": ArmorData.ArmorType.PLATING,
		"modules": [ModuleData.ModuleType.OVERCLOCK],
		"stance": 0,
		"unlock_league": "bronze",
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 2},
				"action": {"kind": "weapons_all_fire"},
			},
			{
				"trigger": {"kind": "enemy_hp_below_pct", "value": 40},
				"action": {"kind": "pick_target", "value": "weakest"},
			},
		],
	},
	{
		"id": "control_static",
		"name": "Director of Operations Brott",
		"archetype": Archetype.CONTROLLER,
		"tier": 3,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.ARC_EMITTER, WeaponData.WeaponType.SHOTGUN],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 1,
		"unlock_league": "bronze",
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 3},
				"action": {"kind": "weapons_all_fire"},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 50},
				"action": {"kind": "switch_stance", "value": 3},
			},
		],
	},
	{
		"id": "control_prowler",
		"name": "Head of Internal Affairs Brott",
		"archetype": Archetype.CONTROLLER,
		"tier": 3,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.ARC_EMITTER],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 3,
		"unlock_league": "bronze",
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 2},
				"action": {"kind": "switch_stance", "value": 2},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 40},
				"action": {"kind": "switch_stance", "value": 1},
			},
		],
	},
	# ── S22.1 Silver content drop (Gizmo spec §4) ────────────────────────────────────
	# 7 new Silver-legal templates (4 tier-3 + 3 tier-4).
	# Archetype distribution: TANK x2, GLASS_CANNON x2, SKIRMISHER x1, BRUISER x1, CONTROLLER x1.
	# Stance distribution: Defensive x3, Kiting x2, Aggressive x1, Ambush x1.
	# All use Silver-legal items only (GDD §6.1). Module count = 2 (GDD §6.2 "full loadouts").
	# behavior_cards: data-only; engine ignores until #243 wiring (S21.1 §7 pattern).
	{
		"id": "tank_bulwark",
		"name": "VP of Infrastructure Brott",
		"archetype": Archetype.TANK,
		"tier": 3,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.FLAK_CANNON],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.SHIELD_PROJECTOR, ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 1,  # Defensive
		"unlock_league": "silver",
		# weight: 12 (Shotgun) + 13 (Flak) + 8 (Reactive) + 14 (Shield) + 7 (Repair) = 54 <= 55 (Brawler)
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 3},
				"action": {"kind": "weapons_all_fire"},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 50},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.SHIELD_PROJECTOR},
			},
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 6},
				"action": {"kind": "switch_stance", "value": 3},
			},
		],
	},
	{
		"id": "glass_trueshot",
		"name": "Senior Analyst Brott",
		"archetype": Archetype.GLASS_CANNON,
		"tier": 3,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.RAILGUN],
		"armor": ArmorData.ArmorType.NONE,
		"modules": [ModuleData.ModuleType.SENSOR_ARRAY, ModuleData.ModuleType.OVERCLOCK],
		"stance": 2,  # Kiting
		"unlock_league": "silver",
		# weight: 15 (Railgun) + 0 (None) + 4 (Sensor) + 5 (Overclock) = 24 <= 30 (Scout)
		# Note: was REACTIVE_MESH (8 kg) — exceeded 30 kg cap; swapped to NONE (glass cannon identity)
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 6},
				"action": {"kind": "pick_target", "value": "weakest"},
			},
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 3},
				"action": {"kind": "switch_stance", "value": 2},
			},
			{
				"trigger": {"kind": "self_energy_above_pct", "value": 70},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.OVERCLOCK},
			},
		],
	},
	{
		"id": "skirmish_harrier",
		"name": "VP of Aggressive Sales Brott",
		"archetype": Archetype.SKIRMISHER,
		"tier": 3,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.FLAK_CANNON],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.SENSOR_ARRAY, ModuleData.ModuleType.OVERCLOCK],
		"stance": 2,  # Kiting
		"unlock_league": "silver",
		# weight: 13 (Flak) + 8 (Reactive) + 4 (Sensor) + 5 (Overclock) = 30 <= 30 (Scout, exactly at cap)
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 5},
				"action": {"kind": "switch_stance", "value": 0},
			},
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 2},
				"action": {"kind": "switch_stance", "value": 2},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 40},
				"action": {"kind": "pick_target", "value": "farthest"},
			},
		],
	},
	{
		"id": "bruiser_enforcer",
		"name": "Director of HR Brott",
		"archetype": Archetype.BRUISER,
		"tier": 3,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.MINIGUN, WeaponData.WeaponType.ARC_EMITTER],
		"armor": ArmorData.ArmorType.PLATING,
		"modules": [ModuleData.ModuleType.SHIELD_PROJECTOR, ModuleData.ModuleType.OVERCLOCK],
		"stance": 0,  # Aggressive
		"unlock_league": "silver",
		# weight: 10 (Minigun) + 11 (Arc) + 15 (Plating) + 14 (Shield) + 5 (Overclock) = 55 <= 55 (Brawler)
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 4},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.OVERCLOCK},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 60},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.SHIELD_PROJECTOR},
			},
			{
				"trigger": {"kind": "enemy_hp_below_pct", "value": 40},
				"action": {"kind": "pick_target", "value": "weakest"},
			},
		],
	},
	{
		"id": "control_disruptor",
		"name": "COO Brott",
		"archetype": Archetype.CONTROLLER,
		"tier": 4,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.ARC_EMITTER, WeaponData.WeaponType.FLAK_CANNON],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.SHIELD_PROJECTOR, ModuleData.ModuleType.SENSOR_ARRAY],
		"stance": 1,  # Defensive
		"unlock_league": "silver",
		# weight: 11 (Arc) + 13 (Flak) + 8 (Reactive) + 14 (Shield) + 4 (Sensor) = 50 <= 55 (Brawler)
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 3},
				"action": {"kind": "weapons_all_fire"},
			},
			{
				# "When They're Medium (3-5 tiles)" -- substitute enemy_beyond_tiles per sec10.B note
				# (enemy_within_range schema unconfirmed; engine ignores BCards today per #243)
				"trigger": {"kind": "enemy_beyond_tiles", "value": 3},
				"action": {"kind": "weapons_fire_primary"},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 50},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.SHIELD_PROJECTOR},
			},
			{
				"trigger": {"kind": "enemy_using_gadget"},
				"action": {"kind": "pick_target", "value": "same"},
			},
		],
	},
	{
		"id": "tank_aegis",
		"name": "CFO Brott",
		"archetype": Archetype.TANK,
		"tier": 4,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.RAILGUN, WeaponData.WeaponType.MINIGUN],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.SHIELD_PROJECTOR, ModuleData.ModuleType.REPAIR_NANITES],
		"stance": 1,  # Defensive
		"unlock_league": "silver",
		# weight: 9 (Railgun) + 10 (Minigun) + 8 (Reactive) + 14 (Shield) + 7 (Repair) = 48 <= 55 (Brawler)
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 6},
				"action": {"kind": "weapons_fire_primary"},
			},
			{
				# "When They're Medium (3-6 tiles)" -- substitute enemy_beyond_tiles per sec10.B note
				"trigger": {"kind": "enemy_beyond_tiles", "value": 3},
				"action": {"kind": "weapons_fire_secondary"},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 60},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.SHIELD_PROJECTOR},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 30},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.REPAIR_NANITES},
			},
		],
	},
	{
		"id": "glass_chrono",
		"name": "Chief Strategy Brott",
		"archetype": Archetype.GLASS_CANNON,
		"tier": 4,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.RAILGUN],
		"armor": ArmorData.ArmorType.NONE,
		"modules": [ModuleData.ModuleType.SENSOR_ARRAY, ModuleData.ModuleType.OVERCLOCK],
		"stance": 3,  # Ambush
		"unlock_league": "silver",
		# weight: 15 (Railgun) + 0 (None) + 4 (Sensor) + 5 (Overclock) = 24 <= 30 (Scout)
		# Note: was REACTIVE_MESH (8 kg) — exceeded 30 kg cap; swapped to NONE (glass cannon identity)
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 7},
				"action": {"kind": "pick_target", "value": "strongest"},
			},
			{
				"trigger": {"kind": "self_energy_above_pct", "value": 80},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.OVERCLOCK},
			},
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 2},
				"action": {"kind": "switch_stance", "value": 2},
			},
			{
				"trigger": {"kind": "self_hp_below_pct", "value": 30},
				"action": {"kind": "switch_stance", "value": 1},
			},
		],
	},
]

## ─────────────────────────────────────────────────────────────────────────
## S25.4: Roguelike Encounter Archetype Pool
## IDs locked: standard_duel | small_swarm | large_swarm | miniboss_escorts |
##             counter_build_elite | glass_cannon_blitz | boss
## ─────────────────────────────────────────────────────────────────────────

## Baseline HP per tier — used to scale archetype hp_pct values.
## Tier 1: battles 1-3, Tier 2: 4-7, Tier 3: 8-11, Tier 4: 12-14, Tier 5: Boss.
static func _baseline_hp_for_tier(tier: int) -> int:
	match tier:
		1: return 80
		2: return 120
		3: return 160
		4: return 200
		_: return 240  # Boss tier

## Archetype template records. enemy_specs describe the enemy composition.
## hp_pct is relative to _baseline_hp_for_tier(tier) at generation time.
const ARCHETYPE_TEMPLATES: Array[Dictionary] = [
	{
		"id": "standard_duel",
		"display_name": "Standard Duel",
		"enemy_specs": [
			{"chassis": 0, "weapons": [4], "armor": 1, "modules": [], "hp_pct": 1.0, "count": 1}
		]
	},
	{
		"id": "small_swarm",
		"display_name": "Small Swarm",
		"enemy_specs": [
			{"chassis": 0, "weapons": [4], "armor": 0, "modules": [], "hp_pct": 0.6, "count": 3}
		]
	},
	{
		"id": "large_swarm",
		"display_name": "Large Swarm",
		"enemy_specs": [
			{"chassis": 0, "weapons": [4], "armor": 0, "modules": [], "hp_pct": 0.4, "count": 5}
		]
	},
	{
		"id": "miniboss_escorts",
		"display_name": "Mini-boss + Escorts",
		"enemy_specs": [
			{"chassis": 2, "weapons": [0, 2], "armor": 3, "modules": [2], "hp_pct": 1.5, "count": 1},
			{"chassis": 0, "weapons": [4], "armor": 0, "modules": [], "hp_pct": 0.7, "count": 2}
		]
	},
	{
		"id": "counter_build_elite",
		"display_name": "Counter-Build Elite",
		## enemy_specs populated dynamically by get_archetype_enemies() via build-read selector
		"enemy_specs": []
	},
	{
		"id": "glass_cannon_blitz",
		"display_name": "Glass-Cannon Blitz",
		"enemy_specs": [
			{"chassis": 0, "weapons": [1, 0], "armor": 0, "modules": [], "hp_pct": 0.5, "count": 2}
		]
	},
	{
		"id": "boss",
		"display_name": "CEO Brott",
		## Placeholder name — finalized in Arc H. S25.9 tunes AI.
		"enemy_specs": [
			{"chassis": 2, "weapons": [1, 0], "armor": 3, "modules": [2, 3, 5], "hp_pct": 2.0, "count": 1}
		]
	},
]

## Counter-Build Elite variant selector — reads player's RunState loadout.
## Priority: modules ≥3 → anti_module; then primary weapon.
static func _select_counter_build_variant(run_state) -> String:
	if run_state == null:
		return "anti_range"
	var modules = run_state.equipped_modules if "equipped_modules" in run_state else []
	if modules.size() >= 3:
		return "anti_module"
	var weapons = run_state.equipped_weapons if "equipped_weapons" in run_state else []
	var primary: int = weapons[0] if weapons.size() > 0 else -1
	if primary in [1, 3]:  # Railgun, Missile Pod
		return "anti_range"
	if primary in [2, 6]:  # Shotgun, Flak Cannon
		return "anti_melee"
	return "anti_range"

## Concrete counter-build elite enemy specs per variant.
static func _counter_build_specs(variant: String) -> Array[Dictionary]:
	match variant:
		"anti_range":
			## Reactive Mesh + Rush build to close range quickly
			return [{"chassis": 1, "weapons": [2, 0], "armor": 2, "modules": [4], "hp_pct": 1.3, "count": 1}]
		"anti_melee":
			## Railgun kiter to punish slow Shotgun users
			return [{"chassis": 0, "weapons": [1], "armor": 1, "modules": [4, 3], "hp_pct": 1.3, "count": 1}]
		"anti_module":
			## EMP Charge + aggressive to shutdown active modules
			return [{"chassis": 1, "weapons": [0, 4], "armor": 2, "modules": [5, 0], "hp_pct": 1.3, "count": 1}]
		_:
			return [{"chassis": 1, "weapons": [0], "armor": 1, "modules": [], "hp_pct": 1.3, "count": 1}]

## ─────────────────────────────────────────────────────────────────────────
## S25.6: Encounter Generator — pre-rolled schedule, weighted draw,
##         no-repeat rule, guarantee seeds, boss-lock at slot 15.
## ─────────────────────────────────────────────────────────────────────────

## S25.6: Maps battle_index (0-indexed) to tier (1-5) for the roguelike run.
## T1=idx 0-2, T2=idx 3-6, T3=idx 7-10, T4=idx 11-13, Boss=idx 14.
## NOTE (deviation): named `difficulty_for_battle` instead of `difficulty_for`
## to avoid colliding with the existing league-era 2-arg
## `difficulty_for(league: String, index: int)` (still used by opponent_data.gd
## for save-compat / batch test baseline).
static func difficulty_for_battle(battle_index: int) -> int:
	if battle_index >= 14: return 5   # Boss tier
	if battle_index >= 11: return 4   # T4
	if battle_index >= 7:  return 3   # T3
	if battle_index >= 3:  return 2   # T2
	return 1                           # T1

## S25.6: Large Swarm hp_pct override by tier (difficulty decoupled from shape).
const LARGE_SWARM_HP_BY_TIER: Dictionary = {1: 0.2, 2: 0.4, 3: 0.7, 4: 0.9}

## S25.6: Returns resolved enemy spawn specs for the given archetype, battle index, and run state.
## Wraps get_archetype_enemies() with tier-adaptive HP for large_swarm.
static func compose_encounter(archetype_id: String, battle_index: int, run_state) -> Array[Dictionary]:
	var tier := difficulty_for_battle(battle_index)

	## Large Swarm: hp_pct overridden by tier (gate 6)
	if archetype_id == "large_swarm":
		var hp_pct: float = LARGE_SWARM_HP_BY_TIER.get(min(tier, 4), 0.9)
		var base_hp: int = _baseline_hp_for_tier(tier)
		## Build specs directly (don't rely on template's fixed hp_pct)
		var count := 5 if tier <= 2 else 6
		var hp: int = max(1, int(base_hp * hp_pct))
		var result: Array[Dictionary] = []
		for _i in range(count):
			result.append({
				"chassis": 0,
				"weapons": [4],  ## Plasma Cutter
				"armor": 0,
				"modules": [],
				"hp": hp,
			})
		return result

	## All other archetypes use get_archetype_enemies()
	return get_archetype_enemies(archetype_id, tier, run_state)

## S25.6: Probability weights per tier. Weights are relative (don't need to sum to 100).
const ARCHETYPE_WEIGHTS_BY_TIER: Dictionary = {
	1: {"standard_duel": 40, "small_swarm": 30, "large_swarm": 15, "glass_cannon_blitz": 15},
	2: {"standard_duel": 30, "small_swarm": 30, "large_swarm": 20, "counter_build_elite": 10, "glass_cannon_blitz": 10},
	3: {"standard_duel": 20, "small_swarm": 20, "large_swarm": 20, "miniboss_escorts": 20, "counter_build_elite": 15, "glass_cannon_blitz": 5},
	4: {"standard_duel": 15, "small_swarm": 10, "large_swarm": 15, "miniboss_escorts": 25, "counter_build_elite": 25, "glass_cannon_blitz": 10},
}

## S25.6: Pick a weighted-random archetype from a tier, excluding last_archetype.
## rng: optional seeded RNG for test determinism; uses global randi() if null.
static func _weighted_draw(tier: int, last_archetype: String, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = ARCHETYPE_WEIGHTS_BY_TIER.get(min(tier, 4), ARCHETYPE_WEIGHTS_BY_TIER[4])

	## Attempt up to 3 draws with no-repeat; fall back to forced pick
	for attempt in range(4):
		if attempt == 3:
			## Forced fallback: pick highest-weight non-repeat
			var best := ""
			var best_w := -1
			for k in weights:
				if k != last_archetype and weights[k] > best_w:
					best_w = weights[k]
					best = k
			return best if best != "" else weights.keys()[0]

		## Weighted random draw
		var total := 0
		for w in weights.values():
			total += w
		var roll := (rng.randi() % total) if rng else (randi() % total)
		var cumulative := 0
		var drawn := ""
		for k in weights:
			cumulative += weights[k]
			if roll < cumulative:
				drawn = k
				break

		if drawn != last_archetype:
			return drawn
		## repeat — try again

	return weights.keys()[0]  ## safety fallback

## S25.6: Full encounter generator.
## Returns the archetype ID for a given battle slot.
## Run schedule is pre-generated on first call and cached on run_state.encounter_schedule.
static func archetype_for(battle_index: int, run_state, rng: RandomNumberGenerator = null) -> String:
	## Boss override FIRST — deterministic regardless of rng state (gate 3)
	if battle_index >= 14:
		return "boss"

	## Use cached schedule if available
	if run_state != null and "encounter_schedule" in run_state and \
		run_state.encounter_schedule is Array and \
		run_state.encounter_schedule.size() > battle_index:
		return run_state.encounter_schedule[battle_index]

	## Generate full 15-slot schedule and cache it
	var schedule := _generate_run_schedule(run_state, rng if rng != null else RandomNumberGenerator.new())
	if run_state != null:
		run_state.encounter_schedule = schedule

	if battle_index < schedule.size():
		return schedule[battle_index]
	return "standard_duel"  ## safety fallback

## S25.6: Generate a full 15-slot encounter schedule for a run.
static func _generate_run_schedule(_run_state, rng: RandomNumberGenerator) -> Array[String]:
	## Step 1: Generate 15 slots with weighted draw + no-repeat
	var schedule: Array[String] = []
	schedule.resize(15)
	schedule[14] = "boss"  ## Battle 15 always boss

	for idx in range(14):
		var tier := difficulty_for_battle(idx)
		var last := schedule[idx - 1] if idx > 0 else ""
		schedule[idx] = _weighted_draw(tier, last, rng)

	## Step 2: Apply guarantee seeds (slots 5, 9, 12 → indices 4, 8, 11)
	var guarantee_map: Dictionary = {4: "small_swarm", 8: "counter_build_elite", 11: "miniboss_escorts"}
	for base_idx in guarantee_map:
		var target: String = guarantee_map[base_idx]
		var seeded_idx: int = base_idx
		## Slide forward if repeat conflict
		for _slide in range(3):
			var prev := schedule[seeded_idx - 1] if seeded_idx > 0 else ""
			var next_arc := schedule[seeded_idx + 1] if seeded_idx < 13 else ""
			if schedule[seeded_idx] == target:
				break  ## already this archetype, no conflict possible with itself
			if prev != target and next_arc != target:
				schedule[seeded_idx] = target
				break
			seeded_idx += 1
			if seeded_idx >= 14:
				seeded_idx = base_idx  ## wrap back and give up sliding
				break

	## Step 3: Post-generation sweep — ensure each guaranteed archetype appears ≥1 time
	var required := ["small_swarm", "counter_build_elite", "miniboss_escorts"]
	for req in required:
		var found := false
		for s in schedule:
			if s == req:
				found = true
				break
		if not found:
			## Find a valid slot to overwrite (latest slot of matching tier, no consecutive repeat)
			for idx in range(13, -1, -1):
				var tier := difficulty_for_battle(idx)
				## Check if this archetype is valid for this tier
				var tier_weights: Dictionary = ARCHETYPE_WEIGHTS_BY_TIER.get(min(tier, 4), {})
				if req not in tier_weights:
					continue
				## Check no consecutive repeat
				var prev := schedule[idx - 1] if idx > 0 else ""
				var nxt := schedule[idx + 1] if idx < 13 else "boss"
				if prev != req and nxt != req:
					schedule[idx] = req
					break

	return schedule

## Returns resolved enemy spawn specs for the given archetype + tier + player state.
## Each returned dict: {chassis, weapons, armor, modules, hp} (hp is absolute, not pct).
static func get_archetype_enemies(archetype_id: String, tier: int, run_state) -> Array[Dictionary]:
	var template: Dictionary = {}
	for t in ARCHETYPE_TEMPLATES:
		if t["id"] == archetype_id:
			template = t
			break
	if template.is_empty():
		## Unknown archetype — fall back to standard_duel
		return get_archetype_enemies("standard_duel", tier, run_state)
	
	var base_hp: int = _baseline_hp_for_tier(tier)
	var specs: Array[Dictionary]
	
	if archetype_id == "counter_build_elite":
		var variant := _select_counter_build_variant(run_state)
		specs = _counter_build_specs(variant)
	else:
		specs = template["enemy_specs"].duplicate(true)
	
	## Expand count and compute absolute HP
	var result: Array[Dictionary] = []
	for spec in specs:
		var count: int = spec.get("count", 1)
		var hp: int = max(1, int(base_hp * float(spec["hp_pct"])))
		for _i in range(count):
			result.append({
				"chassis": spec["chassis"],
				"weapons": spec["weapons"].duplicate(),
				"armor": spec["armor"],
				"modules": spec["modules"].duplicate(),
				"hp": hp,
			})
	return result

## §4.1 — maps (league, index) to a difficulty tier.
## S21.1: Bronze expanded to 5-slot curve [2,2,2,3,3] — tier-2 openers, tier-3 closers.
## S22.1: Silver populated with [3,3,3,4,4] — tier-3 openers, tier-4 closers.
##        Tier-4 is introduced at Silver (Silver's "closing wall").
##        Archetype distribution: 4 TANK/GLASS_CANNON (big chassis + long range),
##        3 SKIRMISHER/BRUISER/CONTROLLER — Silver leans range+specialization
##        vs Bronze's close-range-commit lean.
static func difficulty_for(league: String, index: int) -> int:
	match league:
		"scrapyard":
			var tiers := [1, 1, 2]
			return tiers[index] if index >= 0 and index < tiers.size() else 1
		"bronze":
			var tiers := [2, 2, 2, 3, 3]
			return tiers[index] if index >= 0 and index < tiers.size() else 2
		"silver":  # S22.1: tier-3 openers, tier-4 closers; introduces tier-4
			var tiers := [3, 3, 3, 4, 4]
			return tiers[index] if index >= 0 and index < tiers.size() else 3
		_:
			return 1

## §4 — tier filter + weaker-tier fallback + variety strip + (S21.1) league gating.
##
## current_league (S21.1): when non-empty and a recognized league string, filter
## out templates whose `unlock_league` exceeds the current league's rank. The
## league filter runs *after* the tier fallback but *before* the variety strip,
## so Silver+ templates cannot leak in via either pool slot. Unknown league
## strings (or "") skip the filter entirely for backward compatibility with any
## call-site that hasn't been updated to thread league context.
##
## player_archetype_hint unused; reserved for Sprint 13.10 counter-play.
static func pick_opponent_loadout(difficulty_tier: int, current_league: String = "", last_archetype: int = -1, _player_archetype_hint: int = -1) -> Dictionary:
	var pool: Array = TEMPLATES.filter(func(t): return t.tier == difficulty_tier)
	if pool.size() < 2:
		pool += TEMPLATES.filter(func(t): return t.tier == difficulty_tier - 1)
	if current_league != "" and LEAGUE_RANK.has(current_league):
		var league_cap: int = LEAGUE_RANK[current_league]
		pool = pool.filter(func(t): return LEAGUE_RANK.get(t.get("unlock_league", "scrapyard"), 0) <= league_cap)
	if last_archetype != -1:
		var varied: Array = pool.filter(func(t): return t.archetype != last_archetype)
		if varied.is_empty():
			# S21.1: when variety would empty the pool (e.g. Bronze tier-3
			# is all-CONTROLLER), widen to tier-(N-1) templates respecting
			# the league cap, so the variety invariant holds without needing
			# ≥2 archetypes per tier band. Falls through to the original
			# "keep pool intact" only when no wider tier yields a different
			# archetype either.
			var wider: Array = TEMPLATES.filter(func(t): return t.tier == difficulty_tier - 1 and t.archetype != last_archetype)
			if current_league != "" and LEAGUE_RANK.has(current_league):
				var league_cap2: int = LEAGUE_RANK[current_league]
				wider = wider.filter(func(t): return LEAGUE_RANK.get(t.get("unlock_league", "scrapyard"), 0) <= league_cap2)
			if not wider.is_empty():
				pool = wider
		else:
			pool = varied
	if pool.is_empty():
		return {}
	return pool.pick_random()
