## Diagnostic: Scout-vs-Scout mirror match WR at N=200 to tighten confidence
## on the test_sprint13_3 Scout-mirror pass (normally N=30 per file).
## Usage: godot --headless --path . --script res://tests/diag_mirror_n200.gd
extends SceneTree

const TILE: float = 32.0
const N_MATCHES: int = 200

func _mk(team: int, name_: String) -> BrottState:
	var b := BrottState.new()
	b.chassis_type = ChassisData.ChassisType.SCOUT
	b.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]  # matches test_sprint13_3
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.team = team
	b.bot_name = name_
	b.setup()
	return b

func _initialize() -> void:
	var t0_wins: int = 0
	var t1_wins: int = 0
	var draws: int = 0
	for seed_val in range(N_MATCHES):
		var sim := CombatSim.new(seed_val)
		var a := _mk(0, "A")
		var b := _mk(1, "B")
		# Symmetric spawn around arena center.
		a.position = Vector2(64.0, 256.0)
		b.position = Vector2(448.0, 256.0)
		sim.add_brott(a)
		sim.add_brott(b)
		for _i in range(1200):
			if sim.match_over:
				break
			sim.simulate_tick()
		if sim.winner_team == 0:
			t0_wins += 1
		elif sim.winner_team == 1:
			t1_wins += 1
		else:
			draws += 1
	var total_decided: int = t0_wins + t1_wins
	var wr: float = (float(t0_wins) / float(total_decided)) * 100.0 if total_decided > 0 else 0.0
	print("Scout-vs-Scout mirror N=%d: team0=%d team1=%d draws=%d WR=%.1f%%" % [N_MATCHES, t0_wins, t1_wins, draws, wr])
	# Also run swapped team order — a and b swap spawn positions / team ids.
	var sa_t0: int = 0
	var sa_t1: int = 0
	var sa_d: int = 0
	for seed_val in range(N_MATCHES):
		var sim := CombatSim.new(seed_val)
		var a := _mk(0, "A")
		var b := _mk(1, "B")
		# Swapped: team 0 now on the RIGHT, team 1 on the LEFT.
		# Swap: team 0 now on the RIGHT.
		a.position = Vector2(448.0, 256.0)
		b.position = Vector2(64.0, 256.0)
		sim.add_brott(a)
		sim.add_brott(b)
		for _i in range(1200):
			if sim.match_over:
				break
			sim.simulate_tick()
		if sim.winner_team == 0:
			sa_t0 += 1
		elif sim.winner_team == 1:
			sa_t1 += 1
		else:
			sa_d += 1
	var sa_total: int = sa_t0 + sa_t1
	var sa_wr: float = (float(sa_t0) / float(sa_total)) * 100.0 if sa_total > 0 else 0.0
	print("SWAPPED spawn N=%d: team0=%d team1=%d draws=%d WR=%.1f%%" % [N_MATCHES, sa_t0, sa_t1, sa_d, sa_wr])
	quit(0)
