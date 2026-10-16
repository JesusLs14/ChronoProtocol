class_name WeaponHud
extends PanelContainer

## Muestra el arma equipada (icono y nombre) en la esquina inferior izquierda.
## Se conecta sola a la señal weapon_changed del jugador.

const WEAPONS: Dictionary = {
	"pistol": {
		"name": "Repetidor de Plasma",
		"icon": preload("res://player/shop_icons/icon_plasma.tres"),
	},
	"shotgun": {
		"name": "Escopeta",
		"icon": preload("res://player/shop_icons/icon_shotgun.png"),
	},
	"grenade_launcher": {
		"name": "Lanzagranadas",
		"icon": preload("res://player/shop_icons/icon_grenade_launcher.png"),
	},
}

@export var player_path: NodePath = ^"../.."

@onready var icon_rect: TextureRect = $Row/Icon
@onready var name_label: Label = $Row/Texts/NameLabel
@onready var hint_label: Label = $Row/Texts/HintLabel

var _pop_tween: Tween


func _ready() -> void:
	var player := get_node_or_null(player_path) as Player
	if player == null:
		push_error("WeaponHud requires a Player at player_path.")
		return
	player.weapon_changed.connect(_on_weapon_changed)
	_show_weapon(player.current_weapon, player.unlocked_weapons.size())


func _on_weapon_changed(weapon_id: String) -> void:
	var player := get_node(player_path) as Player
	_show_weapon(weapon_id, player.unlocked_weapons.size())
	# Pequeño salto para que se note el cambio.
	if _pop_tween != null and _pop_tween.is_running():
		_pop_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2(1.12, 1.12)
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "scale", Vector2.ONE, 0.18)


func _show_weapon(weapon_id: String, unlocked_count: int) -> void:
	var data: Dictionary = WEAPONS.get(weapon_id, {})
	icon_rect.texture = data.get("icon", null)
	# El icono del repetidor sale de la hoja pixel art: se escala sin suavizar.
	icon_rect.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST if weapon_id == "pistol"
		else CanvasItem.TEXTURE_FILTER_LINEAR
	)
	name_label.text = data.get("name", weapon_id)
	hint_label.visible = unlocked_count > 1
