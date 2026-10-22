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

Four portable names replace hardcoded model ids. Current as of 2026-10-20.

| Tier | Claude | Codex | Gemini |
|---|---|---|---|
| frontier | claude-fable-5-1 | gpt-6-astra | gemini-4-argon |
| deep | claude-opus-5-5 | gpt-6.1-sol | gemini-3.8-flash |
| standard | claude-sonnet-5-5 | gpt-6.1-sol | gemini-3.8-flash |
| light | claude-haiku-5-5 | gpt-6-luna | gemini-3.5-flash-lite |

Nothing is mapped to `frontier` yet. It exists so a city can raise one agent
without inventing vocabulary.

Codex maps deep and standard to the same model on purpose. GPT-6 has no Terra,
so there is no mid model for standard, and demoting it to Luna would put the
workhorse agents on the high-volume model. The two tiers share GPT-6.1 Sol and
differentiate on effort instead, which the agent table below already does:
standard agents run low or medium, deep agents run high. OpenAI recommends 6.1
Sol over Astra for coding and agentic work on cost grounds, so frontier stays a
deliberate opt-in.

Gemini reserves Gemini 4 Argon, its flagship reasoning model, for frontier only.
Deep and standard both run 3.8 Flash, which Google builds for long-horizon
software engineering, and light drops to 3.5 Flash-Lite for high-throughput
work. Google names those two Flash models together as its current pair for new
projects. Argon being stable also retires this pack's long-standing caveat that
Gemini had no stable top model.

One asymmetry is worth knowing. On Gemini, deep and standard resolve to the same
model, and effort is inert there, so those two tiers behave identically. Codex
gets away with sharing a model because effort still separates its tiers. Under
Gemini, raising an agent from standard to deep changes nothing; move it to
frontier to get more capability.

The frontier tier still carries one external requirement: a Codex CLI new enough
for GPT-6 Astra.

Each provider also keeps its current models as passthrough choices, so a
city can pin an exact model instead of a tier. Retired models are not
carried: Claude's 4.x generation, the whole Codex 5.x line (gpt-5.6-sol,
gpt-5.6-terra, gpt-5.6-luna, gpt-5.5, gpt-5.4 and gpt-5.3-codex-spark), and
Gemini's 2.5 line are all omitted.

Effort shares one vocabulary: `low`, `medium`, `high`, `xhigh`, `max`. Codex
clamps `max` onto `xhigh`. Astra accepts `max`, but the effort option is
provider-wide and Sol and Luna are not confirmed to, so the clamp holds to the
weakest model in the set. Gemini CLI has no reasoning effort control at all,
so the option is declared but inert there. Declaring it anyway is deliberate,
because it keeps a portable agent config from failing to load under Gemini.

There is no speed or fast-mode option. None of the three CLIs exposes one.
Claude Code has no fast flag, and Codex and Gemini express speed only through
model choice. A declared-but-inert speed control would look like a setting
and silently do nothing, so it is left out until a provider gives it a real
surface.

## What you get

| Agent | From | Scope | Tier | Effort |
|---|---|---|---|---|
| mayor | house | city | deep | high |
| dog | bd | city | light | low |
| control-dispatcher | gc | both | standard | low |
| run-operator | gc | rig | standard | low |
| publisher | gc | rig | standard | low |
| issue-triager | gc | rig | standard | medium |
| feature-refiner | gc | rig | standard | medium |
| task-decomposer | gc | rig | deep | high |
| requirements-planner | gc | rig | deep | high |
| design-author | gc | rig | deep | high |
| design-implementation-reviewer | gc | rig | deep | high |
| design-test-risk-reviewer | gc | rig | deep | high |
| implementation-reviewer | gc | rig | deep | high |
| gap-analyst | gc | rig | deep | high |
| quality-judge | gc | rig | deep | high |
| review-synthesizer | gc | rig | deep | medium |
| implementation-worker | gc | rig | deep | high |

Anything unpatched falls through to the provider default of `standard` at
medium effort.

The split is by the kind of work, not by how often an agent runs. Agents that
execute a defined procedure stay cheap. Agents that decide what to build, or
judge whether the result is acceptable, do not. Three entries are worth
calling out. `gap-analyst` sits in the judgment group because finding what is
absent is harder than checking what is present. `quality-judge` does too,
because its gate fails on uncertainty. `review-synthesizer` keeps the deep
tier but drops to medium effort, because it aggregates verdicts the reviewers
have already reasoned out.

## The mayor

The mayor declares `scope = "city"`. Agents from a city-imported pack are
expanded across every rig unless they say otherwise, and a city wants exactly
one mayor.

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
option_defaults = { model = "frontier", effort = "max" }
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
