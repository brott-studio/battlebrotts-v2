## test_arc_p1_click_persist.gd — Arc P.1: click-to-move override persists beyond tick window.
##
## Gates:
##   P1-1: after 26+ ticks override is still active (move_to_override, not cleared)
##   P1-2: ticks clamp at 0, do not go negative
##   P1-3: arrival (clear_move_override) still works correctly
##   P1-4: new click still resets counter to 25 (latest-wins, unchanged)
extends SceneTree

var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	print("=== test_arc_p1_click_persist ===\n")
	_test_p1_1_override_persists_past_25_ticks()
	_test_p1_2_ticks_clamp_at_zero()
	_test_p1_3_arrival_clears_override()
	_test_p1_4_new_click_resets_counter()
	print("\n=== Results: %d passed, %d failed ===" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _make_sim_with_player_and_enemy() -> Array:
	var sim := CombatSim.new(1)

	var player := BrottState.new()
	player.team = 0
	player.bot_name = "Player"
	player.chassis_type = ChassisData.ChassisType.BRAWLER
	player.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	player.armor_type = ArmorData.ArmorType.NONE
	player.setup()
	player.position = Vector2(256.0, 256.0)
	player.brain = BrottBrain.default_for_chassis(1)
	sim.add_brott(player)

	var enemy := BrottState.new()
	enemy.team = 1
	enemy.bot_name = "Enemy"
	enemy.chassis_type = ChassisData.ChassisType.SCOUT
	enemy.weapon_types.append(WeaponData.WeaponType.PLASMA_CUTTER)
	enemy.armor_type = ArmorData.ArmorType.NONE
	enemy.setup()
	enemy.position = Vector2(500.0, 256.0)
	enemy.brain = BrottBrain.new()
	sim.add_brott(enemy)

	return [sim, player, enemy]

## ── P1-1: override persists past 25-tick window ─────────────────────────────
func _test_p1_1_override_persists_past_25_ticks() -> void:
	print("--- P1-1: override persists past 25-tick window ---")
	var parts := _make_sim_with_player_and_enemy()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]

	## Place waypoint far enough that movement alone won't clear it
	var waypoint := Vector2(9000.0, 256.0)
	player.brain.set_move_override(waypoint)
	_assert(player.brain._override_ticks_remaining == 25, "pre-tick: counter == 25")

	## Run 30 ticks (5 beyond the old 25-tick expiry)
	for _i in range(30):
		sim.simulate_tick()

	## Override must still be active — not cleared by tick expiry
	_assert(player.brain._override_move_pos != Vector2.INF, "after 30 ticks: _override_move_pos still set (not INF)")
	_assert(player.brain.movement_override == "move_to_override", "after 30 ticks: movement_override == 'move_to_override'")

## ── P1-2: ticks clamp at 0, do not go negative ──────────────────────────────
func _test_p1_2_ticks_clamp_at_zero() -> void:
	print("--- P1-2: ticks clamp at 0, never negative ---")
	var parts := _make_sim_with_player_and_enemy()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]

	var waypoint := Vector2(9000.0, 256.0)
	player.brain.set_move_override(waypoint)

	## Run 50 ticks — well past the 25-tick window
	for _i in range(50):
		sim.simulate_tick()

	_assert(player.brain._override_ticks_remaining == 0, "after 50 ticks: counter clamped at 0 (not negative)")
	_assert(player.brain._override_move_pos != Vector2.INF, "after 50 ticks: override still live")

## ── P1-3: arrival clears override correctly ──────────────────────────────────
func _test_p1_3_arrival_clears_override() -> void:
	print("--- P1-3: clear_move_override() still works correctly ---")
	var brain := BrottBrain.new()
	brain.set_move_override(Vector2(100.0, 200.0))
	_assert(brain._override_move_pos != Vector2.INF, "pre-clear: override set")

	brain.clear_move_override()
	_assert(brain._override_move_pos == Vector2.INF, "post-clear: _override_move_pos == INF")
	_assert(brain._override_ticks_remaining == 0, "post-clear: _override_ticks_remaining == 0")

## ── P1-4: new click resets counter to 25 (latest-wins) ──────────────────────
func _test_p1_4_new_click_resets_counter() -> void:
	print("--- P1-4: new click resets counter to 25 ---")
	var parts := _make_sim_with_player_and_enemy()
	var sim: CombatSim = parts[0]
	var player: BrottState = parts[1]

	player.brain.set_move_override(Vector2(9000.0, 256.0))

	## Run 10 ticks — counter at 15
	for _i in range(10):
		sim.simulate_tick()
	_assert(player.brain._override_ticks_remaining == 15, "after 10 ticks: counter == 15")

	## New click — counter resets to 25
	player.brain.set_move_override(Vector2(9001.0, 300.0))
	_assert(player.brain._override_ticks_remaining == 25, "after second click: counter reset to 25")

	## Run 5 more — counter at 20
	for _i in range(5):
		sim.simulate_tick()
	_assert(player.brain._override_ticks_remaining == 20, "after 5 ticks from reset: counter == 20")
