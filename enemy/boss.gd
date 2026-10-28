class_name Boss
extends CharacterBody2D

enum BossState { IDLE, LASER, MISSILES, SWARM, SLAM }

signal defeated

@export_range(1, 5000, 1) var max_health: int = 500
@export_range(0.1, 10.0, 0.1) var laser_speed: float = 1.2
@export_range(1.0, 3000.0, 1.0) var slam_speed: float = 900.0
@export_range(0.1, 10.0, 0.1) var attack_interval_min: float = 3.0
@export_range(0.1, 10.0, 0.1) var attack_interval_max: float = 4.0
@export_range(0.1, 5.0, 0.1) var summon_attack_duration: float = 1.0
@export var missile_scene: PackedScene
@export var spider_scene: PackedScene
## Si es true, el jefe espera a start_fight() para atacar (entrada cinemática).
var intro_mode: bool = false
var intro_title: String = "HIVELORD"
var intro_subtitle: String = "SEÑOR DE LA COLMENA"
var intro_color: Color = Color(1.0, 0.18, 0.15)

var current_state: BossState = BossState.IDLE
var is_enraged: bool = false
var _slam_target: Vector2
var _attack_time_remaining: float = 0.0
var _laser_damage_cooldown: float = 0.0
var _laser_charging: bool = false
var _is_defeated: bool = false
var _flash_tween: Tween

@onready var laser_pivot: Node2D = $LaserPivot
@onready var laser_line: Line2D = $LaserPivot/LaserLine
@onready var laser_hitbox: Area2D = $LaserPivot/LaserHitbox
@onready var laser_collision: CollisionShape2D = $LaserPivot/LaserHitbox/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer
@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: BossHealthBar = $BossHealthBar


func _ready() -> void:
	health_component.max_health = max_health
	health_component.current_health = max_health
	health_component.took_damage.connect(_on_health_took_damage)
	health_component.died.connect(_on_health_died)
	health_bar.setup(max_health)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	sprite.play("idle")
	_disable_laser()
	laser_hitbox.body_entered.connect(_on_laser_body_entered)
	if intro_mode:
		health_bar.visible = false
	else:
		_start_attack_timer()


## Vida y velocidad de ataque según cuántas veces ha salido (0 = oleada 5).
## Se llama antes de añadirlo al árbol.
func configure(tier: int) -> void:
	max_health = roundi(500 * (1.0 + 0.5 * tier))
	var speed_up := maxf(0.55, 1.0 - 0.08 * tier)
	attack_interval_min *= speed_up
	attack_interval_max *= speed_up


func intro_roar() -> void:
	sprite.play("summon")


func intro_settle() -> void:
	sprite.play("idle")


## Termina la entrada: aparece la barra de vida y empiezan los ataques.
func start_fight() -> void:
	intro_mode = false
	health_bar.visible = true
	if not _is_defeated:
		_start_attack_timer()


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return

	_laser_damage_cooldown = maxf(0.0, _laser_damage_cooldown - delta)
	match current_state:
		BossState.LASER:
			if not _laser_charging:
				var current_laser_speed := laser_speed * (1.3 if is_enraged else 1.0)
				laser_pivot.rotation += current_laser_speed * delta
				_damage_laser_overlaps()
				_attack_time_remaining -= delta
				if _attack_time_remaining <= 0.0:
					_return_to_idle()
		BossState.SLAM:
			var current_slam_speed := slam_speed * (1.5 if is_enraged else 1.0)
			var distance_to_target := global_position.distance_to(_slam_target)
			if distance_to_target <= current_slam_speed * delta:
				global_position = _slam_target
				velocity = Vector2.ZERO
				_return_to_idle()
			else:
				velocity = global_position.direction_to(_slam_target) * current_slam_speed
				move_and_slide()
		_:
			velocity = Vector2.ZERO


func _start_attack_timer() -> void:
	if is_enraged:
		attack_timer.wait_time = 1.5
		attack_timer.start()
		return

	attack_timer.wait_time = randf_range(
		minf(attack_interval_min, attack_interval_max),
		maxf(attack_interval_min, attack_interval_max)
	)
	attack_timer.start()


func _on_attack_timer_timeout() -> void:
	if _is_defeated or current_state != BossState.IDLE:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Boss cannot attack: no player exists in the player group.")
		_start_attack_timer()
		return

	var attack_states: Array[BossState] = [
		BossState.LASER,
		BossState.MISSILES,
		BossState.SWARM,
		BossState.SLAM
	]
	match attack_states.pick_random():
		BossState.LASER:
			_start_laser(player)
		BossState.MISSILES:
			_fire_missiles(player)
		BossState.SWARM:
			_spawn_swarm()
		BossState.SLAM:
			_start_slam(player)


func _start_laser(player: Node2D) -> void:
	current_state = BossState.LASER
	_laser_charging = true
	_attack_time_remaining = 0.0
	_laser_damage_cooldown = 0.0
	laser_pivot.global_rotation = global_position.direction_to(player.global_position).angle()
	laser_line.width = 2.0
	laser_pivot.show()
	sprite.play("summon")
	_charge_and_fire_laser()


func _charge_and_fire_laser() -> void:
	await get_tree().create_timer(0.5 if is_enraged else 1.0).timeout
	if _is_defeated or current_state != BossState.LASER:
		return

	_laser_charging = false
	laser_line.width = 30.0
	laser_hitbox.monitoring = true
	laser_collision.set_deferred("disabled", false)
	$SfxLaser.play()
	_attack_time_remaining = 3.0


func _fire_missiles(player: Node2D) -> void:
	current_state = BossState.MISSILES
	sprite.play("summon")
	if missile_scene == null:
		push_error("Boss requires missile_scene for the MISSILES attack.")
		_return_to_idle()
		return

	var missile_count := 6 if is_enraged else 3
	for index in range(missile_count):
		var spawn_offset := Vector2.RIGHT.rotated(TAU * float(index) / missile_count) * 90.0
		var missile := missile_scene.instantiate() as Node2D
		if missile == null:
			push_error("Boss missile_scene must have a Node2D root.")
			continue
		get_parent().add_child(missile)
		missile.global_position = global_position + spawn_offset
		missile.look_at(player.global_position)
	await get_tree().create_timer(summon_attack_duration).timeout
	if _is_defeated:
		return
	_return_to_idle()


func _spawn_swarm() -> void:
	current_state = BossState.SWARM
	sprite.play("summon")
	if spider_scene == null:
		push_error("Boss requires spider_scene for the SWARM attack.")
		_return_to_idle()
		return

	var spider_count := 8 if is_enraged else 5
	for _index in range(spider_count):
		var spider := spider_scene.instantiate() as Node2D
		if spider == null:
			push_error("Boss spider_scene must have a Node2D root.")
			continue
		get_parent().add_child(spider)
		spider.global_position = global_position + Vector2(
			randf_range(-100.0, 100.0),
			randf_range(-100.0, 100.0)
		)
	await get_tree().create_timer(summon_attack_duration).timeout
	if _is_defeated:
		return
	_return_to_idle()


func _start_slam(player: Node2D) -> void:
	current_state = BossState.SLAM
	_slam_target = player.global_position
	sprite.play("embestida")
	$SfxSlam.play()


func _damage_laser_overlaps() -> void:
	if _laser_damage_cooldown > 0.0:
		return
	for body in laser_hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage()
			_laser_damage_cooldown = 0.5
			return


func _on_laser_body_entered(body: Node2D) -> void:
	if current_state == BossState.LASER and body.is_in_group("player"):
		_damage_laser_overlaps()


func _return_to_idle() -> void:
	if _is_defeated:
		return
	_disable_laser()
	velocity = Vector2.ZERO
	current_state = BossState.IDLE
	sprite.play("idle")
	_start_attack_timer()


func _disable_laser() -> void:
	_laser_charging = false
	laser_hitbox.monitoring = false
	laser_collision.set_deferred("disabled", true)
	laser_line.width = 2.0
	laser_pivot.hide()


func take_damage(damage_amount: int = 1) -> bool:
	var damage_applied := health_component.take_damage(damage_amount)
	if damage_applied:
		health_bar.set_health(health_component.current_health)
		_update_enrage_state(health_component.current_health)
		$SfxHit.play()
	return damage_applied


func _on_health_took_damage(current_health: int, _damage_amount: int) -> void:
	if _is_defeated:
		return
	health_bar.set_health(current_health)
	_update_enrage_state(current_health)
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _update_enrage_state(current_health: int) -> void:
	if not is_enraged and current_health * 2 < max_health:
		is_enraged = true
		health_bar.set_enraged()


func _on_health_died() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	attack_timer.stop()
	health_bar.fade_out()
	_disable_laser()
	velocity = Vector2.ZERO
	current_state = BossState.IDLE
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	sprite.play("death")
	await sprite.animation_finished
	defeated.emit()
	queue_free()
