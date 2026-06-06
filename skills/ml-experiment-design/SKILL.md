---
name: ml-experiment-design
description: Use when turning a rough ML idea into a runnable experiment - define the experiment card (question, hypothesis, baseline, primary metric, budget, cheapest verification rung) before writing training code.
---

# ML Experiment Design

## Overview

An ML idea is not runnable until it is a CARD. This skill turns a rough idea into a compact, one-screen experiment card — rung R0, the precondition for planning or launching anything. Fill it WITH your human partner; do not write training code until the card is settled.

**Core principle:** One change under test, one locked metric, one decision rule. If you cannot state in advance what result would change your mind, you are not ready to run.

**Upstream:** the idea comes from `superpowers-ml:brainstorming`.
**Downstream:** the card drives `superpowers-ml:ml-feedback-ladder` (how to verify it cheaply) and `superpowers-ml:writing-plans` (the tasks).

## The Experiment Card

Settle every field. Keep each to a line or two — a card, not a document.

- **Research question** — the one question this run answers.
- **Hypothesis** — specific and falsifiable: what changes, and the direction you expect.
- **Baseline** — the exact, runnable comparison (config / commit, not "the usual setup").
- **Variant(s)** — the SINGLE change under test. Anything else is a separate experiment.
- **Primary metric** — one metric, locked now, that decides the outcome.
- **Guardrail metrics** — what must NOT regress while the primary metric moves (cost, latency, memory, a quality/safety metric).
- **Dataset / split** — train / val / test, and the leakage risk you checked for.
- **Seed policy** — how many seeds, fixed or swept; how you tell seed noise from a real effect.
- **Budget** — the compute / wall-clock ceiling you will spend before stopping to decide.
- **Cheapest useful rung** — the smallest rung that tells you something real, to start at (see `superpowers-ml:ml-feedback-ladder`).
- **Success criterion** — the threshold on the primary metric that CONFIRMS the hypothesis, set before running.
- **Exploratory-only** — what this run may suggest but can never confirm (anything the locked primary metric does not measure).

## One Change At A Time

A variant is ONE change, or you cannot attribute the result — two changes is two experiments. If your human partner wants to vary many things, that is a study: write a card per change, then design a ladder for each.

## Template

```
Question:         ...
Hypothesis:       changing X will <increase|decrease> <metric> because ...
Baseline:         <config / commit>
Variant:          <the single change>
Primary metric:   <one, locked>     Success: <threshold set in advance>
Guardrails:       <must-not-regress>
Data / split:     <train / val / test>     Leakage check: <...>
Seeds:            <n, fixed | swept>
Budget:           <GPU-hours / wall-clock ceiling>
Start rung:       <cheapest useful rung>
Exploratory-only: <what will not count as confirmation>
```

## Red Flags - STOP

- No locked primary metric, or the metric is chosen after seeing results.
- Success criterion not written down before the run.
- More than one change under test in a single variant.
- "We'll know it when we see it" — no decision rule.

A card you can fill in five minutes saves a burned cluster job. Write it first.
