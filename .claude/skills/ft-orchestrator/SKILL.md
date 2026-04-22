---
name: ft-orchestrator
description: >
  Single-flow orchestrator for the full ft Pipeline B chain. Use when the user
  wants one end-to-end failure triage run from failing spec input to classified
  outcome and routed action (test-fix PR or app-bug report), with deterministic
  artifact handoffs between all ft stage skills.
---

# ft-orchestrator

EXPLICIT-INVOCATION ONLY.

Run one end-to-end Pipeline B flow using all ft stage skills:

1. `ft-repro`
2. `ft-classifier`
3. `ft-test-fix-runner` or `ft-bug-reporter` (routed by verdict)

## Inputs

- failing spec path
- optional browser/project selector
- optional confidence thresholds

## Canonical flow

1. Initialize `run_id` and artifact folder.
2. Run `ft-repro` → `repro.json` + evidence artifacts.
3. Run `ft-classifier` with `repro.json` → `classification.json`.
4. Route by `classification.json.verdict`:
   - `test-bug` with threshold met → `ft-test-fix-runner`
   - `app-bug` with threshold met → `ft-bug-reporter`
   - `flaky` → mark/retry policy branch
   - `infra` or `needs-human` → stop and escalate

## Expected artifacts

- `repro.json`
- `classification.json`
- `trace.zip`
- failure screenshot/video
- optional `bug.json` (app-bug branch)
- optional PR metadata (test-bug branch)

## Final summary output

Include:

- run id
- verdict
- confidence
- selected branch skill
- resulting bug URL or PR URL when applicable

## Execution rules

1. Keep handoffs file-based and deterministic.
2. Spawn each stage as a fresh agent context.
3. Preserve resume semantics when stage artifacts already exist.
4. Keep tracker operations delegated via `operations-with-issue-tracker`.
5. Keep git operations delegated via `git-flow`.
