---
name: gf-ship
description: >-
  EXPLICIT-INVOCATION ONLY. Run the full git workflow end-to-end: create branch,
  commit, push, open PR. Use only when the user explicitly asks to ship a
  complete feature branch from scratch in one flow. For any partial operation
  (just branch, just commit, just push, just PR) use the individual gf-* skills
  instead.
argument-hint: "work-item-id commit-subject [optional flags]"
---

# gf-ship

EXPLICIT-INVOCATION ONLY.

Coordinate `gf-branch` → `gf-commit` → `gf-push` → `gf-pr` as sequential phases.
Stops on the first failure. Reports phase status after each step.

## When this skill fits

Use it for requests like:

- "ship this feature end-to-end"
- "run the full branch-to-PR workflow"
- "create a branch, commit, push, and open a PR in one go"

Do **not** use it for:

- partial git operations (one phase only — use the individual skill)
- merging, rebasing, or history rewriting
- pushing to or creating a PR from `main`

## What you need before starting

- `GITHUB_TOKEN` set in environment or `.env` (required for the PR phase — the script sources `.env` automatically)
- `REPO_OWNER` and `REPO_NAME` set (or inferrable from `git remote -v`)
- A work-item-id for the branch name and PR title
- A clear commit subject describing the change

Infer what is available from context and proceed. Only stop if a work-item-id truly cannot be derived.

## Workflow

### Option A — Script-driven (non-interactive commit)

When the user supplies a final commit message and wants one command:

```bash
bash .claude/skills/gf-ship/scripts/ship.sh \
  --work-item-id <id> \
  --title "<work-item-title>" \
  --commit-type <type> \
  --commit-subject "<subject>" \
  --commit-scope "<scope>" \
  --base main \
  --files <space-separated-paths>
```

Interpret the phase banners and final `PR_URL:` from the script output.

### Phase summary

After all phases, output a compact table:

```
| Phase | Skill     | Status  | Notes                              |
|-------|-----------|---------|-------------------------------------|
| 1     | gf-branch | SUCCESS | task/1234-fix-login-timeout         |
| 2     | gf-commit | SUCCESS | fix(auth): correct token refresh    |
| 3     | gf-push   | SUCCESS | origin/task/1234-fix-login-timeout  |
| 4     | gf-pr     | SUCCESS | https://github.com/org/repo/pull/88 |

PR: https://github.com/org/repo/pull/88
```

Use **FAILED** and stop populating later phases if a step errors.

## Hard rules

- All hard rules from individual `gf-*` skills apply here.
- Never push to or create a PR from `main`.
- Require `GITHUB_TOKEN` before Phase 4 starts (sourced from `.env` automatically by the PR script).
- Return the PR URL exactly as printed by `gh`; do not guess.
- If the user only needs one phase, direct them to the individual skill instead.
- Never read the bash scripts in `scripts/` before executing them. Call them directly.
