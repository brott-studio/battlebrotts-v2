## test_multi_target_ai.gd — S25.4 Multi-target AI priority + archetype data tests
extends SceneTree

## Helper: build a minimal BrottState at a position with given hp.
func _make_brott(team: int, pos: Vector2, hp_pct: float = 1.0) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.chassis_type = 1  # Brawler
	b.setup()
	b.position = pos
	b.hp = b.max_hp * hp_pct
	return b

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	## ─── T1: targets nearest in 1v3 (no melee) ────────────────────────
	var brain1 := BrottBrain.default_for_chassis(1)
	var brott1 := _make_brott(0, Vector2(0, 0))
	var e1a := _make_brott(1, Vector2(200, 0))   # 200px
	var e1b := _make_brott(1, Vector2(80, 0))    # 80px (nearest non-melee)
	var e1c := _make_brott(1, Vector2(150, 0))   # 150px
	brain1.set_enemies_context([e1a, e1b, e1c])
	brain1.evaluate(brott1, e1a, 0.0)
	if brott1.target != e1b:
		push_error("T1 FAIL: nearest non-melee should win (got dist=%f)" % (brott1.position.distance_to(brott1.target.position) if brott1.target != null else -1.0))
		fail_count += 1
	else:
		pass_count += 1

	## ─── T2: equidistant picks lower HP ───────────────────────────────
	var brain2 := BrottBrain.default_for_chassis(1)
	var brott2 := _make_brott(0, Vector2(0, 0))
	var e2a := _make_brott(1, Vector2(100, 0), 1.0)   # full HP
	var e2b := _make_brott(1, Vector2(0, 100), 0.4)   # equidistant, lower HP
	brain2.set_enemies_context([e2a, e2b])
	brain2.evaluate(brott2, e2a, 0.0)
	if brott2.target != e2b:
		push_error("T2 FAIL: equidistant should pick lower-HP (target.hp=%d, expected=%d)" % [brott2.target.hp if brott2.target != null else -1, int(e2b.hp)])
		fail_count += 1
	else:
		pass_count += 1

	## ─── T3a: melee-adjacent: closest melee wins among multiple melee ─
	var brain3 := BrottBrain.default_for_chassis(1)
	var brott3 := _make_brott(0, Vector2(0, 0))
	var e3a := _make_brott(1, Vector2(30, 0))   # 30px (melee)
	var e3b := _make_brott(1, Vector2(15, 0))   # 15px (melee, closer)
	brain3.set_enemies_context([e3a, e3b])
	brain3.evaluate(brott3, e3a, 0.0)
	if brott3.target != e3b:
		push_error("T3a FAIL: closest melee should win (expected 15px, got dist=%f)" % (brott3.position.distance_to(brott3.target.position) if brott3.target != null else -1.0))
		fail_count += 1
	else:
		pass_count += 1

	## ─── T3b: melee beats non-melee even if non-melee is "closer to origin sense" — actually
	## the rule is: if any enemy is in melee, melee wins. Test: A=100px (non-melee), B=45px (melee).
	## B wins because melee-priority cascade fires first.
	var brain3b := BrottBrain.default_for_chassis(1)
	var brott3b := _make_brott(0, Vector2(0, 0))
	var e3ba := _make_brott(1, Vector2(100, 0))  # not melee
	var e3bb := _make_brott(1, Vector2(45, 0))   # melee (within 48)
	brain3b.set_enemies_context([e3ba, e3bb])
	brain3b.evaluate(brott3b, e3ba, 0.0)
	if brott3b.target != e3bb:
		push_error("T3b FAIL: melee should beat non-melee")
		fail_count += 1
	else:
		pass_count += 1

	## ─── T4: player click-override beats melee ────────────────────────
	## The override short-circuit lives at the top of evaluate() and returns
	## before the multi-target cascade runs. brott.target is therefore NOT
	## set by the brain in this path; combat_sim consumes the override.
	## This test asserts that movement_override == "target_override" and
	## _override_target_id is preserved (not clobbered by cascade).
	var brain4 := BrottBrain.default_for_chassis(1)
	var brott4 := _make_brott(0, Vector2(0, 0))
	var e4a := _make_brott(1, Vector2(30, 0))   # melee — would win cascade
	var e4b := _make_brott(1, Vector2(200, 0))  # far — but is the click-override target
	brain4.set_target_override(1)  # index 1 = e4b in our context array
	brain4.set_enemies_context([e4a, e4b])
	brain4.evaluate(brott4, e4a, 0.0)
	if brain4.movement_override != "target_override" or brain4._override_target_id != 1:
		push_error("T4 FAIL: click-override should short-circuit (movement_override='%s', _override_target_id=%d)" % [brain4.movement_override, brain4._override_target_id])
		fail_count += 1
	else:
		pass_count += 1

	## ─── T5: counter-build anti_module ────────────────────────────────
	var rs5 := RunState.new()
	rs5.equipped_modules = [0, 1, 2]
	rs5.equipped_weapons = [4]
	var v5 := OpponentLoadouts._select_counter_build_variant(rs5)
	if v5 != "anti_module":
		push_error("T5 FAIL: 3 modules → anti_module (got '%s')" % v5)
		fail_count += 1
	else:
		pass_count += 1

	## ─── T6: counter-build anti_range ─────────────────────────────────
	var rs6 := RunState.new()
	rs6.equipped_modules = [0]
	rs6.equipped_weapons = [1]  # Railgun
	var v6 := OpponentLoadouts._select_counter_build_variant(rs6)
	if v6 != "anti_range":
		push_error("T6 FAIL: Railgun primary → anti_range (got '%s')" % v6)
		fail_count += 1
	else:
		pass_count += 1

	## ─── T7: counter-build anti_melee ─────────────────────────────────
	var rs7 := RunState.new()
	rs7.equipped_modules = []
	rs7.equipped_weapons = [2]  # Shotgun
	var v7 := OpponentLoadouts._select_counter_build_variant(rs7)
	if v7 != "anti_melee":
		push_error("T7 FAIL: Shotgun primary → anti_melee (got '%s')" % v7)
		fail_count += 1
	else:
		pass_count += 1

	## ─── T8: archetype templates complete ─────────────────────────────
	var expected_ids := ["standard_duel", "small_swarm", "large_swarm", "miniboss_escorts", "counter_build_elite", "glass_cannon_blitz", "boss", "brawler_rush"]
	var templates := OpponentLoadouts.ARCHETYPE_TEMPLATES
	var t8_ok := true
	if templates.size() != 8:
		t8_ok = false
	else:
		var actual_ids := []
		for t in templates:
			actual_ids.append(t["id"])
		for eid in expected_ids:
			if not (eid in actual_ids):
				t8_ok = false
				break
	if not t8_ok:
		push_error("T8 FAIL: ARCHETYPE_TEMPLATES should have 8 records with locked IDs (got size=%d)" % templates.size())
		fail_count += 1
	else:
		pass_count += 1

	## ─── T9: empty context guard ──────────────────────────────────────
	var brain9 := BrottBrain.default_for_chassis(1)
	var brott9 := _make_brott(0, Vector2(0, 0))
	brain9.set_enemies_context([])
	brain9.evaluate(brott9, null, 0.0)
	if brott9.target != null or brain9.movement_override != "":
		push_error("T9 FAIL: empty context + null enemy should leave target null (target=%s, override='%s')" % [str(brott9.target), brain9.movement_override])
		fail_count += 1
	else:
		pass_count += 1

	print("test_multi_target_ai: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
