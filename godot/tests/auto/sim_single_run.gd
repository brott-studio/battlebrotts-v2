## Arc I S(I).3 — Combat Sim Agent: single-run headless driver.
##
## Runs a full roguelike run (up to 15 battles) with random chassis + reward picks.
## Always accepts loss (never uses retries). Outputs one JSON line to stdout.
##
## Usage:
##   godot --headless --path godot/ --script "res://tests/auto/sim_single_run.gd" -- --seed=12345
##
## Exit codes: 0 = clean (win or death), 1 = driver failure, 2 = timeout.
## sim_* prefix keeps this file OUT of the per-PR test_*.gd glob.

extends AutoDriver

# ─── Constants ───────────────────────────────────────────────────────────────

const SIM_SPEED_MULT := 8.0
const MAX_FLOW_TICKS := 36000

# Screen int constants (GameFlow.Screen enum values)
const SCREEN_MAIN_MENU := 0
const SCREEN_RUN_START := 7
const SCREEN_ARENA := 5
const SCREEN_REWARD_PICK := 8
const SCREEN_RETRY_PROMPT := 9
const SCREEN_BOSS_ARENA := 10
const SCREEN_RUN_COMPLETE := 11

# ─── Sim state ───────────────────────────────────────────────────────────────

var _seed: int = 0
var _rng: RandomNumberGenerator
var _chosen_chassis: int = -1
var _chassis_names := {0: "SCOUT", 1: "BRAWLER", 2: "FORTRESS"}
var _reward_picks: Array = []
var _battles_lost: int = 0
var _cumulative_arena_ticks: int = 0
var _last_arena_ticks_seen: int = 0
var _arena_ticks_recorded: bool = false
var _last_drive_screen: int = -99
var _total_flow_ticks: int = 0
var _wall_clock_start: float = 0.0

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _initialize() -> void:
	_seed = _parse_seed_arg()
	_rng = RandomNumberGenerator.new()
	_rng.seed = _seed
	_wall_clock_start = Time.get_unix_time_from_system()
	boot()
	_ticks_remaining = DEFAULT_BOOT_TICKS

func _process(delta: float) -> bool:
	_total_flow_ticks += 1
	if _total_flow_ticks > MAX_FLOW_TICKS and not _flow_done:
		_capture_and_exit("timeout", 2)
		return true
	return super._process(delta)

# ─── Flow dispatcher ─────────────────────────────────────────────────────────

func _drive_flow_step() -> void:
	if _flow_done:
		return

	# Terminal: death (run_ended set by _show_brott_down)
	var gf: Object = game_main.get("game_flow")
	if gf != null:
		var rs: Object = gf.get("run_state")
		if rs != null and rs.get("run_ended"):
			_capture_and_exit("death", 0)
			return

	var screen: int = gf.get("current_screen") if gf != null else -1

	# Reset arena tick guard on new battle entry
	if (screen == SCREEN_ARENA or screen == SCREEN_BOSS_ARENA) \
	   and _last_drive_screen != SCREEN_ARENA and _last_drive_screen != SCREEN_BOSS_ARENA:
		_arena_ticks_recorded = false
		_last_arena_ticks_seen = 0

	_last_drive_screen = screen

	match screen:
		SCREEN_MAIN_MENU:
			if not game_main.has_method("_on_new_game"):
				_failures.append("game_main missing _on_new_game")
				_flow_done = true
				finish(1)
				return
			game_main.call("_on_new_game")
			_ticks_remaining = 20

		SCREEN_RUN_START:
			if gf == null:
				_failures.append("RUN_START: game_flow is null")
				_flow_done = true
				finish(1)
				return
			_chosen_chassis = _rng.randi_range(0, 2)
			# Use direct start_run + _start_roguelike_match to propagate seed
			gf.call("start_run", _chosen_chassis, _seed)
			game_main.call("_start_roguelike_match")
			_ticks_remaining = 60

		SCREEN_ARENA, SCREEN_BOSS_ARENA:
			# Re-set speed_multiplier every poll — _start_roguelike_match resets it to 1.0
			game_main.set("speed_multiplier", SIM_SPEED_MULT)

			var sim: Object = game_main.get("sim")
			if sim == null:
				_failures.append("ARENA: sim is null")
				_flow_done = true
				finish(1)
				return

			var match_over: bool = sim.get("match_over")
			if not match_over:
				_last_arena_ticks_seen = sim.get("tick_count")
				_ticks_remaining = 30
			else:
				if not _arena_ticks_recorded:
					var tick_count: int = sim.get("tick_count")
					_cumulative_arena_ticks += tick_count
					_arena_ticks_recorded = true
				# Wait for game_main's 1s create_timer to fire and screen to transition
				_ticks_remaining = 60

		SCREEN_REWARD_PICK:
			var rs: Object = gf.get("run_state") if gf != null else null
			var battle_idx: int = rs.get("current_battle_index") if rs != null else 0
			var btn_count: int = _count_reward_buttons()
			if btn_count <= 0:
				_failures.append("REWARD_PICK: no reward buttons at battle %d" % battle_idx)
				_flow_done = true
				finish(1)
				return
			var btn_idx: int = _rng.randi_range(0, btn_count - 1)
			_reward_picks.append({"battle_index": battle_idx, "button_index": btn_idx})
			click_reward(btn_idx)
			_ticks_remaining = 60

		SCREEN_RETRY_PROMPT:
			# Always accept loss — confirmed pattern from test_run_end_flow.gd
			_battles_lost += 1
			if not game_main.has_method("_show_brott_down"):
				_failures.append("RETRY_PROMPT: game_main missing _show_brott_down")
				_flow_done = true
				finish(1)
				return
			game_main.call("_show_brott_down")
			_ticks_remaining = 30

		SCREEN_RUN_COMPLETE:
			_capture_and_exit("win", 0)

		_:
			# Unexpected screen — may be transient; poll again in 30t
			_ticks_remaining = 30

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _parse_seed_arg() -> int:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--seed="):
			var val := arg.substr(7)
			if val.is_valid_int():
				return int(val)
	return int(Time.get_unix_time_from_system()) ^ OS.get_process_id()

func _count_reward_buttons() -> int:
	var reward_screen := _find_child_of_type(game_main, "RewardPickScreen")
	if reward_screen == null:
		return 0
	var count := 0
	for child in reward_screen.get_children():
		if child is Button:
			count += 1
	return count

func _snapshot_loadout() -> Dictionary:
	var gf: Object = game_main.get("game_flow")
	var rs: Object = gf.get("run_state") if gf != null else null
	if rs == null:
		return {"chassis": -1, "weapons": [], "armor": -1, "modules": []}
	return {
		"chassis": rs.get("equipped_chassis"),
		"weapons": rs.get("equipped_weapons").duplicate(),
		"armor":   rs.get("equipped_armor"),
		"modules": rs.get("equipped_modules").duplicate(),
	}

func _capture_and_exit(terminal_state: String, exit_code: int) -> void:
	if _flow_done:
		return
	_flow_done = true

	var wall_clock: float = Time.get_unix_time_from_system() - _wall_clock_start

	var gf: Object = game_main.get("game_flow")
	var rs: Object = gf.get("run_state") if gf != null else null
	var battles_won: int = rs.get("battles_won") if rs != null else 0

	var payload := {
		"schema_version":    1,
		"seed":              _seed,
		"chassis":           _chosen_chassis,
		"chassis_name":      _chassis_names.get(_chosen_chassis, "UNKNOWN"),
		"battles_won":       battles_won,
		"battles_lost":      _battles_lost,
		"total_ticks":       _cumulative_arena_ticks,
		"terminal_state":    terminal_state,
		"reward_picks":      _reward_picks,
		"final_loadout":     _snapshot_loadout(),
		"wall_clock_seconds": snappedf(wall_clock, 0.001),
	}

	print(JSON.stringify(payload))

	if _failures.size() > 0:
		finish(1)
	else:
		finish(exit_code)
