extends Control

## Intro con la historia del juego, presentada como una transmisión de
## propaganda del Mando Chronos (inspirada en el tono de Helldivers 2).
## Clic, Espacio o Enter pasan a la siguiente escena; Esc salta la intro.

@export_file("*.tscn") var game_scene_path: String = "res://player/main.tscn"
@export var chars_per_second: float = 42.0
## Tiempo que se queda cada escena cuando el texto ya terminó.
@export var slide_hold_time: float = 2.4

const SOLDIER_FRAMES: SpriteFrames = preload("res://player/soldier/soldier_sprite_frames.tres")
const SPIDER_SCENE: PackedScene = preload("res://enemy/spider_minion.tscn")
const DRONE_SCENE: PackedScene = preload("res://enemy/enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://enemy/boss.tscn")

const SLIDES: Array[Dictionary] = [
	{
		"headline": "CIUDADANO",
		"text": "Esta es una transmisión oficial del Mando Chronos. Deja lo que estás haciendo. Sí, eso también.",
		"actors": "logo",
	},
	{
		"headline": "AÑO 2187",
		"text": "La humanidad vive en paz, prosperidad y obediencia absoluta gracias al Protocolo Chronos.",
		"actors": "soldier_idle",
	},
	{
		"headline": "LA COLMENA",
		"text": "Pero en las colonias exteriores algo despertó. Drones de vigilancia. Arañas mecánicas. Millones de ellas. Y ninguna ha firmado el Protocolo.",
		"actors": "swarm",
	},
	{
		"headline": "EL HIVELORD",
		"text": "En el corazón de la Colmena late su mente maestra: el Hivelord. Enorme. Furioso. Muy poco democrático.",
		"actors": "boss",
	},
	{
		"headline": "TÚ",
		"text": "Por eso existe el Soldado Chronos. Entrenado en cuatro minutos. Armado con un Repetidor de Plasma. Esperanza de vida operativa: clasificada.",
		"actors": "soldier_shoot",
	},
	{
		"headline": "TU MISIÓN",
		"text": "Sobrevive a las oleadas. Recoge Fragmentos de Núcleo. Mejora tu equipo en la tienda. Y destruye al Hivelord.",
		"actors": "mission",
	},
	{
		"headline": "¿ESTÁS LISTO?",
		"text": "La Colmena no descansa. Tú tampoco. ¡Por la humanidad! ¡Por Chronos!",
		"actors": "final",
	},
]

@onready var stage: Node2D = $Stage
@onready var headline_label: Label = $Headline
@onready var subtitle_label: Label = $SubtitlePanel/SubtitleLabel
@onready var live_badge: Label = $LiveBadge
@onready var progress_label: Label = $ProgressLabel
@onready var fade: ColorRect = $Fade
@onready var flash: ColorRect = $Flash

var _slide_index: int = -1
var _typing: bool = false
var _visible_chars: float = 0.0
var _hold_time_left: float = 0.0
var _leaving: bool = false
var _stage_tween: Tween


func _ready() -> void:
	get_tree().paused = false
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)
	var blink := create_tween().set_loops()
	blink.tween_property(live_badge, "modulate:a", 0.35, 0.6)
	blink.tween_property(live_badge, "modulate:a", 1.0, 0.6)
	_next_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_go_to_game()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("shoot") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _typing:
			# Primer clic: muestra el texto completo.
			_visible_chars = subtitle_label.text.length()
		else:
			_next_slide()


func _process(delta: float) -> void:
	if _leaving or _slide_index < 0:
		return
	if _typing:
		var before := int(_visible_chars)
		_visible_chars += chars_per_second * delta
		var now := int(_visible_chars)
		if now != before and now % 3 == 0:
			Sfx.play("hover", -16.0, 0.15)
		subtitle_label.visible_characters = now
		if now >= subtitle_label.text.length():
			subtitle_label.visible_characters = -1
			_typing = false
			_hold_time_left = slide_hold_time
	else:
		_hold_time_left -= delta
		if _hold_time_left <= 0.0:
			_next_slide()


func _next_slide() -> void:
	_slide_index += 1
	if _slide_index >= SLIDES.size():
		_go_to_game()
		return

	var slide: Dictionary = SLIDES[_slide_index]
	headline_label.text = slide["headline"]
	subtitle_label.text = slide["text"]
	subtitle_label.visible_characters = 0
	_visible_chars = 0.0
	_typing = true
	progress_label.text = "%d / %d" % [_slide_index + 1, SLIDES.size()]

	headline_label.pivot_offset = headline_label.size * 0.5
	headline_label.scale = Vector2(1.3, 1.3)
	headline_label.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(headline_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(headline_label, "modulate:a", 1.0, 0.25)
	_flash_screen(0.25)
	_build_stage(slide["actors"])


func _go_to_game() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.6)
	tween.tween_callback(get_tree().change_scene_to_file.bind(game_scene_path))


func _flash_screen(strength: float) -> void:
	flash.color.a = strength
	create_tween().tween_property(flash, "color:a", 0.0, 0.35)


# --- Escenario de cada diapositiva -----------------------------------------

func _build_stage(kind: String) -> void:
	for child in stage.get_children():
		child.queue_free()
	if _stage_tween != null and _stage_tween.is_running():
		_stage_tween.kill()
	var center := get_viewport_rect().size * Vector2(0.5, 0.45)
	stage.position = center
	stage.scale = Vector2.ONE
	# Acercamiento lento de cámara, como en los anuncios de propaganda.
	_stage_tween = create_tween()
	_stage_tween.tween_property(stage, "scale", Vector2(1.12, 1.12), 6.0)

	match kind:
		"logo":
			var logo := Label.new()
			logo.text = "CHRONOS\nPROTOCOL"
			logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			logo.add_theme_font_size_override("font_size", 120)
			logo.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			logo.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0))
			logo.add_theme_constant_override("outline_size", 18)
			stage.add_child(logo)
			logo.position = -logo.get_combined_minimum_size() * 0.5
		"soldier_idle":
			_add_soldier(Vector2(0, 40), 5.0, "idle", false)
		"swarm":
			for index in range(7):
				var x := -560.0 + index * 180.0
				_add_from_scene(SPIDER_SCENE, Vector2(x, 140 + (index % 2) * 40), 2.6, "Walk", index % 2 == 0)
			for index in range(4):
				_add_from_scene(DRONE_SCENE, Vector2(-420 + index * 280, -120 - (index % 2) * 50), 1.8, "idle", false, true)
		"boss":
			var boss := _add_from_scene(BOSS_SCENE, Vector2(0, 30), 4.2, "idle", false)
			boss.modulate = Color(1.2, 0.75, 0.75)
			var pulse := create_tween().set_loops(4)
			pulse.tween_property(boss, "modulate", Color(1.6, 0.6, 0.6), 0.4)
			pulse.tween_property(boss, "modulate", Color(1.2, 0.75, 0.75), 0.4)
		"soldier_shoot":
			_add_soldier(Vector2(-120, 40), 6.0, "shoot", false, true)
		"mission":
			_add_soldier(Vector2(-380, 60), 4.0, "run", false)
			_add_from_scene(SPIDER_SCENE, Vector2(260, 140), 2.4, "Walk", true)
			_add_from_scene(SPIDER_SCENE, Vector2(460, 90), 2.4, "Walk", true)
			_add_from_scene(DRONE_SCENE, Vector2(380, -140), 1.8, "shoot", true, true)
		"final":
			_add_soldier(Vector2(0, 40), 6.0, "idle", false)
			var ring := create_tween().set_loops(3)
			ring.tween_callback(_flash_screen.bind(0.18))
			ring.tween_interval(0.9)


func _add_soldier(at: Vector2, size: float, animation: String, flip: bool, loop_shoot: bool = false) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SOLDIER_FRAMES
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(size, size)
	sprite.position = at
	sprite.flip_h = flip
	stage.add_child(sprite)
	sprite.play(animation)
	if loop_shoot:
		# La animación de disparo no está en bucle: se repite a mano.
		sprite.animation_finished.connect(func() -> void:
			sprite.play(animation)
			_flash_screen(0.08))
	return sprite


## Copia el sprite animado de la escena de un enemigo para mostrarlo solo.
func _add_from_scene(scene: PackedScene, at: Vector2, size: float, animation: String, flip: bool, hover: bool = false) -> AnimatedSprite2D:
	var instance := scene.instantiate()
	var source := instance.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = source.sprite_frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(size, size)
	sprite.position = at
	sprite.flip_h = flip
	instance.free()
	stage.add_child(sprite)
	sprite.play(animation)
	if not sprite.sprite_frames.get_animation_loop(animation):
		sprite.animation_finished.connect(sprite.play.bind(animation))
	if hover:
		var bob := create_tween().set_loops()
		bob.tween_property(sprite, "position:y", at.y - 12.0, 0.8).set_trans(Tween.TRANS_SINE)
		bob.tween_property(sprite, "position:y", at.y, 0.8).set_trans(Tween.TRANS_SINE)
		sprite.tree_exiting.connect(bob.kill)
	return sprite
