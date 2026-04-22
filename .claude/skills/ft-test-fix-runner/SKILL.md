---
name: ft-test-fix-runner
description: >
  Automated test-side fix execution for Pipeline B after ft-classifier identifies
  a high-confidence test-bug. Use when classification.json recommends test repair
  and a safe git workflow must create a PR. Trigger on requests like "fix
  test-bug and open PR", "run classified test fix flow", or "apply test fix from
  classification".
---

# ft-test-fix-runner

This skill applies targeted test-only fixes for a classified `test-bug` and
ships them through a safe branch-to-PR workflow.

## Runs when

- `classification.json.verdict == "test-bug"`
- confidence meets project threshold

## Flow

1. Create feature branch for the fix.
2. Modify failing test based on classified signals.
3. Commit with scoped message.
4. Push branch.
5. Open or dedupe PR.

## Delegation

Use `git-flow` scripts for execution:

- `gf-branch`
- `gf-commit`
- `gf-push`
- `gf-pr`

## Output contract

Return JSON with at least:

```json
{
  "verdict": "success|failed",
  "branch_name": "task/...",
  "commit_sha": "...",
  "pr_url": "https://...",
  "classification_source": "ft-classifier"
}
```

## Guardrails

1. Restrict changes to test-side code unless explicitly allowed otherwise.
2. Refuse destructive git operations (no force-push, no main-branch commit).
3. Keep run deterministic and idempotent where possible.
4. Emit JSON-only primary output.
