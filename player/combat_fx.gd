class_name CombatFx
extends RefCounted

## Efectos de combate: números de daño que saltan del enemigo, estallido al
## morir y explosiones (bombardeo, araña bomba). Todo se dibuja en código.

const DAMAGE_COLOR: Color = Color(1.0, 0.95, 0.55)
const BIG_DAMAGE_COLOR: Color = Color(1.0, 0.55, 0.15)
const KILL_COLOR: Color = Color(1.0, 0.3, 0.25)


## Número de daño que sube y se desvanece. El golpe que mata sale en rojo.
static func damage_number(parent: Node, at: Vector2, amount: int, killing_blow: bool = false) -> void:
	if parent == null:
		return
	var label := FloatingText.new()
	label.text = str(amount)
	label.font_size = 26 + mini(amount, 12) * 2
	if killing_blow:
		label.color = KILL_COLOR
	elif amount >= 5:
		label.color = BIG_DAMAGE_COLOR
	else:
		label.color = DAMAGE_COLOR
	label.position = parent.to_local(at + Vector2(randf_range(-18.0, 18.0), randf_range(-10.0, 4.0)))
	parent.add_child.call_deferred(label)


## Estallido de pedazos del color del enemigo y un destello circular.
static func death_burst(parent: Node, at: Vector2, color: Color, size: float = 1.0) -> void:
	if parent == null:
		return
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = int(26 * clampf(size, 0.6, 4.0))
	particles.lifetime = 0.7
	particles.spread = 180.0
	particles.gravity = Vector2(0, 260)
	particles.initial_velocity_min = 140.0 * size
	particles.initial_velocity_max = 380.0 * size
	particles.damping_min = 120.0
	particles.damping_max = 240.0
	particles.scale_amount_min = 4.0 * size
	particles.scale_amount_max = 9.0 * size
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 0.85, 1), color, Color(color.darkened(0.6), 0.0)])
	particles.color_ramp = gradient
	particles.z_index = 4
	particles.position = parent.to_local(at)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
	parent.add_child.call_deferred(particles)

	var flash := Shockwave.new()
	flash.radius = 55.0 * size
	flash.color = color.lightened(0.4)
	flash.duration = 0.3
	flash.position = particles.position
	parent.add_child.call_deferred(flash)


## Explosión grande: bola de fuego, onda y chispas.
static func explosion(parent: Node, at: Vector2, radius: float, color: Color = Color(1.0, 0.55, 0.15)) -> void:
	if parent == null:
		return
	var blast := Shockwave.new()
	blast.radius = radius
	blast.color = color
	blast.duration = 0.45
	blast.filled = true
	blast.position = parent.to_local(at)
	parent.add_child.call_deferred(blast)
	death_burst(parent, at, color, radius / 80.0)


## Texto flotante (número de daño).
class FloatingText:
	extends Node2D

	var text: String = ""
	var color: Color = Color.WHITE
	var font_size: int = 28
	var _font: Font

	func _ready() -> void:
		z_index = 30
		_font = ThemeDB.fallback_font
		scale = Vector2(0.4, 0.4)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.08)
		tween.tween_property(self, "scale", Vector2.ONE, 0.1)
		var rise := create_tween().set_parallel()
		rise.tween_property(self, "position:y", position.y - 70.0, 0.75) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rise.tween_property(self, "position:x", position.x + randf_range(-25.0, 25.0), 0.75)
		rise.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.4)
		rise.chain().tween_callback(queue_free)

	func _draw() -> void:
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var origin := Vector2(-width * 0.5, font_size * 0.35)
		draw_string_outline(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color(0, 0, 0, 0.9))
		draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Onda o bola de fuego que crece y se apaga.
class Shockwave:
	extends Node2D

	var radius: float = 60.0
	var color: Color = Color.WHITE
	var duration: float = 0.3
	var filled: bool = false
	var _time: float = 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		_time += delta
		if _time >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := clampf(_time / duration, 0.0, 1.0)
		var fade := 1.0 - progress
		var current := radius * (0.3 + 0.7 * sqrt(progress))
		if filled:
			draw_circle(Vector2.ZERO, current, Color(color, 0.55 * fade))
			draw_circle(Vector2.ZERO, current * 0.55, Color(1.0, 0.93, 0.6, 0.9 * fade))
		else:
			draw_circle(Vector2.ZERO, current * 0.5, Color(1, 1, 1, 0.35 * fade))
		draw_arc(Vector2.ZERO, current, 0.0, TAU, 48, Color(color, fade), 3.0 + 5.0 * fade)
