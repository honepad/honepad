import io
import json
import sys
from pathlib import Path

from honepad.cli import main
from honepad.term import file_link, file_uri, format_clock
from honepad.workspace import write_workspace


def test_format_clock_pads_minutes() -> None:
    assert format_clock(0) == "00:00"
    assert format_clock(65) == "01:05"
    assert format_clock(3600) == "1:00:00"


def test_file_link_uses_osc8() -> None:
    path = Path("/tmp/honepad-work.java")
    text = file_link(path)
    assert "\x1b]8;;file://" in text
    assert "honepad-work.java" in text
    assert file_uri(path).startswith("file://")


def test_start_work_path_is_file_uri(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    out = capsys.readouterr().out
    work = tmp_path / "work" / "bank_system" / "java" / "work.java"
    assert "WORK:" in out
    assert str(work) in out
    assert "file://" in out
    assert "honepad console" in out


def test_console_no_session_fails(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["console"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "no session" in out


def test_console_needs_both_args(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["console", "bank_system"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "both problem and lang" in out


def test_console_unimplemented_lang_fails(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["console", "bank_system", "vb"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "vb" in out
    assert "adapter=" in out


def test_console_quit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("q\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=" in out
    assert "1 run" in out
    assert "2 submit" in out
    assert "3 reset" in out
    assert "5 vscode" in out
    assert "OK: quit" in out
    assert "file://" in out


def test_console_run_then_quit(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("1\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "FAIL" in out
    assert "OK: quit" in out


def test_console_reset(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    work = tmp_path / "work" / "bank_system" / "python3" / "work.py"
    work.write_text("edited-by-candidate\n", encoding="utf-8")
    monkeypatch.setattr(sys, "stdin", io.StringIO("3\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "OK: reset" in out
    assert "def create_account(" in work.read_text(encoding="utf-8")
    assert "edited-by-candidate" not in work.read_text(encoding="utf-8")


def test_console_spec(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr(sys, "stdin", io.StringIO("4\nq\n"))
    assert main(["console"]) == 0
    out = capsys.readouterr().out
    assert "level" in out.lower()
    assert "create" in out.lower()


def test_vscode_no_open_writes_public_tests(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    assert main(["vscode", "--no-open"]) == 0
    out = capsys.readouterr().out
    dest = tmp_path / "workspace" / "bank_system-java" / "honepad.code-workspace"
    assert dest.is_file()
    assert "WORKSPACE:" in out
    assert "file://" in out
    payload = json.loads(dest.read_text(encoding="utf-8"))
    names = [folder["name"] for folder in payload["folders"]]
    assert names == ["work", "public-tests"]
    public = dest.parent / "public"
    cases = json.loads((public / "cases.json").read_text(encoding="utf-8"))
    assert cases
    assert all(int(case["level"]) <= 1 for case in cases)
    assert (public / "Adapter.java").is_file()
    assert (public / "MiniJson.java").is_file()
    assert (public / "Simulation.java").is_file()
    assert (public / "run-public.sh").is_file()
    assert (public / "spec.md").is_file()
    tasks = json.loads((public / ".vscode" / "tasks.json").read_text(encoding="utf-8"))
    labels = [task["label"] for task in tasks["tasks"]]
    assert "Run public tests" in labels


def test_workspace_python_skips_java_adapter(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    dest = write_workspace("bank_system", "python3", 1)
    public = dest.parent / "public"
    assert (public / "cases.json").is_file()
    assert not (public / "Adapter.java").exists()
    assert not (public / "run-public.sh").exists()


def test_vscode_missing_code_prints_fail(monkeypatch, tmp_path: Path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "python3", "--reset"]) == 0
    capsys.readouterr()
    monkeypatch.setattr("honepad.workspace.shutil.which", lambda _name: None)
    assert main(["vscode"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "code" in out
    assert "file://" in out
