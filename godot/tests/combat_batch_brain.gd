## Combat sim batch — runs 500+ matches with BrottBrain smart defaults
## Usage: godot --headless --script tests/combat_batch_brain.gd
extends SceneTree

func _init() -> void:
	print("=== BrottBrain Combat Sims (500+ matches) ===\n")
	
	var chassis_names := ["Scout", "Brawler", "Fortress"]
	var results := {}  # "A_vs_B" -> [wins_a, wins_b, draws]
	
	# All chassis matchups: 3x3 = 9 combos, ~60 matches each = 540+
	for a in 3:
		for b in 3:
			var key := "%s_vs_%s" % [chassis_names[a], chassis_names[b]]
			var wins_a := 0
			var wins_b := 0
			var draws := 0
			
			for i in 60:
				var sim := CombatSim.new(i * 1000 + a * 100 + b)
				
				var brott_a := _make_brott_with_brain(0, a)
				brott_a.position = Vector2(64, 256)
				
				var brott_b := _make_brott_with_brain(1, b)
				brott_b.position = Vector2(448, 256)
				
				sim.add_brott(brott_a)
				sim.add_brott(brott_b)
				
				# Run up to 2400 ticks (2 min)
				for t in 2400:
					if sim.match_over:
						break
					sim.simulate_tick()
				
				if not brott_a.alive and not brott_b.alive:
					draws += 1
				elif not brott_b.alive:
					wins_a += 1
				elif not brott_a.alive:
					wins_b += 1
				else:
					# Timeout — higher HP% wins
					var hp_a := brott_a.hp / brott_a.max_hp
					var hp_b := brott_b.hp / brott_b.max_hp
					if hp_a > hp_b:
						wins_a += 1
					elif hp_b > hp_a:
						wins_b += 1
					else:
						draws += 1
			
			results[key] = [wins_a, wins_b, draws]
			var total := wins_a + wins_b + draws
			var wr_a := 100.0 * wins_a / total
			var wr_b := 100.0 * wins_b / total
			print("%s: %d-%d-%d (%.0f%% / %.0f%%)" % [key, wins_a, wins_b, draws, wr_a, wr_b])
	
	# Summary
	print("\n=== Summary ===")
	var total_matches := 0
	var decisive := 0
	for key in results:
		var r = results[key]
		total_matches += r[0] + r[1] + r[2]
		decisive += r[0] + r[1]
	
	print("Total matches: %d" % total_matches)
	print("Decisive: %d (%.0f%%)" % [decisive, 100.0 * decisive / total_matches])
	
	# Per-chassis overall win rate
	for c in 3:
		var wins := 0
		var played := 0
		for opp in 3:
			var key := "%s_vs_%s" % [chassis_names[c], chassis_names[opp]]
			var r = results[key]
			wins += r[0]
			played += r[0] + r[1] + r[2]
		print("%s overall: %d/%d (%.0f%%)" % [chassis_names[c], wins, played, 100.0 * wins / played])
	
	quit(0)

func _make_brott_with_brain(team: int, chassis_type: int) -> BrottState:
	var chassis_enum : ChassisData.ChassisType = chassis_type as ChassisData.ChassisType
	var b := BrottState.new()
	b.team = team
	b.chassis_type = chassis_enum
	
	# Default loadout per chassis
	match chassis_type:
		0:  # Scout
			b.weapon_types = [WeaponData.WeaponType.PLASMA_CUTTER]
			b.armor_type = ArmorData.ArmorType.PLATING
			b.module_types = []
		1:  # Brawler
			b.weapon_types = [WeaponData.WeaponType.MINIGUN, WeaponData.WeaponType.PLASMA_CUTTER]
			b.armor_type = ArmorData.ArmorType.PLATING
			b.module_types = [ModuleData.ModuleType.OVERCLOCK]
		2:  # Fortress
			b.weapon_types = [WeaponData.WeaponType.RAILGUN, WeaponData.WeaponType.PLASMA_CUTTER]
			b.armor_type = ArmorData.ArmorType.ABLATIVE_SHELL
			b.module_types = [ModuleData.ModuleType.REPAIR_NANITES]
	
	b.setup()
	b.brain = BrottBrain.default_for_chassis(chassis_type)
	return b
