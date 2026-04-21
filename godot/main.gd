## Main scene — sets up combat and drives the simulation visually
extends Node2D

const ARENA_OFFSET := Vector2(384, 60)  # Center arena in 1280x720
const TICKS_PER_SEC := 10

# [S17.1-003] Energy-bar legend. COLOR_ENERGY mirrors arena_renderer.gd's
# own constant (0.2, 0.7, 1.0) — duplicated here rather than imported so we
# don't cross the sacred arena/** boundary. If arena_renderer.gd's tone ever
# changes, update this value to match.
const COLOR_ENERGY := Color(0.2, 0.7, 1.0)
const ENERGY_LEGEND_TEXT := "⚡ Energy (blue bar) — powers weapons; regenerates over time."

@onready var arena_renderer: Node2D = $ArenaRenderer
@onready var speed_label: Label = $UI/SpeedLabel
@onready var player_info: Label = $UI/PlayerInfo
@onready var enemy_info: Label = $UI/EnemyInfo
@onready var time_label: Label = $UI/TimeLabel
@onready var _ui_layer: CanvasLayer = $UI

var energy_legend: Label

# [S17.1-004] First-encounter HUD overlay (one-shot, anchored above the
# S17.1-003 energy legend). Nullable — only populated on first combat
# entry when FirstRunState has not yet seen `energy_explainer`.
var energy_explainer_overlay: Control = null
var _energy_explainer_ticks: int = 0
const ENERGY_EXPLAINER_KEY := "energy_explainer"
const ENERGY_EXPLAINER_TEXT := "⚡ The blue bar is your Energy — it powers your weapons and regenerates over time."
const ENERGY_EXPLAINER_TICK_BUDGET := 60  # ~1 second @ 60 fps auto-dismiss

var sim: CombatSim
var player_brott: BrottState
var enemy_brott: BrottState

var speed_multiplier: float = 1.0
var tick_accumulator: float = 0.0

func _ready() -> void:
	_setup_energy_legend()
	_maybe_spawn_energy_explainer()
	_setup_match()

# [S17.1-003] Add a persistent HUD legend so the blue energy bar has a
# visible-by-default meaning. Static label, set once, never updated.
func _setup_energy_legend() -> void:
	if _ui_layer == null:
		return
	energy_legend = Label.new()
	energy_legend.name = "EnergyLegend"
	energy_legend.text = ENERGY_LEGEND_TEXT
	energy_legend.add_theme_font_size_override("font_size", 13)
	energy_legend.add_theme_color_override("font_color", COLOR_ENERGY)
	# Positioned under PlayerInfo (which ends at y=40); above the arena band.
	energy_legend.offset_left = 20.0
	energy_legend.offset_top = 42.0
	energy_legend.offset_right = 760.0
	energy_legend.offset_bottom = 62.0
	_ui_layer.add_child(energy_legend)

# [S17.1-004] Spawn the one-shot first-encounter overlay if the player
# has not yet acknowledged it. Reuses the ⚡ glyph + copy from S17.1-003's
# legend for visual continuity. Parented to _ui_layer so it follows the
# same scaling as the legend. Does NOT modify the legend node.
func _maybe_spawn_energy_explainer() -> void:
	if _ui_layer == null:
		return
	# Autoload guard — during headless test instantiation the autoload may
	# not be wired; in that case, skip the overlay entirely (safe default
	# is "no first-run UI").
	if not Engine.has_singleton("FirstRunState") and get_node_or_null("/root/FirstRunState") == null:
		return
	var frs: Node = get_node_or_null("/root/FirstRunState")
	if frs == null:
		return
	if frs.call("has_seen", ENERGY_EXPLAINER_KEY):
		return
	_spawn_energy_explainer()

func _spawn_energy_explainer() -> void:
	var panel := Panel.new()
	panel.name = "EnergyExplainerOverlay"
	panel.offset_left = 16.0
	panel.offset_top = 72.0
	panel.offset_right = 16.0 + 420.0
	panel.offset_bottom = 72.0 + 96.0
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var body := Label.new()
	body.name = "Body"
	body.text = ENERGY_EXPLAINER_TEXT
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.offset_left = 12.0
	body.offset_top = 10.0
	body.offset_right = 408.0
	body.offset_bottom = 58.0
	panel.add_child(body)

	# ▲ glyph pointing up at the S17.1-003 legend's ⚡ glyph. Offset taken
	# from design §4.2; intentionally absolute to avoid a frame-order
	# dependency on the legend rect.
	var arrow := Label.new()
	arrow.name = "Arrow"
	arrow.text = "▲"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", COLOR_ENERGY)
	arrow.offset_left = 90.0
	arrow.offset_top = -10.0
	arrow.offset_right = 110.0
	arrow.offset_bottom = 6.0
	panel.add_child(arrow)

	var btn := Button.new()
	btn.name = "GotItButton"
	btn.text = "Got it!"
	btn.offset_left = 420.0 - 96.0 - 8.0
	btn.offset_top = 96.0 - 28.0 - 8.0
	btn.offset_right = 420.0 - 8.0
	btn.offset_bottom = 96.0 - 8.0
	btn.pressed.connect(_on_energy_explainer_dismissed)
	panel.add_child(btn)

	_ui_layer.add_child(panel)
	energy_explainer_overlay = panel
	_energy_explainer_ticks = 0

func _dismiss_energy_explainer() -> void:
	if energy_explainer_overlay == null:
		return
	var frs: Node = get_node_or_null("/root/FirstRunState")
	if frs != null:
		frs.call("mark_seen", ENERGY_EXPLAINER_KEY)
	energy_explainer_overlay.queue_free()
	energy_explainer_overlay = null

func _on_energy_explainer_dismissed() -> void:
	_dismiss_energy_explainer()

func _setup_match() -> void:
	# Create simulation
	sim = CombatSim.new(42)  # deterministic seed
	
	# Player: Brawler with Shotgun + Minigun, Plating, Repair Nanites
	player_brott = BrottState.new()
	player_brott.team = 0
	player_brott.bot_name = "Player Bot"
	player_brott.chassis_type = ChassisData.ChassisType.BRAWLER
	player_brott.weapon_types = [WeaponData.WeaponType.SHOTGUN, WeaponData.WeaponType.MINIGUN]
	player_brott.armor_type = ArmorData.ArmorType.PLATING
	player_brott.module_types = [ModuleData.ModuleType.REPAIR_NANITES, ModuleData.ModuleType.OVERCLOCK]
	player_brott.stance = 0  # Aggressive
	player_brott.position = Vector2(4 * 32.0, 8 * 32.0)
	player_brott.setup()
	
	# Enemy: Scout with Railgun + Plasma Cutter, Reactive Mesh, Afterburner + Shield Projector + Sensor Array
	enemy_brott = BrottState.new()
	enemy_brott.team = 1
	enemy_brott.bot_name = "Enemy Bot"
	enemy_brott.chassis_type = ChassisData.ChassisType.SCOUT
	enemy_brott.weapon_types = [WeaponData.WeaponType.RAILGUN, WeaponData.WeaponType.PLASMA_CUTTER]
	enemy_brott.armor_type = ArmorData.ArmorType.REACTIVE_MESH
	enemy_brott.module_types = [ModuleData.ModuleType.AFTERBURNER, ModuleData.ModuleType.SHIELD_PROJECTOR, ModuleData.ModuleType.SENSOR_ARRAY]
	enemy_brott.stance = 2  # Kiting
	enemy_brott.position = Vector2(12 * 32.0, 8 * 32.0)
	enemy_brott.setup()
	
	sim.add_brott(player_brott)
	sim.add_brott(enemy_brott)
	
	arena_renderer.setup(sim, ARENA_OFFSET)

func _process(delta: float) -> void:
	# [S17.1-004] Tick-budget auto-dismiss for the first-run overlay. Runs
	# regardless of match state so a paused-at-start combat still clears
	# the nudge eventually.
	if energy_explainer_overlay != null:
		_energy_explainer_ticks += 1
		if _energy_explainer_ticks >= ENERGY_EXPLAINER_TICK_BUDGET:
			_dismiss_energy_explainer()

	if sim.match_over:
		arena_renderer.queue_redraw()
		return
	
	tick_accumulator += delta * speed_multiplier
	var tick_delta := 1.0 / float(TICKS_PER_SEC)
	
	while tick_accumulator >= tick_delta:
		tick_accumulator -= tick_delta
		sim.simulate_tick()
		arena_renderer.tick_visuals()
	
	_update_ui()
	arena_renderer.queue_redraw()

func _update_ui() -> void:
	if player_info:
		var hp_str: String = "%d/%d" % [int(player_brott.hp), player_brott.max_hp]
		var en_str: String = "%d" % [int(player_brott.energy)]
		player_info.text = "PLAYER [%s] HP: %s  EN: %s" % [player_brott.bot_name, hp_str, en_str]
	
	if enemy_info:
		var hp_str: String = "%d/%d" % [int(enemy_brott.hp), enemy_brott.max_hp]
		var en_str: String = "%d" % [int(enemy_brott.energy)]
		enemy_info.text = "ENEMY [%s] HP: %s  EN: %s" % [enemy_brott.bot_name, hp_str, en_str]
	
	if time_label:
		var secs: int = sim.tick_count / TICKS_PER_SEC
		time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	
	if speed_label:
		speed_label.text = "Speed: %dx" % [int(speed_multiplier)]

func _unhandled_input(event: InputEvent) -> void:
	# [S17.1-004] Any meaningful input dismisses the first-run overlay on
	# first press. Handled here (not _input) so the button's own press
	# event is not stolen before it fires _on_energy_explainer_dismissed.
	if energy_explainer_overlay != null:
		var is_action := false
		if event is InputEventKey and event.pressed:
			is_action = true
		elif event is InputEventMouseButton and event.pressed:
			is_action = true
		if is_action:
			_dismiss_energy_explainer()
			# fall through — the player's key press (e.g. KEY_1 speed) still
			# applies in the same frame.

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				speed_multiplier = 1.0
			KEY_2:
				speed_multiplier = 2.0
			KEY_5:
				speed_multiplier = 5.0
			KEY_R:
				_setup_match()
			KEY_SPACE:
				if sim.match_over:
					_setup_match()
