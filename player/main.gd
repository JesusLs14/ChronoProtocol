extends Node2D

signal wave_ended

const SHOP_TRANSITION_DELAY: float = 2.5
const MAIN_MENU_PATH: String = "res://menu/main_menu.tscn"
# Pausa entre la muerte del jefe y la pantalla de victoria.
const VICTORY_DELAY: float = 1.5
## Precio base de cada artículo de la tienda y cuánto sube con cada compra
## (Reparar, Sobremarcha, Batería, Escopeta, Lanzagranadas, Francotirador,
## Lanzallamas, Láser).
const SHOP_COSTS: Array[int] = [5, 8, 10, 12, 15, 20, 25, 30]
const SHOP_COST_STEPS: Array[int] = [3, 6, 6, 0, 0, 0, 0, 0]
## Armas de la Armería desde el índice 5: id del arma y nombre.
const EXTRA_WEAPONS: Dictionary = {
	5: ["sniper", "el Rifle de Francotirador"],
	6: ["flamethrower", "el Lanzallamas"],
	7: ["laser", "el Láser"],
}
## Compras máximas de Sobremarcha (+15 % de velocidad cada una).
const OVERDRIVE_MAX_LEVEL: int = 4
const OVERDRIVE_BONUS: float = 0.15
## Vida máxima tope (el HUD muestra hasta 20 baterías).
const MAX_HEALTH_CAP: int = 20
## Margen entre la pared y el punto donde aparece un enemigo.
const SPAWN_WALL_MARGIN: float = 80.0
const DEATH_SUBTITLES: Array[String] = [
	"La Colmena reclama otro soldado.",
	"El Protocolo Chronos necesita más voluntarios.",
	"Tu sacrificio será recordado… por un rato.",
	"El enjambre no perdona.",
	"Otro nombre para el muro de los caídos.",
]
const BOSS_NAMES: Dictionary = {"hivelord": "el Hivelord", "soldier": "el Soldado Cero"}

@export var boss_scene: PackedScene
@export var soldier_boss_scene: PackedScene
@onready var score_label = $UI/ScoreLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/Content/FinalScoreLabel
@onready var wave_time_label: Label = $UI/WaveTimeLabel
@onready var shop_panel: ColorRect = $UI/ShopPanel
@onready var shop_fragments_label: Label = $UI/ShopPanel/ShopFragmentsLabel
@onready var boss_warning_label: Label = $UI/BossWarningLabel
@onready var shop_status_label: Label = $UI/ShopPanel/ShopStatusLabel
@onready var wave_director: WaveDirector = $WaveDirector
@onready var wave_banner: WaveBanner = $UI/WaveBanner
@onready var kill_streak: KillStreak = $KillStreak
@onready var weapon_upgrades: WeaponUpgrades = $WeaponUpgrades
@onready var upgrade_buttons: Dictionary = {
	"fire_rate": $UI/ShopPanel/ShopTabs/Mejoras/FireRateButton,
	"damage": $UI/ShopPanel/ShopTabs/Mejoras/DamageButton,
	"pierce": $UI/ShopPanel/ShopTabs/Mejoras/PierceButton,
}
var spawn_timer: Timer
var score: int = 0
var closing_magnet_active: bool = false
var _wave_has_ended: bool = false
var _boss_active: bool = false
var current_wave: int = 1
var _current_boss: String = "hivelord"
var enemies_to_kill: int = 15
var enemies_killed: int = 0
# Estadísticas de la partida que aún no se guardaron en GameStats.
var _run_kills: int = 0
var _run_bosses: int = 0
var _run_counted: bool = false
var _game_over_records: Label
var _total_kills: int = 0
# Veces que se compró cada artículo de la tienda (mismo orden que SHOP_COSTS).
var _shop_bought: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var _base_speed: float = 0.0
var _props: ArenaProps
var _victory_records: Label

func _ready() -> void:
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_spawn_enemy)
	$UI/GameOverPanel/Content/Buttons/RetryButton.pressed.connect(_on_retry_pressed)
	$UI/GameOverPanel/Content/Buttons/MenuButton.pressed.connect(_on_menu_pressed)
	$UI/VictoryPanel/Buttons/EndlessButton.pressed.connect(_on_endless_pressed)
	$UI/VictoryPanel/Buttons/PlayAgainButton.pressed.connect(_on_retry_pressed)
	$UI/VictoryPanel/Buttons/MenuButton.pressed.connect(_on_menu_pressed)
	$UI/ShopPanel/ShopTabs/Clínica/RepairButton.pressed.connect(_on_shop_purchase_pressed.bind(0))
	$UI/ShopPanel/ShopTabs/Clínica/OverdriveButton.pressed.connect(_on_shop_purchase_pressed.bind(1))
	$UI/ShopPanel/ShopTabs/Clínica/ExtraBatteryButton.pressed.connect(_on_shop_purchase_pressed.bind(2))
	$UI/ShopPanel/ShopTabs/Armería/ShotgunButton.pressed.connect(_on_shop_purchase_pressed.bind(3))
	$UI/ShopPanel/ShopTabs/Armería/GrenadeLauncherButton.pressed.connect(_on_shop_purchase_pressed.bind(4))
	$UI/ShopPanel/ShopTabs/Armería/SniperButton.pressed.connect(_on_shop_purchase_pressed.bind(5))
	$UI/ShopPanel/ShopTabs/Armería/FlamethrowerButton.pressed.connect(_on_shop_purchase_pressed.bind(6))
	$UI/ShopPanel/ShopTabs/Armería/LaserButton.pressed.connect(_on_shop_purchase_pressed.bind(7))
	$UI/ShopPanel/ContinueButton.pressed.connect(_on_continue_pressed)
	for kind: String in upgrade_buttons:
		upgrade_buttons[kind].pressed.connect(_on_upgrade_pressed.bind(kind))
	wave_ended.connect(_on_wave_ended)
	_props = ArenaProps.new()
	$Arena.add_child(_props)
	_props.build(_arena_bounds(0.0))
	var indicators := OffscreenIndicators.new()
	$UI.add_child(indicators)
	$UI.move_child(indicators, 0)
	_game_over_records = $UI/GameOverPanel/Content/RecordsLabel
	_victory_records = _make_records_label($UI/VictoryPanel, 300.0)
	_start_wave(1)

func add_score(points: int) -> void:
	score += points
	score_label.text = "PUNTAJE %d" % score
	spawn_timer.wait_time = max(0.3, spawn_timer.wait_time - 0.05)


func register_enemy_kill(points: int = 10) -> void:
	add_score(points)
	_run_kills += 1
	_total_kills += 1
	kill_streak.register_kill()
	# En las oleadas del jefe, las arañas que invoca solo dan puntos.
	if _wave_has_ended or _boss_active:
		return

	enemies_killed += 1
	_update_wave_progress()
	if enemies_killed >= enemies_to_kill:
		end_wave()


func show_game_over() -> void:
	get_tree().paused = true
	final_score_label.text = "Puntaje: %d\nOleada alcanzada: %d   ·   Bajas: %d   ·   Mejor racha: x%d" % [
		score, current_wave, _total_kills, kill_streak.best,
	]
	$UI/GameOverPanel/Content/SubtitleLabel.text = DEATH_SUBTITLES.pick_random()
	wave_banner.hide()
	_show_records(_game_over_records, commit_stats())
	_animate_game_over()


# El panel aparece con un fundido rojo, el título cae con un golpe y lo demás
# entra después.
func _animate_game_over() -> void:
	game_over_panel.modulate.a = 0.0
	game_over_panel.show()
	var content: VBoxContainer = $UI/GameOverPanel/Content
	var title: Label = $UI/GameOverPanel/Content/GameOverLabel
	var others: Array[Node] = content.get_children().filter(func(node: Node) -> bool: return node != title)
	for node: CanvasItem in others:
		node.modulate.a = 0.0
	title.pivot_offset = title.size * 0.5
	var tween := game_over_panel.create_tween()
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.45)
	tween.parallel().tween_property(title, "scale", Vector2.ONE, 0.35).from(Vector2(1.8, 1.8)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for node: CanvasItem in others:
		tween.tween_property(node, "modulate:a", 1.0, 0.18)
	tween.tween_callback($UI/GameOverPanel/Content/Buttons/RetryButton.grab_focus)

func _on_retry_pressed() -> void:
	commit_stats()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	commit_stats()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func end_wave() -> void:
	if _wave_has_ended:
		return

	_wave_has_ended = true
	spawn_timer.stop()
	kill_streak.hold(true)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	call_deferred("_finish_wave_transition")


func _finish_wave_transition() -> void:
	_update_wave_progress()
	activate_closing_magnet()
	await get_tree().create_timer(SHOP_TRANSITION_DELAY).timeout
	wave_ended.emit()


func activate_closing_magnet() -> void:
	closing_magnet_active = true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Cannot activate closing magnet: no player in the player group.")
		return

	for node in get_tree().get_nodes_in_group("fragments"):
		var fragment := node as Node
		if fragment.has_method("activate_closing_magnet"):
			fragment.activate_closing_magnet(player)


func _on_wave_ended() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_error("Cannot show shop: no Player exists in the player group.")
		return

	shop_fragments_label.text = "Fragmentos de Núcleo: %d" % player.core_fragments
	shop_status_label.text = "Elige una mejora o arma"
	_refresh_upgrade_buttons()
	_refresh_shop_buttons(player)
	shop_panel.show()
	get_tree().paused = true


func _on_shop_purchase_pressed(option_index: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_error("Cannot purchase upgrade: no Player exists in the player group.")
		return
	if option_index < 0 or option_index >= SHOP_COSTS.size():
		push_error("Invalid shop option index: %d" % option_index)
		return

	if option_index == 3 and player.has_shotgun:
		shop_status_label.text = "Ya tienes la Escopeta"
		return
	if option_index == 4 and player.has_grenade_launcher:
		shop_status_label.text = "Ya tienes el Lanzagranadas"
		return
	if EXTRA_WEAPONS.has(option_index) and player.unlocked_weapons.has(EXTRA_WEAPONS[option_index][0]):
		shop_status_label.text = "Ya tienes " + EXTRA_WEAPONS[option_index][1]
		return
	if option_index == 1 and _shop_bought[1] >= OVERDRIVE_MAX_LEVEL:
		shop_status_label.text = "La Sobremarcha ya está al máximo"
		return
	if option_index == 2 and player.max_health >= MAX_HEALTH_CAP:
		shop_status_label.text = "La batería ya está al máximo"
		return
	var cost := _shop_cost(option_index)
	if player.core_fragments < cost:
		shop_status_label.text = "No tienes suficientes Fragmentos de Núcleo"
		return

	player.core_fragments -= cost
	_shop_bought[option_index] += 1
	match option_index:
		0:
			player.current_health = mini(player.max_health, player.current_health + 3)
			player.health_changed.emit(player.current_health, player.max_health)
			shop_status_label.text = "Chasis reparado"
		1:
			# Siempre sobre la velocidad original: +15 % por nivel, sin acumular.
			if _base_speed == 0.0:
				_base_speed = player.speed
			player.speed = _base_speed * (1.0 + OVERDRIVE_BONUS * _shop_bought[1])
			shop_status_label.text = "Sobremarcha nivel %d instalada" % _shop_bought[1]
		2:
			player.max_health = mini(MAX_HEALTH_CAP, player.max_health + 2)
			player.health_changed.emit(player.current_health, player.max_health)
			shop_status_label.text = "Batería máxima aumentada"
		3:
			player.has_shotgun = true
			player.equip_weapon("shotgun")
			print("Escopeta comprada")
			shop_status_label.text = "Escopeta añadida al inventario"
		4:
			player.has_grenade_launcher = true
			player.equip_weapon("grenade_launcher")
			print("Lanzagranadas comprado")
			shop_status_label.text = "Lanzagranadas añadido al inventario"
		5, 6, 7:
			var weapon: Array = EXTRA_WEAPONS[option_index]
			player.equip_weapon(weapon[0])
			shop_status_label.text = "Compraste " + weapon[1]
	shop_fragments_label.text = "Fragmentos de Núcleo: %d" % player.core_fragments
	_refresh_shop_buttons(player)


func _on_upgrade_pressed(kind: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_error("Cannot buy upgrade: no Player exists in the player group.")
		return
	shop_status_label.text = weapon_upgrades.buy(kind, player)
	shop_fragments_label.text = "Fragmentos de Núcleo: %d" % player.core_fragments
	_refresh_upgrade_buttons()


func _refresh_upgrade_buttons() -> void:
	for kind: String in upgrade_buttons:
		var button: Button = upgrade_buttons[kind]
		button.text = weapon_upgrades.button_text(kind)
		button.disabled = weapon_upgrades.is_maxed(kind)


func spawn_boss() -> void:
	_boss_active = true
	boss_warning_label.text = "¡ALERTA: JEFE!"
	boss_warning_label.show()
	await get_tree().create_timer(1.5).timeout
	boss_warning_label.hide()
	var scene := soldier_boss_scene if _current_boss == "soldier" else boss_scene
	if scene == null:
		push_error("Cannot spawn boss '%s': its scene is not assigned." % _current_boss)
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Cannot spawn final boss: no player exists in the player group.")
		return

	var boss := scene.instantiate() as Node2D
	if boss == null or not boss.has_method("configure"):
		push_error("Boss scenes need a Node2D root with configure().")
		return
	boss.configure(wave_director.boss_tier(current_wave))
	boss.intro_mode = true
	# Invisible hasta que la entrada lo hace caer del cielo.
	boss.modulate.a = 0.0
	add_child(boss)
	var spawn_distance := 330.0 if _current_boss == "soldier" else 300.0
	boss.global_position = clamp_to_arena(player.global_position + Vector2(0.0, -spawn_distance), 140.0)
	boss.defeated.connect(_on_boss_defeated)
	var player_node := player as Player
	if player_node != null:
		await BossIntro.play(self, boss, player_node).finished
	if is_instance_valid(boss):
		boss.start_fight()


func _on_boss_defeated() -> void:
	_boss_active = false
	_run_bosses += 1
	kill_streak.hold(true)
	boss_warning_label.text = "JEFE DERROTADO"
	boss_warning_label.show()
	# Las arañas que quedan desaparecen para que no maten al jugador ya ganado.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	await get_tree().create_timer(VICTORY_DELAY).timeout
	boss_warning_label.hide()
	if wave_director.is_endless(current_wave):
		# En el modo infinito el jefe es una oleada más: después viene la tienda.
		_wave_has_ended = true
		kill_streak.hold(true)
		_finish_wave_transition()
	else:
		show_victory()


func show_victory() -> void:
	spawn_timer.stop()
	get_tree().paused = true
	$UI/VictoryPanel/VictoryScoreLabel.text = "Puntaje: %d" % score
	_show_records(_victory_records, commit_stats())
	$UI/VictoryPanel.show()
	$UI/VictoryPanel/Buttons/EndlessButton.grab_focus()


func _on_endless_pressed() -> void:
	$UI/VictoryPanel.hide()
	get_tree().paused = false
	_start_wave(current_wave + 1)


func _update_wave_progress() -> void:
	var prefix := "∞ OLEADA %d" if wave_director.is_endless(current_wave) else "OLEADA %d"
	if wave_director.is_boss_wave(current_wave):
		wave_time_label.text = (prefix + "  |  JEFE") % current_wave
		return

	wave_time_label.text = (prefix + "  |  BAJAS %d/%d") % [
		current_wave,
		enemies_killed,
		enemies_to_kill
	]


func _on_continue_pressed() -> void:
	shop_panel.hide()
	get_tree().paused = false
	_start_wave(current_wave + 1)


func _start_wave(wave: int) -> void:
	current_wave = wave
	enemies_killed = 0
	closing_magnet_active = false
	_wave_has_ended = false
	kill_streak.hold(false)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_props.restock_barrels(player.global_position)
	if wave_director.is_boss_wave(wave):
		_current_boss = wave_director.pick_boss(wave)
	_announce_wave(wave)
	if wave_director.is_boss_wave(wave):
		_update_wave_progress()
		spawn_boss()
		return

	enemies_to_kill = wave_director.kills_for_wave(wave)
	spawn_timer.wait_time = wave_director.spawn_interval(wave)
	_update_wave_progress()
	spawn_timer.start()


func _announce_wave(wave: int) -> void:
	var title := "OLEADA %d" % wave
	if wave_director.is_endless(wave):
		title = "MODO INFINITO · OLEADA %d" % wave
	var subtitle := ""
	if wave_director.is_boss_wave(wave):
		subtitle = "Se acerca " + BOSS_NAMES.get(_current_boss, "un jefe")
	else:
		var names := wave_director.new_enemy_names(wave)
		if not names.is_empty():
			subtitle = "Nuevos enemigos: " + ", ".join(names)
		elif wave_director.is_endless(wave):
			subtitle = "Los enemigos son más resistentes"
	wave_banner.announce(title, subtitle)


func _spawn_enemy() -> void:
	if _wave_has_ended:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Cannot spawn enemy: no player exists in the player group.")
		return

	var variant := wave_director.pick_variant(current_wave)
	var enemy := variant.spawn(wave_director.difficulty(current_wave))
	add_child(enemy)
	enemy.global_position = _pick_spawn_position(player.global_position)


# Punto a 400-600 px del soldado pero siempre dentro de las paredes. Si el
# soldado está en una esquina se prueban otras direcciones; si ninguna cabe,
# se lleva el punto al borde interior del mapa.
func _pick_spawn_position(center: Vector2) -> Vector2:
	var bounds := _arena_bounds(SPAWN_WALL_MARGIN)
	var candidate := center
	for attempt in range(16):
		candidate = center + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * randf_range(400.0, 600.0)
		var inside := not bounds.has_area() or bounds.has_point(candidate)
		if inside and not _props.is_blocked(candidate, 70.0):
			return candidate
	return candidate.clamp(bounds.position, bounds.end)


## Lleva una posición al interior del mapa (con margen a las paredes).
func clamp_to_arena(point: Vector2, margin: float = SPAWN_WALL_MARGIN) -> Vector2:
	var bounds := _arena_bounds(margin)
	if not bounds.has_area():
		return point
	return point.clamp(bounds.position, bounds.end)


func _arena_bounds(margin: float) -> Rect2:
	var arena := get_node_or_null("Arena")
	if arena == null or not arena.has_method("playable_rect"):
		return Rect2()
	return arena.playable_rect(margin)


func _shop_cost(option_index: int) -> int:
	return SHOP_COSTS[option_index] + SHOP_COST_STEPS[option_index] * _shop_bought[option_index]


# Textos de la Clínica con el precio actual (sube con cada compra) y el nivel.
func _refresh_shop_buttons(player: Player) -> void:
	var repair: Button = $UI/ShopPanel/ShopTabs/Clínica/RepairButton
	var overdrive: Button = $UI/ShopPanel/ShopTabs/Clínica/OverdriveButton
	var battery: Button = $UI/ShopPanel/ShopTabs/Clínica/ExtraBatteryButton
	repair.text = "Reparar Chasis — %d Fragmentos (cura 3 de vida)" % _shop_cost(0)
	var overdrive_maxed := _shop_bought[1] >= OVERDRIVE_MAX_LEVEL
	if overdrive_maxed:
		overdrive.text = "Sobremarcha Nv. %d — MÁXIMO" % _shop_bought[1]
	else:
		overdrive.text = "Sobremarcha Nv. %d → %d (+15 %% velocidad) — %d Fragmentos" % [
			_shop_bought[1], _shop_bought[1] + 1, _shop_cost(1),
		]
	overdrive.disabled = overdrive_maxed
	var battery_maxed := player.max_health >= MAX_HEALTH_CAP
	if battery_maxed:
		battery.text = "Batería Extra — MÁXIMO (%d de vida)" % MAX_HEALTH_CAP
	else:
		battery.text = "Batería Extra — %d Fragmentos (+2 de vida máxima)" % _shop_cost(2)
	battery.disabled = battery_maxed
	# Armas que ya se tienen: el botón lo dice y se desactiva.
	var armory := {
		3: ["ShotgunButton", "shotgun", "Escopeta"],
		4: ["GrenadeLauncherButton", "grenade_launcher", "Lanzagranadas"],
		5: ["SniperButton", "sniper", "Rifle de Francotirador"],
		6: ["FlamethrowerButton", "flamethrower", "Lanzallamas"],
		7: ["LaserButton", "laser", "Láser"],
	}
	for index: int in armory:
		var entry: Array = armory[index]
		var button: Button = get_node("UI/ShopPanel/ShopTabs/Armería/" + entry[0])
		var owned := player.unlocked_weapons.has(entry[1])
		button.disabled = owned
		button.text = ("%s — YA LA TIENES" % entry[2]) if owned else ("Comprar %s — %d Fragmentos" % [entry[2], _shop_cost(index)])


## Guarda en GameStats lo nuevo de esta partida (se puede llamar varias veces:
## solo suma lo que falta). Devuelve los récords superados.
func commit_stats() -> PackedStringArray:
	var games := 0 if _run_counted else 1
	_run_counted = true
	var records := GameStats.submit(score, kill_streak.best, current_wave, _run_kills, games, _run_bosses)
	_run_kills = 0
	_run_bosses = 0
	return records


func _make_records_label(panel: Control, top: float) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -600.0
	label.offset_right = 600.0
	label.offset_top = top
	label.offset_bottom = top + 90.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	panel.add_child(label)
	return label


func _show_records(label: Label, records: PackedStringArray) -> void:
	var text := GameStats.records_line()
	if records.is_empty():
		label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	else:
		text = "¡NUEVO RÉCORD! (%s)
" % ", ".join(records) + text
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		var tween := label.create_tween().set_loops(4)
		tween.tween_property(label, "modulate", Color(1.4, 1.4, 1.4), 0.25)
		tween.tween_property(label, "modulate", Color.WHITE, 0.25)
	label.text = text
