## [S24.3] SFX asset existence test.
## Usage: godot --headless --path godot/ --script res://tests/test_s24_3_003_sfx_assets.gd
##
## Invariants:
##   I-A1: hit.ogg exists at res://assets/audio/sfx/hit.ogg
##   I-A2: projectile_launch.ogg exists at res://assets/audio/sfx/projectile_launch.ogg
##   I-A3: ATTRIBUTION.md exists at res://assets/audio/sfx/ATTRIBUTION.md (non-empty)
##   I-A4: Existing S21.5 asset popup_whoosh.ogg is preserved (not deleted or replaced)
##   I-A5: Existing S21.5 asset win_chime.ogg is preserved

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S24.3-003 SFX asset existence tests ===\n")
	_test_hit_ogg_exists()
	_test_projectile_launch_ogg_exists()
	_test_attribution_md_exists()
	_test_popup_whoosh_preserved()
	_test_win_chime_preserved()
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

func _test_hit_ogg_exists() -> void:
	print("--- I-A1: hit.ogg exists ---")
	_assert(FileAccess.file_exists("res://assets/audio/sfx/hit.ogg"),
		"I-A1: res://assets/audio/sfx/hit.ogg exists (S24.3 combat hit SFX asset)")

func _test_projectile_launch_ogg_exists() -> void:
	print("--- I-A2: projectile_launch.ogg exists ---")
	_assert(FileAccess.file_exists("res://assets/audio/sfx/projectile_launch.ogg"),
		"I-A2: res://assets/audio/sfx/projectile_launch.ogg exists (S24.3 projectile launch SFX asset)")

func _test_attribution_md_exists() -> void:
	print("--- I-A3: ATTRIBUTION.md exists and is non-empty ---")
	var path := "res://assets/audio/sfx/ATTRIBUTION.md"
	var exists := FileAccess.file_exists(path)
	_assert(exists, "I-A3a: ATTRIBUTION.md exists at res://assets/audio/sfx/ATTRIBUTION.md")
	if exists:
		var f := FileAccess.open(path, FileAccess.READ)
		var size := f.get_length()
		f.close()
		_assert(size > 0, "I-A3b: ATTRIBUTION.md is non-empty (size > 0 bytes)")
	else:
		# If file doesn't exist, add a failing assertion for the size check too.
		_assert(false, "I-A3b: ATTRIBUTION.md is non-empty (skipped — file missing)")

func _test_popup_whoosh_preserved() -> void:
	print("--- I-A4: S21.5 popup_whoosh.ogg preserved ---")
	_assert(FileAccess.file_exists("res://assets/audio/sfx/popup_whoosh.ogg"),
		"I-A4: res://assets/audio/sfx/popup_whoosh.ogg preserved (S21.5 asset, must not be replaced)")

func _test_win_chime_preserved() -> void:
	print("--- I-A5: S21.5 win_chime.ogg preserved ---")
	_assert(FileAccess.file_exists("res://assets/audio/sfx/win_chime.ogg"),
		"I-A5: res://assets/audio/sfx/win_chime.ogg preserved (S21.5 asset, must not be replaced)")
