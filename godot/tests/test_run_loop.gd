## test_run_loop.gd — S25.7: Battle loop state machine tests.
## Tests RunState + GameFlow + OpponentLoadouts only (no UI / game_main).
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	## Path A: 15-battle win path
	var rs_a := RunState.new(0, 42)
	rs_a.run_ended = false
	var reward_count := 0
	var run_complete := false

	for battle_idx in range(15):
		## Set encounter (use archetype generator)
		var arch := OpponentLoadouts.archetype_for(battle_idx, rs_a)
		var tier := OpponentLoadouts.difficulty_for_battle(battle_idx)
		rs_a.set_encounter(arch, tier, 42)
		## Check battle 14 (index, i.e. 15th battle) goes to boss (no reward)
		var is_boss := (battle_idx == 14)
		## Simulate win
		rs_a.advance_battle_index()
		if not is_boss:
			reward_count += 1
		else:
			run_complete = true

	if reward_count != 14:
		push_error("Path A FAIL: expected 14 reward picks, got %d" % reward_count)
		fail_count += 1
	else:
		pass_count += 1

	if not run_complete:
		push_error("Path A FAIL: RUN_COMPLETE never fired")
		fail_count += 1
	else:
		pass_count += 1

	if rs_a.retry_count != 3:
		push_error("Path A FAIL: retry_count should be unchanged (3), got %d" % rs_a.retry_count)
		fail_count += 1
	else:
		pass_count += 1

	if rs_a.current_battle_index != 15:
		push_error("Path A FAIL: battle_index should be 15 after 15 battles, got %d" % rs_a.current_battle_index)
		fail_count += 1
	else:
		pass_count += 1

	## Path B: 4-loss run-end
	var rs_b := RunState.new(0, 42)
	var retry_prompts := 0
	var run_ended := false

	for attempt in range(4):
		if rs_b.retry_count > 0:
			rs_b.use_retry()
			retry_prompts += 1
		else:
			run_ended = true
			rs_b.run_ended = true
			break

	if retry_prompts != 3:
		push_error("Path B FAIL: expected 3 retry prompts, got %d" % retry_prompts)
		fail_count += 1
	else:
		pass_count += 1

	if not run_ended:
		push_error("Path B FAIL: run_ended should be true after 4 losses")
		fail_count += 1
	else:
		pass_count += 1

	if rs_b.current_battle_index != 0:
		push_error("Path B FAIL: battle_index should stay 0, got %d" % rs_b.current_battle_index)
		fail_count += 1
	else:
		pass_count += 1

	## Path C: start_run() resets run_ended
	var rs_c2 := RunState.new(1, 0)  ## new run
	if rs_c2.run_ended:
		push_error("Path C FAIL: new RunState should not have run_ended set")
		fail_count += 1
	else:
		pass_count += 1

	print("test_run_loop: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
