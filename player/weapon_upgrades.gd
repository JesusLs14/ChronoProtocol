class_name WeaponUpgrades
extends Node

## Mejoras de arma que se compran en la tienda (pestaña "Mejoras"). Afectan a
## todas las armas del soldado y se acumulan por niveles.

const UPGRADES: Dictionary = {
	"fire_rate": {
		"name": "Cadencia",
		"effect": "+15 %",
		"costs": [10, 15, 20, 25, 30],
	},
	"damage": {
		"name": "Daño",
		"effect": "+1 por bala",
		"costs": [15, 25, 35],
	},
	"pierce": {
		"name": "Perforación",
		"effect": "atraviesa +1",
		"costs": [20, 35],
	},
}
const FIRE_RATE_PER_LEVEL: float = 0.15

var levels: Dictionary = {"fire_rate": 0, "damage": 0, "pierce": 0}


func max_level(kind: String) -> int:
	return UPGRADES[kind]["costs"].size()


func is_maxed(kind: String) -> bool:
	return levels[kind] >= max_level(kind)


func cost(kind: String) -> int:
	return -1 if is_maxed(kind) else UPGRADES[kind]["costs"][levels[kind]]


## Texto del botón de la tienda.
func button_text(kind: String) -> String:
	var data: Dictionary = UPGRADES[kind]
	if is_maxed(kind):
		return "%s Nv. %d — MÁXIMO" % [data["name"], levels[kind]]
	return "%s Nv. %d → %d (%s) — %d Fragmentos" % [
		data["name"], levels[kind], levels[kind] + 1, data["effect"], cost(kind),
	]


## Compra el siguiente nivel si alcanza. Devuelve el mensaje para la tienda.
func buy(kind: String, player: Player) -> String:
	var data: Dictionary = UPGRADES[kind]
	if is_maxed(kind):
		return "%s ya está al máximo" % data["name"]
	var price := cost(kind)
	if player.core_fragments < price:
		return "No tienes suficientes Fragmentos de Núcleo"
	player.core_fragments -= price
	levels[kind] += 1
	apply_to(player.weapon_manager)
	return "%s mejorada a nivel %d" % [data["name"], levels[kind]]


func apply_to(weapon_manager: WeaponManager) -> void:
	weapon_manager.upgrade_fire_rate_multiplier = 1.0 + FIRE_RATE_PER_LEVEL * levels["fire_rate"]
	weapon_manager.damage_bonus = levels["damage"]
	weapon_manager.pierce_bonus = levels["pierce"]
