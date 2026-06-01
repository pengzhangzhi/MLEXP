---
name: mlexp-debug
description: Use to root-cause and fix a failed experiment from its evidence pack — produces a hypothesis with evidence, a fix, tests, and a resubmission recommendation. Not for scheduler interruptions.
---

# mlexp-debug — evidence pack → root cause → fix

Root-causes a **real** failure and proposes a verified fix. Read
`references/state-model.md` (failure classifier) and
`references/feedback-ladder.md` first.

## Not for scheduler interruptions

If the input is a preemption / requeue / time-limit / node-failure (an
*interruption*, not a *failure*), STOP and redirect: that is `/mlexp-monitor`'s
resume path, not a bug. Only proceed for `oom / nan / code / data / config /
environment / checkpoint_load` failures.

## Workflow

1. **Load the evidence.** Read the anomaly pack
   `evidence/anomalies/<attempt>-<reason>/` (summary, sacct, stderr/stdout tails,
   config, `git_diff.patch`, recent W&B, checkpoint info, suspected_causes). If no
   pack exists yet, build one the way `/mlexp-monitor` does before debugging.

2. **Debug systematically.** Invoke the `superpowers:systematic-debugging` skill,
   and dispatch the `mlexp-debugger` subagent with the evidence pack. Form a root
   cause from evidence — reproduce at the cheapest ladder rung that exhibits it
   (e.g. OOM → tiny-batch on an interactive GPU with the real batch size; NaN →
   tiny overfit) rather than another multi-day run.

3. **Produce the required output:**
   - root-cause hypothesis + the specific evidence supporting it,
   - a fix plan,
   - the fix (operational submit/env changes applied directly; experiment code/config
     changes proposed for the user's OK; never baseline),
   - tests that would have caught it (added to the cheap rungs),
   - a resubmission recommendation (resume from checkpoint vs restart, with which
     config change).

4. **Apply the fix by kind — the human gate** (`references/protocol-rules.md` §5):
   - **Operational** (a submission-script param — partition/walltime/`--gres`/`--mem`/
     account/env — a broken node, or infra): the experiment's code/config is fine, so
     correct the submit script / environment and resubmit **autonomously**, no asking.
   - **Experiment** (changes model code, training logic, or a config/hyperparameter,
     including an OOM that needs a smaller batch/seq or a model change): do **not**
     edit yet — present the root cause + the proposed diff + the cheap test, and **ask
     the user**; apply it only on their OK (`resume_decision=needs_user_decision`
     until then), then re-gate and resubmit.
   - **Baseline / protected code, deleting an artifact, merging to main**: never do
     it — record a `recommendation` (proposed diff + rationale) for the human.

5. **Re-gate before resubmit.** Re-run the cheap rungs (1–3) so the fix is
   verified cheaply, then hand back to `/mlexp-submit` (or `/mlexp-monitor`'s
   resume path). Log `debugger_invoked` and the outcome.

## Guardrails

- Evidence over claims: every hypothesis cites a concrete log line / metric /
  diff. No speculative "probably the LR" without evidence.
- Treat preemption/requeue/walltime/node-failure as normal, never as bugs.
- Update durable memory via `mlexp-librarian` if the failure is a reusable lesson
  (e.g. "OOM when batch>X on A100 80GB for this model").
