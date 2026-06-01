---
name: mlexp-new
description: Use to turn an ML research idea into a study — design the ablation matrix, write the plan, and freeze the primary-metric protocol. Run before launching experiments.
---

# mlexp-new — idea → study

Turns a research idea into a **Study**: an objective, an enumerated ablation
matrix, a plan, and a **frozen** primary-metric protocol. Read
`references/file-layout.md` and `references/protocol-rules.md` first.

## Workflow

1. **Brainstorm the study.** Invoke the `superpowers:brainstorming` skill to
   shape: the objective, the baseline, the variants, the seeds, the primary
   metric + its direction/aggregation/checkpoint-selection/success criterion, the
   guardrail metrics, and the resource assumptions. One question at a time.

2. **Plan it.** Invoke the `superpowers:writing-plans` skill to produce `plan.md`
   — the implementation plan, the test plan (mapped to the feedback-ladder
   rungs in `references/feedback-ladder.md`), the Slurm plan, the W&B logging
   plan, and the checkpoint/resume plan. State explicitly what jobs will launch,
   what configs will be generated, and what branch/worktree will be used.

3. **Write the study artifacts** under `.mlexp/studies/<study-id>/`
   (`<study-id> = study-YYYY-MM-DD-<slug>`):
   - `objective.md` — the prose objective + risks.
   - `study.yaml` — per the schema in `references/file-layout.md`, with the
     `experiments:` list **enumerated explicitly** (every variant × seed). Do
     NOT add `max_active_jobs` or `max_resubmits_per_run`.
   - `plan.md` — from step 2.

4. **Freeze the protocol.** Write `protocol.lock.yaml`: copy
   `study.yaml.primary_metric` verbatim, compute `protocol_hash` (sha256 of the
   canonicalized primary_metric block, sorted keys), set `protocol_created_at`.
   From now on the primary metric is immutable (`references/protocol-rules.md`).
   If the user later asks to change it, refuse and offer a new study or an
   exploratory metric.

5. **Log events** to `.mlexp/studies/<study-id>/events.jsonl`: `study_created`,
   then one `experiment_created` per experiment, then `protocol_locked`.

6. **Dry-run summary.** Print:
   - number of experiments and initial Slurm jobs to submit,
   - the variants and seeds,
   - estimated GPUs and walltime (from `references/cluster-template.md`
     conventions + the plan),
   - the frozen primary-metric protocol,
   - what MLEXP will check back with you on later — any fix that changes experiment
     code or a config, plus the 3 protected actions (baseline edit / delete / merge,
     recorded as recommendations) — and that everything operational (submit, resume,
     bad-parameter / bad-node fixes) runs autonomously.

## Guardrails

- Do not generate code here — that is `/mlexp-implement`. This skill produces the
  plan and the frozen protocol only.
- The `experiments:` list is the entire plan. There are no hidden caps; the
  number of jobs is whatever the user and plan decided.
- After this skill, hand off to `/mlexp-implement`.
