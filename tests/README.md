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

Run everything with `tools/qa/run_all.sh`. A regression belongs next to the
contract it protects; avoid tests that assert an obsolete implementation detail
when the player-facing invariant is stronger.

