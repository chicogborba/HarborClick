"""Asks Lyria for every track in `recipes.py` whose answer is not in `raw/` yet.

    OPENROUTER_API_KEY=... tools/venv/bin/python tools/audio/lyria/client.py [name ...]

Writes `raw/<name>.mp3` and records prompt and cost in `raw/generations.json`.
Never commit the key; the build and `render_loops.py` never need it.
"""
import base64
import concurrent.futures as futures
import hashlib
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import recipes  # noqa: E402

RAW = os.path.join(HERE, "raw")
LEDGER = os.path.join(RAW, "generations.json")


def ask(name: str, prompt: str) -> dict:
    body = json.dumps({"model": recipes.MODEL, "modalities": ["audio", "text"],
                       "stream": True, "audio": {"format": "wav"},
                       "messages": [{"role": "user", "content": prompt}]}).encode()
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions", data=body,
        headers={"Authorization": "Bearer " + os.environ["OPENROUTER_API_KEY"],
                 "Content-Type": "application/json"})
    chunks, usage = [], {}
    with urllib.request.urlopen(req, timeout=900) as response:
        for raw in response:
            line = raw.decode().strip()
            if not line.startswith("data:") or line[5:].strip() == "[DONE]":
                continue
            try:
                event = json.loads(line[5:])
            except ValueError:
                continue
            if event.get("error"):
                raise RuntimeError(f"{name}: {event['error']}")
            usage = event.get("usage") or usage
            for choice in event.get("choices", []):
                audio = choice.get("delta", {}).get("audio") or {}
                if audio.get("data"):
                    chunks.append(audio["data"])
    data = base64.b64decode("".join(chunks))
    if len(data) < 10000:
        raise RuntimeError(f"{name}: no audio came back")
    with open(os.path.join(RAW, name + ".mp3"), "wb") as out:
        out.write(data)
    return {"model": recipes.MODEL, "prompt": prompt,
            "hash": hashlib.sha1(prompt.encode()).hexdigest()[:12],
            "bytes": len(data), "cost_usd": usage.get("cost")}


def main() -> None:
    os.makedirs(RAW, exist_ok=True)
    ledger = json.load(open(LEDGER)) if os.path.exists(LEDGER) else {}
    wanted = sys.argv[1:] or list(recipes.TRACKS)
    todo = [n for n in wanted if not os.path.exists(os.path.join(RAW, n + ".mp3"))
            or ledger.get(n, {}).get("hash")
            != hashlib.sha1(recipes.TRACKS[n].encode()).hexdigest()[:12]]
    with futures.ThreadPoolExecutor(max_workers=7) as pool:
        jobs = {pool.submit(ask, n, recipes.TRACKS[n]): n for n in todo}
        for job in futures.as_completed(jobs):
            name = jobs[job]
            try:
                ledger[name] = job.result()
                print(f"  {name}: {ledger[name]['bytes']} bytes, ${ledger[name]['cost_usd']}")
            except Exception as error:  # noqa: BLE001 - report and keep the rest
                print(f"  {name}: FAILED {error}")
    with open(LEDGER, "w") as out:
        json.dump(ledger, out, indent=2, sort_keys=True)


if __name__ == "__main__":
    main()
