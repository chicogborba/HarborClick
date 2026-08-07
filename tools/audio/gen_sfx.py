"""All HarborClick sound effects, generated from code."""
from synth import render, add_tone, add_noise, save_wav, note_freq


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
