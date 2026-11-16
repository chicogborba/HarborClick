"""Turns the committed Lyria answers in `raw/` into the game's music loops.

    tools/venv/bin/python tools/audio/lyria/render_loops.py

Offline and deterministic (ffmpeg + numpy). For each track:

* the quiet head and tail a generation starts and ends with are cut, by RMS
  against the track's own median level, so the loop has no fade in it;
* the last CROSSFADE seconds are mixed over the first ones with an equal-power
  curve, which makes the end flow into the start — Godot loops the file whole;
* the level is matched to the synth loops these replaced (`TARGET_RMS`), so the
  mix under the effects does not change for players who never touch a slider;
* it is written as Ogg Vorbis, stereo (needs `pip install soundfile` in the
  tools venv; ffmpeg is used only to decode).
"""
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import recipes  # noqa: E402

RATE = 44100
CROSSFADE = 4.0
MAX_SECONDS = 150.0
# The old synth loops measured ~0.066 RMS; a full arrangement reads louder at
# the same RMS, so this sits a touch under it.
TARGET_RMS = 0.06


def decode(path: str) -> np.ndarray:
    pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le",
                          "-ac", "2", "-ar", str(RATE), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(pcm, dtype=np.float32).reshape(-1, 2).copy()


def trim(audio: np.ndarray) -> np.ndarray:
    window = RATE // 2
    frames = len(audio) // window
    rms = np.sqrt((audio[: frames * window] ** 2).reshape(frames, -1).mean(axis=1))
    loud = np.where(rms > np.median(rms) * 0.6)[0]
    start = (loud[0] + 1) * window
    end = loud[-1] * window
    end = min(end, start + int(MAX_SECONDS * RATE) + int(CROSSFADE * RATE))
    return audio[start:end]


def seam(audio: np.ndarray) -> np.ndarray:
    n = int(CROSSFADE * RATE)
    body, tail = audio[:-n].copy(), audio[-n:]
    t = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
    body[:n] = body[:n] * np.sin(t * np.pi / 2) + tail * np.cos(t * np.pi / 2)
    return body


def level(audio: np.ndarray) -> np.ndarray:
    rms = float(np.sqrt((audio ** 2).mean()))
    out = audio * (TARGET_RMS / max(rms, 1e-6))
    peak = float(np.abs(out).max())
    return out / peak * 0.95 if peak > 0.95 else out


def encode(audio: np.ndarray, path: str) -> None:
    # libsndfile's Vorbis (pip `soundfile`): Homebrew's ffmpeg ships without
    # libvorbis, and its built-in experimental encoder is audibly worse.
    # Written in blocks: one large Vorbis write segfaults libsndfile.
    import soundfile
    data = np.ascontiguousarray(audio, dtype=np.float32)
    with soundfile.SoundFile(path, "w", RATE, 2, format="OGG",
                             subtype="VORBIS", compression_level=0.6) as out:
        for start in range(0, len(data), 16384):
            out.write(data[start:start + 16384])


def main() -> None:
    for name in recipes.TRACKS:
        src = os.path.join(HERE, "raw", name + ".mp3")
        if not os.path.exists(src):
            print(f"  {name}: no raw answer, skipped")
            continue
        loop = level(seam(trim(decode(src))))
        dst = os.path.join(ROOT, "assets", "audio", name + ".ogg")
        encode(loop, dst)
        print(f"  {name}.ogg  {len(loop) / RATE:.1f}s  {os.path.getsize(dst) // 1024} KB")


if __name__ == "__main__":
    main()
