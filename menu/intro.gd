extends Control

## Intro cinemática estilo transmisión de propaganda (inspirada en Helldivers 2).
## Usa las ilustraciones de menu/intro_art/ y las anima con movimientos de
## cámara, capas que se desplazan, partículas, destellos y temblores.
## Clic, Espacio o Enter pasan a la siguiente toma; Esc salta la intro.

@export_file("*.tscn") var game_scene_path: String = "res://player/main.tscn"
@export var chars_per_second: float = 38.0

const ART := "res://menu/intro_art/"
## Mitad del tamaño útil de la pantalla de referencia (1920×1080).
const HALF_SCREEN := Vector2(960, 540)
const LETTERBOX_HEIGHT: float = 96.0

## Cada toma: función que la arma, duración en segundos y texto en pantalla.
const SHOTS: Array[Dictionary] = [
	{"build": "_shot_orbit", "time": 7.0, "text": "AÑO 2187. EL PROTOCOLO CHRONOS PROTEGE A LA HUMANIDAD."},
	{"build": "_shot_propaganda", "time": 6.5, "text": "CIUDADANO: TU PLANETA TE NECESITA."},
	{"build": "_shot_colony", "time": 6.5, "text": "PERO EN LAS COLONIAS EXTERIORES, ALGO DESPERTÓ."},
	{"build": "_shot_swarm", "time": 5.0, "text": "LA COLMENA."},
	{"build": "_shot_hivelord", "time": 6.5, "text": "EN SU NÚCLEO: EL HIVELORD."},
	{"build": "_shot_drop", "time": 5.0, "text": "POR ESO EXISTE EL SOLDADO CHRONOS."},
	{"build": "_shot_landing", "time": 6.5, "text": "ENTRENADO EN CUATRO MINUTOS. ESPERANZA DE VIDA: CLASIFICADA."},
	{"build": "_shot_final", "time": 8.0, "text": "¡POR LA HUMANIDAD! ¡POR CHRONOS!"},
]

@onready var world: Node2D = $World
@onready var caption_panel: PanelContainer = $UI/CaptionPanel
@onready var caption_label: Label = $UI/CaptionPanel/CaptionLabel
@onready var title_label: Label = $UI/TitleLabel
@onready var top_bar: ColorRect = $UI/TopBar
@onready var bottom_bar: ColorRect = $UI/BottomBar
@onready var flash: ColorRect = $UI/Flash
@onready var fade: ColorRect = $UI/Fade
@onready var live_badge: Label = $UI/LiveBadge

var _shot_index: int = -1
var _shot_time_left: float = 0.0
var _typing: bool = false
var _visible_chars: float = 0.0
var _leaving: bool = false
var _shake_strength: float = 0.0
var _shot_tweens: Array[Tween] = []
var _base_world_position := Vector2.ZERO
var _glow_texture: Texture2D


func _ready() -> void:
	get_tree().paused = false
	fade.color.a = 1.0
	title_label.modulate.a = 0.0
	caption_panel.modulate.a = 0.0
	top_bar.size.y = 0.0
	bottom_bar.size.y = 0.0
	var intro_tween := create_tween().set_parallel()
	intro_tween.tween_property(fade, "color:a", 0.0, 1.0)
	intro_tween.tween_property(top_bar, "size:y", LETTERBOX_HEIGHT, 1.2)
	intro_tween.tween_method(_set_bottom_bar, 0.0, LETTERBOX_HEIGHT, 1.2)
	var blink := create_tween().set_loops()
	blink.tween_property(live_badge, "modulate:a", 0.3, 0.6)
	blink.tween_property(live_badge, "modulate:a", 1.0, 0.6)
	_next_shot()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_go_to_game()
	elif event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _typing:
			_visible_chars = caption_label.text.length()
		else:
			_next_shot()


func _process(delta: float) -> void:
	if _leaving or _shot_index < 0:
		return

	if _typing:
		var before := int(_visible_chars)
		_visible_chars += chars_per_second * delta
		var now := int(_visible_chars)
		if now != before and now % 3 == 0:
			Sfx.play("hover", -18.0, 0.15)
		caption_label.visible_characters = now
		if now >= caption_label.text.length():
			caption_label.visible_characters = -1
			_typing = false

	# Temblor de cámara que se apaga solo.
	_shake_strength = maxf(0.0, _shake_strength - delta * 40.0)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	world.position = _base_world_position + shake

	_shot_time_left -= delta
	if _shot_time_left <= 0.0 and not _typing:
		_next_shot()


func _set_bottom_bar(height: float) -> void:
	bottom_bar.size.y = height
	bottom_bar.position.y = get_viewport_rect().size.y - height


# --- Control de tomas -------------------------------------------------------

func _next_shot() -> void:
	_shot_index += 1
	if _shot_index >= SHOTS.size():
		_go_to_game()
		return

	for tween in _shot_tweens:
		if tween.is_valid():
			tween.kill()
	_shot_tweens.clear()
	for child in world.get_children():
		child.queue_free()
	world.scale = Vector2.ONE
	world.rotation = 0.0
	_base_world_position = get_viewport_rect().size * 0.5
	world.position = _base_world_position
	title_label.modulate.a = 0.0

	var shot: Dictionary = SHOTS[_shot_index]
	_shot_time_left = shot["time"]
	_show_caption(shot["text"])
	call(shot["build"])


func _go_to_game() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.7)
	tween.tween_callback(get_tree().change_scene_to_file.bind(game_scene_path))


func _show_caption(text: String) -> void:
	caption_label.text = text
	caption_label.visible_characters = 0
	_visible_chars = 0.0
	_typing = true
	caption_panel.modulate.a = 0.0
	create_tween().tween_property(caption_panel, "modulate:a", 1.0, 0.3)


# --- Utilidades de escena ---------------------------------------------------

func _tween() -> Tween:
	var tween := create_tween()
	_shot_tweens.append(tween)
	return tween


func _add_image(file: String, at: Vector2 = Vector2.ZERO, size: float = 1.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + file)
	sprite.position = at
	sprite.scale = Vector2(size, size)
	world.add_child(sprite)
	return sprite


## Fondo que cubre la pantalla con margen para mover la cámara.
func _add_background(file: String) -> Sprite2D:
	var sprite := _add_image(file)
	var cover := maxf(HALF_SCREEN.x * 2.0 / sprite.texture.get_width(), HALF_SCREEN.y * 2.0 / sprite.texture.get_height())
	sprite.scale = Vector2.ONE * cover * 1.05
	return sprite


func _add_particles(particles: CPUParticles2D, at: Vector2) -> CPUParticles2D:
	particles.position = at
	world.add_child(particles)
	return particles


## Movimiento de cámara: zoom y desplazamiento a lo largo de la toma.
func _camera_move(zoom_from: float, zoom_to: float, pan_from: Vector2, pan_to: Vector2, seconds: float) -> void:
	world.scale = Vector2.ONE * zoom_from
	var center := get_viewport_rect().size * 0.5
	_base_world_position = center + pan_from
	var tween := _tween().set_parallel()
	tween.tween_property(world, "scale", Vector2.ONE * zoom_to, seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "_base_world_position", center + pan_to, seconds).set_trans(Tween.TRANS_SINE)


func _shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)


func _flash(strength: float, seconds: float = 0.4, color: Color = Color(1, 0.95, 0.85)) -> void:
	flash.color = Color(color, strength)
	create_tween().tween_property(flash, "color:a", 0.0, seconds)


func _show_title(text: String, delay: float) -> void:
	title_label.text = text
	title_label.pivot_offset = title_label.size * 0.5
	var tween := _tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		title_label.scale = Vector2(1.4, 1.4)
		_flash(0.5)
		Sfx.play("explosion", -8.0))
	tween.tween_property(title_label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Tomas ------------------------------------------------------------------

func _shot_orbit() -> void:
	_add_background("01_orbita.jpg")
	_add_particles(IntroFx.stars(Vector2(2000, 700)), Vector2(0, -250))
	# La nave insignia cruza en primer plano, más rápido que el fondo.
	var ship := _add_image("02_nave.png", Vector2(-1500, 260), 0.9)
	var ship_tween := _tween()
	ship_tween.tween_property(ship, "position:x", 1500.0, 7.0)
	_camera_move(1.0, 1.12, Vector2(60, 20), Vector2(-60, 0), 7.0)


func _shot_propaganda() -> void:
	_add_background("03_propaganda.jpg")
	_add_particles(IntroFx.dust(Vector2(1800, 900)), Vector2.ZERO)
	# La cámara sube desde la tropa hasta los estandartes.
	_camera_move(1.25, 1.1, Vector2(0, -170), Vector2(0, 60), 6.5)
	_flash(0.35, 0.6, Color(1, 0.85, 0.5))


func _shot_colony() -> void:
	_add_background("04_colonia.jpg")
	_add_particles(IntroFx.smoke(Vector2(1800, 300)), Vector2(0, 250))
	_add_particles(IntroFx.embers(Vector2(1900, 200)), Vector2(0, 480))
	_camera_move(1.1, 1.2, Vector2(110, 0), Vector2(-110, -20), 6.5)
	# Parpadeo rojo de los incendios.
	var glow := ColorRect.new()
	glow.color = Color(1, 0.2, 0.05, 0.0)
	glow.size = Vector2(4000, 3000)
	glow.position = -glow.size * 0.5
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(glow)
	var flicker := _tween().set_loops(8)
	flicker.tween_property(glow, "color:a", 0.12, 0.35)
	flicker.tween_property(glow, "color:a", 0.0, 0.45)


func _shot_swarm() -> void:
	var background := _add_background("04_colonia.jpg")
	background.modulate = Color(0.35, 0.18, 0.18)
	_add_particles(IntroFx.embers(Vector2(1900, 200), 60), Vector2(0, 480))
	# El enjambre avanza hacia la cámara.
	var swarm := _add_image("05_enjambre.png", Vector2(0, 120), 0.45)
	swarm.modulate = Color(0.6, 0.6, 0.6)
	var tween := _tween().set_parallel()
	tween.tween_property(swarm, "scale", Vector2(1.35, 1.35), 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(swarm, "position:y", 260.0, 5.0)
	tween.tween_property(swarm, "modulate", Color.WHITE, 2.0)
	var rumble := _tween().set_loops(5)
	rumble.tween_callback(_shake.bind(6.0))
	rumble.tween_interval(0.9)
	_camera_move(1.0, 1.06, Vector2.ZERO, Vector2(0, -20), 5.0)


func _shot_hivelord() -> void:
	var background := _add_background("06_hivelord.jpg")
	# Luz roja que late sobre el núcleo del Hivelord.
	var texture_size := background.texture.get_size() * background.scale
	var core := (Vector2(0.496, 0.466) - Vector2(0.5, 0.5)) * texture_size
	var glow := Sprite2D.new()
	glow.texture = _radial_glow_texture()
	glow.position = core
	world.add_child(glow)
	glow.modulate = Color(1, 0.15, 0.1, 0.0)
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = blend
	glow.scale = Vector2(3.2, 3.2)
	var pulse := _tween().set_loops(6)
	pulse.tween_property(glow, "modulate:a", 0.85, 0.45)
	pulse.tween_callback(_shake.bind(10.0))
	pulse.tween_property(glow, "modulate:a", 0.2, 0.6)
	_add_particles(IntroFx.embers(Vector2(1900, 150), 50), Vector2(0, 470))
	# Acercamiento lento hacia el núcleo.
	_camera_move(1.0, 1.35, Vector2.ZERO, -core * 0.35, 6.5)


func _shot_drop() -> void:
	_add_background("07_cielo.jpg")
	_camera_move(1.05, 1.15, Vector2.ZERO, Vector2(0, 30), 5.0)
	# Cápsulas lejanas cayendo.
	for index in range(3):
		var far := _add_image("08_capsula.png", Vector2(-700 + index * 520, -500), 0.12)
		far.modulate = Color(0.7, 0.6, 0.6)
		var far_tween := _tween()
		far_tween.tween_interval(index * 0.6)
		far_tween.tween_property(far, "position", far.position + Vector2(420, 1100), 3.2)
	# La cápsula del soldado cruza la pantalla en llamas, cada vez más grande.
	var pod := _add_image("08_capsula.png", Vector2(-900, -700), 0.35)
	var trail := IntroFx.fire_trail(Vector2(-0.6, -1))
	trail.position = Vector2(-120, -180)
	pod.add_child(trail)
	trail.show_behind_parent = true
	var tween := _tween().set_parallel()
	tween.tween_property(pod, "position", Vector2(350, 420), 4.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(pod, "scale", Vector2(0.95, 0.95), 4.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var rumble := _tween().set_loops(10)
	rumble.tween_callback(_shake.bind(5.0))
	rumble.tween_interval(0.45)
	var impact := _tween()
	impact.tween_interval(4.6)
	impact.tween_callback(func() -> void:
		_flash(1.0, 0.8)
		_shake(30.0)
		Sfx.play("explosion", 2.0))


func _shot_landing() -> void:
	_add_background("09_aterrizaje.jpg")
	_shake(25.0)
	var burst := _add_particles(IntroFx.burst(), Vector2(-60, 330))
	burst.emitting = true
	_add_particles(IntroFx.smoke(Vector2(1600, 200), 40), Vector2(150, 300))
	_add_particles(IntroFx.embers(Vector2(1900, 200), 70), Vector2(0, 480))
	_camera_move(1.3, 1.08, Vector2(0, 40), Vector2(0, -10), 6.5)


func _shot_final() -> void:
	_add_background("10_final.jpg")
	_add_particles(IntroFx.embers(Vector2(1900, 300), 120), Vector2(0, 450))
	_add_particles(IntroFx.smoke(Vector2(1800, 300), 30), Vector2(200, 100))
	# La cámara se aleja para mostrar al soldado frente al enjambre.
	_camera_move(1.3, 1.02, Vector2(220, 60), Vector2(0, 0), 8.0)
	var rumble := _tween().set_loops(4)
	rumble.tween_interval(1.4)
	rumble.tween_callback(_shake.bind(4.0))
	_show_title("CHRONOS PROTOCOL", 4.2)


## Textura circular difuminada para luces (se genera una sola vez).
func _radial_glow_texture() -> Texture2D:
	if _glow_texture != null:
		return _glow_texture
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_glow_texture = texture
	return texture
