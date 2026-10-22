class_name KillStreakHud
extends Control

## Contador de racha a la derecha de la pantalla: número grande que salta con
## cada baja, barra con el tiempo que queda y la siguiente recompensa. Las
## recompensas se anuncian con un texto grande en el centro.

@export var kill_streak_path: NodePath = ^"../../KillStreak"
## La racha se muestra a partir de esta cantidad de bajas.
@export var min_visible_count: int = 3

const COLORS: Array[Color] = [
	Color(1, 1, 1), Color(1, 0.85, 0.3), Color(1, 0.55, 0.15), Color(1, 0.25, 0.2), Color(0.9, 0.3, 1),
]

@onready var counter: Control = $Counter
@onready var count_label: Label = $Counter/CountLabel
@onready var name_label: Label = $Counter/NameLabel
@onready var time_bar: ProgressBar = $Counter/TimeBar
@onready var next_label: Label = $Counter/NextLabel
@onready var reward_box: Control = $Reward
@onready var reward_title: Label = $Reward/TitleLabel
@onready var reward_text: Label = $Reward/TextLabel

var _streak: KillStreak
var _pop_tween: Tween
var _reward_tween: Tween


func _ready() -> void:
	counter.modulate.a = 0.0
	reward_box.modulate.a = 0.0
	_streak = get_node_or_null(kill_streak_path) as KillStreak
	if _streak == null:
		push_error("KillStreakHud requires a KillStreak at kill_streak_path.")
		return
	_streak.streak_changed.connect(_on_streak_changed)
	_streak.reward_granted.connect(_on_reward_granted)
	_streak.streak_ended.connect(_on_streak_ended)


func _process(_delta: float) -> void:
	if _streak != null and _streak.count > 0:
		time_bar.value = _streak.time_ratio()


func _on_streak_changed(count: int) -> void:
	if count < min_visible_count:
		return
	var tier := mini(int(count / 10), COLORS.size() - 1)
	count_label.text = "x%d" % count
	count_label.add_theme_color_override("font_color", COLORS[tier])
	name_label.text = _streak_name(count)
	var next := _streak.next_reward()
	next_label.text = "A las %d: %s" % [next[0], next[1]]
	counter.modulate.a = 1.0
	count_label.pivot_offset = count_label.size * 0.5
	if _pop_tween != null and _pop_tween.is_running():
		_pop_tween.kill()
	count_label.scale = Vector2(1.35, 1.35)
	_pop_tween = create_tween()
	_pop_tween.tween_property(count_label, "scale", Vector2.ONE, 0.15)


func _on_streak_ended(_final_count: int) -> void:
	if _pop_tween != null and _pop_tween.is_running():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.tween_property(counter, "modulate:a", 0.0, 0.4)


func _on_reward_granted(title: String, description: String) -> void:
	reward_title.text = title
	reward_text.text = description
	reward_box.pivot_offset = reward_box.size * 0.5
	reward_box.scale = Vector2(1.3, 1.3)
	reward_box.modulate.a = 0.0
	if _reward_tween != null and _reward_tween.is_running():
		_reward_tween.kill()
	_reward_tween = create_tween()
	_reward_tween.tween_property(reward_box, "modulate:a", 1.0, 0.15)
	_reward_tween.parallel().tween_property(reward_box, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reward_tween.tween_interval(1.8)
	_reward_tween.tween_property(reward_box, "modulate:a", 0.0, 0.4)
	Sfx.play("pickup", 0.0)


func _streak_name(count: int) -> String:
	if count >= 50:
		return "MASACRE"
	if count >= 30:
		return "IMPARABLE"
	if count >= 20:
		return "CARNICERÍA"
	if count >= 10:
		return "RACHA"
	return "BAJAS SEGUIDAS"
