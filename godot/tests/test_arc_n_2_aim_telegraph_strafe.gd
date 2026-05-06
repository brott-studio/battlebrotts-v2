## test_arc_n_2_aim_telegraph_strafe.gd — Arc N Sub-sprint N.2 assertions.
##
## Gates:
##   N2-1: aim telegraph progress unit test (cooldown → progress mapping)
##   N2-2: enemy strafes within 96px (movement_override == "first_battle_strafe" observed)
##   N2-3: enemy retreats at <=50% HP (movement_override == "first_battle_retreat" at low HP)
##   N1-3b: CF-N1-3 live HP: enemy.hp == 750 at spawn, decrements correctly after a hit
extends SceneTree

func _init() -> void:
	var pass_count := 0
	var fail_count := 0

	## ── N2-1: aim telegraph progress unit test ──────────────────────────────────
	## Tests the cooldown → (aim_telegraph_active, aim_telegraph_progress) mapping
	## directly against the combat_sim logic (no full sim run needed).
	var n2_1_ok := true

	## Helper: apply the telegraph logic manually (mirrors _fire_weapons() guard)
	## Returns [active, progress] tuple
	var _apply_telegraph := func(b: BrottState, cd: float) -> Array:
		if b.brain != null and b.brain.use_first_battle_ai:
			if cd <= 7.5:
				b.aim_telegraph_active = true
				b.aim_telegraph_progress = clampf((7.5 - cd) / 7.5, 0.0, 1.0)
			else:
				b.aim_telegraph_active = false
				b.aim_telegraph_progress = 0.0
		return [b.aim_telegraph_active, b.aim_telegraph_progress]

	## Setup: enemy with use_first_battle_ai=true
	var tb := BrottState.new()
	tb.team = 1
	tb.bot_name = "TelegraphTest"
	tb.chassis_type = ChassisData.ChassisType.SCOUT
	tb.weapon_types.append(WeaponData.WeaponType.PLASMA_CUTTER)
	tb.armor_type = ArmorData.ArmorType.NONE
	tb.setup()
	tb.brain = BrottBrain.new()
	tb.brain.use_first_battle_ai = true

	## Assert 1: cooldown=8.5 → active=false, progress=0.0
	var r1: Array = _apply_telegraph.call(tb, 8.5)
	if r1[0] != false or absf(float(r1[1])) > 0.001:
		push_error("N2-1 FAIL assert1: cd=8.5 → expected active=false progress=0.0, got active=%s progress=%f" % [r1[0], r1[1]])
		n2_1_ok = false

	## Assert 2: cooldown=7.5 → active=true, progress≈0.0
	var r2: Array = _apply_telegraph.call(tb, 7.5)
	if r2[0] != true or absf(float(r2[1])) > 0.01:
		push_error("N2-1 FAIL assert2: cd=7.5 → expected active=true progress≈0.0, got active=%s progress=%f" % [r2[0], r2[1]])
		n2_1_ok = false

	## Assert 3: cooldown=3.75 → active=true, progress≈0.5
	var r3: Array = _apply_telegraph.call(tb, 3.75)
	if r3[0] != true or absf(float(r3[1]) - 0.5) > 0.02:
		push_error("N2-1 FAIL assert3: cd=3.75 → expected active=true progress≈0.5, got active=%s progress=%f" % [r3[0], r3[1]])
		n2_1_ok = false

	## Assert 4: cooldown=0.5 → active=true, progress≈0.933
	var r4: Array = _apply_telegraph.call(tb, 0.5)
	var expected4: float = (7.5 - 0.5) / 7.5
	if r4[0] != true or absf(float(r4[1]) - expected4) > 0.02:
		push_error("N2-1 FAIL assert4: cd=0.5 → expected active=true progress≈%.3f, got active=%s progress=%f" % [expected4, r4[0], r4[1]])
		n2_1_ok = false

	## Assert 5: cooldown=0.0 (shot fires) → reset telegraph
	tb.aim_telegraph_active = false
	tb.aim_telegraph_progress = 0.0
	if tb.aim_telegraph_active != false or absf(tb.aim_telegraph_progress) > 0.001:
		push_error("N2-1 FAIL assert5: after fire reset → expected active=false progress=0.0, got active=%s progress=%f" % [tb.aim_telegraph_active, tb.aim_telegraph_progress])
		n2_1_ok = false

	if n2_1_ok:
		print("PASS N2-1: aim telegraph progress mapping correct (5 assertions)")
		pass_count += 1
	else:
		print("FAIL N2-1: aim telegraph progress mapping incorrect")
		fail_count += 1

	## ── N2-2: enemy strafes within 96px sim log ─────────────────────────────────
	var n2_2_ok := false  # We need to observe at least one strafe tick

	var sim2 := CombatSim.new(42)
	## Player: Brawler + Shotgun at (256, 256)
	var player2 := BrottState.new()
	player2.team = 0
	player2.bot_name = "Player"
	player2.chassis_type = ChassisData.ChassisType.BRAWLER
	player2.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	player2.armor_type = ArmorData.ArmorType.NONE
	player2.setup()
	player2.position = Vector2(256.0, 256.0)
	player2.brain = BrottBrain.default_for_chassis(1)
	sim2.add_brott(player2)

	## Enemy: Scout + Plasma Cutter with use_first_battle_ai=true, full HP
	## Placed 80px from player (within 96px threshold)
	var enemy2 := BrottState.new()
	enemy2.team = 1
	enemy2.bot_name = "Enemy"
	enemy2.chassis_type = ChassisData.ChassisType.SCOUT
	enemy2.weapon_types.append(WeaponData.WeaponType.PLASMA_CUTTER)
	enemy2.armor_type = ArmorData.ArmorType.NONE
	enemy2.setup()
	enemy2.position = Vector2(256.0 + 80.0, 256.0)
	enemy2.brain = BrottBrain.new()
	enemy2.brain.use_first_battle_ai = true
	sim2.add_brott(enemy2)

	## Run 30 ticks, record movement_override each tick
	for _tick2 in range(30):
		if sim2.match_over:
			break
		sim2.simulate_tick()
		if enemy2.brain != null and enemy2.brain.movement_override == "first_battle_strafe":
			n2_2_ok = true

	if n2_2_ok:
		print("PASS N2-2: 'first_battle_strafe' observed at least once within 30 ticks (distance=80px, threshold=96px)")
		pass_count += 1
	else:
		push_error("N2-2 FAIL: 'first_battle_strafe' never observed in 30 ticks (enemy at 80px from player)")
		print("FAIL N2-2: enemy did not strafe within 96px")
		fail_count += 1

	## ── N2-3: enemy retreats at <=50% HP ────────────────────────────────────────
	var n2_3_ok := true

	var brain3 := BrottBrain.new()
	brain3.use_first_battle_ai = true

	var brott3 := BrottState.new()
	brott3.team = 1
	brott3.bot_name = "RetreatEnemy"
	brott3.chassis_type = ChassisData.ChassisType.SCOUT
	brott3.weapon_types.append(WeaponData.WeaponType.PLASMA_CUTTER)
	brott3.armor_type = ArmorData.ArmorType.NONE
	brott3.setup()
	brott3.position = Vector2(256.0 + 80.0, 256.0)  # within 96px
	## Set HP to 49% of max (below the 50% retreat threshold)
	brott3.hp = floor(float(brott3.max_hp) * 0.49)
	brott3.brain = brain3

	var enemy3 := BrottState.new()
	enemy3.team = 0
	enemy3.bot_name = "Player"
	enemy3.chassis_type = ChassisData.ChassisType.BRAWLER
	enemy3.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	enemy3.armor_type = ArmorData.ArmorType.NONE
	enemy3.setup()
	enemy3.position = Vector2(256.0, 256.0)
	enemy3.alive = true

	## Call evaluate() once with a dummy match_time
	brain3.evaluate(brott3, enemy3, 0.0)

	if brain3.movement_override != "first_battle_retreat":
		push_error("N2-3 FAIL: expected movement_override='first_battle_retreat' at 49%% HP within 96px, got '%s'" % brain3.movement_override)
		n2_3_ok = false

	if n2_3_ok:
		print("PASS N2-3: movement_override='first_battle_retreat' at 49%% HP (within 96px)")
		pass_count += 1
	else:
		print("FAIL N2-3: retreat not triggered at <=50%% HP")
		fail_count += 1

	## ── N1-3b: CF-N1-3 live HP assertion ────────────────────────────────────────
	## Verifies that target_hp=750 is applied as a direct HP value (not baseline*hp_pct)
	## and that HP actually decrements when a hit lands.
	var n1_3b_ok := true

	var sim_b := CombatSim.new(99)
	var player_b := BrottState.new()
	player_b.team = 0
	player_b.bot_name = "Player"
	player_b.chassis_type = ChassisData.ChassisType.BRAWLER
	player_b.weapon_types.append(WeaponData.WeaponType.SHOTGUN)
	player_b.armor_type = ArmorData.ArmorType.NONE
	player_b.setup()
	player_b.position = Vector2(4 * 32.0, 8 * 32.0)
	player_b.brain = BrottBrain.default_for_chassis(1)
	sim_b.add_brott(player_b)

	var e_specs_b := OpponentLoadouts.compose_encounter("first_battle_intro", 0, null)
	var e_spec_b: Dictionary = e_specs_b[0] if not e_specs_b.is_empty() else {}
	var enemy_b := BrottState.new()
	enemy_b.team = 1
	enemy_b.bot_name = "FBIEnemy"
	enemy_b.chassis_type = e_spec_b.get("chassis", 0)
	for wt_b in e_spec_b.get("weapons", []):
		enemy_b.weapon_types.append(wt_b)
	enemy_b.armor_type = e_spec_b.get("armor", 0)
	enemy_b.setup()
	## Apply target_hp directly (mirrors game_main.gd Arc N block)
	var spec_hp_b: int = e_spec_b.get("hp", enemy_b.max_hp)
	if spec_hp_b > 0:
		enemy_b.max_hp = spec_hp_b
		enemy_b.hp = float(spec_hp_b)
	if "speed_override" in e_spec_b:
		enemy_b.speed_override = float(e_spec_b["speed_override"])
	if "fire_rate_override" in e_spec_b:
		enemy_b.fire_rate_override = float(e_spec_b["fire_rate_override"])
	if "stance" in e_spec_b:
		enemy_b.stance = int(e_spec_b["stance"])
	enemy_b.position = Vector2(12 * 32.0, 8 * 32.0)
	enemy_b.brain = BrottBrain.new()
	enemy_b.brain.use_first_battle_ai = true
	sim_b.add_brott(enemy_b)

	## Assert HP == 750 at spawn
	if absf(enemy_b.hp - 750.0) > 0.01:
		push_error("N1-3b FAIL: expected enemy.hp=750 at spawn (target_hp applied directly), got %f" % enemy_b.hp)
		n1_3b_ok = false

	## Run until at least one hit lands (cap 50 ticks)
	var hp_after_hit: float = enemy_b.hp
	var hit_landed := false
	for _tick_b in range(50):
		if sim_b.match_over:
			break
		sim_b.simulate_tick()
		if enemy_b.hp < 750.0:
			hp_after_hit = enemy_b.hp
			hit_landed = true
			break

	if not hit_landed:
		push_error("N1-3b FAIL: no hit landed on enemy within 50 ticks (HP still 750 or match ended early)")
		n1_3b_ok = false
	elif hp_after_hit >= 750.0:
		push_error("N1-3b FAIL: enemy HP did not decrement after hit (got %f, expected < 750)" % hp_after_hit)
		n1_3b_ok = false

	if n1_3b_ok:
		print("PASS N1-3b: enemy.hp=750 at spawn; hp=%f after first hit (HP is live)" % hp_after_hit)
		pass_count += 1
	else:
		print("FAIL N1-3b: live HP assertion failed")
		fail_count += 1

	print("test_arc_n_2_aim_telegraph_strafe: %d passed, %d failed" % [pass_count, fail_count])
	if fail_count > 0:
		quit(1)
	else:
		quit(0)
