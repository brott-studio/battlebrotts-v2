## test_arena_renderer_multi.gd — S25.2 multi-bot + click overlay tests
##
## Covers:
## - BrottBrain override fields default state
## - set_target_override / clear_target_override
## - set_move_override / clear_move_override
## - Latest-wins arbitration: floor click clears target override; enemy click clears move override
## - evaluate() short-circuits with movement_override = "move_to_override" / "target_override"
##   when an override is active.
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	# T1: Default state.
	var brain := BrottBrain.new()
	if not (brain._override_target_id == -1):
		push_error("FAIL: target override default -1"); fail_count += 1
	else: pass_count += 1
	if not (brain._override_move_pos == Vector2.INF):
		push_error("FAIL: move override default INF"); fail_count += 1
	else: pass_count += 1

	# T2: set_target_override sets id and clears move override.
	brain.set_move_override(Vector2(50, 50))  # seed move first
	brain.set_target_override(3)
	if not (brain._override_target_id == 3):
		push_error("FAIL: set_target_override sets id"); fail_count += 1
	else: pass_count += 1
	if not (brain._override_move_pos == Vector2.INF):
		push_error("FAIL: set_target_override clears move"); fail_count += 1
	else: pass_count += 1

	# T3: set_move_override sets pos and clears target override.
	brain.set_move_override(Vector2(100, 200))
	if not (brain._override_move_pos == Vector2(100, 200)):
		push_error("FAIL: set_move_override sets pos"); fail_count += 1
	else: pass_count += 1
	if not (brain._override_target_id == -1):
		push_error("FAIL: set_move_override clears target"); fail_count += 1
	else: pass_count += 1

	# T4: clear methods.
	brain.clear_move_override()
	if not (brain._override_move_pos == Vector2.INF):
		push_error("FAIL: clear_move_override resets"); fail_count += 1
	else: pass_count += 1
	brain.set_target_override(7)
	brain.clear_target_override()
	if not (brain._override_target_id == -1):
		push_error("FAIL: clear_target_override resets"); fail_count += 1
	else: pass_count += 1

	# T5: Latest-wins arbitration via direct override calls.
	var brain2 := BrottBrain.new()
	brain2.set_target_override(1)
	if not (brain2._override_target_id == 1):
		push_error("FAIL: pre target set"); fail_count += 1
	else: pass_count += 1
	brain2.set_move_override(Vector2(300, 300))  # floor click
	if not (brain2._override_target_id == -1):
		push_error("FAIL: floor click clears target (latest-wins)"); fail_count += 1
	else: pass_count += 1
	if not (brain2._override_move_pos == Vector2(300, 300)):
		push_error("FAIL: floor click sets move"); fail_count += 1
	else: pass_count += 1

	# Inverse: move first, then enemy click clears it.
	brain2.set_move_override(Vector2(100, 100))
	brain2.set_target_override(0)
	if not (brain2._override_move_pos == Vector2.INF):
		push_error("FAIL: enemy click clears move (latest-wins)"); fail_count += 1
	else: pass_count += 1
	if not (brain2._override_target_id == 0):
		push_error("FAIL: enemy click sets target"); fail_count += 1
	else: pass_count += 1

	# T6: evaluate() short-circuits when override active.
	# Build a minimal brott + enemy that brain.evaluate can read.
	var brain3 := BrottBrain.new()
	var brott := BrottState.new()
	brott.team = 0
	brott.bot_name = "P"
	brott.chassis_type = ChassisData.ChassisType.SCOUT
	brott.position = Vector2(128, 128)
	brott.setup()
	var enemy := BrottState.new()
	enemy.team = 1
	enemy.bot_name = "E"
	enemy.chassis_type = ChassisData.ChassisType.SCOUT
	enemy.position = Vector2(256, 128)
	enemy.setup()

	# No override: movement_override stays "" after evaluate.
	brain3.evaluate(brott, enemy, 0.0)
	if not (brain3.movement_override == ""):
		push_error("FAIL: evaluate no-override leaves movement_override empty (got '%s')" % brain3.movement_override); fail_count += 1
	else: pass_count += 1

	# Move override: evaluate sets "move_to_override" and returns true.
	brain3.set_move_override(Vector2(200, 200))
	var fired1: bool = brain3.evaluate(brott, enemy, 0.0)
	if not fired1:
		push_error("FAIL: evaluate returns true on move override"); fail_count += 1
	else: pass_count += 1
	if not (brain3.movement_override == "move_to_override"):
		push_error("FAIL: move override sets movement_override='move_to_override' (got '%s')" % brain3.movement_override); fail_count += 1
	else: pass_count += 1

	# Target override: evaluate sets "target_override" and returns true.
	brain3.set_target_override(1)
	var fired2: bool = brain3.evaluate(brott, enemy, 0.0)
	if not fired2:
		push_error("FAIL: evaluate returns true on target override"); fail_count += 1
	else: pass_count += 1
	if not (brain3.movement_override == "target_override"):
		push_error("FAIL: target override sets movement_override='target_override' (got '%s')" % brain3.movement_override); fail_count += 1
	else: pass_count += 1

	print("test_arena_renderer_multi: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
