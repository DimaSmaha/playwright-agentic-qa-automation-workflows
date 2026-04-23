---
name: gf-commit
description: >-
  Create a conventional commit on the current Git branch from staged changes.
  Use when the user asks to commit current work, save changes, or generate a
  commit message. Stages all modified files automatically, drafts a conventional
  commit message, and commits without asking for confirmation.
argument-hint: "optional commit context or scope"
---

# gf-commit

Create a commit for the current branch using the real git changes.

## When this skill fits

Use it for requests like:

- "commit my changes"
- "save current work"
- "write a commit message and commit"
- "commit the test fix"

Do **not** use it for:

- pushing to remote
- amending or rewriting commit history
- squashing or rebasing

## Workflow

### 1. Stage all changes

Run:

```bash
git add .
```

This stages all changes — modified, deleted, and new untracked files. Secrets are blocked by the commit script.

### 2. Preview staged changes

Run:

```bash
git status --short
git diff --staged --stat
```

If there are no staged changes after the choice above, stop and return:

```text
No staged changes available to commit.
```

### 3. Draft a conventional commit message

Produce **one** proposed message from the diff. Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <subject>

[optional body]
```

**Type selection:**

| Type | When |
|---|---|
| `feat` | New feature or test scenario |
| `fix` | Bug fix or test correction |
| `test` | Add or update tests only |
| `refactor` | Code restructure, no behavior change |
| `chore` | Maintenance, config, tooling |
| `ci` | CI/CD changes |
| `docs` | Documentation only |

**Subject rules:**
- Imperative mood: "add" not "added"
- Under 72 characters
- Describes **what changed**, not vague intent (avoid "update", "misc fixes")

### 4. Create the commit

Run:

```bash
bash .claude/skills/gf-commit/scripts/create-commit.sh \
  --type <type> \
  --subject "<subject>" \
  --scope "<scope>" \
  --body "<body>" \
  --files <staged-paths>
```

Return the exact JSON output:

```json
{
  "sha": "deadbeef...",
  "branch": "task/1234-fix-login",
  "message": "fix(auth): correct token refresh timing",
  "files_committed": 2
}
```

## Hard rules

- Never commit on `main` or `master`.
- Never commit files that likely contain secrets (`.env`, `*.pem`, `*.key`, `playwright/.auth/*.json`); warn the user and stop.
- Do not amend existing commits; always create a new commit.
- Never skip hooks (`--no-verify`).
- If a hook fails, fix the issue and create a new commit — do not amend.
- Never read the bash scripts in `scripts/` before executing them. Call them directly.
