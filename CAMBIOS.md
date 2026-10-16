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

## No traído
- Las animaciones nuevas del jefe y del dron de ChronoProtocol: esta carpeta usa otro sprite del jefe (`hivelord.png`) con sus propios ataques.
