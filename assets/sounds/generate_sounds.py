"""Generates short, subtle local feedback sounds for quiz answers (correct/incorrect).

Run once with `python generate_sounds.py` to (re)create the .wav assets.
No external dependencies are required (stdlib `wave` + `struct` only), so the
sounds stay fully offline and reproducible.
"""

import math
import struct
import wave

SAMPLE_RATE = 44100


def _tone(freq, duration, amplitude=0.28, fade=0.015):
    n_samples = int(SAMPLE_RATE * duration)
    fade_samples = max(1, int(SAMPLE_RATE * fade))
    samples = []

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        value = math.sin(2 * math.pi * freq * t)

        # Gentle linear fade in/out to avoid clicks and keep the sound soft.
        if i < fade_samples:
            value *= i / fade_samples
        elif i > n_samples - fade_samples:
            value *= (n_samples - i) / fade_samples

        samples.append(value * amplitude)

    return samples


def _mix(*layers):
    length = max(len(layer) for layer in layers)
    result = [0.0] * length

    for layer in layers:
        for i, value in enumerate(layer):
            result[i] += value

    return result


def _write_wav(path, samples):
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)

        frames = b"".join(
            struct.pack("<h", max(-32768, min(32767, int(s * 32767))))
            for s in samples
        )

        f.writeframes(frames)


def make_correct():
    # Kurzer, freundlicher Zweiklang aufwärts (dezent, ca. 220ms).
    note1 = _tone(880.0, 0.10, amplitude=0.24)
    note2 = _tone(1318.5, 0.14, amplitude=0.24)
    return note1 + note2


def make_incorrect():
    # Kurzer, dezenter Ton abwärts (kein grelles Fehler-Signal).
    note1 = _tone(392.0, 0.09, amplitude=0.22)
    note2 = _tone(311.1, 0.13, amplitude=0.20)
    return note1 + note2


if __name__ == "__main__":
    _write_wav("correct.wav", make_correct())
    _write_wav("incorrect.wav", make_incorrect())
    print("Generated correct.wav and incorrect.wav")
