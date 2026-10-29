extends Control

## Menú principal: Jugar abre la intro (y después la arena), Controles muestra las teclas,
## Opciones el volumen y Salir cierra el juego. Abajo a la izquierda se ven los récords.

@export_file("*.tscn") var game_scene_path: String = "res://menu/intro.tscn"

@onready var buttons: VBoxContainer = $Buttons
@onready var play_button: Button = $Buttons/PlayButton
@onready var controls_button: Button = $Buttons/ControlsButton
@onready var quit_button: Button = $Buttons/QuitButton
@onready var controls_panel: Panel = $ControlsPanel
@onready var back_button: Button = $ControlsPanel/BackButton
@onready var title_label: Label = $TitleLabel
@onready var options_button: Button = $Buttons/OptionsButton
@onready var options_panel: Panel = $OptionsPanel
@onready var options_back_button: Button = $OptionsPanel/OptionsBackButton
@onready var stats_label: Label = $StatsLabel
@onready var arsenal_button: Button = $Buttons/ArsenalButton
var arsenal_panel: ArsenalPanel


func _ready() -> void:
	get_tree().paused = false
	play_button.pressed.connect(_on_play_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	options_button.pressed.connect(_on_options_pressed)
	options_back_button.pressed.connect(_on_options_back_pressed)
	$OptionsPanel/VolumeSlot.add_child(GameSettings.create_volume_controls())
	stats_label.text = GameStats.summary_text()
	controls_panel.hide()
	options_panel.hide()
	arsenal_panel = ArsenalPanel.new()
	add_child(arsenal_panel)
	arsenal_panel.hide()
	arsenal_panel.closed.connect(_on_arsenal_closed)
	arsenal_button.pressed.connect(_on_arsenal_pressed)
	play_button.grab_focus()
	_animate_title()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if controls_panel.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif options_panel.visible:
		_on_options_back_pressed()
		get_viewport().set_input_as_handled()
	elif arsenal_panel.visible:
		_on_arsenal_closed()
		get_viewport().set_input_as_handled()


func _animate_title() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(title_label, "modulate", Color(0.7, 1.0, 1.0), 1.2)
	tween.tween_property(title_label, "modulate", Color.WHITE, 1.2)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)


func _on_controls_pressed() -> void:
	buttons.hide()
	controls_panel.show()
	back_button.grab_focus()


func _on_back_pressed() -> void:
	controls_panel.hide()
	buttons.show()
	controls_button.grab_focus()


func _on_options_pressed() -> void:
	buttons.hide()
	options_panel.show()
	options_back_button.grab_focus()


func _on_options_back_pressed() -> void:
	options_panel.hide()
	buttons.show()
	options_button.grab_focus()


func _on_arsenal_pressed() -> void:
	buttons.hide()
	arsenal_panel.refresh()
	arsenal_panel.show()
	arsenal_panel.back_button.grab_focus()


func _on_arsenal_closed() -> void:
	arsenal_panel.hide()
	buttons.show()
	arsenal_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
