# basic

One import that composes a working Gas City: the `bd`, `core`, `gascity` and
`gascity/roles` packs, a mayor, and opinionated tuning that runs mechanical
agents cheap and judgment agents expensive.

No agent names a model. Agents select a capability tier, and each provider
block maps that tier to its own model, so the same pack runs on Claude Code,
Codex or Gemini without edits.

## Install

In your city's `pack.toml`:

```toml
[imports.gc]
source = "https://github.com/rileywhite/riley-gc-packs.git//packs/basic"
```

Then `gc import install`. That is the whole installation. Add rigs with
`gc rig add <path>` and the worker agents attach to each one automatically.

## Bind it as `gc`

The binding name is not cosmetic. A city-level binding overrides any nested
one, so whatever you write becomes the visible prefix on every agent the
pack contributes. Binding as `gc` gives `gc.mayor`, `gc.run-operator`,
`gc.implementation-worker` and the rest, which is what the gascity formulas
and the upstream documentation already assume. Bind it as something else and
you rename your whole agent surface.

## How one import covers both agent scopes

Gas City has city-scoped agents and rig-scoped agents. You might expect the
rig-scoped ones to need their own import inside a rig block. They do not.
Agents from a city-imported pack are expanded across every rig in the city
and bound to that rig's working tree, unless the agent declares
`scope = "city"`. The upstream worker agents declare `scope = "rig"`, so they
land on your rigs from this single city-level import.

The mayor here declares `scope = "city"` for the opposite reason: without it
a copy would be created per rig, and a city wants exactly one mayor.

## Capability tiers

Four portable names replace hardcoded model ids. Current as of 2026-09-12.

| Tier | Claude | Codex | Gemini |
|---|---|---|---|
| frontier | claude-fable-5-1 | gpt-6-astra | gemini-3.1-pro-preview |
| deep | claude-opus-5 | gpt-5.6-sol | gemini-3.1-pro-preview |
| standard | claude-sonnet-5 | gpt-5.6-terra | gemini-3.8-flash |
| light | claude-haiku-4-5-20251001 | gpt-5.6-luna | gemini-3.8-flash |

Nothing is mapped to `frontier` yet. It exists so a city can raise one agent
without inventing vocabulary.

These ids deliberately go past what gascity 1.4.1 knows. Its built-in table
predates Fable 5.1 and GPT-6 Astra, both of which shipped in early September
2026, and its Gemini entries still stop at 2.5. That works because
`flag_args` reach the CLI verbatim, so the schema is not limited to
gascity's catalogue.

Two consequences follow. The frontier tier carries external version
requirements: Codex CLI 0.153.1 or later for Astra, and a Gemini CLI new
enough for 3.1 Pro. And Gemini currently has no stable Pro model at all,
since 3 Pro Preview is shut down, 2.5 Pro shuts down on 2026-10-16, and 3.1
Pro is still a preview endpoint. Both Gemini judgment tiers therefore ride a
preview id until Google promotes one.

Gemini still collapses four tiers into two. The mapping preserves the cost
shape rather than the absolute quality level: judgment agents get Pro,
mechanical agents get Flash.

Each provider also keeps its current models as passthrough choices, so a
city can pin an exact model instead of a tier. Retired models are not
carried: Claude's 4.x generation, Codex's gpt-5.2, gpt-5.3-codex, gpt-5.4
and gpt-5.4-mini, and Gemini's 2.5 line are all omitted.

Effort shares one vocabulary: `low`, `medium`, `high`, `xhigh`, `max`. Codex
clamps `max` onto `xhigh`. Astra itself accepts `max`, but the effort option
is provider-wide and the 5.6 models are not, so the clamp holds to the
weakest model in the set. Gemini CLI has no reasoning effort control at all,
so the option is declared but inert there. Declaring it anyway is deliberate,
because it keeps a portable agent config from failing to load under Gemini.

There is no speed or fast-mode option. None of the three CLIs exposes one.
Claude Code has no fast flag, and Codex and Gemini express speed only through
model choice. A declared-but-inert speed control would look like a setting
and silently do nothing, so it is left out until a provider gives it a real
surface.

## What you get

| Agent | Scope | Tier | Effort |
|---|---|---|---|
| dog | city | light | low |
| control-dispatcher | both | standard | low |
| run-operator | rig | standard | low |
| publisher | rig | standard | low |
| issue-triager | rig | standard | medium |
| mayor | city | deep | high |
| task-decomposer | rig | deep | high |
| requirements-planner | rig | deep | high |
| design-author | rig | deep | high |
| design-implementation-reviewer | rig | deep | high |
| design-test-risk-reviewer | rig | deep | high |
| implementation-reviewer | rig | deep | high |
| gap-analyst | rig | deep | high |
| review-synthesizer | rig | deep | medium |
| implementation-worker | rig | deep | high |

Anything unpatched falls through to the provider default of `standard` at
medium effort.

The split is by the kind of work, not by how often an agent runs. Agents that
execute a defined procedure stay cheap. Agents that decide what to build, or
judge whether the result is acceptable, do not. Two entries are worth calling
out. `gap-analyst` sits in the judgment group because finding what is absent
is harder than checking what is present. `review-synthesizer` keeps the deep
tier but drops to medium effort, because it aggregates verdicts the reviewers
have already reasoned out.

## What still belongs in your city.toml

Two things are city-only by schema, and a pack declaring them fails to load.

- **Your rig blocks.** Which repositories the city works on is inherently
  per-city. `gc rig add <path>` writes these for you.
- **`[workspace] provider`.** Set `provider = "claude"` in your `city.toml`.

## If your rig has a single working tree

This pack does not serialize implementation workers, because a rig using
per-session worktrees would get nothing but a bottleneck from it. If your rig
is one checkout that every session shares, add this to your `city.toml` so
concurrent workers cannot stomp each other's edits and git index:

```toml
[[rigs.patches]]
agent = "implementation-worker"
max_active_sessions = 1
```

## Version pins

Composed packs are pinned to specific commits. Move a pin with
`gc import upgrade`, never by editing `pack.toml` by hand. Note that the
pinned `gascity/roles` predates its `feature-refiner` and `quality-judge`
agents, so those two are not part of this release.
