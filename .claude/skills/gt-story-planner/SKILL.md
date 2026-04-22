---
name: gt-story-planner
description: >
  First stage of Pipeline A that converts a user story (ID or pasted text) into
  normalized planning artifacts for test generation. Use when asked to plan
  tests for a user story, break a story into scenarios, or prepare scenario
  coverage before writing Playwright tests.
---

# gt-story-planner

Produce `us.json` and `scenarios.md` as deterministic planning inputs for
downstream test ideation.

## Inputs

- User story id (preferred), or
- User story title + description text

## Flow

1. If input is an id, call `operations-with-issue-tracker/scripts/get.sh` to fetch story.
2. If input is pasted text, synthesize equivalent `us.json`.
3. Scan existing Playwright tests to detect already covered scenarios.
4. Emit ordered scenario list to `scenarios.md`.
5. Mark duplicates under `Skipped (already covered)`.

## Scenario design heuristics

- boundaries
- CRUD variations
- interruptions / cancel-retry paths
- invalid inputs
- concurrency
- read-only paths

## Output contracts

- `us.json`
- `scenarios.md` with entries in ordered format:
  - `[P][N] <Module> <description>`

## Rules

1. Write artifacts only in the run folder.
2. Keep output deterministic and resume-safe.
3. Do not create test cases or specs in this stage.
