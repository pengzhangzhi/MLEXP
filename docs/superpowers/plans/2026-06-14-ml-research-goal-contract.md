# ML Research Goal Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a lightweight, non-overlapping ML research goal contract to the existing brainstorming ML addendum.

**Architecture:** Keep the change as markdown guidance only. Add one focused regression check that verifies the brainstorming skill includes the contract, resource posture, non-overlap rules, and the handoff to `ml-experiment-design`; then update the skill and ML docs to match the approved design.

**Tech Stack:** Markdown skill files, shell regression test, existing repository test scripts.

---

### Task 1: Add Failing Regression Check

**Files:**
- Create: `tests/skill-content/test-ml-research-goal-contract.sh`

- [ ] **Step 1: Create the failing test**

Create `tests/skill-content/test-ml-research-goal-contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/brainstorming/SKILL.md"

require_text() {
  local pattern="$1"
  local description="$2"

  if ! grep -Fq "$pattern" "$SKILL_FILE"; then
    echo "FAIL: missing $description" >&2
    echo "Expected to find: $pattern" >&2
    exit 1
  fi
}

require_absent() {
  local pattern="$1"
  local description="$2"

  if grep -Fq "$pattern" "$SKILL_FILE"; then
    echo "FAIL: unexpected $description" >&2
    echo "Unexpected text: $pattern" >&2
    exit 1
  fi
}

require_text "## ML research addendum" "ML addendum"
require_text "Research goal contract" "research goal contract heading"
require_text "Research outcome" "research outcome field"
require_text "Evidence bar" "evidence bar field"
require_text "Current state" "current state field"
require_text "Resource posture" "resource posture field"
require_text "no artificial compute cap by default" "full-resource default"
require_text "Do not skip cheap gates just because more compute is available" "cheap gate protection"
require_text "Non-overlap rules" "non-overlap section"
require_text "Do not duplicate experiment-card fields" "experiment-card ownership warning"
require_text "hypothesis, exact baseline config, variant, primary metric, dataset/split, seed policy, success criterion, and cheapest useful rung" "experiment-card field list"
require_text "superpowers-ml:ml-experiment-design" "experiment-design handoff"
require_absent "**Budget** —" "required budget field in brainstorming addendum"

echo "ML research goal contract skill check passed."
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x tests/skill-content/test-ml-research-goal-contract.sh`

- [ ] **Step 3: Run test to verify it fails**

Run: `tests/skill-content/test-ml-research-goal-contract.sh`

Expected: FAIL, with missing `Research goal contract` because `skills/brainstorming/SKILL.md` does not yet contain the new contract language.

- [ ] **Step 4: Commit the failing test**

```bash
git add tests/skill-content/test-ml-research-goal-contract.sh
git commit -m "test: add ML research goal contract check"
```

### Task 2: Update Brainstorming ML Addendum

**Files:**
- Modify: `skills/brainstorming/SKILL.md`

- [ ] **Step 1: Replace the existing ML research addendum**

Replace the existing addendum under `## ML research addendum` with:

```markdown
When the work is an ML experiment or research direction, the brainstorm has a known shape — steer it to pin down, not to interrogate. Ask only the questions still genuinely open; skip anything the context already answers.

For a narrow, already-clear experiment, hand off directly to `superpowers-ml:ml-experiment-design`.

For a broad, vague, or multi-step ML research request, first settle a short **Research goal contract**:

- **Research outcome** — what should become true if this research direction succeeds
- **Evidence bar** — what evidence would make the direction worth continuing, abandoning, or escalating
- **Current state** — code, data, baselines, prior runs, papers, or constraints already known
- **Resource posture** — no artificial compute cap by default; use available GPUs and cluster resources once cheaper verification rungs pass. Do not skip cheap gates just because more compute is available
- **Stop when** — evidence is enough to conclude, continue with the next card, or abandon the direction
- **Pause if** — credentials, cluster/account access, destructive data changes, unclear research direction, external approval, or a change to the research claim is needed
- **Next handoff** — create one or more `superpowers-ml:ml-experiment-design` cards
- **Optional paste-ready `/goal`** — a durable agent goal derived from the contract when the user is using a goal-capable agent workflow

Do not ask for a compute budget by default. Only ask when the user mentions scarce compute, shared cluster contention, external cost, deadline pressure, or a fixed allocation.

### Non-overlap rules

Do not duplicate experiment-card fields in the research goal contract. The following belong to `superpowers-ml:ml-experiment-design`: hypothesis, exact baseline config, variant, primary metric, dataset/split, seed policy, success criterion, and cheapest useful rung.

If one of those fields is already known during brainstorming, record it as context only. Let `superpowers-ml:ml-experiment-design` lock it in the experiment card.

By the end of the ML brainstorm, either the research goal contract is settled for broad work, or the request is narrow enough to skip it and proceed directly to an experiment card.

ML experiments do not need 2-3 architectural approaches the way features do. Propose alternatives only when the *method* is genuinely contested.

**Terminal state for ML work:** hand off to `superpowers-ml:ml-experiment-design` to turn the research goal or narrow idea into a compact experiment card BEFORE any training code.
```

- [ ] **Step 2: Run the focused check**

Run: `tests/skill-content/test-ml-research-goal-contract.sh`

Expected: PASS.

- [ ] **Step 3: Commit the skill update**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "feat: add ML research goal contract to brainstorming"
```

### Task 3: Update ML Documentation

**Files:**
- Modify: `docs/superpowers-ml.md`

- [ ] **Step 1: Add the goal contract to the fork overview**

In `docs/superpowers-ml.md`, update the `brainstorming` addendum bullet from:

```markdown
- `brainstorming` — for ML experiments, pin down hypothesis, baseline, variant, dataset/split, metric, budget, and the cheapest useful rung; ask only necessary questions.
```

to:

```markdown
- `brainstorming` — for broad ML research, settle a compact research goal contract first: outcome, evidence bar, current state, full-resource posture after cheap gates, stop/pause rules, and handoff to experiment cards. For narrow experiments, hand off directly to `ml-experiment-design`.
```

- [ ] **Step 2: Run the focused check**

Run: `tests/skill-content/test-ml-research-goal-contract.sh`

Expected: PASS.

- [ ] **Step 3: Commit the documentation update**

```bash
git add docs/superpowers-ml.md
git commit -m "docs: describe ML research goal contract"
```

### Task 4: Final Verification

**Files:**
- Verify: `skills/brainstorming/SKILL.md`
- Verify: `docs/superpowers-ml.md`
- Verify: `tests/skill-content/test-ml-research-goal-contract.sh`

- [ ] **Step 1: Run the focused regression check**

Run: `tests/skill-content/test-ml-research-goal-contract.sh`

Expected: `ML research goal contract skill check passed.`

- [ ] **Step 2: Run opencode plugin tests**

Run: `tests/opencode/run-tests.sh`

Expected: all opencode tests pass, or any missing local dependency is reported clearly.

- [ ] **Step 3: Check final git status**

Run: `git status --short`

Expected: clean working tree.
