class_name Bullet
extends Area2D

@export var speed: float = 600.0
@export_range(1, 20, 1) var damage: int = 1
## Enemigos que puede atravesar antes de desaparecer.
@export_range(0, 10, 1) var pierce: int = 0

var _hit_targets: Array[Node] = []


func _ready() -> void:
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return

	var target := area.get_parent()
	if _hit_targets.has(target):
		return
	var damage_applied := false
	if target.has_method("take_damage"):
		damage_applied = target.take_damage(damage)
	else:
		var health_component: Variant = target.get_node_or_null("HealthComponent")
		if health_component != null:
			damage_applied = health_component.take_damage(damage)
	if not damage_applied:
		return

	_hit_targets.append(target)
	if pierce > 0:
		pierce -= 1
		return
	queue_free()


func _on_screen_exited() -> void:
	queue_free()
