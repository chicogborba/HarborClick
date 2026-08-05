# Landing page

Static front door for the public Web release. The landing lives at `/`; the
Godot export lives at `/jogar/`. It deliberately has no runtime dependency or
external font so the first page stays fast on mobile connections.

`tools/export/build_release.sh` assembles both surfaces under `build/release/`.
The Web server must still send the COOP/COEP/CORP headers documented in
`docs/architecture/testing-release.md`, because the Godot game shares the same
origin.
