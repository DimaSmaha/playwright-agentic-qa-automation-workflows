---
name: operations-with-issue-tracker
description: >
  Unified issue-tracker wrapper skill for downstream agentic flows. Use when
  any workflow needs to read, create, update, link, comment on, query, or
  transition work items in ADO, GitHub Issues, Jira, or Linear. Strongly prefer
  this skill over direct tracker CLI/API calls so all callers share one stable
  JSON contract and can switch tracker adapters without changing caller logic.
---

# operations-with-issue-tracker

This skill provides a stable JSON interface for issue-tracker operations.
Callers must use this wrapper and must not invoke tracker-specific CLIs directly.

## Required environment

Set these before running any script:

- `ISSUE_TRACKER=ado|github|jira|linear`
- `TRACKER_ORG` and `TRACKER_PROJECT` when your adapter needs them
- Adapter authentication variables:
  - ADO: `ADO_TOKEN`
  - GitHub: `GITHUB_TOKEN` or `GH_TOKEN`
  - Jira: `JIRA_BASE_URL` and `JIRA_TOKEN` (optional `JIRA_EMAIL`)
  - Linear: `LINEAR_TOKEN`

## Script inventory

- `scripts/preflight.sh`
- `scripts/get.sh`
- `scripts/create.sh`
- `scripts/update.sh`
- `scripts/update-steps.sh`
- `scripts/link.sh`
- `scripts/comment.sh`
- `scripts/query.sh`
- `scripts/transition.sh`

All scripts emit JSON only.

## Output contract

- Success: domain object (for example `{"id":123,...}` or `{"ok":true}`)
- Failure: `{"error":"...", ...context}`
- Non-zero exit code on failure

## Rules

1. Run `scripts/preflight.sh` once per session before any other script.
2. Use `--dedupe-by` on create flows to avoid duplicate artifacts.
3. Do not hardcode internal tracker field IDs in caller workflows.
4. Keep caller logic tracker-agnostic; adapter logic is tracker-specific.

## References

- Detailed contracts: `references/tracker-schema.md`
- Script usage: `references/scripts.md`
- Adapter behavior and support: `references/adapters.md`
