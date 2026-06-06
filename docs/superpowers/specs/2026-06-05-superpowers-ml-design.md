# superpowers-ml — design spec

**Date:** 2026-06-05
**Status:** Approved; implemented.

## Goal

`superpowers-ml` = original Superpowers + a small, conservative ML-research layer, usable as the *only* active Superpowers-style plugin in an ML cluster/dev-node environment. Preserve all existing Superpowers behavior and philosophy; add ML guidance on top.

## Non-goals

No second add-on plugin (single combined fork only). No rewrite of Superpowers. No MLEXP copy. No database, dashboard, daemon, job manager, HPO engine, or complex state. No edits to the `using-superpowers` bootstrap or the SessionStart hook beyond the rename.

## Decisions (locked)

1. **Push target:** archive the existing `pengzhangzhi/MLEXP` `main` to an `archive/mlexp` branch, then make `superpowers-ml` the new `main`.
2. **Plugin name:** rename to `superpowers-ml` (skills invoked as `superpowers-ml:<skill>`); cross-platform manifests renamed too.
3. **Edit style:** append a marked `## ML research addendum` to each revised skill; original content left byte-for-byte intact.

## Repo & fork mechanics

- Fresh `git clone` of latest `obra/superpowers` (full history) into the working dir.
- Remotes: `upstream` → obra/superpowers (for future `git merge upstream/main`); `origin` → pengzhangzhi/MLEXP (SSH).
- Rename to `superpowers-ml` across `.claude-plugin/plugin.json` + `marketplace.json`, `.cursor-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`, `package.json`. Version → `5.1.0-ml.0`.
- MIT `LICENSE` retained; attribution added via `NOTICE`, a `README` banner, and a `CLAUDE.md` fork banner.
- Push order (non-destructive first): push `archive/mlexp`, then force-update `main`.

## Verification rungs (R0–R7)

Canonical definition owned by the new `ml-feedback-ladder` skill; referenced everywhere else.

```
R0 experiment card / protocol defined
R1 code / import / config / static sanity checks
R2 shape / dtype / device / one-batch forward+backward
R3 tiny overfit
R4 real launcher smoke run (local GPU or cluster smoke job)
R5 short pilot / early signal
R6 full run / full study
R7 result review / decision memo
```

Cluster guidance is scheduler-agnostic (Slurm only as an optional example).

## Light revisions — 5 existing skills (addenda only)

- **brainstorming** — pin down hypothesis/baseline/variant/dataset-split/metric/budget/cheapest rung; ask only necessary questions.
- **writing-plans** — staged verification mapped to rungs; distinguish code-correctness vs trainability vs cheap signal vs full evidence; name the proving artifact per rung.
- **test-driven-development** — add shape/dtype/device, deterministic tiny-batch, finite-loss, and one fwd/bwd checks (R1–R3) alongside ordinary unit tests.
- **systematic-debugging** — classify ML failures first; preemption/requeue = operational not scientific; model/data/HP/training/metric changes = experiment changes needing approval.
- **verification-before-completion** — state highest verified rung + exact evidence; no "beats baseline" without the full/equivalent eval under the locked metric.

## New skills — 3

- **ml-experiment-design** — rough idea → compact experiment card (R0): question, hypothesis, baseline, variant(s), primary + guardrail metrics, dataset/split, seed policy, budget, cheapest rung, success criterion, exploratory-only boundary.
- **ml-feedback-ladder** — cheapest→expensive ladder; owns R0–R7; promotion/stop criteria; cheap-passing-is-precondition / cheap-failing-stops-spend / early-signal-can-reject-not-declare-victory.
- **ml-result-review** — sober conclusion separating confirmed result / exploratory observations / failed-incomplete runs / highest verified rung / evidence gaps / recommended next experiment.

## Build approach

Repo scaffolding and all git/remote/push steps done directly (nothing destructive unsupervised). Content authored by a Workflow: one subagent per piece (5 addenda + 3 skills) → adversarial reviewer per piece checking conservatism, fidelity, rung-wording, voice, and absence of banned machinery; vetted output integrated deterministically.

## Validation

Frontmatter parses for all skills; 3 new skills discoverable; 5 originals diff-clean except the appended addendum; rename consistent across manifests; no dangling `superpowers:` cross-refs that should be `superpowers-ml:`; full upstream history + `upstream` remote present; `archive/mlexp` exists before `main` is touched.

## Acceptance criteria

Original Superpowers behavior retained; existing skills only lightly revised; three new ML skills added; no separate overlapping plugin; no heavy ML platform; ML guidance consistently uses verification rungs; results separate confirmed conclusions from exploratory observations; suitable as the sole active Superpowers-style plugin on an ML cluster/dev-node setup.
