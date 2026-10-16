class_name SoldierAimRig
extends Node2D

## Pose de disparo del soldado en tres capas (soldier_aim_parts.png):
## piernas, cuerpo y arma. El cuerpo se inclina un poco hacia el ratón y el
## arma gira el resto sobre el hombro; cabeza, cadera y piernas siguen unidas.
## Va como hijo del AnimatedSprite2D, así hereda su escala, su volteo y el
## destello de daño. Las coordenadas son píxeles de la celda de 144×72.

const PARTS_TEXTURE: Texture2D = preload("res://player/soldier/soldier_aim_parts.png")
const CELL_SIZE := Vector2i(144, 72)
const BODY_ROW: int = 0
const GUN_ROW: int = 1
const LEGS_ROW: int = 2
const HIP := Vector2(70, 46)
const SHOULDER := Vector2(64, 28)
const GUN_TIP := Vector2(103, 27)
const GUN_FRAME_COUNT: int = 4
const RUN_FRAME_COUNT: int = 8
const RUN_FPS: float = 12.0
const FLASH_FPS: float = 16.0
## Parte del ángulo que hace el cuerpo; el arma hace el resto.
const LEAN_FACTOR: float = 0.3
const MAX_LEAN: float = deg_to_rad(12.0)
const MAX_AIM_ANGLE: float = deg_to_rad(80.0)

var _cell: Node2D
var _legs: Sprite2D
var _torso_pivot: Node2D
var _gun_pivot: Node2D
var _gun: Sprite2D
var _gun_tip: Marker2D
var _gun_frames: Array[AtlasTexture] = []
var _still_legs: AtlasTexture
var _run_legs: Array[AtlasTexture] = []
var _run_time: float = 0.0
var _flash_time: float = 99.0


## cell_top_left: esquina superior izquierda de la celda en el espacio del
## AnimatedSprite2D (depende de su offset). El rig queda en el origen del
## sprite para que scale.x = -1 lo voltee sobre el mismo eje que flip_h.
func setup(cell_top_left: Vector2) -> void:
	name = "AimRig"
	visible = false
	_cell = Node2D.new()
	_cell.position = cell_top_left
	add_child(_cell)

	_still_legs = _region(0, LEGS_ROW)
	for column in range(RUN_FRAME_COUNT):
		_run_legs.append(_region(column + 1, LEGS_ROW))
	for column in range(GUN_FRAME_COUNT):
		_gun_frames.append(_region(column, GUN_ROW))

	_legs = _make_sprite(_still_legs, Vector2.ZERO)
	_cell.add_child(_legs)

	_torso_pivot = Node2D.new()
	_torso_pivot.position = HIP
	_cell.add_child(_torso_pivot)
	_torso_pivot.add_child(_make_sprite(_region(0, BODY_ROW), -HIP))

	_gun_pivot = Node2D.new()
	_gun_pivot.position = SHOULDER - HIP
	_torso_pivot.add_child(_gun_pivot)
	_gun = _make_sprite(_gun_frames[0], -SHOULDER)
	_gun_pivot.add_child(_gun)

	_gun_tip = Marker2D.new()
	_gun_tip.position = GUN_TIP - SHOULDER
	_gun_pivot.add_child(_gun_tip)


## Reinicia el fogonazo de la boca del arma.
func play_flash() -> void:
	_flash_time = 0.0


## Orienta cuerpo y arma hacia target (posición global). moving indica si las
## piernas corren y backwards si corre en sentido contrario al que mira.
func update_pose(target: Vector2, moving: bool, backwards: bool, delta: float) -> void:
	_flash_time += delta
	var flash_frame := int(_flash_time * FLASH_FPS)
	_gun.texture = _gun_frames[flash_frame if flash_frame < GUN_FRAME_COUNT else 0]

	if moving:
		_run_time += delta
		var frame := int(_run_time * RUN_FPS) % RUN_FRAME_COUNT
		if backwards:
			frame = RUN_FRAME_COUNT - 1 - frame
		_legs.texture = _run_legs[frame]
	else:
		_run_time = 0.0
		_legs.texture = _still_legs

	# to_local ya tiene en cuenta el volteo (scale.x = -1 del rig).
	var to_target := _cell.to_local(target) - SHOULDER
	var barrel_height := SHOULDER.y - GUN_TIP.y
	var distance := maxf(to_target.length(), absf(barrel_height) + 1.0)
	var angle := wrapf(to_target.angle() + asin(barrel_height / distance), -PI, PI)
	angle = clampf(angle, -MAX_AIM_ANGLE, MAX_AIM_ANGLE)
	var lean := clampf(angle * LEAN_FACTOR, -MAX_LEAN, MAX_LEAN)
	_torso_pivot.rotation = lean
	_gun_pivot.rotation = angle - lean


func get_gun_tip_position() -> Vector2:
	return _gun_tip.global_position


func _region(column: int, row: int) -> AtlasTexture:
	var region := AtlasTexture.new()
	region.atlas = PARTS_TEXTURE
	region.region = Rect2(Vector2(column * CELL_SIZE.x, row * CELL_SIZE.y), Vector2(CELL_SIZE))
	return region


func _make_sprite(texture: Texture2D, offset_position: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.position = offset_position
	return sprite
