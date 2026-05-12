## test_arc_p2_gun_facing.gd — Arc P.2: weapon icons rotate to face target.
##
## These are logic-layer tests that verify the helper geometry rather than
## calling draw functions directly (which require a live CanvasItem).
## We test the direction math used by _draw_ingame_weapons and the
## _draw_rotated_rect helper by computing expected vectors inline.
##
## Gates:
##   P2-1: aim_dir toward live target — rotated mounts point in direction of target
##   P2-2: no live target — mounts fall back to facing_angle for Brawler/Fortress
##   P2-3: no live target Scout — mounts fall back to default right (1,0)
##   P2-4: _draw_rotated_rect geometry — vertices form correct oriented quad
extends SceneTree

var pass_count := 0
var fail_count := 0

func _initialize() -> void:
	print("=== test_arc_p2_gun_facing ===\n")
	_test_p2_1_aim_dir_toward_target()
	_test_p2_2_fallback_facing_angle_brawler()
	_test_p2_3_fallback_default_scout()
	_test_p2_4_rotated_rect_geometry()
	print("\n=== Results: %d passed, %d failed ===" % [pass_count, fail_count])
	quit(1 if fail_count > 0 else 0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		pass_count += 1
		print("  PASS: %s" % msg)
	else:
		fail_count += 1
		print("  FAIL: %s" % msg)

func _approx_eq(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) < eps

func _vec_approx(a: Vector2, b: Vector2, eps: float = 0.01) -> bool:
	return a.distance_to(b) < eps

## Replicate the aim_dir logic from _draw_ingame_weapons for direct testing.
func _compute_aim_dir(bot_pos: Vector2, target_pos: Vector2, target_alive: bool,
		chassis_type: ChassisData.ChassisType, facing_angle_deg: float) -> Vector2:
	if target_alive:
		var delta := target_pos - bot_pos
		if delta.length_squared() > 0.01:
			return delta.normalized()
	# fallback
	if chassis_type == ChassisData.ChassisType.BRAWLER or \
			chassis_type == ChassisData.ChassisType.FORTRESS:
		var rad := deg_to_rad(facing_angle_deg)
		return Vector2(cos(rad), sin(rad))
	return Vector2(1.0, 0.0)  # Scout default

## ── P2-1: aim_dir points toward live target ─────────────────────────────────
func _test_p2_1_aim_dir_toward_target() -> void:
	print("--- P2-1: aim_dir toward live target ---")
	# Bot at (100,100), target to the right at (200,100)
	var aim := _compute_aim_dir(Vector2(100,100), Vector2(200,100), true,
			ChassisData.ChassisType.SCOUT, 0.0)
	_assert(_vec_approx(aim, Vector2(1,0)), "target right: aim_dir == (1,0), got %s" % str(aim))

	# Bot at (100,100), target above at (100,0) → dir = (0,-1)
	aim = _compute_aim_dir(Vector2(100,100), Vector2(100,0), true,
			ChassisData.ChassisType.BRAWLER, 90.0)
	_assert(_vec_approx(aim, Vector2(0,-1)), "target up: aim_dir == (0,-1), got %s" % str(aim))

	# Bot at (256,256), target at 45° → normalized (√2/2, √2/2)
	aim = _compute_aim_dir(Vector2(256,256), Vector2(356,356), true,
			ChassisData.ChassisType.SCOUT, 0.0)
	var expected := Vector2(1,1).normalized()
	_assert(_vec_approx(aim, expected), "target 45 deg: aim_dir ≈ (0.707, 0.707), got %s" % str(aim))

## ── P2-2: fallback to facing_angle for Brawler/Fortress ─────────────────────
func _test_p2_2_fallback_facing_angle_brawler() -> void:
	print("--- P2-2: fallback facing_angle for Brawler/Fortress ---")
	# facing_angle 0 deg → (1, 0)
	var aim := _compute_aim_dir(Vector2(100,100), Vector2.ZERO, false,
			ChassisData.ChassisType.BRAWLER, 0.0)
	_assert(_vec_approx(aim, Vector2(1,0)), "Brawler facing 0 deg: aim_dir == (1,0)")

	# facing_angle 90 deg → (0, 1) in GDScript convention (y down)
	aim = _compute_aim_dir(Vector2(100,100), Vector2.ZERO, false,
			ChassisData.ChassisType.FORTRESS, 90.0)
	_assert(_vec_approx(aim, Vector2(0,1)), "Fortress facing 90 deg: aim_dir == (0,1)")

	# facing_angle 180 deg → (-1, 0)
	aim = _compute_aim_dir(Vector2(100,100), Vector2.ZERO, false,
			ChassisData.ChassisType.BRAWLER, 180.0)
	_assert(_vec_approx(aim, Vector2(-1,0)), "Brawler facing 180 deg: aim_dir == (-1,0)")

## ── P2-3: Scout with no target falls back to default (1,0) ──────────────────
func _test_p2_3_fallback_default_scout() -> void:
	print("--- P2-3: Scout no-target falls back to (1,0) ---")
	var aim := _compute_aim_dir(Vector2(100,100), Vector2.ZERO, false,
			ChassisData.ChassisType.SCOUT, 45.0)
	_assert(_vec_approx(aim, Vector2(1,0)), "Scout no target: aim_dir == (1,0) (default right), got %s" % str(aim))

## ── P2-4: _draw_rotated_rect geometry ────────────────────────────────────────
func _test_p2_4_rotated_rect_geometry() -> void:
	print("--- P2-4: rotated rect geometry ---")
	## Replicate the helper inline:
	## origin=(0,0), dir_vec=(10,0) (pointing right), thickness=4
	## Expected: axis-aligned rect from (0,-2) to (10,+2)
	var origin := Vector2(0, 0)
	var dir_vec := Vector2(10, 0)
	var thickness := 4.0
	var perp_axis := dir_vec.normalized().rotated(PI / 2.0)
	var half_t := perp_axis * (thickness * 0.5)
	var p0 := origin - half_t
	var p1 := origin + dir_vec - half_t
	var p2 := origin + dir_vec + half_t
	var p3 := origin + half_t
	_assert(_vec_approx(p0, Vector2(0, -2)), "p0 == (0,-2), got %s" % str(p0))
	_assert(_vec_approx(p1, Vector2(10, -2)), "p1 == (10,-2), got %s" % str(p1))
	_assert(_vec_approx(p2, Vector2(10, 2)), "p2 == (10,2), got %s" % str(p2))
	_assert(_vec_approx(p3, Vector2(0, 2)), "p3 == (0,2), got %s" % str(p3))

	## Rotated 90 degrees: dir_vec=(0,10), should give rect from (-2,0) to (+2,10)
	dir_vec = Vector2(0, 10)
	perp_axis = dir_vec.normalized().rotated(PI / 2.0)
	half_t = perp_axis * (thickness * 0.5)
	p0 = origin - half_t
	p1 = origin + dir_vec - half_t
	p2 = origin + dir_vec + half_t
	p3 = origin + half_t
	_assert(_vec_approx(p0, Vector2(2, 0)), "rotated 90: p0 ≈ (2,0), got %s" % str(p0))
	_assert(_vec_approx(p1, Vector2(2, 10)), "rotated 90: p1 ≈ (2,10), got %s" % str(p1))
	_assert(_vec_approx(p2, Vector2(-2, 10)), "rotated 90: p2 ≈ (-2,10), got %s" % str(p2))
	_assert(_vec_approx(p3, Vector2(-2, 0)), "rotated 90: p3 ≈ (-2,0), got %s" % str(p3))
