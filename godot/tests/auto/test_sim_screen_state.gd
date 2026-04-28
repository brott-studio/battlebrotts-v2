## test_sim_screen_state.gd — verifies direct _start_roguelike_match() sets ARENA screen state.
## Prerequisite for sim driver (sim_single_run.gd) to exit SCREEN_RUN_START polling loop.
## Arc J sprint-28.1 / SI1-001.

extends AutoDriver

var _step: int = 0

func _initialize() -> void:
	boot()
	_ticks_remaining = 40

func _drive_flow_step() -> void:
	match _step:
		0:
			# Trigger new game to reach RUN_START
			game_main.call("_on_new_game")
			_ticks_remaining = 15
			_step += 1
		1:
			# Verify we're at RUN_START
			var gf: Object = game_main.get("game_flow")
			if gf == null:
				_failures.append("game_flow is null")
				_flow_done = true
				finish(1)
				return
			var screen_before: int = gf.get("current_screen")
			if screen_before != 7:  # GameFlow.Screen.RUN_START
				_failures.append("Expected RUN_START(7) before direct call, got %d" % screen_before)
			# Call _start_roguelike_match directly (sim driver pattern), bypassing click_chassis
			gf.call("start_run", 0, 12345)
			game_main.call("_start_roguelike_match")
			_ticks_remaining = 20
			_step += 1
		2:
			# Assert current_screen is now ARENA (5), not still RUN_START (7)
			var gf: Object = game_main.get("game_flow")
			var screen_after: int = gf.get("current_screen") if gf != null else -1
			if screen_after != 5:  # GameFlow.Screen.ARENA
				_failures.append("Expected ARENA(5) after direct _start_roguelike_match, got %d" % screen_after)
			# Also assert in_arena is true
			var in_arena: bool = game_main.get("in_arena")
			if not in_arena:
				_failures.append("Expected in_arena=true after _start_roguelike_match, got false")
			_flow_done = true
			finish()
