#!/usr/bin/env bats

load '../helpers/common'

COMMON_SH="$OWT_SCRIPTS/_common.sh"

# ── json_escape ───────────────────────────────────────────────────────────────

@test "json_escape: escapes double quotes" {
  run bash -c "source '$COMMON_SH'; json_escape 'say \"hello\"'"
  assert_success
  [[ "$output" == 'say \"hello\"' ]]
}

@test "json_escape: escapes backslashes" {
  run bash -c "source '$COMMON_SH'; json_escape 'a\\b'"
  assert_success
  [[ "$output" == 'a\\b' ]]
}

@test "json_escape: escapes newlines" {
  run bash -c $'source \''"$COMMON_SH"$'\'; json_escape $\'line1\\nline2\''
  assert_success
  assert_output_contains '\n'
}

@test "json_escape: leaves plain text unchanged" {
  run bash -c "source '$COMMON_SH'; json_escape 'hello world 123'"
  assert_success
  [[ "$output" == 'hello world 123' ]]
}

# ── emit_error ────────────────────────────────────────────────────────────────

@test "emit_error: exits with code 1" {
  run bash -c "source '$COMMON_SH'; emit_error 'something went wrong'"
  assert_failure
}

@test "emit_error: outputs error JSON" {
  run bash -c "source '$COMMON_SH'; emit_error 'something went wrong'"
  assert_output_contains '"error"'
  assert_output_contains 'something went wrong'
}

@test "emit_error: includes extra key-value pairs" {
  run bash -c "source '$COMMON_SH'; emit_error 'bad input' 'field' 'name'"
  assert_failure
  assert_output_contains '"field"'
  assert_output_contains '"name"'
}

# ── emit_ok ───────────────────────────────────────────────────────────────────

@test "emit_ok: exits with code 0" {
  run bash -c "source '$COMMON_SH'; emit_ok"
  assert_success
}

@test "emit_ok: outputs ok:true JSON" {
  run bash -c "source '$COMMON_SH'; emit_ok"
  assert_output_contains '"ok":true'
}

@test "emit_ok: includes extra key-value pairs" {
  run bash -c "source '$COMMON_SH'; emit_ok 'tracker' 'fake'"
  assert_success
  assert_output_contains '"tracker"'
  assert_output_contains '"fake"'
}

# ── slug ──────────────────────────────────────────────────────────────────────

@test "slug: lowercases and replaces spaces with dashes" {
  run bash -c "source '$COMMON_SH'; slug 'Hello World'"
  assert_success
  [[ "$output" == 'hello-world' ]]
}

@test "slug: collapses multiple separators into one dash" {
  run bash -c "source '$COMMON_SH'; slug 'foo--bar  baz'"
  assert_success
  [[ "$output" == 'foo-bar-baz' ]]
}

@test "slug: strips leading and trailing dashes" {
  run bash -c "source '$COMMON_SH'; slug ' Hello World '"
  assert_success
  [[ "$output" == 'hello-world' ]]
}

@test "slug: handles numbers" {
  run bash -c "source '$COMMON_SH'; slug 'Fix issue 42'"
  assert_success
  [[ "$output" == 'fix-issue-42' ]]
}

# ── sha1_prefix ───────────────────────────────────────────────────────────────

@test "sha1_prefix: returns 12-character hex string by default" {
  run bash -c "source '$COMMON_SH'; sha1_prefix 'some input'"
  assert_success
  [[ "${#output}" -eq 12 ]]
  [[ "$output" =~ ^[0-9a-f]+$ ]]
}

@test "sha1_prefix: same input produces same hash" {
  run bash -c "source '$COMMON_SH'; sha1_prefix 'stable input'"
  local first="$output"
  run bash -c "source '$COMMON_SH'; sha1_prefix 'stable input'"
  [[ "$output" == "$first" ]]
}

@test "sha1_prefix: honours custom length argument" {
  run bash -c "source '$COMMON_SH'; sha1_prefix 'input' 8"
  assert_success
  [[ "${#output}" -eq 8 ]]
}

# ── is_valid_json ─────────────────────────────────────────────────────────────

@test "is_valid_json: returns 0 for a valid JSON object" {
  run bash -c "source '$COMMON_SH'; is_valid_json '{\"ok\":true}'"
  assert_success
}

@test "is_valid_json: returns 0 for a valid JSON array" {
  run bash -c "source '$COMMON_SH'; is_valid_json '[1,2,3]'"
  assert_success
}

@test "is_valid_json: returns non-zero for plain text" {
  run bash -c "source '$COMMON_SH'; is_valid_json 'not json'"
  assert_failure
}

# ── require_cmd ───────────────────────────────────────────────────────────────

@test "require_cmd: succeeds when command exists" {
  run bash -c "source '$COMMON_SH'; require_cmd bash"
  assert_success
}

@test "require_cmd: exits 1 when command is missing" {
  run bash -c "source '$COMMON_SH'; require_cmd __cmd_that_does_not_exist__"
  assert_failure
  assert_output_contains '"error"'
}

# ── tracker_from_env ──────────────────────────────────────────────────────────

@test "tracker_from_env: returns tracker name when valid" {
  run bash -c "source '$COMMON_SH'; ISSUE_TRACKER=fake tracker_from_env"
  assert_success
  [[ "$output" == 'fake' ]]
}

@test "tracker_from_env: exits 1 when ISSUE_TRACKER is missing" {
  run bash -c "source '$COMMON_SH'; unset ISSUE_TRACKER; tracker_from_env"
  assert_failure
  assert_output_contains 'ISSUE_TRACKER is required'
}

@test "tracker_from_env: exits 1 for an unknown tracker name" {
  run bash -c "source '$COMMON_SH'; ISSUE_TRACKER=trello tracker_from_env"
  assert_failure
  assert_output_contains '"error"'
}

# ── require_auth ──────────────────────────────────────────────────────────────

@test "require_auth: exits 1 for fake tracker when FAKE_TRACKER_URL is missing" {
  run bash -c "source '$COMMON_SH'; unset FAKE_TRACKER_URL; require_auth fake"
  assert_failure
  assert_output_contains 'FAKE_TRACKER_URL'
}

@test "require_auth: succeeds for fake tracker when FAKE_TRACKER_URL is set" {
  run bash -c "source '$COMMON_SH'; FAKE_TRACKER_URL=http://localhost:3000 require_auth fake"
  assert_success
}

@test "require_auth: exits 1 for github tracker when token is missing" {
  run bash -c "source '$COMMON_SH'; unset GITHUB_TOKEN GH_TOKEN; require_auth github"
  assert_failure
  assert_output_contains 'GITHUB_TOKEN'
}
