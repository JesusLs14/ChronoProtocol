class_name FragmentDropper
extends RefCounted

## Suelta varios orbes de Fragmento de Núcleo (de 1 cada uno) que saltan
## alrededor del punto donde murió el enemigo.

## Probabilidad de soltar un orbe extra.
const BONUS_CHANCE: float = 0.25
const SCATTER_MIN: float = 30.0
const SCATTER_MAX: float = 90.0
## Lo sube el evento Frenesí dorado (doble de orbes).
static var multiplier: int = 1


static func drop(fragment_scene: PackedScene, parent: Node, at: Vector2, count: int) -> void:
	if fragment_scene == null or parent == null:
		push_error("FragmentDropper needs a fragment scene and a parent.")
		return
	if randf() < BONUS_CHANCE:
		count += 1
	count *= multiplier
	for index in range(count):
		var fragment := fragment_scene.instantiate() as Node2D
		if fragment == null:
			push_error("fragment_scene must have a Node2D root.")
			return
		fragment.set_amount(1)
		parent.add_child(fragment)
		fragment.set_spawn_position(at)
		var angle := TAU * (float(index) / count) + randf_range(-0.4, 0.4)
		fragment.pop_to(at + Vector2.from_angle(angle) * randf_range(SCATTER_MIN, SCATTER_MAX))
