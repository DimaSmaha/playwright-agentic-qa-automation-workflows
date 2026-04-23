#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v bats >/dev/null 2>&1; then
  echo "ERROR: bats not found. Install with:"
  echo "  git clone https://github.com/bats-core/bats-core.git /tmp/bats-core"
  echo "  bash /tmp/bats-core/install.sh /usr/local"
  exit 1
fi

FILTER="${1:-}"

if [[ -n "$FILTER" ]]; then
  mapfile -t files < <(find "$SCRIPT_DIR" -name '*.bats' | grep "$FILTER" | sort)
else
  mapfile -t files < <(find "$SCRIPT_DIR" -name '*.bats' | sort)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No .bats files found${FILTER:+ matching '$FILTER'}"
  exit 0
fi

echo "Running ${#files[@]} test suite(s)..."
bats --tap "${files[@]}"
