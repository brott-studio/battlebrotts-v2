## test_arc_o3_death_freeze.gd — Arc O.3 assertions.
##
## Gates (5 Gizmo ACs):
##   O3-1: Single death — _spawn_death_burst called once, death_freeze_timer set to 6.0
##   O3-2: 3-death burst — after 3 calls to _spawn_death_burst, active_particle_count ≤ 120
##   O3-3: 5-death burst — active_particle_count ≤ 120, death_freeze_timer resets to 6.0 on each _on_death
##   O3-4: Debris guard — after 5 burst calls, death_debris.size() ≤ 30
##   O3-5: DEATH_BURST_MAX constant == 120
##
## Usage: godot --headless --path godot/ --script res://tests/test_arc_o3_death_freeze.gd
extends SceneTree

const ArenaRenderer = preload("res://arena/arena_renderer.gd")

var pass_count := 0
var fail_count := 0
var test_count := 0

func _initialize() -> void:
	print("=== test_arc_o3_death_freeze ===\n")
	_test_o3_1_single_death_freeze_timer()
	_test_o3_2_three_death_burst_particle_cap()
	_test_o3_3_five_death_burst_reset_and_cap()
	_test_o3_4_debris_guard_five_bursts()
	_test_o3_5_death_burst_max_constant()
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

## Build a minimal ArenaRenderer-like object by instantiating it directly.
## Since ArenaRenderer extends Node2D and uses _claim_particle / pool internals,
## we test its public API via a CombatSim + on_death signal.
func _make_renderer_and_sim() -> Array:
	var renderer := ArenaRenderer.new()
	renderer.arena_offset = Vector2.ZERO
	renderer._init_particle_pool()

	var sim := CombatSim.new(42)
	var b1 := _make_brott(0)
	b1.position = Vector2(128.0, 128.0)
	var b2 := _make_brott(1)
	b2.position = Vector2(256.0, 256.0)
	sim.add_brott(b1)
	sim.add_brott(b2)
	renderer.sim = sim
	sim.on_death.connect(renderer._on_death)

	return [renderer, sim, b1, b2]

func _make_brott(team: int) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.chassis_type = ChassisData.ChassisType.BRAWLER
	b.weapon_types = [WeaponData.WeaponType.MINIGUN]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.setup()
	return b

## ── O3-1: Single death → death_freeze_timer == 6.0 ─────────────────────────
func _test_o3_1_single_death_freeze_timer() -> void:
	print("--- O3-1: Single death sets death_freeze_timer = 6.0 ---")
	var parts := _make_renderer_and_sim()
	var renderer: ArenaRenderer = parts[0]
	var sim: CombatSim = parts[1]
	var victim: BrottState = parts[3]

	_assert(renderer.death_freeze_timer == 0.0, "pre-death: death_freeze_timer == 0.0")

	# Kill the brott — this fires on_death signal → _on_death synchronously
	sim._kill_brott(victim)

	_assert(renderer.death_freeze_timer == 6.0, "post-death: death_freeze_timer == 6.0")

	# Call deferred _spawn_death_burst manually (call_deferred won't run in SceneTree headless _initialize)
	renderer._spawn_death_burst(victim.position)

	# Pool should have some active particles (20–30 range)
	_assert(renderer.active_particle_count >= 20, "single burst: active_particle_count >= 20")
	_assert(renderer.active_particle_count <= 30, "single burst: active_particle_count <= 30")

## ── O3-2: 3-death burst → active_particle_count ≤ 120 ──────────────────────
func _test_o3_2_three_death_burst_particle_cap() -> void:
	print("--- O3-2: 3-death burst → active_particle_count ≤ 120 ---")
	var renderer := ArenaRenderer.new()
	renderer.arena_offset = Vector2.ZERO
	renderer._init_particle_pool()

	var sim := CombatSim.new(1)
	renderer.sim = sim

	# Simulate 3 burst calls directly (as would happen via call_deferred in 3 frames)
	for _i in range(3):
		renderer._spawn_death_burst(Vector2(128.0, 128.0))

	_assert(renderer.active_particle_count <= 120,
		"3-burst: active_particle_count (%d) ≤ 120" % renderer.active_particle_count)

## ── O3-3: 5-death burst → cap enforced, death_freeze_timer resets ───────────
func _test_o3_3_five_death_burst_reset_and_cap() -> void:
	print("--- O3-3: 5-death burst → cap enforced + death_freeze_timer resets each _on_death ---")
	var parts := _make_renderer_and_sim()
	var renderer: ArenaRenderer = parts[0]
	var sim: CombatSim = parts[1]

	# Add 5 more enemy brotts to kill
	var deaths := 0
	for i in range(5):
		var b := _make_brott(1)
		b.position = Vector2(100.0 + i * 20.0, 100.0)
		sim.add_brott(b)
		sim._kill_brott(b)
		deaths += 1
		# Manually call _spawn_death_burst (call_deferred won't fire in headless SceneTree _initialize)
		renderer._spawn_death_burst(b.position)

	_assert(renderer.active_particle_count <= 120,
		"5-burst: active_particle_count (%d) ≤ 120" % renderer.active_particle_count)
	# After 5 kills, death_freeze_timer was reset 5× — should still be 6.0 from last kill
	_assert(renderer.death_freeze_timer == 6.0,
		"5-burst: death_freeze_timer == 6.0 (reset on each kill)")

## ── O3-4: Debris guard → death_debris.size() ≤ 30 after 5 burst calls ──────
func _test_o3_4_debris_guard_five_bursts() -> void:
	print("--- O3-4: debris guard prevents death_debris.size() > 30 after 5 bursts ---")
	var renderer := ArenaRenderer.new()
	renderer.arena_offset = Vector2.ZERO
	renderer._init_particle_pool()

	var sim := CombatSim.new(2)
	renderer.sim = sim

	# Pre-populate death_debris to near limit so guard is exercised
	for _i in range(27):
		renderer.death_debris.append({"pos": Vector2.ZERO, "vel": Vector2.ZERO,
			"rotation": 0.0, "rot_speed": 0.0, "lifetime": 1.0, "max_lifetime": 1.0,
			"size": 1.0, "color": Color.WHITE})

	# 5 burst calls — each tries to add 4–6 debris; guard should cap at 30
	for _i in range(5):
		renderer._spawn_death_burst(Vector2(128.0, 128.0))

	_assert(renderer.death_debris.size() <= 30,
		"after 5 bursts with pre-populated debris: death_debris.size() (%d) ≤ 30" % renderer.death_debris.size())

## ── O3-5: DEATH_BURST_MAX constant == 120 ───────────────────────────────────
func _test_o3_5_death_burst_max_constant() -> void:
	print("--- O3-5: ArenaRenderer.DEATH_BURST_MAX == 120 ---")
	_assert(ArenaRenderer.DEATH_BURST_MAX == 120, "DEATH_BURST_MAX == 120")
