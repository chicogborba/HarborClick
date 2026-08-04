# Runtime source map

Runtime code is organized by responsibility:

- `autoload/` — cross-scene services and persistent global state.
- `core/` — low-level schemas/contracts with no presentation.
- `data/` — declarative catalogs.
- `economy/` — formulas and deterministic simulation.
- `cargo/` — identity, transactions and movement policy.
- `npc/` — the crew, their stations and the task board that assigns them.
- `events/` — rare interruptions: special calls and their minigames.
- `world/` — scene composition and physical presentation.
- `ui/` — controls, overlays and responsive composition.
- `progression/` — career, achievements and contracts.
- `fx/` — small visual effects.
- `main.gd` — playable-screen composition root.

Dependency direction is data/core → policy → world → UI. Autoloads are services,
not a default home for convenience functions. Before adding a new global,
check whether the owner can be a regular node or pure `RefCounted` class.

See `docs/architecture/overview.md` and the README inside the target directory.

