#!/usr/bin/env bats

load '../helpers/common'

CREATE="$OWT_SCRIPTS/create.sh"

# Writes a preflight cache for the fake tracker so require_preflight passes.
_write_fake_cache() {
  mkdir -p "$WORKFLOW_ARTIFACTS_DIR"
  printf '{"tracker":"fake","base_url":"%s"}\n' "${FAKE_TRACKER_URL:-http://localhost:3000}" \
    > "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json"
}

setup() { setup_artifacts_dir; }
teardown() { teardown_artifacts_dir; }

# ── validation (no external services) ────────────────────────────────────────

@test "create: exits 1 when --type is missing" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --title 'T'"
  assert_failure
  assert_output_contains 'missing --type'
}

@test "create: exits 1 when --title is missing" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --type Bug"
  assert_failure
  assert_output_contains 'missing --title'
}

@test "create: exits 1 for an invalid --type value" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --type Widget --title 'T'"
  assert_failure
  assert_output_contains 'invalid --type'
}

@test "create: exits 1 for an invalid --dedupe-by value" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --type Bug --title 'T' --dedupe-by unknown"
  assert_failure
  assert_output_contains 'invalid --dedupe-by'
}

@test "create: exits 1 when description file path does not exist" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --type Bug --title 'T' --description-file /no/such/file"
  assert_failure
  assert_output_contains 'does not exist'
}

@test "create: exits 1 for unknown argument" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://x WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --bogus"
  assert_failure
}

# ── integration (requires fake tracker) ──────────────────────────────────────

@test "create: creates a Bug and returns contract JSON" {
  require_fake_tracker
  _write_fake_cache
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --type Bug --title 'Test bug from bats'"
  assert_success
  assert_json_field 'deduped' 'false'
  assert_output_contains '"url"'
}

@test "create: creates a Task and returns contract JSON" {
  require_fake_tracker
  _write_fake_cache
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --type Task --title 'Test task from bats'"
  assert_success
  assert_json_field 'deduped' 'false'
}

@test "create: creates a Test Case and returns contract JSON" {
  require_fake_tracker
  _write_fake_cache
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$CREATE' --type 'Test Case' --title 'TC from bats'"
  assert_success
  assert_json_field 'deduped' 'false'
}
