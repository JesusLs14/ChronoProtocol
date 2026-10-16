class_name Grenade
extends Area2D

@export var speed: float = 520.0
@export var max_range: float = 650.0
@export var explosion_radius: float = 170.0
@export_range(1, 10, 1) var explosion_damage: int = 3
@export var explosion_duration: float = 0.35

const BODY_COLOR: Color = Color(0.35, 0.95, 0.45)
const EXPLOSION_COLOR: Color = Color(1.0, 0.6, 0.15)

var _travelled: float = 0.0
var _target_distance: float = INF
var _exploded: bool = false
var _explosion_time: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


# La granada vuela hasta el punto apuntado (o hasta max_range) y explota allí.
func set_target(target_position: Vector2) -> void:
	_target_distance = minf(global_position.distance_to(target_position), max_range)


func _process(delta: float) -> void:
	if _exploded:
		_explosion_time += delta
		queue_redraw()
		if _explosion_time >= explosion_duration:
			queue_free()
		return

	var step := speed * delta
	position += Vector2.RIGHT.rotated(rotation) * step
	_travelled += step
	if _travelled >= minf(_target_distance, max_range):
		_explode()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		_explode()


func _explode() -> void:
	if _exploded:
		return

	_exploded = true
	set_deferred("monitoring", false)
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		var area := hurtbox as Area2D
		if area == null or area.global_position.distance_to(global_position) > explosion_radius:
			continue
		var target := area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(explosion_damage)
		else:
			var health_component: Variant = target.get_node_or_null("HealthComponent")
			if health_component != null:
				health_component.take_damage(explosion_damage)

	var screen_shake := get_tree().get_first_node_in_group("screen_shake")
	if screen_shake != null:
		screen_shake.shake()
	queue_redraw()


func _draw() -> void:
	if not _exploded:
		draw_circle(Vector2.ZERO, 9.0, Color(0.1, 0.15, 0.12))
		draw_circle(Vector2.ZERO, 6.0, BODY_COLOR)
		return

	var progress := clampf(_explosion_time / explosion_duration, 0.0, 1.0)
	var radius := explosion_radius * (0.35 + 0.65 * progress)
	var fade := 1.0 - progress
	draw_circle(Vector2.ZERO, radius, Color(EXPLOSION_COLOR, 0.6 * fade))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.92, 0.55, 0.9 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(EXPLOSION_COLOR, fade), 6.0)
