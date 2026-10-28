class_name HealthComponent
extends Node

signal took_damage(current_health: int, damage_amount: int)
signal died

@export_range(1, 1000, 1) var max_health: int = 3
## Muestra el número de daño en cada golpe y un estallido al morir.
@export var show_combat_fx: bool = true

var current_health: int
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health


func take_damage(damage_amount: int = 1) -> bool:
	if is_dead or damage_amount <= 0:
		return false

	current_health = maxi(0, current_health - damage_amount)
	took_damage.emit(current_health, damage_amount)
	_show_damage(damage_amount)
	if current_health == 0:
		is_dead = true
		_show_death()
		died.emit()
	return true


func _show_damage(damage_amount: int) -> void:
	var body := get_parent() as Node2D
	if not show_combat_fx or body == null:
		return
	CombatFx.damage_number(body.get_parent(), body.global_position + Vector2(0, -40) * body.scale, damage_amount, current_health == 0)


func _show_death() -> void:
	var body := get_parent() as Node2D
	if not show_combat_fx or body == null:
		return
	CombatFx.death_burst(body.get_parent(), body.global_position, _body_color(body), body.scale.x * (2.2 if body.is_in_group("boss") else 1.0))
	Sfx.play("explosion", -15.0, 0.2)


# Color del enemigo (el tinte de su variante) para el estallido.
func _body_color(body: Node2D) -> Color:
	var color := Color(1.0, 0.6, 0.25)
	var hit_flash := body.get_node_or_null("HitFlashComponent")
	if hit_flash != null and "_original_modulate" in hit_flash:
		color = hit_flash._original_modulate
	# Los sprites sin tinte son blancos: el estallido toma un verde de bicho.
	if color.r > 0.95 and color.g > 0.95 and color.b > 0.95:
		color = Color(0.55, 1.0, 0.45)
	return Color(minf(color.r, 1.0), minf(color.g, 1.0), minf(color.b, 1.0), 1.0)
