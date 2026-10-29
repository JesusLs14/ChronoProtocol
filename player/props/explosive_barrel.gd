class_name ExplosiveBarrel
extends StaticBody2D

## Barril explosivo: estorba el paso como un obstáculo y, con unos disparos,
## explota dañando a los enemigos cercanos (y al soldado, si está muy cerca).
## Su explosión hace estallar a los barriles vecinos.

const RADIUS: float = 26.0
const BLAST_RADIUS: float = 180.0
const ENEMY_DAMAGE: int = 8
const PLAYER_DAMAGE: int = 2
const MAX_HEALTH: int = 3

var _health: int = MAX_HEALTH
var _exploded: bool = false
var _flash: float = 0.0
var _time: float = randf() * 10.0


func _init() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("obstacle")
	add_to_group("barrels")
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var body_shape := CollisionShape2D.new()
	body_shape.shape = shape
	add_child(body_shape)
	# Las balas del soldado dañan por esta área, como a los enemigos.
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.add_to_group("enemy_hurtbox")
	var hurt_shape := CollisionShape2D.new()
	hurt_shape.shape = shape
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	queue_redraw()


func take_damage(damage_amount: int = 1) -> bool:
	if _exploded or damage_amount <= 0:
		return false
	_health -= damage_amount
	_flash = 1.0
	Sfx.play("click", -8.0, 0.2)
	if _health <= 0:
		_explode.call_deferred()
	return true


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var at := global_position
	CombatFx.explosion(get_parent(), at, BLAST_RADIUS, Color(1.0, 0.5, 0.12))
	Sfx.play("explosion", 0.0, 0.1)
	var screen_shake := get_tree().get_first_node_in_group("screen_shake")
	if screen_shake != null:
		screen_shake.shake()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(at) <= BLAST_RADIUS * 0.8:
		player.take_damage(PLAYER_DAMAGE)
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		var area := hurtbox as Area2D
		if area == null or area.get_parent() == self or area.global_position.distance_to(at) > BLAST_RADIUS:
			continue
		var target := area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(ENEMY_DAMAGE)
		else:
			var health_component: Variant = target.get_node_or_null("HealthComponent")
			if health_component != null:
				health_component.take_damage(ENEMY_DAMAGE)
	queue_free()


func _draw() -> void:
	# Sombra, cuerpo rojo con aros metálicos y símbolo de peligro.
	draw_circle(Vector2(4, 8), RADIUS + 2.0, Color(0, 0, 0, 0.35))
	var body := Color(0.78, 0.16, 0.1).lerp(Color(1.8, 1.6, 1.4), _flash)
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_circle(Vector2(-6, -7), RADIUS * 0.45, Color(1, 0.45, 0.35, 0.35))
	draw_arc(Vector2.ZERO, RADIUS - 1.0, 0.0, TAU, 32, Color(0.25, 0.27, 0.32), 4.0)
	draw_arc(Vector2.ZERO, RADIUS * 0.62, 0.0, TAU, 28, Color(0.35, 0.37, 0.42), 3.0)
	var pulse := 0.6 + 0.4 * sin(_time * 5.0)
	var triangle := PackedVector2Array([Vector2(0, -10), Vector2(9, 7), Vector2(-9, 7)])
	draw_colored_polygon(triangle, Color(1.0, 0.85, 0.15, pulse))
	draw_line(Vector2(0, -4), Vector2(0, 2), Color(0.1, 0.05, 0.0), 2.0)
	draw_circle(Vector2(0, 4.5), 1.2, Color(0.1, 0.05, 0.0))
	# Barra de vida pequeña cuando ya recibió daño.
	if _health < MAX_HEALTH:
		var ratio := float(_health) / MAX_HEALTH
		draw_rect(Rect2(-20, -RADIUS - 12, 40, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-20, -RADIUS - 12, 40 * ratio, 5), Color(1.0, 0.6, 0.1))
