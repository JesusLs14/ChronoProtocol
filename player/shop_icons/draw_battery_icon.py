"""Dibuja icon_battery.png (batería con celdas cian y un "+"), en pixel art de
32x32 escalado a 128x128, con el estilo de los demás iconos de la tienda.

Uso: python draw_battery_icon.py  (necesita Pillow)
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
SIZE = 32
SCALE = 4

OUTLINE = (8, 10, 20, 255)
METAL_DARK = (52, 60, 78, 255)
METAL = (92, 104, 126, 255)
METAL_LIGHT = (170, 186, 206, 255)
SHINE = (226, 238, 250, 255)
INSIDE = (14, 22, 36, 255)
CELL = (40, 220, 235, 255)
CELL_LIGHT = (170, 255, 255, 255)
CELL_DARK = (18, 130, 170, 255)
PLUS = (120, 255, 140, 255)
PLUS_DARK = (30, 150, 70, 255)
SPARK = (120, 245, 255, 255)

image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
px = image.load()


def rect(x0: int, y0: int, x1: int, y1: int, color: tuple) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px[x, y] = color


# Cuerpo (vertical) con borde negro.
rect(7, 6, 24, 29, OUTLINE)
rect(8, 7, 23, 28, METAL)
rect(8, 7, 9, 28, METAL_LIGHT)
rect(22, 7, 23, 28, METAL_DARK)
rect(8, 27, 23, 28, METAL_DARK)
rect(10, 7, 21, 7, METAL_LIGHT)
# Polo superior.
rect(12, 2, 19, 6, OUTLINE)
rect(13, 3, 18, 6, METAL)
rect(13, 3, 14, 5, SHINE)
rect(17, 3, 18, 6, METAL_DARK)

# Ventana interior con tres celdas de energía.
rect(10, 9, 21, 26, OUTLINE)
rect(11, 10, 20, 25, INSIDE)
for top in (11, 16, 21):
    rect(12, top, 19, top + 3, CELL)
    rect(12, top, 19, top, CELL_LIGHT)
    rect(12, top + 3, 19, top + 3, CELL_DARK)
    rect(19, top, 19, top + 3, CELL_DARK)

# Brillo del metal.
rect(8, 9, 8, 14, SHINE)

# "+" verde abajo a la derecha (más capacidad).
rect(23, 21, 29, 23, OUTLINE)
rect(25, 19, 27, 25, OUTLINE)
rect(24, 22, 28, 22, PLUS)
rect(26, 20, 26, 24, PLUS)
px[28, 22] = PLUS_DARK
px[26, 24] = PLUS_DARK

# Chispas.
for x, y in ((4, 9), (3, 18), (28, 6), (27, 13), (5, 26)):
    px[x, y] = SPARK
for x, y in ((4, 8), (4, 10), (3, 9), (5, 9)):
    px[x, y] = (60, 200, 230, 200)

image.resize((SIZE * SCALE, SIZE * SCALE), Image.NEAREST).save(HERE / "icon_battery.png")
print("icon_battery.png generado")
