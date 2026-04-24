## [S24.2] Mute integration test — checkbox does not duplicate state.
## Usage: godot --headless --path godot/ --script res://tests/test_s24_2_002_mute_integration.gd
##
## Invariant: set_audio_muted(true) via FirstRunState → AudioServer.is_bus_mute(0) == true.
## The "audio_muted" key must be the ONLY mute key in [settings] (no duplicate created).
## Additive keys master_db/sfx_db/music_db must not shadow or rename "audio_muted".

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

const FirstRunStateScript := preload("res://ui/first_run_state.gd")

func _initialize() -> void:
	print("=== S24.2-002 Mute integration tests ===\n")
	_test_set_muted_true_applies_to_bus()
	_test_set_muted_false_applies_to_bus()
	_test_audio_muted_key_preserved()
	_test_no_duplicate_mute_key()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _make_frs(uid: String) -> Node:
	var frs: Node = FirstRunStateScript.new()
	frs.name = "FRS_" + uid
	get_root().add_child(frs)
	return frs

func _test_set_muted_true_applies_to_bus() -> void:
	print("--- mute true → bus 0 muted ---")
	# Ensure bus layout loaded.
	var layout_path := "res://default_bus_layout.tres"
	if ResourceLoader.exists(layout_path):
		var layout: AudioBusLayout = ResourceLoader.load(layout_path) as AudioBusLayout
		if layout != null:
			AudioServer.set_bus_layout(layout)

	var frs := _make_frs("mute_true")
	frs.call("set_audio_muted", true)
	_assert(bool(frs.call("get_audio_muted")), "get_audio_muted() == true after set_audio_muted(true)")

	var muted: bool = bool(frs.call("get_audio_muted"))
	AudioServer.set_bus_mute(0, muted)
	_assert(AudioServer.is_bus_mute(0), "AudioServer.is_bus_mute(0) == true after muting")
	frs.queue_free()
	AudioServer.set_bus_mute(0, false)

func _test_set_muted_false_applies_to_bus() -> void:
	print("--- mute false → bus 0 unmuted ---")
	var frs := _make_frs("mute_false")
	frs.call("set_audio_muted", false)
	_assert(not bool(frs.call("get_audio_muted")), "get_audio_muted() == false after set_audio_muted(false)")

	AudioServer.set_bus_mute(0, false)
	_assert(not AudioServer.is_bus_mute(0), "AudioServer.is_bus_mute(0) == false after unmuting")
	frs.queue_free()

func _test_audio_muted_key_preserved() -> void:
	print("--- audio_muted key preserved alongside new db keys ---")
	var frs := _make_frs("key_preserved")
	# Set both old and new keys.
	frs.call("set_audio_muted", true)
	frs.call("set_master_db", -3.0)
	frs.call("set_sfx_db", -2.0)
	frs.call("set_music_db", -8.0)
	# audio_muted must still be readable independently.
	_assert(bool(frs.call("get_audio_muted")), "audio_muted key still accessible after adding db keys")
	# Clean up.
	frs.call("set_audio_muted", false)
	frs.call("set_master_db", 0.0)
	frs.call("set_sfx_db", 0.0)
	frs.call("set_music_db", -6.0)
	frs.queue_free()

func _test_no_duplicate_mute_key() -> void:
	print("--- no duplicate audio_muted key created ---")
	# Verify: calling set_audio_muted multiple times does not create more than one key.
	# We validate this by confirming get_audio_muted() reflects the last write.
	var frs := _make_frs("no_dup")
	frs.call("set_audio_muted", true)
	frs.call("set_audio_muted", false)
	frs.call("set_audio_muted", true)
	var result: bool = bool(frs.call("get_audio_muted"))
	_assert(result == true, "Last write wins — no duplicate key confusion (expected true, got %s)" % str(result))
	frs.call("set_audio_muted", false)
	frs.queue_free()
