# Vendored: pixel-art-studio

`pixelstudio.py` is copied unmodified from
[Gamezxz/pixel-art-studio](https://github.com/Gamezxz/pixel-art-studio)
(`scripts/pixelstudio.py`, MIT — see `LICENSE.pixelstudio`).

The generators use it for two things only:

- `ramp()` — hue-shifted shading ramps. Shadows rotate toward blue, highlights
  toward yellow, saturation peaks at the midtone. `palette.py` builds every
  material from it, so a colour is never just a darker copy of itself.
- `Sprite` — a canvas with `only=` masking, used where a sprite is easier to
  build by restacking shapes (`gen_train.py`).

Its rules — one light source from the north-west, ramps instead of straight
darkening, integer scale only, no orphan pixels — are the art direction for
every generator here; see `tools/README.md`.
