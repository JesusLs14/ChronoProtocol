class_name Flame
extends Bullet

## Llamarada del lanzallamas: sale con algo de dispersión, se frena, crece y
## se apaga en poco tiempo, así que solo alcanza de cerca. Atraviesa a los
## enemigos y daña una vez a cada uno.

@export var lifetime: float = 0.4
@export var spread: float = 0.22

var _time: float = 0.0
var _start_speed: float = 0.0


func _ready() -> void:
	super()
	rotation += randf_range(-spread, spread)
	_start_speed = speed
	z_index = 2


func _process(delta: float) -> void:
	_time += delta
	if _time >= lifetime:
		queue_free()
		return
	var progress := _time / lifetime
	speed = _start_speed * (1.0 - 0.65 * progress)
	super(delta)
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_time / lifetime, 0.0, 1.0)
	var radius := 16.0 + 30.0 * progress
	var fade := 1.0 - progress * progress
	draw_circle(Vector2.ZERO, radius, Color(0.85, 0.15, 0.05, 0.45 * fade))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(1.0, 0.5, 0.08, 0.75 * fade))
	draw_circle(Vector2.ZERO, radius * 0.4, Color(1.0, 0.92, 0.55, 0.95 * fade))
