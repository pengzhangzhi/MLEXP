# ML research goal contract — design spec

**Date:** 2026-06-14
**Status:** Approved for planning; not implemented.

## Goal

Strengthen the existing ML brainstorming flow with a compact research goal contract for vague or multi-step ML research requests. The contract should make the agent's durable objective clearer before experiment-card design, especially in Codex/Claude-style long-running goal workflows.

This is a light extension to `skills/brainstorming/SKILL.md`, not a new skill.

## Non-goals

- No new `ml-research-goal` skill.
- No new slash command implementation.
- No required compute budget cap.
- No required constraints section.
- No replacement for `ml-experiment-design`, `ml-feedback-ladder`, `writing-plans`, or `verification-before-completion`.
- No heavy research management system, database, dashboard, scheduler, or job orchestration.

## Why this belongs in brainstorming

`superpowers-ml` already has most of the needed structure:

- `brainstorming` shapes the rough work.
- `ml-experiment-design` creates a single R0 experiment card.
- `ml-feedback-ladder` defines cheap-to-expensive verification.
- `verification-before-completion` prevents overclaiming.

A separate goal skill would overlap with those pieces. The missing piece is smaller: when the user's ML research request is broad, vague, or multi-step, brainstorming should briefly define the durable research goal before handing off to the experiment-card skill.

## Ownership boundaries

| Workflow step | Owns | Does not own |
|---|---|---|
| `brainstorming` | Rough idea shaping; whether the task is ML research; optional research goal contract for vague or multi-step requests | Exact experiment protocol |
| `ml-experiment-design` | One concrete experiment card: question, hypothesis, baseline, variant, primary metric, dataset/split, seeds, success criterion | Broad agent objective, multi-experiment persistence, stop/pause policy |
| `ml-feedback-ladder` | R0-R7 verification path, proof artifacts, promotion/stop gates for one experiment | Redefining the research goal or experiment |
| `writing-plans` | Implementation tasks from the approved spec/card/ladder | Reopening the research goal without user approval |
| `verification-before-completion` | Highest verified rung and evidence-backed completion claims | Choosing the research direction |

## Research goal contract

When an ML research request is vague or multi-step, `brainstorming` should settle this compact contract before invoking `ml-experiment-design`:

```text
Research outcome: what should become true if this succeeds.
Evidence bar: what evidence would make the direction worth continuing, abandoning, or escalating.
Current state: what code, data, baselines, prior runs, or papers already exist.
Resource posture: no artificial compute cap by default; use available GPUs and cluster resources once cheaper verification rungs pass.
Stop when: evidence is enough to conclude, continue with the next card, or abandon the direction.
Pause if: credentials, cluster/account access, destructive data changes, unclear research direction, external approval, or a change to the research claim is needed.
Next handoff: create one or more `ml-experiment-design` cards.
Optional paste-ready `/goal`: a durable agent goal derived from the contract when the user is using a goal-capable agent workflow.
```

The contract should be short. It is a bridge from broad research intent to concrete experiment design, not another full spec format.

## Resource posture

The default should favor aggressive research execution after cheap gates pass:

```text
Resource posture: no artificial compute cap by default; use available GPUs and cluster resources once cheaper verification rungs pass. Do not skip cheap gates just because more compute is available.
```

Only ask for a budget when the user mentions scarce compute, shared cluster contention, external cost, deadline pressure, or a fixed allocation.

## Non-overlap rules

The contract must not duplicate experiment-card fields except as handoff notes. These belong to `ml-experiment-design`:

- hypothesis
- exact baseline config
- variant under test
- primary metric
- dataset/split
- seed policy
- experiment success criterion
- cheapest useful rung for that experiment

If a field is already known during brainstorming, record it as context, then let `ml-experiment-design` lock it in the experiment card.

## Trigger behavior

Use the research goal contract when:

- the user asks for a Codex/Claude `/goal` for ML research;
- the request is broad, such as improving a model, making a paper idea work, running a study, or exploring a new method;
- the work may produce multiple experiment cards;
- the agent needs a durable objective across long-running or multi-session work.

Skip the contract when:

- the user already provides a clear experiment card;
- the work is a narrow implementation task;
- the work is debugging an existing run;
- `ml-experiment-design` can start directly without ambiguity.

## User interaction

Do not turn this into a questionnaire. Ask only for missing information that changes the research direction, evidence bar, or pause conditions. If uncertainty is low-risk, state a conservative assumption and continue.

For ordinary ML research, do not ask for a compute cap. Assume full available resources are acceptable after R0-R4 checks pass.

## Documentation changes

Implementation should update:

- `skills/brainstorming/SKILL.md` — revise the ML research addendum to include the research goal contract and non-overlap rules.
- `docs/superpowers-ml.md` — briefly mention that broad ML requests may get a lightweight research goal contract before experiment-card design.
- `README.md` — optionally add one sentence to the ML fork banner or workflow description if it improves discoverability without bloating the README.

No manifest or hook changes are needed.

## Validation

- Frontmatter still parses for all skills.
- The `brainstorming` skill still hands ML work to `superpowers-ml:ml-experiment-design` before training code.
- The revised addendum does not require a default compute budget or constraints section.
- The revised addendum clearly says not to duplicate experiment-card fields.
- Existing ML skills still own their current responsibilities.
- Existing tests that inspect skill files or plugin loading still pass.

## Acceptance criteria

- Broad ML research tasks get a clearer durable goal without adding a new skill.
- The framework stays lean and non-overlapping.
- Agents are encouraged to use full available compute after cheap verification gates pass.
- Cheap-to-expensive verification remains mandatory; extra compute does not justify skipping R0-R4.
- Experiment-specific details remain owned by `ml-experiment-design`.
