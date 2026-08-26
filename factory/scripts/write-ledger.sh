#!/usr/bin/env bash
# Day-1 ledger helper. --self-test only checks STATE.json parses.
set -euo pipefail

echo "PLAN: ledger helper"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" ]]; then
  echo "FAIL: not a git checkout"
  echo "DONE: ok=false error=no-git"
  exit 1
fi

if [[ "${1:-}" == "--self-test" ]]; then
  echo "DO: parse factory/STATE.json"
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$ROOT/factory/STATE.json"
  echo "OK: STATE parses"
  echo "DONE: ok=true"
  exit 0
fi

echo "FAIL: only --self-test is implemented"
echo "DONE: ok=false error=usage"
exit 1
