---
name: skill-creator
description: >
  Create, improve, or benchmark SKILL.md files for the Claude Code skill system.
  Use when asked to write a new skill, improve an existing skill's instructions,
  measure skill performance, or optimize a skill's trigger description. Runs
  parallel with-skill vs baseline evaluations and produces benchmark.json.
---

# skill-creator

Author, iterate, and measure Claude Code skills. Works for net-new skills and
rewrites of existing ones.

## When this skill fits

- "create a new skill for X"
- "improve the gt-story-planner skill"
- "benchmark this skill"
- "optimize the trigger description for ft-classifier"
- "write evals for the new skill"

Do **not** use it for:

- running the pipelines themselves (use `gt-us-to-spec` or `ft-orchestrator`)
- writing Playwright tests (use `gt-spec-writer`)

## Skill anatomy

Every skill lives at `.claude/skills/<name>/SKILL.md` and follows this structure:

```
skill-name/
├── SKILL.md          required, target <400 lines
│   ├── YAML frontmatter  name + description (both required)
│   └── Markdown workflow
└── scripts/          optional — shell scripts invoked by the skill
└── references/       optional — reference docs read during execution (~300 lines each)
```

**Frontmatter fields:**

| Field | Required | Purpose |
|---|---|---|
| `name` | yes | Identifier used in skill list |
| `description` | yes | Trigger text — drives when Claude invokes this skill |
| `compatibility` | no | Tool/env dependencies |

The `description` field is the most important: it must state *when to use* (trigger conditions) and *what it does* (outcome). Vague descriptions cause missed triggers or false triggers.

## Workflow

### 1. Capture intent

Ask the user (one question at a time):

1. What should the skill do and when should it trigger?
2. What inputs does it receive and what outputs does it produce?
3. What are the 2-3 most important rules / hard constraints?
4. Who calls this skill — a user directly, or another skill (pipeline)?

Stop after each answer to confirm before continuing.

### 2. Research existing patterns

Before writing, check what already exists:

```bash
ls .claude/skills/
```

Read the SKILL.md for any related existing skill. Reuse structure and conventions
rather than inventing new ones. Note what the new skill must NOT duplicate.

### 3. Draft SKILL.md

Write the skill file at `.claude/skills/<name>/SKILL.md`.

Required sections:
- YAML frontmatter with `name` and `description`
- **When this skill fits** — trigger examples + do-not-use list
- **What comes before and after** — pipeline position (if applicable)
- **Inputs** — what is required; what to ask for if missing
- **Workflow** — numbered steps, each a concrete action
- **Output** — files written + what to tell the user
- **Hard rules** — invariants that must never be violated

Keep it under 400 lines. Every line must be actionable — no padding.

### 4. Write evaluation cases

Create 2-3 realistic eval prompts that cover:
- The primary happy-path trigger
- A boundary / edge case
- A should-NOT-trigger case (to test description precision)

Format:

```json
{
  "skill_name": "<name>",
  "evals": [
    {
      "id": 1,
      "prompt": "Exact user request that should trigger the skill",
      "expected": "Description of what a correct run looks like",
      "should_trigger": true
    },
    {
      "id": 2,
      "prompt": "Request that looks similar but should NOT trigger",
      "expected": "Skill is not invoked; a different skill handles it",
      "should_trigger": false
    }
  ]
}
```

Write to `.workflow-artifacts/skill-evals/<name>-evals.json`.

### 5. Run parallel evaluations

For each eval with `should_trigger: true`:

1. Run **with-skill** — invoke the skill explicitly, observe output
2. Run **baseline** — run the same prompt without skill invocation, observe output

Run both in parallel where possible. Record:
- Pass / fail on each expected assertion
- Time taken (seconds)
- Approximate token count

Write results to `.workflow-artifacts/skill-evals/<name>-benchmark.json`:

```json
{
  "skill": "<name>",
  "timestamp": "<ISO>",
  "evals": [
    {
      "id": 1,
      "with_skill": { "passed": true, "time_s": 12, "notes": "..." },
      "baseline":   { "passed": false, "time_s": 8,  "notes": "..." }
    }
  ],
  "pass_rate_with_skill": 0.90,
  "pass_rate_baseline": 0.40
}
```

### 6. Analyze and improve

Read benchmark results. For each failed assertion:
- Is the skill instruction ambiguous?
- Is the workflow missing a step?
- Is the description causing false triggers or missed triggers?

Apply targeted edits to SKILL.md. Re-run only the failing evals to confirm fix.
Stop when pass rate ≥ 0.85 or user accepts current state.

### 7. Optimize the trigger description

The frontmatter `description` controls when the skill fires. To improve it:

1. Write 20 trigger queries: 12 should-trigger, 8 should-not-trigger
2. For each: does the current description cause the correct decision?
3. Identify false-positive patterns (skill fires when it shouldn't) and
   false-negative patterns (skill is missed when it should fire)
4. Rewrite description — be specific about trigger conditions; list clear
   exclusions in "SKIP when" or "Do NOT use" language
5. Re-evaluate on the 20 queries; accept when misclassification rate < 10%

## Output

- `.claude/skills/<name>/SKILL.md`
- `.workflow-artifacts/skill-evals/<name>-evals.json`
- `.workflow-artifacts/skill-evals/<name>-benchmark.json`

Tell the user the pass rate and whether the description optimization is recommended.

## Hard rules

- Never ship a skill with no eval cases — untested skills drift.
- Always run baseline alongside with-skill — improvement is relative, not absolute.
- Do not exceed 400 lines in SKILL.md — prune before adding.
- Do not duplicate instructions already in an existing skill — link or defer instead.
- The `description` field must mention at least one concrete trigger phrase and one explicit exclusion.
