"""Tiny chiptune synth: pure stdlib (wave/struct/math). 22050 Hz, 16-bit mono."""
import math
import os
import struct
import wave

SR = 22050
OUT_DIR = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio"))


# ---------------------------------------------------------------- oscillators
def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4.0 * abs(p - 0.5) - 1.0


def saw(phase):
    return 2.0 * (phase % 1.0) - 1.0


def sine(phase):
    return math.sin(phase * math.tau)


_noise_state = 0x7FFF


def noise(_phase=0.0):
    """1-bit LFSR noise, NES-flavoured."""
    global _noise_state
    bit = ((_noise_state >> 0) ^ (_noise_state >> 1)) & 1
    _noise_state = (_noise_state >> 1) | (bit << 14)
    return 1.0 if (_noise_state & 1) else -1.0


WAVES = {"square": square, "triangle": triangle, "saw": saw,
         "sine": sine, "noise": noise}


# ------------------------------------------------------------------ envelopes
def adsr(n, total, attack=0.01, decay=0.05, sustain=0.7, release=0.1):
    t = n / SR
    dur = total / SR
    if t < attack:
        return t / attack if attack > 0 else 1.0
    if t < attack + decay:
        k = (t - attack) / decay if decay > 0 else 1.0
        return 1.0 + (sustain - 1.0) * k
    if t < dur - release:
        return sustain
    if release <= 0:
        return 0.0
    k = (dur - t) / release
    return max(0.0, sustain * k)


def note_freq(name):
    """'A4' / 'C#5' / 'rest' -> Hz."""
    if name in (None, "rest", "-"):
        return 0.0
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
             "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    octave = int(name[-1])
    semis = names[name[:-1]]
    midi = (octave + 1) * 12 + semis
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


# ------------------------------------------------------------------ rendering
def render(length_s):
    return [0.0] * int(SR * length_s)


def add_tone(buf, start_s, dur_s, freq, wave="square", gain=0.3,
             duty=0.5, env=(0.01, 0.05, 0.7, 0.08), sweep=0.0, vibrato=0.0):
    """Mix a tone into buf. sweep = multiply freq over the note (1.0 = none)."""
    fn = WAVES[wave]
    start = int(start_s * SR)
    n_samples = int(dur_s * SR)
    phase = 0.0
    for i in range(n_samples):
        idx = start + i
        if idx >= len(buf):
            break
        f = freq
        if sweep:
            f = freq * (sweep ** (i / max(1, n_samples)))
        if vibrato:
            f *= 1.0 + math.sin(i / SR * math.tau * 6.0) * vibrato
        phase += f / SR
        amp = adsr(i, n_samples, *env) * gain
        if wave == "square":
            buf[idx] += fn(phase, duty) * amp
        else:
            buf[idx] += fn(phase) * amp


def add_noise(buf, start_s, dur_s, gain=0.25, env=(0.005, 0.05, 0.4, 0.06),
              lowpass=0.0):
    start = int(start_s * SR)
    n_samples = int(dur_s * SR)
    prev = 0.0
    for i in range(n_samples):
        idx = start + i
        if idx >= len(buf):
            break
        v = noise()
        if lowpass:
            v = prev + (v - prev) * lowpass
            prev = v
        buf[idx] += v * adsr(i, n_samples, *env) * gain


def save_wav(buf, name, normalize=0.86):
    os.makedirs(OUT_DIR, exist_ok=True)
    peak = max(1e-6, max(abs(v) for v in buf))
    scale = normalize / peak if peak > normalize else 1.0
    frames = bytearray()
    for v in buf:
        s = int(max(-1.0, min(1.0, v * scale)) * 32000)
        frames += struct.pack("<h", s)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(bytes(frames))
    print("  %s.wav  %.2fs" % (name, len(buf) / SR))
