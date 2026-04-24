## S21.5 — Audio assets presence test
## Usage: godot --headless --path godot/ --script res://tests/test_s21_5_002_audio_assets.gd
##
## Invariant I2: Two OGG assets present at res://assets/audio/sfx/:
##   win_chime.ogg and popup_whoosh.ogg.
##   Attribution log at res://assets/audio/sfx/ATTRIBUTION.md.

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S21.5-002 Audio asset presence tests ===\n")
	_test_assets_exist()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _test_assets_exist() -> void:
	print("--- I2: Asset presence ---")

	# OGG files
	var sfx_base := "res://assets/audio/sfx/"
	var win_chime_path := sfx_base + "win_chime.ogg"
	var popup_whoosh_path := sfx_base + "popup_whoosh.ogg"
	var attribution_path := sfx_base + "ATTRIBUTION.md"

	_assert(FileAccess.file_exists(win_chime_path), "I2: win_chime.ogg exists at " + win_chime_path)
	_assert(FileAccess.file_exists(popup_whoosh_path), "I2: popup_whoosh.ogg exists at " + popup_whoosh_path)
	_assert(FileAccess.file_exists(attribution_path), "I2: ATTRIBUTION.md exists at " + attribution_path)

	# Verify OGG files are non-empty (at least 1 KB)
	if FileAccess.file_exists(win_chime_path):
		var f := FileAccess.open(win_chime_path, FileAccess.READ)
		if f != null:
			_assert(f.get_length() > 1024, "I2: win_chime.ogg is non-trivial (> 1 KB)")
			f.close()

	if FileAccess.file_exists(popup_whoosh_path):
		var f := FileAccess.open(popup_whoosh_path, FileAccess.READ)
		if f != null:
			_assert(f.get_length() > 1024, "I2: popup_whoosh.ogg is non-trivial (> 1 KB)")
			f.close()

	# Verify ATTRIBUTION.md mentions both assets
	if FileAccess.file_exists(attribution_path):
		var f := FileAccess.open(attribution_path, FileAccess.READ)
		if f != null:
			var content := f.get_as_text()
			f.close()
			_assert(content.contains("win_chime"), "I2: ATTRIBUTION.md mentions win_chime")
			_assert(content.contains("popup_whoosh"), "I2: ATTRIBUTION.md mentions popup_whoosh")

	# Verify .import metadata files exist (Godot requires them for project import)
	_assert(FileAccess.file_exists(win_chime_path + ".import"), "I2: win_chime.ogg.import exists")
	_assert(FileAccess.file_exists(popup_whoosh_path + ".import"), "I2: popup_whoosh.ogg.import exists")
