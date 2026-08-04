# Events domain

Rare, interrupting, refusable things. Today that is one family: the special
call.

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
  that can only ever fine you. The suite checks it over forty seeds.
- **The director never touches cargo.** The special hull is a variant handed to
  `BerthCallController.seed_new`, which still mints every UID.

Run the `special` suite plus `cargo` and `phase3_progression_ui` after changing
anything here, and the `charter` / `minigame` captures for the two boards.
