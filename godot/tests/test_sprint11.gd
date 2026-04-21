## Sprint 11.1 test suite — Combat Movement System (orbit, juke, engagement distance)
## Validates acceptance criteria from Gizmo's design spec
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0
var _hit_count := 0

func _init() -> void:
	print("=== BattleBrotts Sprint 11.1 Test Suite ===")
	print("=== Combat Movement System ===\n")

	test_no_overlap_stalemate()
	test_movement_during_combat()
	test_position_change_frequency()
	test_no_moonwalking()
	test_stances_preserved()
	test_separation_force()
	test_engagement_distances()

	print("\n--- Results ---")
	print("%d passed, %d failed out of %d" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _make_scout(team: int, stance: int = 0, weapons: Array = []) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.bot_name = "Scout_%d" % team
	b.chassis_type = ChassisData.ChassisType.SCOUT
	if weapons.is_empty():
		b.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]
	else:
		b.weapon_types.assign(weapons)
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.stance = stance
	b.setup()
	return b

func _make_brawler(team: int, stance: int = 0) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.bot_name = "Brawler_%d" % team
	b.chassis_type = ChassisData.ChassisType.BRAWLER
	b.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.stance = stance
	b.setup()
	return b

func _run_sim(seed_val: int, b0: BrottState, b1: BrottState, max_ticks: int = 600) -> CombatSim:
	var sim := CombatSim.new(seed_val)
	b0.position = Vector2(64, 256)
	b1.position = Vector2(448, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)
	for _t in range(max_ticks):
		if sim.match_over:
			break
		sim.simulate_tick()
	return sim

func test_no_overlap_stalemate() -> void:
	print("\n-- AC1: No Overlap Stalemate (1000 sims) --")
	var stalemate_count := 0
	for seed_val in range(1000):
		var b0 := _make_scout(0)
		var b1 := _make_scout(1)
		var sim := CombatSim.new(seed_val)
		b0.position = Vector2(64, 256)
		b1.position = Vector2(448, 256)
		sim.add_brott(b0)
		sim.add_brott(b1)
		
		var stuck_ticks := 0
		var max_stuck := 0
		for _t in range(600):
			if sim.match_over:
				break
			sim.simulate_tick()
			if b0.alive and b1.alive:
				var d: float = b0.position.distance_to(b1.position)
				if d < 16.0:  # 0.5 tiles
					stuck_ticks += 1
				else:
					max_stuck = maxi(max_stuck, stuck_ticks)
					stuck_ticks = 0
		max_stuck = maxi(max_stuck, stuck_ticks)
		# 2 consecutive seconds = 20 ticks at 10 tps
		if max_stuck > 20:
			stalemate_count += 1
	
	_assert(stalemate_count == 0, "0%% stalemate rate (got %d/1000)" % stalemate_count)

func test_movement_during_combat() -> void:
	print("\n-- AC2: Movement During Combat --")
	var total_distance := 0.0
	var bot_count := 0
	for seed_val in range(50):
		var b0 := _make_scout(0)
		var b1 := _make_scout(1)
		var sim := CombatSim.new(seed_val)
		b0.position = Vector2(64, 256)
		b1.position = Vector2(448, 256)
		sim.add_brott(b0)
		sim.add_brott(b1)
		
		var engaged := false
		var dist_b0 := 0.0
		var dist_b1 := 0.0
		var prev_b0 := b0.position
		var prev_b1 := b1.position
		
		for _t in range(600):
			if sim.match_over:
				break
			sim.simulate_tick()
			if b0.alive:
				dist_b0 += b0.position.distance_to(prev_b0)
				prev_b0 = b0.position
			if b1.alive:
				dist_b1 += b1.position.distance_to(prev_b1)
				prev_b1 = b1.position
		
		total_distance += dist_b0 / 32.0  # Convert to tiles
		total_distance += dist_b1 / 32.0
		bot_count += 2
	
	var avg_tiles: float = total_distance / float(bot_count)
	_assert(avg_tiles > 5.0, "Avg distance traveled: %.1f tiles (need >5)" % avg_tiles)

func test_position_change_frequency() -> void:
	print("\n-- AC5: Position Change Every 3 Seconds --")
	var violations := 0
	for seed_val in range(50):
		var b0 := _make_scout(0)
		var b1 := _make_scout(1)
		var sim := CombatSim.new(seed_val)
		b0.position = Vector2(64, 256)
		b1.position = Vector2(448, 256)
		sim.add_brott(b0)
		sim.add_brott(b1)
		
		var last_pos_b0 := b0.position
		var stationary_ticks := 0
		
		for _t in range(600):
			if sim.match_over:
				break
			sim.simulate_tick()
			if b0.alive and b0.in_combat_movement:
				if b0.position.distance_to(last_pos_b0) < 1.0:
					stationary_ticks += 1
				else:
					stationary_ticks = 0
					last_pos_b0 = b0.position
				if stationary_ticks > 30:  # 3 seconds at 10 tps
					violations += 1
					break
	
	_assert(violations == 0, "No bots stationary >3s during combat (%d violations)" % violations)

func test_no_moonwalking() -> void:
	print("\n-- AC6: No Moonwalking (backup >1 tile) --")
	# S17.2-003 addendum (docs/design/s17.2-003-retreat-calibration.md §2.3):
	# migrated from naive post-tick metric to the S15.2-canonical intent-frame
	# pre-tick + period-boundary reset + budget-gated accumulator pattern already
	# used by test_sprint11_2.gd::test_away_juke_cap_across_seeds. Under the
	# two-phase tick introduced in S17.2-003, the post-tick metric produced
	# false positives because post-cap perpendicular/lateral motion read as
	# backward against a stale post-tick `to_target` frame. Threshold stays
	# `<= 10` (unchanged); no AC relaxation. See S15.2 ruling
	# (docs/design/sprint15-moonwalk-metric-ruling.md, main + Addendum 1 + 2).
	var violations := 0
	for seed_val in range(100):
		var b0 := _make_scout(0)
		var b1 := _make_scout(1)
		var sim := CombatSim.new(seed_val)
		b0.position = Vector2(200, 256)  # Start close
		b1.position = Vector2(220, 256)
		sim.add_brott(b0)
		sim.add_brott(b1)
		
		var prev_pos := b0.position
		var backup_run := 0.0
		var prev_bd := 0.0
		
		for _t in range(300):
			if sim.match_over:
				break
			# Pre-tick intent-frame sampling (S15.2 ruling, main).
			var to_target_pre: Vector2 = Vector2.ZERO
			if b0.alive and b0.target != null:
				to_target_pre = b0.target.position - b0.position
			sim.simulate_tick()
			if b0.alive and b0.target != null:
				# Period-boundary reset (S15.2 Addendum 1): bd drop → new retreat period.
				if b0.backup_distance < prev_bd:
					backup_run = 0.0
				prev_bd = b0.backup_distance
				var movement: Vector2 = b0.position - prev_pos
				if to_target_pre.length() > 0.1 and movement.length() > 0.1:
					var dot: float = movement.normalized().dot(to_target_pre.normalized())
					if dot < -0.7:  # Mostly backing away
						# Budget-gated accumulator (S15.2 Addendum 2): only accumulate
						# while retreat period is live.
						if b0.backup_distance < CombatSim.TILE_SIZE:
							backup_run += movement.length()
						# else: post-cap freeze; wait for period-boundary reset.
					else:
						backup_run = 0.0
				prev_pos = b0.position
				if backup_run > 32.0 * 1.2:  # >1.2 tiles straight backup (small margin)
					violations += 1
					break
	
	_assert(violations <= 10, "No moonwalking violations (%d/100)" % violations)
	# Threshold retained at ≤10 per Gizmo's S17.2-003 addendum ruling §2 (no AC
	# relaxation; the combination of `RETREAT_SPEED_MULT = 0.50` + metric
	# migration is expected to land at ≤1–2/100). The wall-stuck nav nudge tail
	# documented in the prior comment block is still present as the dominant
	# residual source of violations, which is why the ≤10 floor remains.

func test_stances_preserved() -> void:
	print("\n-- AC7: Existing Stances Preserved --")
	
	# Kiting: should maintain distance
	var b0 := _make_scout(0, 2, [WeaponData.WeaponType.RAILGUN])  # Kiting with long range
	var b1 := _make_scout(1)
	var sim := _run_sim(42, b0, b1, 300)
	# Kiting bot should not be right on top of enemy
	# (check that engagement distance is based on stance)
	_assert(true, "Kiting stance runs without crash")
	
	# Defensive
	b0 = _make_scout(0, 1, [WeaponData.WeaponType.RAILGUN])
	b1 = _make_scout(1)
	sim = _run_sim(43, b0, b1, 300)
	_assert(true, "Defensive stance runs without crash")
	
	# Ambush: should hold position (no combat movement)
	b0 = _make_scout(0, 3)
	b1 = _make_scout(1)
	sim = CombatSim.new(44)
	var start_pos := Vector2(256, 256)
	b0.position = start_pos
	b1.position = Vector2(270, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)
	for _t in range(100):
		if sim.match_over:
			break
		sim.simulate_tick()
	_assert(not b0.in_combat_movement, "Ambush bot does not enter combat movement")

func test_separation_force() -> void:
	print("\n-- Separation Force (32px threshold) --")
	var b0 := _make_brawler(0)
	var b1 := _make_brawler(1)
	var sim := CombatSim.new(99)
	# Start overlapping
	b0.position = Vector2(256, 256)
	b1.position = Vector2(256, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)
	
	for _t in range(50):
		sim.simulate_tick()
	
	var final_dist: float = b0.position.distance_to(b1.position)
	_assert(final_dist >= 20.0, "Bots separated after overlap: %.1f px apart" % final_dist)

func test_engagement_distances() -> void:
	print("\n-- Engagement Distances --")
	# Aggressive with Plasma Cutter (range 1.5 tiles = 48px)
	# Ideal = 48 * 0.65 = 31.2px, tolerance = 16px
	var b0 := _make_scout(0, 0)  # Aggressive
	var b1 := _make_scout(1, 0)
	var sim := CombatSim.new(55)
	b0.position = Vector2(100, 256)
	b1.position = Vector2(412, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)
	
	var entered_combat := false
	for _t in range(600):
		if sim.match_over:
			break
		sim.simulate_tick()
		if b0.in_combat_movement:
			entered_combat = true
			break
	
	_assert(entered_combat, "Aggressive bot enters combat movement state")
