## test_s26_1_starter_weapon.gd — [S26.1-003] Battle-start fix regression tests
##
## Pre-S26.1 behavior: RunState._init() left equipped_weapons = [], so the
## player entered battle 1 unarmed. The arena rendered, the player couldn't
## fire, the swarm killed them in seconds — playtest reported as "blank
## screen" because nothing meaningful happened on-screen.
##
## Post-S26.1 behavior: RunState._init() seeds equipped_weapons with a
## chassis-appropriate starter weapon when the array is empty:
##   - Brawler (chassis 1): Shotgun (WeaponData.WeaponType.SHOTGUN == 2)
##     [K.4: closes mobility gap vs kiting opponents at T1, #314]
##   - Scout (chassis 0): Plasma Cutter (WeaponData.WeaponType.PLASMA_CUTTER == 4)
##   - Fortress (chassis 2): Flak Cannon (WeaponData.WeaponType.FLAK_CANNON == 6)
##     [M.2b: Plasma Cutter range 2.5 unplayable at 60 px/s vs 150HP T1]
## These assertions all FAIL on main @ 9aa417f and PASS post-fix.
extends SceneTree

const PLASMA_CUTTER := 4  # WeaponData.WeaponType.PLASMA_CUTTER
const SHOTGUN := 2         # WeaponData.WeaponType.SHOTGUN  [K.4: Brawler T1 starter]
const FLAK_CANNON := 6     # WeaponData.WeaponType.FLAK_CANNON  [M.2b: Fortress T1 starter]

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	# T1: Default-constructed RunState (Scout chassis 0) has at least one weapon.
	var rs := RunState.new()
	assert(rs.equipped_weapons.size() > 0, "S26.1: default RunState must start with >=1 weapon")
	assert(PLASMA_CUTTER in rs.equipped_weapons, "S26.1: Scout default starter weapon must be Plasma Cutter (4)")
	pass_count += 2

	# T2a: Scout (0) starts with Plasma Cutter.
	var rs_scout := RunState.new(0)
	assert(rs_scout.equipped_weapons.size() > 0, "S26.1: Scout must start with >=1 weapon")
	assert(PLASMA_CUTTER in rs_scout.equipped_weapons, "S26.1: Scout starter must be Plasma Cutter (4)")
	pass_count += 2

	# T2b: Fortress (2) starts with Flak Cannon. [M.2b]
	# Plasma Cutter range 2.5 was unplayable at 60 px/s vs 150HP T1 opponents.
	var rs_fortress := RunState.new(2)
	assert(rs_fortress.equipped_weapons.size() > 0, "M.2b: Fortress must start with >=1 weapon")
	assert(FLAK_CANNON in rs_fortress.equipped_weapons, "M.2b: Fortress starter must be Flak Cannon (6)")
	pass_count += 2

	# T2c: Brawler (1) starts with Shotgun. [K.4]
	var rs_brawler := RunState.new(1)
	assert(rs_brawler.equipped_weapons.size() > 0, "K.4: Brawler must start with >=1 weapon")
	assert(SHOTGUN in rs_brawler.equipped_weapons, "K.4: Brawler starter must be Shotgun (2) to close T1 mobility gap (#314)")
	pass_count += 2

	# T3: build_player_brott() carries the Brawler Shotgun starter onto BrottState.
	# This is the path the arena actually uses — if the BrottState has no
	# weapons, the player can't fire, even if equipped_weapons is non-empty.
	var rs_b := RunState.new(1)  # Brawler chassis
	var b := rs_b.build_player_brott()
	assert(b != null, "S26.1: build_player_brott must produce a BrottState")
	assert(b.weapon_types.size() > 0, "S26.1: built player BrottState must carry >=1 weapon")
	assert(SHOTGUN in b.weapon_types, "K.4: built Brawler BrottState weapon must be Shotgun")
	pass_count += 3

	# T4: Adding more weapons via add_item still works (starter doesn't block growth).
	var rs_d := RunState.new(0)  # Scout with Plasma Cutter start
	var added := rs_d.add_item("weapon", 0)  # MINIGUN
	assert(added, "S26.1: add_item('weapon', MINIGUN) should succeed on a starter loadout")
	assert(rs_d.equipped_weapons.size() == 2, "S26.1: starter + added weapon = 2")
	pass_count += 2

	# T5: Deterministic seed still produces a starter weapon.
	var rs_seed := RunState.new(2, 12345)  # Fortress
	assert(rs_seed.seed == 12345, "S26.1: seed plumbing unchanged")
	assert(rs_seed.equipped_weapons.size() > 0, "S26.1: seeded RunState still gets a starter weapon")
	pass_count += 2

	print("test_s26_1_starter_weapon: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
