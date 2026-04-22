# TMS Export Format Reference

Field mappings for each supported Test Management System.
Read this during Phase 5 when the user specifies a target TMS.

---

## Xray for Jira (REST API / UI)

| Xray Field             | Maps from                          |
| ---------------------- | ---------------------------------- |
| Summary                | Test Case Title                    |
| Issue Type             | `Test`                             |
| Labels                 | Tags (comma-separated)             |
| Test Type              | `Manual` or `Automated`            |
| Precondition           | Preconditions block                |
| Step → Action          | Step description                   |
| Step → Data            | Test Data variable + value         |
| Step → Expected Result | Expected result for that step      |
| Linked Issues          | Story ID (Jira issue link "tests") |

### CLI Upload (Xray)

```bash
pw-cli testcase create \
  --story <STORY_ID> \
  --file <testcase.json> \
  --project <PROJECT_KEY> \
  --type Manual
```

### JSON Payload Shape

```json
{
  "fields": {
    "summary": "<title>",
    "issuetype": { "name": "Test" },
    "labels": ["<tag1>", "<tag2>"],
    "priority": { "name": "P2" }
  },
  "steps": [
    {
      "action": "<step text>",
      "data": "<test data>",
      "result": "<expected result>"
    }
  ]
}
```

---

## Zephyr Scale (Jira plugin)

| Zephyr Field                 | Maps from                  |
| ---------------------------- | -------------------------- |
| Name                         | Test Case Title            |
| Objective                    | Story title + AC reference |
| Precondition                 | Preconditions block        |
| Priority                     | P1/P2/P3                   |
| Labels                       | Tags                       |
| Test Steps → Description     | Step text                  |
| Test Steps → Test Data       | Test Data table row        |
| Test Steps → Expected Result | Expected result            |
| Folder                       | App area (Phase 2)         |

### CLI Upload (Zephyr)

```bash
zscale-cli testcase create \
  --name "<title>" \
  --project <PROJECT_KEY> \
  --folder "<area>" \
  --steps-file <steps.json>
```

---

## TestRail

| TestRail Field    | Maps from                                |
| ----------------- | ---------------------------------------- |
| Title             | Test Case Title                          |
| Section           | App area                                 |
| Type              | Test type (Functional, Regression…)      |
| Priority          | P1–P4                                    |
| Preconditions     | Preconditions block                      |
| Steps → Content   | Step text                                |
| Steps → Expected  | Expected result                          |
| References        | Story ID                                 |
| Custom: Test Data | Test Data table (formatted as key:value) |

### CLI Upload (TestRail)

```bash
trcli -y \
  -h <TESTRAIL_URL> \
  --project "<PROJECT_NAME>" \
  parse_junit \
  --title "<suite name>" \
  -f <testcase.xml>
```

---

## CSV / Generic TMS

For systems with CSV import, output this column order:

```
TC_ID,Title,Type,Priority,Preconditions,Step_Number,Step_Action,Step_Data,Step_Expected,Tags,Story_ID
```

One row per step. Repeat TC metadata columns for each step row.

---

## Markdown (for PRs / Confluence)

```markdown
### TC-<ID>: <Title>

**Type:** <type> | **Priority:** <P1-P3> | **Tags:** `<tag1>` `<tag2>`

**Preconditions:**

- …

| #   | Step | Test Data | Expected |
| --- | ---- | --------- | -------- |
| 1   | …    | …         | …        |

**Story:** [<STORY_ID>](jira-url)
```
