# Nuevo protagonista: soldado

## Archivos

**Creados** (carpeta `player/soldier/`):
- `soldier_sheet_source.png`: copia byte a byte de "Diseño sin título.png" (el original en Descargas no se tocó).
- `extract_soldier_frames.gd`: procedimiento reproducible que separa los frames.
- `soldier_frames.png`: hoja normalizada generada (celdas de 144×72 px, 8 columnas).
- `soldier_sprite_frames.tres`: recurso SpriteFrames generado con las 6 animaciones.

Para regenerar los dos últimos:

```
godot --headless --path . --script res://player/soldier/extract_soldier_frames.gd
```

**Modificados:**
- `player/player.tscn`: el AnimatedSprite2D usa `soldier_sprite_frames.tres`. Se eliminaron los 22 AtlasTexture del personaje anterior y la referencia a `players blue x1.png` (el archivo sigue en disco). La escala pasa de 9.59×8.16 (deformada) a 4×4 uniforme.
- `player/player.gd`: estados de animación dash, hurt y death (detalles abajo).

## Cómo se separaron los frames

La imagen mide 595×332 y tiene fondo transparente, pero no sigue una cuadrícula uniforme: las filas 1 a 3 tienen 8 figuras, la del dash tiene 5 con otro espaciado y la última tiene 7 con separaciones irregulares. Además, el fogonazo del frame 6 de disparo toca la bufanda del frame 7.

El extractor etiqueta las figuras por píxeles conectados (los semitransparentes se adjuntan a la figura sólida más cercana) y asigna cada grupo al frame cuyo rango contiene su centro. Así se conservan las estelas del dash, las chispas y las marcas de impacto sin arrastrar píxeles vecinos. Cada frame se coloca en su celda con el centro del casco en x=72 y la línea de los pies en y=66, para que no haya saltos entre frames y el volteo horizontal sea simétrico. El extractor falla si algún frame no cabe en su celda, así que nada se recorta. No se generó ningún frame nuevo: los 32 son originales.

## Animaciones

| Animación | Región del original (fila, frames) | FPS | Bucle |
|---|---|---|---|
| idle | Fila 1 (y 0–71), frames 1–8 | 8 | sí |
| run | Fila 2 (y 72–137), frames 1–8 | 12 | sí |
| shoot | Fila 3 (y 138–205), frames 5–8 (último apuntado + 3 con fogonazo) | 16 | no |
| dash | Fila 4 (y 206–264), frames 1–5 (con estela de velocidad) | 24 | sí |
| hurt | Fila 5 (y 265–331), frames 1–2 (el 2 tiene marcas de impacto) | 8 | no |
| death | Fila 5, frames 3–7 (tropieza, se dobla, cae, queda tendido) | 8 | no |

- Los frames 1–4 de la fila 3 no se usan: son casi idénticos al 5 y, si se incluyeran, el fogonazo llegaría unos 0.25 s después de que salga la bala.
- Shoot dura 0.25 s, igual que el intervalo de disparo del Repetidor de Plasma.
- En la muerte, el primer frame se alinea por el casco (igual que hurt) y los siguientes mantienen fijo el pie trasero, para que el cuerpo caiga hacia delante sin deslizarse.
- La animación `reload` anterior no se usaba en el código y la imagen no trae frames de recarga, así que no se incluyó.

## Cambios en player.gd (solo la parte visual)

- `_update_animation()`: durante el dash se reproduce `dash`. `hurt` y `shoot` se terminan antes de volver a run o idle. Cuando la vida llega a 0 no se cambia más de animación.
- `take_damage()`: si el soldado sobrevive reproduce `hurt` y si muere reproduce `death`. Como `show_game_over()` pausa el juego, solo el sprite pasa a `PROCESS_MODE_ALWAYS`, y la caída se ve detrás del panel sin tocar la lógica de Game Over.
- La animación de carrera ahora requiere una velocidad mayor de 10 px/s. Antes bastaba con `> 0`, y como la fricción hace que la velocidad decaiga sin llegar nunca a cero, el personaje seguía corriendo en el sitio después de parar.
- Ya no se reproduce `shoot` si la vida es 0.
- Velocidad, dash, invulnerabilidad, disparo, armas, vida, cámara y colisiones no cambiaron.

## Escala y colisión

- Escala 4×4 entera con filtro nearest (`texture_filter = 1`, ya estaba en el nodo): los píxeles quedan nítidos y sin deformación. El soldado mide unos 224 px de alto, parecido al personaje anterior (unos 261 px).
- `offset = (0, -30)` y `position = (0, 88)`: el eje del casco coincide con el centro de la cápsula de colisión (x = 0, en el origen del nodo) y los pies quedan en su borde inferior (y = 88). La cápsula (radio 75) no se movió ni se redimensionó y cubre torso y piernas.
- El sprite mira a la derecha. Se sigue volteando horizontalmente hacia el ratón con `flip_h`, como antes, y nunca en vertical.

## Pruebas ejecutadas (Godot 4.7.2)

1. Se importó el proyecto (`--headless --import`) sin errores de rutas.
2. Prueba automática sobre `main.tscn`, con 23 comprobaciones y 0 fallos:
   - El jugador usa el nuevo SpriteFrames, las 6 animaciones existen y todas las regiones (144×72) caen dentro de la textura.
   - El juego arranca en idle. Con la flecha derecha se desplaza unos 81 px en 20 frames de física y pasa a run; al soltar vuelve a idle.
   - Al pulsar dash se reproduce `dash` y luego vuelve a idle.
   - Disparar crea un proyectil y reproduce `shoot`, y luego vuelve a idle.
   - Al recibir daño baja 1 punto de vida, se reproduce `hurt` y luego vuelve a idle.
   - Con la vida a 0 se reproduce `death`, el juego se pausa (Game Over) y la animación llega a su último frame con el sprite visible.
3. En una primera ejecución con los enemigos activos, el dron de la escena dañó al jugador por su cuenta, así que las colisiones y el daño siguen funcionando.
4. Se ejecutó con ventana y se tomaron capturas en reposo y en carrera, a unos 145 FPS.

## Limitaciones pendientes

- **Desfase corregido (segunda ronda):** el sprite y la cápsula estaban desplazados 165 px a la izquierda del origen del nodo. Ahora ambos están centrados en el origen (`x = 0`), así que las balas salen del soldado y la cámara y los enemigos apuntan a él. La cápsula conserva su tamaño y su altura relativa (y = 13).
- Los pies de la última fila tocan el borde inferior de la imagen original, así que podría faltar 1 px de sombra bajo los pies en hurt y death.
- La carrera usa los mismos frames en todas las direcciones y mira hacia el ratón, como hacía el personaje anterior. Si corres en dirección contraria al ratón, el soldado corre "de espaldas".
- No probé a mano con teclado y ratón reales: las entradas se simularon desde el script de prueba.

## Tercera ronda: balas desde la boca del arma

- `player/player.tscn`: nuevo nodo `Muzzle` (Marker2D) en `(124, -68)`. Es la punta del cañón en la pose de disparo: celda (103, 27) del frame, a escala 4.
- `player/player.gd`: el nuevo `_update_facing()` voltea al soldado hacia el ratón y lleva `Muzzle` al mismo lado. Se llama también justo antes de disparar, para que la bala salga del lado correcto aunque el ratón acabe de cruzar al otro lado.
- `player/weapon_manager.gd`: el nuevo `muzzle_path` (por defecto `../Muzzle`) hace que los proyectiles aparezcan en la boca del arma. Si el nodo no existe, siguen saliendo del origen del jugador. La dirección de disparo sigue calculándose desde el centro del jugador hacia el ratón, igual que antes.
- Pruebas: la prueba automática pasa con 25 comprobaciones, incluidas el lado de la boca y que la bala aparece en ella. También hay capturas disparando hacia la derecha y hacia la izquierda.

## Cuarta ronda: lanzagranadas y orientación al correr

**Lanzagranadas** (antes la tienda cobraba 15 fragmentos y no daba ningún arma):
- Nuevos `player/grenade.gd` y `player/grenade.tscn`. La granada vuela a 520 px/s hasta el punto apuntado (máximo 650 px) o hasta tocar un enemigo. Al explotar hace 3 de daño a todos los enemigos en un radio de 170 px y sacude la cámara. La granada y la explosión se dibujan por código porque el proyecto no tiene sprite de granada.
- Nuevo `player/grenade_launcher.tres` (WeaponData) con un intervalo de 0.9 s entre disparos.
- `player/weapon_manager.gd`: nuevo `fire_weapon_at()` para armas que se disparan por separado, con su propia cadencia. Sale desde la boca del arma.
- `player/player.gd`: con `current_weapon == "grenade_launcher"` el clic lanza granadas. `player.tscn` asigna `grenade_weapon`.
- `player/main.gd`: al comprar, el lanzagranadas se añade a `unlocked_weapons` y se equipa, igual que la escopeta. Se cambia de arma con la rueda del ratón.

**Orientación:** al correr o hacer dash el soldado mira hacia donde se mueve. Al disparar se gira hacia el ratón durante la animación de disparo, y quieto también mira al ratón.

Pruebas: la prueba automática pasa con 31 comprobaciones. Incluyen que mira hacia donde corre con el ratón detrás, que la compra equipa el arma y cobra 15 fragmentos, que se lanza la granada, que se respeta la cadencia y que la explosión daña a un enemigo. Hay capturas de la granada en vuelo, de la explosión y de la carrera hacia la izquierda.

## Quinta ronda: animaciones del jefe final

Antes, el jefe dibujaba un recorte fijo de 512×512 de `player/hivelord.jpg`, que incluía parte del segundo frame, y un shader eliminaba el fondo negro. La hoja es un JPG de 2752×1536 con 4 filas en una cuadrícula de 7 columnas.

**Creados** (carpeta `enemy/boss/`):
- `extract_boss_frames.gd`: extractor reproducible. Vuelve transparente el fondo negro por brillo, descarta el ruido del JPG, asigna chispas y proyectiles a su frame por componentes conectados y reduce la imagen a la mitad con alfa premultiplicado.
- `boss_frames.png` y `boss_sprite_frames.tres`: archivos generados. `hivelord.jpg` no se modificó.

| Animación | Región del original | FPS | Bucle | Cuándo se reproduce |
|---|---|---|---|---|
| idle | Fila 1, frames 1–4 | 6 | sí | reposo y láser |
| slam | Fila 2, frames 2–5 (garras, vista lateral) | 10 | sí | embestida; se voltea si va hacia la izquierda |
| summon | Fila 2, frame 1 (expulsa vapor) | 2.5 | no | enjambre de arañas |
| missiles | Fila 3, frames 1–5 (abre la escotilla y dispara) | 10 | no | misiles |
| hurt | Fila 4, frames 1–2 (descargas) | 10 | no | al recibir daño en reposo, como mucho una vez cada 1.2 s |
| death | Fila 4, frames 3–7 (se tambalea, arde, explota, chatarra) | 6 | no | al morir |

**Cambios en el jefe:**
- `enemy/boss.tscn`: el `Sprite2D` con shader se sustituye por un `AnimatedSprite2D` a escala 1.1, que da el mismo tamaño en pantalla que antes, centrado en la colisión. Las colisiones, el láser y la vida no cambiaron.
- `enemy/boss.gd`:
  - Cada ataque reproduce su animación y las de una sola vez vuelven a idle al terminar.
  - Al morir, la señal `defeated` se emite igual que antes, pero el jefe se retira de la escena cuando termina la animación de muerte, en lugar de desaparecer al instante. Su colisión y su hurtbox ya están desactivadas desde ese momento.
- **Corrección:** la embestida termina al chocar. Al centrar la colisión del jugador en la ronda anterior, el punto objetivo de la embestida quedó dentro del jugador y el jefe se quedaba empujando para siempre sin volver a atacar.
- `enemy/boss_sprite_key.gdshader` ya no se usa. No lo borré.

**Sin frames propios:** el láser usa la animación de reposo. El enjambre usa el único frame con vapor, porque la hoja no tiene una secuencia de invocación.

**Pruebas:** la prueba del jefe pasa con 32 comprobaciones: animaciones, regiones dentro de la textura, cada ataque, el regreso a idle, la embestida con volteo, el daño, la muerte con `defeated` y la retirada al terminar. La prueba del jugador sigue pasando con 31. Hay capturas de los misiles, la embestida y la muerte.

## Sexta ronda: soldado más pequeño y drones animados

**Soldado:** la escala pasa de 4× a 3×, sigue siendo entera para que los píxeles queden nítidos, y el soldado mide unos 168 px de alto en lugar de 224. Todo lo demás se redujo en la misma proporción:
- la cápsula de colisión: radio de 75 a 56, centro en y = 10;
- la posición de los pies: y = 66;
- la boca del arma: `Muzzle` en (93, -51).

**Dron** (`enemy/enemy.tscn`, `enemy/enemy.gd`; la hoja es `enemy/Drone.png`, de 16×6 celdas de 96 px):
- **Disparo:** antes la animación existía pero nunca se reproducía, y además incluía 7 frames en los que el dron desaparece y solo se ve el proyectil. Ahora usa los frames 3–8 de la fila Attack, a 14 FPS y sin bucle, y se reproduce cada vez que el dron dispara.
- **Daño:** las regiones estaban desplazadas 4 px (y = 196, 95×98) y cortaban al dron. Ahora usan la fila Hurt correcta (y = 192, 96×96).
- **Flotación:** el sprite sube y baja 6 px de forma continua. Cada dron empieza en una fase distinta y la colisión no se mueve.
- La lógica de reposo ya no interrumpe la animación de disparo. Idle (fila Idle) y muerte (fila Death) ya estaban bien y no cambiaron.
- **Sin usar:** las filas Walk/Fly y Dodge de la hoja, porque el dron no se desplaza ni esquiva en el juego.

**Pruebas:**
- Dron: 33 comprobaciones sin fallos, con y sin ventana: regiones alineadas, flotación, disparo con bala y animación, regreso a idle, daño y muerte.
- Jugador (31) y jefe (32): siguen sin fallos.

## Séptima ronda: el arma apunta al ratón

- `player/player.gd`: mientras dispara, el soldado se dibuja en dos partes creadas en código (`AimRig`, hijo del AnimatedSprite2D): el torso con el arma, tomado de los frames de disparo (y 0–44 de la celda), gira sobre la cadera (70, 44) hacia el ratón, con un máximo de 50°. La cadera (y 40–48) y las piernas (y 48–72) no giran; si se mueve, las piernas usan los frames de carrera. El ángulo se corrige para que la línea del cañón, que va 17 px por encima de la cadera, pase por el cursor. `Muzzle` sigue la punta del cañón girado.
- Mantener el clic dispara de forma continua a la cadencia de cada arma (antes había que hacer un clic por bala). Mientras dispara, y 0.35 s después, mira al ratón aunque corra hacia el otro lado; al soltar vuelve a mirar hacia donde corre. El dash y el daño muestran sus animaciones normales.
- `player/weapon_manager.gd`: la bala sale de la boca del arma en dirección al cursor (antes salía en la dirección centro del jugador → cursor y pasaba al lado del cursor). Si el cursor está casi encima del soldado se usa el centro, para no disparar hacia atrás.
- `anim_sprite` ahora tiene tipo `AnimatedSprite2D`. El ratón se lee con `_get_aim_position()` para poder simularlo en pruebas.
- Pruebas: 42 comprobaciones de apuntado (6 direcciones, bala desde el cañón y por el cursor, límite de ángulo, disparo continuo, correr y disparar, dash, daño) y las 19 de movimiento, sin fallos.
