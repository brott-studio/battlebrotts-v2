## test_arc_n_1_first_battle_feel.gd — Arc N Sub-sprint N.1 AutoDriver assertions.
##
## Gates:
##   N1-1: archetype_for(0) == "first_battle_intro"; archetype_for(1..13) != "first_battle_intro"
##   N1-2: compose_encounter("first_battle_intro", 0, null) spec: hp==750, speed_override==50.0,
##          fire_rate_override==0.4, stance==0
##   N1-3: BrottState created from spec has speed_override==50.0, fire_rate_override==0.4,
##          get_effective_speed()==50.0
##   N1-4: RunStartScreen emits chassis_type==1 (Brawler) on Start Run pressed
##   N1-5: Fight duration: 50-seed batch Brawler+Shotgun vs first_battle_intro, median in [20, 40]s
##   N1-6: Player win rate >= 0.80 in same 50-seed batch
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	## ── N1-1: archetype_for(0) == "first_battle_intro" ──────────────────────────
	var n1_1_ok := true
	var arch_0 := OpponentLoadouts.archetype_for(0, null)
	if arch_0 != "first_battle_intro":
		push_error("N1-1 FAIL: archetype_for(0) expected 'first_battle_intro', got '%s'" % arch_0)
		n1_1_ok = false
	for idx in range(1, 14):
		var rng := RandomNumberGenerator.new()
		rng.seed = idx * 1000 + 7
		var mock_state := RunState.new(1, idx * 1000 + 7)
		var arch := OpponentLoadouts.archetype_for(idx, mock_state, rng)
		if arch == "first_battle_intro":
			push_error("N1-1 FAIL: archetype_for(%d) returned 'first_battle_intro' — should never appear for idx > 0" % idx)
			n1_1_ok = false
			break
	if n1_1_ok:
		print("PASS N1-1: archetype_for(0)='first_battle_intro', never appears at idx 1-13")
		pass_count += 1
	else:
		print("FAIL N1-1: first_battle_intro archetype selection incorrect")
		fail_count += 1

	## ── N1-2: compose_encounter spec fields ─────────────────────────────────────
	var n1_2_ok := true
	var specs := OpponentLoadouts.compose_encounter("first_battle_intro", 0, null)
	if specs.is_empty():
		push_error("N1-2 FAIL: compose_encounter('first_battle_intro', 0, null) returned empty")
		n1_2_ok = false
	else:
		var spec: Dictionary = specs[0]
		if spec.get("hp", -1) != 750:
			push_error("N1-2 FAIL: hp expected 750, got %d" % spec.get("hp", -1))
			n1_2_ok = false
		if absf(float(spec.get("speed_override", -999.0)) - 50.0) > 0.01:
			push_error("N1-2 FAIL: speed_override expected 50.0, got %s" % str(spec.get("speed_override", "MISSING")))
			n1_2_ok = false
		if absf(float(spec.get("fire_rate_override", -999.0)) - 0.4) > 0.001:
			push_error("N1-2 FAIL: fire_rate_override expected 0.4, got %s" % str(spec.get("fire_rate_override", "MISSING")))
			n1_2_ok = false
		if spec.get("stance", -1) != 0:
			push_error("N1-2 FAIL: stance expected 0, got %d" % spec.get("stance", -1))
			n1_2_ok = false
	if n1_2_ok:
		print("PASS N1-2: compose_encounter spec fields correct (hp=750, speed=50, fire_rate=0.4, stance=0)")
		pass_count += 1
	else:
		print("FAIL N1-2: first_battle_intro spec fields incorrect")
		fail_count += 1

	## ── N1-3: BrottState overrides applied ──────────────────────────────────────
	var n1_3_ok := true
	if not specs.is_empty():
		var spec: Dictionary = specs[0]
		var ebrott := BrottState.new()
		ebrott.team = 1
		ebrott.chassis_type = spec.get("chassis", 0)
		for wt in spec.get("weapons", []):
			ebrott.weapon_types.append(wt)
		ebrott.armor_type = spec.get("armor", 0)
		ebrott.setup()
		var spec_hp: int = spec.get("hp", ebrott.max_hp)
		if spec_hp > 0:
			ebrott.max_hp = spec_hp
			ebrott.hp = float(spec_hp)
		## Apply overrides (mirrors game_main.gd Arc N block)
		if "speed_override" in spec:
			ebrott.speed_override = float(spec["speed_override"])
		if "fire_rate_override" in spec:
			ebrott.fire_rate_override = float(spec["fire_rate_override"])
		if "stance" in spec:
			ebrott.stance = int(spec["stance"])

		if absf(ebrott.speed_override - 50.0) > 0.01:
			push_error("N1-3 FAIL: ebrott.speed_override expected 50.0, got %f" % ebrott.speed_override)
			n1_3_ok = false
		if absf(ebrott.fire_rate_override - 0.4) > 0.001:
			push_error("N1-3 FAIL: ebrott.fire_rate_override expected 0.4, got %f" % ebrott.fire_rate_override)
			n1_3_ok = false
		if absf(ebrott.get_effective_speed() - 50.0) > 0.01:
			push_error("N1-3 FAIL: get_effective_speed() expected 50.0 (override), got %f" % ebrott.get_effective_speed())
			n1_3_ok = false
	else:
		push_error("N1-3 SKIP: specs empty (N1-2 must pass first)")
		n1_3_ok = false
	if n1_3_ok:
		print("PASS N1-3: BrottState speed_override=50.0, fire_rate_override=0.4, get_effective_speed()=50.0")
		pass_count += 1
	else:
		print("FAIL N1-3: BrottState override application incorrect")
		fail_count += 1

	## ── N1-4: RunStartScreen emits chassis_type==1 ──────────────────────────────
	## (Headless unit test: instantiate RunStartScreen, connect signal, call setup, verify emission)
	var n1_4_ok := true
	var screen := RunStartScreen.new()
	var emitted_chassis: int = -1
	screen.start_run_requested.connect(func(ct: int): emitted_chassis = ct)
	screen.setup(0)
	## Programmatically find the StartRunBtn and simulate press
	var btn: Button = screen.get_node_or_null("StartRunBtn")
	if btn == null:
		push_error("N1-4 FAIL: StartRunBtn not found on RunStartScreen after setup()")
		n1_4_ok = false
	else:
		btn.emit_signal("pressed")
		if emitted_chassis != 1:
			push_error("N1-4 FAIL: start_run_requested emitted chassis_type=%d, expected 1" % emitted_chassis)
			n1_4_ok = false
	screen.queue_free()
	if n1_4_ok:
		print("PASS N1-4: RunStartScreen emits chassis_type=1 (Brawler)")
		pass_count += 1
	else:
		print("FAIL N1-4: RunStartScreen chassis emission incorrect")
		fail_count += 1

	## ── N1-5+6: 50-seed batch: fight duration + player win rate ─────────────────
	var durations: Array[float] = []
	var player_wins: int = 0
	var total_runs: int = 50

	for seed_val in range(total_runs):
		var sim := CombatSim.new(seed_val)
		## Player: Brawler + Shotgun (chassis_type=1, WeaponType.SHOTGUN=2)
		var player := BrottState.new()
		player.team = 0
		player.bot_name = "Player"
		player.chassis_type = ChassisData.ChassisType.BRAWLER
		player.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
		player.armor_type = ArmorData.ArmorType.NONE
		player.setup()
		player.position = Vector2(4 * 32.0, 8 * 32.0)
		player.brain = BrottBrain.default_for_chassis(1)
		sim.add_brott(player)

		## Enemy: first_battle_intro spec
		var e_specs := OpponentLoadouts.compose_encounter("first_battle_intro", 0, null)
		var e_spec: Dictionary = e_specs[0] if not e_specs.is_empty() else {}
		var enemy := BrottState.new()
		enemy.team = 1
		enemy.bot_name = "Enemy"
		enemy.chassis_type = e_spec.get("chassis", 0)
		for wt in e_spec.get("weapons", []):
			enemy.weapon_types.append(wt)
		enemy.armor_type = e_spec.get("armor", 0)
		enemy.setup()
		var e_hp: int = e_spec.get("hp", enemy.max_hp)
		if e_hp > 0:
			enemy.max_hp = e_hp
			enemy.hp = float(e_hp)
		if "speed_override" in e_spec:
			enemy.speed_override = float(e_spec["speed_override"])
		if "fire_rate_override" in e_spec:
			enemy.fire_rate_override = float(e_spec["fire_rate_override"])
		if "stance" in e_spec:
			enemy.stance = int(e_spec["stance"])
		enemy.position = Vector2(12 * 32.0, 8 * 32.0)
		enemy.brain = BrottBrain.default_for_chassis(enemy.chassis_type)
		sim.add_brott(enemy)

		## Run until match over (cap at 1000 ticks = 100s)
		for _tick in range(1000):
			if sim.match_over:
				break
			sim.simulate_tick()

		var dur_sec: float = float(sim.tick_count) / float(CombatSim.TICKS_PER_SEC)
		durations.append(dur_sec)
		if sim.winner_team == 0:
			player_wins += 1

	## Gate N1-5: median duration in [20, 40]s
	durations.sort()
	var median: float = durations[25] if durations.size() >= 50 else 0.0
	if median >= 20.0 and median <= 40.0:
		print("PASS N1-5: median fight duration %.1fs in [20, 40]s" % median)
		pass_count += 1
	else:
		push_error("N1-5 FAIL: median fight duration %.1fs — expected in [20, 40]s" % median)
		print("FAIL N1-5: median fight duration %.1fs not in [20, 40]s" % median)
		fail_count += 1

	## Gate N1-6: player win rate >= 0.80
	var win_rate: float = float(player_wins) / float(total_runs)
	if win_rate >= 0.80:
		print("PASS N1-6: player win rate %.0f%% (>= 80%%)" % (win_rate * 100.0))
		pass_count += 1
	else:
		push_error("N1-6 FAIL: player win rate %.0f%% — expected >= 80%%" % (win_rate * 100.0))
		print("FAIL N1-6: player win rate %.0f%% < 80%%" % (win_rate * 100.0))
		fail_count += 1

	print("test_arc_n_1_first_battle_feel: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
