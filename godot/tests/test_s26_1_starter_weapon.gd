## test_s26_1_starter_weapon.gd — [S26.1-003] Battle-start fix regression tests
##
## Pre-S26.1 behavior: RunState._init() left equipped_weapons = [], so the
## player entered battle 1 unarmed. The arena rendered, the player couldn't
## fire, the swarm killed them in seconds — playtest reported as "blank
## screen" because nothing meaningful happened on-screen.
##
## Post-S26.1 behavior: RunState._init() seeds equipped_weapons with the
## Plasma Cutter (WeaponData.WeaponType.PLASMA_CUTTER == 4) when the array
## is empty, guaranteeing every new run enters battle 1 with at least one
## firing weapon. These assertions all FAIL on main @ 9aa417f and PASS
## post-fix.
extends SceneTree

const PLASMA_CUTTER := 4  # WeaponData.WeaponType.PLASMA_CUTTER

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	# T1: Default-constructed RunState has at least one weapon.
	var rs := RunState.new()
	assert(rs.equipped_weapons.size() > 0, "S26.1: default RunState must start with >=1 weapon")
	assert(PLASMA_CUTTER in rs.equipped_weapons, "S26.1: starter weapon must be Plasma Cutter (4)")
	pass_count += 2

	# T2: All three chassis archetypes start armed.
	for chassis_type in [0, 1, 2]:
		var rs_c := RunState.new(chassis_type)
		assert(rs_c.equipped_weapons.size() > 0, "S26.1: chassis %d must start with >=1 weapon" % chassis_type)
		assert(PLASMA_CUTTER in rs_c.equipped_weapons, "S26.1: chassis %d starter must be Plasma Cutter" % chassis_type)
		pass_count += 2

	# T3: build_player_brott() carries the starter weapon onto BrottState.
	# This is the path the arena actually uses — if the BrottState has no
	# weapons, the player can't fire, even if equipped_weapons is non-empty.
	var rs_b := RunState.new(1)  # Brawler chassis
	var b := rs_b.build_player_brott()
	assert(b != null, "S26.1: build_player_brott must produce a BrottState")
	assert(b.weapon_types.size() > 0, "S26.1: built player BrottState must carry >=1 weapon")
	assert(PLASMA_CUTTER in b.weapon_types, "S26.1: built BrottState weapon must be Plasma Cutter")
	pass_count += 3

	# T4: Adding more weapons via add_item still works (starter doesn't block growth).
	var rs_d := RunState.new(0)
	var added := rs_d.add_item("weapon", 0)  # MINIGUN
	assert(added, "S26.1: add_item('weapon', MINIGUN) should succeed on a starter loadout")
	assert(rs_d.equipped_weapons.size() == 2, "S26.1: starter + added weapon = 2")
	pass_count += 2

	# T5: Deterministic seed still produces a starter weapon.
	var rs_seed := RunState.new(2, 12345)
	assert(rs_seed.seed == 12345, "S26.1: seed plumbing unchanged")
	assert(rs_seed.equipped_weapons.size() > 0, "S26.1: seeded RunState still gets a starter weapon")
	pass_count += 2

	print("test_s26_1_starter_weapon: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
