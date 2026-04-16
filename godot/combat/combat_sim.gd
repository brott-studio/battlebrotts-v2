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
const MATCH_TIMEOUT_TICKS: int = 90 * 10

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

# --- Instrumentation (S11.2) ---
var shots_fired: Dictionary = {}   # weapon_name -> int
var shots_hit: Dictionary = {}     # weapon_name -> int
var first_engagement_tick: int = -1
var kill_ticks: Dictionary = {}    # bot_name -> tick when killed

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

func simulate_tick() -> void:
	if match_over:
		return
	tick_count += 1
	
	# Check overtime trigger
	if not overtime_active and tick_count >= _get_overtime_ticks():
		overtime_active = true
		for b in brotts:
			if b.alive:
				b.stance = 0  # Force Aggressive
				b.overtime = true
	
	# Check sudden death escalation
	if not sudden_death_active and tick_count >= _get_sudden_death_ticks():
		sudden_death_active = true

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

func _enter_combat_movement(b: BrottState) -> void:
	b.in_combat_movement = true
	b.orbit_direction = 1 if rng.randf() < 0.5 else -1
	b.juke_timer = float(rng.randf_range(1.5, 3.0)) * float(TICKS_PER_SEC)
	b.juke_active_timer = 0.0
	b.backup_distance = 0.0

func _exit_combat_movement(b: BrottState) -> void:
	b.in_combat_movement = false
	b.juke_active_timer = 0.0
	b.juke_timer = 0.0
	b.backup_distance = 0.0

func _move_brott(b: BrottState) -> void:
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
			b.position += to_center.normalized() * spd
		else:
			b.position = center
	elif move_override == "cover":
		b.accelerate_toward_speed(target_speed, TICK_DELTA)
		var spd: float = b.current_speed * TICK_DELTA
		var best_pillar := Vector2.ZERO
		var best_dist := INF
		for p in _get_pillar_positions():
			var d := b.position.distance_to(p)
			if d < best_dist:
				best_dist = d
				best_pillar = p
		if best_dist > 32.0:
			b.position += (best_pillar - b.position).normalized() * spd
	else:
		var to_target: Vector2 = b.target.position - b.position
		var dist: float = to_target.length()
		var max_weapon_range: float = _get_max_weapon_range_px(b)
		var has_los: bool = _has_los(b.position, b.target.position)
		
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
			# Stance-based pathfinding (pre-engagement or ambush)
			match b.stance:
				0:  # Aggressive — close to engagement distance
					var engage: Dictionary = _get_engagement_distance(b)
					if dist > engage["ideal"] + engage["tolerance"]:
						b.position += to_target.normalized() * spd
				1:  # Defensive
					if dist < max_weapon_range * 0.8:
						b.position -= to_target.normalized() * spd
					elif dist > max_weapon_range:
						b.position += to_target.normalized() * spd
				2:  # Kiting
					var ideal: float = max_weapon_range * 0.7
					var perp: Vector2 = Vector2(-to_target.y, to_target.x).normalized()
					if dist < ideal * 0.8:
						b.position -= to_target.normalized() * spd * 0.7
						b.position += perp * spd * 0.3
					elif dist > ideal * 1.2:
						b.position += to_target.normalized() * spd
					else:
						b.position += perp * spd
				3:  # Ambush
					pass
	
	# Update visual facing angle (turn speed is visual-only)
	if b.target != null:
		var desired_angle: float = rad_to_deg((b.target.position - b.position).angle())
		var angle_diff: float = fmod(desired_angle - b.facing_angle + 540.0, 360.0) - 180.0
		var max_turn: float = b.turn_speed * TICK_DELTA
		if absf(angle_diff) <= max_turn:
			b.facing_angle = desired_angle
		else:
			b.facing_angle += signf(angle_diff) * max_turn
		b.facing_angle = fmod(b.facing_angle + 360.0, 360.0)
	
	# Bot-bot separation force (S11.1: 32px threshold, 60% base speed)
	var sep_threshold: float = TILE_SIZE  # 32px = 1 tile
	for other in brotts:
		if other == b or not other.alive:
			continue
		var sep: Vector2 = b.position - other.position
		var sep_dist: float = sep.length()
		if sep_dist < sep_threshold and sep_dist > 0.01:
			var repulsion_speed: float = b.base_speed * 0.6 * TICK_DELTA
			b.position += sep.normalized() * repulsion_speed
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

func _do_combat_movement(b: BrottState, base_spd: float) -> void:
	var to_target: Vector2 = b.target.position - b.position
	var dist: float = to_target.length()
	var engage: Dictionary = _get_engagement_distance(b)
	var ideal: float = engage["ideal"]
	var tolerance: float = engage["tolerance"]
	
	# Juke active — juke bursts at 120% base speed subject to accel
	if b.juke_active_timer > 0:
		b.juke_active_timer -= 1.0
		var juke_target_speed: float = b.base_speed * 1.2
		if b.afterburner_active:
			juke_target_speed *= 1.80
		if overtime_active:
			juke_target_speed *= OVERTIME_SPEED_MULT
		b.accelerate_toward_speed(juke_target_speed, TICK_DELTA)
		var juke_spd: float = b.current_speed * TICK_DELTA
		match b.juke_type:
			"lateral":
				var perp: Vector2 = Vector2(-to_target.y, to_target.x).normalized()
				b.position += perp * float(b.orbit_direction) * juke_spd
			"toward":
				if dist > TILE_SIZE * 0.5:
					b.position += to_target.normalized() * juke_spd
			"away":
				if b.backup_distance < TILE_SIZE:
					var step: float = minf(juke_spd, TILE_SIZE - b.backup_distance)
					b.position -= to_target.normalized() * step
					b.backup_distance += step
					if b.backup_distance >= TILE_SIZE:
						b.juke_active_timer = 0.0  # End juke early — cap reached
		if b.juke_active_timer <= 0:
			if b.juke_type == "lateral":
				b.orbit_direction *= -1
			b.juke_timer = float(rng.randf_range(1.5, 3.0)) * float(TICKS_PER_SEC)
		return
	
	# Juke trigger
	b.juke_timer -= 1.0
	if b.juke_timer <= 0:
		b.juke_active_timer = 4.0  # 4 ticks = 0.4s at 10 ticks/sec
		var roll: float = rng.randf()
		if roll < 0.6:
			b.juke_type = "lateral"
			b.orbit_direction *= -1
		elif roll < 0.9:
			b.juke_type = "toward"
		else:
			b.juke_type = "away"
		return
	
	# Normal combat movement — orbit at 70% base speed subject to accel
	var orbit_target_speed: float = b.base_speed * 0.7
	if b.afterburner_active:
		orbit_target_speed *= 1.80
	if overtime_active:
		orbit_target_speed *= OVERTIME_SPEED_MULT
	b.accelerate_toward_speed(orbit_target_speed, TICK_DELTA)
	var orbit_spd: float = b.current_speed * TICK_DELTA
	
	if dist > ideal + tolerance:
		b.position += to_target.normalized() * base_spd
		b.backup_distance = 0.0
	elif dist < ideal - tolerance:
		if b.backup_distance < TILE_SIZE:
			var step: float = minf(base_spd, TILE_SIZE - b.backup_distance)
			b.position -= to_target.normalized() * step
			b.backup_distance += step
		else:
			var perp: Vector2 = Vector2(-to_target.y, to_target.x).normalized()
			b.position += perp * float(b.orbit_direction) * orbit_spd
			b.backup_distance = 0.0
	else:
		var perp: Vector2 = Vector2(-to_target.y, to_target.x).normalized()
		b.position += perp * float(b.orbit_direction) * orbit_spd
		b.backup_distance = 0.0

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
		if first_engagement_tick < 0:
			first_engagement_tick = tick_count
		
		var pellets: int = int(wd["pellets"])
		for _p in range(pellets):
			var is_crit: bool = rng.randf() < CRIT_CHANCE
			var spread_rad: float = deg_to_rad(float(wd["spread_deg"]))
			var angle_offset: float = rng.randf_range(-spread_rad / 2.0, spread_rad / 2.0)
			
			var dir: Vector2 = (b.target.position - b.position).normalized()
			dir = dir.rotated(angle_offset)
			var target_pos: Vector2 = b.position + dir * range_px
			
			var proj: Projectile = Projectile.new(b, target_pos, float(wd["damage"]), is_crit, float(wd["range_tiles"]), int(wd["splash_radius"]))
			projectiles.append(proj)
			on_projectile_spawned.emit(proj)

func _update_projectiles() -> void:
	var to_remove: Array[int] = []
	
	for i in range(projectiles.size()):
		var proj: Projectile = projectiles[i]
		if not proj.alive:
			to_remove.append(i)
			continue
		
		proj.pos += proj.velocity * TICK_DELTA
		proj.traveled += proj.speed * TICK_DELTA
		
		if proj.traveled >= proj.max_range_px:
			proj.alive = false
			to_remove.append(i)
			continue
		
		for b in brotts:
			if not b.alive or b == proj.source or b.team == proj.source.team:
				continue
			if proj.pos.distance_to(b.position) <= BOT_HITBOX_RADIUS:
				if rng.randf() < b.dodge_chance:
					proj.alive = false
					to_remove.append(i)
					break
				
				_apply_damage(b, proj.damage, proj.is_crit, proj.source, proj.pos)
				
				if proj.splash_radius > 0:
					var splash_px: float = float(proj.splash_radius) * TILE_SIZE
					for other in brotts:
						if not other.alive or other == b or other.team == proj.source.team:
							continue
						if other.position.distance_to(proj.pos) <= splash_px:
							_apply_damage(other, proj.damage * 0.5, false, proj.source, other.position)
				
				proj.alive = false
				to_remove.append(i)
				break
	
	to_remove.sort()
	for j in range(to_remove.size() - 1, -1, -1):
		projectiles.remove_at(to_remove[j])

func _apply_damage(target: BrottState, base_dmg: float, is_crit: bool, source: BrottState, hit_pos: Vector2) -> void:
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
		on_damage.emit(target, effective, is_crit, hit_pos)
		# Instrumentation: track shots hit (by source weapon)
		if source != null:
			for wt_idx in range(source.weapon_types.size()):
				var wd_instr: Dictionary = WeaponData.get_weapon(source.weapon_types[wt_idx])
				var wn: String = str(wd_instr.get("name", str(source.weapon_types[wt_idx])))
				shots_hit[wn] = shots_hit.get(wn, 0) + 1
				break  # attribute to first weapon (projectile doesn't track index)
	
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
	## Returns {weapon_name: hit_rate_float} for each weapon that fired
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
		"hit_rates": get_hit_rates(),
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
