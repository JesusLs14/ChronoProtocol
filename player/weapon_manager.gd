class_name WeaponManager
extends Node

const MAX_WEAPON_SLOTS: int = 4

@export var player_path: NodePath = ^".."
@export var initial_weapon: WeaponData
## Punto opcional desde el que salen los proyectiles (p. ej. la boca del arma).
@export var muzzle_path: NodePath = ^"../Muzzle"

## Multiplica la cadencia de todas las armas (p. ej. la sobrecarga de racha).
var fire_rate_multiplier: float = 1.0
var _player: Node2D
var _muzzle: Node2D
var _active_weapons: Array[WeaponData] = []
var _fire_cooldowns: Array[float] = []
# Armas que se disparan por separado (no en cada clic), p. ej. el lanzagranadas.
var _separate_cooldowns: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_muzzle = get_node_or_null(muzzle_path) as Node2D
	if _player == null:
		push_error("WeaponManager requires a Node2D at player_path.")
		return
	if initial_weapon == null:
		push_error("WeaponManager requires an initial_weapon.")
		return

	add_weapon(initial_weapon)


func _process(delta: float) -> void:
	for index in range(_fire_cooldowns.size()):
		_fire_cooldowns[index] = maxf(0.0, _fire_cooldowns[index] - delta * fire_rate_multiplier)
	for weapon: WeaponData in _separate_cooldowns:
		_separate_cooldowns[weapon] = maxf(0.0, _separate_cooldowns[weapon] - delta * fire_rate_multiplier)


func add_weapon(weapon: WeaponData) -> bool:
	if weapon == null:
		push_error("Cannot add a null weapon.")
		return false
	if _active_weapons.size() >= MAX_WEAPON_SLOTS:
		return false

	_active_weapons.append(weapon)
	_fire_cooldowns.append(0.0)
	return true


func get_active_weapons() -> Array[WeaponData]:
	return _active_weapons.duplicate()


func fire_at(
	target_position: Vector2,
	projectile_count: int = 1,
	spread_degrees: float = 0.0,
	minimum_fire_interval: float = 0.0
) -> bool:
	if _player == null:
		return false
	if projectile_count < 1:
		push_error("Projectile count must be at least one.")
		return false
	if spread_degrees < 0.0 or minimum_fire_interval < 0.0:
		push_error("Spread and minimum fire interval cannot be negative.")
		return false

	var aim_direction := _aim_direction_to(target_position)
	if aim_direction == Vector2.ZERO:
		return false

	var fired := false
	for index in range(_active_weapons.size()):
		if _fire_cooldowns[index] > 0.0:
			continue

		var weapon := _active_weapons[index]
		if weapon.projectile_scene == null:
			push_error("Weapon '%s' has no projectile scene." % weapon.weapon_name)
			continue

		var total_spread := deg_to_rad(spread_degrees)
		var angle_step := total_spread / float(projectile_count - 1) if projectile_count > 1 else 0.0
		var first_angle := -total_spread * 0.5
		var weapon_fired := true

		for projectile_index in range(projectile_count):
			var spread_offset := first_angle + angle_step * projectile_index
			var projectile_direction := aim_direction.rotated(spread_offset)
			var projectile := weapon.projectile_scene.instantiate() as Node2D
			if projectile == null:
				push_error(
					"Weapon '%s' projectile scene must have a Node2D root." % weapon.weapon_name
				)
				weapon_fired = false
				continue

			_player.get_parent().add_child(projectile)
			projectile.global_position = _spawn_position()
			projectile.global_rotation = projectile_direction.angle()

		if weapon_fired:
			_fire_cooldowns[index] = maxf(weapon.fire_interval, minimum_fire_interval)
			fired = true

	return fired


# Dispara un arma que no forma parte de las armas activas. Si el proyectil
# tiene set_target (p. ej. la granada), recibe el punto apuntado.
func fire_weapon_at(weapon: WeaponData, target_position: Vector2) -> bool:
	if _player == null or weapon == null:
		return false
	if weapon.projectile_scene == null:
		push_error("Weapon '%s' has no projectile scene." % weapon.weapon_name)
		return false
	if _separate_cooldowns.get(weapon, 0.0) > 0.0:
		return false

	var aim_direction := _aim_direction_to(target_position)
	if aim_direction == Vector2.ZERO:
		return false

	var projectile := weapon.projectile_scene.instantiate() as Node2D
	if projectile == null:
		push_error("Weapon '%s' projectile scene must have a Node2D root." % weapon.weapon_name)
		return false

	_player.get_parent().add_child(projectile)
	projectile.global_position = _spawn_position()
	projectile.global_rotation = aim_direction.angle()
	if projectile.has_method("set_target"):
		projectile.set_target(target_position)
	_separate_cooldowns[weapon] = weapon.fire_interval
	return true


func _spawn_position() -> Vector2:
	return _muzzle.global_position if _muzzle != null else _player.global_position


# La bala va desde la boca del arma hasta el punto apuntado, así pasa por el
# cursor. Si el cursor queda más cerca que la boca del arma, se apunta desde el
# centro del jugador para no disparar hacia atrás.
func _aim_direction_to(target_position: Vector2) -> Vector2:
	var center := _player.global_position
	var spawn := _spawn_position()
	if center.distance_to(target_position) > center.distance_to(spawn) * 1.5:
		return spawn.direction_to(target_position)
	return center.direction_to(target_position)
