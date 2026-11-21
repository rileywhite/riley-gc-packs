# compound-engineering

[Every Inc.'s Compound Engineering](https://github.com/EveryInc/compound-engineering-plugin)
methodology as a Gas City build factory, with a capability tier for every
agent. It wraps gascity-packs'
[compound-engineering](https://github.com/gastownhall/gascity-packs/tree/main/compound-engineering)
pack and assigns its 28 `ce-*` agents a tier and effort. For now it takes
that pack from a fork that fixes where the formulas find their check scripts;
see [Upstream fix](#upstream-fix). Nothing else about the formulas changes.

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
version = "0.9.0"
```

Then run `gc import install`.

Importing it is all a city does to use it. The `house` mayor triages every
piece of work and sends complex or risky work to `compound-build`, so no city
configuration is needed. See [house](../house).

## Bind it as `compound-engineering`

The binding is not cosmetic. The upstream formulas route every review lane,
the planner and the implementer to `compound-engineering.ce-*` by name. Bind
the pack under any other key, `ce` included, and all 28 routes point at agents
that don't exist.

## One gascity, one set of roles

Upstream compound-engineering imports gascity itself, by a relative path, so
its gascity resolves at whatever commit this pack pins. The pin matches the
gascity commit in the `gc` pack (`b7318e5` on the fork, see below), which keeps
a single gascity in the city. Always move the `gc` and `compound-engineering` pins together.

The compound formulas also route work to five of gc's worker roles:
`run-operator`, `publisher`, `task-decomposer`, `implementation-reviewer` and
`review-synthesizer`. Upstream compound-engineering brings gascity's formulas
but none of its agents, so those roles come only from the `gc` pack, carrying
its tiers. This was checked in a test city: each route lands on exactly one
agent, with the `gc` pack's tier and effort.

**Don't also import `gascity/roles` yourself.** Upstream's README tells you to
add it at rig scope. With this pack set, that would create a second, untiered
copy of every worker role alongside the tiered one.

## Upstream fix

Upstream compound-engineering (gascity-packs `0f07496`) points every check gate
in its formulas at `.gc/scripts/checks/<name>.sh`. Nothing populates that
directory in a running city, so each gate fails with a hard
`control_dispatch_error`. Symlinking `.gc/scripts` into the pack cache does not
help: the dispatcher quarantines the review and plan-review loops with "symlink
target outside containment", so the security, reliability and adversarial
lanes and the review synthesis never run, and finalize fails three times.

The fix moves those 12 paths to the layer-resolved
`../assets/scripts/checks/<name>.sh` form, which gc 1.5.1 resolves
(gascity#3834) to the scripts in the gascity layer this pack imports, the same
way upstream's gascity formulas already do. It also rewrites the 21 prompt
lines that sent agents to `.gc/scripts`, and adds a guard test.

| | |
|---|---|
| Fork | [rileywhite/gascity-packs](https://github.com/rileywhite/gascity-packs), branch `compound-check-asset-paths` |
| Commit | `b7318e5`, upstream main `0f07496` plus the fix; it touches only `compound-engineering/` and `tests/` |
| Pinned by | this pack's `compound-engineering` import and the `gc` pack's `gc` and `roles` imports |
| Upstream work | No upstream PR from this fork yet. Related upstream: [gascity-packs#149](https://github.com/gastownhall/gascity-packs/pull/149) (draft, the same change across every pack, conflicting since August) and [#169](https://github.com/gastownhall/gascity-packs/pull/169) (gascity only) |

**When upstream has the fix** (a gascity-packs commit whose
`compound-engineering/formulas` contain no `.gc/scripts/checks`):

1. Point all three imports back at `https://github.com/gastownhall/gascity-packs/tree/main/...`
   with `version = "sha:<that commit>"`: `compound-engineering` here, and `gc`
   and `roles` in the `gc` pack. Move them together.
2. Check what else that commit changes in `gascity/` and `compound-engineering/`,
   and note it in the pin comments as the earlier pin moves did.
3. Remove this section and the fork notes in both `pack.toml` files, bump every
   pack's version together and tag the release.
4. In each city: `gc import upgrade`, then confirm
   `gc formula show compound-code-review --json` resolves every check under the
   gascity pack's `assets/scripts/checks/`. Delete any rig-local `.gc/scripts`
   workaround (cilador has a copy with a `README.mayor`).
5. The fork can then be archived.

## Run a build

`compound-build` is a targeted formula, so create a bead and sling the
workflow at it from the rig:

```bash
gc bd create "Add rate limiting to the public API"
gc sling gc.run-operator <bead-id> --on compound-build --var artifact_root=gc-plans/rate-limiting/build
```

## Agent tiers

Each tier names the kind of agent it's for; see [house](../house) for the
vocabulary. Compound Engineering's fan-out runs up to 17 review lanes per pass
and up to 8 passes, so effort carries as much weight here as the tier.

| Agent | Role | Tier | Effort |
|---|---|---|---|
| ce-brainstorm | requirements, interactive | principal | medium |
| ce-plan | planning, interactive | principal | medium |
| ce-architecture-strategist | plan review: architecture | principal | high |
| ce-coherence-reviewer | plan review | engineer | high |
| ce-feasibility-reviewer | plan review | engineer | high |
| ce-scope-guardian-reviewer | plan review | engineer | high |
| ce-work | implementation, applies review fixes | engineer | xhigh |
| ce-correctness-reviewer | defect lane, always on | engineer | high |
| ce-testing-reviewer | defect lane, always on | engineer | high |
| ce-security-reviewer | defect lane | engineer | high |
| ce-reliability-reviewer | defect lane | engineer | high |
| ce-performance-reviewer | defect lane | engineer | high |
| ce-data-migration-reviewer | defect lane | engineer | high |
| ce-api-contract-reviewer | defect lane | engineer | high |
| ce-adversarial-reviewer | defect lane | engineer | high |
| ce-julik-frontend-races-reviewer | defect lane | engineer | high |
| ce-swift-ios-reviewer | defect lane | engineer | high |
| ce-deployment-verification-agent | defect lane | engineer | high |
| ce-maintainability-reviewer | design-quality lane, always on | engineer | medium |
| ce-agent-native-reviewer | design-quality lane, always on | engineer | medium |
| ce-plan-review-synthesizer | synthesis | engineer | medium |
| ce-code-review-synthesizer | synthesis | engineer | medium |
| ce-pr-comment-resolver | resolution | engineer | medium |
| ce-compound | distills learnings | engineer | medium |
| ce-project-standards-reviewer | checks written conventions, always on | operator | medium |
| ce-previous-comments-reviewer | checks earlier comments | operator | medium |
| ce-code-review-selector | chooses conditional lanes | operator | medium |
| ce-learnings-researcher | retrieves past findings | operator | medium |

The choices worth knowing:

- **The planner, brainstormer and architecture strategist are principals.**
  They decide what gets built and its structure, and they run once per build or
  once per plan-review pass, which keeps the top tier affordable.
- **The interactive principals run at medium.** In interactive mode the
  brainstormer and planner ask you questions. Top-tier models think longer per
  turn and take more initiative, so medium keeps the pauses short and the
  questions on what you asked. The scope guardian also reviews every plan for
  scope creep.
- **ce-work matches gc's implementation-worker** as an engineer at `xhigh`.
- **Review lanes split by kind, not cost.** Defect lanes and design-quality
  lanes are engineers, because both are judgment calls. Design-quality lanes
  run at medium, since a miss costs design debt rather than a bug. Lanes that
  check the change against something already written down, project
  conventions or earlier comments, are operators.
- **The selector is an operator, not a custodian.** Upstream calls it a cheap
  gate, but a wrong skip silently drops a lane such as security.

To change any agent for your city, patch it from `city.toml` by its
binding-qualified name, for example `compound-engineering.ce-security-reviewer`.
See [house](../house) for the full recipe.
