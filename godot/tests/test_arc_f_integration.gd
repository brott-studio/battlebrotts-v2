## test_arc_f_integration.gd — S25.9: Arc F full-loop integration validation.
## Runs 10 headless roguelike runs. Validates variety rule, guarantee seeds, and boss access.
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0
	var total_runs := 10

	for run_idx in range(total_runs):
		var rng := RandomNumberGenerator.new()
		rng.seed = (run_idx + 1) * 31337  ## Diverse deterministic seeds

		var rs := RunState.new(0, rng.randi())
		var schedule: Array[String] = []

		## Generate 15-slot schedule
		for battle_idx in range(15):
			var arch := OpponentLoadouts.archetype_for(battle_idx, rs, rng)
			schedule.append(arch)
			rs.current_encounter["archetype_id"] = arch

		## Gate A: battle 15 (idx 14) = boss
		if schedule[14] != "boss":
			push_error("Run %d: Gate A FAIL — battle 15 is '%s', expected 'boss'" % [run_idx, schedule[14]])
			fail_count += 1
		else:
			pass_count += 1

		## Gate B: no consecutive repeat (variety rule)
		var has_repeat := false
		for i in range(1, 15):
			if schedule[i] == schedule[i-1] and schedule[i] != "boss":
				push_error("Run %d: Gate B FAIL — repeat at slot %d ('%s')" % [run_idx, i, schedule[i]])
				has_repeat = true
				break
		if not has_repeat:
			pass_count += 1
		else:
			fail_count += 1

		## Gate C: guarantee seeds present (small_swarm, counter_build_elite, miniboss_escorts)
		var has_swarm := "small_swarm" in schedule
		var has_elite := "counter_build_elite" in schedule
		var has_escort := "miniboss_escorts" in schedule
		if has_swarm and has_elite and has_escort:
			pass_count += 1
		else:
			push_error("Run %d: Gate C FAIL — missing guarantee: swarm=%s elite=%s escort=%s" % [run_idx, has_swarm, has_elite, has_escort])
			fail_count += 1

	print("test_arc_f_integration: %d passed, %d failed (10 runs × 3 gates each)" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
