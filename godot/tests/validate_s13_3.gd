## S13.3 Validation Sweep — N=100 per matchup, print PR-ready summary
extends SceneTree

const N: int = 100

func _init() -> void:
	print("## S13.3 Validation — N=%d per matchup\n" % N)
	print("| Matchup | Side-A WR | Mean TTM | σ TTM | Per-shot HR | Per-pellet HR |")
	print("|---|---|---|---|---|---|")

	var matchups := [
		["Scout vs Scout",       ChassisData.ChassisType.SCOUT,    ChassisData.ChassisType.SCOUT,
			[WeaponData.WeaponType.PLASMA_CUTTER], [WeaponData.WeaponType.PLASMA_CUTTER]],
		["Brawler vs Brawler",   ChassisData.ChassisType.BRAWLER,  ChassisData.ChassisType.BRAWLER,
			[WeaponData.WeaponType.SHOTGUN],       [WeaponData.WeaponType.SHOTGUN]],
		["Fortress vs Fortress", ChassisData.ChassisType.FORTRESS, ChassisData.ChassisType.FORTRESS,
			[WeaponData.WeaponType.MINIGUN],       [WeaponData.WeaponType.MINIGUN]],
		["Scout vs Brawler",     ChassisData.ChassisType.SCOUT,    ChassisData.ChassisType.BRAWLER,
			[WeaponData.WeaponType.PLASMA_CUTTER], [WeaponData.WeaponType.SHOTGUN]],
		["Scout vs Fortress",    ChassisData.ChassisType.SCOUT,    ChassisData.ChassisType.FORTRESS,
			[WeaponData.WeaponType.PLASMA_CUTTER], [WeaponData.WeaponType.MINIGUN]],
		["Brawler vs Fortress",  ChassisData.ChassisType.BRAWLER,  ChassisData.ChassisType.FORTRESS,
			[WeaponData.WeaponType.SHOTGUN],       [WeaponData.WeaponType.MINIGUN]],
	]
	for m in matchups:
		_run(m[0], m[1], m[2], m[3], m[4])
	quit(0)

func _bot(team: int, chassis: int, weapons: Array) -> BrottState:
	var b := BrottState.new()
	b.team = team
	b.bot_name = "bot%d" % team
	b.chassis_type = chassis
	b.weapon_types.assign(weapons)
	b.armor_type = ArmorData.ArmorType.NONE
	b.module_types = []
	b.stance = 0
	b.setup()
	return b

func _run(label: String, c_a: int, c_b: int, w_a: Array, w_b: Array) -> void:
	var team0 := 0
	var team1 := 0
	var draws := 0
	var durs: Array[float] = []
	var sf := 0; var sh := 0; var pf := 0; var ph := 0
	for seed_val in range(N):
		var b0 := _bot(0, c_a, w_a); b0.position = Vector2(64, 256)
		var b1 := _bot(1, c_b, w_b); b1.position = Vector2(448, 256)
		var sim := CombatSim.new(seed_val)
		sim.add_brott(b0); sim.add_brott(b1)
		for _t in range(1200):
			if sim.match_over: break
			sim.simulate_tick()
		if sim.winner_team == 0: team0 += 1
		elif sim.winner_team == 1: team1 += 1
		else: draws += 1
		durs.append(float(sim.tick_count) / float(CombatSim.TICKS_PER_SEC))
		for k in sim.shots_fired: sf += int(sim.shots_fired[k])
		for k in sim.shots_hit: sh += int(sim.shots_hit[k])
		for k in sim.pellets_fired: pf += int(sim.pellets_fired[k])
		for k in sim.pellets_hit: ph += int(sim.pellets_hit[k])
	var decisive := team0 + team1
	var wr := 0.5 if decisive == 0 else float(team0) / float(decisive)
	var mean := 0.0
	for d in durs: mean += d
	mean /= float(durs.size())
	var var_sum := 0.0
	for d in durs: var_sum += (d - mean) * (d - mean)
	var stddev: float = sqrt(var_sum / float(durs.size()))
	var shr := 0.0 if sf == 0 else float(sh) / float(sf)
	var phr := 0.0 if pf == 0 else float(ph) / float(pf)
	print("| %s | %.1f%% (%d/%d/%d) | %.1fs | %.1fs | %.1f%% | %.1f%% |" % [
		label, wr * 100.0, team0, team1, draws, mean, stddev, shr * 100.0, phr * 100.0
	])
