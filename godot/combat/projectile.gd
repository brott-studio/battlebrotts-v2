## Projectile traveling in the arena
class_name Projectile
extends RefCounted

var pos: Vector2
var velocity: Vector2
var damage: float
var source: BrottState
var target_pos: Vector2  # for homing/splash
var splash_radius: int = 0  # tiles, 0 = none
var is_crit: bool = false
var alive: bool = true
var speed: float = 400.0  # px/s
var max_range_px: float = 0.0
var traveled: float = 0.0

func _init(p_source: BrottState, p_target_pos: Vector2, p_damage: float, p_crit: bool, p_range_tiles: float, p_splash: int, p_speed: float = 400.0) -> void:
	source = p_source
	pos = p_source.position
	target_pos = p_target_pos
	damage = p_damage
	is_crit = p_crit
	splash_radius = p_splash
	max_range_px = p_range_tiles * 32.0
	speed = p_speed
	
	var dir := (p_target_pos - pos).normalized()
	velocity = dir * speed
