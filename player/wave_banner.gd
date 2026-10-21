class_name WaveBanner
extends VBoxContainer

## Aviso grande al empezar una oleada: aparece, se queda un momento y se va.

@export var hold_time: float = 2.2

@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	hide()


func announce(title: String, subtitle: String = "") -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	show()
	if _tween != null and _tween.is_running():
		_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2(1.25, 1.25)
	modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, 0.25)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(hold_time)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.5)
	_tween.chain().tween_callback(hide)
