---
name: mlexp-submit
description: Use to submit a study's experiments to Slurm — renders submit scripts with the cluster conventions, gates on the smoke-Slurm rung, sbatch's the jobs, and records each attempt.
---

# mlexp-submit — render, gate, sbatch, record

Submits the experiments a study enumerates. Read
`references/cluster-template.md`, `references/feedback-ladder.md`, and
`references/file-layout.md` first.

## Scope flags

```
/mlexp-submit <study>            # alias for --all
/mlexp-submit <study> --all
/mlexp-submit <study> --experiment <exp-id>
/mlexp-submit <study> --variant <variant>
/mlexp-submit <study> --dry-run     # render + summarize, do NOT sbatch
```

Submit **exactly** the experiments the study plan enumerates (or the subset the
flag selects). No hidden concurrency cap — the plan is the plan.

## Workflow (per selected experiment)

1. **Resolve the cluster profile — fail loud.** Resolve the active profile:
   `.mlexp/config.yaml` → `cluster_profile` → (defer-to-project-memory /
   `.mlexp/cluster-<profile>.md` / `references/cluster-<profile>.md`; precedence in
   `references/cluster-template.md`). **STOP** if `.mlexp/config.yaml` is missing,
   no profile resolves, OR the rendered script would still contain template
   placeholders (e.g. `<your-account>`, `<part-a>`), with a precise message:
   "No cluster profile resolved. Point your profile at your project's CLAUDE.md
   (`inherits: ../CLAUDE.md`), or copy references/cluster-template.md to
   .mlexp/cluster-<name>.md, fill it in, and set cluster_profile in
   .mlexp/config.yaml (see README 'Configure your cluster')." **Never sbatch a
   placeholder script.**

2. **Smoke gate (decidable from files).** Grep the study `events.jsonl` for a
   `smoke_passed` event (key `smoke:<study_id>:<config_hash>`). If absent, run a
   smoke job first (rung 4: ≈1 step, `--time=00:15:00`) confirming
   env/launcher/W&B-init/checkpoint-write on a real node; on success append
   `smoke_passed` with payload `{slurm_job_id, observed_step_rate, checkpoint_written: true, git_commit}`.
   Do not submit full runs until smoke is green. (Keying on `config_hash` means a
   code/config change correctly invalidates a stale smoke pass.)

3. **Cadence sanity (advisory warn, never a block).** If smoke reported an
   `observed_step_rate` and the study sets `study.yaml.checkpointing.interval_steps`,
   compute `expected_steps ≈ rate × --time` and **WARN** (do not block — data is
   approximate, the field optional, and we keep the "no hidden caps" stance) when
   `expected_steps < interval_steps`, i.e. no checkpoint is expected before
   walltime — the canonical "fails only after 8 hours" trap.

4. **Idempotency check.** Build `submit:<exp_id>:attempt-<NNN>` (next attempt
   index) and grep the experiment's attempt `events.jsonl`. If present, the
   submission already happened — skip it.

5. **Render `submit.sh`** from the active cluster profile's template
   (`references/cluster-template.md`, or your `.mlexp/cluster-<profile>.md`):
   account, partition list, `--gres`, `cpus-per-task`/`mem-per-cpu` within the
   profile's rule of thumb, `--time`, `--requeue`, any site-required flags, and
   `--output`/`--error` paths, wrapping the train command in the profile's
   environment activation. `RESUME_ARG` is empty for a fresh attempt.

6. **Submit (ordered).** If `--dry-run`, print the rendered script + a summary
   (N jobs, GPUs, walltime) and stop. Otherwise re-grep `submit:<exp_id>:attempt-<NNN>`,
   `sbatch submit.sh`, capture the job id from `Submitted batch job <ID>`, and
   **immediately** append the `slurm_submitted` event carrying that `submit:` key
   (before any other event) — so a crash after `sbatch` cannot cause a re-submit
   (state-model §7).

7. **Record the attempt.** Create `attempts/attempt-NNN/` with:
   - `submit.sh` (the rendered script),
   - `attempt.yaml` — `lifecycle=submitted, scheduler_state=submitted,
     health=not_applicable, terminal_outcome=none, interruption=none,
     failure_reason=none, resume_decision=none`, plus `slurm_job_id`,
     `stdout_path`/`stderr_path`, `slurm_script_path`, `wandb_*` (group =
     experiment id, run identity per `study.yaml`), `git_commit`, and the
     experiment's `config_hash`.
   - `attempt_created` is appended at creation; `slurm_submitted` (step 6) carries
     the `submit:` key.

8. **Summary.** Print the submitted job ids and a one-line dry-run-style recap
   (e.g. "Submitted 18 jobs: 9 baseline, 9 rope_x; 18 GPUs; t=4h each").

## Guardrails

- Any site-required flags from your cluster profile (e.g. `--requeue`, idle-GPU
  exemptions) are mandatory on every job — never omit them.
- Re-running this skill must not double-submit (idempotency, step 2).
- Hand off to `/mlexp-monitor` after submission.
