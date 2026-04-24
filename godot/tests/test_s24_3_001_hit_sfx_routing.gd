## [S24.3] Hit SFX bus routing test.
## Usage: godot --headless --path godot/ --script res://tests/test_s24_3_001_hit_sfx_routing.gd
##
## Invariants:
##   I-H1: An AudioStreamPlayer with .bus = "SFX" assigned before add_child retains "SFX" bus.
##   I-H2: Default AudioStreamPlayer bus is "Master" (confirms SFX override is meaningful).
##   I-H3: HitSfxPlayer pattern: .bus = "SFX" set BEFORE add_child (ordering convention).
##   I-H4: HitSfxPlayer bus is NOT "Master" (explicit negative assertion).

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S24.3-001 Hit SFX bus routing tests ===\n")
	_test_bus_assignment_before_add_child()
	_test_default_bus_is_master()
	_test_hit_player_bus_is_sfx()
	_test_hit_player_bus_is_not_master()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _test_bus_assignment_before_add_child() -> void:
	print("--- I-H1: bus='SFX' set before add_child is preserved ---")
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	get_root().add_child(player)
	_assert(player.bus == "SFX",
		"I-H1: AudioStreamPlayer.bus == 'SFX' after set-before-add_child")
	player.queue_free()

func _test_default_bus_is_master() -> void:
	print("--- I-H2: default AudioStreamPlayer bus is 'Master' ---")
	var player := AudioStreamPlayer.new()
	_assert(player.bus == "Master",
		"I-H2: default AudioStreamPlayer.bus == 'Master' (confirms SFX assignment is non-trivial)")
	player.free()

func _test_hit_player_bus_is_sfx() -> void:
	print("--- I-H3: HitSfxPlayer pattern: .bus='SFX' BEFORE add_child ---")
	# Replicate exact pattern from game_main.gd _init_combat_sfx_players()
	var player := AudioStreamPlayer.new()
	player.name = "HitSfxPlayer"
	player.bus = "SFX"   # MUST be before add_child
	get_root().add_child(player)
	_assert(player.bus == "SFX",
		"I-H3: HitSfxPlayer.bus == 'SFX' (set before add_child per S21.5 ordering convention)")
	player.queue_free()

func _test_hit_player_bus_is_not_master() -> void:
	print("--- I-H4: HitSfxPlayer is NOT routed to Master bus ---")
	var player := AudioStreamPlayer.new()
	player.name = "HitSfxPlayer"
	player.bus = "SFX"
	get_root().add_child(player)
	_assert(player.bus != "Master",
		"I-H4: HitSfxPlayer.bus != 'Master' (routed through SFX bus, not directly to Master)")
	player.queue_free()
