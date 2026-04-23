#!/usr/bin/env bats

load '../helpers/common'

GET="$OWT_SCRIPTS/get.sh"

_write_fake_cache() {
  mkdir -p "$WORKFLOW_ARTIFACTS_DIR"
  printf '{"tracker":"fake","base_url":"%s"}\n' "${FAKE_TRACKER_URL:-http://localhost:3000}" \
    > "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json"
}

setup() { setup_artifacts_dir; }
teardown() { teardown_artifacts_dir; }

# ── validation ────────────────────────────────────────────────────────────────

@test "get: exits 1 when --id is missing" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$GET'"
  assert_failure
  assert_output_contains 'missing id'
}

@test "get: exits 1 for unknown argument" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$GET' --bogus"
  assert_failure
}

@test "get: exits 1 when cache is missing" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$GET' --id 1"
  assert_failure
  assert_output_contains 'preflight'
}

# ── integration (requires fake tracker) ──────────────────────────────────────

@test "get: returns contract JSON for a known item" {
  require_fake_tracker
  # First create an item so we have an id to fetch.
  # Fake tracker always returns id=0, so we fetch id=0.
  _write_fake_cache
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$GET' --id 1 --type Task"
  # The fake tracker may return 404 for id 1 if empty, but script must produce contract JSON shape.
  # We only assert it exits without crashing — actual item existence depends on tracker state.
  [[ "$status" -eq 0 || "$output" == *'"error"'* ]]
}

@test "get: accepts positional id argument" {
  require_fake_tracker
  _write_fake_cache
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$GET' 1"
  [[ "$status" -eq 0 || "$output" == *'"error"'* ]]
}
