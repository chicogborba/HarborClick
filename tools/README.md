# Tooling

- `sprites/` — deterministic PIL generators for every PNG. Two rail sprites are
  not free to resize: `rail_gantry` stands on steel that
  `GroundBaker._paint_rail_platform` paints, so `GANTRY_GAUGE` in `gen_rail.py`
  and that spacing are one number kept in two files, and `rail_shed` is drawn to
  `PortLayout.rail_shed_rect()`. Change one side only and the crane is parked in
  mid-air over the ballast.
- `sprites/vendor/` — `pixelstudio.py` from pixel-art-studio (MIT), vendored
  for its hue-shifted `ramp()`. Every material in `palette.py` is shaded from
  one: shadows lean blue, highlights lean yellow. Art direction for all
  generators: one light from the north-west, south faces showing (the yard's
  3/4 view), integer scale only, never a rotation finer than a quarter turn.
- `sprites/gen_train.py` draws the rake facing east at 1:1 (see the world
  README); `gen_wheel.py` computes the Roda da Sorte disc pixel by pixel at 64
  angles, because a rotated sprite is resampled mush; `gen_bonus.py` is the
  golden gull, its sparkle and the Missões do Dia key.
- `sprites/pixellab/` — the handful of *illustrated* assets a loop cannot draw:
  prompts, the model's committed answers and the harmoniser that makes them
  match the rest. The build reads the cached answers and never calls the API;
  see [`sprites/pixellab/README.md`](sprites/pixellab/README.md).
- `audio/` — deterministic audio generators.
- `capture/` — headed responsive/visual/performance harness. `lang=pt_BR`
  photographs a language other than the machine's. `closeup.tscn` takes one
  zoomed shot per process (`rail`, `rail_shunt`, `gull`, `ship`, `yard`) — the
  matrix harness can wedge on a stale frame after its first shot when the
  window is unfocused, which a single shot never does.
- `balance/` — deterministic economy scenarios.
- `docs/` — whole-repository code-map generator.
- `qa/` — one-command project validation.
- `generate_all.sh` — regenerate sprites and audio.

Generated outputs live in `assets`, except `sprites/gen_landing.py`, which
composes the public page's art out of those sprites and writes it to
`landing/assets` — so it runs last in `generate_all.sh`. Alphabetical order is
load-bearing in one other place: `gen_pixellab.py` writes the ship the title's
berth is composed with, and it has to run before `gen_title.py`. Edit generator and
output together. The project-local Python environment is `tools/venv`. Visual changes need a focused
capture at 320×568 and 390×844 plus the matrix before release.

Documentation changes that add/move code must run:

```bash
tools/venv/bin/python tools/docs/generate_code_map.py
```

