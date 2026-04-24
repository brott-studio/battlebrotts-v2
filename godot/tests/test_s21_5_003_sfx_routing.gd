## S21.5 — SFX bus routing test
## Usage: godot --headless --path godot/ --script res://tests/test_s21_5_003_sfx_routing.gd
##
## Invariant I3: Both SFX AudioStreamPlayer nodes explicitly route to bus "SFX"
##   (not "Master", not default).
##
## Strategy: instantiate ResultScreen with victory state to trigger WinChimePlayer,
## and instantiate GameMain to trigger PopupWhooshPlayer via _play_popup_whoosh().
## Query AudioStreamPlayer.bus on both.

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const ResultScreenScript := preload("res://ui/result_screen.gd")
const GameMainScript := preload("res://game_main.gd")

func _initialize() -> void:
	print("=== S21.5-003 SFX bus routing tests ===\n")
	_test_win_chime_routes_to_sfx()
	_test_popup_whoosh_routes_to_sfx()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _assert_eq(a: Variant, b: Variant, msg: String) -> void:
	_assert(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])

## Test 1: WinChimePlayer routes to SFX bus.
## Instantiate ResultScreen, call setup() with won=true (using a minimal GameState).
## After setup(), find WinChimePlayer among children and verify bus == "SFX".
func _test_win_chime_routes_to_sfx() -> void:
	print("--- I3a: WinChimePlayer bus == SFX ---")

	var rs: Control = ResultScreenScript.new()
	rs.name = "ResultScreen"
	get_root().add_child(rs)

	# Minimal GameState — only requires .bolts, .bronze_unlocked, .brottbrain_unlocked,
	# .current_league, .opponents_beaten fields used by _build_ui().
	var gs := GameState.new()
	rs.setup(gs, true, 50)

	# Find WinChimePlayer among children.
	var player: AudioStreamPlayer = null
	for child in rs.get_children():
		if child is AudioStreamPlayer and child.name == "WinChimePlayer":
			player = child
			break

	_assert(player != null, "I3a: WinChimePlayer node created on victory setup")
	if player != null:
		_assert_eq(player.bus, &"SFX", "I3a: WinChimePlayer.bus == SFX")

	rs.queue_free()

## Test 2: PopupWhooshPlayer routes to SFX bus.
## Instantiate GameMain, call _play_popup_whoosh() directly, verify bus == "SFX".
func _test_popup_whoosh_routes_to_sfx() -> void:
	print("--- I3b: PopupWhooshPlayer bus == SFX ---")

	var gm: Node2D = GameMainScript.new()
	gm.name = "GameMain"
	get_root().add_child(gm)

	# Call _play_popup_whoosh() directly to create the player node.
	gm.call("_play_popup_whoosh")

	# Find PopupWhooshPlayer.
	var player: AudioStreamPlayer = gm.get_node_or_null("PopupWhooshPlayer")

	_assert(player != null, "I3b: PopupWhooshPlayer node created after _play_popup_whoosh")
	if player != null:
		_assert_eq(player.bus, &"SFX", "I3b: PopupWhooshPlayer.bus == SFX")

	gm.queue_free()
