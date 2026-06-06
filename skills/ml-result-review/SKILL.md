---
name: ml-result-review
description: Use when concluding an ML experiment - produce a sober conclusion that separates confirmed results from exploratory observations and states the highest verified rung.
---

# ML Result Review

## Overview

You are concluding an ML experiment, not selling it. Passing tests showed the code path runs; they never showed the method works. Your job here is a SOBER conclusion that resists over-claiming, written so your human partner can decide on real evidence.

**Core principle:** Confirmed, exploratory, and failed are different things. Keep them apart.

This is downstream of `superpowers-ml:ml-feedback-ladder` (which owns the rungs) and `superpowers-ml:verification-before-completion` (evidence before claims). Cite the highest rung you actually reached, never the one you hoped for.

## What "Confirmed" Means

A result is CONFIRMED only when the required full or equivalent evaluation completed under the declared primary metric and met the locked success criterion.

- Met the locked criterion under the locked metric = confirmed.
- Better-looking but not the locked test = exploratory, not confirmed.
- **Operational interruptions (preemption, requeue, node failure) are not scientific failures.** A requeued run that still completed the locked evaluation is confirmed. Note the interruption; do not downgrade the result for it.

Never claim the method beats a baseline without the full or equivalent evaluation under the locked primary metric.

## The Review Format

Write the conclusion under these explicit headings, in order:

### CONFIRMED
What met the locked success criterion under the primary metric. One line per claim, each tied to the evaluation that proved it. If nothing is confirmed, write "None."

### EXPLORATORY
Interesting observations that were NOT the locked test: secondary metrics, partial runs, eyeballed curves, single seeds. Label clearly so no one mistakes these for results.

### FAILED / INCOMPLETE
Runs that did not finish the locked evaluation, and WHY. Distinguish scientific failure (method/config wrong) from operational interruption (infra). An operational interruption belongs here only if it actually prevented the evaluation from completing.

### HIGHEST VERIFIED RUNG
State the top rung (R0-R7) actually reached and the artifact that proves it (log path, metric value, checkpoint, decision memo). Use the canonical wording from `superpowers-ml:ml-feedback-ladder`.

### EVIDENCE GAPS
What remains unproven. What a skeptic would still doubt. Which rungs are not yet climbed.

### RECOMMENDED NEXT
The single next experiment that closes the most important gap. Name its target rung. This is what you hand your human partner to decide on.

## Force The Supported / Not-Supported Split

Every conclusion must separate what the evidence supports from what it does not. Model the language exactly:

```
Supported:         implementation trains stably through R5 pilot.
Not supported yet: variant beats baseline at full scale.
Exploratory:       early loss looked better, but this was not the
                   locked primary metric.
```

If you cannot phrase a claim as "Supported:" with its evidence, it is not supported. Demote it.

## Reporting Line

Close with the standard rung statement, naming the highest GREEN rung and what is still unverified above it, e.g.:

> Verified through R5 (short pilot). Not yet verified by full study.

## Red Flags - STOP

- "It works" / "the method wins" without the locked full evaluation
- Quoting a secondary or early metric as if it were the locked one
- Treating a preemption or requeue as a scientific failure
- Claiming a rung you did not reach, or omitting the artifact for it
- An empty EVIDENCE GAPS section (there are always gaps)
- A conclusion with no RECOMMENDED NEXT

## The Bottom Line

Separate confirmed from exploratory from failed. State the highest rung you actually climbed, with its artifact. Name what is still unproven.

A sober "not supported yet" is a real result. An over-claim is a liability.
