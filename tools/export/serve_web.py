#!/usr/bin/env python3
"""Serve build/web locally for a quick check.

    python3 tools/export/serve_web.py [port]

Opening index.html straight from disk does not work: the browser blocks the
module fetch, so this serves the folder. The game exports without threads, so
no COOP/COEP are needed (or sent) — sending them would only break ad SDK
iframes later (R4).
"""
import functools
import http.server
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                    "build", "web")


class IsolatedHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> int:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
    root = os.path.normpath(ROOT)
    if not os.path.isdir(root):
        print(f"No build at {root}. Run tools/export/build_web.sh first.",
              file=sys.stderr)
        return 1
    handler = functools.partial(IsolatedHandler, directory=root)
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"HarborClick on http://127.0.0.1:{port}/  (Ctrl-C to stop)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
