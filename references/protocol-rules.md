# MLEXP Protocol Rules (immutability, no p-hacking, autonomy)

These rules protect the integrity of the confirmatory claim. Every skill obeys
them.

---

## 1. The primary metric is immutable

At study creation, `mlexp-new` freezes the confirmatory protocol into
`protocol.lock.yaml`. The frozen fields are:

```
primary_metric.name
primary_metric.direction
primary_metric.aggregation
primary_metric.checkpoint_selection
primary_metric.comparison_baseline
primary_metric.success_criterion
```

**After freezing, do not change any of these.** A skill asked to change a frozen
field MUST refuse and respond:

> The primary-metric protocol is frozen for this study (`protocol.lock.yaml`,
> hash `…`). I can't change `<field>`. To use a different primary metric,
> create a new study with `/mlexp-new`. I *can* add this as an **exploratory**
> metric if you'd like.

A skill may recompute `protocol_hash` from the `primary_metric` block at any time
to detect tampering; a mismatch is a hard error to surface to the user, never to
silently "fix."

---

## 2. Exploratory metrics & analyses are allowed (and tracked)

You MAY add, at any time:
- an exploratory metric (e.g. time-to-threshold, memory-normalized accuracy),
- an exploratory analysis (e.g. convergence speed),
- a diagnostic plot (e.g. gradient norm over time),
- a post-hoc failure analysis.

Each addition MUST:
- be logged with an `exploratory_metric_added` event,
- be clearly labeled **exploratory**,
- **never** be used to claim the original idea succeeded.

---

## 3. No p-hacking by protocol amendment

**Allowed:**
- Add exploratory metric: training-stability score.
- Add exploratory analysis: time-to-threshold.
- Add diagnostic plot: gradient norm over time.
- Add post-hoc failure analysis.

**Not allowed:**
- Variant lost on the primary metric → change the primary metric to one it wins.
- Variant lost under mean-across-seeds → report only the best seed as primary.
- Variant lost under best-validation checkpoint → switch to final checkpoint as
  primary.

If a variant loses on the frozen protocol, that is the confirmatory result.
Exploratory findings can motivate a *new* study; they cannot rewrite this one's
verdict.

---

## 4. Report separation (enforced by `mlexp-report`)

A report MUST present these sections, in order, and keep the confirmatory result
separate from everything else:

```
1. Objective
2. Frozen primary-metric protocol
3. Study matrix
4. Run manifest
5. Confirmatory result        ← uses ONLY the frozen protocol
6. Guardrail metrics
7. Training dynamics
8. Interruptions and resumes
9. Failures and exclusions
10. Exploratory analysis      ← clearly labeled, cannot override §5
11. Decision
12. Recommended next experiments
```

The **Confirmatory result** (§5) is computed strictly from the frozen
`primary_metric` (name, direction, aggregation, checkpoint_selection,
comparison_baseline, success_criterion). Exploratory/diagnostic/failure content
lives only in §6–§10.

---

## 5. Autonomy — operational vs. experiment, and the three never-auto actions

MLEXP runs the **operational grind** on its own, but a human stays in the loop for
anything that changes the **science**. Three human-in-the-loop decisions:

- **`/mlexp-new`** — the idea, the ablation design, and the frozen primary-metric protocol.
- **`/mlexp-implement`** — the implementation plan and the code review.
- **Any fix that revises experiment code or a config/hyperparameter.** When debugging
  a real bug, the agent root-causes it and prepares the fix (plus the cheap test that
  catches it), then **stops and asks you before editing**. On your OK it applies the
  fix behind the rungs and resubmits on its own.

Failures split into two kinds, with two responses:

- **Operational** — the experiment's code/config is fine; it failed in *how or where
  it ran*: a wrong submission-script parameter (partition, walltime, `--gres`,
  `--mem`, account, env activation), a broken/unhealthy node, a filesystem/scheduler/
  infra hiccup, a W&B/network problem, or a preemption/requeue/timeout. → The agent
  **fixes it and resubmits autonomously** — corrects the submit script / environment,
  moves off the bad node, resumes from checkpoint. No asking.
- **Experiment** — the fix changes model code, training logic, or an experiment
  config/hyperparameter (it touches the science or what's being compared): a real code
  bug, a NaN needing a numerics/code change, a bad experiment config, or an OOM that
  can only be fixed by changing batch size / seq length / the model. → The agent
  **proposes the fix and asks you first.** (OOM nuance: if more `--mem` / a bigger GPU
  / fewer procs fixes it without changing the experiment's effective setup, that's
  operational — autonomous; if it needs a smaller batch or a model change, that's an
  experiment change — ask.)

Three actions are destructive or irreversible and are **never done automatically**:

```
modifies_baseline_code
deletes_checkpoint_dataset_or_wandb_artifact
merges_experiment_branch_to_main
```

The agent never does these and never blocks for them — it logs a **`recommendation`**
event (kind + reason + affected paths + suggested action), surfaced in the
`/mlexp-report` decision section, and performs one only on an **explicit in-session
user instruction** (e.g. "merge `exp/...` to main").

**Detection** of an experiment-code change is a `git diff` against `repo.baseline_ref`
/ the experiment's config paths; run it before submit and before applying any debugger
fix. A baseline-touching change → recommendation (never auto). An in-scope
code/config change → propose and ask. An operational (submit-script/env) change →
just do it.

### Done autonomously, no prompt

```
submit the plan's experiments              resume / requeue after an interruption
restart a no-checkpoint interruption       fix a bad submission-script param and resubmit
move a run off a broken node               handle W&B / network / infra hiccups
add an exploratory metric or analysis      create the report
create a debug branch / worktree           run tests · pull W&B data
```

### Asks you first

```
revise experiment code        change an experiment config / hyperparameter
(+ the 3 destructive actions above — only on an explicit user request)
```
