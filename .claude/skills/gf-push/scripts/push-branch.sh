#!/usr/bin/env bash
# gf-push — push-branch.sh
# Pushes the current branch to origin. Refuses main, force-push forbidden.
# Outputs JSON only. Exit 0 = success, non-zero = failure.
#
# Usage:
#   push-branch.sh [--remote origin]

set -euo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────
json_err() { printf '{"error":"%s","branch":"%s","stderr":"%s"}\n' "$1" "${BRANCH:-}" "${2:-}"; exit 1; }
json_ok()  { printf '%s\n' "$1"; exit 0; }

REMOTE="origin"
while [[ $# -gt 0 ]]; do
  case $1 in
    --remote) REMOTE="$2"; shift 2 ;;
    *) json_err "unknown argument: $1" ;;
  esac
done

# ── get current branch ────────────────────────────────────────────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) \
  || json_err "not a git repository" ""

# ── safety: refuse push to main ───────────────────────────────────────────────
[[ "$BRANCH" == "main" || "$BRANCH" == "master" ]] \
  && json_err "refusing to push directly to $BRANCH" ""

# ── detect existing upstream ──────────────────────────────────────────────────
SET_UPSTREAM=true
if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  SET_UPSTREAM=false
fi

# ── push (no force, ever) ─────────────────────────────────────────────────────
PUSH_STDERR_FILE=$(mktemp)
PUSH_FLAGS=(-u "$REMOTE" HEAD)

if ! git push "${PUSH_FLAGS[@]}" 2>"$PUSH_STDERR_FILE"; then
  STDERR_SNIPPET=$(tail -5 "$PUSH_STDERR_FILE" | tr '\n' ' ' | sed 's/"/\\"/g')
  rm -f "$PUSH_STDERR_FILE"
  json_err "push failed" "$STDERR_SNIPPET"
fi
rm -f "$PUSH_STDERR_FILE"

PUSHED_SHA=$(git rev-parse HEAD)

json_ok "$(printf '{"branch":"%s","remote":"%s","set_upstream":%s,"pushed_sha":"%s"}' \
  "$BRANCH" "$REMOTE" "$( [[ $SET_UPSTREAM == true ]] && echo true || echo false)" "$PUSHED_SHA")"