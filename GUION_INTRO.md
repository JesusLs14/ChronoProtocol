# Intro cinemática: guion y prompts

Genera cada imagen en Gemini y mándamelas con el nombre que dice cada toma. Yo las animo en Godot: capas con profundidad, movimiento de cámara, fuego, humo, chispas, explosiones, temblor, sonido y los textos de propaganda.

## Reglas para todas las imágenes

- **Formato:** horizontal 16:9 (los fondos). Pídelo en la máxima resolución que te dé.
- **Capas sueltas** (las que dicen "CAPA"): sobre **fondo verde puro (#00FF00)**, sin sombra en el suelo, sin cuadros de transparencia. Yo quito el verde.
- **Mismo estilo en todas.** Si alguna sale con otro estilo, vuelve a generarla agregando "same style as the previous image".
- Pega al final de **cada** prompt este bloque de estilo:

```
Style: detailed pixel art, cinematic sci-fi, dark military propaganda mood, palette of deep navy, steel grey, cyan glow, burning orange and red accents, dramatic lighting, high contrast. No text, no letters, no logos, no watermark.
```

- Cuando aparezca el soldado, pega también este bloque para que siempre sea el mismo:

```
The soldier: Chronos Protocol trooper in dark navy armored power suit with steel plates, rounded helmet with a glowing cyan horizontal visor, long tattered red scarf, carrying a futuristic plasma rifle with cyan glowing details.
```

## Tomas

### Toma 1 · `01_orbita.png` (fondo)
*Texto en pantalla: "AÑO 2187. EL PROTOCOLO CHRONOS PROTEGE A LA HUMANIDAD."*
```
Wide cinematic shot of outer space: a huge blue-green colony planet in the lower half, a fleet of massive angular grey military starships with cyan engine glow in orbit, stars and a distant nebula. Epic scale, 16:9 composition with empty space at the top for titles.
```

### Toma 2 · `02_nave.png` (CAPA, fondo verde)
```
A single massive angular grey military flagship starship seen from the side, cyan engine glow at the back, isolated on a pure flat #00FF00 green background.
```

### Toma 3 · `03_propaganda.png` (fondo)
*Texto: "CIUDADANO: TU PLANETA TE NECESITA."*
```
Military propaganda poster scene: rows of identical soldiers standing at attention saluting in front of giant hanging banners with a stylized hourglass emblem, dramatic low angle, golden light from above, heroic and slightly ominous. 16:9.
```
(+ bloque del soldado)

### Toma 4 · `04_colonia.png` (fondo)
*Texto: "PERO EN LAS COLONIAS EXTERIORES, ALGO DESPERTÓ."*
```
A ruined futuristic colony city at night on an alien planet, burning buildings, the ground and towers covered by organic-mechanical hive growth with glowing red veins, smoke columns, red sky. 16:9, wide shot.
```

### Toma 5 · `05_enjambre.png` (CAPA, fondo verde)
*Texto: "LA COLMENA."*
```
A swarm of mechanical spider robots with glowing red eyes and small spherical surveillance drones with a cyan eye, crawling and flying together toward the viewer, isolated on a pure flat #00FF00 green background.
```

### Toma 6 · `06_hivelord.png` (fondo)
*Texto: "EN SU NÚCLEO: EL HIVELORD."*
```
A colossal biomechanical hive overlord monster rising inside a giant cavern, armored carapace, glowing red core in its chest, mechanical claws, tendrils connected to the walls, tiny silhouettes of spider robots at its feet for scale. Low angle, terrifying. 16:9.
```

### Toma 7 · `07_cielo.png` (fondo) y `08_capsula.png` (CAPA, fondo verde)
*Texto: "POR ESO EXISTE EL SOLDADO CHRONOS."*
```
07: The sky of an alien planet seen from high in the atmosphere, burning orange clouds, red sky, smoke trails of falling objects in the distance. 16:9.
```
```
08: A single armored military drop pod falling diagonally, engulfed in fire and re-entry flames at its bottom, isolated on a pure flat #00FF00 green background.
```

### Toma 8 · `09_aterrizaje.png` (fondo)
*Texto: "ENTRENADO EN CUATRO MINUTOS. ESPERANZA DE VIDA: CLASIFICADA."*
```
The soldier kneeling in a superhero landing pose inside a smoking impact crater, cracked ground, dust and sparks around, the open drop pod behind him, burning colony in the background. Dramatic low angle. 16:9.
```
(+ bloque del soldado)

### Toma 9 · `10_final.png` (fondo)
*Texto: "¡POR LA HUMANIDAD! ¡POR CHRONOS!" y luego el título del juego.*
```
The soldier seen from behind, standing on a ridge holding his plasma rifle, red scarf blowing in the wind, facing a huge swarm of mechanical spiders and the silhouette of the colossal hive overlord on the horizon, red burning sky. Epic final shot, 16:9, empty space at the top for the title.
```
(+ bloque del soldado)

## Lo que necesito de vuelta

10 imágenes: `01_orbita`, `02_nave`, `03_propaganda`, `04_colonia`, `05_enjambre`, `06_hivelord`, `07_cielo`, `08_capsula`, `09_aterrizaje`, `10_final`. Si alguna no sale bien, mándame lo que tengas y la ajusto o la hago por código.
