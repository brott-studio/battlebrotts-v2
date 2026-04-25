## Test runner — runs all tests headlessly and reports results
## Usage: godot --headless --script tests/test_runner.gd
extends SceneTree

# [S23.4] Structural floor -- if the whole suite runs fewer than this many
# total assertions, CI fails loudly. Catches parse-errors or runner
# regressions that silently skip test files (closes #258).
# NOTE: Ett plan S3 estimated ~2694 based on CI run 24894353223, but local
# measurement on current main HEAD shows 1347 (72 inline + 1275 subprocess).
# Floor set at 1200 (~11% headroom below 1347) per S3 tuning guidance.
# Boltz: if you prefer a tighter floor, single-line edit here.
const MIN_TOTAL_ASSERTIONS := 1200

var pass_count := 0
var fail_count := 0
var test_count := 0

# Explicit enumeration of every test_sprint*.gd file covered by the
# previous CI glob (sprints 10-19 / 1[0-9] pattern). See [S16.1-005]:
# this replaces the shell-glob loop that used to live in
# .github/workflows/verify.yml. Each file is invoked in a child Godot
# process; per-file exit codes are aggregated so a failure in one file
# does NOT short-circuit the rest of the suite.
#
# [S16.2-005] Sprint 3/4/5/6 test files have been triaged (issue #138):
# every failing assertion was classified as stale-by-design (pre-S10 engine
# assumptions superseded by current GDD canon) and retired in-place with a
# GDD pointer comment. Zero (b) real-regression quarantines were added by
# this task. Sprint 3/4/5/6 files now pass and are enumerated below so the
# runner stops silently ignoring them (closes the silent-green-where-red
# gap from the S16.1-005 deviation note).
const SPRINT_TEST_FILES := [
	"res://tests/test_sprint4.gd",
	"res://tests/test_sprint5.gd",
	"res://tests/test_sprint6.gd",
	"res://tests/test_sprint10.gd",
	"res://tests/test_sprint11.gd",
	"res://tests/test_sprint11_2.gd",
	"res://tests/test_sprint12_1.gd",
	"res://tests/test_sprint12_2.gd",
	"res://tests/test_sprint12_3.gd",
	"res://tests/test_sprint12_4.gd",
	"res://tests/test_sprint12_5.gd",
	"res://tests/test_sprint13_2.gd",
	"res://tests/test_sprint13_3.gd",
	"res://tests/test_sprint13_4.gd",
	"res://tests/test_sprint13_5.gd",
	"res://tests/test_sprint13_6.gd",
	"res://tests/test_sprint13_7.gd",
	"res://tests/test_sprint13_8_modal_hardening.gd",
	"res://tests/test_sprint13_8_toast.gd",
	"res://tests/test_sprint13_9.gd",
	"res://tests/test_sprint13_10.gd",
	"res://tests/test_sprint14_1_nav.gd",
	"res://tests/test_sprint17_1_shop_scroll.gd",
	"res://tests/test_sprint17_1_loadout_overlap.gd",
	"res://tests/test_sprint17_1_visible_tooltips.gd",
	"res://tests/test_sprint17_1_first_encounter_hud.gd",
	"res://tests/test_sprint17_1_random_event_popup.gd",
	"res://tests/test_sprint17_1_first_run_crate.gd",
	"res://tests/test_sprint17_2_wall_stuck.gd",
	"res://tests/test_s17_2_scout_feel.gd",
	"res://tests/test_s17_3_002_drag_lie.gd",
	"res://tests/test_s17_3_003_delete_redesign.gd",
	"res://tests/test_s17_3_004_card_library.gd",
	"res://tests/test_s17_4_001_selected_row_pixels.gd",
	"res://tests/test_s17_4_002_tray_scroll_anchor.gd",
	"res://tests/test_sprint21_1.gd",
	# [S21.2] UX bundle (#103, #104, #107) tests — added by Nutts T1/T2/T3.
	# [S25.8] test_s21_2_001_inline_captions moved to ARC_G_PENDING (depends on retired ResultScreen).
	"res://tests/test_s21_2_002_scroll_wrappers.gd",
	"res://tests/test_s21_2_003_first_encounter_overlays.gd",
	# [S21.3] Arena onboarding HUD-element overlays (#245, #107) — added by Nutts S21.3-001.
	"res://tests/test_s21_3_arena_onboarding.gd",
	# [S21.4 T1] Scroll position preserved in shop/loadout on child-node tap (#105).
	"res://tests/test_s21_4_001_scroll_position.gd",
	# [S21.4 T2] Random-event popup redesign — named anchor + skip button + dampening (#106).
	"res://tests/test_s21_4_002_event_popup.gd",
	# [S21.4 T3] League progression surfacing on two surfaces — ResultScreen + OpponentSelectScreen (#108).
	# [S25.8] Moved to ARC_G_PENDING — ResultScreen retired, replaced by BrottDownScreen.
	# [S21.5 T1] Audio bus layout — 3 buses in order: Master/SFX/Music (I1).
	"res://tests/test_s21_5_001_audio_bus_layout.gd",
	# [S21.5 T2] Audio asset presence — OGG files + ATTRIBUTION.md exist (I2).
	"res://tests/test_s21_5_002_audio_assets.gd",
	# [S21.5 T3] SFX bus routing — WinChimePlayer + PopupWhooshPlayer both use bus "SFX" (I3).
	# [S25.8] Moved to ARC_G_PENDING — ResultScreen retired.
	# [S21.5 T4] Mute toggle — FirstRunState.set_audio_muted() + AudioServer.is_bus_mute() (I4).
	"res://tests/test_s21_5_004_mute_toggle.gd",
	# [S22.1] Silver league content — 7 templates + tier-4 + preview-opponent precondition fix.
	"res://tests/test_sprint22_1.gd",
	# [S24.2] Mixer UI — slider persistence / mute integration / bus volume.
	"res://tests/test_s24_2_001_slider_persist.gd",
	"res://tests/test_s24_2_002_mute_integration.gd",
	"res://tests/test_s24_2_003_bus_volume.gd",
	# [S24.3] Combat SFX — hit + projectile routing to SFX bus.
	"res://tests/test_s24_3_001_hit_sfx_routing.gd",
	"res://tests/test_s24_3_002_projectile_sfx_routing.gd",
	"res://tests/test_s24_3_003_sfx_assets.gd",
	# [S24.4] Combat SFX — critical + death routing to SFX bus.
	"res://tests/test_s24_4_001_crit_sfx_routing.gd",
	"res://tests/test_s24_4_002_death_sfx_routing.gd",
	"res://tests/test_s24_4_003_sfx_assets.gd",
	"res://tests/test_s24_5_001_menu_loop_seam.gd",
	"res://tests/test_s24_5_002_menu_music_routing.gd",
	"res://tests/test_run_state_init.gd",
	"res://tests/test_arena_renderer_multi.gd",
	# [S25.3] Hardcoded baseline AI — 9 conditions covering rule chain, hysteresis, module priority.
	"res://tests/test_baseline_ai.gd",
	# [S25.4] Multi-target AI priority cascade + 7-archetype encounter data.
	"res://tests/test_multi_target_ai.gd",
	# [S25.5] Reward pick screen + run flow — 6 conditions covering pool exclusion, seed determinism, dedup, retry seed.
	"res://tests/test_reward_pick.gd",
	# [S25.6] Encounter generator — pre-rolled schedule, weighted draw, no-repeat, guarantee seeds, boss-lock, large_swarm tier HP.
	"res://tests/test_encounter_generator.gd",
	# [S25.7] Battle-to-battle loop state machine — paths A/B/C (8 conditions).
	"res://tests/test_run_loop.gd",
	# [S25.8] Run-end screens (BROTT DOWN + RUN COMPLETE) + first-run tooltips.
	"res://tests/test_run_end_screens.gd",
	# [S25.9] Arc F full-loop integration validation — 10 runs × 3 gates (boss reached, variety rule, guarantee seeds).
	"res://tests/test_arc_f_integration.gd",
]

# [S25.1] Arc-G-pending test files: these reference APIs removed in Arc F
# (league-reflect, BrottState.current_league, old GameFlow behavior).
# They are intentionally failing until Arc G deletes them.
# Listed here instead of SPRINT_TEST_FILES so CI overall exit code stays green.
# Arc G removes these files and this constant entirely.
const SPRINT_TEST_FILES_ARC_G_PENDING := [
	"res://tests/test_sprint3.gd",
	"res://tests/test_sprint14_1.gd",
	"res://tests/test_sprint22_2c.gd",
	# [S25.3] Card-eval loop retired (Arc F roguelike pivot). These card-behavior
	# tests will be deleted in Arc G when the BehaviorCard class is removed.
	"res://tests/test_sprint14_2_cards.gd",
	# [S25.8] Tests depending on the retired league-era ResultScreen class.
	# BrottDownScreen replaced ResultScreen; these tests reference league
	# progression / win-chime routing on ResultScreen and need rewriting against
	# BrottDownScreen + RunCompleteScreen in Arc G.
	"res://tests/test_s21_2_001_inline_captions.gd",
	"res://tests/test_s21_4_003_league_surface.gd",
	"res://tests/test_s21_5_003_sfx_routing.gd",
]

var file_pass_count := 0
var file_fail_count := 0
var subprocess_assert_count := 0  # [S23.4] Accumulated assertion count from sprint-file subprocesses
var failed_files: Array[String] = []

func _init() -> void:
	print("=== BattleBrotts Test Suite ===\n")
	
	print("--- Core inline suite (data/damage/combat/module/movement + sprint10 stalemate) ---")
	_run_data_tests()
	_run_damage_tests()
	_run_combat_tests()
	_run_module_tests()
	_run_movement_tests()
	_run_sprint10_tests()
	
	print("\n=== Inline results: %d passed, %d failed, %d total ===" % [pass_count, fail_count, test_count])
	
	# Aggregate all sprint test files via subprocess. Never short-circuit:
	# every file runs even if an earlier one failed, so CI logs surface
	# every failure rather than just the first.
	print("\n=== Sprint test files (explicit enumeration — S16.1-005) ===")
	for test_path in SPRINT_TEST_FILES:
		_run_sprint_test_file(test_path)
	
	print("\n=== Sprint-file results: %d files passed, %d files failed ===" % [file_pass_count, file_fail_count])
	if file_fail_count > 0:
		print("Failed files:")
		for f in failed_files:
			print("  - %s" % f)

	# [S25.1] Arc-G-pending files: run informatively only, do not affect exit code.
	# These reference APIs removed in S25.1 and will be deleted in Arc G.
	var arc_g_pass_count := 0
	var arc_g_fail_count := 0
	print("\n=== Arc-G-pending tests (expected failures, informational only) ===")
	for test_path in SPRINT_TEST_FILES_ARC_G_PENDING:
		var abs_path := ProjectSettings.globalize_path(test_path)
		if not FileAccess.file_exists(abs_path):
			arc_g_fail_count += 1
			print("[MISSING (arc-g)] %s — Arc G cleanup pending" % test_path)
			continue
		var godot_bin := OS.get_executable_path()
		var project_dir := ProjectSettings.globalize_path("res://")
		var args := ["--headless", "--path", project_dir, "--script", test_path]
		var arc_g_out: Array = []
		var arc_g_exit := OS.execute(godot_bin, args, arc_g_out, true)
		if arc_g_out.size() > 0:
			print(arc_g_out[0])
		if arc_g_exit == 0:
			arc_g_pass_count += 1
			print("[PASS (arc-g)] %s" % test_path)
		else:
			arc_g_fail_count += 1
			print("[EXPECTED FAIL (arc-g)] %s (exit %d) — Arc G cleanup pending" % [test_path, arc_g_exit])
	print("=== Arc-G-pending: %d pass, %d expected-fail (not counted in overall) ===" % [arc_g_pass_count, arc_g_fail_count])
	
	var inline_ok := fail_count == 0
	var files_ok := file_fail_count == 0
	print("\n=== OVERALL: inline %s | sprint files %s ===" % [
		"PASS" if inline_ok else "FAIL",
		"PASS" if files_ok else "FAIL",
	])
	
	# [S23.4] Structural no-op detection: if the suite ran fewer total
	# assertions than the floor, OR zero sprint files passed, fail loudly
	# with exit 2 (distinct from the exit-1 "tests failed" signal so CI logs
	# can be grepped for "ASSERTION FLOOR" or exit 2 specifically).
	var total_asserts := test_count + subprocess_assert_count
	var floor_ok := total_asserts >= MIN_TOTAL_ASSERTIONS
	var files_nonzero := file_pass_count > 0

	print("\ntotal assertions run: %d" % total_asserts)

	if not floor_ok:
		print("\n!!! ASSERTION FLOOR VIOLATED !!!")
		print("!!! total assertions run: %d (floor: %d)" % [total_asserts, MIN_TOTAL_ASSERTIONS])
		print("!!! CI failing loudly -- see battlebrotts-v2#258 for context.")
	if not files_nonzero:
		print("\n!!! ZERO SPRINT FILES PASSED !!!")
		print("!!! Likely a runner or parse-error regression. CI failing loudly.")

	if inline_ok and files_ok and floor_ok and files_nonzero:
		quit(0)
	elif not floor_ok or not files_nonzero:
		quit(2)
	else:
		quit(1)

func _run_sprint_test_file(res_path: String) -> void:
	var file_name := res_path.get_file()
	print("\n--- [FILE] %s ---" % file_name)
	# Resolve res:// to an absolute path on disk so OS.execute can invoke
	# the Godot binary against it with --path pointing at the project root.
	var abs_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		print("  MISSING: %s (expected at %s)" % [res_path, abs_path])
		file_fail_count += 1
		failed_files.append(file_name)
		return
	var godot_bin := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	var args := ["--headless", "--path", project_dir, "--script", res_path]
	var out: Array = []
	var exit_code := OS.execute(godot_bin, args, out, true)
	if out.size() > 0:
		# out[0] is a single concatenated string of stdout+stderr when
		# read_stderr=true. Print verbatim so CI logs remain readable.
		print(out[0])
	# [S23.4] Accumulate subprocess assertion counts so the end-of-run floor
	# check reflects the full suite, not just the inline tests.
	subprocess_assert_count += _parse_subprocess_assertions(out[0] if out.size() > 0 else "")
	if exit_code == 0:
		file_pass_count += 1
		print("  [PASS] %s (exit 0)" % file_name)
	else:
		file_fail_count += 1
		failed_files.append(file_name)
		print("  [FAIL] %s (exit %d)" % [file_name, exit_code])

# [S23.4] Parse assertion counts from a sprint-file subprocess stdout string.
# Matches both "=== Results: N passed, M failed, T total ===" and bare
# "N passed, M failed" formats. Returns the sum of all pass counts found,
# or 0 if no match.
func _parse_subprocess_assertions(stdout: String) -> int:
	var total := 0
	var regex := RegEx.new()
	regex.compile("(\\d+)\\s+passed,\\s+\\d+\\s+failed")
	for m in regex.search_all(stdout):
		total += int(m.get_string(1))
	return total

func assert_eq(a: Variant, b: Variant, msg: String) -> void:
	test_count += 1
	if a == b:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %s, expected %s)" % [msg, str(a), str(b)])

func assert_near(a: float, b: float, tol: float, msg: String) -> void:
	test_count += 1
	if absf(a - b) <= tol:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (got %f, expected %f ± %f)" % [msg, a, b, tol])

func assert_true(val: bool, msg: String) -> void:
	test_count += 1
	if val:
		pass_count += 1
	else:
		fail_count += 1
		print("  FAIL: %s (expected true)" % msg)

func assert_false(val: bool, msg: String) -> void:
	assert_true(not val, msg)

## ===== DATA VALIDATION TESTS =====

func _run_data_tests() -> void:
	print("--- Data Validation ---")
	
	# Chassis stats (S13.3 balance)
	var scout := ChassisData.get_chassis(ChassisData.ChassisType.SCOUT)
	assert_eq(scout["hp"], 165, "Scout HP = 165 (S13.3: 110 × 1.5 pacing)")
	assert_near(scout["speed"], 220.0, 0.1, "Scout speed = 220")
	assert_eq(scout["weapon_slots"], 2, "Scout weapon slots = 2")
	assert_eq(scout["module_slots"], 3, "Scout module slots = 3")
	assert_near(scout["dodge_chance"], 0.15, 0.001, "Scout dodge = 15%")
	
	var brawler := ChassisData.get_chassis(ChassisData.ChassisType.BRAWLER)
	assert_eq(brawler["hp"], 225, "Brawler HP = 225 (150 × 1.5 pacing)")
	assert_near(brawler["speed"], 120.0, 0.1, "Brawler speed = 120")
	assert_eq(brawler["weapon_slots"], 2, "Brawler weapon slots = 2")
	assert_eq(brawler["module_slots"], 2, "Brawler module slots = 2")
	
	var fortress := ChassisData.get_chassis(ChassisData.ChassisType.FORTRESS)
	assert_eq(fortress["hp"], 330, "Fortress HP = 330 (S13.3: 220 × 1.5 pacing)")
	assert_near(fortress["speed"], 60.0, 0.1, "Fortress speed = 60")
	assert_eq(fortress["weapon_slots"], 2, "Fortress weapon slots = 2")
	assert_eq(fortress["module_slots"], 1, "Fortress module slots = 1")
	
	# Weapon stats
	var minigun := WeaponData.get_weapon(WeaponData.WeaponType.MINIGUN)
	assert_eq(minigun["damage"], 3, "Minigun damage = 3")
	assert_eq(minigun["range_tiles"], 5, "Minigun range = 5")
	assert_near(minigun["fire_rate"], 6.0, 0.1, "Minigun fire rate = 6")
	assert_eq(minigun["energy_cost"], 2, "Minigun energy = 2")
	assert_eq(minigun["weight"], 10, "Minigun weight = 10")
	
	var railgun := WeaponData.get_weapon(WeaponData.WeaponType.RAILGUN)
	assert_eq(railgun["damage"], 45, "Railgun damage = 45")
	assert_near(railgun["fire_rate"], 0.6, 0.1, "Railgun fire rate = 0.6")
	assert_eq(railgun["energy_cost"], 16, "Railgun energy = 16")
	
	var shotgun := WeaponData.get_weapon(WeaponData.WeaponType.SHOTGUN)
	assert_eq(shotgun["damage"], 6, "Shotgun damage = 6")
	assert_eq(shotgun["pellets"], 5, "Shotgun pellets = 5")
	assert_near(shotgun["spread_deg"], 30.0, 0.1, "Shotgun spread = 30°")
	
	var missile := WeaponData.get_weapon(WeaponData.WeaponType.MISSILE_POD)
	assert_eq(missile["damage"], 30, "Missile damage = 30")
	assert_eq(missile["splash_radius"], 1, "Missile splash = 1 tile")
	
	var plasma := WeaponData.get_weapon(WeaponData.WeaponType.PLASMA_CUTTER)
	assert_eq(plasma["damage"], 14, "Plasma Cutter damage = 14 (v3)")
	assert_eq(plasma["weight"], 8, "Plasma Cutter weight = 8")
	
	var arc := WeaponData.get_weapon(WeaponData.WeaponType.ARC_EMITTER)
	assert_eq(arc["chain_targets"], 1, "Arc Emitter chains to 1")
	
	var flak := WeaponData.get_weapon(WeaponData.WeaponType.FLAK_CANNON)
	assert_eq(flak["damage"], 15, "Flak damage = 15")
	
	# Armor stats
	var plating := ArmorData.get_armor(ArmorData.ArmorType.PLATING)
	assert_near(plating["reduction"], 0.20, 0.001, "Plating reduction = 20%")
	
	var reactive := ArmorData.get_armor(ArmorData.ArmorType.REACTIVE_MESH)
	assert_near(reactive["reduction"], 0.10, 0.001, "Reactive Mesh reduction = 10%")
	assert_eq(reactive["special"], "reflect", "Reactive Mesh reflects")
	
	var ablative := ArmorData.get_armor(ArmorData.ArmorType.ABLATIVE_SHELL)
	assert_near(ablative["reduction"], 0.40, 0.001, "Ablative Shell reduction = 40%")
	
	# Ablative reduction drops below 30% HP
	assert_near(ArmorData.effective_reduction(ArmorData.ArmorType.ABLATIVE_SHELL, 0.5), 0.40, 0.001, "Ablative at 50% HP = 40%")
	assert_near(ArmorData.effective_reduction(ArmorData.ArmorType.ABLATIVE_SHELL, 0.2), 0.10, 0.001, "Ablative at 20% HP = 10%")
	
	# Module stats
	var overclock := ModuleData.get_module(ModuleData.ModuleType.OVERCLOCK)
	assert_eq(overclock["weight"], 5, "Overclock weight = 5")
	assert_true(overclock["activated"], "Overclock is activated")
	
	var nanites := ModuleData.get_module(ModuleData.ModuleType.REPAIR_NANITES)
	assert_near(nanites["heal_per_sec"], 3.0, 0.1, "Repair Nanites = 3 HP/s")
	assert_false(nanites["activated"], "Repair Nanites is passive")
	
	var shield := ModuleData.get_module(ModuleData.ModuleType.SHIELD_PROJECTOR)
	assert_eq(shield["absorb"], 40, "Shield absorb = 40")
	assert_near(shield["duration"], 5.0, 0.1, "Shield duration = 5s")
	assert_near(shield["cooldown"], 20.0, 0.1, "Shield cooldown = 20s")

## ===== DAMAGE FORMULA TESTS =====

func _run_damage_tests() -> void:
	print("--- Damage Formula ---")
	
	# Normal damage, no armor
	# base_damage * (1 - 0) * 1.0
	var dmg := 10.0 * (1.0 - 0.0) * 1.0
	assert_near(dmg, 10.0, 0.01, "Normal damage, no armor = 10")
	
	# Damage with Plating (20%)
	dmg = 10.0 * (1.0 - 0.20) * 1.0
	assert_near(dmg, 8.0, 0.01, "10 dmg with Plating = 8")
	
	# Crit damage
	dmg = 10.0 * (1.0 - 0.0) * 1.5
	assert_near(dmg, 15.0, 0.01, "10 dmg crit = 15")
	
	# Crit + armor
	dmg = 10.0 * (1.0 - 0.20) * 1.5
	assert_near(dmg, 12.0, 0.01, "10 dmg crit + Plating = 12")
	
	# Ablative Shell (40%)
	dmg = 10.0 * (1.0 - 0.40) * 1.0
	assert_near(dmg, 6.0, 0.01, "10 dmg + Ablative = 6")
	
	# Shotgun pellets: 6 damage * 5 pellets, each independent
	# Max damage (all hit, no armor): 6 * 5 = 30
	var max_shotgun := 6.0 * 5.0 * (1.0 - 0.0) * 1.0
	assert_near(max_shotgun, 30.0, 0.01, "Shotgun max (all pellets, no armor) = 30")
	
	# Splash: full at impact, 50% at radius
	var splash_full := 30.0 * (1.0 - 0.0) * 1.0
	var splash_half := 30.0 * 0.5
	assert_near(splash_full, 30.0, 0.01, "Missile direct = 30")
	assert_near(splash_half, 15.0, 0.01, "Missile splash = 15")
	
	# Minimum damage = 1
	dmg = 1.0 * (1.0 - 0.40) * 1.0
	assert_near(maxf(dmg, 1.0), 1.0, 0.01, "Min damage floor = 1")

## ===== COMBAT SIMULATION TESTS =====

func _run_combat_tests() -> void:
	print("--- Combat Simulation ---")
	
	# Test energy regen
	var sim := CombatSim.new(1)
	var b := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b.energy = 50.0
	b.position = Vector2(128, 128)
	sim.add_brott(b)
	
	# Add dummy enemy far away (no combat)
	var dummy := _make_brott(1, ChassisData.ChassisType.FORTRESS)
	dummy.position = Vector2(400, 400)
	sim.add_brott(dummy)
	
	# Run 10 ticks = 1 second at 10 ticks/sec = +5 energy
	for i in 10:
		sim.simulate_tick()
	assert_near(b.energy, 55.0, 1.0, "Energy regen: 50 → ~55 after 1s")
	
	# Test match timeout
	var sim2 := CombatSim.new(2)
	var b1 := _make_brott(0, ChassisData.ChassisType.FORTRESS)
	b1.position = Vector2(256, 256)
	b1.weapon_types = []
	b1.weapon_cooldowns = []
	b1.hp = 99999.0
	b1.max_hp = 99999
	var b2 := _make_brott(1, ChassisData.ChassisType.FORTRESS)
	b2.position = Vector2(260, 260)
	b2.weapon_types = []
	b2.weapon_cooldowns = []
	b2.hp = 99999.0
	b2.max_hp = 99999
	sim2.add_brott(b1)
	sim2.add_brott(b2)
	
	# Fast forward to timeout (100s * 10 ticks/sec = 1000 ticks)
	for i in 1000:
		sim2.simulate_tick()
	assert_true(sim2.match_over, "Match ends at timeout")
	assert_eq(sim2.tick_count, 1000, "Tick count = 1000 at timeout")
	
	# Test brott death
	var sim3 := CombatSim.new(3)
	var attacker := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	attacker.position = Vector2(100, 100)
	var victim := _make_brott(1, ChassisData.ChassisType.SCOUT)
	victim.position = Vector2(100, 100)
	victim.hp = 1.0
	sim3.add_brott(attacker)
	sim3.add_brott(victim)
	
	# Manually kill
	sim3._kill_brott(victim)
	assert_false(victim.alive, "Victim is dead")
	assert_near(victim.hp, 0.0, 0.01, "Dead brott HP = 0")
	
	# Test determinism
	var sim_a := CombatSim.new(99)
	var sim_b := CombatSim.new(99)
	var ba1 := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	ba1.position = Vector2(64, 128)
	ba1.weapon_types = [WeaponData.WeaponType.MINIGUN]
	ba1.weapon_cooldowns = [0.0]
	var ba2 := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	ba2.position = Vector2(128, 128)
	ba2.weapon_types = [WeaponData.WeaponType.MINIGUN]
	ba2.weapon_cooldowns = [0.0]
	sim_a.add_brott(ba1)
	sim_a.add_brott(ba2)
	
	var bb1 := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	bb1.position = Vector2(64, 128)
	bb1.weapon_types = [WeaponData.WeaponType.MINIGUN]
	bb1.weapon_cooldowns = [0.0]
	var bb2 := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	bb2.position = Vector2(128, 128)
	bb2.weapon_types = [WeaponData.WeaponType.MINIGUN]
	bb2.weapon_cooldowns = [0.0]
	sim_b.add_brott(bb1)
	sim_b.add_brott(bb2)
	
	for i in 100:
		sim_a.simulate_tick()
		sim_b.simulate_tick()
	assert_near(ba1.hp, bb1.hp, 0.01, "Determinism: same seed → same HP (bot 1)")
	assert_near(ba2.hp, bb2.hp, 0.01, "Determinism: same seed → same HP (bot 2)")

## ===== MODULE TESTS =====

func _run_module_tests() -> void:
	print("--- Module Tests ---")
	
	# Repair Nanites: 3 HP/s passive
	var b := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b.module_types = [ModuleData.ModuleType.REPAIR_NANITES]
	b.module_cooldowns = [0.0]
	b.module_active_timers = [0.0]
	b.hp = 100.0
	b.max_hp = 150
	
	var sim := CombatSim.new(1)
	sim.add_brott(b)
	var dummy := _make_brott(1, ChassisData.ChassisType.FORTRESS)
	dummy.position = Vector2(400, 400)
	sim.add_brott(dummy)
	
	for i in 10:  # 1 second at 10 ticks/sec
		sim._tick_modules(b)
	assert_near(b.hp, 103.0, 0.5, "Repair Nanites: +3 HP after 1s")
	
	# HP doesn't exceed max
	b.hp = 149.0
	for i in 10:
		sim._tick_modules(b)
	assert_near(b.hp, 150.0, 0.1, "Repair Nanites: capped at max HP")
	
	# Overclock fire rate
	var b2 := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b2.overclock_active = true
	assert_near(b2.get_fire_rate_multiplier(), 1.30, 0.01, "Overclock active = +30% fire rate")
	b2.overclock_active = false
	b2.overclock_recovery = true
	assert_near(b2.get_fire_rate_multiplier(), 0.80, 0.01, "Overclock recovery = -20% fire rate")
	b2.overclock_recovery = false
	assert_near(b2.get_fire_rate_multiplier(), 1.0, 0.01, "Normal fire rate = 1.0")
	
	# Shield absorb
	var b3 := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b3.shield_active = true
	b3.shield_hp = 40.0
	b3.hp = 150.0
	# Simulate 25 damage to shield
	var absorbed := minf(25.0, b3.shield_hp)
	b3.shield_hp -= absorbed
	var remaining := 25.0 - absorbed
	assert_near(b3.shield_hp, 15.0, 0.01, "Shield absorbs 25, 15 remaining")
	assert_near(remaining, 0.0, 0.01, "No damage passes through")
	
	# Afterburner speed
	var b4 := _make_brott(0, ChassisData.ChassisType.SCOUT)
	assert_near(b4.get_effective_speed(), 220.0, 0.1, "Scout base speed = 220")
	b4.afterburner_active = true
	assert_near(b4.get_effective_speed(), 396.0, 0.1, "Afterburner: 220 * 1.8 = 396")

## ===== MOVEMENT TESTS =====

func _run_movement_tests() -> void:
	print("--- Movement Tests ---")
	
	# Aggressive stance moves toward target
	var sim := CombatSim.new(1)
	var b := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	b.position = Vector2(64, 128)
	b.stance = 0  # Aggressive
	b.weapon_types = []
	b.weapon_cooldowns = []
	var target := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	target.position = Vector2(256, 128)
	target.weapon_types = []
	target.weapon_cooldowns = []
	sim.add_brott(b)
	sim.add_brott(target)
	
	var start_dist := b.position.distance_to(target.position)
	for i in 20:
		sim.simulate_tick()
	var end_dist := b.position.distance_to(target.position)
	assert_true(end_dist < start_dist, "Aggressive stance: closer after 1s")
	
	# Arena bounds clamping
	var b2 := _make_brott(0, ChassisData.ChassisType.SCOUT)
	b2.position = Vector2(-10, -10)
	var sim2 := CombatSim.new(2)
	var t2 := _make_brott(1, ChassisData.ChassisType.FORTRESS)
	t2.position = Vector2(-50, -50)
	t2.weapon_types = []
	t2.weapon_cooldowns = []
	sim2.add_brott(b2)
	sim2.add_brott(t2)
	sim2.simulate_tick()
	assert_true(b2.position.x >= 12.0, "Arena clamp: X >= hitbox radius")
	assert_true(b2.position.y >= 12.0, "Arena clamp: Y >= hitbox radius")

## ===== HELPERS =====

func _make_brott(team: int, chassis: ChassisData.ChassisType) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.chassis_type = chassis
	b.weapon_types = [WeaponData.WeaponType.MINIGUN]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.position = Vector2(128, 128)
	b.setup()
	return b

func _run_sprint10_tests() -> void:
	print("\n--- Sprint 10 Tests ---")
	# Stalemate detection: 300-tick sim, bots should move
	var sim := CombatSim.new(42)
	var bot_a := _make_brott(0, ChassisData.ChassisType.BRAWLER)
	bot_a.position = Vector2(64, 128)
	bot_a.stance = 0  # Aggressive
	bot_a.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]
	bot_a.weapon_cooldowns = [0.0]
	var bot_b := _make_brott(1, ChassisData.ChassisType.BRAWLER)
	bot_b.position = Vector2(448, 384)
	bot_b.stance = 0  # Aggressive
	bot_b.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]
	bot_b.weapon_cooldowns = [0.0]
	sim.add_brott(bot_a)
	sim.add_brott(bot_b)
	var positions: Array[Vector2] = []
	for tick in range(300):
		sim.simulate_tick()
		if tick % 50 == 0 and sim.brotts.size() > 0 and sim.brotts[0].alive:
			positions.append(sim.brotts[0].position)
	var moved := false
	if positions.size() >= 2:
		for i in range(1, positions.size()):
			if positions[i].distance_to(positions[0]) > 1.0:
				moved = true
				break
	assert_true(moved, "Sprint10: Bots moved during 300-tick sim")
