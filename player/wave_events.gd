class_name WaveEvents
extends Node2D

## Eventos especiales de oleada. Desde la oleada 3, las oleadas normales
## (no las del jefe) tienen una probabilidad de traer un evento, nunca dos
## seguidas:
## - Enjambre: solo arañas, muchas más y más seguido.
## - Apagón: todo se oscurece salvo un círculo de luz alrededor del soldado.
## - Lluvia de meteoritos: caen meteoritos cerca del soldado; dañan a todos.
## - Frenesí dorado: enemigos más rápidos que dan doble puntaje y fragmentos.
## - Artillería: solo drones, el doble de seguido; toca usar las coberturas.

const FIRST_EVENT_WAVE: int = 3
const EVENT_CHANCE: float = 0.4
const EVENTS: Dictionary = {
	"swarm": {
		"name": "ENJAMBRE",
		"text": "Solo arañas, y vienen muchísimas",
		"color": Color(1.0, 0.55, 0.3),
	},
	"blackout": {
		"name": "APAGÓN",
		"text": "Se cayó la luz: solo ves cerca de ti",
		"color": Color(0.55, 0.65, 1.0),
	},
	"meteors": {
		"name": "LLUVIA DE METEORITOS",
		"text": "Esquiva los círculos rojos (también dañan a los bichos)",
		"color": Color(1.0, 0.35, 0.2),
	},
	"frenzy": {
		"name": "FRENESÍ DORADO",
		"text": "Enemigos más rápidos, pero doble puntaje y fragmentos",
		"color": Color(1.0, 0.85, 0.25),
	},
	"artillery": {
		"name": "ARTILLERÍA",
		"text": "Solo drones: usa las columnas para cubrirte",
		"color": Color(0.85, 0.45, 1.0),
	},
}
const METEOR_INTERVAL: float = 1.1
const BLACKOUT_LIGHT_RADIUS: float = 340.0

var current: String = ""
var _last_wave_had_event: bool = false
var _meteor_timer: float = 0.0
var _darkness: ColorRect
var _bounds: Rect2


func setup(bounds: Rect2) -> void:
	_bounds = bounds
	z_index = 40


## Decide el evento de la oleada ("" si no hay) y lo activa.
func begin_wave(wave: int, director: WaveDirector) -> String:
	end_event()
	if wave < FIRST_EVENT_WAVE or director.is_boss_wave(wave) or _last_wave_had_event:
		_last_wave_had_event = false
		return ""
	if randf() >= EVENT_CHANCE:
		return ""
	_last_wave_had_event = true
	current = EVENTS.keys().pick_random()
	_meteor_timer = 2.0
	if current == "blackout":
		_start_blackout()
	FragmentDropper.multiplier = 2 if current == "frenzy" else 1
	return current


func end_event() -> void:
	current = ""
	FragmentDropper.multiplier = 1
	if _darkness != null:
		var darkness := _darkness
		_darkness = null
		var tween := darkness.create_tween()
		tween.tween_property(darkness, "modulate:a", 0.0, 0.8)
		tween.tween_callback(darkness.queue_free)


func event_name() -> String:
	return EVENTS[current]["name"] if current != "" else ""


func event_text() -> String:
	return EVENTS[current]["text"] if current != "" else ""


func event_color() -> Color:
	return EVENTS[current]["color"] if current != "" else Color.WHITE


## Variante a usar en lugar de la normal (null = la de la oleada).
func override_variant(director: WaveDirector) -> EnemyVariant:
	match current:
		"swarm":
			return director.fast_spider if randf() < 0.6 else director.spider
		"artillery":
			return director.gunner_drone if randf() < 0.4 else director.drone
	return null


func kills_multiplier() -> float:
	match current:
		"swarm":
			return 1.6
		"artillery":
			return 0.7
	return 1.0


func spawn_interval_multiplier() -> float:
	match current:
		"swarm":
			return 0.4
		"artillery":
			return 0.6
	return 1.0


func score_multiplier() -> int:
	return 2 if current == "frenzy" else 1


## Ajusta al enemigo recién creado (velocidad del frenesí).
func modify_enemy(enemy: Node2D) -> void:
	if current == "frenzy" and "speed" in enemy:
		enemy.speed *= 1.3
		var sprite := enemy.get_node_or_null("AnimatedSprite2D") as CanvasItem
		if sprite != null:
			sprite.self_modulate = Color(1.3, 1.15, 0.6)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _darkness != null:
		var material := _darkness.material as ShaderMaterial
		material.set_shader_parameter("light_position", player.global_position)
	if current == "meteors" and not get_tree().paused:
		_meteor_timer -= delta
		if _meteor_timer <= 0.0:
			_meteor_timer = METEOR_INTERVAL * randf_range(0.7, 1.3)
			_drop_meteor(player.global_position)


func _drop_meteor(around: Vector2) -> void:
	var meteor := Meteor.new()
	var point := around + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 480.0)
	if _bounds.has_area():
		point = point.clamp(_bounds.position + Vector2(60, 60), _bounds.end - Vector2(60, 60))
	get_parent().add_child(meteor)
	meteor.global_position = point


func _start_blackout() -> void:
	_darkness = ColorRect.new()
	_darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BLACKOUT_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("light_radius", BLACKOUT_LIGHT_RADIUS)
	_darkness.material = material
	_darkness.position = _bounds.position - Vector2(400, 400)
	_darkness.size = _bounds.size + Vector2(800, 800)
	_darkness.modulate.a = 0.0
	add_child(_darkness)
	_darkness.create_tween().tween_property(_darkness, "modulate:a", 1.0, 1.2)


const BLACKOUT_SHADER: String = """
shader_type canvas_item;

uniform vec2 light_position;
uniform float light_radius = 340.0;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float flicker = 1.0 + 0.04 * sin(TIME * 23.0) + 0.03 * sin(TIME * 7.0);
	float distance_to_light = distance(world_position, light_position);
	float darkness = smoothstep(light_radius * 0.45, light_radius * flicker, distance_to_light);
	COLOR = vec4(0.0, 0.01, 0.03, 0.93 * darkness) * vec4(1.0, 1.0, 1.0, COLOR.a);
}
"""


## Meteorito: círculo de aviso que se cierra, cae envuelto en fuego y explota.
## Daña al soldado y a los enemigos que alcanza.
class Meteor:
	extends Node2D

	const WARNING_TIME: float = 1.2
	const RADIUS: float = 115.0
	const PLAYER_DAMAGE: int = 1
	const ENEMY_DAMAGE: int = 5

	var _time: float = 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_time += delta
		if _time >= WARNING_TIME:
			_impact()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := _time / WARNING_TIME
		var blink := 0.5 + 0.5 * sin(_time * (8.0 + 22.0 * progress))
		draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.25, 0.1, 0.08 + 0.15 * progress))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, Color(1.0, 0.3, 0.15, 0.6 + 0.4 * blink), 3.0)
		draw_arc(Vector2.ZERO, RADIUS * (1.0 - progress), 0.0, TAU, 40, Color(1.0, 0.7, 0.4, 0.7), 2.0)
		# La roca cae desde arriba a la izquierda dejando una estela.
		var fall := Vector2(-260, -900) * pow(1.0 - progress, 1.6)
		draw_line(fall + Vector2(-70, -240), fall, Color(1.0, 0.5, 0.15, 0.5), 14.0)
		draw_line(fall + Vector2(-35, -120), fall, Color(1.0, 0.85, 0.45, 0.8), 6.0)
		draw_circle(fall, 16.0, Color(0.35, 0.22, 0.18))
		draw_circle(fall + Vector2(-4, -4), 9.0, Color(1.0, 0.6, 0.25))

	func _impact() -> void:
		CombatFx.explosion(get_parent(), global_position, RADIUS, Color(1.0, 0.45, 0.15))
		Sfx.play("explosion", -3.0, 0.15)
		var screen_shake := get_tree().get_first_node_in_group("screen_shake")
		if screen_shake != null:
			screen_shake.shake()
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and player.global_position.distance_to(global_position) <= RADIUS:
			player.take_damage(PLAYER_DAMAGE)
		for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
			var area := hurtbox as Area2D
			if area == null or area.global_position.distance_to(global_position) > RADIUS:
				continue
			var target := area.get_parent()
			if target.has_method("take_damage"):
				target.take_damage(ENEMY_DAMAGE)
			else:
				var health_component: Variant = target.get_node_or_null("HealthComponent")
				if health_component != null:
					health_component.take_damage(ENEMY_DAMAGE)
		queue_free()
