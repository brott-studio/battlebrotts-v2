## Bot preview renderer — Sprint 12.3: 96×96 visual loadout with equipment layers
## Draws chassis base, armor overlay, weapon mounts, module indicators
## Supports equip/unequip animations
class_name BotPreview
extends Control

const PREVIEW_SIZE := 96.0
const HALF := PREVIEW_SIZE / 2.0

# Animation state
var _equip_anims: Array[Dictionary] = []  # {type, item_key, progress, duration}
var _unequip_anims: Array[Dictionary] = []
var _nod_timer: float = 0.0
var _nod_offset: float = 0.0
var _weight_sink_timer: float = 0.0
var _weight_sink_offset: float = 0.0
var _shake_timer: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

# Current loadout (set externally)
var chassis_type: int = ChassisData.ChassisType.SCOUT
var equipped_weapons: Array[int] = []
var equipped_armor: int = ArmorData.ArmorType.NONE
var equipped_modules: Array[int] = []

# Module indicator colors
const MODULE_COLORS := {
	ModuleData.ModuleType.OVERCLOCK: Color(1.0, 0.6, 0.0),      # orange
	ModuleData.ModuleType.REPAIR_NANITES: Color(0.2, 0.8, 0.2),  # green
	ModuleData.ModuleType.SHIELD_PROJECTOR: Color(0.3, 0.5, 1.0), # blue
	ModuleData.ModuleType.SENSOR_ARRAY: Color(1.0, 0.9, 0.2),    # yellow
	ModuleData.ModuleType.AFTERBURNER: Color(1.0, 0.2, 0.2),     # red
	ModuleData.ModuleType.EMP_CHARGE: Color(0.6, 0.2, 0.9),      # purple
}

# Weapon silhouette definitions (draw offsets from mount point)
const WEAPON_SILHOUETTES := {
	WeaponData.WeaponType.MINIGUN: "barrel_cluster",
	WeaponData.WeaponType.RAILGUN: "long_barrel",
	WeaponData.WeaponType.SHOTGUN: "wide_barrel",
	WeaponData.WeaponType.MISSILE_POD: "pod_cluster",
	WeaponData.WeaponType.PLASMA_CUTTER: "blade",
	WeaponData.WeaponType.ARC_EMITTER: "coil",
	WeaponData.WeaponType.FLAK_CANNON: "wide_barrel_short",
}

func _ready() -> void:
	custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)

func update_loadout(p_chassis: int, p_weapons: Array[int], p_armor: int, p_modules: Array[int]) -> void:
	chassis_type = p_chassis
	equipped_weapons = p_weapons.duplicate()
	equipped_armor = p_armor
	equipped_modules = p_modules.duplicate()
	queue_redraw()

## Trigger equip animation (0.3s tween snap + 2-frame clunk shake)
func play_equip_anim(item_key: String) -> void:
	_equip_anims.append({"key": item_key, "progress": 0.0, "duration": 0.3})
	# Nod reaction
	_nod_timer = 0.2
	_nod_offset = 0.0

## Trigger equip with heavy weight sink
func play_equip_anim_heavy(item_key: String) -> void:
	play_equip_anim(item_key)
	_weight_sink_timer = 0.3
	_weight_sink_offset = 0.0

## Trigger unequip animation (0.2s detach + fade)
func play_unequip_anim(item_key: String) -> void:
	_unequip_anims.append({"key": item_key, "progress": 0.0, "duration": 0.2})

func _process(delta: float) -> void:
	var needs_redraw := false

	# Update equip animations
	var done_equip: Array[int] = []
	for i in range(_equip_anims.size()):
		_equip_anims[i]["progress"] += delta
		if _equip_anims[i]["progress"] >= _equip_anims[i]["duration"]:
			done_equip.append(i)
			# Trigger clunk shake at end
			_shake_timer = 2.0 / 60.0  # 2 frames
			_shake_offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		needs_redraw = true
	done_equip.reverse()
	for idx in done_equip:
		_equip_anims.remove_at(idx)

	# Update unequip animations
	var done_unequip: Array[int] = []
	for i in range(_unequip_anims.size()):
		_unequip_anims[i]["progress"] += delta
		if _unequip_anims[i]["progress"] >= _unequip_anims[i]["duration"]:
			done_unequip.append(i)
		needs_redraw = true
	done_unequip.reverse()
	for idx in done_unequip:
		_unequip_anims.remove_at(idx)

	# Nod animation
	if _nod_timer > 0:
		_nod_timer -= delta
		var t := 1.0 - (_nod_timer / 0.2)
		if t < 0.5:
			_nod_offset = 2.0 * (t / 0.5)  # down
		else:
			_nod_offset = 2.0 * (1.0 - (t - 0.5) / 0.5)  # back up
		needs_redraw = true
	else:
		_nod_offset = 0.0

	# Weight sink animation
	if _weight_sink_timer > 0:
		_weight_sink_timer -= delta
		var t := 1.0 - (_weight_sink_timer / 0.3)
		if t < 0.3:
			_weight_sink_offset = 1.0 * (t / 0.3)
		else:
			_weight_sink_offset = 1.0 * (1.0 - (t - 0.3) / 0.7)
		needs_redraw = true
	else:
		_weight_sink_offset = 0.0

	# Shake
	if _shake_timer > 0:
		_shake_timer -= delta
		_shake_offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		needs_redraw = true
	else:
		_shake_offset = Vector2.ZERO

	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	var center := Vector2(HALF, HALF) + _shake_offset + Vector2(0, _nod_offset + _weight_sink_offset)

	# Layer 1: Chassis base
	_draw_chassis(center)

	# Layer 2: Armor overlay
	_draw_armor(center)

	# Layer 3: Weapon mounts
	_draw_weapons(center)

	# Layer 4: Module indicators
	_draw_modules(center)

func _draw_chassis(center: Vector2) -> void:
	match chassis_type:
		ChassisData.ChassisType.SCOUT:
			# Triangular, nimble shape
			var pts := PackedVector2Array([
				center + Vector2(0, -30),
				center + Vector2(-24, 24),
				center + Vector2(24, 24),
			])
			draw_colored_polygon(pts, Color(0.25, 0.45, 0.85))
			# Inner detail
			var inner := PackedVector2Array([
				center + Vector2(0, -18),
				center + Vector2(-14, 14),
				center + Vector2(14, 14),
			])
			draw_colored_polygon(inner, Color(0.3, 0.55, 0.95))

		ChassisData.ChassisType.BRAWLER:
			# Pentagon, stocky
			var pts := PackedVector2Array()
			for i in 5:
				var angle: float = i * TAU / 5.0 - PI / 2.0
				pts.append(center + Vector2(cos(angle), sin(angle)) * 30.0)
			draw_colored_polygon(pts, Color(0.7, 0.5, 0.2))
			# Inner
			var inner := PackedVector2Array()
			for i in 5:
				var angle: float = i * TAU / 5.0 - PI / 2.0
				inner.append(center + Vector2(cos(angle), sin(angle)) * 20.0)
			draw_colored_polygon(inner, Color(0.8, 0.6, 0.3))

		ChassisData.ChassisType.FORTRESS:
			# Square, heavy
			draw_rect(Rect2(center - Vector2(28, 28), Vector2(56, 56)), Color(0.4, 0.4, 0.5))
			draw_rect(Rect2(center - Vector2(20, 20), Vector2(40, 40)), Color(0.5, 0.5, 0.6))

func _draw_armor(center: Vector2) -> void:
	match equipped_armor:
		ArmorData.ArmorType.PLATING:
			# Angular plates on front and sides
			var col := Color(0.6, 0.6, 0.7, 0.7)
			# Front plate
			draw_rect(Rect2(center + Vector2(-18, -34), Vector2(36, 8)), col)
			# Side plates
			draw_rect(Rect2(center + Vector2(-34, -14), Vector2(8, 28)), col)
			draw_rect(Rect2(center + Vector2(26, -14), Vector2(8, 28)), col)

		ArmorData.ArmorType.REACTIVE_MESH:
			# Glowing wire-frame mesh
			var col := Color(0.3, 1.0, 0.5, 0.5)
			# Draw mesh lines around chassis
			for i in range(0, 360, 30):
				var angle := deg_to_rad(float(i))
				var outer := center + Vector2(cos(angle), sin(angle)) * 34.0
				var next_angle := deg_to_rad(float(i + 30))
				var next_outer := center + Vector2(cos(next_angle), sin(next_angle)) * 34.0
				draw_line(outer, next_outer, col, 1.5)
			# Inner ring
			draw_arc(center, 28.0, 0, TAU, 24, col, 1.0)

		ArmorData.ArmorType.ABLATIVE_SHELL:
			# Bulky rounded shell
			var col := Color(0.5, 0.35, 0.2, 0.6)
			draw_circle(center, 38.0, col)
			# Highlight
			draw_arc(center, 38.0, -PI * 0.7, PI * 0.3, 16, Color(0.7, 0.5, 0.3, 0.4), 2.0)

func _draw_weapons(center: Vector2) -> void:
	# Slot 1: right side, Slot 2: left side
	for i in range(equipped_weapons.size()):
		if i >= 2:
			break
		var wt: int = equipped_weapons[i]
		var mount_x := 32.0 if i == 0 else -32.0  # right or left
		var mount := center + Vector2(mount_x, 0)
		var flip := 1.0 if i == 0 else -1.0

		# Check if this weapon is animating in
		var anim_scale := 1.0
		for anim in _equip_anims:
			if anim["key"] == "weapon_%d" % i:
				var t: float = anim["progress"] / anim["duration"]
				anim_scale = t  # scale from 0 to 1
				mount = center.lerp(mount, t)  # slide in

		_draw_weapon_silhouette(mount, wt, flip, anim_scale)

func _draw_weapon_silhouette(pos: Vector2, weapon_type: int, flip: float, anim_scale: float) -> void:
	var col := Color(0.8, 0.8, 0.8, anim_scale)

	match weapon_type:
		WeaponData.WeaponType.MINIGUN:
			# Barrel cluster — 3 small barrels
			for j in range(3):
				var y_off := (j - 1) * 4.0
				draw_rect(Rect2(pos + Vector2(0, y_off - 1.5), Vector2(14.0 * flip, 3)), col)

		WeaponData.WeaponType.RAILGUN:
			# Long barrel
			draw_rect(Rect2(pos + Vector2(0, -2), Vector2(20.0 * flip, 4)), col)
			# Charge coil
			draw_circle(pos + Vector2(4.0 * flip, 0), 3.0, Color(0.3, 0.7, 1.0, anim_scale))

		WeaponData.WeaponType.SHOTGUN:
			# Wide barrel
			draw_rect(Rect2(pos + Vector2(0, -4), Vector2(10.0 * flip, 8)), col)

		WeaponData.WeaponType.MISSILE_POD:
			# Pod cluster — 2x2 tubes
			for dx in [0, 5]:
				for dy in [-3, 3]:
					draw_rect(Rect2(pos + Vector2(dx * flip, dy - 1.5), Vector2(4.0 * flip, 3)), col)

		WeaponData.WeaponType.PLASMA_CUTTER:
			# Blade shape
			var pts := PackedVector2Array([
				pos,
				pos + Vector2(16.0 * flip, -3),
				pos + Vector2(18.0 * flip, 0),
				pos + Vector2(16.0 * flip, 3),
			])
			draw_colored_polygon(pts, Color(0.8, 0.3, 0.9, anim_scale))

		WeaponData.WeaponType.ARC_EMITTER:
			# Coil shape
			draw_circle(pos + Vector2(6.0 * flip, 0), 5.0, Color(0.3, 0.5, 1.0, anim_scale))
			draw_arc(pos + Vector2(6.0 * flip, 0), 7.0, 0, TAU, 12, Color(0.4, 0.6, 1.0, anim_scale * 0.6), 1.5)

		WeaponData.WeaponType.FLAK_CANNON:
			# Wide barrel, shorter than shotgun
			draw_rect(Rect2(pos + Vector2(0, -5), Vector2(8.0 * flip, 10)), col)
			# Muzzle flare hint
			draw_circle(pos + Vector2(8.0 * flip, 0), 3.0, Color(1.0, 0.6, 0.2, anim_scale * 0.5))

func _draw_modules(center: Vector2) -> void:
	# Place module indicator lights along bottom of chassis
	var count := equipped_modules.size()
	if count == 0:
		return

	var start_x := -((count - 1) * 8.0) / 2.0
	for i in range(count):
		var mt: int = equipped_modules[i]
		var light_pos := center + Vector2(start_x + i * 8.0, 18.0)
		var col: Color = MODULE_COLORS.get(mt, Color.WHITE)

		# Glow
		draw_circle(light_pos, 5.0, Color(col.r, col.g, col.b, 0.3))
		# Light
		draw_circle(light_pos, 3.0, col)

## Returns whether a specific weapon type has a distinct silhouette definition
func has_weapon_silhouette(weapon_type: int) -> bool:
	return weapon_type in WEAPON_SILHOUETTES

## Returns the module indicator color for a given module type
func get_module_color(module_type: int) -> Color:
	return MODULE_COLORS.get(module_type, Color.WHITE)
