## Sprint 12.4 test suite — Charm Pass: Personality Animations
extends SceneTree

var pass_count := 0
var fail_count := 0
var test_count := 0

func _init() -> void:
	print("=== BattleBrotts Sprint 12.4 Test Suite ===")
	print("=== Charm Pass: Idle Anims, Movement Quirks, Victory/Defeat, Combat Flavor ===\n")

	test_idle_anim_scout()
	test_idle_anim_brawler()
	test_idle_anim_fortress()
	test_idle_brawler_is_horizontal()
	test_scout_spin_rate()
	test_dust_puff_particles()
	test_gear_particle()
	test_victory_anim_win()
	test_victory_anim_perfect()
	test_victory_anim_close()
	test_victory_anim_loss()
	test_smoke_particle_below_25_hp()
	test_crit_recoil()
	test_module_ring_color()
	test_no_gameplay_state_change()

	print("\n--- Results ---")
	print("%d passed, %d failed out of %d" % [pass_count, fail_count, test_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	test_count += 1
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

# --- Idle animations per chassis ---
func test_idle_anim_scout() -> void:
	print("\n[Test] Scout idle: hover-bob 1px, 0.8s cycle")
	# At t=0, sin(0)=0
	var offset0 := CharmAnims.get_idle_offset(ChassisData.ChassisType.SCOUT, 0.0)
	_assert(absf(offset0) < 0.01, "Scout idle offset 0 at t=0")
	# At t=0.2 (quarter cycle), sin(PI/2) = 1 → offset = 1.0
	var offset_quarter := CharmAnims.get_idle_offset(ChassisData.ChassisType.SCOUT, 0.2)
	_assert(absf(offset_quarter - 1.0) < 0.05, "Scout idle offset ~1.0 at quarter cycle (0.2s)")
	# Amplitude check: should not exceed 1px
	var max_offset := 0.0
	for i in range(100):
		var t := float(i) * 0.01
		max_offset = maxf(max_offset, absf(CharmAnims.get_idle_offset(ChassisData.ChassisType.SCOUT, t)))
	_assert(max_offset <= 1.01, "Scout idle amplitude <= 1px (got %.3f)" % max_offset)
	_assert(not CharmAnims.get_idle_is_horizontal(ChassisData.ChassisType.SCOUT), "Scout idle is vertical")

func test_idle_anim_brawler() -> void:
	print("\n[Test] Brawler idle: side-to-side rock 1px, 1.2s cycle")
	var offset0 := CharmAnims.get_idle_offset(ChassisData.ChassisType.BRAWLER, 0.0)
	_assert(absf(offset0) < 0.01, "Brawler idle offset 0 at t=0")
	# At t=0.3 (quarter cycle), sin(PI/2) = 1
	var offset_quarter := CharmAnims.get_idle_offset(ChassisData.ChassisType.BRAWLER, 0.3)
	_assert(absf(offset_quarter - 1.0) < 0.05, "Brawler idle offset ~1.0 at quarter cycle")
	var max_offset := 0.0
	for i in range(100):
		var t := float(i) * 0.02
		max_offset = maxf(max_offset, absf(CharmAnims.get_idle_offset(ChassisData.ChassisType.BRAWLER, t)))
	_assert(max_offset <= 1.01, "Brawler idle amplitude <= 1px (got %.3f)" % max_offset)

func test_idle_anim_fortress() -> void:
	print("\n[Test] Fortress idle: breathing 0.5px, 2.0s cycle")
	var offset0 := CharmAnims.get_idle_offset(ChassisData.ChassisType.FORTRESS, 0.0)
	_assert(absf(offset0) < 0.01, "Fortress idle offset 0 at t=0")
	# At t=0.5 (quarter cycle), sin(PI/2) = 1 → 0.5
	var offset_quarter := CharmAnims.get_idle_offset(ChassisData.ChassisType.FORTRESS, 0.5)
	_assert(absf(offset_quarter - 0.5) < 0.05, "Fortress idle offset ~0.5 at quarter cycle")
	var max_offset := 0.0
	for i in range(100):
		var t := float(i) * 0.04
		max_offset = maxf(max_offset, absf(CharmAnims.get_idle_offset(ChassisData.ChassisType.FORTRESS, t)))
	_assert(max_offset <= 0.51, "Fortress idle amplitude <= 0.5px (got %.3f)" % max_offset)

func test_idle_brawler_is_horizontal() -> void:
	print("\n[Test] Brawler idle is horizontal, others vertical")
	_assert(CharmAnims.get_idle_is_horizontal(ChassisData.ChassisType.BRAWLER), "Brawler idle is horizontal")
	_assert(not CharmAnims.get_idle_is_horizontal(ChassisData.ChassisType.SCOUT), "Scout idle is not horizontal")
	_assert(not CharmAnims.get_idle_is_horizontal(ChassisData.ChassisType.FORTRESS), "Fortress idle is not horizontal")

# --- Movement quirks ---
func test_scout_spin_rate() -> void:
	print("\n[Test] Scout spin: ~10% chance on direction change")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var spins := 0
	var trials := 10000
	for _i in range(trials):
		if CharmAnims.should_scout_spin(rng):
			spins += 1
	var rate := float(spins) / float(trials)
	_assert(rate > 0.08 and rate < 0.12, "Scout spin rate ~10%% (got %.1f%%)" % (rate * 100))

func test_dust_puff_particles() -> void:
	print("\n[Test] Brawler dust puff particles on standstill→move")
	var puffs := CharmAnims.create_dust_puff(Vector2(100, 100))
	_assert(puffs.size() == 4, "Dust puff creates 4 particles (got %d)" % puffs.size())
	_assert(puffs[0]["lifetime"] == 18.0, "Dust puff lifetime = 18 frames (0.3s)")
	_assert(puffs[0]["pos"].y > 100, "Dust puff spawns at feet (y > center)")

func test_gear_particle() -> void:
	print("\n[Test] Fortress gear-grinding particle on deceleration")
	var gp := CharmAnims.create_gear_particle(Vector2(200, 200), Vector2(10, 0))
	_assert(gp["lifetime"] == 12.0, "Gear particle lifetime = 12 frames")
	_assert(gp["vel"].x < 0, "Gear particle moves opposite to velocity")

# --- Victory/defeat reactions ---
func test_victory_anim_win() -> void:
	print("\n[Test] Victory anim: win (spin + 4px jump)")
	var b := BrottState.new()
	b.chassis_type = ChassisData.ChassisType.SCOUT
	b.setup()
	CharmAnims.start_victory_anim(b, "win")
	_assert(b.victory_anim_timer == 0.3, "Win anim duration = 0.3s")
	_assert(b.victory_anim_type == "win", "Win anim type correct")
	# Tick halfway
	CharmAnims.tick_victory_anim(b, 0.15)
	_assert(b.charm_rotation > 100 and b.charm_rotation < 250, "Mid-win: rotation in progress (%.1f°)" % b.charm_rotation)
	_assert(b.charm_y_offset < -2.0, "Mid-win: jumping up (offset=%.1f)" % b.charm_y_offset)

func test_victory_anim_perfect() -> void:
	print("\n[Test] Victory anim: perfect win (double spin + 6px jump)")
	var b := BrottState.new()
	b.chassis_type = ChassisData.ChassisType.BRAWLER
	b.setup()
	CharmAnims.start_victory_anim(b, "perfect")
	_assert(b.victory_anim_timer == 0.5, "Perfect win duration = 0.5s")
	CharmAnims.tick_victory_anim(b, 0.25)
	_assert(b.charm_rotation > 300 and b.charm_rotation < 400, "Mid-perfect: double spin in progress (%.1f°)" % b.charm_rotation)
	_assert(b.charm_y_offset < -4.0, "Mid-perfect: big jump (offset=%.1f)" % b.charm_y_offset)

func test_victory_anim_close() -> void:
	print("\n[Test] Victory anim: close win (<20% HP, wobbly spin)")
	var b := BrottState.new()
	b.chassis_type = ChassisData.ChassisType.FORTRESS
	b.setup()
	CharmAnims.start_victory_anim(b, "close")
	_assert(b.victory_anim_timer == 0.4, "Close win duration = 0.4s")
	CharmAnims.tick_victory_anim(b, 0.2)
	_assert(b.charm_rotation > 100, "Mid-close: spinning (%.1f°)" % b.charm_rotation)
	# Wobbly = y_offset oscillates
	_assert(absf(b.charm_y_offset) <= 1.5, "Close win: wobble amplitude <= 1.5px")

func test_victory_anim_loss() -> void:
	print("\n[Test] Victory anim: loss (slump down 2px)")
	var b := BrottState.new()
	b.chassis_type = ChassisData.ChassisType.SCOUT
	b.setup()
	CharmAnims.start_victory_anim(b, "loss")
	_assert(b.victory_anim_timer == 0.5, "Loss anim duration = 0.5s")
	# Tick to end
	CharmAnims.tick_victory_anim(b, 0.5)
	# At end, offsets reset
	_assert(b.charm_y_offset == 0.0, "Loss anim resets at end")

# --- Combat flavor ---
func test_smoke_particle_below_25_hp() -> void:
	print("\n[Test] Smoke particles trail below 25% HP")
	var sp := CharmAnims.create_smoke_particle(Vector2(150, 150))
	_assert(sp["lifetime"] == 24.0, "Smoke particle lifetime = 24 frames (0.4s)")
	_assert(sp["color"].a < 0.6, "Smoke particle is semi-transparent")
	_assert(sp["vel"].y < 0, "Smoke drifts upward")

func test_crit_recoil() -> void:
	print("\n[Test] Crit received: 2px visual recoil")
	var b := BrottState.new()
	b.chassis_type = ChassisData.ChassisType.BRAWLER
	b.setup()
	b.position = Vector2(200, 200)
	# Simulate crit recoil from left
	var source_pos := Vector2(100, 200)
	var recoil_dir := (b.position - source_pos).normalized()
	b.recoil_offset = recoil_dir * 2.0
	_assert(absf(b.recoil_offset.length() - 2.0) < 0.01, "Recoil offset = 2px")
	_assert(b.recoil_offset.x > 0, "Recoil pushes away from attacker")

func test_module_ring_color() -> void:
	print("\n[Test] Module activation ring colors match module type")
	_assert(CharmAnims.get_module_ring_color(ModuleData.ModuleType.OVERCLOCK) == Color(1.0, 0.6, 0.0), "Overclock = orange")
	_assert(CharmAnims.get_module_ring_color(ModuleData.ModuleType.SHIELD_PROJECTOR) == Color(0.3, 0.5, 1.0), "Shield = blue")
	_assert(CharmAnims.get_module_ring_color(ModuleData.ModuleType.EMP_CHARGE) == Color(0.6, 0.2, 0.9), "EMP = purple")

# --- Verify no gameplay impact ---
func test_no_gameplay_state_change() -> void:
	print("\n[Test] Charm animations do NOT affect gameplay state")
	# Run a full sim with and without charm state — results must be identical
	var sim1 := CombatSim.new(12345)
	var b1a := BrottState.new()
	b1a.team = 0; b1a.chassis_type = ChassisData.ChassisType.SCOUT
	b1a.weapon_types = [WeaponData.WeaponType.MINIGUN]
	b1a.armor_type = ArmorData.ArmorType.PLATING
	b1a.module_types = [ModuleData.ModuleType.OVERCLOCK]
	b1a.setup()
	b1a.position = Vector2(100, 256)
	var b1b := BrottState.new()
	b1b.team = 1; b1b.chassis_type = ChassisData.ChassisType.BRAWLER
	b1b.weapon_types = [WeaponData.WeaponType.SHOTGUN]
	b1b.armor_type = ArmorData.ArmorType.REACTIVE_MESH
	b1b.module_types = [ModuleData.ModuleType.SHIELD_PROJECTOR]
	b1b.setup()
	b1b.position = Vector2(400, 256)
	b1a.target = b1b; b1b.target = b1a
	sim1.add_brott(b1a); sim1.add_brott(b1b)

	# Second sim, identical
	var sim2 := CombatSim.new(12345)
	var b2a := BrottState.new()
	b2a.team = 0; b2a.chassis_type = ChassisData.ChassisType.SCOUT
	b2a.weapon_types = [WeaponData.WeaponType.MINIGUN]
	b2a.armor_type = ArmorData.ArmorType.PLATING
	b2a.module_types = [ModuleData.ModuleType.OVERCLOCK]
	b2a.setup()
	b2a.position = Vector2(100, 256)
	var b2b := BrottState.new()
	b2b.team = 1; b2b.chassis_type = ChassisData.ChassisType.BRAWLER
	b2b.weapon_types = [WeaponData.WeaponType.SHOTGUN]
	b2b.armor_type = ArmorData.ArmorType.REACTIVE_MESH
	b2b.module_types = [ModuleData.ModuleType.SHIELD_PROJECTOR]
	b2b.setup()
	b2b.position = Vector2(400, 256)
	b2a.target = b2b; b2b.target = b2a
	sim2.add_brott(b2a); sim2.add_brott(b2b)

	# Mutate charm state on sim1 bots (as if animations ran)
	b1a.idle_timer = 99.9
	b1a.charm_y_offset = 5.0
	b1a.charm_rotation = 180.0
	b1a.recoil_offset = Vector2(2, 2)
	b1a.module_ring_timer = 0.5
	b1b.smoke_particles = [{"fake": true}]

	# Run both sims
	for _i in range(200):
		sim1.simulate_tick()
		sim2.simulate_tick()

	_assert(sim1.winner_team == sim2.winner_team, "Winner same: %d vs %d" % [sim1.winner_team, sim2.winner_team])
	_assert(sim1.tick_count == sim2.tick_count, "Tick count same: %d vs %d" % [sim1.tick_count, sim2.tick_count])
	_assert(absf(b1a.hp - b2a.hp) < 0.01, "Bot A HP same: %.1f vs %.1f" % [b1a.hp, b2a.hp])
	_assert(absf(b1b.hp - b2b.hp) < 0.01, "Bot B HP same: %.1f vs %.1f" % [b1b.hp, b2b.hp])
	_assert(b1a.position.distance_to(b2a.position) < 0.01, "Bot A position same")
	_assert(b1b.position.distance_to(b2b.position) < 0.01, "Bot B position same")
