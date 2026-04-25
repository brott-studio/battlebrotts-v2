## Run state — tracks player loadout and run progress for the roguelike loop
## S25.1: New class replacing league-era GameState for run-scoped data.
class_name RunState
extends RefCounted

## Current battle index (0-indexed; increments after each battle)
var current_battle_index: int = 0

## Retry count remaining (3 per run, decrements on loss)
var retry_count: int = 3

## Battles won this run
var battles_won: int = 0

## Current loadout
var equipped_chassis: int = 0   # ChassisData.ChassisType value
var equipped_weapons: Array[int] = []
var equipped_armor: int = 0     # ArmorData.ArmorType.NONE = 0
var equipped_modules: Array[int] = []

## Last encounter archetype (S13.9 pattern; -1 = unset/fresh run)
var _last_encounter_archetype: int = -1

## Farthest threat name seen this run (for BROTT DOWN screen, S25.8)
var _farthest_threat_name: String = ""

## Best kill name this run (for RUN COMPLETE screen, S25.8)
var _best_kill_name: String = ""

## S25.5: Current encounter context (set on ARENA entry; read on retry).
var current_encounter: Dictionary = {"archetype_id": "", "tier": 0, "arena_seed": 0}

## S25.5: Fired when any run state is mutated (equipment added, battle advanced, retry used).
signal run_state_changed

## RNG seed for deterministic behavior (0 = time-based at runtime)
var seed: int = 0

func _init(chassis_type: int = 0, rng_seed: int = 0) -> void:
	equipped_chassis = chassis_type
	equipped_weapons = []
	equipped_armor = 0   # ArmorType.NONE — reward pick fills this in Arc F later
	equipped_modules = []
	seed = rng_seed
	retry_count = 3
	current_battle_index = 0
	battles_won = 0
	_last_encounter_archetype = -1
	_farthest_threat_name = ""
	_best_kill_name = ""

## S25.5: Set the current encounter context (called before entering ARENA).
func set_encounter(archetype_id: String, tier: int, arena_seed: int) -> void:
	current_encounter = {"archetype_id": archetype_id, "tier": tier, "arena_seed": arena_seed}

## S25.5: Add an item to the loadout. Returns false if already equipped (no-op).
## category: "weapon" | "armor" | "module"
func add_item(category: String, type: int) -> bool:
	match category:
		"weapon":
			if type in equipped_weapons:
				return false
			equipped_weapons.append(type)
		"armor":
			if equipped_armor == type:
				return false
			equipped_armor = type
		"module":
			if type in equipped_modules:
				return false
			equipped_modules.append(type)
		_:
			return false
	run_state_changed.emit()
	return true

## S25.5: Advance to the next battle (increments index, emits signal).
func advance_battle_index() -> void:
	current_battle_index += 1
	battles_won += 1
	run_state_changed.emit()

## S25.5: Use a retry (decrements count, emits signal).
func use_retry() -> void:
	retry_count = max(0, retry_count - 1)
	run_state_changed.emit()

## Build a BrottState from the current run loadout.
## Does NOT reference GameState — RunState is the sole source of truth.
func build_player_brott() -> BrottState:
	var b := BrottState.new()
	b.team = 0
	b.bot_name = "Player Bot"
	b.chassis_type = equipped_chassis
	for wt in equipped_weapons:
		b.weapon_types.append(wt)
	b.armor_type = equipped_armor
	for mt in equipped_modules:
		b.module_types.append(mt)
	b.stance = 0
	b.setup()
	return b
