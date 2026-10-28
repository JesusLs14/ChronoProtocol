extends Node

## Autoload "GameSettings": volumen de la música y de los efectos.
## Crea los buses "Music" y "SFX", manda la música al primero y todos los
## demás sonidos al segundo, y guarda los valores en user://settings.cfg.

const SETTINGS_PATH: String = "user://settings.cfg"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

var music_volume: float = 0.8
var sfx_volume: float = 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load()
	_apply()
	get_tree().node_added.connect(_on_node_added)
	# Sonidos que ya estaban en el árbol antes que este autoload (la música y
	# los reproductores de Sfx).
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


## Dos deslizadores (Música y Efectos) listos para poner en un menú.
func create_volume_controls() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_slider_row("MÚSICA", music_volume, set_music_volume))
	box.add_child(_slider_row("EFECTOS", sfx_volume, _on_sfx_slider_changed))
	return box


func _on_sfx_slider_changed(value: float) -> void:
	set_sfx_volume(value)
	# Un sonido corto para que se oiga el volumen nuevo.
	Sfx.play("hover", 0.0, 0.0)


func _slider_row(title: String, value: float, on_changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(130, 0)
	label.add_theme_font_size_override("font_size", 24)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(200, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var percent := Label.new()
	percent.custom_minimum_size = Vector2(70, 0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.add_theme_font_size_override("font_size", 22)
	percent.text = "%d %%" % roundi(value * 100.0)
	row.add_child(percent)
	slider.value_changed.connect(func(new_value: float) -> void:
		percent.text = "%d %%" % roundi(new_value * 100.0)
		on_changed.call(new_value))
	return row


func _on_node_added(node: Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	if node.name == &"Musica" and node.get_parent() == get_tree().root:
		node.bus = MUSIC_BUS
	elif node.bus == &"Master":
		node.bus = SFX_BUS


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _apply() -> void:
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)


func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(config.get_value("audio", "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)
