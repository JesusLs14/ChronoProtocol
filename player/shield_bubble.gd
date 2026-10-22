class_name ShieldBubble
extends Node2D

## Burbuja de energía alrededor del soldado mientras tiene escudo. Muestra un
## punto por cada golpe que todavía puede bloquear.

@export var radius: float = 110.0
@export var color: Color = Color(0.3, 0.95, 1.0)

var charges: int = 0:
	set(value):
		charges = maxi(0, value)
		visible = charges > 0
		queue_redraw()

var _time: float = 0.0
var _hit_flash: float = 0.0


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 3.0)
	queue_redraw()


## Destello cuando el escudo bloquea un golpe.
func flash() -> void:
	_hit_flash = 1.0


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	var alpha := 0.18 + 0.1 * pulse + 0.5 * _hit_flash
	draw_circle(Vector2.ZERO, radius, Color(color, alpha * 0.5))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.6 + 0.4 * _hit_flash), 4.0 + 4.0 * _hit_flash)
	draw_arc(Vector2.ZERO, radius - 10.0, _time, _time + PI * 0.6, 24, Color(color, 0.5), 3.0)
	for index in charges:
		var angle := -PI * 0.5 + (index - (charges - 1) * 0.5) * 0.35
		draw_circle(Vector2.from_angle(angle) * (radius + 14.0), 7.0, Color(color, 0.95))
