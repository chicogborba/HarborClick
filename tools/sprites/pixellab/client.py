"""Thin PixelLab REST client, with the raw generations kept on disk.

Every other generator in `tools/sprites` is deterministic: run it and you get
the same PNG. A model is not, and a build that phones an API is not a build, so
this splits the two halves apart.

  * **the recipe** — prompt, size and knobs, in `recipes.py`, in the repo;
  * **the raw generation** — what the model answered, cached under `raw/`, in
    the repo as well.

`gen_pixellab.py` only ever reads `raw/`. It never calls the network, so
`tools/generate_all.sh` stays offline and reproducible. Filling `raw/` is a
separate, explicit act: `python -m pixellab.client fetch [name ...]`, which
needs `PIXELLAB_API_KEY` and only touches recipes whose cached answer is
missing or whose recipe hash has moved on.

The hash is over the request body, so editing a prompt invalidates exactly the
asset whose prompt changed and nothing else.
"""
from __future__ import annotations

import base64
import hashlib
import io
import json
import os
import sys
import urllib.error
import urllib.request

BASE = "https://api.pixellab.ai/v1"
HERE = os.path.dirname(os.path.abspath(__file__))
RAW_DIR = os.path.join(HERE, "raw")
LOCK_PATH = os.path.join(HERE, "raw", "generations.json")


def _key() -> str:
    key = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if not key:
        raise SystemExit(
            "PIXELLAB_API_KEY is not set. The raw generations under "
            "tools/sprites/pixellab/raw are committed, so only re-fetching "
            "needs it.")
    return key


def request_body(recipe: dict) -> dict:
    """The exact JSON posted for a recipe — and the thing that is hashed."""
    body: dict = {
        "description": recipe["prompt"],
        "image_size": {"width": recipe["width"], "height": recipe["height"]},
    }
    for field in ("text_guidance_scale", "outline", "shading", "detail",
                  "view", "direction", "isometric", "no_background", "seed",
                  "init_image_strength"):
        if field in recipe:
            body[field] = recipe[field]
    if recipe.get("palette"):
        body["color_image"] = {"type": "base64", "base64": recipe["palette"]}
    if recipe.get("init_image"):
        body["init_image"] = {"type": "base64", "base64": recipe["init_image"]}
    return body


def recipe_hash(recipe: dict) -> str:
    payload = json.dumps(request_body(recipe), sort_keys=True).encode()
    return hashlib.sha256(payload).hexdigest()[:16]


def load_lock() -> dict:
    if not os.path.exists(LOCK_PATH):
        return {}
    with open(LOCK_PATH) as handle:
        return json.load(handle)


def save_lock(lock: dict) -> None:
    os.makedirs(RAW_DIR, exist_ok=True)
    with open(LOCK_PATH, "w") as handle:
        json.dump(lock, handle, indent=2, sort_keys=True)
        handle.write("\n")


def raw_path(name: str) -> str:
    return os.path.join(RAW_DIR, name + ".png")


def is_stale(name: str, recipe: dict, lock: dict) -> bool:
    if not os.path.exists(raw_path(name)):
        return True
    return lock.get(name, {}).get("hash") != recipe_hash(recipe)


def post(endpoint: str, body: dict) -> dict:
    request = urllib.request.Request(
        f"{BASE}/{endpoint}",
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {_key()}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode()[:600]
        raise SystemExit(f"PixelLab {endpoint} failed ({error.code}): {detail}")


def fetch(name: str, recipe: dict, lock: dict) -> None:
    body = request_body(recipe)
    endpoint = recipe.get("endpoint", "generate-image-pixflux")
    print(f"  generating {name} ({recipe['width']}x{recipe['height']}) ...")
    answer = post(endpoint, body)
    os.makedirs(RAW_DIR, exist_ok=True)
    with open(raw_path(name), "wb") as handle:
        handle.write(base64.b64decode(answer["image"]["base64"]))
    usage = answer.get("usage", {})
    lock[name] = {
        "hash": recipe_hash(recipe),
        "endpoint": endpoint,
        "prompt": recipe["prompt"],
        "size": [recipe["width"], recipe["height"]],
        "usage": usage,
    }
    print(f"    saved raw/{name}.png  usage={usage}")


def main(argv: list[str]) -> int:
    import recipes  # local module, imported late so `-m` works from either dir

    wanted = set(argv[1:]) if len(argv) > 1 else None
    lock = load_lock()
    todo = []
    for name, recipe in recipes.RECIPES.items():
        if wanted is not None and name not in wanted:
            continue
        if is_stale(name, recipe, lock):
            todo.append((name, recipe))
    if not todo:
        print("pixellab: every raw generation is current.")
        return 0
    print(f"pixellab: {len(todo)} generation(s) to fetch.")
    for name, recipe in todo:
        fetch(name, recipe, lock)
        save_lock(lock)
    return 0


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    sys.path.insert(0, os.path.dirname(HERE))
    raise SystemExit(main(sys.argv))
