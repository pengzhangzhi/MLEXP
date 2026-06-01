# MLEXP Acceptance Walkthroughs

The plugin is pure markdown, so "done for v0" is validated by walking each
acceptance criterion (design spec §14) through the skills against a concrete
scenario, plus the grep self-checks at the end. Each walkthrough lists the
*scenario*, the *steps*, and the *expected* file/state result.

---

## 1. Study creation artifacts

- **Scenario:** user has an idea "replace AdamW with Muon — AdamW baseline vs Muon, 3 seeds each".
- **Steps:** `/mlexp-new`.
- **Expected:** `.mlexp/studies/study-*/` contains `objective.md`, `plan.md`,
  `study.yaml` (with 6 experiments enumerated = 2 variants × 3 seeds, no `max_*`
  fields), and `protocol.lock.yaml` with a `primary_metric` block + a
  `protocol_hash: sha256:...`. `events.jsonl` has `study_created`, 6×
  `experiment_created`, `protocol_locked`.

## 2. Primary-metric immutability + exploratory addition

- **Scenario:** after creation, user says "change the primary metric to
  val/loss"; then "add time-to-threshold as a metric".
- **Steps:** ask any skill.
- **Expected:**
  - Change request is **refused** with the message in `references/protocol-rules.md`
    (offers a new study or an exploratory metric); `protocol.lock.yaml` is
    unchanged; `protocol_hash` still matches.
  - The exploratory add **succeeds**, is labeled exploratory, and appends an
    `exploratory_metric_added` event. It is never usable for the confirmatory
    claim.

## 3. Adoption with no prior study

- **Scenario:** user already launched 4 jobs by hand: `squeue` shows ids
  20001–20004; no `.mlexp/studies/` dir exists.
- **Steps:** `/mlexp-monitor 20001 20002 20003 20004` (or point at a W&B group).
- **Expected:** a `study-*/` is created with `objective: "adopted"`; 4
  `experiment.yaml` + `attempt.yaml` map the job ids; each logs an
  `attempt_adopted` event; the normal reconcile cycle then runs. If no primary
  metric is set, the tool notes no confirmatory claim is possible until one is.

## 4. Orthogonal state (running + stalled simultaneously)

- **Scenario:** `squeue` shows job RUNNING, but W&B step has not advanced and no
  new checkpoint for longer than the stall threshold.
- **Steps:** `/mlexp-monitor`.
- **Expected:** the attempt's `attempt.yaml` holds
  `lifecycle: running, scheduler_state: running, health: stalled,
  terminal_outcome: none, failure_reason: none` — all simultaneously. (A flat
  enum could not represent this; orthogonality is the point.)

## 5. PREEMPTED + checkpoint → interrupted + resume, NO debugger

- **Scenario:** `sacct -j 12345 -o State` → `PREEMPTED`; a checkpoint
  `.../checkpoints/step_120000.pt` exists.
- **Steps:** `/mlexp-monitor`.
- **Expected:** terminal attempt gets
  `terminal_outcome: interrupted, interruption: preempted, failure_reason: none,
  resume_decision: resume_from_checkpoint`. An **interruption record** appears
  under `evidence/interruptions/attempt-001-preempted/` (NOT under
  `evidence/anomalies/`). A new `attempt-002` is created
  (`resume_from_checkpoint_step: 120000`) and submitted. Events:
  `interruption_detected`, `resume_decision_set`, `run_resumed`. **No**
  `debugger_invoked`, **no** anomaly pack.

## 6. OUT_OF_MEMORY → failed + needs_debug + anomaly pack + debugger

- **Scenario:** `sacct` → `OUT_OF_MEMORY` (or stderr "CUDA out of memory").
- **Steps:** `/mlexp-monitor`.
- **Expected:** attempt gets
  `terminal_outcome: failed, interruption: none, failure_reason: oom,
  resume_decision: needs_debug`. An **anomaly evidence pack** appears under
  `evidence/anomalies/attempt-NNN-oom/` (summary, sacct, stderr/stdout tails,
  config, git diff, recent W&B, checkpoint, suspected_causes). The
  `mlexp-debugger` subagent is dispatched. Events: `failure_detected`,
  `evidence_pack_created`, `debugger_invoked`. The debugger then splits the FIX: if
  the OOM is **operational** (fixable by more `--mem` / a bigger GPU / fewer procs),
  the agent corrects the submit script and resubmits autonomously; if it needs an
  **experiment** change (smaller batch/seq or a model change), the agent does NOT edit
  — it proposes the fix and sets `resume_decision=needs_user_decision` for the user's
  OK (no autonomous code/config edit).

## 7. Idempotent double-run

- **Scenario:** run `/mlexp-monitor` twice over the exact same ground truth
  (e.g. the §5 preemption).
- **Steps:** `/mlexp-monitor` then immediately `/mlexp-monitor` again.
- **Expected:** the second run produces **no** duplicate attempt, **no** duplicate
  evidence dir, **no** duplicate resume submission, **no** duplicate events —
  because each action's idempotency key (`resume:…`, `evidence:…`, `debug:…`,
  `submit:…`) is already present in `events.jsonl` and is skipped.

## 8. The 3 protected actions are never taken autonomously (and never block)

- **Scenario A:** a debugger fix would need to edit a file outside the experiment's
  paths (touches baseline). **Scenario B:** the autonomous cycle could delete an old
  checkpoint. **Scenario C:** the cycle could merge `exp/...` into `main`.
  **Scenario D:** normal submit / resume / report / in-scope debugger fix.
  **Scenario E:** the user *explicitly* says "merge `exp/...` to main".
- **Steps:** trigger each.
- **Expected:** A/B/C — the agent does **not** perform the action and does **not**
  pause to ask. It applies any safe in-scope alternative, logs a `recommendation`
  (kind + reason + affected paths + suggested action), and keeps going; the
  recommendation surfaces in the report's Decision section. D proceeds with no
  prompt. E (an explicit user instruction) proceeds, logging `approval_requested`
  then `approval_granted`. At no point does an unattended cycle block waiting on a
  human.

## 9. Report confirmatory-vs-exploratory separation

- **Scenario:** study finished; variant loses on the frozen primary metric but
  wins on an exploratory metric.
- **Steps:** `/mlexp-report`.
- **Expected:** `analysis/report.md` has the fixed sections in order; the
  **Confirmatory result** uses only the frozen protocol and reports the loss; the
  exploratory win appears only in the labeled **Exploratory analysis** section and
  does not change the verdict. `run_manifest.csv` has all §16.4 columns.

## 10. No hidden caps

- **Scenario:** inspect the whole plugin and any generated `study.yaml`.
- **Steps:** the grep below.
- **Expected:** `max_active_jobs` / `max_resubmits_per_run` appear **nowhere**.

## 11. Second interruption at the same checkpoint step still resumes

- **Scenario:** `attempt-002` (itself a resume from step 120000) is PREEMPTED
  again with the latest checkpoint still at step 120000.
- **Steps:** `/mlexp-monitor`.
- **Expected:** a new `attempt-003` is created and submitted. The resume
  idempotency key encodes the consuming attempt
  (`resume:<exp>:into=attempt-003:from_step=120000`), so it is **distinct** from
  attempt-002's key and the resume is **not** wrongly skipped. Re-running the tick
  does not create a duplicate (the key now exists in attempt-002's `events.jsonl`).

## 12. Stalled escalation only with code-level evidence

- **Scenario A:** a RUNNING job with a deadlock traceback in stderr and no step
  progress for well beyond the threshold. **Scenario B:** a RUNNING job that is
  merely slow (W&B step advancing slowly, no error).
- **Steps:** `/mlexp-monitor`.
- **Expected:** A → `health=stalled` *with evidence* escalates to a real failure
  (anomaly evidence pack + `mlexp-debugger` dispatched). B → surfaced to the user
  as `suspect`/`stalled` but **not** escalated (no debugger, no evidence pack) —
  the interruption≠failure / no-debugger-spam rules hold.

## 13. Operational failure → autonomous fix; experiment fix → asks first

- **Scenario A (operational):** a job fails because the submit script requested too
  little walltime, the wrong partition, or too little `--mem` (not a code bug); or a
  `NODE_FAIL` on an unhealthy node with a valid checkpoint.
- **Scenario B (experiment):** an OOM or NaN whose only fix changes an experiment
  config/hyperparameter or model code (e.g. a smaller batch, or Newton-Schulz in fp32).
- **Steps:** `/mlexp-monitor`.
- **Expected:** A — the agent corrects the submission-script parameter / moves off the
  bad node and **resubmits autonomously**; no `needs_user_decision`, no prompt;
  experiment code and config untouched. B — the debugger root-causes and **proposes**
  the fix, sets `resume_decision=needs_user_decision`, and surfaces it for the user's
  OK; it does **not** edit code/config autonomously, and the monitor keeps managing
  the other experiments meanwhile.

---

## Grep self-checks (run from the plugin root)

```bash
# Criterion 10 — caps are never operative fields. In the plugin these names appear
# ONLY as prohibitions; in a user's generated study they must not appear at all.
#   (a) generated studies carry zero cap fields:
grep -rn "max_active_jobs\|max_resubmits_per_run" ../.mlexp/studies/ 2>/dev/null \
  && echo "FAIL: a cap leaked into a study" || echo "PASS: no caps in generated studies"
#   (b) every plugin mention is a negation — eyeball that each line says "No"/"do not add":
grep -rn "max_active_jobs\|max_resubmits_per_run" . | grep -v VALIDATION.md

# 'preempted' is never STORED as a failure_reason; the only mention is the NEVER rule:
( grep -rln "failure_reason=preempted\|failure_reason: preempted" . \
    | grep -v "references/state-model.md" | grep -v VALIDATION.md ) \
  && echo "FAIL: preempted stored as a failure" || echo "PASS: only the NEVER rule references it"

# Every referenced doc exists:
python3 - <<'PY'
import re, glob, os
refs=set()
for f in glob.glob('skills/*/SKILL.md')+glob.glob('agents/*.md'):
    refs |= set(re.findall(r'references/[\w\-]+\.md', open(f).read()))
missing=[r for r in sorted(refs) if not os.path.exists(r)]
print('referenced:', sorted(refs)); print('MISSING:', missing); assert not missing
PY
```
