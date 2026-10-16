extends Control

## Menú principal: Jugar abre la arena, Controles muestra las teclas y Salir
## cierra el juego.

@export_file("*.tscn") var game_scene_path: String = "res://player/main.tscn"

@onready var buttons: VBoxContainer = $Buttons
@onready var play_button: Button = $Buttons/PlayButton
@onready var controls_button: Button = $Buttons/ControlsButton
@onready var quit_button: Button = $Buttons/QuitButton
@onready var controls_panel: Panel = $ControlsPanel
@onready var back_button: Button = $ControlsPanel/BackButton
@onready var title_label: Label = $TitleLabel


func _ready() -> void:
	get_tree().paused = false
	play_button.pressed.connect(_on_play_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	controls_panel.hide()
	play_button.grab_focus()
	_animate_title()


func _unhandled_input(event: InputEvent) -> void:
	if controls_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
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


func _on_quit_pressed() -> void:
	get_tree().quit()
