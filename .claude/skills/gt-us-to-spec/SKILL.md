---
name: gt-us-to-spec
description: >
  Explicit-invocation orchestrator for Pipeline A (User Story → Automated Test).
  Use only when the caller explicitly requests a full end-to-end flow from user
  story to Playwright spec artifacts. Chains planner, ideation, test-case
  generation, spec writing, and refactor stages with per-scenario routing.
---

# gt-us-to-spec

EXPLICIT-INVOCATION ONLY.

Run full Pipeline A with artifact handoffs and per-scenario branching.

## Accepted inputs

- `--us-id <id>`
- `--us-text "<title+description>"`

## Orchestration flow

1. `gt-story-planner` → `us.json`, `scenarios.md`
2. `gt-test-ideation` → `test-ideas.json`
3. Loop each scenario:
   - `gt-test-case-generator` → `tc.json`, `tc-steps.xml`
   - `gt-spec-writer` → `spec.json`, `.spec.ts`
   - if passing: `gt-refactor-tests` → `refactor.done`
   - if failing: route to Pipeline B app-bug reporting leg

## Orchestrator state

Keep only:

- `run_id`
- scenario list
- per-scenario status summary

## Final summary output

Emit table-like summary for each scenario:

- scenario
- test case id
- spec path
- status
- PR (if available)

## Rules

1. Spawn each stage as a fresh agent.
2. Keep handoff contracts file-based; avoid free-form state transfer.
3. Support resume semantics if stage artifacts already exist.
4. Keep tracker operations delegated via `operations-with-issue-tracker`.
