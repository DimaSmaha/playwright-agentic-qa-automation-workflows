#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../_common.sh"

VERB="${1:-unknown}"
emit_error "ado adapter verb is not implemented yet" "tracker" "ado" "verb" "$VERB"

