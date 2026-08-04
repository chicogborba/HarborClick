# Testing and release

## Fast loop

Run the nearest focused suites from `tests/README.md`, then:

```bash
tools/qa/run_all.sh
```

This checks the generated code map, imports the project, and runs every
deterministic headless suite. Cargo changes are not complete without cargo,
gate, automation and traffic.

## Visual QA

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  tools/capture/capture.tscn -- matrix
```

The matrix covers compact/tall phones, tablet portrait, notebook and desktop.
Use focused names (`title`, `world`, `night`, `wake`, `shop`, etc.) while
iterating.

## Web export

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quiet --path . \
  --export-release Web build/web/index.html
```

The preset excludes source-only `tools`, `tests` and `build` directories. The
runtime output is HTML, JS, PCK, WASM, worklets and icons.

The Web preset deliberately does not install a PWA service worker. Saves live
in Godot's browser storage, while releases must stay network-fresh; an older
cache-first worker could otherwise keep serving a previous `.pck` after a
successful deploy. The temporary cleanup in `html/head_include` unregisters
that legacy worker and deletes only `HarborClick-sw-cache-*` entries. Change
its build marker whenever a release needs to force that one-time cleanup.

## Hosting contract

Godot Web requires these response headers:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Resource-Policy: same-origin
```

WASM must be served as `application/wasm`. Stage a new release directory,
verify local/remote checksums, atomically swap the web root, run `nginx -t`,
reload, then verify HTTPS headers and the public PCK checksum. Keep the previous
directory until the new build is confirmed.
