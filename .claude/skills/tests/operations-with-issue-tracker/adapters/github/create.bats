#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/github/create.sh"

# Track created issue numbers so teardown can close them.
CREATED_ISSUE_ID=""

setup() { setup_artifacts_dir; }

teardown() {
  teardown_artifacts_dir
  if [[ -n "$CREATED_ISSUE_ID" && -n "${REPO_OWNER:-}" && -n "${REPO_NAME:-}" ]]; then
    gh issue close "$CREATED_ISSUE_ID" --repo "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1 || true
    CREATED_ISSUE_ID=""
  fi
}

_env() {
  printf 'REPO_OWNER=%s REPO_NAME=%s WORKFLOW_ARTIFACTS_DIR=%s' \
    "'$REPO_OWNER'" "'$REPO_NAME'" "'$WORKFLOW_ARTIFACTS_DIR'"
}

@test "github/create: exits 1 when --type is missing" {
  require_github
  run bash -c "$(_env) bash '$CREATE_ADAPTER' --title 'T'"
  assert_failure
  assert_output_contains 'missing --type'
}

@test "github/create: exits 1 when --title is missing" {
  require_github
  run bash -c "$(_env) bash '$CREATE_ADAPTER' --type Bug"
  assert_failure
  assert_output_contains 'missing --title'
}

@test "github/create: creates a real GitHub issue and returns contract JSON" {
  require_github
  run bash -c "$(_env) bash '$CREATE_ADAPTER' --type Bug --title '[bats-test] create adapter smoke test'"
  assert_success
  assert_json_field 'deduped' 'false'
  assert_output_contains '"url"'
  CREATED_ISSUE_ID="$(printf '%s' "$output" | jq -r '.id' 2>/dev/null || true)"
}

@test "github/create: deduplicates by title on second call" {
  require_github
  local title="[bats-test] dedupe by title $(date +%s)"
  bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '$title'" >/dev/null
  run bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '$title' --dedupe-by title"
  assert_success
  assert_json_field 'deduped' 'true'
  local issue_id
  issue_id="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '$title' --dedupe-by title" | jq -r '.id' 2>/dev/null || true)"
  [[ -n "$issue_id" ]] && gh issue close "$issue_id" --repo "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1 || true
}
