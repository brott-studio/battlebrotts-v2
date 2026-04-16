## S13.2 Fix Validation — cross-chassis TCR + hit rate tuning
extends SceneTree

func _init() -> void:
	print("=== S13.2 Fix Validation ===\n")
	
	var matchups := [
		["Scout vs Scout", ChassisData.ChassisType.SCOUT, ChassisData.ChassisType.SCOUT,
			[WeaponData.WeaponType.PLASMA_CUTTER], [WeaponData.WeaponType.PLASMA_CUTTER]],
		["Brawler vs Brawler", ChassisData.ChassisType.BRAWLER, ChassisData.ChassisType.BRAWLER,
			[WeaponData.WeaponType.SHOTGUN], [WeaponData.WeaponType.SHOTGUN]],
		["Fortress vs Fortress", ChassisData.ChassisType.FORTRESS, ChassisData.ChassisType.FORTRESS,
			[WeaponData.WeaponType.MINIGUN], [WeaponData.WeaponType.MINIGUN]],
		["Scout vs Fortress", ChassisData.ChassisType.SCOUT, ChassisData.ChassisType.FORTRESS,
			[WeaponData.WeaponType.PLASMA_CUTTER], [WeaponData.WeaponType.MINIGUN]],
		["Scout vs Brawler", ChassisData.ChassisType.SCOUT, ChassisData.ChassisType.BRAWLER,
			[WeaponData.WeaponType.PLASMA_CUTTER], [WeaponData.WeaponType.SHOTGUN]],
		["Brawler vs Fortress", ChassisData.ChassisType.BRAWLER, ChassisData.ChassisType.FORTRESS,
			[WeaponData.WeaponType.SHOTGUN], [WeaponData.WeaponType.MINIGUN]],
	]
	
	for m in matchups:
		_run_matchup(m[0], m[1], m[2], m[3], m[4])
	
	print("\n=== Validation Complete ===")
	quit(0)

func _run_matchup(label: String, c0: ChassisData.ChassisType, c1: ChassisData.ChassisType,
		w0: Array, w1: Array) -> void:
	print("--- %s (100 sims) ---" % label)
	var durations: Array[float] = []
	var hit_rates_all: Array[float] = []
	var tcr_cycles: Array[int] = []
	var team0_wins := 0
	var team1_wins := 0
	var draws := 0
	
	for seed_val in range(100):
		var b0 := BrottState.new()
		b0.team = 0
		b0.bot_name = "Bot0"
		b0.chassis_type = c0
		b0.weapon_types.assign(w0)
		b0.armor_type = ArmorData.ArmorType.NONE
		b0.module_types = []
		b0.stance = 0
		b0.setup()
		b0.position = Vector2(64, 256)
		
		var b1 := BrottState.new()
		b1.team = 1
		b1.bot_name = "Bot1"
		b1.chassis_type = c1
		b1.weapon_types.assign(w1)
		b1.armor_type = ArmorData.ArmorType.NONE
		b1.module_types = []
		b1.stance = 0
		b1.setup()
		b1.position = Vector2(448, 256)
		
		var sim := CombatSim.new(seed_val)
		sim.json_log_enabled = true
		sim.add_brott(b0)
		sim.add_brott(b1)
		
		for _t in range(1000):
			if sim.match_over:
				break
			sim.simulate_tick()
		
		var dur: float = float(sim.tick_count) / 10.0
		durations.append(dur)
		
		if sim.winner_team == 0: team0_wins += 1
		elif sim.winner_team == 1: team1_wins += 1
		else: draws += 1
		
		# Hit rates
		var hr := sim.get_hit_rates()
		for wname in hr:
			hit_rates_all.append(hr[wname])
		
		# Count TCR cycles for bot0
		var tension_entries := 0
		for entry in sim.get_json_log():
			for ev in entry["events"]:
				if ev.get("type", "") == "tcr_phase" and ev.get("phase", "") == "TENSION" and ev.get("bot_id", "") == "Bot0":
					tension_entries += 1
				if ev.get("type", "") == "tcr_resume" and ev.get("bot_id", "") == "Bot0":
					tension_entries += 0  # resume doesn't count as new cycle
		tcr_cycles.append(tension_entries)
	
	var avg_dur: float = 0.0
	for d in durations: avg_dur += d
	avg_dur /= float(durations.size())
	
	var avg_hr: float = 0.0
	if hit_rates_all.size() > 0:
		for h in hit_rates_all: avg_hr += h
		avg_hr /= float(hit_rates_all.size())
	
	var avg_cycles: float = 0.0
	for c in tcr_cycles: avg_cycles += float(c)
	avg_cycles /= float(tcr_cycles.size())
	
	print("  Duration: avg %.1fs (min %.1f, max %.1f)" % [avg_dur, durations.min(), durations.max()])
	print("  Hit rate: avg %.1f%%" % (avg_hr * 100.0))
	print("  TCR cycles (bot0): avg %.1f" % avg_cycles)
	print("  Wins: T0=%d T1=%d Draw=%d" % [team0_wins, team1_wins, draws])
