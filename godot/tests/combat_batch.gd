## Run 600 headless combat matches for balance verification
extends SceneTree

const MATCHES_PER_MATCHUP := 100
const CHASSIS_NAMES := ["Scout", "Brawler", "Fortress"]

var results := {}  # "Scout_vs_Brawler" -> {wins_a, wins_b, draws}
var weapon_usage := {}  # weapon_name -> times_equipped
var total_matches := 0

func _init() -> void:
	print("=== BattleBrotts Combat Simulation ===\n")
	
	var chassis_types := [
		ChassisData.ChassisType.SCOUT,
		ChassisData.ChassisType.BRAWLER,
		ChassisData.ChassisType.FORTRESS,
	]
	var weapon_types := [
		WeaponData.WeaponType.MINIGUN,
		WeaponData.WeaponType.RAILGUN,
		WeaponData.WeaponType.SHOTGUN,
		WeaponData.WeaponType.MISSILE_POD,
		WeaponData.WeaponType.PLASMA_CUTTER,
		WeaponData.WeaponType.ARC_EMITTER,
		WeaponData.WeaponType.FLAK_CANNON,
	]
	
	# Initialize weapon usage
	for wt in weapon_types:
		var wd := WeaponData.get_weapon(wt)
		weapon_usage[wd["name"]] = 0
	
	# Run all chassis matchups
	for i in range(chassis_types.size()):
		for j in range(i, chassis_types.size()):
			var ca: ChassisData.ChassisType = chassis_types[i]
			var cb: ChassisData.ChassisType = chassis_types[j]
			var key := "%s_vs_%s" % [CHASSIS_NAMES[i], CHASSIS_NAMES[j]]
			results[key] = {"wins_a": 0, "wins_b": 0, "draws": 0}
			
			for m in MATCHES_PER_MATCHUP:
				var seed_val := i * 10000 + j * 1000 + m
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_val
				
				# Random loadout for each bot
				var w1a: WeaponData.WeaponType = weapon_types[rng.randi() % weapon_types.size()]
				var w1b: WeaponData.WeaponType = weapon_types[rng.randi() % weapon_types.size()]
				var w2a: WeaponData.WeaponType = weapon_types[rng.randi() % weapon_types.size()]
				var w2b: WeaponData.WeaponType = weapon_types[rng.randi() % weapon_types.size()]
				
				weapon_usage[WeaponData.get_weapon(w1a)["name"]] += 1
				weapon_usage[WeaponData.get_weapon(w1b)["name"]] += 1
				weapon_usage[WeaponData.get_weapon(w2a)["name"]] += 1
				weapon_usage[WeaponData.get_weapon(w2b)["name"]] += 1
				
				var sim := CombatSim.new(seed_val)
				
				var b1 := BrottState.new()
				b1.team = 0
				b1.chassis_type = ca
				b1.weapon_types = [w1a, w1b] as Array[WeaponData.WeaponType]
				b1.armor_type = ArmorData.ArmorType.NONE
				b1.module_types = [] as Array[ModuleData.ModuleType]
				b1.position = Vector2(64, 256)
				b1.stance = rng.randi() % 3
				b1.setup()
				
				var b2 := BrottState.new()
				b2.team = 1
				b2.chassis_type = cb
				b2.weapon_types = [w2a, w2b] as Array[WeaponData.WeaponType]
				b2.armor_type = ArmorData.ArmorType.NONE
				b2.module_types = [] as Array[ModuleData.ModuleType]
				b2.position = Vector2(448, 256)
				b2.stance = rng.randi() % 3
				b2.setup()
				
				sim.add_brott(b1)
				sim.add_brott(b2)
				
				while not sim.match_over:
					sim.simulate_tick()
				
				if sim.winner_team == 0:
					results[key]["wins_a"] += 1
				elif sim.winner_team == 1:
					results[key]["wins_b"] += 1
				else:
					results[key]["draws"] += 1
				
				total_matches += 1
	
	# Print results
	print("Total matches: %d\n" % total_matches)
	
	# Chassis win tracking
	var chassis_wins := {"Scout": 0, "Brawler": 0, "Fortress": 0}
	var chassis_matches := {"Scout": 0, "Brawler": 0, "Fortress": 0}
	
	print("--- Matchup Results ---")
	for key in results:
		var r = results[key]
		var parts: PackedStringArray = key.split("_vs_")
		var na: String = parts[0]
		var nb: String = parts[1]
		var total: int = r["wins_a"] + r["wins_b"] + r["draws"]
		var pct_a: float = 100.0 * r["wins_a"] / total if total > 0 else 0.0
		var pct_b: float = 100.0 * r["wins_b"] / total if total > 0 else 0.0
		print("%s: %s wins %d (%.1f%%), %s wins %d (%.1f%%), draws %d" % [
			key, na, r["wins_a"], pct_a, nb, r["wins_b"], pct_b, r["draws"]
		])
		
		chassis_wins[na] += r["wins_a"]
		chassis_matches[na] += total
		chassis_wins[nb] += r["wins_b"]
		chassis_matches[nb] += total
	
	print("\n--- Overall Chassis Win Rates ---")
	for name in chassis_wins:
		var wr: float = 100.0 * chassis_wins[name] / chassis_matches[name] if chassis_matches[name] > 0 else 0.0
		print("%s: %d/%d (%.1f%%)" % [name, chassis_wins[name], chassis_matches[name], wr])
	
	print("\n--- Weapon Usage ---")
	for wname in weapon_usage:
		print("%s: %d" % [wname, weapon_usage[wname]])
	
	print("\n=== Simulation Complete ===")
	quit(0)
