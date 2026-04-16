## Sprint 10 test suite — Bot separation, battle sim validation
## Usage: godot --headless --script tests/test_sprint10.gd
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0
var _hit_count := 0

const CombatSim = preload("res://combat/combat_sim.gd")
const BrottData = preload("res://combat/brott_data.gd")

func _init() -> void:
	print("=== BattleBrotts Sprint 10 Test Suite ===\n")

	test_stalemate_detection()
	test_bot_separation()
	test_hit_rate()
	test_match_resolution()

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

func _make_aggressive_bot(team: int) -> Dictionary:
	return {
		"name": "TestBot%d" % team,
		"hp": 100,
		"max_hp": 100,
		"armor_dr": 0,
		"speed": 3.0,
		"weapons": [{"type": "plasma_cutter", "damage": 10, "cooldown": 5, "range": 80.0, "projectile_speed": 200.0}],
		"stance": 0,  # Aggressive
		"team": team,
		"modules": [],
		"chassis": "standard"
	}

func _create_sim(seed_val: int = 0) -> Object:
	var sim = CombatSim.new()
	sim.rng_seed = seed_val
	sim.setup([_make_aggressive_bot(0)], [_make_aggressive_bot(1)])
	return sim

func test_stalemate_detection() -> void:
	print("\n-- Stalemate Detection --")
	var sim = _create_sim(42)
	var positions: Array[Vector2] = []
	for tick in range(300):
		sim.tick()
		if tick % 50 == 0:
			if sim.brotts.size() > 0 and sim.brotts[0].alive:
				positions.append(sim.brotts[0].position)
	# Check position variance — bots should have moved
	if positions.size() >= 2:
		var moved := false
		for i in range(1, positions.size()):
			if positions[i].distance_to(positions[0]) > 1.0:
				moved = true
				break
		_assert(moved, "Bots moved during 300-tick sim (not stuck)")
	else:
		_assert(false, "Not enough position samples collected")

func test_bot_separation() -> void:
	print("\n-- Bot Separation --")
	var sim = _create_sim(42)
	var min_dist := 99999.0
	for tick in range(300):
		sim.tick()
		# Check all living bot pairs
		for i in range(sim.brotts.size()):
			if not sim.brotts[i].alive:
				continue
			for j in range(i + 1, sim.brotts.size()):
				if not sim.brotts[j].alive:
					continue
				var d := sim.brotts[i].position.distance_to(sim.brotts[j].position)
				if d < min_dist:
					min_dist = d
	_assert(min_dist >= 12.0, "Min bot distance %.1f >= BOT_HITBOX_RADIUS (12.0)" % min_dist)

func _on_damage(_a, _b, _c, _d) -> void:
	_hit_count += 1

func test_hit_rate() -> void:
	print("\n-- Hit Rate --")
	var sim = _create_sim(42)
	_hit_count = 0
	if sim.has_signal("on_damage"):
		sim.on_damage.connect(_on_damage)
	for tick in range(300):
		sim.tick()
	_assert(_hit_count > 0, "Hits occurred during 300-tick sim (%d hits)" % _hit_count)

func test_match_resolution() -> void:
	print("\n-- Match Resolution --")
	var resolved := 0
	for seed_val in range(10):
		var sim = _create_sim(seed_val)
		var finished := false
		for tick in range(900):
			sim.tick()
			if sim.is_match_over():
				finished = true
				break
		if finished:
			resolved += 1
	_assert(resolved >= 5, "Match resolution: %d/10 resolved before 900 ticks (need >= 5)" % resolved)
