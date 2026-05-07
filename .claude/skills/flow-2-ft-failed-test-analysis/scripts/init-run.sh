#!/usr/bin/env bash
set -euo pipefail
run_id="ft-$(date +%Y%m%d-%H%M%S)"
mkdir -p ".workflow-artifacts/${run_id}"
echo "$run_id"
