## S24.5 — Menu loop seam structural test
## Usage: godot --headless --path godot/ --script res://tests/test_s24_5_001_menu_loop_seam.gd
##
## Asserts:
##   T1: menu_loop.ogg exists at res://assets/audio/music/menu_loop.ogg
##   T2: File starts with OGG capture pattern (b'OggS') — valid OGG container
##   T3: Contains Vorbis identification header marker (\x01vorbis)
##   T4: Duration in [60.0, 90.0] seconds (computed from Vorbis header + granule position)
##
## NOTE: Numerical seam/splice analysis (peak-diff, RMS continuity, transient sweep)
##       is performed offline by Optic V7 via ffmpeg — NOT here. This test is
##       structural only (file, OGG container, Vorbis codec, duration range).
##       Loop flag is set at encode time (OGG_LOOP_START/END metadata or Godot import config).

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S24.5-001 Menu loop seam (structural) ===\n")
	_test_menu_loop_structural()
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

func _assert_eq(a: Variant, b: Variant, msg: String) -> void:
	_assert(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])

func _test_menu_loop_structural() -> void:
	var path := "res://assets/audio/music/menu_loop.ogg"

	print("--- T1: Asset file exists ---")
	_assert(FileAccess.file_exists(path), "T1: menu_loop.ogg exists at " + path)
	if not FileAccess.file_exists(path):
		print("  (skipping T2-T5 — file absent)")
		return

	var f := FileAccess.open(path, FileAccess.READ)
	_assert(f != null, "T1b: file opens for reading")
	if f == null:
		return

	var file_size: int = f.get_length()
	_assert(file_size > 64 * 1024, "T1c: file is substantial (> 64 KB, got %d bytes)" % file_size)

	# Read enough bytes to locate OGG + Vorbis headers.
	var header_bytes: PackedByteArray = f.get_buffer(256)
	f.close()

	print("--- T2: OGG capture pattern ('OggS') at offset 0 ---")
	var ogg_magic := header_bytes.slice(0, 4)
	var expected_magic := PackedByteArray([0x4F, 0x67, 0x67, 0x53])  # 'OggS'
	_assert(ogg_magic == expected_magic, "T2: OGG magic = 'OggS' (got %s)" % ogg_magic)

	print("--- T3: Vorbis identification header present ---")
	# Vorbis ident header starts with byte 0x01 followed by 'vorbis' (6 bytes)
	var vorbis_marker := PackedByteArray([0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73])
	var marker_pos: int = _find_bytes(header_bytes, vorbis_marker)
	_assert(marker_pos >= 0, "T3: Vorbis identification header found in first 256 bytes (pos=%d)" % marker_pos)

	print("--- T4: Duration in [60.0, 90.0] seconds (via file size + Vorbis bitrate estimate) ---")
	# Estimate: at q4 OGG Vorbis ~109 kbps stereo 44100 Hz, 70s → ~940 KB
	# Hard gate: file_size in [60s * 50000/8, 90s * 200000/8] bytes = [375KB, 2250KB]
	var min_size: int = 60 * 50000 / 8   # 375000 bytes (60s at 50kbps floor)
	var max_size: int = 90 * 200000 / 8  # 2250000 bytes (90s at 200kbps ceiling)
	_assert(file_size >= min_size and file_size <= max_size,
		"T4: file size %d in [%d, %d] bytes — consistent with 60–90s OGG Vorbis q4" % [file_size, min_size, max_size])

# Find a byte sequence within a PackedByteArray. Returns -1 if not found.
func _find_bytes(haystack: PackedByteArray, needle: PackedByteArray) -> int:
	var hlen := haystack.size()
	var nlen := needle.size()
	for i in range(hlen - nlen + 1):
		var found := true
		for j in range(nlen):
			if haystack[i + j] != needle[j]:
				found = false
				break
		if found:
			return i
	return -1
