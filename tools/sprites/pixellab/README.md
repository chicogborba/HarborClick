# Generated art

Every other PNG in this game is drawn by code, and that is not a limitation to
work around — it is the only reason a hundred sprites share one palette. It
breaks down for exactly one kind of asset: the *illustrated* piece, where the
value is in the drawing and a nested loop is the wrong instrument. The crest on
the title plate, the ship at its berth and the three berth photographs on the
selection board are those pieces. They come from PixelLab.

## The build never calls the network

    recipes.py ──asked once, by hand──▶ raw/*.png ──gen_pixellab.py──▶ assets/

* `recipes.py` is the prompt, the size and the knobs. It is the source.
* `raw/` is what the model answered, committed. It is the input `generate_all.sh`
  reads, so the build is offline, deterministic and identical on every machine.
  Godot is told to ignore the folder — the raw canvas is not a game asset.
* `gen_pixellab.py` (in `tools/sprites`) harmonises those answers and writes the
  real assets. It is an ordinary generator: no key, no network, same PNG twice.

Refetching is a separate, explicit act:

```bash
PIXELLAB_API_KEY=... tools/venv/bin/python tools/sprites/pixellab/client.py
```

It only touches recipes whose cached answer is missing or whose recipe hash has
moved on, so editing one prompt regenerates one asset. `raw/generations.json`
records the hash, the prompt and what each call cost. Never commit the key.

## Making a generation belong here

`harmonize.py` is the difference between an asset and a guest:

* the request carries the game's colours as a forced palette;
* `snap` then pulls what came back onto the nearest colour the game already
  paints with, but only when it is close enough to be the same intent;
* `harden` removes partial alpha, `trim` removes the padding around the subject,
  and `halve` is the only resize allowed — exact 2:1, nearest. A model asked for
  128px puts more structure in than one asked for 64, and halving keeps it.

Two rules, learned the expensive way. Generate large and halve rather than
generating small. And ask for a projection the model can actually hold: it
answers every phrasing of "from directly above" for a gantry crane with a side
elevation, which is why the quay cranes in `gen_title.py` are still hand-drawn.
