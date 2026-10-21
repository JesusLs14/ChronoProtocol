extends Node2D

signal wave_ended

const SHOP_TRANSITION_DELAY: float = 2.5
const MAIN_MENU_PATH: String = "res://menu/main_menu.tscn"
# Pausa entre la muerte del jefe y la pantalla de victoria.
const VICTORY_DELAY: float = 1.5
const SHOP_COSTS: Array[int] = [5, 8, 10, 12, 15]
const BOSS_BASE_HEALTH: int = 500

@export var boss_scene: PackedScene
@onready var score_label = $UI/ScoreLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var wave_time_label: Label = $UI/WaveTimeLabel
@onready var shop_panel: ColorRect = $UI/ShopPanel
@onready var shop_fragments_label: Label = $UI/ShopPanel/ShopFragmentsLabel
@onready var boss_warning_label: Label = $UI/BossWarningLabel
@onready var shop_status_label: Label = $UI/ShopPanel/ShopStatusLabel
@onready var wave_director: WaveDirector = $WaveDirector
@onready var wave_banner: WaveBanner = $UI/WaveBanner
var spawn_timer: Timer
var score: int = 0
var closing_magnet_active: bool = false
var _wave_has_ended: bool = false
var _boss_active: bool = false
var current_wave: int = 1
var enemies_to_kill: int = 15
var enemies_killed: int = 0

func _ready() -> void:
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_spawn_enemy)
	$UI/GameOverPanel/RetryButton.pressed.connect(_on_retry_pressed)
	$UI/GameOverPanel/MenuButton.pressed.connect(_on_menu_pressed)
	$UI/VictoryPanel/Buttons/EndlessButton.pressed.connect(_on_endless_pressed)
	$UI/VictoryPanel/Buttons/PlayAgainButton.pressed.connect(_on_retry_pressed)
	$UI/VictoryPanel/Buttons/MenuButton.pressed.connect(_on_menu_pressed)
	$UI/ShopPanel/ShopTabs/Clínica/RepairButton.pressed.connect(_on_shop_purchase_pressed.bind(0))
	$UI/ShopPanel/ShopTabs/Clínica/OverdriveButton.pressed.connect(_on_shop_purchase_pressed.bind(1))
	$UI/ShopPanel/ShopTabs/Clínica/ExtraBatteryButton.pressed.connect(_on_shop_purchase_pressed.bind(2))
	$UI/ShopPanel/ShopTabs/Armería/ShotgunButton.pressed.connect(_on_shop_purchase_pressed.bind(3))
	$UI/ShopPanel/ShopTabs/Armería/GrenadeLauncherButton.pressed.connect(_on_shop_purchase_pressed.bind(4))
	$UI/ShopPanel/ContinueButton.pressed.connect(_on_continue_pressed)
	wave_ended.connect(_on_wave_ended)
	_start_wave(1)

func add_score(points: int) -> void:
	score += points
	score_label.text = "SCORE %d" % score
	spawn_timer.wait_time = max(0.3, spawn_timer.wait_time - 0.05)


func register_enemy_kill(points: int = 10) -> void:
	add_score(points)
	# En las oleadas del jefe, las arañas que invoca solo dan puntos.
	if _wave_has_ended or _boss_active:
		return

	enemies_killed += 1
	_update_wave_progress()
	if enemies_killed >= enemies_to_kill:
		end_wave()


func show_game_over() -> void:
	get_tree().paused = true
	if final_score_label:
		final_score_label.text = "Score: %d" % score
	game_over_panel.show()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func end_wave() -> void:
	if _wave_has_ended:
		return

	_wave_has_ended = true
	spawn_timer.stop()
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

	shop_fragments_label.text = "Core Fragments: %d" % player.core_fragments
	shop_status_label.text = "Elige una mejora o arma"
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
	var cost := SHOP_COSTS[option_index]
	if player.core_fragments < cost:
		shop_status_label.text = "No tienes suficientes Fragmentos de Núcleo"
		return

	player.core_fragments -= cost
	match option_index:
		0:
			player.current_health = mini(player.max_health, player.current_health + 3)
			player.health_changed.emit(player.current_health, player.max_health)
			shop_status_label.text = "Chasis reparado"
		1:
			player.speed *= 1.15
			shop_status_label.text = "Sobremarcha instalada"
		2:
			player.max_health += 2
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
	shop_fragments_label.text = "Core Fragments: %d" % player.core_fragments


func spawn_boss() -> void:
	_boss_active = true
	boss_warning_label.text = "WARNING: BOSS"
	boss_warning_label.show()
	await get_tree().create_timer(1.5).timeout
	boss_warning_label.hide()
	if boss_scene == null:
		push_error("Cannot spawn final boss: boss_scene is not assigned.")
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Cannot spawn final boss: no player exists in the player group.")
		return

	var boss := boss_scene.instantiate() as Boss
	if boss == null:
		push_error("boss_scene must have a Boss root node.")
		return
	boss.max_health = roundi(BOSS_BASE_HEALTH * wave_director.boss_health_multiplier(current_wave))
	add_child(boss)
	boss.global_position = player.global_position + Vector2(0.0, -300.0)
	boss.defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	_boss_active = false
	boss_warning_label.text = "BOSS DEFEATED"
	boss_warning_label.show()
	# Las arañas que quedan desaparecen para que no maten al jugador ya ganado.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	await get_tree().create_timer(VICTORY_DELAY).timeout
	boss_warning_label.hide()
	if wave_director.is_endless(current_wave):
		# En el modo infinito el jefe es una oleada más: después viene la tienda.
		_wave_has_ended = true
		_finish_wave_transition()
	else:
		show_victory()


func show_victory() -> void:
	spawn_timer.stop()
	get_tree().paused = true
	$UI/VictoryPanel/VictoryScoreLabel.text = "Score: %d" % score
	$UI/VictoryPanel.show()
	$UI/VictoryPanel/Buttons/EndlessButton.grab_focus()


func _on_endless_pressed() -> void:
	$UI/VictoryPanel.hide()
	get_tree().paused = false
	_start_wave(current_wave + 1)


func _update_wave_progress() -> void:
	var prefix := "∞ WAVE %d" if wave_director.is_endless(current_wave) else "WAVE %d"
	if wave_director.is_boss_wave(current_wave):
		wave_time_label.text = (prefix + "  |  BOSS") % current_wave
		return

	wave_time_label.text = (prefix + "  |  KILLS %d/%d") % [
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
		subtitle = "Se acerca el Hivelord"
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
	var spawn_direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var spawn_distance := randf_range(400.0, 600.0)
	add_child(enemy)
	enemy.global_position = player.global_position + spawn_direction * spawn_distance
