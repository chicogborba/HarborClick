# World domain

A tap and a press-and-hold are two verbs sharing one press, and `PortWorld`
owns the decision between them: `GRAB_HOLD` of finger-down on somebody lifts
them off the ground, anything shorter opens their badge on release, and
`GRAB_SLOP` of travel makes it the camera's drag instead of either. Only
`StructureActor.is_person()` can be picked up — somebody on foot, not a crewed
machine. While anyone is in the hand the world emits `npc_grab_changed` and Main
stops the camera answering drags, or the yard slides one way under the person
sliding the other.

`PortWorld` is the composition root for the terminal. The quay carries up to
`PortLayout.BERTH_MAX` berths — `ships` and `berths` are the arrays, and `ship`
and `berth` are berth 0, the names the focused suites use. A harness that builds
only `ship` still works: `berth_hulls()` treats it as the one-berth port it is.

Berths share one channel and **nothing ever passes in it**. An 80-px channel
does not fit two 66-px hulls, and no offset makes it: a hull held clear of a
moored one would end up off the map, so "passing outboard" is one ship sliding
through another with its edges showing. The hull is drawn **bow up**, so it can
only steam toward negative y: the channel runs south → north, `channel_entry_y`
is below the world and `channel_exit_y` above it, and `phase4_ship` measures the
actual PNG to keep those two facts tied together. They came apart once already.
`lane_clear_north/south` answer whether
the run is possible; when it is not, `Ship.arrive/depart` take the seaward route
to `PortLayout.OFFING_X` instead, which stays on the berth's own line and so can
never cross anybody. Only one hull manoeuvres at a time either way.

It creates the yard, the hulls and their berth controllers, the gate, the traffic
coordinator, the structures, the water, the atmosphere and the ambient actors,
then wires their signals.

Major owners:

- `container_yard.gd` — physical slots, reservations, UID stacks and manifest.
- `ship.gd` — vessel view, bays, phases and interaction presentation.
- `road_truck.gd` — visible public-road trip and longitudinal bed cargo.
- `rail_rake.gd` — the train on the branch, and the run-around shunt that gets
  its locomotive to the other end. It owns no cargo: `RailYard` does, and the
  rake reports back at three moments so the controller never has to guess where
  a train is. The signal, the crossing wig-wags and the ramp board are built and
  driven by `PortWorld._build_rail` / `_drive_rail_furniture` off the same
  service state, so nothing on the ground can claim something the branch is not
  doing.

  The rake also carries the fx that make the trip down there worth taking: a
  headlight that leads the train, an exhaust plume metered off *measured* speed
  (the shunt and the run move the loco on different axes at different rates, and
  the plume answers to both without either knowing about it), brake smoke thrown
  under the bogies at the stand, and three different wagon types dealt by slot —
  `WAGON_DEAL`, not `slot % 3`, so no two coupled vehicles match and a restored
  service comes back the same train. The smoke is a fixed reused pool: it runs
  for the whole of every journey, and a per-puff node would make the rake the
  only thing in the world churning the scene tree once a frame.

  Sound is the other half of it. `train_horn` before every departure and on the
  run in, `rail_brake` where the brakes actually go on rather than where the
  train stops, `coupling` when the buffers meet at the end of the shunt, and
  `crossing_bell` struck by `PortWorld` on the same clock that drives the
  wig-wag lamps — a baked-in loop would drift out of step with the picture the
  first frame the game dropped.
- `structure_layer.gd` / `structure_actor.gd` — purchased equipment views/jobs.
- `port_layout.gd` — canonical geometry and routes.
- `ground_baker.gd` — generated ground composition.
- `water_foam.gd`, `water_quality.gd`, `atmosphere.gd`, `skyscape.gd`,
  `critters.gd`, `rainfall.gd`, `harbour_signals.gd` — environmental
  presentation. The windsocks and pennants read the same `TimeManager.wind` the
  clock does, so the corner and the quay can never disagree, and they stand where
  a terminal has clear ground — never on the crane rail or in a truck lane.

Keep reusable decisions out of `PortWorld`; it should delegate to cargo/data
policy and coordinate the result. Cargo sprites must reflect a real `CargoUnit`.
Run phase4 ship/water, traffic, rail, wake and visual captures after world work.

Actors that are somebody carry an `NpcProfile` and take their work from
`PortWorld.tasks` — see [`scripts/npc/README.md`](../npc/README.md). Both `crew`
and `tasks` are optional: focused test harnesses build a world without them, so
every actor must fall back to behaving on its own. An actor may only *describe*
its objective; the transaction still belongs to the cargo layer.

The quay crane does not animate on a timer. `BerthCallController.move_started`
hands each real transfer to a free portainer, which drives its trolley over that
box for exactly the flight's duration and parks when there is nothing in the air.

`GroundBaker` also owns the terminal's operational wayfinding: import/export
sector tint, gate directions, drains, service pads, quay safety markings and the
intermodal rail corridor. Scenery props may reinforce those systems but must
never obstruct a cargo slot or a vehicle route.

Mooring lines are ropes, not lines: a head line and a stern line, led from the
fairleads `gen_ship.py` actually draws down the port bulwark to the bollards
`PortLayout` actually places, and thrown over about a second rather than
appearing. Two, dark and near taut — the first version had four pale hemp lines
with a generous sag and, on a 66-px hull seen from above, they crossed each other
and read as spaghetti. Tarred rope with a shallow catenary reads as mooring. `moorings_visible()` reports whether
the ship is *made fast*, not whether the ropes are still on screen — letting go
is instant, hauling them back aboard is an animation, and berth state must never
wait on one.

Weather: `TimeManager` rolls fog and rain, and rain is deliberately visual only —
fog already carries the throughput penalty, and a second weather with a second
penalty quietly halves the port on a bad day. `Rainfall` draws it (each drop
carries the height it lands at, so splashes happen across the port rather than on
the world's bottom edge) and `Atmosphere` supplies the overcast grade and strikes
the masts early.

Everything standing on the ground drops something to the lower right, because the
light in this game comes from the upper left everywhere: the hull, the bottom box
of a yard stack and the bollards on the quay. Boxes packed in a hold are the
exception — the deck rows are eleven pixels apart and a box is thirteen tall, so
an offset copy lands on the box below it and the hold turns into dark bands. That
offset is the whole difference between flat 2D and a top-down view with depth.

Water is worked by every hull, moving or not. `_feed_water_shader` hands the
shader one rectangle per visible ship, and a lap of disturbed water runs along
each of them — peaked a few pixels *out*, because the first three are under the
hull's own contact shadow and a band brightest at zero is a band nobody sees. A
berth is what the player looks at almost all of the time; before this the surface
only moved during the five seconds of an arrival.

The half-length handed to the shader is *that hull's*, not the berth envelope:
once classes had their own lengths, a fixed 116 px drew the bow wave up to forty
pixels off the end of the ship it belonged to.

The wake is three things, and the middle one is what makes a hull read as
*cutting*: a bow wave leaving the stem at a fixed angle, a collar of disturbed
water dragged along the sides, and a widening V astern with transverse crests
curved back inside it. All of it lives in `water_top.gdshader`, driven by
`ship_speed`, which is measured from the hull actually moving.

`FlyingContainer` is the sole visible cargo hand-off. Origin views refresh as
soon as the flight is prepared, and destination views do not appear until its
impact animation has hidden the travelling sprite. Transfer coordinates are
global visual centres: ship variant transforms and exact longitudinal truck-bed
slots are resolved before `PortWorld` converts them into the overhead layer.

`CargoRelay` extends it into the chain of custody, and `PortWorld.fly_cargo` is
where the choice is made. A relay is three legs — a gantry lifts the box onto the
apron, a tractor drives it to the block's driving lane, the transtainer that owns
those stacks puts it away — and each leg belongs to a machine the player bought.

Three rules make it safe to put a real fleet between a transfer and its commit:

- **The chassis is booked when the itinerary is drawn.** No tractor free, no
  relay: the box takes the plain arc at the old speed. So the number of boxes
  being driven equals the number of machines free to drive them, a tap never
  queues behind the fleet, and buying another tractor is visible rather than
  merely counted.
- **Every failure funnels into that same arc** — a machine freed mid-leg, a
  tractor boxed in past `RIDE_DEADLINE`, a traveller force-landed by the capture
  harness. The presentation is allowed to fail; the transaction is not.
- **Wheeled machines lead, gantries follow.** A tractor owns its leg and the box
  rides its chassis (`relay_bed_position`/`relay_bed_rotation`, so the load lies
  along the direction of travel); a gantry shadows a leg the relay is pacing,
  clamped to its own reach. Only one of the two can be driving the box at a time.

`PortLayout` owns the three places a hand-off may happen — `quay_interchange`,
`block_interchange`, `gate_interchange` — plus `depot_slot`, the numbered rank
where terminal plant stands between runs. A machine with a depot is visible
always; a road-plated one (reach stacker, empty handler) is off-site until a job
drives it in. That distinction is the whole difference between "I bought a
tractor" and "nothing happened".

Run the relay suite after touching any of it.

## One GitHub hull source

`gen_ship.py` again matches `origin/main`: one 66x232 `ship_top.png`, bow at the
top, twelve cargo rows from y=44 and the accommodation block near the bottom.
The catalogue's Feeder/Panamax/New Panamax entries scale and recolour that same
texture; they do not swap in class-specific PNGs or change the 24-box berth
grid. Newer route class names are compatibility aliases onto those three views.

`Ship.BAY_Y0`, the deck-light coordinates and the wake shader use that source
coordinate system. The local multi-berth manoeuvre and transactional cargo code
remain intact: restoring the GitHub art contract does not roll back gameplay
owners or cargo identity.

## A road rig is two bodies

`RoadTruck` is a tractor and a chassis, articulated on the fifth wheel, and it
drives on its nose: velocity is `heading * cruise`, never the direction of the
next waypoint. Both of those exist because of the same bug. The first version
moved along the waypoint direction while its rotation eased towards it, so
through a corner the body pointed one way and the vehicle travelled another and
the boxes looked like they were sliding a beat behind the wheels. A rig that only
ever moves forwards cannot do that, and boxes parented to the chassis cannot lag
it — the failure stops being something to tune and becomes something that cannot
be expressed.

Two consequences worth knowing before touching the driving:

- The trailer's rear axle is **state**. Deriving it from the trailer's heading and
  the heading from it is a fixed point, and the trailer stays rigidly in line.
- A steered vehicle cannot land on a point, so a waypoint is taken when it is
  within `ARRIVE_RADIUS` **or** has gone behind the nose inside `PASS_RADIUS`.
  Without the second, a mark the rig sweeps past just outside the radius becomes a
  roundabout it circles for ever. The last waypoint of a route snaps, because a
  painted bay wants to be exact.

`cargo_relay.gd` is presentation over a transaction, and the transaction always
wins. Two ceilings enforce it: `APPROACH_GRACE` bounds how long a box may rest
on the apron waiting for a tractor that was booked but has not arrived, and a
per-itinerary watchdog bounds the whole trip against the length the relay itself
priced. Both exist because the berth counts a transfer as in flight until it
lands — so a box that waits is a ship that cannot change phase and a tap that
does nothing. `tests/relay_test_runner.gd` books a tractor that never turns up
and asserts the box still lands promptly.
