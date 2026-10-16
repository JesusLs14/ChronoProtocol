"""Genera soldier_aim_parts.png a partir de soldier_frames.png.

Separa la pose de disparo en tres capas para que solo el arma gire hacia el
ratón y el cuerpo y las piernas sigan alineados:

- Fila 0, columna 0: cuerpo sin el arma (cabeza, torso, bufanda, cadera).
- Fila 1, columnas 0-3: el arma con los brazos (frames de disparo 0-3, con
  fogonazo en 1-3).
- Fila 2, columna 0: piernas en reposo (de la pose de disparo).
- Fila 2, columnas 1-8: piernas de carrera, sin restos del arma y movidas en x
  para que la cadera quede justo debajo del torso de disparo.

Todas las celdas miden 144x72, igual que soldier_frames.png, así que las
coordenadas dentro de la celda son las mismas.

Uso: python build_aim_parts.py  (necesita Pillow y numpy)
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
CELL_W, CELL_H = 144, 72
SHOOT_ROW_Y = 144
RUN_ROW_Y = 72
LEGS_TOP = 47
SHOOT_FRAMES = 4
RUN_FRAMES = 8


def cell(sheet: np.ndarray, column: int, row_y: int) -> np.ndarray:
    return sheet[row_y:row_y + CELL_H, column * CELL_W:(column + 1) * CELL_W].copy()


def gun_mask() -> np.ndarray:
    """Píxeles del arma y de los antebrazos dentro de la celda de disparo."""
    ys, xs = np.mgrid[0:CELL_H, 0:CELL_W]
    barrel = (ys >= 25) & (ys <= 31) & (xs >= 66)
    front = (ys >= 22) & (ys <= 31) & (xs >= 81)
    hands = (ys > 31) & (ys <= 40) & (xs >= 79)
    return barrel | front | hands


def fill_chest(body: np.ndarray, removed: np.ndarray) -> None:
    """Rellena con la armadura del pecho el hueco que deja el arma sobre el
    torso: cada píxel quitado dentro de la silueta copia el píxel opaco más
    cercano de debajo, en la misma columna."""
    alpha = body[:, :, 3]
    for x in range(CELL_W):
        column = np.nonzero(removed[:, x])[0]
        if len(column) == 0:
            continue
        opaque_above = np.nonzero(alpha[:column.min(), x] > 128)[0]
        opaque_below = np.nonzero(alpha[column.max() + 1:, x] > 128)[0]
        # Solo dentro del cuerpo: tiene que haber armadura arriba y abajo.
        if len(opaque_above) == 0 or len(opaque_below) == 0:
            continue
        source_y = column.max() + 1 + opaque_below[0]
        for y in column:
            body[y, x] = body[source_y, x]


def keep_leg_components(legs: np.ndarray) -> np.ndarray:
    """Quita los grupos de píxeles que no bajan hasta los pies (restos del
    arma o de la mano que asoman por la cintura en los frames de carrera)."""
    opaque = legs[:, :, 3] > 0
    labels = np.zeros(opaque.shape, dtype=np.int32)
    current = 0
    height, width = opaque.shape
    for y0 in range(height):
        for x0 in range(width):
            if not opaque[y0, x0] or labels[y0, x0]:
                continue
            current += 1
            stack = [(y0, x0)]
            labels[y0, x0] = current
            while stack:
                y, x = stack.pop()
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < height and 0 <= nx < width and opaque[ny, nx] and not labels[ny, nx]:
                            labels[ny, nx] = current
                            stack.append((ny, nx))
    result = legs.copy()
    for label in range(1, current + 1):
        ys = np.nonzero(labels == label)[0]
        if ys.max() < 10 or len(ys) < 12:
            result[labels == label] = 0
    return result


def pelvis_x(legs: np.ndarray) -> float:
    xs = np.nonzero(legs[0:5, :, 3] > 128)[1]
    return float(xs.mean())


def main() -> None:
    sheet = np.array(Image.open(HERE / "soldier_frames.png").convert("RGBA"))
    out = np.zeros((CELL_H * 3, CELL_W * (RUN_FRAMES + 1), 4), dtype=np.uint8)
    mask = gun_mask()

    shoot0 = cell(sheet, 0, SHOOT_ROW_Y)
    body = shoot0.copy()
    removed = mask & (body[:, :, 3] > 0)
    body[mask] = 0
    fill_chest(body, removed)
    body[LEGS_TOP + 1:] = 0
    out[0:CELL_H, 0:CELL_W] = body

    for column in range(SHOOT_FRAMES):
        frame = cell(sheet, column, SHOOT_ROW_Y)
        gun = np.zeros_like(frame)
        gun[mask] = frame[mask]
        # El fogonazo sale por delante del cañón, fuera de la máscara.
        gun[18:36, 106:] = frame[18:36, 106:]
        out[CELL_H:CELL_H * 2, column * CELL_W:(column + 1) * CELL_W] = gun

    standing = np.zeros_like(shoot0)
    standing[LEGS_TOP:] = shoot0[LEGS_TOP:]
    out[CELL_H * 2:, 0:CELL_W] = standing
    target_x = pelvis_x(shoot0[LEGS_TOP:])

    for column in range(RUN_FRAMES):
        frame = cell(sheet, column, RUN_ROW_Y)
        legs = keep_leg_components(frame[LEGS_TOP:])
        shift = int(round(target_x - pelvis_x(legs)))
        legs = np.roll(legs, shift, axis=1)
        # La mano y el arma asoman por delante de la cintura en las primeras
        # filas; ya alineadas, las piernas no pasan de x = 84 a esa altura.
        legs[0:7, 84:] = 0
        legs = keep_leg_components(legs)
        placed = np.zeros_like(frame)
        placed[LEGS_TOP:] = legs
        x0 = (column + 1) * CELL_W
        out[CELL_H * 2:, x0:x0 + CELL_W] = placed
        print(f"piernas de carrera {column}: desplazadas {shift:+d} px")

    Image.fromarray(out).save(HERE / "soldier_aim_parts.png")
    print("soldier_aim_parts.png generado")


if __name__ == "__main__":
    main()
