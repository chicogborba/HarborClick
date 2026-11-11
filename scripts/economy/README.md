# Economy and progression

- `foreman.gd` — pure standing-order policy for *spending*: what the port buys
  when nobody is looking. Off until the first rebuild, because rule 7 asks what a
  reset opens and prestige used to open nothing but a multiplier. The reserve is
  the design, not a convenience — without it an auto-buyer holds the wallet at
  zero and land, upgrades and charters stop being reachable, so choosing the
  reserve *is* the strategy. One purchase per tick: clearing the treasury the
  instant it can afford anything deletes the moment the genre runs on. Ticked by
  `GameState._tick_foreman`; never buys land.
- `economy_math.gd` contains reusable formulas.
- `economy_catalog.gd` exposes canonical economy data.
- `economy_simulator.gd` runs deterministic scenarios and is the only telemetry
  a single-player offline game gets, so it models the economy that is actually
  played: structures **and** upgrades, taps priced from the real `click_power`
  (crit expectation included, no RNG), prestige that resets the port and banks
  golden shares, the shares spent on the capital tree, the 75% rebuild discount,
  and absences paid at the offline efficiency up to the offline cap. A scenario
  declares a session/absence cycle instead of pretending the player never
  closes the game. Anything it does not model is listed at the top of the file.
  Do not add a knob that stands in for a system — model the system, or the
  numbers describe a game nobody plays.
- `progression/progression_manager.gd` tracks achievements, contracts, career
  totals and its own save section.

## The sandbox and the game share their formulas or they are worthless

Since the upgrade catalogue became a graph, three things depend on how many of
some *other* machine the port runs — synergies, conductors and the capital
tree's breadth node. That put two obligations on this directory:

- **One implementation of the pay-per-unit curve.** `GameState` and
  `EconomySimulator` both call `EconomyMath.saturating_bonus`. Anything that
  reimplements it locally will drift, and a sandbox that has drifted reports a
  curve for a game nobody is playing.
- **`EconomySimulator` refreshes its derived cache after a *structure* purchase,
  not only after an upgrade.** Before those kinds existed that line was genuinely
  unnecessary. Now a unit of one machine can move another's rate, so leaving it
  out quietly freezes the economy mid-run — which is much worse than crashing,
  because the numbers still look plausible.

`build_wide` and `build_tall` are the composition pair: identical scenarios but
for which half of the tree the agent commits to. They exist to keep item 4 of the
plan honest, and what they can and cannot prove is written down there rather than
asserted loosely in the test.

Keep formula code pure and deterministic — **no autoloads**, which is why
`BREADTH_MIN_COUNT` lives in `economy_math.gd` and not on `GameState`.
Presentation reads calculated state; it does not duplicate costs or rates. Any
balance change should run phase3 economy/progression, route tests,
`tools/balance/run_balance.gd -- all` and `tools/balance/week_report.gd`.

## Pacing: a week

The game is paced so a casual player — five ten-minute check-ins a day
(`casual_week`) — opens most of the catalogue over seven days, and someone who
keeps it open (`engaged_week`, eight half-hours a day) not before day four.
`week_report.gd` prints the day each machine and parcel is first bought. As
tuned: casual opens the armazém on day 1, rebocador/trem day 3, flutuante/
alfândega day 4, torre/drone day 6, porto IA and the portal day 7; the first
rebuild pays on day 2. The levers, in the order they matter:

- **Frontier paybacks** (`StructureDB`/`EconomyCatalog`, kept identical): from
  the reach stacker up they stretch 240 s → 8600 s. The frontier machine is what
  compounds; at 180–2400 s the catalogue was finished on day 4.
- **Prestige**: `PRESTIGE_DIVISOR` 1e10 and a cube-root meta multiplier. With a
  square root the reset loop compounded to ×500 in a week.
- **Level unlocks** (`TerminalLevel.UNLOCKS`) run to level 18 (~day 3), the
  rebuild at 14 (~day 2), instead of all arriving in the first hour.

## Why level up, why take a challenge

Every loop has to pay into another one, or the player is right to ignore it:

- **Levels** open features up to 18, and *every* level also pays +2% production
  (`GameState.level_multiplier`, "Nível" in the rate breakdown) and a wheel
  token. Levels 19-30 used to pay nothing at all.
- **Achievements** pay Terminal XP (40, or 80/160/240 for the bigger ones) on
  top of +1% production each. They used to promise "coleção" cosmetics and
  "carreira" points that existed nowhere in the game.
- **Daily missions** pay a wheel token each (+40 XP), all three a x3 surge.
  They unlock at level 7, after the gull and the wheel they can ask for.
- **Contracts** pay 180-360 s of production for a 5-10 min window (was 60-120 s,
  less than the window itself earned). "Produce TEU" is measured in seconds of
  the port's own rate, not a fixed 30-90 TEU a grown port finished instantly.


## Roda da Sorte

`lucky_wheel.gd` (`LuckyWheel`) is the rules and nothing else: eight segments
with weights that sum to 100, one free spin every four real hours, a token for
every third ship that leaves (at most nine banked). Every moment comes in as a
`now_unix` argument and every roll from a caller's RNG, so the suite fakes both.

`wheel_service.gd` (`WheelService`) is the live node `Main` creates first. It
owns the wheel, persists it as the `lucky_wheel` save section, hears
`EventBus.ship_departed`, and is the only thing that lets a prize touch the
economy.

- **Decided at the spin, paid at the reveal.** `spin()` picks the segment and
  holds it as `pending`; the panel animates to it and calls `claim_and_apply()`
  when it stops, when it is closed early, or — if a reload caught it — on
  restore. A pending prize blocks the next spin, so one can never overwrite
  another, and it is applied exactly once.
- **Priced in the port's own income.** Cash is `max(base_cps, 0.5) × seconds`
  through `grant_nonproductive_reward` (it never counts toward prestige), and
  base rather than surged cps, so a spin during a frenzy does not pay 7× cash.
  Surges go through `GameState.grant_surge`, where the strongest one wins.
- **Meta, not run.** Tokens and the free clock survive a prestige.
