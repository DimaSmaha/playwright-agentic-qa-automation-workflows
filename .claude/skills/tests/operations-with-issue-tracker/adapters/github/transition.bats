#!/usr/bin/env bats

load '../../../../helpers/common'

CREATE_ADAPTER="$OWT_SCRIPTS/adapters/github/create.sh"
TRANSITION_ADAPTER="$OWT_SCRIPTS/adapters/github/transition.sh"

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

@test "github/transition: exits 1 when --id is missing" {
  require_github
  run bash -c "$(_env) bash '$TRANSITION_ADAPTER' --to closed"
  assert_failure
  assert_output_contains 'missing --id'
}

@test "github/transition: exits 1 when --to is missing" {
  require_github
  run bash -c "$(_env) bash '$TRANSITION_ADAPTER' --id 1"
  assert_failure
  assert_output_contains 'missing --to'
}

@test "github/transition: closes an open issue and reports changed:true" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] transition test'")";
  CREATED_ISSUE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_ISSUE_ID" ]] && skip "could not create test issue"

  run bash -c "$(_env) bash '$TRANSITION_ADAPTER' --id '$CREATED_ISSUE_ID' --to closed"
  assert_success
  assert_json_field 'changed' 'true'
  assert_json_field 'to' 'closed'
}

@test "github/transition: reports changed:false when state already matches" {
  require_github
  local create_out
  create_out="$(bash -c "$(_env) bash '$CREATE_ADAPTER' --type Task --title '[bats-test] no-op transition'")";
  CREATED_ISSUE_ID="$(printf '%s' "$create_out" | jq -r '.id' 2>/dev/null || true)"
  [[ -z "$CREATED_ISSUE_ID" ]] && skip "could not create test issue"

  run bash -c "$(_env) bash '$TRANSITION_ADAPTER' --id '$CREATED_ISSUE_ID' --to open"
  assert_success
  assert_json_field 'changed' 'false'
}
