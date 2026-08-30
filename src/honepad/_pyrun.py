"""Child process: replay Python traces and print one JSON report line."""

from __future__ import annotations

import json
import os
import sys
import tempfile

from honepad.runner import run_python_body


def main(argv: list[str] | None = None) -> int:
    terminate = os._exit
    args = sys.argv[1:] if argv is None else argv
    problem, level_s, kind = args[0], args[1], args[2]
    orig_stdout = sys.stdout
    orig___stdout__ = sys.__stdout__
    orig_stdout.flush()
    saved_fd = os.dup(1)
    capture = tempfile.TemporaryFile()
    os.dup2(capture.fileno(), 1)
    sink = os.fdopen(os.dup(capture.fileno()), "w", encoding="utf-8")
    sys.stdout = sink
    sys.__stdout__ = sink
    report = None
    rc = 1
    captured = b""
    try:
        try:
            report = run_python_body(problem, int(level_s), kind)
            rc = 0 if report.ok else 1
        except KeyboardInterrupt:
            raise
        except BaseException as exc:
            sys.stderr.write(f"{exc}\n")
            rc = 1
    finally:
        try:
            sink.flush()
        except OSError:
            pass
        try:
            capture.flush()
            capture.seek(0)
            captured = capture.read()
        except OSError:
            captured = b""
        os.dup2(saved_fd, 1)
        os.close(saved_fd)
        sys.stdout = orig_stdout
        sys.__stdout__ = orig___stdout__
        try:
            sink.close()
        except OSError:
            pass
        capture.close()
    if captured and report is not None:
        text = captured.decode("utf-8", errors="replace")
        if not text.endswith("\n"):
            text += "\n"
        sys.stdout.write(text)
        sys.stdout.flush()
    if report is not None:
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
        sys.stdout.flush()
    terminate(rc)


if __name__ == "__main__":
    raise SystemExit(main())
