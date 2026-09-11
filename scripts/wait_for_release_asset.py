#!/usr/bin/env python3
"""Poll a GitHub Release asset until it exists, then download it.

release.published fires when release-please creates the GitHub Release,
before Publish uploads the wheel or sdist. Homebrew and Scoop must wait.

--once does a single GET (tests and a probe). Default waits until the
deadline, polling every --interval-s.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def _log(msg: str) -> None:
    print(msg, flush=True)


def fetch_once(url: str, dest: Path, token: str = "") -> tuple[int, str]:
    headers = {"User-Agent": "honepad-wait-for-release-asset"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read()
            dest.write_bytes(body)
            digest = hashlib.sha256(body).hexdigest()
            return resp.status, digest
    except urllib.error.HTTPError as exc:
        return exc.code, ""
    except (urllib.error.URLError, TimeoutError, OSError):
        return 0, ""


def wait_for_asset(
    url: str,
    dest: Path,
    *,
    deadline_s: float,
    interval_s: float,
    token: str = "",
    once: bool = False,
) -> int:
    dest.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    _log(f"PLAN: fetch {url} into {dest}")
    attempt = 0
    while True:
        attempt += 1
        remaining = deadline_s - (time.monotonic() - start)
        _log(f"DO: GET attempt={attempt} remaining_s={remaining:.1f}")
        status, digest = fetch_once(url, dest, token=token)
        if status == 200 and digest:
            _log(f"OK: downloaded sha256={digest} bytes={dest.stat().st_size}")
            _log(f"DONE: ok=true sha256={digest}")
            return 0
        if once:
            _log(f"DONE: ok=false error=not_ready status={status}")
            return 2
        remaining = deadline_s - (time.monotonic() - start)
        if remaining <= 0:
            _log(f"FAIL: deadline status={status}")
            _log("DONE: ok=false error=deadline")
            return 1
        sleep_for = min(interval_s, max(0.05, remaining))
        _log(f"WAIT: status={status} sleep_s={sleep_for:.1f} remaining_s={remaining:.1f}")
        time.sleep(sleep_for)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--deadline-s", type=float, default=480)
    parser.add_argument("--interval-s", type=float, default=5)
    parser.add_argument("--token", default="")
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args(argv)
    return wait_for_asset(
        args.url,
        Path(args.output),
        deadline_s=args.deadline_s,
        interval_s=args.interval_s,
        token=args.token,
        once=args.once,
    )


if __name__ == "__main__":
    sys.exit(main())
