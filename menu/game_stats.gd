extends Node

## Autoload "GameStats": récords y estadísticas guardados entre partidas en
## user://stats.cfg (mejor puntaje, mejor racha, oleada más alta, bajas
## totales, partidas jugadas y jefes derrotados).

const STATS_PATH: String = "user://stats.cfg"

var best_score: int = 0
var best_streak: int = 0
var best_wave: int = 0
var total_kills: int = 0
var games_played: int = 0
var bosses_defeated: int = 0


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


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "best_score", best_score)
	config.set_value("records", "best_streak", best_streak)
	config.set_value("records", "best_wave", best_wave)
	config.set_value("totals", "kills", total_kills)
	config.set_value("totals", "games", games_played)
	config.set_value("totals", "bosses", bosses_defeated)
	config.save(STATS_PATH)
