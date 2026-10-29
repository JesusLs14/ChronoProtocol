class_name BossIntro
extends CanvasLayer

## Entrada del jefe (Hivelord o Soldado Cero): cae del cielo, la cámara se acerca con
## barras de cine, aparece su nombre y ruge; luego la cámara vuelve al soldado
## y empieza la pelea. Mientras dura, el soldado no se mueve ni recibe daño.

signal finished

const ZOOM_IN: Vector2 = Vector2(1.6, 1.6)
const BAR_HEIGHT: float = 130.0
const DROP_HEIGHT: float = 700.0

## Jefe con sprite, intro_title, intro_subtitle, intro_color, intro_roar() e intro_settle().
var _boss: Node2D
var _player: Player
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _name_label: Label
var _title_label: Label
## 0 = barras de cine fuera de la pantalla, 1 = barras dentro.
var _bars: float = 0.0:
	set(value):
		_bars = value
		if _top_bar != null:
			_top_bar.offset_top = -BAR_HEIGHT * (1.0 - value)
			_top_bar.offset_bottom = BAR_HEIGHT * value
			_bottom_bar.offset_top = -BAR_HEIGHT * value
			_bottom_bar.offset_bottom = BAR_HEIGHT * (1.0 - value)


## Crea la escena de entrada y la reproduce. Se espera con `await intro.finished`.
static func play(main: Node, boss: Node2D, player: Player) -> BossIntro:
	var intro := BossIntro.new()
	intro._boss = boss
	intro._player = player
	main.add_child(intro)
	return intro


func _ready() -> void:
	layer = 5
	_build_ui()
	_run.call_deferred()


func _build_ui() -> void:
	_top_bar = _bar()
	_bottom_bar = _bar()
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bars = 0.0

	var texts := VBoxContainer.new()
	texts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	texts.offset_left = -700
	texts.offset_right = 700
	texts.offset_top = -330
	texts.offset_bottom = -150
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(texts)
	_title_label = _label(30, Color(1.0, 0.75, 0.3), 8)
	_title_label.text = _boss.intro_subtitle
	texts.add_child(_title_label)
	_name_label = _label(110, _boss.intro_color, 18)
	_name_label.text = _boss.intro_title
	texts.add_child(_name_label)
	_title_label.modulate.a = 0.0
	_name_label.modulate.a = 0.0


func _bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar


func _label(font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.15, 0, 0))
	label.add_theme_constant_override("outline_size", outline)
	return label


func _run() -> void:
	_player.in_cinematic = true
	# El HUD se esconde durante la entrada.
	var huds: Array[CanvasLayer] = []
	for hud in [_player.get_node_or_null("CanvasLayer"), get_parent().get_node_or_null("UI")]:
		if hud is CanvasLayer and hud.visible:
			hud.visible = false
			huds.append(hud)
	var player_camera := get_tree().get_first_node_in_group("arena_camera") as Camera2D
	var camera := Camera2D.new()
	if player_camera != null:
		camera.limit_left = player_camera.limit_left
		camera.limit_right = player_camera.limit_right
		camera.limit_top = player_camera.limit_top
		camera.limit_bottom = player_camera.limit_bottom
		camera.global_position = player_camera.get_screen_center_position()
	else:
		camera.global_position = _player.global_position
	get_parent().add_child(camera)
	camera.make_current()

	# Barras de cine.
	create_tween().tween_property(self, "_bars", 1.0, 0.4)

	# La cámara viaja hasta el jefe mientras cae del cielo.
	var sprite: Node2D = _boss.sprite
	var sprite_home := sprite.position
	sprite.position = sprite_home + Vector2(0, -DROP_HEIGHT)
	sprite.modulate.a = 0.0
	# main.gd crea al jefe invisible para que no se vea antes de caer.
	_boss.modulate.a = 1.0
	var travel := create_tween().set_parallel()
	travel.tween_property(camera, "global_position", _boss.global_position, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(camera, "zoom", ZOOM_IN, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(sprite, "modulate:a", 1.0, 0.3).set_delay(0.3)
	travel.tween_property(sprite, "position", sprite_home, 0.55).set_delay(0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await travel.finished

	# Impacto y rugido.
	_shake(camera, 22.0, 0.45)
	Sfx.play("explosion", 2.0, 0.0)
	CombatFx.explosion(get_parent(), _boss.global_position + Vector2(0, 40), 220.0, Color(1.0, 0.35, 0.2))
	_boss.intro_roar()

	var names := create_tween()
	names.tween_property(_title_label, "modulate:a", 1.0, 0.25)
	names.tween_property(_name_label, "modulate:a", 1.0, 0.12)
	names.parallel().tween_property(_name_label, "scale", Vector2.ONE, 0.25).from(Vector2(1.6, 1.6))
	_name_label.pivot_offset = _name_label.size * 0.5
	await get_tree().create_timer(1.9, false).timeout
	if is_instance_valid(_boss):
		_boss.intro_settle()

	# La cámara vuelve con el soldado.
	var back := create_tween().set_parallel()
	var return_point := player_camera.get_screen_center_position() if player_camera != null else _player.global_position
	back.tween_property(camera, "global_position", return_point, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(camera, "zoom", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(_title_label, "modulate:a", 0.0, 0.3)
	back.tween_property(_name_label, "modulate:a", 0.0, 0.3)
	back.tween_property(self, "_bars", 0.0, 0.5).set_delay(0.2)
	await back.finished

	if player_camera != null:
		player_camera.make_current()
	camera.queue_free()
	_player.in_cinematic = false
	for hud in huds:
		hud.visible = true
	finished.emit()
	queue_free()


func _shake(camera: Camera2D, strength: float, duration: float) -> void:
	var tween := create_tween()
	var steps := 10
	for step in steps:
		var falloff := 1.0 - float(step) / steps
		tween.tween_property(camera, "offset", Vector2(
			randf_range(-strength, strength), randf_range(-strength, strength)) * falloff,
			duration / steps)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)
