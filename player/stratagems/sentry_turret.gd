class_name SentryTurret
extends Node2D

## Torreta automática de la estratagema: gira hacia el enemigo más cercano y
## le dispara balas del soldado durante un tiempo; luego se apaga.

const BULLET_SCENE: PackedScene = preload("res://player/bullet.tscn")

@export var lifetime: float = 20.0
@export var fire_interval: float = 0.28
@export var detection_range: float = 750.0
@export var turn_speed: float = 8.0

var _time: float = 0.0
var _cooldown: float = 0.0
var _aim_angle: float = -PI * 0.5
var _flash: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_flash = maxf(0.0, _flash - delta * 8.0)
	if _time >= lifetime:
		_shutdown()
		return

	var target := _nearest_enemy()
	if target != null:
		var wanted := global_position.direction_to(target.global_position).angle()
		_aim_angle = lerp_angle(_aim_angle, wanted, minf(1.0, turn_speed * delta))
		if _cooldown == 0.0 and absf(angle_difference(_aim_angle, wanted)) < 0.2:
			_fire()
	queue_redraw()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := detection_range
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		var area := hurtbox as Area2D
		# Los enemigos que ya murieron salen del grupo "enemy".
		if area == null or not area.get_parent().is_in_group("enemy"):
			continue
		var distance := global_position.distance_to(area.global_position)
		if distance < best_distance:
			best_distance = distance
			best = area
	return best


func _fire() -> void:
	_cooldown = fire_interval
	_flash = 1.0
	var bullet := BULLET_SCENE.instantiate() as Node2D
	get_parent().add_child(bullet)
	var direction := Vector2.from_angle(_aim_angle)
	bullet.global_position = global_position + direction * 48.0
	bullet.rotation = _aim_angle


func _shutdown() -> void:
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# Base hexagonal, cañón giratorio y anillo con el tiempo restante.
	draw_circle(Vector2(0, 6), 34.0, Color(0, 0, 0, 0.35))
	var base := PackedVector2Array()
	for index in 6:
		base.append(Vector2.from_angle(TAU * index / 6.0) * 30.0)
	draw_colored_polygon(base, Color(0.12, 0.14, 0.2))
	draw_polyline(base + PackedVector2Array([base[0]]), Color(0.4, 1.0, 0.4, 0.8), 2.0)
	var direction := Vector2.from_angle(_aim_angle)
	draw_line(Vector2.ZERO, direction * 46.0, Color(0.3, 0.33, 0.4), 12.0)
	draw_line(Vector2.ZERO, direction * 46.0, Color(0.5, 0.55, 0.65), 5.0)
	draw_circle(Vector2.ZERO, 14.0, Color(0.22, 0.25, 0.32))
	draw_circle(Vector2.ZERO, 6.0, Color(0.4, 1.0, 0.4, 0.6 + 0.4 * sin(_time * 8.0)))
	if _flash > 0.0:
		draw_circle(direction * 52.0, 10.0 * _flash, Color(0.6, 1.0, 1.0, _flash))
	var left := 1.0 - _time / lifetime
	draw_arc(Vector2.ZERO, 40.0, -PI * 0.5, -PI * 0.5 + TAU * left, 32, Color(0.4, 1.0, 0.4, 0.7), 3.0)
