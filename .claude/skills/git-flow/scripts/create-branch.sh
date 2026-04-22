#!/usr/bin/env bash
# gf-branch — create-branch.sh
# Creates a safe feature branch from the base branch.
# Outputs JSON only. Exit 0 = success, non-zero = failure.
#
# Usage:
#   create-branch.sh --work-item-id 11111 --title "filter order number" [--base main]
#
# Required env:
#   (none beyond a valid git repo)
#
# Optional env:
#   CORE_BRANCH  default base branch (default: main)

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────
die() { printf '{"error":"%s","branch":"%s","location":"%s"}\n' "$1" "${BRANCH:-}" "${LOCATION:-}"; exit 1; }
json_success() { printf '%s\n' "$1"; exit 0; }

# ── arg parsing ───────────────────────────────────────────────────────────────
WORK_ITEM_ID=""
WORK_ITEM_TITLE=""
BASE="${CORE_BRANCH:-main}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --work-item-id) WORK_ITEM_ID="$2"; shift 2 ;;
    --title)        WORK_ITEM_TITLE="$2"; shift 2 ;;
    --base)         BASE="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$WORK_ITEM_ID" ]] && die "missing --work-item-id"

# ── build branch name ─────────────────────────────────────────────────────────
slug() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//; s/-$//'
}

TITLE_SLUG=$(slug "${WORK_ITEM_TITLE:-}")
RAW="task/${WORK_ITEM_ID}${TITLE_SLUG:+-$TITLE_SLUG}"
BRANCH="${RAW:0:60}"   # truncate to ~60 chars

# ── safety checks ─────────────────────────────────────────────────────────────
# Must be inside a git repo
git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"

# Fetch latest base
git fetch origin "$BASE" 2>/dev/null || die "could not fetch origin/$BASE"

# Fast-forward check
LOCAL_SHA=$(git rev-parse "$BASE" 2>/dev/null || true)
REMOTE_SHA=$(git rev-parse "origin/$BASE")
if [[ -n "$LOCAL_SHA" && "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  git merge --ff-only "origin/$BASE" 2>/dev/null || die "base branch cannot be fast-forwarded — merge or rebase first"
fi

# Local branch existence
LOCATION=""
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  LOCATION="local"
  die "branch already exists"
fi

# Remote branch existence
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  LOCATION="origin"
  die "branch already exists"
fi

# ── create branch ─────────────────────────────────────────────────────────────
BASE_SHA=$(git rev-parse "origin/$BASE")
git switch -c "$BRANCH" "origin/$BASE"

json_success "$(printf '{"branch":"%s","base":"%s","base_sha":"%s","work_item_id":%s}' \
  "$BRANCH" "$BASE" "$BASE_SHA" "$WORK_ITEM_ID")"