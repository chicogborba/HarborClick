# Architecture overview

HarborClick uses a scene-oriented shell with data-first domain objects. The
scene tree presents and animates state; pure or `RefCounted` classes decide
rules; autoloads own cross-scene state.

```text
Title.tscn
  └─ title_screen.gd ── chooses profile ──> Main.tscn
                                              │
                           main.gd (screen composition)
                                              │
                           PortWorld (terminal composition)
                           ├─ ContainerYard
                           ├─ Ship
                           ├─ BerthCallController
                           ├─ GateDock + RoadTruck views
                           ├─ StructureLayer / actors
                           ├─ NpcRoster + TaskBoard (crew and assignments)
                           └─ Atmosphere / water / critters

Autoloads: EventBus · GameState · TimeManager · Progression
           SaveManager · AudioManager · UserPreferences
```

## Ownership boundaries

- `Main` owns screen composition, overlays and camera wiring.
- `PortWorld` owns physical terminal composition and routes work between
  systems. It should not become the home of reusable policy.
- Cargo controllers own transactions and ledgers; sprites are views.
- `TaskBoard` owns *who* is doing a piece of work and never *what happens to the
  box*: it derives needs from live state, hands each key to one claimant, and
  leaves every transfer to the cargo layer. Its one reservation — the land-side
  haul — goes through `PortWorld.request_job`, which is still the only entry.
- Autoloads own state that must survive scene changes.
- `scripts/data` is declarative and must not depend on scene instances.
- `tools` owns reproducible artifacts and QA helpers, never runtime behavior.

## Design direction

Godot scenes and scripts are treated as classes with single responsibilities.
Rules that can be decided without a scene live in pure policy/data classes;
animated consequences live in Nodes. This follows Godot's own scene
organization guidance and keeps AI work localized: find the owner, read its
README and contract tests, then change one seam.

## Dependency direction

```text
data / core / economy policy
            ↓
 cargo policy and transactions
            ↓
 world composition and presentation
            ↓
 UI composition

autoloads provide cross-scene services; EventBus carries notifications upward.
```

Avoid adding dependencies in the reverse direction. In particular, pure policy
must not reference an animated scene class merely to read a constant; pass the
value or move the constant to a neutral owner.

