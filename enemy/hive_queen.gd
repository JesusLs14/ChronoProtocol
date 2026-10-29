class_name HiveQueen
extends CharacterBody2D

## Reina de la Colmena: jefe enorme y lento que se queda a distancia del
## soldado. Ataques:
## - Puesta: deja huevos a su alrededor; si no se rompen a tiempo, de cada
##   uno salen arañas.
## - Escupitajo ácido: lanza globos de ácido que dejan charcos que queman.
## - Chillido: anillo de proyectiles en todas direcciones.
## Bajo la mitad de vida se enfurece: más huevos, más ácido y anillos dobles.
##
## Sprites: queen_art/ (generados con Gemini y limpiados con prepare_queen_art.py).

signal defeated

enum Attack { EGGS, ACID, SCREECH }

const BULLET_SCENE: PackedScene = preload("res://enemy/enemy_bullet.tscn")
const SPIDER_SCENE: PackedScene = preload("res://enemy/spider_minion.tscn")
const ACID_COLOR: Color = Color(0.5, 1.0, 0.3)
const MAX_EGGS: int = 10

@export_range(1, 5000, 1) var max_health: int = 700
@export var move_speed: float = 70.0
@export var preferred_distance: float = 380.0

var tier: int = 2
var intro_mode: bool = false
var intro_title: String = "REINA DE LA COLMENA"
var intro_subtitle: String = "MADRE DEL ENJAMBRE"
var intro_color: Color = Color(1.0, 0.3, 0.85)
var is_enraged: bool = false
## Cuerpo visible (lo usa la entrada cinemática para hacerla caer).
var sprite: Node2D

@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: BossHealthBar = $BossHealthBar

var _aggression: float = 1.0
var _attack_cooldown: float = 2.0
var _busy: bool = false
var _attack_tween: Tween
var _is_defeated: bool = false
var _flash_tween: Tween


## Vida y agresividad según el nivel del jefe (2 = oleada 15).
func configure(new_tier: int) -> void:
	tier = maxi(1, new_tier)
	max_health = 400 + 150 * tier
	_aggression = 1.0 + 0.12 * (tier - 2)


func _ready() -> void:
	sprite = QueenBody.new()
	sprite.name = "Body"
	add_child(sprite)
	health_component.max_health = max_health
	health_component.current_health = max_health
	health_component.took_damage.connect(_on_health_took_damage)
	health_component.died.connect(_on_health_died)
	health_bar.setup(max_health)
	if intro_mode:
		health_bar.visible = false


func start_fight() -> void:
	intro_mode = false
	health_bar.visible = true
	_attack_cooldown = 1.2


func intro_roar() -> void:
	(sprite as QueenBody).screech()


func intro_settle() -> void:
	pass


func _physics_process(delta: float) -> void:
	if _is_defeated or intro_mode:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	# Se acerca o se aleja despacio para mantener la distancia. La vertical
	# cuenta más para que no quede tapada por la barra de vida.
	var to_player := player.global_position - global_position
	var distance := Vector2(to_player.x, to_player.y * 1.8).length()
	var push := clampf((distance - preferred_distance) / 200.0, -1.0, 1.0)
	velocity = to_player.normalized() * push * move_speed * (0.4 if _busy else 1.0)
	move_and_slide()
	(sprite as QueenBody).facing_left = to_player.x < 0.0

	_attack_cooldown -= delta * _aggression
	if not _busy and _attack_cooldown <= 0.0 and not player.is_dead:
		_start_attack(player)


func _start_attack(player: Node2D) -> void:
	_busy = true
	var options: Array[Attack] = [Attack.EGGS, Attack.ACID, Attack.ACID, Attack.SCREECH]
	if _egg_count() >= MAX_EGGS:
		options.erase(Attack.EGGS)
	match options.pick_random():
		Attack.EGGS:
			_lay_eggs()
		Attack.ACID:
			_spit_acid(player)
		Attack.SCREECH:
			_screech()


func _lay_eggs() -> void:
	var count := (4 if is_enraged else 3) + mini(tier - 2, 2)
	(sprite as QueenBody).lay()
	_attack_tween = create_tween()
	_attack_tween.tween_interval(0.6)
	for index in count:
		_attack_tween.tween_callback(_drop_egg.bind(TAU * index / count + randf_range(-0.3, 0.3)))
		_attack_tween.tween_interval(0.18)
	_attack_tween.tween_callback(_finish_attack.bind(2.2))


func _drop_egg(angle: float) -> void:
	var egg := QueenEgg.new()
	egg.hatch_time = maxf(3.5, 6.0 - 0.4 * (tier - 2))
	egg.spiders = 2 + (1 if is_enraged else 0)
	get_parent().add_child(egg)
	var main := get_tree().get_first_node_in_group("main")
	var target := global_position + Vector2.from_angle(angle) * randf_range(170.0, 260.0)
	if main != null and main.has_method("clamp_to_arena"):
		target = main.clamp_to_arena(target)
	egg.global_position = target
	Sfx.play("pickup", -6.0, 0.3)


func _spit_acid(player: Node2D) -> void:
	var count := (5 if is_enraged else 3) + mini(tier - 2, 2)
	(sprite as QueenBody).screech()
	_attack_tween = create_tween()
	_attack_tween.tween_interval(0.45)
	for index in count:
		_attack_tween.tween_callback(_throw_acid.bind(player, index))
		_attack_tween.tween_interval(0.16)
	_attack_tween.tween_callback(_finish_attack.bind(1.8))


func _throw_acid(player: Node2D, index: int) -> void:
	if not is_instance_valid(player):
		return
	var target: Vector2 = player.global_position + (player as CharacterBody2D).velocity * 0.5
	if index > 0:
		target += Vector2.from_angle(randf() * TAU) * randf_range(60.0, 200.0)
	var glob := AcidGlob.new()
	glob.from = global_position + Vector2(0, -30)
	glob.to = target
	get_parent().add_child(glob)
	Sfx.play("flame", -8.0, 0.2)


func _screech() -> void:
	(sprite as QueenBody).screech()
	_attack_tween = create_tween()
	_attack_tween.tween_interval(0.55)
	_attack_tween.tween_callback(_fire_ring.bind(0.0))
	if is_enraged:
		_attack_tween.tween_interval(0.35)
		_attack_tween.tween_callback(_fire_ring.bind(0.5))
	_attack_tween.tween_callback(_finish_attack.bind(1.6))


func _fire_ring(offset: float) -> void:
	var count := 12 + 2 * (tier - 2)
	Sfx.play("explosion", -10.0, 0.0)
	var screen_shake := get_tree().get_first_node_in_group("screen_shake")
	if screen_shake != null:
		screen_shake.shake()
	for index in count:
		var bullet = BULLET_SCENE.instantiate()
		bullet.speed = 300.0 + 20.0 * (tier - 2)
		bullet.modulate = Color(1.0, 0.4, 0.9)
		bullet.scale = Vector2(0.8, 0.8)
		get_parent().add_child(bullet)
		var angle := TAU * (index + offset) / count
		bullet.global_position = global_position + Vector2.from_angle(angle) * 80.0
		bullet.global_rotation = angle


func _finish_attack(cooldown: float) -> void:
	_busy = false
	_attack_cooldown = cooldown * (0.7 if is_enraged else 1.0)


func _egg_count() -> int:
	return get_tree().get_nodes_in_group("queen_eggs").size()


func take_damage(damage_amount: int = 1) -> bool:
	if _is_defeated:
		return false
	return health_component.take_damage(damage_amount)


func _on_health_took_damage(current_health: int, _damage_amount: int) -> void:
	if _is_defeated:
		return
	health_bar.set_health(current_health)
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if not is_enraged and current_health * 2 < max_health:
		is_enraged = true
		health_bar.set_enraged()
		(sprite as QueenBody).enraged = true


func _on_health_died() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	if _attack_tween != null:
		_attack_tween.kill()
	health_bar.fade_out()
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	# Los huevos que quedan se pudren con ella.
	for egg in get_tree().get_nodes_in_group("queen_eggs"):
		egg.queue_free()
	var body := sprite as QueenBody
	body.dying = true
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.6)
	await tween.finished
	defeated.emit()
	queue_free()


## Cuerpo de la Reina con el sprite de queen_art/ (idle, poner huevos,
## chillido y muerte). Mantiene la misma interfaz que el cuerpo provisional:
## facing_left, enraged, dying, screech() y lay().
class QueenBody:
	extends AnimatedSprite2D

	const SHEET: Texture2D = preload("res://enemy/queen_art/hive_queen_sheet.png")
	const CELL := Vector2(364, 360)
	## Animación: [fila, cuadros, velocidad, bucle].
	const ANIMATIONS: Dictionary = {
		"idle": [0, 4, 6.0, true],
		"lay": [1, 7, 11.0, false],
		"screech": [2, 6, 11.0, false],
		"death": [3, 8, 7.0, false],
	}

	var facing_left: bool = false:
		set(value):
			facing_left = value
			# El sprite mira hacia la derecha; se voltea si el soldado está a la izquierda.
			flip_h = value
	var enraged: bool = false
	var dying: bool = false:
		set(value):
			dying = value
			if value:
				play("death")
	var _time: float = 0.0

	func _init() -> void:
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		for animation: String in ANIMATIONS:
			var data: Array = ANIMATIONS[animation]
			frames.add_animation(animation)
			frames.set_animation_speed(animation, data[2])
			frames.set_animation_loop(animation, data[3])
			for index in data[1]:
				var region := AtlasTexture.new()
				region.atlas = SHEET
				region.region = Rect2(Vector2(index, data[0]) * CELL, CELL)
				frames.add_frame(animation, region)
		sprite_frames = frames
		offset = Vector2(0, -15)
		scale = Vector2(1.15, 1.15)
		animation_finished.connect(_on_animation_finished)
		play("idle")

	func screech() -> void:
		if not dying:
			play("screech")

	func lay() -> void:
		if not dying:
			play("lay")

	func _process(delta: float) -> void:
		_time += delta
		# Furiosa late en rojo y rosa.
		if enraged and not dying:
			var pulse := 0.5 + 0.5 * sin(_time * 7.0)
			self_modulate = Color(1.0 + 0.35 * pulse, 0.85, 1.0 + 0.2 * pulse)
		else:
			self_modulate = Color.WHITE

	func _on_animation_finished() -> void:
		if not dying:
			play("idle")


## Huevo de la Reina: late, se agrieta y suelta arañas si no se rompe a tiempo.
## Se rompe a balazos como un enemigo (tiene hurtbox).
class QueenEgg:
	extends Node2D

	const MAX_HEALTH: int = 4
	const RADIUS: float = 26.0
	const EGG_SHEET: Texture2D = preload("res://enemy/queen_art/queen_egg_sheet.png")

	var hatch_time: float = 5.0
	var spiders: int = 2
	var _health: int = MAX_HEALTH
	var _time: float = 0.0
	var _broken: bool = false

	func _init() -> void:
		add_to_group("enemy")
		add_to_group("queen_eggs")
		var hurtbox := Area2D.new()
		hurtbox.name = "Hurtbox"
		hurtbox.collision_layer = 2
		hurtbox.collision_mask = 0
		hurtbox.monitoring = false
		hurtbox.add_to_group("enemy_hurtbox")
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = RADIUS
		shape.shape = circle
		hurtbox.add_child(shape)
		add_child(hurtbox)

	func _ready() -> void:
		z_index = 1
		scale = Vector2(0.2, 0.2)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_time += delta
		if _time >= hatch_time and not _broken:
			_hatch()
			return
		queue_redraw()

	func take_damage(damage_amount: int = 1) -> bool:
		if _broken or damage_amount <= 0:
			return false
		_health -= damage_amount
		CombatFx.damage_number(get_parent(), global_position + Vector2(0, -30), damage_amount, _health <= 0)
		if _health <= 0:
			_broken = true
			remove_from_group("enemy")
			CombatFx.death_burst(get_parent(), global_position, Color(0.85, 0.3, 0.9), 1.0)
			Sfx.play("explosion", -14.0, 0.3)
			queue_free()
		return true

	func _hatch() -> void:
		_broken = true
		remove_from_group("enemy")
		CombatFx.death_burst(get_parent(), global_position, ACID_COLOR, 1.2)
		Sfx.play("explosion", -10.0, 0.3)
		for index in spiders:
			var spider := SPIDER_SCENE.instantiate() as Node2D
			get_parent().add_child.call_deferred(spider)
			spider.position = position + Vector2.from_angle(TAU * index / spiders) * 30.0
		queue_free()

	func _draw() -> void:
		var progress := _time / hatch_time
		# Cuadros 0-2: late (más rápido cuanto más cerca de eclosionar);
		# 3-5: se agrieta en el último 25 %.
		var frame := int(_time * (3.0 + 6.0 * progress)) % 3
		if progress > 0.75:
			frame = 3 + mini(2, int((progress - 0.75) / 0.25 * 3.0))
		var cell := Vector2(EGG_SHEET.get_width() / 6.0, EGG_SHEET.get_height())
		var pulse := 1.0 + 0.05 * sin(_time * (4.0 + 10.0 * progress))
		var size := cell * 0.42 * pulse
		draw_texture_rect_region(EGG_SHEET, Rect2(Vector2(-size.x * 0.5, -size.y * 0.62), size), Rect2(Vector2(frame * cell.x, 0), cell))
		# Barra que avisa cuánto falta para que eclosione.
		draw_rect(Rect2(-22, -RADIUS - 22, 44, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-22, -RADIUS - 22, 44 * progress, 5), Color(1.0, 0.35, 0.8))


## Globo de ácido: vuela en arco y deja un charco que quema al soldado.
class AcidGlob:
	extends Node2D

	const FLIGHT_TIME: float = 0.7

	var from: Vector2
	var to: Vector2
	var _time: float = 0.0

	func _ready() -> void:
		z_index = 5
		global_position = from

	func _process(delta: float) -> void:
		_time += delta
		var progress := minf(_time / FLIGHT_TIME, 1.0)
		global_position = from.lerp(to, progress)
		if progress >= 1.0:
			var puddle := AcidPuddle.new()
			get_parent().add_child(puddle)
			puddle.global_position = global_position
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var height := sin(_time / FLIGHT_TIME * PI) * 140.0
		draw_circle(Vector2(0, 6), 9.0, Color(0, 0, 0, 0.3))
		draw_circle(Vector2(0, -height), 13.0, Color(0.25, 0.6, 0.15))
		draw_circle(Vector2(0, -height), 9.0, ACID_COLOR)


## Charco de ácido: quema al soldado si lo pisa y desaparece en unos segundos.
class AcidPuddle:
	extends Node2D

	const RADIUS: float = 80.0
	const LIFETIME: float = 4.5
	const TICK: float = 0.7

	var _time: float = 0.0
	var _tick: float = 0.0

	func _ready() -> void:
		z_index = -1

	func _process(delta: float) -> void:
		_time += delta
		_tick = maxf(0.0, _tick - delta)
		if _time >= LIFETIME:
			queue_free()
			return
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and _tick == 0.0 and player.global_position.distance_to(global_position) < RADIUS:
			_tick = TICK
			player.take_damage(1)
		queue_redraw()

	func _draw() -> void:
		var appear := minf(_time / 0.25, 1.0)
		var fade := minf((LIFETIME - _time) / 0.8, 1.0)
		var bubble := 0.85 + 0.15 * sin(_time * 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, RADIUS * appear, Color(0.3, 0.75, 0.15, 0.45 * fade))
		draw_circle(Vector2.ZERO, RADIUS * 0.7 * appear * bubble, Color(ACID_COLOR, 0.5 * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for index in 4:
			var spot := Vector2.from_angle(index * 1.7 + _time) * RADIUS * 0.45
			draw_circle(spot * Vector2(1.0, 0.6), 5.0, Color(0.85, 1.0, 0.6, 0.7 * fade))
