---
name: decomposition-maintenance
description: "Use when updating a UI decomposition markmap after features change; verify all visible fields and sections are represented, keep the tree aligned to the current app structure, and add missing nodes before marking coverage."
---

# Decomposition Maintenance

Use this skill when the decomposition map needs to stay in sync with the product.

## Workflow

1. Open the current decomposition file and identify the existing hierarchy.
2. Inspect the updated UI, page objects, tests, or snapshots to find new or removed fields.
3. Verify that every visible field, section, and flow is represented in the decomposition.
4. Add missing nodes with the smallest possible structural change.
5. Keep names consistent with the app UI and existing map conventions.
6. Preserve the markmap formatting and any existing legend or notes.
7. If a field cannot be verified from the available sources, leave it unstyled and do not invent unsupported nodes.

## Rules

- Prefer shallow, readable trees over deeply nested or duplicated branches.
- Keep the decomposition focused on user-facing elements and test-relevant structure.
- Do not rewrite unrelated sections when only one flow changed.
- If the app changed materially, update the decomposition first before adding coverage annotations.
