---
name: decomposition-coverage
description: "Use when marking fields in a decomposition markmap as covered by automated tests; classify nodes as fully covered or partially covered and wrap them in color spans that match the map legend."
---

# Decomposition Coverage

Use this skill when a decomposition file already exists and new automated tests need to be reflected in the coverage styling.

## Coverage Rules

- Mark a node as fully covered only when the automated tests exercise the complete field or flow.
- Mark a node as partially covered when tests touch part of the section but not every field or state.
- Leave a node unstyled when there is no direct test coverage.
- Keep the styling consistent with the document legend.

## Styling Convention

- Fully covered: `<span style="color:green">**Text**</span>`
- Partially covered: `<span style="color:orange">_Text_</span>`
- Uncovered: plain text

## Workflow

1. Read the current decomposition and identify which nodes are already styled.
2. Inspect the latest automated tests and page objects to see what they actually cover.
3. Update only the affected nodes.
4. Use span wrappers instead of plain bold or italics when adding coverage color.
5. Keep the legend up to date if the color convention changes.
6. Avoid over-marking: only color nodes with evidence from tests.

## Notes

- Prefer the smallest edit that communicates coverage clearly.
- If a test covers only one branch of a feature, mark the parent as partial rather than fully covered.
- If the decomposition and tests disagree, update the decomposition structure first, then apply coverage.
