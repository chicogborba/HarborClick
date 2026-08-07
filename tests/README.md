# Test suite index

| Suite | Contract |
|---|---|
| core | economy basics, save envelope, wipe |
| cargo | UID ownership, ship calls, reload, 100-call stress |
| gate | non-deficit trucks, 24-box reserve, truck travel |
| automation | berth automation uses the manual transaction path |
| traffic | road-plated machines: lanes, separation and long-run movement |
| relay | the container's chain of custody, and that no failure in it can stall a transfer |
| backup | import/export, rejection and storage |
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
| rail | branch plans and standing orders, the operational floor, parked-only work, the run-around, the completion bonus, the rake |

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

