#!/usr/bin/env python3
"""Checks the landing page's markup and its string table agree.

The game's translations are guarded by `tests/i18n_test_runner.gd`; the landing
had nothing, and its failure mode is worse than a blank label. `Loc.t()` on a
missing key returns the key, so a heading renamed in the markup but not in
`i18n.js` publishes the literal text `yard.2.body` to the front page, in every
language, and nothing anywhere says so.

Three things, all of them cheap:

* every `data-i18n` key in the markup exists in the table;
* every key in the table is used by the markup, so dead copy does not
  accumulate behind renames;
* every key has all nine languages, because a gap silently falls back to
  English mid-sentence.

  tools/venv/bin/python tools/qa/check_landing_strings.py
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
HTML = os.path.join(ROOT, "landing", "index.html")
TABLE = os.path.join(ROOT, "landing", "i18n.js")

# Keys the script asks for directly rather than through a `data-i18n` element.
CODE_KEYS = {"doc.title", "doc.desc", "lang.label", "wire"}


def main() -> int:
    html = open(HTML, encoding="utf-8").read()
    table = open(TABLE, encoding="utf-8").read()

    used = set(re.findall(r'data-i18n="([^"]+)"', html))
    used |= set(re.findall(r'data-i18n-label="([^"]+)"', html))
    used |= CODE_KEYS

    languages = re.search(r"const LANGUAGES = \[(.*?)\n  \];", table, re.S)
    codes = re.findall(r'\["([^"]+)"', languages.group(1))

    rows = dict(re.findall(r'^    "([^"]+)": \{(.*?)\n    \},',
                           table, re.M | re.S))

    problems = []
    for key in sorted(used - set(rows)):
        problems.append(f"{key}: in the markup, missing from i18n.js — the "
                        f"page would print the key itself")
    for key in sorted(set(rows) - used):
        problems.append(f"{key}: in i18n.js, used by nothing")
    for key, body in sorted(rows.items()):
        gaps = [code for code in codes
                if not re.search(r"(?<![\w.])" + code + r":", body)]
        if gaps:
            problems.append(f"{key}: no {', '.join(gaps)}")

    if problems:
        print("landing strings: FAILED", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    print(f"landing strings: {len(rows)} keys x {len(codes)} languages, "
          f"all present and all used")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
