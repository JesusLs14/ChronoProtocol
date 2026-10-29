extends CharacterBody2D

@export var speed: float = 220.0
@export var fragment_scene: PackedScene
## Orbes de Fragmento (de 1 cada uno) que suelta al morir.
@export_range(1, 100, 1) var fragment_drop_amount: int = 2
@export_range(1, 1000, 1) var score_points: int = 10
@export_range(0.1, 5.0, 0.1) var attack_interval: float = 0.8

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: Node = $HealthComponent
@onready var hit_flash: HitFlashComponent = $HitFlashComponent
@onready var attack_area: Area2D = $AttackArea

var _is_dead: bool = false
var _attack_cooldown: float = 0.0
# Rodeo de obstáculos: al chocar con una columna o barricada camina de lado
# un momento hacia el lado que más lo acerca al soldado.
const AVOID_TIME: float = 0.45
var _avoid_direction: Vector2 = Vector2.ZERO
var _avoid_time: float = 0.0


func _ready() -> void:
	health_component.took_damage.connect(_on_health_took_damage)
	health_component.died.connect(_on_health_died)
	sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := global_position.direction_to(player.global_position)
	sprite.flip_h = direction.x < 0.0
	var attack_offset := absf(attack_area.position.x)
	attack_area.position.x = -attack_offset if sprite.flip_h else attack_offset

	var player_in_attack_range := false
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			player_in_attack_range = true
			if _attack_cooldown == 0.0:
				_attack_player(body)
			break

	if player_in_attack_range:
		velocity = Vector2.ZERO
	else:
		var heading := direction
		if _avoid_time > 0.0:
			_avoid_time -= delta
			heading = (direction * 0.35 + _avoid_direction).normalized()
		velocity = heading * speed
	move_and_slide()
	_check_obstacle_collision(direction)

	if not player_in_attack_range and (
			sprite.animation not in [&"Hurt", &"Attack"] or not sprite.is_playing()
	):
		sprite.play(&"Walk" if velocity != Vector2.ZERO else &"Idle")


func _check_obstacle_collision(to_player: Vector2) -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if not collision.get_collider() is StaticBody2D:
			continue
		var side := collision.get_normal().orthogonal()
		# Si ya rodeaba, sigue hacia el mismo lado para no quedarse oscilando.
		if _avoid_time > 0.0 and side.dot(_avoid_direction) < 0.0:
			side = -side
		elif _avoid_time <= 0.0 and side.dot(to_player) < 0.0:
			side = -side
		_avoid_direction = side
		_avoid_time = AVOID_TIME
		return


func _attack_player(player: Node2D) -> void:
	_attack_cooldown = attack_interval
	sprite.play(&"Attack")
	if player.has_method("take_damage"):
		player.take_damage()


func _on_health_took_damage(_current_health: int, _damage_amount: int) -> void:
	if _is_dead:
		return

	hit_flash.flash()
	sprite.play(&"Hurt")


func _on_health_died() -> void:
	_is_dead = true
	remove_from_group("enemy")
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	$AttackArea/CollisionShape2D.set_deferred("disabled", true)
	_spawn_fragment()
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.register_enemy_kill(score_points)
	sprite.play(&"Death")


func _spawn_fragment() -> void:
	call_deferred("_spawn_fragment_deferred", global_position)


func _spawn_fragment_deferred(spawn_position: Vector2) -> void:
	FragmentDropper.drop(fragment_scene, get_parent(), spawn_position, fragment_drop_amount)


func _on_animation_finished() -> void:
	if sprite.animation == &"Death":
		queue_free()
	elif sprite.animation == &"Hurt" and not _is_dead:
		sprite.play(&"Walk")
	elif sprite.animation == &"Attack" and not _is_dead:
		sprite.play(&"Idle")
