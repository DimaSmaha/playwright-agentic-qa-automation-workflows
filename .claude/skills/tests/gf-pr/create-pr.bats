#!/usr/bin/env bats

load '../helpers/common'
load '../helpers/mock-git'

CREATE_PR="$GF_PR_SCRIPTS/create-pr.sh"

setup() {
  setup_git_repo
  git -C "$GIT_REPO_DIR" checkout -b feature/pr-test -q
  printf 'change\n' > "$GIT_REPO_DIR/change.txt"
  git -C "$GIT_REPO_DIR" add change.txt
  git -C "$GIT_REPO_DIR" commit -m "feat: test change" -q
  git -C "$GIT_REPO_DIR" push origin feature/pr-test -q
}

teardown() { teardown_git_repo; }

@test "create-pr: exits 1 when PR_HOST is not set" {
  run bash -c "cd '$GIT_REPO_DIR' && REPO_OWNER=o REPO_NAME=r bash '$CREATE_PR'"
  assert_failure
  assert_output_contains 'PR_HOST'
}

@test "create-pr: exits 1 for an invalid PR_HOST value" {
  run bash -c "cd '$GIT_REPO_DIR' && PR_HOST=bitbucket REPO_OWNER=o REPO_NAME=r bash '$CREATE_PR'"
  assert_failure
  assert_output_contains 'PR_HOST must be'
}

@test "create-pr: exits 1 when REPO_OWNER is not set" {
  run bash -c "cd '$GIT_REPO_DIR' && PR_HOST=github REPO_NAME=r bash '$CREATE_PR'"
  assert_failure
  assert_output_contains 'REPO_OWNER'
}

@test "create-pr: exits 1 when REPO_NAME is not set" {
  run bash -c "cd '$GIT_REPO_DIR' && PR_HOST=github REPO_OWNER=o bash '$CREATE_PR'"
  assert_failure
  assert_output_contains 'REPO_NAME'
}

@test "create-pr: exits 1 for an unknown argument" {
  run bash -c "cd '$GIT_REPO_DIR' && PR_HOST=github REPO_OWNER=o REPO_NAME=r bash '$CREATE_PR' --bogus"
  assert_failure
}

# ── integration (requires GitHub credentials) ─────────────────────────────────

@test "create-pr: creates a real GitHub PR and returns contract JSON" {
  require_github
  # Make a unique branch for this PR so there is no existing PR
  local branch="bats-pr-test-$(date +%s)"
  git -C "$GIT_REPO_DIR" checkout -b "$branch" -q
  printf 'pr content\n' > "$GIT_REPO_DIR/pr.txt"
  git -C "$GIT_REPO_DIR" add pr.txt
  git -C "$GIT_REPO_DIR" commit -m "feat: pr smoke test" -q
  git -C "$GIT_REPO_DIR" push origin "$branch" -q

  run bash -c "cd '$GIT_REPO_DIR' && PR_HOST=github REPO_OWNER='$REPO_OWNER' REPO_NAME='$REPO_NAME' GITHUB_TOKEN='${GITHUB_TOKEN:-${GH_TOKEN:-}}' bash '$CREATE_PR' --title '[bats-test] PR smoke test' --base main"
  # Clean up the PR and branch regardless
  local pr_id
  pr_id="$(printf '%s' "$output" | jq -r '.id // empty' 2>/dev/null || true)"
  if [[ -n "$pr_id" ]]; then
    gh pr close "$pr_id" --repo "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1 || true
  fi
  gh api -X DELETE "repos/$REPO_OWNER/$REPO_NAME/git/refs/heads/$branch" >/dev/null 2>&1 || true

  assert_success
  assert_output_contains '"url"'
  assert_output_contains '"title"'
}
