## Arc I S(I).2 — TestRunEndFlow
## End-to-end user flow: boot → new game → chassis pick → arena → battle loss
## → retry prompt → brott down screen → new run → run start screen.
##
## Acceptance criteria:
##   - exits 0 on clean run
##   - exits 1 if loss → brott-down → new-run transition is broken
##   - wall-clock under 15s
##
## Usage:
##   godot --headless --path godot/ --script "res://tests/auto/test_run_end_flow.gd"

extends AutoDriver

var _step: int = 0

func _initialize() -> void:
	var packed: PackedScene = load("res://game_main.tscn")
	game_main = packed.instantiate()
	root.add_child(game_main)
	_setup_test_environment()
	_ticks_remaining = 40

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
			var screen: int = gf.get("current_screen") if gf != null else -1
			if screen != 7:
				_failures.append("Expected RUN_START(7), got %d" % screen)
			# Click Start Run (Arc N entry path — defaults to Brawler, chassis 1)
			click_start_run()
			_ticks_remaining = 60
			_step += 1

		2:
			assert_state("run.active", true)
			assert_state("arena.in_arena", true)
			assert_cmp("arena.tick_count", "gte", 1)
			force_battle_end(1)
			_ticks_remaining = 180
			_step += 1

		3:
			var gf: Object = game_main.get("game_flow")
			var screen: int = gf.get("current_screen") if gf != null else -1
			if screen != 9:
				_failures.append("Expected RETRY_PROMPT(9) after battle loss, got %d" % screen)
			assert_state("arena.in_arena", false)
			if not game_main.has_method("_show_brott_down"):
				_failures.append("game_main missing _show_brott_down")
				_flow_done = true
				finish(1)
				return
			game_main.call("_show_brott_down")
			_ticks_remaining = 10
			_step += 1

		4:
			var brott_down := _find_child_of_type(game_main, "BrottDownScreen")
			if brott_down == null:
				_failures.append("BrottDownScreen not found after _show_brott_down")
				_flow_done = true
				finish(1)
				return
			var gf: Object = game_main.get("game_flow")
			var rs: Object = gf.get("run_state") if gf != null else null
			if rs == null or not rs.get("run_ended"):
				_failures.append("Expected run_state.run_ended==true after _show_brott_down")
			var new_run_btn: Button = brott_down.get_node_or_null("NewRunButton") as Button
			if new_run_btn == null:
				_failures.append("NewRunButton not found in BrottDownScreen")
				_flow_done = true
				finish(1)
				return
			new_run_btn.emit_signal("pressed")
			_ticks_remaining = 30
			_step += 1

		5:
			assert_state("run.active", false)
			var gf: Object = game_main.get("game_flow")
			var screen: int = gf.get("current_screen") if gf != null else -1
			if screen != 7:
				_failures.append("Expected RUN_START(7) after New Run, got %d" % screen)
			var rs_screen := _find_run_start_screen()
			if rs_screen == null:
				_failures.append("RunStartScreen not found after New Run pressed")
			_flow_done = true
			finish()
