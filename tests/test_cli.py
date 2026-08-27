from honepad.cli import main


def test_langs(capsys) -> None:
    assert main(["langs"]) == 0
    out = capsys.readouterr().out
    assert "python3" in out
    assert "javascript" in out
    lang_lines = [
        line for line in out.splitlines() if line.strip() and not line.endswith(" languages")
    ]
    assert lang_lines
    python3 = next(line for line in lang_lines if line.split()[0] == "python3")
    assert "no-runner" not in python3.split()
    assert "runner" in python3.split()
    fortran = next(line for line in lang_lines if line.split()[0] == "fortran")
    assert "no-runner" in fortran.split()
    for line in lang_lines:
        markers = [tok for tok in line.split() if tok in ("runner", "no-runner")]
        assert len(markers) == 1, line


def test_run_bank(capsys) -> None:
    assert main(["run", "bank_system", "--lang", "python3", "--level", "4"]) == 0
    assert "OK" in capsys.readouterr().out


def test_timer_does_not_sleep(capsys) -> None:
    assert main(["timer", "--minutes", "90"]) == 0
    out = capsys.readouterr().out
    assert "remaining_s=5400" in out
    assert "NEXT:" in out


def test_run_unimplemented_catalog_lang_exits(capsys) -> None:
    code = main(["run", "bank_system", "--lang", "fortran", "--level", "1"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code in (1, 2)
    assert "fortran" in out
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
    code = main(["start", "bank_system", "fortran"])
    captured = capsys.readouterr()
    out = captured.out + captured.err
    assert code in (1, 2)
    assert "FAIL" in out
    assert "fortran" in out
    assert "adapter=" in out
    assert "OK: unlocked=" not in out
    assert "Bank system level" not in out
    assert "STUB:" not in out
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
    assert "Traceback" not in out
