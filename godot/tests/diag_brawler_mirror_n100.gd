## Diagnostic: Brawler-vs-Brawler mirror WR at N=100 and swapped-spawn N=100
## to determine whether the sprint13_3 Brawler-mirror 72.7% is a real bias
## or N=30 variance. Gizmo S17.2-003 design memo.
extends SceneTree

const N_MATCHES: int = 100

func _mk(team: int, name_: String) -> BrottState:
	var b := BrottState.new()
	b.chassis_type = ChassisData.ChassisType.BRAWLER
	b.weapon_types = [WeaponData.WeaponType.SHOTGUN]
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.team = team
	b.bot_name = name_
	b.setup()
	return b

func _run(n: int, left_team: int, right_team: int, label: String) -> void:
	var t0_wins: int = 0
	var t1_wins: int = 0
	var draws: int = 0
	for seed_val in range(n):
		var sim := CombatSim.new(seed_val)
		var a := _mk(left_team, "L")
		var b := _mk(right_team, "R")
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
	var decided: int = t0_wins + t1_wins
	var wr: float = (float(t0_wins) / float(decided)) * 100.0 if decided > 0 else 0.0
	print("%s N=%d: team0=%d team1=%d draws=%d team0_WR=%.1f%%" % [label, n, t0_wins, t1_wins, draws, wr])

func _initialize() -> void:
	# Canonical: team 0 on LEFT, team 1 on RIGHT.
	_run(N_MATCHES, 0, 1, "Brawler-mirror canonical (L=team0)")
	# Swapped: team 0 on RIGHT.
	_run(N_MATCHES, 1, 0, "Brawler-mirror swapped  (L=team1)")
	quit(0)
