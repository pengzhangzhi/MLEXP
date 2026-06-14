# superpowers-ml

`superpowers-ml` is a **conservative fork** of [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent (MIT). It keeps every original skill and the original philosophy unchanged, and adds a small layer of guidance for **ML research**: a vocabulary of staged empirical verification, and three new skills for designing, verifying, and concluding experiments.

Nothing is removed. The ML layer is added as clearly-marked addenda to five existing skills and as three new `ml-*` skills.

## Why a separate layer

In normal software engineering, a passing test suite may be enough to say the code works. **In ML research, passing tests only show the code *path* might run — they do not show the *method* works.** Establishing that needs staged empirical verification, and cheap checks must gate expensive cluster/GPU jobs.

So the ML layer pushes one habit everywhere: **say what you have actually verified, and at what cost — and never confuse "the code runs" with "the method works."**

## Verification rungs (R0–R7)

A shared vocabulary, cheapest to most expensive. The canonical definition lives in the `superpowers-ml:ml-feedback-ladder` skill; everything else just references it.

| Rung | Establishes | Typical evidence |
|------|-------------|------------------|
| **R0** | experiment card / protocol defined | a written experiment card |
| **R1** | code / import / config / static sanity | clean import, lint, config parse |
| **R2** | shape / dtype / device / one-batch forward+backward | a passing one-batch test |
| **R3** | tiny overfit | loss → ~0 on a handful of examples |
| **R4** | real launcher smoke run (local GPU or cluster smoke job) | a short end-to-end run log |
| **R5** | short pilot / early signal | early metric curve vs. baseline |
| **R6** | full run / full study | the full result under the locked metric |
| **R7** | result review / decision memo | a sober conclusion (see `ml-result-review`) |

Report like this:

> Verified through **R3** (tiny overfit). Not yet verified by smoke run, pilot, or full study.

Or, separating support from claims:

> **Supported:** implementation trains stably through R5 pilot.
> **Not supported yet:** variant beats baseline at full scale.

**Policy:** a cheap rung *passing* is a precondition, not proof of final success. A cheap rung *failing* means don't spend the expensive rung — fix first. Early signal can *reject* an obviously bad run, but does not *declare victory* unless the locked protocol says so.

## What the fork adds

**Addenda to five existing skills** (each appended under a `## ML research addendum` heading; original text untouched):

- `brainstorming` — for broad ML research, settle a compact research goal contract first: outcome, evidence bar, current state, full-resource posture after cheap gates, stop/pause rules, and handoff to experiment cards. For narrow experiments, hand off directly to `ml-experiment-design`.
- `writing-plans` — ML plans carry staged verification mapped to rungs, and name the artifact that proves each one.
- `test-driven-development` — ML tests add shape/dtype/device, deterministic tiny-batch, finite-loss, and one-step forward/backward checks.
- `systematic-debugging` — classify ML failures first; treat preemption/requeue as operational, not scientific; treat model/data/HP/metric changes as experiment changes needing approval.
- `verification-before-completion` — state the highest verified rung and its evidence; never claim "beats baseline" without the full evaluation under the locked metric.

**Three new skills:**

- `superpowers-ml:ml-experiment-design` — turn a rough idea into a compact experiment card (R0).
- `superpowers-ml:ml-feedback-ladder` — design the cheapest→expensive verification ladder; owns the R0–R7 definitions and promotion/stop criteria.
- `superpowers-ml:ml-result-review` — produce a sober conclusion separating confirmed results from exploratory observations.

## Conservatism (non-goals)

This is *guidance*, not infrastructure. The fork deliberately does **not** add a database, dashboard, daemon, job manager, HPO engine, or any complex state. Cluster guidance is **scheduler-agnostic** — Slurm appears only as an optional example.

## Attribution & upstream

Forked from [obra/superpowers](https://github.com/obra/superpowers) (MIT), retained in full — see `LICENSE` and `NOTICE`. To pull upstream improvements: `git fetch upstream && git merge upstream/main`, keeping the ML addenda and `ml-*` skills.
