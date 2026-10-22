# bd

gc's bundled [bd](https://github.com/gastownhall/gascity/tree/main/examples/bd)
pack (beads on Dolt, with its dolt maintenance agents and orders), with a
capability tier and effort for every agent it defines.

This pack defines no tiers of its own. It selects from the vocabulary in
[`house`](../house), so compose the two together.

## Install

In your city's `pack.toml`, next to `gc` and `house`:

```toml
[imports.bd]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/bd"
```

Bind it as `bd`, the key gc init writes for the bundled pack. gc requires the
bd pack to be reachable in any city whose beads provider is bd, and this
import satisfies that. Its maintenance agent comes out as `bd.dog`.

The pack is named `bd-tiered`, not `bd`. `gc doctor` treats any pack named
`bd` outside the pack cache as a user override of the builtin bd pack, and
fails the city unless `dolt` is overridden too.

## What it inherits

| Import | Source | Pin |
|---|---|---|
| `bd` | gascity `examples/bd` | `f895c0f`, the pin gc 1.5 bundles |

Move a pin with `gc import upgrade`, not by hand.

## Tiers

| Agent | Scope | Tier | Effort |
|---|---|---|---|
| dog | city | light | low |
