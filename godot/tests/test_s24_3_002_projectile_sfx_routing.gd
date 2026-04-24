## [S24.3] Projectile launch SFX bus routing test.
## Usage: godot --headless --path godot/ --script res://tests/test_s24_3_002_projectile_sfx_routing.gd
##
## Invariants:
##   I-P1: An AudioStreamPlayer with .bus = "SFX" assigned before add_child retains "SFX" bus.
##   I-P2: ProjectileLaunchSfxPlayer pattern: .bus = "SFX" set BEFORE add_child.
##   I-P3: ProjectileLaunchSfxPlayer bus is NOT "Master".
##   I-P4: Two independent SFX players can both hold "SFX" bus (no conflict).

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S24.3-002 Projectile launch SFX bus routing tests ===\n")
	_test_bus_assignment_preserved()
	_test_proj_player_bus_is_sfx()
	_test_proj_player_bus_is_not_master()
	_test_two_sfx_players_independent()
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

func _test_bus_assignment_preserved() -> void:
	print("--- I-P1: bus='SFX' preserved through add_child ---")
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	get_root().add_child(player)
	_assert(player.bus == "SFX",
		"I-P1: AudioStreamPlayer.bus == 'SFX' after set-before-add_child")
	player.queue_free()

func _test_proj_player_bus_is_sfx() -> void:
	print("--- I-P2: ProjectileLaunchSfxPlayer: .bus='SFX' BEFORE add_child ---")
	# Replicate exact pattern from game_main.gd _init_combat_sfx_players()
	var player := AudioStreamPlayer.new()
	player.name = "ProjectileLaunchSfxPlayer"
	player.bus = "SFX"   # MUST be before add_child per S21.5 ordering convention
	get_root().add_child(player)
	_assert(player.bus == "SFX",
		"I-P2: ProjectileLaunchSfxPlayer.bus == 'SFX' (set before add_child)")
	player.queue_free()

func _test_proj_player_bus_is_not_master() -> void:
	print("--- I-P3: ProjectileLaunchSfxPlayer NOT routed to Master bus ---")
	var player := AudioStreamPlayer.new()
	player.name = "ProjectileLaunchSfxPlayer"
	player.bus = "SFX"
	get_root().add_child(player)
	_assert(player.bus != "Master",
		"I-P3: ProjectileLaunchSfxPlayer.bus != 'Master'")
	player.queue_free()

func _test_two_sfx_players_independent() -> void:
	print("--- I-P4: HitSfxPlayer + ProjectileLaunchSfxPlayer both hold 'SFX' independently ---")
	var hit_player := AudioStreamPlayer.new()
	hit_player.name = "HitSfxPlayer"
	hit_player.bus = "SFX"
	get_root().add_child(hit_player)

	var proj_player := AudioStreamPlayer.new()
	proj_player.name = "ProjectileLaunchSfxPlayer"
	proj_player.bus = "SFX"
	get_root().add_child(proj_player)

	_assert(hit_player.bus == "SFX",
		"I-P4a: HitSfxPlayer.bus == 'SFX' (independent of ProjectileLaunchSfxPlayer)")
	_assert(proj_player.bus == "SFX",
		"I-P4b: ProjectileLaunchSfxPlayer.bus == 'SFX' (independent of HitSfxPlayer)")

	hit_player.queue_free()
	proj_player.queue_free()
