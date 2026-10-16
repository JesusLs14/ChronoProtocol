extends Node

## Efectos de sonido globales (autoload "Sfx").
## - Sfx.play("explosion") desde cualquier script.
## - Todos los botones del juego suenan solos al pulsarlos y al pasar por
##   ellos con el ratón o el mando.

const SOUNDS: Dictionary = {
	"explosion": preload("res://sfx/explosion.wav"),
	"click": preload("res://sfx/ui_click.wav"),
	"hover": preload("res://sfx/ui_hover.wav"),
	"pickup": preload("res://sfx/pickup.wav"),
}
const POOL_SIZE: int = 8
## Tiempo mínimo entre dos reproducciones del mismo sonido, para que el imán
## de fragmentos no sature al recoger muchos a la vez.
const MIN_REPEAT_INTERVAL: float = 0.045

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _last_played_ms: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	# Botones que ya estaban en el árbol antes que este autoload.
	for button in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(button)


func play(sound_name: String, volume_db: float = 0.0, pitch_variation: float = 0.0) -> void:
	var stream: AudioStream = SOUNDS.get(sound_name)
	if stream == null:
		push_error("Unknown sound: %s" % sound_name)
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played_ms.get(sound_name, -100000)) < MIN_REPEAT_INTERVAL * 1000.0:
		return
	_last_played_ms[sound_name] = now

	var player := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta(&"sfx_connected"):
		return
	button.set_meta(&"sfx_connected", true)
	button.pressed.connect(play.bind("click", 0.0, 0.0))
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	button.focus_entered.connect(_on_button_hovered.bind(button))


func _on_button_hovered(button: BaseButton) -> void:
	if button.is_visible_in_tree() and not button.disabled:
		play("hover", -6.0)
