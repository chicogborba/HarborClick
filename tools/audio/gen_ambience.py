"""Harbour ambience: four seamless 12 s stereo beds plus a thunder one-shot.

Built on the newer synth.py tools: MUSIC_SR, render_stereo/pan, coloured
noise, the biquad high-pass, detune and Schroeder reverb.

Every bed renders LOOP_S + FADE_S seconds and then crossfades the extra
FADE_S tail into the head (_seamless): the loop's last sample and its first
sample are then adjacent samples of the same render, so the wrap is click
free. The amplitude LFOs in _swell run a whole number of cycles per loop for
the same reason.
"""
import math
import random

from synth import (MUSIC_SR, render, render_stereo, add_tone, add_noise,
                   reverb, pan, save_wav)

SR = MUSIC_SR
LOOP_S = 12.0          # loop length of every bed
FADE_S = 1.5           # tail crossfaded into the head for the seamless loop


def _seamless(left, right, seconds=LOOP_S, fade=FADE_S, sr=SR):
    """Crossfade the `fade` seconds rendered after `seconds` into the head,
    then trim to `seconds`. The loop then wraps on adjacent samples."""
    n = int(seconds * sr)
    x = int(fade * sr)
    for i in range(x):
        head = i / float(x)
        tail = 1.0 - head
        left[i] = left[i] * head + left[n + i] * tail
        right[i] = right[i] * head + right[n + i] * tail
    return left[:n], right[:n]


def _swell(buf, waves, base=0.6, depth=0.4, loop_s=LOOP_S, sr=SR):
    """Slow amplitude waves over a bed. waves = [(cycles per loop, amp)]."""
    total = sum(amp for _, amp in waves) or 1.0
    for i in range(len(buf)):
        t = i / sr
        s = 0.0
        for cycles, amp in waves:
            s += amp * math.sin(math.tau * cycles * t / loop_s)
        buf[i] *= base + depth * (s / total)


def gen_sea():
    """Waves on the hull: two brown-noise layers, panned apart, swelling."""
    total = LOOP_S + FADE_S
    left, right = render_stereo(total, SR)
    for pos, gain, lp, waves in ((-0.45, 0.60, 0.0, [(1, 0.7), (3, 0.3)]),
                                 (0.45, 0.50, 0.05, [(2, 0.6), (5, 0.4)])):
        bed = render(total, SR)
        add_noise(bed, 0.0, total, gain, env=(1.5, 2.5, 0.85, 3.0),
                  color="brown", lowpass=lp, sr=SR)
        _swell(bed, waves, base=0.55, depth=0.45)
        pan(bed, left, right, position=pos)
    save_wav(_seamless(left, right), "amb_sea", normalize=0.8, sr=SR)


def gen_port():
    """Machinery hum: 55 Hz + 110 Hz, slightly detuned per side, over a faint
    pink wash."""
    total = LOOP_S + FADE_S
    left, right = render_stereo(total, SR)
    hum_env = (2.0, 3.0, 0.9, 2.5)
    for pos, det in ((-0.2, -4.0), (0.2, 5.0)):
        hum = render(total, SR)
        add_tone(hum, 0.0, total, 55.0, "sine", 0.14, env=hum_env,
                 detune=det, sr=SR)
        add_tone(hum, 0.0, total, 110.0, "sine", 0.06, env=hum_env,
                 detune=det * 1.5, sr=SR)
        pan(hum, left, right, position=pos)
    wash = render(total, SR)
    add_noise(wash, 0.0, total, 0.05, env=(2.5, 3.0, 0.9, 3.0),
              color="pink", lowpass=0.05, sr=SR)
    _swell(wash, [(2, 1.0)], base=0.75, depth=0.25)
    pan(wash, left, right, position=0.0, gain=0.8)
    save_wav(_seamless(left, right), "amb_port", normalize=0.7, sr=SR)


def gen_rain():
    """Rain on the deck: high-passed pink hiss plus sparse droplet ticks."""
    total = LOOP_S + FADE_S
    left, right = render_stereo(total, SR)
    hiss = render(total, SR)
    add_noise(hiss, 0.0, total, 0.32, env=(1.0, 2.0, 0.9, 3.0),
              color="pink", highpass=0.18, sr=SR)
    _swell(hiss, [(1, 0.5), (5, 0.5)], base=0.78, depth=0.22)
    pan(hiss, left, right, position=0.0)
    rng = random.Random(0x5EED)
    t = 0.25
    while t < total - 0.15:
        drop = render(0.06, SR)
        g = rng.uniform(0.03, 0.10)
        add_noise(drop, 0.0, 0.05, g, env=(0.001, 0.006, 0.2, 0.02),
                  color="white", highpass=0.5, sr=SR)
        add_tone(drop, 0.0, 0.035, rng.uniform(1800.0, 5200.0), "sine",
                 g * 0.5, env=(0.001, 0.008, 0.3, 0.02), sr=SR)
        pan(drop, left, right, position=rng.uniform(-0.85, 0.85))
        t += rng.uniform(0.02, 0.30)
    save_wav(_seamless(left, right), "amb_rain", normalize=0.8, sr=SR)


def gen_wind():
    """Wind along the quay: band-limited noise whose filter sweeps slowly,
    with a low moan underneath."""
    total = LOOP_S + FADE_S
    left, right = render_stereo(total, SR)
    bed = render(total, SR)
    chunks = 24
    dur = total / chunks
    for c in range(chunks):
        k = c / float(chunks)
        lp = 0.05 + 0.15 * (0.5 - 0.5 * math.cos(math.tau * k))
        add_noise(bed, c * dur, dur + 0.08, 0.34,
                  env=(0.22, 0.15, 0.85, 0.25), color="white",
                  lowpass=lp, sr=SR)
    _swell(bed, [(1, 0.6), (2, 0.4)], base=0.5, depth=0.5)
    add_tone(bed, 0.0, total, 82.0, "sine", 0.045,
             env=(3.0, 3.0, 0.7, 4.0), vibrato=0.012, sr=SR)
    pan(bed, left, right, position=0.0)
    gust = render(total, SR)
    add_noise(gust, 0.0, total, 0.20, env=(2.0, 3.0, 0.85, 3.0),
              color="pink", lowpass=0.12, sr=SR)
    _swell(gust, [(3, 1.0)], base=0.6, depth=0.4)
    pan(gust, left, right, position=-0.6, gain=0.7)
    pan(gust, left, right, position=0.6, gain=0.7)
    save_wav(_seamless(left, right), "amb_wind", normalize=0.8, sr=SR)


def gen_thunder():
    """One-shot: brown-noise rumble and a sub boom through a big reverb."""
    dur = 3.0
    buf = render(dur, SR)
    add_noise(buf, 0.0, dur, 0.85, env=(0.25, 0.6, 0.55, 1.4),
              color="brown", lowpass=0.08, sr=SR)
    add_tone(buf, 0.0, 2.4, 41.0, "sine", 0.45,
             env=(0.02, 0.5, 0.5, 1.8), sweep=0.72, sr=SR)
    add_tone(buf, 0.04, 0.14, 210.0, "saw", 0.10,
             env=(0.002, 0.03, 0.3, 0.09), sweep=0.4, lowpass=0.3, sr=SR)
    wet = reverb(buf, mix=0.45, decay=0.72, room=1.4, sr=SR)
    left, right = render_stereo(dur, SR)
    pan(wet, left, right, position=-0.25, gain=0.75)
    pan(wet, left, right, position=0.25, gain=0.75)
    save_wav((left, right), "amb_thunder", normalize=0.9, sr=SR)


if __name__ == "__main__":
    print("ambience:")
    gen_sea()
    gen_port()
    gen_rain()
    gen_wind()
    gen_thunder()
