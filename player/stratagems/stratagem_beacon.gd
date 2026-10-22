class_name StratagemBeacon
extends Node2D

## Baliza de estratagema: vuela hasta el punto apuntado, marca la zona con un
## haz de luz y, tras la espera, cae el ataque orbital o la cápsula con la
## caja de suministros o la torreta.

const FLIGHT_TIME: float = 0.45
const CALL_IN_TIME: float = 2.0
const ORBITAL_RADIUS: float = 280.0
const ORBITAL_DAMAGE: int = 12
const POD_FALL_TIME: float = 0.55
const POD_TEXTURE: Texture2D = preload("res://menu/intro_art/08_capsula.png")
const CRATE_SCENE: PackedScene = preload("res://player/stratagems/supply_crate.tscn")
const TURRET_SCENE: PackedScene = preload("res://player/stratagems/sentry_turret.tscn")

var id: String = ""
var color: Color = Color.WHITE
var _target: Vector2
var _time: float = 0.0
var _phase: String = "flight"
var _strike_radius: float = 0.0
var _strike_alpha: float = 0.0


func setup(stratagem_id: String, beam_color: Color, from: Vector2, target: Vector2) -> void:
	id = stratagem_id
	color = beam_color
	global_position = from
	_target = target


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
	if id == "orbital":
		_orbital_strike()
	else:
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


func _damage_enemies(radius: float, damage: int) -> void:
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		var area := hurtbox as Area2D
		if area == null or area.global_position.distance_to(global_position) > radius:
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
