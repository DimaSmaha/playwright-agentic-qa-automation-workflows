---
name: gf-push
description: >-
  Push the current local branch to origin using the same branch name. Use when
  the user wants to publish local commits or push a feature branch. Refuses to
  push main or master. Never force-pushes.
argument-hint: "optional remote name (default: origin)"
---

# gf-push

Push the current branch to `origin` safely.

## When this skill fits

Use it for requests like:

- "push my current branch"
- "publish this branch to origin"
- "push local commits to remote"

Do **not** use it for:

- pushing `main` or `master`
- force pushing
- deleting remote branches
- opening pull requests

## Workflow

### 1. Detect the current branch

Run `git branch --show-current`.

If the current branch is `main` or `master`, stop immediately and return:

```text
You cannot push the main branch with this skill. Switch to a feature branch first.
```

### 2. Push the branch

Run:

```bash
bash .claude/skills/git-flow/scripts/push-branch.sh
```

The script will:

- confirm the workspace is a git repository
- detect the current branch
- refuse if branch is `main` or `master`
- push to `origin/<same-branch-name>` using `-u` to set upstream

### 3. Return the result

Show the JSON output:

```json
{
  "branch": "task/1234-fix-login",
  "remote": "origin",
  "set_upstream": true,
  "pushed_sha": "deadbeef..."
}
```

## Hard rules

- Never push `main` or `master`.
- Never add `--force` or `--force-with-lease`.
- Always use the same branch name locally and remotely.
- Return the exact git result — do not summarize vaguely.
