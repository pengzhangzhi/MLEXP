---
name: mlexp-report
description: Use to produce a paper-quality analysis of a study — pulls W&B histories into tables/figures and writes a decision memo with confirmatory and exploratory results clearly separated. Runs standalone over finished runs.
---

# mlexp-report — paper-quality analysis

Produces the analysis artifacts and a decision memo for a study. Read
`references/protocol-rules.md` (report separation + immutability) and
`references/file-layout.md` first. Runs standalone over finished or adopted
studies.

## Workflow

0. **Metrics source.** Reporting requires a metrics source — W&B by default. If
   W&B is unconfigured/unreachable, say so and either point the analyst at another
   configured source (e.g. parsed training logs / a local metrics file) or stop;
   do not fabricate numbers.

1. **Pull & build (analyst subagent).** Dispatch the `mlexp-analyst` subagent to:
   - pull W&B histories for every experiment (by group / run ids from each
     `attempt.yaml`; reassemble resumed attempt chains),
   - write `analysis/metrics.parquet` (tidy per-step metrics) and
     `analysis/run_manifest.csv`,
   - render `analysis/figures/*.pdf` (learning curves, seed scatter,
     memory/throughput) and `analysis/tables/*.{md,tex}` (ablation table),
   - write `analysis/report.md`.

2. **Compute the confirmatory result from the frozen protocol ONLY.** Use
   `protocol.lock.yaml`: the named primary metric, its direction, the
   `aggregation` (e.g. mean across seeds), the `checkpoint_selection` rule, the
   `comparison_baseline`, and the `success_criterion`. Recompute `protocol_hash`
   and confirm it matches — surface a mismatch, never silently adjust. Do not
   substitute a different metric/aggregation/checkpoint even if the variant would
   look better — that is p-hacking (`references/protocol-rules.md`).

3. **Enforce the report sections** (from `references/protocol-rules.md`):
   Objective · Frozen protocol · Study matrix · Run manifest · **Confirmatory
   result** · Guardrail metrics · Training dynamics · Interruptions & resumes ·
   Failures & exclusions · **Exploratory analysis** (labeled, cannot override
   confirmatory) · Decision · Recommended next experiments.

4. **Run manifest columns** (per row): `experiment_id, variant, seed, attempts,
   slurm_job_ids, wandb_run_ids, git_commit, config_hash, final_status,
   checkpoint_lineage, included_in_primary_analysis, exclusion_reason`. State the
   exclusion reason for any run not in the primary analysis (e.g. unresolved
   failure). **Adopted runs** carry `git_commit`/`config_hash` = `unknown
   (adopted)`; exclude them from the confirmatory primary analysis with
   `exclusion_reason: "adopted: provenance unknown"` unless the user supplies
   provenance.

5. **Independent separation check (gate before remembering).** In a fresh subagent
   context, grep/parse the written `analysis/report.md` and confirm: (a) the
   `protocol_hash` cited matches `protocol.lock.yaml`; (b) the **Confirmatory**
   section references only the frozen `primary_metric` fields (name, direction,
   aggregation, checkpoint_selection, comparison_baseline, success_criterion); and
   (c) no exploratory-metric name appears in the Confirmatory or Decision sections.
   If any check fails, fix the report before proceeding — this makes the
   confirmatory/exploratory separation an enforced gate, not self-attestation.

6. **Log & remember.** Append `report_generated`. Then invoke the
   `mlexp-librarian` subagent to write reusable lessons / failure patterns /
   cluster-playbook deltas to `.mlexp/memory/`.

## Guardrails

- The confirmatory verdict is whatever the frozen protocol yields — even if the
  variant loses. Exploratory findings motivate a new study; they never rewrite
  this study's verdict.
- Keep confirmatory, guardrail, exploratory, diagnostic, and failure content in
  their separate sections.
- Cite W&B run ids / steps behind every number — evidence over claims.
