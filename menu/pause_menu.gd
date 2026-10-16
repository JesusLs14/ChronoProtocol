class_name PauseMenu
extends CanvasLayer

## Menú de pausa: se abre con la acción "pause" (Esc o Start). No se abre si
## el juego ya está pausado por otra pantalla (tienda o Game Over).

@export_file("*.tscn") var main_menu_path: String = "res://menu/main_menu.tscn"

@onready var resume_button: Button = $Panel/Buttons/ResumeButton
@onready var restart_button: Button = $Panel/Buttons/RestartButton
@onready var menu_button: Button = $Panel/Buttons/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(close)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible:
		close()
	elif not get_tree().paused:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	show()
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_path)
