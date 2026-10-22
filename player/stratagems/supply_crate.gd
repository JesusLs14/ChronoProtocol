class_name SupplyCrate
extends Area2D

## Caja de suministros que deja la estratagema. Al tocarla el soldado
## recupera vida y gana un escudo de un golpe.

@export var heal_amount: int = 3
@export var shield_charges: int = 1
@export var lifetime: float = 30.0

var _time: float = 0.0
var _taken: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _time >= lifetime and not _taken:
		queue_free()
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Player or body.is_dead:
		return
	_taken = true
	var player := body as Player
	player.heal(heal_amount)
	player.add_shield(shield_charges)
	Sfx.play("pickup", 2.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	# Caja metálica con franjas cian y una cruz de salud que parpadea.
	var bob := sin(_time * 3.0) * 3.0
	var body_rect := Rect2(-34, -30 + bob, 68, 52)
	draw_rect(Rect2(-30, 26, 60, 8), Color(0, 0, 0, 0.35))
	draw_rect(body_rect, Color(0.08, 0.1, 0.14))
	draw_rect(body_rect.grow(-4), Color(0.28, 0.32, 0.4))
	draw_rect(Rect2(-34, -12 + bob, 68, 6), Color(0.3, 0.9, 1.0))
	var glow := 0.6 + 0.4 * sin(_time * 6.0)
	var cross := Color(0.4, 1.0, 0.5, glow)
	draw_rect(Rect2(-5, -2 + bob, 10, 22), cross)
	draw_rect(Rect2(-11, 4 + bob, 22, 10), cross)
	# Aviso de que va a desaparecer.
	if lifetime - _time < 5.0 and int(_time * 6.0) % 2 == 0:
		draw_arc(Vector2(0, bob), 46.0, 0.0, TAU, 32, Color(1, 0.4, 0.3, 0.8), 2.0)
