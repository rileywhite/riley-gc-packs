# compound-engineering

[Every Inc.'s Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)
methodology as a Gas City build factory, with a capability tier for every
agent. It wraps gascity-packs'
[compound-engineering](https://github.com/gastownhall/gascity-packs/tree/main/compound-engineering)
pack and changes nothing about its formulas: it only assigns its 28 `ce-*`
agents a tier and effort.

Compound Engineering's distinguishing features are a four-persona review of
the plan before any code exists, a review fan-out of up to 17 specialist
lanes, and a final step that distills each build's findings into durable
learnings. See the upstream README for the full stage map and every launch
variable.

## Install

This pack needs `gc`, `bd` and `house` alongside it. `house` defines what the
tier names mean, and the compound formulas route work to gc's worker roles.

```toml
[imports.compound-engineering]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/compound-engineering"
version = "0.6.0"
```

Then run `gc import install`.

## Bind it as `compound-engineering`

The binding is not cosmetic. The upstream formulas route every review lane,
the planner and the implementer to `compound-engineering.ce-*` by name. Bind
the pack under any other key, `ce` included, and all 28 routes point at agents
that don't exist.

## One gascity in the city

Upstream compound-engineering imports gascity itself, by a relative path, so
its gascity resolves at whatever commit this pack pins. The pin matches the
gascity commit in the `gc` pack (`d36950e`), which keeps a single gascity in
the city. compound-engineering has not changed upstream since that commit, so
this is also the current upstream pack. Move the `gc` and
`compound-engineering` pins together.

## Run a build

`compound-build` is a targeted formula, so create a bead and sling the
workflow at it from the rig:

```bash
gc bd create "Add rate limiting to the public API"
gc sling gc.run-operator <bead-id> --on compound-build --var artifact_root=gc-plans/rate-limiting/build
```

## Agent tiers

The rubric is the same as `gc`'s: agents that decide what to build, or judge
whether the result is acceptable, sit on the judgment tier. Compound
Engineering's fan-out forces one extra distinction, between review lanes
that catch defects and lanes about hygiene. A missed defect ships a bug; a
missed style note doesn't. With up to 17 lanes per pass and up to 8 passes,
that distinction is what keeps a build affordable.

| Agent | Role | Tier | Effort |
|---|---|---|---|
| ce-brainstorm | requirements | deep | high |
| ce-plan | planning, applies plan findings | deep | high |
| ce-architecture-strategist | plan review | deep | high |
| ce-coherence-reviewer | plan review | deep | high |
| ce-feasibility-reviewer | plan review | deep | high |
| ce-scope-guardian-reviewer | plan review | deep | high |
| ce-work | implementation, applies review fixes | deep | xhigh |
| ce-correctness-reviewer | defect lane, always on | deep | high |
| ce-testing-reviewer | defect lane, always on | deep | high |
| ce-security-reviewer | defect lane | deep | high |
| ce-reliability-reviewer | defect lane | deep | high |
| ce-performance-reviewer | defect lane | deep | high |
| ce-data-migration-reviewer | defect lane | deep | high |
| ce-api-contract-reviewer | defect lane | deep | high |
| ce-adversarial-reviewer | defect lane | deep | high |
| ce-julik-frontend-races-reviewer | defect lane | deep | high |
| ce-swift-ios-reviewer | defect lane | deep | high |
| ce-deployment-verification-agent | defect lane | deep | high |
| ce-maintainability-reviewer | hygiene lane, always on | standard | medium |
| ce-project-standards-reviewer | hygiene lane, always on | standard | medium |
| ce-agent-native-reviewer | hygiene lane, always on | standard | medium |
| ce-previous-comments-reviewer | history lane | standard | medium |
| ce-code-review-selector | chooses conditional lanes | standard | medium |
| ce-learnings-researcher | retrieves past findings | standard | medium |
| ce-plan-review-synthesizer | synthesis | deep | medium |
| ce-code-review-synthesizer | synthesis | deep | medium |
| ce-pr-comment-resolver | resolution | deep | medium |
| ce-compound | distills learnings | deep | medium |

Three choices are worth knowing:

- **ce-work matches gc's implementation-worker** at deep and `xhigh`. It does
  the same job, writing each item and applying review fixes.
- **The selector stays off light.** Upstream calls it a cheap gate, but a
  wrong skip silently drops a lane such as security, the same reasoning `gc`
  uses for its control dispatcher.
- **Synthesizers run at medium** on the judgment tier. They consolidate
  verdicts the lanes already reasoned out, matching gc's review-synthesizer.

To change any agent for your city, patch it from `city.toml` by its
binding-qualified name, for example `compound-engineering.ce-security-reviewer`.
See [house](../house) for the full recipe.
