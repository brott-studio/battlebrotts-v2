## Visual arena renderer — draws the combat using _draw()
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

func setup(p_sim: CombatSim, p_offset: Vector2) -> void:
	sim = p_sim
	arena_offset = p_offset
	sim.on_damage.connect(_on_damage)

func _on_damage(target: BrottState, amount: float, is_crit: bool, hit_pos: Vector2) -> void:
	var color: Color = Color.YELLOW if is_crit else Color.WHITE
	var text: String = str(int(amount))
	if is_crit:
		text += "!"
	damage_texts.append({
		"pos": hit_pos + arena_offset,
		"text": text,
		"color": color,
		"timer": 40.0,
		"velocity": Vector2(0, -30),
		"font_size": 16 if is_crit else 12,
	})

func tick_visuals() -> void:
	var to_remove: Array = []
	for i in range(damage_texts.size()):
		damage_texts[i]["timer"] -= 1.0
		damage_texts[i]["pos"] += damage_texts[i]["velocity"] * 0.05
		if damage_texts[i]["timer"] <= 0:
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		damage_texts.remove_at(idx)
	
	for b: BrottState in sim.brotts:
		if b.flash_timer > 0:
			b.flash_timer -= 1.0
		if b.death_timer > 0:
			b.death_timer -= 1.0
	
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	
	# Floor
	draw_rect(Rect2(arena_offset, Vector2(ARENA_PX, ARENA_PX)), COLOR_FLOOR)
	
	# Grid
	for i in range(ARENA_TILES + 1):
		var x: float = arena_offset.x + i * TILE_SIZE
		var y: float = arena_offset.y + i * TILE_SIZE
		draw_line(Vector2(x, arena_offset.y), Vector2(x, arena_offset.y + ARENA_PX), COLOR_GRID, 1.0)
		draw_line(Vector2(arena_offset.x, y), Vector2(arena_offset.x + ARENA_PX, y), COLOR_GRID, 1.0)
	
	# Pillars
	for ppos: Vector2 in sim._get_pillar_positions():
		draw_circle(ppos + arena_offset, PILLAR_RADIUS, COLOR_PILLAR)
	
	# Projectiles
	for proj: Projectile in sim.projectiles:
		if not proj.alive:
			continue
		var pp: Vector2 = proj.pos + arena_offset
		var col: Color = COLOR_MISSILE if proj.splash_radius > 0 else COLOR_PROJECTILE
		var rad: float = 4.0 if proj.splash_radius > 0 else 2.5
		draw_circle(pp, rad, col)
	
	# Brotts
	for b: BrottState in sim.brotts:
		_draw_brott(b)
	
	# Damage numbers
	for dt: Dictionary in damage_texts:
		var alpha: float = clampf(float(dt["timer"]) / 20.0, 0.0, 1.0)
		var col: Color = dt["color"]
		col.a = alpha
		draw_string(ThemeDB.fallback_font, dt["pos"], dt["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, dt["font_size"], col)
	
	# Match result
	if sim.match_over:
		_draw_match_result()

func _draw_brott(b: BrottState) -> void:
	var pos: Vector2 = b.position + arena_offset
	
	if not b.alive:
		if b.death_timer > 0:
			var t: float = b.death_timer / 20.0
			var exp_radius: float = BOT_RADIUS * (2.0 - t)
			var col: Color = COLOR_EXPLOSION
			col.a = t
			draw_circle(pos, exp_radius, col)
		return
	
	var base_col: Color = COLOR_PLAYER if b.team == 0 else COLOR_ENEMY
	if b.flash_timer > 0:
		base_col = Color.WHITE
	
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

func _draw_match_result() -> void:
	draw_rect(Rect2(arena_offset, Vector2(ARENA_PX, ARENA_PX)), Color(0, 0, 0, 0.6))
	var text: String = "DRAW"
	var col: Color = Color.YELLOW
	if sim.winner_team == 0:
		text = "VICTORY"
		col = Color.GREEN
	elif sim.winner_team == 1:
		text = "DEFEAT"
		col = Color.RED
	var center: Vector2 = arena_offset + Vector2(ARENA_PX / 2.0, ARENA_PX / 2.0)
	draw_string(ThemeDB.fallback_font, center - Vector2(60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 32, col)
