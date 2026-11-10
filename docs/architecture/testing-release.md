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
runtime output is HTML, JS, PCK, WASM, worklets, manifest and icons.

The export runs **without threads** (`variant/thread_support=false`), so
cross-origin isolation is not required — and the PWA service worker is now
enabled (`progressive_web_app/enabled=true`, portrait, generated icons,
offline page `index.html`). Saves live in Godot's browser storage
(IndexedDB). The cleanup in `html/head_include` still unregisters the legacy
pre-PWA worker and deletes only `HarborClick-sw-cache-*` caches; bump its
build marker when a release must force that one-time cleanup.

## Hosting contract

No COOP/COEP/CORP are sent any more: requiring them would break rewarded-ad
SDKs that run in a cross-origin iframe (plano-release R4). `deploy/` and
`tools/export/serve_web.py` reflect that. WASM must still be served as
`application/wasm`. Stage a new release directory,
verify local/remote checksums, atomically swap the web root, run `nginx -t`,
reload, then verify HTTPS headers and the public PCK checksum. Keep the previous
directory until the new build is confirmed.

## Platform status (ondas 6–7)

- **Web**: preset sem threads + PWA ligado; export local valida; headers de
  isolamento removidos do deploy. Falta: testar a build servida num navegador
  real (persistência de `user://`, SW, ads placeholder).
- **Android**: preset `Android` em `export_presets.cfg` (retrato travado,
  gl_compatibility, ícones adaptativos gerados, pacote
  `dev.portstack.harborclick`). Ciclo de vida já tratado em código
  (`SaveManager` grava em pausa/foco/voltar). **Pendente: aparelho real** —
  60 FPS em intermediário, pause/resume, área segura. Exportar exige SDK +
  keystore configurados no editor.
- **Perf (R3)**: `tools/capture/perf.tscn -- 1920x1080` PASS no stress
  (p95 6,94 ms contra o budget de 16,67 ms, M1). Falta medir em aparelho
  Android intermediário.

## Automatic production deploy

`.github/workflows/deploy-production.yml` is the production path. Every push to
`main` downloads the checksum-pinned Godot 4.7.1 editor and Web templates, runs
`tools/qa/run_all.sh`, assembles `build/release/`, then sends that immutable
release to the VPS through SSH.

GitHub Actions authenticates with the repository secret
`HARBORCLICK_DEPLOY_KEY`. The matching server account is unprivileged, the SSH
host key is pinned in `deploy/known_hosts`, and the workflow token itself has
read-only repository permission. `deploy/remote_release.sh` validates the
archive before atomically switching `/var/www/harborclick-deploy/current`.
Failed tests, exports, uploads, or validations leave the current production
release untouched.

The full server bootstrap, release layout, and rollback contract are documented
in `deploy/README.md`.
