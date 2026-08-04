# Economy and progression

- `economy_math.gd` contains reusable formulas.
- `economy_catalog.gd` exposes canonical economy data.
- `economy_simulator.gd` runs deterministic active/hybrid/offline scenarios.
- `progression/progression_manager.gd` tracks achievements, contracts, career
  totals and its own save section.

Keep formula code pure and deterministic. Presentation reads calculated state;
it does not duplicate costs or rates. Any balance change should run phase3
economy/progression, route tests and `tools/balance/run_balance.gd -- all`.

