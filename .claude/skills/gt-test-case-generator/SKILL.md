---
name: gt-test-case-generator
description: >
  Pipeline A stage that converts ideation output into tracker-backed test cases
  and structured steps artifacts. Use when asked to generate test cases from
  test-ideas.json, create QA test steps, or publish scenario-level test cases to
  the issue tracker with dedupe and resume safety.
---

# gt-test-case-generator

Convert one scenario from `test-ideas.json` into a tracker test case and emit
`tc.json` for downstream spec writing.

## When this skill fits

Use it for requests like:

- "create test case for scenario 2"
- "upload test case to the tracker"
- "generate tc.json for this scenario"
- "publish test case for the cart flow"

Do **not** use it for:

- generating ideation (use `gt-test-ideation`)
- writing Playwright specs (use `gt-spec-writer`)

## What comes before and after

- **Before:** `gt-test-ideation` produces `test-ideas.json`
- **After:** `gt-spec-writer` reads `tc.json` to generate the Playwright spec

## Inputs

**Required:**
- `test-ideas.json` from `gt-test-ideation`
- `scenario_index` — which scenario to process (0-based)

If `test-ideas.json` is missing, check `.workflow-artifacts/` or ask the user to
run `gt-test-ideation` first.

If `scenario_index` is not specified, ask: "Which scenario index should I create
a test case for? (0 = first scenario)"

## Workflow

### 1. Resume check

If `.workflow-artifacts/{run_id}/tc-{index}.json` already exists, return it
immediately without re-creating anything:

```text
tc.json already exists for scenario index <n>. Returning existing artifact.
```

### 2. Read the scenario

Load `test-ideas.json[scenario_index]`. Extract:

- `scenario` (title)
- `ideas` (steps)
- `verifications` (expected results)
- `navigations`, `conditions`, `ac_trace`, `reusable_helpers`

### 3. Format test case steps

Build a numbered step list pairing each idea with its verification:

```
Step 1: <ideas[0]>
  Expected: <verifications[0]>

Step 2: <ideas[1]>
  Expected: <verifications[1]>
...
```

Write this to `.workflow-artifacts/{run_id}/tc-steps-{index}.md`.

Also write `tc-steps-{index}.xml` as a simple XML list:

```xml
<steps>
  <step index="1">
    <action><![CDATA[<ideas[0]>]]></action>
    <expected><![CDATA[<verifications[0]>]]></expected>
  </step>
</steps>
```

### 4. Create the test case in the tracker

Run preflight if not already done:

```bash
bash .claude/skills/operations-with-issue-tracker/scripts/preflight.sh
```

Create the test case:

```bash
bash .claude/skills/operations-with-issue-tracker/scripts/create.sh \
  --type "Test Case" \
  --title "<scenario title>" \
  --description-file ".workflow-artifacts/${run_id}/tc-steps-${index}.md" \
  --parent "<us_id from us.json>" \
  --tag "automated,claude-generated"
```

**With the fake tracker:** the response is `{"id":0,"url":"...","deduped":false}`.
`id:0` is expected and valid. Generate a local ID:

```bash
local_id="tc-$(date +%s)"
```

### 5. Write tc.json

Write `.workflow-artifacts/{run_id}/tc-{index}.json` with the full ideation
context included (needed by `gt-spec-writer` to generate the spec):

```json
{
  "id": "tc-1234567890",
  "url": "http://localhost:3000/testcases/create",
  "title": "[P1] Auth: Login with valid credentials succeeds",
  "parent_us_id": "manual",
  "steps_xml_path": ".workflow-artifacts/gt-20240601-143012/tc-steps-0.xml",
  "scenario": "[P1] Auth: Login with valid credentials succeeds",
  "conditions": ["User is on the login page"],
  "ideas": ["User enters valid username", "..."],
  "verifications": ["Username field is filled", "..."],
  "navigations": ["login", "inventory"],
  "ac_trace": ["AC1: ..."],
  "reusable_helpers": ["LoginPage.login(username, password)"],
  "deduped": false
}
```

## Output

- `.workflow-artifacts/{run_id}/tc-{index}.json`
- `.workflow-artifacts/{run_id}/tc-steps-{index}.md`
- `.workflow-artifacts/{run_id}/tc-steps-{index}.xml`

Tell the user: "Pass `tc-{index}.json` to `gt-spec-writer` to generate the Playwright spec."

## Hard rules

- Resume-safe: if `tc.json` already exists for this index, return it without recreating.
- Always go through `operations-with-issue-tracker` scripts — never call tracker APIs directly.
- `id:0` from fake tracker is valid — generate a local `tc-{timestamp}` ID.
- Include the **full ideation context** in `tc.json` so `gt-spec-writer` doesn't need to re-read `test-ideas.json`.
- JSON-only primary output.
