---
name: gf-commit
description: >-
  Create a conventional commit on the current Git branch from staged changes.
  Use when the user asks to commit current work, save changes, or generate a
  commit message. Asks whether to stage all unstaged files. Shows the proposed
  message and waits for confirmation before committing.
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

### 1. Ask about staging

Ask the user:

```text
Do you want to stage all unstaged files before committing?
```

Options:
- **Yes** — stage all unstaged files (`--files .`)
- **No** — use the current staged set as-is

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

### 4. Show and confirm the message

Display the proposed message:

**Proposed commit message**
```
<proposed-message>
```

Then ask: `Is this commit message OK?`

- **OK** → proceed to step 5 with this message
- **Not OK** → ask the user to send their exact message in their next reply; do not commit until received

### 5. Create the commit

Run:

```bash
bash .claude/skills/git-flow/scripts/create-commit.sh \
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
- Do not create the commit until the user confirms **OK** (or supplies their own message after **Not OK**).
- Do not amend existing commits; always create a new commit.
- Never skip hooks (`--no-verify`).
- If a hook fails, fix the issue and create a new commit — do not amend.
