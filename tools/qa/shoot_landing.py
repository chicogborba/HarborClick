#!/usr/bin/env python3
"""Screenshot the landing page at honest device metrics, over CDP.

There is no way to judge the front door by reading it, and the obvious way to
photograph it is a trap: `chrome --headless --window-size=390,844` silently
renders at a 500px floor and then crops the PNG to the size you asked for,
which looks exactly like a broken mobile layout. This drives
`Emulation.setDeviceMetricsOverride` instead, which is the only way to see a
phone width as a phone sees it.

Serve a mirror of the release layout first — the page uses absolute
`/media/...` paths, so opening `landing/index.html` from disk shows nothing:

    tools/export/build_release.sh
    (cd build/release && python3 -m http.server 8765)
    tools/venv/bin/python tools/qa/shoot_landing.py http://127.0.0.1:8765/ shots

Each shot is `name:WIDTHxHEIGHT` plus any of these flags, colon-separated:

    @<selector>  scroll there first, so the reveal observer actually fires
    L=<code>     load in one language (?lang=ru)
    w=<seconds>  wait longer before the shutter — the ship crosses in ~60s
    c=<selector> click something first, e.g. the language picker
    full         whole page rather than the viewport
    still        with prefers-reduced-motion: reduce
    d<n>         device pixel ratio

    tools/venv/bin/python tools/qa/shoot_landing.py http://127.0.0.1:8765/ shots \\
        phone:390x844 desktop:1440x900:w=20 ru:1440x900:L=ru \\
        loop:1440x900:@.bay picker:390x844:c=#lang-btn still:1440x900:still
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.request

try:
    import websocket                      # websocket-client
except ImportError:                       # pragma: no cover - setup hint
    raise SystemExit("pip install websocket-client into tools/venv first")

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PORT = 9333
SETTLE = 2.6                              # default wait after navigation


def launch(profile):
    """A headless Chrome we can talk CDP to.

    `--remote-allow-origins=*` is not optional: without it Chrome rejects the
    websocket handshake, and the failure looks like the browser never started.
    """
    proc = subprocess.Popen(
        [CHROME, "--headless=new", f"--remote-debugging-port={PORT}",
         "--remote-allow-origins=*", f"--user-data-dir={profile}",
         "--no-first-run", "--no-default-browser-check", "--hide-scrollbars",
         "--force-device-scale-factor=1", "--disable-gpu", "about:blank"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(80):
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/version",
                                   timeout=1)
            return proc
        except Exception:
            time.sleep(0.25)
    proc.terminate()
    raise SystemExit("chrome never answered on the debugging port")


def page_socket():
    # `/json/new` refuses POST on current Chrome; take the tab that is already
    # open instead of asking for another one.
    targets = json.load(
        urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/list"))
    page = next(target for target in targets if target["type"] == "page")
    return websocket.create_connection(page["webSocketDebuggerUrl"],
                                       suppress_origin=True, timeout=60)


class CDP:
    def __init__(self, socket):
        self.socket = socket
        self.count = 0

    def send(self, method, **params):
        self.count += 1
        self.socket.send(json.dumps(
            {"id": self.count, "method": method, "params": params}))
        while True:
            message = json.loads(self.socket.recv())
            if message.get("id") == self.count:
                if "error" in message:
                    raise RuntimeError(f"{method}: {message['error']}")
                return message.get("result", {})

    def js(self, expression):
        return self.send("Runtime.evaluate", returnByValue=True,
                         expression=expression).get("result", {}).get("value")


def metrics(cdp, width, height, dpr):
    cdp.send("Emulation.setDeviceMetricsOverride", width=width, height=height,
             deviceScaleFactor=dpr, mobile=width < 700,
             screenWidth=width, screenHeight=height)


def shoot(cdp, url, out_dir, shot):
    name, width, height = shot["name"], shot["width"], shot["height"]
    metrics(cdp, width, height, shot["dpr"])
    cdp.send("Emulation.setEmulatedMedia", features=[{
        "name": "prefers-reduced-motion",
        "value": "reduce" if shot["still"] else "no-preference"}])
    target = f"{url}?lang={shot['lang']}" if shot["lang"] else url
    cdp.send("Page.navigate", url=target)
    time.sleep(shot["wait"])

    if shot["at"]:
        landed = cdp.js(
            "(() => { const n = document.querySelector(%r);"
            " if (!n) return 'missing';"
            " document.documentElement.style.scrollBehavior = 'auto';"
            " scrollTo(0, n.getBoundingClientRect().top + scrollY - 70);"
            " return scrollY; })()" % shot["at"])
        if landed == "missing":
            raise SystemExit(f"{name}: no element matches {shot['at']}")
        time.sleep(1.6)

    if shot["click"]:
        cdp.js("document.querySelector(%r).click()" % shot["click"])
        time.sleep(0.6)

    if shot["full"]:
        # A full-page capture never scrolls, so the reveal observer never
        # fires and every panel below the fold photographs blank.
        cdp.js("document.querySelectorAll('.reveal')"
               ".forEach(n => n.classList.add('seen'))")
        page_height = int(cdp.send("Page.getLayoutMetrics")
                          ["cssContentSize"]["height"])
        metrics(cdp, width, page_height, shot["dpr"])
        time.sleep(1.0)

    data = cdp.send("Page.captureScreenshot", format="png",
                    captureBeyondViewport=shot["full"])["data"]
    path = os.path.join(out_dir, f"{name}.png")
    with open(path, "wb") as handle:
        handle.write(base64.b64decode(data))
    print(f"  {path}")


def parse(spec):
    parts = spec.split(":")
    width, height = (int(value) for value in parts[1].split("x"))
    flags = parts[2:]

    def flag(prefix, cast=str, fallback=None):
        for item in flags:
            if item.startswith(prefix):
                return cast(item[len(prefix):])
        return fallback

    return {
        "name": parts[0], "width": width, "height": height,
        "dpr": flag("d", float, 1.0),
        "at": flag("@"),
        "lang": flag("L="),
        "wait": flag("w=", float, SETTLE),
        "click": flag("c="),
        "full": "full" in flags,
        "still": "still" in flags,
    }


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    url, out_dir = sys.argv[1], sys.argv[2]
    shots = [parse(spec) for spec in sys.argv[3:]] or \
        [parse("desktop:1440x900"), parse("phone:390x844")]
    os.makedirs(out_dir, exist_ok=True)
    proc = launch(os.path.join(out_dir, ".chrome"))
    try:
        cdp = CDP(page_socket())
        cdp.send("Page.enable")
        for shot in shots:
            shoot(cdp, url, out_dir, shot)
    finally:
        proc.terminate()


if __name__ == "__main__":
    main()
