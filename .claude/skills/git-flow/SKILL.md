---
name: git-flow
description: >
  End-to-end safe git workflow: create branch → commit → push → open PR, with
  a tracker item linked. Use this skill whenever the user wants to ship code,
  open a PR, commit changes, create a feature branch, or push work to a remote.
  Also triggers for phrases like "ship this", "make a PR", "commit my changes",
  "push to GitHub", or any multi-step git workflow. Strongly prefer this skill
  over ad-hoc git commands — it enforces safety rules (no force-push, no
  committing secrets, no committing on main) and produces structured JSON output
  compatible with Pipeline A and Pipeline B.
---

# git-flow

A safe, composable, CI-friendly git workflow skill. Takes working changes from
"I'm on a branch" → "PR open, tracker item linked" — while refusing anything
destructive.

## Quick reference

| Skill     | Script                   | One-liner             |
| --------- | ------------------------ | --------------------- |
| gf-branch | scripts/create-branch.sh | Create feature branch |
| gf-commit | scripts/create-commit.sh | Stage + commit safely |
| gf-push   | scripts/push-branch.sh   | Push current branch   |
| gf-pr     | scripts/create-pr.sh     | Open / dedupe PR      |
| gf-ship   | orchestrator/ship.sh     | Run all four in order |

---

## When to use which

- **Single step needed** → call the individual script directly.
- **Full flow from branch to PR** → use `gf-ship` (orchestrator).
- **Pipeline B (triage fix)** → `gf-branch → gf-commit → gf-push → gf-pr`
- **Pipeline A (feature)** → `gf-ship` with `--work-item-id`

---

## Environment variables (set before running)

```bash
export CORE_BRANCH=main          # base branch (default: main)
export PR_HOST=github            # github | gitlab | ado
export GITHUB_TOKEN=...          # or GITLAB_TOKEN / ADO_TOKEN
export REPO_OWNER=acme           # GitHub org or user
export REPO_NAME=my-repo
export WORK_ITEM_ID=11111        # tracker issue / ADO work item id
export WORK_ITEM_TITLE="..."     # used in branch name + PR title
```

---

## Safety rules (enforced by every script)

| Rule                          | Script that enforces it |
| ----------------------------- | ----------------------- |
| No push to `main`             | gf-push                 |
| No force-push                 | gf-push                 |
| No committing secrets         | gf-commit               |
| No committing on `main`       | gf-commit               |
| No duplicate PRs              | gf-pr                   |
| Branch must not exist         | gf-branch               |
| Base must be fast-forwardable | gf-branch               |

---

## Output contract

Every script emits **JSON only** to stdout.

- **Success** → structured object (see each section below)
- **Failure** → `{ "error": "...", ...context }` + exit code ≠ 0

No free-form stdout. Stderr is captured and surfaced in the JSON error object.

---

## Detailed script docs

Read `references/scripts.md` for full flag reference, examples, and edge cases.

## Adapter docs

Read `references/adapters.md` for GitHub / GitLab / ADO adapter details.

## Integration with pipelines

Read `references/integration.md` for Pipeline A / B wiring diagrams.

---

## Phase table (gf-ship output)

```
Phase   Status   Detail
BRANCH  SUCCESS  task/11111-filter-order-number
COMMIT  SUCCESS  fix(orders): scope date filter
PUSH    SUCCESS  origin/task/11111-filter-order-number
PR      SUCCESS  https://github.com/acme/repo/pull/88
```

Final JSON:

```json
{
  "run_id": "gfs-20240601-001",
  "verdict": "success",
  "pr_url": "https://github.com/acme/repo/pull/88",
  "branch_name": "task/11111-filter-order-number",
  "phases": [...]
}
```
