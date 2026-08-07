# Cargo flow and invariants

`CargoUnit` is the source of truth. A sprite on a ship, truck or yard stack is
only a view of a UID that has one owner.

## Entry paths

1. Ship call: `BerthCallController.seed_new()` creates the inbound manifest
   off-map, then `Ship` carries it into view.
2. Public road: `GateDock._call_a_truck()` creates city-origin units before a
   `RoadTruck` enters the map.
3. Branch line: `RailYard._call_a_service()` creates interior-origin units on a
   rake that is still off-map, before `RailRake` runs it in.
4. New profile: `ContainerYard.seed_new()` records the inaugural city convoy
   that arrived before the first shift.
5. Legacy v2 migration: `ContainerYard.restore_saved()` performs one city
   retrofit before the scene is visible, then persists v3.

No other runtime code may create yard cargo.

## The yard has a direction

The terminal's gate is west and its quay is east, and the yard between them is
zoned by column, permanently and geometrically — `PortLayout.block_role`:

| Column | Role | Holds | Leaves by |
|---|---|---|---|
| landward (0) | `import` | boxes discharged from a hull | the gate, beside it |
| middle | `buffer` | overflow, and transhipment waiting for its hull | either |
| seaward (last) | `export` | boxes brought in by road | a crane, beside it |

A box is put down where the machine that handles it **next** will want it. That
is what gives the terminal an in and an out:

```text
DISCHARGE   hull -> STS -> apron -> tractor drives WEST -> RTG -> import yard
DELIVERY    import yard -> RTG -> short haul -> gate -> lorry -> city
RECEIVE     city -> lorry -> gate -> tractor drives EAST -> RTG -> export yard
LOAD        export yard -> RTG -> short haul -> STS -> hull
```

So the two long hauls run in opposite directions across the terminal and the two
short ones do not. Before this, `take_exportable` took whatever stack was
tallest, so a load could reach into the import yard standing beside the gate and
drive the box the whole width of the terminal straight past the export stacks
parked under the crane — cargo-correct, and completely incoherent to watch.

Two rules keep it honest:

- **Routing is a preference, never a gate.** `ContainerYard.export_pickup_slot`
  asks seaward, then buffer, then landward, and a berth can always be loaded from
  somewhere. Making the yards a hard rule is what stalled berths before
  transhipment was allowed.
- **Landing is a rule.** `pick_landing_slot` stays inside the sector's own yard
  and a full yard refuses the move. Overflowing an arriving import into the
  export stacks was tried and is worse in a quiet way: it removes the pressure
  that makes buying land mean anything, and it puts a box bound for the gate in
  the yard a crane loads from.

`GroundBaker` paints each block's role and a chevron pointing the way its cargo
leaves, off the same `PortLayout.role_heads_seaward` the routing uses, so the
paint cannot disagree with the traffic.

## Ship contract

```text
ARRIVING → DISCHARGING → WAITING_EXPORT → LOADING → DEPARTING
```

- A call discharges 24 inbound UIDs.
- A call loads 24 different UIDs.
- `ship.import_manifest_uids()` is the exclusion set for that same hull.
- Previous-hull cargo is valid transshipment cargo.
- A transfer reserves origin and destination, animates, then commits.
- Its source view refreshes when the flight is prepared; its destination view
  appears only after the travelling sprite finishes and hides.
- Flight endpoints are the transformed visual centres of the actual source and
  destination slots, including hull variants and longitudinal truck beds.
- Reward and ownership change only on commit.

## Road contract

`RoadCargoPolicy` is the pure decision owner.

| Yard state | Truck brings | Truck may take | Inventory delta |
|---|---:|---:|---:|
| Below target | 2 | 1 | +1 |
| At/above target | 1 | 1 | 0 |

A full yard performs the balanced trip by lifting first, opening one real slot,
then dropping the city box into that slot. A truck never takes its own arrival
UID back.

`ContainerYard.road_pickup_slot()` enforces the second invariant: road traffic
may remove current-call imports first because that hull cannot reload them, but
it may not reduce other cargo below
`RoadCargoPolicy.MIN_OPERATIONAL_STOCK` (24).

## Rail contract

`RailCargoPolicy` is the pure decision owner, and it is deliberately the road's
policy at a train's scale: the same three bands, the same floor.

| Yard state | Rake brings | Rake may take | Inventory delta |
|---|---:|---:|---:|
| Below target | every wagon | half the rake | + |
| Between target and `DRAIN_FILL` | half the rake | half the rake | 0 |
| At/above `DRAIN_FILL` | 1 | every wagon | − |

### The standing order

`GameState.rail_order` is the fourth standing order, beside `crane_policy`,
`route_policy` and the foreman. It biases the exchange above; it may not break
it.

| Order | Rake brings | Rake may take | What it buys |
|---|---:|---:|---|
| `equilibrio` (default) | the bands above | the bands above | the branch follows the yard |
| `abastecer` | every wagon | a quarter of the rake | stock climbs as fast as a train can carry it |
| `escoar` | every wagon | every wagon | twice the moves per booked path, no net stock |

Two rules survive every order, and both are asserted in
`tests/rail_test_runner.gd`:

- **No empty trains.** `drops >= 1` in every band and every order.
- **No order can deadlock the port.** `DRAIN_FILL` is checked *before* the order
  is read, so a jammed yard still gets its clearing service whatever the player
  selected. The drain band exists to break a deadlock that nothing else on the
  map can break; an order able to switch it off would be a way of bricking a
  save.

The order applies to the *next* service. `RailYard.order()` reports what the
train currently at the ramp was briefed with, which is not necessarily what is
selected — a booked path is not renegotiated once the train is on it.

`RailCargoPolicy.MIN_OPERATIONAL_STOCK` *is* `RoadCargoPolicy`'s. There is one
terminal and one stock of boxes; two land-side channels with two ideas of
"enough" would let the quieter one starve the ship the busier one just
protected. Every rail lift therefore goes through `PortWorld.take_road_pickup`,
the same protected path the road and the autonomous machines use.

A service runs `AWAY → ARRIVING → WORKING → RUNAROUND → DEPARTING → AWAY`, one
train at a time, because there is one running line. Only `WORKING` can be worked
— tapped or picked up by `RailYard.AUTO_MOVERS` — so cargo never changes hands
on a moving train.

`RUNAROUND` is a real move, not a state name. The corridor is a stub siding, so
the locomotive uncouples, draws forward past the east turnout, crosses to the
run-around loop, runs back west alongside its own train, crosses at the west
turnout and couples to what was the tail. `RailRake` performs it over the exact
coordinates `GroundBaker._paint_rail_corridor` paints, and
`tests/rail_test_runner.gd` asserts the loco reaches the loop, gets east of its
train first, and comes back down onto the running line.

Every stage the view drives also carries `RailYard.TRANSIT_TIMEOUT`. A branch
that blocked on a train nobody was drawing — headless, or a save restored into a
scene without a rake — would be a service that never ends and a wagon-load of
identities that never come home.

### What a service is worth

Each box pays on the way past, through the same manual-reward transaction the
gate uses. The difference between a rake that was worked to the last wagon and
one that merely turned up is settled *on departure*, in `RailYard._settle_service`:
`booked` (what the plan asked for) against `moved` (ownership changes that
actually committed, counted off `CargoTransfer.commit()` rather than off the
tap that requested them). Equal, and the service pays
`COMPLETION_SECONDS` of current income as career money — the berth's departure
bonus at the third door, and the only reason to chase the last two wagons
instead of letting the dwell run out on them. Short, and the branch says so
instead of going quiet.

### The branch has to announce itself

It runs along the very bottom of the world, below the last row of sheds, and the
camera does not follow it. Everything the player learns about it therefore
arrives through two channels, and neither is optional:

- `RailYard.notice_requested` carries a `kind`, so a refusal (`blocked`), a
  service (`rail`) and a completed composition (`milestone`) are three different
  registers rather than one undifferentiated toast. `PortWorld` passes the kind
  straight through to `NotificationCoordinator`.
- `RailYard.report()` is the single read the shop's orders board renders. It is
  the branch's only instrument; a player who picks a standing order and cannot
  see what it did has not been given a decision.

## The relay is presentation, never authority

`CargoRelay` puts real machines between a transfer's preparation and its commit:
a gantry lifts the box to the apron, a tractor drives it, the transtainer stacks
it. None of that owns any cargo. The transfer is prepared before the first leg
and commits when `landed` fires, exactly as with a plain flight — the relay only
decides how long that takes and what the player watches while it happens.

Three properties keep that safe, and all three are covered by
`tests/relay_test_runner.gd`:

1. The chassis is booked when the itinerary is planned. No free tractor means no
   relay at all, so a move can never queue behind the fleet.
2. Every failure — a machine freed mid-leg, a tractor blocked past its deadline,
   a force-landed traveller — collapses the remaining legs into the plain arc.
3. `landed` still fires exactly once, and the node still frees itself, so
   `tree_exiting` rollback and the reload reconciliation are unchanged.

A relay that could stall would be a container that never commits. That is why
the fallback exists and why it is asserted rather than assumed.

## “Never stuck” proof

- New/v2 profiles have at least one full outbound manifest before play.
- Truck plans never reduce the total manifest balance.
- Autonomous structure pickups use the same protected road-pickup path.
- Current-call imports can leave by road without consuming the next outbound
  manifest.
- The next ship can load the previous ship's imports.

- Rail plans never reduce the total manifest balance below the drain line, and
  rail lifts obey the same operational floor as the road.

Regression owners: `tests/cargo_test_runner.gd`,
`tests/gate_test_runner.gd`, `tests/rail_test_runner.gd`,
`tests/automation_test_runner.gd`, and `tests/traffic_test_runner.gd`.
