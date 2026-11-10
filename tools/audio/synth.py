"""Tiny chiptune synth: pure stdlib (wave/struct/math). 22050 Hz, 16-bit mono.

Effects & stereo toolbox (all optional — with the defaults below every
existing call produces exactly the same 22050 Hz mono bytes as before):

- MUSIC_SR: 44100 Hz rate for music/ambience renders. render(), add_tone(),
  add_noise() and save_wav() all take an sr=... (default SR).
- add_tone(..., lowpass=f, detune=c): per-tone 2-pole resonant low-pass
  (cutoff f as a fraction of Nyquist, 0..1) and/or a second oscillator
  detuned by c cents at half gain, applied before mixing.
- add_noise(..., color='white'|'pink'|'brown', highpass=f): coloured noise
  ('white' is the original LFSR) plus an optional 2-pole high-pass.
- reverb(buf, mix, decay, room): Schroeder tank (4 parallel feedback combs +
  2 series allpasses); returns a new buffer the same length as buf.
- delay(buf, seconds, feedback, mix): feedback echo; same length as buf.
- render_stereo(seconds, sr) -> (left, right); pan(mono, left, right,
  position, gain): equal-power panning of a mono buffer into a stereo pair.
- save_wav(buf, name, normalize, sr): buf is a mono list or a (left, right)
  tuple; writes 16-bit PCM with 1 or 2 channels.
"""
import math
import os
import struct
import wave

SR = 22050
MUSIC_SR = 44100          # rate for music/ambience renders (pass sr=MUSIC_SR)
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
def adsr(n, total, attack=0.01, decay=0.05, sustain=0.7, release=0.1, sr=SR):
    t = n / sr
    dur = total / sr
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
def render(length_s, sr=SR):
    return [0.0] * int(sr * length_s)


def add_tone(buf, start_s, dur_s, freq, wave="square", gain=0.3,
             duty=0.5, env=(0.01, 0.05, 0.7, 0.08), sweep=0.0, vibrato=0.0,
             lowpass=None, detune=0.0, sr=SR):
    """Mix a tone into buf. sweep = multiply freq over the note (1.0 = none).

    lowpass: 2-pole resonant low-pass on this tone, cutoff as a fraction of
    Nyquist (0..1, None = off). detune: add a second oscillator detuned by
    that many cents at half gain.
    """
    fn = WAVES[wave]
    start = int(start_s * sr)
    n_samples = int(dur_s * sr)
    phase = 0.0
    phase2 = 0.0
    detune_ratio = 2.0 ** (detune / 1200.0) if detune else 1.0
    lp = _biquad("lp", lowpass, sr, q=1.0) if lowpass is not None else None
    for i in range(n_samples):
        idx = start + i
        if idx >= len(buf):
            break
        f = freq
        if sweep:
            f = freq * (sweep ** (i / max(1, n_samples)))
        if vibrato:
            f *= 1.0 + math.sin(i / sr * math.tau * 6.0) * vibrato
        phase += f / sr
        if wave == "square":
            s = fn(phase, duty)
        else:
            s = fn(phase)
        if detune:
            phase2 += f * detune_ratio / sr
            s += (fn(phase2, duty) if wave == "square" else fn(phase2)) * 0.5
        if lp is not None:
            s = _biquad_apply(s, lp)
        amp = adsr(i, n_samples, *env, sr=sr) * gain
        buf[idx] += s * amp


def add_noise(buf, start_s, dur_s, gain=0.25, env=(0.005, 0.05, 0.4, 0.06),
              lowpass=0.0, color="white", highpass=None, sr=SR):
    """Mix noise into buf.

    color: 'white' (the original LFSR), 'pink' or 'brown'. lowpass: one-pole
    coefficient as before (0 = off). highpass: 2-pole high-pass cutoff as a
    fraction of Nyquist (None = off).
    """
    start = int(start_s * sr)
    n_samples = int(dur_s * sr)
    prev = 0.0
    pink = [0.0] * 7
    brown = 0.0
    hp = _biquad("hp", highpass, sr, q=0.7071) if highpass is not None else None
    for i in range(n_samples):
        idx = start + i
        if idx >= len(buf):
            break
        if color == "white":
            v = noise()
        elif color == "pink":
            w = noise()
            pink[0] = 0.99886 * pink[0] + w * 0.0555179
            pink[1] = 0.99332 * pink[1] + w * 0.0750759
            pink[2] = 0.96900 * pink[2] + w * 0.1538520
            pink[3] = 0.86650 * pink[3] + w * 0.3104856
            pink[4] = 0.55000 * pink[4] + w * 0.5329522
            pink[5] = -0.7616 * pink[5] - w * 0.0168980
            v = (pink[0] + pink[1] + pink[2] + pink[3] + pink[4] +
                 pink[5] + pink[6] + w * 0.5362) * 0.11
            pink[6] = w * 0.115926
        elif color == "brown":
            w = noise()
            brown = (brown + 0.02 * w) / 1.02
            v = brown * 3.5
        else:
            raise ValueError("color must be 'white', 'pink' or 'brown'")
        if lowpass:
            v = prev + (v - prev) * lowpass
            prev = v
        if hp is not None:
            v = _biquad_apply(v, hp)
        buf[idx] += v * adsr(i, n_samples, *env, sr=sr) * gain


# ------------------------------------------------------------- biquad filters
def _biquad(kind, cutoff, sr, q=0.7071):
    """RBJ biquad coefficients + zeroed state. cutoff = fraction of Nyquist."""
    c = max(1e-4, min(1.0, cutoff))
    w0 = math.pi * c                     # fc = c * sr/2  ->  w0 = pi * c
    cosw0 = math.cos(w0)
    alpha = math.sin(w0) / (2.0 * q)
    a0 = 1.0 + alpha
    if kind == "lp":
        b0 = (1.0 - cosw0) / 2.0
        b1 = 1.0 - cosw0
    else:                                # high-pass
        b0 = (1.0 + cosw0) / 2.0
        b1 = -(1.0 + cosw0)
    b2 = b0
    a1 = -2.0 * cosw0
    a2 = 1.0 - alpha
    return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0,
            0.0, 0.0, 0.0, 0.0]          # coeffs + x1, x2, y1, y2


def _biquad_apply(x, st):
    y = (st[0] * x + st[1] * st[5] + st[2] * st[6]
         - st[3] * st[7] - st[4] * st[8])
    st[6] = st[5]
    st[5] = x
    st[8] = st[7]
    st[7] = y
    return y


# -------------------------------------------------------- effects and stereo
def _comb(x, d, g):
    """Feedback comb: y[i] = x[i] + g * y[i-d]."""
    n = len(x)
    out = [0.0] * n
    line = [0.0] * d
    j = 0
    for i in range(n):
        y = x[i] + g * line[j]
        line[j] = y
        out[i] = y
        j += 1
        if j >= d:
            j = 0
    return out


def _allpass(x, d, g):
    """Schroeder allpass: y[i] = -g*x[i] + x[i-d] + g*y[i-d]."""
    n = len(x)
    out = [0.0] * n
    din = [0.0] * d
    dout = [0.0] * d
    j = 0
    for i in range(n):
        y = -g * x[i] + din[j] + g * dout[j]
        din[j] = x[i]
        dout[j] = y
        out[i] = y
        j += 1
        if j >= d:
            j = 0
    return out


def reverb(buf, mix=0.2, decay=0.5, room=1.0, sr=SR):
    """Schroeder reverb: 4 parallel feedback combs into 2 series allpasses.

    Returns a new buffer the same length as buf. mix = wet level, decay =
    comb feedback (0..1), room = tank size (scales the delay lines).
    """
    n = len(buf)
    scale = sr / 44100.0 * room
    g = min(0.9, max(0.0, decay))
    wet = [0.0] * n
    for base in (1116, 1188, 1277, 1356):
        comb = _comb(buf, max(1, int(base * scale)), g)
        for i in range(n):
            wet[i] += comb[i] * 0.25
    wet = _allpass(wet, max(1, int(556 * scale)), 0.5)
    wet = _allpass(wet, max(1, int(441 * scale)), 0.5)
    dry = 1.0 - mix
    return [buf[i] * dry + wet[i] * mix for i in range(n)]


def delay(buf, seconds, feedback=0.35, mix=0.25, sr=SR):
    """Feedback echo: y[i] = x[i] + feedback*y[i-d], blended by mix.

    Returns a new buffer the same length as buf.
    """
    n = len(buf)
    d = max(1, int(seconds * sr))
    out = [0.0] * n
    line = [0.0] * d
    j = 0
    dry = 1.0 - mix
    for i in range(n):
        y = buf[i] + feedback * line[j]
        line[j] = y
        out[i] = buf[i] * dry + y * mix
        j += 1
        if j >= d:
            j = 0
    return out


def render_stereo(seconds, sr=SR):
    """(left, right) zero buffers of `seconds` at rate sr."""
    n = int(sr * seconds)
    return [0.0] * n, [0.0] * n


def pan(buf, left, right, position=0.0, gain=1.0):
    """Mix a mono buffer into a stereo pair with equal-power panning.

    position: -1 = hard left, 0 = centre, +1 = hard right.
    """
    pos = max(-1.0, min(1.0, position))
    angle = (pos + 1.0) * 0.25 * math.pi
    l = math.cos(angle) * gain
    r = math.sin(angle) * gain
    n = min(len(buf), len(left), len(right))
    for i in range(n):
        v = buf[i]
        left[i] += v * l
        right[i] += v * r
    return left, right


# ------------------------------------------------------------------- output
def save_wav(buf, name, normalize=0.86, sr=SR):
    """Write 16-bit PCM. buf is a mono list or a (left, right) tuple."""
    os.makedirs(OUT_DIR, exist_ok=True)
    stereo = isinstance(buf, tuple) and len(buf) == 2
    chans = [buf[0], buf[1]] if stereo else [buf]
    peak = max(1e-6, max(abs(v) for c in chans for v in c))
    scale = normalize / peak if peak > normalize else 1.0
    frames = bytearray()
    if stereo:
        for l, r in zip(chans[0], chans[1]):
            frames += struct.pack("<h", int(max(-1.0, min(1.0, l * scale)) * 32000))
            frames += struct.pack("<h", int(max(-1.0, min(1.0, r * scale)) * 32000))
    else:
        for v in chans[0]:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32000))
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(2 if stereo else 1)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes(bytes(frames))
    print("  %s.wav  %.2fs" % (name, len(chans[0]) / sr))
