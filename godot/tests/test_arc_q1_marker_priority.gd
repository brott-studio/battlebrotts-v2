## test_arc_q1_marker_priority.gd — Arc Q.1: Full marker priority on click-to-move.
##
## Gates:
##   Q1-1: _kiting resets to false when move_to_override is active
##   Q1-2: brott.stance resets to _default_stance during override
##   Q1-3: bot moves at base_speed (max) during override, not kite-reduced speed
##   Q1-4: kite state resumes correctly after override clears
extends SceneTree

var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	print("=== test_arc_q1_marker_priority ===\n")
	_test_q1_1_kiting_reset_during_override()
	_test_q1_2_stance_reset_during_override()
	_test_q1_3_speed_at_base_during_override()
	_test_q1_4_kite_resumes_after_override_clears()
	print("\n=== Results: %d passed, %d failed ===" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _make_sim_with_kiting_bot() -> Array:
	## Create a sim where the player bot is a Scout (default kite stance) and
	## the enemy is a Brawler. Scout starts at low HP so _kiting fires naturally.
	var sim := CombatSim.new(42)

	var player := BrottState.new()
	player.team = 0
	player.bot_name = "Player"
	player.chassis_type = ChassisData.ChassisType.SCOUT
	player.weapon_types.append(WeaponData.WeaponType.PLASMA_CUTTER)
	player.armor_type = ArmorData.ArmorType.NONE
	player.setup()
	player.position = Vector2(256.0, 256.0)
	player.brain = BrottBrain.default_for_chassis(0)  ## Scout: _default_stance=2
	## Seed low HP so kite hysteresis triggers immediately (hp_pct <= 0.30)
	player.hp = float(player.max_hp) * 0.20
	sim.add_brott(player)

	var enemy := BrottState.new()
	enemy.team = 1
	enemy.bot_name = "Enemy"
	enemy.chassis_type = ChassisData.ChassisType.BRAWLER
	enemy.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	enemy.armor_type = ArmorData.ArmorType.NONE
	enemy.setup()
	enemy.position = Vector2(500.0, 256.0)
	enemy.brain = BrottBrain.default_for_chassis(1)
	sim.add_brott(enemy)

	return [sim, player, enemy]

## ── Q1-1: _kiting resets to false during move override ───────────────────────
func _test_q1_1_kiting_reset_during_override() -> void:
	print("--- Q1-1: _kiting resets to false during move_to_override ---")
	var parts := _make_sim_with_kiting_bot()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]

	## Run 2 ticks to let brain evaluate and arm _kiting=true (hp <= 30%)
	sim.simulate_tick()
	sim.simulate_tick()
	_assert(player.brain._kiting == true, "pre-override: _kiting armed at low HP")

	## Set move override
	player.brain.set_move_override(Vector2(9000.0, 256.0))
	_assert(player.brain._override_move_pos != Vector2.INF, "override armed")

	## Run one tick — brain should reset _kiting during override path
	sim.simulate_tick()
	_assert(player.brain._kiting == false, "during override: _kiting == false")
	_assert(player.brain.movement_override == "move_to_override", "during override: movement_override == 'move_to_override'")

## ── Q1-2: stance resets to _default_stance during override ───────────────────
func _test_q1_2_stance_reset_during_override() -> void:
	print("--- Q1-2: brott.stance resets to _default_stance during move override ---")
	var parts := _make_sim_with_kiting_bot()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]

	## Let kite arm naturally (2 ticks, low HP)
	sim.simulate_tick()
	sim.simulate_tick()
	_assert(player.stance == 2, "pre-override: stance == 2 (kiting)")

	## Set move override and run one tick
	player.brain.set_move_override(Vector2(9000.0, 256.0))
	sim.simulate_tick()

	## Scout _default_stance == 2, but _kiting==false means the stance is driven
	## by _default_stance not kite. For Scout _default_stance IS 2 — so confirm
	## the kite flag is cleared (not the stance number which coincides for Scout).
	## Use a Brawler-default brain to distinguish: inject brain with _default_stance=0.
	var brain2 := BrottBrain.new()
	brain2._default_stance = 0
	brain2._kiting = true
	## Manually call evaluate to exercise the early-return reset
	var dummy_enemy := BrottState.new()
	dummy_enemy.team = 1
	dummy_enemy.bot_name = "DummyEnemy"
	dummy_enemy.chassis_type = ChassisData.ChassisType.BRAWLER
	dummy_enemy.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	dummy_enemy.armor_type = ArmorData.ArmorType.NONE
	dummy_enemy.setup()
	dummy_enemy.position = Vector2(400.0, 256.0)

	var dummy_brott := BrottState.new()
	dummy_brott.team = 0
	dummy_brott.bot_name = "Dummy"
	dummy_brott.chassis_type = ChassisData.ChassisType.BRAWLER
	dummy_brott.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	dummy_brott.armor_type = ArmorData.ArmorType.NONE
	dummy_brott.setup()
	dummy_brott.position = Vector2(256.0, 256.0)
	dummy_brott.stance = 2  ## kiting was active
	dummy_brott.brain = brain2
	dummy_brott.target = dummy_enemy

	brain2.set_move_override(Vector2(9000.0, 256.0))
	brain2.evaluate(dummy_brott, dummy_enemy, 0.0)

	_assert(brain2._kiting == false, "evaluate with override: _kiting cleared to false")
	_assert(dummy_brott.stance == 0, "evaluate with override: stance reset to _default_stance (0)")

## ── Q1-3: bot accelerates toward base_speed during override ─────────────────
func _test_q1_3_speed_at_base_during_override() -> void:
	print("--- Q1-3: bot accelerates toward base_speed during override, not a reduced speed ---")
	var parts := _make_sim_with_kiting_bot()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]

	## Position bot close to a distant waypoint so speed ramps
	player.position = Vector2(100.0, 256.0)
	var waypoint := Vector2(9000.0, 256.0)
	player.brain.set_move_override(waypoint)

	## Record base speed
	var expected_max_speed: float = player.base_speed
	_assert(expected_max_speed > 0.0, "player base_speed > 0")

	## Run 15 ticks to let speed ramp
	for _i in range(15):
		sim.simulate_tick()

	## Speed should be at or near base_speed (within accel tolerance)
	## During a long run to a distant waypoint, bot should reach max speed.
	_assert(player.current_speed >= expected_max_speed * 0.8,
		"after 15 ticks of override: current_speed >= 80%% of base_speed (%.1f >= %.1f)" % [player.current_speed, expected_max_speed * 0.8])

## ── Q1-4: kite state resumes correctly after override clears ─────────────────
func _test_q1_4_kite_resumes_after_override_clears() -> void:
	print("--- Q1-4: kite state resumes after override clears ---")
	## Use a fresh Brawler with low HP (so kite would arm) but _default_stance=0
	var sim := CombatSim.new(99)

	var player := BrottState.new()
	player.team = 0
	player.bot_name = "Player"
	player.chassis_type = ChassisData.ChassisType.BRAWLER
	player.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	player.armor_type = ArmorData.ArmorType.NONE
	player.setup()
	player.position = Vector2(256.0, 256.0)
	player.brain = BrottBrain.default_for_chassis(1)  ## Brawler: _default_stance=0
	player.hp = float(player.max_hp) * 0.20  ## low HP — kite will arm
	sim.add_brott(player)

	var enemy := BrottState.new()
	enemy.team = 1
	enemy.bot_name = "Enemy"
	enemy.chassis_type = ChassisData.ChassisType.SCOUT
	enemy.weapon_types.append(WeaponData.WeaponType.PLASMA_CUTTER)
	enemy.armor_type = ArmorData.ArmorType.NONE
	enemy.setup()
	enemy.position = Vector2(500.0, 256.0)
	enemy.brain = BrottBrain.default_for_chassis(0)
	## Give enemy god-mode HP so it doesn't die early
	enemy.hp = 99999.0
	enemy.max_hp = 99999
	sim.add_brott(enemy)

	## Let kite arm
	sim.simulate_tick()
	sim.simulate_tick()
	_assert(player.brain._kiting == true, "pre-override: kite armed")

	## Move override near-enough that it clears quickly
	player.brain.set_move_override(player.position + Vector2(64.0, 0.0))
	## Seed _override_move_initial_dist so arrival check works
	for _i in range(10):
		sim.simulate_tick()
		if player.brain._override_move_pos == Vector2.INF:
			break

	## Override should have cleared
	_assert(player.brain._override_move_pos == Vector2.INF, "override cleared after arrival")

	## Run a few more ticks — kite should re-arm (low HP, no override)
	for _i in range(5):
		sim.simulate_tick()
	_assert(player.brain._kiting == true, "after override clears: kite re-arms at low HP")
