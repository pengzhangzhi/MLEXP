# Cluster Profile (template)

A **cluster profile** captures how to submit and monitor jobs on a specific
Slurm cluster. The plugin ships only this generic template. Your real,
site-specific profile lives **in your research repo**, not in the plugin, so any
site-internal details (account names, partition names, paths) stay private.

## How profiles are resolved

`/.mlexp/config.yaml` selects the active profile:

```yaml
cluster_profile: my-cluster
```

Skills resolve the active profile in this order:

0. **Existing project memory (preferred when present).** If the repo already
   teaches the agent how to use this cluster — a `CLAUDE.md` / `AGENTS.md`,
   project memory, or `docs/` covering how to submit, get a debug/interactive GPU,
   activate the container/venv, and where checkpoints/runs live — **defer to it.**
   Make the profile a thin pointer that *inherits* it instead of re-authoring it:

   ```yaml
   # .mlexp/cluster-<profile>.md
   inherits: ../CLAUDE.md      # path to the doc that already documents submission
   # then ONLY the values that differ or aren't covered there
   ```
1. `.mlexp/cluster-<profile>.md` in your research repo — your real profile (a full
   fill-in OR the thin pointer above). Gitignore it if it has internal details.
2. `references/cluster-<profile>.md` shipped by the plugin — generic templates only.

So: if your project already documents how to use the cluster, **point at that**
(step 0) and add only the deltas — don't maintain a second, drifting copy. If it
doesn't, copy this template to `.mlexp/cluster-<your-cluster>.md`, fill in the
real values, and set `cluster_profile` to match. Either way the plugin never needs
anything specific to your cluster.

## What a profile should define

Fill these in for your site (placeholders shown):

- **Account / project:** `--account=<your-account>` (and QOS if your site uses it).
- **Partitions:** a partition list so Slurm picks one with capacity, e.g.
  `--partition=<part-a>,<part-b>,<backfill-part>`.
- **GPU request convention:** how your site wants GPUs requested, e.g.
  `--gres=gpu:<N>` vs `--gpus-per-node=<N>`.
- **CPU/RAM rule of thumb:** e.g. `cpus-per-task ≤ <k> * N_GPU`,
  `mem-per-cpu ≤ <m>G`.
- **Walltime & preemption:** the max walltime per partition; whether a
  long/backfill partition exists and whether it preempts. If jobs can be
  preempted, set `--requeue` and make training **checkpoint + resume** (MLEXP
  treats preemption as a normal interruption, not a failure).
- **Idle-GPU policing (if any):** some sites kill jobs whose GPUs look idle
  (e.g. during data loading). If yours does, add the exemption flag your site
  documents.
- **Container / environment activation:** how a job enters its runtime
  (container image, virtualenv, module loads, env vars like `HF_HOME`).
- **Scratch / storage paths:** where checkpoints, runs, caches, and datasets
  live, e.g. `/scratch/$USER/<project>/{runs,checkpoints,cache,data}`.
- **Interactive / debug GPU:** how to get a quick 1-GPU shell for the cheap
  feedback-ladder rungs (tiny batch / tiny overfit), e.g. `salloc`/`srun --pty`
  on a short partition. Use it for rungs 1–3; the smoke rung (4) must go through
  the real `sbatch` submit path.
- **Where Slurm commands run:** confirm `squeue`/`sacct`/`sbatch` are available
  where you run MLEXP (often the login/head node), so monitoring needs no extra
  allocation.

## `submit.sh` template

`mlexp-submit` fills the `${...}` placeholders per attempt. `RESUME_ARG` is empty
for a fresh attempt and `--resume <ckpt>` (from
`study.yaml.checkpointing.resume_arg_template`) for a resume.

```bash
#!/bin/bash
#SBATCH --job-name=${JOB_NAME}
#SBATCH --account=${ACCOUNT}
#SBATCH --partition=${PARTITION}
#SBATCH --gres=gpu:${N_GPU}
#SBATCH --cpus-per-task=${CPUS}
#SBATCH --mem-per-cpu=${MEM_PER_CPU}
#SBATCH --time=${TIME}
#SBATCH --requeue
#SBATCH --output=${STDOUT_PATH}
#SBATCH --error=${STDERR_PATH}
# Add any site-specific flags (idle-GPU policing exemption, QOS, reservations) here.

set -euo pipefail
# Enter your runtime (container/venv/modules), set caches, then run:
#   <activate environment>
#   export WANDB_ENTITY=${WANDB_ENTITY} WANDB_PROJECT=${WANDB_PROJECT} WANDB_RUN_GROUP=${WANDB_GROUP}
#   cd ${REPO} && python ${TRAIN_CMD} --config ${CONFIG_PATH} ${RESUME_ARG}
```

Capture the submitted job id from `sbatch` stdout (`Submitted batch job <ID>`)
into `attempt.yaml.slurm_job_id`.

## Multi-day training

If your longest partition can't fit the full run, use a preemptible/backfill
partition with a long walltime, `--requeue`, and **checkpoint + resume** in the
training loop. MLEXP's monitor will auto-resume from the latest checkpoint on
preemption/timeout/node-failure.
