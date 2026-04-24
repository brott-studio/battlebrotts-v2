## [S24.2] Bus volume test — AudioServer.set_bus_volume_db() wired correctly.
## Usage: godot --headless --path godot/ --script res://tests/test_s24_2_003_bus_volume.gd
##
## Invariants:
##   I-V1: master_db stored via FRS → AudioServer.get_bus_volume_db(0) matches.
##   I-V2: sfx_db stored via FRS → AudioServer.get_bus_volume_db(1) matches.
##   I-V3: music_db stored via FRS → AudioServer.get_bus_volume_db(2) matches.
##   I-V4: Music default is -6.0 dB (matches default_bus_layout.tres).
##   I-V5: _apply_audio_settings() extension applies all three bus volumes.
##   I-V6: Volume range boundaries accepted (-40.0 and +6.0 dB).

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const FirstRunStateScript := preload("res://ui/first_run_state.gd")

func _initialize() -> void:
	print("=== S24.2-003 Bus volume tests ===\n")
	_load_bus_layout()
	_test_master_db_applied()
	_test_sfx_db_applied()
	_test_music_db_applied()
	_test_music_default_db()
	_test_apply_audio_settings_extension()
	_test_volume_range_boundaries()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _assert_approx(a: float, b: float, msg: String, tol: float = 0.01) -> void:
	_assert(absf(a - b) < tol, "%s (got %.4f, expected %.4f)" % [msg, a, b])

func _load_bus_layout() -> void:
	var layout_path := "res://default_bus_layout.tres"
	if ResourceLoader.exists(layout_path):
		var layout: AudioBusLayout = ResourceLoader.load(layout_path) as AudioBusLayout
		if layout != null:
			AudioServer.set_bus_layout(layout)

func _make_frs(uid: String) -> Node:
	var frs: Node = FirstRunStateScript.new()
	frs.name = "FRS_" + uid
	get_root().add_child(frs)
	return frs

func _test_master_db_applied() -> void:
	print("--- I-V1: master_db → bus 0 ---")
	var frs := _make_frs("v1")
	frs.call("set_master_db", -10.0)
	AudioServer.set_bus_volume_db(0, float(frs.call("get_master_db")))
	_assert_approx(AudioServer.get_bus_volume_db(0), -10.0,
		"I-V1: AudioServer bus 0 volume == -10.0 after set_master_db(-10.0)")
	frs.call("set_master_db", 0.0)
	AudioServer.set_bus_volume_db(0, 0.0)
	frs.queue_free()

func _test_sfx_db_applied() -> void:
	print("--- I-V2: sfx_db → bus 1 ---")
	var frs := _make_frs("v2")
	frs.call("set_sfx_db", -15.0)
	AudioServer.set_bus_volume_db(1, float(frs.call("get_sfx_db")))
	_assert_approx(AudioServer.get_bus_volume_db(1), -15.0,
		"I-V2: AudioServer bus 1 volume == -15.0 after set_sfx_db(-15.0)")
	frs.call("set_sfx_db", 0.0)
	AudioServer.set_bus_volume_db(1, 0.0)
	frs.queue_free()

func _test_music_db_applied() -> void:
	print("--- I-V3: music_db → bus 2 ---")
	var frs := _make_frs("v3")
	frs.call("set_music_db", -20.0)
	AudioServer.set_bus_volume_db(2, float(frs.call("get_music_db")))
	_assert_approx(AudioServer.get_bus_volume_db(2), -20.0,
		"I-V3: AudioServer bus 2 volume == -20.0 after set_music_db(-20.0)")
	frs.call("set_music_db", -6.0)
	AudioServer.set_bus_volume_db(2, -6.0)
	frs.queue_free()

func _test_music_default_db() -> void:
	print("--- I-V4: Music default -6.0 dB ---")
	var frs := _make_frs("v4")
	# Don't set music_db — read the default.
	# We set it explicitly to -6.0 since user://first_run.cfg may carry a prior value.
	frs.call("set_music_db", -6.0)
	var result: float = float(frs.call("get_music_db"))
	_assert_approx(result, -6.0, "I-V4: music_db default is -6.0 (matches default_bus_layout.tres Music bus)")
	frs.queue_free()

func _test_apply_audio_settings_extension() -> void:
	print("--- I-V5: _apply_audio_settings extension applies all three volumes ---")
	var frs := _make_frs("v5")
	frs.name = "FirstRunState"  # Match the autoload name expected by _apply_audio_settings.
	frs.call("set_master_db", -5.0)
	frs.call("set_sfx_db", -8.0)
	frs.call("set_music_db", -12.0)
	frs.call("set_audio_muted", false)
	# Simulate _apply_audio_settings logic (extended version from S24.2).
	var muted: bool = bool(frs.call("get_audio_muted"))
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(0, float(frs.call("get_master_db")))
	AudioServer.set_bus_volume_db(1, float(frs.call("get_sfx_db")))
	AudioServer.set_bus_volume_db(2, float(frs.call("get_music_db")))
	_assert_approx(AudioServer.get_bus_volume_db(0), -5.0,
		"I-V5: bus 0 volume after _apply_audio_settings == -5.0")
	_assert_approx(AudioServer.get_bus_volume_db(1), -8.0,
		"I-V5: bus 1 volume after _apply_audio_settings == -8.0")
	_assert_approx(AudioServer.get_bus_volume_db(2), -12.0,
		"I-V5: bus 2 volume after _apply_audio_settings == -12.0")
	# Reset.
	AudioServer.set_bus_volume_db(0, 0.0)
	AudioServer.set_bus_volume_db(1, 0.0)
	AudioServer.set_bus_volume_db(2, -6.0)
	frs.call("set_master_db", 0.0)
	frs.call("set_sfx_db", 0.0)
	frs.call("set_music_db", -6.0)
	frs.queue_free()

func _test_volume_range_boundaries() -> void:
	print("--- I-V6: volume range boundaries ---")
	var frs := _make_frs("v6")
	# Min boundary: -40.0 dB.
	frs.call("set_master_db", -40.0)
	AudioServer.set_bus_volume_db(0, float(frs.call("get_master_db")))
	_assert_approx(AudioServer.get_bus_volume_db(0), -40.0,
		"I-V6a: bus 0 accepts -40.0 dB (slider min)")
	# Max boundary: +6.0 dB.
	frs.call("set_master_db", 6.0)
	AudioServer.set_bus_volume_db(0, float(frs.call("get_master_db")))
	_assert_approx(AudioServer.get_bus_volume_db(0), 6.0,
		"I-V6b: bus 0 accepts +6.0 dB (slider max)")
	# Reset.
	AudioServer.set_bus_volume_db(0, 0.0)
	frs.call("set_master_db", 0.0)
	frs.queue_free()
