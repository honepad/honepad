from __future__ import annotations

import importlib.util
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]


def _load():
    path = HERE / "scripts" / "wait_for_release_asset.py"
    spec = importlib.util.spec_from_file_location("wait_for_release_asset", path)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


wait = _load()


class _Handler(BaseHTTPRequestHandler):
    hits = 0
    payload = b"honepad-sdist"

    def do_GET(self) -> None:  # noqa: N802
        type(self).hits += 1
        if self.path != "/honepad-0.1.1.tar.gz" or type(self).hits < 2:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Length", str(len(self.payload)))
        self.end_headers()
        self.wfile.write(self.payload)

    def log_message(self, format: str, *args: object) -> None:  # noqa: A003
        return


def _serve() -> HTTPServer:
    server = HTTPServer(("127.0.0.1", 0), _Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


def test_once_not_ready_exits_2(tmp_path: Path) -> None:
    _Handler.hits = 0
    server = _serve()
    try:
        host, port = server.server_address
        dest = tmp_path / "sdist.tar.gz"
        code = wait.wait_for_asset(
            f"http://{host}:{port}/honepad-0.1.1.tar.gz",
            dest,
            deadline_s=5,
            interval_s=0.1,
            once=True,
        )
        assert code == 2
        assert not dest.exists()
    finally:
        server.shutdown()


def test_wait_retries_until_asset_exists(tmp_path: Path) -> None:
    _Handler.hits = 0
    server = _serve()
    try:
        host, port = server.server_address
        dest = tmp_path / "sdist.tar.gz"
        code = wait.wait_for_asset(
            f"http://{host}:{port}/honepad-0.1.1.tar.gz",
            dest,
            deadline_s=5,
            interval_s=0.05,
        )
        assert code == 0
        assert dest.read_bytes() == b"honepad-sdist"
        assert _Handler.hits >= 2
    finally:
        server.shutdown()


def test_deadline_exits_1(tmp_path: Path) -> None:
    class Always404(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            self.send_error(404)

        def log_message(self, format: str, *args: object) -> None:  # noqa: A003
            return

    server = HTTPServer(("127.0.0.1", 0), Always404)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        host, port = server.server_address
        dest = tmp_path / "missing.tar.gz"
        code = wait.wait_for_asset(
            f"http://{host}:{port}/missing.tar.gz",
            dest,
            deadline_s=0.2,
            interval_s=0.05,
        )
        assert code == 1
    finally:
        server.shutdown()
