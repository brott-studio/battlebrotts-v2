## test_encounter_generator.gd — S25.6 encounter generator validation
##
## Gates covered:
##   Gate 1 — no consecutive repeat across 1000 runs (absolute, 0 violations)
##   Gate 2 — guarantee archetypes (small_swarm, counter_build_elite,
##            miniboss_escorts) each appear ≥1 time per run, ≥99% success
##   Gate 3 — battle 15 (index 14) always returns "boss" regardless of seed
##   Gate 4 — difficulty_for_battle() tier mapping
##            [1,1,1,2,2,2,2,3,3,3,3,4,4,4,5]
##   Gate 6 — large_swarm tier-adaptive HP (0.2 / 0.4 / 0.7 / 0.9 by tier)
##
## NOTE: deviation from sub-sprint spec — the new tier-by-battle mapping is
##       exposed as `difficulty_for_battle(int)` instead of `difficulty_for(int)`
##       to avoid colliding with the existing league-era 2-arg
##       `difficulty_for(league: String, index: int)` (still used by
##       opponent_data.gd for save-compat / batch test baseline).
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	## Gate 3: Battle 15 (index 14) always returns "boss"
	var gate3_ok := true
	for seed in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var result := OpponentLoadouts.archetype_for(14, null, rng)
		if result != "boss":
			push_error("Gate 3 FAIL at seed %d: expected boss, got %s" % [seed, result])
			gate3_ok = false
			break
	if gate3_ok:
		pass_count += 1
	else:
		fail_count += 1

	## Gate 4: difficulty_for_battle() mapping
	var expected_tiers := [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5]
	var gate4_ok := true
	for i in range(15):
		var t := OpponentLoadouts.difficulty_for_battle(i)
		if t != expected_tiers[i]:
			push_error("Gate 4 FAIL: difficulty_for_battle(%d) = %d, expected %d" % [i, t, expected_tiers[i]])
			gate4_ok = false
	if gate4_ok:
		pass_count += 1
	else:
		fail_count += 1

	## Gate 6: Large Swarm tier-adaptive HP
	var gate6_ok := true
	var expected_pct := {1: 0.2, 2: 0.4, 3: 0.7, 4: 0.9}
	var idx_per_tier := {1: 0, 2: 3, 3: 7, 4: 11}
	for tier in expected_pct:
		var idx: int = idx_per_tier[tier]
		var specs := OpponentLoadouts.compose_encounter("large_swarm", idx, null)
		var base_hp := OpponentLoadouts._baseline_hp_for_tier(tier)
		var expected_hp := int(base_hp * float(expected_pct[tier]))
		if specs.is_empty():
			push_error("Gate 6 FAIL T%d: compose_encounter returned no specs" % tier)
			gate6_ok = false
			continue
		for spec in specs:
			var got: int = spec.get("hp", 0)
			if abs(got - expected_hp) > 1:  # tolerance for int truncation
				push_error("Gate 6 FAIL T%d: hp %d, expected ~%d" % [tier, got, expected_hp])
				gate6_ok = false
				break
	if gate6_ok:
		pass_count += 1
	else:
		fail_count += 1

	## Gates 1+2: 1000-run simulation
	var no_repeat_violations := 0
	var guarantee_failures := 0
	var total_runs := 1000

	for seed in range(total_runs):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 7919  # diverse seeds
		## Generate schedule using a mock run_state (just needs encounter_schedule field)
		var mock_state := RunState.new(0, seed)
		var schedule: Array[String] = []
		for idx in range(15):
			var arch := OpponentLoadouts.archetype_for(idx, mock_state, rng)
			schedule.append(arch)

		## Gate 1: no consecutive repeat (boss is at idx 14, exempted from prior-slot match)
		for i in range(1, 15):
			if schedule[i] == schedule[i - 1] and schedule[i] != "boss":
				no_repeat_violations += 1

		## Gate 2: guarantee archetypes present
		var has_swarm := schedule.has("small_swarm")
		var has_elite := schedule.has("counter_build_elite")
		var has_miniboss := schedule.has("miniboss_escorts")
		if not (has_swarm and has_elite and has_miniboss):
			guarantee_failures += 1

	## Gate 1: 0 violations allowed (no-repeat is absolute)
	if no_repeat_violations == 0:
		pass_count += 1
	else:
		push_error("Gate 1 FAIL: %d consecutive repeat violations in 1000 runs" % no_repeat_violations)
		fail_count += 1

	## Gate 2: ≥99% success (≤10 failures in 1000)
	if guarantee_failures <= 10:
		pass_count += 1
	else:
		push_error("Gate 2 FAIL: %d/%d runs missing a guarantee archetype (>1%%)" % [guarantee_failures, total_runs])
		fail_count += 1

	print("test_encounter_generator: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
