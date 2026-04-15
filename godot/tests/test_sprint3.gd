## Sprint 3 test suite — UI flow wiring, screen transitions, cover trigger
## Usage: godot --headless --script tests/test_sprint3.gd
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _init() -> void:
	print("=== BattleBrotts Sprint 3 Test Suite ===\n")
	
	_test_game_flow_initial_screen()
	_test_game_flow_new_game_goes_to_shop()
	_test_game_flow_screen_transitions()
	_test_game_flow_brottbrain_skip_when_locked()
	_test_game_flow_brottbrain_available_when_unlocked()
	_test_game_flow_match_result_updates_state()
	_test_game_flow_continue_from_result_loops()
	_test_game_flow_opponent_selection()
	_test_cover_trigger_near_pillar()
	_test_cover_trigger_far_from_pillar()
	_test_cover_trigger_dead_enemy()
	_test_cover_trigger_exact_boundary()
	_test_main_scene_is_game_main()
	_test_all_screen_classes_exist()
	
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	
	if fail_count > 0:
		quit(1)
	else:
		quit(0)

func assert_eq(a: Variant, b: Variant, msg: String) -> void:
	test_count += 1
	if a == b:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %s, expected %s)" % [msg, str(a), str(b)])

func assert_true(val: bool, msg: String) -> void:
	test_count += 1
	if val:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (expected true)" % [msg])

func assert_false(val: bool, msg: String) -> void:
	test_count += 1
	if not val:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (expected false)" % [msg])

# --- Flow tests ---

func _test_game_flow_initial_screen() -> void:
	print("test_game_flow_initial_screen")
	var gf := GameFlow.new()
	assert_eq(gf.current_screen, GameFlow.Screen.MAIN_MENU, "initial screen is MAIN_MENU")

func _test_game_flow_new_game_goes_to_shop() -> void:
	print("test_game_flow_new_game_goes_to_shop")
	var gf := GameFlow.new()
	gf.new_game()
	assert_eq(gf.current_screen, GameFlow.Screen.SHOP, "new_game → SHOP")

func _test_game_flow_screen_transitions() -> void:
	print("test_game_flow_screen_transitions")
	var gf := GameFlow.new()
	gf.new_game()
	assert_eq(gf.current_screen, GameFlow.Screen.SHOP, "after new_game → SHOP")
	gf.go_to_loadout()
	assert_eq(gf.current_screen, GameFlow.Screen.LOADOUT, "go_to_loadout → LOADOUT")
	gf.go_to_opponent_select()
	assert_eq(gf.current_screen, GameFlow.Screen.OPPONENT_SELECT, "go_to_opponent_select → OPPONENT_SELECT")

func _test_game_flow_brottbrain_skip_when_locked() -> void:
	print("test_game_flow_brottbrain_skip_when_locked")
	var gf := GameFlow.new()
	gf.new_game()
	# BrottBrain is locked in Scrapyard
	assert_false(gf.game_state.brottbrain_unlocked, "brain locked in Scrapyard")
	gf.go_to_brottbrain()
	assert_eq(gf.current_screen, GameFlow.Screen.OPPONENT_SELECT, "skip brain → OPPONENT_SELECT")

func _test_game_flow_brottbrain_available_when_unlocked() -> void:
	print("test_game_flow_brottbrain_available_when_unlocked")
	var gf := GameFlow.new()
	gf.new_game()
	gf.game_state.brottbrain_unlocked = true
	gf.go_to_brottbrain()
	assert_eq(gf.current_screen, GameFlow.Screen.BROTTBRAIN_EDITOR, "brain unlocked → BROTTBRAIN_EDITOR")

func _test_game_flow_match_result_updates_state() -> void:
	print("test_game_flow_match_result_updates_state")
	var gf := GameFlow.new()
	gf.new_game()
	gf.select_opponent(0)
	assert_eq(gf.current_screen, GameFlow.Screen.ARENA, "select_opponent → ARENA")
	gf.finish_match(true)
	assert_true(gf.last_match_won, "last_match_won is true")
	assert_true(gf.last_bolts_earned > 0, "earned bolts on win")
	assert_eq(gf.current_screen, GameFlow.Screen.RESULT, "finish_match → RESULT")

func _test_game_flow_continue_from_result_loops() -> void:
	print("test_game_flow_continue_from_result_loops")
	var gf := GameFlow.new()
	gf.new_game()
	gf.select_opponent(0)
	gf.finish_match(true)
	gf.continue_from_result()
	assert_eq(gf.current_screen, GameFlow.Screen.SHOP, "continue_from_result → SHOP (loop)")

func _test_game_flow_opponent_selection() -> void:
	print("test_game_flow_opponent_selection")
	var gf := GameFlow.new()
	gf.new_game()
	gf.select_opponent(2)
	assert_eq(gf.selected_opponent_index, 2, "opponent index stored")
	assert_eq(gf.current_screen, GameFlow.Screen.ARENA, "select_opponent → ARENA")

# --- Helper ---

func _make_brott(team: int, chassis: int) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.chassis_type = chassis
	b.weapon_types = [WeaponData.WeaponType.MINIGUN]
	b.armor_type = ArmorData.ArmorType.PLATING
	b.position = Vector2(128, 128)
	b.setup()
	return b

func _cover_card() -> BrottBrain.BehaviorCard:
	return BrottBrain.BehaviorCard.new(BrottBrain.Trigger.WHEN_THEYRE_IN_COVER, 0, BrottBrain.Action.SWITCH_STANCE, 1)

# --- Cover trigger tests ---

func _test_cover_trigger_near_pillar() -> void:
	print("test_cover_trigger_near_pillar")
	var brain := BrottBrain.new()
	brain.add_card(_cover_card())
	var brott := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	# Pillar at (176, 176) — place enemy right there
	enemy.position = Vector2(176, 176)
	var fired := brain.evaluate(brott, enemy, 0.0)
	assert_true(fired, "enemy near pillar triggers cover card")

func _test_cover_trigger_far_from_pillar() -> void:
	print("test_cover_trigger_far_from_pillar")
	var brain := BrottBrain.new()
	brain.add_card(_cover_card())
	var brott := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	enemy.position = Vector2(256, 256)  # center, far from all pillars
	var fired := brain.evaluate(brott, enemy, 0.0)
	assert_false(fired, "enemy at center does not trigger cover card")

func _test_cover_trigger_dead_enemy() -> void:
	print("test_cover_trigger_dead_enemy")
	var brain := BrottBrain.new()
	brain.add_card(_cover_card())
	var brott := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	enemy.position = Vector2(176, 176)  # near pillar
	enemy.alive = false
	var fired := brain.evaluate(brott, enemy, 0.0)
	assert_false(fired, "dead enemy cannot trigger cover card")

func _test_cover_trigger_exact_boundary() -> void:
	print("test_cover_trigger_exact_boundary")
	var brain := BrottBrain.new()
	brain.add_card(_cover_card())
	var brott := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	var enemy := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	# Pillar at (176, 176), place enemy exactly 48px away on X axis
	enemy.position = Vector2(176 + 48, 176)
	var fired := brain.evaluate(brott, enemy, 0.0)
	assert_true(fired, "enemy at exactly 48px from pillar triggers cover (<=)")

# --- Scene config tests ---

func _test_main_scene_is_game_main() -> void:
	print("test_main_scene_is_game_main")
	var cfg := ConfigFile.new()
	var err := cfg.load("res://project.godot")
	assert_eq(err, OK, "project.godot loads")
	var main_scene: String = cfg.get_value("application", "run/main_scene", "")
	assert_eq(main_scene, "res://game_main.tscn", "main scene is game_main.tscn")

func _test_all_screen_classes_exist() -> void:
	print("test_all_screen_classes_exist")
	# Verify all screen scripts can be loaded
	var screens := [
		"res://ui/main_menu_screen.gd",
		"res://ui/shop_screen.gd",
		"res://ui/loadout_screen.gd",
		"res://ui/brottbrain_screen.gd",
		"res://ui/opponent_select_screen.gd",
		"res://ui/result_screen.gd",
		"res://arena/arena_renderer.gd",
		"res://game_main.gd",
		"res://game/game_flow.gd",
	]
	for path in screens:
		var script = load(path)
		assert_true(script != null, "script exists: %s" % path)
