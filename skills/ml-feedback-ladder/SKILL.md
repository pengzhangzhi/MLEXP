---
name: ml-feedback-ladder
description: Use when planning how to verify an ML experiment cheaply before expensive runs - design the R0-R7 ladder from local sanity checks to full study, with promotion/stop criteria.
---

# ML Feedback Ladder

## Overview

In normal software, a passing test suite can mean the code works. In ML research, passing tests only show the code PATH might run - they do NOT show the method works. You need STAGED EMPIRICAL verification, ordered cheapest-to-expensive, where every cheap check GATES the expensive cluster/GPU jobs below it.

This skill OWNS the canonical ladder. Design the rungs for ONE specific experiment with your human partner before launching anything.

**Core principle:** Cheap checks gate expensive jobs. Never spend a slow rung to find a bug a fast rung would have caught.

**Upstream:** the experiment, metric, and protocol come from `superpowers-ml:ml-experiment-design`.
**Downstream:** the ladder you design here becomes verification steps in `superpowers-ml:writing-plans`, and the final rung hands off to `superpowers-ml:ml-result-review`.

## The Ladder

Each rung names what it CHECKS, the ARTIFACT that proves it passed, and rough COST. Cost is relative - a rung is "expensive" if it consumes a scheduled GPU/cluster job.

| Rung | Checks | Proof artifact | Cost |
|------|--------|----------------|------|
| **R0** | Experiment card / protocol defined: question, locked primary metric, baseline, decision rule | The experiment card itself | minutes, no compute |
| **R1** | Code / import / config / static sanity: it imports, config parses, paths resolve, seeds set | Clean import + config dump + linter | seconds, dev node |
| **R2** | Shape / dtype / device / one-batch forward+backward: loss is finite, gradients flow | Logged shapes/dtypes/device + one non-NaN loss + non-zero grads | seconds-minutes, dev node |
| **R3** | Tiny overfit: a handful of examples driven to ~zero loss (or memorized) | Loss curve collapsing to near-zero on the tiny set | minutes, dev node / 1 GPU |
| **R4** | Real launcher smoke run: the ACTUAL launch path (local GPU or cluster smoke job) starts, checkpoints, logs, resumes - on tiny data/steps | Launcher exits 0, checkpoint written, logs/metrics emitted | one short job |
| **R5** | Short pilot / early signal: real data, real config, truncated budget; metric is moving the right way and is stable | Early metric curve vs. baseline on the locked metric | a fraction of a full run |
| **R6** | Full run / full study: the locked protocol at full budget, seeds/sweeps as specified | Complete metrics across all planned seeds/conditions | the expensive job(s) |
| **R7** | Result review / decision memo: compare to baseline under the locked primary metric, decide | Decision memo (handed to `superpowers-ml:ml-result-review`) | analysis time |

R0-R3 should run on your dev node in well under an hour. R4+ consume scheduled jobs - protect them.

## Promotion and Stop Criteria

State the gate between EACH adjacent rung before you launch. A rung promotes ONLY when its proof artifact exists and is green.

- **R0 -> R1:** card has a single locked primary metric and an explicit decision rule. No metric, no launch.
- **R1 -> R2:** imports clean, config parses, paths/seeds resolved.
- **R2 -> R3:** one batch forward+backward, loss finite, gradients non-zero on the right devices.
- **R3 -> R4:** tiny set overfits. If it CANNOT overfit a handful of examples, the model/loss/data wiring is broken - fix before any GPU job.
- **R4 -> R5:** real launcher runs end-to-end on tiny budget, checkpoints, resumes, logs the metric.
- **R5 -> R6:** early signal is stable and not obviously worse than baseline. Promote to the expensive full run only here.
- **R6 -> R7:** all planned seeds/conditions complete; metrics intact, no silent failures.

**STOP rule at every rung:** if the proof artifact is missing or red, do NOT spend the next rung. Fix the cheap thing first.

## Policy

State these plainly and hold to them:

- A cheap rung PASSING is a PRECONDITION, not proof of final success. R3 overfitting tells you the plumbing works; it tells you NOTHING about whether the method beats the baseline.
- A cheap rung FAILING means do NOT spend the expensive rung. Diagnose and fix at the lowest rung that reproduces the problem.
- Early signal (R5) may REJECT an obviously bad run - kill it, save the budget. Early signal must NOT claim victory. Only R6/R7 under the locked primary metric can support a "beats baseline" claim.
- Never skip a rung to "save time." A skipped fast rung is paid back as a burned slow job.

## Scheduler-Agnostic

The launcher at R4+ is whatever your cluster uses. Slurm is ONE example (e.g. a small `sbatch` smoke job), not an assumption - the ladder is identical for a bare `torchrun`, a Ray/Kubernetes submission, or a plain SSH-to-GPU script. Design the rungs around YOUR launch path; do not hard-code a scheduler.

## Reporting

Report progress as the highest GREEN rung, and separate what is supported from what is not:

```
Verified through R3 (tiny overfit). Not yet verified by smoke run, pilot, or full study.
```

Never report a method as beating a baseline without R6 (or an equivalent full evaluation) under the locked primary metric.
