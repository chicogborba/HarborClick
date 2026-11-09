# HarborClick agent guide

HarborClick is a Godot 4.7 mobile-first container-terminal game. Read
[`docs/README.md`](docs/README.md) before exploring source files. It routes work
to the smallest relevant subsystem and links the generated whole-repository map.

## Five-minute orientation

1. `project.godot` defines autoloads and starts at `scenes/Title.tscn`.
2. `scripts/main.gd` composes the playable screen.
3. `scripts/world/port_world.gd` composes the physical terminal.
4. `scripts/cargo/berth_call_controller.gd` owns ship transfers.
5. `scripts/cargo/gate_dock.gd` owns public-road truck transfers.
6. `scripts/autoload/save_manager.gd` owns versioned persistence.

Do not scan the whole repository to find a feature. Use
[`docs/reference/code-map.md`](docs/reference/code-map.md), then read the
README in the target directory.

## Non-negotiable gameplay contracts

- A container is a `CargoUnit` identity before it is a sprite.
- Cargo enters through a ship manifest, a visible road vehicle, a visible rail
  service, or the pre-session new-profile/legacy migration seed. It never
  appears during the live yard loop.
- A ship cannot reload a UID from its own inbound manifest. A later ship can.
- Road plans are inventory-neutral or inventory-positive.
- Road collection protects `RoadCargoPolicy.MIN_OPERATIONAL_STOCK` (24 boxes).
- Rail plans have `drops >= lifts` below `DRAIN_FILL`, a rake is never worked
  while it is moving, and no `GameState.rail_order` may suppress the clearing
  service — `DRAIN_FILL` is read before the standing order is, so a jammed yard
  always gets the run that unblocks it.
- A transfer changes ownership only when its `CargoTransfer` commits.
- Save/reload must preserve every UID exactly once.
- Presentation may fail; a transfer may not. `CargoRelay` puts real machines
  between a box and its commit, and every way that can go wrong falls back to the
  plain arc rather than holding the transfer open.

Product judgement — "is this good?" as opposed to "what is left?" — lives in
[`docs/design/principios.md`](docs/design/principios.md). Read it before adding
anything a player is meant to *feel*.

Read [`docs/architecture/cargo-flow.md`](docs/architecture/cargo-flow.md) before
changing cargo, gate, yard, ship, truck, or automation code.

## Change routing

| Change | Start here | Required focused tests |
|---|---|---|
| Cargo identity or berth | `scripts/cargo/README.md` | cargo, automation |
| How a container is *seen* moving | `scripts/world/README.md` | relay, cargo, capture |
| Crew, tasks or NPC dossiers | `scripts/npc/README.md` | npc, cargo, traffic |
| Special calls or minigames | `scripts/events/README.md` | special, cargo |
| Truck/gate/yard balance | `scripts/cargo/README.md` | gate, cargo, traffic |
| The branch line, the rake or its shunt | `scripts/cargo/README.md` | rail, cargo, capture |
| World visuals or actors | `scripts/world/README.md` | phase4 ship/water, traffic, capture |
| UI, title, responsive layout | `scripts/ui/README.md` | ui_p0, a11y, contrast, capture |
| Save/profile/migration | `scripts/autoload/README.md` | core, backup, profile |
| Economy/data/progression | `scripts/economy/README.md` | phase3, route |
| Generated art/audio | `tools/README.md` | regenerate, capture |

## Commands

```bash
# Parse/import check
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit

# One command for documentation freshness + every headless suite
tools/qa/run_all.sh

# Mobile visual QA
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  tools/capture/capture.tscn -- matrix

# Rebuild generated source map after adding/moving code
tools/venv/bin/python tools/docs/generate_code_map.py
```

Set `GODOT_BIN` when Godot is installed elsewhere.

## Editing rules

- Prefer pure `RefCounted` policy classes for rules and Nodes for presentation.
- Keep `PortWorld` as composition/orchestration; move reusable decisions out.
- New persisted state needs snapshot, restore, new-profile seed, migration, and
  a reload regression.
- New cargo creation needs an explicit off-map or manifest origin and a UID.
- Do not edit generated PNG/WAV assets by hand. Edit `tools/sprites` or
  `tools/audio`, regenerate, and commit generator plus output.
- The few model-generated illustrations live behind `tools/sprites/pixellab`:
  edit the recipe, refetch with a key, commit prompt and answer together. The
  build itself never calls the API and must stay that way.
- Keep pixel textures nearest-neighbour and UI text on `UiTheme` surfaces.
- Update the nearest subsystem README when a contract or entry point changes.
- Run `tools/docs/generate_code_map.py --check` before handoff.

## Deployment

The Web preset writes `build/web/index.html`. `build/*`, `tools/*`, and
`tests/*` are excluded from the game pack. Production requires COOP/COEP/CORP
headers for Godot Web; see `deploy/docker-compose.yml` (Traefik labels) and
[`docs/architecture/testing-release.md`](docs/architecture/testing-release.md).

