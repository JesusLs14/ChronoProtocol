extends Area2D

@export var speed: float = 350.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += Vector2.RIGHT.rotated(global_rotation) * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		# Las columnas, barricadas, barriles y paredes sirven de cobertura.
		if not body is CharacterBody2D:
			queue_free()
		return

	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()
