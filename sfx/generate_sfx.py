"""Genera los efectos de sonido sintéticos del juego (WAV mono, 44.1 kHz).

- explosion.wav: golpe grave y ruido que se apaga (granada).
- ui_click.wav: clic corto al pulsar un botón.
- ui_hover.wav: tic suave al pasar el ratón o el foco por un botón.
- pickup.wav: campanita de dos notas al recoger un fragmento.

Uso: python generate_sfx.py  (necesita numpy)
"""
import wave
from pathlib import Path

import numpy as np

RATE = 44100
HERE = Path(__file__).parent
rng = np.random.default_rng(7)


def timeline(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def lowpass(signal: np.ndarray, strength: float) -> np.ndarray:
    """Filtro de un polo: strength cerca de 1 = más grave."""
    out = np.empty_like(signal)
    value = 0.0
    for index, sample in enumerate(signal):
        value = value * strength + sample * (1.0 - strength)
        out[index] = value
    return out


def save(name: str, signal: np.ndarray, peak: float = 0.9) -> None:
    signal = signal / max(1e-9, np.abs(signal).max()) * peak
    # Rampa corta al final para evitar chasquidos.
    fade = min(len(signal), int(RATE * 0.01))
    signal[-fade:] *= np.linspace(1.0, 0.0, fade)
    data = (signal * 32767).astype(np.int16)
    with wave.open(str(HERE / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(data.tobytes())
    print(name, f"{len(signal) / RATE:.2f} s")


def explosion() -> np.ndarray:
    t = timeline(0.9)
    noise = lowpass(rng.uniform(-1, 1, len(t)), 0.85) * np.exp(-t * 5.0)
    crackle = rng.uniform(-1, 1, len(t)) * np.exp(-t * 22.0) * 0.5
    frequency = 90.0 * np.exp(-t * 3.0) + 35.0
    thump = np.sin(2 * np.pi * np.cumsum(frequency) / RATE) * np.exp(-t * 6.0) * 1.4
    return noise + crackle + thump


def ui_click() -> np.ndarray:
    t = timeline(0.07)
    frequency = 1400.0 - 600.0 * t / t[-1]
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(frequency) / RATE)) * 0.4
    tone += np.sin(2 * np.pi * np.cumsum(frequency) / RATE)
    return lowpass(tone, 0.3) * np.exp(-t * 55.0)


def ui_hover() -> np.ndarray:
    t = timeline(0.05)
    return np.sin(2 * np.pi * 2200.0 * t) * np.exp(-t * 90.0)


def pickup() -> np.ndarray:
    t = timeline(0.22)
    first = np.where(t < 0.07, 1.0, 0.0)
    frequency = np.where(first > 0, 1046.5, 1568.0)
    phase = 2 * np.pi * np.cumsum(frequency) / RATE
    tone = np.sin(phase) + 0.3 * np.sin(phase * 2)
    envelope = np.where(first > 0, np.exp(-t * 30.0), np.exp(-(t - 0.07) * 18.0))
    return tone * envelope


if __name__ == "__main__":
    save("explosion.wav", explosion())
    save("ui_click.wav", ui_click(), 0.6)
    save("ui_hover.wav", ui_hover(), 0.35)
    save("pickup.wav", pickup(), 0.55)
