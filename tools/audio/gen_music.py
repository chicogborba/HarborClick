"""Six ambient loops - dawn, day, dusk, night, fog and rain - and the shop.

These play for hours, so they are written to stay out of the way: slow tempo,
long phrases that do not repeat inside a loop, soft triangle leads, and no
busy percussion. The day track is the only one with a pulse at all.
"""
from synth import render, add_tone, add_noise, save_wav, note_freq

SOFT = (0.06, 0.22, 0.55, 0.45)      # gentle attack/release for pads & leads


def beat(bpm):
    return 60.0 / bpm


def play(buf, seq, bpm, wave, gain, duty=0.5, env=SOFT, start=0.0,
         octave=0, legato=0.94):
    """seq: [(note|None, beats)]. Returns the end time."""
    t = start
    b = beat(bpm)
    for name, length in seq:
        dur = length * b
        if name is not None:
            add_tone(buf, t, dur * legato, note_freq(name) * (2.0 ** octave),
                     wave, gain, duty=duty, env=env)
        t += dur
    return t


def chords(buf, progression, bpm, gain=0.05, bars_each=2):
    """Sustained pad: each chord held for `bars_each` bars."""
    b = beat(bpm)
    t = 0.0
    for chord in progression:
        dur = bars_each * 4 * b
        for i, name in enumerate(chord):
            add_tone(buf, t + i * 0.05, dur * 0.98, note_freq(name),
                     "triangle", gain, env=(0.6, 0.5, 0.7, 1.2))
        t += dur
    return t


def gen_day():
    """Warm, open, mid-tempo. 16 bars, two distinct 8-bar phrases."""
    bpm = 76
    b = beat(bpm)
    length = 16 * 4 * b
    buf = render(length + 2.0)

    # phrase A then phrase B — no immediate repeats
    lead = [
        ("D5", 2), ("F5", 1), ("G5", 1), ("A5", 3), (None, 1),
        ("G5", 2), ("F5", 2), ("D5", 3), (None, 1),
        ("C5", 2), ("D5", 1), ("F5", 1), ("G5", 3), (None, 1),
        ("F5", 2), ("D5", 2), ("C5", 4),
        # B
        ("A4", 2), ("C5", 1), ("D5", 1), ("F5", 3), (None, 1),
        ("E5", 2), ("D5", 2), ("C5", 3), (None, 1),
        ("D5", 2), ("F5", 1), ("A5", 1), ("G5", 3), (None, 1),
        ("F5", 2), ("D5", 2), ("D5", 4),
    ]
    play(buf, lead, bpm, "triangle", 0.15)

    chords(buf, [
        ["D4", "F4", "A4"], ["C4", "E4", "G4"],
        ["B3", "D4", "G4"], ["A3", "C4", "E4"],
        ["D4", "F4", "A4"], ["A3", "C4", "E4"],
        ["G3", "B3", "D4"], ["D4", "F4", "A4"],
    ], bpm, gain=0.055)

    bass = []
    for root in ["D2", "C2", "G2", "A2", "D2", "A2", "G2", "D2"]:
        bass += [(root, 4), (None, 1), (root, 3)]
    play(buf, bass, bpm, "triangle", 0.13, env=(0.05, 0.3, 0.6, 0.5))

    # a soft heartbeat, once per bar — enough pulse, no drum kit
    for bar in range(16):
        add_tone(buf, bar * 4 * b, 0.16, 72, "triangle", 0.075,
                 env=(0.004, 0.09, 0.15, 0.06), sweep=0.5)
    save_wav(buf, "music_day", normalize=0.55)


def gen_night():
    """Slow, minor, mostly pad. 16 bars."""
    bpm = 56
    b = beat(bpm)
    length = 16 * 4 * b
    buf = render(length + 3.0)

    lead = [
        ("A4", 4), ("C5", 3), (None, 1),
        ("B4", 4), ("A4", 4),
        ("G4", 3), (None, 1), ("E4", 4),
        ("A4", 6), (None, 2),
        ("C5", 4), ("B4", 3), (None, 1),
        ("A4", 4), ("G4", 4),
        ("E4", 3), (None, 1), ("D4", 4),
        ("A4", 8),
    ]
    play(buf, lead, bpm, "triangle", 0.13, env=(0.15, 0.35, 0.55, 0.9))

    chords(buf, [
        ["A3", "C4", "E4"], ["F3", "A3", "C4"],
        ["C4", "E4", "G4"], ["G3", "B3", "D4"],
        ["A3", "C4", "E4"], ["D4", "F4", "A4"],
        ["E3", "G3", "B3"], ["A3", "C4", "E4"],
    ], bpm, gain=0.05)

    bass = []
    for root in ["A2", "F2", "C3", "G2", "A2", "D3", "E3", "A2"]:
        bass += [(root, 8)]
    play(buf, bass, bpm, "triangle", 0.12, env=(0.25, 0.5, 0.7, 1.0))
    save_wav(buf, "music_night", normalize=0.48)


def gen_fog():
    """Almost no melody — a wash with the odd distant note. 16 bars."""
    bpm = 48
    b = beat(bpm)
    length = 16 * 4 * b
    buf = render(length + 4.0)

    lead = [
        (None, 4), ("D4", 4),
        (None, 2), ("F4", 6),
        (None, 8),
        ("A4", 5), (None, 3),
        (None, 4), ("C4", 4),
        ("D4", 6), (None, 2),
        (None, 8),
        ("D4", 8),
    ]
    play(buf, lead, bpm, "triangle", 0.12, env=(0.4, 0.6, 0.5, 1.6))

    chords(buf, [
        ["D3", "A3", "D4"], ["D3", "A3", "C4"],
        ["F3", "C4", "F4"], ["C3", "G3", "C4"],
        ["D3", "A3", "D4"], ["A2", "E3", "A3"],
        ["F3", "C4", "F4"], ["D3", "A3", "D4"],
    ], bpm, gain=0.05, bars_each=2)

    # far-off horns, twice in the loop
    for bar in (3, 11):
        add_tone(buf, bar * 4 * b, 3.0, 58, "triangle", 0.085,
                 env=(0.8, 0.6, 0.6, 1.4), vibrato=0.003)

    add_noise(buf, 0.0, length, 0.022, env=(2.5, 3.0, 0.9, 3.0), lowpass=0.04)
    save_wav(buf, "music_fog", normalize=0.42)


def gen_dusk():
    """Warm and settling: major turning to minor, sun going down. 16 bars."""
    bpm = 66
    b = beat(bpm)
    length = 16 * 4 * b
    buf = render(length + 3.0)

    lead = [
        ("G4", 3), ("E4", 1), ("D4", 4),
        ("C4", 3), ("D4", 1), ("E4", 4),
        ("F4", 3), ("E4", 1), ("D4", 4),
        ("C4", 2), ("B3", 2), ("A3", 4),
        # B — lower, duskier
        ("A3", 4), ("C4", 2), ("D4", 2),
        ("E4", 4), ("D4", 4),
        ("C4", 3), ("A3", 1), ("G3", 4),
        ("A3", 8),
    ]
    play(buf, lead, bpm, "triangle", 0.14, env=(0.1, 0.3, 0.5, 0.8))

    chords(buf, [
        ["G3", "B3", "D4"], ["C3", "E3", "G3"],
        ["A2", "C3", "E3"], ["D3", "F3", "A3"],
        ["G3", "B3", "D4"], ["E3", "G3", "B3"],
        ["A2", "C3", "E3"], ["D3", "F3", "A3"],
    ], bpm, gain=0.05)

    bass = []
    for root in ["G2", "C2", "A2", "D2", "G2", "E2", "A2", "D2"]:
        bass += [(root, 4), (None, 1), (root, 3)]
    play(buf, bass, bpm, "triangle", 0.12, env=(0.05, 0.3, 0.6, 0.5))
    save_wav(buf, "music_dusk", normalize=0.5)


def gen_dawn():
    """Cool rising, minor to major — the port waking up. 16 bars."""
    bpm = 72
    b = beat(bpm)
    length = 16 * 4 * b
    buf = render(length + 3.0)

    lead = [
        ("E4", 4), ("G4", 2), ("A4", 2),
        ("B4", 4), ("A4", 4),
        ("G4", 3), ("E4", 1), ("D4", 4),
        ("E4", 8),
        # B — opens out
        ("C4", 4), ("E4", 2), ("G4", 2),
        ("A4", 4), ("G4", 4),
        ("F4", 3), ("E4", 1), ("D4", 4),
        ("C4", 8),
    ]
    play(buf, lead, bpm, "triangle", 0.13, env=(0.12, 0.3, 0.5, 0.9))

    chords(buf, [
        ["A2", "C3", "E3"], ["F2", "A2", "C3"],
        ["C3", "E3", "G3"], ["G2", "B2", "D3"],
        ["A2", "C3", "E3"], ["D3", "F3", "A3"],
        ["C3", "E3", "G3"], ["C3", "E3", "G3"],
    ], bpm, gain=0.045)

    bass = []
    for root in ["A1", "F1", "C2", "G1", "A1", "D2", "C2", "C2"]:
        bass += [(root, 8)]
    play(buf, bass, bpm, "triangle", 0.11, env=(0.2, 0.4, 0.6, 0.9))
    save_wav(buf, "music_dawn", normalize=0.48)


def gen_rain():
    """Rain cousin of the fog loop: sparse notes over a noise wash."""
    bpm = 52
    b = beat(bpm)
    length = 16 * 4 * b
    buf = render(length + 4.0)

    lead = [
        (None, 4), ("E4", 4),
        (None, 2), ("D4", 6),
        (None, 8),
        ("C4", 5), (None, 3),
        (None, 4), ("G3", 4),
        ("A3", 6), (None, 2),
        (None, 8),
        ("E4", 8),
    ]
    play(buf, lead, bpm, "triangle", 0.11, env=(0.4, 0.6, 0.5, 1.6))

    chords(buf, [
        ["A2", "C3", "E3"], ["G2", "B2", "D3"],
        ["F2", "A2", "C3"], ["E2", "G2", "B2"],
        ["A2", "C3", "E3"], ["F2", "A2", "C3"],
        ["C3", "E3", "G3"], ["A2", "C3", "E3"],
    ], bpm, gain=0.045, bars_each=2)

    # rain bed: coloured noise, steady
    add_noise(buf, 0.0, length, 0.030, env=(2.0, 2.5, 0.8, 2.5), lowpass=0.06)
    save_wav(buf, "music_rain", normalize=0.4)



def gen_shop():
    """The shop: same D tonal centre as the day loop, so the crossfade in and
    out lands on shared harmony instead of a key change. Lighter and a touch
    playful - a bossa comp on the off-beats, a walking bass, brushed hats -
    because this is the board where the money gets spent. 16 bars at 92."""
    bpm = 92
    b = beat(bpm)
    length = 16 * 4 * b
    buf = render(length + 2.0)
    prog = [["D4", "F4", "A4", "C5"], ["G3", "B3", "D4", "F4"],
            ["C4", "E4", "G4", "B4"], ["A3", "C4", "E4", "G4"]]
    roots = ["D2", "G2", "C2", "A2"]
    walks = [["D2", "F2", "A2", "C3"], ["G2", "B2", "D3", "F2"],
             ["C2", "E2", "G2", "B2"], ["A2", "G2", "F2", "E2"]]
    for bar in range(16):
        t0 = bar * 4 * b
        chord = prog[bar % 4]
        # bossa comp: short plucks on the "and"s
        for hit in (0.5, 1.5, 2.0, 3.0, 3.5):
            for i, name in enumerate(chord):
                add_tone(buf, t0 + hit * b + i * 0.008, 0.18, note_freq(name),
                         "square", 0.022, duty=0.25, env=(0.004, 0.08, 0.3, 0.08))
        # walking bass, one note a beat
        for i, name in enumerate(walks[bar % 4]):
            add_tone(buf, t0 + i * b, b * 0.85, note_freq(name), "triangle", 0.12,
                     env=(0.01, 0.12, 0.5, 0.12))
        # brushed hats on every eighth, accent on 2 and 4
        for e in range(8):
            gain = 0.03 if e in (2, 6) else 0.016
            add_noise(buf, t0 + e * 0.5 * b, 0.05, gain,
                      env=(0.002, 0.03, 0.1, 0.02))
    # a lead that answers itself: two 8-bar phrases, triangle, sparse
    lead = [
        (None, 2), ("A4", 1), ("C5", 1), ("D5", 2), ("F5", 2),
        ("E5", 1), ("D5", 1), ("C5", 2), (None, 4),
        (None, 2), ("G4", 1), ("B4", 1), ("D5", 2), ("E5", 2),
        ("C5", 3), (None, 5),
        (None, 2), ("F5", 1), ("E5", 1), ("D5", 2), ("C5", 2),
        ("A4", 2), ("C5", 2), ("D5", 4),
        (None, 2), ("E5", 1), ("F5", 1), ("G5", 2), ("E5", 2),
        ("D5", 6), (None, 2),
    ]
    play(buf, lead, bpm, "triangle", 0.11)
    save_wav(buf, "music_shop", normalize=0.5)

if __name__ == "__main__":
    print("music:")
    gen_day()
    gen_night()
    gen_fog()
    gen_dusk()
    gen_dawn()
    gen_rain()
    gen_shop()
