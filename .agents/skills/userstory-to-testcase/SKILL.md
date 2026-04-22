---
name: userstory-to-testcase
description: >
  Generate structured test cases from user stories for QA engineers and test managers.
  Use this skill whenever a user story, feature ticket, or acceptance criteria needs to be
  converted into test cases. Triggers when the user mentions "test case", "user story",
  "acceptance criteria", "QA", "test scenario", "test steps", or drops a Jira/TMS link or
  story ID. Also triggers on phrases like "write tests for", "generate test cases",
  "create test scenarios", or "upload test to Jira". Use even if the request seems simple —
  this skill handles everything from story ingestion to TMS upload.
---

# User Story → Test Case Generator

Converts a user story (via CLI fetch, paste, or file drop) into fully structured,
TMS-ready test cases — covering title, steps, data, expected results, and upload.

---

## Phase 1 — Ingest the User Story

**Preferred: use the CLI tool to fetch the story.**

```bash
jira-cli issue view <STORY_ID> --output json
```

If no CLI is available or the user pastes the story directly, accept that as input.
If a file is dropped (`.txt`, `.md`, `.docx`, `.json`), read it with the appropriate tool.

**Extract and confirm:**

- Story title / summary
- Acceptance criteria (ACs)
- Priority / story points (if present)
- Epic / feature area
- Any linked designs, APIs, or dependencies

> If ACs are missing or vague, ask the user to clarify before proceeding.

---

## Phase 2 — Understand Feature, Area & Test Type

Before writing a single test step, reason through:

1. **Feature understanding** — What behaviour is being delivered? What is the user trying to achieve?
2. **App area** — Which part of the product is affected? (e.g. auth, checkout, dashboard, API, mobile nav)
3. **Test type(s) needed** — Select all that apply:

| Type                    | When to use                                 |
| ----------------------- | ------------------------------------------- |
| Functional / Happy path | Core AC validation                          |
| Negative / Edge case    | Invalid input, empty state, boundary values |
| Regression              | Touches existing flows                      |
| Integration             | Cross-service or API boundary               |
| Accessibility           | UI changes visible to screen readers        |
| Performance             | Load-sensitive paths                        |
| Security                | Auth, permissions, data exposure            |

Document your reasoning in a short **"Analysis block"** before writing test cases (shown in output).

---

## Phase 3 — Check Existing Locators, Methods & Patterns

Run the following to avoid duplicating selectors or step patterns:

```bash
# Search existing locator usage in Playwright tests/app code
rg -n "locator\(|getByRole\(|getByLabel\(|getByText\(|getByTestId\(" playwright/tests playwright/app

# Search page objects, fixture helpers, and reusable methods
rg -n "class .*Page|async .*\(|function .*\(" playwright/tests playwright/app

# If this repo does not use playwright/app, also search current project folders
rg -n "locator\(|getByRole\(|getByLabel\(|getByText\(|getByTestId\(" tests
rg -n "class .*Page|async .*\(|function .*\(" tests/pages tests/fixtures
```

> Read `references/locator-patterns.md` for the project's selector conventions.
> Read `references/step-patterns.md` for approved step phrasing and data formats.

Use what you find — don't invent new selectors when existing ones work.

---

## Phase 3.5 — Optional Real-Flow Context Check (Before Writing)

If acceptance criteria are unclear, dynamic, or missing edge details, run an exploratory
playwright-cli flow against the actual website using the user story path before writing test cases.

What to capture from this run:

- Actual field labels, placeholders, and validation messages
- Navigation order and step transitions
- Conditional states and error branches not explicit in the story
- Stable locator opportunities and reusable action patterns

Feed these observations back into Phase 4 so steps and expected results match real behaviour.

---

## Phase 4 — Write Test Cases

For **each acceptance criterion**, generate at minimum:

- 1 happy-path test case
- 1 negative or edge-case test case (unless trivially inapplicable)

### Test Case Structure

```
Title:         [Action] [Object] [Condition]  (≤10 words, imperative mood)
ID:            TC-<STORY_ID>-<seq>  (e.g. TC-PROJ-1234-01)
Type:          Functional | Negative | Regression | Integration | …
Priority:      P1 | P2 | P3
Preconditions: Bullet list of state before test starts
Steps:
  1. <Actor> <action> <object>
  2. …
Expected:      Observable outcome (what the user/system does)
Test Data:     Table of inputs used in the steps
Tags:          <area>, <story-id>, <type>
```

### Step Writing Rules

- Steps must be **atomic** — one action per step.
- Use third-person actor: _"User clicks…"_ / _"System displays…"_
- Reference real locator names or field labels found in Phase 3.
- Parameterise test data — never hardcode values inline; put them in the Test Data table.
- For API tests, include request method, endpoint, payload schema, and status code in Expected.

> See `references/step-patterns.md` for canonical phrasing examples.

---

## Phase 5 — Format for Jira / TMS

After drafting, format the output in the target system's structure.

### Jira (Zephyr / Xray)

```
Summary:        <Title>
Issue Type:     Test
Labels:         <tags>
Precondition:   <preconditions>
Test Steps (table):
  | Step | Test Data | Expected Result |
  | …    | …         | …               |
```

### Generic TMS (CSV / Markdown table)

```
TC ID | Title | Type | Priority | Preconditions | Steps | Expected | Test Data | Tags
```

> If the user specifies a TMS format, load `references/tms-formats.md` for exact field mappings.

---

## Phase 6 — Upload to Jira / TMS

**Preferred: use CLI tool.**

```bash
# Generic Jira CLI
jira-cli issue create \
  --type Test \
  --summary "<title>" \
  --body-file <testcase.md> \
  --label <tags>
```

If the upload succeeds, print the created issue URL.
If the CLI is unavailable, output the formatted test cases as copyable text and instruct
the user to paste them manually — providing the exact Jira field-by-field breakdown.

---

## Phase 7 — Final Text Output

Always end with a clean plain-text summary block the user can copy, share, or log:

```
========================================
TEST CASE GENERATION SUMMARY
Story:      <ID> — <Title>
Generated:  <timestamp>
Total TCs:  <N>  (Happy path: X | Negative: Y | Other: Z)
Uploaded:   <Yes — <URL>> | <No — manual paste required>
----------------------------------------
<TC-ID-01>  <Title>
<TC-ID-02>  <Title>
…
========================================
```

---

## Reference Files

Load these when relevant — do not load all upfront:

| File                             | When to read                                          |
| -------------------------------- | ----------------------------------------------------- |
| `references/locator-patterns.md` | Phase 3 — before writing steps involving UI selectors |
| `references/step-patterns.md`    | Phase 4 — for approved step phrasing conventions      |
| `references/tms-formats.md`      | Phase 5 — when a specific TMS export format is needed |

---

## Common Pitfalls to Avoid

- **Do not skip Phase 2** — understanding the app area prevents wrong test type selection.
- **Do not invent selectors** — always check existing locators first (Phase 3).
- **Do not hardcode test data** — parameterise everything into the Test Data table.
- **Do not write vague Expected results** — every expected result must be observable and verifiable.
- **Do not upload without confirming** — always show the formatted test cases to the user before uploading.
