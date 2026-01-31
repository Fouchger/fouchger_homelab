#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: lib/yaml.sh
# Created: 2026-01-31
# Updated: 2026-01-31
# Description: Minimal YAML query helpers using python3 + PyYAML.
# Purpose: Avoid hard dependency on yq during early bootstrap and headless runs.
# Usage:
#   source "${ROOT_DIR}/lib/yaml.sh"
#   yaml_get "config/apps.yml" "apps.curl.name"
#   yaml_list "config/apps.yml" "apps"           # prints keys (curl, jq, ...)
# Notes:
#   - Keep queries simple: dot-separated path.
#   - For mapping nodes, yaml_list prints keys.
#   - For list nodes, yaml_list prints items.
# -----------------------------------------------------------------------------

set -o errexit
set -o nounset
set -o pipefail

# shellcheck shell=bash

yaml__py() {
  python3 - "$@" <<'PY'
import sys, yaml

path = sys.argv[1]
mode = sys.argv[2]
query = sys.argv[3]

with open(path, 'r', encoding='utf-8') as f:
    data = yaml.safe_load(f)

node = data
if query:
    for part in query.split('.'):
        if part == '':
            continue
        if isinstance(node, dict):
            node = node.get(part)
        else:
            node = None
        if node is None:
            break

def out(s: str):
    sys.stdout.write(s)

if mode == 'get':
    if node is None:
        sys.exit(1)
    if isinstance(node, (dict, list)):
        # Emit YAML for complex nodes
        out(yaml.safe_dump(node, default_flow_style=False).rstrip())
    else:
        out(str(node))
elif mode == 'list':
    if node is None:
        sys.exit(1)
    if isinstance(node, dict):
        for k in node.keys():
            out(f"{k}\n")
    elif isinstance(node, list):
        for item in node:
            out(f"{item}\n")
    else:
        out(f"{node}\n")
else:
    sys.exit(2)
PY
}

yaml_get() {
  local file query
  file="$1"; query="${2:-}"
  yaml__py "$file" get "$query"
}

yaml_list() {
  local file query
  file="$1"; query="${2:-}"
  yaml__py "$file" list "$query"
}
