# Declarative game data

These files describe achievements, contracts, land, prestige, routes, ships,
structures and upgrades. Catalog entries are the source of truth for IDs,
unlock requirements, prices, labels and visual metadata.

Data modules must remain deterministic and scene-independent. Consumers may
query catalogs; catalogs must not reach into `PortWorld` or UI nodes. When an
ID changes, search saves, progression, UI labels and tests because string IDs
are persisted.

Focused suites: economy, progression, route and core.

