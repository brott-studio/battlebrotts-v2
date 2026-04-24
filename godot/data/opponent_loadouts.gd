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

# Template schema (§3.1 + S21.1 additions):
#   id, name, archetype, tier, chassis, weapons, armor, modules, stance,
#   unlock_league (S21.1), behavior_cards (S21.1; data-only, engine-ignored).
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
		"unlock_league": "silver",
		"behavior_cards": [],
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
		"unlock_league": "silver",
		"behavior_cards": [],
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
		"unlock_league": "silver",
		"behavior_cards": [],
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
		"unlock_league": "bronze",
		"behavior_cards": [],
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
		"unlock_league": "gold",
		"behavior_cards": [],
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
		"unlock_league": "scrapyard",
		"behavior_cards": [],
	},
	# ── S21.1 Bronze content drop (Gizmo spec §4) ───────────────────────────────
	{
		"id": "tank_rustwall",
		"name": "Rustwall",
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
		"name": "Zap",
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
		"name": "Scrapper",
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
		"name": "Clanker",
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
		"name": "Static",
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
		"name": "Prowler",
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
		"name": "Bulwark",
		"archetype": Archetype.TANK,
		"tier": 3,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.FLAK_CANNON],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.REPAIR_NANITES, ModuleData.ModuleType.SENSOR_ARRAY],
		"stance": 1,  # Defensive
		"unlock_league": "silver",
		# weight: 12 (Shotgun) + 13 (Flak) + 8 (Reactive) + 7 (Repair) + 4 (Sensor) = 44 <= 55 (Brawler)
		# S22.2b: removed Shield Projector (broke Shield+Reactive+Defensive triangle); added Sensor Array.
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 3},
				"action": {"kind": "weapons_all_fire"},
			},
			{
				"trigger": {"kind": "enemy_hp_below_pct", "value": 50},
				"action": {"kind": "pick_target", "value": "weakest"},
			},
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 6},
				"action": {"kind": "switch_stance", "value": 3},
			},
		],
	},
	{
		"id": "glass_trueshot",
		"name": "Trueshot",
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
		"name": "Harrier",
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
		"name": "Enforcer",
		"archetype": Archetype.BRUISER,
		"tier": 3,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.MINIGUN, WeaponData.WeaponType.ARC_EMITTER],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.SHIELD_PROJECTOR, ModuleData.ModuleType.OVERCLOCK],
		"stance": 1,  # Defensive
		"unlock_league": "silver",
		# weight: 10 (Minigun) + 11 (Arc) + 8 (Reactive) + 10 (Shield) + 5 (Overclock) = 44 <= 55 (Brawler)
		# S22.2b: Plating→Reactive Mesh; stance Aggressive→Defensive. Patient pressure > charge-into-killbox.
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
		"name": "Disruptor",
		"archetype": Archetype.CONTROLLER,
		"tier": 4,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.ARC_EMITTER, WeaponData.WeaponType.FLAK_CANNON],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.OVERCLOCK, ModuleData.ModuleType.SENSOR_ARRAY],
		"stance": 1,  # Defensive
		"unlock_league": "silver",
		# weight: 11 (Arc) + 13 (Flak) + 8 (Reactive) + 5 (Overclock) + 4 (Sensor) = 41 <= 55 (Brawler)
		# S22.2b: Shield Projector→Overclock; burst-DPS controller profile replaces absorb-wall.
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
				"trigger": {"kind": "self_energy_above_pct", "value": 70},
				"action": {"kind": "use_gadget", "value": ModuleData.ModuleType.OVERCLOCK},
			},
			{
				"trigger": {"kind": "enemy_using_gadget"},
				"action": {"kind": "pick_target", "value": "same"},
			},
		],
	},
	{
		"id": "tank_aegis",
		"name": "Aegis",
		"archetype": Archetype.TANK,
		"tier": 4,
		"chassis": ChassisData.ChassisType.BRAWLER,
		"weapons": [WeaponData.WeaponType.RAILGUN, WeaponData.WeaponType.MINIGUN],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.SHIELD_PROJECTOR, ModuleData.ModuleType.SENSOR_ARRAY],
		"stance": 1,  # Defensive
		"unlock_league": "silver",
		# weight: 15 (Railgun) + 10 (Minigun) + 8 (Reactive) + 10 (Shield) + 4 (Sensor) = 47 <= 55 (Brawler)
		# S22.2b: Repair Nanites→Sensor Array; keeps Shield identity but loses dual-sustain stack.
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
				"trigger": {"kind": "enemy_beyond_tiles", "value": 6},
				"action": {"kind": "pick_target", "value": "weakest"},
			},
		],
	},
	{
		"id": "glass_chrono",
		"name": "Chrono",
		"archetype": Archetype.GLASS_CANNON,
		"tier": 4,
		"chassis": ChassisData.ChassisType.SCOUT,
		"weapons": [WeaponData.WeaponType.RAILGUN],
		"armor": ArmorData.ArmorType.REACTIVE_MESH,
		"modules": [ModuleData.ModuleType.SENSOR_ARRAY],
		"stance": 3,  # Ambush
		"unlock_league": "silver",
		# weight: 15 (Railgun) + 8 (Reactive) + 4 (Sensor) = 27 <= 30 (Scout)
		# S22.2b: None→Reactive Mesh; dropped Overclock to fit cap. One-module Scout is loadout-legal.
		# Ambush+Railgun sniper identity preserved; Reactive opens survival window vs Minigun+Shotgun burst.
		"behavior_cards": [
			{
				"trigger": {"kind": "enemy_beyond_tiles", "value": 7},
				"action": {"kind": "pick_target", "value": "strongest"},
			},
			{
				"trigger": {"kind": "enemy_within_tiles", "value": 4},
				"action": {"kind": "switch_stance", "value": 2},
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
