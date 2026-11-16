"""The soundtrack, as prompts.

Every track the game plays is asked of Google's Lyria 3 (through OpenRouter)
once, by hand, with these words; the answer is committed under `raw/` and
`render_loops.py` turns it into the looping `assets/audio/music_*.ogg` the game
plays. The build never calls the network — see `client.py`.

The shared brief keeps seven separate generations sounding like one game: a
pixel-art container port with a Brazilian heart, so the grooves lean on bossa
nova, samba-cancao and MPB under chiptune-coloured leads, and every track is
asked for steady energy with no intro, climax or ending, because it loops for
as long as the player keeps the port open.
"""

MODEL = "google/lyria-3-pro-preview"

BRIEF = (
    "Instrumental background music for a cozy pixel-art idle game about a busy "
    "container port in Brazil. Chiptune-coloured leads (soft square and triangle "
    "waves) over warm acoustic textures. No vocals. Steady energy from start to "
    "finish: no intro, no build-up, no big climax, no ending, so it can loop for "
    "hours under gameplay without drawing attention to itself. "
)

TRACKS = {
    "music_day": BRIEF + (
        "Daytime on the quay: a gentle bossa nova groove at 92 BPM, nylon-string "
        "guitar comping, light shaker and rim clicks, mellow round bass, a hint of "
        "distant harbour bells. Major key, optimistic, sunny, relaxed."),
    "music_dawn": BRIEF + (
        "Dawn over the harbour: sparse and soft at 80 BPM, slow nylon guitar "
        "arpeggios, warm airy synth pads, a few bell-like chiptune notes like "
        "birds waking, very light percussion. Hopeful, fresh, quiet."),
    "music_dusk": BRIEF + (
        "Golden hour at the terminal: mellow electric piano and brushed bossa "
        "drums at 84 BPM, a smooth breathy synth lead like a soft flute, "
        "walking upright-style bass. Warm, nostalgic, content."),
    "music_night": BRIEF + (
        "The port at night under floodlights: calm lo-fi at 70 BPM, muted soft "
        "keys, deep gentle bass, sparse brushed percussion, faint distant "
        "foghorn-like synth swells. Peaceful, a little dreamy, never dark."),
    "music_fog": BRIEF + (
        "Fog rolling over the docks: slow ambient at 66 BPM, soft evolving pads, "
        "a low clarinet-like synth melody, gentle muffled marimba, very sparse "
        "percussion. Mysterious but cozy, calm."),
    "music_rain": BRIEF + (
        "A rainy afternoon at the port: soft lo-fi samba-cancao at 76 BPM, gentle "
        "piano chords, light vinyl warmth, soft cavaquinho-like plucks, brushed "
        "drums. Melancholic but warm and comforting."),
    "music_shop": BRIEF + (
        "The shop clipboard: playful and bouncy at 108 BPM, a light samba-pop "
        "groove with marimba, pandeiro-style percussion and cheerful square-wave "
        "lead, short catchy motifs. Upbeat, fun, rewarding, still unobtrusive."),
}
