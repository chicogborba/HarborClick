# Cargo domain

## Owners

- `cargo_unit.gd` — one traceable container identity.
- `cargo_transfer.gd` — prepare/commit/rollback ownership transaction.
- `cargo_inventory.gd` — compact inventory helper.
- `berth_call_controller.gd` — ship-call workflow and rewards.
- `gate_dock.gd` — public-road truck workflow.
- `road_cargo_policy.gd` — pure non-deficit/reserve policy.
- `traffic_coordinator.gd` — lanes and minimum separation.

## Rules

- Never add cargo directly to a sprite or stack.
- Create the UID at its manifest/off-map origin.
- Reserve both sides before animation.
- Commit exactly once when the flight lands.
- Preserve/reconcile prepared transfers on teardown and reload.
- Same-hull imports are excluded from loading; later-hull cargo is valid.
- Truck plans have `drops >= lifts`.
- Every road pickup uses the protected path in `PortWorld`.

Read `docs/architecture/cargo-flow.md`. Run cargo, gate, automation and traffic
after any change in this directory.

