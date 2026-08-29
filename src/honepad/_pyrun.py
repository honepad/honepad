"""Child process: replay Python traces and print one JSON report line."""

from __future__ import annotations

import io
import json
import sys

from honepad.runner import run_python_body


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    problem, level_s, kind = args[0], args[1], args[2]
    real_stdout = sys.stdout
    sys.stdout = io.StringIO()
    try:
        try:
            report = run_python_body(problem, int(level_s), kind)
        except KeyboardInterrupt:
            raise
        except BaseException as exc:
            sys.stderr.write(f"{exc}\n")
            return 1
    finally:
        sys.stdout = real_stdout
    payload = {
        "passed": report.passed,
        "failed": [
            {
                "case": row.case,
                "index": row.index,
                "method": row.method,
                "args": row.args,
                "expected": row.expected,
                "actual": row.actual,
            }
            for row in report.failed
        ],
    }
    sys.stdout.write(json.dumps(payload) + "\n")
    return 0 if report.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
