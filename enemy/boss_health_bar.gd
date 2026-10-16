class_name BossHealthBar
extends CanvasLayer

## Barra de vida del jefe en la parte superior de la pantalla. La barra roja
## baja al instante y una barra clara la sigue con retraso para que se note
## cuánto daño hizo cada golpe.

@export var boss_name: String = "HIVELORD"
@export var normal_fill_color: Color = Color(0.9, 0.12, 0.18)
@export var enraged_fill_color: Color = Color(1.0, 0.45, 0.05)
@export var trail_delay: float = 0.35
@export var trail_duration: float = 0.45

@onready var root_control: Control = $Root
@onready var name_label: Label = $Root/NameLabel
@onready var value_label: Label = $Root/ValueLabel
@onready var enraged_label: Label = $Root/EnragedLabel
@onready var trail_bar: ProgressBar = $Root/TrailBar
@onready var health_bar: ProgressBar = $Root/HealthBar

var _fill_style: StyleBoxFlat
var _trail_tween: Tween
var _hit_tween: Tween


func _ready() -> void:
	name_label.text = boss_name
	enraged_label.hide()
	_fill_style = (health_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate()
	_fill_style.bg_color = normal_fill_color
	health_bar.add_theme_stylebox_override("fill", _fill_style)
	root_control.modulate.a = 0.0
	create_tween().tween_property(root_control, "modulate:a", 1.0, 0.6)


func setup(max_health: int) -> void:
	for bar: ProgressBar in [health_bar, trail_bar]:
		bar.max_value = max_health
		bar.value = max_health
	_update_value_label()


func set_health(current_health: int) -> void:
	if is_equal_approx(health_bar.value, float(current_health)):
		return
	health_bar.value = current_health
	_update_value_label()

	if _trail_tween != null and _trail_tween.is_running():
		_trail_tween.kill()
	_trail_tween = create_tween()
	_trail_tween.tween_interval(trail_delay)
	_trail_tween.tween_property(trail_bar, "value", float(current_health), trail_duration)

	if _hit_tween != null and _hit_tween.is_running():
		_hit_tween.kill()
	health_bar.modulate = Color(1.8, 1.8, 1.8)
	_hit_tween = create_tween()
	_hit_tween.tween_property(health_bar, "modulate", Color.WHITE, 0.15)


func set_enraged() -> void:
	_fill_style.bg_color = enraged_fill_color
	enraged_label.show()


func fade_out() -> void:
	set_health(0)
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(root_control, "modulate:a", 0.0, 0.5)
	tween.tween_callback(hide)


func _update_value_label() -> void:
	value_label.text = "%d / %d" % [int(health_bar.value), int(health_bar.max_value)]
