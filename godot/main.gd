## Main scene — sets up combat and drives the simulation visually
extends Node2D

const ARENA_OFFSET := Vector2(384, 60)  # Center arena in 1280x720
const TICKS_PER_SEC := 10

@onready var arena_renderer: Node2D = $ArenaRenderer
@onready var speed_label: Label = $UI/SpeedLabel
@onready var player_info: Label = $UI/PlayerInfo
@onready var enemy_info: Label = $UI/EnemyInfo
@onready var time_label: Label = $UI/TimeLabel
@onready var _ui_layer: CanvasLayer = $UI

var sim: CombatSim
var player_brott: BrottState
var enemy_brott: BrottState

var speed_multiplier: float = 1.0
var tick_accumulator: float = 0.0

func _ready() -> void:
	_apply_audio_settings()
	_setup_match()

# [S21.5] Apply persisted mute state from FirstRunState on scene load.
# Mutes/unmutes the Master bus (bus 0) globally.
func _apply_audio_settings() -> void:
	var frs := get_node_or_null("/root/FirstRunState")
	if frs == null:
		return
	var muted: bool = frs.call("get_audio_muted")
	AudioServer.set_bus_mute(0, muted)
	# [S24.2] Apply persisted bus volumes (additive — mute logic above unchanged).
	AudioServer.set_bus_volume_db(0, frs.call("get_master_db"))
	AudioServer.set_bus_volume_db(1, frs.call("get_sfx_db"))
	AudioServer.set_bus_volume_db(2, frs.call("get_music_db"))

func _setup_match() -> void:
	# Create simulation
	sim = CombatSim.new(42)  # deterministic seed
	
	# Player: Brawler with Shotgun + Minigun, Plating, Repair Nanites
	# Demo route — league-agnostic; default "bronze" applies.
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
	# Demo route — league-agnostic; default "bronze" applies.
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
		player_info.text = "PLAYER [%s] HP: %s" % [player_brott.bot_name, hp_str]
	
	if enemy_info:
		var hp_str: String = "%d/%d" % [int(enemy_brott.hp), enemy_brott.max_hp]
		enemy_info.text = "ENEMY [%s] HP: %s" % [enemy_brott.bot_name, hp_str]
	
	if time_label:
		var secs: int = sim.tick_count / TICKS_PER_SEC
		time_label.text = "%d:%02d" % [secs / 60, secs % 60]
	
	if speed_label:
		speed_label.text = "Speed: %dx" % [int(speed_multiplier)]

func _unhandled_input(event: InputEvent) -> void:
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
