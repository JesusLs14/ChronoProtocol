class_name StratagemController
extends Node

## Estratagemas al estilo Helldivers 2: se mantiene Ctrl (o Q), se mete la
## combinación con WASD o las flechas y la baliza se lanza hacia el ratón.
## Mientras se mete la combinación el soldado no camina.

signal entering_changed(active: bool)
signal input_changed(sequence: Array)
signal stratagem_called(id: String)

enum Dir { UP, DOWN, LEFT, RIGHT }

const STRATAGEMS: Array[Dictionary] = [
	{
		"id": "orbital",
		"name": "Ataque orbital",
		"code": [Dir.RIGHT, Dir.DOWN, Dir.UP, Dir.RIGHT],
		"cooldown": 30.0,
		"color": Color(1.0, 0.3, 0.2),
	},
	{
		"id": "supply",
		"name": "Suministros",
		"code": [Dir.DOWN, Dir.DOWN, Dir.UP, Dir.RIGHT],
		"cooldown": 40.0,
		"color": Color(0.3, 0.9, 1.0),
	},
	{
		"id": "turret",
		"name": "Torreta",
		"code": [Dir.DOWN, Dir.UP, Dir.RIGHT, Dir.LEFT],
		"cooldown": 45.0,
		"color": Color(0.4, 1.0, 0.4),
	},
	{
		"id": "airstrike",
		"name": "Ataque aéreo",
		"code": [Dir.UP, Dir.RIGHT, Dir.DOWN, Dir.RIGHT],
		"cooldown": 35.0,
		"color": Color(1.0, 0.8, 0.2),
	},
	{
		"id": "ems",
		"name": "Pulso EMS",
		"code": [Dir.DOWN, Dir.LEFT, Dir.UP, Dir.LEFT],
		"cooldown": 50.0,
		"color": Color(0.6, 0.55, 1.0),
	},
]
## Distancia máxima a la que se lanza la baliza.
const THROW_RANGE: float = 650.0
const BEACON_SCENE: PackedScene = preload("res://player/stratagems/stratagem_beacon.tscn")

@export var player_path: NodePath = ^".."

var entering: bool = false
var sequence: Array = []
var cooldowns: Dictionary = {}
## Menos de 1 = recargas más rápidas (mejora Logística orbital del Arsenal).
var cooldown_multiplier: float = 1.0

var _player: Player


func _ready() -> void:
	_player = get_node(player_path) as Player
	for stratagem in STRATAGEMS:
		cooldowns[stratagem["id"]] = 0.0


func _process(delta: float) -> void:
	for id: String in cooldowns:
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
	var holding := Input.is_action_pressed("stratagem") and not _player.is_dead and not _player.in_cinematic
	if holding != entering:
		entering = holding
		sequence.clear()
		entering_changed.emit(entering)
		input_changed.emit(sequence)


func _unhandled_input(event: InputEvent) -> void:
	if not entering:
		return
	var direction := _direction_from(event)
	if direction < 0:
		return
	get_viewport().set_input_as_handled()
	sequence.append(direction)
	Sfx.play("hover", -4.0, 0.0)

	var any_match := false
	for stratagem in STRATAGEMS:
		var code: Array = stratagem["code"]
		if not _starts_with(code, sequence):
			continue
		any_match = true
		if code.size() == sequence.size():
			_call(stratagem)
			return
	if not any_match:
		# Combinación equivocada: se empieza de nuevo.
		sequence.clear()
		Sfx.play("click", -10.0, 0.0)
	input_changed.emit(sequence)


func is_ready(id: String) -> bool:
	return cooldowns.get(id, 0.0) <= 0.0


func cooldown_ratio(id: String) -> float:
	for stratagem in STRATAGEMS:
		if stratagem["id"] == id:
			return cooldowns[id] / (stratagem["cooldown"] * cooldown_multiplier)
	return 0.0


func _call(stratagem: Dictionary) -> void:
	sequence.clear()
	input_changed.emit(sequence)
	var id: String = stratagem["id"]
	if not is_ready(id):
		Sfx.play("click", -10.0, 0.0)
		return
	cooldowns[id] = stratagem["cooldown"] * cooldown_multiplier
	var from := _player.global_position
	var target := _player._get_aim_position()
	if from.distance_to(target) > THROW_RANGE:
		target = from + from.direction_to(target) * THROW_RANGE
	var beacon := BEACON_SCENE.instantiate() as StratagemBeacon
	beacon.setup(id, stratagem["color"], from, target)
	_player.get_parent().add_child(beacon)
	Sfx.play("click", 0.0, 0.0)
	stratagem_called.emit(id)


func _starts_with(code: Array, entered: Array) -> bool:
	if entered.size() > code.size():
		return false
	for index in entered.size():
		if code[index] != entered[index]:
			return false
	return true


func _direction_from(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return -1
		match key.physical_keycode:
			KEY_W, KEY_UP:
				return Dir.UP
			KEY_S, KEY_DOWN:
				return Dir.DOWN
			KEY_A, KEY_LEFT:
				return Dir.LEFT
			KEY_D, KEY_RIGHT:
				return Dir.RIGHT
		return -1
	var button := event as InputEventJoypadButton
	if button != null and button.pressed:
		match button.button_index:
			JOY_BUTTON_DPAD_UP:
				return Dir.UP
			JOY_BUTTON_DPAD_DOWN:
				return Dir.DOWN
			JOY_BUTTON_DPAD_LEFT:
				return Dir.LEFT
			JOY_BUTTON_DPAD_RIGHT:
				return Dir.RIGHT
	return -1
