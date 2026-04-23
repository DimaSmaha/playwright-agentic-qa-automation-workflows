#!/usr/bin/env bats

load '../../../../helpers/common'

QUERY_ADAPTER="$OWT_SCRIPTS/adapters/github/query.sh"

setup() { setup_artifacts_dir; }
teardown() { teardown_artifacts_dir; }

_env() {
  printf 'REPO_OWNER=%s REPO_NAME=%s WORKFLOW_ARTIFACTS_DIR=%s' \
    "'$REPO_OWNER'" "'$REPO_NAME'" "'$WORKFLOW_ARTIFACTS_DIR'"
}

@test "github/query: exits 1 when --limit is non-numeric" {
  require_github
  run bash -c "$(_env) bash '$QUERY_ADAPTER' --limit abc"
  assert_failure
  assert_output_contains 'must be numeric'
}

@test "github/query: returns results array and count" {
  require_github
  run bash -c "$(_env) bash '$QUERY_ADAPTER' --query 'is:issue' --limit 5"
  assert_success
  assert_output_contains '"results"'
  assert_output_contains '"count"'
}

@test "github/query: default query works without arguments" {
  require_github
  run bash -c "$(_env) bash '$QUERY_ADAPTER'"
  assert_success
  assert_output_contains '"results"'
}

@test "github/query: count matches results array length" {
  require_github
  run bash -c "$(_env) bash '$QUERY_ADAPTER' --limit 3"
  assert_success
  local count results_len
  count="$(printf '%s' "$output" | jq -r '.count' 2>/dev/null || echo -1)"
  results_len="$(printf '%s' "$output" | jq -r '.results | length' 2>/dev/null || echo -1)"
  [[ "$count" == "$results_len" ]]
}
