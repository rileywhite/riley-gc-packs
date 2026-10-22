# gc

The public [gascity](https://github.com/gastownhall/gascity-packs/tree/main/gascity)
pack, its worker roles and gc's core pack, with a capability tier and effort
for every agent they define.

This pack defines no tiers of its own. It selects from the vocabulary in
[`house`](../house), so compose the two together.

## Install

In your city's `pack.toml`, next to `bd` and `house`:

```toml
[imports.gc]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/gc"
```

Bind it as `gc`. That is the key the gascity pack is written against: its
README installs it with `gc import add --name gc`, its skills surface as
`gc.<skill>`, and `gc doctor` flags any other key. Agents come out as
`gc.run-operator`, `gc.implementation-worker` and the rest.

The worker roles declare `scope = "rig"` upstream, so this one city-level
import expands them across every rig. No rig-level import is needed.

## What it inherits

| Import | Source | Pin |
|---|---|---|
| `gc` | gascity-packs `gascity` | `d36950e` |
| `roles` | gascity-packs `gascity/roles` | `d36950e` |
| `core` | gascity `internal/bootstrap/packs/core` | `f895c0f`, the pin gc 1.5 bundles |

gascity and its roles are pinned past their 0.1.6 release (`3b3b89f`) to
`d36950e` (gascity-packs#194), the last commit that touches `gascity/`.
gc 1.5 resolves formula check scripts only when they are written as
`../assets/scripts/checks/<name>`, which it rewrites to the script inside the
pack. 0.1.6 still writes `.gc/scripts/checks/<name>`, a directory nothing
populates any more, so under 0.1.6 every build-* artifact check fails with a
hard `control_dispatch_error` and the workflow closes as failed even when
every step passed.

Move a pin with `gc import upgrade`, not by hand.

## Tiers

See the agent table in [`house`](../house#what-you-get). This pack sets every
row marked `gc`.
