class_name WaveDirector
extends Node

## Decide qué enemigos trae cada oleada, cuántas bajas se necesitan y cómo
## sube la dificultad. Las oleadas 1-4 son la campaña, la 5 es el jefe y desde
## la 6 empieza el modo infinito, con un jefe cada 5 oleadas: en la 10 el
## Soldado Cero y desde la 15 uno al azar, cada vez más fuerte.

const BOSS_WAVE: int = 5
const ENDLESS_BOSS_EVERY: int = 5
const CAMPAIGN_KILLS: Array[int] = [15, 20, 30, 50]

@export var spider: EnemyVariant
@export var fast_spider: EnemyVariant
@export var armored_spider: EnemyVariant
@export var drone: EnemyVariant
@export var gunner_drone: EnemyVariant
@export var bomber_spider: EnemyVariant


func is_endless(wave: int) -> bool:
	return wave > BOSS_WAVE


func is_boss_wave(wave: int) -> bool:
	return wave == BOSS_WAVE or (is_endless(wave) and (wave - BOSS_WAVE) % ENDLESS_BOSS_EVERY == 0)


func kills_for_wave(wave: int) -> int:
	if wave <= CAMPAIGN_KILLS.size():
		return CAMPAIGN_KILLS[wave - 1]
	return 40 + 8 * (wave - BOSS_WAVE - 1)


## Multiplica la vida de los enemigos en el modo infinito.
func difficulty(wave: int) -> float:
	return 1.0 if not is_endless(wave) else 1.0 + 0.2 * (wave - BOSS_WAVE)


func spawn_interval(wave: int) -> float:
	return 1.5 if not is_endless(wave) else maxf(0.6, 1.2 - 0.05 * (wave - BOSS_WAVE))


## Qué jefe sale: "hivelord" o "soldier".
func pick_boss(wave: int) -> String:
	if wave == BOSS_WAVE:
		return "hivelord"
	if wave == BOSS_WAVE + ENDLESS_BOSS_EVERY:
		return "soldier"
	return ["hivelord", "soldier"].pick_random()


## Nivel de dificultad del jefe: 0 en la oleada 5, 1 en la 10, 2 en la 15...
## Cada jefe lo usa para subir su vida y su agresividad.
func boss_tier(wave: int) -> int:
	return maxi(0, (wave - BOSS_WAVE) / ENDLESS_BOSS_EVERY)


## Pares [variante, peso] de la oleada.
func composition(wave: int) -> Array:
	match wave:
		1:
			return [[spider, 1.0]]
		2:
			return [[spider, 0.65], [drone, 0.35]]
		3:
			return [[spider, 0.4], [fast_spider, 0.35], [drone, 0.25]]
		4:
			return [
				[fast_spider, 0.25], [armored_spider, 0.25], [bomber_spider, 0.15],
				[drone, 0.15], [gunner_drone, 0.2],
			]
	return [
		[spider, 0.15], [fast_spider, 0.2], [armored_spider, 0.2], [bomber_spider, 0.15],
		[drone, 0.15], [gunner_drone, 0.15],
	]


func pick_variant(wave: int) -> EnemyVariant:
	var entries := composition(wave)
	var total := 0.0
	for entry in entries:
		total += entry[1]
	var roll := randf() * total
	for entry in entries:
		roll -= entry[1]
		if roll <= 0.0:
			return entry[0]
	return entries[-1][0]


## Nombres de los enemigos que aparecen por primera vez en esta oleada.
func new_enemy_names(wave: int) -> PackedStringArray:
	var seen: Array = []
	for previous in range(1, mini(wave, BOSS_WAVE)):
		for entry in composition(previous):
			seen.append(entry[0])
	var names := PackedStringArray()
	if wave >= BOSS_WAVE:
		return names
	for entry in composition(wave):
		if not seen.has(entry[0]):
			names.append(entry[0].display_name)
	return names
