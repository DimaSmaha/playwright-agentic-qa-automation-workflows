#!/usr/bin/env bash
# Helpers for setting up real temporary git repos in tests.

# Creates a bare remote + a clone with origin pointing to it.
# Sets GIT_REPO_DIR (the clone working copy) and GIT_BARE_DIR (bare remote).
# Tests must cd into GIT_REPO_DIR or pass -C "$GIT_REPO_DIR" to git commands.
setup_git_repo() {
  GIT_BARE_DIR="$(mktemp -d)"
  GIT_REPO_DIR="$(mktemp -d)"
  export GIT_BARE_DIR GIT_REPO_DIR

  git init --bare "$GIT_BARE_DIR" -q

  git -C "$GIT_REPO_DIR" init -q
  git -C "$GIT_REPO_DIR" config user.email "test@test.com"
  git -C "$GIT_REPO_DIR" config user.name "Test"
  git -C "$GIT_REPO_DIR" remote add origin "$GIT_BARE_DIR"

  echo "init" > "$GIT_REPO_DIR/init.txt"
  git -C "$GIT_REPO_DIR" add init.txt
  git -C "$GIT_REPO_DIR" commit -m "init" -q
  git -C "$GIT_REPO_DIR" branch -M main
  git -C "$GIT_REPO_DIR" push -u origin main -q
}

teardown_git_repo() {
  rm -rf "${GIT_BARE_DIR:-}" "${GIT_REPO_DIR:-}"
  unset GIT_BARE_DIR GIT_REPO_DIR
}

# Stage a new file in GIT_REPO_DIR
stage_file() {
  local filename="$1"
  local content="${2:-test content}"
  printf '%s\n' "$content" > "$GIT_REPO_DIR/$filename"
  git -C "$GIT_REPO_DIR" add "$filename"
}
