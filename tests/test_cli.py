import pytest

from honepad.catalog import languages
from honepad.cli import build_parser, main
from honepad.runner import _RUNNERS

# Catalog id used by unimplemented-lang CLI tests. Must stay off
# _RUNNERS so start/run keep failing with FAIL: instead of succeeding.
UNIMPLEMENTED_CATALOG_LANG = "vb"


def test_unimplemented_catalog_lang_not_in_runners() -> None:
    assert UNIMPLEMENTED_CATALOG_LANG not in _RUNNERS


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


def test_run_bank(capsys) -> None:
    assert main(["run", "bank_system", "--lang", "python3", "--level", "4"]) == 0
    assert "OK" in capsys.readouterr().out


def test_timer_does_not_sleep(capsys) -> None:
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


def test_run_unknown_lang_id_exits(capsys) -> None:
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
    assert "adapter=" in out
    assert "OK: unlocked=" not in out
    assert "Bank system level" not in out
    assert "STUB:" not in out
    assert "Traceback" not in out


def test_start_help_mentions_fail_for_unimplemented(capsys) -> None:
    parser = build_parser()
    with pytest.raises(SystemExit) as excinfo:
        parser.parse_args(["start", "-h"])
    assert excinfo.value.code == 0
    out = capsys.readouterr().out
    assert "FAIL" in out
    assert "unimplemented" in out.lower()


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
    assert "Traceback" not in out
