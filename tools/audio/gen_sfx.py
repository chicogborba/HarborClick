"""All HarborClick sound effects, generated from code."""
from synth import render, add_tone, add_noise, save_wav, note_freq


def sfx_tap():
    """UI tap: short blip."""
    buf = render(0.09)
    add_tone(buf, 0.0, 0.07, 880, "square", 0.24, duty=0.25,
             env=(0.002, 0.02, 0.4, 0.04))
    save_wav(buf, "tap")


def sfx_thunk():
    """Container landing on the stack: metallic clunk + dust."""
    buf = render(0.30)
    add_tone(buf, 0.0, 0.10, 180, "square", 0.32, duty=0.5,
             env=(0.001, 0.05, 0.3, 0.05), sweep=0.55)
    add_tone(buf, 0.0, 0.16, 92, "triangle", 0.34,
             env=(0.001, 0.08, 0.35, 0.08), sweep=0.7)
    add_noise(buf, 0.0, 0.13, 0.16, env=(0.001, 0.05, 0.2, 0.07), lowpass=0.25)
    save_wav(buf, "thunk")


def sfx_click():
    """Tapping the ship: crisp pick-up."""
    buf = render(0.16)
    add_tone(buf, 0.0, 0.08, 520, "square", 0.26, duty=0.35,
             env=(0.001, 0.03, 0.4, 0.04), sweep=1.6)
    add_noise(buf, 0.0, 0.05, 0.10, env=(0.001, 0.02, 0.2, 0.03), lowpass=0.4)
    save_wav(buf, "click")


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


def sfx_horn():
    """Ship horn on arrival/departure: deep, warbling."""
    buf = render(1.5)
    add_tone(buf, 0.0, 1.35, 104, "square", 0.30, duty=0.5,
             env=(0.09, 0.15, 0.85, 0.35), vibrato=0.006)
    add_tone(buf, 0.0, 1.35, 78, "triangle", 0.34,
             env=(0.09, 0.15, 0.85, 0.35), vibrato=0.005)
    add_tone(buf, 0.0, 1.35, 156, "square", 0.10, duty=0.3,
             env=(0.12, 0.2, 0.6, 0.4))
    save_wav(buf, "horn")


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
    sfx_buy()
    sfx_upgrade()
    sfx_deny()
    sfx_build()
    sfx_horn()
    sfx_foghorn()
    sfx_gull()
    sfx_meow()
    sfx_prestige()
    sfx_milestone()
