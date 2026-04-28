## S(I).5 — bb_test JS bridge
##
## Exposes `window.bb_test` in Web Debug builds only.
## Runtime gate: OS.has_feature("web") AND OS.has_feature("debug_test_bridge")
##
## Activated via export preset "Web Debug" (custom_features="debug_test_bridge").
## The release "Web" preset has no custom_features, so bb_test is never injected.
##
## Usage from Playwright:
##   await page.evaluate(() => window.bb_test.click_chassis(0))
##   await page.evaluate(() => window.bb_test.get_arena_state())

extends Node

## Hold strong refs to all JS callback objects — GC will free them otherwise.
var _js_callbacks: Array = []

## Lazily resolved after main scene loads (autoload boots before scene).
var _game_main: Node = null

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	if not (OS.has_feature("web") and OS.has_feature("debug_test_bridge")):
		return  # No-op in release builds — autoload is inert.

	var win = JavaScriptBridge.get_interface("window")
	var bb = JavaScriptBridge.create_object("Object")

	var cb_click_chassis    := JavaScriptBridge.create_callback(_click_chassis_cb)
	var cb_click_reward     := JavaScriptBridge.create_callback(_click_reward_cb)
	var cb_get_run_state    := JavaScriptBridge.create_callback(_get_run_state_cb)
	var cb_get_arena_state  := JavaScriptBridge.create_callback(_get_arena_state_cb)
	var cb_force_battle_end := JavaScriptBridge.create_callback(_force_battle_end_cb)
	var cb_get_version      := JavaScriptBridge.create_callback(_get_version_cb)

	bb.click_chassis    = cb_click_chassis
	bb.click_reward     = cb_click_reward
	bb.get_run_state    = cb_get_run_state
	bb.get_arena_state  = cb_get_arena_state
	bb.force_battle_end = cb_force_battle_end
	bb.get_version      = cb_get_version

	win.bb_test = bb

	# Keep strong refs — without this the callbacks are freed by GC.
	_js_callbacks = [cb_click_chassis, cb_click_reward, cb_get_run_state,
	                 cb_get_arena_state, cb_force_battle_end, cb_get_version]

# ─── JS callback wrappers ─────────────────────────────────────────────────────

func _click_chassis_cb(args: Array):
	if args.size() < 1:
		return _err("click_chassis: missing index argument")
	return _click_chassis(int(args[0]))

func _click_reward_cb(args: Array):
	if args.size() < 1:
		return _err("click_reward: missing index argument")
	return _click_reward(int(args[0]))

func _get_run_state_cb(_args: Array):
	return _get_run_state()

func _get_arena_state_cb(_args: Array):
	return _get_arena_state()

func _force_battle_end_cb(args: Array):
	if args.size() < 1:
		return _err("force_battle_end: missing winner_team argument")
	return _force_battle_end(int(args[0]))

func _get_version_cb(_args: Array):
	return _get_version()

# ─── Verb implementations ─────────────────────────────────────────────────────

func _click_chassis(index: int):
	var gm := _get_game_main()
	if gm == null:
		return _err("click_chassis: game_main not found")
	var run_start := _find_run_start_screen(gm)
	if run_start == null:
		return _err("click_chassis(%d): RunStartScreen not found" % index)
	var btn_name := "ChassisBtn_%d" % index
	for child in run_start.get_children():
		if child is Button and child.name == btn_name:
			child.emit_signal("pressed")
			return true
	return _err("click_chassis(%d): button '%s' not found" % [index, btn_name])

func _click_reward(index: int):
	var gm := _get_game_main()
	if gm == null:
		return _err("click_reward: game_main not found")
	var reward_screen := _find_child_of_type(gm, "RewardPickScreen")
	if reward_screen == null:
		return _err("click_reward(%d): RewardPickScreen not found" % index)
	var buttons: Array = []
	for child in reward_screen.get_children():
		if child is Button:
			buttons.append(child)
	if index < 0 or index >= buttons.size():
		return _err("click_reward(%d): only %d buttons found" % [index, buttons.size()])
	buttons[index].emit_signal("pressed")
	return true

func _get_run_state() -> Dictionary:
	var gm := _get_game_main()
	if gm == null:
		return {"active": false}
	var gf: Object = gm.get("game_flow")
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
			"current_screen": int(gf.get("current_screen")),
			"current_encounter": {},
		}
	return {
		"active": true,
		"current_battle_index": int(rs.get("current_battle_index")),
		"battles_won": int(rs.get("battles_won")),
		"retries_remaining": int(rs.get("retry_count")),
		"equipped_chassis": int(rs.get("equipped_chassis")),
		"equipped_weapons": _plain_array(rs.get("equipped_weapons")),
		"equipped_armor": int(rs.get("equipped_armor")),
		"equipped_modules": _plain_array(rs.get("equipped_modules")),
		"current_screen": int(gf.get("current_screen")),
		"current_encounter": rs.get("current_encounter") if rs.get("current_encounter") != null else {},
	}

func _get_arena_state() -> Dictionary:
	var gm := _get_game_main()
	var in_arena: bool = false
	var tick_count: int = 0
	var match_over: bool = false
	var winner_team: int = -1
	var player_data := {}
	var enemies_data: Array = []

	if gm != null:
		in_arena = gm.get("in_arena") as bool

	var sim: Object = gm.get("sim") if gm != null else null
	if sim != null:
		tick_count = int(sim.get("tick_count"))
		match_over = sim.get("match_over") as bool
		winner_team = int(sim.get("winner_team"))
		var brotts = sim.get("brotts")
		if brotts != null:
			for b in brotts:
				var entry := {
					"hp": int(b.get("hp")),
					"max_hp": int(b.get("max_hp")),
					"energy": int(b.get("energy")),
					"alive": b.get("alive") as bool,
					"team": int(b.get("team")),
					"bot_name": str(b.get("bot_name")),
				}
				if int(b.get("team")) == 0:
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

func _force_battle_end(winner_team: int):
	var gm := _get_game_main()
	if gm == null:
		return _err("force_battle_end: game_main not found")
	var sim: Object = gm.get("sim")
	if sim == null:
		return _err("force_battle_end: sim is null (not in arena?)")
	sim.set("match_over", true)
	sim.set("winner_team", winner_team)
	sim.emit_signal("on_match_end", winner_team)
	return true

func _get_version() -> Dictionary:
	return {
		"bridge": "1.0",
		"game": str(ProjectSettings.get_setting("application/config/version", "unknown")),
	}

# ─── Internal helpers ─────────────────────────────────────────────────────────

## Lazily resolve game_main — not available at autoload _ready() time.
## Root child is named "GameMain" per game_main.tscn.
func _get_game_main() -> Node:
	if _game_main == null or not is_instance_valid(_game_main):
		_game_main = get_tree().root.get_node_or_null("GameMain")
	return _game_main

## Find RunStartScreen in game_main's ui hierarchy.
func _find_run_start_screen(gm: Node) -> Node:
	if gm == null:
		return null
	var ui_scroll: Node = gm.get("ui_scroll")
	if ui_scroll != null:
		for child in ui_scroll.get_children():
			if child.get_class() == "RunStartScreen" or \
			   (child is Control and child.has_method("_on_card_pressed")):
				return child
	var current_ui: Node = gm.get("current_ui")
	if current_ui != null and \
	   (current_ui.get_class() == "RunStartScreen" or current_ui.has_method("_on_card_pressed")):
		return current_ui
	return null

## Find first child (recursive) by class name.
## Checks both engine class and GDScript declared class_name.
func _find_child_of_type(node: Node, class_name_str: String) -> Node:
	if node == null:
		return null
	for child in node.get_children():
		if child.get_class() == class_name_str:
			return child
		var s = child.get_script()
		if s != null and s.get_global_name() == class_name_str:
			return child
		var found := _find_child_of_type(child, class_name_str)
		if found != null:
			return found
	return null

## Coerce a typed/packed array to a plain Array for JSON serialization.
func _plain_array(v) -> Array:
	if v == null:
		return []
	var out: Array = []
	for item in v:
		out.append(item)
	return out

## Standard error return.
func _err(msg: String) -> Dictionary:
	return {"error": msg}
