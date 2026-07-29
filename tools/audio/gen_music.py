"""Three ambient loops: day, night and fog.

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


if __name__ == "__main__":
    print("music:")
    gen_day()
    gen_night()
    gen_fog()
