#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

PARENT_DIR="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
source "${PARENT_DIR}/_common.sh"

ID=""
TYPE="Task"

while [[ $# -gt 0 ]]; do
  case $1 in
    --id)   ID="${2-}";   shift 2 ;;
    --type) TYPE="${2-}"; shift 2 ;;
    *) emit_error "unknown argument: $1" ;;
  esac
done

[[ -z "$ID" ]] && emit_error "missing --id"

PATH_SEGMENT="$(fake_type_to_path "$TYPE")"
URL="${FAKE_TRACKER_URL}/${PATH_SEGMENT}/${ID}"

raw="$(curl_with_retry GET "$URL")"

# Normalize to the standard get.sh contract shape.
# Fake tracker returns varying shapes; we extract what we can.
title="$(printf '%s' "$raw" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('title',''))" 2>/dev/null || true)"
description="$(printf '%s' "$raw" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('description',''))" 2>/dev/null || true)"

if [[ -z "$title" ]]; then
  title="item-${ID}"
fi

escaped_title="$(json_escape "$title")"
escaped_desc="$(json_escape "$description")"
escaped_url="$(json_escape "$URL")"
escaped_type="$(json_escape "$TYPE")"

printf '{"id":%s,"type":"%s","title":"%s","description":"%s","acl":[],"parent_id":null,"url":"%s","steps_xml":"","image_urls":[]}\n' \
  "$ID" "$escaped_type" "$escaped_title" "$escaped_desc" "$escaped_url"
