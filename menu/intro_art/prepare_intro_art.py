"""Prepara las ilustraciones de la intro a partir de source/:

- Fondos: se escalan a 2304 px de ancho (un poco más que la pantalla, para
  poder mover y acercar la cámara) y se guardan como JPG.
- Capas (nave, enjambre, cápsula): se quita el fondo verde, se suaviza el
  borde verdoso y se recortan a su contenido. Se guardan como PNG.

Uso: python prepare_intro_art.py  (necesita Pillow y numpy)
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
SOURCE = HERE / "source"
BACKGROUND_WIDTH = 2304
BACKGROUNDS = [
    "01_orbita", "03_propaganda", "04_colonia", "06_hivelord",
    "07_cielo", "09_aterrizaje", "10_final",
]
LAYERS = {"02_nave": 1400, "05_enjambre": 1500, "08_capsula": 900}


def green_mask(rgb: np.ndarray) -> np.ndarray:
    r, g, b = (rgb[:, :, i].astype(int) for i in range(3))
    return (g > 140) & (g > r + 60) & (g > b + 60)


def despill(rgb: np.ndarray) -> np.ndarray:
    """Quita el tinte verde de los bordes: el verde no puede pasar del
    máximo entre rojo y azul."""
    out = rgb.astype(int)
    limit = np.maximum(out[:, :, 0], out[:, :, 2])
    out[:, :, 1] = np.minimum(out[:, :, 1], limit + 12)
    return out.clip(0, 255).astype(np.uint8)


def keep_ship_only(rgb: np.ndarray, alpha: np.ndarray) -> None:
    """02_nave trae espacio y un planeta pintados debajo del verde: se corta
    todo lo que queda por debajo de la última fila con verde."""
    # El borde se mide en la franja izquierda, donde no hay casco.
    green_rows = np.nonzero(green_mask(rgb)[:, :100].mean(axis=1) > 0.5)[0]
    floor = green_rows.max()
    alpha[floor + 1:] = 0
    # Abajo a la derecha asoma la punta de otra nave pintada debajo.
    height, width = alpha.shape
    alpha[floor - 45:, int(width * 0.8):] = np.where(
        green_mask(rgb)[floor - 45:, int(width * 0.8):], 0, alpha[floor - 45:, int(width * 0.8):]
    )
    alpha[floor - 25:, int(width * 0.82):] = 0


def keep_largest_component(alpha: np.ndarray) -> None:
    """Deja solo el objeto principal (quita restos sueltos y bordes de JPG)."""
    solid = alpha > 0
    labels = np.zeros(solid.shape, dtype=np.int32)
    sizes = [0]
    height, width = solid.shape
    for start_y, start_x in zip(*np.nonzero(solid)):
        if labels[start_y, start_x]:
            continue
        label = len(sizes)
        labels[start_y, start_x] = label
        stack = [(start_y, start_x)]
        count = 0
        while stack:
            y, x = stack.pop()
            count += 1
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < height and 0 <= nx < width and solid[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = label
                    stack.append((ny, nx))
        sizes.append(count)
    biggest = int(np.argmax(sizes))
    alpha[labels != biggest] = 0


def main() -> None:
    for name in BACKGROUNDS:
        image = Image.open(SOURCE / f"{name}.jpg").convert("RGB")
        height = round(image.height * BACKGROUND_WIDTH / image.width)
        image.resize((BACKGROUND_WIDTH, height), Image.LANCZOS).save(HERE / f"{name}.jpg", quality=92)
        print(name, image.size, "->", (BACKGROUND_WIDTH, height))

    for name, width in LAYERS.items():
        rgb = np.array(Image.open(SOURCE / f"{name}.jpg").convert("RGB"))
        alpha = np.where(green_mask(rgb), 0, 255).astype(np.uint8)
        if name == "02_nave":
            keep_ship_only(rgb, alpha)
        if name != "05_enjambre":
            keep_largest_component(alpha)
        # Borde suave: los píxeles que tocan el verde quedan semitransparentes.
        solid = alpha > 0
        edge = solid & ~(np.roll(solid, 1, 0) & np.roll(solid, -1, 0) & np.roll(solid, 1, 1) & np.roll(solid, -1, 1))
        alpha[edge] = 170
        image = Image.fromarray(np.dstack([despill(rgb), alpha]))
        image = image.crop(image.getbbox())
        height = round(image.height * width / image.width)
        image.resize((width, height), Image.LANCZOS).save(HERE / f"{name}.png")
        print(name, "->", (width, height))


if __name__ == "__main__":
    main()
