# riley-gc-packs

Opt-in [Gas City](https://github.com/gastownhall/gascity) packs.

A pack is a unit of workspace configuration: agents, commands, formulas,
services, providers, or any combination. Packs compose through `pack.toml`
imports, so a city opts into any subset without forking.

## Packs

| Pack | Bind as | What it does |
|---|---|---|
| [gc](packs/gc) | `gc` | The public gascity pack, its worker roles and gc core, with a capability tier for every agent. |
| [bd](packs/bd) | `bd` | gc's bundled beads pack, with a capability tier for every agent. |
| [house](packs/house) | `house` | House style: the provider-agnostic tier vocabulary the other packs select from, and a mayor. |
| [compound-engineering](packs/compound-engineering) | `compound-engineering` | Optional. Every Inc.'s Compound Engineering methodology as a build factory, with a capability tier for every agent. |

A city composes `gc`, `bd` and `house`, and can add `compound-engineering` on
top. `gc`, `bd` and `compound-engineering` inherit upstream packs and tier
their agents; `house` holds what is shared, so it can tune other packs the
same way.

## Installing

Packs are imported by URL. Point `source` at the repository with the pack
path after a `//` separator:

```toml
[imports.gc]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/gc"

[imports.bd]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/bd"

[imports.house]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/house"

# optional
[imports.compound-engineering]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/compound-engineering"
```

Then run `gc import install`. See each pack's README for its binding, and
[house](packs/house) for anything a city still has to write for itself.
