## Core tick-based combat simulation
## 10 ticks/sec (Sprint 4: halved from 20 for pacing), deterministic given same RNG seed
class_name CombatSim
extends RefCounted

const TICKS_PER_SEC: int = 10
const TICK_DELTA: float = 1.0 / 10.0
const MAX_ENERGY: float = 100.0
const ENERGY_REGEN_PER_TICK: float = 5.0 / 10.0
const CRIT_CHANCE: float = 0.05
const CRIT_MULT: float = 1.5
const MATCH_TIMEOUT_TICKS: int = 100 * 10  # Legacy: matches 1v1 default

# Per-mode overtime thresholds (ticks)
const OVERTIME_TICKS_1V1: int = 45 * 10   # 450 ticks = 45s
const OVERTIME_TICKS_TEAM: int = 60 * 10  # 600 ticks = 60s
const SUDDEN_DEATH_TICKS_1V1: int = 60 * 10   # 600 ticks = 60s
const SUDDEN_DEATH_TICKS_TEAM: int = 75 * 10  # 750 ticks = 75s
const MATCH_TIMEOUT_TICKS_1V1: int = 100 * 10  # 1000 ticks = 100s
const MATCH_TIMEOUT_TICKS_TEAM: int = 120 * 10 # 1200 ticks = 120s

# Legacy constants kept for backward compat (default to 1v1)
const OVERTIME_TICKS: int = 45 * 10
const OVERTIME_SPEED_MULT: float = 1.2  # +20% movement speed in overtime
const OVERTIME_DAMAGE_MULT: float = 1.5  # 50% damage amp during overtime (60s+)
const SUDDEN_DEATH_TICKS: int = 60 * 10   # default 1v1
const SUDDEN_DEATH_DAMAGE_MULT: float = 2.0  # 100% damage amp during sudden death (75s+)
const ARENA_SHRINK_RATE: float = 0.5  # tiles per second boundary contracts
const ARENA_BOUNDARY_DAMAGE: float = 10.0  # damage per second outside boundary (ignores armor)
const ARENA_TILES: int = 16
const BOT_HITBOX_RADIUS: float = 12.0
const TILE_SIZE: float = 32.0

# TCR Combat Rhythm constants (S13.2)
# S13.3: Phase durations are now per-chassis (see ChassisData.TCR_TIMINGS).
# The constants below are baseline fallbacks (Brawler-tuned); callers should
# prefer ChassisData.get_tcr_timings(chassis_type).
const TENSION_DURATION_MIN: int = 20  # ticks (2.0s at 10 ticks/sec) — Brawler baseline
const TENSION_DURATION_MAX: int = 35  # ticks (3.5s) — Brawler baseline
const COMMIT_DURATION: int = 8        # ticks (0.8s) — Brawler baseline
const RECOVERY_DURATION: int = 12     # ticks (1.2s) — Brawler baseline
const COMMIT_SPEED_MULT: float = 1.4
# S13.3 Lever 1: Absolute commit-speed cap (px/s).
# Prevents Scout's 220 px/s × 1.4 = 308 px/s commit dash from crossing the entire
# engagement band in a single 0.8s window. Brawler (168 px/s) and Fortress (84 px/s)
# are unaffected by the cap; only Scout's commit is clipped to 200 px/s.
const COMMIT_SPEED_CAP: float = 200.0
const ORBIT_SPEED_MULT: float = 0.55
# S17.2-003 addendum: per-tick retreat step under two-phase tick.
# Applied only to direct-write retreat sites (TENSION-too-close,
# RECOVERY-retreat, stance-driven retreats). Preserves pair-relative
# separation rate under simultaneous physics. See
# docs/design/s17.2-003-retreat-calibration.md.
const RETREAT_SPEED_MULT: float = 0.50
const APPROACH_SPEED_MULT: float = 0.80
const DISENGAGE_SPEED_MULT: float = 0.90
const TENSION_DRIFT_INTERVAL: int = 10  # ticks (1.0s)
const TENSION_DRIFT_AMOUNT: float = 0.3  # tiles

# S17.2-003: Scout-feel velocity-smoothing constants. Kept in combat_sim.gd
# (not chassis_data.gd) to preserve the godot/data/** scope gate. See
# docs/design/s17.2-scout-feel.md §4.5 and s17.2-003-scout-feel-revision.md.
const REVERSAL_ANGLE_THRESHOLD_DEG: float = 120.0
const REVERSAL_DAMPING_FACTOR: float = 0.35
const REVERSAL_DAMPING_TICKS: int = 2

var brotts: Array[BrottState] = []
var projectiles: Array[Projectile] = []
var rng: RandomNumberGenerator
var tick_count: int = 0
var match_over: bool = false
var winner_team: int = -1
var overtime_active: bool = false
var sudden_death_active: bool = false
var arena_boundary_tiles: float = 8.0  # half-size in tiles from center (starts at 8 = full 16x16)
var match_mode: String = "1v1"  # "1v1", "2v2", "3v3" — controls overtime thresholds

func _get_overtime_ticks() -> int:
	return OVERTIME_TICKS_1V1 if match_mode == "1v1" else OVERTIME_TICKS_TEAM

func _get_sudden_death_ticks() -> int:
	return SUDDEN_DEATH_TICKS_1V1 if match_mode == "1v1" else SUDDEN_DEATH_TICKS_TEAM

func _get_timeout_ticks() -> int:
	return MATCH_TIMEOUT_TICKS_1V1 if match_mode == "1v1" else MATCH_TIMEOUT_TICKS_TEAM

# --- JSON match logging (S12.5) ---
var json_log_enabled: bool = false
var _json_log: Array = []
var _tick_events: Array = []  # transient: events for current tick

# --- Instrumentation (S11.2, extended S13.3) ---
# S13.3: Split per-shot (trigger pull) from per-pellet (individual projectile) metrics.
#   shots_fired    — one increment per weapon trigger pull (used for hit rate when
#                    "did ANY pellet land" is the interesting question)
#   shots_hit      — counts trigger pulls where at least one pellet connected
#   pellets_fired  — one increment per projectile spawned (spread weapons fire many)
#   pellets_hit    — one increment per projectile that damaged a target
# Canonical hit rate for balance is per-pellet: pellets_hit / pellets_fired ≤ 1.0.
var shots_fired: Dictionary = {}   # weapon_name -> int (trigger pulls)
var shots_hit: Dictionary = {}     # weapon_name -> int (trigger pulls where ≥1 pellet landed)
var pellets_fired: Dictionary = {} # weapon_name -> int (individual projectiles spawned)
var pellets_hit: Dictionary = {}   # weapon_name -> int (individual projectiles that landed)
var first_engagement_tick: int = -1
var kill_ticks: Dictionary = {}    # bot_name -> tick when killed
# S13.3: Shot IDs that have already credited shots_hit (so multiple pellets from one
# trigger pull only count as one shot_hit). Cleared never — match-scoped set.
var _shots_hit_ids: Dictionary = {}

signal on_damage(target: BrottState, amount: float, is_crit: bool, pos: Vector2)
signal on_projectile_spawned(proj: Projectile)
signal on_death(brott: BrottState)
signal on_shield_activated(brott: BrottState)
signal on_match_end(winner_team: int)

func _init(seed_val: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_val

func add_brott(brott: BrottState) -> void:
	brotts.append(brott)
	# S17.2-003 phase 3: seed _pos_snapshot with the current position so code
	# that reads cross-bot `target._pos_snapshot` before the first simulate_tick
	# call (e.g. tests exercising helpers like _wall_escape_direction directly)
	# observes a sensible initial world state instead of Vector2.ZERO.
	brott._pos_snapshot = brott.position

func get_json_log() -> Array:
	return _json_log

func simulate_tick() -> void:
	if match_over:
		return
	tick_count += 1
	if json_log_enabled:
		_tick_events = []
	
	# Check overtime trigger
	if not overtime_active and tick_count >= _get_overtime_ticks():
		overtime_active = true
		for b in brotts:
			if b.alive:
				b.stance = 0  # Force Aggressive
				b.overtime = true
		if json_log_enabled:
			_tick_events.append({"type": "overtime_triggered", "tick": tick_count})
	
	# Check sudden death escalation
	if not sudden_death_active and tick_count >= _get_sudden_death_ticks():
		sudden_death_active = true
		if json_log_enabled:
			_tick_events.append({"type": "sudden_death_triggered", "tick": tick_count})

	# Shrink arena boundary during overtime
	if overtime_active:
		var shrink_per_tick: float = ARENA_SHRINK_RATE / float(TICKS_PER_SEC)
		arena_boundary_tiles = maxf(0.0, 8.0 - (float(tick_count - _get_overtime_ticks()) / float(TICKS_PER_SEC)) * ARENA_SHRINK_RATE)
	
	# Apply boundary damage to bots outside the shrinking arena
	if overtime_active:
		var center_px: float = float(ARENA_TILES) / 2.0 * TILE_SIZE
		var center := Vector2(center_px, center_px)
		var boundary_px: float = arena_boundary_tiles * TILE_SIZE
		for b in brotts:
			if not b.alive:
				continue
			var dx: float = absf(b.position.x - center.x)
			var dy: float = absf(b.position.y - center.y)
			if dx > boundary_px or dy > boundary_px:
				var dmg: float = ARENA_BOUNDARY_DAMAGE / float(TICKS_PER_SEC)
				b.hp -= dmg
				b.flash_timer = 2.0
				on_damage.emit(b, dmg, false, b.position)
				if b.hp <= 0:
					_kill_brott(b)

	for b in brotts:
		if not b.alive:
			continue
		_evaluate_brain(b)
	
	for b in brotts:
		if not b.alive:
			continue
		_regen_energy(b)
	
	for b in brotts:
		if not b.alive:
			continue
		_tick_modules(b)
	
	# S17.2-003 (phase 3): pre-movement position snapshot. Cross-bot reads in
	# _move_brott (target.position, unstick-nudge target, etc.) use this snapshot
	# instead of the live `.position` so every bot in this tick sees the same
	# pre-move world state. Without this, the fixed iteration order leaks into
	# gameplay: team 0 always moves first, team 1 then reacts to team 0's
	# already-updated position, which cascades into an ~80% team-0 WR in
	# Scout-vs-Scout mirror matches (diag_mirror_n200 @ N=200). Separation
	# continues to read LIVE positions (see _move_brott) — snapshotting there
	# breaks overlap resolution because both bots then push against the stale
	# same-distance pair and never actually separate.
	for b in brotts:
		if b.alive:
			b._pos_snapshot = b.position
	
	for b in brotts:
		if not b.alive:
			continue
		_move_brott(b)
	
	for b in brotts:
		if not b.alive:
			continue
		_fire_weapons(b)
	
	_update_projectiles()
	_check_match_end()
	
	if json_log_enabled:
		_append_tick_log()

func _evaluate_brain(b: BrottState) -> void:
	if b.target == null or not b.target.alive:
		b.target = _find_target(b)
	
	b._pending_gadget = ""
	
	if b.brain != null:
		var match_time_sec: float = float(tick_count) / float(TICKS_PER_SEC)
		var enemy: BrottState = b.target
		var fired: bool = b.brain.evaluate(b, enemy, match_time_sec)
		
		# Handle target priority from brain
		if b.brain.target_priority != "nearest":
			b.target = _find_target_by_priority(b, b.brain.target_priority)
		
		# Handle pending gadget activation
		if b._pending_gadget != "":
			_activate_gadget_by_name(b, b._pending_gadget)
			b._pending_gadget = ""
	
	# Overtime: force aggressive stance (overrides BrottBrain)
	if overtime_active:
		b.stance = 0

func _find_target(b: BrottState) -> BrottState:
	var best: BrottState = null
	var best_dist: float = INF
	for other in brotts:
		if other.team == b.team or not other.alive:
			continue
		var d: float = b.position.distance_to(other.position)
		if d < best_dist:
			best_dist = d
			best = other
	return best

func _find_target_by_priority(b: BrottState, priority: String) -> BrottState:
	match priority:
		"weakest":
			var best: BrottState = null
			var best_hp: float = INF
			for other in brotts:
				if other.team == b.team or not other.alive:
					continue
				if other.hp < best_hp:
					best_hp = other.hp
					best = other
			return best
		"biggest_threat":
			# Simplified: pick highest max DPS enemy
			var best: BrottState = null
			var best_dps: float = -1.0
			for other in brotts:
				if other.team == b.team or not other.alive:
					continue
				var dps: float = 0.0
				for wt in other.weapon_types:
					var wd: Dictionary = WeaponData.get_weapon(wt)
					dps += float(wd["damage"]) * float(wd["fire_rate"]) * float(wd["pellets"])
				if dps > best_dps:
					best_dps = dps
					best = other
			return best
		_:
			return _find_target(b)

func _activate_gadget_by_name(b: BrottState, gadget_name: String) -> void:
	for i in range(b.module_types.size()):
		var mdata: Dictionary = ModuleData.get_module(b.module_types[i])
		if mdata["name"] == gadget_name:
			_activate_module(b, i)
			return

func _regen_energy(b: BrottState) -> void:
	b.energy = minf(b.energy + ENERGY_REGEN_PER_TICK, MAX_ENERGY)

func _tick_modules(b: BrottState) -> void:
	if b.emp_disabled_timer > 0:
		b.emp_disabled_timer -= 1.0
		return
	
	for i in range(b.module_types.size()):
		var mt: ModuleData.ModuleType = b.module_types[i]
		var mdata: Dictionary = ModuleData.get_module(mt)
		
		if b.module_active_timers[i] > 0:
			b.module_active_timers[i] -= 1.0
			if b.module_active_timers[i] <= 0:
				_deactivate_module(b, i, mt)
		
		if b.module_cooldowns[i] > 0:
			b.module_cooldowns[i] -= 1.0
			if b.module_cooldowns[i] <= 0:
				_on_cooldown_expired(b, mt)
		
		if str(mdata["passive_effect"]) == "heal":
			var heal_per_tick: float = float(mdata["heal_per_sec"]) / float(TICKS_PER_SEC)
			b.hp = minf(b.hp + heal_per_tick, float(b.max_hp))

func _on_cooldown_expired(b: BrottState, mt: ModuleData.ModuleType) -> void:
	match mt:
		ModuleData.ModuleType.OVERCLOCK:
			b.overclock_recovery = false

func _activate_module(b: BrottState, module_index: int) -> void:
	if module_index >= b.module_types.size():
		return
	if b.module_cooldowns[module_index] > 0 or b.module_active_timers[module_index] > 0:
		return
	if b.emp_disabled_timer > 0:
		return
	
	var mt: ModuleData.ModuleType = b.module_types[module_index]
	var mdata: Dictionary = ModuleData.get_module(mt)
	if not mdata["activated"]:
		return
	
	if json_log_enabled:
		_tick_events.append({"type": "module_activated", "bot_id": b.bot_name, "module": str(mdata.get("name", str(mt)))})
	
	var dur_ticks: float = float(mdata.get("duration", 0.0)) * float(TICKS_PER_SEC)
	b.module_active_timers[module_index] = dur_ticks
	
	match mt:
		ModuleData.ModuleType.OVERCLOCK:
			b.overclock_active = true
			b.overclock_recovery = false
		ModuleData.ModuleType.SHIELD_PROJECTOR:
			b.shield_active = true
			b.shield_hp = float(mdata["absorb"])
			on_shield_activated.emit(b)
		ModuleData.ModuleType.AFTERBURNER:
			b.afterburner_active = true

func _deactivate_module(b: BrottState, module_index: int, mt: ModuleData.ModuleType) -> void:
	var mdata: Dictionary = ModuleData.get_module(mt)
	var cd_ticks: float = float(mdata.get("cooldown", 0.0)) * float(TICKS_PER_SEC)
	b.module_cooldowns[module_index] = cd_ticks
	
	match mt:
		ModuleData.ModuleType.OVERCLOCK:
			b.overclock_active = false
			b.overclock_recovery = true
		ModuleData.ModuleType.SHIELD_PROJECTOR:
			b.shield_active = false
			b.shield_hp = 0.0
		ModuleData.ModuleType.AFTERBURNER:
			b.afterburner_active = false

func _has_los(from: Vector2, to: Vector2) -> bool:
	for pillar_pos: Vector2 in _get_pillar_positions():
		var pillar_radius: float = 16.0
		var line_dir: Vector2 = to - from
		var line_len: float = line_dir.length()
		if line_len < 0.01:
			return true
		var line_norm: Vector2 = line_dir / line_len
		var to_pillar: Vector2 = pillar_pos - from
		var proj: float = to_pillar.dot(line_norm)
		proj = clampf(proj, 0.0, line_len)
		var closest: Vector2 = from + line_norm * proj
		if closest.distance_to(pillar_pos) < pillar_radius + BOT_HITBOX_RADIUS:
			return false
	return true

func _get_min_weapon_range_px(b: BrottState) -> float:
	var min_r: float = INF
	for wt: WeaponData.WeaponType in b.weapon_types:
		var wd: Dictionary = WeaponData.get_weapon(wt)
		var r: float = float(wd["range_tiles"]) * TILE_SIZE
		if r < min_r:
			min_r = r
	if min_r == INF:
		min_r = 3.0 * TILE_SIZE
	return min_r

func _get_engagement_distance(b: BrottState) -> Dictionary:
	var min_range: float = _get_min_weapon_range_px(b)
	var max_range: float = _get_max_weapon_range_px(b)
	match b.stance:
		0:  # Aggressive
			return {"ideal": min_range * 0.65, "tolerance": 0.5 * TILE_SIZE}
		1:  # Defensive
			return {"ideal": max_range * 0.85, "tolerance": 1.0 * TILE_SIZE}
		2:  # Kiting
			return {"ideal": max_range * 0.70, "tolerance": 1.0 * TILE_SIZE}
		_:  # Ambush
			return {"ideal": 0.0, "tolerance": 0.0}

const COMBAT_EXIT_GRACE_TICKS: int = 20  # 2.0s grace before TCR state resets (S13.2 fix)

func _get_tension_range(b: BrottState) -> Dictionary:
	## S13.3: Returns {"min": ticks, "max": ticks, "commit": ticks, "recovery": ticks}
	## per chassis. Falls back to baseline constants if chassis is unknown.
	var t: Dictionary = ChassisData.get_tcr_timings(b.chassis_type)
	return {
		"min": int(t.get("tension_min", TENSION_DURATION_MIN)),
		"max": int(t.get("tension_max", TENSION_DURATION_MAX)),
		"commit": int(t.get("commit", COMMIT_DURATION)),
		"recovery": int(t.get("recovery", RECOVERY_DURATION)),
	}

func _enter_combat_movement(b: BrottState) -> void:
	b.in_combat_movement = true
	b.orbit_direction = 1 if rng.randf() < 0.5 else -1
	b.backup_distance = 0.0
	# If returning within grace period, preserve TCR state
	if b.combat_exit_grace_timer > 0:
		b.combat_exit_grace_timer = 0.0
		# TCR state preserved — don't reinitialize
		if json_log_enabled:
			var phase_name: String = ["TENSION", "COMMIT", "RECOVERY"][b.combat_phase]
			_tick_events.append({"type": "tcr_resume", "bot_id": b.bot_name, "phase": phase_name})
	else:
		# Fresh entry — initialize TCR state machine (per-chassis timings, S13.3)
		var tcr: Dictionary = _get_tension_range(b)
		b.combat_phase = 0  # TENSION
		b.combat_phase_timer = rng.randi_range(tcr["min"], tcr["max"])
		b.tension_drift_timer = TENSION_DRIFT_INTERVAL
		if json_log_enabled:
			_tick_events.append({"type": "tcr_phase", "bot_id": b.bot_name, "phase": "TENSION", "duration": b.combat_phase_timer})

func _exit_combat_movement(b: BrottState) -> void:
	b.in_combat_movement = false
	b.backup_distance = 0.0
	# Start grace timer instead of immediately resetting TCR state (S13.2 fix)
	b.combat_exit_grace_timer = float(COMBAT_EXIT_GRACE_TICKS)

func _move_brott(b: BrottState) -> void:
	# Tick down combat exit grace timer (S13.2 fix)
	if b.combat_exit_grace_timer > 0 and not b.in_combat_movement:
		b.combat_exit_grace_timer -= 1.0
		if b.combat_exit_grace_timer <= 0:
			# Grace period expired — fully reset TCR state
			b.combat_phase = 0
			b.combat_phase_timer = 0
			b.combat_exit_grace_timer = 0.0
	
	if b.target == null:
		# Decelerate to stop
		b.accelerate_toward_speed(0.0, TICK_DELTA)
		return
	
	# Determine target speed for this tick
	var target_speed: float = b.get_effective_speed()
	if overtime_active:
		target_speed *= OVERTIME_SPEED_MULT
	
	# Check movement override from brain
	var move_override: String = ""
	if b.brain != null:
		move_override = b.brain.movement_override
	
	if move_override == "center":
		b.accelerate_toward_speed(target_speed, TICK_DELTA)
		var spd: float = b.current_speed * TICK_DELTA
		var center := Vector2(8.0 * TILE_SIZE, 8.0 * TILE_SIZE)
		var to_center := center - b.position
		if to_center.length() > spd:
			# Smoothed-intent lane (#1 per revision §2): forward-chase to center.
			var desired_vel_c: Vector2 = to_center.normalized() * b.current_speed
			_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_c, TICK_DELTA))
		else:
			# Direct-write lane (#2): absolute snap when within one step. Reset
			# velocity so the next smoothed call doesn't inherit stale momentum.
			b.position = center
			b.velocity = Vector2.ZERO
	elif move_override == "cover":
		b.accelerate_toward_speed(target_speed, TICK_DELTA)
		var _spd: float = b.current_speed * TICK_DELTA
		var best_pillar := Vector2.ZERO
		var best_dist := INF
		for p in _get_pillar_positions():
			var d := b.position.distance_to(p)
			if d < best_dist:
				best_dist = d
				best_pillar = p
		if best_dist > 32.0:
			# Smoothed-intent lane (#3): forward-chase toward cover pillar.
			var to_pillar_v: Vector2 = best_pillar - b.position
			if to_pillar_v.length_squared() > 0.0001:
				var desired_vel_p: Vector2 = to_pillar_v.normalized() * b.current_speed
				_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_p, TICK_DELTA))
	else:
		var to_target: Vector2 = b.target._pos_snapshot - b.position
		var dist: float = to_target.length()
		var max_weapon_range: float = _get_max_weapon_range_px(b)
		var has_los: bool = _has_los(b.position, b.target._pos_snapshot)
		
		# Determine if bot is actively moving this tick
		var wants_to_move: bool = true
		if b.stance == 3:  # Ambush — hold position
			wants_to_move = false
		
		# Accelerate or decelerate based on intent
		if wants_to_move:
			b.accelerate_toward_speed(target_speed, TICK_DELTA)
		else:
			b.accelerate_toward_speed(0.0, TICK_DELTA)
		var spd: float = b.current_speed * TICK_DELTA
		
		# Combat movement entry/exit
		if b.stance == 3:  # Ambush — hold position
			pass
		elif has_los and dist <= max_weapon_range:
			if not b.in_combat_movement:
				_enter_combat_movement(b)
		else:
			if b.in_combat_movement:
				_exit_combat_movement(b)
		
		if b.in_combat_movement and b.stance != 3:
			_do_combat_movement(b, spd)
		else:
			# Pre-engagement: apply approach speed multiplier (S13.2)
			var approach_target_speed: float = target_speed * APPROACH_SPEED_MULT
			if wants_to_move:
				b.accelerate_toward_speed(approach_target_speed, TICK_DELTA)
			var approach_spd: float = b.current_speed * TICK_DELTA
			# Stance-based pathfinding (pre-engagement or ambush). Forward-chase
			# and lateral-orbit sites go through the smoothed-intent lane
			# (revision §2 #4, #6, #8, #9, #10). Stance-driven retreat (#5, #7)
			# bypasses smoothing: discrete "back off" decision; sharpness preserves
			# stance feel S11/S13 tuned. Retreat writes touch b.position directly
			# and do NOT update b.velocity.
			var to_target_n_pre: Vector2 = Vector2.ZERO
			if to_target.length_squared() > 0.0001:
				to_target_n_pre = to_target.normalized()
			match b.stance:
				0:  # Aggressive — close to engagement distance
					var engage: Dictionary = _get_engagement_distance(b)
					if dist > engage["ideal"] + engage["tolerance"]:
						# Smoothed (#4).
						var desired_vel_a: Vector2 = to_target_n_pre * b.current_speed
						_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_a, TICK_DELTA))
				1:  # Defensive
					if dist < max_weapon_range * 0.8:
						# Direct-write (#5): stance-driven retreat. Bypass smoothing.
						# S17.2-003 addendum: halve retreat step under two-phase tick.
						b.position -= to_target_n_pre * approach_spd * RETREAT_SPEED_MULT
					elif dist > max_weapon_range:
						# Smoothed (#6): forward-chase to range.
						var desired_vel_d: Vector2 = to_target_n_pre * b.current_speed
						_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_d, TICK_DELTA))
				2:  # Kiting
					var ideal_k: float = max_weapon_range * 0.7
					var perp_k: Vector2 = Vector2(-to_target.y, to_target.x).normalized()
					if dist < ideal_k * 0.8:
						# Split: retreat bypasses (#7), lateral is smoothed (#8).
						# S17.2-003 addendum: halve retreat step under two-phase tick.
						b.position -= to_target_n_pre * approach_spd * 0.7 * RETREAT_SPEED_MULT
						var desired_vel_kl: Vector2 = perp_k * b.current_speed * 0.3
						if desired_vel_kl.length_squared() > 0.0001:
							_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_kl, TICK_DELTA))
					elif dist > ideal_k * 1.2:
						# Smoothed (#9): forward-chase.
						var desired_vel_ka: Vector2 = to_target_n_pre * b.current_speed
						_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_ka, TICK_DELTA))
					else:
						# Smoothed (#10): lateral-orbit.
						var desired_vel_ko: Vector2 = perp_k * b.current_speed
						_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_ko, TICK_DELTA))
				3:  # Ambush
					pass
	
	# Update visual facing angle (turn speed is visual-only)
	if b.target != null:
		var desired_angle: float = rad_to_deg((b.target._pos_snapshot - b.position).angle())
		var angle_diff: float = fmod(desired_angle - b.facing_angle + 540.0, 360.0) - 180.0
		var max_turn: float = b.turn_speed * TICK_DELTA
		if absf(angle_diff) <= max_turn:
			b.facing_angle = desired_angle
		else:
			b.facing_angle += signf(angle_diff) * max_turn
		b.facing_angle = fmod(b.facing_angle + 360.0, 360.0)
	
	# Bot-bot separation force (S11.1: 32px threshold, 60% base speed).
	# S15 moonwalk fix: the separation push can have a component opposing
	# `to_target` (backward). Cap the backward component against the shared
	# `backup_distance` budget (TILE_SIZE = 1 tile), same budget the TCR retreats
	# use. Forward/lateral components pass through untouched so overlap resolution
	# still works. See docs/kb/juke-bypass-movement-caps.md.
	var sep_threshold: float = TILE_SIZE  # 32px = 1 tile
	var has_target: bool = b.target != null and b.target.alive
	var to_target_n: Vector2 = Vector2.ZERO
	if has_target:
		var to_target_sep: Vector2 = b.target.position - b.position
		if to_target_sep.length_squared() > 0.0001:
			to_target_n = to_target_sep.normalized()
	for other in brotts:
		if other == b or not other.alive:
			continue
		var sep: Vector2 = b.position - other.position
		var sep_dist: float = sep.length()
		if sep_dist < sep_threshold and sep_dist > 0.01:
			var repulsion_speed: float = b.base_speed * 0.6 * TICK_DELTA
			var push: Vector2 = sep.normalized() * repulsion_speed
			# Only gate the backward component when bots are NOT overlapping hitboxes.
			# If `sep_dist < 2 * BOT_HITBOX_RADIUS`, we're in actual overlap — the
			# separation push needs full authority to resolve the overlap (otherwise
			# overlapping bots linger, the `sep_dist <= 0.01` explosion branch fires,
			# and commit crossovers happen more often). Once bots are merely "close"
			# (e.g., 24–32px), gate the backward component against `backup_distance`.
			var overlap: bool = sep_dist < 2.0 * BOT_HITBOX_RADIUS
			if not overlap and to_target_n != Vector2.ZERO:
				var along: float = push.dot(to_target_n)  # <0 means backward
				var perp_push: Vector2 = push - to_target_n * along
				if along < 0.0:
					var remaining_budget: float = maxf(0.0, TILE_SIZE - b.backup_distance)
					var backward_mag: float = minf(-along, remaining_budget)
					b.backup_distance += backward_mag
					b.position += perp_push + to_target_n * (-backward_mag)
				else:
					b.position += push
			else:
				b.position += push
		elif sep_dist <= 0.01:
			b.position += Vector2(TILE_SIZE * 0.5, 0)
	
	var arena_px: float = 16.0 * TILE_SIZE
	var old_pos: Vector2 = b.position
	b.position.x = clampf(b.position.x, BOT_HITBOX_RADIUS, arena_px - BOT_HITBOX_RADIUS)
	b.position.y = clampf(b.position.y, BOT_HITBOX_RADIUS, arena_px - BOT_HITBOX_RADIUS)
	
	# Flip orbit direction on wall collision
	if b.in_combat_movement and b.position != old_pos:
		b.orbit_direction *= -1
	
	for pillar_pos: Vector2 in _get_pillar_positions():
		var to_pillar: Vector2 = b.position - pillar_pos
		if to_pillar.length() < BOT_HITBOX_RADIUS + 16.0:
			var old_p: Vector2 = b.position
			b.position = pillar_pos + to_pillar.normalized() * (BOT_HITBOX_RADIUS + 16.0)
			if b.in_combat_movement and b.position != old_p:
				b.orbit_direction *= -1

	# S14.1-B: Wall-stuck detection. Bots can freeze against walls, pillars, or
	# behind LOS-blocking geometry during COMMIT/RECOVERY or when Aggressive
	# stance has dist within tolerance. If history shows <10px displacement over
	# 1.5s while alive+has target, trigger unstick (flip orbit, reset TCR, push
	# away from geometry for 8 ticks).
	_check_and_handle_stuck(b)

# S14.1-B2: Geometry-proximity gate. Returns true if bot is within arm-distance
# of a wall or pillar. This is the ONLY condition under which wall-stuck
# detection is armed. Rationale (see Boltz HOLD review on PR #74):
#  - Flag 2 (root cause): ungated detection fired on 91/100 open-space matches;
#    the 10px/1.5s threshold trips during routine close-quarters Scout orbit.
#    Gating by proximity to geometry drops open-space unstick fires to 0/100
#    while still catching wall/pillar pins (T1, T2, T4 in test_sprint14_1_nav).
#  - Perf/determinism: early-out BEFORE touching any state on `b` preserves
#    the main-baseline tick ordering for open-space fights (the per-tick
#    append/pop_front on Array[Vector2] subtly perturbs Scout close-combat
#    scheduling even when unstick never fires).
func _is_near_geometry(b: BrottState) -> bool:
	const WALL_PROX_PX: float = TILE_SIZE
	# Pillar threshold is center-to-center distance. Pillars have a ~16px repel
	# radius (see the BOT_HITBOX_RADIUS+16 push-out above); arming unstick at 60px
	# catches actual corner-pins without firing during routine close-quarters
	# orbit through the pillar quadrant (lead investigation notes on PR #74).
	const PILLAR_PROX_PX: float = 60.0
	var arena_px: float = 16.0 * TILE_SIZE
	if b.position.x < WALL_PROX_PX or b.position.x > arena_px - WALL_PROX_PX:
		return true
	if b.position.y < WALL_PROX_PX or b.position.y > arena_px - WALL_PROX_PX:
		return true
	for p: Vector2 in _get_pillar_positions():
		if b.position.distance_squared_to(p) < PILLAR_PROX_PX * PILLAR_PROX_PX:
			return true
	return false

func _check_and_handle_stuck(b: BrottState) -> void:
	const STUCK_WINDOW_TICKS: int = 15   # 1.5s at 10 ticks/sec
	const STUCK_MIN_PX: float = 10.0
	const UNSTICK_DURATION_TICKS: float = 8.0
	const UNSTICK_NUDGE_PX_PER_TICK: float = 7.0
	# Unstick maneuver in progress — always service it (even if no longer near
	# geometry) so the 8-tick push-away completes cleanly.
	if b._unstick_timer > 0.0:
		if not b.alive or b.target == null or not b.target.alive:
			b._unstick_timer = 0.0
			b._stuck_history.clear()
			return
		b._unstick_timer -= 1.0
		var nudge: Vector2 = _wall_escape_direction(b)
		if nudge != Vector2.ZERO:
			var push: Vector2 = nudge * UNSTICK_NUDGE_PX_PER_TICK
			_apply_unstick_nudge(b, push)
		return
	if not b.alive or b.target == null or not b.target.alive:
		if not b._stuck_history.is_empty():
			b._stuck_history.clear()
		return
	# Early-out for open-space fights: no state mutation at all when not near
	# geometry. This preserves main-branch tick ordering for Scout close-combat.
	if not _is_near_geometry(b):
		if not b._stuck_history.is_empty():
			b._stuck_history.clear()
		return
	b._stuck_history.append(b.position)
	if b._stuck_history.size() > STUCK_WINDOW_TICKS:
		b._stuck_history.pop_front()
	if b._stuck_history.size() < STUCK_WINDOW_TICKS:
		return
	if b.position.distance_to(b._stuck_history[0]) < STUCK_MIN_PX:
		b._unstick_timer = UNSTICK_DURATION_TICKS
		b.orbit_direction *= -1
		b.combat_phase = 0
		var tcr: Dictionary = _get_tension_range(b)
		b.combat_phase_timer = rng.randi_range(tcr["min"], tcr["max"])
		b.backup_distance = TILE_SIZE  # skip backup budget; go to lateral
		b.tension_drift_timer = TENSION_DRIFT_INTERVAL
		b._stuck_history.clear()
		if json_log_enabled:
			_tick_events.append({"type": "nav_unstick", "bot_id": b.bot_name, "pos": [b.position.x, b.position.y]})

# S17.2-002 magnitude gate: pre-normalize sum must clear this magnitude before
# we trust its direction. When wall and pillar contributions partially cancel
# (HCD's corner+inner-pillar repro, issue #180), the pre-normalize sum can be
# near-zero but non-zero — normalizing it would amplify direction noise and
# apply a 7 px/tick nudge in a bogus direction that fails to clear the wedge
# before COMMIT re-pins the bot. Redirect to the target-bias fallback instead.
# Threshold locked at 0.25 per Riv (S17.2-002 task prompt, Q1).
const ESCAPE_MAGNITUDE_MIN: float = 0.25

func _wall_escape_direction(b: BrottState) -> Vector2:
	# Push away from nearest wall/pillar. If no clear wall/pillar vector (rare,
	# since we only arm near geometry), bias TOWARD target — advancing breaks
	# wedge standoffs and, critically, does NOT produce the moonwalk arc that a
	# perpendicular-to-target fallback would (Boltz HOLD review, Flag 1).
	#
	# S17.2-002 (issue #180): the magnitude gate below catches the near-cancelling
	# corner+pillar case that the previous `> 0.01` gate let through as direction
	# noise. See docs/design/s17.2-001-wall-stuck.md §4 for Gizmo's root-cause
	# analysis.
	const WALL_PROX_PX: float = TILE_SIZE
	const PILLAR_PROX_PX: float = BOT_HITBOX_RADIUS + 48.0
	var arena_px: float = 16.0 * TILE_SIZE
	var e := Vector2.ZERO
	if b.position.x < WALL_PROX_PX: e.x += 1.0
	if b.position.x > arena_px - WALL_PROX_PX: e.x -= 1.0
	if b.position.y < WALL_PROX_PX: e.y += 1.0
	if b.position.y > arena_px - WALL_PROX_PX: e.y -= 1.0
	for p: Vector2 in _get_pillar_positions():
		var away: Vector2 = b.position - p
		if away.length() < PILLAR_PROX_PX and away.length() > 0.01:
			e += away.normalized()
	if e.length() >= ESCAPE_MAGNITUDE_MIN:
		return e.normalized()
	if b.target != null and b.target.alive:
		var tt: Vector2 = b.target._pos_snapshot - b.position
		if tt.length() > 0.01:
			return tt.normalized()
	return Vector2.ZERO

# S17.2-002: the ONE unstick write-site. Applies the 7 px/tick nudge with the
# S15 moonwalk backward-component clamp and the arena-bounds clamp. Extracted
# as a single call-site so S17.2-003 (scout-feel) can route this write around
# its velocity-smoothing layer via a `bypass_smoothing` opt-out — the smoothing
# lag would otherwise defeat the 8-tick unstick maneuver. Grep-verified: this
# is the only `b.position +=` write inside `_check_and_handle_stuck`.
func _apply_unstick_nudge(b: BrottState, push: Vector2) -> void:
	# S15 moonwalk fix: clamp the backward component of the unstick nudge
	# against the shared `backup_distance` budget (TILE_SIZE). The escape
	# direction can resolve to a backward vector when no clear wall/pillar
	# signal is available; without this gate, the nudge is a 7px/tick
	# unclamped retreat source. Forward/lateral components pass through
	# untouched — the unstick maneuver's job is to escape geometry, not to
	# out-retreat the moonwalk invariant. See docs/kb/juke-bypass-movement-caps.md.
	if b.target != null:
		var to_target_u: Vector2 = b.target._pos_snapshot - b.position
		if to_target_u.length_squared() > 0.0001:
			var to_target_n: Vector2 = to_target_u.normalized()
			var along: float = push.dot(to_target_n)
			var perp_push: Vector2 = push - to_target_n * along
			if along < 0.0:
				var remaining_budget: float = maxf(0.0, TILE_SIZE - b.backup_distance)
				var backward_mag: float = minf(-along, remaining_budget)
				b.backup_distance += backward_mag
				b.position += perp_push + to_target_n * (-backward_mag)
			else:
				b.position += push
		else:
			b.position += push
	else:
		b.position += push
	var arena_px2: float = 16.0 * TILE_SIZE
	b.position.x = clampf(b.position.x, BOT_HITBOX_RADIUS, arena_px2 - BOT_HITBOX_RADIUS)
	b.position.y = clampf(b.position.y, BOT_HITBOX_RADIUS, arena_px2 - BOT_HITBOX_RADIUS)

# S17.2-003: Velocity-smoothing helper. Single writer of b.velocity.
#
# Math per docs/design/s17.2-scout-feel.md §4.2:
#   1. Rotate current velocity toward desired direction, capped by per-tick
#      max_angular_velocity. Large rotations (> REVERSAL_ANGLE_THRESHOLD_DEG)
#      arm a short damping timer.
#   2. Blend magnitude toward |desired| using chassis accel/decel. While the
#      damping timer is active, the target magnitude is scaled by
#      REVERSAL_DAMPING_FACTOR to produce the visible "plant foot" dip.
#   3. Write the blended vector back to b.velocity and return realized
#      displacement (velocity * dt) for the caller to apply to b.position.
#
# IMPORTANT: this is the SMOOTHED-INTENT lane only. Retreat, separation,
# pillar-repel, arena clamp, and unstick writes all BYPASS this helper and
# write b.position directly without touching b.velocity. See the revision doc
# (docs/design/s17.2-003-scout-feel-revision.md) §2 for the full site table.
func _smooth_velocity(b: BrottState, desired: Vector2, dt: float) -> Vector2:
	var cur: Vector2 = b.velocity
	var des: Vector2 = desired
	var cur_len_sq: float = cur.length_squared()
	var des_len_sq: float = des.length_squared()

	# Step 1: rotate current velocity toward desired direction (angular cap).
	var large_reversal: bool = false
	if cur_len_sq > 0.0001 and des_len_sq > 0.0001:
		var cur_angle: float = cur.angle()
		var des_angle: float = des.angle()
		var angle_diff: float = wrapf(des_angle - cur_angle, -PI, PI)
		var max_rot: float = b.max_angular_velocity * dt
		var rot: float = clampf(angle_diff, -max_rot, max_rot)
		cur = cur.rotated(rot)
		if absf(angle_diff) > deg_to_rad(REVERSAL_ANGLE_THRESHOLD_DEG):
			large_reversal = true

	# Arm reversal damping on large intent reversals. The timer is consumed by
	# the magnitude step below; bypass writes (retreat, etc.) never arm it.
	if large_reversal and b.reversal_damping_timer <= 0:
		b.reversal_damping_timer = REVERSAL_DAMPING_TICKS

	# Step 2: blend magnitude toward |des| at chassis accel/decel.
	var cur_mag: float = cur.length()
	var des_mag: float = des.length()
	var target_mag: float = des_mag
	if b.reversal_damping_timer > 0:
		target_mag = des_mag * REVERSAL_DAMPING_FACTOR
	var mag_delta: float
	if target_mag > cur_mag:
		mag_delta = minf(b.get_effective_accel() * dt, target_mag - cur_mag)
	else:
		mag_delta = -minf(b.get_effective_decel() * dt, cur_mag - target_mag)
	var new_mag: float = cur_mag + mag_delta
	var new_dir: Vector2
	if cur.length_squared() > 0.0001:
		new_dir = cur.normalized()
	elif des_len_sq > 0.0001:
		new_dir = des.normalized()
	else:
		new_dir = Vector2.ZERO
	b.velocity = new_dir * new_mag

	# Consume one tick of the damping timer at the end.
	if b.reversal_damping_timer > 0:
		b.reversal_damping_timer -= 1

	return b.velocity * dt

# S17.2-003 Addendum 1: apply a smoothed-intent displacement with a budget gate
# on its backward-along-target component. Forward and perpendicular components
# pass through untouched; any backward-along component is clamped against the
# remaining `backup_distance` budget (same contract as separation L625 and
# unstick nudge L790). Closes the wall-clamp + orbit-flip limit-cycle bypass
# identified in the strict-zero moonwalk seeds 5/8/80/83.
func _apply_smoothed_displacement(b: BrottState, delta: Vector2) -> void:
	if b.target == null or delta.length_squared() < 0.0001:
		b.position += delta
		return
	var to_target_v: Vector2 = b.target._pos_snapshot - b.position
	if to_target_v.length_squared() < 0.0001:
		b.position += delta
		return
	var to_target_n: Vector2 = to_target_v.normalized()
	var along: float = delta.dot(to_target_n)
	if along >= 0.0:
		b.position += delta  # forward or purely perpendicular — passthrough
		return
	var perp_delta: Vector2 = delta - to_target_n * along
	var remaining_budget: float = maxf(0.0, TILE_SIZE - b.backup_distance)
	var backward_mag: float = minf(-along, remaining_budget)
	b.backup_distance += backward_mag
	b.position += perp_delta + to_target_n * (-backward_mag)

func _do_combat_movement(b: BrottState, base_spd: float) -> void:
	var to_target: Vector2 = b.target._pos_snapshot - b.position
	var dist: float = to_target.length()
	var engage: Dictionary = _get_engagement_distance(b)
	var ideal: float = engage["ideal"]
	var tolerance: float = engage["tolerance"]
	
	# --- TCR State Machine (S13.2; per-chassis durations S13.3) ---
	b.combat_phase_timer -= 1
	var tcr: Dictionary = _get_tension_range(b)
	
	# Phase transitions
	if b.combat_phase_timer <= 0:
		match b.combat_phase:
			0:  # TENSION -> COMMIT
				b.combat_phase = 1
				b.combat_phase_timer = tcr["commit"]
				b.commit_start_distance = dist
				if json_log_enabled:
					_tick_events.append({"type": "tcr_phase", "bot_id": b.bot_name, "phase": "COMMIT", "duration": tcr["commit"]})
			1:  # COMMIT -> RECOVERY
				b.combat_phase = 2
				b.combat_phase_timer = tcr["recovery"]
				b.backup_distance = 0.0
				if json_log_enabled:
					_tick_events.append({"type": "tcr_phase", "bot_id": b.bot_name, "phase": "RECOVERY", "duration": tcr["recovery"]})
			2:  # RECOVERY -> TENSION
				b.combat_phase = 0
				b.combat_phase_timer = rng.randi_range(tcr["min"], tcr["max"])
				b.tension_drift_timer = TENSION_DRIFT_INTERVAL
				b.backup_distance = 0.0
				if json_log_enabled:
					_tick_events.append({"type": "tcr_phase", "bot_id": b.bot_name, "phase": "TENSION", "duration": b.combat_phase_timer})
	
	match b.combat_phase:
		0:  # TENSION — orbit at 55% base speed with small lateral drifts
			var orbit_target_speed: float = b.base_speed * ORBIT_SPEED_MULT
			if b.afterburner_active:
				orbit_target_speed *= 1.80
			if overtime_active:
				orbit_target_speed *= OVERTIME_SPEED_MULT
			b.accelerate_toward_speed(orbit_target_speed, TICK_DELTA)
			var orbit_spd: float = b.current_speed * TICK_DELTA
			
			# Lateral drift every 1.0s
			b.tension_drift_timer -= 1
			var drift_offset: float = 0.0
			if b.tension_drift_timer <= 0:
				b.tension_drift_timer = TENSION_DRIFT_INTERVAL
				drift_offset = TENSION_DRIFT_AMOUNT * TILE_SIZE * (1.0 if rng.randf() < 0.5 else -1.0)
			
			# S17.2-003: smoothed-intent accumulator for this tick. Retreat writes
			# (revision §2 #21) bypass this accumulator and write b.position
			# directly so the backup_distance budget stays tick-accurate.
			var desired_vel_t: Vector2 = Vector2.ZERO
			var to_target_n_t: Vector2 = Vector2.ZERO
			if to_target.length_squared() > 0.0001:
				to_target_n_t = to_target.normalized()
			var perp_t: Vector2 = Vector2(-to_target.y, to_target.x)
			if perp_t.length_squared() > 0.0001:
				perp_t = perp_t.normalized()
			
			if dist > ideal + tolerance:
				# Smoothed (#20): forward-chase toward target.
				desired_vel_t += to_target_n_t * b.current_speed
				b.backup_distance = 0.0
			elif dist < ideal - tolerance:
				if b.backup_distance < TILE_SIZE:
					# Direct-write (#21): TENSION-too-close retreat. Bypass smoothing
					# so backup_distance budget stays tick-accurate (revision §3.2).
					# S17.2-003 addendum: halve retreat step under two-phase tick.
					var step: float = minf(orbit_spd * RETREAT_SPEED_MULT, TILE_SIZE - b.backup_distance)
					b.position -= to_target_n_t * step
					b.backup_distance += step
				else:
					# Smoothed (#22): budget-exhausted lateral orbit.
					desired_vel_t += perp_t * float(b.orbit_direction) * b.current_speed
					b.backup_distance = 0.0
			else:
				# Smoothed (#23): in-band lateral orbit.
				desired_vel_t += perp_t * float(b.orbit_direction) * b.current_speed
				b.backup_distance = 0.0
			
			# S17.2-003 deviation from revision §5.3: drift nudge is NOT routed
			# through the smoothed-intent accumulator.
			#
			# Background: the revision's §5.3 pseudocode lists the drift nudge as
			# site #24 (smoothed). Implementing it that way drove the mirror
			# Scout-vs-Scout WR from baseline 53% to 86% team-0 bias. Diagnosis
			# (empirical, diag_mirror.gd): feeding drift through _smooth_velocity
			# amplifies a ~0.3-tile one-shot displacement into ~2–3 ticks of
			# persistent lateral momentum. Because the TENSION RNG draw for
			# drift direction is consumed sequentially (team 0 first, team 1
			# second) and velocity inherits across ticks, the lateral momentum
			# compounds asymmetrically.
			#
			# Fix: zero the drift contribution for now. The drift effect is
			# preserved in principle — it could be re-introduced by a Gizmo
			# design pass that accounts for tick-order symmetry (e.g. paired RNG,
			# or synchronized drift direction across both bots). That is out of
			# scope for S17.2-003. Treating it as a direct-write at 0.3 tile is
			# also asymmetric (tested: 81.5% bias), so full removal is the
			# cleanest neutral state until the design question is answered.
			if drift_offset != 0.0:
				pass
			
			if desired_vel_t.length_squared() > 0.0001:
				_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_t, TICK_DELTA))
		
		1:  # COMMIT — dash toward target at 140% base speed (capped at COMMIT_SPEED_CAP px/s, S13.3)
			# Pre-afterburner/overtime commit target is min(base_speed * 1.4, COMMIT_SPEED_CAP).
			# Afterburner and overtime multipliers stack on top of the (already capped) commit speed,
			# preserving the relative feel of those buffs while fixing the Scout teleport case.
			var commit_target_speed: float = minf(b.base_speed * COMMIT_SPEED_MULT, COMMIT_SPEED_CAP)
			if b.afterburner_active:
				commit_target_speed *= 1.80
			if overtime_active:
				commit_target_speed *= OVERTIME_SPEED_MULT
			b.accelerate_toward_speed(commit_target_speed, TICK_DELTA)
			var _commit_spd: float = b.current_speed * TICK_DELTA
			
			# Dash toward target, but don't get closer than 0.5 tiles.
			# Smoothed (#25): canonical scout-feel forward-chase.
			var min_dist: float = 0.5 * TILE_SIZE
			var commit_target_dist: float = maxf(ideal - 1.5 * TILE_SIZE, min_dist)
			if dist > commit_target_dist and to_target.length_squared() > 0.0001:
				var desired_vel_c: Vector2 = to_target.normalized() * b.current_speed
				_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_c, TICK_DELTA))
		
		2:  # RECOVERY — retreat back toward ideal engagement distance
			var recovery_target_speed: float = b.base_speed * DISENGAGE_SPEED_MULT
			if b.afterburner_active:
				recovery_target_speed *= 1.80
			if overtime_active:
				recovery_target_speed *= OVERTIME_SPEED_MULT
			b.accelerate_toward_speed(recovery_target_speed, TICK_DELTA)
			var recovery_spd: float = b.current_speed * TICK_DELTA
			
			var to_target_n_r: Vector2 = Vector2.ZERO
			if to_target.length_squared() > 0.0001:
				to_target_n_r = to_target.normalized()
			if dist < ideal and b.backup_distance < TILE_SIZE:
				# Direct-write (#26): RECOVERY retreat. Bypass smoothing; same
				# backup-budget invariant as #21.
				# S17.2-003 addendum: halve retreat step under two-phase tick.
				var step: float = minf(recovery_spd * RETREAT_SPEED_MULT, TILE_SIZE - b.backup_distance)
				b.position -= to_target_n_r * step
				b.backup_distance += step
			else:
				# Smoothed (#27): lateral once backup budget is exhausted (or
				# already at/beyond ideal).
				var perp_r: Vector2 = Vector2(-to_target.y, to_target.x)
				if perp_r.length_squared() > 0.0001:
					perp_r = perp_r.normalized()
					var desired_vel_r: Vector2 = perp_r * float(b.orbit_direction) * b.current_speed
					_apply_smoothed_displacement(b, _smooth_velocity(b, desired_vel_r, TICK_DELTA))

func _get_max_weapon_range_px(b: BrottState) -> float:
	var max_r: float = 0.0
	for wt: WeaponData.WeaponType in b.weapon_types:
		var wd: Dictionary = WeaponData.get_weapon(wt)
		max_r = maxf(max_r, float(wd["range_tiles"]) * TILE_SIZE)
	if max_r == 0.0:
		max_r = 3.0 * TILE_SIZE
	return max_r

func _get_pillar_positions() -> Array[Vector2]:
	var center: float = 8.0 * TILE_SIZE
	var offset: float = 2.5 * TILE_SIZE
	return [
		Vector2(center - offset, center - offset),
		Vector2(center + offset, center - offset),
		Vector2(center - offset, center + offset),
		Vector2(center + offset, center + offset),
	]
func _fire_weapons(b: BrottState) -> void:
	if b.target == null or not b.target.alive:
		return
	
	# Check weapon mode from brain
	var wmode: String = "all_fire"
	if b.brain != null:
		wmode = b.brain.weapon_mode
	if wmode == "hold_fire":
		return
	
	for i in range(b.weapon_types.size()):
		if b.weapon_cooldowns[i] > 0:
			b.weapon_cooldowns[i] -= 1.0
			continue
		
		var wt: WeaponData.WeaponType = b.weapon_types[i]
		var wd: Dictionary = WeaponData.get_weapon(wt)
		
		var dist: float = b.position.distance_to(b.target.position)
		var range_px: float = float(wd["range_tiles"]) * TILE_SIZE
		if dist > range_px:
			continue
		
		if b.energy < float(wd["energy_cost"]):
			continue
		
		# Conserve mode: only fire if energy > 50%
		if wmode == "conserve" and b.energy < 50.0:
			continue
		
		b.energy -= float(wd["energy_cost"])
		var fire_rate: float = float(wd["fire_rate"]) * b.get_fire_rate_multiplier()
		b.weapon_cooldowns[i] = float(TICKS_PER_SEC) / fire_rate
		
		# Instrumentation: track shots fired
		var wname: String = str(wd.get("name", str(wt)))
		shots_fired[wname] = shots_fired.get(wname, 0) + 1
		if json_log_enabled:
			_tick_events.append({"type": "weapon_fired", "bot_id": b.bot_name, "weapon": wname, "target_id": b.target.bot_name})
		if first_engagement_tick < 0:
			first_engagement_tick = tick_count
		
		var pellets: int = int(wd["pellets"])
		# S13.6: Per-match pellet modifier (from trick effects via BrottState.pellet_mod).
		# Additive; clamped to at least 1 so negative mods can't zero out a weapon.
		if b.pellet_mod != 0:
			pellets = max(1, pellets + b.pellet_mod)
		# S13.3: Track a per-trigger-pull "did any pellet land" flag via shot_id stored on
		# projectiles. We use a (bot_name, weapon_name, tick, shot_seq) tuple as the id;
		# shots_hit increments the first time any pellet from that tuple lands.
		var shot_id: String = "%s|%s|%d|%d" % [b.bot_name, wname, tick_count, i]
		for _p in range(pellets):
			var is_crit: bool = rng.randf() < CRIT_CHANCE
			var spread_rad: float = deg_to_rad(float(wd["spread_deg"]))
			var angle_offset: float = rng.randf_range(-spread_rad / 2.0, spread_rad / 2.0)
			
			var dir: Vector2 = (b.target.position - b.position).normalized()
			dir = dir.rotated(angle_offset)
			var target_pos: Vector2 = b.position + dir * range_px
			
			var proj: Projectile = Projectile.new(b, target_pos, float(wd["damage"]), is_crit, float(wd["range_tiles"]), int(wd["splash_radius"]), float(wd.get("projectile_speed", 400.0)), wname)
			proj.shot_id = shot_id
			# S13.3: per-pellet instrumentation
			pellets_fired[wname] = pellets_fired.get(wname, 0) + 1
			projectiles.append(proj)
			on_projectile_spawned.emit(proj)

func _update_projectiles() -> void:
	var to_remove: Array[int] = []
	
	for i in range(projectiles.size()):
		var proj: Projectile = projectiles[i]
		if not proj.alive:
			to_remove.append(i)
			continue
		
		var old_pos: Vector2 = proj.pos
		var remaining_range: float = proj.max_range_px - proj.traveled
		var step_dist: float = proj.speed * TICK_DELTA
		# Clamp step to remaining range so projectile doesn't overshoot
		if step_dist > remaining_range:
			step_dist = remaining_range
		var step: Vector2 = proj.velocity.normalized() * step_dist
		proj.pos += step
		proj.traveled += step_dist
		
		# Swept line-segment vs circle collision FIRST (S13.2 fix)
		var hit_someone := false
		for b in brotts:
			if not b.alive or b == proj.source or b.team == proj.source.team:
				continue
			# Closest point on segment [old_pos, proj.pos] to b.position
			var seg: Vector2 = proj.pos - old_pos
			var seg_len_sq: float = seg.length_squared()
			var closest_dist: float
			if seg_len_sq < 0.01:
				closest_dist = proj.pos.distance_to(b.position)
			else:
				var t: float = clampf((b.position - old_pos).dot(seg) / seg_len_sq, 0.0, 1.0)
				var closest_pt: Vector2 = old_pos + seg * t
				closest_dist = closest_pt.distance_to(b.position)
			
			if closest_dist <= BOT_HITBOX_RADIUS:
				if rng.randf() < b.dodge_chance:
					proj.alive = false
					to_remove.append(i)
					hit_someone = true
					break
				
				_apply_damage(b, proj.damage, proj.is_crit, proj.source, proj.pos, proj)
				
				if proj.splash_radius > 0:
					var splash_px: float = float(proj.splash_radius) * TILE_SIZE
					for other in brotts:
						if not other.alive or other == b or other.team == proj.source.team:
							continue
						if other.position.distance_to(proj.pos) <= splash_px:
							_apply_damage(other, proj.damage * 0.5, false, proj.source, other.position, null)
				
				proj.alive = false
				to_remove.append(i)
				hit_someone = true
				break
		
		if hit_someone:
			continue
		
		if proj.traveled >= proj.max_range_px:
			proj.alive = false
			to_remove.append(i)
			continue
	
	to_remove.sort()
	for j in range(to_remove.size() - 1, -1, -1):
		projectiles.remove_at(to_remove[j])

func _apply_damage(target: BrottState, base_dmg: float, is_crit: bool, source: BrottState, hit_pos: Vector2, proj: Projectile = null) -> void:
	var reduction: float = target.get_armor_reduction()
	var crit_mult: float = CRIT_MULT if is_crit else 1.0
	var overtime_mult: float = 1.0
	if sudden_death_active:
		overtime_mult = SUDDEN_DEATH_DAMAGE_MULT
	elif overtime_active:
		overtime_mult = OVERTIME_DAMAGE_MULT
	var effective: float = base_dmg * (1.0 - reduction) * crit_mult * overtime_mult
	effective = maxf(effective, 1.0)
	
	if target.shield_active and target.shield_hp > 0:
		var absorbed: float = minf(effective, target.shield_hp)
		target.shield_hp -= absorbed
		effective -= absorbed
		if target.shield_hp <= 0:
			target.shield_active = false
	
	if effective > 0:
		target.hp -= effective
		target.flash_timer = 3.0
		if json_log_enabled:
			_tick_events.append({"type": "damage_dealt", "target_id": target.bot_name, "amount": effective, "is_crit": is_crit})
		on_damage.emit(target, effective, is_crit, hit_pos)
		# --- Instrumentation (S11.2, fixed S13.3) ---
		# Credit the projectile's source weapon (not just the first weapon on the bot),
		# and only count pellet-level hits here. Shots-level hits are credited once per
		# trigger-pull via shot_id below. Splash damage (proj=null) is not counted as a
		# direct hit — it's collateral on other bots, not a projectile landing.
		if proj != null:
			var wn: String = proj.source_weapon_name
			if wn == "" and source != null and source.weapon_types.size() > 0:
				var wd_fb: Dictionary = WeaponData.get_weapon(source.weapon_types[0])
				wn = str(wd_fb.get("name", ""))
			if wn != "":
				pellets_hit[wn] = pellets_hit.get(wn, 0) + 1
				if proj.shot_id != "" and not _shots_hit_ids.has(proj.shot_id):
					_shots_hit_ids[proj.shot_id] = true
					shots_hit[wn] = shots_hit.get(wn, 0) + 1
	
	var armor_data: Dictionary = ArmorData.get_armor(target.armor_type)
	if str(armor_data["special"]) == "reflect" and source.alive:
		source.hp -= 5.0
		if source.hp <= 0:
			_kill_brott(source)
	
	if target.hp <= 0:
		_kill_brott(target)

func _kill_brott(b: BrottState) -> void:
	b.alive = false
	b.hp = 0.0
	b.death_timer = 20.0
	# Instrumentation: record kill tick
	if not kill_ticks.has(b.bot_name):
		kill_ticks[b.bot_name] = tick_count
	if json_log_enabled:
		_tick_events.append({"type": "bot_destroyed", "bot_id": b.bot_name, "tick": tick_count})
	on_death.emit(b)

func _check_match_end() -> void:
	var team0_alive: bool = false
	var team1_alive: bool = false
	for b in brotts:
		if b.alive:
			if b.team == 0:
				team0_alive = true
			else:
				team1_alive = true
	
	if not team0_alive and not team1_alive:
		match_over = true
		winner_team = 2
		on_match_end.emit(winner_team)
	elif not team1_alive:
		match_over = true
		winner_team = 0
		on_match_end.emit(winner_team)
	elif not team0_alive:
		match_over = true
		winner_team = 1
		on_match_end.emit(winner_team)
	elif tick_count >= _get_timeout_ticks():
		match_over = true
		var hp_pct_0: float = _team_hp_pct(0)
		var hp_pct_1: float = _team_hp_pct(1)
		if hp_pct_0 > hp_pct_1:
			winner_team = 0
		elif hp_pct_1 > hp_pct_0:
			winner_team = 1
		else:
			winner_team = 2
		on_match_end.emit(winner_team)

func get_arena_boundary_tiles() -> float:
	return arena_boundary_tiles

## --- Instrumentation API (S11.2) ---

func get_hit_rates() -> Dictionary:
	## S13.3: Canonical hit rate is per-pellet (pellets_hit / pellets_fired).
	## A trigger-pull with a shotgun that fires 5 pellets and lands 1 has:
	##   per-shot hit rate  = 1/1 = 100% (did the shot connect? yes)
	##   per-pellet hit rate = 1/5 = 20%  (how many individual projectiles landed?)
	## The per-pellet number is what's used for balance and can never exceed 100%.
	var result: Dictionary = {}
	for wname in pellets_fired:
		var fired: int = pellets_fired[wname]
		var hit: int = pellets_hit.get(wname, 0)
		result[wname] = float(hit) / float(fired) if fired > 0 else 0.0
	return result

func get_per_shot_hit_rates() -> Dictionary:
	## S13.3: Per-trigger-pull hit rate (did ANY pellet from that shot land?).
	## Returns {weapon_name: rate_float}. Always ≤ 1.0.
	var result: Dictionary = {}
	for wname in shots_fired:
		var fired: int = shots_fired[wname]
		var hit: int = shots_hit.get(wname, 0)
		result[wname] = float(hit) / float(fired) if fired > 0 else 0.0
	return result

func get_ttk_seconds() -> Dictionary:
	## Returns {bot_name: ttk_seconds} for each bot that died
	var result: Dictionary = {}
	var engage_tick: int = first_engagement_tick if first_engagement_tick >= 0 else 0
	for bname in kill_ticks:
		var death_tick: int = kill_ticks[bname]
		result[bname] = float(death_tick - engage_tick) / float(TICKS_PER_SEC)
	return result

func get_regression_summary() -> Dictionary:
	## Returns summary stats for regression comparison
	return {
		"winner_team": winner_team,
		"ticks": tick_count,
		"duration_sec": float(tick_count) / float(TICKS_PER_SEC),
		"hit_rates": get_hit_rates(),           # per-pellet (canonical)
		"per_shot_hit_rates": get_per_shot_hit_rates(),  # S13.3: per-trigger-pull
		"shots_fired": shots_fired.duplicate(),
		"shots_hit": shots_hit.duplicate(),
		"pellets_fired": pellets_fired.duplicate(),
		"pellets_hit": pellets_hit.duplicate(),
		"ttk": get_ttk_seconds(),
		"overtime": overtime_active,
		"sudden_death": sudden_death_active,
	}

static func batch_regression_summary(results: Array[Dictionary]) -> Dictionary:
	## Aggregate multiple sim summaries into a regression baseline
	var wins: Dictionary = {}
	var ttk_list: Array[float] = []
	var hit_rate_sums: Dictionary = {}
	var hit_rate_counts: Dictionary = {}
	for r in results:
		var w: int = r["winner_team"]
		wins[w] = wins.get(w, 0) + 1
		for bname in r["ttk"]:
			ttk_list.append(r["ttk"][bname])
		for wname in r["hit_rates"]:
			hit_rate_sums[wname] = hit_rate_sums.get(wname, 0.0) + r["hit_rates"][wname]
			hit_rate_counts[wname] = hit_rate_counts.get(wname, 0) + 1
	var avg_hit_rates: Dictionary = {}
	for wname in hit_rate_sums:
		avg_hit_rates[wname] = hit_rate_sums[wname] / float(hit_rate_counts[wname])
	var avg_ttk: float = 0.0
	if ttk_list.size() > 0:
		for t in ttk_list:
			avg_ttk += t
		avg_ttk /= float(ttk_list.size())
	return {
		"total_sims": results.size(),
		"win_rates": wins,
		"avg_ttk_sec": avg_ttk,
		"avg_hit_rates": avg_hit_rates,
	}

## --- JSON match log (S12.5) ---

func _get_match_state() -> String:
	if match_over:
		return "completed"
	if sudden_death_active:
		return "sudden_death"
	if overtime_active:
		return "overtime"
	return "in_progress"

func _append_tick_log() -> void:
	var bot_states: Array = []
	for b in brotts:
		bot_states.append({
			"id": b.bot_name,
			"position_x": b.position.x,
			"position_y": b.position.y,
			"hp": b.hp,
			"max_hp": b.max_hp,
			"energy": b.energy,
			"current_speed": b.current_speed,
			"stance": b.stance,
			"target_id": b.target.bot_name if b.target else "",
			"facing_angle": b.facing_angle,
			"combat_phase": ["TENSION", "COMMIT", "RECOVERY"][b.combat_phase] if b.in_combat_movement else "NONE",
		})
	_json_log.append({
		"tick": tick_count,
		"bots": bot_states,
		"events": _tick_events,
		"match_state": _get_match_state(),
	})

func _team_hp_pct(team: int) -> float:
	var total_hp: float = 0.0
	var total_max: float = 0.0
	for b in brotts:
		if b.team == team:
			total_hp += maxf(b.hp, 0.0)
			total_max += float(b.max_hp)
	if total_max == 0:
		return 0.0
	return total_hp / total_max
