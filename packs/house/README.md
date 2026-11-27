# house

House style for a Gas City. The shared layer a city composes next to the packs
it inherits: the capability-tier vocabulary their agents select from, the
city's mayor, and any ways of working the city wants on top of upstream.

It imports no other pack. The packs it tunes, [`gc`](../gc) and [`bd`](../bd),
each tier their own agents using the names defined here, so the three compose
side by side and any of them can be swapped for another pack written the same
way.

No agent names a model. Agents select a capability tier, and each provider
block here maps that tier to its own model, so the same packs run on Claude
Code, Codex or Gemini without edits.

## Install

In your city's `pack.toml`:

```toml
[imports.gc]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/gc"

[imports.bd]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/bd"

[imports.house]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/house"
```

Then `gc import install`. Add rigs with `gc rig add <path>` and the worker
agents attach to each one automatically.

## Bindings

A city-level binding becomes the visible prefix on every agent a pack
contributes, so the keys above are not cosmetic:

- `gc` is the key the public gascity pack is written against. Its README
  installs it with `gc import add --name gc`, its skills surface as
  `gc.<skill>`, and `gc doctor` checks for it.
- `bd` is the key gc init writes for its bundled beads pack.
- `house` names this pack, so its mayor is `house.mayor`.

## Capability tiers

Four portable names replace hardcoded model ids. Each one names the kind of
agent the tier is for, so a new agent is placed by asking what kind of agent it
is, not how big a model it needs. Models are current as of 2026-11-21.

| Tier | For agents that | Claude | Codex | Gemini |
|---|---|---|---|---|
| principal | set the direction everything downstream builds on | claude-fable-5-2 | gpt-6.2-astra | gemini-3.1-pro-preview |
| engineer | plan, build and review the work | claude-opus-5-5 | gpt-6.2-sol | gemini-3.8-flash |
| operator | run a defined procedure | claude-sonnet-5-5 | gpt-6.1-terra | gemini-3.8-flash |
| custodian | keep things running unattended | claude-haiku-5-5 | gpt-6-luna | gemini-3.5-flash-lite |

A principal is an agent whose output everything downstream implements and
which runs rarely, typically once per build. Both conditions matter. The first
makes its mistakes the most expensive in the pipeline, and the second keeps the
top tier affordable.

Principals that work with a person in the loop run at medium effort rather than
high. Top-tier models think longer per turn and take more initiative, which in
a conversation means long pauses before each question and a tendency to wander
past what was asked. Anthropic notes that lower effort on its top tier often
beats prior models at their highest.

The names before 0.7.0, `frontier`, `deep`, `standard` and `light`, were
removed in 0.10.0. A city patch that still uses one must be renamed to
`principal`, `engineer`, `operator` or `custodian` respectively.

OpenAI positions GPT-6.1 Terra for writing, visual understanding and computer
use rather than coding. Terra needs Codex CLI 0.159.0 or later, and the
principal and engineer tiers need Codex CLI 0.171.0 or later, the first release
with GPT-6.2 Astra and Sol in its catalog.

Gemini maps only to models Gemini CLI documents. Google says Gemini CLI "has
not been optimized for Gemini 4" and points Gemini 4 users to Antigravity CLI,
and no Gemini CLI page confirms the Gemini 4 models work there. So no Gemini 4
model is offered, not even as a passthrough value. Principal falls back to 3.1
Pro, still a preview endpoint. This is worth revisiting once Gemini CLI
documents Gemini 4.

One asymmetry is worth knowing. On Gemini, engineer and operator resolve to the
same model, and effort is inert there, so those two tiers behave identically.
Under Gemini, moving an agent from operator to engineer changes nothing.

Each provider also offers the models its tiers use as passthrough choices, so
a city can pin an exact model instead of a tier. Superseded and retired models
are deliberately left out, so every listed model is one the tiers use today.

Effort shares one vocabulary: `low`, `medium`, `high`, `xhigh`, `max`. Every
level maps to a real setting on Claude Code and Codex. Codex used to clamp
`max` onto `xhigh`, but `max` is now a real level on every GPT-6 model.

Codex also offers `ultra` above `max`, which this vocabulary does not expose.
Ultra fans the work out to subagents rather than reasoning harder, Luna rejects
it, and neither other provider has an equivalent, so a portable agent config set
to `ultra` would break on the others.

Gemini CLI has no per-invocation thinking control; its thinking level lives only
in `settings.json` model configs. The effort option is declared but inert there.
Declaring it anyway is deliberate, because it keeps a portable agent config
from failing to load under Gemini.

There is no speed or fast-mode option. Codex now has a config-level Fast mode,
but Claude Code exposes no fast flag and Gemini CLI has none either. A portable
speed option would silently do nothing on two of the three providers, so it is
left out until they all give it a real surface.

## What you get

| Agent | From | Scope | Tier | Effort |
|---|---|---|---|---|
| requirements-planner | gc | rig | principal | medium |
| design-author | gc | rig | principal | high |
| mayor | house | city | engineer | high |
| task-decomposer | gc | rig | engineer | high |
| design-implementation-reviewer | gc | rig | engineer | high |
| design-test-risk-reviewer | gc | rig | engineer | high |
| implementation-reviewer | gc | rig | engineer | high |
| gap-analyst | gc | rig | engineer | high |
| quality-judge | gc | rig | engineer | high |
| review-synthesizer | gc | rig | engineer | medium |
| implementation-worker | gc | rig | engineer | xhigh |
| control-dispatcher | gc | both | operator | low |
| run-operator | gc | rig | operator | low |
| publisher | gc | rig | operator | low |
| issue-triager | gc | rig | operator | medium |
| feature-refiner | gc | rig | operator | medium |
| dog | bd | city | custodian | low |

A city that adds the optional `compound-engineering` pack gets its 28 `ce-*`
agents as well. They are tiered by the same rubric, and its
[README](../compound-engineering/README.md) has the full table.

Anything unpatched falls through to the provider default of `operator` at
medium effort.

The tier follows the kind of agent. A few placements are worth calling out:

- **The requirements planner and design author are principals.** Each runs once
  per build, and the whole build implements what they decide. The planner runs
  at medium because it works with a person in the loop.
- **The mayor and the implementation worker stay engineers.** Both matter a
  great deal, but they run continuously or once per work item, so the top
  tier's price would land on the largest line items.
- **`gap-analyst` and `quality-judge` are engineers, not operators.** Finding
  what is absent is harder than checking what is present, and the quality gate
  fails on uncertainty.
- **`review-synthesizer` is an engineer at medium effort.** It aggregates
  verdicts the reviewers have already reasoned out.

## The mayor

The mayor declares `scope = "city"`. Agents from a city-imported pack are
expanded across every rig unless they say otherwise, and a city wants exactly
one mayor.

The mayor also decides how work runs. Every piece of work, a single bug
included, runs a full build that plans the work, does it, reviews it and opens
a pull request. The mayor never uses `do-work` for real work, because it skips
planning and review.

Before launching, the mayor triages the bead to choose how broad the build
should be:

| Triage result | Build |
|---|---|
| Complex or risky: security, data, public APIs, concurrency, deployment, several components, unclear requirements, or a costly mistake | `compound-build`, when [compound-engineering](../compound-engineering) is installed |
| Simple: well specified, localized, small blast radius | `build-basic` |
| Unsure | `compound-build` |

A city without compound-engineering runs `build-basic` for everything. The
mayor records each decision on the bead, as `house.build` metadata and a
`triage:` note with its reason, and launches the build to publish a pull
request once its reviews pass. A workflow you name, or your own call that work
is simple or complex, always wins.

### Workflow notices

Gas City records a run's result on its workflow root bead and tells no one.
The `notify-mayor-on-workflow-result` order closes that gap. Every two minutes
it reads each rig's top-level workflow runs and mails the mayor, with
`--notify` so a stopped mayor is woken, when:

- a run finishes, whatever its outcome, or
- a run's plan or code review lands on a status other than approved while the
  run is still going. A build does not stop when a review loop runs out of
  rounds, so this is the early warning.

Each notice is sent once. Its subject leads with the review verdict rather
than `gc.outcome`, which can read `fail` for a run whose reviews all approved.
The body gives the run, its source bead, each review's status and rounds,
the publish status and the pull request link. The mayor decides what to do.

The order runs with no agent. On its first run it records every existing
run as already seen and sends nothing, so installing it does not replay
history. A failed send is not recorded and is retried on the next run. It
reads these optional environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `GC_WORKFLOW_NOTICE_TO` | the session whose template is `<binding>.mayor` | who gets the notices |
| `GC_WORKFLOW_NOTICE_LOOKBACK` | `6` | hours of closed runs to consider |
| `GC_WORKFLOW_NOTICE_DRY_RUN` | `0` | `1` prints the notices instead of sending them |

To preview what it would send, without touching its state, run from the city
root:

    GC_WORKFLOW_NOTICE_DRY_RUN=1 GC_PACK_STATE_DIR=$(mktemp -d) \
      bash <house pack>/assets/scripts/notify-mayor-on-workflow-result.sh

With an empty state directory the script seeds and prints nothing, so put
`{"runs":{}}` in `notify-mayor-on-workflow-result-state.json` there first to
see every run in the lookback window.

## What still belongs in your city.toml

Two things are city-only by schema, and a pack declaring them fails to load.

- **Your rig blocks.** Which repositories the city works on is inherently
  per-city. `gc rig add <path>` writes these for you.
- **`[workspace] provider`.** Set `provider = "claude"` in your `city.toml`.

## Overriding one agent from your city.toml

The tiers here are defaults. To change one agent for your city, patch it from
`city.toml`. Two details matter, and both are easy to get wrong.

Name the agent with its **import binding**. City-level patches match on the
binding-qualified name, so it is `gc.implementation-worker`, not
`implementation-worker`. This differs from `[[rigs.patches]]` entries, which
match the bare name within their own pack.

Scope it with **`dir`**, not `rig`. Both name the rig, but `rig` is the newer
key and gascity 1.4.1 does not understand it. On that release a `rig` key is
ignored, the patch falls back to city scope, and it fails with "agent not
found in merged config" rather than telling you the key was the problem.

```toml
[[patches.agent]]
dir = "my-repo"
name = "gc.implementation-worker"
option_defaults = { model = "principal", effort = "high" }
```

A patch with no `dir` targets the city-scoped copy, which is what you want for
`house.mayor` or `bd.dog`.

## If your rig has a single working tree

The `gc` pack does not serialize implementation workers, because a rig using
per-session worktrees would get nothing but a bottleneck from it. If your rig
is one checkout that every session shares, add this to your `city.toml` so
concurrent workers cannot stomp each other's edits and git index:

```toml
[[patches.agent]]
dir = "my-repo"
name = "gc.implementation-worker"
max_active_sessions = 1
```
