---
name: ft-bug-reporter
description: >
  Create or dedupe tracker bugs for classified Playwright app defects in Pipeline
  B. Use when classification.json returns app-bug with confidence above threshold
  and a bug artifact must be produced with links to evidence. Trigger on requests
  like "file bug from classification", "create issue for app-bug", or
  "generate bug.json from Playwright failure evidence".
---

# ft-bug-reporter

This skill turns a high-confidence `app-bug` classification into a tracker bug
and emits `bug.json` for downstream automation.

## Runs when

- `classification.json.verdict == "app-bug"`
- confidence meets project threshold

## Flow

1. Use issue-tracker wrapper scripts (do not call tracker APIs directly).
2. Create bug with dedupe key (error hash / stable signature).
3. Attach evidence artifacts (trace, screenshot, video when available).
4. Link the bug to failing test identity.
5. Emit normalized `bug.json`.

## Integration dependency

Use `operations-with-issue-tracker` for all tracker operations.

## Output contract (`bug.json`)

```json
{
  "id": 11111,
  "title": "...",
  "url": "...",
  "severity": "high",
  "summary": "...",
  "classification_source": "ft-classifier",
  "deduped": false
}
```

## Rules

1. JSON-only output, no free-form primary output.
2. Idempotent create behavior via dedupe key.
3. Keep severity mapping project-configurable.
4. Preserve evidence links in created/updated bug.
