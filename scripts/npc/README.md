# Crew domain

The people who work the terminal, and the board that decides what each of them
is doing. Nothing here can create, destroy or move a `CargoUnit`.

- `npc_catalog.gd` — the roles, the station each one stands at, the one-line
  reason the job exists, the name pools and the seeded special characters.
- `npc_profile.gd` — one person: name, role, hire date (port day and calendar
  date), dossier, helmet colour, tally. Serialisable.
- `npc_roster.gd` — the payroll, keyed by station slot (`"sts#0"`) so the
  operator survives every rebuild of the machine they operate. Persisted as the
  `npc_roster` save section.
- `task_board.gd` — needs derived from live world state, and one owner per need.

## Why the crew is short

The port is a chain with a small number of links, and each link is one person's
station:

```
mar -> [berço] portêiner -> [pátio] conferente -> [pilha] transtêiner
    -> [estrada] motorista -> [portão] despachante -> [cidade] carreteiro
```

plus `manobra` for the tug that puts the hull alongside, and the same chain
backwards for a box that is being exported. `NpcCatalog.ROLES` staffs exactly
those stations. A warehouse, the radar tower, the AI hub, the portal, the train
and the survey drone are infrastructure: they work, they are simply not
somebody, and `NpcCatalog.has_crew` returns false for them.

`StructureLayer.CAPS` was lowered to match. Buying more equipment makes the port
faster; it must not turn the yard into a crowd nobody can follow.

## The two rules of the board

1. **A need has a key, and a key has one claimant.** Keys name the physical
   thing being worked — `pilha:bloco3`, `portao:baia1`, `estrada:patio47` — so
   two people cannot be given the same job. Not checked afterwards: there is
   only one key.
2. **The board does not move cargo.** `BerthCallController`, `GateDock` and
   `PortWorld` remain the only owners of a transfer. The board says who is doing
   it and can put that in Portuguese on a card.

Needs are derived on every call and never stored, so the board cannot drift from
the terminal it describes. Claims are weak references, pruned when an actor is
freed, so a rebuild cannot leave a station starved.

The one exception is the land side: describing a delivery means reserving yard
capacity, so it is claimed through `claim_haul`, which also feeds the claimed
identities back into `PortWorld.request_job`. That is what stops two drivers
being sent to the same stack — the second used to arrive and find nothing.

## Adding a role

Ask what would stop happening in the port if nobody did it. If there is no
answer, it is scenery and it does not belong here. If there is, give it a
station, a duty line, and a need generator in `TaskBoard.open_needs` whose keys
are scoped to a physical place.

Player-visible strings are drawn with a hand-made bitmap font: check new text
against `assets/fonts/harbor_font.fnt` — it has `-`, `•`, `→` and `▸`, and no em
dash or middle dot. `tests/npc_test_runner.gd` fails the build on a character it
cannot draw.

Run the npc suite plus cargo, gate, traffic and automation after changing
anything an actor does, and the `crew` capture for the dossier layout.
