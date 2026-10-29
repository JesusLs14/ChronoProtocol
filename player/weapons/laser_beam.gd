class_name LaserBeam
extends Node2D

## Láser continuo del soldado: mientras se mantiene el disparo dibuja un rayo
## desde la boca del arma hacia donde se apunta. Lo cortan las paredes y los
## obstáculos, y daña a todo lo que toca cada cierto tiempo.

const RANGE: float = 760.0
const HIT_WIDTH: float = 30.0
const TICK_INTERVAL: float = 0.12
const TICK_DAMAGE: int = 1
## Tiempo que el rayo sigue visible después del último fotograma de disparo.
const LINGER: float = 0.06

var weapon_manager: WeaponManager

var _from: Vector2
var _to: Vector2
var _visible_time: float = 0.0
var _tick_cooldown: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 4


## Dispara un fotograma del rayo. Devuelve true cuando le toca hacer daño
## (para el sonido y la animación de disparo).
func fire(from: Vector2, target: Vector2) -> bool:
	var direction := from.direction_to(target)
	if direction == Vector2.ZERO:
		return false
	_from = from
	_to = _cut_by_obstacles(from, from + direction * RANGE)
	_visible_time = LINGER
	if _tick_cooldown > 0.0:
		return false
	var rate := 1.0
	if weapon_manager != null:
		rate = weapon_manager.fire_rate_multiplier * weapon_manager.upgrade_fire_rate_multiplier
	_tick_cooldown = TICK_INTERVAL / rate
	_damage_along_beam()
	return true


func _process(delta: float) -> void:
	_time += delta
	_tick_cooldown = maxf(0.0, _tick_cooldown - delta)
	_visible_time = maxf(0.0, _visible_time - delta)
	queue_redraw()


func _cut_by_obstacles(from: Vector2, to: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var player := get_parent() as CollisionObject2D
	if player != null:
		query.exclude = [player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	# Los barriles se dañan con su hurtbox: el rayo los atraviesa para llegar.
	var collider: Object = hit.get("collider")
	if collider != null and collider.has_method("take_damage"):
		return to
	return hit["position"]


func _damage_along_beam() -> void:
	var damage := TICK_DAMAGE + (weapon_manager.damage_bonus if weapon_manager != null else 0)
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		var area := hurtbox as Area2D
		if area == null:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(area.global_position, _from, _to)
		if closest.distance_to(area.global_position) > HIT_WIDTH + 20.0:
			continue
		var target := area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(damage)
		else:
			var health_component: Variant = target.get_node_or_null("HealthComponent")
			if health_component != null:
				health_component.take_damage(damage)


func _draw() -> void:
	if _visible_time <= 0.0:
		return
	var flicker := 0.85 + 0.15 * sin(_time * 60.0)
	draw_line(_from, _to, Color(0.1, 0.8, 1.0, 0.35 * flicker), 22.0)
	draw_line(_from, _to, Color(0.4, 1.0, 1.0, 0.8 * flicker), 9.0)
	draw_line(_from, _to, Color(0.95, 1.0, 1.0, flicker), 3.0)
	draw_circle(_from, 9.0 * flicker, Color(0.7, 1.0, 1.0, 0.9))
	draw_circle(_to, 14.0 * flicker, Color(0.4, 1.0, 1.0, 0.6))
