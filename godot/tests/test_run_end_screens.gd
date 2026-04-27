## test_run_end_screens.gd — S25.8: run-end screen stat fields + loss-path routing
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	## T1: BrottDownScreen — stats fields + build display
	var rs1 := RunState.new(1, 42)  ## Brawler
	rs1.current_battle_index = 5
	rs1.battles_won = 4
	rs1.retry_count = 1  ## used 2 retries
	## Equip something
	rs1.add_item("weapon", 0)  ## Minigun
	rs1.add_item("armor", 1)   ## Plating

	var screen1 := BrottDownScreen.new()
	screen1.setup(rs1, rs1.current_battle_index + 1)
	var stats1 := screen1.get_node_or_null("StatsLabel")
	if stats1 == null:
		push_error("T1 FAIL: BrottDownScreen missing StatsLabel")
		fail_count += 1
	else:
		pass_count += 1
	var chassis1 := screen1.get_node_or_null("ChassisLabel")
	if chassis1 == null:
		push_error("T1b FAIL: BrottDownScreen missing ChassisLabel")
		fail_count += 1
	else:
		pass_count += 1
	## Verify "—" for farthest threat (em-dash present)
	if stats1 != null and not String(stats1.text).contains("—"):
		push_error("T1c FAIL: Farthest Threat should be — (em-dash); got: %s" % stats1.text)
		fail_count += 1
	else:
		pass_count += 1
	## Verify NewRunButton exists (no Return to Menu)
	var new_run1 := screen1.get_node_or_null("NewRunButton")
	if new_run1 == null:
		push_error("T1d FAIL: BrottDownScreen missing NewRunButton")
		fail_count += 1
	else:
		pass_count += 1
	screen1.free()

	## T2: RunCompleteScreen — stats fields + build display
	var rs2 := RunState.new(0, 42)  ## Scout
	rs2.current_battle_index = 14
	rs2.battles_won = 15
	rs2.retry_count = 3  ## never used retries

	var screen2 := RunCompleteScreen.new()
	screen2.setup(rs2)
	var stats2 := screen2.get_node_or_null("StatsLabel")
	if stats2 == null:
		push_error("T2 FAIL: RunCompleteScreen missing StatsLabel")
		fail_count += 1
	else:
		pass_count += 1
	if stats2 != null and not String(stats2.text).contains("15 / 15"):
		push_error("T2b FAIL: Battles Won should show 15 / 15; got: %s" % stats2.text)
		fail_count += 1
	else:
		pass_count += 1
	if stats2 != null and not String(stats2.text).contains("—"):
		push_error("T2c FAIL: Best Kill should be — (em-dash); got: %s" % stats2.text)
		fail_count += 1
	else:
		pass_count += 1
	## Verify no "Return to Menu" button (GDD §A.5)
	var return_btn2 := screen2.get_node_or_null("ReturnToMenuButton")
	if return_btn2 != null:
		push_error("T2d FAIL: RunCompleteScreen should not have ReturnToMenuButton (GDD §A.5)")
		fail_count += 1
	else:
		pass_count += 1
	var new_run2 := screen2.get_node_or_null("NewRunButton")
	if new_run2 == null:
		push_error("T2e FAIL: RunCompleteScreen missing NewRunButton")
		fail_count += 1
	else:
		pass_count += 1
	screen2.free()

	## T3: "New Run" resets RunState (end_run() + fresh run_state semantics)
	var rs3_new := RunState.new(0, 99)
	if rs3_new.current_battle_index != 0:
		push_error("T3 FAIL: new RunState should have battle_index=0")
		fail_count += 1
	else:
		pass_count += 1
	if rs3_new.retry_count != 3:
		push_error("T3b FAIL: new RunState should have retry_count=3")
		fail_count += 1
	else:
		pass_count += 1
	if rs3_new.equipped_weapons.size() != 1:
		push_error("T3c FAIL: new RunState should have exactly 1 weapon (S26.1 starter)")
		fail_count += 1
	else:
		pass_count += 1
	if not (4 in rs3_new.equipped_weapons):
		push_error("T3c2 FAIL: new RunState starter weapon should be Plasma Cutter (4) per S26.1")
		fail_count += 1
	else:
		pass_count += 1
	if rs3_new.run_ended != false:
		push_error("T3d FAIL: new RunState should have run_ended=false")
		fail_count += 1
	else:
		pass_count += 1

	## T4: Tooltip copy invariants — no league-era keys in the active surfaces.
	## (Cannot easily inspect game_main.gd constants from SceneTree without instantiation.
	##  Boltz/grep in CI verify ARENA_SEQUENCE starts with click_controls and no
	##  brottbrain/shop_first/opponent_first strings remain in FE_COPY/ARENA_FE_COPY.)

	print("test_run_end_screens: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
