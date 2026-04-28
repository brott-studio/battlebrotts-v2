## Arc I S(I).1 — TestFirstFlowChassisPick
## End-to-end user flow: boot → menu → new game → chassis pick → arena entry → first tick
##
## Acceptance criteria:
##   - exits 0 on clean run
##   - exits 1 if _on_chassis_picked is broken (or chassis does not arm the run)
##   - wall-clock under 15s
##
## Usage:
##   godot --headless --path godot/ --script "res://tests/auto/test_first_flow_chassis_pick.gd"

extends AutoDriver

var _step: int = 0

func _initialize() -> void:
	# Boot: load game_main.tscn, add to scene, setup test env
	var packed: PackedScene = load("res://game_main.tscn")
	game_main = packed.instantiate()
	root.add_child(game_main)
	_setup_test_environment()
	# Wait 40 frames (10 boot + 30 extra settle) before first step
	_ticks_remaining = 40

func _drive_flow_step() -> void:
	match _step:
		0:
			# Assert menu state after boot settle
			var run := get_run_state()
			if run.get("active", false):
				_failures.append("After boot: expected run.active==false, got true")
			# Trigger new game
			if not game_main.has_method("_on_new_game"):
				_failures.append("game_main missing _on_new_game")
				_flow_done = true
				finish(1)
				return
			game_main.call("_on_new_game")
			_ticks_remaining = 15  # settle into RunStartScreen
			_step += 1
		1:
			# Assert RUN_START screen
			var gf: Object = game_main.get("game_flow")
			if gf == null:
				_failures.append("game_flow is null after _on_new_game")
				_flow_done = true
				finish(1)
				return
			var screen: int = gf.get("current_screen")
			if screen != 7:  # GameFlow.Screen.RUN_START
				_failures.append("Expected screen RUN_START(7), got %d" % screen)
			# Click chassis 0
			click_chassis(0)
			_ticks_remaining = 60  # settle into arena
			_step += 1
		2:
			# Assert run active, chassis 0, in_arena
			assert_state("run.active", true)
			assert_state("run.equipped_chassis", 0)
			assert_state("arena.in_arena", true)
			_ticks_remaining = 60  # let sim tick
			_step += 1
		3:
			# Assert sim is ticking
			assert_cmp("arena.tick_count", "gte", 1)
			_flow_done = true
			finish()
