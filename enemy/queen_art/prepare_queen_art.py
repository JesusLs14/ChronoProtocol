"""Prepara los sprites de la Reina de la Colmena a partir de las imágenes de
Gemini en source/ (fondo verde #00FF00 y, en la Reina, líneas de cuadrícula).

- hive_queen_sheet.png: 8x4 celdas de 364x360 (idle 4, poner huevos 7,
  chillido/ácido 6, muerte 8), sin fondo ni cuadrícula.
- queen_egg_sheet.png: 6 celdas de 244x176 (late 3, se rompe 3).

El fondo se quita con un relleno desde el borde de cada celda (solo el verde
conectado al exterior), más los píxeles casi idénticos al verde puro, para
no borrar las venas verdes de la Reina ni el ácido.

Uso: python prepare_queen_art.py  (necesita Pillow y numpy)
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
SOURCE = HERE / "source"

QUEEN_COLUMNS, QUEEN_ROWS = 8, 4
QUEEN_CELL = (364, 360)
GRID_MARGIN = 12
EGG_FRAMES = 6
EGG_SCALE = 4


def background_mask(rgb: np.ndarray) -> np.ndarray:
    """True donde el píxel es fondo verde conectado al borde de la imagen."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    greenness = g - np.maximum(r, b)
    candidate = (greenness > 120) & (g > 170)
    near_pure = (greenness > 200) & (g > 225)
    seed = np.zeros_like(candidate)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = True
    filled = seed & candidate
    # Relleno por dilatación restringida a los candidatos hasta estabilizar.
    while True:
        grown = filled.copy()
        grown[1:, :] |= filled[:-1, :]
        grown[:-1, :] |= filled[1:, :]
        grown[:, 1:] |= filled[:, :-1]
        grown[:, :-1] |= filled[:, 1:]
        grown &= candidate
        if np.array_equal(grown, filled):
            break
        filled = grown
    return filled | near_pure


def key_out(cell: Image.Image) -> Image.Image:
    rgb = np.array(cell.convert("RGB")).astype(np.int32)
    mask = background_mask(rgb)
    alpha = np.where(mask, 0, 255).astype(np.uint8)
    # Quita el borde verdoso que deja el JPG junto al fondo.
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    edge = np.zeros_like(mask)
    edge[1:, :] |= mask[:-1, :]
    edge[:-1, :] |= mask[1:, :]
    edge[:, 1:] |= mask[:, :-1]
    edge[:, :-1] |= mask[:, 1:]
    edge &= ~mask
    spill = edge & (g > np.maximum(r, b) + 30)
    rgb[..., 1] = np.where(spill, np.maximum(r, b), g)
    alpha = np.where(spill, 160, alpha).astype(np.uint8)
    out = np.dstack([rgb.clip(0, 255).astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")


def queen_sheet() -> None:
    source = Image.open(SOURCE / "queen_sheet_gemini.jpg").convert("RGB")
    width, height = QUEEN_CELL
    sheet = Image.new("RGBA", (width * QUEEN_COLUMNS, height * QUEEN_ROWS), (0, 0, 0, 0))
    step_x = source.width / QUEEN_COLUMNS
    step_y = source.height / QUEEN_ROWS
    for row in range(QUEEN_ROWS):
        for column in range(QUEEN_COLUMNS):
            box = (
                round(column * step_x) + GRID_MARGIN,
                round(row * step_y) + GRID_MARGIN,
                round((column + 1) * step_x) - GRID_MARGIN,
                round((row + 1) * step_y) - GRID_MARGIN,
            )
            cell = key_out(source.crop(box))
            sheet.paste(cell, (column * width + GRID_MARGIN, row * height + GRID_MARGIN))
    sheet.save(HERE / "hive_queen_sheet.png")
    print("hive_queen_sheet.png", sheet.size)


def egg_sheet() -> None:
    source = Image.open(SOURCE / "eggs_gemini.jpg").convert("RGB")
    step = source.width / EGG_FRAMES
    cell_size = (round(step) // EGG_SCALE, source.height // EGG_SCALE)
    sheet = Image.new("RGBA", (cell_size[0] * EGG_FRAMES, cell_size[1]), (0, 0, 0, 0))
    for index in range(EGG_FRAMES):
        box = (round(index * step), 0, round((index + 1) * step), source.height)
        cell = key_out(source.crop(box)).resize(cell_size, Image.LANCZOS)
        sheet.paste(cell, (index * cell_size[0], 0))
    sheet.save(HERE / "queen_egg_sheet.png")
    print("queen_egg_sheet.png", sheet.size, "cell", cell_size)


if __name__ == "__main__":
    queen_sheet()
    egg_sheet()
