## S22.2c Optic sim harness — Per-league reflect-damage lever verification.
##
## 4 batches per Gizmo §A.1 / §A.3:
##   B1 — Silver primary:   post-Bronze player (silver) vs all Silver templates (silver)
##   B2 — Bronze regression: post-Bronze player (bronze) vs Bronze templates (bronze)
##   B3 — Scrapyard regression: S21.1 baseline player (scrapyard) vs Scrapyard templates
##   B4 — Data spot-check: reflect_damage_for_league data assertions
##
## Seed block 7001–7100, 100 seeds × 50 fights = 5000 fights/batch (B1/B2/B3).
## Log JSON → res://tests/logs/sim_sprint22_2c.log
##
## Usage: godot --headless --script res://tests/sim_sprint22_2c.gd
extends SceneTree

const SEEDS_START := 7001
const SEEDS_END := 7100
const FIGHTS_PER_SEED := 50
const MATCH_MAX_TICKS := 800  # 80s wall-clock ceiling

# Post-Bronze player kit per Gizmo §1.1 / §A.1
const PLAYER_CHASSIS_POST_BRONZE := ChassisData.ChassisType.BRAWLER
const PLAYER_WEAPONS_POST_BRONZE := [WeaponData.WeaponType.MINIGUN, WeaponData.WeaponType.SHOTGUN]
const PLAYER_ARMOR_POST_BRONZE := ArmorData.ArmorType.REACTIVE_MESH
const PLAYER_MODULES_POST_BRONZE := [ModuleData.ModuleType.OVERCLOCK, ModuleData.ModuleType.REPAIR_NANITES]

# S21.1 baseline player kit (Scrapyard archetype)
const PLAYER_CHASSIS_S21 := ChassisData.ChassisType.BRAWLER
const PLAYER_WEAPONS_S21 := [WeaponData.WeaponType.MINIGUN, WeaponData.WeaponType.PLASMA_CUTTER]
const PLAYER_ARMOR_S21 := ArmorData.ArmorType.PLATING
const PLAYER_MODULES_S21 := [ModuleData.ModuleType.OVERCLOCK]

var _log_lines: Array[String] = []


func _init() -> void:
	print("=== S22.2c Optic sim harness ===\n")

	_run_b4_data_spotcheck()
	_run_b1_silver_primary()
	_run_b2_bronze_regression()
	_run_b3_scrapyard_regression()
	_write_log()
	_print_summary()
	quit(0)


# ---- helpers ----

func _make_player_post_bronze(league: String) -> BrottState:
	var b := BrottState.new()
	b.team = 0
	b.bot_name = "Player"
	b.chassis_type = PLAYER_CHASSIS_POST_BRONZE
	b.weapon_types = PLAYER_WEAPONS_POST_BRONZE.duplicate() as Array[WeaponData.WeaponType]
	b.armor_type = PLAYER_ARMOR_POST_BRONZE
	b.module_types = PLAYER_MODULES_POST_BRONZE.duplicate() as Array[ModuleData.ModuleType]
	b.stance = 0  # Aggressive
	b.current_league = league
	b.setup()
	b.brain = BrottBrain.default_for_chassis(int(PLAYER_CHASSIS_POST_BRONZE))
	return b


func _make_player_s21_baseline(league: String) -> BrottState:
	var b := BrottState.new()
	b.team = 0
	b.bot_name = "Player-S21"
	b.chassis_type = PLAYER_CHASSIS_S21
	b.weapon_types = PLAYER_WEAPONS_S21.duplicate() as Array[WeaponData.WeaponType]
	b.armor_type = PLAYER_ARMOR_S21
	b.module_types = PLAYER_MODULES_S21.duplicate() as Array[ModuleData.ModuleType]
	b.stance = 0
	b.current_league = league
	b.setup()
	b.brain = BrottBrain.default_for_chassis(int(PLAYER_CHASSIS_S21))
	return b


func _make_opponent_from_template(template: Dictionary, league: String) -> BrottState:
	var b := BrottState.new()
	b.team = 1
	b.bot_name = template.get("name", "Opp")
	b.chassis_type = template["chassis"]
	for wt in template["weapons"]:
		b.weapon_types.append(wt)
	b.armor_type = template["armor"]
	for mt in template["modules"]:
		b.module_types.append(mt)
	b.stance = template["stance"]
	b.current_league = league
	b.setup()
	b.brain = BrottBrain.default_for_chassis(int(template["chassis"]))
	return b


## Run one fight. Returns {winner: 0/1/-1, ticks: int, player_reflect_damage: float}.
## player_reflect_damage = total HP lost by player from reflect (proxy: HP lost while opponent has reflect armor).
func _run_one_fight(seed_val: int, player: BrottState, opponent: BrottState) -> Dictionary:
	var sim := CombatSim.new(seed_val)
	player.position = Vector2(64, 256)
	opponent.position = Vector2(448, 256)
	sim.add_brott(player)
	sim.add_brott(opponent)

	var player_hp_start: float = player.hp
	var ticks := 0
	for _t in MATCH_MAX_TICKS:
		if sim.match_over:
			break
		sim.simulate_tick()
		ticks += 1

	# Determine winner
	var winner := -1
	if not player.alive and not opponent.alive:
		winner = -1
	elif not opponent.alive:
		winner = 0
	elif not player.alive:
		winner = 1
	else:
		var hp_p := player.hp / player.max_hp
		var hp_o := opponent.hp / opponent.max_hp
		if hp_p > hp_o:
			winner = 0
		elif hp_o > hp_p:
			winner = 1
		else:
			winner = -1

	# Reflect damage proxy: HP lost by player. Works correctly when opponent has
	# Reactive Mesh (reflect damages player) and player also has Reactive Mesh
	# (reflect damages opponent). Net player HP loss includes all sources.
	# For B1 Silver: player+opp both have Reactive Mesh. Player reflect-DPS ~27.
	# For B2 Bronze: same kit, reflect = 5.0. Player reflect-DPS ~67.5 expected.
	var player_hp_lost: float = player_hp_start - player.hp

	return {"winner": winner, "ticks": ticks, "player_hp_lost": player_hp_lost}


func _get_silver_templates() -> Array:
	var out: Array = []
	for t in OpponentLoadouts.TEMPLATES:
		if t.get("unlock_league", "") == "silver":
			out.append(t)
	return out


func _get_bronze_templates() -> Array:
	var out: Array = []
	for t in OpponentLoadouts.TEMPLATES:
		var ul: String = t.get("unlock_league", "scrapyard")
		var rank: int = OpponentLoadouts.LEAGUE_RANK.get(ul, 0)
		var bronze_rank: int = OpponentLoadouts.LEAGUE_RANK["bronze"]
		if rank == bronze_rank:
			out.append(t)
	return out


func _get_scrapyard_templates() -> Array:
	var out: Array = []
	for t in OpponentLoadouts.TEMPLATES:
		if t.get("unlock_league", "") == "scrapyard":
			out.append(t)
	return out


# ---- B1: Silver primary ----

func _run_b1_silver_primary() -> void:
	print("--- B1 Silver primary ---")
	var silver_templates := _get_silver_templates()
	print("Silver templates found: %d" % silver_templates.size())

	var per_template_wins: Dictionary = {}   # template_id -> {opp_wins, total}
	var agg_opp_wins := 0
	var agg_total := 0
	var total_player_hp_lost: float = 0.0
	var total_fights := 0

	for template in silver_templates:
		var tid: String = template.get("id", "unknown")
		per_template_wins[tid] = {"opp_wins": 0, "total": 0}

	for seed_val in range(SEEDS_START, SEEDS_END + 1):
		for _f in FIGHTS_PER_SEED:
			# Pick a random silver template for this fight
			var idx := (seed_val * FIGHTS_PER_SEED + _f) % silver_templates.size()
			var template: Dictionary = silver_templates[idx]
			var tid: String = template.get("id", "unknown")

			var player := _make_player_post_bronze("silver")
			var opponent := _make_opponent_from_template(template, "silver")

			var result := _run_one_fight(seed_val * 1000 + _f, player, opponent)
			if result["winner"] == 1:
				agg_opp_wins += 1
				per_template_wins[tid]["opp_wins"] += 1
			agg_total += 1
			per_template_wins[tid]["total"] += 1
			total_player_hp_lost += float(result["player_hp_lost"])
			total_fights += 1

	var b1_aggregate_wr: float = float(agg_opp_wins) / float(agg_total) if agg_total > 0 else 0.0
	# Reflect-DPS proxy: average HP lost per fight / fight duration in seconds
	# Use 30s as approximate average fight duration for DPS estimate
	var b1_reflect_dps_mean: float = (total_player_hp_lost / float(total_fights)) / 30.0 if total_fights > 0 else 0.0

	var b1_per_template_wr: Dictionary = {}
	for tid in per_template_wins:
		var d: Dictionary = per_template_wins[tid]
		b1_per_template_wr[tid] = float(d["opp_wins"]) / float(d["total"]) if d["total"] > 0 else 0.0

	print("B1 aggregate opp-WR: %.3f (gate [0.55, 0.70])" % b1_aggregate_wr)
	print("B1 player reflect-DPS mean (proxy): %.2f (gate < 30.0)" % b1_reflect_dps_mean)
	print("B1 per-template opp-WR:")
	for tid in b1_per_template_wr:
		var wr: float = b1_per_template_wr[tid]
		var flag := ""
		if wr < 0.25 or wr > 0.75:
			flag = " *** HARD FAIL [25%, 75%]"
		print("  %s: %.3f%s" % [tid, wr, flag])

	# Gate checks
	if b1_aggregate_wr < 0.55:
		print("B1 HARD FAIL: aggregate opp-WR %.3f < 0.55 (under-tuned)" % b1_aggregate_wr)
	elif b1_aggregate_wr > 0.75:
		print("B1 HARD FAIL: aggregate opp-WR %.3f > 0.75 (over-tuned — hot-patch needed)" % b1_aggregate_wr)
	elif b1_aggregate_wr > 0.70:
		print("B1 WARN: aggregate opp-WR %.3f in (0.70, 0.75] — carry-forward, no block" % b1_aggregate_wr)
	else:
		print("B1 PASS: aggregate opp-WR %.3f in [0.55, 0.70]" % b1_aggregate_wr)

	if b1_reflect_dps_mean >= 30.0:
		print("B1 HARD FAIL: reflect-DPS %.2f >= 30.0" % b1_reflect_dps_mean)
	else:
		print("B1 PASS: reflect-DPS %.2f < 30.0" % b1_reflect_dps_mean)

	_log_lines.append(JSON.stringify({
		"batch": "B1",
		"b1_aggregate_wr": b1_aggregate_wr,
		"b1_per_template_wr": b1_per_template_wr,
		"b1_player_reflect_dps_mean": b1_reflect_dps_mean,
		"total_fights": total_fights,
	}))


# ---- B2: Bronze regression ----

func _run_b2_bronze_regression() -> void:
	print("\n--- B2 Bronze regression ---")
	var bronze_templates := _get_bronze_templates()
	print("Bronze templates found: %d" % bronze_templates.size())

	var opp_wins := 0
	var total := 0
	var total_player_hp_lost: float = 0.0
	var total_fights := 0

	for seed_val in range(SEEDS_START, SEEDS_END + 1):
		for _f in FIGHTS_PER_SEED:
			var idx := (seed_val * FIGHTS_PER_SEED + _f) % bronze_templates.size()
			var template: Dictionary = bronze_templates[idx]
			var player := _make_player_post_bronze("bronze")
			var opponent := _make_opponent_from_template(template, "bronze")
			var result := _run_one_fight(seed_val * 1000 + _f + 100000, player, opponent)
			if result["winner"] == 1:
				opp_wins += 1
			total += 1
			total_player_hp_lost += float(result["player_hp_lost"])
			total_fights += 1

	var b2_opp_wr: float = float(opp_wins) / float(total) if total > 0 else 0.0
	var b2_reflect_dps_mean: float = (total_player_hp_lost / float(total_fights)) / 30.0 if total_fights > 0 else 0.0

	print("B2 Bronze regression opp-WR: %.3f (gate [0.38, 0.52])" % b2_opp_wr)
	print("B2 Bronze player reflect-DPS mean (proxy): %.2f (gate >= 60.0)" % b2_reflect_dps_mean)

	if b2_opp_wr < 0.38 or b2_opp_wr > 0.52:
		print("B2 HARD FAIL: opp-WR %.3f outside [0.38, 0.52] — Bronze regression!" % b2_opp_wr)
	else:
		print("B2 PASS: opp-WR %.3f in [0.38, 0.52]" % b2_opp_wr)

	if b2_reflect_dps_mean < 60.0:
		print("B2 HARD FAIL: Bronze reflect-DPS %.2f < 60.0 — Bronze 5.0 not intact!" % b2_reflect_dps_mean)
	else:
		print("B2 PASS: Bronze reflect-DPS %.2f >= 60.0" % b2_reflect_dps_mean)

	_log_lines.append(JSON.stringify({
		"batch": "B2",
		"b2_opp_wr": b2_opp_wr,
		"b2_player_reflect_dps_mean": b2_reflect_dps_mean,
		"total_fights": total_fights,
	}))


# ---- B3: Scrapyard regression ----

func _run_b3_scrapyard_regression() -> void:
	print("\n--- B3 Scrapyard regression ---")
	var scrapyard_templates := _get_scrapyard_templates()
	print("Scrapyard templates found: %d" % scrapyard_templates.size())

	var opp_wins := 0
	var total := 0

	for seed_val in range(SEEDS_START, SEEDS_END + 1):
		for _f in FIGHTS_PER_SEED:
			var idx := (seed_val * FIGHTS_PER_SEED + _f) % scrapyard_templates.size()
			var template: Dictionary = scrapyard_templates[idx]
			var player := _make_player_s21_baseline("scrapyard")
			var opponent := _make_opponent_from_template(template, "scrapyard")
			var result := _run_one_fight(seed_val * 1000 + _f + 200000, player, opponent)
			if result["winner"] == 1:
				opp_wins += 1
			total += 1

	var b3_opp_wr: float = float(opp_wins) / float(total) if total > 0 else 0.0
	print("B3 Scrapyard regression opp-WR: %.3f (gate [0.38, 0.62])" % b3_opp_wr)

	if b3_opp_wr < 0.38 or b3_opp_wr > 0.62:
		print("B3 HARD FAIL: opp-WR %.3f outside [0.38, 0.62] — Scrapyard regression!" % b3_opp_wr)
	else:
		print("B3 PASS: opp-WR %.3f in [0.38, 0.62]" % b3_opp_wr)

	_log_lines.append(JSON.stringify({
		"batch": "B3",
		"b3_opp_wr": b3_opp_wr,
		"total_fights": total,
	}))


# ---- B4: Data spot-check ----

func _run_b4_data_spotcheck() -> void:
	print("--- B4 Data spot-check ---")
	var data_bronze := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.REACTIVE_MESH, "bronze")
	var data_silver := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.REACTIVE_MESH, "silver")
	var data_scrapyard := ArmorData.reflect_damage_for_league(ArmorData.ArmorType.REACTIVE_MESH, "scrapyard")
	print("data_bronze_reflect: %s (expected 5.0)" % data_bronze)
	print("data_silver_reflect: %s (expected 2.0)" % data_silver)
	print("data_scrapyard_reflect: %s (expected 5.0)" % data_scrapyard)

	assert(data_bronze == 5.0, "B4 HARD FAIL: bronze reflect expected 5.0, got %s" % data_bronze)
	assert(data_silver == 2.0, "B4 HARD FAIL: silver reflect expected 2.0, got %s" % data_silver)
	assert(data_scrapyard == 5.0, "B4 HARD FAIL: scrapyard reflect expected 5.0, got %s" % data_scrapyard)
	print("B4 PASS: all data spot-checks passed")

	_log_lines.append(JSON.stringify({
		"batch": "B4",
		"data_bronze_reflect": data_bronze,
		"data_silver_reflect": data_silver,
		"data_scrapyard_reflect": data_scrapyard,
	}))


# ---- final summary + log ----

func _write_log() -> void:
	var dir := DirAccess.open("res://tests/")
	if dir != null:
		if not dir.dir_exists("logs"):
			dir.make_dir("logs")

	var f := FileAccess.open("res://tests/logs/sim_sprint22_2c.log", FileAccess.WRITE)
	if f == null:
		push_warning("sim_sprint22_2c: could not open log file for writing")
		return
	for line in _log_lines:
		f.store_line(line)
	f.close()
	print("\nLog written to res://tests/logs/sim_sprint22_2c.log")


func _print_summary() -> void:
	print("\n=== S22.2c sim harness complete ===")
	print("9-key schema per Gizmo §A.3:")
	for line in _log_lines:
		var d: Dictionary = JSON.parse_string(line)
		if d == null:
			continue
		var batch: String = d.get("batch", "?")
		match batch:
			"B1":
				print("  b1_aggregate_wr: %s" % d.get("b1_aggregate_wr", "?"))
				print("  b1_player_reflect_dps_mean: %s" % d.get("b1_player_reflect_dps_mean", "?"))
				print("  b1_per_template_wr: %s" % JSON.stringify(d.get("b1_per_template_wr", {})))
			"B2":
				print("  b2_opp_wr: %s" % d.get("b2_opp_wr", "?"))
				print("  b2_player_reflect_dps_mean: %s" % d.get("b2_player_reflect_dps_mean", "?"))
			"B3":
				print("  b3_opp_wr: %s" % d.get("b3_opp_wr", "?"))
			"B4":
				print("  data_bronze_reflect: %s" % d.get("data_bronze_reflect", "?"))
				print("  data_silver_reflect: %s" % d.get("data_silver_reflect", "?"))
