class_name ArenaProps
extends Node2D

## Obstáculos del mapa: columnas y barricadas fijas que sirven de cobertura
## (detienen las balas de ambos lados y estorban el paso) y barriles
## explosivos que se reponen al empezar cada oleada. Las posiciones son
## fracciones de la zona jugable, así que se adaptan al tamaño de la arena.

const PILLAR_RADIUS: float = 46.0
## Centros de las columnas (fracciones del ancho y alto de la zona jugable).
const PILLARS: Array[Vector2] = [
	Vector2(0.22, 0.25), Vector2(0.78, 0.25), Vector2(0.22, 0.75), Vector2(0.78, 0.75),
	Vector2(0.5, 0.17), Vector2(0.5, 0.83), Vector2(0.1, 0.5), Vector2(0.9, 0.5),
]
## Barricadas: centro (fracciones) y tamaño en píxeles.
const BARRICADES: Array = [
	[Vector2(0.35, 0.38), Vector2(190, 44)],
	[Vector2(0.65, 0.62), Vector2(190, 44)],
	[Vector2(0.35, 0.64), Vector2(44, 170)],
	[Vector2(0.65, 0.36), Vector2(44, 170)],
	[Vector2(0.12, 0.15), Vector2(170, 44)],
	[Vector2(0.88, 0.85), Vector2(170, 44)],
]
const BARREL_COUNT: int = 7
## Distancia mínima entre un barril nuevo y el soldado.
const BARREL_PLAYER_CLEARANCE: float = 280.0

var _bounds: Rect2
## Zonas ocupadas por columnas y barricadas (para no poner nada encima).
var _blocked: Array[Rect2] = []


## Crea las columnas y barricadas dentro de bounds (zona jugable global).
func build(bounds: Rect2) -> void:
	_bounds = bounds
	for fraction in PILLARS:
		_add_pillar(_at(fraction))
	for barricade in BARRICADES:
		_add_barricade(_at(barricade[0]), barricade[1])


## true si el punto cae sobre un obstáculo (con margen).
func is_blocked(point: Vector2, margin: float = 0.0) -> bool:
	for rect in _blocked:
		if rect.grow(margin).has_point(point):
			return true
	for barrel in get_tree().get_nodes_in_group("barrels"):
		if (barrel as Node2D).global_position.distance_to(point) < ExplosiveBarrel.RADIUS + margin:
			return true
	return false


## Repone barriles hasta BARREL_COUNT en lugares libres, lejos del soldado.
func restock_barrels(player_position: Vector2) -> void:
	var missing := BARREL_COUNT - get_tree().get_nodes_in_group("barrels").size()
	var area := _bounds.grow(-90.0)
	for _index in range(missing):
		for _attempt in range(30):
			var point := Vector2(
				randf_range(area.position.x, area.end.x),
				randf_range(area.position.y, area.end.y)
			)
			if point.distance_to(player_position) < BARREL_PLAYER_CLEARANCE or is_blocked(point, 90.0):
				continue
			var barrel := ExplosiveBarrel.new()
			add_child(barrel)
			barrel.global_position = point
			barrel.scale = Vector2.ZERO
			barrel.create_tween().tween_property(barrel, "scale", Vector2.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			break


func _at(fraction: Vector2) -> Vector2:
	return _bounds.position + _bounds.size * fraction


func _add_pillar(center: Vector2) -> void:
	var body := _Obstacle.new()
	body.kind = "pillar"
	body.half_size = Vector2(PILLAR_RADIUS, PILLAR_RADIUS)
	var shape := CircleShape2D.new()
	shape.radius = PILLAR_RADIUS
	_finish_obstacle(body, shape, center)


func _add_barricade(center: Vector2, size: Vector2) -> void:
	var body := _Obstacle.new()
	body.kind = "barricade"
	body.half_size = size * 0.5
	var shape := RectangleShape2D.new()
	shape.size = size
	_finish_obstacle(body, shape, center)


func _finish_obstacle(body: _Obstacle, shape: Shape2D, center: Vector2) -> void:
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	body.global_position = center
	_blocked.append(Rect2(center - body.half_size, body.half_size * 2.0))


## Columna o barricada: cuerpo estático en la capa de las paredes, dibujado en código.
class _Obstacle:
	extends StaticBody2D

	var kind: String = "pillar"
	var half_size: Vector2 = Vector2(40, 40)
	var _time: float = randf() * 10.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		add_to_group("obstacle")

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var glow := 0.55 + 0.45 * sin(_time * 2.0)
		if kind == "pillar":
			var radius := half_size.x
			draw_circle(Vector2(6, 10), radius + 4.0, Color(0, 0, 0, 0.4))
			draw_circle(Vector2.ZERO, radius, Color(0.16, 0.19, 0.26))
			draw_circle(Vector2.ZERO, radius * 0.78, Color(0.24, 0.28, 0.36))
			draw_circle(Vector2(-radius * 0.25, -radius * 0.3), radius * 0.35, Color(0.34, 0.39, 0.48))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.06, 0.08, 0.12), 4.0)
			draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 32, Color(0.1, 0.95, 0.9, 0.5 * glow), 3.0)
			for index in 6:
				var dot := Vector2.from_angle(TAU * index / 6.0) * radius * 0.86
				draw_circle(dot, 3.0, Color(0.5, 0.56, 0.66))
			return
		var rect := Rect2(-half_size, half_size * 2.0)
		draw_rect(Rect2(rect.position + Vector2(6, 10), rect.size), Color(0, 0, 0, 0.4))
		draw_rect(rect, Color(0.22, 0.25, 0.32))
		draw_rect(rect.grow(-5.0), Color(0.3, 0.34, 0.42))
		# Franjas de peligro amarillas y negras.
		var horizontal := half_size.x >= half_size.y
		var stripe_area := rect.grow(-9.0)
		var length := stripe_area.size.x if horizontal else stripe_area.size.y
		var stripes := int(length / 18.0)
		for index in stripes:
			var color := Color(0.95, 0.75, 0.1) if index % 2 == 0 else Color(0.08, 0.08, 0.1)
			var segment := Rect2(stripe_area.position, stripe_area.size)
			if horizontal:
				segment.position.x += index * 18.0
				segment.size.x = 18.0
			else:
				segment.position.y += index * 18.0
				segment.size.y = 18.0
			draw_rect(segment, color)
		draw_rect(rect, Color(0.06, 0.08, 0.12), false, 3.0)
		draw_rect(rect.grow(-2.0), Color(0.1, 0.95, 0.9, 0.25 * glow), false, 2.0)
