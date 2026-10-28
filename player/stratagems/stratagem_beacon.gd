class_name StratagemBeacon
extends Node2D

## Baliza de estratagema: vuela hasta el punto apuntado, marca la zona con un
## haz de luz y, tras la espera, cae el ataque orbital, el bombardeo en línea
## del ataque aéreo, el pulso EMS que paraliza a los enemigos, o la cápsula
## con la caja de suministros o la torreta.

const FLIGHT_TIME: float = 0.45
const CALL_IN_TIME: float = 2.0
const ORBITAL_RADIUS: float = 280.0
const ORBITAL_DAMAGE: int = 12
const POD_FALL_TIME: float = 0.55
const AIRSTRIKE_BOMBS: int = 6
const AIRSTRIKE_SPACING: float = 95.0
const AIRSTRIKE_RADIUS: float = 130.0
const AIRSTRIKE_DAMAGE: int = 6
const EMS_RADIUS: float = 340.0
const EMS_DAMAGE: int = 1
const EMS_STUN_TIME: float = 5.0
const POD_TEXTURE: Texture2D = preload("res://menu/intro_art/08_capsula.png")
const CRATE_SCENE: PackedScene = preload("res://player/stratagems/supply_crate.tscn")
const TURRET_SCENE: PackedScene = preload("res://player/stratagems/sentry_turret.tscn")

var id: String = ""
var color: Color = Color.WHITE
var _target: Vector2
var _throw_direction: Vector2 = Vector2.RIGHT
var _time: float = 0.0
var _phase: String = "flight"
var _strike_radius: float = 0.0
var _strike_alpha: float = 0.0


func setup(stratagem_id: String, beam_color: Color, from: Vector2, target: Vector2) -> void:
	id = stratagem_id
	color = beam_color
	global_position = from
	_target = target
	if from.distance_to(target) > 1.0:
		_throw_direction = from.direction_to(target)


func _ready() -> void:
	z_index = 5
	var tween := create_tween()
	tween.tween_property(self, "global_position", _target, FLIGHT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _phase = "beam")
	tween.tween_interval(CALL_IN_TIME)
	tween.tween_callback(_arrive)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var blink := 0.6 + 0.4 * sin(_time * 18.0)
	if _phase != "done":
		draw_circle(Vector2.ZERO, 10.0, Color(color, blink))
		draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, blink))
	if _phase == "beam":
		# Haz de luz hacia el cielo y anillo en el suelo.
		var width := 10.0 + 4.0 * sin(_time * 10.0)
		draw_rect(Rect2(-width * 0.5, -1600.0, width, 1600.0), Color(color, 0.45))
		draw_rect(Rect2(-width * 0.15, -1600.0, width * 0.3, 1600.0), Color(1, 1, 1, 0.6))
		var ring := 30.0 + fmod(_time * 120.0, 90.0)
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, Color(color, 1.0 - (ring - 30.0) / 90.0), 3.0)
	if _strike_alpha > 0.0:
		draw_circle(Vector2.ZERO, _strike_radius, Color(1, 0.6, 0.2, _strike_alpha * 0.5))
		draw_circle(Vector2.ZERO, _strike_radius * 0.55, Color(1, 0.95, 0.7, _strike_alpha))
		draw_arc(Vector2.ZERO, _strike_radius, 0.0, TAU, 64, Color(1, 0.4, 0.1, _strike_alpha), 8.0)


func _arrive() -> void:
	match id:
		"orbital":
			_orbital_strike()
		"airstrike":
			_airstrike()
		"ems":
			_ems_pulse()
		_:
			_drop_pod()


func _orbital_strike() -> void:
	_phase = "done"
	_damage_enemies(ORBITAL_RADIUS, ORBITAL_DAMAGE)
	_impact_feedback(2.0)
	var burst := IntroFx.burst(200)
	add_child(burst)
	burst.emitting = true
	_strike_alpha = 1.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_strike_radius", ORBITAL_RADIUS, 0.25).from(40.0)
	tween.tween_property(self, "_strike_alpha", 0.0, 0.9)
	tween.chain().tween_interval(1.0)
	tween.chain().tween_callback(queue_free)


## Un caza cruza la pantalla y suelta una fila de bombas en la dirección en
## que se lanzó la baliza.
func _airstrike() -> void:
	_phase = "done"
	var jet := _Jet.new()
	jet.direction = _throw_direction
	add_child(jet)
	var half := (AIRSTRIKE_BOMBS - 1) * 0.5
	var tween := create_tween()
	tween.tween_interval(0.25)
	for index in AIRSTRIKE_BOMBS:
		var offset := _throw_direction * (index - half) * AIRSTRIKE_SPACING
		tween.tween_callback(_bomb.bind(global_position + offset))
		tween.tween_interval(0.09)
	tween.tween_interval(1.0)
	tween.tween_callback(queue_free)


func _bomb(at: Vector2) -> void:
	CombatFx.explosion(get_parent(), at, AIRSTRIKE_RADIUS)
	_damage_enemies(AIRSTRIKE_RADIUS, AIRSTRIKE_DAMAGE, at)
	Sfx.play("explosion", -3.0, 0.15)
	var screen_shake := get_tree().get_first_node_in_group("screen_shake")
	if screen_shake != null:
		screen_shake.shake()


## Onda eléctrica: daña un poco y paraliza a los enemigos (no a los jefes).
func _ems_pulse() -> void:
	_phase = "done"
	Sfx.play("explosion", -6.0, 0.0)
	var wave := CombatFx.Shockwave.new()
	wave.radius = EMS_RADIUS
	wave.color = color
	wave.duration = 0.6
	add_child(wave)
	var inner := CombatFx.Shockwave.new()
	inner.radius = EMS_RADIUS * 0.6
	inner.color = Color(0.85, 0.9, 1.0)
	inner.duration = 0.4
	add_child(inner)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or enemy.global_position.distance_to(global_position) > EMS_RADIUS:
			continue
		if not enemy.is_in_group("boss"):
			StunEffect.apply(enemy, EMS_STUN_TIME)
	_damage_enemies(EMS_RADIUS, EMS_DAMAGE)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(queue_free)


func _drop_pod() -> void:
	var pod := Sprite2D.new()
	pod.texture = POD_TEXTURE
	pod.scale = Vector2(0.22, 0.22)
	pod.position = Vector2(-420, -1100)
	add_child(pod)
	var trail := IntroFx.fire_trail(Vector2(-0.4, -1))
	trail.amount = 60
	pod.add_child(trail)
	trail.show_behind_parent = true
	var tween := create_tween()
	tween.tween_property(pod, "position", Vector2(0, -40), POD_FALL_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_phase = "done"
		trail.emitting = false
		_impact_feedback(-2.0)
		# La cápsula también daña a lo que aplasta.
		_damage_enemies(120.0, 4)
		var burst := IntroFx.burst(90)
		add_child(burst)
		burst.emitting = true
		_spawn_payload())
	tween.tween_interval(0.6)
	tween.tween_property(pod, "modulate:a", 0.0, 0.5)
	tween.tween_interval(1.0)
	tween.tween_callback(queue_free)


func _spawn_payload() -> void:
	var scene := CRATE_SCENE if id == "supply" else TURRET_SCENE
	var payload := scene.instantiate() as Node2D
	get_parent().add_child(payload)
	payload.global_position = global_position + Vector2(0, 30)


func _damage_enemies(radius: float, damage: int, center: Variant = null) -> void:
	var origin: Vector2 = global_position if center == null else center
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		var area := hurtbox as Area2D
		if area == null or area.global_position.distance_to(origin) > radius:
			continue
		var target := area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(damage)
		else:
			var health_component: Variant = target.get_node_or_null("HealthComponent")
			if health_component != null:
				health_component.take_damage(damage)


func _impact_feedback(volume_db: float) -> void:
	Sfx.play("explosion", volume_db, 0.05)
	var screen_shake := get_tree().get_first_node_in_group("screen_shake")
	if screen_shake != null:
		screen_shake.shake()


## Sombra del caza del ataque aéreo, que cruza a toda velocidad.
class _Jet:
	extends Node2D

	var direction: Vector2 = Vector2.RIGHT
	var _time: float = 0.0

	func _ready() -> void:
		z_index = 8
		rotation = direction.angle()
		position = -direction * 900.0
		var tween := create_tween()
		tween.tween_property(self, "position", direction * 900.0, 0.9)
		tween.tween_callback(queue_free)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var body := PackedVector2Array([
			Vector2(70, 0), Vector2(-10, -18), Vector2(-20, -70), Vector2(-40, -70),
			Vector2(-35, -12), Vector2(-60, -10), Vector2(-70, -30), Vector2(-80, -30),
			Vector2(-75, 0), Vector2(-80, 30), Vector2(-70, 30), Vector2(-60, 10),
			Vector2(-35, 12), Vector2(-40, 70), Vector2(-20, 70), Vector2(-10, 18),
		])
		draw_colored_polygon(body, Color(0, 0, 0, 0.45))
		draw_circle(Vector2(-85, 0), 10.0 + 3.0 * sin(_time * 40.0), Color(1.0, 0.7, 0.3, 0.7))
