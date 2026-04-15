## Core tick-based combat simulation
## 20 ticks/sec, deterministic given same RNG seed
class_name CombatSim
extends RefCounted

const TICKS_PER_SEC: int = 20
const TICK_DELTA: float = 1.0 / 20.0
const MAX_ENERGY: float = 100.0
const ENERGY_REGEN_PER_TICK: float = 5.0 / 20.0
const CRIT_CHANCE: float = 0.05
const CRIT_MULT: float = 1.5
const MATCH_TIMEOUT_TICKS: int = 120 * 20
const BOT_HITBOX_RADIUS: float = 12.0
const TILE_SIZE: float = 32.0

var brotts: Array[BrottState] = []
var projectiles: Array[Projectile] = []
var rng: RandomNumberGenerator
var tick_count: int = 0
var match_over: bool = false
var winner_team: int = -1

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
			var heal_per_tick: float = float(mdata["heal_per_sec"]) / 20.0
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
	
	var dur_ticks: float = float(mdata.get("duration", 0.0)) * 20.0
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
	var cd_ticks: float = float(mdata.get("cooldown", 0.0)) * 20.0
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

func _move_brott(b: BrottState) -> void:
	if b.target == null:
		return
	var spd: float = b.get_effective_speed() * TICK_DELTA
	
	# Check movement override from brain
	var move_override: String = ""
	if b.brain != null:
		move_override = b.brain.movement_override
	
	if move_override == "center":
		var center := Vector2(8.0 * TILE_SIZE, 8.0 * TILE_SIZE)
		var to_center := center - b.position
		if to_center.length() > spd:
			b.position += to_center.normalized() * spd
		else:
			b.position = center
	elif move_override == "cover":
		# Simplified: move toward nearest pillar
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
		
		match b.stance:
			0:  # Aggressive
				if dist > max_weapon_range * 0.5:
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
	
	var arena_px: float = 16.0 * TILE_SIZE
	b.position.x = clampf(b.position.x, BOT_HITBOX_RADIUS, arena_px - BOT_HITBOX_RADIUS)
	b.position.y = clampf(b.position.y, BOT_HITBOX_RADIUS, arena_px - BOT_HITBOX_RADIUS)
	
	for pillar_pos: Vector2 in _get_pillar_positions():
		var to_pillar: Vector2 = b.position - pillar_pos
		if to_pillar.length() < BOT_HITBOX_RADIUS + 16.0:
			b.position = pillar_pos + to_pillar.normalized() * (BOT_HITBOX_RADIUS + 16.0)

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
		b.weapon_cooldowns[i] = 20.0 / fire_rate
		
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
	var effective: float = base_dmg * (1.0 - reduction) * crit_mult
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
	elif tick_count >= MATCH_TIMEOUT_TICKS:
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
