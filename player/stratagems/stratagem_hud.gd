class_name StratagemHud
extends Control

## Panel de estratagemas a la izquierda. Siempre muestra cada estratagema con
## su recarga; al mantener Ctrl/Q se ilumina, muestra las combinaciones y
## marca las flechas ya metidas.

@export var controller_path: NodePath = ^"../../StratagemController"

const ROW_HEIGHT: float = 58.0
const WIDTH: float = 330.0
const ARROW_SIZE: float = 22.0
const ARROW_GAP: float = 30.0

var _controller: StratagemController
var _sequence: Array = []
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	_controller = get_node_or_null(controller_path) as StratagemController
	if _controller == null:
		push_error("StratagemHud requires a StratagemController at controller_path.")
		return
	_controller.input_changed.connect(func(sequence: Array) -> void: _sequence = sequence.duplicate())
	custom_minimum_size = Vector2(WIDTH, ROW_HEIGHT * StratagemController.STRATAGEMS.size() + 34)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _controller == null:
		return
	var entering := _controller.entering
	var alpha := 1.0 if entering else 0.55
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.75 if entering else 0.35))
	draw_rect(Rect2(0, 0, 4, size.y), Color(1, 0.8, 0.25, alpha))
	var header := "ESTRATAGEMAS" if entering else "ESTRATAGEMAS  (mantén Ctrl o Q)"
	draw_string(_font, Vector2(14, 22), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.85, 0.3, alpha))

	for index in StratagemController.STRATAGEMS.size():
		var stratagem: Dictionary = StratagemController.STRATAGEMS[index]
		var top := 34.0 + index * ROW_HEIGHT
		var id: String = stratagem["id"]
		var ready := _controller.is_ready(id)
		var color: Color = stratagem["color"]
		var code: Array = stratagem["code"]
		var matches := entering and _starts_with(code, _sequence)
		var row_alpha := alpha if ready else alpha * 0.45

		# Icono: círculo de color con la recarga como arco.
		var icon_center := Vector2(32, top + 22)
		draw_circle(icon_center, 16.0, Color(color, 0.25 * row_alpha))
		draw_arc(icon_center, 16.0, 0.0, TAU, 24, Color(color, row_alpha), 2.0)
		if not ready:
			var left := _controller.cooldown_ratio(id)
			draw_arc(icon_center, 10.0, -PI * 0.5, -PI * 0.5 + TAU * left, 24, Color(color, 0.9), 5.0)
			var seconds := "%d" % ceili(_controller.cooldowns[id])
			draw_string(_font, Vector2(WIDTH - 40, top + 16), seconds + " s", HORIZONTAL_ALIGNMENT_RIGHT, 30, 15, Color(1, 1, 1, 0.8))

		draw_string(_font, Vector2(58, top + 16), stratagem["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, row_alpha))
		# Flechas de la combinación; las ya metidas se pintan del color.
		for arrow_index in code.size():
			var entered: bool = matches and arrow_index < _sequence.size()
			var arrow_color := Color(color, 1.0) if entered else Color(1, 1, 1, row_alpha * (0.95 if matches or not entering else 0.35))
			_draw_arrow(Vector2(68 + arrow_index * ARROW_GAP, top + 38), code[arrow_index], arrow_color)


func _draw_arrow(center: Vector2, direction: int, color: Color) -> void:
	var half := ARROW_SIZE * 0.5
	var points := PackedVector2Array([Vector2(0, -half), Vector2(half, half * 0.4), Vector2(-half, half * 0.4)])
	var angle := 0.0
	match direction:
		StratagemController.Dir.DOWN:
			angle = PI
		StratagemController.Dir.LEFT:
			angle = -PI * 0.5
		StratagemController.Dir.RIGHT:
			angle = PI * 0.5
	var rotated := PackedVector2Array()
	for point in points:
		rotated.append(center + point.rotated(angle))
	draw_colored_polygon(rotated, color)


func _starts_with(code: Array, entered: Array) -> bool:
	if entered.size() > code.size():
		return false
	for index in entered.size():
		if code[index] != entered[index]:
			return false
	return true
