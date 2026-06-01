# MLEXP State Model (the rules engine, in prose)

This is the single source of truth for how MLEXP interprets a run's state. Every
skill — especially `mlexp-monitor` — follows these rules verbatim. The
determinism that matters lives here, not in code.

---

## 1. Orthogonal state fields

**Never collapse these into one enum.** They are independent dimensions; a run
can hold any consistent combination.

```
lifecycle:        created | submitted | pending | running | terminal
scheduler_state:  unknown | submitted | pending | running | completing | completed | failed | cancelled | timeout | preempted | requeued | node_fail | out_of_memory
health:           unknown | not_applicable | warming_up | healthy | suspect | stalled
terminal_outcome: none | succeeded | failed | cancelled | interrupted
interruption:     none | preempted | requeued | time_limit | node_failure | maintenance | unknown
failure_reason:   none | oom | nan | code | data | config | environment | wandb | checkpoint_missing | checkpoint_load | infra | unknown
resume_decision:  none | wait_for_scheduler_requeue | resume_from_checkpoint | restart_from_scratch | needs_user_decision | needs_debug | do_not_resume
```

The point of orthogonality — this combination is **valid and important**:

```yaml
lifecycle: running
scheduler_state: running
health: stalled          # Slurm says running, but training is not progressing
terminal_outcome: none
failure_reason: none
```

A flat enum like `FAILED_OOM` cannot express "running but stalled." That is
exactly the situation the monitor must represent.

> **Field-name note:** these seven fields are **attempt-level**. The
> **experiment-level** `status` field (`active | done | abandoned`, see
> `file-layout.md`) is a separate domain — do not confuse experiment `status`
> with attempt `lifecycle`.

---

## 2. Lifecycle transitions

**Allowed:**
```
created   → submitted
submitted → pending
submitted → running
pending   → running
running   → terminal
pending   → terminal
submitted → terminal
running   → pending      # ONLY for scheduler requeue of the same job
```

**Disallowed:**
```
terminal → running
terminal → pending
terminal → submitted
```

To continue after `terminal`, **create a new attempt** (do not mutate the
terminal one). The attempt chain (`parent_attempt_id`) records the lineage.

---

## 3. Slurm → state mapping (canonical)

Map the raw Slurm state (from `squeue`/`sacct -o State`) as follows:

```
PENDING       → scheduler_state=pending,        lifecycle=pending
RUNNING       → scheduler_state=running,        lifecycle=running
COMPLETING    → scheduler_state=completing,     lifecycle=running
COMPLETED     → scheduler_state=completed,      lifecycle=terminal, terminal_outcome=succeeded
FAILED        → scheduler_state=failed,         lifecycle=terminal, terminal_outcome=failed
CANCELLED     → scheduler_state=cancelled,      lifecycle=terminal, terminal_outcome=cancelled
TIMEOUT       → scheduler_state=timeout,        lifecycle=terminal, terminal_outcome=interrupted, interruption=time_limit
PREEMPTED     → scheduler_state=preempted,      lifecycle=terminal, terminal_outcome=interrupted, interruption=preempted
NODE_FAIL     → scheduler_state=node_fail,      lifecycle=terminal, terminal_outcome=interrupted, interruption=node_failure
OUT_OF_MEMORY → scheduler_state=out_of_memory,  lifecycle=terminal, terminal_outcome=failed,      failure_reason=oom
REQUEUED      → scheduler_state=requeued,       interruption=requeued   (see the REQUEUED subsection below)
```

Notes:
- `sacct` may append `+` or reason codes (e.g. `CANCELLED+`, `FAILED by ...`) —
  match on the leading token.
- For `FAILED`, refine `failure_reason` with the classifier in §8 (the exit code
  alone rarely tells you oom vs nan vs code).
- **Maintenance:** there is no Slurm `MAINTENANCE` job state. Detect it as a
  `CANCELLED`/`PENDING` whose reason references a maintenance reservation (e.g.
  `ReqNodeNotAvail`, `Reservation`) covering the allocation →
  `interruption=maintenance` (treat as an interruption, not a cancellation/failure).

### REQUEUED: same-job-continue vs new-attempt
- If Slurm shows the **same job id** back in `PENDING`/`RUNNING` (cluster
  `JobRequeue=1` auto-requeue), treat it as the same attempt continuing:
  `lifecycle=pending`, `interruption=requeued`, `resume_decision=wait_for_scheduler_requeue`.
  Do not create a new attempt; the job keeps its id.
- If the job is gone and you must submit anew, treat it like a normal
  interruption (§5) and create a new attempt.

---

## 4. Interruption vs failure — the keystone rule

```
preempted | requeued | time_limit | node_failure | maintenance   → INTERRUPTION → resume logic, interruption record, NO debugger
oom | nan | code | data | config | environment | checkpoint_load → FAILURE      → anomaly evidence pack → debugger
```

Shared clusters preempt, requeue, hit walltime, and lose nodes constantly. These
are **normal operating conditions, not experiment failures.**

`interruption != failure_reason`. A preemption is recorded as:

```yaml
terminal_outcome: interrupted
interruption: preempted
failure_reason: none
```

**NEVER failure_reason=preempted.** Storing a scheduler interruption as a failure
is the single most common mistake this model exists to prevent.

`infra` (node/filesystem) with a valid checkpoint is **not** a code bug — it is
cluster weather → resume like an interruption, no debugger. `wandb`
(init/auth/network) is not a training failure either → resume from checkpoint (or
restart from scratch) autonomously and log a note, no debugger. `unknown` is
investigated **autonomously by the debugger** (it gathers evidence and forms a
hypothesis), not surfaced to a human.

---

## 5. Resume-decision rules

Set `resume_decision` from the interruption/failure + checkpoint state:

```
preempted     + checkpoint exists  → resume_from_checkpoint   (create new attempt, submit resume)
preempted     + no checkpoint      → restart_from_scratch     (auto: new attempt from step 0, log no_checkpoint_restart) — see note
time_limit    + checkpoint exists  → resume_from_checkpoint
node_failure  + checkpoint exists  → resume_from_checkpoint
maintenance   + checkpoint exists  → resume_from_checkpoint
requeued (same job)                → wait_for_scheduler_requeue   (do nothing; Slurm restarts it)
infra + checkpoint exists          → resume_from_checkpoint   (node/filesystem = cluster weather, NOT a code bug; NO debugger)
oom | nan | code | data | config | environment | checkpoint_load → needs_debug   (debugger root-causes, then splits operational vs experiment — see below)
wandb (init/auth/network)          → resume_from_checkpoint if a checkpoint exists, else restart_from_scratch   (W&B logging trouble is not a training failure; never blocks; NO debugger; log a wandb_issue note)
any failure_reason not listed (e.g. unknown) → needs_debug   (debugger investigates)
```

Default response to a normal interruption is **resume from the latest checkpoint**.
A normal interruption with **no checkpoint** auto-restarts from scratch (a fresh
attempt from step 0), logged with reason `no_checkpoint_restart` — the agent does
not stop to ask. If an experiment produces **no checkpoint across ≥2 attempts**
(checkpointing is likely broken), stop restarting blindly: set
`failure_reason=checkpoint_missing, resume_decision=needs_debug`, build an evidence
pack, and dispatch the debugger to find why no checkpoint is written. Apart from the
no-checkpoint case, `restart_from_scratch` happens only on an explicit user event
(e.g. "checkpoint may be corrupted, do a clean rerun"), logged with a reason.
`needs_user_decision` now means **a fix that changes experiment code or a config is
proposed and awaiting the human's OK** — the monitor surfaces it and continues other
experiments; it never spins or blocks the whole loop.

**Debugger outcome — operational vs experiment (the human gate).** After the debugger
root-causes a real failure it classifies the FIX:

- **Operational** (a submission-script param — partition/walltime/`--gres`/`--mem`/
  account/env — a broken node, or infra): the agent corrects the submit script /
  environment and **resubmits autonomously** (`resume_decision = resume_from_checkpoint`,
  or `restart_from_scratch` with the corrected submit). No human.
- **Experiment** (changes model code, training logic, or an experiment config/
  hyperparameter — including an OOM that needs a smaller batch/seq or a model change):
  the agent does **not** edit. It records the proposed fix + the cheap test that catches
  it, sets `resume_decision = needs_user_decision`, surfaces it to the human, and moves
  on to other experiments. On the human's OK it implements behind the rungs and
  resubmits. See `protocol-rules.md` §5.

---

## 6. Health evaluator (only meaningful while lifecycle=running)

`health = not_applicable` whenever `lifecycle ≠ running`.

**Inputs:** Slurm state; W&B latest step + latest update timestamp; whether W&B
metrics are finite; stdout/stderr tail; checkpoint freshness (mtime/step delta);
configured warmup window and heartbeat expectation.

**Outputs & heuristics:**
```
unknown      — not enough info yet (e.g. W&B not queried)
warming_up   — job started < warmup window ago; W&B/logs may not exist yet
healthy      — W&B step is increasing AND metrics finite AND heartbeat fresh
suspect      — warning signs (no W&B update in a while; loss flat/rising; one non-finite blip)
              but not enough to call stalled/failed
stalled      — running per Slurm, but no meaningful progress (W&B step flat AND no new
              checkpoint AND no log progress) for longer than the configured threshold
```

A loss `NaN` while running is `suspect` → escalate to a failure
(`failure_reason=nan`) when the run dies or the NaN persists, depending on how
the training script behaves.

**Multi-phase monitoring:** apply phase-appropriate expectations —
- *warming-up phase* (first warmup window): missing W&B is normal → `warming_up`,
  never `stalled`.
- *early phase*: expect first checkpoint + decreasing loss.
- *mid phase*: expect steady step rate, periodic checkpoints.
- *near-done phase*: expect eval metrics + final checkpoint.

---

## 7. Idempotency (no code — grep the event log)

Before any expensive or irreversible action, build a deterministic
**idempotency key** and `grep` it in the relevant `events.jsonl`. If present,
**skip the action and append nothing new.**

```
submit:<exp_id>:attempt-<NNN>                       # before sbatch'ing an attempt; written ON the slurm_submitted event
resume:<exp_id>:into=attempt-<NNN>:from_step=<int>  # before submitting a resume INTO a new attempt from a checkpoint step
evidence:<attempt_id>:<failure_reason>              # before writing an anomaly evidence dir
debug:<attempt_id>:<failure_reason>                 # before dispatching the debugger
```

This makes re-running `mlexp-monitor` over the same ground truth safe: no
duplicate attempts, evidence packs, resume submissions, or events.

**Grep scope & write order (so re-ticks never double-act):**
- Grep a `submit:`/`resume:` key in the **target attempt's** `events.jsonl`.
  Encoding the consuming `attempt-<NNN>` in the resume key means a *second*
  interruption at the same checkpoint step (resuming into a different attempt
  index) gets a distinct key, while a re-tick into the same next attempt dedupes.
- The `submit:` key is the **single** guard for an `sbatch`. Write order is
  normative: grep the `submit:` key immediately **before** `sbatch`; append the
  `slurm_submitted` event **carrying that key** immediately **after** capturing
  the job id, before `run_resumed` or any other event — so a mid-tick crash after
  `sbatch` cannot leave the attempt unguarded and cause a re-submit.
- The interruption-record write is guarded by the `resume:` key — there is no
  separate evidence key for interruptions.

### No debugger spam

Do NOT create an anomaly evidence pack or dispatch the debugger for:
```
preempted | requeued | time_limit (with valid checkpoint) | node_failure (with valid checkpoint)
| transient W&B delay during the warmup phase
```
These get an **interruption record** instead.

Invoke the debugger only for real failures:
```
oom | nan | python exception | CUDA error | missing data | bad config
| checkpoint load failure | repeated resume failure | stalled with code-level evidence
```

---

## 8. Failure classifier (infer failure_reason from evidence)

Inspect `sacct` State, stderr tail, and stdout tail:

```
oom               — Slurm OUT_OF_MEMORY; or stderr "CUDA out of memory" / "torch.cuda.OutOfMemoryError" / "OOMKilled"
nan               — "loss is nan" / "nan"/"inf" in logged loss / "assert torch.isfinite" failures
code              — Python traceback / AssertionError / TypeError not attributable to data/config
data              — FileNotFoundError on data paths / dataloader worker crash / corrupt-sample errors
config            — config parse error / missing-key / invalid hyperparameter / argparse error
environment       — ImportError / CUDA driver/version mismatch / missing shared lib / venv issues
wandb             — wandb.init failure / network auth error during W&B setup
checkpoint_missing— resume requested but checkpoint absent/unreadable → restart_from_scratch first; needs_debug if no checkpoint ever appears (≥2 attempts)
checkpoint_load   — checkpoint present but corrupt/incompatible/fails to deserialize (state_dict mismatch, torch.load error) → needs_debug
infra             — node/filesystem errors not attributable to the job's code
unknown           — none of the above; gather more evidence before deciding
```

When ambiguous, prefer `unknown` and gather more evidence rather than guessing —
evidence over claims.
