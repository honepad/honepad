#!/usr/bin/env bash
# Read factory STATE and print one JSON job. Under 10s.
set -euo pipefail

echo "PLAN: pick next factory job"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" ]]; then
  echo "FAIL: not a git checkout"
  echo "DONE: ok=false error=no-git"
  exit 1
fi

STATE="$ROOT/factory/STATE.json"
if [[ ! -f "$STATE" ]]; then
  echo "FAIL: STATE missing at $STATE"
  echo "DONE: ok=false error=no-state"
  exit 1
fi

echo "DO: read $STATE"
python3 - "$STATE" <<'PY'
import json, sys
from datetime import datetime, timezone

state = json.load(open(sys.argv[1]))
now = datetime.now(timezone.utc)
gate = state.get("human_gate")
if gate:
    print(f"WAIT: human_gate kind={gate.get('kind')} {gate.get('message')}", flush=True)
    print("DONE: ok=false error=human_gate")
    print(f"NEXT: human-gate:{gate.get('kind')}")
    sys.exit(2)

src = state.get("next_work_source") or "bootstrap"
cursor = state.get("pr_plan_cursor") or "pr-2"
job = {
    "job_id": f"{src}-{cursor}",
    "work_source": src,
    "pr_plan_cursor": cursor,
    "stealth_mode": state.get("stealth_mode", True),
}
print("OK: picked " + src, flush=True)
print(json.dumps(job), flush=True)
print("DONE: ok=true source=" + src)
print("NEXT: spawn one child for this job")
PY
