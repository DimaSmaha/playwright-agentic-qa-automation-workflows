---
name: gf-branch
description: >-
  Create a new Git branch from the latest main branch. Use when starting work
  on a feature, fix, or task. Requires a work-item-id or an explicit branch
  name; if neither is supplied, ask for it and stop. Do not use for merging,
  deleting branches, or opening pull requests.
argument-hint: "work-item-id [optional title]"
---

# gf-branch

Create and switch to a new feature branch safely.

## When this skill fits

Use it for requests like:

- "create a branch for task 1234"
- "start a branch for this fix"
- "checkout a new branch called fix/login-timeout"

Do **not** use it for:

- merging or rebasing branches
- deleting or renaming branches
- pushing or opening pull requests

## Workflow

### 1. Require a work-item-id or branch name

Check whether a work-item-id or explicit branch name was provided.

If neither is supplied, respond with:

```text
A work-item-id or branch name is required to create a branch.
```

Then stop.

### 2. Confirm the workspace is a git repo

Verify `git rev-parse --is-inside-work-tree` returns success. If not, stop and
tell the user to run this from inside a git repository.

### 3. Create the branch

Run the helper script:

```bash
bash .claude/skills/gf-branch/scripts/create-branch.sh \
  --work-item-id <id> \
  --title "<title>" \
  --base main
```

The script will:

- fetch the latest `main` from origin
- verify `main` is fast-forwardable locally
- refuse if the branch already exists locally or on origin
- create and switch to `task/<id>[-<slug>]`

### 4. Return the result

Show the JSON output from the script:

```json
{
  "branch": "task/1234-fix-login-timeout",
  "base": "main",
  "base_sha": "abc123...",
  "work_item_id": 1234
}
```

Do not paraphrase or guess — return the exact script output.

## Hard rules

- Never invent a branch name without a work-item-id or explicit input.
- Never create a branch from or on `main`.
- Use `--ff-only` semantics when updating the base branch.
- If the branch already exists, stop and show the script error — do not proceed.
- Return the exact git result, not a summary.
- Never read the bash scripts in `scripts/` before executing them. Call them directly.
