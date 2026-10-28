# Cambios en SOLDADO (16/10/2026)

## Mejoras traídas de ChronoProtocol-main
- **Nuevo soldado** (`player/soldier/`): sprite con animaciones idle, run, shoot, dash, hurt y death, escala 3× sin deformar y centrado en la colisión. `prota.png` sigue en disco pero ya no se usa.
- **Apuntado** (`player/player.gd`): al disparar, el torso y el arma giran hacia el ratón (máx. 50°) y las piernas siguen corriendo. Al correr mira hacia donde se mueve.
- **Disparo** (`player/weapon_manager.gd`): la bala sale de la boca del arma (`Muzzle`) en dirección al cursor. Mantener el clic dispara de forma continua a la cadencia de cada arma.
- **Lanzagranadas** (`player/grenade*.{gd,tscn}`, `grenade_launcher.tres`): el botón de la tienda (15 fragmentos) vuelve a estar activo y ahora sí entrega el arma.
- Se conservaron las cosas propias de esta carpeta: sonidos de disparo y daño, mando (stick izquierdo para moverse, derecho para apuntar), muerte con animación antes del Game Over, y el jefe con enfurecido y sonidos.

## Nuevo
- **Destello de daño**: el soldado parpadea en rojo 3 veces y aparece una viñeta roja en los bordes de la pantalla (`hit_flash_component.gd` ahora acepta color y número de destellos; `damage_vignette.gdshader`).
- **Fondo**: piso metálico animado con juntas cian, remaches, pulso de energía y núcleo en el centro (`player/arena_background.gdshader`, nodo `Arena/Background`). Las paredes y colisiones no cambiaron.
- **Menú principal** (`menu/main_menu.tscn`, ahora escena inicial): Jugar, Controles y Salir.
- **Menú de pausa** (`menu/pause_menu.tscn`): Esc o Start. Continuar, Reiniciar y Menú principal. El Game Over también tiene botón "Menú principal".
- **Barra de vida del jefe** (`enemy/boss_health_bar.tscn`): antes medía 4 px de ancho y casi no se veía. Ahora es una barra ancha arriba con el nombre, la vida en números, una barra clara que muestra el daño reciente, color naranja y aviso "¡ENFURECIDO!" bajo la mitad de vida, y se desvanece al morir el jefe.

## Segunda ronda: pose de disparo e iconos de la tienda
- **Piernas al disparar:** antes giraba todo el torso con la cabeza sobre la cadera y, al correr, se usaban las piernas de la carrera inclinada, que quedaban detrás del torso. Ahora la pose se arma con tres capas nuevas (`player/soldier/soldier_aim_parts.png`, generada por `build_aim_parts.py` a partir de los frames originales):
  - cuerpo sin el arma, que se queda derecho y solo se inclina hasta 12°;
  - arma con los brazos, que gira sobre el hombro hacia el ratón (hasta 80° arriba o abajo) y conserva el fogonazo;
  - piernas: las de reposo y 8 de carrera, ya sin restos del arma y movidas para que la cadera quede bajo el torso.
  - Si corre en sentido contrario a donde apunta, las piernas reproducen la carrera al revés (camina hacia atrás).
  - El código está en `player/soldier/soldier_aim_rig.gd`, un componente nuevo; `player.gd` solo lo crea y le pasa el ratón.
- **Iconos en la tienda** (`player/shop_icons/`): corazón en Reparar Chasis, rayo en Sobremarcha, escopeta y lanzagranadas en la Armería. Se les quitó el fondo de cuadros que venía pintado en las imágenes. Batería Extra no tiene icono porque no se envió uno.

## Tercera ronda: jugabilidad
- **Invulnerabilidad tras un golpe** (`player.gd`, `hurt_invulnerability_duration` = 0.6 s): el soldado parpadea y no recibe más daño durante ese tiempo. En una prueba de 20 s quieto, los golpes recibidos bajaron de 131 a 24 (como máximo 2 por segundo, antes 18).
- **El jefe ya muere bien:** su animación de muerte estaba en bucle, así que nunca terminaba, el jefe no desaparecía y la partida no se podía ganar. Ahora la animación termina (`enemy/boss.tscn`).
- **Pantalla de victoria** (`main.tscn`, `main.gd`): aparece 1.5 s después de derrotar al jefe, con el puntaje y botones para jugar de nuevo o ir al menú. Las arañas que quedan desaparecen al morir el jefe.
- **Arma actual en pantalla** (`player/weapon_hud.gd`, abajo a la izquierda): icono y nombre del arma; da un pequeño salto al cambiar. `Player.equip_weapon()` y la señal `weapon_changed` avisan del cambio.
- **Destello de daño de drones y arañas:** antes cambiaba a blanco un sprite que ya era blanco y no se veía; ahora brilla (`hit_flash_component.gd`).
- Se quitó una conexión rota del botón Retry a una función que no existía.

## Cuarta ronda: dron, sonidos e icono
- **Dron animado** (traído de ChronoProtocol, `enemy/enemy.gd` y `enemy.tscn`): flota subiendo y bajando, reproduce su animación al disparar y la animación de daño ya no corta al dron.
- **Sonidos nuevos** (`sfx/`, generados con `generate_sfx.py`): explosión de la granada, clic y sonido al pasar por cualquier botón, y campanita al recoger fragmentos. Los reproduce el autoload `Sfx` (`sfx/sfx.gd`), que conecta solo todos los botones del juego y evita que el imán de fragmentos sature el sonido.
- **Icono de Batería Extra** (`player/shop_icons/icon_battery.png`, dibujado con `draw_battery_icon.py`): batería con celdas cian y un "+" verde.

## Quinta ronda: historia, enemigos por oleada y modo infinito
- **Intro** (`menu/intro.tscn`, `menu/intro.gd`): transmisión de propaganda del Mando Chronos, al estilo de Helldivers 2, en 7 escenas: el Protocolo Chronos, la Colmena, el Hivelord, el Soldado Chronos y la misión. Texto que se escribe solo, titulares animados, líneas de pantalla vieja y los sprites del juego en escena. Sale al pulsar Jugar; clic o Espacio avanza y Esc la salta.
- **Enemigos distintos por oleada** (`enemy/enemy_variant.gd`, `enemy/variants/`, `player/wave_director.gd`): 5 tipos a partir de la araña y el dron, con otro color, tamaño y estadísticas:
  - Araña (1 vida), Araña veloz (más rápida y pequeña), Araña acorazada (4 de vida, lenta, grande);
  - Dron (3 de vida), Dron artillero (5 de vida, dispara casi el doble de rápido).
  - Oleada 1: arañas. Oleada 2: arañas y drones. Oleada 3: entra la araña veloz. Oleada 4: acorazadas y artilleros. Oleada 5: el jefe.
  - Al empezar cada oleada aparece un aviso con los enemigos nuevos (`player/wave_banner.gd`). Cada tipo da distinto puntaje y los más duros sueltan un fragmento extra.
- **Modo infinito:** la pantalla de victoria tiene el botón "MODO INFINITO". Las oleadas siguen con mezcla de todos los enemigos, más vida y aparición más rápida; el jefe vuelve cada 5 oleadas con 50 % más de vida cada vez, y la tienda sale después de cada oleada. El HUD muestra "∞ WAVE n".
- El puntaje ahora se ve más grande y conserva la palabra "SCORE". Las arañas que invoca el jefe ya no cuentan para terminar la oleada (antes podían acabarla en medio de la pelea).
- Se quitó el dron que aparecía fijo junto al jugador al empezar, porque la oleada 1 es solo de arañas.

## Sexta ronda: intro cinemática
- La intro anterior (sprites del juego como marionetas) se reemplazó por una cinemática con 10 ilustraciones nuevas generadas con los prompts de `GUION_INTRO.md`. Las originales están en `menu/intro_art/source/`; `prepare_intro_art.py` las escala y quita el fondo verde de la nave, el enjambre y la cápsula.
- 8 tomas animadas (`menu/intro.gd`, partículas en `menu/intro_fx.gd`): la flota en órbita con la nave insignia cruzando; la tropa saludando con polvo dorado; la colonia en llamas con humo y brasas; el enjambre avanzando hacia la cámara; el Hivelord con el núcleo latiendo en rojo y temblores; la cápsula cayendo en llamas con impacto; el aterrizaje con estallido de chispas; y el plano final con el título CHRONOS PROTOCOL.
- Barras de cine arriba y abajo, textos de propaganda que se escriben solos, destellos, temblor de cámara y sonido. Clic o Espacio pasa de toma, Esc la salta.

## Séptima ronda: racha de bajas
- **Contador de racha** estilo Diablo (`player/kill_streak.gd`, `player/kill_streak_hud.gd`): a la derecha aparece "x12" desde la 3.ª baja seguida, con el nombre de la racha, una barra con el tiempo que queda y la siguiente recompensa. Hay 4 s para conseguir la siguiente baja; si se acaba el tiempo o el soldado recibe daño, la racha se corta (un golpe que bloquea el escudo no la corta).
- **Recompensas:**
  - 10 bajas: +1 de vida.
  - 20: escudo que bloquea 2 golpes (burbuja cian con un punto por golpe, `player/shield_bubble.gd`).
  - 30: sobrecarga por 6 s, con 35 % más de velocidad, doble cadencia en todas las armas y estela cian.
  - 50: masacre, +3 de vida y escudo de 3 golpes.
  - Desde ahí, cada 25 bajas: sobrecarga, escudo o +2 de vida, en ese orden.
- Cada recompensa se anuncia con un texto grande y un sonido.
- El HUD de arriba a la izquierda (puntaje y oleada) ya no se encima.

## Octava ronda: correcciones
- El panel del arma subió 40 px. En una ventana maximizada, la barra de tareas de Windows tapaba la parte de abajo. Nuevo: F11 o Alt+Enter cambian a pantalla completa real (`menu/window_controls.gd`, autoload).
- Recibir daño ya no hace sonido: solo queda el destello. El sonido ahora suena solo al morir.
- La racha ya no se pierde al terminar la oleada: se congela durante la transición, la tienda y la muerte del jefe, y al empezar la siguiente oleada sigue con el tiempo completo.
- El HUD de racha ahora dice qué da la próxima recompensa ("A las 20: Bloquea los próximos 2 golpes").

## Novena ronda: mejoras de arma y más fragmentos
- **Pestaña "Mejoras" en la tienda** (`player/weapon_upgrades.gd`). Cada mejora sube de nivel, se aplica a todas las armas y el botón muestra el nivel actual y el costo del siguiente:
  - Cadencia: +15 % por nivel, 5 niveles (10, 15, 20, 25, 30 fragmentos).
  - Daño: +1 por bala, y también a la explosión de la granada; 3 niveles (15, 25, 35).
  - Perforación: la bala atraviesa +1 enemigo; 2 niveles (20, 35).
  - Al llegar al máximo, el botón dice MÁXIMO y se desactiva. La cadencia se suma a la sobrecarga de la racha.
- **Más orbes:** los enemigos sueltan varios orbes de 1 fragmento que saltan alrededor (`player/fragment_dropper.gd`). La araña suelta 2, el dron 3, y las acorazadas y los drones artilleros 1 más. Además, cada enemigo tiene 25 % de probabilidad de soltar un orbe extra.

## Décima ronda: estratagemas estilo Helldivers 2
- Se mantiene **Ctrl o Q** (o Back en el mando), se mete la combinación con WASD, las flechas o la cruceta, y la baliza se lanza hacia el ratón (máximo 650 px). Mientras se mete la combinación el soldado no camina ni dispara, y un error reinicia la combinación (`player/stratagems/stratagem_controller.gd`).
- La baliza marca la zona con un haz de luz y a los 2 s llega la ayuda (`stratagem_beacon.gd`):
  - **Ataque orbital** → ↓ ↑ → (recarga 30 s): explosión de 280 px de radio que hace 12 de daño.
  - **Suministros** ↓ ↓ ↑ → (recarga 40 s): cae una cápsula y deja una caja que da +3 de vida y un escudo de 1 golpe al tocarla. Dura 30 s (`supply_crate.gd`).
  - **Torreta** ↓ ↑ → ← (recarga 45 s): cae una torreta que dispara sola al enemigo más cercano durante 20 s (`sentry_turret.gd`).
  - Las cápsulas usan la ilustración de la intro y dañan a lo que aplastan.
- Panel a la izquierda (`stratagem_hud.gd`): siempre muestra cada estratagema con su recarga; al mantener Ctrl/Q se ilumina y marca las flechas que ya se metieron. Los controles del menú lo explican.

## Undécima ronda: récords, volumen, flechas, efectos, entrada del jefe y más contenido
- **Récords guardados** (autoload `GameStats`, `menu/game_stats.gd`, archivo `user://stats.cfg`): mejor puntaje, mejor racha, oleada más alta, partidas, bajas totales y jefes derrotados. Se ven abajo a la izquierda del menú principal y en el Game Over y la Victoria, con "¡NUEVO RÉCORD!" cuando se supera alguno. También se guardan al reiniciar o salir al menú desde la pausa.
- **Volumen** (autoload `GameSettings`, `menu/game_settings.gd`, archivo `user://settings.cfg`): deslizadores de Música y Efectos en el nuevo botón OPCIONES del menú y en la pausa. Crea los buses "Music" y "SFX" y manda solo la música al primero y todos los demás sonidos al segundo.
- **Flechas de enemigos fuera de pantalla** (`player/offscreen_indicators.gd`): en el borde, del color de cada enemigo, más grandes y opacas cuanto más cerca está. El jefe tiene una flecha roja grande que late con la palabra JEFE.
- **Números de daño y explosión al morir** (`player/combat_fx.gd`, desde `enemy/health_component.gd`): cada golpe hace saltar el daño (amarillo, naranja si es 5 o más, rojo el golpe que mata) y al morir el enemigo estalla en pedazos de su color con un pequeño sonido.
- **Entrada del Hivelord** (`player/boss_intro.gd`): barras de cine, el HUD se oculta, la cámara viaja hasta el jefe y se acerca mientras cae del cielo, impacto con temblor, "SEÑOR DE LA COLMENA / HIVELORD" y rugido; luego la cámara vuelve al soldado y empieza la pelea. Durante la entrada el soldado no se mueve ni recibe daño, y el jefe no ataca (`Boss.intro_mode`, `start_fight()`).
- **Estratagemas nuevas** (`stratagem_controller.gd`, `stratagem_beacon.gd`):
  - **Ataque aéreo** ↑ → ↓ → (recarga 35 s): cruza la sombra de un caza y caen 6 bombas en fila en la dirección del lanzamiento (6 de daño, 130 px cada una).
  - **Pulso EMS** ↓ ← ↑ ← (recarga 50 s): onda de 340 px que hace 1 de daño y paraliza 5 s a los enemigos (no al jefe): no se mueven, no disparan, se ponen azules y les saltan chispas (`player/stratagems/stun_effect.gd`).
- **Enemigo nuevo: Araña bomba** (`enemy/spider_bomber.gd`, `spider_bomber.tscn`, `variants/bomber_spider.tres`): amarilla, 2 de vida, algo más rápida. Al alcanzar al soldado parpadea y explota a los 0.6 s; también explota si la matan. La explosión quita 2 de vida al soldado y 3 a los enemigos cercanos (puede encadenar otras bombas). Aparece desde la oleada 4 y en el modo infinito. `Player.take_damage()` ahora acepta la cantidad de daño (por defecto 1).

## Duodécima ronda: el Soldado Cero
- **Nuevo jefe en la oleada 10** (`enemy/corrupted_soldier.gd`, `corrupted_soldier.tscn`): un soldado Chronos contaminado por la Colmena. Usa los mismos sprites y la misma pose de apuntado del protagonista con el shader `enemy/corruption.gdshader` (morado, venas verdes que laten, las luces cian del traje en rojo y franjas de glitch que aumentan al enfurecerse).
  - Se mueve de lado manteniendo distancia y hace dash con estela morada; durante el dash las balas lo atraviesan.
  - Ráfagas de plasma morado avisadas con una línea roja de mira (los últimos instantes la mira se queda fija para poder esquivar).
  - Bajo la mitad de vida se enfurece: escopeta en abanico (con aviso en cono), tres granadas tóxicas que marcan un círculo verde antes de explotar, y su propio orbital con baliza roja (2 de daño).
  - Al bajar del 66 % y del 33 % de vida se cubre con un escudo que hay que romper a balazos.
  - Barra de vida morada "SOLDADO CERO" (verde al enfurecerse) y entrada cinemática "SOLDADO CERO — EL PRIMERO QUE CAYÓ".
- **Jefes al azar** (`wave_director.gd`): oleada 5 Hivelord, oleada 10 Soldado Cero y desde la 15, cada 5 oleadas, uno al azar. Cada aparición sube un nivel: el Hivelord tiene 50 % más de vida y ataca 8 % más seguido por nivel; el Soldado Cero gana 120 de vida, más balas por ráfaga, más velocidad y más agresividad. El aviso de la oleada dice qué jefe se acerca.
- Los jefes llevan el grupo "boss" (flechas, estallido grande y el EMS no los paraliza) y comparten `configure()`, `start_fight()`, `intro_roar()` e `intro_settle()` para la entrada.

## No traído
- Las animaciones nuevas del jefe de ChronoProtocol: esta carpeta usa otro sprite del jefe (`hivelord.png`) con sus propios ataques.
