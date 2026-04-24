#!/usr/bin/env bash
# Generates a run_id, creates the artifact directory, and echoes the run_id.
set -euo pipefail
run_id="gt-$(date +%Y%m%d-%H%M%S)"
mkdir -p ".workflow-artifacts/${run_id}"
echo "$run_id"
