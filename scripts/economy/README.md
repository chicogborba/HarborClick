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

Keep formula code pure and deterministic. Presentation reads calculated state;
it does not duplicate costs or rates. Any balance change should run phase3
economy/progression, route tests and `tools/balance/run_balance.gd -- all`.

