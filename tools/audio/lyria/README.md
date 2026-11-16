# The soundtrack

Seven loops — dawn, day, dusk, night, fog, rain and the shop — composed by
Google's Lyria 3 (`google/lyria-3-pro-preview`, through OpenRouter). They
replaced the synth loops of `../gen_music.py`, which is kept as reference and
renders only with `--synth`.

    recipes.py ──asked once, by hand──▶ raw/*.mp3 ──render_loops.py──▶ assets/audio/music_*.ogg

* `recipes.py` is the source: one shared brief (a cozy pixel port with a
  Brazilian heart — bossa, samba-canção, MPB grooves under chiptune-coloured
  leads, steady energy, no intro or ending) plus a line per track.
* `raw/` is what the model answered, committed with `generations.json`
  (prompt, hash, cost: $0.08 a track). Godot ignores the folder.
* `render_loops.py` trims the fade-in/out, crossfades the tail over the head so
  the file loops seamlessly, matches the old loops' level and writes Ogg. It is
  offline and deterministic; it needs `soundfile` in the tools venv
  (`tools/venv/bin/pip install soundfile`) because Homebrew's ffmpeg has no
  libvorbis.

Refetching is explicit and only touches tracks whose answer is missing or whose
prompt changed:

```bash
OPENROUTER_API_KEY=... tools/venv/bin/python tools/audio/lyria/client.py [music_day ...]
tools/venv/bin/python tools/audio/lyria/render_loops.py
```

Never commit the key. `AudioManager._load` prefers `<name>.ogg` over
`<name>.wav` and loops an Ogg whole.
