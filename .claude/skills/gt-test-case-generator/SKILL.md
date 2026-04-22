---
name: gt-test-case-generator
description: >
  Pipeline A stage that converts ideation output into tracker-backed test cases
  and structured steps artifacts. Use when asked to generate test cases from
  test-ideas.json, create QA test steps, or publish scenario-level test cases to
  the issue tracker with dedupe and resume safety.
---

# gt-test-case-generator

Transform scenario ideation into tracker test case artifacts for downstream
spec writing.

## Input

- `test-ideas.json`
- selected `scenario_index`

## Flow

1. Read `test-ideas.json[scenario_index]`.
2. Render tracker-compatible steps file to `tc-steps.xml`.
3. Create test case via `operations-with-issue-tracker/scripts/create.sh --type "Test Case"`.
4. Update case steps via `operations-with-issue-tracker/scripts/update-steps.sh`.
5. Emit normalized `tc.json`.

## Output contracts

- `tc-steps.xml`
- `tc.json` with at least:

```json
{
  "id": 11111,
  "url": "https://...",
  "title": "...",
  "parent_us_id": 11112,
  "steps_xml_path": "workflow-artifacts/.../tc-steps.xml",
  "ideas_json_path": "workflow-artifacts/.../test-ideas.json",
  "deduped": false
}
```

## Rules

1. Resume-safe: short-circuit if `tc.json` already exists for the scenario.
2. Use dedupe-first creation semantics.
3. Keep tracker logic adapter-agnostic through `operations-with-issue-tracker`.
4. Emit JSON-only primary output.
