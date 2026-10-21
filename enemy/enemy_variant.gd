class_name EnemyVariant
extends Resource

## Variante de un enemigo: usa la escena base (araña o dron) y le cambia vida,
## velocidad, tamaño, color y recompensa. Así cada oleada puede traer enemigos
## distintos sin sprites nuevos.

@export var display_name: String = "Araña"
@export var scene: PackedScene
@export_range(1, 100, 1) var health: int = 1
@export var speed_multiplier: float = 1.0
@export var size_multiplier: float = 1.0
@export var tint: Color = Color.WHITE
## Segundos entre disparos (solo drones). 0 = el valor de la escena.
@export var fire_interval: float = 0.0
@export_range(0, 10, 1) var bonus_fragments: int = 0
@export_range(1, 1000, 1) var score_points: int = 10


## Crea el enemigo listo para añadirlo al árbol. difficulty (>= 1) multiplica
## la vida y, más suavemente, la velocidad (modo infinito).
func spawn(difficulty: float = 1.0) -> Node2D:
	var enemy := scene.instantiate() as Node2D
	var health_component := enemy.get_node("HealthComponent")
	health_component.max_health = maxi(1, ceili(health * difficulty))
	enemy.speed *= speed_multiplier * minf(1.0 + (difficulty - 1.0) * 0.25, 1.4)
	enemy.scale *= size_multiplier
	# El destello de daño toma este color como base al entrar en el árbol.
	enemy.get_node("AnimatedSprite2D").modulate = tint
	if fire_interval > 0.0 and "fire_interval" in enemy:
		enemy.fire_interval = fire_interval / minf(difficulty, 1.5)
	enemy.fragment_drop_amount += bonus_fragments
	enemy.score_points = score_points
	return enemy
