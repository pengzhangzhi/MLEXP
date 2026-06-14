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
