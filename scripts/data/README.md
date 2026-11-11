# Declarative game data

These files describe achievements, contracts, land, prestige, routes, ships,
structures and upgrades. Catalog entries are the source of truth for IDs,
unlock requirements, prices, labels and visual metadata.

Data modules must remain deterministic and scene-independent. Consumers may
query catalogs; catalogs must not reach into `PortWorld` or UI nodes. When an
ID changes, search saves, progression, UI labels and tests because string IDs
are persisted.

## `upgrade_db.gd` is a graph, not a list

Upgrades carry four fields the other catalogues do not, and every one of them is
a rule some other file enforces:

- `requires` — upgrade ids that must be owned first. `GameState.upgrade_available`
  refuses the purchase; the shop draws the node anyway and says what opens it.
- `excludes` / `group` — nodes that cannot be fitted together. `group` is the
  N-way form: every member excludes every other, so an N-way choice cannot be
  written down with N chances to forget a side. Buying over a fitted sibling is
  a **swap**: `UpgradeDB.price_for` charges `SWAP_SURCHARGE`× and
  `GameState.buy_upgrade` removes the loser in the same transaction.
- `targets` — the plural of `target`, for a node fitted to several machines.
  Read everything through `UpgradeDB.targets_of`, never `item.target`.
- `stats` — rail knobs, applied by `GameState.rail_stat` over the baseline that
  `RailCargoPolicy`/`RailYard` own.

`kind` is one of `click_mult`, `click_cps_pct`, `structure_mult`, `global_mult`,
`synergy` (pays per unit of a *different* machine), `transform` (mode
`conductor`: the machine stops producing and pays the port a share per unit of
itself) and `rail_stat`.

Two invariants worth knowing before editing:

- **Anything that pays per unit goes through `EconomyMath.saturating_bonus`.**
  Both `GameState` and `EconomySimulator` call it, which is the only reason the
  sandbox and the game cannot drift apart on the one formula that matters most.
- **`UpgradeDB.is_valid()` is a test, and one of its checks is not cosmetic.**
  `depth_of` recurses through `requires`, so a cycle is a hang the first time
  the shop is opened, not a wrong label.

Ids are persisted in saves. Renaming one silently un-buys it for every existing
player, so retire ids the way `PrestigeDB.LEGACY_NODE_IDS` does rather than
editing them in place.

Focused suites: economy, progression, route and core.

The X-ray scanner is a one-off purchase with no catalogue row: its price and
benefit are rules priced in the port's income, so they live with the rest of
its rules in `scripts/events/xray_policy.gd`, and its cargo silhouettes in
`XrayScan.ITEMS` (`scripts/events/xray_scan.gd`).

