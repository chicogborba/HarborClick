# Cargo flow and invariants

`CargoUnit` is the source of truth. A sprite on a ship, truck or yard stack is
only a view of a UID that has one owner.

## Entry paths

1. Ship call: `BerthCallController.seed_new()` creates the inbound manifest
   off-map, then `Ship` carries it into view.
2. Public road: `GateDock._call_a_truck()` creates city-origin units before a
   `RoadTruck` enters the map.
3. New profile: `ContainerYard.seed_new()` records the inaugural city convoy
   that arrived before the first shift.
4. Legacy v2 migration: `ContainerYard.restore_saved()` performs one city
   retrofit before the scene is visible, then persists v3.

No other runtime code may create yard cargo.

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

Regression owners: `tests/cargo_test_runner.gd`,
`tests/gate_test_runner.gd`, `tests/automation_test_runner.gd`, and
`tests/traffic_test_runner.gd`.
