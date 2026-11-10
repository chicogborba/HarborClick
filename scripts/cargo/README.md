# Cargo domain

## Carga premiada (reefer)

One box in every ~12 of an inbound manifest (`BerthCallController.PREMIUM_EVERY`)
is `CargoUnit.premiada` — a property of the manifest, assigned at seed time, so
it is deterministic per call and persists through `snapshot()` (old saves read
as not premiada). It gleams on the deck and pays `PREMIUM_MULT` (×5) when
discharged: the base quote is paid as always (at the finger for a tap, at
landing for an automated move), and the remaining 4× is committed at landing
under the derived transaction id `"<transfer_id>:premiada"`, so a reload between
the two can neither double-pay nor lose the bonus. This replaced the invisible
3% crit: `GameState.CRIT_CHANCE` is 0, and the `crit` flag survives in quotes
only for save compatibility and premiada display.

## Owners

- `cargo_unit.gd` — one traceable container identity.
- `cargo_transfer.gd` — prepare/commit/rollback ownership transaction.
- `cargo_inventory.gd` — compact inventory helper.
- `berth_call_controller.gd` — ship-call workflow and rewards.
- `gate_dock.gd` — public-road truck workflow.
- `road_cargo_policy.gd` — pure non-deficit/reserve policy.
- `rail_yard.gd` — branch-line service workflow: one rake at a time, worked only
  while it stands, and a run-around before it can leave a stub siding.
- `rail_cargo_policy.gd` — the road's policy at a train's scale, sharing its
  operational floor exactly, plus the branch's standing order. `GameState.rail_order`
  picks between `equilibrio` (follow the yard), `abastecer` (run in full, take a
  token load back) and `escoar` (work every wagon both ways). The order biases
  the exchange and cannot break it: `DRAIN_FILL` is read *before* the order, so
  a jammed yard still gets the clearing service that unblocks it whatever the
  player selected. The shop's orders board is where it is set, and
  `RailYard.report()` is the only readout the branch has — it runs along the
  bottom of the world where the camera never goes.
  - **The baselines live here; what the player bought does not.** Rake length,
    the service interval, the ramp dwell, the auto-worker rate and cap, and the
    completion bonus are constants in these two files, because they are the rules
    of the branch and have to be readable and testable without a save. The
    `ramal` trunk of the upgrade tree moves them through
    `GameState.rail_stat(stat, base)`, which adds flat before it multiplies.
    Read a fitted figure through `RailYard.dwell_seconds()` /
    `completion_seconds()` / `auto_rate()`, never off the constant.
  - **Rake length is bounded by the ground, not by taste.**
    `RailCargoPolicy.clamp_rake` holds it inside `MIN_RAKE..MAX_RAKE`, and
    `PortLayout.rail_west_turnout_x` is *derived* from `MAX_RAKE` so the
    run-around loop is always long enough to hold the loco clear of the tail of
    the longest rake the shop can sell. Raising `MAX_RAKE` moves the painted
    track with it; hardcoding either figure separately puts the loco on ballast.
- `crane_allocation.gd` — pure standing-order policy: how one gang of bought
  equipment is divided between the berths being worked. Every berth used to be
  handed the whole port's move rate independently, so three hulls alongside
  multiplied the same machines by three and there was nothing to decide about
  them. The pool is `pool_rate() x worked berths` and `EQUILIBRIO` divides it
  back out evenly, so the default is the old numbers exactly; the other orders
  concentrate it. `PortWorld._allocate_cranes` is the only caller —
  `BerthCallController` merely obeys the share it is handed, and falls back to
  the undivided rate when nobody hands it one.
- `traffic_coordinator.gd` — lanes and minimum separation.

## Rules

- Never add cargo directly to a sprite or stack.
- Create the UID at its manifest/off-map origin.
- Reserve both sides before animation.
- Commit exactly once when the flight lands.
- Preserve/reconcile prepared transfers on teardown and reload.
- Same-hull imports are excluded from loading; later-hull cargo is valid.
- Truck plans have `drops >= lifts`.
- Rail plans have `drops >= lifts` below `DRAIN_FILL`, and a rake is never
  worked while it is moving.
- No fitted upgrade may produce a rake outside `MIN_RAKE..MAX_RAKE` or an
  interval the dwell cannot clear — clamp at the call site, always.
- No standing order suppresses the clearing service.
- A completion bonus is settled from committed transfers, never from taps.
- Every road *and rail* pickup uses the protected path in `PortWorld`.

Read `docs/architecture/cargo-flow.md`. Run cargo, gate, rail, automation and
traffic after any change in this directory.

