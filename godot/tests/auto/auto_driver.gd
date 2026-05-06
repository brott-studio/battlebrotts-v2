## Arc I S(I).1 — AutoDriver base class
## Headless game-driving harness for end-to-end flow tests.
##
## Usage:
##   godot --headless --path godot/ --script "res://tests/auto/test_*.gd"
##
## Extends SceneTree so it can be launched as a custom main loop via
## --script. Tests subclass AutoDriver, override _initialize() to set up
## initial state and _ticks_remaining, and override _drive_flow_step() to
## run each step of the test flow.
##
## Node path assumptions (resolved from game_main.gd + run_state.gd source):
##   game_main:        root child named "GameMain" (game_main.tscn)
##   run_state:        game_main.game_flow.run_state (RefCounted, not a Node)
##   sim:              game_main.sim (CombatSim)
##   game_flow.current_screen: GameFlow.Screen enum value

class_name AutoDriver
extends SceneTree

const TICK_SECONDS := 1.0 / 60.0
const DEFAULT_BOOT_TICKS := 10
const ACTION_TIMEOUT_TICKS := 600

var game_main: Node = null
var _failures: Array[String] = []

# Engine-driven flow state
var _ticks_remaining: int = 0
var _flow_done: bool = false

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _initialize() -> void:
	# Subclass overrides this to set up initial state and _ticks_remaining.
	# Base class just quits cleanly.
	_flow_done = true

func _process(delta: float) -> bool:
	if _flow_done:
		return true  # quit
	if _ticks_remaining > 0:
		_ticks_remaining -= 1
		return false  # still waiting
	# Run the next step of the test flow.
	_drive_flow_step()
	return false  # continue

func _drive_flow_step() -> void:
	# Override in subclass to drive flow step by step.
	_flow_done = true
	finish()

## Store n ticks to wait before the next _drive_flow_step() call.
func tick(n: int) -> void:
	_ticks_remaining = n

func boot() -> void:
	var packed: PackedScene = load("res://game_main.tscn")
	game_main = packed.instantiate()
	root.add_child(game_main)
	_setup_test_environment()

func _setup_test_environment() -> void:
	# Pre-mark all first-encounter overlay keys as seen so overlays never
	# appear during tests and intro screens are suppressed.
	var frs := root.get_node_or_null("FirstRunState")
	if frs == null:
		return
	for k in [
		"run_start_first_visit",
		"first_reward_pick",
		"first_retry_prompt",
		"energy_explainer",
		"click_controls_explainer",
		"combatants_explainer",
		"time_explainer",
		"concede_explainer",
		"silver_unlocked_modal_seen",
	]:
		frs.call("mark_seen", k)

func finish(exit_code: int = 0) -> void:
	if _failures.size() > 0:
		for f in _failures:
			push_error(f)
		quit(1)
	else:
		quit(exit_code)

# ─── Verb: click_chassis ─────────────────────────────────────────────────────

## Click the chassis card for chassis type `index`.
##
## RunStartScreen shuffles the visual order but names every button
## "ChassisBtn_<chassis_type>" (e.g. "ChassisBtn_0" for Scout). This verb
## finds the button by chassis-type name so `click_chassis(0)` always picks
## Scout regardless of visual position, and `equipped_chassis` will equal 0
## after the run starts.
##
## Signal path: button.pressed → RunStartScreen._on_card_pressed →
##              start_run_requested.emit(chassis_type) →
##              game_main._on_chassis_picked(chassis_type)
func click_chassis(index: int) -> void:
	var run_start := _find_run_start_screen()
	if run_start == null:
		_failures.append("click_chassis(%d): RunStartScreen not found (current screen may not be RUN_START)" % index)
		return
	# Buttons are named "ChassisBtn_<chassis_type>" — look up by type, not visual slot.
	var btn_name := "ChassisBtn_%d" % index
	var btn: Button = null
	for child in run_start.get_children():
		if child is Button and child.name == btn_name:
			btn = child as Button
			break
	if btn == null:
		_failures.append("click_chassis(%d): button '%s' not found in RunStartScreen" % [index, btn_name])
		return
	btn.emit_signal("pressed")

# ─── Verb: click_start_run ───────────────────────────────────────────────────

## Triggers the Arc N "Start Run" button on RunStartScreen.
## Replaces click_chassis() for Arc N+ entry path.
##
## Signal path: StartRunBtn.pressed → RunStartScreen._on_start_run_pressed →
##              start_run_requested.emit(default_chassis) →
##              game_main._on_chassis_picked(default_chassis)
func click_start_run() -> void:
	var run_start := _find_run_start_screen()
	if run_start == null:
		_failures.append("click_start_run: RunStartScreen not found (current screen may not be RUN_START)")
		return
	var btn: Button = null
	for child in run_start.get_children():
		if child is Button and child.name == "StartRunBtn":
			btn = child as Button
			break
	if btn == null:
		push_error("AutoDriver.click_start_run: StartRunBtn not found")
		_failures.append("click_start_run: StartRunBtn not found in RunStartScreen")
		return
	btn.emit_signal("pressed")

# ─── Verb: click_reward ──────────────────────────────────────────────────────

## Click reward option at position `index` in the RewardPickScreen.
## Signal path: RewardPickScreen.picked(item)
func click_reward(index: int) -> void:
	var reward_screen := _find_child_of_type(game_main, "RewardPickScreen")
	if reward_screen == null:
		_failures.append("click_reward(%d): RewardPickScreen not found" % index)
		return
	# RewardPickScreen exposes reward buttons — find them by name convention.
	var buttons: Array = []
	for child in reward_screen.get_children():
		if child is Button:
			buttons.append(child)
	if index < 0 or index >= buttons.size():
		_failures.append("click_reward(%d): only %d reward buttons found" % [index, buttons.size()])
		return
	buttons[index].emit_signal("pressed")

# ─── Verb: get_run_state ─────────────────────────────────────────────────────

## Return a snapshot of the current run state as a Dictionary.
## Returns empty dict with active=false if no run is in progress.
func get_run_state() -> Dictionary:
	if game_main == null:
		return {"active": false}
	var gf: Object = game_main.get("game_flow")
	if gf == null:
		return {"active": false}
	var rs: Object = gf.get("run_state")
	if rs == null:
		return {
			"active": false,
			"current_battle_index": 0,
			"battles_won": 0,
			"retries_remaining": 0,
			"equipped_chassis": -1,
			"equipped_weapons": [],
			"equipped_armor": 0,
			"equipped_modules": [],
			"current_screen": gf.get("current_screen") if gf != null else -1,
			"current_encounter": {},
		}
	return {
		"active": true,
		"current_battle_index": rs.get("current_battle_index"),
		"battles_won": rs.get("battles_won"),
		"retries_remaining": rs.get("retry_count"),
		"equipped_chassis": rs.get("equipped_chassis"),
		"equipped_weapons": rs.get("equipped_weapons"),
		"equipped_armor": rs.get("equipped_armor"),
		"equipped_modules": rs.get("equipped_modules"),
		"current_screen": gf.get("current_screen"),
		"current_encounter": rs.get("current_encounter"),
	}

# ─── Verb: get_arena_state ───────────────────────────────────────────────────

## Return a snapshot of the current arena/sim state.
func get_arena_state() -> Dictionary:
	var in_arena: bool = false
	var tick_count: int = 0
	var match_over: bool = false
	var winner_team: int = -1
	var player_data := {}
	var enemies_data: Array = []

	if game_main != null:
		in_arena = game_main.get("in_arena") as bool

	var sim: Object = game_main.get("sim") if game_main != null else null
	if sim != null:
		tick_count = sim.get("tick_count")
		match_over = sim.get("match_over")
		winner_team = sim.get("winner_team")
		var brotts = sim.get("brotts")
		if brotts != null:
			for b in brotts:
				var entry := {
					"hp": b.get("hp"),
					"max_hp": b.get("max_hp"),
					"energy": b.get("energy"),
					"alive": b.get("alive"),
					"team": b.get("team"),
					"bot_name": b.get("bot_name"),
				}
				if b.get("team") == 0:
					player_data = entry
				else:
					enemies_data.append(entry)

	return {
		"in_arena": in_arena,
		"tick_count": tick_count,
		"match_over": match_over,
		"winner_team": winner_team,
		"player": player_data,
		"enemies": enemies_data,
	}

# ─── Verb: force_battle_end ──────────────────────────────────────────────────

## Force the current match to end with `winner_team` as the winner.
## Directly sets sim.match_over + sim.winner_team and emits on_match_end.
func force_battle_end(winner_team: int) -> void:
	var sim: Object = game_main.get("sim") if game_main != null else null
	if sim == null:
		_failures.append("force_battle_end: sim is null (not in arena?)")
		return
	sim.set("match_over", true)
	sim.set("winner_team", winner_team)
	sim.emit_signal("on_match_end", winner_team)

# ─── Helper: assert_state ────────────────────────────────────────────────────

## Assert a dot-path value against {arena: ..., run: ...}.
## Collects failures instead of halting; call finish() to report.
##
## Path format: "run.active", "arena.in_arena", "arena.player.hp", etc.
func assert_state(path: String, expected_value) -> void:
	var parts := path.split(".")
	if parts.size() < 2:
		_failures.append("assert_state: invalid path '%s'" % path)
		return

	var top := parts[0]
	var data: Dictionary
	match top:
		"run":
			data = get_run_state()
		"arena":
			data = get_arena_state()
		_:
			_failures.append("assert_state: unknown root '%s' in path '%s'" % [top, path])
			return

	# Traverse remaining path segments.
	var current: Variant = data
	for i in range(1, parts.size()):
		var key := parts[i]
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			_failures.append("assert_state: path '%s' not found (failed at '%s')" % [path, key])
			return

	if current != expected_value:
		_failures.append("assert_state FAIL: %s — expected %s, got %s" % [path, str(expected_value), str(current)])

## Assert that a value satisfies a comparison (gte, lte, gt, lt, eq, ne).
func assert_cmp(path: String, op: String, threshold) -> void:
	var parts := path.split(".")
	if parts.size() < 2:
		_failures.append("assert_cmp: invalid path '%s'" % path)
		return
	var top := parts[0]
	var data: Dictionary
	match top:
		"run":
			data = get_run_state()
		"arena":
			data = get_arena_state()
		_:
			_failures.append("assert_cmp: unknown root '%s' in '%s'" % [top, path])
			return
	var current: Variant = data
	for i in range(1, parts.size()):
		var key := parts[i]
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			_failures.append("assert_cmp: path '%s' not found" % path)
			return
	var ok: bool = false
	match op:
		"gte": ok = current >= threshold
		"lte": ok = current <= threshold
		"gt":  ok = current > threshold
		"lt":  ok = current < threshold
		"eq":  ok = current == threshold
		"ne":  ok = current != threshold
		_:
			_failures.append("assert_cmp: unknown op '%s'" % op)
			return
	if not ok:
		_failures.append("assert_cmp FAIL: %s %s %s — got %s" % [path, op, str(threshold), str(current)])

# ─── Internal helpers ─────────────────────────────────────────────────────────

## Find the RunStartScreen inside game_main's ui_scroll / current_ui hierarchy.
func _find_run_start_screen() -> Node:
	if game_main == null:
		return null
	# RunStartScreen may be inside ui_scroll → current_ui, or directly as current_ui.
	var ui_scroll: Node = game_main.get("ui_scroll")
	if ui_scroll != null:
		for child in ui_scroll.get_children():
			if child.get_class() == "RunStartScreen" or child is Control and child.has_method("_on_card_pressed") or child.has_method("_on_start_run_pressed"):
				return child
	var current_ui: Node = game_main.get("current_ui")
	if current_ui != null and (current_ui.get_class() == "RunStartScreen" or current_ui.has_method("_on_card_pressed") or current_ui.has_method("_on_start_run_pressed")):
		return current_ui
	return null

## Find first child (recursive) matching the given class name string.
## Checks both engine class (get_class) and GDScript class_name (get_script().get_global_name()).
func _find_child_of_type(node: Node, class_name_str: String) -> Node:
	if node == null:
		return null
	for child in node.get_children():
		# Check engine base class name
		if child.get_class() == class_name_str:
			return child
		# Check GDScript declared class_name (Godot 4)
		var s = child.get_script()
		if s != null and s.get_global_name() == class_name_str:
			return child
		var found := _find_child_of_type(child, class_name_str)
		if found != null:
			return found
	return null

