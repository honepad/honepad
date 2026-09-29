"""Play one desk from the first start through DONE.

The child is ``python -m honepad`` with a piped console, the same commands
a person types. ``code`` on ``PATH`` is a shim that records its argv and
exits. That is the launch ``open_vscode`` performs (``which``, then
``--new-window``). A GUI is not opened: it is headless-hostile and the
product does not wait on the editor.

``slice_stub`` drops helper classes such as ``Account``. The fixture keeps
those and removes later public methods, so an unlock still has a method to
merge and the next run fails until that method is filled in.
"""

from __future__ import annotations

import ast
import json
import os
import shutil
import subprocess
import sys
import threading
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import pytest

from honepad.catalog import language, repo_root
from honepad.workstub import (
    _java_method,
    _java_method_order,
    class_name_for,
    methods_through_level,
    naming_for,
)

PROBLEM = "bank_system"
REPO = Path(__file__).resolve().parents[1]
PROMPT = "  > "


def _api(lang: str, level: int) -> set[str]:
    return methods_through_level(PROBLEM, level, naming_for(lang))


def _introduced(lang: str, level: int) -> set[str]:
    previous = _api(lang, level - 1) if level > 1 else set()
    return _api(lang, level) - previous


def _declared(text: str, lang: str, name: str) -> bool:
    if lang == "python3":
        return f"def {name}(" in text
    return f"{name}(" in text


def _strip_python(text: str, allowed: set[str]) -> str:
    tree = ast.parse(text)
    for node in tree.body:
        if not isinstance(node, ast.ClassDef) or node.name != "Simulation":
            continue
        kept = []
        for item in node.body:
            if isinstance(item, ast.FunctionDef) and not item.name.startswith("_"):
                if item.name not in allowed:
                    continue
            kept.append(item)
        if not kept:
            raise AssertionError("Simulation lost every method")
        node.body = kept
    return ast.unparse(tree) + "\n"


def _strip_java(text: str, allowed: set[str], class_name: str) -> str:
    # ``public class`` is followed by ``new LinkedHashMap<>()``, so the order
    # walk also yields that token. Only real method names are removed.
    for name in _java_method_order(text):
        if not name.isidentifier() or name == class_name or name in allowed:
            continue
        block = _java_method(text, name)
        if not block or block not in text:
            raise AssertionError(f"could not remove {name}")
        text = text.replace(block, "", 1)
    return text


def solution_through(lang: str, level: int) -> str:
    """Official solution limited to the public methods unlocked at ``level``."""
    ext = str(language(lang)["ext"])
    path = repo_root() / "langs" / lang / "problems" / PROBLEM / f"solution.{ext}"
    text = path.read_text(encoding="utf-8")
    allowed = _api(lang, level)
    if ext == "py":
        return _strip_python(text, allowed)
    if ext == "java":
        return _strip_java(text, allowed, class_name_for(PROBLEM))
    raise AssertionError(ext)


def _break_create(lang: str, text: str) -> str:
    """Same methods, but creating an account reports failure."""
    if lang == "python3":
        tree = ast.parse(text)
        found = False
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name == "create_account":
                node.body = [ast.Return(value=ast.Constant(value=False))]
                found = True
                break
        if not found:
            raise AssertionError("create_account missing")
        return ast.unparse(tree) + "\n"
    sig = "public boolean createAccount(int timestamp, String accountId)"
    start = text.find(sig)
    if start < 0:
        raise AssertionError("createAccount missing")
    nxt = text.find("\n    public ", start + len(sig))
    end = len(text) if nxt < 0 else nxt
    region = text[start:end]
    broken = region.replace("return true;", "return false;", 1)
    if broken == region:
        raise AssertionError("createAccount success return missing")
    return text[:start] + broken + text[end:]


class JourneyConsole:
    def __init__(self, proc: subprocess.Popen[bytes]) -> None:
        self.proc = proc
        self._chunks: list[str] = []
        self._lock = threading.Lock()
        thread = threading.Thread(target=self._read, name="honepad-journey", daemon=True)
        thread.start()

    def _read(self) -> None:
        stdout = self.proc.stdout
        assert stdout is not None
        fd = stdout.fileno()
        while True:
            try:
                data = os.read(fd, 4096)
            except OSError:
                return
            if not data:
                return
            with self._lock:
                self._chunks.append(data.decode("utf-8", "replace"))

    def text(self) -> str:
        with self._lock:
            return "".join(self._chunks)

    def wait_since(self, start: int, marker: str, timeout: float) -> str:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            new = self.text()[start:]
            if marker in new:
                return new
            code = self.proc.poll()
            if code is not None:
                raise AssertionError(f"console exited {code} waiting for {marker!r}\n{new[-4000:]}")
            time.sleep(0.05)
        new = self.text()[start:]
        raise AssertionError(f"timed out waiting for {marker!r}\n{new[-4000:]}")

    def send(self, line: str, *, until: str, timeout: float) -> str:
        start = len(self.text())
        stdin = self.proc.stdin
        assert stdin is not None
        stdin.write((line + "\n").encode())
        stdin.flush()
        chunk = self.wait_since(start, until, timeout)
        if "Traceback (most recent call last)" in chunk:
            raise AssertionError(chunk[-4000:])
        return chunk

    def close(self) -> None:
        if self.proc.poll() is not None:
            return
        stdin = self.proc.stdin
        if stdin is not None:
            stdin.close()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5)


class Desk:
    def __init__(self, root: Path, lang: str) -> None:
        self.root = root
        self.lang = lang
        self.repo = REPO
        self.shim_dir = root / "bin"
        self.shim_log = root / "code-argv.txt"
        self.run_s = 60 if lang == "python3" else 180
        self.shim_dir.mkdir()
        self._write_shim()
        self.env = os.environ.copy()
        self.env["HONEPAD_SESSION"] = str(root / "session.json")
        self.env["HONEPAD_ROOT"] = str(REPO)
        self.env["PYTHONPATH"] = str(REPO / "src")
        self.env["NO_COLOR"] = "1"
        self.env["TERM"] = "dumb"
        self.env["PYTHONUNBUFFERED"] = "1"
        self.env["PATH"] = str(self.shim_dir) + os.pathsep + self.env.get("PATH", "")
        # A quoted which() name is a CI toolchain. VS Code is not installed
        # there; this lookup only checks that the shim is first on PATH.
        editor = "code"
        found = shutil.which(editor, path=self.env["PATH"])
        if found is None or Path(found).resolve() != (self.shim_dir / editor).resolve():
            raise AssertionError(f"code shim is not first on PATH: {found}")

    def _write_shim(self) -> None:
        # The product looks this name up, then launches it. The shim must be executable.
        script = (
            f"#!{sys.executable}\n"
            "import pathlib, sys\n"
            f"pathlib.Path({str(self.shim_log)!r}).write_text('\\n'.join(sys.argv) + '\\n')\n"
        )
        path = self.shim_dir / "code"
        path.write_text(script, encoding="utf-8")
        path.chmod(0o755)

    def honepad(self, args: list[str], *, timeout: float = 60, ok: bool = True) -> str:
        proc = subprocess.run(
            [sys.executable, "-m", "honepad", *args],
            cwd=self.repo,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        out = proc.stdout + proc.stderr
        if ok and proc.returncode != 0:
            raise AssertionError(f"{args} -> {proc.returncode}\n{out[-4000:]}")
        if not ok and proc.returncode == 0:
            raise AssertionError(f"{args} succeeded\n{out[-4000:]}")
        return out

    @contextmanager
    def console(self) -> Iterator[JourneyConsole]:
        proc = subprocess.Popen(
            [sys.executable, "-m", "honepad", "console"],
            cwd=self.repo,
            env=self.env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        con = JourneyConsole(proc)
        try:
            con.wait_since(0, PROMPT, 20)
            yield con
        finally:
            con.close()

    def session(self) -> dict[str, object]:
        raw = json.loads((self.root / "session.json").read_text(encoding="utf-8"))
        if not isinstance(raw, dict):
            raise AssertionError("session file is not an object")
        return raw

    def session_text(self) -> str:
        return (self.root / "session.json").read_text(encoding="utf-8")

    def work(self, problem: str) -> Path:
        ext = str(language(self.lang)["ext"])
        if ext == "java":
            name = f"{class_name_for(problem)}.java"
        else:
            name = f"work.{ext}"
        return self.root / "work" / problem / self.lang / name

    def write_work(self, text: str) -> None:
        self.work(PROBLEM).write_text(text, encoding="utf-8")

    def workspace_root(self) -> Path:
        return self.root / "workspace" / f"{PROBLEM}-{self.lang}"

    def wait_shim(self, timeout: float = 5) -> str:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.shim_log.is_file() and self.shim_log.stat().st_size:
                return self.shim_log.read_text(encoding="utf-8")
            time.sleep(0.05)
        raise AssertionError("code shim was not invoked")

    def assert_workspace(self, *, submit_label: str, confirm: bool) -> None:
        root = self.workspace_root()
        payload = json.loads((root / "honepad.code-workspace").read_text(encoding="utf-8"))
        assert [item["name"] for item in payload["folders"]] == ["spec", "public-tests", "work"]
        if self.lang == "java":
            assert payload["extensions"]["recommendations"] == ["vscjava.vscode-java-pack"]
        else:
            assert payload["extensions"]["recommendations"] == ["ms-python.python"]
        public = root / "public"
        cases = json.loads((public / "cases.json").read_text(encoding="utf-8"))
        assert isinstance(cases, list) and cases
        readme = (public / "README.md").read_text(encoding="utf-8")
        if self.lang == "java":
            assert (public / "src" / "test" / "java" / "PublicTracesTest.java").is_file()
            assert "JUnit" in readme
            settings = self.work(PROBLEM).parent / ".vscode" / "settings.json"
            written = json.loads(settings.read_text(encoding="utf-8"))
            assert written["java.import.maven.enabled"] is False
            assert written["java.import.gradle.enabled"] is False
        else:
            assert (public / "test_public.py").is_file()
            assert "pytest" in readme
        tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
        labels = [item["label"] for item in tasks["tasks"]]
        assert "Run public tests" in labels
        assert submit_label in labels
        assert ("inputs" in tasks) is confirm
        if self.lang == "java":
            assert "Run JUnit tests" in labels
        else:
            assert "Run pytest" in labels


def _assert_declared(text: str, lang: str, level: int, *, present: bool) -> None:
    names = _introduced(lang, level)
    assert names, level
    for name in names:
        assert _declared(text, lang, name) is present, name


@pytest.mark.parametrize("lang", ["python3", "java"])
def test_bank_system_journey_from_start_through_done(tmp_path: Path, lang: str) -> None:
    if lang == "java" and shutil.which("javac") is None:
        pytest.skip("javac not on PATH")
    desk = Desk(tmp_path, lang)
    bank = desk.work(PROBLEM)

    out = desk.honepad(["start", PROBLEM, lang, "--minutes", "45", "--no-console"])
    assert "OK: LEVEL 1" in out
    assert "create_account" in out
    assert bank.is_file()
    assert (bank.parent / "spec.md").is_file()
    session = desk.session()
    assert session["problem"] == PROBLEM
    assert session["lang"] == lang
    assert session["unlocked"] == 1
    assert session["minutes"] == 45
    assert "desks" not in session
    started_at = session["started_at"]
    stub = bank.read_text(encoding="utf-8")
    _assert_declared(stub, lang, 1, present=True)
    _assert_declared(stub, lang, 2, present=False)

    out = desk.honepad(["start", "--minutes", "30", "--no-console"])
    assert "NOTE: clock is now 30 minutes" in out
    assert "OK: LEVEL 1" in out
    session = desk.session()
    assert session["minutes"] == 30
    assert session["unlocked"] == 1
    assert session["started_at"] == started_at

    out = desk.honepad(["start", PROBLEM, lang, "--level", "3", "--no-console"], ok=False)
    assert "LOCKED: LEVEL 3 (open through LEVEL 1)" in out
    session = desk.session()
    assert session["started_at"] == started_at
    assert session["unlocked"] == 1
    assert session["minutes"] == 30

    out = desk.honepad(["run", "workers"], ok=False)
    assert f"FAIL: session is {PROBLEM} {lang}, not workers" in out
    assert "passed=" not in out

    before = desk.session_text()
    out = desk.honepad(["timer"])
    assert "remaining_s=" in out
    assert "OK: started_at=" in out
    assert "do not sleep" in out
    assert desk.session_text() == before

    with desk.console() as con:
        assert f"honepad  {PROBLEM}  {lang}  LEVEL 1" in con.text()
        help_text = con.send("?", until=PROMPT, timeout=20)
        assert "1  run" in help_text
        assert "5  vscode" in help_text
        unknown = con.send("x", until=PROMPT, timeout=20)
        assert "FAIL: unknown option 'x'" in unknown
        assert f"honepad  {PROBLEM}  {lang}" not in unknown
        spec = con.send("4", until=PROMPT, timeout=20)
        assert "create_account" in spec
        con.send("", until=PROMPT, timeout=20)
        unchanged = bank.read_bytes()
        con.send("3", until="Anything else cancels", timeout=20)
        cancelled = con.send("nope", until=PROMPT, timeout=20)
        assert "OK: reset cancelled" in cancelled
        assert bank.read_bytes() == unchanged
        con.send("6", until="problem (Enter keeps", timeout=20)
        switched = con.send("q", until=PROMPT, timeout=20)
        assert "OK: switch cancelled" in switched
        assert desk.session()["problem"] == PROBLEM

        failed = con.send("1", until=PROMPT, timeout=desk.run_s)
        assert "FAIL" in failed
        assert "KIND: work" in failed
        assert "UNLOCKED" not in failed
        assert desk.session()["unlocked"] == 1

        if lang == "python3":
            desk.write_work("def (\n")
            broken = con.send("1", until=PROMPT, timeout=desk.run_s)
            assert "SyntaxError" in broken
            assert "work.py" in broken
            assert "UNLOCKED" not in broken
            assert "expected=" not in broken
            desk.write_work(
                "class Simulation:\n"
                "    def create_account(self, *args):\n"
                "        raise RuntimeError('boom')\n"
            )
            debug = con.send("1", until=PROMPT, timeout=desk.run_s)
            assert "DEBUG: RuntimeError: boom" in debug
            assert "work.py:3" in debug
            assert "UNLOCKED" not in debug
            for line in debug.splitlines():
                if line.startswith("DEBUG:"):
                    assert not line.split("DEBUG:", 1)[1].strip().startswith("{")
        else:
            desk.write_work("public class Simulation {\n    int x = ;\n}\n")
            broken = con.send("1", until=PROMPT, timeout=desk.run_s)
            assert "FAIL" in broken
            assert "Simulation.java" in broken
            assert "UNLOCKED" not in broken
            assert "expected=" not in broken

        desk.write_work(_break_create(lang, solution_through(lang, 1)))
        wrong = con.send("1", until=PROMPT, timeout=desk.run_s)
        assert "FAIL" in wrong
        assert "expected=" in wrong
        assert "actual=" in wrong
        assert "UNLOCKED" not in wrong
        assert desk.session()["unlocked"] == 1

        desk.write_work(solution_through(lang, 1))
        _assert_declared(bank.read_text(encoding="utf-8"), lang, 2, present=False)
        passed = con.send("run", until=PROMPT, timeout=desk.run_s)
        assert "failed=0" in passed
        assert "still LEVEL 1" in passed
        assert "hidden through" not in passed
        assert "UNLOCKED" not in passed
        assert desk.session()["unlocked"] == 1

        con.send("2", until="Unlock?", timeout=20)
        held = con.send("n", until=PROMPT, timeout=20)
        assert "OK: submit cancelled" in held
        assert "passed=" not in held
        assert desk.session()["unlocked"] == 1

        con.send("submit", until="Unlock?", timeout=20)
        unlocked = con.send("y", until=PROMPT, timeout=desk.run_s)
        assert "UNLOCKED: level 2" in unlocked
        assert "hidden through LEVEL" in unlocked
        assert "failed=0" in unlocked
        assert desk.session()["unlocked"] == 2
        _assert_declared(bank.read_text(encoding="utf-8"), lang, 2, present=True)
        bank_at_2 = bank.read_bytes()

        con.send("6", until="problem (Enter keeps", timeout=20)
        con.send("workers", until="language (Enter keeps", timeout=20)
        moved = con.send("", until=PROMPT, timeout=20)
        assert "NOTE: new desk at LEVEL 1. Clock is 30 minutes." in moved
        assert f"OK: workers {lang} LEVEL 1" in moved
        assert bank.read_bytes() == bank_at_2
        assert desk.work("workers").is_file()
        session = desk.session()
        assert session["problem"] == "workers"
        assert session["unlocked"] == 1
        assert session["minutes"] == 30
        desks = session["desks"]
        assert isinstance(desks, dict)
        assert desks["bank_system"]["unlocked"] == 2
        assert desks["bank_system"]["minutes"] == 30
        quit_out = con.send("q", until="OK: quit", timeout=20)
        assert "OK: quit" in quit_out
        assert con.proc.wait(timeout=10) == 0

    out = desk.honepad(["start", "--minutes", "12", "--no-console"])
    assert "NOTE: clock is now 12 minutes" in out
    session = desk.session()
    assert session["problem"] == "workers"
    assert session["minutes"] == 12
    assert session["unlocked"] == 1

    out = desk.honepad(["start", "--no-console"])
    assert "OK: LEVEL 1" in out
    session = desk.session()
    assert session["problem"] == "workers"
    assert session["minutes"] == 12

    out = desk.honepad(["start", PROBLEM, lang, "--level", "1", "--no-console"])
    assert "NOTE: resume at LEVEL 2" in out
    assert "NOTE: showing LEVEL 1. The desk is open through LEVEL 2." in out
    assert "OK: LEVEL 2" in out
    session = desk.session()
    assert session["problem"] == PROBLEM
    assert session["unlocked"] == 2
    assert session["minutes"] == 30
    desks = session["desks"]
    assert isinstance(desks, dict)
    assert desks["workers"]["minutes"] == 12
    assert desks["workers"]["unlocked"] == 1
    assert bank.read_bytes() == bank_at_2

    desk.shim_log.unlink(missing_ok=True)
    out = desk.honepad(["vscode"], timeout=30)
    assert "OK: opened in VS Code" in out
    assert "WORKSPACE:" in out
    assert "TESTS:" in out
    opened = desk.wait_shim()
    assert "--new-window" in opened
    assert "honepad.code-workspace" in opened
    assert str(bank) in opened
    desk.assert_workspace(submit_label="Submit (unlock next level)", confirm=True)

    desk.shim_log.unlink()
    out = desk.honepad(["vscode", "--no-open"])
    assert "OK: wrote workspace" in out
    assert not desk.shim_log.exists()

    with desk.console() as con:
        assert "LEVEL 2" in con.text()
        con.send("6", until="problem (Enter keeps", timeout=20)
        con.send("workers", until="language (Enter keeps", timeout=20)
        resumed = con.send("", until=PROMPT, timeout=20)
        assert "NOTE: resumed workers at LEVEL 1. Clock is 12 minutes." in resumed
        assert bank.read_bytes() == bank_at_2
        con.send("6", until="problem (Enter keeps", timeout=20)
        con.send(PROBLEM, until="language (Enter keeps", timeout=20)
        resumed = con.send("", until=PROMPT, timeout=20)
        assert "NOTE: resumed bank_system at LEVEL 2. Clock is 30 minutes." in resumed
        assert desk.session()["minutes"] == 30
        assert desk.session()["unlocked"] == 2

        desk.shim_log.unlink(missing_ok=True)
        opened_key = con.send("5", until=PROMPT, timeout=30)
        assert "OK: opened in VS Code" in opened_key
        assert "WORKSPACE:" in opened_key
        assert "TESTS:" in opened_key
        launched = desk.wait_shim()
        assert "--new-window" in launched
        assert "honepad.code-workspace" in launched
        assert str(bank) in launched

        for level in (2, 3):
            _assert_declared(bank.read_text(encoding="utf-8"), lang, level, present=True)
            failed = con.send("1", until=PROMPT, timeout=desk.run_s)
            assert "FAIL" in failed
            assert "UNLOCKED" not in failed
            assert desk.session()["unlocked"] == level
            desk.write_work(solution_through(lang, level))
            _assert_declared(bank.read_text(encoding="utf-8"), lang, level + 1, present=False)
            con.send("2", until="Unlock?", timeout=20)
            unlocked = con.send("y", until=PROMPT, timeout=desk.run_s)
            assert f"UNLOCKED: level {level + 1}" in unlocked
            assert "hidden through LEVEL" in unlocked
            assert "failed=0" in unlocked
            assert desk.session()["unlocked"] == level + 1
            _assert_declared(bank.read_text(encoding="utf-8"), lang, level + 1, present=True)

        assert desk.session()["unlocked"] == 4
        assert desk.session().get("cleared") is not True
        desk.assert_workspace(submit_label="Submit last level", confirm=False)
        failed = con.send("1", until=PROMPT, timeout=desk.run_s)
        assert "FAIL" in failed
        assert "UNLOCKED" not in failed
        assert "DONE:" not in failed
        desk.write_work(solution_through(lang, 4))
        finished = con.send("2", until=PROMPT, timeout=desk.run_s)
        assert "Unlock?" not in finished
        assert f"DONE: {PROBLEM} {lang}" in finished
        assert "all 4 levels" in finished
        assert "UNLOCKED:" not in finished
        assert desk.session().get("cleared") is True
        desk.assert_workspace(submit_label="Replay last level", confirm=False)

        replay = con.send("2", until=PROMPT, timeout=desk.run_s)
        assert "Unlock?" not in replay
        assert "NOTE: replay" in replay
        assert "still complete" in replay
        assert desk.session().get("cleared") is True
        helped = con.send("help", until=PROMPT, timeout=20)
        assert "2  replay" in helped

        desk.shim_log.unlink(missing_ok=True)
        again = con.send("code", until=PROMPT, timeout=30)
        assert "OK: opened in VS Code" in again
        assert "--new-window" in desk.wait_shim()
        desk.assert_workspace(submit_label="Replay last level", confirm=False)

        # Line mode has no TTY, so Ctrl-D is the EOT byte on its own line.
        end = con.send("\x04", until="OK: quit", timeout=20)
        assert "OK: quit" in end
        assert con.proc.wait(timeout=10) == 0

    out = desk.honepad(["debrief"])
    assert f"DEBRIEF: {PROBLEM} {lang} LEVEL 4/4" in out

    out = desk.honepad(["start", PROBLEM, lang, "--reset", "--no-console"])
    assert "OK: LEVEL 1" in out
    session = desk.session()
    assert session["problem"] == PROBLEM
    assert session["unlocked"] == 1
    assert session["minutes"] == 90
    assert session.get("cleared") is not True
    desks = session["desks"]
    assert isinstance(desks, dict)
    assert desks["workers"]["minutes"] == 12
    assert desks["workers"]["unlocked"] == 1
    assert desk.work("workers").is_file()
    rewritten = bank.read_text(encoding="utf-8")
    _assert_declared(rewritten, lang, 1, present=True)
    _assert_declared(rewritten, lang, 4, present=False)
    desk.assert_workspace(submit_label="Submit (unlock next level)", confirm=True)
