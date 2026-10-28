class_name OffscreenIndicators
extends Control

## Flechas en el borde de la pantalla que apuntan a los enemigos que están
## fuera de cuadro. Toman el color de cada enemigo, crecen cuando el enemigo
## está cerca y el jefe tiene una flecha roja más grande con su nombre.

const MARGIN: float = 34.0
const MIN_SIZE: float = 14.0
const MAX_SIZE: float = 26.0
## A esta distancia del borde la flecha ya es del tamaño mínimo.
const FAR_DISTANCE: float = 900.0
const BOSS_COLOR: Color = Color(1.0, 0.2, 0.2)

var _font: Font
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect()
	if screen.size.x <= MARGIN * 2.0 or screen.size.y <= MARGIN * 2.0:
		return
	var canvas := get_viewport().get_canvas_transform()
	var center := screen.get_center()
	var half := screen.size * 0.5 - Vector2(MARGIN, MARGIN)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var on_screen := canvas * enemy.global_position
		if screen.grow(-8.0).has_point(on_screen):
			continue
		var offset := on_screen - center
		if offset == Vector2.ZERO:
			continue
		# Punto del borde (con margen) en la dirección del enemigo.
		var scale_to_edge := minf(
			half.x / maxf(absf(offset.x), 0.001),
			half.y / maxf(absf(offset.y), 0.001)
		)
		var edge_point := center + offset * scale_to_edge
		var distance := on_screen.distance_to(edge_point)
		var closeness := 1.0 - clampf(distance / FAR_DISTANCE, 0.0, 1.0)
		var is_boss := enemy.is_in_group("boss")
		var arrow_size := lerpf(MIN_SIZE, MAX_SIZE, closeness)
		var color := _enemy_color(enemy)
		if is_boss:
			arrow_size = MAX_SIZE * 1.6 + 3.0 * sin(_time * 8.0)
			color = BOSS_COLOR
		color.a = lerpf(0.55, 1.0, closeness) if not is_boss else 1.0
		_draw_arrow(edge_point, offset.angle(), arrow_size, color)
		if is_boss:
			var label_pos := edge_point - offset.normalized() * (arrow_size + 26.0)
			draw_string_outline(_font, label_pos + Vector2(-34, 6), "JEFE", HORIZONTAL_ALIGNMENT_CENTER, 68, 18, 5, Color.BLACK)
			draw_string(_font, label_pos + Vector2(-34, 6), "JEFE", HORIZONTAL_ALIGNMENT_CENTER, 68, 18, color)


func _draw_arrow(tip_center: Vector2, angle: float, arrow_size: float, color: Color) -> void:
	var points := PackedVector2Array([
		Vector2(arrow_size, 0),
		Vector2(-arrow_size * 0.7, arrow_size * 0.75),
		Vector2(-arrow_size * 0.35, 0),
		Vector2(-arrow_size * 0.7, -arrow_size * 0.75),
	])
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(tip_center + point.rotated(angle))
	var outline := transformed.duplicate()
	outline.append(transformed[0])
	draw_colored_polygon(transformed, color)
	draw_polyline(outline, Color(0, 0, 0, color.a * 0.8), 2.0)


func _enemy_color(enemy: Node2D) -> Color:
	var sprite := enemy.get_node_or_null("AnimatedSprite2D") as CanvasItem
	var hit_flash := enemy.get_node_or_null("HitFlashComponent")
	var color := Color(1.0, 0.85, 0.35)
	if hit_flash != null and "_original_modulate" in hit_flash:
		color = hit_flash._original_modulate
	elif sprite != null:
		color = sprite.modulate
	# Sin tinte (blanco): amarillo de alerta.
	if color.r > 0.95 and color.g > 0.95 and color.b > 0.95:
		color = Color(1.0, 0.85, 0.35)
	return Color(minf(color.r, 1.0), minf(color.g, 1.0), minf(color.b, 1.0), 1.0)
