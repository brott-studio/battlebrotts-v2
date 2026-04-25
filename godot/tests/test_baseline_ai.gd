## test_baseline_ai.gd — S25.3 Hardcoded baseline AI tests
extends SceneTree

## Helper: build a minimal BrottState
func _make_brott(chassis: int, hp_pct: float, modules: Array = []) -> BrottState:
	var b := BrottState.new()
	b.team = 0
	b.chassis_type = chassis
	for m in modules:
		b.module_types.append(m)
	b.setup()
	b.hp = b.max_hp * hp_pct
	return b

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	## T1: Advance semantics — no override, stance = default
	var brain1 := BrottBrain.default_for_chassis(1)  # Brawler, default_stance=0
	var brott1 := _make_brott(1, 1.0)
	var enemy1 := _make_brott(1, 1.0)
	enemy1.team = 1
	brain1.evaluate(brott1, enemy1, 0.0)
	if not (brott1.stance == 0 and brain1.movement_override == ""):
		push_error("T1 FAIL: advance should be stance-0, empty override (got stance=%d, override='%s')" % [brott1.stance, brain1.movement_override])
		fail_count += 1
	else:
		pass_count += 1

	## T2: Kite threshold — HP drops to 0.29, should set _kiting=true, stance=2
	var brain2 := BrottBrain.default_for_chassis(1)
	var brott2 := _make_brott(1, 0.29)
	var enemy2 := _make_brott(1, 1.0); enemy2.team = 1
	brain2.evaluate(brott2, enemy2, 0.0)
	if not (brain2._kiting == true and brott2.stance == 2):
		push_error("T2 FAIL: should kite at 0.29 HP (got _kiting=%s, stance=%d)" % [str(brain2._kiting), brott2.stance])
		fail_count += 1
	else:
		pass_count += 1

	## T3: Kite recovery — HP recovers to 0.41, should clear kite
	brain2._kiting = true
	brott2.hp = brott2.max_hp * 0.41
	brain2.evaluate(brott2, enemy2, 0.0)
	if not (brain2._kiting == false and brott2.stance == 0):
		push_error("T3 FAIL: should stop kiting at 0.41 HP (got _kiting=%s, stance=%d)" % [str(brain2._kiting), brott2.stance])
		fail_count += 1
	else:
		pass_count += 1

	## T4: Hysteresis no-flicker — HP oscillates 0.28↔0.32, kiting stays true
	var brain4 := BrottBrain.default_for_chassis(1)
	brain4._kiting = false
	var brott4 := _make_brott(1, 0.28)
	var enemy4 := _make_brott(1, 1.0); enemy4.team = 1
	brain4.evaluate(brott4, enemy4, 0.0)  # drops to kiting
	var flicker := false
	for i in range(10):
		brott4.hp = brott4.max_hp * (0.28 if i % 2 == 0 else 0.32)
		brain4.evaluate(brott4, enemy4, float(i) * 0.1)
		if not brain4._kiting:
			flicker = true
			break
	if flicker:
		push_error("T4 FAIL: kiting should not flicker between 0.28-0.32")
		fail_count += 1
	else:
		pass_count += 1

	## T5: Repair Nanites auto-fire at HP < 0.40
	var brain5 := BrottBrain.new()
	var brott5 := _make_brott(1, 0.35, [ModuleData.ModuleType.REPAIR_NANITES])
	var enemy5 := _make_brott(1, 1.0); enemy5.team = 1
	brain5.evaluate(brott5, enemy5, 0.0)
	if brott5._pending_gadget != "Repair Nanites":
		push_error("T5 FAIL: Repair Nanites should auto-fire at HP 0.35 (got '%s')" % brott5._pending_gadget)
		fail_count += 1
	else:
		pass_count += 1

	## T6: EMP auto-fire when enemy has active module
	var brain6 := BrottBrain.new()
	var brott6 := _make_brott(1, 0.8, [ModuleData.ModuleType.EMP_CHARGE])
	var enemy6 := _make_brott(1, 1.0, [ModuleData.ModuleType.SHIELD_PROJECTOR]); enemy6.team = 1
	# Simulate active module on enemy
	if enemy6.module_active_timers.size() > 0:
		enemy6.module_active_timers[0] = 5.0  # mark as active
	brain6.evaluate(brott6, enemy6, 0.0)
	if brott6._pending_gadget != "EMP Charge":
		push_error("T6 FAIL: EMP should auto-fire when enemy has active module (got '%s')" % brott6._pending_gadget)
		fail_count += 1
	else:
		pass_count += 1

	## T7: Afterburner fires when kiting
	var brain7 := BrottBrain.new()
	brain7._kiting = false
	var brott7 := _make_brott(2, 0.25, [ModuleData.ModuleType.AFTERBURNER]); brott7.team = 0
	var enemy7 := _make_brott(1, 1.0); enemy7.team = 1
	brain7.evaluate(brott7, enemy7, 0.0)  # HP 0.25 triggers kite
	if brott7._pending_gadget != "Afterburner":
		push_error("T7 FAIL: Afterburner should fire when kiting (got '%s')" % brott7._pending_gadget)
		fail_count += 1
	else:
		pass_count += 1

	## T8: Module priority — Repair wins when all conditions met
	var brain8 := BrottBrain.new()
	var brott8 := _make_brott(1, 0.35, [
		ModuleData.ModuleType.REPAIR_NANITES,
		ModuleData.ModuleType.EMP_CHARGE,
		ModuleData.ModuleType.AFTERBURNER
	])
	brain8._kiting = true
	var enemy8 := _make_brott(1, 1.0, [ModuleData.ModuleType.SHIELD_PROJECTOR]); enemy8.team = 1
	if enemy8.module_active_timers.size() > 0:
		enemy8.module_active_timers[0] = 5.0
	brain8.evaluate(brott8, enemy8, 0.0)
	if brott8._pending_gadget != "Repair Nanites":
		push_error("T8 FAIL: Repair should win priority over EMP+Afterburner (got '%s')" % brott8._pending_gadget)
		fail_count += 1
	else:
		pass_count += 1

	## T9: Public API smoke test
	var brain9 := BrottBrain.default_for_chassis(0)
	if not (brain9 is BrottBrain and brain9.has_method("evaluate") and
		"movement_override" in brain9 and "weapon_mode" in brain9 and
		"target_priority" in brain9):
		push_error("T9 FAIL: BrottBrain public API incomplete")
		fail_count += 1
	else:
		pass_count += 1

	print("test_baseline_ai: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
