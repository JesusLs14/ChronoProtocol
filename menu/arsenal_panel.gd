class_name ArsenalPanel
extends Panel

## Arsenal del menú principal: mejoras permanentes que se compran con los
## fragmentos guardados al terminar cada partida (GameStats.bank). Cada fila
## muestra el nivel, el efecto y el costo del siguiente nivel.

signal closed

var back_button: Button

var _bank_label: Label
var _status_label: Label
var _rows: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -470.0
	offset_right = 470.0
	offset_top = -110.0
	offset_bottom = 450.0

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40.0
	box.offset_right = -40.0
	box.offset_top = 22.0
	box.offset_bottom = -22.0
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "ARSENAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.3, 1, 0.95))
	box.add_child(title)

	_bank_label = Label.new()
	_bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bank_label.add_theme_font_size_override("font_size", 22)
	_bank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(_bank_label)

	for id: String in GameStats.UNLOCKS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(_on_buy_pressed.bind(id))
		box.add_child(button)
		_rows[id] = button

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 19)
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_status_label.text = "Los fragmentos que te sobran al terminar una partida se guardan aquí"
	box.add_child(_status_label)

	back_button = Button.new()
	back_button.text = "VOLVER"
	back_button.custom_minimum_size = Vector2(260, 60)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func() -> void: closed.emit())
	box.add_child(back_button)
	refresh()


func refresh() -> void:
	_bank_label.text = "Fragmentos guardados: %d" % GameStats.bank
	for id: String in _rows:
		var data: Dictionary = GameStats.UNLOCKS[id]
		var button: Button = _rows[id]
		var level := GameStats.unlock_level(id)
		var max_level := GameStats.unlock_max_level(id)
		if level >= max_level:
			button.text = "%s  Nv. %d/%d — MÁXIMO  (%s)" % [data["name"], level, max_level, data["effect"]]
			button.disabled = true
		else:
			button.text = "%s  Nv. %d/%d — %d fragmentos  (%s)" % [
				data["name"], level, max_level, GameStats.unlock_cost(id), data["effect"],
			]
			button.disabled = false


func _on_buy_pressed(id: String) -> void:
	var name_text: String = GameStats.UNLOCKS[id]["name"]
	if GameStats.buy_unlock(id):
		_status_label.text = "%s mejorado a nivel %d" % [name_text, GameStats.unlock_level(id)]
	else:
		_status_label.text = "No tienes suficientes fragmentos guardados"
	refresh()
