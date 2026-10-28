class_name CorruptedSoldier
extends CharacterBody2D

## Soldado Cero: un soldado Chronos contaminado por la Colmena. Pelea como el
## protagonista: se mueve de lado manteniendo distancia, hace dash (las balas
## lo atraviesan mientras dura) y dispara ráfagas de plasma avisando antes con
## una línea roja de mira. Desde la mitad de vida se enfurece: escopeta en
## abanico, granadas tóxicas y su propio ataque orbital. Al bajar del 66 % y
## del 33 % de vida se cubre con un escudo que hay que romper.

signal defeated

enum Attack { BURST, SHOTGUN, GRENADE, ORBITAL }

const BULLET_SCENE: PackedScene = preload("res://enemy/enemy_bullet.tscn")
const BULLET_COLOR: Color = Color(0.85, 0.4, 1.0)
const DASH_SPEED: float = 950.0
const DASH_DURATION: float = 0.2
const AIM_DISTANCE: float = 400.0
const SHIELD_THRESHOLDS: Array[float] = [0.66, 0.33]
const ORBITAL_COOLDOWN: float = 11.0

@export_range(1, 5000, 1) var max_health: int = 420
@export var move_speed: float = 240.0
@export var preferred_distance: float = 380.0

## Veces que este jefe ya apareció (1 = la primera, en la oleada 10).
var tier: int = 1
## Si es true, espera a start_fight() para atacar (entrada cinemática).
var intro_mode: bool = false
var intro_title: String = "SOLDADO CERO"
var intro_subtitle: String = "EL PRIMERO QUE CAYÓ"
var intro_color: Color = Color(0.8, 0.35, 1.0)
var is_enraged: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: BossHealthBar = $BossHealthBar
@onready var hit_flash: HitFlashComponent = $HitFlashComponent

var _aim_rig: SoldierAimRig
var _overlay: Node2D
var _aggression: float = 1.0
var _attack_cooldown: float = 1.5
var _dash_cooldown: float = 3.0
var _orbital_cooldown: float = 0.0
var _dash_time: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _trail_time: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 2.0
var _busy: bool = false
var _attack_tween: Tween
var _aim_angle: float = PI * 0.5
var _aim_locked: bool = false
var _telegraph: float = 0.0
var _telegraph_spread: float = 0.0
var _shield: int = 0
var _shield_max: int = 0
var _shields_used: int = 0
var _is_defeated: bool = false
var _time: float = 0.0


## Ajusta vida y agresividad según cuántas veces ha salido. Se llama antes
## de añadirlo al árbol.
func configure(new_tier: int) -> void:
	tier = maxi(1, new_tier)
	max_health = 300 + 120 * tier
	_aggression = 1.0 + 0.15 * (tier - 1)


func _ready() -> void:
	health_component.max_health = max_health
	health_component.current_health = max_health
	health_component.took_damage.connect(_on_health_took_damage)
	health_component.died.connect(_on_health_died)
	health_bar.setup(max_health)
	if intro_mode:
		health_bar.visible = false
	_build_aim_rig()
	_overlay = Node2D.new()
	_overlay.z_index = 3
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_aim_angle = global_position.direction_to(player.global_position).angle()


## Termina la entrada: aparece la barra de vida y empiezan los ataques.
func start_fight() -> void:
	intro_mode = false
	health_bar.visible = true
	_attack_cooldown = 1.0


func intro_roar() -> void:
	_aim_rig.play_flash()
	_set_glitch(1.0)


func intro_settle() -> void:
	_set_glitch(0.3)


func _physics_process(delta: float) -> void:
	if _is_defeated:
		return
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or intro_mode:
		velocity = Vector2.ZERO
		_update_aim(player, delta)
		_update_visuals(delta)
		return

	var scaled := delta * _aggression
	_attack_cooldown -= scaled
	_dash_cooldown -= scaled
	_orbital_cooldown -= scaled

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_direction * DASH_SPEED
		move_and_slide()
		_trail_time -= delta
		if _trail_time <= 0.0:
			_spawn_dash_trail()
			_trail_time = 0.035
		_update_visuals(delta)
		return

	_move(player, delta)
	_update_aim(player, delta)

	if not _busy and _attack_cooldown <= 0.0 and not player.is_dead:
		_start_attack(player)
	elif not _busy and _dash_cooldown <= 0.0:
		_start_dash(player)
	_update_visuals(delta)


# Se mantiene a cierta distancia del soldado y lo rodea de lado. La distancia
# vertical cuenta más (elipse) para que no se salga por arriba o por abajo de
# la pantalla, que es más baja que ancha.
func _move(player: Node2D, delta: float) -> void:
	var to_player := player.global_position - global_position
	var distance := Vector2(to_player.x, to_player.y * 1.7).length()
	var forward := to_player / maxf(distance, 1.0)
	var radial := forward * clampf((distance - preferred_distance) / 150.0, -1.0, 1.0)
	var tangent := forward.orthogonal() * _strafe_sign
	var wish := (radial + tangent * 0.8).normalized()
	var speed := move_speed * (1.0 + 0.1 * (tier - 1))
	if _busy:
		speed *= 0.45
	velocity = velocity.lerp(wish * speed, 1.0 - exp(-8.0 * delta))
	move_and_slide()

	_strafe_timer -= delta
	if _strafe_timer <= 0.0 or get_slide_collision_count() > 0:
		_strafe_sign = -_strafe_sign
		_strafe_timer = randf_range(1.4, 3.0)


func _update_aim(player: Node2D, delta: float) -> void:
	if player == null or _aim_locked:
		return
	var wanted := _muzzle_position().direction_to(player.global_position).angle()
	_aim_angle = lerp_angle(_aim_angle, wanted, minf(1.0, 9.0 * delta))


func _start_dash(player: Node2D) -> void:
	var side := global_position.direction_to(player.global_position).orthogonal()
	_dash_direction = side * (1.0 if randf() < 0.5 else -1.0)
	_dash_time = DASH_DURATION
	_dash_cooldown = randf_range(2.2, 3.8)
	_trail_time = 0.0


func _spawn_dash_trail() -> void:
	var trail := sprite.duplicate(0) as AnimatedSprite2D
	trail.material = null
	for child in trail.get_children():
		child.queue_free()
	trail.self_modulate = Color.WHITE
	trail.modulate = Color(0.75, 0.3, 1.0, 0.55)
	trail.z_index = -1
	trail.stop()
	get_parent().add_child(trail)
	trail.global_transform = sprite.global_transform
	var tween := trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.18)
	tween.tween_callback(trail.queue_free)


# --- Ataques -------------------------------------------------------------------

func _start_attack(player: Node2D) -> void:
	var options: Array[Attack] = [Attack.BURST, Attack.BURST, Attack.GRENADE]
	if is_enraged:
		options = [Attack.BURST, Attack.SHOTGUN, Attack.SHOTGUN, Attack.GRENADE]
		if _orbital_cooldown <= 0.0:
			options.append(Attack.ORBITAL)
			options.append(Attack.ORBITAL)
	_busy = true
	match options.pick_random():
		Attack.BURST:
			_burst()
		Attack.SHOTGUN:
			_shotgun()
		Attack.GRENADE:
			_grenades(player)
		Attack.ORBITAL:
			_orbital(player)


# Línea roja de mira y luego una ráfaga de plasma.
func _burst() -> void:
	var shots := mini(5 + tier, 10)
	_attack_tween = create_tween()
	_attack_tween.tween_method(_set_telegraph.bind(0.0), 0.0, 1.0, 0.75 / _aggression)
	for index in shots:
		_attack_tween.tween_callback(_fire_bullets.bind(1, 0.0, 0.05))
		_attack_tween.tween_interval(0.09)
	_attack_tween.tween_callback(_finish_attack.bind(randf_range(1.5, 2.3)))


# Abanico de perdigones; furioso dispara dos veces.
func _shotgun() -> void:
	var pellets := 7 + mini(tier - 1, 4)
	var spread := deg_to_rad(55.0)
	_attack_tween = create_tween()
	_attack_tween.tween_method(_set_telegraph.bind(spread), 0.0, 1.0, 0.55 / _aggression)
	_attack_tween.tween_callback(_fire_bullets.bind(pellets, spread, 0.0))
	if tier >= 2 or randf() < 0.5:
		_attack_tween.tween_method(_set_telegraph.bind(spread), 0.0, 1.0, 0.4 / _aggression)
		_attack_tween.tween_callback(_fire_bullets.bind(pellets, spread, 0.0))
	_attack_tween.tween_callback(_finish_attack.bind(randf_range(1.3, 2.0)))


# Granadas tóxicas: una normal, tres furioso.
func _grenades(player: Node2D) -> void:
	var count := 3 if is_enraged else 1
	_attack_tween = create_tween()
	_attack_tween.tween_interval(0.25)
	for index in count:
		_attack_tween.tween_callback(_throw_grenade.bind(player, index))
		_attack_tween.tween_interval(0.22)
	_attack_tween.tween_callback(_finish_attack.bind(randf_range(1.2, 1.8)))


func _throw_grenade(player: Node2D, index: int) -> void:
	if not is_instance_valid(player):
		return
	var target: Vector2 = player.global_position + (player as CharacterBody2D).velocity * 0.45
	if index > 0:
		target += Vector2.from_angle(randf() * TAU) * randf_range(90.0, 180.0)
	var grenade := ToxicGrenade.new()
	grenade.from = _muzzle_position()
	grenade.to = target
	get_parent().add_child(grenade)
	_aim_rig.play_flash()
	Sfx.play("click", -4.0, 0.1)


# Baliza roja sobre el soldado: a los pocos segundos cae un orbital.
func _orbital(player: Node2D) -> void:
	_orbital_cooldown = ORBITAL_COOLDOWN
	var strike := EnemyStrike.new()
	strike.delay = maxf(1.1, 1.7 - 0.1 * (tier - 1))
	get_parent().add_child(strike)
	strike.global_position = player.global_position
	_aim_rig.play_flash()
	Sfx.play("hover", 0.0, 0.0)
	_attack_tween = create_tween()
	_attack_tween.tween_interval(0.6)
	_attack_tween.tween_callback(_finish_attack.bind(1.0))


func _fire_bullets(count: int, spread: float, jitter: float) -> void:
	_telegraph = 0.0
	_aim_rig.play_flash()
	$SfxShoot.play()
	var speed := 540.0 * (1.0 + 0.08 * (tier - 1))
	for index in count:
		var offset := 0.0 if count == 1 else lerpf(-spread * 0.5, spread * 0.5, float(index) / (count - 1))
		var bullet = BULLET_SCENE.instantiate()
		bullet.speed = speed
		bullet.modulate = BULLET_COLOR
		bullet.scale = Vector2(0.75, 0.75)
		get_parent().add_child(bullet)
		bullet.global_position = _muzzle_position()
		bullet.global_rotation = _aim_angle + offset + randf_range(-jitter, jitter)


func _finish_attack(cooldown: float) -> void:
	_busy = false
	_telegraph = 0.0
	_attack_cooldown = cooldown
	# A veces esquiva justo después de atacar.
	if randf() < 0.35:
		_dash_cooldown = 0.0


func _set_telegraph(value: float, spread: float) -> void:
	_telegraph = value
	_telegraph_spread = spread
	# El último momento la mira se queda fija: hay tiempo para esquivar.
	_aim_locked = value > 0.85


# --- Daño, escudo y muerte ------------------------------------------------------

func take_damage(damage_amount: int = 1) -> bool:
	if _is_defeated or _dash_time > 0.0:
		# Durante el dash las balas lo atraviesan.
		return false
	if _shield > 0:
		_shield -= 1
		Sfx.play("click", -6.0, 0.15)
		if _shield == 0:
			CombatFx.death_burst(get_parent(), global_position, Color(0.7, 0.4, 1.0), 2.0)
			Sfx.play("explosion", -6.0, 0.0)
		return true
	return health_component.take_damage(damage_amount)


func _on_health_took_damage(current_health: int, _damage_amount: int) -> void:
	if _is_defeated:
		return
	health_bar.set_health(current_health)
	hit_flash.flash()
	var ratio := float(current_health) / max_health
	if not is_enraged and ratio < 0.5:
		is_enraged = true
		health_bar.set_enraged()
		_set_glitch(0.8)
	if _shields_used < SHIELD_THRESHOLDS.size() and ratio < SHIELD_THRESHOLDS[_shields_used] and current_health > 0:
		_shields_used += 1
		_shield_max = 10 + 4 * tier
		_shield = _shield_max
		Sfx.play("hover", 2.0, 0.0)


func _on_health_died() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	if _attack_tween != null:
		_attack_tween.kill()
	_telegraph = 0.0
	_shield = 0
	health_bar.fade_out()
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	_aim_rig.visible = false
	sprite.self_modulate.a = 1.0
	sprite.play("death")
	await sprite.animation_finished
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tween.finished
	defeated.emit()
	queue_free()


# --- Dibujo -------------------------------------------------------------------

func _build_aim_rig() -> void:
	_aim_rig = SoldierAimRig.new()
	sprite.add_child(_aim_rig)
	_aim_rig.setup(sprite.offset - Vector2(SoldierAimRig.CELL_SIZE) * 0.5)
	# Las capas del rig usan el shader de contaminación del sprite.
	_aim_rig.use_parent_material = true
	for child in _aim_rig.find_children("*", "CanvasItem", true, false):
		(child as CanvasItem).use_parent_material = true


func _update_visuals(delta: float) -> void:
	var face_left := cos(_aim_angle) < 0.0
	sprite.flip_h = face_left
	_aim_rig.scale.x = -1.0 if face_left else 1.0
	if _dash_time > 0.0:
		_aim_rig.visible = false
		sprite.self_modulate.a = 1.0
		sprite.play("dash")
	else:
		_aim_rig.visible = true
		sprite.self_modulate.a = 0.0
		var moving := velocity.length() > 20.0
		var backwards := moving and velocity.x * (-1.0 if face_left else 1.0) < -20.0
		var target := global_position + Vector2.from_angle(_aim_angle) * AIM_DISTANCE
		_aim_rig.update_pose(target, moving, backwards, delta)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	if _telegraph > 0.0:
		var start := _overlay.to_local(_muzzle_position())
		var color := Color(1.0, 0.15, 0.2, 0.25 + 0.6 * _telegraph)
		var width := 1.5 + 3.0 * _telegraph
		if _telegraph_spread <= 0.0:
			_overlay_line(start, start + Vector2.from_angle(_aim_angle) * 1500.0, color, width)
		else:
			var length := 520.0
			var left := start + Vector2.from_angle(_aim_angle - _telegraph_spread * 0.5) * length
			var right := start + Vector2.from_angle(_aim_angle + _telegraph_spread * 0.5) * length
			_overlay.draw_colored_polygon(PackedVector2Array([start, left, right]), Color(1.0, 0.15, 0.2, 0.12 + 0.2 * _telegraph))
			_overlay_line(start, left, color, width)
			_overlay_line(start, right, color, width)
	if _shield > 0:
		var center := Vector2(0, 0)
		var pulse := 0.85 + 0.15 * sin(_time * 6.0)
		_overlay.draw_circle(center, 95.0, Color(0.6, 0.25, 1.0, 0.18 * pulse))
		_overlay.draw_arc(center, 95.0, 0.0, TAU, 48, Color(0.75, 0.4, 1.0, 0.5), 3.0)
		var ratio := float(_shield) / _shield_max
		_overlay.draw_arc(center, 103.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 48, Color(0.5, 1.0, 0.4, 0.9), 5.0)


func _overlay_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	_overlay.draw_line(from, to, color, width)


func _muzzle_position() -> Vector2:
	if _aim_rig != null and _aim_rig.visible:
		return _aim_rig.get_gun_tip_position()
	return global_position + Vector2(0, -20)


func _set_glitch(value: float) -> void:
	var material := sprite.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("glitch", value)


## Granada tóxica: vuela en arco, avisa con un círculo y explota.
class ToxicGrenade:
	extends Node2D

	const COLOR: Color = Color(0.45, 1.0, 0.35)
	const FLIGHT_TIME: float = 0.6
	const FUSE_TIME: float = 0.55
	const RADIUS: float = 140.0

	var from: Vector2
	var to: Vector2
	var _time: float = 0.0
	var _landed: bool = false

	func _ready() -> void:
		z_index = 4
		global_position = from

	func _process(delta: float) -> void:
		_time += delta
		if not _landed:
			var progress := minf(_time / FLIGHT_TIME, 1.0)
			global_position = from.lerp(to, progress)
			if progress >= 1.0:
				_landed = true
				_time = 0.0
		elif _time >= FUSE_TIME:
			_explode()
			return
		queue_redraw()

	func _draw() -> void:
		if not _landed:
			var height := sin(_time / FLIGHT_TIME * PI) * 120.0
			draw_circle(Vector2(0, 8), 8.0, Color(0, 0, 0, 0.3))
			draw_circle(Vector2(0, -height), 9.0, Color(0.1, 0.15, 0.1))
			draw_circle(Vector2(0, -height), 6.0, COLOR)
			return
		var blink := 0.5 + 0.5 * sin(_time * 30.0)
		draw_circle(Vector2.ZERO, RADIUS, Color(COLOR, 0.08 + 0.12 * blink))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(COLOR, 0.8), 3.0)
		draw_arc(Vector2.ZERO, RADIUS * _time / FUSE_TIME, 0.0, TAU, 40, Color(COLOR, 0.5), 2.0)
		draw_circle(Vector2.ZERO, 8.0, Color(COLOR, blink))

	func _explode() -> void:
		CombatFx.explosion(get_parent(), global_position, RADIUS, COLOR)
		Sfx.play("explosion", -4.0, 0.1)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(global_position) <= RADIUS:
			player.take_damage(1)
		queue_free()


## Orbital del Soldado Cero: anillo rojo que se cierra y luego la explosión.
class EnemyStrike:
	extends Node2D

	const COLOR: Color = Color(1.0, 0.2, 0.25)
	const RADIUS: float = 210.0

	var delay: float = 1.6
	var _time: float = 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_time += delta
		if _time >= delay:
			_strike()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := _time / delay
		var blink := 0.5 + 0.5 * sin(_time * (10.0 + 20.0 * progress))
		draw_circle(Vector2.ZERO, RADIUS, Color(COLOR, 0.06 + 0.14 * progress))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 56, Color(COLOR, 0.9), 3.0)
		draw_arc(Vector2.ZERO, RADIUS * (1.0 - progress), 0.0, TAU, 56, Color(1, 0.6, 0.5, 0.7), 2.0)
		var width := 6.0 + 8.0 * progress
		draw_rect(Rect2(-width * 0.5, -1600.0, width, 1600.0), Color(COLOR, 0.25 + 0.35 * blink))
		draw_circle(Vector2.ZERO, 10.0, Color(1, 1, 1, blink))

	func _strike() -> void:
		CombatFx.explosion(get_parent(), global_position, RADIUS, COLOR)
		Sfx.play("explosion", 0.0, 0.0)
		var screen_shake := get_tree().get_first_node_in_group("screen_shake")
		if screen_shake != null:
			screen_shake.shake()
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(global_position) <= RADIUS:
			player.take_damage(2)
		queue_free()
