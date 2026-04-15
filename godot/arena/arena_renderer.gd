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

var sim: CombatSim = null
var arena_offset: Vector2 = Vector2.ZERO
var damage_texts: Array = []
var particles: Array = []  # impact sparks

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

# Hit flash tracking (max 1 flash per 3 frames)
var last_flash_frame: Dictionary = {}  # brott -> last flash frame
var frame_count: int = 0

# Shotgun damage accumulator
var shotgun_accum: Dictionary = {}  # target_id -> {total, pos, timer, is_crit}

func setup(p_sim: CombatSim, p_offset: Vector2) -> void:
	sim = p_sim
	arena_offset = p_offset
	sim.on_damage.connect(_on_damage)
	sim.on_death.connect(_on_death)

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
		var angle := randf() * TAU
		var speed := randf_range(40.0, 80.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var lt := randf_range(lifetime_min, lifetime_max)
		var sz := randf_range(size_min, size_max)
		var col := col1.lerp(col2, randf())
		particles.append({
			"pos": hit_pos + arena_offset,
			"vel": vel,
			"lifetime": lt,
			"max_lifetime": lt,
			"color": col,
			"size": sz,
		})

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
	
	# Debris particles
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
	
	# Big particle burst
	for _i in range(randi_range(20, 30)):
		var angle := randf() * TAU
		var speed := randf_range(80.0, 150.0)
		var col := [Color.ORANGE, Color.GRAY, Color.WHITE][randi() % 3]
		particles.append({
			"pos": brott.position + arena_offset,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"lifetime": randf_range(300.0, 600.0) / (1000.0 / 60.0),
			"max_lifetime": randf_range(300.0, 600.0) / (1000.0 / 60.0),
			"color": col,
			"size": randf_range(2.0, 4.0),
		})
	
	# Set death_timer for explosion sprite animation
	brott.death_timer = 30.0

func get_time_scale() -> float:
	if death_slow_mo_timer > 0:
		return 0.5
	return 1.0

func tick_visuals() -> void:
	frame_count += 1
	
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
	
	# Update particles
	var p_remove: Array = []
	for i in range(particles.size()):
		var p = particles[i]
		p["pos"] += p["vel"] * (1.0 / 60.0)
		p["vel"].y += 30.0 * (1.0 / 60.0)  # light gravity
		p["lifetime"] -= 1.0
		if p["lifetime"] <= 0:
			p_remove.append(i)
	p_remove.reverse()
	for idx in p_remove:
		particles.remove_at(idx)
	
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

	# Update brott visual state
	for b: BrottState in sim.brotts:
		if b.flash_timer > 0:
			b.flash_timer -= 1.0
		if b.death_timer > 0:
			b.death_timer -= 1.0
	
	queue_redraw()

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
	
	# Particles (sparks)
	for p in particles:
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
	
	# Overtime banner
	if overtime_triggered:
		_draw_overtime_banner(draw_offset)

func _draw_brott(b: BrottState, draw_offset: Vector2) -> void:
	var pos: Vector2 = b.position + draw_offset
	
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
	
	# Shield
	if b.shield_active:
		draw_arc(pos, BOT_RADIUS + 4, 0, TAU, 32, COLOR_SHIELD, 2.5)
	
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
