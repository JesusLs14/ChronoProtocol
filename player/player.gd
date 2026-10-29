class_name Player
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal weapon_changed(weapon_id: String)
## Se emite cuando un golpe quita vida (no cuando lo bloquea el escudo).
signal damaged

@export var speed: float = 300.0
@export var acceleration: float = 14.0
@export var friction: float = 12.0
@export var max_health: int = 10
var current_health: int = 10
var is_dead: bool = false
## Durante una cinemática (entrada del jefe) no se mueve, no dispara y no recibe daño.
var in_cinematic: bool = false
var has_shotgun: bool = false
var has_grenade_launcher: bool = false
var unlocked_weapons: Array[String] = ["pistol"]
var current_weapon_index: int = 0
var current_weapon: String = "pistol"
@export var grenade_weapon: WeaponData
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.18
@export var dash_invulnerability_duration: float = 0.25
## Tiempo sin recibir daño después de un golpe; el soldado parpadea mientras dura.
@export var hurt_invulnerability_duration: float = 0.6
@export var dash_cooldown: float = 0.8
var core_fragments: int = 0
# Al soltar las teclas la velocidad decae exponencialmente sin llegar a cero;
# por debajo de este valor el soldado ya se muestra en reposo.
const RUN_ANIMATION_MIN_SPEED: float = 10.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_flash: HitFlashComponent = $HitFlashComponent
@onready var weapon_manager: WeaponManager = $WeaponManager
const SNIPER_WEAPON: WeaponData = preload("res://player/weapons/sniper_rifle.tres")
const FLAMETHROWER_WEAPON: WeaponData = preload("res://player/weapons/flamethrower.tres")
## Armas que no usan el sonido normal de disparo (tienen el suyo).
const WEAPON_SOUNDS: Dictionary = {"sniper": "sniper", "flamethrower": "flame", "laser": "laser"}
var _laser: LaserBeam
@onready var muzzle: Marker2D = $Muzzle
@onready var damage_overlay: ColorRect = $CanvasLayer/DamageOverlay

# Distancia a la que se coloca el punto de mira cuando se apunta con el stick.
const STICK_AIM_DISTANCE: float = 400.0
const DAMAGE_OVERLAY_ALPHA: float = 0.35
const DAMAGE_OVERLAY_DURATION: float = 0.3
var _damage_overlay_tween: Tween
@onready var shield_bubble: ShieldBubble = $ShieldBubble
@onready var stratagems: StratagemController = $StratagemController

# Sobrecarga (recompensa de racha): más velocidad y cadencia por un tiempo.
const BOOST_SPEED_MULTIPLIER: float = 1.35
const BOOST_FIRE_RATE_MULTIPLIER: float = 2.0
const BOOST_TRAIL_INTERVAL: float = 0.07
const SHIELD_BLOCK_INVULNERABILITY: float = 0.4
var _boost_time_left: float = 0.0
var _boost_trail_time: float = 0.0

# Tiempo que el soldado sigue apuntando después del último disparo.
const AIM_HOLD_TIME: float = 0.35

var _fire_held: bool = false
var _aim_time_remaining: float = 0.0
var _aim_rig: SoldierAimRig

var _dash_direction := Vector2.ZERO
var _dash_time_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _invulnerability_time_remaining: float = 0.0
var _hurt_blink_remaining: float = 0.0
const HURT_BLINK_INTERVAL: float = 0.08
var _trail_time_remaining: float = 0.0


func _ready() -> void:
	current_health = clampi(current_health, 0, max_health)
	var health_container: HBoxContainer = $CanvasLayer/HBoxContainer
	health_changed.connect(health_container.update_health)
	health_changed.emit(current_health, max_health)
	_build_aim_rig()
	_laser = LaserBeam.new()
	_laser.weapon_manager = weapon_manager
	add_child(_laser)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	if event is InputEventMouseButton and event.pressed:
		var direction := 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			direction = 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			direction = -1

		if direction != 0:
			if unlocked_weapons.is_empty():
				push_error("Cannot switch weapons: no weapons are unlocked.")
				return
			current_weapon_index = posmod(
				current_weapon_index + direction,
				unlocked_weapons.size()
			)
			current_weapon = unlocked_weapons[current_weapon_index]
			weapon_changed.emit(current_weapon)
			return

	if event.is_action_pressed("shoot"):
		_fire_held = true
		_try_fire()


# El botón se suelta aunque el clic termine sobre la interfaz.
func _input(event: InputEvent) -> void:
	if event.is_action_released("shoot"):
		_fire_held = false


# Mantener el clic dispara de forma continua, a la cadencia de cada arma.
func _try_fire() -> void:
	if is_dead or in_cinematic or current_health <= 0 or _dash_time_remaining > 0.0 or stratagems.entering:
		return
	var target := _get_aim_position()
	_set_facing(target.x < global_position.x)
	_aim_time_remaining = maxf(_aim_time_remaining, 0.01)
	_update_aim_pose()
	var fired := false
	if current_weapon == "shotgun":
		fired = weapon_manager.fire_at(target, 5, 45.0, 0.8)
	elif current_weapon == "grenade_launcher":
		fired = weapon_manager.fire_weapon_at(grenade_weapon, target)
	elif current_weapon == "sniper":
		fired = weapon_manager.fire_weapon_at(SNIPER_WEAPON, target)
	elif current_weapon == "flamethrower":
		fired = weapon_manager.fire_weapon_at(FLAMETHROWER_WEAPON, target)
	elif current_weapon == "laser":
		fired = _laser.fire(muzzle.global_position, target)
	else:
		fired = weapon_manager.fire_at(target)
	if fired:
		_aim_time_remaining = AIM_HOLD_TIME
		_aim_rig.play_flash()
		if WEAPON_SOUNDS.has(current_weapon):
			Sfx.play(WEAPON_SOUNDS[current_weapon], -4.0, 0.08)
		else:
			$SfxShoot.play()
		if anim_sprite.animation != &"hurt":
			anim_sprite.play("shoot")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_dash_cooldown_remaining = maxf(0.0, _dash_cooldown_remaining - delta)
	_invulnerability_time_remaining = maxf(0.0, _invulnerability_time_remaining - delta)
	_update_hurt_blink(delta)
	_update_boost(delta)
	_aim_time_remaining = maxf(0.0, _aim_time_remaining - delta)

	var input_direction: Vector2 = _get_move_direction()
	if Input.is_action_just_pressed("dash") and _dash_cooldown_remaining == 0.0 and not in_cinematic:
		_start_dash(input_direction)

	if _dash_time_remaining > 0.0:
		velocity = _dash_direction * dash_speed
		move_and_slide()
		_dash_time_remaining = maxf(0.0, _dash_time_remaining - delta)
		_trail_time_remaining -= delta
		if _trail_time_remaining <= 0.0:
			_spawn_dash_trail()
			_trail_time_remaining = 0.04
		if _dash_time_remaining == 0.0:
			velocity = _dash_direction * speed
		_update_animation()
		return

	var weight: float

	if input_direction != Vector2.ZERO:
		weight = 1.0 - exp(-acceleration * delta)
		velocity = velocity.lerp(input_direction * speed * _speed_multiplier(), weight)
	else:
		weight = 1.0 - exp(-friction * delta)
		velocity = velocity.lerp(Vector2.ZERO, weight)

	move_and_slide()

	if _fire_held and not Input.is_action_pressed("shoot"):
		_fire_held = false
	if _fire_held:
		_try_fire()
	_update_animation()
	_update_aim_pose(delta)


func _start_dash(input_direction: Vector2) -> void:
	_dash_direction = input_direction
	if _dash_direction == Vector2.ZERO:
		_dash_direction = velocity.normalized()
	if _dash_direction == Vector2.ZERO:
		_dash_direction = _get_aim_position() - global_position
	_dash_direction = _dash_direction.normalized()
	_dash_time_remaining = dash_duration
	_dash_cooldown_remaining = dash_cooldown
	_invulnerability_time_remaining = dash_invulnerability_duration
	_trail_time_remaining = 0.0


func _spawn_dash_trail() -> void:
	var trail := anim_sprite.duplicate() as AnimatedSprite2D
	trail.visible = true
	trail.self_modulate.a = 1.0
	trail.modulate = Color(0.35, 0.85, 1.0, 0.5)
	trail.z_index = -1
	trail.stop()
	get_parent().add_child(trail)
	trail.global_transform = anim_sprite.global_transform
	var tween := create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.16)
	tween.tween_callback(trail.queue_free)


func _update_animation() -> void:
	if current_health <= 0:
		return

	_update_facing()
	if _dash_time_remaining > 0.0:
		_aim_time_remaining = 0.0
		_show_aim_rig(false)
		anim_sprite.play("dash")
		return
	if anim_sprite.animation in [&"shoot", &"hurt"] and anim_sprite.is_playing():
		return

	if velocity.length() > RUN_ANIMATION_MIN_SPEED:
		anim_sprite.play("run")
	else:
		anim_sprite.play("idle")


# Al correr o hacer dash el soldado mira hacia donde se mueve; al disparar o
# estar quieto mira hacia el ratón.
func _update_facing() -> void:
	if not _is_aiming() and absf(velocity.x) > RUN_ANIMATION_MIN_SPEED:
		_set_facing(velocity.x < 0.0)
	else:
		_set_facing(_get_aim_position().x < global_position.x)


# Voltea al soldado y lleva la boca del arma al mismo lado.
func _set_facing(face_left: bool) -> void:
	anim_sprite.flip_h = face_left
	muzzle.position.x = -absf(muzzle.position.x) if face_left else absf(muzzle.position.x)
	if _aim_rig != null:
		_aim_rig.scale.x = -1.0 if face_left else 1.0


func _is_aiming() -> bool:
	return (_fire_held or _aim_time_remaining > 0.0) and current_health > 0 \
		and _dash_time_remaining == 0.0


# Pose de disparo en capas (piernas, cuerpo y arma) como hija del
# AnimatedSprite2D, así hereda su escala y el destello de daño. Mientras
# apunta, el sprite normal se oculta con self_modulate y solo se dibuja esta pose.
func _build_aim_rig() -> void:
	_aim_rig = SoldierAimRig.new()
	anim_sprite.add_child(_aim_rig)
	var cell_size := Vector2(SoldierAimRig.CELL_SIZE)
	_aim_rig.setup(anim_sprite.offset - cell_size * 0.5)


func _show_aim_rig(visible_now: bool) -> void:
	if _aim_rig == null:
		return
	_aim_rig.visible = visible_now
	anim_sprite.self_modulate.a = 0.0 if visible_now else 1.0


# Orienta el arma hacia el ratón y lleva la boca del arma (Muzzle) a la punta
# del cañón girado.
func _update_aim_pose(delta: float = 0.0) -> void:
	if _aim_rig == null:
		return
	var aiming := _is_aiming() and anim_sprite.animation != &"hurt"
	_show_aim_rig(aiming)
	if not aiming:
		return

	var moving := velocity.length() > RUN_ANIMATION_MIN_SPEED
	var facing_sign := -1.0 if anim_sprite.flip_h else 1.0
	var backwards := moving and velocity.x * facing_sign < -RUN_ANIMATION_MIN_SPEED
	_aim_rig.update_pose(_get_aim_position(), moving, backwards, delta)
	muzzle.global_position = _aim_rig.get_gun_tip_position()


func _get_move_direction() -> Vector2:
	# Mientras se mete una estratagema, WASD/flechas son para la combinación.
	if stratagems.entering or in_cinematic:
		return Vector2.ZERO
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var keyboard_direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	if Input.is_physical_key_pressed(KEY_D):
		keyboard_direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		keyboard_direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		keyboard_direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		keyboard_direction.y -= 1.0

	if keyboard_direction != Vector2.ZERO:
		direction = (direction + keyboard_direction).normalized()

	return direction


func take_damage(amount: int = 1) -> void:
	if _invulnerability_time_remaining > 0.0 or current_health <= 0 or in_cinematic:
		return

	if shield_bubble.charges > 0:
		shield_bubble.charges -= 1
		shield_bubble.flash()
		_invulnerability_time_remaining = SHIELD_BLOCK_INVULNERABILITY
		Sfx.play("click", -2.0, 0.1)
		return

	damaged.emit()

	current_health = maxi(0, current_health - maxi(1, amount))
	health_changed.emit(current_health, max_health)
	hit_flash.flash()
	_flash_damage_overlay()
	var screen_shake := get_tree().get_first_node_in_group("screen_shake")
	if screen_shake != null:
		screen_shake.shake()

	if current_health > 0:
		anim_sprite.play("hurt")
		_invulnerability_time_remaining = maxf(_invulnerability_time_remaining, hurt_invulnerability_duration)
		_hurt_blink_remaining = hurt_invulnerability_duration
		return

	is_dead = true
	$SfxHit.play()
	_hurt_blink_remaining = 0.0
	anim_sprite.visible = true
	_fire_held = false
	velocity = Vector2.ZERO
	_dash_time_remaining = 0.0
	_show_aim_rig(false)
	anim_sprite.play("death")
	await anim_sprite.animation_finished

	var main = get_tree().get_first_node_in_group("main")
	if main == null:
		push_error("Cannot show game over: no main node exists in the main group.")
		return
	main.show_game_over()


# --- Recompensas de racha ----------------------------------------------------

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func add_shield(charges: int) -> void:
	if is_dead or charges <= 0:
		return
	shield_bubble.charges += charges


func apply_boost(seconds: float) -> void:
	if is_dead or seconds <= 0.0:
		return
	_boost_time_left = maxf(_boost_time_left, seconds)
	weapon_manager.fire_rate_multiplier = BOOST_FIRE_RATE_MULTIPLIER


func is_boosted() -> bool:
	return _boost_time_left > 0.0


func _speed_multiplier() -> float:
	return BOOST_SPEED_MULTIPLIER if is_boosted() else 1.0


func _update_boost(delta: float) -> void:
	if _boost_time_left <= 0.0:
		return
	_boost_time_left = maxf(0.0, _boost_time_left - delta)
	# Estela cian mientras dura la sobrecarga.
	_boost_trail_time -= delta
	if _boost_trail_time <= 0.0 and velocity.length() > RUN_ANIMATION_MIN_SPEED:
		_spawn_dash_trail()
		_boost_trail_time = BOOST_TRAIL_INTERVAL
	if _boost_time_left == 0.0:
		weapon_manager.fire_rate_multiplier = 1.0


# Parpadeo durante la invulnerabilidad que sigue a un golpe.
func _update_hurt_blink(delta: float) -> void:
	if _hurt_blink_remaining <= 0.0:
		return
	_hurt_blink_remaining = maxf(0.0, _hurt_blink_remaining - delta)
	if _hurt_blink_remaining == 0.0:
		anim_sprite.visible = true
	else:
		anim_sprite.visible = int(_hurt_blink_remaining / HURT_BLINK_INTERVAL) % 2 == 0


# Destello rojo en los bordes de la pantalla al recibir daño.
func _flash_damage_overlay() -> void:
	if damage_overlay == null:
		return
	if _damage_overlay_tween != null and _damage_overlay_tween.is_running():
		_damage_overlay_tween.kill()
	damage_overlay.modulate.a = DAMAGE_OVERLAY_ALPHA
	_damage_overlay_tween = create_tween()
	_damage_overlay_tween.tween_property(damage_overlay, "modulate:a", 0.0, DAMAGE_OVERLAY_DURATION)


# Añade un arma al inventario (si no la tenía) y la equipa.
func equip_weapon(weapon_id: String) -> void:
	if not unlocked_weapons.has(weapon_id):
		unlocked_weapons.append(weapon_id)
	current_weapon_index = unlocked_weapons.find(weapon_id)
	current_weapon = weapon_id
	weapon_changed.emit(current_weapon)


func add_fragment(amount: int) -> void:
	if amount <= 0:
		push_error("Fragment amount must be greater than zero.")
		return

	core_fragments += amount


# Punto al que apunta el jugador: el stick derecho del mando si se está usando,
# si no el ratón. Separado para poder simularlo en las pruebas.
func _get_aim_position() -> Vector2:
	var aim_vector := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if aim_vector.length() > 0.2:
		return global_position + aim_vector.normalized() * STICK_AIM_DISTANCE
	return get_global_mouse_position()
