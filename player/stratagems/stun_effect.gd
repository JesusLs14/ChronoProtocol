class_name StunEffect
extends Node2D

## Parálisis del Pulso EMS: el enemigo deja de moverse, de atacar y de
## animarse, se pinta de azul y le saltan chispas. Se quita sola al acabar.
## Mientras dura, el enemigo sigue recibiendo balas.

var duration: float = 5.0
var _time: float = 0.0
var _enemy: Node2D
var _sprite: CanvasItem
var _paused_timers: Array[Timer] = []


## Paraliza al enemigo; si ya estaba paralizado, renueva el tiempo.
static func apply(enemy: Node2D, seconds: float) -> void:
	var existing := enemy.get_node_or_null("StunEffect") as StunEffect
	if existing != null:
		existing._time = 0.0
		existing.duration = maxf(existing.duration, seconds)
		return
	var effect := StunEffect.new()
	effect.name = "StunEffect"
	effect.duration = seconds
	enemy.add_child(effect)


func _ready() -> void:
	_enemy = get_parent() as Node2D
	z_index = 6
	_enemy.set_physics_process(false)
	for timer in _enemy.find_children("*", "Timer", false, false):
		var enemy_timer := timer as Timer
		if not enemy_timer.paused:
			enemy_timer.paused = true
			_paused_timers.append(enemy_timer)
	_sprite = _enemy.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if _sprite != null:
		_sprite.self_modulate = Color(0.55, 0.7, 1.6)
		if _sprite is AnimatedSprite2D:
			(_sprite as AnimatedSprite2D).speed_scale = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	# Al morir sale del grupo "enemy": se suelta para que termine su animación.
	if _time >= duration or not _enemy.is_in_group("enemy"):
		_release()


func _release() -> void:
	set_process(false)
	if is_instance_valid(_enemy):
		_enemy.set_physics_process(true)
		for timer in _paused_timers:
			if is_instance_valid(timer):
				timer.paused = false
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.self_modulate = Color.WHITE
			if _sprite is AnimatedSprite2D:
				(_sprite as AnimatedSprite2D).speed_scale = 1.0
	queue_free()


func _draw() -> void:
	# Chispas eléctricas que saltan alrededor del enemigo.
	var radius := 34.0
	for index in 3:
		var angle := _time * 7.0 + index * TAU / 3.0 + randf() * 0.6
		var start := Vector2.from_angle(angle) * radius * 0.4
		var mid := Vector2.from_angle(angle + 0.3) * radius * 0.8 + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var end := Vector2.from_angle(angle - 0.2) * radius
		draw_polyline(PackedVector2Array([start, mid, end]), Color(0.75, 0.85, 1.0, 0.9), 2.5)
