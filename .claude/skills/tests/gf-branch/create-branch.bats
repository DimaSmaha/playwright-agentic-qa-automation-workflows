#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/mock-git'

CREATE_BRANCH="$GF_BRANCH_SCRIPTS/create-branch.sh"

setup() { setup_git_repo; }
teardown() { teardown_git_repo; }

@test "create-branch: exits 1 when --work-item-id is missing" {
  run bash -C "$GIT_REPO_DIR" "$CREATE_BRANCH"
  assert_failure
  assert_output_contains 'missing --work-item-id'
}

@test "create-branch: creates branch task/<id> when no title given" {
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_BRANCH' --work-item-id 99"
  assert_success
  assert_json_field 'branch' 'task/99'
  git -C "$GIT_REPO_DIR" show-ref --verify --quiet refs/heads/task/99
}

@test "create-branch: creates branch task/<id>-<slug> when title is given" {
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_BRANCH' --work-item-id 42 --title 'Fix order filter'"
  assert_success
  assert_json_field 'branch' 'task/42-fix-order-filter'
}

@test "create-branch: JSON output contains base and work_item_id" {
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_BRANCH' --work-item-id 7"
  assert_success
  assert_json_field 'work_item_id' '7'
  assert_output_contains '"base"'
  assert_output_contains '"base_sha"'
}

@test "create-branch: exits 1 when branch already exists locally" {
  bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_BRANCH' --work-item-id 10" >/dev/null
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_BRANCH' --work-item-id 10"
  assert_failure
  assert_output_contains 'branch already exists'
}

@test "create-branch: truncates branch name to 60 characters" {
  local long_title="this is a very long title that should cause the branch name to be truncated at sixty chars"
  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_BRANCH' --work-item-id 1 --title '$long_title'"
  assert_success
  local branch
  branch="$(printf '%s' "$output" | jq -r '.branch' 2>/dev/null || true)"
  [[ "${#branch}" -le 60 ]]
}

@test "create-branch: respects custom --base branch" {
  git -C "$GIT_REPO_DIR" checkout -b custom-base -q
  echo "extra" >> "$GIT_REPO_DIR/init.txt"
  git -C "$GIT_REPO_DIR" add init.txt
  git -C "$GIT_REPO_DIR" commit -m "extra" -q
  git -C "$GIT_REPO_DIR" push origin custom-base -q
  git -C "$GIT_REPO_DIR" checkout main -q

  run bash -c "cd '$GIT_REPO_DIR' && bash '$CREATE_BRANCH' --work-item-id 55 --base custom-base"
  assert_success
  assert_json_field 'base' 'custom-base'
}
