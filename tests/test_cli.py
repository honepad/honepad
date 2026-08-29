import io
import subprocess
import sys
from pathlib import Path

import pytest

from honepad.catalog import languages, problems
from honepad.cli import build_parser, main
from honepad.runner import _RUNNERS, run_prepare_cmd
from honepad.session import load_session
from honepad.term import invocation

# Catalog id used by unimplemented-lang CLI tests. Must stay off
# _RUNNERS so start/run keep failing with FAIL: instead of succeeding.
UNIMPLEMENTED_CATALOG_LANG = "vb"


def test_unimplemented_catalog_lang_not_in_runners() -> None:
    assert UNIMPLEMENTED_CATALOG_LANG not in _RUNNERS


def test_invocation_from_argv0() -> None:
    exe = Path(sys.executable).name or "python3"
    assert invocation("./honepad") == "./honepad"
    assert invocation("honepad") == "honepad"
    assert invocation("/tmp/clone/honepad") == "/tmp/clone/honepad"
    assert invocation("__main__.py") == f"{exe} -m honepad"
    assert invocation("/opt/honepad/src/honepad/__main__.py") == f"{exe} -m honepad"
    assert invocation("pytest") == "honepad"


def test_python_module_honepad_langs() -> None:
    result = subprocess.run(
        [sys.executable, "-m", "honepad", "langs"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    assert "languages" in result.stdout


def _langs_header_and_rows(out: str) -> tuple[str, list[str]]:
    lines = [line for line in out.splitlines() if line.strip()]
    assert lines
    return lines[0], lines[1:]


def test_langs_header_includes_runner_count(capsys) -> None:
    assert main(["langs"]) == 0
    header, _rows = _langs_header_and_rows(capsys.readouterr().out)
    assert str(len(languages())) in header
    assert str(len(_RUNNERS)) in header


def test_langs(capsys) -> None:
    assert main(["langs"]) == 0
    out = capsys.readouterr().out
    assert "python3" in out
    assert "javascript" in out
    _header, lang_lines = _langs_header_and_rows(out)
    assert lang_lines
    python3 = next(line for line in lang_lines if line.split()[0] == "python3")
    assert "no-runner" not in python3.split()
    assert "runner" in python3.split()
    fortran = next(line for line in lang_lines if line.split()[0] == "fortran")
    assert "no-runner" not in fortran.split()
    assert "runner" in fortran.split()
    fsharp = next(line for line in lang_lines if line.split()[0] == "fsharp")
    assert "no-runner" not in fsharp.split()
    assert "runner" in fsharp.split()
    freepascal = next(line for line in lang_lines if line.split()[0] == "freepascal")
    assert "no-runner" not in freepascal.split()
    assert "runner" in freepascal.split()
    smalltalk = next(line for line in lang_lines if line.split()[0] == "smalltalk")
    assert "no-runner" not in smalltalk.split()
    assert "runner" in smalltalk.split()
    shell = next(line for line in lang_lines if line.split()[0] == "shell")
    assert "no-runner" not in shell.split()
    assert "runner" in shell.split()
    unimplemented = next(
        line for line in lang_lines if line.split()[0] == UNIMPLEMENTED_CATALOG_LANG
    )
    assert "no-runner" in unimplemented.split()
    for line in lang_lines:
        markers = [tok for tok in line.split() if tok in ("runner", "no-runner")]
        assert len(markers) == 1, line


def test_langs_runner_column_matches_dispatch_table(capsys) -> None:
    assert main(["langs"]) == 0
    out = capsys.readouterr().out
    _header, lang_lines = _langs_header_and_rows(out)
    by_id = {line.split()[0]: line.split() for line in lang_lines}
    catalog_ids = [row["id"] for row in languages()]
    assert catalog_ids
    assert set(by_id) == set(catalog_ids)
    for lang_id in catalog_ids:
        markers = [tok for tok in by_id[lang_id] if tok in ("runner", "no-runner")]
        assert markers == (["runner"] if lang_id in _RUNNERS else ["no-runner"]), lang_id


def test_run_bank(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    assert main(["run", "bank_system", "--lang", "python3", "--level", "4"]) == 0
    assert "OK" in capsys.readouterr().out


def test_timer_does_not_sleep(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "missing.json"))
    assert main(["timer", "--minutes", "90"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=5400" in out
    assert "NEXT:" in out


def test_run_unimplemented_catalog_lang_exits(capsys) -> None:
    code = main(["run", "bank_system", "--lang", UNIMPLEMENTED_CATALOG_LANG, "--level", "1"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code in (1, 2)
    assert UNIMPLEMENTED_CATALOG_LANG in out
    assert "adapter=" in out
    assert "Traceback" not in out


def test_run_unknown_lang_id_exits(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    assert main(["start", "bank_system", "java", "--reset"]) == 0
    capsys.readouterr()
    code = main(["run", "bank_system", "--lang", "notalang", "--level", "1"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code in (1, 2)
    assert "notalang" in out
    assert "Traceback" not in out


def test_start_unimplemented_catalog_lang_exits(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    code = main(["start", "bank_system", UNIMPLEMENTED_CATALOG_LANG])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code in (1, 2)
    assert "FAIL" in out
    assert UNIMPLEMENTED_CATALOG_LANG in out
    assert "no runner" in out
    assert "adapter=" not in out
    assert "factory job" not in out
    assert "NEXT:" in out
    assert "start bank_system java" in out
    assert "OK: unlocked=" not in out
    assert "Bank system level" not in out
    assert "STUB:" not in out
    assert "WORK:" not in out
    assert "Traceback" not in out


def _tty_stdin(monkeypatch, text: str) -> io.StringIO:
    fake_in = io.StringIO(text)
    monkeypatch.setattr(fake_in, "isatty", lambda: True)
    monkeypatch.setattr(sys, "stdin", fake_in)
    monkeypatch.setattr(sys.stdout, "isatty", lambda: True)
    monkeypatch.setattr("honepad.console._use_live", lambda *_a, **_k: False)
    return fake_in


def test_start_without_args_on_tty_picks_lang_then_problem(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    _tty_stdin(monkeypatch, "python3\nbank_system\n")
    assert main(["start", "--no-console"]) == 0
    out = capsys.readouterr().out
    session = load_session()
    assert session is not None
    assert session["lang"] == "python3"
    assert session["problem"] == "bank_system"
    assert "language:" in out
    assert "problem:" in out
    assert "python3" in out
    assert "bank_system" in out
    assert UNIMPLEMENTED_CATALOG_LANG not in out
    assert "OK: unlocked=" in out


def test_start_picker_accepts_numbers(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    runner_ids = [row["id"] for row in languages() if row["id"] in _RUNNERS]
    lang_n = runner_ids.index("java") + 1
    problem_n = problems().index("file_storage") + 1
    _tty_stdin(monkeypatch, f"{lang_n}\n{problem_n}\n")
    assert main(["start", "--no-console"]) == 0
    capsys.readouterr()
    session = load_session()
    assert session is not None
    assert session["lang"] == "java"
    assert session["problem"] == "file_storage"


def test_start_with_problem_only_picks_lang(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    _tty_stdin(monkeypatch, "python3\n")
    assert main(["start", "workers", "--no-console"]) == 0
    out = capsys.readouterr().out
    session = load_session()
    assert session is not None
    assert session["lang"] == "python3"
    assert session["problem"] == "workers"
    assert "language:" in out
    assert "problem:" not in out


def test_bare_honepad_no_session_on_tty_picks(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    _tty_stdin(monkeypatch, "python3\nbank_system\nq\n")
    assert main([]) == 0
    out = capsys.readouterr().out
    session = load_session()
    assert session is not None
    assert session["lang"] == "python3"
    assert session["problem"] == "bank_system"
    assert "language:" in out
    assert "problem:" in out
    assert "OK: quit" in out


def test_start_picker_quit_prints_next(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    _tty_stdin(monkeypatch, "q\n")
    assert main(["start", "--no-console"]) == 1
    out = capsys.readouterr().out
    assert "FAIL:" in out
    assert "NEXT:" in out
    assert load_session() is None


def test_start_help_mentions_fail_for_unimplemented(capsys) -> None:
    parser = build_parser()
    with pytest.raises(SystemExit) as excinfo:
        parser.parse_args(["start", "-h"])
    assert excinfo.value.code == 0
    out = capsys.readouterr().out
    assert "FAIL" in out
    assert "unimplemented" in out.lower()


def test_start_missing_stub_prints_fail(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))

    def _missing(*_args, **_kwargs):
        raise FileNotFoundError("missing stub")

    monkeypatch.setattr("honepad.cli.ensure_work_copy", _missing)
    assert main(["start", "bank_system", "python3"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "missing stub" in out
    assert "Traceback" not in out


def test_start_os_filenotfound_prints_full_fail(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))

    def _missing(*_args, **_kwargs):
        raise FileNotFoundError(2, "No such file or directory", "/missing/stub.java")

    monkeypatch.setattr("honepad.cli.ensure_work_copy", _missing)
    assert main(["start", "bank_system", "java"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert "FAIL: 2" not in out
    assert "No such file" in out or "/missing/stub.java" in out
    assert "Traceback" not in out


def test_start_unknown_lang_id_exits(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setenv("HONEPAD_SESSION", str(tmp_path / "session.json"))
    code = main(["start", "bank_system", "notalang"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code in (1, 2)
    assert "FAIL" in out
    assert "notalang" in out
    assert "OK: unlocked=" not in out
    assert "Bank system level" not in out
    assert "STUB:" not in out
    assert "WORK:" not in out
    assert "Traceback" not in out


def test_start_java_missing_javac_fails_before_session(monkeypatch, tmp_path, capsys) -> None:
    session_file = tmp_path / "session.json"
    monkeypatch.setenv("HONEPAD_SESSION", str(session_file))

    def _which(name: str, mode: int = 0, path: str | None = None) -> str | None:
        if name == "javac":
            return None
        return f"/usr/bin/{name}"

    monkeypatch.setattr("shutil.which", _which)
    code = main(["start", "bank_system", "java", "--reset", "--no-console"])
    out = capsys.readouterr().out
    assert code == 1
    assert "FAIL" in out
    assert "javac" in out
    assert "PATH" in out
    assert "NEXT:" in out
    assert "OK: unlocked=" not in out
    assert not session_file.is_file()


def test_run_prepare_cmd_missing_binary_raises(tmp_path: Path) -> None:
    with pytest.raises(RuntimeError, match="not on PATH"):
        run_prepare_cmd(["no-such-honepad-compiler"], tmp_path, "java")


def test_corrupt_cases_prints_fail(monkeypatch, tmp_path, capsys) -> None:
    cases_dir = tmp_path / "cases"
    cases_dir.mkdir()
    cases_path = cases_dir / "level1.json"
    cases_path.write_text("{", encoding="utf-8")
    monkeypatch.setattr("honepad.traces.problem_dir", lambda _problem: tmp_path)
    assert main(["cases", "bank_system", "--level", "1"]) == 1
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert "FAIL:" in out
    assert str(cases_path) in out or "level1.json" in out
    assert "Traceback" not in out
