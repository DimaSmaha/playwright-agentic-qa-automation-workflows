---
name: gt-test-ideation
description: >
  Pipeline A ideation stage that expands planned scenarios into structured test
  design units used by test-case generation and spec writing. Use when asked for
  test ideas, test design expansion, or conversion of scenarios into conditions,
  verifications, and navigations.
---

# gt-test-ideation

Consume `us.json` and `scenarios.md`, then generate structured scenario-level
test design artifacts.

## Inputs

- `us.json`
- `scenarios.md`

## Required output per scenario

```json
{
  "conditions": [],
  "ideas": [],
  "verifications": [],
  "navigations": [],
  "ac_trace": [],
  "reusable_helpers": []
}
```

## Constraints

1. `ideas.length === verifications.length` (hard fail if violated).
2. Navigation paths must be canonical.
3. Reuse existing page-object methods whenever possible.
4. Discover reusable methods from:
   - `playwright/app/ui/pages/**/*.page.ts`
   - `playwright/app/ui/components/**/*.component.ts`

## Output artifacts

- `test-ideas.md`
- `test-ideas.json`

## Rules

1. Keep artifact paths deterministic.
2. Preserve scenario index/title continuity from `scenarios.md`.
3. Do not create tracker entities in this stage.
