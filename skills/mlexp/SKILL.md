---
name: mlexp
description: Use to start or orient an ML experiment workflow (MLEXP) — when the user wants to plan, run, monitor, debug, or write up deep-learning experiments / ablations on a cluster, or asks "what should I do next" with their experiments.
---

# MLEXP — ML Experimentalist (orientation & router)

MLEXP turns your ad-hoc "help me plan / launch / babysit / debug / write up my
experiments" prompts into repeatable workflows over **durable files**.

## First principle: the LLM is not the source of truth

Truth = `files (study.yaml / experiment.yaml / attempt.yaml / events.jsonl) +
Slurm + W&B + git`. You (the model) **reconcile** state into files; you never
invent it. Because state is files, the system survives a closed laptop, dropped
SSH, ended session, or preempted job — when the user returns, reconcile from
ground truth.

## Vocabulary

```
Study  ──< Experiment ──< Attempt ──→ slurm_job_id, wandb_run_id(s)
```
- **Study** — one research objective + its experiments; owns the frozen
  primary-metric protocol.
- **Experiment** — one logical training target = `variant × seed`.
- **Attempt** — one Slurm submission (preemption → new attempt, same experiment).

## The slow-feedback ladder (why MLEXP exists)

ML feedback is a day away, so MLEXP **de-risks early**: it decomposes the one-day
verdict into cheap proxy feedbacks (import → unit → tiny batch → smoke Slurm →
early signal → full result) and refuses to spend an expensive rung until the
cheap one is green. See `references/feedback-ladder.md`.

## Router — pick the phase (each runs standalone)

| If the user wants to… | Use |
|---|---|
| design an ablation / start a study | `/mlexp-new` |
| implement variant code + configs + tests | `/mlexp-implement` |
| submit jobs to Slurm | `/mlexp-submit` |
| **check on / babysit running jobs** | `/mlexp-monitor` |
| figure out why a job died and fix it | `/mlexp-debug` |
| write up results | `/mlexp-report` |

You can enter at **any** phase. In particular, `/mlexp-monitor` can **adopt**
jobs you launched by hand (Slurm job IDs, a W&B group, or an experiment log) with
no prior `/mlexp-new`.

**You're in the loop for three calls that change the science:** `/mlexp-new` (the
idea + ablation design), `/mlexp-implement` (the implementation plan + code review),
and **approving any fix that revises experiment code or a config** while debugging.
Everything **operational** — submit, monitor, auto-resume/requeue, fix a bad
submission parameter or a dead node, resubmit, report — runs autonomously and never
pauses to ask, so the monitor can run unattended under `/loop`. It won't edit
baselines, delete artifacts, or merge to main on its own; it surfaces those as
recommendations.

## Detect current phase and recommend the next step

1. Look for `.mlexp/` (and its `studies/<study>/` subtree) in the user's repo.
2. **First-run bootstrap.** If `.mlexp/config.yaml` is absent or has no resolvable
   `cluster_profile`, offer to create it: pre-fill `wandb.entity/project` from any
   existing W&B config in the repo, and set up the cluster profile by **deferring
   to existing project memory** — if the repo has a `CLAUDE.md`/`AGENTS.md`/docs
   that already document submission, offer to write `.mlexp/cluster-<name>.md` as a
   one-line `inherits: ../CLAUDE.md` (+ any deltas) rather than re-authoring; else
   offer to copy `references/cluster-template.md` for the user to fill in. (See
   `references/cluster-template.md` resolution order.)
3. If no study exists: suggest `/mlexp-new` (or `/mlexp-monitor` to adopt existing
   jobs).
4. If a study exists: read its `study.yaml` and `events.jsonl`, and the latest
   `attempt.yaml` per experiment, then:
   - experiments planned but no attempts → recommend `/mlexp-implement` then
     `/mlexp-submit`.
   - attempts running/pending → recommend `/mlexp-monitor` (offer to run it
     under `/loop`).
   - failures, or terminal-but-unresolved attempts (`resume_decision ∈
     {needs_debug, restart_from_scratch}`) → `/mlexp-monitor` resolves these
     autonomously (auto-resume, auto-dispatch the debugger, in-scope fix, resubmit);
     only a recorded `recommendation` needs you.
   - every experiment **resolved** (latest attempt `lifecycle=terminal` AND
     `resume_decision ∈ {none, do_not_resume}`) → recommend `/mlexp-report`.
5. Summarize the study's health in a short table (experiment → latest attempt →
   lifecycle/scheduler_state/health).

## The rules every MLEXP skill obeys (read as needed)

- `references/state-model.md` — orthogonal state, transitions, Slurm mapping,
  interruption-vs-failure, resume rules, health, idempotency, failure classifier.
- `references/file-layout.md` — the exact on-disk schema.
- `references/protocol-rules.md` — primary-metric immutability, no p-hacking,
  report separation, the autonomy rule and the 3 actions never done automatically.
- `references/feedback-ladder.md` — the rungs and gate policy.
- `references/cluster-template.md` — cluster submission-convention template; your
  real, site-specific profile lives in `.mlexp/cluster-<profile>.md`.

Non-negotiables: orthogonal state (never one flat enum); preemption ≠ failure;
primary metric frozen after `/mlexp-new`; **autonomous for operations, ask before
changing the science** — operational fixes (submit params, bad node, infra) run
unattended, but a fix that revises experiment code or a config is proposed for the
user's OK; the 3 destructive actions are never done autonomously (recommended
instead); no hidden concurrency/resubmit caps; idempotency via grepping
`events.jsonl` before any expensive action.
