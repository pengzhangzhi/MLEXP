# MLEXP Feedback Ladder (de-risk early)

The defining principle of MLEXP. A normal coding agent loops
`edit → test → feedback` in seconds. ML feedback is a day away. So MLEXP
decomposes the one-day verdict into a ladder of progressively expensive proxy
feedbacks and **refuses to climb to a more expensive rung until the cheaper rung
is green.**

| # | Rung | Feedback | Cost | Policy |
|---|---|---|---|---|
| 1 | import / config validate | seconds | free | **gate** |
| 2 | unit + shape/dtype/device tests | tens of sec | free | **gate** |
| 3 | tiny batch fwd/bwd + tiny overfit | minutes | 1 GPU (interactive) | **gate** |
| 4 | smoke Slurm job (≈1 step, real submit path) | 5–15 min | 1 GPU | **gate** |
| 5 | early-training signal | ~30 min | real | watch, don't gate |
| 6 | full result | hours–days | full study | the answer |

---

## Per-rung concrete checks

**Rung 1 — import / config (seconds):**
- `python -c "import <pkg>"` for the variant module(s).
- The generated config loads and validates (required keys present, types sane).

**Rung 2 — unit + shape/dtype/device (tens of seconds):**
- `pytest` the variant's unit tests.
- Shape test: forward on a dummy batch returns expected shapes.
- Dtype/device test: params/outputs on the right dtype and device.

**Rung 3 — tiny batch fwd/bwd + tiny overfit (minutes, 1 GPU):**
- 1–2 optimizer steps on a tiny batch; loss is finite.
- Tiny overfit: a handful of steps on a few examples drives loss down (sanity
  that learning works at all).
- Run on a short interactive 1-GPU allocation (e.g. `salloc` / `srun --pty`);
  see your active cluster profile.

**Rung 4 — smoke Slurm (5–15 min, 1 GPU):**
- Submit through the **real** `mlexp-submit` path with `--time=00:15:00` and a
  step cap of ~1, on the real partitions with the real container/venv.
- Confirms the things only a compute node reveals: env activation, distributed
  launcher, W&B init from the node, and that a checkpoint actually gets written.
- **Report an observed step rate** (steps per wall-minute, from W&B step
  timestamps or the training log) and whether a checkpoint was written. These feed
  the `smoke_passed` event and `mlexp-submit`'s checkpoint-cadence-vs-walltime
  warning (rung 4 is the cheapest place to measure throughput on a real node).

**Rung 5 — early-training signal (~30 min): watch, don't gate.**
- Loss trend sane, first checkpoint written, W&B step advancing. `mlexp-monitor`
  watches; this does not block submission.

**Rung 6 — full result (hours–days):** the actual experiment outcome.

---

## Gate policy

- **`mlexp-implement` gates the free rungs (1–3)**: it does not hand off to
  submit until import/config + unit/shape + tiny-batch are green.
- **`mlexp-submit` gates the smoke rung (4)**: it does not submit the full study
  until a smoke Slurm job for the study has passed.
- A green cheaper rung is a *precondition*, not a guarantee — but a red cheaper
  rung means do not spend the more expensive one. This is how MLEXP avoids
  burning multi-day GPU runs on bugs a 10-second test would have caught.
- After any debugger fix, **re-run the cheap rungs** before resubmitting.

Evidence over claims: a rung is "green" only with the command output to prove it
(`mlexp-tester` reports the actual output, never an unverified "looks fine").
