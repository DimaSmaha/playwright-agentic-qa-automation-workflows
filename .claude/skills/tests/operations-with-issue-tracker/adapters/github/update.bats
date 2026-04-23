#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/github/create.sh"
UPDATE_ADAPTER="$OWT_SCRIPTS/adapters/github/update.sh"

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

@test "github/update: exits 1 when --id is missing" {
  require_github
  run bash -c "$(_env) bash '$UPDATE_ADAPTER' --severity high"
  assert_failure
  assert_output_contains 'missing --id'
}

@test "github/update: applies severity and priority labels" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Bug --title '[bats-test] update adapter test'")";
  CREATED_ISSUE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_ISSUE_ID" ]] && skip "could not create test issue"

  run bash -c "$(_env) bash '$UPDATE_ADAPTER' --id '$CREATED_ISSUE_ID' --severity high --priority p1"
  assert_success
  assert_output_contains '"id"'
  assert_output_contains '"updated"'
  assert_output_contains 'high'
  assert_output_contains 'p1'
}

@test "github/update: applies a custom tag label" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] update tag test'")";
  CREATED_ISSUE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_ISSUE_ID" ]] && skip "could not create test issue"

  run bash -c "$(_env) bash '$UPDATE_ADAPTER' --id '$CREATED_ISSUE_ID' --tag bats-run"
  assert_success
  assert_output_contains 'bats-run'
}
