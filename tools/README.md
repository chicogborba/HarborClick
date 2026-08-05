# Tooling

- `sprites/` — deterministic PIL generators for every PNG.
- `audio/` — deterministic audio generators.
- `capture/` — headed responsive/visual/performance harness.
- `balance/` — deterministic economy scenarios.
- `docs/` — whole-repository code-map generator.
- `qa/` — one-command project validation.
- `generate_all.sh` — regenerate sprites and audio.

Generated outputs live in `assets`, except `sprites/gen_landing.py`, which
composes the public page's art out of those sprites and writes it to
`landing/assets` — so it runs last in `generate_all.sh`. Edit generator and
output together. The project-local Python environment is `tools/venv`. Visual changes need a focused
capture at 320×568 and 390×844 plus the matrix before release.

Documentation changes that add/move code must run:

```bash
tools/venv/bin/python tools/docs/generate_code_map.py
```

