## Arc I S(I).2 — TestRewardPickFlow
## End-to-end user flow: boot → new game → chassis pick → arena → battle win
## → reward pick screen → pick reward → next battle arena entry.
##
## Acceptance criteria:
##   - exits 0 on clean run
##   - exits 1 if reward pick → next battle transition is broken
##   - wall-clock under 15s
##
## Usage:
##   godot --headless --path godot/ --script "res://tests/auto/test_reward_pick_flow.gd"

extends AutoDriver

var _step: int = 0

func _initialize() -> void:
	var packed: PackedScene = load("res://game_main.tscn")
	game_main = packed.instantiate()
	root.add_child(game_main)
	_setup_test_environment()
	_ticks_remaining = 40  # boot + settle

func _drive_flow_step() -> void:
	match _step:
		0:
			var run := get_run_state()
			if run.get("active", false):
				_failures.append("After boot: expected run.active==false, got true")
			if not game_main.has_method("_on_new_game"):
				_failures.append("game_main missing _on_new_game")
				_flow_done = true
				finish(1)
				return
			game_main.call("_on_new_game")
			_ticks_remaining = 15
			_step += 1

		1:
			var gf: Object = game_main.get("game_flow")
			if gf == null:
				_failures.append("game_flow is null after _on_new_game")
				_flow_done = true
				finish(1)
				return
			var screen: int = gf.get("current_screen")
			if screen != 7:
				_failures.append("Expected RUN_START(7) after new game, got %d" % screen)
			click_chassis(0)
			_ticks_remaining = 60
			_step += 1

		2:
			assert_state("run.active", true)
			assert_state("run.equipped_chassis", 0)
			assert_state("arena.in_arena", true)
			assert_cmp("arena.tick_count", "gte", 1)
			force_battle_end(0)
			_ticks_remaining = 180
			_step += 1

		3:
			var gf: Object = game_main.get("game_flow")
			var screen: int = gf.get("current_screen") if gf != null else -1
			if screen != 8:
				_failures.append("Expected REWARD_PICK(8) after battle win, got %d" % screen)
			assert_state("arena.in_arena", false)
			click_reward(0)
			_ticks_remaining = 60
			_step += 1

		4:
			assert_state("arena.in_arena", true)
			assert_cmp("run.current_battle_index", "gte", 1)
			_ticks_remaining = 60
			_step += 1

		5:
			assert_cmp("arena.tick_count", "gte", 1)
			_flow_done = true
			finish()
