---
name: gf-pr
description: >-
  Create a pull request from the current branch to main on GitHub. Use when the
  user asks to open a PR, publish work for review, or create a pull request.
  Requires GITHUB_TOKEN. Deduplicates: if a PR already exists for the branch,
  returns the existing one. Do not use for merging, force-push, or PRs from main.
argument-hint: "optional PR title or work-item-id"
---

# gf-pr

Create a pull request from the current branch to `main` on GitHub.

## When this skill fits

Use it for requests like:

- "open a PR for this branch"
- "create a pull request"
- "publish this branch for review"
- "make a PR for task 1234"

Do **not** use it for:

- merging pull requests
- reviewing or commenting on PRs
- creating a PR from `main`
- force-pushing

## Workflow

### 1. Detect the current branch

Run `git branch --show-current`.

If the branch is `main` or `master`, stop and return:

```text
You cannot create a pull request from the main branch. Switch to a feature branch first.
```

### 2. Verify GITHUB_TOKEN

Check that `GITHUB_TOKEN` (or `GH_TOKEN`) is set in the environment. If missing, stop and return:

```text
GITHUB_TOKEN is required to create a pull request.
Set it in your environment: export GITHUB_TOKEN=<your-pat>
```

Also verify `REPO_OWNER` and `REPO_NAME` are set (or derivable from `git remote -v`).

### 3. Check for existing PR on this branch

The helper script checks for an open PR with the same source branch before creating a new one. If found, it returns the existing PR with `"deduped": true` — no new PR is opened.

### 4. Build the PR title

Priority order:

1. `[<work-item-id>] <WORK_ITEM_TITLE>` — if `WORK_ITEM_ID` and `WORK_ITEM_TITLE` are set
2. Explicit `--title` if provided
3. Derived from branch name and commit subjects (`git log main..HEAD --oneline`)

Never invent a misleading title. If the branch name is unclear, read the actual commits.

### 5. Create the PR

Run:

```bash
bash .claude/skills/git-flow/scripts/create-pr.sh \
  --work-item-id <id> \
  --base main
```

The script uses `gh pr create` via the GitHub CLI adapter.

Return the JSON output:

```json
{
  "id": 88,
  "url": "https://github.com/org/repo/pull/88",
  "title": "[1234] fix(auth): correct token refresh timing",
  "linked_work_item_id": 1234,
  "deduped": false
}
```

## Hard rules

- Never create a PR from `main`.
- Never proceed without `GITHUB_TOKEN`.
- Never invent a PR title — base it on real work-item-id or commits.
- If an open PR already exists on this branch, return it (`deduped: true`); do not create a duplicate.
- Return the exact PR URL from `gh` output — do not guess URLs.
- Do not force-push as part of PR creation.
