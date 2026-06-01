# MLEXP File Layout (the data contract)

Truth lives in files, not the LLM. This document defines the on-disk schema that
every MLEXP skill reads and writes. Skills MUST use these exact field names and
enum spellings (the enums are defined in `state-model.md`).

All MLEXP state lives under a **single `.mlexp/` directory in the user's research
repo**, not in the plugin:

```
<repo>/.mlexp/                # the one MLEXP directory — everything lives here
  config.yaml                 # defaults: wandb entity/project, active cluster profile
  cluster-<profile>.md        # OPTIONAL site profile — copy or point at references/cluster-template.md; gitignore if it has internal details
  memory/                     # durable project memory (lesson delta)
    lessons.md  failure_patterns.md  cluster_playbook.md
  studies/<study-id>/         # one dir per study
    study.yaml                # objective, repo, branch, experiment list, checkpointing config
    protocol.lock.yaml        # FROZEN primary metric + hash  ← immutable
    objective.md  plan.md  events.jsonl
    experiments/<exp-id>/     # the study's experiments (variant × seed)
      experiment.yaml         # variant, seed, config_path + hash, git commit, acceptance criteria
      attempts/attempt-NNN/
        attempt.yaml          # the orthogonal state block + slurm/wandb/checkpoint/resume fields
        submit.sh  stdout.log  stderr.log  events.jsonl
    evidence/
      anomalies/<attempt>-<reason>/      # real failures (oom/nan/code/...) → debugger
        summary.md sacct.txt slurm_state.json stderr_tail.txt stdout_tail.txt
        config.yaml git_commit.txt git_diff.patch wandb_recent.parquet
        wandb_summary.json checkpoint.yaml suspected_causes.md
      interruptions/<attempt>-<reason>/  # preemption/timeout/node_fail → resume (no debugger)
        summary.md slurm_state.json checkpoint.yaml resume_decision.yaml
    analysis/
      report.md  run_manifest.csv  metrics.parquet
      figures/  tables/
```

`attempt-NNN` is zero-padded, 1-based (`attempt-001`, `attempt-002`, …).

---

## `.mlexp/config.yaml`

```yaml
wandb:
  entity: my-entity
  project: mlexp
cluster_profile: my-cluster    # active profile; resolved as .mlexp/cluster-<profile>.md first, then references/cluster-<profile>.md (see cluster-template.md)
```

---

## `study.yaml`

> All values below are **illustrative placeholders** — replace them from your
> cluster profile / project memory. The `/scratch/$USER/...` paths and `my-entity`
> look real but are examples, not defaults.

```yaml
id: study-2026-06-01-rope-x
title: "RoPE variant X ablation"
objective: >
  Test whether RoPE variant X improves validation accuracy over the current
  baseline without harming memory, throughput, or training stability.

repo:
  path: /scratch/$USER/rope-x
  baseline_ref: main
  experiment_branch: exp/study-2026-06-01-rope-x

primary_metric:
  name: val/accuracy
  direction: maximize                 # maximize | minimize
  aggregation: mean_across_seeds      # how seeds combine for the confirmatory claim
  checkpoint_selection: best_validation   # which checkpoint defines the result
  comparison_baseline: baseline       # variant name the others are compared against
  success_criterion:
    type: absolute_gain               # absolute_gain | relative_gain | threshold
    threshold: 0.5

guardrail_metrics:
  - { name: train/loss,                 rule: finite_and_decreasing }
  - { name: system/gpu_memory_gb,       rule: track_peak }
  - { name: throughput/samples_per_sec, rule: track_mean }

checkpointing:
  required: true
  checkpoint_glob: "/scratch/$USER/rope-x/runs/${experiment_id}/checkpoints/*.pt"
  step_regex: "step_(\\d+)\\.pt"
  resume_arg_template: "--resume {checkpoint_path}"
  source: glob                        # glob | training_log | wandb_artifact | user_provided

wandb:
  entity: my-entity
  project: rope-x
  group_pattern: "{experiment_id}"    # one W&B group per experiment
  run_identity: run_per_attempt       # run_per_attempt (default) | same_run_resumed

experiments:
  - { id: exp-baseline-seed1, variant: baseline, seed: 1, config_path: configs/generated/baseline_seed1.yaml }
  - { id: exp-rope-x-seed1,   variant: rope_x,   seed: 1, config_path: configs/generated/rope_x_seed1.yaml }
  # … variants × seeds enumerated explicitly. No max_active_jobs / max_resubmits_per_run.

created_at: 2026-06-01T03:10:00Z
updated_at: 2026-06-01T03:10:00Z
```

**No concurrency/resubmit caps.** The experiment list *is* the plan. Never add
`max_active_jobs` or `max_resubmits_per_run`.

---

## `protocol.lock.yaml` (immutable)

Written once at study creation by copying `study.yaml.primary_metric` verbatim
and adding a hash. **These fields are immutable. To change them, create a new
study.** (See `protocol-rules.md`.)

```yaml
primary_metric:
  name: val/accuracy
  direction: maximize
  aggregation: mean_across_seeds
  checkpoint_selection: best_validation
  comparison_baseline: baseline
  success_criterion: { type: absolute_gain, threshold: 0.5 }

protocol_hash: "sha256:<hex of canonicalized primary_metric block>"
protocol_created_at: 2026-06-01T03:10:00Z
```

`protocol_hash` = sha256 over the primary_metric block serialized with sorted
keys and no insignificant whitespace. Any skill can recompute it to detect
tampering.

---

## `experiment.yaml`

```yaml
id: exp-rope-x-seed1
study_id: study-2026-06-01-rope-x
variant: rope_x
seed: 1
config_path: configs/generated/rope_x_seed1.yaml
config_hash: "sha256:..."
git_branch: exp/study-2026-06-01-rope-x
git_commit: abc1234
status: active                        # active | done | abandoned  (experiment-level; distinct from attempt lifecycle)
acceptance_criteria:
  - "primary metric logged to W&B every eval"
  - "checkpoint written at least every 5000 steps"
tags: [rope, ablation]
created_at: 2026-06-01T03:10:00Z
updated_at: 2026-06-01T03:10:00Z
```

---

## `attempt.yaml`

The orthogonal run-state block (enum domains + rules in `state-model.md`) plus
identity, W&B, checkpoint, resume, and monitor-bookkeeping fields.

```yaml
id: attempt-001
experiment_id: exp-rope-x-seed1
attempt_index: 1

# ── orthogonal state (independent fields; never collapse into one enum) ──
lifecycle: running          # created|submitted|pending|running|terminal
scheduler_state: running    # mapped from Slurm
health: healthy             # unknown|not_applicable|warming_up|healthy|suspect|stalled
terminal_outcome: none      # none|succeeded|failed|cancelled|interrupted
interruption: none          # none|preempted|requeued|time_limit|node_failure|maintenance|unknown
failure_reason: none        # none|oom|nan|code|data|config|environment|wandb|checkpoint_missing|checkpoint_load|infra|unknown
resume_decision: none       # none|wait_for_scheduler_requeue|resume_from_checkpoint|restart_from_scratch|needs_user_decision|needs_debug|do_not_resume

# ── slurm ──
slurm_job_id: "12345"
slurm_array_job_id: null
slurm_array_task_id: null
slurm_script_path: .mlexp/studies/study-.../experiments/exp-rope-x-seed1/attempts/attempt-001/submit.sh
stdout_path: .../attempt-001/stdout.log
stderr_path: .../attempt-001/stderr.log

# ── wandb ──
wandb_entity: my-entity
wandb_project: rope-x
wandb_run_id: abc123
wandb_group: exp-rope-x-seed1
wandb_url: https://wandb.ai/my-entity/rope-x/runs/abc123

# ── checkpoint ──
latest_checkpoint_path: /scratch/$USER/runs/exp-rope-x-seed1/checkpoints/step_120000.pt
checkpoint_step: 120000
checkpoint_mtime: 2026-06-01T09:00:00Z
checkpoint_source: glob
checkpoint_metadata:
  global_step: 120000
  optimizer_state_present: true
  scheduler_state_present: true
  model_state_present: true

# ── resume lineage ──
parent_attempt_id: null
resume_from_attempt_id: null
resume_from_checkpoint_path: null
resume_from_checkpoint_step: null
resume_reason: null

# ── monitor bookkeeping ──
last_seen_step: 120000
last_wandb_update_at: 2026-06-01T09:01:00Z
last_monitor_tick_at: 2026-06-01T09:05:00Z

started_at: 2026-06-01T03:12:00Z
ended_at: null
created_at: 2026-06-01T03:11:00Z
updated_at: 2026-06-01T09:05:00Z
```

### Example: preempted attempt that triggered a resume

```yaml
id: attempt-001
experiment_id: exp-rope-x-seed1
attempt_index: 1
lifecycle: terminal
scheduler_state: preempted
health: not_applicable
terminal_outcome: interrupted
interruption: preempted
failure_reason: none
resume_decision: resume_from_checkpoint
latest_checkpoint_path: /scratch/$USER/runs/checkpoints/step_120000.pt
checkpoint_step: 120000
ended_at: 2026-06-01T09:10:00Z
```

The resuming attempt (`attempt-002`) carries:

```yaml
id: attempt-002
attempt_index: 2
parent_attempt_id: attempt-001
resume_from_attempt_id: attempt-001
resume_from_checkpoint_path: /scratch/$USER/runs/checkpoints/step_120000.pt
resume_from_checkpoint_step: 120000
resume_reason: preempted
lifecycle: submitted
scheduler_state: submitted
health: not_applicable
```

---

## `events.jsonl` (append-only)

Every state mutation appends **exactly one** event line to the entity's
`events.jsonl` (attempt-level for attempt changes, study-level for study/experiment
changes). This is the audit log and the basis for idempotency.

```json
{"timestamp":"2026-06-01T09:10:00Z","entity_type":"attempt","entity_id":"attempt-001","event_type":"interruption_detected","actor":"mlexp-monitor","source":"slurm","payload":{"interruption":"preempted","checkpoint_step":120000},"idempotency_key":"resume:exp-rope-x-seed1:into=attempt-002:from_step=120000"}
{"timestamp":"2026-06-01T09:11:00Z","entity_type":"attempt","entity_id":"attempt-002","event_type":"slurm_submitted","actor":"mlexp-monitor","source":"slurm","payload":{"slurm_job_id":"12401"},"idempotency_key":"submit:exp-rope-x-seed1:attempt-002"}
```

The `submit:` key is written on the `slurm_submitted` event; the `resume:` key is
written on the `interruption_detected` event of the attempt being resumed. See
`state-model.md` §7 for grep scope and write order.

Fields: `timestamp` (ISO8601 UTC), `entity_type` (`study|experiment|attempt`),
`entity_id`, `event_type`, `actor` (`user|mlexp-<skill>|<subagent>`), `source`
(`slurm|wandb|fs|git|user`), `payload` (object), `idempotency_key` (optional).

### Closed `event_type` vocabulary

```
study_created          protocol_locked         experiment_created
attempt_created        slurm_submitted         scheduler_state_changed
training_health_changed checkpoint_updated     interruption_detected
resume_decision_set    run_resumed             failure_detected
evidence_pack_created  debugger_invoked        exploratory_metric_added
recommendation         approval_requested      approval_granted
approval_denied        report_generated        attempt_adopted
smoke_passed
```

`recommendation` records a destructive/irreversible action the agent declined to
take on its own (modify baseline, delete an artifact, merge to main) — payload =
`{kind, reason, affected_paths, suggested_action}`; it surfaces in the report. The
`approval_*` events are used only when the user **explicitly** authorizes one of
those actions in-session — never for an autonomous decision (see
`protocol-rules.md` §5).

---

## W&B run identity (both patterns supported)

- **Pattern A — `same_run_resumed`:** every attempt logs to the same W&B
  `run_id`; resumes call `wandb.init(id=..., resume="must")`. The run's history
  is continuous.
- **Pattern B — `run_per_attempt` (DEFAULT):** each attempt is its own W&B run,
  all sharing a `wandb_group = <experiment_id>`. The group reassembles the
  attempt chain; each attempt is cleanly isolated for debugging.

`study.yaml.wandb.run_identity` selects the pattern. Default is
`run_per_attempt` because attempt isolation makes failure analysis cleaner and
the group still reconstructs the full experiment timeline.
