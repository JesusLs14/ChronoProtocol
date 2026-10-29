"""Dibuja los iconos del francotirador, el lanzallamas y el láser en pixel art
de 64x23 escalado a 256x92, con la misma paleta metálica que los demás iconos
de la tienda.

Uso: python draw_weapon_icons.py  (necesita Pillow)
"""
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
WIDTH, HEIGHT = 64, 23
SCALE = 4

OUTLINE = (8, 10, 20, 255)
METAL_DARK = (52, 60, 78, 255)
METAL = (92, 104, 126, 255)
METAL_LIGHT = (170, 186, 206, 255)
SHINE = (226, 238, 250, 255)
GRIP = (60, 44, 36, 255)
GRIP_LIGHT = (98, 72, 56, 255)


def new_canvas():
    return Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))


def rect(px, x0, y0, x1, y1, color):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            if 0 <= x < WIDTH and 0 <= y < HEIGHT:
                px[x, y] = color


def outline(image):
    """Contorno oscuro de 1 px alrededor de todo lo dibujado."""
    src = image.copy().load()
    px = image.load()
    for x in range(WIDTH):
        for y in range(HEIGHT):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < WIDTH and 0 <= ny < HEIGHT and src[nx, ny][3] != 0 and src[nx, ny] != OUTLINE:
                    px[x, y] = OUTLINE
                    break


def body(px, x0, x1, y0, y1):
    rect(px, x0, y0, x1, y1, METAL)
    rect(px, x0, y0, x1, y0, METAL_LIGHT)
    rect(px, x0, y1, x1, y1, METAL_DARK)


def grip(px, x, y, height=6):
    for i in range(height):
        rect(px, x - i // 3, y + i, x + 3 - i // 3, y + i, GRIP if i % 2 else GRIP_LIGHT)


def save(image, name):
    image.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.NEAREST).save(HERE / name)


def sniper():
    image = new_canvas()
    px = image.load()
    # Culata, cuerpo, cañón largo y mira telescópica.
    rect(px, 2, 9, 12, 14, GRIP_LIGHT)
    rect(px, 2, 14, 10, 15, GRIP)
    body(px, 12, 34, 9, 13)
    rect(px, 34, 10, 60, 11, METAL_LIGHT)
    rect(px, 34, 12, 60, 12, METAL_DARK)
    rect(px, 58, 9, 61, 13, METAL)
    rect(px, 17, 4, 31, 7, METAL_DARK)
    rect(px, 17, 4, 31, 4, METAL_LIGHT)
    rect(px, 15, 5, 16, 6, (120, 220, 255, 255))
    rect(px, 32, 5, 33, 6, (120, 220, 255, 255))
    rect(px, 21, 8, 22, 8, METAL_DARK)
    rect(px, 27, 8, 28, 8, METAL_DARK)
    grip(px, 22, 14)
    rect(px, 40, 13, 41, 17, METAL_DARK)
    rect(px, 38, 17, 43, 17, METAL_DARK)
    rect(px, 13, 10, 33, 10, SHINE)
    outline(image)
    save(image, "icon_sniper.png")


def flamethrower():
    image = new_canvas()
    px = image.load()
    tank = (210, 70, 40, 255)
    tank_light = (255, 140, 80, 255)
    tank_dark = (130, 36, 24, 255)
    # Depósito rojo, cuerpo, boquilla ancha y llama piloto.
    rect(px, 8, 13, 22, 19, tank)
    rect(px, 8, 13, 22, 13, tank_light)
    rect(px, 8, 19, 22, 19, tank_dark)
    rect(px, 7, 14, 7, 18, tank_dark)
    rect(px, 23, 14, 23, 18, tank_dark)
    body(px, 4, 40, 7, 12)
    rect(px, 40, 6, 46, 13, METAL_DARK)
    rect(px, 41, 7, 46, 7, METAL_LIGHT)
    rect(px, 46, 5, 49, 14, METAL)
    rect(px, 47, 5, 49, 5, METAL_LIGHT)
    grip(px, 30, 12)
    rect(px, 5, 8, 39, 8, SHINE)
    flame = [(255, 240, 150, 255), (255, 170, 40, 255), (240, 80, 20, 255)]
    for i, color in enumerate(flame):
        rect(px, 51 + i * 3, 8 - i, 53 + i * 3, 11 + i, color)
    rect(px, 51, 9, 52, 10, (255, 255, 230, 255))
    outline(image)
    save(image, "icon_flamethrower.png")


def laser():
    image = new_canvas()
    px = image.load()
    glow = (90, 255, 255, 255)
    glow_dark = (20, 160, 200, 255)
    # Cuerpo con bobinas de energía, emisor y rayo.
    body(px, 4, 34, 7, 14)
    for x in (10, 15, 20, 25):
        rect(px, x, 6, x + 2, 15, METAL_DARK)
        rect(px, x, 9, x + 2, 12, glow)
        rect(px, x, 11, x + 2, 12, glow_dark)
    rect(px, 34, 8, 40, 13, METAL_DARK)
    rect(px, 40, 9, 42, 12, glow)
    rect(px, 43, 10, 63, 11, glow)
    rect(px, 43, 10, 63, 10, (220, 255, 255, 255))
    grip(px, 24, 14)
    rect(px, 5, 8, 33, 8, SHINE)
    outline(image)
    save(image, "icon_laser.png")


sniper()
flamethrower()
laser()
