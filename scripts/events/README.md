# Events domain

Rare, interrupting, refusable things. Today that is three families: the special
call, the golden gull, and the Receita Federal's X-ray inspections.

- `special_call_director.gd` — the clock and the state machine. When a charter is
  offered, which berth takes it, when the minigame is cued, what a result pays.
  Persisted as the `special_calls` save section.
- `stack_game.gd` — the rules of the stacking minigame, with no nodes in them, so
  a suite can play whole games headless.
- `maze_game.gd` — the rules of the yard-maze minigame, carved deterministically
  from the charter's own seed with its own generator (touching the global RNG
  here would make every other seeded thing depend on how a minigame was played).

Data lives in [`scripts/data/special_call_db.gd`](../data/special_call_db.gd);
the screens are [`scripts/ui/special_call_alert.gd`](../ui/special_call_alert.gd)
and the two boards built on
[`scripts/ui/minigame_board.gd`](../ui/minigame_board.gd) —
`crane_minigame.gd` (timing) and `maze_minigame.gd` (navigation). A charter names
its game in `SpecialCallDB`; `Main._open_minigame` opens the board that plays it.

## The flow

```
idle -> offered -> (accepted) -> booked -> alongside -> minigame -> resolved
                \- (declined/expired) -> idle, on a shorter cooldown
```

`booked` is the interesting state: the next call seeded at a free berth becomes
the special one, so the charter's vessel **arrives up the fairway** instead of
appearing alongside. The minigame is cued by that vessel berthing, never by the
acceptance — the player agreed to it, then watched it come in, and only then is
asked to do the job.

## Rules this domain keeps

- **Rare or it is not an event.** Minutes of cooldown, one offer on the table at
  a time, nothing at all before the terminal has something worth staking.
- **Priced in the port's own income.** A prize is a multiplier for a window or a
  number of seconds of cps; a forfeit is the same in reverse. Never a flat number
  that is enormous in the first hour and invisible in the tenth.
- **A burst is session-scoped.** `GameState.surge_*` never survives a reload:
  one that did could be banked, and banking a 10× multiplier is not a reward, it
  is an exploit.
- **A forfeit cannot reach into debt.** `GameState.apply_fine` takes what is
  there and reports what it took.
- **Nothing half-happens.** A charter interrupted by a reload or a prestige is
  abandoned: no prize, no forfeit. A minigame caught mid-play comes back as one
  still to play, because half a burst of input cannot be restored honestly.
- **A game must be winnable.** The maze is carved with a backtracker, so every
  cell is reachable from the gate — a maze that walls off a crate is a charter
  that can only ever fine you. The suite checks it over forty seeds. The X-ray
  draws every crate in its own cell: contraband that showed only through a
  tool is a scan that can only be lost by whoever did not find the tool.
- **One event at a time.** `SpecialCallDirector.can_run` (set by `Main` from
  `_event_boards_busy`) holds the offer clock while a board or the tour is up,
  and a charter that berths behind one waits in `Main._queued_charter` and
  plays the moment the coast is clear. The X-ray clock holds the same way. An
  offer once on the table still expires on its own — waiting never holds the
  player hostage either.
- **The director never touches cargo.** The special hull is a variant handed to
  `BerthCallController.seed_new`, which still mints every UID.

## Gaivota dourada

The rare thing that needs no berth: every few minutes a golden gull carrying a
parcel crosses the visible part of the terminal for about nine seconds. Tapping
it pays a prize; letting it fly off costs nothing.

- `golden_gull_policy.gd` — the clock and the prize table. Pure rules, and
  **session-scoped, deliberately NOT persisted**: a reward clock that survived
  a reload could be farmed by reloading (quit a second before the gull, come
  back to one already owed) — the same reason `GameState.surge_*` never
  survives a reload. Nothing in it is registered with `SaveManager`.
- `golden_gull.gd` — the presentation: the flight across the visible rect, the
  fixed sparkle pool, the catch burst. `PortWorld` owns the spawn (in the
  `overhead` layer) and taps the gull before anything else in `_try_tap`;
  `Main` applies the prize — `cash` through `grant_nonproductive_reward`,
  `surge` through `grant_surge`, `token` through `WheelService.grant_token`.

Run the `gull` suite after changing anything here.

## Receita Federal: o scanner de raio-X

Leôncio, auditor da Receita, takes Alisson's first tip slot after the tour and
says the port needs an X-ray scanner; his tip closing opens the scanner's
board. Bought, it calls an inspection every five to nine minutes of play.

- `xray_policy.gd` — price (seconds of base income, floored), the inspection
  clock, the Benefício Fiscal (a `grant_surge`, bigger for a clean scan) and
  the counters. Pure rules. **Persisted** as the `xray_scanner` section: a
  clock that reset on load would re-arm its short first delay every session.
  A due inspection stays due until `resolve`, so a board caught by a reload
  comes back to be played. Meta progress — a prestige does not take it back.
  `seed_new` (new profile, and any save from before the scanner) is "not
  bought".
- `xray_scan.gd` — one scan: a jittered 5x2 grid of goods in the container and
  one contraband (pistol, rifle, taped bricks, grenade), dealt from the
  inspection's own seed with a local generator. **One picture, one verb**: the
  board draws every crate in false colour at reading size — the only hidden
  thing is *which*, never *where* — and the player taps it. Wrong taps cost
  `WRONG_PENALTY` once per spot; decoys shaped like weapons (hair dryer,
  drill) join from `DECOY_LEVEL`. Items never overlap, so every scan is
  winnable — the suite checks it over forty seeds.
- `xray_service.gd` — the node: registers the section, ticks the clock while
  `Main._xray_clock_runs` (after the tour, no board open), takes the money and
  grants the benefit. A loss costs nothing; a lost scan may be retried once for
  a `minigame_retry` rewarded ad, like the charters.

Run the `xray` suite after changing anything here, and the `tour_receita`,
`tour_xray_due`, `xray_panel`, `xray_roll`, `xray_boot`, `xray_scan`,
`xray_miss` closeups.

Run the `special` suite plus `cargo` and `phase3_progression_ui` after changing
anything here, and the `charter` / `minigame` captures for the two boards.
