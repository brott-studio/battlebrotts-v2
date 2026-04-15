## BrottBrain — behavior card system for autonomous Brott decision-making
## Cards are evaluated top-to-bottom each tick; first match fires.
class_name BrottBrain
extends RefCounted

## Trigger types — the "WHEN" part of a behavior card
enum Trigger {
	WHEN_IM_HURT,          # My HP below threshold (0.1–0.9)
	WHEN_IM_HEALTHY,       # My HP above threshold
	WHEN_LOW_ENERGY,       # My energy below threshold
	WHEN_CHARGED_UP,       # My energy above threshold
	WHEN_THEYRE_HURT,      # Enemy HP below threshold
	WHEN_THEYRE_CLOSE,     # Enemy within distance (tiles)
	WHEN_THEYRE_FAR,       # Enemy beyond distance (tiles)
	WHEN_THEYRE_IN_COVER,  # Enemy behind cover (not implemented yet, always false)
	WHEN_GADGET_READY,     # Specific module off cooldown
	WHEN_CLOCK_SAYS,       # Match time exceeds threshold (seconds)
}

## Action types — the "DO" part of a behavior card
enum Action {
	SWITCH_STANCE,   # Change to named stance (0-3)
	USE_GADGET,      # Activate a specific module
	PICK_TARGET,     # Change target priority: "nearest", "weakest", "biggest_threat"
	WEAPONS,         # Set weapon mode: "all_fire", "conserve", "hold_fire"
	GET_TO_COVER,    # Override movement: go to cover (not fully implemented)
	HOLD_CENTER,     # Override movement: go to arena center
}

## A single behavior card: one trigger + one action
class BehaviorCard extends RefCounted:
	var trigger: int = 0  # Trigger enum
	var trigger_param: Variant = null  # threshold (float), distance (int), module name (String), seconds (int)
	var action: int = 0  # Action enum
	var action_param: Variant = null  # stance (int), module name (String), target mode (String), weapon mode (String)
	
	func _init(t: int = 0, t_param: Variant = null, a: int = 0, a_param: Variant = null) -> void:
		trigger = t
		trigger_param = t_param
		action = a
		action_param = a_param

const MAX_CARDS := 8

## The card list, evaluated top to bottom
var cards: Array = []  # Array of BehaviorCard

## Default stance when no cards fire
var default_stance: int = 0  # 0=aggressive, 1=defensive, 2=kiting, 3=ambush

## Weapon firing mode: "all_fire", "conserve", "hold_fire"
var weapon_mode: String = "all_fire"

## Target priority: "nearest", "weakest", "biggest_threat"
var target_priority: String = "nearest"

## Movement override: "", "cover", "center"
var movement_override: String = ""

func add_card(card: BehaviorCard) -> bool:
	if cards.size() >= MAX_CARDS:
		return false
	cards.append(card)
	return true

func clear_cards() -> void:
	cards.clear()

## Evaluate cards against current state. Returns true if a card fired.
func evaluate(brott: RefCounted, enemy: RefCounted, match_time_sec: float) -> bool:
	movement_override = ""  # Reset each tick
	
	for card in cards:
		if _check_trigger(card, brott, enemy, match_time_sec):
			_execute_action(card, brott)
			return true
	return false

func _check_trigger(card: BehaviorCard, brott: RefCounted, enemy: RefCounted, match_time_sec: float) -> bool:
	var param: Variant = card.trigger_param
	match card.trigger:
		Trigger.WHEN_IM_HURT:
			return brott.hp / float(brott.max_hp) < float(param)
		Trigger.WHEN_IM_HEALTHY:
			return brott.hp / float(brott.max_hp) > float(param)
		Trigger.WHEN_LOW_ENERGY:
			return brott.energy / 100.0 < float(param)
		Trigger.WHEN_CHARGED_UP:
			return brott.energy / 100.0 > float(param)
		Trigger.WHEN_THEYRE_HURT:
			if enemy == null or not enemy.alive:
				return false
			return enemy.hp / float(enemy.max_hp) < float(param)
		Trigger.WHEN_THEYRE_CLOSE:
			if enemy == null or not enemy.alive:
				return false
			var dist_tiles: float = brott.position.distance_to(enemy.position) / 32.0
			return dist_tiles <= float(param)
		Trigger.WHEN_THEYRE_FAR:
			if enemy == null or not enemy.alive:
				return false
			var dist_tiles: float = brott.position.distance_to(enemy.position) / 32.0
			return dist_tiles >= float(param)
		Trigger.WHEN_THEYRE_IN_COVER:
			return false  # Cover system not implemented yet
		Trigger.WHEN_GADGET_READY:
			var mod_name: String = str(param)
			for i in range(brott.module_types.size()):
				var mdata: Dictionary = ModuleData.get_module(brott.module_types[i])
				if mdata["name"] == mod_name and brott.module_cooldowns[i] <= 0 and brott.module_active_timers[i] <= 0:
					return true
			return false
		Trigger.WHEN_CLOCK_SAYS:
			return match_time_sec >= float(param)
	return false

func _execute_action(card: BehaviorCard, brott: RefCounted) -> void:
	match card.action:
		Action.SWITCH_STANCE:
			brott.stance = int(card.action_param)
		Action.USE_GADGET:
			# Store the module name to activate — combat_sim will handle it
			brott._pending_gadget = str(card.action_param)
		Action.PICK_TARGET:
			target_priority = str(card.action_param)
		Action.WEAPONS:
			weapon_mode = str(card.action_param)
		Action.GET_TO_COVER:
			movement_override = "cover"
		Action.HOLD_CENTER:
			movement_override = "center"

## ===== SMART DEFAULTS =====
## Pre-built BrottBrains that work out of the box for each chassis

static func default_for_chassis(chassis_type: int) -> BrottBrain:
	var brain := BrottBrain.new()
	match chassis_type:
		0:  # Scout — kiting, flee when hurt
			brain.default_stance = 2  # Kiting
			brain.add_card(BehaviorCard.new(
				Trigger.WHEN_IM_HURT, 0.3,
				Action.SWITCH_STANCE, 1  # Defensive
			))
			brain.add_card(BehaviorCard.new(
				Trigger.WHEN_THEYRE_HURT, 0.3,
				Action.SWITCH_STANCE, 0  # Aggressive — go for the kill
			))
		1:  # Brawler — aggressive, switch to defensive when low
			brain.default_stance = 0  # Aggressive
			brain.add_card(BehaviorCard.new(
				Trigger.WHEN_IM_HURT, 0.4,
				Action.SWITCH_STANCE, 1  # Defensive
			))
			brain.add_card(BehaviorCard.new(
				Trigger.WHEN_IM_HEALTHY, 0.7,
				Action.SWITCH_STANCE, 0  # Aggressive
			))
		2:  # Fortress — aggressive, hold center
			brain.default_stance = 0  # Aggressive
			brain.add_card(BehaviorCard.new(
				Trigger.WHEN_THEYRE_FAR, 8,
				Action.HOLD_CENTER, null
			))
	return brain
