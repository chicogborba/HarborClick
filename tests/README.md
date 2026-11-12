# Test suite index

| Suite | Contract |
|---|---|
| core | economy basics, save envelope, wipe |
| cargo | UID ownership, ship calls, reload, 100-call stress, carga premiada: manifest marks 1-in-12, the ×5 is paid once across base + landing tx, UIDs and the flag survive reload |
| gate | non-deficit trucks, 24-box reserve, truck travel |
| automation | berth automation uses the manual transaction path |
| traffic | road-plated machines: lanes, separation and long-run movement |
| relay | the container's chain of custody, and that no failure in it can stall a transfer |
| backup | import/export, rejection and storage |
| ports | a port is paid for, keeps its own books, swaps catalogues and comes home |
| profile | three isolated save slots |
| route | route order, fleet, freight and persistence |
| phase3 economy/progression/UI | balance and career |
| phase4 ship/water | vessel and rendering contracts |
| ui_p0 | HUD, shop and responsive shell |
| a11y / contrast | keyboard, names and readable colors |
| notification | routing, dedupe, priority and history |
| wake | motion-derived wake and shader coordinates |
| npc | crew identity and persistence, one task per key, hull shudder, sound takes |
| special | charter rarity, the special hull, bounded stakes, both minigames |
| rail | branch plans and standing orders, the operational floor, parked-only work, the run-around, the completion bonus, the rake drawn 1:1, ground gate: the corridor is painted only when the land/machine/feature is owned, else a sale board |
| clicks | real mouse events through the viewport on the main scene: every console key opens and Escape closes, the wheel button and GIRAR, a tap on the ship moves a box, a tap on a machine and an upgrade card buys |
| level | Terminal level: XP curve and the minute table it is tuned to, the unlock table, legacy-save migration, prestige survival |
| combo | the tap combo: steps build with a steady hand, a pause lets it fall, a skill can pin it, a payout in it is multiplied once |
| deadline | laytime: the clock is sized from the work, an overstay costs 15% of what that ship earned (never into debt), an early sailing multiplies the freight |
| skills | the Capataz skills: recharge clocks, save clamping, what each does, no early or double use, level gate, ad reset |
| build | purchases stand after a delay: tier durations, the price counts what is still being built, two work at a time, a tap hurries one, an ad finishes one, time away counts, the queue saves, a rebuild clears it |
| adflow | every rewarded-ad placement end to end with a fake provider: wheel spin, doubling a cash prize, the offline return, finishing a build; a refused ad pays nothing |
| telemetry | local opt-in events: opted out is a no-op (no provider call, no file), opted in batches to the provider and mirrors to a capped JSONL on-device |
| fx | pooled effects: fixed pool, lifetime, reduced-motion no-op, whole pixels, camera shake returns to rest |
| ads | rewarded-ad policy and service: daily caps, cooldowns, day rollover, reward exactly once, a failed ad pays nothing, no-ads pass |
| wheel | Roda da Sorte: segment weights, free spin before tokens, a token per third departure, prize priced in base cps, claim-once, reload, prestige survival |
| xray | Receita Federal scanner: scans deterministic per seed, exactly one contraband, always winnable (no overlap), wrong tap costs once per spot, timeout loses, difficulty curve and decoys; price floor, clock (first delay, blocked, waits when due), benefit sizes, streaks; snapshot/restore/garbage and a SaveManager reload; tip speakers and dismiss; the board plays a scan to a win |
| gull | Gaivota dourada: session-only reward clock (first delay, blocked clock, re-arm gaps), prize weights and cash floor, flight escape exactly once, hit/catch, token grant capped at MAX_TOKENS |
| daily | Missões do Dia: the same three missions for the same local day (and variety over 30 days), note() clamping to the goal and ignoring other events, claim-once, the streak with reset and the day-7 extra token, the all-three bonus, claimable count, save round trip and garbage restore, the service paying tokens to the wheel and the surge to GameState |

Run everything with `tools/qa/run_all.sh`. A regression belongs next to the
contract it protects; avoid tests that assert an obsolete implementation detail
when the player-facing invariant is stronger.

## A passing suite has to mean something

A GDScript runtime error does not raise. It prints, aborts the function it
happened in, and returns to the caller as though that function had finished —
so a runner that counts only the assertions it was *handed* will print PASSED
with stack traces sitting above it. That is not a hypothetical: two rail tests
spent a build silently not running, because `preload` was failing on a PNG that
had no `.import` yet, and the suite reported success and exited 0.

Two things guard against it now, and new suites should use both:

- **`run_all.sh` fails any suite whose output contains `SCRIPT ERROR`**, whatever
  that suite's own exit code said. This is the engine's prefix for a parse,
  compile or runtime script fault. It is deliberately not `ERROR`, which is what
  `push_error` emits when a runner reports its own assertion failures.
- **A roll call inside the runner.** `rail_test_runner.gd` lists every test it
  intends to run and each test names itself as its *last* statement; a test that
  aborts never gets there, and the absent name becomes a failure carrying that
  test's own name. Worth copying into any suite whose tests can die on a missing
  resource or a null node rather than on an assertion.

Corollary, learned the same way: after adding a generated asset, run
`Godot --headless --path . --import` before the suites. A brand-new PNG has no
`.import` file, and `preload` on it is a compile error in every script that
mentions it.

