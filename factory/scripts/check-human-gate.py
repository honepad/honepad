#!/usr/bin/env python3
"""Map next-job.sh through factory/STATE.json human_gate.

Exit codes:
- human_gate set: exit 0 iff next-job.sh returns 2
- human_gate unset: exit 0 iff next-job.sh returns 0
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / "factory" / "STATE.json"
NEXT_JOB = ROOT / "factory" / "scripts" / "next-job.sh"


def _log(line: str) -> None:
    print(line, flush=True)


def mapped_exit(human_gate: object, next_job_rc: int) -> int:
    if human_gate:
        return 0 if next_job_rc == 2 else 1
    return 0 if next_job_rc == 0 else 1


def self_test() -> int:
    _log("PLAN: self-test human_gate exit mapping")
    cases: tuple[tuple[object, int, int], ...] = (
        ({"kind": "parked"}, 2, 0),
        ({"kind": "parked"}, 0, 1),
        (None, 0, 0),
        (None, 2, 1),
    )
    for gate, rc, want in cases:
        got = mapped_exit(gate, rc)
        if got != want:
            _log(f"FAIL: mapped_exit({gate!r}, {rc})={got} want={want}")
            _log("DONE: ok=false error=self-test")
            return 1
        _log(f"OK: mapped_exit gate={bool(gate)} rc={rc} -> {got}")
    _log("DONE: ok=true")
    return 0


def check() -> int:
    _log("PLAN: map next-job.sh through human_gate")
    _log(f"DO: read {STATE}")
    if not STATE.is_file():
        _log(f"FAIL: STATE missing at {STATE}")
        _log("DONE: ok=false error=no-state")
        return 1
    state = json.loads(STATE.read_text(encoding="utf-8"))
    gate = state.get("human_gate")
    _log(f"OK: human_gate={'set' if gate else 'unset'}")
    _log("DO: run factory/scripts/next-job.sh")
    result = subprocess.run(["bash", str(NEXT_JOB)], cwd=ROOT, check=False)
    code = mapped_exit(gate, result.returncode)
    if code == 0:
        _log(f"OK: next-job rc={result.returncode} mapped={code}")
        _log("DONE: ok=true")
    else:
        _log(f"FAIL: next-job rc={result.returncode} mapped={code}")
        _log("DONE: ok=false error=human_gate_map")
    return code


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    return check()


if __name__ == "__main__":
    raise SystemExit(main())
