extends Node

## Autoload "GameStats": récords y estadísticas guardados entre partidas en
## user://stats.cfg (mejor puntaje, mejor racha, oleada más alta, bajas
## totales, partidas jugadas y jefes derrotados). También guarda el Arsenal:
## los fragmentos que sobran al terminar una partida y las mejoras
## permanentes que se compran con ellos en el menú.

const STATS_PATH: String = "user://stats.cfg"
## Mejoras permanentes del Arsenal: nombre, efecto y costo de cada nivel.
const UNLOCKS: Dictionary = {
	"armor": {
		"name": "Blindaje reforzado",
		"effect": "+1 de vida inicial",
		"costs": [20, 40, 70, 100, 140],
	},
	"reserve": {
		"name": "Reserva de fragmentos",
		"effect": "+6 fragmentos al empezar",
		"costs": [15, 30, 50, 75],
	},
	"arsenal": {
		"name": "Equipo inicial",
		"effect": "Nv. 1: Escopeta · Nv. 2: y Lanzagranadas",
		"costs": [40, 90],
	},
	"logistics": {
		"name": "Logística orbital",
		"effect": "estratagemas recargan 10 % más rápido",
		"costs": [30, 60, 100],
	},
	"adrenaline": {
		"name": "Adrenalina",
		"effect": "+1 s para seguir la racha",
		"costs": [25, 55],
	},
}

var best_score: int = 0
var best_streak: int = 0
var best_wave: int = 0
var total_kills: int = 0
var games_played: int = 0
var bosses_defeated: int = 0
## Fragmentos guardados para el Arsenal.
var bank: int = 0
var unlocks: Dictionary = {}


func _ready() -> void:
	_load()


## Suma los datos de una partida. Devuelve los récords superados para
## anunciarlos ("Puntaje", "Racha", "Oleada"). kills, games y bosses son lo
## nuevo desde la última vez que se llamó en esta partida.
func submit(score: int, streak: int, wave: int, kills: int, games: int, bosses: int) -> PackedStringArray:
	var records := PackedStringArray()
	if score > best_score:
		best_score = score
		records.append("Puntaje")
	if streak > best_streak:
		best_streak = streak
		records.append("Racha")
	if wave > best_wave:
		best_wave = wave
		records.append("Oleada")
	total_kills += kills
	games_played += games
	bosses_defeated += bosses
	_save()
	return records


## Texto corto con los récords, para el Game Over y la Victoria.
func records_line() -> String:
	return "Récord: %d   ·   Mejor racha: x%d   ·   Oleada más alta: %d" % [best_score, best_streak, best_wave]


## Texto largo para el menú principal.
func summary_text() -> String:
	if games_played == 0:
		return "RÉCORDS\nAún no hay partidas.\n¡Sal a defender la colonia!"
	return "RÉCORDS\nMejor puntaje: %d\nMejor racha: x%d\nOleada más alta: %d\n\nPartidas: %d\nBajas totales: %d\nJefes derrotados: %d" % [
		best_score, best_streak, best_wave, games_played, total_kills, bosses_defeated,
	]


func unlock_level(id: String) -> int:
	return unlocks.get(id, 0)


func unlock_max_level(id: String) -> int:
	return UNLOCKS[id]["costs"].size()


func unlock_cost(id: String) -> int:
	var level := unlock_level(id)
	return -1 if level >= unlock_max_level(id) else UNLOCKS[id]["costs"][level]


## Compra el siguiente nivel de una mejora permanente si alcanza el banco.
func buy_unlock(id: String) -> bool:
	var cost := unlock_cost(id)
	if cost < 0 or bank < cost:
		return false
	bank -= cost
	unlocks[id] = unlock_level(id) + 1
	_save()
	return true


## Guarda en el banco los fragmentos que sobraron al terminar la partida.
func deposit(amount: int) -> void:
	if amount <= 0:
		return
	bank += amount
	_save()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(STATS_PATH) != OK:
		return
	best_score = config.get_value("records", "best_score", 0)
	best_streak = config.get_value("records", "best_streak", 0)
	best_wave = config.get_value("records", "best_wave", 0)
	total_kills = config.get_value("totals", "kills", 0)
	games_played = config.get_value("totals", "games", 0)
	bosses_defeated = config.get_value("totals", "bosses", 0)
	bank = config.get_value("arsenal", "bank", 0)
	unlocks = config.get_value("arsenal", "unlocks", {})


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "best_score", best_score)
	config.set_value("records", "best_streak", best_streak)
	config.set_value("records", "best_wave", best_wave)
	config.set_value("totals", "kills", total_kills)
	config.set_value("totals", "games", games_played)
	config.set_value("totals", "bosses", bosses_defeated)
	config.set_value("arsenal", "bank", bank)
	config.set_value("arsenal", "unlocks", unlocks)
	config.save(STATS_PATH)
