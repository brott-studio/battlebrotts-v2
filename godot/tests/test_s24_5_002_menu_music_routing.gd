## S24.5 — Menu music routing test
## Usage: godot --headless --path godot/ --script res://tests/test_s24_5_002_menu_music_routing.gd
##
## Asserts:
##   T1: Asset file exists at res://assets/audio/music/menu_loop.ogg
##   T2: OGG Vorbis identification header has sample_rate == 44100 Hz
##   T3: OGG Vorbis identification header has channels == 2 (stereo)
##   T4: File size consistent with 60–90s duration at OGG Vorbis q4 bitrate
##   T5: AudioServer reports "Music" bus at index 2 (bus layout invariant from S21.5)
##   T6: AudioStreamPlayer with bus = "Music" is confirmed to route to Music bus index 2

extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== S24.5-002 Menu music routing tests ===\n")
	# Load bus layout so AudioServer has the correct bus configuration.
	var layout_path := "res://default_bus_layout.tres"
	if ResourceLoader.exists(layout_path):
		var layout: AudioBusLayout = ResourceLoader.load(layout_path) as AudioBusLayout
		if layout != null:
			AudioServer.set_bus_layout(layout)
	_test_routing()
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

func _test_routing() -> void:
	var path := "res://assets/audio/music/menu_loop.ogg"

	print("--- T1: Asset exists ---")
	_assert(FileAccess.file_exists(path), "T1: menu_loop.ogg exists at " + path)
	if not FileAccess.file_exists(path):
		return

	print("--- T2+T3+T4: OGG Vorbis format checks (sample_rate, channels, duration range) ---")
	var f := FileAccess.open(path, FileAccess.READ)
	var file_size := f.get_length() if f != null else 0
	var header_bytes: PackedByteArray
	if f != null:
		header_bytes = f.get_buffer(256)
		f.close()

	if header_bytes.size() >= 48:
		# Vorbis ident header: byte 0x01 + 'vorbis'
		var vorbis_marker := PackedByteArray([0x01, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73])
		var marker_pos := _find_bytes(header_bytes, vorbis_marker)
		if marker_pos >= 0:
			# Layout after marker (7 bytes): version(4) + channels(1) + sample_rate(4)
			var base := marker_pos + 7
			if base + 9 <= header_bytes.size():
				var channels: int = header_bytes[base + 4]
				var sample_rate: int = (
					header_bytes[base + 5] |
					(header_bytes[base + 6] << 8) |
					(header_bytes[base + 7] << 16) |
					(header_bytes[base + 8] << 24)
				)
				_assert_eq(sample_rate, 44100, "T2: sample_rate == 44100 Hz (got %d)" % sample_rate)
				_assert_eq(channels, 2, "T3: channels == 2 stereo (got %d)" % channels)
			else:
				_assert(false, "T2+T3: Vorbis ident header truncated — cannot verify format")
		else:
			_assert(false, "T2+T3: Vorbis ident header not found in first 256 bytes")
	else:
		_assert(false, "T2+T3: File too small to parse Vorbis header")

	# T4: File size consistent with 60–90s at ~109 kbps (q4 stereo 44100 Hz)
	var min_size: int = 60 * 50000 / 8
	var max_size: int = 90 * 200000 / 8
	_assert(file_size >= min_size and file_size <= max_size,
		"T4: file size %d in [%d, %d] bytes — consistent with 60–90s OGG Vorbis q4" % [file_size, min_size, max_size])

	print("--- T5: AudioServer 'Music' bus is at index 2 ---")
	_assert_eq(AudioServer.bus_count >= 3, true, "T5-pre: AudioServer has >= 3 buses")
	var music_bus_idx: int = AudioServer.get_bus_index("Music")
	_assert_eq(music_bus_idx, 2, "T5: AudioServer.get_bus_index('Music') == 2 (got %d)" % music_bus_idx)

	print("--- T6: AudioStreamPlayer with bus='Music' routes to bus index 2 ---")
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	_assert_eq(player.bus, &"Music", "T6a: player.bus == 'Music'")
	_assert_eq(AudioServer.get_bus_index(player.bus), 2, "T6b: player routes to bus index 2")
	player.free()
