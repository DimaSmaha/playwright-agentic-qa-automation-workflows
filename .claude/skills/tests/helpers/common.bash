#!/usr/bin/env bash
# Shared helpers for all test suites.
# Sourced via bats `load '../helpers/common'` (depth-adjusted per suite).

_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$_HELPERS_DIR/.." && pwd)"
SKILLS_DIR="$(cd "$TESTS_DIR/.." && pwd)"

OWT_SCRIPTS="$SKILLS_DIR/operations-with-issue-tracker/scripts"
GF_BRANCH_SCRIPTS="$SKILLS_DIR/gf-branch/scripts"
GF_COMMIT_SCRIPTS="$SKILLS_DIR/gf-commit/scripts"
GF_PUSH_SCRIPTS="$SKILLS_DIR/gf-push/scripts"
GF_PR_SCRIPTS="$SKILLS_DIR/gf-pr/scripts"

setup_artifacts_dir() {
  export WORKFLOW_ARTIFACTS_DIR
  WORKFLOW_ARTIFACTS_DIR="$(mktemp -d)"
}

teardown_artifacts_dir() {
  [[ -n "${WORKFLOW_ARTIFACTS_DIR:-}" ]] && rm -rf "$WORKFLOW_ARTIFACTS_DIR"
  unset WORKFLOW_ARTIFACTS_DIR
}

# Skip a test if FAKE_TRACKER_URL is not set or the server is not reachable.
require_fake_tracker() {
  if [[ -z "${FAKE_TRACKER_URL:-}" ]]; then
    skip "FAKE_TRACKER_URL not set"
  fi
  if ! curl -sf "${FAKE_TRACKER_URL}/" >/dev/null 2>&1; then
    skip "fake tracker not reachable at ${FAKE_TRACKER_URL}"
  fi
}

# Skip a test if GITHUB_TOKEN (or GH_TOKEN) and REPO_OWNER/REPO_NAME are not set.
require_github() {
  if [[ -z "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
    skip "GITHUB_TOKEN not set"
  fi
  if [[ -z "${REPO_OWNER:-}" || -z "${REPO_NAME:-}" ]]; then
    skip "REPO_OWNER or REPO_NAME not set"
  fi
}

# Bats-compatible assertions
assert_success() {
  if [[ "$status" -ne 0 ]]; then
    echo "Expected exit 0, got exit $status. Output: $output" >&3
    return 1
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "Expected non-zero exit, got exit 0. Output: $output" >&3
    return 1
  fi
}

assert_output_contains() {
  if ! printf '%s' "$output" | grep -qF "$1"; then
    echo "Output missing: '$1'" >&3
    echo "Actual output: $output" >&3
    return 1
  fi
}

assert_json_field() {
  local field="$1" expected="$2"
  local actual
  actual="$(printf '%s' "$output" | jq -r ".$field" 2>/dev/null || echo "PARSE_ERROR")"
  if [[ "$actual" != "$expected" ]]; then
    echo "JSON field .$field: expected='$expected' actual='$actual'" >&3
    echo "Output: $output" >&3
    return 1
  fi
}
