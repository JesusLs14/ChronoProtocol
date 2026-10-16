# Regenera soldier_frames.png y soldier_sprite_frames.tres a partir de
# soldier_sheet_source.png (copia sin modificar del sprite sheet original).
#
# Uso (desde la carpeta del proyecto):
#   godot --headless --path . --script res://player/soldier/extract_soldier_frames.gd
#
# El sprite sheet original no sigue una cuadrícula uniforme (la fila del dash
# y la de daño/muerte tienen otro espaciado, y el fogonazo de un frame de
# disparo toca la bufanda del siguiente). Por eso cada frame se define por su
# franja vertical y su rango horizontal, y los píxeles se asignan a cada frame
# por componentes conectados, no por rectángulos.
extends SceneTree

const SOURCE_PATH: String = "res://player/soldier/soldier_sheet_source.png"
const FRAMES_PATH: String = "res://player/soldier/soldier_frames.png"
const SPRITE_FRAMES_PATH: String = "res://player/soldier/soldier_sprite_frames.tres"

# Celda normalizada: el centro del casco queda en CELL_ANCHOR_X y la línea de
# los pies en CELL_FEET_Y, así no hay saltos de posición entre frames y el
# volteo horizontal (flip_h) es simétrico respecto al personaje.
const CELL_SIZE: Vector2i = Vector2i(144, 72)
const CELL_ANCHOR_X: int = 72
const CELL_FEET_Y: int = 66
const COLUMNS: int = 8

# Umbral para separar figuras: los píxeles semitransparentes por debajo de él
# se adjuntan a la figura sólida más cercana en lugar de unir figuras vecinas.
const SOLID_ALPHA: float = 0.25

enum Anchor { HELMET, REAR_FOOT }

# Franjas verticales [y_inicio, y_fin) de cada fila del sheet original.
const BANDS: Array[Vector2i] = [
	Vector2i(0, 72), Vector2i(72, 138), Vector2i(138, 206), Vector2i(206, 265), Vector2i(265, 332),
]

# Rangos horizontales [x_min, x_max] de cada figura, medidos sobre el original.
const SEGMENTS: Array = [
	[Vector2i(11, 65), Vector2i(85, 139), Vector2i(160, 214), Vector2i(234, 288),
		Vector2i(308, 362), Vector2i(383, 437), Vector2i(457, 511), Vector2i(532, 586)],
	[Vector2i(8, 70), Vector2i(83, 144), Vector2i(156, 219), Vector2i(232, 293),
		Vector2i(305, 367), Vector2i(380, 441), Vector2i(454, 516), Vector2i(529, 590)],
	[Vector2i(5, 74), Vector2i(80, 148), Vector2i(153, 222), Vector2i(228, 296),
		Vector2i(301, 369), Vector2i(372, 446), Vector2i(447, 514), Vector2i(517, 590)],
	[Vector2i(21, 112), Vector2i(137, 226), Vector2i(250, 340), Vector2i(363, 454),
		Vector2i(478, 568)],
	[Vector2i(7, 77), Vector2i(93, 159), Vector2i(172, 247), Vector2i(266, 320),
		Vector2i(339, 400), Vector2i(417, 489), Vector2i(504, 576)],
]

# Animaciones: fila del original, índices de frame (0 = primera figura de la
# fila), velocidad en FPS, bucle y modo de anclaje.
const ANIMATIONS: Array[Dictionary] = [
	{"name": "idle", "row": 0, "frames": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 8.0, "loop": true,
		"anchor": Anchor.HELMET},
	{"name": "run", "row": 1, "frames": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 12.0, "loop": true,
		"anchor": Anchor.HELMET},
	# Último frame de apuntado + los tres con fogonazo: dura 0.25 s, igual que
	# el intervalo de disparo del arma inicial.
	{"name": "shoot", "row": 2, "frames": [4, 5, 6, 7], "fps": 16.0, "loop": false,
		"anchor": Anchor.HELMET},
	{"name": "dash", "row": 3, "frames": [0, 1, 2, 3, 4], "fps": 24.0, "loop": true,
		"anchor": Anchor.HELMET},
	{"name": "hurt", "row": 4, "frames": [0, 1], "fps": 8.0, "loop": false,
		"anchor": Anchor.HELMET},
	# La muerte mantiene fijo el pie trasero para que el cuerpo caiga hacia
	# delante sin deslizarse.
	{"name": "death", "row": 4, "frames": [2, 3, 4, 5, 6], "fps": 8.0, "loop": false,
		"anchor": Anchor.REAR_FOOT},
]

var _source: Image
var _labels: PackedInt32Array
var _width: int = 0
var _height: int = 0


func _init() -> void:
	_source = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if _source == null or _source.is_empty():
		push_error("No se pudo cargar %s" % SOURCE_PATH)
		quit(1)
		return
	_source.convert(Image.FORMAT_RGBA8)
	_width = _source.get_width()
	_height = _source.get_height()
	_label_figures()

	var rows: int = 0
	for animation: Dictionary in ANIMATIONS:
		rows += ceili(float((animation["frames"] as Array).size()) / COLUMNS)
	var sheet := Image.create(CELL_SIZE.x * COLUMNS, CELL_SIZE.y * rows, false, Image.FORMAT_RGBA8)

	var regions: Dictionary = {}
	var cell_row: int = 0
	for animation: Dictionary in ANIMATIONS:
		var animation_regions: Array[Rect2i] = []
		var row: int = animation["row"]
		var frames: Array = animation["frames"]
		var rear_foot_offset: int = 0
		for i in range(frames.size()):
			var cell := Vector2i((i % COLUMNS) * CELL_SIZE.x, (cell_row + i / COLUMNS) * CELL_SIZE.y)
			var frame_index: int = frames[i]
			var mask := _frame_mask(row, frame_index)
			var anchor_x: int = _helmet_center_x(mask)
			if animation["anchor"] == Anchor.REAR_FOOT:
				# El primer frame se alinea por el casco, igual que "hurt"; los
				# siguientes conservan la posición de su pie trasero.
				if i == 0:
					rear_foot_offset = _rear_foot_x(mask) - anchor_x
				anchor_x = _rear_foot_x(mask) - rear_foot_offset
			var shift := Vector2i(cell.x + CELL_ANCHOR_X - anchor_x, cell.y + CELL_FEET_Y - _feet_y(mask))
			if not _blit(mask, sheet, shift, Rect2i(cell, CELL_SIZE)):
				push_error("El frame %d de la fila %d no cabe en la celda" % [frame_index, row])
				quit(1)
				return
			animation_regions.append(Rect2i(cell, CELL_SIZE))
		regions[animation["name"]] = animation_regions
		cell_row += ceili(float(frames.size()) / COLUMNS)

	var error := sheet.save_png(ProjectSettings.globalize_path(FRAMES_PATH))
	if error != OK:
		push_error("No se pudo guardar %s" % FRAMES_PATH)
		quit(1)
		return
	_write_sprite_frames(regions)
	print("Frames extraídos: %s y %s" % [FRAMES_PATH, SPRITE_FRAMES_PATH])
	quit()


# Etiqueta las figuras sólidas con 8-conectividad y después adjunta los
# píxeles semitransparentes a la figura sólida más cercana.
func _label_figures() -> void:
	_labels = PackedInt32Array()
	_labels.resize(_width * _height)
	_labels.fill(-1)
	var next_label: int = 0
	for y in range(_height):
		for x in range(_width):
			if _labels[y * _width + x] != -1 or _alpha(x, y) < SOLID_ALPHA:
				continue
			_flood(Vector2i(x, y), next_label, SOLID_ALPHA)
			next_label += 1

	var frontier: Array[Vector2i] = []
	for y in range(_height):
		for x in range(_width):
			if _labels[y * _width + x] != -1:
				frontier.append(Vector2i(x, y))
	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for point in frontier:
			var label: int = _labels[point.y * _width + point.x]
			for neighbor in _neighbors(point):
				var index: int = neighbor.y * _width + neighbor.x
				if _labels[index] == -1 and _alpha(neighbor.x, neighbor.y) > 0.0:
					_labels[index] = label
					next_frontier.append(neighbor)
		frontier = next_frontier

	# Partículas semitransparentes aisladas (estelas, chispas).
	for y in range(_height):
		for x in range(_width):
			if _labels[y * _width + x] == -1 and _alpha(x, y) > 0.0:
				_flood(Vector2i(x, y), next_label, 0.0)
				next_label += 1


func _flood(start: Vector2i, label: int, min_alpha: float) -> void:
	var stack: Array[Vector2i] = [start]
	_labels[start.y * _width + start.x] = label
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		for neighbor in _neighbors(point):
			var index: int = neighbor.y * _width + neighbor.x
			var alpha: float = _alpha(neighbor.x, neighbor.y)
			if _labels[index] == -1 and alpha > 0.0 and alpha >= min_alpha:
				_labels[index] = label
				stack.append(neighbor)


func _neighbors(point: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var neighbor := point + Vector2i(dx, dy)
			if (dx != 0 or dy != 0) and neighbor.x >= 0 and neighbor.y >= 0 \
					and neighbor.x < _width and neighbor.y < _height:
				result.append(neighbor)
	return result


# Píxeles de una figura: las etiquetas cuyo centro cae en el rango del frame.
func _frame_mask(row: int, frame_index: int) -> Array[Vector2i]:
	var band: Vector2i = BANDS[row]
	var segment: Vector2i = (SEGMENTS[row] as Array)[frame_index]
	var bounds: Dictionary = {}
	for y in range(band.x, band.y):
		for x in range(_width):
			var label: int = _labels[y * _width + x]
			if label == -1:
				continue
			var span: Vector2i = bounds.get(label, Vector2i(x, x))
			bounds[label] = Vector2i(mini(span.x, x), maxi(span.y, x))
	var mask: Array[Vector2i] = []
	for y in range(band.x, band.y):
		for x in range(_width):
			var label: int = _labels[y * _width + x]
			if label == -1:
				continue
			var span: Vector2i = bounds[label]
			var center: float = (span.x + span.y) * 0.5
			if center >= segment.x and center <= segment.y + 0.5:
				mask.append(Vector2i(x, y))
	return mask


func _is_body_pixel(point: Vector2i) -> bool:
	var color := _source.get_pixelv(point)
	var is_scarf: bool = color.r > color.b + 0.15 and color.r > color.g + 0.1
	return color.a > 0.9 and not is_scarf


func _feet_y(mask: Array[Vector2i]) -> int:
	var bottom: int = 0
	for point in mask:
		if _is_body_pixel(point):
			bottom = maxi(bottom, point.y)
	return bottom


func _top_y(mask: Array[Vector2i]) -> int:
	var top: int = _height
	for point in mask:
		if _is_body_pixel(point):
			top = mini(top, point.y)
	return top


# Centro horizontal de las 8 filas superiores del cuerpo (el casco).
func _helmet_center_x(mask: Array[Vector2i]) -> int:
	var top: int = _top_y(mask)
	var total: float = 0.0
	var count: int = 0
	for point in mask:
		if point.y < top + 8 and _is_body_pixel(point):
			total += point.x
			count += 1
	return roundi(total / maxi(count, 1))


# Píxel del cuerpo más a la izquierda en las 5 filas inferiores (pie trasero).
func _rear_foot_x(mask: Array[Vector2i]) -> int:
	var bottom: int = _feet_y(mask)
	var left: int = _width
	for point in mask:
		if point.y > bottom - 5 and _is_body_pixel(point):
			left = mini(left, point.x)
	return left


func _blit(mask: Array[Vector2i], sheet: Image, shift: Vector2i, cell: Rect2i) -> bool:
	for point in mask:
		var target := point + shift
		if not cell.has_point(target):
			return false
		sheet.set_pixelv(target, _source.get_pixelv(point))
	return true


func _alpha(x: int, y: int) -> float:
	return _source.get_pixel(x, y).a


func _write_sprite_frames(regions: Dictionary) -> void:
	var lines: PackedStringArray = []
	var sub_resources: PackedStringArray = []
	var animations: PackedStringArray = []
	var next_id: int = 1
	for animation: Dictionary in ANIMATIONS:
		var frames: PackedStringArray = []
		for region: Rect2i in regions[animation["name"]]:
			var id := "AtlasTexture_%d" % next_id
			next_id += 1
			sub_resources.append(
				"[sub_resource type=\"AtlasTexture\" id=\"%s\"]\natlas = ExtResource(\"1_frames\")\nregion = Rect2(%d, %d, %d, %d)\n"
				% [id, region.position.x, region.position.y, region.size.x, region.size.y]
			)
			frames.append("{\n\"duration\": 1.0,\n\"texture\": SubResource(\"%s\")\n}" % id)
		animations.append(
			"{\n\"frames\": [%s],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %.1f\n}"
			% [", ".join(frames), "true" if animation["loop"] else "false", animation["name"], animation["fps"]]
		)
	lines.append("[gd_resource type=\"SpriteFrames\" format=3]\n")
	lines.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_frames\"]\n" % FRAMES_PATH)
	lines.append_array(sub_resources)
	lines.append("[resource]\nanimations = [%s]\n" % ", ".join(animations))
	var file := FileAccess.open(SPRITE_FRAMES_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo escribir %s" % SPRITE_FRAMES_PATH)
		return
	file.store_string("\n".join(lines))
