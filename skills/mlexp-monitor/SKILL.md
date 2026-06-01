---
name: mlexp-monitor
description: Use to check on running ML experiments — reconciles Slurm/W&B/checkpoint state, auto-resumes interruptions, builds evidence packs and dispatches the debugger on real failures. Run on demand or under /loop to keep watching. Triggers on "check on my jobs / are my runs ok / monitor my experiments".
---

# mlexp-monitor — the reconcile loop

The automation of "check on my jobs." It reconciles each active attempt against
ground truth (Slurm + W&B + checkpoints + logs), applies the rules in
`references/state-model.md`, and acts: auto-resume interruptions, build evidence
+ dispatch the debugger on real failures, leave healthy runs alone. **Read
`references/state-model.md` and `references/file-layout.md` before acting.**

It is deterministic-by-discipline: same ground truth → same decisions; every
expensive action is idempotency-guarded by grepping `events.jsonl`.

## Autonomous for operations — ask before changing the science

The monitor runs **unattended** (often under `/loop`, frequently with no one
watching) and handles all **operational** trouble itself, no asking: resume / requeue
an interruption, restart a no-checkpoint interruption, fix a bad submission-script
parameter (partition/walltime/`--gres`/`--mem`/account/env) and resubmit, move a run
off a broken node, ride out W&B/infra hiccups. It escalates real failures to the
debugger to root-cause.

It does **not** change the science unattended. If the fix would **revise experiment
code or a config/hyperparameter**, the debugger proposes it and the monitor
**surfaces it for your OK** (`resume_decision=needs_user_decision`) — it does not edit
code/config on its own — then keeps managing every other experiment. It also **never**
edits baseline code, deletes a checkpoint/artifact, or merges to main; it records a
`recommendation` instead. See `references/protocol-rules.md` §5. Human in the loop:
`/mlexp-new` (design), `/mlexp-implement` (plan), and approving any code/config fix.

## Reconcile cycle (per active attempt)

For each attempt whose `lifecycle ∈ {submitted, pending, running}`:

### 1. Observe (read-only)
- `sacct -j <slurm_job_id> -n -o State,ExitCode,Elapsed,MaxRSS` (and `squeue -j
  <id>` for live state). SLURM binaries are on the IDE node PATH — no `srun`.
- W&B (optional signal): latest step, latest update timestamp, whether the
  primary/loss metrics are finite (use the entity/project/run from `attempt.yaml`),
  e.g. `python -c 'import wandb; r=wandb.Api().run("<entity>/<project>/<run_id>"); print(r.lastHistoryStep, dict(r.summary))'`.
  **If W&B is unconfigured or unreachable, degrade gracefully** — rely on
  checkpoint mtime/step + log tails for progress/health (never block, never call a
  W&B outage a training failure).
- Checkpoint freshness: glob `study.yaml.checkpointing.checkpoint_glob`, parse
  step via `step_regex`, read mtime — newest wins.
- Tail `stdout.log` / `stderr.log` (~200 lines).

### 2. Classify (pure rules from state-model.md)
- Map the Slurm state → `scheduler_state` + lifecycle/terminal fields (§3 mapping).
- Decide **interruption vs failure** (§4 keystone). Preemption / requeue /
  timeout / node-failure / maintenance are interruptions, **never** `failure_reason`.
- If running: evaluate **phase-aware health** (§6) → warming_up / healthy /
  suspect / stalled.
- If a real failure: classify `failure_reason` from the evidence (§8).

### 3. Act (idempotent — build the key, grep events.jsonl, skip if present)

**Interruption + checkpoint exists** — idempotency key
`resume:<exp_id>:into=attempt-<NNN+1>:from_step=<step>` (NNN+1 = the new attempt
index), grepped in the terminal attempt's `events.jsonl`:
- Set the terminal attempt: `terminal_outcome=interrupted, interruption=<reason>,
  resume_decision=resume_from_checkpoint`, update checkpoint fields, `ended_at`.
  Append `interruption_detected` (carrying the `resume:` key) + `resume_decision_set`.
- Write an **interruption record** under `evidence/interruptions/<attempt>-<reason>/`
  (`summary.md, slurm_state.json, checkpoint.yaml, resume_decision.yaml`).
- Create the next attempt (`attempt-NNN+1`) with `parent_attempt_id`,
  `resume_from_attempt_id`, `resume_from_checkpoint_path/step`, `resume_reason`,
  then submit it via the `/mlexp-submit` render+sbatch path with `RESUME_ARG` set.
  **Write order (state-model §7):** grep `submit:<exp_id>:attempt-<NNN+1>`
  immediately before `sbatch`; append `slurm_submitted` (carrying that key)
  immediately after capturing the job id; then `run_resumed`.
- **Do NOT dispatch the debugger.**

**Interruption + no checkpoint** — autonomous, no asking:
- First time: `terminal_outcome=interrupted, interruption=<reason>,
  resume_decision=restart_from_scratch`. Write the interruption record, create the
  next attempt (`resume_from_checkpoint_step: 0`, `resume_reason: no_checkpoint_restart`)
  and submit it. No debugger — the run simply hadn't checkpointed yet.
- If the experiment has already restarted from scratch and STILL produced no
  checkpoint (≥2 no-checkpoint attempts), checkpointing is likely broken: set
  `failure_reason=checkpoint_missing, resume_decision=needs_debug`, build an anomaly
  evidence pack, and dispatch the debugger to find why no checkpoint is written.

**Same-job requeue** (Slurm shows the same id back in PENDING/RUNNING):
- `interruption=requeued, resume_decision=wait_for_scheduler_requeue`,
  `lifecycle` back to `pending`. Do nothing else; Slurm restarts it.

**Terminal success:** `lifecycle=terminal, terminal_outcome=succeeded`; update
final checkpoint; leave it.

**Real failure** (oom/nan/code/data/config/environment/checkpoint_load):
- `lifecycle=terminal, terminal_outcome=failed, failure_reason=<reason>,
  resume_decision=needs_debug`.
- Build an **anomaly evidence pack** (next section), key
  `evidence:<attempt_id>:<failure_reason>`.
- Dispatch the `mlexp-debugger` subagent, key `debug:<attempt_id>:<failure_reason>`.
  **Fan out in parallel** when several attempts failed (one debugger per pack).
- **Apply the outcome (state-model §5 split).** If the debugger's fix is
  **operational** (submission-script param / env / broken node / infra), correct it
  and resubmit autonomously. If it would **change experiment code or a config**, do
  NOT edit — set `resume_decision=needs_user_decision`, record the proposed fix +
  test, surface it for the user's OK, and move on to other experiments. Baseline
  edits / deletes / merges → `recommendation`, never auto.
- Append `failure_detected`, `evidence_pack_created`, `debugger_invoked`.

**Running but stalled / persistent suspect / NaN — escalation:** if a still-running
attempt is classified `health=stalled` *with code-level evidence* (a deadlock/hang
traceback, a repeated identical log line, or no step progress AND no new checkpoint
for well beyond the threshold), or a NaN persists per §6, treat it as a real
failure: set `failure_reason` accordingly (`nan`, or `code`/`data` where the
evidence supports it), build the anomaly evidence pack
(`evidence:<attempt_id>:<failure_reason>`), and dispatch `mlexp-debugger`
(`debug:<attempt_id>:<failure_reason>`). A `stalled`/`suspect` run with NO
code-level evidence is surfaced to the user but **not** escalated — don't
debugger-spam a slow-but-live job; keep the interruption≠failure rule intact.

**Running & healthy:** update `health`, `last_seen_step`, `last_*_at`; append
`scheduler_state_changed` / `training_health_changed` / `checkpoint_updated` only
when a value actually changed. Then leave it alone.

### 4. No debugger spam
Never build an anomaly pack or dispatch the debugger for: preempted, requeued,
time_limit (with valid checkpoint), node_failure (with valid checkpoint), or a
transient W&B delay during the warmup phase. Those get interruption records.

## Anomaly evidence pack (real failures)

Write `evidence/anomalies/<attempt>-<failure_reason>/`:
```
summary.md          one-paragraph what/where/when + classified failure_reason
sacct.txt           full sacct -j <id> output
slurm_state.json    the mapped state block
stderr_tail.txt stdout_tail.txt   last ~200 lines each
config.yaml         the experiment config
git_commit.txt git_diff.patch     commit + diff vs baseline_ref
wandb_recent.parquet wandb_summary.json   recent history + summary
checkpoint.yaml     latest checkpoint info (if any)
suspected_causes.md initial hypotheses (handed to the debugger)
```

## Standalone adoption (no prior /mlexp-new)

Babysit jobs you launched by hand. **Adoption inputs** (what to type):
```
/mlexp-monitor <study>                       # an existing study
/mlexp-monitor <jobid> [<jobid> ...]         # adopt by Slurm job id(s)
/mlexp-monitor <entity>/<project>/<group>    # adopt a W&B group (or a W&B run URL)
/mlexp-monitor <path/to/experiment-log>      # adopt from a log: ≥1 slurm job id and/or wandb run id per line
```
Steps:
1. Create `.mlexp/studies/<study-id>/study.yaml` with `objective: "adopted"`. Infer
   the primary metric from the run config / W&B if you can; otherwise mark it
   `unknown` and NOTE that no confirmatory claim is possible until one is set via a
   new study — do not block. **Populate the `checkpointing` block** — the monitor
   needs it for resume + checkpoint-based health: infer `checkpoint_glob`/`step_regex`
   from each job's submit script or run/output directory. If they are not inferable,
   NOTE that resume + checkpoint-health are disabled for these runs and keep
   monitoring Slurm state — do not block on a human.
2. For each job/run create an `experiment.yaml` + `attempts/attempt-001/attempt.yaml`
   mapping `slurm_job_id` / `wandb_run_id`, with `parent_attempt_id: null` and
   `git_commit`/`config_hash` = `"unknown (adopted)"`. Set the attempt's initial
   `lifecycle` by mapping its CURRENT `sacct`/`squeue` state via state-model §3 — so
   a job that already COMPLETED/FAILED/PREEMPTED is created already-terminal. Append
   `attempt_adopted`.
3. Run the Classify/Act step once over EVERY freshly adopted attempt **regardless of
   its starting lifecycle** — so an adopted-but-already-failed job still gets its
   evidence pack / interruption record this tick (the normal reconcile gate only
   enters non-terminal attempts).

`/mlexp-report` marks adopted runs and excludes them from the confirmatory primary
analysis with `exclusion_reason: "adopted: provenance unknown"` unless provenance
is supplied.

## Always-on usage

Run under `/loop` to keep watching, e.g. `/loop 15m /mlexp-monitor <study>`. Each
tick re-reads ground truth and reconciles (safe — idempotent). Adapt cadence to
phase (warming-up/early/mid/near-done).

**Stop condition.** An experiment is **resolved** when its latest attempt is
`lifecycle=terminal` AND `resume_decision ∈ {none, do_not_resume}` (succeeded, or
interrupted-then-resumed-to-success). A `needs_debug` attempt is **not** a stopping
point — the debugger root-causes it; an **operational** fix is applied and resubmitted
autonomously (keep ticking), while a **code/config** fix is proposed and parked at
`needs_user_decision` for your OK (that one experiment waits on you; the others keep
going). A `restart_from_scratch` spawns a fresh attempt next tick. Stop `/loop` when
every experiment is either **resolved** or **parked awaiting you** (a proposed
code/config fix at `needs_user_decision`, or a recorded `recommendation`): surface
those items (they also appear in the report) and stop — never spin, and never wait on
a human mid-loop for the rest. Session-bound (lives while the Claude Code session
lives), not an OS daemon.

## Output each run

A short table: experiment → latest attempt → `lifecycle / scheduler_state /
health`, plus what was done this tick (resumed N, evidence packs M, debuggers K,
no-ops). Cite the evidence (sacct line / W&B step / checkpoint mtime) for each
state change — evidence over claims.
