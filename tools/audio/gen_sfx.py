"""All HarborClick sound effects, generated from code."""
from synth import render, add_tone, add_noise, save_wav, note_freq, reverb, delay


## The UI blip fires more than anything else in the game, so it gets takes too.
TAP_TAKES = (880, 828, 932)


def sfx_tap():
    """UI tap: short blip, in three takes."""
    for index, freq in enumerate([TAP_TAKES[0]] + list(TAP_TAKES)):
        buf = render(0.09)
        add_tone(buf, 0.0, 0.07, freq, "square", 0.24, duty=0.25,
                 env=(0.002, 0.02, 0.4, 0.04))
        save_wav(buf, "tap" if index == 0 else "tap_%d" % index)


def _thunk(name, body, skin, sweep, grit, lowpass, ring=None):
    """One take of a container landing: body tone, skin tone, dust, optional ring.

    `body` is the low mass of the box, `skin` the corrugated steel it lands on,
    `grit` the dust that comes off the stack. A ring is the twist-lock catching.
    """
    buf = render(0.32)
    add_tone(buf, 0.0, 0.10, skin, "square", 0.32, duty=0.5,
             env=(0.001, 0.05, 0.3, 0.05), sweep=sweep)
    add_tone(buf, 0.0, 0.16, body, "triangle", 0.34,
             env=(0.001, 0.08, 0.35, 0.08), sweep=0.7)
    add_noise(buf, 0.0, 0.13, grit, env=(0.001, 0.05, 0.2, 0.07),
              lowpass=lowpass)
    if ring:
        add_tone(buf, 0.05, 0.13, ring, "triangle", 0.09,
                 env=(0.004, 0.05, 0.3, 0.07), sweep=0.9)
    save_wav(buf, name)


## Six takes of one event. A box coming off a hull never lands the same way
## twice — a different corner touches first, the stack under it is a different
## height, the spreader lets go a fraction earlier. Under automation this fires
## several times a second, and a single sample at that rate reads as a stuck
## buffer rather than as a working port. `AudioManager` draws these from a
## shuffle bag and layers its own pitch ladder on top.
THUNK_TAKES = [
    # body, skin, sweep, grit, lowpass, ring
    (92, 180, 0.55, 0.16, 0.25, None),
    (86, 168, 0.60, 0.19, 0.22, 640),
    (99, 196, 0.50, 0.13, 0.30, None),
    (81, 158, 0.66, 0.21, 0.20, 540),
    (105, 210, 0.47, 0.12, 0.34, 720),
    (95, 174, 0.58, 0.17, 0.27, 470),
]

## The spreader taking hold of a box on the deck. Fewer takes than the landing:
## it is a quieter, shorter sound and the player hears it under their own
## finger, so it needs variety without becoming a texture of its own.
CLICK_TAKES = [
    # pick freq, sweep, grit
    (520, 1.60, 0.10),
    (486, 1.72, 0.12),
    (556, 1.48, 0.09),
    (505, 1.66, 0.11),
]


def sfx_thunk():
    """Container landing on the stack: metallic clunk + dust, in six takes."""
    # The unnumbered file stays: it is the fallback when a family has not been
    # regenerated yet, and `AudioManager` falls back to it by name.
    _thunk("thunk", *THUNK_TAKES[0])
    for index, take in enumerate(THUNK_TAKES):
        _thunk("thunk_%d" % (index + 1), *take)


def sfx_splash():
    """Somebody hitting the harbour: a slap, then the water closing over it.

    Two noise bursts and a falling tone. The first burst is bright and brief —
    the surface breaking — and the second is long, low-passed and quieter, which
    is the part that reads as *water* rather than as a box being dropped. The
    tone sweeps down because the cavity a body opens closes as it fills.
    """
    buf = render(0.75)
    add_noise(buf, 0.0, 0.09, 0.42, env=(0.001, 0.03, 0.25, 0.05), lowpass=0.85)
    add_tone(buf, 0.0, 0.22, 300, "sine", 0.20, env=(0.002, 0.06, 0.3, 0.12),
             sweep=0.45)
    add_noise(buf, 0.04, 0.52, 0.24, env=(0.03, 0.14, 0.35, 0.3), lowpass=0.32)
    # The last of it slopping back, a beat later.
    add_noise(buf, 0.30, 0.32, 0.12, env=(0.08, 0.12, 0.3, 0.2), lowpass=0.2)
    save_wav(buf, "splash")


def _click(name, freq, sweep, grit):
    buf = render(0.16)
    add_tone(buf, 0.0, 0.08, freq, "square", 0.26, duty=0.35,
             env=(0.001, 0.03, 0.4, 0.04), sweep=sweep)
    add_noise(buf, 0.0, 0.05, grit, env=(0.001, 0.02, 0.2, 0.03), lowpass=0.4)
    save_wav(buf, name)


def sfx_click():
    """Tapping the ship: crisp pick-up, in four takes."""
    _click("click", *CLICK_TAKES[0])
    for index, take in enumerate(CLICK_TAKES):
        _click("click_%d" % (index + 1), *take)


def sfx_buy():
    """Structure purchase: bright two-note ka-ching."""
    buf = render(0.42)
    add_tone(buf, 0.00, 0.12, note_freq("E5"), "square", 0.26, duty=0.25)
    add_tone(buf, 0.09, 0.22, note_freq("B5"), "square", 0.24, duty=0.25)
    add_tone(buf, 0.09, 0.22, note_freq("E6"), "triangle", 0.16)
    save_wav(buf, "buy")


def sfx_upgrade():
    """Upgrade: rising four-note fanfare."""
    buf = render(0.62)
    for i, name in enumerate(["C5", "E5", "G5", "C6"]):
        add_tone(buf, i * 0.075, 0.26, note_freq(name), "square", 0.22, duty=0.4,
                 env=(0.005, 0.05, 0.6, 0.14))
    add_tone(buf, 0.30, 0.30, note_freq("C4"), "triangle", 0.18)
    save_wav(buf, "upgrade")


def sfx_deny():
    """Not enough TEUs: low buzz."""
    buf = render(0.22)
    add_tone(buf, 0.0, 0.09, 150, "square", 0.22, duty=0.5,
             env=(0.002, 0.03, 0.6, 0.04))
    add_tone(buf, 0.10, 0.10, 112, "square", 0.22, duty=0.5,
             env=(0.002, 0.03, 0.6, 0.05))
    save_wav(buf, "deny")


def sfx_build():
    """Land purchase / construction: hammering + rising tone."""
    buf = render(0.85)
    for i in range(4):
        add_noise(buf, i * 0.13, 0.09, 0.30, env=(0.001, 0.04, 0.2, 0.04),
                  lowpass=0.35)
        add_tone(buf, i * 0.13, 0.07, 240 + i * 30, "square", 0.16, duty=0.5,
                 env=(0.001, 0.03, 0.3, 0.03), sweep=0.7)
    for i, name in enumerate(["G4", "C5", "E5"]):
        add_tone(buf, 0.52 + i * 0.08, 0.26, note_freq(name), "square", 0.20,
                 duty=0.3, env=(0.005, 0.05, 0.6, 0.12))
    save_wav(buf, "build")


## Four ships, four horns. Every vessel sounding identical is the one thing a
## port never does, and this plays on every arrival and every departure.
HORN_TAKES = [
    # low, mid, upper, vibrato
    (78, 104, 156, 0.006),
    (71, 95, 142, 0.005),
    (86, 115, 172, 0.007),
    (66, 88, 132, 0.004),
]


def _horn(name, low, mid, upper, vibrato):
    buf = render(1.5)
    add_tone(buf, 0.0, 1.35, mid, "square", 0.30, duty=0.5,
             env=(0.09, 0.15, 0.85, 0.35), vibrato=vibrato)
    add_tone(buf, 0.0, 1.35, low, "triangle", 0.34,
             env=(0.09, 0.15, 0.85, 0.35), vibrato=vibrato * 0.85)
    add_tone(buf, 0.0, 1.35, upper, "square", 0.10, duty=0.3,
             env=(0.12, 0.2, 0.6, 0.4))
    save_wav(buf, name)


def sfx_horn():
    """Ship horn on arrival/departure: deep, warbling, in four takes."""
    _horn("horn", *HORN_TAKES[0])
    for index, take in enumerate(HORN_TAKES):
        _horn("horn_%d" % (index + 1), *take)


def sfx_foghorn():
    """Foghorn: lower and longer than the ship horn."""
    buf = render(2.2)
    add_tone(buf, 0.0, 2.0, 62, "triangle", 0.40,
             env=(0.25, 0.3, 0.85, 0.7), vibrato=0.004)
    add_tone(buf, 0.0, 2.0, 93, "square", 0.14, duty=0.5,
             env=(0.3, 0.3, 0.7, 0.8))
    save_wav(buf, "foghorn")


def sfx_gull():
    """Seagull cry: two chirps with a downward sweep."""
    buf = render(0.5)
    add_tone(buf, 0.00, 0.14, 1500, "square", 0.14, duty=0.2,
             env=(0.01, 0.04, 0.5, 0.06), sweep=0.55)
    add_tone(buf, 0.20, 0.18, 1350, "square", 0.13, duty=0.2,
             env=(0.01, 0.05, 0.5, 0.08), sweep=0.5)
    save_wav(buf, "gull")


def sfx_meow():
    """Port cat."""
    buf = render(0.5)
    add_tone(buf, 0.0, 0.42, 620, "saw", 0.16,
             env=(0.05, 0.1, 0.7, 0.18), sweep=0.62, vibrato=0.03)
    save_wav(buf, "meow")


def sfx_train_horn():
    """Branch-line horn: a two-tone chime, twice, the way a loco sounds up.

    Deliberately nothing like `horn`. A ship's horn is one deep warbling note
    that says a hull is moving; a locomotive sounds a *chord* — two reeds a
    fourth apart, blown together, in short bursts. That interval is the whole
    identification: the player hears which of the three doors just opened
    without looking at the bottom of the map, which is the only place the
    branch is visible from.
    """
    buf = render(1.5)
    for start, dur in ((0.00, 0.34), (0.42, 0.62)):
        for freq, gain in ((311, 0.30), (415, 0.26), (622, 0.10)):
            add_tone(buf, start, dur, freq, "triangle", gain,
                     env=(0.02, 0.08, 0.82, 0.16), vibrato=0.006)
        # The reed edge. Pure triangles are a church organ, not an air horn.
        add_tone(buf, start, dur, 311, "square", 0.05, duty=0.35,
                 env=(0.03, 0.1, 0.7, 0.2))
    save_wav(buf, "train_horn")


def sfx_rail_brake():
    """Cast-iron brake blocks on steel tyres: a squeal that falls away.

    A loaded rake stops over a couple of hundred metres, and the sound of it is
    high, thin and *descending* — the pitch tracks the wheel it is coming off.
    Sweeping down is what makes it read as the train stopping rather than as a
    machine starting up."""
    buf = render(1.1)
    add_tone(buf, 0.0, 0.85, 2400, "saw", 0.10, env=(0.12, 0.2, 0.6, 0.3),
             sweep=0.42, vibrato=0.02)
    add_tone(buf, 0.05, 0.75, 3100, "triangle", 0.06,
             env=(0.15, 0.2, 0.5, 0.3), sweep=0.38)
    # The rolling stock under it: the low rumble that stops when the squeal does.
    add_noise(buf, 0.0, 0.9, 0.10, env=(0.05, 0.2, 0.5, 0.4), lowpass=0.10)
    save_wav(buf, "rail_brake")


def sfx_coupling():
    """Buffers meeting and the drawgear taking up: clank, then the slack run.

    One hit is a hammer. What says *coupling* is the second, quieter knock a
    moment later as the shock runs back down the rake and the couplings pull
    tight one after another."""
    buf = render(0.7)
    add_tone(buf, 0.0, 0.09, 148, "square", 0.34, duty=0.4,
             env=(0.001, 0.04, 0.25, 0.05), sweep=0.55)
    add_tone(buf, 0.0, 0.14, 74, "triangle", 0.30, env=(0.001, 0.06, 0.3, 0.07),
             sweep=0.7)
    add_noise(buf, 0.0, 0.10, 0.20, env=(0.001, 0.04, 0.2, 0.06), lowpass=0.30)
    add_tone(buf, 0.16, 0.10, 118, "square", 0.16, duty=0.45,
             env=(0.002, 0.05, 0.25, 0.06), sweep=0.6)
    add_tone(buf, 0.30, 0.09, 96, "triangle", 0.10, env=(0.003, 0.05, 0.2, 0.05),
             sweep=0.65)
    save_wav(buf, "coupling")


def sfx_crossing_bell():
    """Level-crossing bell: one strike of the gong, struck on the wig-wag beat.

    A single strike rather than a loop. `PortWorld` already flashes the lamps on
    a half-second beat and rings this on the same clock, so the rhythm comes
    from the thing the player can see — a baked-in loop would drift out of step
    with the lamps the moment either changed."""
    buf = render(0.55)
    for freq, gain in ((1046, 0.26), (1568, 0.13), (2093, 0.07)):
        add_tone(buf, 0.0, 0.45, freq, "triangle", gain,
                 env=(0.002, 0.09, 0.30, 0.34))
    add_noise(buf, 0.0, 0.03, 0.10, env=(0.001, 0.01, 0.2, 0.02), lowpass=0.6)
    save_wav(buf, "crossing_bell")


def sfx_prestige():
    """Prestige reset: shimmering ascent."""
    buf = render(1.4)
    scale = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6"]
    for i, name in enumerate(scale):
        add_tone(buf, i * 0.07, 0.5, note_freq(name), "triangle", 0.16,
                 env=(0.01, 0.1, 0.5, 0.3))
    add_tone(buf, 0.6, 0.7, note_freq("C4"), "square", 0.16, duty=0.25,
             env=(0.02, 0.1, 0.6, 0.4))
    save_wav(buf, "prestige")


def sfx_milestone():
    """Milestone toast."""
    buf = render(0.5)
    for i, name in enumerate(["G5", "C6"]):
        add_tone(buf, i * 0.09, 0.28, note_freq(name), "square", 0.20, duty=0.3,
                 env=(0.005, 0.05, 0.6, 0.16))
    save_wav(buf, "milestone")


def sfx_wheel_tick():
    """A peg passing the wheel's pointer: a dry wooden tick, very short, so a
    fast spin is a rattle and a slow one is a count."""
    buf = render(0.05)
    add_noise(buf, 0.0, 0.025, 0.35, env=(0.0005, 0.01, 0.2, 0.012), lowpass=0.55)
    add_tone(buf, 0.0, 0.02, 1760, "square", 0.12, duty=0.2,
             env=(0.0005, 0.008, 0.2, 0.01))
    save_wav(buf, "wheel_tick")


def sfx_wheel_win():
    """The wheel stops on a prize: a bright little fanfare, rising to a chord."""
    buf = render(0.9)
    for i, name in enumerate(["C5", "E5", "G5"]):
        add_tone(buf, i * 0.08, 0.16, note_freq(name), "square", 0.18, duty=0.3,
                 env=(0.003, 0.04, 0.5, 0.08))
    for name in ("C6", "E6", "G6"):
        add_tone(buf, 0.26, 0.55, note_freq(name), "triangle", 0.14,
                 env=(0.005, 0.1, 0.6, 0.35))
    save_wav(buf, "wheel_win")


def sfx_coins():
    """Coins spilling: a quick sparkle of high pings over a soft shimmer."""
    buf = render(0.6)
    pings = ["E6", "B6", "G6", "E7", "C7", "G7"]
    for i, name in enumerate(pings):
        add_tone(buf, i * 0.045, 0.18, note_freq(name), "triangle", 0.12,
                 env=(0.001, 0.03, 0.3, 0.12))
    add_noise(buf, 0.0, 0.35, 0.06, env=(0.01, 0.1, 0.3, 0.2), lowpass=0.9)
    save_wav(buf, "coins")


# ------------------------------------------------------------- interface sounds
# Everything the audit found silent. Short, soft, and in the same square/triangle
# voice as the rest, with a touch of the new reverb where the sound is a *place*
# (a gate, a bell) rather than a button.

def sfx_ui_open():
    """A board put down on the desk: a low tap and a rising two-note lift."""
    buf = render(0.18)
    add_tone(buf, 0.0, 0.05, 220, "triangle", 0.20, env=(0.001, 0.02, 0.2, 0.03))
    add_tone(buf, 0.02, 0.09, 660, "square", 0.08, duty=0.25, sweep=1.25,
             env=(0.002, 0.03, 0.3, 0.05))
    save_wav(buf, "ui_open")


def sfx_ui_close():
    """The same board lifted: the lift reversed, quieter."""
    buf = render(0.15)
    add_tone(buf, 0.0, 0.08, 660, "square", 0.07, duty=0.25, sweep=0.78,
             env=(0.002, 0.03, 0.3, 0.04))
    add_tone(buf, 0.03, 0.05, 196, "triangle", 0.14, env=(0.001, 0.02, 0.2, 0.03))
    save_wav(buf, "ui_close")


def sfx_ui_tab():
    """A tab turned: one short high tick."""
    buf = render(0.07)
    add_tone(buf, 0.0, 0.04, 1175, "square", 0.10, duty=0.125,
             env=(0.001, 0.015, 0.2, 0.02))
    save_wav(buf, "ui_tab")


def sfx_achievement():
    """A trophy: a bright arpeggio over a bell, with room around it."""
    buf = render(1.4)
    for i, name in enumerate(["E5", "G5", "B5", "E6"]):
        add_tone(buf, i * 0.09, 0.30, note_freq(name), "triangle", 0.16,
                 env=(0.005, 0.08, 0.5, 0.2))
    for freq, g in ((1319, 0.10), (1976, 0.07), (2637, 0.05)):
        add_tone(buf, 0.36, 0.9, freq, "sine", g, env=(0.002, 0.2, 0.3, 0.5))
    save_wav(reverb(buf, mix=0.28, decay=0.55), "achievement")


def sfx_new_day():
    """Dawn: three soft rising notes, long and airy."""
    buf = render(1.8)
    for i, name in enumerate(["C5", "G5", "C6"]):
        add_tone(buf, i * 0.28, 0.9, note_freq(name), "triangle", 0.13,
                 detune=6.0, env=(0.05, 0.2, 0.5, 0.5), lowpass=0.5)
    save_wav(reverb(buf, mix=0.35, decay=0.65), "new_day")


def sfx_truck_arrive():
    """A lorry pulling up: an engine note dropping and a pneumatic hiss."""
    buf = render(1.0)
    add_tone(buf, 0.0, 0.55, 110, "saw", 0.16, sweep=0.55, lowpass=0.18,
             env=(0.02, 0.1, 0.7, 0.3))
    add_tone(buf, 0.0, 0.5, 55, "triangle", 0.18, sweep=0.6,
             env=(0.02, 0.1, 0.7, 0.3))
    add_noise(buf, 0.52, 0.35, 0.16, env=(0.005, 0.1, 0.3, 0.2), lowpass=0.7,
              highpass=0.25)
    save_wav(buf, "truck_arrive")


def sfx_gate_arm():
    """The barrier arm: a short servo whine up, a clack at the top."""
    buf = render(0.55)
    add_tone(buf, 0.0, 0.35, 180, "saw", 0.07, sweep=2.2, lowpass=0.3,
             env=(0.02, 0.08, 0.6, 0.1))
    add_noise(buf, 0.36, 0.05, 0.22, env=(0.001, 0.02, 0.2, 0.02), lowpass=0.5)
    add_tone(buf, 0.36, 0.08, 140, "triangle", 0.22, env=(0.001, 0.03, 0.2, 0.04))
    save_wav(buf, "gate_arm")


def sfx_berth_done():
    """A call finished and paid: a till, then a ship's two-note blast."""
    buf = render(1.3)
    add_tone(buf, 0.0, 0.18, note_freq("E6"), "square", 0.14, duty=0.25,
             env=(0.002, 0.04, 0.4, 0.1))
    add_tone(buf, 0.09, 0.30, note_freq("B6"), "triangle", 0.14,
             env=(0.002, 0.05, 0.5, 0.2))
    add_tone(buf, 0.35, 0.8, 117, "triangle", 0.20, vibrato=0.01,
             env=(0.08, 0.2, 0.7, 0.4))
    add_tone(buf, 0.35, 0.8, 175, "square", 0.07, duty=0.5, lowpass=0.2,
             env=(0.08, 0.2, 0.7, 0.4))
    save_wav(reverb(buf, mix=0.2, decay=0.5), "berth_done")


def sfx_gull_escape():
    """The golden gull gets away: a thin chirp falling off into the distance."""
    buf = render(0.6)
    add_tone(buf, 0.0, 0.35, 1900, "square", 0.08, duty=0.25, sweep=0.5,
             env=(0.005, 0.1, 0.3, 0.2))
    save_wav(delay(buf, 0.12, feedback=0.4, mix=0.35), "gull_escape")


def sfx_skill():
    """A skill pressed: a power-up sweep with a chord stab on top."""
    buf = render(0.8)
    add_tone(buf, 0.0, 0.4, 220, "saw", 0.10, sweep=3.0, lowpass=0.4,
             env=(0.01, 0.1, 0.6, 0.2))
    for name in ("C5", "E5", "G5"):
        add_tone(buf, 0.22, 0.45, note_freq(name), "square", 0.08, duty=0.25,
                 env=(0.003, 0.08, 0.5, 0.25))
    save_wav(buf, "skill")


def sfx_combo():
    """One step of the tap combo: a short blip; the game raises its pitch."""
    buf = render(0.08)
    add_tone(buf, 0.0, 0.05, 784, "triangle", 0.18, env=(0.001, 0.02, 0.3, 0.025))
    save_wav(buf, "combo")


def sfx_build_start():
    """A works order: three hammer knocks and a crane's ratchet."""
    buf = render(0.7)
    for i in range(3):
        add_noise(buf, i * 0.16, 0.05, 0.25, env=(0.001, 0.02, 0.2, 0.02),
                  lowpass=0.35)
        add_tone(buf, i * 0.16, 0.06, 150, "triangle", 0.2,
                 env=(0.001, 0.02, 0.2, 0.03))
    save_wav(buf, "build_start")


def sfx_bell():
    """The notice bell: a small clear ring with a long tail."""
    buf = render(1.2)
    for freq, g in ((1568, 0.14), (2349, 0.08), (3136, 0.05)):
        add_tone(buf, 0.0, 0.9, freq, "sine", g, env=(0.001, 0.15, 0.25, 0.5))
    add_noise(buf, 0.0, 0.02, 0.12, env=(0.0005, 0.01, 0.2, 0.01), lowpass=0.6)
    save_wav(reverb(buf, mix=0.2, decay=0.5), "bell")



## Alisson's voice: Simlish. No words, but a voice - a bright, high, bouncy
## babble of syllables. Each take is a consonant onset (a noise burst or a
## plosive pop) into a vowel: a sawtooth glottis at a cartoon-high pitch, run
## through two formant resonators so it reads as "a", "e", "i", "o", "u"
## rather than as a beep. The pitch contour bends up or down per syllable, with
## a quick vibrato - the sing-song that makes Simlish sound like talking.
import math
import random

# vowel -> (F1, F2), pushed up a third for a small, chirpy speaker
_VOWELS = {
    "a": (900, 1500), "e": (560, 2200), "i": (360, 2700),
    "o": (580, 1050), "u": (400, 950),
}
# (onset, vowel, f0 Hz, contour end ratio, length s)
VOICE_TAKES = [
    ("b", "a", 430, 1.25, 0.11), ("w", "i", 470, 0.85, 0.10),
    ("sh", "a", 450, 1.15, 0.12), ("n", "o", 400, 1.30, 0.11),
    ("p", "u", 480, 0.80, 0.09), ("l", "e", 440, 1.20, 0.10),
    ("k", "a", 500, 0.90, 0.09), ("z", "o", 420, 1.35, 0.12),
    ("m", "i", 460, 1.10, 0.10), ("d", "e", 490, 0.82, 0.09),
]


def _resonator(x, freq, bw, sr):
    r = math.exp(-math.pi * bw / sr)
    b1 = -2.0 * r * math.cos(2.0 * math.pi * freq / sr)
    b2 = r * r
    gain = 1.0 - r
    y1 = y2 = 0.0
    out = []
    for v in x:
        y = gain * v - b1 * y1 - b2 * y2
        y2, y1 = y1, y
        out.append(y)
    return out


def _syllable(onset, vowel, f0, bend, length, rng, sr=22050, formant=1.0):
    n = int(sr * length)
    onset_n = {"b": 0.012, "p": 0.014, "d": 0.012, "k": 0.016, "t": 0.012,
               "sh": 0.035, "z": 0.03, "w": 0.02, "l": 0.018,
               "n": 0.02, "m": 0.02}[onset]
    on = int(sr * onset_n)
    glottis = []
    phase = 0.0
    for i in range(n):
        t = i / sr
        k = i / max(1, n - 1)
        f = f0 * (1.0 + (bend - 1.0) * k) * (1.0 + 0.025 * math.sin(2 * math.pi * 7.5 * t))
        phase = (phase + f / sr) % 1.0
        glottis.append(2.0 * phase - 1.0)
    f1, f2 = (f * formant for f in _VOWELS[vowel])
    voiced = [a + 0.7 * b for a, b in zip(_resonator(glottis, f1, 110, sr),
                                         _resonator(glottis, f2, 160, sr))]
    out = []
    for i in range(n):
        # voiced envelope: nasals and glides fade in, plosives snap in
        soft = onset in ("w", "l", "n", "m")
        a = min(1.0, (i - (0 if soft else on)) / (sr * (0.02 if soft else 0.004))) \
            if i >= (0 if soft else on) else 0.0
        rel = min(1.0, (n - i) / (sr * 0.03))
        v = voiced[i] * max(0.0, a) * rel
        if onset in ("w", "l", "n", "m") and i < on:
            v *= 0.5          # a hummed lead-in
        out.append(v)
    # consonant noise: hiss for sh/z, a short pop for plosives
    hiss = onset in ("sh", "z")
    pop = onset in ("b", "p", "d", "k", "t")
    prev = 0.0
    for i in range(min(n, on + int(sr * 0.006))):
        noise = rng.uniform(-1.0, 1.0)
        if hiss:
            hp = noise - prev
            prev = noise
            out[i] += hp * 0.18 * (1.0 - i / max(1, on)) if i < on else 0.0
        elif pop:
            out[i] += noise * 0.35 * math.exp(-i / (sr * 0.004))
    peak = max(1e-6, max(abs(v) for v in out))
    return [v / peak * 0.8 for v in out]


def sfx_voice():
    """Alisson talking: ten Simlish syllables."""
    rng = random.Random(1987)
    for index, (onset, vowel, f0, bend, length) in enumerate(VOICE_TAKES):
        save_wav(_syllable(onset, vowel, f0, bend, length, rng),
                 "voice_%d" % (index + 1))

## Neide's voice, the Receita Federal auditor: the same Simlish machine, an
## octave-ish lower and drier than Alisson. Crisp plosive onsets (t, k, p, d),
## round "o"/"e" vowels, formants pulled down a touch for a fuller chest, and
## contours that mostly *fall* - the cadence of somebody reading out a
## regulation. Short takes, so she sounds clipped and official, not bouncy.
VOICE_RF_TAKES = [
    ("t", "o", 250, 0.86, 0.09), ("k", "e", 270, 0.90, 0.08),
    ("p", "a", 240, 0.84, 0.10), ("d", "o", 260, 1.06, 0.09),
    ("m", "e", 235, 0.88, 0.10), ("t", "a", 275, 0.82, 0.08),
    ("n", "u", 245, 0.92, 0.10), ("k", "o", 265, 0.80, 0.09),
]


def sfx_voice_rf():
    """Neide talking: eight clipped, official Simlish syllables."""
    rng = random.Random(1964)
    for index, (onset, vowel, f0, bend, length) in enumerate(VOICE_RF_TAKES):
        save_wav(_syllable(onset, vowel, f0, bend, length, rng, formant=0.86),
                 "voice_rf_%d" % (index + 1))

if __name__ == "__main__":
    print("sfx:")
    sfx_tap()
    sfx_click()
    sfx_thunk()
    sfx_splash()
    sfx_buy()
    sfx_upgrade()
    sfx_deny()
    sfx_build()
    sfx_horn()
    sfx_train_horn()
    sfx_rail_brake()
    sfx_coupling()
    sfx_crossing_bell()
    sfx_foghorn()
    sfx_gull()
    sfx_meow()
    sfx_prestige()
    sfx_milestone()
    sfx_wheel_tick()
    sfx_wheel_win()
    sfx_coins()
    sfx_ui_open()
    sfx_ui_close()
    sfx_ui_tab()
    sfx_achievement()
    sfx_new_day()
    sfx_truck_arrive()
    sfx_gate_arm()
    sfx_berth_done()
    sfx_gull_escape()
    sfx_skill()
    sfx_combo()
    sfx_build_start()
    sfx_bell()
    sfx_voice()
    sfx_voice_rf()
