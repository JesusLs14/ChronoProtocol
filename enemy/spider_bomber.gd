extends "res://enemy/spider_minion.gd"

## Araña bomba: corre hacia el soldado y, al alcanzarlo, se enciende y
## explota. También explota si la matan, así que conviene acabar con ella de
## lejos: la explosión daña al soldado (2 de vida) y a las demás arañas.

const FUSE_TIME: float = 0.6
const BLAST_RADIUS: float = 140.0
const PLAYER_DAMAGE: int = 2
const ENEMY_DAMAGE: int = 3
const BLAST_COLOR: Color = Color(1.0, 0.6, 0.15)

var _fuse_lit: bool = false
var _exploded: bool = false
var _base_tint: Color = Color.WHITE


func _ready() -> void:
	super()
	_base_tint = sprite.modulate


# En vez de morder, enciende la mecha.
func _attack_player(_player: Node2D) -> void:
	if _fuse_lit:
		return
	_fuse_lit = true
	_attack_cooldown = 999.0
	sprite.play(&"Attack")
	var blink := create_tween().set_loops(int(FUSE_TIME / 0.1))
	blink.tween_property(sprite, "modulate", Color(3.0, 1.2, 0.4), 0.05)
	blink.tween_property(sprite, "modulate", _base_tint, 0.05)
	Sfx.play("hover", 0.0, 0.0)
	await get_tree().create_timer(FUSE_TIME, false).timeout
	if _is_dead:
		return
	# Se cuenta como baja normal (puntos y fragmentos) y explota.
	health_component.take_damage(health_component.current_health)


func _on_health_died() -> void:
	super()
	_explode.call_deferred()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var at := global_position
	CombatFx.explosion(get_parent(), at, BLAST_RADIUS, BLAST_COLOR)
	Sfx.play("explosion", -2.0, 0.1)
	var screen_shake := get_tree().get_first_node_in_group("screen_shake")
	if screen_shake != null:
		screen_shake.shake()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(at) <= BLAST_RADIUS and player.has_method("take_damage"):
		player.take_damage(PLAYER_DAMAGE)
	for hurtbox in get_tree().get_nodes_in_group("enemy_hurtbox"):
		var area := hurtbox as Area2D
		if area == null or area.get_parent() == self or area.global_position.distance_to(at) > BLAST_RADIUS:
			continue
		var target := area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(ENEMY_DAMAGE)
		else:
			var other_health: Variant = target.get_node_or_null("HealthComponent")
			if other_health != null:
				other_health.take_damage(ENEMY_DAMAGE)
	# La bomba no deja cadáver.
	sprite.hide()
	queue_free()
