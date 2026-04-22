# Adapter reference

Adapter scripts live under:

`scripts/adapters/<tracker>/<verb>.sh`

Each adapter must emit the same JSON shape for each verb.

## Current support

- `github`: implemented for all verbs (`gh` CLI)
- `ado`: preflight implemented, verb stubs return JSON errors
- `jira`: preflight implemented, verb stubs return JSON errors
- `linear`: preflight implemented, verb stubs return JSON errors

## Adapter contract rules

1. Print JSON to stdout only.
2. Exit non-zero on failure.
3. Keep caller-facing fields tracker-neutral.
4. Handle tracker-native field mapping inside adapter scripts only.
