## Visual arena renderer — Sprint 4: screen shake, hit flash, sparks, damage numbers, death explosions
extends Node2D

const TILE_SIZE := 32.0
const ARENA_TILES := 16
const ARENA_PX := ARENA_TILES * TILE_SIZE
const BOT_RADIUS := 12.0
const PILLAR_RADIUS := 16.0
const HEALTH_BAR_WIDTH := 28.0
const HEALTH_BAR_HEIGHT := 4.0
const ENERGY_BAR_HEIGHT := 3.0

const COLOR_FLOOR := Color(0.15, 0.15, 0.18)
const COLOR_GRID := Color(0.22, 0.22, 0.26)
const COLOR_PILLAR := Color(0.4, 0.4, 0.45)
const COLOR_PLAYER := Color(0.2, 0.4, 0.9)
const COLOR_ENEMY := Color(0.9, 0.2, 0.2)
const COLOR_SHIELD := Color(0.3, 0.6, 1.0, 0.4)
const COLOR_PROJECTILE := Color(1.0, 0.9, 0.3)
const COLOR_MISSILE := Color(1.0, 0.5, 0.1)
const COLOR_HP_HIGH := Color(0.2, 0.8, 0.2)
const COLOR_HP_MID := Color(0.9, 0.8, 0.1)
const COLOR_HP_LOW := Color(0.9, 0.2, 0.1)
const COLOR_ENERGY := Color(0.2, 0.7, 1.0)
const COLOR_BAR_BG := Color(0.1, 0.1, 0.1, 0.8)
const COLOR_EXPLOSION := Color(1.0, 0.6, 0.1)
const COLOR_DANGER_ZONE := Color(0.8, 0.1, 0.1, 0.35)
const COLOR_DANGER_BORDER := Color(1.0, 0.15, 0.1, 0.8)

var sim: CombatSim = null
var arena_offset: Vector2 = Vector2.ZERO
var damage_texts: Array = []
var particles: Array = []  # impact sparks (now pooled)
var particle_pool: Array = []  # pre-allocated particle pool (~200 slots)
var particle_pool_size: int = 200
var active_particle_count: int = 0  # tracks how many pool slots are active

# Screen shake state
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var shake_decay: String = "linear"  # "linear" or "ease_out"
var shake_offset: Vector2 = Vector2.ZERO

# Death sequence state
var death_freeze_timer: float = 0.0
var death_flash_timer: float = 0.0
var death_zoom: float = 1.0
var death_zoom_target: Vector2 = Vector2.ZERO
var death_zoom_timer: float = 0.0
var death_slow_mo_timer: float = 0.0
var death_debris: Array = []

# Overtime visual state
var overtime_flash_timer: float = 0.0
var overtime_banner_alpha: float = 0.0
var overtime_triggered: bool = false

# Sudden death visual state
var sudden_death_flash_timer: float = 0.0
var sudden_death_triggered: bool = false

# Hit flash tracking (max 1 flash per 3 frames)
var last_flash_frame: Dictionary = {}  # brott -> last flash frame
var frame_count: int = 0

# Shotgun damage accumulator
var shotgun_accum: Dictionary = {}  # target_id -> {total, pos, timer, is_crit}

# S12.4: Charm pass state
var charm_rng := RandomNumberGenerator.new()
var prev_brott_velocities: Dictionary = {}  # id -> Vector2
var prev_brott_speeds: Dictionary = {}  # id -> float
var fortress_micro_shake: Vector2 = Vector2.ZERO
var fortress_micro_shake_timer: float = 0.0
var overtime_glow_intensity: float = 0.0  # 0→1 for overtime light glow
var victory_sparks_spawned: bool = false

# ─────────────────────────────────────────────────────────────
# [S17.2-004] Dev-only velocity debug overlay
#
# Dev-flag-gated draw of velocity vectors per bot. OFF by default.
#
# Toggle mechanisms (either works; both resolve to `debug_velocity_overlay`):
#   1. Env var: BB_DEBUG_VELOCITY=1 (read once in setup())
#   2. Hotkey:  F3 (live toggle at runtime)
#
# Renders two vectors per bot:
#   - Cyan : computed velocity (position-delta / sample-dt). Always
#            available — this is the "Option B" implementation that
#            works on main today before S17.2-003 lands.
#   - Magenta: b.velocity. Drawn only when non-zero. On main, combat_sim.gd
#             never writes b.velocity, so this vector is invisible until
#             S17.2-003 ships in S17.3; then it lights up automatically.
#   - (Future) desired vector — depends on S17.2-003 exposing the tick's
#             desired direction. Follow-up task post-S17.2-003.
#
# Additive, dev-only, zero gameplay impact.
# ─────────────────────────────────────────────────────────────
var debug_velocity_overlay: bool = false
var _debug_prev_position: Dictionary = {}  # id -> Vector2
var _debug_prev_sample_time: Dictionary = {}  # id -> float (seconds)
var _debug_computed_velocity: Dictionary = {}  # id -> Vector2 (px/s)
const _DEBUG_SAMPLE_INTERVAL: float = 0.05  # resample every 50ms → ~20Hz
const _DEBUG_VELOCITY_SCALE: float = 0.15  # px per (px/s) — keeps arrows short
const _DEBUG_COLOR_COMPUTED := Color(0.2, 1.0, 1.0, 0.9)  # cyan
const _DEBUG_COLOR_VELOCITY := Color(1.0, 0.2, 1.0, 0.9)  # magenta

## S25.2: Click overlay state
var _waypoint_pos: Vector2 = Vector2.INF        # INF = no active waypoint
var _waypoint_fade_t: float = 0.0               # 0 = hidden, 1 = full alpha
var _reticle_target_id: int = -1                # -1 = no active reticle (index into sim.brotts)
var _pulse_accum: float = 0.0                   # accumulator for player outline pulse

## S25.2: Player brain reference (cached at setup for click handler)
var _player_brain: BrottBrain = null

func setup(p_sim: CombatSim, p_offset: Vector2) -> void:
	sim = p_sim
	arena_offset = p_offset
	sim.on_damage.connect(_on_damage)
	sim.on_death.connect(_on_death)
	# [S17.2-004] Env-var opt-in for dev velocity overlay.
	if OS.has_environment("BB_DEBUG_VELOCITY") and OS.get_environment("BB_DEBUG_VELOCITY") == "1":
		debug_velocity_overlay = true
		print("[S17.2-004] velocity debug overlay enabled via BB_DEBUG_VELOCITY=1")
	set_process_unhandled_input(true)
	charm_rng.seed = 12345  # deterministic for testing
	_init_particle_pool()

func _init_particle_pool() -> void:
	"""Pre-allocate particle pool at setup to prevent frame-time spikes during death bursts."""
	particle_pool.clear()
	for i in range(particle_pool_size):
		particle_pool.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"lifetime": 0.0,
			"max_lifetime": 0.0,
			"color": Color.WHITE,
			"size": 1.0,
			"active": false,
		})
	active_particle_count = 0

func _claim_particle() -> Dictionary:
	"""Claim an inactive particle from the pool. Returns null if pool exhausted."""
	for p in particle_pool:
		if not p["active"]:
			p["active"] = true
			active_particle_count += 1
			return p
	# Pool exhausted — skip particle (no crash, no OOM)
	return null

func _unhandled_input(event: InputEvent) -> void:
	# [S17.2-004] Hidden hotkey (F3) to toggle the velocity overlay at runtime.
	# Dev-only: not bound in the input map and not discoverable in shipping UI.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			debug_velocity_overlay = not debug_velocity_overlay
			print("[S17.2-004] velocity debug overlay toggled: ", debug_velocity_overlay)
			return

	# S25.2: Click handler — routes left-clicks to floor or enemy dispatch.
	if sim == null or sim.match_over:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	# Bounds check: ignore clicks outside the arena rect.
	var arena_rect := Rect2(arena_offset, Vector2(ARENA_PX, ARENA_PX))
	if not arena_rect.has_point(mb.position):
		return
	var arena_local: Vector2 = mb.position - arena_offset

	# Hit-test enemies first; floor click otherwise.
	var hit_idx := _hit_test_enemy(arena_local)
	if hit_idx != -1:
		_handle_enemy_click(hit_idx)
	else:
		_handle_floor_click(arena_local)

## S25.2: Register the player brain so the click handler can set overrides.
func set_player_brain(brain: BrottBrain) -> void:
	_player_brain = brain

## S25.2: Hit-test enemies. Returns index in sim.brotts of clicked enemy, or -1.
## Iterates in reverse render order so last-drawn (visually topmost) wins on overlap.
func _hit_test_enemy(arena_local: Vector2) -> int:
	if sim == null:
		return -1
	for i in range(sim.brotts.size() - 1, -1, -1):
		var b: BrottState = sim.brotts[i]
		if not b.alive or b.team == 0:
			continue
		var dist: float = (b.position - arena_local).length()
		if dist <= BOT_RADIUS + 4.0:
			return i
	return -1

## S25.2: Floor click — set waypoint, clear target override (latest-wins).
func _handle_floor_click(arena_local: Vector2) -> void:
	_waypoint_pos = arena_local
	_waypoint_fade_t = 1.0
	_reticle_target_id = -1
	if _player_brain != null:
		_player_brain.set_move_override(arena_local)

## S25.2: Enemy click — set reticle, clear waypoint (latest-wins).
func _handle_enemy_click(target_idx: int) -> void:
	_reticle_target_id = target_idx
	_waypoint_pos = Vector2.INF
	_waypoint_fade_t = 0.0
	if _player_brain != null:
		_player_brain.set_target_override(target_idx)

## S25.2: Helper — find player brott (team == 0).
func _get_player_brott() -> BrottState:
	if sim == null:
		return null
	for b: BrottState in sim.brotts:
		if b.team == 0:
			return b
	return null

func _get_weapon_shake_class(source: BrottState) -> String:
	# Determine shake intensity based on weapon type
	# Normal: Minigun, Plasma Cutter
	# Heavy: Shotgun, Flak Cannon
	# Big: Railgun, Missile Pod
	if source == null:
		return "normal"
	for wt in source.weapon_types:
		match wt:
			WeaponData.WeaponType.RAILGUN, WeaponData.WeaponType.MISSILE_POD:
				return "big"
			WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.FLAK_CANNON:
				return "heavy"
	return "normal"

func _trigger_shake(intensity: float, duration_frames: int, decay: String) -> void:
	# Concurrent shakes take the max
	if intensity > shake_intensity:
		shake_intensity = intensity
		shake_duration = float(duration_frames)
		shake_timer = float(duration_frames)
		shake_decay = decay

func _spawn_sparks(hit_pos: Vector2, weapon_class: String) -> void:
	var count: int = 0
	var lifetime_min: float = 150.0
	var lifetime_max: float = 250.0
	var col1: Color = Color.WHITE
	var col2: Color = Color.YELLOW
	var size_min: float = 1.0
	var size_max: float = 2.0
	
	match weapon_class:
		"bullet":
			count = randi_range(3, 5)
			lifetime_min = 150.0; lifetime_max = 250.0
			col1 = Color.WHITE; col2 = Color.YELLOW
		"shotgun":
			count = randi_range(2, 3)
			lifetime_min = 100.0; lifetime_max = 200.0
			col1 = Color.ORANGE; col2 = Color.ORANGE
		"railgun":
			count = randi_range(8, 12)
			lifetime_min = 300.0; lifetime_max = 400.0
			col1 = Color.CYAN; col2 = Color.WHITE
			size_min = 2.0; size_max = 3.0
		"missile":
			count = randi_range(15, 20)
			lifetime_min = 400.0; lifetime_max = 600.0
			col1 = Color.ORANGE; col2 = Color.RED
			size_min = 2.0; size_max = 4.0
		"plasma":
			count = randi_range(4, 6)
			lifetime_min = 200.0; lifetime_max = 300.0
			col1 = Color(0.8, 0.2, 0.9); col2 = Color(1.0, 0.4, 1.0)
			size_min = 1.0; size_max = 3.0
		"arc":
			count = randi_range(3, 4)
			lifetime_min = 150.0; lifetime_max = 250.0
			col1 = Color(0.3, 0.5, 1.0); col2 = Color(0.3, 0.5, 1.0)
		_:
			count = randi_range(3, 5)
	
	for _i in range(count):
		var p: Dictionary = _claim_particle()
		if p == null:
			continue  # pool exhausted
		var angle := randf() * TAU
		var speed := randf_range(40.0, 80.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var lt := randf_range(lifetime_min, lifetime_max)
		var sz := randf_range(size_min, size_max)
		var col := col1.lerp(col2, randf())
		p["pos"] = hit_pos + arena_offset
		p["vel"] = vel
		p["lifetime"] = lt
		p["max_lifetime"] = lt
		p["color"] = col
		p["size"] = sz

func _get_spark_class_for_source(source: BrottState) -> String:
	if source == null:
		return "bullet"
	for wt in source.weapon_types:
		match wt:
			WeaponData.WeaponType.MINIGUN: return "bullet"
			WeaponData.WeaponType.RAILGUN: return "railgun"
			WeaponData.WeaponType.SHOTGUN: return "shotgun"
			WeaponData.WeaponType.MISSILE_POD: return "missile"
			WeaponData.WeaponType.PLASMA_CUTTER: return "plasma"
			WeaponData.WeaponType.ARC_EMITTER: return "arc"
			WeaponData.WeaponType.FLAK_CANNON: return "bullet"
	return "bullet"

func _on_damage(target: BrottState, amount: float, is_crit: bool, hit_pos: Vector2) -> void:
	# Screen shake based on weapon
	var source: BrottState = null
	for b in sim.brotts:
		if b != target and b.alive:
			source = b
			break
	
	var shake_class := _get_weapon_shake_class(source)
	match shake_class:
		"normal": _trigger_shake(randf_range(1.0, 2.0), 3, "linear")
		"heavy": _trigger_shake(randf_range(3.0, 4.0), 5, "linear")
		"big": _trigger_shake(randf_range(6.0, 8.0), 8, "ease_out")
	
	# Hit flash (clamp to max 1 per 3 frames)
	var target_id := target.get_instance_id()
	if not last_flash_frame.has(target_id) or frame_count - last_flash_frame[target_id] >= 3:
		target.flash_timer = 2.0  # 2 frames = ~33ms
		last_flash_frame[target_id] = frame_count
	
	# Sparks
	var spark_class := _get_spark_class_for_source(source)
	_spawn_sparks(hit_pos, spark_class)
	
	# Shotgun consolidation: accumulate pellet damage into one number
	var is_shotgun := false
	if source != null:
		for wt in source.weapon_types:
			if wt == WeaponData.WeaponType.SHOTGUN:
				is_shotgun = true
				break
	
	if is_shotgun:
		if not shotgun_accum.has(target_id):
			shotgun_accum[target_id] = {"total": 0.0, "pos": hit_pos, "timer": 6.0, "is_crit": false}
		shotgun_accum[target_id]["total"] += amount
		shotgun_accum[target_id]["pos"] = hit_pos
		if is_crit:
			shotgun_accum[target_id]["is_crit"] = true
		shotgun_accum[target_id]["timer"] = 6.0  # reset timer (100ms at ~60fps)
	else:
		_add_damage_text(hit_pos, amount, is_crit)

	# S12.4: Crit received — 2px visual recoil away from attacker
	if is_crit and source != null and target.alive:
		var recoil_dir := (target.position - source.position).normalized()
		target.recoil_offset = recoil_dir * 2.0

func _add_damage_text(hit_pos: Vector2, amount: float, is_crit: bool) -> void:
	var color: Color = Color.YELLOW if is_crit else Color.WHITE
	var text: String = str(int(amount))
	if is_crit:
		text += "!"
	var x_offset := randf_range(-4.0, 4.0)  # horizontal scatter to avoid overlap
	damage_texts.append({
		"pos": hit_pos + arena_offset + Vector2(x_offset, 0),
		"text": text,
		"color": color,
		"timer": 36.0,  # 600ms at 60fps
		"max_timer": 36.0,
		"velocity": Vector2(0, -50),  # 30px over 600ms
		"font_size": 10 if is_crit else 8,  # 8px normal, 10px crit (per spec)
		"is_crit": is_crit,
		"scale": 1.2 if is_crit else 1.0,  # crit scale-up pop
	})

func _on_death(brott: BrottState) -> void:
	# Death explosion sequence
	# Hit-stop: 100ms freeze
	death_freeze_timer = 6.0  # ~100ms at 60fps
	
	# Screen flash
	death_flash_timer = 2.0
	
	# Screen shake
	_trigger_shake(randf_range(10.0, 12.0), 12, "ease_out")
	
	# Camera zoom
	death_zoom_target = brott.position + arena_offset
	death_zoom_timer = 30.0  # 500ms total (200ms in, 300ms out)
	death_zoom = 1.0
	
	# Slow-mo
	death_slow_mo_timer = 18.0  # 0.3s at 60fps
	
	# Debris particles (pooled)
	for _i in range(randi_range(4, 6)):
		var angle := randf() * TAU
		var speed := randf_range(100.0, 150.0)
		var rot_speed := randf_range(-5.0, 5.0)
		death_debris.append({
			"pos": brott.position + arena_offset,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"rotation": randf() * TAU,
			"rot_speed": rot_speed,
			"lifetime": 48.0,  # 800ms
			"max_lifetime": 48.0,
			"size": 4.0,
			"color": [Color.ORANGE, Color.GRAY, Color.WHITE][randi() % 3],
		})
	
	# Big particle burst (pooled)
	for _i in range(randi_range(20, 30)):
		var p: Dictionary = _claim_particle()
		if p == null:
			continue  # pool exhausted
		var angle := randf() * TAU
		var speed := randf_range(80.0, 150.0)
		var col: Color = [Color.ORANGE, Color.GRAY, Color.WHITE][randi() % 3]
		p["pos"] = brott.position + arena_offset
		p["vel"] = Vector2(cos(angle), sin(angle)) * speed
		p["lifetime"] = randf_range(300.0, 600.0) / (1000.0 / 60.0)
		p["max_lifetime"] = randf_range(300.0, 600.0) / (1000.0 / 60.0)
		p["color"] = col
		p["size"] = randf_range(2.0, 4.0)
	
	# Set death_timer for explosion sprite animation
	brott.death_timer = 30.0

func get_time_scale() -> float:
	if death_slow_mo_timer > 0:
		return 0.5
	return 1.0

func tick_visuals() -> void:
	frame_count += 1

	# S25.2: Pulse accumulator + overlay state cleanup (waypoint fade on arrival,
	# reticle dead-target poll). Runs even during hit-stop freeze so reticle
	# clears promptly if a target dies during freeze.
	_pulse_accum += 1.0 / 60.0
	if _waypoint_pos != Vector2.INF:
		var player_b := _get_player_brott()
		if player_b != null:
			var dist: float = (player_b.position - _waypoint_pos).length()
			if dist < 8.0:
				_waypoint_fade_t -= (1.0 / 60.0) / 0.4  # fade over 0.4s
				if _waypoint_fade_t <= 0.0:
					_waypoint_pos = Vector2.INF
					_waypoint_fade_t = 0.0
					if _player_brain != null:
						_player_brain.clear_move_override()
	if _reticle_target_id != -1:
		var target_alive := false
		if _reticle_target_id >= 0 and _reticle_target_id < sim.brotts.size():
			var tgt: BrottState = sim.brotts[_reticle_target_id]
			if tgt.alive:
				target_alive = true
		if not target_alive:
			_reticle_target_id = -1
			if _player_brain != null:
				_player_brain.clear_target_override()

	# Hit-stop freeze
	if death_freeze_timer > 0:
		death_freeze_timer -= 1.0
		queue_redraw()
		return
	
	# Update damage texts
	var to_remove: Array = []
	for i in range(damage_texts.size()):
		damage_texts[i]["timer"] -= 1.0
		damage_texts[i]["pos"] += damage_texts[i]["velocity"] * (1.0 / 60.0)
		# Crit scale pop: 1.2 → 1.0 over first ~6 frames
		if damage_texts[i]["is_crit"] and damage_texts[i]["scale"] > 1.0:
			damage_texts[i]["scale"] = maxf(1.0, damage_texts[i]["scale"] - 0.033)
		if damage_texts[i]["timer"] <= 0:
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		damage_texts.remove_at(idx)
	
	# Update shotgun accumulators
	var shotgun_emit: Array = []
	for tid in shotgun_accum.keys():
		shotgun_accum[tid]["timer"] -= 1.0
		if shotgun_accum[tid]["timer"] <= 0:
			shotgun_emit.append(tid)
	for tid in shotgun_emit:
		var acc = shotgun_accum[tid]
		_add_damage_text(acc["pos"], acc["total"], acc["is_crit"])
		shotgun_accum.erase(tid)
	
	# Update particles (pooled)
	for p in particle_pool:
		if not p["active"]:
			continue
		p["pos"] += p["vel"] * (1.0 / 60.0)
		p["vel"].y += 30.0 * (1.0 / 60.0)  # light gravity
		p["lifetime"] -= 1.0
		if p["lifetime"] <= 0:
			p["active"] = false
			active_particle_count -= 1
	
	# Update debris
	var d_remove: Array = []
	for i in range(death_debris.size()):
		var d = death_debris[i]
		d["pos"] += d["vel"] * (1.0 / 60.0)
		d["vel"].y += 120.0 * (1.0 / 60.0)  # heavier gravity for debris
		d["rotation"] += d["rot_speed"] * (1.0 / 60.0)
		d["lifetime"] -= 1.0
		if d["lifetime"] <= 0:
			d_remove.append(i)
	d_remove.reverse()
	for idx in d_remove:
		death_debris.remove_at(idx)
	
	# Update shake
	if shake_timer > 0:
		shake_timer -= 1.0
		var t: float = shake_timer / shake_duration if shake_duration > 0 else 0.0
		var intensity: float = shake_intensity
		if shake_decay == "ease_out":
			intensity *= t * t
		else:
			intensity *= t
		shake_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		if shake_timer <= 0:
			shake_offset = Vector2.ZERO
	
	# Update death effects
	if death_flash_timer > 0:
		death_flash_timer -= 1.0
	if death_zoom_timer > 0:
		death_zoom_timer -= 1.0
		if death_zoom_timer > 18.0:  # first 200ms: zoom in
			death_zoom = lerpf(1.0, 1.1, 1.0 - (death_zoom_timer - 18.0) / 12.0)
		else:  # last 300ms: zoom out
			death_zoom = lerpf(1.1, 1.0, 1.0 - death_zoom_timer / 18.0)
	if death_slow_mo_timer > 0:
		death_slow_mo_timer -= 1.0
	
	# Update overtime banner
	if sim.overtime_active and not overtime_triggered:
		overtime_triggered = true
		overtime_flash_timer = 60.0  # 1 sec flash
		overtime_banner_alpha = 1.0
	if overtime_flash_timer > 0:
		overtime_flash_timer -= 1.0
	if overtime_triggered:
		overtime_banner_alpha = maxf(0.4, overtime_banner_alpha - 0.01)  # fade to persistent 0.4
	
	# Update sudden death banner
	if sim.sudden_death_active and not sudden_death_triggered:
		sudden_death_triggered = true
		sudden_death_flash_timer = 90.0  # 1.5 sec flash
	if sudden_death_flash_timer > 0:
		sudden_death_flash_timer -= 1.0

	# Update brott visual state
	for b: BrottState in sim.brotts:
		if b.flash_timer > 0:
			b.flash_timer -= 1.0
		if b.death_timer > 0:
			b.death_timer -= 1.0

	# S12.4: Charm pass visual tick
	_tick_charm_anims()

	queue_redraw()


## S12.4: Charm pass — tick all personality animations
func _tick_charm_anims() -> void:
	var delta := 1.0 / 60.0

	# Overtime glow ramp
	if sim.overtime_active:
		overtime_glow_intensity = minf(1.0, overtime_glow_intensity + delta * 0.5)

	# Fortress micro-shake decay
	if fortress_micro_shake_timer > 0:
		fortress_micro_shake_timer -= delta
		if fortress_micro_shake_timer <= 0:
			fortress_micro_shake = Vector2.ZERO

	for b: BrottState in sim.brotts:
		if not b.alive:
			continue

		# Idle timer always ticks
		b.idle_timer += delta

		# Victory/defeat anim
		CharmAnims.tick_victory_anim(b, delta)

		# Recoil decay (spring back over ~0.1s)
		if b.recoil_offset.length() > 0.01:
			b.recoil_offset = b.recoil_offset.lerp(Vector2.ZERO, delta * 15.0)
		else:
			b.recoil_offset = Vector2.ZERO

		# Movement quirks: detect transitions
		var bid := b.get_instance_id()
		var cur_vel := b.velocity
		var cur_speed := b.current_speed
		var prev_vel: Vector2 = prev_brott_velocities.get(bid, Vector2.ZERO)
		var prev_speed: float = prev_brott_speeds.get(bid, 0.0)
		var is_moving := cur_speed > 5.0
		var was_still := prev_speed <= 5.0

		# Scout: 360° spin on direction change
		if b.chassis_type == ChassisData.ChassisType.SCOUT:
			if b.spin_anim_timer > 0:
				b.spin_anim_timer -= delta
				var t := 1.0 - (b.spin_anim_timer / 0.25)
				b.charm_rotation = t * 360.0
				if b.spin_anim_timer <= 0:
					b.charm_rotation = 0.0
			elif is_moving and prev_vel.length() > 5.0:
				# cur_vel is Variant (sim is untyped in this scope, so b.velocity is Variant),
				# which propagates through angle_to() and abs(). Explicit annotation keeps the
				# warnings-as-errors parser happy — same pattern as the S16.1-002 test_sprint10 fix.
				var angle_diff: float = abs(cur_vel.angle_to(prev_vel))
				if angle_diff > 0.5:  # ~30° threshold
					if CharmAnims.should_scout_spin(charm_rng):
						b.spin_anim_timer = 0.25

		# Brawler: dust puff on standstill→move
		if b.chassis_type == ChassisData.ChassisType.BRAWLER:
			if is_moving and was_still:
				var puffs := CharmAnims.create_dust_puff(b.position)
				for puff in puffs:
					var p: Dictionary = _claim_particle()
					if p == null:
						continue  # pool exhausted
					puff["pos"] += arena_offset
					p.merge(puff)

		# Fortress: micro-shake on start/stop, gear particle on decel
		if b.chassis_type == ChassisData.ChassisType.FORTRESS:
			if (is_moving and was_still) or (not is_moving and not was_still and prev_speed > 5.0):
				# start or stop: micro-shake 0.5px, 0.1s
				fortress_micro_shake = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
				fortress_micro_shake_timer = 0.1
			if cur_speed < prev_speed - 5.0 and cur_speed > 5.0:
				# decelerating: gear-grinding particle (pooled)
				var gp := CharmAnims.create_gear_particle(b.position + arena_offset, cur_vel)
				var p: Dictionary = _claim_particle()
				if p != null:
					p.merge(gp)

		# Combat flavor: smoke trail below 25% HP (pooled)
		var hp_pct := b.hp / float(b.max_hp)
		if hp_pct < 0.25 and hp_pct > 0.0 and frame_count % 4 == 0:
			var sp := CharmAnims.create_smoke_particle(b.position + arena_offset)
			var p: Dictionary = _claim_particle()
			if p != null:
				p.merge(sp)

		# Combat flavor: module activation ring
		if b.module_ring_timer > 0:
			b.module_ring_timer -= delta

		# Detect module activations (active_timer just started)
		for mi in range(b.module_active_timers.size()):
			if b.module_active_timers[mi] > 0 and b.module_cooldowns[mi] == 0:
				# Module just activated — only trigger ring if not already showing
				if b.module_ring_timer <= 0:
					b.module_ring_timer = 0.4
					b.module_ring_color = CharmAnims.get_module_ring_color(b.module_types[mi])

		prev_brott_velocities[bid] = cur_vel
		prev_brott_speeds[bid] = cur_speed

	# Victory/defeat reactions on match end
	if sim.match_over and not victory_sparks_spawned:
		victory_sparks_spawned = true
		for b: BrottState in sim.brotts:
			if not b.alive:
				CharmAnims.start_victory_anim(b, "loss")
				# Sparks for loss
				for _i in range(5):
					var angle := randf() * TAU
					var speed := randf_range(20.0, 40.0)
					var p: Dictionary = _claim_particle()
					if p != null:
						p["pos"] = b.position + arena_offset
						p["vel"] = Vector2(cos(angle), sin(angle)) * speed
						p["lifetime"] = 20.0
						p["max_lifetime"] = 20.0
						p["color"] = Color(1.0, 0.8, 0.2, 0.8)
						p["size"] = 1.5
				continue
			if b.team == sim.winner_team:
				var hp_pct := b.hp / float(b.max_hp)
				if hp_pct >= 1.0:
					CharmAnims.start_victory_anim(b, "perfect")
				elif hp_pct < 0.20:
					CharmAnims.start_victory_anim(b, "close")
				else:
					CharmAnims.start_victory_anim(b, "win")
			else:
				CharmAnims.start_victory_anim(b, "loss")
				for _i in range(5):
					var angle := randf() * TAU
					var speed := randf_range(20.0, 40.0)
					var p: Dictionary = _claim_particle()
					if p != null:
						p["pos"] = b.position + arena_offset
						p["vel"] = Vector2(cos(angle), sin(angle)) * speed
						p["lifetime"] = 20.0
						p["max_lifetime"] = 20.0
						p["color"] = Color(1.0, 0.8, 0.2, 0.8)
						p["size"] = 1.5

func _draw() -> void:
	if sim == null:
		return
	
	# Apply screen shake offset
	var draw_offset: Vector2 = arena_offset + shake_offset
	
	# Floor
	draw_rect(Rect2(draw_offset, Vector2(ARENA_PX, ARENA_PX)), COLOR_FLOOR)
	
	# Grid
	for i in range(ARENA_TILES + 1):
		var x: float = draw_offset.x + i * TILE_SIZE
		var y: float = draw_offset.y + i * TILE_SIZE
		draw_line(Vector2(x, draw_offset.y), Vector2(x, draw_offset.y + ARENA_PX), COLOR_GRID, 1.0)
		draw_line(Vector2(draw_offset.x, y), Vector2(draw_offset.x + ARENA_PX, y), COLOR_GRID, 1.0)
	
	# Danger zone overlay (shrinking arena boundary)
	if sim.overtime_active:
		_draw_danger_zone(draw_offset)
	
	# Pillars
	for ppos: Vector2 in sim._get_pillar_positions():
		draw_circle(ppos + draw_offset, PILLAR_RADIUS, COLOR_PILLAR)
	
	# Projectiles
	for proj: Projectile in sim.projectiles:
		if not proj.alive:
			continue
		var pp: Vector2 = proj.pos + draw_offset
		var col: Color = COLOR_MISSILE if proj.splash_radius > 0 else COLOR_PROJECTILE
		var rad: float = 4.0 if proj.splash_radius > 0 else 2.5
		draw_circle(pp, rad, col)
	
	# Brotts
	for b: BrottState in sim.brotts:
		_draw_brott(b, draw_offset)

	# S25.2: Click overlay layer (waypoint diamond, reticle ring, player pulse).
	# Drawn after bots so it sits visually on top.
	_draw_click_overlay(draw_offset)

	# [S17.2-004] Dev-only velocity debug overlay (additive, OFF by default).
	if debug_velocity_overlay:
		_draw_debug_velocity_overlay(draw_offset)
	
	# Particles (sparks)
	for p in particle_pool:
		if not p["active"]:
			continue
		var alpha: float = clampf(p["lifetime"] / p["max_lifetime"], 0.0, 1.0)
		var col: Color = p["color"]
		col.a = alpha
		draw_circle(p["pos"] + shake_offset, p["size"], col)
	
	# Debris
	for d in death_debris:
		var alpha: float = clampf(d["lifetime"] / d["max_lifetime"], 0.0, 1.0)
		var col: Color = d["color"]
		col.a = alpha
		var sz: float = d["size"]
		var dp: Vector2 = d["pos"] + shake_offset
		draw_rect(Rect2(dp - Vector2(sz/2, sz/2), Vector2(sz, sz)), col)
	
	# Damage numbers
	for dt: Dictionary in damage_texts:
		var progress: float = 1.0 - dt["timer"] / dt["max_timer"]
		# Start fading at 400ms (66% progress), fully transparent at 600ms
		var alpha: float = 1.0
		if progress > 0.66:
			alpha = clampf(1.0 - (progress - 0.66) / 0.34, 0.0, 1.0)
		var col: Color = dt["color"]
		col.a = alpha
		# Dark outline effect via drawing slightly offset
		var outline_col := Color(0, 0, 0, alpha * 0.8)
		var fs: int = dt["font_size"]
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(ThemeDB.fallback_font, dt["pos"] + off, dt["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs, outline_col)
		draw_string(ThemeDB.fallback_font, dt["pos"], dt["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)
	
	# Death screen flash
	if death_flash_timer > 0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(1, 1, 1, 0.3))
	
	# Match result
	if sim.match_over:
		_draw_match_result(draw_offset)
	
	# Overtime / Sudden Death banner
	if sudden_death_triggered:
		_draw_sudden_death_banner(draw_offset)
	elif overtime_triggered:
		_draw_overtime_banner(draw_offset)
	
	# Sudden death red flash
	if sudden_death_flash_timer > 0:
		var flash_alpha := clampf(sudden_death_flash_timer / 90.0 * 0.4, 0.0, 0.4)
		draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color(1, 0, 0, flash_alpha))

# ─────────────────────────────────────────────────────────────
# [S17.2-004] Dev-only velocity debug overlay helpers.
# ─────────────────────────────────────────────────────────────
func _draw_debug_velocity_overlay(draw_offset: Vector2) -> void:
	if sim == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0

	# Live bot IDs (for stale-entry cleanup).
	var live_ids: Dictionary = {}

	for b: BrottState in sim.brotts:
		if not b.alive:
			continue
		var bid := b.get_instance_id()
		live_ids[bid] = true

		# Re-sample computed velocity at a fixed interval.
		# Between samples, we keep drawing the last-computed vector so the
		# arrow doesn't flicker between render frames (bots only move on
		# combat ticks @ 10Hz; render runs faster, so naive per-frame delta
		# would read zero most frames).
		var prev_t: float = _debug_prev_sample_time.get(bid, -1.0)
		if prev_t < 0.0:
			_debug_prev_sample_time[bid] = now
			_debug_prev_position[bid] = b.position
			_debug_computed_velocity[bid] = Vector2.ZERO
		else:
			var dt: float = now - prev_t
			if dt >= _DEBUG_SAMPLE_INTERVAL:
				var prev_pos: Vector2 = _debug_prev_position.get(bid, b.position)
				if dt > 0.0:
					_debug_computed_velocity[bid] = (b.position - prev_pos) / dt
				_debug_prev_position[bid] = b.position
				_debug_prev_sample_time[bid] = now

		var origin: Vector2 = b.position + draw_offset
		var computed_v: Vector2 = _debug_computed_velocity.get(bid, Vector2.ZERO)
		if computed_v.length() > 1.0:
			_draw_debug_arrow(origin, computed_v * _DEBUG_VELOCITY_SCALE, _DEBUG_COLOR_COMPUTED)

		# b.velocity is always Vector2.ZERO on main today (combat_sim.gd never
		# writes it). After S17.2-003 lands, this branch activates automatically.
		var stored_v: Vector2 = b.velocity
		if stored_v.length() > 1.0:
			_draw_debug_arrow(origin, stored_v * _DEBUG_VELOCITY_SCALE, _DEBUG_COLOR_VELOCITY)

	# Drop stale entries so dicts don't grow across matches.
	for bid_key in _debug_prev_position.keys():
		if not live_ids.has(bid_key):
			_debug_prev_position.erase(bid_key)
			_debug_prev_sample_time.erase(bid_key)
			_debug_computed_velocity.erase(bid_key)

	# Legend — small, top-left of arena.
	var legend_pos: Vector2 = draw_offset + Vector2(6, 14)
	var font := ThemeDB.fallback_font
	draw_string(font, legend_pos, "[S17.2-004 DEBUG]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.8))
	draw_string(font, legend_pos + Vector2(0, 12), "cyan=computed_velocity  magenta=b.velocity", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))

func _draw_debug_arrow(origin: Vector2, vec: Vector2, col: Color) -> void:
	var tip: Vector2 = origin + vec
	draw_line(origin, tip, col, 1.5)
	# Arrowhead: two short lines at 25° off the vector, 4px long.
	var len: float = vec.length()
	if len < 2.0:
		return
	var dir: Vector2 = vec / len
	var head_len: float = 4.0
	var head_angle: float = deg_to_rad(25.0)
	var left_dir: Vector2 = dir.rotated(PI - head_angle)
	var right_dir: Vector2 = dir.rotated(PI + head_angle)
	draw_line(tip, tip + left_dir * head_len, col, 1.5)
	draw_line(tip, tip + right_dir * head_len, col, 1.5)

func _draw_danger_zone(draw_offset: Vector2) -> void:
	var boundary: float = sim.get_arena_boundary_tiles()
	var center_px: float = float(ARENA_TILES) / 2.0 * TILE_SIZE
	var boundary_px: float = boundary * TILE_SIZE
	
	# Safe zone rect (centered)
	var safe_left: float = draw_offset.x + center_px - boundary_px
	var safe_top: float = draw_offset.y + center_px - boundary_px
	var safe_size: float = boundary_px * 2.0
	
	# Draw danger overlays on four sides
	# Top strip
	if safe_top > draw_offset.y:
		draw_rect(Rect2(Vector2(draw_offset.x, draw_offset.y), Vector2(ARENA_PX, safe_top - draw_offset.y)), COLOR_DANGER_ZONE)
	# Bottom strip
	var safe_bottom: float = safe_top + safe_size
	if safe_bottom < draw_offset.y + ARENA_PX:
		draw_rect(Rect2(Vector2(draw_offset.x, safe_bottom), Vector2(ARENA_PX, draw_offset.y + ARENA_PX - safe_bottom)), COLOR_DANGER_ZONE)
	# Left strip (between top and bottom strips)
	if safe_left > draw_offset.x:
		draw_rect(Rect2(Vector2(draw_offset.x, safe_top), Vector2(safe_left - draw_offset.x, safe_size)), COLOR_DANGER_ZONE)
	# Right strip
	var safe_right: float = safe_left + safe_size
	if safe_right < draw_offset.x + ARENA_PX:
		draw_rect(Rect2(Vector2(safe_right, safe_top), Vector2(draw_offset.x + ARENA_PX - safe_right, safe_size)), COLOR_DANGER_ZONE)
	
	# Draw pulsing border around safe zone
	var pulse: float = sin(float(frame_count) * 0.1) * 0.2 + 0.8
	var border_col := COLOR_DANGER_BORDER
	border_col.a *= pulse
	var safe_rect := Rect2(Vector2(safe_left, safe_top), Vector2(safe_size, safe_size))
	draw_rect(safe_rect, border_col, false, 2.0)

func _draw_brott(b: BrottState, draw_offset: Vector2) -> void:
	var pos: Vector2 = b.position + draw_offset

	# S12.4: Apply charm visual offsets (render-layer only)
	var idle_val := CharmAnims.get_idle_offset(b.chassis_type, b.idle_timer)
	if CharmAnims.get_idle_is_horizontal(b.chassis_type):
		pos.x += idle_val  # Brawler: side-to-side
	else:
		pos.y += idle_val  # Scout/Fortress: up/down
	pos.y += b.charm_y_offset  # victory/defeat anim
	pos += b.recoil_offset  # crit recoil
	# Fortress micro-shake
	if b.chassis_type == ChassisData.ChassisType.FORTRESS and fortress_micro_shake_timer > 0:
		pos += fortress_micro_shake
	
	if not b.alive:
		if b.death_timer > 0:
			# 3-frame explosion animation, 48x48 (2x brott size)
			var t: float = clampf(b.death_timer / 30.0, 0.0, 1.0)
			var exp_radius: float = 24.0 * (2.0 - t)  # 48px max diameter
			var col: Color = COLOR_EXPLOSION
			col.a = t
			draw_circle(pos, exp_radius, col)
			# Inner bright core
			var core_col := Color(1.0, 0.9, 0.4, t * 0.8)
			draw_circle(pos, exp_radius * 0.4, core_col)
		return
	
	var base_col: Color = COLOR_PLAYER if b.team == 0 else COLOR_ENEMY
	
	# S12.3: Armor slightly modifies bot outline color in-game
	match b.armor_type:
		ArmorData.ArmorType.PLATING:
			base_col = base_col.lerp(Color(0.6, 0.6, 0.7), 0.15)
		ArmorData.ArmorType.REACTIVE_MESH:
			base_col = base_col.lerp(Color(0.3, 1.0, 0.5), 0.12)
		ArmorData.ArmorType.ABLATIVE_SHELL:
			base_col = base_col.lerp(Color(0.6, 0.4, 0.25), 0.18)
	
	# Hit flash: 80% white blend for 2 frames
	if b.flash_timer > 0:
		base_col = base_col.lerp(Color.WHITE, 0.8)
	
	match b.chassis_type:
		ChassisData.ChassisType.SCOUT:
			var dir: Vector2 = Vector2(0, -1)
			if b.target and b.target.alive:
				dir = (b.target.position - b.position).normalized()
			var pts := PackedVector2Array([
				pos + dir * BOT_RADIUS,
				pos + dir.rotated(2.4) * BOT_RADIUS,
				pos + dir.rotated(-2.4) * BOT_RADIUS,
			])
			draw_colored_polygon(pts, base_col)
		ChassisData.ChassisType.BRAWLER:
			var pts := PackedVector2Array()
			for i in 5:
				var angle: float = i * TAU / 5.0 - PI / 2.0
				pts.append(pos + Vector2(cos(angle), sin(angle)) * BOT_RADIUS)
			draw_colored_polygon(pts, base_col)
		ChassisData.ChassisType.FORTRESS:
			draw_rect(Rect2(pos - Vector2(BOT_RADIUS, BOT_RADIUS), Vector2(BOT_RADIUS * 2, BOT_RADIUS * 2)), base_col)
	
	# S12.3: Draw weapon silhouettes on in-game sprite (24×24 scale)
	_draw_ingame_weapons(b, pos)

	# S25.2: Numbered enemy label (1, 2, 3, …) above bot for multi-target clarity.
	# Index is 1-based across living enemies in sim.brotts order.
	if b.team != 0:
		var enemy_index := 0
		for other: BrottState in sim.brotts:
			if other == b:
				break
			if other.alive and other.team != 0:
				enemy_index += 1
		var label_text := str(enemy_index + 1)
		var label_pos: Vector2 = pos + Vector2(-3, -BOT_RADIUS - 14)
		# Dark outline for readability over arena bg + bot color.
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(ThemeDB.fallback_font, label_pos + off, label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.9))
		draw_string(ThemeDB.fallback_font, label_pos, label_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	
	# Shield
	if b.shield_active:
		draw_arc(pos, BOT_RADIUS + 4, 0, TAU, 32, COLOR_SHIELD, 2.5)

	# S12.4: Module activation ring
	if b.module_ring_timer > 0:
		var ring_alpha := clampf(b.module_ring_timer / 0.4, 0.0, 1.0)
		var ring_radius := BOT_RADIUS + 6.0 + (1.0 - ring_alpha) * 12.0
		var ring_col := b.module_ring_color
		ring_col.a = ring_alpha * 0.7
		draw_arc(pos, ring_radius, 0, TAU, 32, ring_col, 2.0)

	# S12.4: Overtime glow (all bots' lights glow brighter)
	if overtime_glow_intensity > 0 and b.alive:
		var glow_alpha := overtime_glow_intensity * (0.15 + sin(b.idle_timer * 3.0) * 0.05)
		var glow_col := Color(1.0, 0.9, 0.6, glow_alpha)
		draw_circle(pos, BOT_RADIUS + 2, glow_col)
	
	# Health bar
	var bar_y: float = pos.y - BOT_RADIUS - 12
	var bar_x: float = pos.x - HEALTH_BAR_WIDTH / 2.0
	var hp_pct: float = clampf(b.hp / float(b.max_hp), 0.0, 1.0)
	var hp_col: Color = COLOR_HP_HIGH
	if hp_pct < 0.3:
		hp_col = COLOR_HP_LOW
	elif hp_pct < 0.6:
		hp_col = COLOR_HP_MID
	draw_rect(Rect2(Vector2(bar_x, bar_y), Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), COLOR_BAR_BG)
	draw_rect(Rect2(Vector2(bar_x, bar_y), Vector2(HEALTH_BAR_WIDTH * hp_pct, HEALTH_BAR_HEIGHT)), hp_col)
	
	# Energy bar
	var en_y: float = bar_y + HEALTH_BAR_HEIGHT + 1
	var en_pct: float = clampf(b.energy / 100.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2(bar_x, en_y), Vector2(HEALTH_BAR_WIDTH, ENERGY_BAR_HEIGHT)), COLOR_BAR_BG)
	draw_rect(Rect2(Vector2(bar_x, en_y), Vector2(HEALTH_BAR_WIDTH * en_pct, ENERGY_BAR_HEIGHT)), COLOR_ENERGY)

func _draw_match_result(draw_offset: Vector2) -> void:
	draw_rect(Rect2(draw_offset, Vector2(ARENA_PX, ARENA_PX)), Color(0, 0, 0, 0.6))
	var text: String = "DRAW"
	var col: Color = Color.YELLOW
	if sim.winner_team == 0:
		text = "VICTORY"
		col = Color.GREEN
	elif sim.winner_team == 1:
		text = "DEFEAT"
		col = Color.RED
	var center: Vector2 = draw_offset + Vector2(ARENA_PX / 2.0, ARENA_PX / 2.0)
	draw_string(ThemeDB.fallback_font, center - Vector2(60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 32, col)

func _draw_overtime_banner(draw_offset: Vector2) -> void:
	var center: Vector2 = draw_offset + Vector2(ARENA_PX / 2.0, 40.0)
	var alpha: float = overtime_banner_alpha
	# Pulsing effect when flash is active
	if overtime_flash_timer > 0:
		alpha = clampf(sin(overtime_flash_timer * 0.3) * 0.5 + 1.0, 0.5, 1.0)
	var col := Color(1.0, 0.3, 0.1, alpha)
	# Outline
	var outline_col := Color(0, 0, 0, alpha * 0.8)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(ThemeDB.fallback_font, center - Vector2(60, 0) + off, "OVERTIME!", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, outline_col)
	draw_string(ThemeDB.fallback_font, center - Vector2(60, 0), "OVERTIME!", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, col)

func _draw_sudden_death_banner(draw_offset: Vector2) -> void:
	var center: Vector2 = draw_offset + Vector2(ARENA_PX / 2.0, 40.0)
	# Pulsing red text
	var pulse: float = sin(float(frame_count) * 0.15) * 0.3 + 0.7
	var col := Color(1.0, 0.1, 0.1, pulse)
	var outline_col := Color(0, 0, 0, pulse * 0.9)
	for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(ThemeDB.fallback_font, center - Vector2(80, 0) + off, "SUDDEN DEATH!", HORIZONTAL_ALIGNMENT_CENTER, 160, 24, outline_col)
	draw_string(ThemeDB.fallback_font, center - Vector2(80, 0), "SUDDEN DEATH!", HORIZONTAL_ALIGNMENT_CENTER, 160, 24, col)

## S12.3: Draw simplified weapon silhouettes on in-game 24×24 bot sprites
func _draw_ingame_weapons(b: BrottState, pos: Vector2) -> void:
	var weapon_col := Color(0.75, 0.75, 0.75, 0.85)
	for i in range(b.weapon_types.size()):
		if i >= 2:
			break
		var wt: WeaponData.WeaponType = b.weapon_types[i]
		var side := 1.0 if i == 0 else -1.0  # right / left
		var mount := pos + Vector2(BOT_RADIUS * side, 0)
		
		match wt:
			WeaponData.WeaponType.MINIGUN:
				# Small barrel cluster
				for j in range(2):
					draw_rect(Rect2(mount + Vector2(0, (j - 0.5) * 3 - 1), Vector2(5.0 * side, 2)), weapon_col)
			WeaponData.WeaponType.RAILGUN:
				# Long thin barrel
				draw_rect(Rect2(mount + Vector2(0, -1), Vector2(8.0 * side, 2)), weapon_col)
			WeaponData.WeaponType.SHOTGUN:
				# Wide short barrel
				draw_rect(Rect2(mount + Vector2(0, -2), Vector2(4.0 * side, 4)), weapon_col)
			WeaponData.WeaponType.MISSILE_POD:
				# Small pod cluster (2 tubes)
				draw_rect(Rect2(mount + Vector2(0, -2), Vector2(3.0 * side, 2)), weapon_col)
				draw_rect(Rect2(mount + Vector2(0, 1), Vector2(3.0 * side, 2)), weapon_col)
			WeaponData.WeaponType.PLASMA_CUTTER:
				# Small blade
				var pts := PackedVector2Array([
					mount,
					mount + Vector2(6.0 * side, -1.5),
					mount + Vector2(6.0 * side, 1.5),
				])
				draw_colored_polygon(pts, Color(0.7, 0.3, 0.8, 0.85))
			WeaponData.WeaponType.ARC_EMITTER:
				# Small coil dot
				draw_circle(mount + Vector2(3.0 * side, 0), 2.5, Color(0.3, 0.5, 1.0, 0.85))
			WeaponData.WeaponType.FLAK_CANNON:
				# Wide short barrel
				draw_rect(Rect2(mount + Vector2(0, -2.5), Vector2(3.0 * side, 5)), weapon_col)

# ─────────────────────────────────────────────────────────────
# S25.2: Click overlay rendering — waypoint diamond, reticle ring, player pulse.
# ─────────────────────────────────────────────────────────────
func _draw_click_overlay(draw_offset: Vector2) -> void:
	# Waypoint diamond (yellow #FFD700, fades on player arrival).
	if _waypoint_pos != Vector2.INF and _waypoint_fade_t > 0.0:
		var wp: Vector2 = _waypoint_pos + draw_offset
		var d := 8.0  # half-diagonal → 16px diamond
		var diamond := PackedVector2Array([
			wp + Vector2(0, -d),
			wp + Vector2(d, 0),
			wp + Vector2(0, d),
			wp + Vector2(-d, 0),
		])
		var wpc := Color(1.0, 0.843, 0.0, _waypoint_fade_t)
		draw_colored_polygon(diamond, wpc)
		var outline := PackedVector2Array(diamond)
		outline.append(diamond[0])
		draw_polyline(outline, Color(1, 1, 1, _waypoint_fade_t * 0.6), 1.5)

	# Reticle ring on target enemy (orange #FF8C00).
	if _reticle_target_id != -1 and _reticle_target_id >= 0 and _reticle_target_id < sim.brotts.size():
		var tgt: BrottState = sim.brotts[_reticle_target_id]
		if tgt.alive:
			var rp: Vector2 = tgt.position + draw_offset
			draw_arc(rp, BOT_RADIUS + 6.0, 0, TAU, 32, Color(1.0, 0.549, 0.0, 0.9), 2.0)

	# Player outline pulse — yellow if move-override, orange if target-override.
	var player := _get_player_brott()
	if player != null and player.alive and _player_brain != null:
		var has_move: bool = _player_brain._override_move_pos != Vector2.INF
		var has_target: bool = _player_brain._override_target_id != -1
		if has_move or has_target:
			var pulse_alpha: float = lerp(0.4, 1.0, 0.5 + 0.5 * sin(_pulse_accum * TAU / 0.6))
			var pulse_color: Color
			if has_move:
				pulse_color = Color(1.0, 0.843, 0.0, pulse_alpha)
			else:
				pulse_color = Color(1.0, 0.549, 0.0, pulse_alpha)
			var pp: Vector2 = player.position + draw_offset
			draw_arc(pp, BOT_RADIUS + 3.0, 0, TAU, 32, pulse_color, 2.0)
