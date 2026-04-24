## S21.5 — Audio bus layout test
## Usage: godot --headless --path godot/ --script res://tests/test_s21_5_001_audio_bus_layout.gd
##
## Invariant I1: Audio bus layout has exactly 3 buses in order:
##   Master (bus 0, 0dB), SFX (bus 1, 0dB, send=Master), Music (bus 2, -6dB, send=Master).
##
## Strategy: load the bus layout resource directly and verify bus
## configuration via AudioServer after applying the layout.

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S21.5-001 Audio bus layout tests ===\n")
	_test_bus_layout()
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

func _assert_near(a: float, b: float, tol: float, msg: String) -> void:
	_assert(absf(a - b) <= tol, "%s (got %f, expected %f ± %f)" % [msg, a, b, tol])

func _test_bus_layout() -> void:
	print("--- I1: Audio bus layout ---")

	# Load and apply the bus layout resource.
	var layout_path := "res://default_bus_layout.tres"
	_assert(ResourceLoader.exists(layout_path), "default_bus_layout.tres exists at res://")

	var layout: AudioBusLayout = ResourceLoader.load(layout_path) as AudioBusLayout
	_assert(layout != null, "default_bus_layout.tres loads as AudioBusLayout")
	if layout == null:
		return

	AudioServer.set_bus_layout(layout)

	# I1: exactly 3 buses
	_assert_eq(AudioServer.bus_count, 3, "I1: bus_count == 3")

	# Bus 0: Master
	_assert_eq(AudioServer.get_bus_name(0), "Master", "I1: bus 0 name == Master")
	_assert_near(AudioServer.get_bus_volume_db(0), 0.0, 0.001, "I1: bus 0 volume == 0 dB")
	_assert_eq(AudioServer.get_bus_send(0), &"", "I1: bus 0 send == empty (no parent)")
	_assert(not AudioServer.is_bus_mute(0), "I1: bus 0 not muted by default")

	# Bus 1: SFX
	_assert_eq(AudioServer.get_bus_name(1), "SFX", "I1: bus 1 name == SFX")
	_assert_near(AudioServer.get_bus_volume_db(1), 0.0, 0.001, "I1: bus 1 volume == 0 dB")
	_assert_eq(AudioServer.get_bus_send(1), &"Master", "I1: bus 1 send == Master")

	# Bus 2: Music
	_assert_eq(AudioServer.get_bus_name(2), "Music", "I1: bus 2 name == Music")
	_assert_near(AudioServer.get_bus_volume_db(2), -6.0, 0.001, "I1: bus 2 volume == -6 dB")
	_assert_eq(AudioServer.get_bus_send(2), &"Master", "I1: bus 2 send == Master")
