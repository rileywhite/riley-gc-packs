# riley-gc-packs

Opt-in [Gas City](https://github.com/gastownhall/gascity) packs.

A pack is a unit of workspace configuration: agents, commands, formulas,
services, providers, or any combination. Packs compose through `pack.toml`
imports, so a city opts into any subset without forking.

## Packs

| Pack | Scope | What it does |
|---|---|---|
| [basic](packs/basic) | city | Composes `bd`, `core`, `gascity` and the gascity worker roles, defines a mayor, and tiers model spend by agent role. |

## Installing

Packs are imported by URL. Point `source` at the repository with the pack
path after a `//` separator:

```toml
[imports.gc]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/basic"
```

Then run `gc import install`. See each pack's README for its binding and
anything a city still has to write for itself.
