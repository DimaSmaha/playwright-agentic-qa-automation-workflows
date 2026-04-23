#!/usr/bin/env bats

load '../helpers/common'

PREFLIGHT="$OWT_SCRIPTS/preflight.sh"

setup() { setup_artifacts_dir; }
teardown() { teardown_artifacts_dir; }

@test "preflight: exits 1 when ISSUE_TRACKER is not set" {
  run bash -c "unset ISSUE_TRACKER; bash '$PREFLIGHT'"
  assert_failure
  assert_output_contains 'ISSUE_TRACKER'
}

@test "preflight: exits 1 for unknown ISSUE_TRACKER value" {
  run bash -c "ISSUE_TRACKER=trello bash '$PREFLIGHT'"
  assert_failure
  assert_output_contains '"error"'
}

@test "preflight: exits 1 for fake tracker when FAKE_TRACKER_URL is not set" {
  run bash -c "ISSUE_TRACKER=fake WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' unset FAKE_TRACKER_URL; bash '$PREFLIGHT'"
  assert_failure
}

@test "preflight: exits 1 for github tracker when GITHUB_TOKEN is not set" {
  run bash -c "ISSUE_TRACKER=github WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' unset GITHUB_TOKEN GH_TOKEN; bash '$PREFLIGHT'"
  assert_failure
}

@test "preflight: rejects unknown argument" {
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL=http://localhost:3000 WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT' --unknown"
  assert_failure
  assert_output_contains '"error"'
}

# ── requires fake tracker ─────────────────────────────────────────────────────

@test "preflight: succeeds with fake tracker and creates cache file" {
  require_fake_tracker
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT'"
  assert_success
  assert_json_field 'ok' 'true'
  [[ -f "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json" ]]
}

@test "preflight: cache contains tracker=fake" {
  require_fake_tracker
  run bash -c "ISSUE_TRACKER=fake FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR' bash '$PREFLIGHT'"
  assert_success
  assert_json_field 'tracker' 'fake'
}

@test "preflight: --force refreshes existing cache" {
  require_fake_tracker
  local env_vars="ISSUE_TRACKER=fake FAKE_TRACKER_URL='$FAKE_TRACKER_URL' WORKFLOW_ARTIFACTS_DIR='$WORKFLOW_ARTIFACTS_DIR'"
  bash -c "$env_vars bash '$PREFLIGHT'" >/dev/null
  local mtime_before
  mtime_before="$(date -r "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json" +%s 2>/dev/null || stat -c '%Y' "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json")"
  sleep 1
  run bash -c "$env_vars bash '$PREFLIGHT' --force"
  assert_success
  local mtime_after
  mtime_after="$(date -r "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json" +%s 2>/dev/null || stat -c '%Y' "$WORKFLOW_ARTIFACTS_DIR/.tracker-cache.json")"
  [[ "$mtime_after" -ge "$mtime_before" ]]
}
