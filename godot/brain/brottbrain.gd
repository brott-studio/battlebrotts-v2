## BrottBrain — autonomous Brott decision-making.
## S25.3: Hardcoded baseline AI replaces card-eval loop. Card definitions retained
## on disk for save-format compat (CUT: Arc G).
class_name BrottBrain
extends RefCounted

## ─────────────────────────────────────────────────────────────────────────
## CUT: Arc G — card-crafting metagame retired in Arc F roguelike pivot.
## Enums + BehaviorCard class + cards array retained for save-format compat.
## No active code path evaluates cards after S25.3.
## Do not delete without a save-format migration.
## ─────────────────────────────────────────────────────────────────────────

## Trigger types — the "WHEN" part of a behavior card
enum Trigger {
	WHEN_IM_HURT,          # My HP below threshold (0.1–0.9)
	WHEN_IM_HEALTHY,       # My HP above threshold
	WHEN_LOW_ENERGY,       # My energy below threshold
	WHEN_CHARGED_UP,       # My energy above threshold
	WHEN_THEYRE_HURT,      # Enemy HP below threshold
	WHEN_THEYRE_CLOSE,     # Enemy within distance (tiles)
	WHEN_THEYRE_FAR,       # Enemy beyond distance (tiles)
	WHEN_THEYRE_IN_COVER,  # Enemy near a pillar (within 48px)
	WHEN_GADGET_READY,     # Specific module off cooldown
	WHEN_CLOCK_SAYS,       # Match time exceeds threshold (seconds) — S14.2: hidden from tray, retained for save-compat
	WHEN_THEYRE_RUNNING,   # S14.2 Slice B: enemy velocity ≥ threshold tiles/sec AND moving away
	WHEN_I_JUST_HIT_THEM,  # S14.2 Slice B: landed hit on enemy within grace window seconds
}

## Action types — the "DO" part of a behavior card
enum Action {
	SWITCH_STANCE,   # Change to named stance (0-3)
	USE_GADGET,      # Activate a specific module
	PICK_TARGET,     # Change target priority: "nearest", "weakest", "biggest_threat"
	WEAPONS,         # Set weapon mode: "all_fire", "conserve", "hold_fire"
	GET_TO_COVER,    # Override movement: go to cover — S14.2: hidden from tray (cover pathfinding incomplete); retained for save-compat
	HOLD_CENTER,     # Override movement: go to arena center
	CHASE_TARGET,    # S14.2 Slice B: override movement — close distance on enemy at stance-max speed
	FOCUS_WEAKEST,   # S14.2 Slice B: sugar — sets target_priority="weakest" + clears pending target lock
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

## Movement override: "", "cover", "center", "chase", "move_to_override", "target_override"
var movement_override: String = ""

## S25.2: Player click-to-move / click-to-target overrides.
## -1 = no target override (target_override is index into sim.brotts).
## Vector2.INF = no move override.
var _override_target_id: int = -1
var _override_move_pos: Vector2 = Vector2.INF

## S25.3: Hysteresis state for kite decision — persists across ticks to prevent
## stance flickering at the HP threshold boundary.
var _kiting: bool = false

## S25.3: Default stance per chassis (set by default_for_chassis).
## Scout=2 (Hit&Run), Brawler=0 (Aggressive), Fortress=1 (PlayItSafe).
var _default_stance: int = 0

## S25.9: Boss AI flag. When true, _evaluate_boss() runs instead of baseline.
var is_boss: bool = false

## S25.9: Boss brain factory — returns a BrottBrain configured for IRONCLAD PRIME.
static func boss_ai() -> BrottBrain:
	var brain := BrottBrain.new()
	brain.is_boss = true
	brain._default_stance = 0  ## Aggressive — boss never defaults to kite
	return brain

## S25.4: Enemy context for multi-target priority selection (set by combat_sim each tick).
var _enemies_context: Array = []

## S25.4: Set the enemies available for targeting this tick.
func set_enemies_context(enemies: Array) -> void:
	_enemies_context = enemies

## S25.2: Set a target-override from player click. Overrides card-eval target.
## target_id is the index of the target in sim.brotts.
func set_target_override(target_id: int) -> void:
	_override_target_id = target_id
	_override_move_pos = Vector2.INF  # latest-wins: clear move override

## S25.2: Clear target override (called when target dies or player clicks floor).
func clear_target_override() -> void:
	_override_target_id = -1

## S25.2: Set a move-override from player click. Overrides card-eval movement.
func set_move_override(pos: Vector2) -> void:
	_override_move_pos = pos
	_override_target_id = -1  # latest-wins: clear target override

## S25.2: Clear move override (called when waypoint reached or player clicks enemy).
func clear_move_override() -> void:
	_override_move_pos = Vector2.INF

## S25.3: Check if a module (by name) is equipped, not on cooldown, and not active.
## Returns the slot index if ready, or -1 if not available.
func _module_ready(brott: RefCounted, mod_name: String) -> int:
	for i in range(brott.module_types.size()):
		var mdata: Dictionary = ModuleData.get_module(brott.module_types[i])
		if mdata["name"] == mod_name:
			if brott.module_cooldowns[i] <= 0 and brott.module_active_timers[i] <= 0:
				return i
	return -1

## S25.9: Boss AI rule chain for IRONCLAD PRIME.
## Priority: executioner mode (player low HP) > module auto-fire > movement.
## Boss does NOT use Afterburner flee — ever.
func _evaluate_boss(brott: RefCounted, enemy: RefCounted) -> bool:
	if enemy == null or not enemy.alive:
		movement_override = ""
		return true
	
	var boss_hp_pct: float = float(brott.hp) / float(brott.max_hp) if brott.max_hp > 0 else 1.0
	var player_hp_pct: float = float(enemy.hp) / float(enemy.max_hp) if enemy.max_hp > 0 else 1.0
	
	## Rule 1: Executioner mode — when player HP < 30%, commit to kill.
	## Movement-only: does NOT alter module priority.
	if player_hp_pct < 0.30:
		_boss_executioner_mode(brott, enemy)
	else:
		## Default boss movement: aggressive at full HP, no kiting
		brott.stance = 0
		_kiting = false
		movement_override = ""
	
	## Rule 2: Boss module priority (HP-banded, Afterburner NEVER selected).
	## EMP trigger: player has any active module right now.
	var player_has_active_module: bool = false
	for t in enemy.module_active_timers:
		if t > 0.0:
			player_has_active_module = true
			break
	
	if boss_hp_pct <= 0.40:
		## Shield Projector top priority at low HP
		if _module_ready(brott, "Shield Projector") >= 0:
			brott._pending_gadget = "Shield Projector"
			return true
		if player_has_active_module and _module_ready(brott, "EMP Charge") >= 0:
			brott._pending_gadget = "EMP Charge"
			return true
	elif boss_hp_pct <= 0.60:
		## Shield Projector > EMP
		if _module_ready(brott, "Shield Projector") >= 0:
			brott._pending_gadget = "Shield Projector"
			return true
		if player_has_active_module and _module_ready(brott, "EMP Charge") >= 0:
			brott._pending_gadget = "EMP Charge"
			return true
	else:
		## Above 60% HP: EMP on active modules, then Shield Projector
		if player_has_active_module and _module_ready(brott, "EMP Charge") >= 0:
			brott._pending_gadget = "EMP Charge"
			return true
		if _module_ready(brott, "Shield Projector") >= 0:
			brott._pending_gadget = "Shield Projector"
			return true
	## Note: Afterburner is explicitly excluded from all boss HP bands. Boss never flees.
	
	return true

## S25.9: Executioner mode — boss closes distance when player HP < 30%.
## Movement-only. Does NOT change module priority.
func _boss_executioner_mode(brott: RefCounted, enemy: RefCounted) -> void:
	brott.stance = 0  ## Aggressive
	_kiting = false   ## Override any kite state
	## Signal pursuit to combat_sim via movement_override.
	## "chase" is the existing combat_sim movement override for closing distance.
	movement_override = "chase"

func add_card(card: BehaviorCard) -> bool:
	if cards.size() >= MAX_CARDS:
		return false
	cards.append(card)
	return true

func clear_cards() -> void:
	cards.clear()

## Evaluate cards against current state. Returns true if a card fired.
func evaluate(brott: RefCounted, enemy: RefCounted, match_time_sec: float) -> bool:
	## S25.9: Boss-specific AI — runs instead of baseline when is_boss == true.
	if is_boss:
		return _evaluate_boss(brott, enemy)

	movement_override = ""  # Reset each tick
	
	## S25.2: Apply player click overrides before card evaluation.
	## These take priority over card-driven behavior. The override sets state
	## that S25.3 (baseline AI rewrite) reads to actually drive movement/targeting.
	if _override_move_pos != Vector2.INF:
		movement_override = "move_to_override"
		return true
	if _override_target_id != -1:
		movement_override = "target_override"
		return true
	
	## CUT: Arc G — card evaluation loop removed S25.3 roguelike pivot.
	## cards array + add_card/clear_cards + BehaviorCard + Trigger/Action enums
	## remain on disk for save-compat. See CUT block above enum Trigger.
	## S25.3: Hardcoded baseline AI — card-eval loop removed.
	
	## S25.4: Empty context guard — no enemies available, no-op safely.
	if _enemies_context.is_empty() and (enemy == null or not enemy.alive):
		brott.target = null
		movement_override = ""
		return true
	
	if enemy == null or not enemy.alive:
		## No live enemy — hold stance, no overrides
		movement_override = ""
		return true
	
	## S25.4: Multi-target priority selection.
	## Override short-circuits above already handled player click-to-target.
	## This cascade runs only when no active click override is set.
	var alive_enemies: Array = _enemies_context.filter(func(e): return e != null and e.alive and e.hp > 0)
	
	if alive_enemies.is_empty():
		## No live enemies in context — use passed `enemy` as fallback (1v1 compat)
		if enemy != null and enemy.alive:
			brott.target = enemy
		else:
			brott.target = null
			movement_override = ""
			return true
	else:
		## Priority cascade:
		## 1. Melee-adjacent (within 48px) — pick closest melee-range attacker
		var melee_enemies: Array = alive_enemies.filter(func(e): return brott.position.distance_to(e.position) < 48.0)
		if not melee_enemies.is_empty():
			melee_enemies.sort_custom(func(a, b_): return brott.position.distance_to(a.position) < brott.position.distance_to(b_.position))
			brott.target = melee_enemies[0]
		else:
			## 2. Nearest; tie-break equidistant by lowest HP
			var sorted_enemies: Array = alive_enemies.duplicate()
			sorted_enemies.sort_custom(func(a, b_):
				var da: float = brott.position.distance_to(a.position)
				var db: float = brott.position.distance_to(b_.position)
				if abs(da - db) < 1.0:  ## equidistant (within 1px epsilon)
					return a.hp < b_.hp  ## tie-break: lower HP wins
				return da < db  ## nearest wins
			)
			brott.target = sorted_enemies[0]
	
	var hp_pct: float = float(brott.hp) / float(brott.max_hp) if brott.max_hp > 0 else 1.0
	
	## --- Rule 1: Kite hysteresis ---
	if not _kiting and hp_pct <= 0.30:
		_kiting = true
	elif _kiting and hp_pct >= 0.40:
		_kiting = false
	brott.stance = 2 if _kiting else _default_stance
	## Note: combat_sim forces stance=0 in overtime, overriding this.
	## That's intentional — overtime suppresses kite by design.
	
	## --- Rule 2: Module auto-fire (priority: Repair > EMP > Afterburner) ---
	## Only one module fires per tick; return immediately on match to avoid double-fire.
	if hp_pct < 0.40 and _module_ready(brott, "Repair Nanites") >= 0:
		brott._pending_gadget = "Repair Nanites"
		movement_override = ""
		return true
	
	var enemy_has_module: bool = false
	if enemy.module_active_timers.size() > 0:
		for t: float in enemy.module_active_timers:
			if t > 0:
				enemy_has_module = true
				break
	if enemy_has_module and _module_ready(brott, "EMP Charge") >= 0:
		brott._pending_gadget = "EMP Charge"
		movement_override = ""
		return true
	
	if _kiting and _module_ready(brott, "Afterburner") >= 0:
		brott._pending_gadget = "Afterburner"
		movement_override = ""
		return true
	
	## --- Rule 3: Movement (advance/kite handled by stance via combat_sim) ---
	movement_override = ""
	return true

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
			if enemy == null or not enemy.alive:
				return false
			var cover_dist := 48.0
			var center: float = 8.0 * 32.0
			var offset: float = 2.5 * 32.0
			var pillars: Array[Vector2] = [
				Vector2(center - offset, center - offset),
				Vector2(center + offset, center - offset),
				Vector2(center - offset, center + offset),
				Vector2(center + offset, center + offset),
			]
			for p in pillars:
				if enemy.position.distance_to(p) <= cover_dist:
					return true
			return false
		Trigger.WHEN_GADGET_READY:
			var mod_name: String = str(param)
			for i in range(brott.module_types.size()):
				var mdata: Dictionary = ModuleData.get_module(brott.module_types[i])
				if mdata["name"] == mod_name and brott.module_cooldowns[i] <= 0 and brott.module_active_timers[i] <= 0:
					return true
			return false
		Trigger.WHEN_CLOCK_SAYS:
			return match_time_sec >= float(param)
		Trigger.WHEN_THEYRE_RUNNING:
			# S14.2 Slice B: enemy velocity magnitude ≥ threshold tiles/sec AND moving away from brott.
			if enemy == null or not enemy.alive:
				return false
			var speed_tiles: float = enemy.velocity.length() / 32.0
			if speed_tiles < float(param):
				return false
			var away: Vector2 = enemy.position - brott.position
			if away.length_squared() <= 0.001 or enemy.velocity.length_squared() <= 0.001:
				return false
			return enemy.velocity.dot(away) > 0.0
		Trigger.WHEN_I_JUST_HIT_THEM:
			# S14.2 Slice B: landed hit within grace window. `last_hit_time_sec` is
			# stamped on the hitter (brott) by combat_sim at damage-application time.
			var last_hit: float = brott.last_hit_time_sec if "last_hit_time_sec" in brott else -1.0
			if last_hit < 0.0:
				return false
			return (match_time_sec - last_hit) <= float(param)
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
		Action.CHASE_TARGET:
			# S14.2 Slice B: combat_sim handles "chase" symmetrically to "cover"/"center".
			movement_override = "chase"
		Action.FOCUS_WEAKEST:
			# S14.2 Slice B: sugar — force weakest-targeting and drop any pending target lock.
			target_priority = "weakest"
			if brott != null and "target" in brott:
				brott.target = null

## ===== SMART DEFAULTS =====
## Pre-built BrottBrains that work out of the box for each chassis

static func default_for_chassis(chassis_type: int) -> BrottBrain:
	## S25.3: Baseline AI — no cards; stance-only configuration per chassis.
	## Scout=2 (Hit&Run baseline), Brawler=0 (Aggressive), Fortress=1 (PlayItSafe).
	var brain := BrottBrain.new()
	match chassis_type:
		0:  # Scout
			brain._default_stance = 2
		1:  # Brawler
			brain._default_stance = 0
		2:  # Fortress
			brain._default_stance = 1
		_:
			brain._default_stance = 0
	brain.default_stance = brain._default_stance
	return brain
