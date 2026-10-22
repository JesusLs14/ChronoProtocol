class_name KillStreak
extends Node

## Racha de bajas seguidas, al estilo del contador de masacre de Diablo.
## Cada baja reinicia un tiempo límite; si se acaba o el jugador recibe daño,
## la racha termina. Al llegar a ciertas cifras se dan recompensas.

signal streak_changed(count: int)
signal reward_granted(title: String, description: String)
signal streak_ended(final_count: int)

## Segundos que hay para conseguir la siguiente baja.
@export var streak_window: float = 4.0
@export var player_path: NodePath = ^"../player"

## Recompensas fijas: bajas -> [tipo, título, descripción].
const REWARDS: Dictionary = {
	10: ["heal_1", "¡RACHA x10!", "+1 de vida"],
	20: ["shield", "¡ESCUDO!", "Bloquea los próximos 2 golpes"],
	30: ["boost", "¡SOBRECARGA!", "Más velocidad y doble cadencia por 6 s"],
	50: ["massacre", "¡MASACRE!", "+3 de vida y escudo de 3 golpes"],
}
## Desde 50, cada 25 bajas más se repiten estas recompensas en orden.
const REPEAT_EVERY: int = 25
const REPEAT_REWARDS: Array = [
	["boost", "¡IMPARABLE!", "Más velocidad y doble cadencia por 6 s"],
	["shield", "¡ESCUDO!", "Bloquea los próximos 2 golpes"],
	["heal_2", "¡CARNICERÍA!", "+2 de vida"],
]

var count: int = 0
var best: int = 0
var time_left: float = 0.0

var _player: Player
# Entre oleadas (transición, tienda) la racha se congela y no se pierde.
var _held: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Player
	if _player == null:
		push_error("KillStreak requires a Player at player_path.")
		return
	_player.damaged.connect(_end_streak)


func _process(delta: float) -> void:
	if count == 0 or _held:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left == 0.0:
		_end_streak()


func register_kill() -> void:
	count += 1
	best = maxi(best, count)
	time_left = streak_window
	streak_changed.emit(count)
	var reward := _reward_for(count)
	if not reward.is_empty():
		_grant(reward)


## Congela la racha (fin de oleada) o la reanuda con el tiempo completo
## (inicio de la siguiente oleada).
func hold(held: bool) -> void:
	_held = held
	if not held and count > 0:
		time_left = streak_window
		streak_changed.emit(count)


## Siguiente cifra que da recompensa y qué da, para mostrarla en el HUD.
func next_reward() -> Array:
	for threshold: int in REWARDS.keys():
		if threshold > count:
			return [threshold, REWARDS[threshold][2]]
	var last: int = REWARDS.keys().max()
	var steps := int((count - last) / REPEAT_EVERY) + 1
	var reward: Array = REPEAT_REWARDS[(steps - 1) % REPEAT_REWARDS.size()]
	return [last + steps * REPEAT_EVERY, reward[2]]


func time_ratio() -> float:
	return time_left / streak_window


func _reward_for(kills: int) -> Array:
	if REWARDS.has(kills):
		return REWARDS[kills]
	var last: int = REWARDS.keys().max()
	if kills > last and (kills - last) % REPEAT_EVERY == 0:
		var index := ((kills - last) / REPEAT_EVERY - 1) % REPEAT_REWARDS.size()
		return REPEAT_REWARDS[index]
	return []


func _grant(reward: Array) -> void:
	if _player == null or _player.is_dead:
		return
	match reward[0]:
		"heal_1":
			_player.heal(1)
		"heal_2":
			_player.heal(2)
		"shield":
			_player.add_shield(2)
		"boost":
			_player.apply_boost(6.0)
		"massacre":
			_player.heal(3)
			_player.add_shield(3)
	reward_granted.emit(reward[1], reward[2])


func _end_streak() -> void:
	if count == 0:
		return
	var final_count := count
	count = 0
	time_left = 0.0
	streak_ended.emit(final_count)
