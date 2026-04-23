#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/mock-git'

PUSH_BRANCH="$GF_PUSH_SCRIPTS/push-branch.sh"

setup() {
  setup_git_repo
  git -C "$GIT_REPO_DIR" checkout -b feature/push-test -q
  printf 'change\n' > "$GIT_REPO_DIR/change.txt"
  git -C "$GIT_REPO_DIR" add change.txt
  git -C "$GIT_REPO_DIR" commit -m "test commit" -q
}

teardown() { teardown_git_repo; }

@test "push-branch: exits 1 when not in a git repo" {
  local tmp
  tmp="$(mktemp -d)"
  run bash -c "cd '$tmp' && bash '$PUSH_BRANCH'"
  rm -rf "$tmp"
  assert_failure
  assert_output_contains '"error"'
}

@test "push-branch: exits 1 when on main branch" {
  git -C "$GIT_REPO_DIR" checkout main -q
  run bash -c "cd '$GIT_REPO_DIR' && bash '$PUSH_BRANCH'"
  assert_failure
  assert_output_contains 'refusing to push'
}

@test "push-branch: exits 1 when on master branch" {
  git -C "$GIT_REPO_DIR" checkout -b master -q 2>/dev/null || true
  run bash -c "cd '$GIT_REPO_DIR' && bash '$PUSH_BRANCH'"
  assert_failure
  assert_output_contains 'refusing to push'
}

@test "push-branch: successfully pushes a feature branch" {
  run bash -c "cd '$GIT_REPO_DIR' && bash '$PUSH_BRANCH'"
  assert_success
  assert_json_field 'branch' 'feature/push-test'
  assert_json_field 'remote' 'origin'
  assert_json_field 'set_upstream' 'true'
  assert_output_contains '"pushed_sha"'
}

@test "push-branch: set_upstream is false when upstream already set" {
  bash -c "cd '$GIT_REPO_DIR' && bash '$PUSH_BRANCH'" >/dev/null
  run bash -c "cd '$GIT_REPO_DIR' && bash '$PUSH_BRANCH'"
  assert_success
  assert_json_field 'set_upstream' 'false'
}

@test "push-branch: --remote flag is accepted" {
  run bash -c "cd '$GIT_REPO_DIR' && bash '$PUSH_BRANCH' --remote origin"
  assert_success
  assert_json_field 'remote' 'origin'
}
