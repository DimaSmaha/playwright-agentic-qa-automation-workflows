---
name: git-flow
description: >-
  Git workflow reference. Decomposed into focused individual skills — use those
  instead. gf-branch: create branch. gf-commit: commit changes. gf-push: push
  branch. gf-pr: open pull request. gf-ship: full end-to-end flow (explicit
  invocation only). Scripts live in .claude/skills/git-flow/scripts/.
---

# git-flow

This skill has been decomposed into individual focused skills. Use them directly:

| Skill | When to use |
|---|---|
| `gf-branch` | Create a new feature branch |
| `gf-commit` | Commit staged changes with conventional message |
| `gf-push` | Push current branch to origin |
| `gf-pr` | Open or dedupe a GitHub pull request |
| `gf-ship` | Full end-to-end flow (EXPLICIT INVOCATION ONLY) |

## Scripts location

All bash scripts remain in `.claude/skills/git-flow/scripts/`:

- `create-branch.sh` — used by `gf-branch`
- `create-commit.sh` — used by `gf-commit`
- `push-branch.sh` — used by `gf-push`
- `create-pr.sh` — used by `gf-pr`
- `orchestrator/ship.sh` — used by `gf-ship`

## References

- Script flags and examples: `references/scripts.md`
- GitHub / GitLab / ADO adapter details: `references/adapters.md`
- Pipeline A / B wiring: `references/integration.md`
