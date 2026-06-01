---
name: mlexp-implement
description: Use to implement a study's variant code and configs behind the cheap feedback-ladder gates — sets up a worktree, generates configs, writes code + tests, runs the free rungs before anything expensive.
---

# mlexp-implement — code + tests behind the ladder gates

Implements a study's variants and generates its configs, gated by the cheap
rungs of `references/feedback-ladder.md` so no expensive run is spent on a bug a
10-second test would catch. Read `references/feedback-ladder.md` and
`references/protocol-rules.md` first.

## Workflow

1. **Isolate the workspace.** Invoke the `superpowers:using-git-worktrees` skill
   to create the study branch `exp/<study-id>` in its own worktree. `main` and
   the baseline stay untouched.

2. **Implement with TDD.** Invoke the `superpowers:test-driven-development` skill
   for the variant code. Write the cheap-rung tests (rungs 1–3) alongside the
   implementation: import/config validation, shape/dtype/device tests, a tiny
   forward/backward, and a tiny overfit sanity test.

3. **Generate configs.** Produce each experiment's `config_path` (variants ×
   seeds) from the study plan. Record `config_hash` (sha256 of the resolved
   config) into each `experiment.yaml`, plus `git_branch` and `git_commit`. Log
   `experiment_created` if not already logged by `/mlexp-new`.

4. **Independent review + testing (subagents).**
   - Dispatch the `mlexp-tester` subagent to run the free rungs (1–3) — and the
     tiny-batch rung on an interactive GPU — and report pass/fail **with command
     output** (evidence over claims).
   - Dispatch the `mlexp-reviewer` subagent for an independent review: does the
     implementation match the spec? Does it accidentally change baseline
     behavior? Are metrics/checkpoint/resume logged correctly? Could it fail only
     after 8 hours? Findings come back severity-tagged.

5. **Keep the variant in scope.** Before committing or submitting, run `git diff`
   against `study.yaml.repo.baseline_ref`. The change must stay inside the
   experiment's branch/worktree and not alter baseline behavior. If the variant
   genuinely needs a baseline change, raise it in the plan/review here — this is one
   of the two human-in-the-loop phases — rather than slipping it in; record a
   `recommendation` if it's deferred (`references/protocol-rules.md` §5).

6. **Gate to submit.** Hand off to `/mlexp-submit` only once rungs 1–3 are green
   (the tester reported real passing output) and the reviewer's blockers are
   resolved.

## Guardrails

- Never modify baseline code, delete artifacts, or merge to main on your own; if
  the plan needs a baseline change, raise it with the human in this phase.
- Write tests before/with implementation; record a git diff summary.
- Re-run the cheap rungs after any change.
- Leave changes uncommitted for the user to review unless they ask otherwise.
