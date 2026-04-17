## Debug harness: per-seed moonwalk trace for Scout vs Scout close-quarters.
##
## Usage:
##   godot --headless --path godot --script tests/harness/debug_moonwalk.gd [-- seed=N]
##
## Prints one line per simulated tick for the requested seed (default: scan all
## 100 seeds and report which ones violate the `test_away_juke_cap_across_seeds`
## bar). Each line shows: tick, b0 position, movement length, dot(movement,
## to_target), rolling backup_run, TCR phase, `backup_distance` budget,
## `_unstick_timer`. Violation threshold matches the test: `backup_run >
## 32.0 * 1.2` with `dot < -0.7` as the backward-tick gate.
##
## Intended as a turnkey repro for future moonwalk regressions. See
## docs/kb/juke-bypass-movement-caps.md and PR #80 for context.
extends SceneTree

func _make_scout(team: int) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.bot_name = "Scout_%d" % team
	b.chassis_type = ChassisData.ChassisType.SCOUT
	b.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.stance = 0
	b.setup()
	return b

func _scan_all_seeds() -> void:
	print("=== Moonwalk seed scan (0..99) ===")
	var violation_count := 0
	for seed_val in range(100):
		var b0 := _make_scout(0)
		var b1 := _make_scout(1)
		var sim := CombatSim.new(seed_val)
		b0.position = Vector2(200, 256)
		b1.position = Vector2(220, 256)
		sim.add_brott(b0)
		sim.add_brott(b1)
		var prev_pos := b0.position
		var backup_run := 0.0
		var prev_bd := 0.0
		var max_run := 0.0
		var violated_tick := -1
		for t in range(300):
			if sim.match_over:
				break
			# Pre-tick sampling per S15.2 ruling (intent frame).
			var tt_pre: Vector2 = Vector2.ZERO
			if b0.alive and b0.target != null:
				tt_pre = b0.target.position - b0.position
			sim.simulate_tick()
			if b0.alive and b0.target != null:
				# Period-boundary reset (S15.2 addendum): bd drop = new retreat period.
				if b0.backup_distance < prev_bd:
					backup_run = 0.0
				prev_bd = b0.backup_distance
				var mv: Vector2 = b0.position - prev_pos
				if tt_pre.length() > 0.1 and mv.length() > 0.1:
					var dot: float = mv.normalized().dot(tt_pre.normalized())
					if dot < -0.7:
						backup_run += mv.length()
						if backup_run > max_run: max_run = backup_run
					else:
						backup_run = 0.0
				prev_pos = b0.position
				if backup_run > 32.0 * 1.2 and violated_tick < 0:
					violated_tick = t
		if violated_tick >= 0:
			violation_count += 1
			print("seed=%d violated_at_tick=%d max_run=%.1f" % [seed_val, violated_tick, max_run])
	print("=== Total violations: %d/100 ===" % violation_count)

func _trace_seed(seed_val: int) -> void:
	print("=== Moonwalk trace seed=%d ===" % seed_val)
	var b0 := _make_scout(0)
	var b1 := _make_scout(1)
	var sim := CombatSim.new(seed_val)
	b0.position = Vector2(200, 256)
	b1.position = Vector2(220, 256)
	sim.add_brott(b0)
	sim.add_brott(b1)
	var prev_pos := b0.position
	var backup_run := 0.0
	var prev_bd := 0.0
	for t in range(120):
		if sim.match_over:
			break
		# Pre-tick sampling per S15.2 ruling (intent frame).
		var tt_pre: Vector2 = Vector2.ZERO
		if b0.alive and b0.target != null:
			tt_pre = b0.target.position - b0.position
		sim.simulate_tick()
		if not (b0.alive and b0.target != null):
			continue
		# Period-boundary reset (S15.2 addendum): bd drop = new retreat period.
		if b0.backup_distance < prev_bd:
			backup_run = 0.0
		prev_bd = b0.backup_distance
		var mv: Vector2 = b0.position - prev_pos
		var dot := 0.0
		if tt_pre.length() > 0.1 and mv.length() > 0.1:
			dot = mv.normalized().dot(tt_pre.normalized())
			if dot < -0.7:
				backup_run += mv.length()
			else:
				backup_run = 0.0
		print("t=%d b0=(%.1f,%.1f) b1=(%.1f,%.1f) mv=%.2f dot=%.2f run=%.1f phase=%d bd=%.1f unstick=%.1f" % [
			t, b0.position.x, b0.position.y, b0.target.position.x, b0.target.position.y,
			mv.length(), dot, backup_run, b0.combat_phase, b0.backup_distance, b0._unstick_timer])
		prev_pos = b0.position

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_arg: int = -1
	for a in args:
		if a.begins_with("seed="):
			seed_arg = int(a.substr(5))
	if seed_arg >= 0:
		_trace_seed(seed_arg)
	else:
		_scan_all_seeds()
	quit()
